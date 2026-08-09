unit invoice_merchandise_sale_send_web;


interface

uses System.SysUtils, System.JSON, invoice_merchandise_send_web, un_dm;

Type
  // Rodada 2 — Sincronia por PROCESSO (D8-D11 de prompt_notas_mercadoria_
  // servico.md): processo de VENDA de mercadoria — Seq 22 NOTA_VENDA ->
  // /order-sale/sincronize. Dispara pela NOTA (TB_NOTA_FISCAL e o unico
  // fato gerador — D8) com INNER JOIN TB_PEDIDO PED_TIPO=1; envia o
  // payload COMPLETO (order + sale + items PRO_TIPO<>'S' + totalizer +
  // billing + user + invoice{...merchandise}). Substitui a
  // TOrderSaleSendWeb aposentada (payload do pedido absorvido dela).
  // D13 (Rodada 3): so venda PURA — nota COM item de servico e da
  // TInvoiceServiceSendWeb (Seq 21), que envia a ordem conjugada INTEIRA;
  // aqui o filtro disjunto exclui (skip sem marca no SRC_LOG).
  TInvoiceMerchandiseSaleSendWeb = class(TInvoiceMerchandiseSendWeb)
    protected
      function PedTipo: Integer; override;
      function FiltroDisjuntoOk: Boolean; override;
      procedure AddRamoPedido(AJson: TJSONObject); override;
  end;

implementation

{ TInvoiceMerchandiseSaleSendWeb }

function TInvoiceMerchandiseSaleSendWeb.PedTipo: Integer;
begin
  Result := 1; // PED_TIPO=1 Vendas
end;

function TInvoiceMerchandiseSaleSendWeb.FiltroDisjuntoOk: Boolean;
begin
  // D13: venda PURA = nota SEM item de servico (NOT VerificaServico) —
  // espelho do NOT EXISTS do catch-up (SqlItemServico/NOTA_VENDA).
  Result := not FCtrl.VerificaServico;
end;

procedure TInvoiceMerchandiseSaleSendWeb.AddRamoPedido(AJson: TJSONObject);
Var
  LcSale        : TJSONObject;
  LcCustomerDoc : String;
  LcSalesmanDoc : String;
begin
  // Achado transversal: CustomerExternalCode/SalesmanExternalCode do Obj
  // legado carregam o CODIGO INTERNO (emp_codigo), não o documento.
  LcCustomerDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Empresa);
  LcSalesmanDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Vendedor);

  LcSale := TJSONObject.Create;
  LcSale.AddPair('number', TJSONNumber.Create(FCtrl.Pedido.Registro.Numero));
  if LcCustomerDoc <> '' then
    LcSale.AddPair('customerDocument', LcCustomerDoc);
  if LcSalesmanDoc <> '' then
    LcSale.AddPair('salesmanDocument', LcSalesmanDoc);
  AJson.AddPair('sale', LcSale);
end;


end.
