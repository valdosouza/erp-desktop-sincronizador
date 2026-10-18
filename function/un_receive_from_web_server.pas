unit un_receive_from_web_server;

interface

uses
  Classes,System.SysUtils,System.StrUtils,Vcl.Forms,Vcl.CheckLst,
  IdHTTP,un_base_setes, general_web, un_sync_key_state;

type
    TreceiveFromWebServer = Class(TBaseSetes)
  private
    // D-SY13: o setes-sync recusou a CHAVE neste ciclo - para tudo
    FChaveRecusada: Boolean;
    procedure PreparaListBox;

    procedure SyncTable(indice: Integer);
    procedure send;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure   inicializa; Override;
    procedure   Execute;
  End;

implementation

{ TreceiveFromWebServer }

procedure TreceiveFromWebServer.PreparaListBox;
Var
  I: Integer;
Begin
  FlistBox.Items.Clear;
  FListaSincronia.getListaReceber;
  for I := 0 to FListaSincronia.ListaReceber.count - 1 do
  Begin
    FlistBox.Items.Add(FListaSincronia.ListaReceber[I].Tabela);
  End;
End;



procedure TreceiveFromWebServer.SyncTable(indice: Integer);
Var
  I: Integer;
  LcReceiveWeb : TGeneralWeb;
begin
  LcReceiveWeb := TGeneralSendFactory.Instanciar(FListaSincronia.registro.NomeClasse);
  try
    SetProgressBar(FSincronia.Lista.count);
    LcReceiveWeb.InstitutionDestino := FInstitutionDestino;
    LcReceiveWeb.URL := FURL;
    // D-SY13: sem a chave o setes-sync responde 401 e a sincronia INTEIRA
    // ficaria inativa (antes so marcava o SRC_LOG) - mesma chave do envio
    LcReceiveWeb.ApiKey := FApiKey;
    LcReceiveWeb.Metodo := 'Get';
    LcReceiveWeb.EndPoint := FListaSincronia.registro.endPoint;
    LcReceiveWeb.Inicializa;
    for I := 0 to FSincronia.Lista.count - 1 do
    Begin
      // Parada graciosa: usuario pediu para fechar - para ANTES do
      // proximo registro (o atual ja gravou checkpoint/SRC_LOG).
      if PararSolicitado then Break;
      TRy
        Try
          LcReceiveWeb.Codigo := FSincronia.Lista[I].Registro;
          LcReceiveWeb.receive;
          // D-SY13: chave recusada - nada de SRC_LOG, sincronia INATIVA
          if LcReceiveWeb.AuthRefused then
          Begin
            FChaveRecusada := True;
            // nunca levanta (falha ao gravar o CONFIG.INI vai para o log) -
            // nada cai no Except abaixo, que gravaria SRC_LOG num registro
            MarcarSincroniaInativa(LcReceiveWeb.Retorno.ID, LcReceiveWeb.ErrorCode,
              LcReceiveWeb.Retorno.Mensagem);
          End;
        Finally
          if not LcReceiveWeb.AuthRefused then
          Begin
            FSincronia.Clear;
            FSincronia.Registro.Tabela    := FListaSincronia.Registro.Tabela;
            FSincronia.Registro.Registro  := FSincronia.Lista[I].Registro;
            FSincronia.Registro.LogResult := LcReceiveWeb.Retorno.Mensagem;
            FSincronia.saveReturn;
            case LcReceiveWeb.Retorno.ID of
              200:Begin
                    SetLastUpdate(FListaSincronia.registro.Tabela, FListaSincronia.registro.Tipo, 'R', FSincronia.Lista[I].Tempo);
                  end;
            end;
          End;
          updateMsgProcess(concat(FListaSincronia.registro.DescricaoProcesso, ' - ',
          intToStr(progresso.MaxValue), ' / ',
          intToStr(progresso.Progress + 1)), indice);
        End;
      Except
        on e: Exception do
        BEgin
          // Se der Errado a proxima sincronia ser� a partir desta data e hora - 10 segundo
          FSincronia.registro.LogResult := e.Message;
          FSincronia.saveReturn;
          // Se der certo a proxima sincronia ser� a partir desta data e hora + 01 segundo
          SetLastUpdate(FListaSincronia.registro.Tabela, FListaSincronia.registro.Tipo, 'E', FSincronia.Lista[I].Tempo - StrToTime('00:01:00'));
        End;
      end;
      // D-SY13: chave recusada - nenhum outro registro e tentado
      if FChaveRecusada then Break;
    End;
  finally
    LcReceiveWeb.Destroy;
  end;
end;

// Nota: o corpo estava nomeado "Receive" sem declaracao correspondente na
// classe (que declara "send") - corrigido para compilar.
procedure TreceiveFromWebServer.send;
Var
  I: Integer;
begin
  for I := 0 to FListaSincronia.ListaReceber.count - 1 do
  Begin
    if PararSolicitado then Break; // parada graciosa entre tabelas
    if FChaveRecusada then Break;  // D-SY13: chave recusada - para o ciclo
    FListaSincronia.ClonarObj(FListaSincronia.ListaReceber[I],FListaSincronia.registro);
    if FListaSincronia.registro.ativo = 'S' then
    Begin
      SyncTable(I)
    End;
  End;
end;

constructor TreceiveFromWebServer.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TreceiveFromWebServer.Destroy;
begin
  inherited;
end;


procedure TreceiveFromWebServer.inicializa;
begin
  inherited;
end;

procedure TreceiveFromWebServer.Execute;
begin
  FChaveRecusada := False;
  // D-SY13: sincronia inativa = nada a receber
  if SincroniaInativa then Exit;
  if ValidaConexao then
  Begin
    PreparaListBox;
    send;
  End;
end;

end.
