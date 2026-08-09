unit un_sincronia_seed;

{ =====================================================================
  Catalogo de seed da TB_LISTA_SINCRONIA (Onda 0 da revisao do sync).

  Fonte dos dados: uMain.pas (RegisterClass) + controller/
  ControllerTrigger.pas (tabelas/campos confirmados no codigo) +
  Infra-IA/setes-sync/CONTRATOS_SYNC.md (endpoints que existem hoje na
  setes-sync, pos Ondas 1-6). Modulo restaurante (7 linhas TB_REST_*)
  REMOVIDO do catalogo em 2026-07-26 (Valdo).

  WAY: 'E' = Enviar (local -> web/retaguarda), 'R' = Receber (web ->
  local, fase futura D16) - convencao do motor (ControllerListaSincronia:
  getListaEnviar WHERE WAY='E' / getListaReceber WHERE WAY='R').

  Texto SEM acentuacao de proposito: o restante do projeto usa encoding
  ANSI/Windows-1252 (ver mojibake em general_web.pas) e este arquivo
  evita depender de encoding para compilar em qualquer maquina.

  DESC_TRIGGER fica sempre vazio (NULL) - nenhum nome real de trigger
  foi encontrado no codigo-fonte do Sincronizador; preencher a mao se
  o motor de fato exigir o nome (ver MAPA_INDEXACAO.md).
  ===================================================================== }

interface

type
  TSincroniaSeedRow = record
    Seq:         Integer;
    Way:         String;
    DescTabela:  String;
    Kind:        String;
    DescProcess: String;
    DescField:   String;  // '' = NULL (nenhum campo-chave confirmado)
    Note:        String;
    SetOn:       String;  // 'S' ou 'N'
    ClassName:   String;
    EndPoint:    String;  // '' = NULL (endpoint ainda nao existe)
  end;

const
  // Rodada 2 — Sincronia por PROCESSO (D8-D11, 2026-07-27): TB_PEDIDO saiu
  // da fila e a NOTA_MERCADORIA intermediaria tambem; TB_NOTA_FISCAL passou
  // a carregar os PROCESSOS.
  // RENUMERACAO (Valdo, 2026-07-27): os processos de nota SUBIRAM para logo
  // apos a avulsa — NOTA_SERVICO 21, NOTA_VENDA 22, NOTA_COMPRA 23,
  // NOTA_AJUSTE 24 — o que de quebra corrige a ordem de dependencia (os
  // retornos 55/65/NFS-e processavam ANTES das notas); as linhas antigas
  // 22-30 deslocaram +3 (25-33, mesma ordem relativa).
  // REORDENACAO (Valdo, 2026-07-27): o USUARIO subiu para a Seq 1 — ele e
  // a referencia do bloco `user` de todos os movimentos; os cadastros
  // antigos 1-16 empurraram para 2-17; transportadora (era 38) e servico
  // (era 40) sao CADASTROS BASICOS — sem eles as notas nao podem ser
  // usadas — e vieram para 18/19, ANTES do bloco de movimento.
  // Catalogo: 33 linhas CONTIGUAS = Seqs 1-19 (cadastros) + 20-33
  // (movimento: notas, financeiro, retornos, arquivo).
  // Reservados: 34+.
  // Bancos JA SEMEADOS se renumeram SOZINHOS a cada start: o bootstrap
  // impoe o SEQ canonico por (WAY, DESC_TABELA, KIND) — un_dm.
  // EnforceSeqCatalogo — sem SQL manual de UPDATE.
  SINCRONIA_SEED: array[0..32] of TSincroniaSeedRow = (
    // ---- 1: USUARIO PRIMEIRO (revisao do Valdo, 2026-07-27): e a referencia
    // do bloco `user` de TODOS os movimentos � subir antes de tudo reduz os
    // 409 USER_NOT_SYNCED (prompt_indexacao_usuario_firebird.md 2026-07-26) ----
    (Seq: 1; Way: 'E'; DescTabela: 'TB_USUARIO'; Kind: 'CADASTRO';
     DescProcess: 'Usuario do sistema (autor das operacoes)'; DescField: 'USU_CODIGO';
     Note: 'Decisoes 1-3 (2026-07-26) - entity + tb_user sem credencial; cascata colaborador->externalCode; perfil PDV desliga (decisao 8)';
     SetOn: 'S'; ClassName: 'TUserSendWeb'; EndPoint: '/user/sincronize'),

    // ---- 2-13: cadastros (ordem de prioridade D8) ----
    (Seq: 2;  Way: 'E'; DescTabela: 'TB_MARCA_PRODUTO'; Kind: 'CADASTRO';
     DescProcess: 'Marca de produto (catalogo central)'; DescField: 'MRC_CODIGO';
     Note: 'Onda 3 - dedupe por descricao na setes_central (D5/D17)';
     SetOn: 'S'; ClassName: 'TBrandSendWeb'; EndPoint: '/brand/sincronize'),

    (Seq: 3;  Way: 'E'; DescTabela: 'TB_CATEGORY'; Kind: 'CADASTRO';
     DescProcess: 'Categoria de produto/servico (arvore)'; DescField: 'ID';
     Note: 'Onda 3 - id local, posit_level recalculado no servidor';
     SetOn: 'S'; ClassName: 'TCategorySendWeb'; EndPoint: '/category/sincronize'),

    (Seq: 4;  Way: 'E'; DescTabela: 'TB_MEDIDA'; Kind: 'CADASTRO';
     DescProcess: 'Unidade de medida (catalogo central)'; DescField: 'MED_CODIGO';
     Note: 'Onda 3 - endpoint NOVO (nao existia na setes-sync)';
     SetOn: 'S'; ClassName: 'TMeasureSendWeb'; EndPoint: '/measure/sincronize'),

    (Seq: 5;  Way: 'E'; DescTabela: 'TB_EMBALAGEM'; Kind: 'CADASTRO';
     DescProcess: 'Embalagem (catalogo central)'; DescField: 'EMB_CODIGO';
     Note: 'Onda 3 - dedupe por descricao';
     SetOn: 'S'; ClassName: 'TPackageSendWeb'; EndPoint: '/package/sincronize'),

    (Seq: 6;  Way: 'E'; DescTabela: 'TB_PRODUTO'; Kind: 'CADASTRO';
     DescProcess: 'Produto (product+merchandise+stock)'; DescField: 'PRO_CODIGO';
     Note: 'Onda 3 - id local; brand/package/measure por descricao; categoria por id (409 se ausente)';
     SetOn: 'S'; ClassName: 'TMerchandiseSendWeb'; EndPoint: '/merchandise/sincronize'),

    (Seq: 7;  Way: 'E'; DescTabela: 'TB_TABELA_PRECO'; Kind: 'CADASTRO';
     DescProcess: 'Tabela de preco'; DescField: 'TPR_CODIGO';
     Note: 'Onda 3 - id local';
     SetOn: 'S'; ClassName: 'TPriceListSendWeb'; EndPoint: '/price-list/sincronize'),

    (Seq: 8;  Way: 'E'; DescTabela: 'TB_PRECO'; Kind: 'PRECO';
     DescProcess: 'Preco por tabela/produto'; DescField: 'PRC_CODIGO';
     Note: 'Onda 3 - 409 se tabela/produto ainda nao sincronizados';
     SetOn: 'S'; ClassName: 'TPriceSendWeb'; EndPoint: '/price/sincronize'),

    (Seq: 9;  Way: 'E'; DescTabela: 'TB_ESTOQUES'; Kind: 'CADASTRO';
     DescProcess: 'Lista de estoques (depositos)'; DescField: 'ETS_CODIGO';
     Note: 'Onda 3 - id local; ETS_PRINCIPAL vira coluna main';
     SetOn: 'S'; ClassName: 'TStockListSendWeb'; EndPoint: '/stock-list/sincronize'),

    (Seq: 10;  Way: 'E'; DescTabela: 'TB_ESTOQUE'; Kind: 'ESTOQUE';
     DescProcess: 'Saldo de estoque'; DescField: 'EST_CODIGO';
     Note: 'Onda 3 - achado: alvo real e tb_stock_balance (tabela propria, nao tb_stock)';
     SetOn: 'S'; ClassName: 'TStockBalanceSendWeb'; EndPoint: '/stock-balance/sincronize'),

    (Seq: 11; Way: 'E'; DescTabela: 'TB_PROMOTION'; Kind: 'CADASTRO';
     DescProcess: 'Promocao + itens'; DescField: 'ID';
     Note: 'Onda 3 - items = snapshot (fora da lista = soft delete)';
     SetOn: 'S'; ClassName: 'TPromotionSendWeb'; EndPoint: '/promotion/sincronize'),

    (Seq: 12; Way: 'E'; DescTabela: 'TB_PLANOCONTAS'; Kind: 'CADASTRO';
     DescProcess: 'Plano de contas (arvore unica)'; DescField: 'PLC_CODIGO';
     Note: 'Onda 3 - id local; posit_level recalculado';
     SetOn: 'S'; ClassName: 'TFinancialPlansSendWeb'; EndPoint: '/financial-plans/sincronize'),

    (Seq: 13; Way: 'E'; DescTabela: 'TB_FORMAPAGTO'; Kind: 'CADASTRO';
     DescProcess: 'Forma de pagamento (catalogo central)'; DescField: 'FPT_CODIGO';
     Note: 'Onda 3 - idNfce so na criacao; attrs do vinculo nao sobrescrevem config web';
     SetOn: 'S'; ClassName: 'TPaymentTypeSendWeb'; EndPoint: '/payment-type/sincronize'),

    // ---- 14-17: papeis de entidade (reindexacao por documento/UUID) ----
    (Seq: 14; Way: 'E'; DescTabela: 'TB_CLIENTE'; Kind: 'CADASTRO';
     DescProcess: 'Cliente (cadeia central + papel)'; DescField: 'CLI_CODEMP';
     Note: 'Onda 4 - reindexado por CPF/CNPJ ou externalCode; vendedor/transportador por documento (409 se ausente)';
     SetOn: 'S'; ClassName: 'TCustomerSendWeb'; EndPoint: '/customer/sincronize'),

    (Seq: 15; Way: 'E'; DescTabela: 'TB_FORNECEDOR'; Kind: 'CADASTRO';
     DescProcess: 'Fornecedor (cadeia central + papel)'; DescField: 'FOR_CODEMP';
     Note: 'Onda 4 - mesmo CNPJ de um cliente cai na MESMA entity (D3)';
     SetOn: 'S'; ClassName: 'TProviderSendWeb'; EndPoint: '/provider/sincronize'),

    (Seq: 16; Way: 'E'; DescTabela: 'TB_COLABORADOR'; Kind: 'CADASTRO';
     DescProcess: 'Colaborador/Vendedor (precedencia Collaborator->Salesman)'; DescField: 'CLB_CODIGO';
     Note: 'Onda 4 - grava collaborator SEMPRE + salesman quando o bloco vem';
     SetOn: 'S'; ClassName: 'TSalesManSendWeb'; EndPoint: '/salesman/sincronize'),

    (Seq: 17; Way: 'E'; DescTabela: 'TB_CONTABANCARIA'; Kind: 'CADASTRO';
     DescProcess: 'Conta bancaria'; DescField: 'CTB_CODIGO';
     Note: 'Onda 4 - bankNumber (FEBRABAN) resolvido na central; 409 se banco desconhecido. Corrige bug C1 (payload vazio)';
     SetOn: 'S'; ClassName: 'TBankAccountSendWeb'; EndPoint: '/bank-account/sincronize'),

    // ---- pedidos — REMOVIDOS DO SEED (Rodada 2, D8, 2026-07-27):
    // TB_PEDIDO saiu da fila de sincronia (a NOTA e o unico fato gerador
    // dos processos — Seqs 22/23/24 substituem). Alem de nao semear, o
    // bootstrap DELETA as linhas mortas de bancos ja semeados POR
    // TABELA/KIND (TB_PEDIDO inteira + NOTA_MERCADORIA — nunca por SEQ,
    // que foi reutilizado na renumeracao) e dropa o trigger TG_SRC_PEDIDO
    // (un_dm.SeedListaSincroniaIfEmpty). Os Seqs 17-19 que eles ocupavam
    // foram reutilizados na reordenacao de 2026-07-27 (conta bancaria 17,
    // transportadora 18, servico 19).

    // ---- 18: transportadora (decisao 4 da revisao de entidades 2026-07-25;
    // reordenada para ANTES das notas em 2026-07-27 � cadastro basico) ----
    (Seq: 18; Way: 'E'; DescTabela: 'TB_TRANSPORTADORA'; Kind: 'CADASTRO';
     DescProcess: 'Transportadora (cadeia central + papel)'; DescField: 'TRP_CODEMP';
     Note: 'Decisao 4 (2026-07-25) - fecha o 409 CARRIER_NOT_SYNCED eterno do customer; sincronizar ANTES do cliente';
     SetOn: 'S'; ClassName: 'TCarrierSendWeb'; EndPoint: '/carrier/sincronize'),

    // ---- 19: servico (prompt_notas_mercadoria_servico.md, D2; reordenado
    // para ANTES das notas em 2026-07-27 � sem ele as notas nao podem ser usadas) ----
    (Seq: 19; Way: 'E'; DescTabela: 'TB_PRODUTO'; Kind: 'SERVICO';
     DescProcess: 'Servico (product kind S)'; DescField: 'PRO_CODIGO';
     Note: 'D2 - PRO_TIPO=S vira SO tb_product (kind S); P/M continuam na Seq 5; A (cardapio) aposentado nao sincroniza';
     SetOn: 'S'; ClassName: 'TServiceSendWeb'; EndPoint: '/service/sincronize'),

    // ---- 20-24: nota fiscal — avulsa + 4 PROCESSOS (Rodada 2, D8-D11):
    // a NOTA e o fato gerador; cada KIND envia o processo COMPLETO
    // (pedido + nota + ramos) para o endpoint de pedido correspondente.
    // Renumeracao 2026-07-27: processos vieram de 42-45 para 21-24
    // (antes dos retornos — ordem de dependencia correta) ----
    (Seq: 20; Way: 'E'; DescTabela: 'TB_NOTA_FISCAL'; Kind: 'NOTA_AVULSA';
     DescProcess: 'Nota fiscal avulsa (tipo EM)'; DescField: 'NFL_CODIGO';
     Note: 'Onda 5 - destinatario por documento; CFOP = id da central (409 se desconhecido)';
     SetOn: 'S'; ClassName: 'TInvoiceSendWeb'; EndPoint: '/invoice/sincronize'),

    (Seq: 21; Way: 'E'; DescTabela: 'TB_NOTA_FISCAL'; Kind: 'NOTA_SERVICO';
     DescProcess: 'Processo de servico (ordem completa, incl. conjugada)'; DescField: 'NFL_CODIGO';
     Note: 'D13 - PED_TIPO=1 COM item PRO_TIPO=S; ordem de servico COMPLETA: na conjugada os blocos sale/saleItems e invoice{service+merchandise} viajam juntos';
     SetOn: 'S'; ClassName: 'TInvoiceServiceSendWeb'; EndPoint: '/order-service/sincronize'),

    (Seq: 22; Way: 'E'; DescTabela: 'TB_NOTA_FISCAL'; Kind: 'NOTA_VENDA';
     DescProcess: 'Processo de venda PURA (pedido+nota mercadoria)'; DescField: 'NFL_CODIGO';
     Note: 'D13 - PED_TIPO=1 SEM item de servico (conjugada e da Seq 21); itens PRO_TIPO<>S; invoice{merchandise}';
     SetOn: 'S'; ClassName: 'TInvoiceMerchandiseSaleSendWeb'; EndPoint: '/order-sale/sincronize'),

    (Seq: 23; Way: 'E'; DescTabela: 'TB_NOTA_FISCAL'; Kind: 'NOTA_COMPRA';
     DescProcess: 'Processo de compra (pedido+nota mercadoria)'; DescField: 'NFL_CODIGO';
     Note: 'D9/D10/D11 - PED_TIPO=2; issuer=N e entityDocument = fornecedor; objeto completo c/ bloco invoice{merchandise}';
     SetOn: 'S'; ClassName: 'TInvoiceMerchandisePurchaseSendWeb'; EndPoint: '/order-purchase/sincronize'),

    (Seq: 24; Way: 'E'; DescTabela: 'TB_NOTA_FISCAL'; Kind: 'NOTA_AJUSTE';
     DescProcess: 'Processo de ajuste de estoque (pedido+nota)'; DescField: 'NFL_CODIGO';
     Note: 'D9/D10/D11 - PED_TIPO=3; entityDocument opcional; objeto completo c/ bloco invoice{merchandise}';
     SetOn: 'S'; ClassName: 'TInvoiceMerchandiseAdjustSendWeb'; EndPoint: '/order-stock-adjust/sincronize'),

    // ---- 25: movimentacao de estoque (era Seq 22) ----
    (Seq: 25; Way: 'E'; DescTabela: 'TB_CTRL_ESTOQUE'; Kind: 'MOVIMENTO';
     DescProcess: 'Movimentacao de estoque'; DescField: 'CET_CODIGO';
     Note: 'Onda 5 - achado: PK fisica so id AUTO_INCREMENT no destino, pode colidir entre institutions (Rodada 4)';
     SetOn: 'S'; ClassName: 'TStockStatementSendWeb'; EndPoint: '/stock-statement/sincronize'),

    // ---- 26-28: financeiro e caixa (eram Seqs 23-25) ----
    (Seq: 26; Way: 'E'; DescTabela: 'TB_FINANCEIRO'; Kind: 'FINANCEIRO';
     DescProcess: 'Titulo financeiro (formato NOVO 5.5)'; DescField: 'FIN_CODIGO';
     Note: 'Onda 5 - PK NATURAL no destino (pedido+terminal+parcela); FIN_CODIGO NAO vira id - semantica de ESPELHO (baixa=evento unico N)';
     SetOn: 'S'; ClassName: 'TFinancialSendWeb'; EndPoint: '/financial/sincronize'),

    (Seq: 27; Way: 'E'; DescTabela: 'TB_MOVIM_FINANCEIRO'; Kind: 'FINANCEIRO';
     DescProcess: 'Movimento financeiro (extrato)'; DescField: 'MVF_CODIGO';
     Note: 'Onda 5 - id local; conta/historico ausentes = sentinela 0';
     SetOn: 'S'; ClassName: 'TFinancialStatementSendWeb'; EndPoint: '/financial-statement/sincronize'),

    (Seq: 28; Way: 'E'; DescTabela: 'TB_CASHIER'; Kind: 'FINANCEIRO';
     DescProcess: 'Abertura/fechamento de caixa'; DescField: 'ID';
     Note: 'Onda 5 - tb_userid fica NULL; items do caixa removidos do contrato (endpoint proprio futuro)';
     SetOn: 'S'; ClassName: 'TCashierSendWeb'; EndPoint: '/cashier/sincronize'),

    // ---- 29-31: retornos de NF-e / NFS-e (eram Seqs 26-28) — agora
    // DEPOIS das notas de processo, ordem de dependencia correta ----
    (Seq: 29; Way: 'E'; DescTabela: 'TB_RETORNO_NFE'; Kind: 'RETORNO_55';
     DescProcess: 'Retorno de autorizacao NF-e modelo 55'; DescField: 'NFE_CODIGO';
     Note: 'Onda 6 - statusCode/fileName; upsert por id+institution+terminal';
     SetOn: 'S'; ClassName: 'TInvoiceReturn55SendWeb'; EndPoint: '/invoice-return-55/sincronize'),

    (Seq: 30; Way: 'E'; DescTabela: 'TB_RETORNO_NFC'; Kind: 'RETORNO_65';
     DescProcess: 'Retorno de autorizacao NFC-e modelo 65'; DescField: 'NFC_CODIGO';
     Note: 'Onda 6';
     SetOn: 'S'; ClassName: 'TInvoiceReturn65SendWeb'; EndPoint: '/invoice-return-65/sincronize'),

    (Seq: 31; Way: 'E'; DescTabela: 'TB_RETORNO_NFS'; Kind: 'RETORNO_NFSE';
     DescProcess: 'Retorno de autorizacao NFS-e'; DescField: 'NFS_CODNFL';
     Note: 'Patch 04 (C3) APLICADO 2026-07-25: classe criada (invoice_return_service_send_web.pas + ControllerRetornoNFS, molde 55/65) e registrada no uMain. Endpoint Onda 6';
     SetOn: 'S'; ClassName: 'TInvoiceReturnServiceSendWeb'; EndPoint: '/invoice-return-service/sincronize'),

    // ---- 32: arquivo XML (disco, nao mais banco — era Seq 29) ----
    (Seq: 32; Way: 'E'; DescTabela: 'TB_ARQUIVOS'; Kind: 'ARQUIVO';
     DescProcess: 'XML da nota fiscal (conteudo completo em Base64)'; DescField: 'ARQ_CODIGO';
     Note: 'C7: enviar contentBase64 completo (nao so metadados). Grava em disco <cnpj>/<ano>/<mes> no servidor (D9/D20)';
     SetOn: 'S'; ClassName: 'TFileSendWeb'; EndPoint: '/filexml/sincronize'),

    // ---- 33: carta de correcao (era Seq 30) - GAP da Onda 0, NAO ATIVAR ----
    (Seq: 33; Way: 'E'; DescTabela: 'TB_CARTA_CORRECAO'; Kind: 'RETIFICACAO';
     DescProcess: 'Carta de Correcao Eletronica (CC-e)'; DescField: 'CCE_CODIGO';
     Note: 'ACHADO DA ONDA 0: classe existe no Delphi mas o endpoint NAO foi implementado nas Ondas 1-6 - fica para a Rodada 4';
     SetOn: 'N'; ClassName: 'TInvoiceRectificationSendWeb'; EndPoint: '/invoice-rectification/sincronize')

    // ---- 34-37: RESERVADOS. O modulo restaurante (D23, 7 linhas TB_REST_*,
    // antigas Seqs 31-37) foi REMOVIDO do catalogo (Valdo, 2026-07-26) — o
    // bootstrap DELETA as linhas por DESC_TABELA LIKE 'TB_REST_%' (por isso
    // as Seqs 31-33 puderam ser reutilizadas na renumeracao de 2026-07-27).



    // ---- 41+: RESERVADOS. 41 PEDIDO_SERVICO (patch 06) morreu na Rodada 2
    // (D8 — processo de servico inteiro vive na Seq 21); 42-45 eram os
    // processos de nota ANTES da renumeracao de 2026-07-27 (foram para
    // 21-24 — o enforcement do bootstrap renumera bancos ja semeados).
  );

implementation

end.
