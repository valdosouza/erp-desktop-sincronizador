unit un_sync_key_state;

{ D-SY13 (Valdo, 2026-10-18) - chave do sincronizador INATIVA.

  O setes-sync recusa a chave com codigo proprio:
    401 SYNC_KEY_MISSING  - header X-Api-Key ausente (FApiKey vazio)
    401 SYNC_KEY_INVALID  - chave inexistente
    403 SYNC_KEY_INACTIVE - chave EXISTENTE e inativa
  Ao receber a recusa (TGeneralWeb.AuthRefused) o sincronizador:
    - interrompe o ciclo SEM gravar SRC_LOG naquele registro (os registros
      seguem pendentes na TB_SINCRONIA - nada se perde);
    - grava aqui o estado "sincronia inativa" (CONFIG.INI, secao SISWEB -
      persiste entre aberturas);
    - o timer nao dispara mais e toda tentativa manual fica INERTE.
  So volta quando o usuario usa "Ativar sincronia" (Tarefas): a acao consulta
  GET /sync-key/status - ativa = limpa o estado e retoma; inativa ou
  inexistente = nada muda.
  A-SY1 (a ratificar pelo Valdo): o 401 (chave inexistente ou ausente) tem o
  MESMO efeito do 403.
  Limite conhecido (setes-sync): a chave VALIDA fica 5 min em cache no
  servidor - desativar a chave vale em ate 5 min.

  Texto SEM acentuacao de proposito (arquivo sem BOM, lido como ANSI). }

interface

type
  TSyncKeyCheck = (skcAtiva, skcInativa, skcIndeterminado);

// Estado gravado localmente (CONFIG.INI, SISWEB\SincroniaInativa = 'S')
function SincroniaInativa: Boolean;
// Texto para a tela: desde quando e por que
function SincroniaInativaDescricao: String;
// Nunca levanta excecao (quem chama esta no meio do laco de envio): falha ao
// gravar o CONFIG.INI vai para o log_api_data.txt e devolve False - o ciclo
// para do mesmo jeito e o proximo recebe a recusa de novo.
function MarcarSincroniaInativa(pStatusHttp: Integer; const pCodigo, pMensagem: String): Boolean;
procedure LimparSincroniaInativa;
// Recusa de autenticacao do setes-sync (401 qualquer - A-SY1 - ou 403
// SYNC_KEY_INACTIVE). Fonte UNICA da regra: TGeneralWeb e a consulta abaixo.
function IsRecusaDaChave(pStatusHttp: Integer; const pCodigo: String): Boolean;
// Consulta GET /sync-key/status com a chave da instalacao
function ConsultarChaveSincronia(const pUrl, pApiKey: String; out pDetalhe: String): TSyncKeyCheck;

implementation

uses System.SysUtils, System.JSON, REST.Client, REST.Types, un_sistema, UnFunctions;

const
  SECAO           = 'SISWEB';
  CH_INATIVA      = 'SincroniaInativa';
  CH_DESDE        = 'SincroniaInativaDesde';
  CH_MOTIVO       = 'SincroniaInativaMotivo';
  ENDPOINT_STATUS = '/sync-key/status';
  CODE_INACTIVE   = 'SYNC_KEY_INACTIVE';

function SincroniaInativa: Boolean;
begin
  Result := UpperCase(Trim(Fc_Aq_Geral('L', SECAO, CH_INATIVA, 'N'))) = 'S';
end;

function SincroniaInativaDescricao: String;
Var
  LcDesde, LcMotivo: String;
begin
  LcDesde  := Trim(Fc_Aq_Geral('L', SECAO, CH_DESDE, ''));
  LcMotivo := Trim(Fc_Aq_Geral('L', SECAO, CH_MOTIVO, ''));
  Result := 'Sincronia INATIVA - a chave foi recusada pelo servidor';
  if LcDesde <> '' then
    Result := Result + ' em ' + LcDesde;
  if LcMotivo <> '' then
    Result := Result + ' (' + LcMotivo + ')';
  Result := Result + '. Use Tarefas > Ativar sincronia depois que a chave voltar a ficar ativa.';
end;

function MarcarSincroniaInativa(pStatusHttp: Integer; const pCodigo, pMensagem: String): Boolean;
Var
  LcMotivo: String;
begin
  Result := False;
  try
    LcMotivo := 'HTTP ' + IntToStr(pStatusHttp);
    if Trim(pCodigo) <> '' then
      LcMotivo := LcMotivo + ' ' + Trim(pCodigo);
    if Trim(pMensagem) <> '' then
      LcMotivo := LcMotivo + ' - ' + Trim(pMensagem);
    // corpo de um intermediario (HTML com quebras de linha) nao pode quebrar
    // o CONFIG.INI: valor de INI e UMA linha
    LcMotivo := StringReplace(LcMotivo, #13, ' ', [rfReplaceAll]);
    LcMotivo := StringReplace(LcMotivo, #10, ' ', [rfReplaceAll]);
    LcMotivo := Copy(Trim(LcMotivo), 1, 200);
    // motivo antes do flag: quem le o flag 'S' ja encontra o motivo gravado
    Fc_Aq_Geral('G', SECAO, CH_DESDE, FormatDateTime('dd/mm/yyyy hh:nn:ss', Now));
    Fc_Aq_Geral('G', SECAO, CH_MOTIVO, LcMotivo);
    Fc_Aq_Geral('G', SECAO, CH_INATIVA, 'S');
    Result := True;
  except
    on E: Exception do
      try
        GeralogFile('un_sync_key_state', 'falha ao gravar SincroniaInativa no CONFIG.INI: ' + E.Message);
      except
      end;
  end;
end;

procedure LimparSincroniaInativa;
begin
  Fc_Aq_Geral('G', SECAO, CH_INATIVA, 'N');
  Fc_Aq_Geral('G', SECAO, CH_DESDE, '');
  Fc_Aq_Geral('G', SECAO, CH_MOTIVO, '');
end;

function IsRecusaDaChave(pStatusHttp: Integer; const pCodigo: String): Boolean;
begin
  Result := (pStatusHttp = 401) or
            ((pStatusHttp = 403) and (Trim(pCodigo) = CODE_INACTIVE));
end;

function ConsultarChaveSincronia(const pUrl, pApiKey: String; out pDetalhe: String): TSyncKeyCheck;
Var
  LcClient   : TRESTClient;
  LcRequest  : TRESTRequest;
  LcResponse : TRESTResponse;
  LcJson     : TJSONValue;
  LcCodigo   : String;
  LcStatus   : Integer;
begin
  Result   := skcIndeterminado;
  pDetalhe := '';
  LcClient   := TRESTClient.Create(pUrl + ENDPOINT_STATUS);
  LcRequest  := TRESTRequest.Create(nil);
  LcResponse := TRESTResponse.Create(nil);
  try
    try
      LcRequest.Client   := LcClient;
      LcRequest.Response := LcResponse;
      LcRequest.Method   := rmGET;
      LcRequest.Timeout  := 15000;
      LcRequest.Params.AddItem('X-Api-Key', pApiKey,
        TRESTRequestParameterKind.pkHTTPHEADER,
        [TRESTRequestParameterOption.poDoNotEncode]);
      LcRequest.Execute;
      LcStatus := LcResponse.StatusCode;

      LcCodigo := '';
      LcJson := nil;
      try
        if LcResponse.Content <> '' then
          LcJson := TJSONObject.ParseJSONValue(LcResponse.Content);
        if (LcJson is TJSONObject) and
           Assigned(TJSONObject(LcJson).GetValue('code')) then
          LcCodigo := TJSONObject(LcJson).GetValue('code').Value;
      finally
        if Assigned(LcJson) then LcJson.Free;
      end;

      pDetalhe := 'HTTP ' + IntToStr(LcStatus);
      if LcCodigo <> '' then
        pDetalhe := pDetalhe + ' ' + LcCodigo;

      if LcStatus = 200 then
        Result := skcAtiva
      else if IsRecusaDaChave(LcStatus, LcCodigo) then
        Result := skcInativa;
      // outro status (servidor fora, 404 de servidor antigo sem a consulta,
      // 5xx...) = indeterminado: a sincronia segue inativa
    except
      on E: Exception do
        pDetalhe := E.Message;
    end;
  finally
    LcResponse.Free;
    LcRequest.Free;
    LcClient.Free;
  end;
end;

end.
