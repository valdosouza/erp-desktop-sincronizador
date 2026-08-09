unit invoice_merchandise_purchase_send_web;


interface

uses System.SysUtils, System.JSON, invoice_merchandise_send_web, un_dm;

Type
  // Rodada 2 — Sincronia por PROCESSO (D8-D11 de prompt_notas_mercadoria_
  // servico.md): processo de COMPRA — Seq 23 NOTA_COMPRA ->
  // /order-purchase/sincronize. INNER JOIN TB_PEDIDO PED_TIPO=2; payload
  // COMPLETO (order + purchase + items + totalizer + user + invoice
  // {...merchandise}) — compra nao leva billing nem listas de item.
  // issuer='N' fixo: a nota de compra e emitida pelo FORNECEDOR e o
  // entityDocument da base (NFL_CODEMP) ja e o documento dele. Substitui
  // a TOrderPurchaseSendWeb aposentada.
  TInvoiceMerchandisePurchaseSendWeb = class(TInvoiceMerchandiseSendWeb)
    protected
      function PedTipo: Integer; override;
      function IssuerFlag: String; override;
      function UsaListasDeItem: Boolean; override;
      function UsaBilling: Boolean; override;
      procedure AddRamoPedido(AJson: TJSONObject); override;
  end;

implementation

{ TInvoiceMerchandisePurchaseSendWeb }

function TInvoiceMerchandisePurchaseSendWeb.PedTipo: Integer;
begin
  Result := 2; // PED_TIPO=2 Compras
end;

function TInvoiceMerchandisePurchaseSendWeb.IssuerFlag: String;
begin
  // Compra: quem emite e o fornecedor (a institution e destinataria) —
  // sobrescreve a regra EE/EM da base, que marcaria 'S' na entrada externa.
  Result := 'N';
end;

function TInvoiceMerchandisePurchaseSendWeb.UsaListasDeItem: Boolean;
begin
  Result := False;
end;

function TInvoiceMerchandisePurchaseSendWeb.UsaBilling: Boolean;
begin
  Result := False;
end;

procedure TInvoiceMerchandisePurchaseSendWeb.AddRamoPedido(AJson: TJSONObject);
Var
  LcPurchase    : TJSONObject;
  LcProviderDoc : String;
begin
  // Achado transversal: ProviderExternalCode do Obj legado carrega o
  // CODIGO INTERNO do fornecedor (emp_codigo), não o documento.
  LcProviderDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Empresa);

  LcPurchase := TJSONObject.Create;
  LcPurchase.AddPair('number', TJSONNumber.Create(FCtrl.Pedido.Registro.Numero));
  if LcProviderDoc <> '' then
    LcPurchase.AddPair('providerDocument', LcProviderDoc);
  LcPurchase.AddPair('approved', FCtrl.Pedido.Registro.Aprovado);
  AJson.AddPair('purchase', LcPurchase);
end;


end.
