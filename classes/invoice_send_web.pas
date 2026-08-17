unit invoice_send_web;


interface

uses System.SysUtils, System.JSON, general_web,
     ControllerNotaFiscal, ObjInvoiceMerchandise, un_dm;

Type
  // Rodada 2 — Sincronia por PROCESSO (D8-D11 de prompt_notas_mercadoria_
  // servico.md): alem da nota AVULSA (comportamento proprio, INTOCADO —
  // Seq 20 / /invoice/sincronize), esta unit e a BASE da hierarquia de
  // processos:
  //
  //   TInvoiceSendWeb (avulsa)
  //     +- TInvoiceMerchandiseSendWeb (INTERMEDIARIA, sem linha no catalogo)
  //     |    +- TInvoiceMerchandiseSaleSendWeb     (PED_TIPO=1 -> /order-sale)
  //     |    +- TInvoiceMerchandisePurchaseSendWeb (PED_TIPO=2 -> /order-purchase)
  //     |    +- TInvoiceMerchandiseAdjustSendWeb   (PED_TIPO=3 -> /order-stock-adjust)
  //     +- TInvoiceServiceSendWeb (processo de servico -> /order-service)
  //
  // Os helpers protected abaixo montam os blocos compartilhados: os campos
  // base do /invoice (na avulsa entram na RAIZ; nos processos entram no
  // bloco `invoice` — D10: nenhuma URL nova) e os blocos de PEDIDO
  // (order/items/totalizer/billing/user) a partir de FCtrl.Pedido, que o
  // FillDataObjetoDetached ja carrega. A avulsa (EM, nota SEM itens) nunca
  // chama os blocos de pedido.
  TInvoiceSendWeb = class(TGeneralWeb)
    protected
      FCtrl: TControllerNotaFiscal;
      // Contagem TOTAL de itens da nota (mercadoria + servico) — o
      // totalizer do conjugado leva sempre o TOTAL, identico nos dois
      // ramos (upsert idempotente na web — regra do patch 06).
      FItensNota: Integer;
      // issuer: 'S' quando a propria institution emite (NFL_TIPO EE/EM);
      // 'N' quando e destinatario. A compra sobrescreve (nota emitida
      // pelo fornecedor -> sempre 'N').
      function IssuerFlag: String; virtual;
      // Campos do /invoice SEM id/terminal/deleted (contrato do bloco
      // `invoice` dos processos — CONTRATOS_SYNC.md).
      procedure AddInvoiceBaseFields(AJson: TJSONObject);
      // Sub-bloco `merchandise` do bloco `invoice` (ramo
      // tb_invoice_merchandise no destino) — na BASE porque a conjugada
      // (TInvoiceServiceSendWeb, D13) tambem o envia quando a nota tem
      // parte mercadoria, e ela herda direto daqui.
      procedure AddMerchandiseRamo(AInvoice: TJSONObject);
      // Itens do processo: guarda o total (FItensNota) e refiltra a lista
      // pela natureza (PRO_TIPO) — ApenasServico=True traz so 'S'.
      procedure CarregaItens(ApenasServico: Boolean);
      // Status do PEDIDO no dominio da WEB (Valdo, 2026-08-14): o legado
      // guarda em PED_FATURADO um flag de FATURAMENTO ('S' faturado / 'A'
      // em aberto); a web quer o estado do PROCESSO — 'F' fechado / 'A'
      // aberto. Traducao no ENVIO ("quem aposenta se adapta" — D15/D22).
      function OrderStatus: String;
      procedure AddOrderBlock(AJson: TJSONObject);
      // NomeBloco (D13): a conjugada envia DOIS arrays de itens no mesmo
      // payload — 'items' (servico) e 'saleItems' (mercadoria).
      procedure AddItemsBlock(AJson: TJSONObject; IncluiListas: Boolean;
                              const NomeBloco: String = 'items');
      procedure AddTotalizerBlock(AJson: TJSONObject);
      procedure AddBillingBlock(AJson: TJSONObject);
      procedure AddUserBlock(AJson: TJSONObject);
      procedure GenerateJson;Override;
    public
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation

{ TInvoiceSendWeb }

constructor TInvoiceSendWeb.Create;
begin
  inherited;
  FCtrl := TControllerNotaFiscal.Create(nil);
end;

destructor TInvoiceSendWeb.Destroy;
begin
  FreeAndNil(FCtrl);
  inherited;
end;

function TInvoiceSendWeb.IssuerFlag: String;
begin
  // D: issuer='S' quando a própria institution emite (NFL_TIPO EE/EM);
  // 'N' quando é destinatário (documento vira o do emitente terceiro).
  if (FCtrl.Registro.Tipo = 'EE') OR (FCtrl.Registro.Tipo = 'EM') then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TInvoiceSendWeb.AddInvoiceBaseFields(AJson: TJSONObject);
Var
  LcEntityDoc : String;
begin
  // Achado transversal: EntityExternalCode/IssuerExternalCode do Obj
  // legado carregam o CODIGO INTERNO (NFL_CODEMP), não o documento.
  LcEntityDoc := DM.GetDocumentByEmpCodigo(FCtrl.Registro.CodigoEmpresa);

  AJson.AddPair('issuer', IssuerFlag);
  AJson.AddPair('kindEmis', FCtrl.ObjInvoice.Nota.TipoEmissao);
  AJson.AddPair('finality', FCtrl.ObjInvoice.Nota.Finalidade);
  AJson.AddPair('number', FCtrl.ObjInvoice.Nota.Numero);
  AJson.AddPair('serie', FCtrl.ObjInvoice.Nota.Serie);
  AJson.AddPair('cfopId', FCtrl.ObjInvoice.Nota.Cfop);
  if LcEntityDoc <> '' then
    AJson.AddPair('entityDocument', LcEntityDoc);
  AJson.AddPair('dtEmission', FormatDateTime('yyyy-mm-dd', FCtrl.ObjInvoice.Nota.Data_emissao));
  AJson.AddPair('value', TJSONNumber.Create(FCtrl.ObjInvoice.Nota.Valor));
  AJson.AddPair('model', FCtrl.ObjInvoice.Nota.Modelo);
  AJson.AddPair('status', FCtrl.ObjInvoice.Nota.Status);
end;

procedure TInvoiceSendWeb.AddMerchandiseRamo(AInvoice: TJSONObject);
Var
  LcMerchandise : TJSONObject;
begin
  // D3: sub-bloco "merchandise" = ramo tb_invoice_merchandise no destino.
  // discountValue/indPres vem do TB_PEDIDO (mesma fonte do
  // FillDataInvoiceMerchandise legado), carregado pelo FillDataObjetoDetached.
  // Leitura DIRETA do model (patch 06): o model de destino
  // tblinvoiceMerchandise tem typo no getter de ValorIcmsSt.
  LcMerchandise := TJSONObject.Create;
  if FCtrl.Registro.DataSaida > 0 then
    LcMerchandise.AddPair('dtExit', FormatDateTime('yyyy-mm-dd', FCtrl.Registro.DataSaida));
  if FCtrl.Registro.HoraSaida > 0 then
    LcMerchandise.AddPair('tmExit', FormatDateTime('hh:nn:ss', FCtrl.Registro.HoraSaida));
  LcMerchandise.AddPair('baseIcmsValue', TJSONNumber.Create(FCtrl.Registro.ValorBaseICMS));
  LcMerchandise.AddPair('icmsValue', TJSONNumber.Create(FCtrl.Registro.ValorICMS));
  LcMerchandise.AddPair('baseIcmsStValue', TJSONNumber.Create(FCtrl.Registro.ValorBaseICMSST));
  LcMerchandise.AddPair('icmsStValue', TJSONNumber.Create(FCtrl.Registro.ValorICMSST));
  LcMerchandise.AddPair('totalValue', TJSONNumber.Create(FCtrl.Registro.ValorProdutos));
  LcMerchandise.AddPair('freightValue', TJSONNumber.Create(FCtrl.Registro.ValorFrete));
  LcMerchandise.AddPair('insuranceValue', TJSONNumber.Create(FCtrl.Registro.ValorSeguro));
  LcMerchandise.AddPair('expensesValue', TJSONNumber.Create(FCtrl.Registro.ValorOutrasDespesas));
  LcMerchandise.AddPair('ipiValue', TJSONNumber.Create(FCtrl.Registro.ValorIPI));
  LcMerchandise.AddPair('discountValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorDesconto));
  LcMerchandise.AddPair('totalQtty', TJSONNumber.Create(FCtrl.Registro.QtdeProdutos));
  LcMerchandise.AddPair('indPres', TJSONNumber.Create(FCtrl.Pedido.Registro.IndicaPresenca));
  AInvoice.AddPair('merchandise', LcMerchandise);
end;

procedure TInvoiceSendWeb.CarregaItens(ApenasServico: Boolean);
begin
  // Total ANTES do filtro: o totalizer do conjugado leva a contagem
  // TOTAL de itens da nota nas duas classes (patch 06).
  FCtrl.Pedido.Itens.Registro.CodigoNota := FCtrl.Registro.Codigo;
  FCtrl.Pedido.Itens.getListByNF;
  FItensNota := FCtrl.Pedido.Itens.Lista.Count;
  // Rodada 2: o vinculo de itens agora e o NFL_CODIGO REAL (ITF_CODNFL) —
  // as TOrder*SendWeb aposentadas passavam PED_CODIGO aqui.
  FCtrl.Pedido.Itens.getListByNFPorNatureza(FCtrl.Registro.Codigo, ApenasServico);
end;

function TInvoiceSendWeb.OrderStatus: String;
begin
  // 'S' (faturado no legado) = processo FECHADO na web; 'A' (em aberto)
  // permanece 'A'. Qualquer outro conteudo segue cru — dado fora do
  // dominio conhecido nao e inventado aqui (a web normaliza na transicao).
  if UpperCase(Trim(FCtrl.Pedido.Registro.Faturado)) = 'S' then
    Result := 'F'
  else
    Result := FCtrl.Pedido.Registro.Faturado;
end;

procedure TInvoiceSendWeb.AddOrderBlock(AJson: TJSONObject);
Var
  LcOrder : TJSONObject;
begin
  LcOrder := TJSONObject.Create;
  LcOrder.AddPair('dtRecord', FormatDateTime('yyyy-mm-dd', FCtrl.Pedido.Registro.Data));
  LcOrder.AddPair('note', FCtrl.Pedido.Registro.Observacao);
  LcOrder.AddPair('status', OrderStatus);
  LcOrder.AddPair('origin', 'D');
  AJson.AddPair('order', LcOrder);
end;

procedure TInvoiceSendWeb.AddItemsBlock(AJson: TJSONObject; IncluiListas: Boolean;
  const NomeBloco: String);
Var
  LcItems : TJSONArray;
  LcItem  : TJSONObject;
  I       : Integer;
begin
  LcItems := TJSONArray.Create;
  for I := 0 to FCtrl.Pedido.Itens.Lista.Count - 1 do
  Begin
    LcItem := TJSONObject.Create;
    LcItem.AddPair('id', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].Codigo));
    LcItem.AddPair('productId', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].CodigoProduto));
    LcItem.AddPair('quantity', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].Quantidade));
    LcItem.AddPair('unitValue', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].ValorUnitario));
    LcItem.AddPair('discountAliquot', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].AliqDesconto));
    LcItem.AddPair('discountValue', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].ValorDesconto));
    // D6: item de servico (e itens de compra/ajuste) NAO leva
    // stockListId/priceListId — so a venda de mercadoria usa.
    if IncluiListas then
    Begin
      LcItem.AddPair('stockListId', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].CodigoEstoque));
      LcItem.AddPair('priceListId', TJSONNumber.Create(FCtrl.Pedido.Itens.Lista[I].CodigoTabela));
    End;
    LcItems.AddElement(LcItem);
  End;
  AJson.AddPair(NomeBloco, LcItems);
end;

procedure TInvoiceSendWeb.AddTotalizerBlock(AJson: TJSONObject);
Var
  LcTotalizer : TJSONObject;
begin
  LcTotalizer := TJSONObject.Create;
  // D6: contagem TOTAL de itens da nota (mercadoria + servico)
  LcTotalizer.AddPair('itemsQtde', TJSONNumber.Create(FItensNota));
  LcTotalizer.AddPair('productQtde', TJSONNumber.Create(FCtrl.Pedido.Registro.QtdeProdutos));
  LcTotalizer.AddPair('productValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorProdutos));
  LcTotalizer.AddPair('ipiValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorIPI));
  LcTotalizer.AddPair('discountAliquot', TJSONNumber.Create(FCtrl.Pedido.Registro.AliqDesconto));
  LcTotalizer.AddPair('discountValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorDesconto));
  LcTotalizer.AddPair('expensesValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorOutrasDEspesas));
  LcTotalizer.AddPair('totalValue', TJSONNumber.Create(FCtrl.Pedido.Registro.ValorPedido));
  AJson.AddPair('totalizer', LcTotalizer);
end;

procedure TInvoiceSendWeb.AddBillingBlock(AJson: TJSONObject);
Var
  LcBilling  : TJSONObject;
  LcPlots    : String;
  LcDeadline : String;
begin
  // Lookup da forma de pagamento (mesma rotina do FillDataObjeto legado)
  FCtrl.Pedido.FormaPagto.Registro.Codigo := FCtrl.Pedido.Registro.FormaPagto;
  FCtrl.Pedido.FormaPagto.getById;

  LcBilling := TJSONObject.Create;
  LcBilling.AddPair('paymentTypeDescription', FCtrl.Pedido.FormaPagto.Registro.Descricao);
  LcPlots    := Copy(FCtrl.Pedido.Registro.Prazo, 1, 3);
  LcDeadline := Copy(FCtrl.Pedido.Registro.Prazo, 7, Length(FCtrl.Pedido.Registro.Prazo) - 6);
  LcBilling.AddPair('plots', LcPlots);
  LcBilling.AddPair('deadline', LcDeadline);
  AJson.AddPair('billing', LcBilling);
end;

procedure TInvoiceSendWeb.AddUserBlock(AJson: TJSONObject);
Var
  LcUser    : TJSONObject;
  LcUserDoc : String;
  LcUserExt : String;
begin
  // AUTOR (prompt_indexacao_usuario_firebird.md): PED_CODUSU resolvido
  // pela cascata (documento do colaborador > externalCode); sem
  // referencia disponivel o bloco nao viaja e a web usa o fallback
  // de transicao (decisoes 2/5/8).
  if DM.GetUserSyncRef(FCtrl.Pedido.Registro.Usuario, LcUserDoc, LcUserExt) then
  Begin
    LcUser := TJSONObject.Create;
    if LcUserDoc <> '' then
      LcUser.AddPair('userDocument', LcUserDoc)
    else
      LcUser.AddPair('userExternalCode', LcUserExt);
    AJson.AddPair('user', LcUser);
  End;
end;

procedure TInvoiceSendWeb.GenerateJson;
Var
  LcJson : TJSONObject;
begin
  inherited;
  FCtrl.NotaAvulsa := True;
  FCtrl.Registro.Tipo := 'EM';
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getSincronia;
  // D13: nao e nota avulsa (EM) ou registro ausente — nada a enviar por
  // esta classe: skip SEM marca no SRC_LOG (a fila por KIND ja filtra
  // nfl_tipo='EM'; orfao eventual sai pela limpeza de 48h).
  if not FCtrl.exist then
  Begin
    FSkip := True;
    Exit;
  End;

  FCtrl.ClearDataObjecto;
  FCtrl.ObjInvoice.Estabelecimento := FInstitutionDestino;
  FCtrl.ObjInvoice.Terminal := FTerminal;
  // FillDataObjetoDetached resolve CFOP (join TB_NATUREZA) e mantém a
  // mesma lógica de emitente/destinatário do legado — reaproveitado.
  FCtrl.FillDataObjetoDetached(FCtrl.Registro);

  LcJson := TJSONObject.Create;
  Try
    LcJson.AddPair('id', TJSONNumber.Create(FCtrl.ObjInvoice.Nota.Codigo));
    LcJson.AddPair('terminal', TJSONNumber.Create(FTerminal));
    AddInvoiceBaseFields(LcJson);
    // decisao 8: DELETED real da tabela, direto do model (getter normalizado)
    LcJson.AddPair('deleted', FCtrl.Registro.Deleted);

    FStrJson := LcJson.ToJSON;
  Finally
    LcJson.Free;
  End;
end;


end.
