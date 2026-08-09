unit invoice_merchandise_adjust_send_web;


interface

uses System.SysUtils, System.JSON, invoice_merchandise_send_web, un_dm;

Type
  // Rodada 2 — Sincronia por PROCESSO (D8-D11 de prompt_notas_mercadoria_
  // servico.md): processo de AJUSTE DE ESTOQUE — Seq 24 NOTA_AJUSTE ->
  // /order-stock-adjust/sincronize. INNER JOIN TB_PEDIDO PED_TIPO=3;
  // payload (order + adjust + items + user + invoice{...merchandise}) —
  // ajuste nao leva totalizer, billing nem listas de item. Substitui a
  // TOrderStockAdjustSendWeb aposentada.
  TInvoiceMerchandiseAdjustSendWeb = class(TInvoiceMerchandiseSendWeb)
    protected
      function PedTipo: Integer; override;
      function UsaListasDeItem: Boolean; override;
      function UsaTotalizer: Boolean; override;
      function UsaBilling: Boolean; override;
      procedure AddRamoPedido(AJson: TJSONObject); override;
  end;

implementation

{ TInvoiceMerchandiseAdjustSendWeb }

function TInvoiceMerchandiseAdjustSendWeb.PedTipo: Integer;
begin
  Result := 3; // PED_TIPO=3 Ajustes
end;

function TInvoiceMerchandiseAdjustSendWeb.UsaListasDeItem: Boolean;
begin
  Result := False;
end;

function TInvoiceMerchandiseAdjustSendWeb.UsaTotalizer: Boolean;
begin
  Result := False;
end;

function TInvoiceMerchandiseAdjustSendWeb.UsaBilling: Boolean;
begin
  Result := False;
end;

procedure TInvoiceMerchandiseAdjustSendWeb.AddRamoPedido(AJson: TJSONObject);
Var
  LcAdjust    : TJSONObject;
  LcEntityDoc : String;
  LcDirection : String;
begin
  // Achado transversal: EntityExternalCode do Obj legado carrega o
  // CODIGO INTERNO (emp_codigo), não o documento. Campo opcional no
  // contrato — omitido quando o lookup não encontra documento.
  LcEntityDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Empresa);

  // Sentido do ajuste (Valdo, 2026-08-09): a 1a letra do NFL_TIPO da
  // propria nota ja da o sentido — 'EI'/'EX' (Entrada Interna/Externa) ou
  // 'SI'/'SE' (Saida Interna/Externa). Resolve o TODO da Rodada 4 sem
  // precisar de DDL nova.
  LcDirection := Copy(FCtrl.Registro.Tipo, 1, 1);

  LcAdjust := TJSONObject.Create;
  LcAdjust.AddPair('number', TJSONNumber.Create(FCtrl.Pedido.Registro.Numero));
  if LcEntityDoc <> '' then
    LcAdjust.AddPair('entityDocument', LcEntityDoc);
  LcAdjust.AddPair('direction', LcDirection);
  AJson.AddPair('adjust', LcAdjust);
end;


end.
