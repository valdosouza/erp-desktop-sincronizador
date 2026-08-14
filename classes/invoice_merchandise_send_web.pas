unit invoice_merchandise_send_web;


interface

uses System.SysUtils, System.JSON, general_web, invoice_send_web,
     ControllerNotaFiscal, ObjInvoiceMerchandise, un_dm;

Type
  // Rodada 2 — Sincronia por PROCESSO (D8-D11 de prompt_notas_mercadoria_
  // servico.md): esta classe virou a INTERMEDIARIA da hierarquia — NAO tem
  // linha no catalogo (Seq 21 NOTA_MERCADORIA morreu) e NAO se registra no
  // uMain. Ela monta o PROCESSO COMPLETO de mercadoria (D9: pedido + nota
  // + ramo numa transacao unica na web, matando o 409 ORDER_NOT_SYNCED por
  // construcao): raiz {id=NFL_CODIGO, terminal, deleted} + order + ramo do
  // pedido (sale/purchase/adjust — filhas) + items PRO_TIPO<>'S' +
  // totalizer/billing/user + bloco `invoice` {base + merchandise}.
  //
  // As filhas so variam o PED_TIPO (WHERE do getSincronia), o bloco do
  // ramo e quais blocos opcionais viajam (D11: "os irmaos so variam o
  // WHERE e o endpoint" — o endpoint vem do catalogo TB_LISTA_SINCRONIA).
  //
  // Avaliacao do "objeto completo" legado (D9): TInvoiceDetachedSendWeb /
  // FillDataObjetoDetached NAO serializam o processo inteiro — o Detached
  // preenche so o bloco Nota (com resolucao de CFOP) + observacoes, e e
  // exatamente ESSA parte que continua reaproveitada aqui (via
  // AddInvoiceBaseFields da base). O restante (pedido/itens/totalizer/
  // billing/user) foi ABSORVIDO das TOrder*SendWeb aposentadas, montado
  // direto dos models (motivo do patch 06 mantido: o model de destino
  // tblinvoiceMerchandise tem typo no getter de ValorIcmsSt).
  TInvoiceMerchandiseSendWeb = class(TInvoiceSendWeb)
    protected
      // PED_TIPO do processo (1 venda / 2 compra / 3 ajuste) — filtra o
      // INNER JOIN TB_PEDIDO do getSincronia (irmao errado nem enxerga).
      function PedTipo: Integer; virtual; abstract;
      // Bloco do ramo do pedido: sale / purchase / adjust.
      procedure AddRamoPedido(AJson: TJSONObject); virtual; abstract;
      // Venda leva stockListId/priceListId nos itens; compra/ajuste nao.
      function UsaListasDeItem: Boolean; virtual;
      // Ajuste nao leva totalizer; compra/ajuste nao levam billing.
      function UsaTotalizer: Boolean; virtual;
      function UsaBilling: Boolean; virtual;
      // D13 (Rodada 3): filtro DISJUNTO do processo — a VENDA exclui nota
      // com item de servico (a conjugada viaja INTEIRA pela
      // TInvoiceServiceSendWeb/Seq 21). Compra/ajuste nao tem item 'S'
      // por natureza (default True).
      function FiltroDisjuntoOk: Boolean; virtual;
      // Bloco `invoice` = campos base do /invoice + sub-bloco merchandise.
      procedure AddInvoiceBlock(AJson: TJSONObject);
      procedure GenerateJson;Override;
  end;

implementation

{ TInvoiceMerchandiseSendWeb }

function TInvoiceMerchandiseSendWeb.UsaListasDeItem: Boolean;
begin
  Result := True;
end;

function TInvoiceMerchandiseSendWeb.UsaTotalizer: Boolean;
begin
  Result := True;
end;

function TInvoiceMerchandiseSendWeb.UsaBilling: Boolean;
begin
  Result := True;
end;

function TInvoiceMerchandiseSendWeb.FiltroDisjuntoOk: Boolean;
begin
  Result := True; // compra/ajuste: PED_TIPO ja resolve (sem item 'S')
end;

procedure TInvoiceMerchandiseSendWeb.AddInvoiceBlock(AJson: TJSONObject);
Var
  LcInvoice : TJSONObject;
begin
  // D10: bloco `invoice` = campos do /invoice SEM id/terminal/deleted
  // (a web grava pedido+nota+ramo na MESMA transacao). O sub-bloco
  // merchandise vive na BASE (AddMerchandiseRamo) — a conjugada (D13)
  // tambem o usa.
  LcInvoice := TJSONObject.Create;
  AddInvoiceBaseFields(LcInvoice);
  AddMerchandiseRamo(LcInvoice);
  AJson.AddPair('invoice', LcInvoice);
end;

procedure TInvoiceMerchandiseSendWeb.GenerateJson;
Var
  LcJson : TJSONObject;
begin
  // NAO chama o GenerateJson da avulsa (herdado) — o processo monta o
  // proprio payload. D13: todos os exits de filtro abaixo marcam FSkip
  // ("nao e meu registro") — o motor NAO grava SRC_LOG e o registro
  // segue pendente para as demais classes do ciclo.
  FStrJson := '';
  FCtrl.NotaAvulsa := False;
  // D11: os irmaos so variam o WHERE — INNER JOIN TB_PEDIDO + PED_TIPO
  FCtrl.TipoPedido := PedTipo;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getSincronia;
  if not FCtrl.exist then
  Begin
    FSkip := True;
    Exit;
  End;

  // D13: filtro DISJUNTO — a venda exclui nota com item de servico
  // (a conjugada viaja INTEIRA pela TInvoiceServiceSendWeb/Seq 21).
  if not FiltroDisjuntoOk then
  Begin
    FSkip := True;
    Exit;
  End;

  // Notas Mercadoria x Servico (D3): so envia quando a nota TEM parte
  // mercadoria — valor de produtos OU item PRO_TIPO <> 'S'.
  if (FCtrl.Registro.ValorProdutos <= 0) and (not FCtrl.VerificaProduto) then
  Begin
    FSkip := True;
    Exit;
  End;

  // Seguranca: processo exige o pedido conjugado (getSincronia ja faz o
  // INNER JOIN, este e so um cinto extra antes do fill). Sem pedido,
  // nenhuma classe de processo reivindica — orfao sai pela limpeza de 48h.
  if FCtrl.Registro.CodigoPedido <= 0 then
  Begin
    FSkip := True;
    Exit;
  End;

  FCtrl.ClearDataObjecto;
  FCtrl.ObjInvoice.Estabelecimento := FInstitutionDestino;
  FCtrl.ObjInvoice.Terminal := FTerminal;
  // Carrega Nota (com resolucao de CFOP) + Pedido (Pedido.getbyId) —
  // mesma rotina reaproveitada da avulsa.
  FCtrl.FillDataObjetoDetached(FCtrl.Registro);
  // Itens de MERCADORIA (PRO_TIPO <> 'S'); total guardado p/ totalizer.
  CarregaItens(False);

  LcJson := TJSONObject.Create;
  Try
    // D1: id do processo = NFL_CODIGO (tb_order.id = tb_invoice.id)
    LcJson.AddPair('id', TJSONNumber.Create(FCtrl.Registro.Codigo));
    LcJson.AddPair('terminal', TJSONNumber.Create(FTerminal));
    // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
    LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

    AddOrderBlock(LcJson);
    AddRamoPedido(LcJson);
    AddItemsBlock(LcJson, UsaListasDeItem);
    if UsaTotalizer then
      AddTotalizerBlock(LcJson);
    if UsaBilling then
      AddBillingBlock(LcJson);
    AddUserBlock(LcJson);
    AddInvoiceBlock(LcJson);

    FStrJson := LcJson.ToJSON;
  Finally
    LcJson.Free;
  End;
end;


end.
