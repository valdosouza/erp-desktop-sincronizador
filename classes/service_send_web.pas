unit service_send_web;

interface

uses System.SysUtils,general_web,REST.Json, ControllerProduto,ObjMerchandise,
     System.JSON;

Type
  // Notas Mercadoria x Servico (D2 de prompt_notas_mercadoria_servico.md):
  // produto com PRO_TIPO='S' vira SO tb_product (kind='S') na web — molde
  // merchandise_send_web SEM os blocos merchandise/stock e SEM os catalogos
  // de marca/embalagem/medida (servico nao tem estoque nem embalagem).
  TServiceSendWeb = class(TGeneralWeb)
    private
      FCtrl: TControllerProduto;
    protected
      procedure GenerateJson;Override;
    public
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation

uses un_dm;

{ TServiceSendWeb }

constructor TServiceSendWeb.Create;
begin
  inherited;
  FCtrl := TControllerProduto.Create(nil);
end;

destructor TServiceSendWeb.Destroy;
begin
  FreeAndNil(FCtrl);
  inherited;
end;

procedure TServiceSendWeb.GenerateJson;
Var
  LcJson,
  LcProduct: TJSONObject;
begin
  inherited;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getbyId;
  if FCtrl.exist then
  Begin
    // D2: so PRO_TIPO='S' viaja por aqui — 'P'/'M' vao pela
    // TMerchandiseSendWeb (Seq 5) e 'A' (cardapio) esta APOSENTADO.
    // D13: skip = FSkip ("nao e meu registro") — o motor NAO grava
    // SRC_LOG e o registro fica para a classe irma.
    if FCtrl.Registro.Tipo <> 'S' then
    Begin
      FSkip := True;
      Exit;
    End;

    // Reaproveita o FillDataObjects do produto (bloco Produto do Obj);
    // os blocos Mercadoria/Estoque tambem sao preenchidos mas NAO viajam.
    FCtrl.FillDataObjects(FCtrl.Registro, FCtrl.Obj, FInstitutionDestino);

    LcJson := TJSONObject.Create;
    try
      // Contrato /service/sincronize: id = PRO_CODIGO ✅; tb_institution_id
      // NÃO viaja (D12) — resolvido pela API key no servidor. O kind='S'
      // e definido pelo proprio endpoint na web.
      LcJson.AddPair('id', TJSONNumber.Create(FCtrl.Registro.Codigo));
      // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
      LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

      LcProduct := TJSONObject.Create;
      LcProduct.AddPair('description', FCtrl.Obj.Produto.Descricao);
      LcProduct.AddPair('categoryId', TJSONNumber.Create(FCtrl.Obj.Produto.Categoria));
      LcProduct.AddPair('identifier', FCtrl.Obj.Produto.Identificador);
      LcProduct.AddPair('promotion', FCtrl.Obj.Produto.Promocao);
      LcProduct.AddPair('highlights', FCtrl.Obj.Produto.Destaque);
      LcProduct.AddPair('active', FCtrl.Obj.Produto.Ativo);
      LcProduct.AddPair('published', FCtrl.Obj.Produto.Publicado);
      LcProduct.AddPair('note', FCtrl.Obj.Produto.Observacao);
      LcJson.AddPair('product', LcProduct);

      FStrJson := LcJson.ToJSON;
    finally
      LcJson.Free;
    end;
  End;
end;


end.
