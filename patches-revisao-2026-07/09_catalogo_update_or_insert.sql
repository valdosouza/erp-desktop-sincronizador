-- =============================================================
-- 09_catalogo_update_or_insert.sql — Catalogo COMPLETO da TB_LISTA_SINCRONIA
-- (gerado do canonico un_sincronia_seed.pas em 2026-07-27).
-- MOTIVO: bancos ja semeados NUNCA ganharam linhas novas (o seed so roda com
-- a tabela vazia) — na 1a rodada real a linha TB_USUARIO estava ausente e
-- NENHUM usuario subiu (todos os movimentos com bloco user = 409).
-- UPDATE OR INSERT ... MATCHING (WAY, DESC_TABELA, KIND) = idempotente e
-- SUPERA os SQLs manuais dos patches 06/07 e dos prompts de usuario/carrier.
-- NAO toca DESC_TRIGGER (preenchido pelo bootstrap) nem LAST_UPDATE.
-- Em PDV (terminal <> 0), re-rode depois o UPDATE do perfil:
--   UPDATE TB_LISTA_SINCRONIA SET SET_ON = 'N' WHERE (SEQ NOT BETWEEN 20 AND 33);
-- =============================================================

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_USUARIO', 'CADASTRO', 'Usuario do sistema (autor das operacoes)', 1, 'USU_CODIGO', 'Decisoes 1-3 (2026-07-26) - entity + tb_user sem credencial; cascata colaborador->externalCode; perfil PDV desliga (decisao 8)', 'S', 'TUserSendWeb', '/user/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_MARCA_PRODUTO', 'CADASTRO', 'Marca de produto (catalogo central)', 2, 'MRC_CODIGO', 'Onda 3 - dedupe por descricao na setes_central (D5/D17)', 'S', 'TBrandSendWeb', '/brand/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CATEGORY', 'CADASTRO', 'Categoria de produto/servico (arvore)', 3, 'ID', 'Onda 3 - id local, posit_level recalculado no servidor', 'S', 'TCategorySendWeb', '/category/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_MEDIDA', 'CADASTRO', 'Unidade de medida (catalogo central)', 4, 'MED_CODIGO', 'Onda 3 - endpoint NOVO (nao existia na setes-sync)', 'S', 'TMeasureSendWeb', '/measure/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_EMBALAGEM', 'CADASTRO', 'Embalagem (catalogo central)', 5, 'EMB_CODIGO', 'Onda 3 - dedupe por descricao', 'S', 'TPackageSendWeb', '/package/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_PRODUTO', 'CADASTRO', 'Produto (product+merchandise+stock)', 6, 'PRO_CODIGO', 'Onda 3 - id local; brand/package/measure por descricao; categoria por id (409 se ausente)', 'S', 'TMerchandiseSendWeb', '/merchandise/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_TABELA_PRECO', 'CADASTRO', 'Tabela de preco', 7, 'TPR_CODIGO', 'Onda 3 - id local', 'S', 'TPriceListSendWeb', '/price-list/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_PRECO', 'PRECO', 'Preco por tabela/produto', 8, 'PRC_CODIGO', 'Onda 3 - 409 se tabela/produto ainda nao sincronizados', 'S', 'TPriceSendWeb', '/price/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_ESTOQUES', 'CADASTRO', 'Lista de estoques (depositos)', 9, 'ETS_CODIGO', 'Onda 3 - id local; ETS_PRINCIPAL vira coluna main', 'S', 'TStockListSendWeb', '/stock-list/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_ESTOQUE', 'ESTOQUE', 'Saldo de estoque', 10, 'EST_CODIGO', 'Onda 3 - achado: alvo real e tb_stock_balance (tabela propria, nao tb_stock)', 'S', 'TStockBalanceSendWeb', '/stock-balance/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_PROMOTION', 'CADASTRO', 'Promocao + itens', 11, 'ID', 'Onda 3 - items = snapshot (fora da lista = soft delete)', 'S', 'TPromotionSendWeb', '/promotion/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_PLANOCONTAS', 'CADASTRO', 'Plano de contas (arvore unica)', 12, 'PLC_CODIGO', 'Onda 3 - id local; posit_level recalculado', 'S', 'TFinancialPlansSendWeb', '/financial-plans/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_FORMAPAGTO', 'CADASTRO', 'Forma de pagamento (catalogo central)', 13, 'FPT_CODIGO', 'Onda 3 - idNfce so na criacao; attrs do vinculo nao sobrescrevem config web', 'S', 'TPaymentTypeSendWeb', '/payment-type/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CLIENTE', 'CADASTRO', 'Cliente (cadeia central + papel)', 14, 'CLI_CODEMP', 'Onda 4 - reindexado por CPF/CNPJ ou externalCode; vendedor/transportador por documento (409 se ausente)', 'S', 'TCustomerSendWeb', '/customer/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_FORNECEDOR', 'CADASTRO', 'Fornecedor (cadeia central + papel)', 15, 'FOR_CODEMP', 'Onda 4 - mesmo CNPJ de um cliente cai na MESMA entity (D3)', 'S', 'TProviderSendWeb', '/provider/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_COLABORADOR', 'CADASTRO', 'Colaborador/Vendedor (precedencia Collaborator->Salesman)', 16, 'CLB_CODIGO', 'Onda 4 - grava collaborator SEMPRE + salesman quando o bloco vem', 'S', 'TSalesManSendWeb', '/salesman/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CONTABANCARIA', 'CADASTRO', 'Conta bancaria', 17, 'CTB_CODIGO', 'Onda 4 - bankNumber (FEBRABAN) resolvido na central; 409 se banco desconhecido. Corrige bug C1 (payload vazio)', 'S', 'TBankAccountSendWeb', '/bank-account/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_TRANSPORTADORA', 'CADASTRO', 'Transportadora (cadeia central + papel)', 18, 'TRP_CODEMP', 'Decisao 4 (2026-07-25) - fecha o 409 CARRIER_NOT_SYNCED eterno do customer; sincronizar ANTES do cliente', 'S', 'TCarrierSendWeb', '/carrier/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_PRODUTO', 'SERVICO', 'Servico (product kind S)', 19, 'PRO_CODIGO', 'D2 - PRO_TIPO=S vira SO tb_product (kind S); P/M continuam na Seq 5; A (cardapio) aposentado nao sincroniza', 'S', 'TServiceSendWeb', '/service/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_NOTA_FISCAL', 'NOTA_AVULSA', 'Nota fiscal avulsa (tipo EM)', 20, 'NFL_CODIGO', 'Onda 5 - destinatario por documento; CFOP = id da central (409 se desconhecido)', 'S', 'TInvoiceSendWeb', '/invoice/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_NOTA_FISCAL', 'NOTA_SERVICO', 'Processo de servico (ordem completa, incl. conjugada)', 21, 'NFL_CODIGO', 'D13 - PED_TIPO=1 COM item PRO_TIPO=S; ordem de servico COMPLETA: na conjugada os blocos sale/saleItems e invoice{service+merchandise} viajam juntos', 'S', 'TInvoiceServiceSendWeb', '/order-service/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_NOTA_FISCAL', 'NOTA_VENDA', 'Processo de venda PURA (pedido+nota mercadoria)', 22, 'NFL_CODIGO', 'D13 - PED_TIPO=1 SEM item de servico (conjugada e da Seq 21); itens PRO_TIPO<>S; invoice{merchandise}', 'S', 'TInvoiceMerchandiseSaleSendWeb', '/order-sale/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_NOTA_FISCAL', 'NOTA_COMPRA', 'Processo de compra (pedido+nota mercadoria)', 23, 'NFL_CODIGO', 'D9/D10/D11 - PED_TIPO=2; issuer=N e entityDocument = fornecedor; objeto completo c/ bloco invoice{merchandise}', 'S', 'TInvoiceMerchandisePurchaseSendWeb', '/order-purchase/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_NOTA_FISCAL', 'NOTA_AJUSTE', 'Processo de ajuste de estoque (pedido+nota)', 24, 'NFL_CODIGO', 'D9/D10/D11 - PED_TIPO=3; entityDocument opcional; objeto completo c/ bloco invoice{merchandise}', 'S', 'TInvoiceMerchandiseAdjustSendWeb', '/order-stock-adjust/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CTRL_ESTOQUE', 'MOVIMENTO', 'Movimentacao de estoque', 25, 'CET_CODIGO', 'Onda 5 - achado: PK fisica so id AUTO_INCREMENT no destino, pode colidir entre institutions (Rodada 4)', 'S', 'TStockStatementSendWeb', '/stock-statement/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_FINANCEIRO', 'FINANCEIRO', 'Titulo financeiro (formato NOVO 5.5)', 26, 'FIN_CODIGO', 'Onda 5 - PK NATURAL no destino (pedido+terminal+parcela); FIN_CODIGO NAO vira id - semantica de ESPELHO (baixa=evento unico N)', 'S', 'TFinancialSendWeb', '/financial/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_MOVIM_FINANCEIRO', 'FINANCEIRO', 'Movimento financeiro (extrato)', 27, 'MVF_CODIGO', 'Onda 5 - id local; conta/historico ausentes = sentinela 0', 'S', 'TFinancialStatementSendWeb', '/financial-statement/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CASHIER', 'FINANCEIRO', 'Abertura/fechamento de caixa', 28, 'ID', 'Onda 5 - tb_userid fica NULL; items do caixa removidos do contrato (endpoint proprio futuro)', 'S', 'TCashierSendWeb', '/cashier/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_RETORNO_NFE', 'RETORNO_55', 'Retorno de autorizacao NF-e modelo 55', 29, 'NFE_CODIGO', 'Onda 6 - statusCode/fileName; upsert por id+institution+terminal', 'S', 'TInvoiceReturn55SendWeb', '/invoice-return-55/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_RETORNO_NFC', 'RETORNO_65', 'Retorno de autorizacao NFC-e modelo 65', 30, 'NFC_CODIGO', 'Onda 6', 'S', 'TInvoiceReturn65SendWeb', '/invoice-return-65/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_RETORNO_NFS', 'RETORNO_NFSE', 'Retorno de autorizacao NFS-e', 31, 'NFS_CODNFL', 'Patch 04 (C3) APLICADO 2026-07-25: classe criada (invoice_return_service_send_web.pas + ControllerRetornoNFS, molde 55/65) e registrada no uMain. Endpoint Onda 6', 'S', 'TInvoiceReturnServiceSendWeb', '/invoice-return-service/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_ARQUIVOS', 'ARQUIVO', 'XML da nota fiscal (conteudo completo em Base64)', 32, 'ARQ_CODIGO', 'C7: enviar contentBase64 completo (nao so metadados). Grava em disco <cnpj>/<ano>/<mes> no servidor (D9/D20)', 'S', 'TFileSendWeb', '/filexml/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES ('E', 'TB_CARTA_CORRECAO', 'RETIFICACAO', 'Carta de Correcao Eletronica (CC-e)', 33, 'CCE_CODIGO', 'ACHADO DA ONDA 0: classe existe no Delphi mas o endpoint NAO foi implementado nas Ondas 1-6 - fica para a Rodada 4', 'N', 'TInvoiceRectificationSendWeb', '/invoice-rectification/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

COMMIT;
