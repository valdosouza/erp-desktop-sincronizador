/* =====================================================================
   [FALLBACK/REFERÊNCIA] — o caminho AUTOMÁTICO agora é o patch 00:
   un_dm.pas (EnsureSincronia, chamada em DataModuleCreate) +
   function/un_sincronia_seed.pas. Este script serve para conferência
   manual ou para quem preferir rodar o seed direto pelo console.

   Onda 0 — Seed de TB_LISTA_SINCRONIA (tabela vazia em produção/teste)

   ATUALIZADO 2026-07-27 (espelho de function/un_sincronia_seed.pas, que é
   o canônico): Rodada 2 — Sincronia por PROCESSO (D8-D11, patch 07) +
   RENUMERAÇÃO (Valdo, 2026-07-27): os processos de nota subiram para logo
   após a avulsa — 21 NOTA_SERVICO (/order-service), 22 NOTA_VENDA,
   23 NOTA_COMPRA, 24 NOTA_AJUSTE — corrigindo de quebra a ordem de
   dependência (os retornos 55/65/NFS-e processavam ANTES das notas);
   as linhas antigas 22-30 deslocaram +3 (25-33, mesma ordem relativa).
   TB_PEDIDO SAIU da fila e a NOTA_MERCADORIA intermediária também.
   Histórico anterior: Seq NFS-e ativa (patch 04), restaurante removido,
   carrier (38), usuário (39), serviço (40).
   Catálogo: 33 linhas = Seqs 1-16, 20-33, 38, 39, 40.
   Reservados: 17-19, 34-37, 41+.
   Bancos JÁ SEMEADOS: NÃO precisa de UPDATE manual de SEQ — o bootstrap
   impõe o SEQ canônico por (WAY, DESC_TABELA, KIND) a cada start
   (un_dm.EnforceSeqCatalogo).

   Gerado a partir do CÓDIGO REAL do Sincronizador (não é suposição):
   - uMain.pas (RegisterClass)         → CLASS_NAME (classes reais)
   - controller/ControllerTrigger.pas  → DESC_TABELA/DESC_FIELD confirmados
     (é a lista que o PRÓPRIO Delphi usa para configurar triggers — fonte
     mais confiável que a Documentacao.md, que é derivada/redigida)
   - Infra-IA/setes-sync/CONTRATOS_SYNC.md → END_POINT (rotas que EXISTEM
     hoje na setes-sync, pós Ondas 1-6)

   ⚠️ CONFIRA ANTES DE RODAR:
   - DESC_TRIGGER: NENHUM nome de trigger real foi encontrado no código-
     fonte do Sincronizador. Ficou NULL em TODAS as linhas — preencha com
     o nome real já existente no seu Firebird (ou deixe NULL se o motor
     não exige o nome, apenas SEQ/tabela para achar o registro pendente).
   - Linha com SET_ON='N' (Seq 33, CC-e): NÃO ative até a Rodada 4
     decidir/implementar — ativar quebraria com 404.
   - PK da tabela é (WAY, DESC_TABELA, KIND) — usei KIND para diferenciar
     fluxos que compartilham tabela (TB_NOTA_FISCAL serve os 5 KINDs —
     avulsa + 4 processos; TB_PRODUTO serve CADASTRO e SERVICO). SEQ não
     tem UNIQUE — é só ordem de processamento.
   ===================================================================== */

SET TERM ^ ;

/* ---------------------------------------------------------------------
   1-12: CADASTROS (ordem de prioridade D8)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_MARCA_PRODUTO', 'CADASTRO', 'Marca de produto (catálogo central)', 2,
   'MRC_CODIGO', NULL, 'Onda 3 — dedupe por descrição na setes_central (D5/D17)', 'S',
   'TBrandSendWeb', '/brand/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CATEGORY', 'CADASTRO', 'Categoria de produto/serviço (árvore)', 3,
   'ID', NULL, 'Onda 3 — id local, posit_level recalculado no servidor', 'S',
   'TCategorySendWeb', '/category/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_MEDIDA', 'CADASTRO', 'Unidade de medida (catálogo central)', 4,
   'MED_CODIGO', NULL, 'Onda 3 — endpoint NOVO (não existia na setes-sync)', 'S',
   'TMeasureSendWeb', '/measure/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_EMBALAGEM', 'CADASTRO', 'Embalagem (catálogo central)', 5,
   'EMB_CODIGO', NULL, 'Onda 3 — dedupe por descrição', 'S',
   'TPackageSendWeb', '/package/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PRODUTO', 'CADASTRO', 'Produto (product+merchandise+stock)', 6,
   'PRO_CODIGO', NULL, 'Onda 3 — id local; brand/package/measure por descrição; categoria por id (409 se ausente)', 'S',
   'TMerchandiseSendWeb', '/merchandise/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_TABELA_PRECO', 'CADASTRO', 'Tabela de preço', 7,
   'TPR_CODIGO', NULL, 'Onda 3 — id local', 'S',
   'TPriceListSendWeb', '/price-list/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PRECO', 'PRECO', 'Preço por tabela/produto', 8,
   'PRC_CODIGO', NULL, 'Onda 3 — 409 se tabela/produto ainda não sincronizados', 'S',
   'TPriceSendWeb', '/price/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_ESTOQUES', 'CADASTRO', 'Lista de estoques (depósitos)', 9,
   'ETS_CODIGO', NULL, 'Onda 3 — id local; ETS_PRINCIPAL vira coluna main', 'S',
   'TStockListSendWeb', '/stock-list/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_ESTOQUE', 'ESTOQUE', 'Saldo de estoque', 10,
   'EST_CODIGO', NULL, 'Onda 3 — achado: alvo real é tb_stock_balance (tabela própria, não tb_stock)', 'S',
   'TStockBalanceSendWeb', '/stock-balance/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PROMOTION', 'CADASTRO', 'Promoção + itens', 11,
   'ID', NULL, 'Onda 3 — items = snapshot (fora da lista = soft delete)', 'S',
   'TPromotionSendWeb', '/promotion/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PLANOCONTAS', 'CADASTRO', 'Plano de contas (árvore única)', 12,
   'PLC_CODIGO', NULL, 'Onda 3 — id local; posit_level recalculado', 'S',
   'TFinancialPlansSendWeb', '/financial-plans/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_FORMAPAGTO', 'CADASTRO', 'Forma de pagamento (catálogo central)', 13,
   'FPT_CODIGO', NULL, 'Onda 3 — idNfce só na criação; attrs do vínculo não sobrescrevem config web', 'S',
   'TPaymentTypeSendWeb', '/payment-type/sincronize')^

/* ---------------------------------------------------------------------
   13-16: PAPÉIS DE ENTIDADE (reindexação por documento/UUID — D3/D4)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CLIENTE', 'CADASTRO', 'Cliente (cadeia central + papel)', 14,
   'CLI_CODEMP', NULL, 'Onda 4 — reindexado por CPF/CNPJ ou externalCode; vendedor/transportador por documento (409 se ausente)', 'S',
   'TCustomerSendWeb', '/customer/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_FORNECEDOR', 'CADASTRO', 'Fornecedor (cadeia central + papel)', 15,
   'FOR_CODEMP', NULL, 'Onda 4 — mesmo CNPJ de um cliente cai na MESMA entity (D3)', 'S',
   'TProviderSendWeb', '/provider/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_COLABORADOR', 'CADASTRO', 'Colaborador/Vendedor (precedência Collaborator->Salesman)', 16,
   'CLB_CODIGO', NULL, 'Onda 4 — grava collaborator SEMPRE + salesman quando o bloco vem', 'S',
   'TSalesManSendWeb', '/salesman/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CONTABANCARIA', 'CADASTRO', 'Conta bancária', 17,
   'CTB_CODIGO', NULL, 'Onda 4 — bankNumber (FEBRABAN) resolvido na central; 409 se banco desconhecido. Corrige bug C1 (payload vazio)', 'S',
   'TBankAccountSendWeb', '/bank-account/sincronize')^

/* ---------------------------------------------------------------------
   17-19: PEDIDOS — REMOVIDOS (Rodada 2, D8, 2026-07-27): TB_PEDIDO saiu
   da fila de sincronia (a NOTA é o único fato gerador; Seqs 22/23/24
   substituem). O bootstrap DELETA as linhas mortas por TABELA/KIND
   (TB_PEDIDO inteira + NOTA_MERCADORIA — nunca por SEQ, reutilizado na
   renumeração) e dropa o trigger TG_SRC_PEDIDO. Seqs 17-19 RESERVADOS.
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   20-24: NOTA FISCAL — AVULSA + 4 PROCESSOS (Rodada 2, D8-D11): a NOTA
   é o fato gerador; cada KIND envia o processo COMPLETO (pedido + nota +
   ramos) para o endpoint de pedido correspondente (D10: nenhuma URL nova).
   Renumeração 2026-07-27: processos vieram de 42-45 para 21-24 (antes
   dos retornos — ordem de dependência correta).
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_AVULSA', 'Nota fiscal avulsa (tipo EM)', 20,
   'NFL_CODIGO', NULL, 'Onda 5 — destinatário por documento; CFOP = id da central (409 se desconhecido)', 'S',
   'TInvoiceSendWeb', '/invoice/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_SERVICO', 'Processo de serviço (ordem completa, incl. conjugada)', 21,
   'NFL_CODIGO', NULL, 'D13 — PED_TIPO=1 COM item PRO_TIPO=S; ordem de serviço COMPLETA: na conjugada os blocos sale/saleItems e invoice{service+merchandise} viajam juntos', 'S',
   'TInvoiceServiceSendWeb', '/order-service/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_VENDA', 'Processo de venda PURA (pedido+nota mercadoria)', 22,
   'NFL_CODIGO', NULL, 'D13 — PED_TIPO=1 SEM item de serviço (conjugada é da Seq 21); itens PRO_TIPO<>S; invoice{merchandise}', 'S',
   'TInvoiceMerchandiseSaleSendWeb', '/order-sale/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_COMPRA', 'Processo de compra (pedido+nota mercadoria)', 23,
   'NFL_CODIGO', NULL, 'D9/D10/D11 — PED_TIPO=2; issuer=N e entityDocument = fornecedor; objeto completo c/ bloco invoice{merchandise}', 'S',
   'TInvoiceMerchandisePurchaseSendWeb', '/order-purchase/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_AJUSTE', 'Processo de ajuste de estoque (pedido+nota)', 24,
   'NFL_CODIGO', NULL, 'D9/D10/D11 — PED_TIPO=3; entityDocument opcional; objeto completo c/ bloco invoice{merchandise}', 'S',
   'TInvoiceMerchandiseAdjustSendWeb', '/order-stock-adjust/sincronize')^

/* ---------------------------------------------------------------------
   25: MOVIMENTAÇÃO DE ESTOQUE (era Seq 22)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CTRL_ESTOQUE', 'MOVIMENTO', 'Movimentação de estoque', 25,
   'CET_CODIGO', NULL, 'Onda 5 — achado: PK física só id AUTO_INCREMENT no destino, pode colidir entre institutions (Rodada 4)', 'S',
   'TStockStatementSendWeb', '/stock-statement/sincronize')^

/* ---------------------------------------------------------------------
   26-28: FINANCEIRO E CAIXA (eram Seqs 23-25)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_FINANCEIRO', 'FINANCEIRO', 'Título financeiro (formato NOVO 5.5)', 26,
   'FIN_CODIGO', NULL, 'Onda 5 — PK NATURAL no destino (pedido+terminal+parcela); FIN_CODIGO NÃO vira id — semântica de ESPELHO (baixa=evento único N)', 'S',
   'TFinancialSendWeb', '/financial/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_MOVIM_FINANCEIRO', 'FINANCEIRO', 'Movimento financeiro (extrato)', 27,
   'MVF_CODIGO', NULL, 'Onda 5 — id local; conta/histórico ausentes = sentinela 0', 'S',
   'TFinancialStatementSendWeb', '/financial-statement/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CASHIER', 'FINANCEIRO', 'Abertura/fechamento de caixa', 28,
   'ID', NULL, 'Onda 5 — tb_userid fica NULL; items do caixa removidos do contrato (endpoint próprio futuro)', 'S',
   'TCashierSendWeb', '/cashier/sincronize')^

/* ---------------------------------------------------------------------
   29-31: RETORNOS DE NF-e / NFS-e (Onda 6 — eram Seqs 26-28; agora
   DEPOIS das notas de processo, ordem de dependência correta)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_RETORNO_NFE', 'RETORNO_55', 'Retorno de autorização NF-e modelo 55', 29,
   'NFE_CODIGO', NULL, 'Onda 6 — statusCode/fileName; upsert por id+institution+terminal', 'S',
   'TInvoiceReturn55SendWeb', '/invoice-return-55/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_RETORNO_NFC', 'RETORNO_65', 'Retorno de autorização NFC-e modelo 65', 30,
   'NFC_CODIGO', NULL, 'Onda 6', 'S',
   'TInvoiceReturn65SendWeb', '/invoice-return-65/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_RETORNO_NFS', 'RETORNO_NFSE', 'Retorno de autorização NFS-e', 31,
   'NFS_CODNFL', NULL, 'Patch 04 (C3) APLICADO 2026-07-25: classe criada (invoice_return_service_send_web.pas) e registrada no uMain. Endpoint Onda 6', 'S',
   'TInvoiceReturnServiceSendWeb', '/invoice-return-service/sincronize')^

/* ---------------------------------------------------------------------
   32: ARQUIVO XML (Onda 6 — disco, não mais banco; era Seq 29)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_ARQUIVOS', 'ARQUIVO', 'XML da nota fiscal (conteúdo completo em Base64)', 32,
   'ARQ_CODIGO', NULL, 'C7: enviar contentBase64 completo (não só metadados). Grava em disco <cnpj>/<ano>/<mes> no servidor (D9/D20)', 'S',
   'TFileSendWeb', '/filexml/sincronize')^

/* ---------------------------------------------------------------------
   33: CARTA DE CORREÇÃO (era Seq 30) — GAP ENCONTRADO NA ONDA 0
   Classe registrada em uMain.pas mas SEM endpoint na setes-sync.
   NÃO ATIVAR — decisão/implementação fica para a Rodada 4.
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_CARTA_CORRECAO', 'RETIFICACAO', 'Carta de Correção Eletrônica (CC-e)', 33,
   'CCE_CODIGO', NULL, 'ACHADO DA ONDA 0: classe existe no Delphi mas o endpoint NÃO foi implementado nas Ondas 1-6 — fica para a Rodada 4', 'N',
   'TInvoiceRectificationSendWeb', '/invoice-rectification/sincronize')^

/* ---------------------------------------------------------------------
   34-37: RESERVADOS — o módulo restaurante (D23, 7 linhas TB_REST_*,
   antigas Seqs 31-37) foi REMOVIDO do catálogo (Valdo, 2026-07-26); o
   bootstrap DELETA as linhas por DESC_TABELA LIKE 'TB_REST_%' (por isso
   as Seqs 31-33 puderam ser reutilizadas na renumeração de 2026-07-27).
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   38-39: TRANSPORTADORA E USUÁRIO (revisões de 2026-07-25/26)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_TRANSPORTADORA', 'CADASTRO', 'Transportadora (cadeia central + papel)', 18,
   'TRP_CODEMP', NULL, 'Decisão 4 (2026-07-25) — fecha o 409 CARRIER_NOT_SYNCED eterno do customer; sincronizar ANTES do cliente', 'S',
   'TCarrierSendWeb', '/carrier/sincronize')^

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_USUARIO', 'CADASTRO', 'Usuário do sistema (autor das operações)', 1,
   'USU_CODIGO', NULL, 'Decisões 1-3 (2026-07-26) — entity + tb_user sem credencial; cascata colaborador->externalCode; perfil PDV desliga (decisão 8)', 'S',
   'TUserSendWeb', '/user/sincronize')^

/* ---------------------------------------------------------------------
   40: SERVIÇO (prompt_notas_mercadoria_servico.md, D2, 2026-07-26)
   --------------------------------------------------------------------- */

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PRODUTO', 'SERVICO', 'Serviço (product kind S)', 19,
   'PRO_CODIGO', NULL, 'D2 — PRO_TIPO=S vira SÓ tb_product (kind S); P/M continuam na Seq 5; A (cardápio) aposentado não sincroniza', 'S',
   'TServiceSendWeb', '/service/sincronize')^

/* 41+: RESERVADOS — 41 PEDIDO_SERVICO (patch 06) morreu na Rodada 2 (D8:
   o processo de serviço inteiro vive na Seq 21); 42-45 eram os processos
   de nota ANTES da renumeração de 2026-07-27 (foram para 21-24 — o
   enforcement do bootstrap renumera bancos já semeados sozinho). */

SET TERM ; ^

COMMIT;

/* ---------------------------------------------------------------------
   Conferência pós-INSERT
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN SET_ON='S' THEN 1 ELSE 0 END) AS ATIVAS
FROM TB_LISTA_SINCRONIA;
-- Esperado: TOTAL=33, ATIVAS=32
--   Seqs presentes: 1-19 (19: usuario PRIMEIRO na Seq 1; carrier 18 e servico 19 ANTES das notas — reordenacoes Valdo 2026-07-27) + 20-33 (14) = 33
--   (12 cadastros + 4 papéis + avulsa + 4 processos de nota + estoque
--    + 3 financeiro/caixa + retorno-55 + retorno-65 + retorno-NFSe
--    + filexml + rectification + carrier + usuário + serviço = 33)
--   INATIVA=1: Seq 33 rectification (CC-e — gap da Onda 0, Rodada 4)
--   Reservados: 34+
