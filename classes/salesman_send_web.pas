unit salesman_send_web;

interface

uses System.SysUtils,general_web,REST.Json, ControllerColaborador, System.JSON,
     ControllerUf, ControllerCidade, ControllerEndereco;

Type
  TSalesManSendWeb = class(TGeneralWeb)
    private
      FCtrl: TControllerColaborador;
      function ValidaSendSalesman(): Boolean;
      // decisao 1 da revisao de entidades (2026-07-25): colaborador sem CPF
      // reenvia o UUID gravado em TB_COLABORADOR.EXTERNALCODE (bootstrap cria
      // a coluna) — mesmo ciclo do TB_EMPRESA nas classes customer/provider.
      function GetExternalCodeColaborador: String;
      function DateToIso(pData: TDate): String;
      function OnlyDigits(pTexto: String): String;
      // codigo da MINHA EMPRESA (TB_EMPRESA.EMP_TIPO = 0); 0 se nao houver
      function GetCodigoMinhaEmpresa: Integer;
    protected
      procedure GenerateJson;Override;
    public
    constructor Create;override;
    destructor Destroy;override;
    // decisao 1: write-back do externalCode na TB_COLABORADOR (nao TB_EMPRESA)
    function ExternalCodeTable: String; override;
    function ExternalCodeKeyField: String; override;
  end;

implementation

{ TGeneralWeb }

uses UnFunctions, un_dm, IBX.IBQuery;

function TSalesManSendWeb.ExternalCodeTable: String;
begin
  Result := 'TB_COLABORADOR';
end;

function TSalesManSendWeb.ExternalCodeKeyField: String;
begin
  Result := 'CLB_CODIGO';
end;

function TSalesManSendWeb.GetExternalCodeColaborador: String;
Var
  Lc_Qry : TIBQuery;
begin
  Result := '';
  Lc_Qry := FCtrl.GeraQuery;
  Try
    with Lc_Qry do
    Begin
      Active := False;
      Sql.Clear;
      Sql.Add('SELECT EXTERNALCODE FROM TB_COLABORADOR WHERE CLB_CODIGO = :CLB_CODIGO');
      ParamByName('CLB_CODIGO').AsInteger := FCodigo;
      Active := True;
      FetchAll;
      if (RecordCount > 0) then
        Result := Trim(FieldByName('EXTERNALCODE').AsString);
    end;
  Finally
    FCtrl.FinalizaQuery(Lc_Qry);
  End;
end;

constructor TSalesManSendWeb.Create;
begin
  inherited;
  FCtrl := TControllerColaborador.Create(nil);
end;

destructor TSalesManSendWeb.Destroy;
begin
  FCtrl.DisposeOf;
  inherited;
end;

function TSalesManSendWeb.GetCodigoMinhaEmpresa: Integer;
Var
  Lc_Qry : TIBQuery;
begin
  Result := 0;
  Lc_Qry := FCtrl.GeraQuery;
  Try
    with Lc_Qry do
    Begin
      Active := False;
      Sql.Clear;
      Sql.Add('SELECT FIRST 1 EMP_CODIGO FROM TB_EMPRESA ' +
              'WHERE (EMP_TIPO = 0) AND (COALESCE(DELETED, ''N'') <> ''S'') ' +
              'ORDER BY EMP_CODIGO');
      Active := True;
      if not Eof then
        Result := FieldByName('EMP_CODIGO').AsInteger;
    end;
  Finally
    FCtrl.FinalizaQuery(Lc_Qry);
  End;
end;

function TSalesManSendWeb.OnlyDigits(pTexto: String): String;
begin
  Result := unMaskField(Trim(pTexto));
end;

function TSalesManSendWeb.DateToIso(pData: TDate): String;
begin
  if pData <= 0 then
    Result := ''
  else
    Result := FormatDateTime('yyyy-mm-dd', pData);
end;

procedure TSalesManSendWeb.GenerateJson;
Var
  LcJson         : TJSONObject;
  LcEntity       : TJSONObject;
  LcCollaborator : TJSONObject;
  LcSalesman     : TJSONObject;
  LcAddresses    : TJSONArray;
  LcAddress      : TJSONObject;
  LcPhones       : TJSONArray;
  LcPhone        : TJSONObject;
  LcMailings     : TJSONArray;
  LcMailing      : TJSONObject;
  LcDoc          : String;
  LcPersonType   : String;
  LcExternalCode : String;
  LcUF           : TControllerUf;
  LcCidade       : TControllerCidade;
  LcCodigoEstado : Integer;
  LcCodigoCidade : Integer;
  LcCodigoPais   : Integer;
  LcEnd          : TControllerEndereco;
  LcEnderecoOk   : Boolean;
  LcKind, LcRua, LcNum, LcCompl, LcBairro, LcCep : String;
begin
  inherited;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getbyId;
  if FCtrl.exist then
  Begin
    if ValidaSendSalesman then
    Begin
      LcJson := TJSONObject.Create;
      Try
        LcDoc := OnlyDigits(FCtrl.Registro.CPFCNPJ);
        // decisao 2 da revisao de entidades: branco/INVALIDO -> 'N' (fluxo
        // externalCode); corrige tambem o bug antigo em que qualquer doc
        // fora de 11 digitos virava 'J' com CNPJ invalido (400 eterno)
        LcPersonType := DerivePersonType(LcDoc);

        LcEntity := TJSONObject.Create;
        LcEntity.AddPair('nameCompany', FCtrl.Registro.Nome);
        LcEntity.AddPair('nickTrade',   FCtrl.Registro.Nome);
        if DateToIso(FCtrl.Registro.NAscimento) <> '' then
          LcEntity.AddPair('aniversary', DateToIso(FCtrl.Registro.NAscimento))
        else
          LcEntity.AddPair('aniversary', TJSONNull.Create);
        LcJson.AddPair('entity', LcEntity);

        LcJson.AddPair('personType', LcPersonType);

        if LcPersonType = 'F' then
        Begin
          LcJson.AddPair('person', TJSONObject.Create
            .AddPair('cpf', LcDoc)
            .AddPair('rg', FCtrl.Registro.Identidade)
            .AddPair('birthday', DateToIso(FCtrl.Registro.NAscimento)));
        End
        else if LcPersonType = 'J' then
        Begin
          LcJson.AddPair('company', TJSONObject.Create
            .AddPair('cnpj', LcDoc)
            .AddPair('ie', FCtrl.Registro.Identidade)
            .AddPair('im', '')
            .AddPair('dtFoundation', DateToIso(FCtrl.Registro.NAscimento)));
        End;

        // externalCode — só quando já sincronizado antes (reenvio, D4);
        // decisao 1: TB_COLABORADOR.EXTERNALCODE (gap do TODO antigo fechado)
        LcExternalCode := GetExternalCodeColaborador;
        if LcExternalCode <> '' then
          LcJson.AddPair('externalCode', LcExternalCode);

        // addresses - endereco do COLABORADOR, quando COMPLETO (rua + UF + cidade
        // resolvidas). Colaborador sem cadastro completo usa o endereco da MINHA
        // EMPRESA (TB_EMPRESA.EMP_TIPO = 0): continua sendo uma ENTIDADE PROPRIA
        // (CPF ou externalCode), so o endereco e emprestado (Valdo, 2026-11-22).
        // Antes, so o CEP preenchido gerava endereco com rua vazia e estado/cidade
        // 0, e o servidor recusava o colaborador inteiro (400 bloco entity).
        LcRua          := Trim(FCtrl.Registro.Endereco);
        LcCodigoEstado := 0;
        LcCodigoCidade := 0;
        if LcRua <> '' then
        Begin
          Try
            LcUF := TControllerUf.Create(nil);
            LcCidade := TControllerCidade.Create(nil);
            LcCodigoEstado := LcUF.BuscaCodigo(FCtrl.Registro.Estado);
            LcCodigoCidade := LcCidade.Buscacodigo(0, FCtrl.Registro.Cidade, FCtrl.Registro.Estado);
          Finally
            FreeAndNil(LcUF);
            FreeAndNil(LcCidade);
          End;
        End;
        LcEnderecoOk := (LcRua <> '') and (LcCodigoEstado > 0) and (LcCodigoCidade > 0);
        LcKind := 'RESIDENCIAL';
        LcNum := '';
        LcCompl := '';
        LcBairro := FCtrl.Registro.Bairro;
        LcCep := OnlyDigits(FCtrl.Registro.Cep);
        LcCodigoPais := 1058;
        if not LcEnderecoOk then
        Begin
          LcEnd := TControllerEndereco.Create(nil);
          Try
            LcEnd.Registro.CodigoEmpresa := GetCodigoMinhaEmpresa;
            if LcEnd.Registro.CodigoEmpresa > 0 then
              LcEnd.getByEmpresa;
            LcEnderecoOk := (LcEnd.Registro.Codigo > 0) and
                            (Trim(LcEnd.Registro.Logradouro) <> '') and
                            (LcEnd.Registro.CodigoEstado > 0) and
                            (LcEnd.Registro.CodigoCidade > 0);
            if LcEnderecoOk then
            Begin
              LcKind         := 'COMERCIAL';
              LcRua          := Trim(LcEnd.Registro.Logradouro);
              LcNum          := LcEnd.Registro.NumeroPredial;
              LcCompl        := LcEnd.Registro.Complemento;
              LcBairro       := LcEnd.Registro.Bairro;
              LcCep          := OnlyDigits(LcEnd.Registro.Cep);
              LcCodigoEstado := LcEnd.Registro.CodigoEstado;
              LcCodigoCidade := LcEnd.Registro.CodigoCidade;
              if LcEnd.Registro.CodigoPais > 0 then
                LcCodigoPais := LcEnd.Registro.CodigoPais;
            End;
          Finally
            FreeAndNil(LcEnd);
          End;
        End;
        if LcEnderecoOk then
        Begin
          LcAddresses := TJSONArray.Create;
          LcAddress := TJSONObject.Create;
          LcAddress.AddPair('kind', LcKind);
          LcAddress.AddPair('street', LcRua);
          LcAddress.AddPair('nmbr', LcNum);
          LcAddress.AddPair('complement', LcCompl);
          LcAddress.AddPair('neighborhood', LcBairro);
          LcAddress.AddPair('zipCode', LcCep);
          LcAddress.AddPair('tbCountryId', TJSONNumber.Create(LcCodigoPais));
          LcAddress.AddPair('tbStateId', TJSONNumber.Create(LcCodigoEstado));
          LcAddress.AddPair('tbCityId', TJSONNumber.Create(LcCodigoCidade));
          LcAddress.AddPair('main', 'S');
          LcAddresses.Add(LcAddress);
          LcJson.AddPair('addresses', LcAddresses);
        End;

        // phones — bug C5 do legado: TControllerColaborador.FillDataObjeto
        // grava Registro.Fone nos dois kinds (Fone e Celular). Aqui cada
        // kind lê o campo correto.
        LcPhones := TJSONArray.Create;
        if Trim(FCtrl.Registro.Fone) <> '' then
        Begin
          LcPhone := TJSONObject.Create;
          LcPhone.AddPair('kind', 'FONE');
          LcPhone.AddPair('contact', TJSONNull.Create);
          LcPhone.AddPair('number', OnlyDigits(FCtrl.Registro.Fone));
          LcPhones.Add(LcPhone);
        End;
        if Trim(FCtrl.Registro.Celular) <> '' then
        Begin
          LcPhone := TJSONObject.Create;
          LcPhone.AddPair('kind', 'CELULAR');
          LcPhone.AddPair('contact', TJSONNull.Create);
          LcPhone.AddPair('number', OnlyDigits(FCtrl.Registro.Celular));
          LcPhones.Add(LcPhone);
        End;
        if LcPhones.Count > 0 then
          LcJson.AddPair('phones', LcPhones)
        else
          LcPhones.Free;

        // mailings — e-mail NÃO é mais obrigatório (contrato novo); apenas
        // entra na lista quando presente
        if Trim(FCtrl.Registro.email) <> '' then
        Begin
          LcMailings := TJSONArray.Create;
          LcMailing := TJSONObject.Create;
          LcMailing.AddPair('email', Trim(FCtrl.Registro.email));
          LcMailing.AddPair('groupId', TJSONNumber.Create(1));
          LcMailings.Add(LcMailing);
          LcJson.AddPair('mailings', LcMailings);
        End;

        // collaborator — grava SEMPRE (precedência Collaborator→Salesman)
        LcCollaborator := TJSONObject.Create;
        LcCollaborator.AddPair('active', 'S');
        if DateToIso(FCtrl.Registro.Admissao) <> '' then
          LcCollaborator.AddPair('dtAdmission', DateToIso(FCtrl.Registro.Admissao))
        else
          LcCollaborator.AddPair('dtAdmission', TJSONNull.Create);
        if DateToIso(FCtrl.Registro.Demissao) <> '' then
          LcCollaborator.AddPair('dtResignation', DateToIso(FCtrl.Registro.Demissao))
        else
          LcCollaborator.AddPair('dtResignation', TJSONNull.Create);
        LcCollaborator.AddPair('salary', TJSONNumber.Create(FCtrl.Registro.Salario));
        LcCollaborator.AddPair('fathersName', FCtrl.Registro.NomePai);
        LcCollaborator.AddPair('mothersName', FCtrl.Registro.NomeMae);
        LcCollaborator.AddPair('voteNumber', FCtrl.Registro.TituloEleitor);
        LcCollaborator.AddPair('voteZone', FCtrl.Registro.TituloZona);
        LcCollaborator.AddPair('voteSection', FCtrl.Registro.SecaoZona);
        LcCollaborator.AddPair('militaryCertificate', FCtrl.Registro.CertificadoMilitar);
        LcCollaborator.AddPair('pis', FCtrl.Registro.PIS);
        LcJson.AddPair('collaborator', LcCollaborator);

        // salesman — quando o colaborador também é vendedor (cargo comercial);
        // como o Firebird não tem uma flag direta "é vendedor" nesta classe,
        // envia sempre junto com collaborator (precedência D13 é decidida
        // no servidor pela presença do bloco)
        LcSalesman := TJSONObject.Create;
        LcSalesman.AddPair('active', 'S');
        LcSalesman.AddPair('aliqKickback', TJSONNumber.Create(FCtrl.Registro.ComissaoAliqVenda));
        LcSalesman.AddPair('kickbackProduct', FCtrl.Registro.ComissaoPorProduto);
        // TODO: não há campo Firebird equivalente a flexValue — enviado 0
        LcSalesman.AddPair('flexValue', TJSONNumber.Create(0));
        LcJson.AddPair('salesman', LcSalesman);

        // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
        LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

        FStrJSon := LcJson.ToJSON;
      Finally
        LcJson.Free;
      End;
    End;
  End;
 end;

function TSalesManSendWeb.ValidaSendSalesman: Boolean;
begin
  // D15/D22: e-mail deixou de ser obrigatório para sincronizar o colaborador
  // (o legado descartava quem não tivesse e-mail — trava removida aqui).
  Result := True;
end;

end.
