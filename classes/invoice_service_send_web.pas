unit invoice_service_send_web;


interface

uses System.SysUtils, System.JSON, general_web, invoice_send_web,
     ControllerNotaFiscal, ObjInvoiceMerchandise, un_dm;

Type
  // Rodada 2 (D8-D11) + Rodada 3 (D13) de prompt_notas_mercadoria_servico.md:
  // PROCESSO COMPLETO de servico — Seq 21 NOTA_SERVICO ->
  // /order-service/sincronize. Herda da AVULSA (D11).
  //
  // D13: reivindica a nota PED_TIPO=1 que TEM item de servico
  // (VerificaServico — espelho do EXISTS do catch-up) e envia a ORDEM DE
  // SERVICO COMPLETA: na conjugada os itens de MERCADORIA viajam JUNTO
  // (blocos sale{number, salesmanDocument} + saleItems com stockListId/
  // priceListId, espelhos dos do /order-sale) e o bloco invoice leva os
  // DOIS ramos (service + merchandise). A venda PURA (sem item de servico)
  // e da TInvoiceMerchandiseSaleSendWeb (Seq 22) — filtros DISJUNTOS,
  // marca UNICA no SRC_LOG so de quem envia (patch 08).
  //
  // Payload: raiz {id=NFL_CODIGO, terminal, deleted} + order +
  // service{number, customerDocument} + items PRO_TIPO='S' (sem listas)
  // [+ sale + saleItems quando ha parte mercadoria] + totalizer + billing
  // + user + invoice{base + service{totalValue=NFL_VL_TL_SRV}
  // [+ merchandise{...} quando ha parte mercadoria]}.
  TInvoiceServiceSendWeb = class(TInvoiceSendWeb)
    protected
      procedure GenerateJson;Override;
  end;

implementation

{ TInvoiceServiceSendWeb }

procedure TInvoiceServiceSendWeb.GenerateJson;
Var
  LcJson    : TJSONObject;
  LcService : TJSONObject;
  LcSale    : TJSONObject;
  LcInvoice : TJSONObject;
  LcRamoSrv : TJSONObject;
  LcCustomerDoc   : String;
  LcSalesmanDoc   : String;
  LcNfsNumero     : String;
  LcTemMercadoria : Boolean;
begin
  // NAO chama o GenerateJson da avulsa — o processo monta o proprio
  // payload. D13: exits de filtro marcam FSkip ("nao e meu registro") —
  // o motor NAO grava SRC_LOG e o registro segue para as demais classes.
  FStrJson := '';
  FCtrl.NotaAvulsa := False;
  // Dominio do legado (spec): pedido de servico E PED_TIPO=1 — o join do
  // getSincronia filtra; compra/ajuste nunca viram processo de servico.
  FCtrl.TipoPedido := 1;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getSincronia;
  if not FCtrl.exist then
  Begin
    FSkip := True;
    Exit;
  End;

  // D13: filtro DISJUNTO — esta classe reivindica a nota COM item de
  // servico (VerificaServico, espelho do EXISTS do catch-up). Nota
  // so-mercadoria e da TInvoiceMerchandiseSaleSendWeb (Seq 22).
  if not FCtrl.VerificaServico then
  Begin
    FSkip := True;
    Exit;
  End;

  // Seguranca: processo exige o pedido conjugado. Sem pedido, nenhuma
  // classe de processo reivindica — orfao sai pela limpeza de 48h.
  if FCtrl.Registro.CodigoPedido <= 0 then
  Begin
    FSkip := True;
    Exit;
  End;

  FCtrl.ClearDataObjecto;
  FCtrl.ObjInvoice.Estabelecimento := FInstitutionDestino;
  FCtrl.ObjInvoice.Terminal := FTerminal;
  // Carrega Nota (com resolucao de CFOP) + Pedido — rotina da avulsa.
  FCtrl.FillDataObjetoDetached(FCtrl.Registro);

  // Decisao Valdo 2026-08-01/02: NFL_NUMERO e numero de nota de MERCADORIA —
  // para servico e SEMPRE vazio. O numero da NFS-e vem DIRETO do retorno
  // (TB_RETORNO_NFS.NFS_NUMERO via NFS_CODNFL, semantica de LEFT JOIN):
  // achou = usa; sem retorno = number segue em branco e a web grava NULL
  // (o reenvio pos-autorizacao atualiza). Na CONJUGADA, um NFL_NUMERO
  // preenchido (NF-e da parte mercadoria) e preservado quando nao ha
  // retorno de NFS-e.
  LcNfsNumero := DM.GetNfsNumero(FCtrl.Registro.Codigo);
  if LcNfsNumero <> '' then
    FCtrl.ObjInvoice.Nota.Numero := LcNfsNumero;

  // D13: a conjugada leva TAMBEM a parte mercadoria — mesmo criterio da
  // intermediaria (valor de produtos OU item PRO_TIPO <> 'S').
  LcTemMercadoria := (FCtrl.Registro.ValorProdutos > 0) or FCtrl.VerificaProduto;

  // Itens de SERVICO (PRO_TIPO = 'S'); total guardado p/ totalizer.
  CarregaItens(True);

  // Cliente do ramo de servico (mesmo do pedido conjugado).
  LcCustomerDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Empresa);

  LcJson := TJSONObject.Create;
  Try
    // D1: id do processo = NFL_CODIGO (a nota mista vincula TODO o
    // processo: tb_order.id = tb_invoice.id = orderId do financeiro)
    LcJson.AddPair('id', TJSONNumber.Create(FCtrl.Registro.Codigo));
    LcJson.AddPair('terminal', TJSONNumber.Create(FTerminal));
    // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
    LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

    AddOrderBlock(LcJson);

    // Bloco "service": mesmo numero do pedido, SEM salesmanDocument
    // (ramo de servico nao tem vendedor).
    LcService := TJSONObject.Create;
    LcService.AddPair('number', TJSONNumber.Create(FCtrl.Pedido.Registro.Numero));
    if LcCustomerDoc <> '' then
      LcService.AddPair('customerDocument', LcCustomerDoc);
    LcJson.AddPair('service', LcService);

    // D6: item de servico NAO leva stockListId/priceListId
    AddItemsBlock(LcJson, False);

    // D13: CONJUGADA — ramo de venda viaja junto: sale{number,
    // salesmanDocument} + saleItems (PRO_TIPO<>'S', COM stockListId/
    // priceListId), espelhos dos blocos do /order-sale. O
    // customerDocument ja foi no bloco service (contrato).
    if LcTemMercadoria then
    Begin
      LcSalesmanDoc := DM.GetDocumentByEmpCodigo(FCtrl.Pedido.Registro.Vendedor);
      LcSale := TJSONObject.Create;
      LcSale.AddPair('number', TJSONNumber.Create(FCtrl.Pedido.Registro.Numero));
      if LcSalesmanDoc <> '' then
        LcSale.AddPair('salesmanDocument', LcSalesmanDoc);
      LcJson.AddPair('sale', LcSale);

      // Refiltra a lista para MERCADORIA (o total FItensNota ja foi
      // guardado no CarregaItens — totalizer leva o TOTAL da nota).
      FCtrl.Pedido.Itens.getListByNFPorNatureza(FCtrl.Registro.Codigo, False);
      AddItemsBlock(LcJson, True, 'saleItems');
    End;

    AddTotalizerBlock(LcJson);
    AddBillingBlock(LcJson);
    AddUserBlock(LcJson);

    // D10: bloco `invoice` = campos do /invoice SEM id/terminal/deleted
    // + sub-bloco "service" (ramo tb_invoice_service no destino); D13:
    // na conjugada o sub-bloco "merchandise" viaja junto (presenca =
    // a nota tambem e de mercadoria).
    LcInvoice := TJSONObject.Create;
    AddInvoiceBaseFields(LcInvoice);
    LcRamoSrv := TJSONObject.Create;
    LcRamoSrv.AddPair('totalValue', TJSONNumber.Create(FCtrl.Registro.ValorServico));
    LcInvoice.AddPair('service', LcRamoSrv);
    if LcTemMercadoria then
      AddMerchandiseRamo(LcInvoice);
    LcJson.AddPair('invoice', LcInvoice);

    FStrJson := LcJson.ToJSON;
  Finally
    LcJson.Free;
  End;
end;


end.
