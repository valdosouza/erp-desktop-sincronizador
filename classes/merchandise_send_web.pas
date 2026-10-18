unit merchandise_send_web;

interface

uses System.SysUtils,general_web,REST.Json, ControllerProduto,ObjMerchandise,
     System.JSON, ControllerMarcaProduto, ControllerEmbalagem, ControllerMedida;

Type
  TMerchandiseSendWeb = class(TGeneralWeb)
    private
      FCtrl: TControllerProduto;
      // Nomes por descrição (D5 do guia de revisão): TMerchandise/TStock
      // (destiny/model) não têm mais name_brand/name_package/name_measure
      // (não são colunas reais) — a resolução mora aqui, não no controller.
      function GetBrandName(pCodigo: Integer): String;
      function GetPackageName(pCodigo: Integer): String;
      // D-SY10 (Valdo, 2026-10-18): a medida e unica na setes_central e a
      // CHAVE e a ABREVIACAO (mesma sistematica do setes-api) - vai a
      // abreviacao (measureAbbreviation) e a descricao (nameMeasure, atributo
      // da criacao na web; executavel antigo so mandava a descricao).
      procedure GetMeasure(pCodigo: Integer; out pAbreviatura, pDescricao: String);
      // D-SY5 / D-SY6 (Valdo, 2026-10-17)
      function NormalizeIndEscala(const pValue: String): String;
      function DecodeAplicacao(const pValue: String): String;
    protected
      procedure GenerateJson;Override;
    public
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation

uses un_dm, synacode;

{ TGeneralWeb }

function TMerchandiseSendWeb.GetBrandName(pCodigo: Integer): String;
Var
  LcCtrl: TControllerMarcaProduto;
begin
  Result := 'N�O INFORMADA';
  LcCtrl := TControllerMarcaProduto.Create(nil);
  Try
    LcCtrl.Registro.Codigo := pCodigo;
    LcCtrl.getbyId;
    if LcCtrl.exist then
      Result := LcCtrl.Registro.Descricao;
  Finally
    LcCtrl.DisposeOf;
  End;
end;

function TMerchandiseSendWeb.GetPackageName(pCodigo: Integer): String;
Var
  LcCtrl: TControllerEmbalagem;
begin
  Result := 'UND';
  LcCtrl := TControllerEmbalagem.Create(nil);
  Try
    LcCtrl.Registro.Codigo := pCodigo;
    LcCtrl.getbyId;
    if LcCtrl.exist then
      Result := LcCtrl.Registro.Descricao;
  Finally
    LcCtrl.DisposeOf;
  End;
end;

procedure TMerchandiseSendWeb.GetMeasure(pCodigo: Integer; out pAbreviatura, pDescricao: String);
Var
  LcCtrl: TControllerMedida;
begin
  // Medida inexistente no Firebird: ABREVIACAO 'UND' (D-SY10 - antes o 'UND'
  // ia como DESCRICAO e a web criava uma 2a linha 'UND' sem abreviacao ao
  // lado da UNIDADE/UND). Descricao vazia: a web reusa a linha da abreviacao
  // e, se ela nao existir na central, cria com a propria abreviacao como
  // descricao.
  // Medida com MED_ABREVIATURA vazia: abreviacao '' -> a web resolve pela
  // descricao, como antes (com aviso no log do setes-sync).
  pAbreviatura := 'UND';
  pDescricao   := '';
  LcCtrl := TControllerMedida.Create(nil);
  Try
    LcCtrl.Registro.Codigo := pCodigo;
    LcCtrl.getbyId;
    if LcCtrl.exist then
    Begin
      pAbreviatura := Trim(LcCtrl.Registro.Abreviatura);
      pDescricao   := Trim(LcCtrl.Registro.Descricao);
    End;
  Finally
    LcCtrl.DisposeOf;
  End;
end;

function TMerchandiseSendWeb.NormalizeIndEscala(const pValue: String): String;
begin
  // D-SY5 (Valdo, 2026-10-17): INDESCALA do Firebird COMO ESTA (S/N) - antes
  // ia 'N' fixo. Vazio ou fora de S/N vai '' = ausente -> NULL na web: o
  // legado omite a tag indEscala da NF-e quando o campo esta vazio
  // (StrToIndEscala do ACBr em un_geranfe3X.pas). Nunca manda valor fora de
  // S/N (o setes-sync recusaria o produto inteiro com 400).
  Result := UpperCase(Trim(pValue));
  if (Result <> 'S') and (Result <> 'N') then
    Result := '';
end;

function TMerchandiseSendWeb.DecodeAplicacao(const pValue: String): String;
Var
  LcRaw, LcDecoded: String;
  I, LcLen: Integer;
begin
  // D-SY6 (Valdo, 2026-10-17): o legado grava PRO_APLICACAO em Base64
  // (Un_Produtos.pas: EncodeBase64(AnsiString(texto)), synacode) e le com
  // String(DecodeBase64(AnsiString(valor))). A web recebe o TEXTO: decodifica
  // aqui do MESMO jeito do legado (pagina de codigo ANSI da maquina; o JSON
  // sai em Unicode). Tolerancia: valor sem forma de Base64, ou que
  // decodificado traz caractere de controle (fora TAB/CR/LF), segue como esta.
  Result := pValue;
  LcRaw := Trim(pValue);
  LcLen := Length(LcRaw);
  if (LcLen = 0) or ((LcLen mod 4) <> 0) then
    Exit;
  for I := 1 to LcLen do
  Begin
    if not CharInSet(LcRaw[I], ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '=']) then
      Exit;
    // '=' so no fim (padding de 1 ou 2 caracteres)
    if (LcRaw[I] = '=') and (I < LcLen - 1) then
      Exit;
  End;
  if (LcRaw[LcLen - 1] = '=') and (LcRaw[LcLen] <> '=') then
    Exit;
  LcDecoded := String(DecodeBase64(AnsiString(LcRaw)));
  for I := 1 to Length(LcDecoded) do
    if (Ord(LcDecoded[I]) < 32) and not CharInSet(LcDecoded[I], [#9, #10, #13]) then
      Exit;
  Result := LcDecoded;
end;

constructor TMerchandiseSendWeb.Create;
begin
  inherited;
  FCtrl := TControllerProduto.Create(nil);
end;

destructor TMerchandiseSendWeb.Destroy;
begin
  FreeAndNil(FCtrl);
  inherited;
end;

procedure TMerchandiseSendWeb.GenerateJson;
Var
  LcJson,
  LcProduct,
  LcMerchandise,
  LcStock: TJSONObject;
  LcMedAbrev,
  LcMedDesc: String;
begin
  inherited;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getbyId;
  if FCtrl.exist then
  Begin
    // Notas Mercadoria x Servico (D2): esta classe cobre SOMENTE PRO_TIPO
    // 'P'/'M' — 'S' viaja pela TServiceSendWeb (Seq 40) e 'A' (cardapio,
    // restaurante APOSENTADO) nao sincroniza. D13: skip = FSkip ("nao e
    // meu registro") — o motor NAO grava SRC_LOG e o registro fica para a
    // classe irma ('A' nao e de ninguem: sai pela limpeza de 48h).
    if (FCtrl.Registro.Tipo <> 'P') and (FCtrl.Registro.Tipo <> 'M') then
    Begin
      FSkip := True;
      Exit;
    End;

    // FillDataObjects preenche product/merchandise/stock (campos reais das
    // tabelas); marca/embalagem/medida são resolvidas por descrição AQUI
    // (GetBrandName/GetPackageName/GetMeasureName), pois TMerchandise/TStock
    // não têm mais name_brand/name_package/name_measure. LcObj morto
    // (criado e nunca usado) foi REMOVIDO.
    FCtrl.FillDataObjects(FCtrl.Registro, FCtrl.Obj, FInstitutionDestino);

    LcJson := TJSONObject.Create;
    try
      // Contrato /merchandise/sincronize: id = PRO_CODIGO ✅; tb_institution_id
      // NÃO viaja (D12) — resolvido pela API key no servidor.
      LcJson.AddPair('id', TJSONNumber.Create(FCtrl.Registro.Codigo));
      // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
      LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

      LcProduct := TJSONObject.Create;
      LcProduct.AddPair('description', FCtrl.Obj.Produto.Descricao);
      LcProduct.AddPair('categoryId', TJSONNumber.Create(FCtrl.Obj.Produto.Categoria));
      LcProduct.AddPair('identifier', FCtrl.Obj.Produto.Identificador);
      // D2: tb_product.kind espelha PRO_TIPO ('P'/'M' — 'S' nunca passa aqui)
      LcProduct.AddPair('kind', FCtrl.Registro.Tipo);
      // TODO: Firebird (TProduto) não grava centro de custo/plano financeiro
      // no produto ainda — financialPlansId fica NULL.
      LcProduct.AddPair('financialPlansId', TJSONNull.Create);
      LcProduct.AddPair('promotion', FCtrl.Obj.Produto.Promocao);
      LcProduct.AddPair('highlights', FCtrl.Obj.Produto.Destaque);
      LcProduct.AddPair('active', FCtrl.Obj.Produto.Ativo);
      LcProduct.AddPair('published', FCtrl.Obj.Produto.Publicado);
      LcProduct.AddPair('note', FCtrl.Obj.Produto.Observacao);
      LcJson.AddPair('product', LcProduct);

      LcMerchandise := TJSONObject.Create;
      LcMerchandise.AddPair('nameBrand', GetBrandName(FCtrl.Registro.CodigoMarca));
      LcMerchandise.AddPair('internalId', FCtrl.Obj.Mercadoria.CodigoInterno);
      LcMerchandise.AddPair('ncm', FCtrl.Obj.Mercadoria.NCM);
      LcMerchandise.AddPair('cest', FCtrl.Obj.Mercadoria.CEST);
      LcMerchandise.AddPair('kindTributary', FCtrl.Obj.Mercadoria.TipoTributacao);
      LcMerchandise.AddPair('source', FCtrl.Obj.Mercadoria.Origem);
      LcMerchandise.AddPair('kind', FCtrl.Obj.Mercadoria.Tipo);
      LcMerchandise.AddPair('print', FCtrl.Obj.Mercadoria.Imprime);
      LcMerchandise.AddPair('controlSeries', FCtrl.Obj.Mercadoria.ControlarSerie);
      LcMerchandise.AddPair('exclusiveDealer', FCtrl.Obj.Mercadoria.ExclusivoRevenda);
      // D-SY6: texto decodificado (no Firebird esta em Base64)
      LcMerchandise.AddPair('application', DecodeAplicacao(FCtrl.Obj.Mercadoria.Aplicacao));
      LcMerchandise.AddPair('composition', FCtrl.Obj.Mercadoria.TipoComposicao);
      // D-SY5: INDESCALA real (o model ja tinha o campo; o 'N' fixo saiu)
      LcMerchandise.AddPair('manufSignIndScale', NormalizeIndEscala(FCtrl.Registro.IndicacaoEscala));
      // Fornecedor/id_provider REMOVIDO do payload — contrato mantém NULL até a
      // Onda 4 do servidor (tb_merchandise.id_provider).
      LcJson.AddPair('merchandise', LcMerchandise);

      LcStock := TJSONObject.Create;
      LcStock.AddPair('namePackage', GetPackageName(FCtrl.Registro.CodigoEmbalagem));
      // D-SY10: a CHAVE da medida e a abreviacao; a descricao vai junto
      // (atributo da criacao na web; servidor antigo ainda le o nameMeasure)
      GetMeasure(FCtrl.Registro.MedidaComercial, LcMedAbrev, LcMedDesc);
      LcStock.AddPair('measureAbbreviation', LcMedAbrev);
      LcStock.AddPair('nameMeasure', LcMedDesc);
      LcStock.AddPair('codebar', FCtrl.Obj.Estoque.CodigoBarra);
      LcStock.AddPair('st', FCtrl.Obj.Estoque.TemST);
      LcStock.AddPair('divisor', TJSONNumber.Create(FCtrl.Obj.Estoque.Divisor));
      LcStock.AddPair('location', FCtrl.Obj.Estoque.Localizacao);
      LcStock.AddPair('weight', TJSONNumber.Create(FCtrl.Obj.Estoque.Peso));
      LcStock.AddPair('width', TJSONNumber.Create(FCtrl.Obj.Estoque.Largura));
      LcStock.AddPair('length', TJSONNumber.Create(FCtrl.Obj.Estoque.Comprimento));
      LcStock.AddPair('height', TJSONNumber.Create(FCtrl.Obj.Estoque.Altura));
      LcStock.AddPair('costManufactures', TJSONNumber.Create(FCtrl.Obj.Estoque.CustoFabrica));
      LcStock.AddPair('actualCost', TJSONNumber.Create(FCtrl.Obj.Estoque.CustoReal));
      LcStock.AddPair('costPrice', TJSONNumber.Create(FCtrl.Obj.Estoque.PrecoCusto));
      LcStock.AddPair('negative', FCtrl.Obj.Estoque.EstoqueNegativa);
      LcStock.AddPair('outline', FCtrl.Obj.Estoque.ForaDeLinha);
      // quantity/minimum NÃO viajam aqui — domínio do /stock-balance.
      LcJson.AddPair('stock', LcStock);

      FStrJson := LcJson.ToJSON;
    finally
      LcJson.Free;
    end;
  End;
end;


end.


