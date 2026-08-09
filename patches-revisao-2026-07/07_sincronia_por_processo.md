# Patch 07 — Sincronia por PROCESSO (Rodada 2 da fase Notas Mercadoria × Serviço, D8–D11)

> ## ⚠️ SUPERADO EM PARTE pelo patch 08 (D13, 2026-07-27)
>
> As menções à **mecânica `[KIND]`** ("NOTA_VENDA e NOTA_SERVICO disparam
> sobre o MESMO registro — a mecânica [KIND] sustenta") estão SUPERADAS: a
> conjugada agora viaja INTEIRA por UM envio (Seq 21 NOTA_SERVICO →
> /order-service com sale/saleItems/invoice.merchandise) e a marca no
> SRC_LOG voltou a ser ÚNICA, só de quem envia. Ver `08_fila_marca_unica.md`.

> ## ✅ APLICADO em 2026-07-27 (Claude Code)
>
> Spec: `Infra-IA/setes-sync/prompt_notas_mercadoria_servico.md`, seção
> "Rodada 2 — Sincronia por PROCESSO (D8–D11)". Parte do estado do patch 06
> (fila por [KIND], `getListByNFPorNatureza`, `VerificaProduto`).
> **A NOTA vira o único fato gerador**: TB_PEDIDO sai da fila (D8), cada
> envio carrega pedido + nota + ramos num objeto completo (D9), para os
> endpoints de pedido JÁ existentes com bloco `invoice` novo (D10 — a web
> já aceita e grava tudo na mesma transação, smoke-testado), via hierarquia
> de classes sobre a nota avulsa (D11). **Aguarda compilação do Valdo** +
> SQL manual em bancos já semeados (abaixo).
>
> ## 🔁 RENUMERADO em 2026-07-27 (decisão do Valdo)
>
> Os processos de nota SUBIRAM para logo após a avulsa — **21 NOTA_SERVICO,
> 22 NOTA_VENDA, 23 NOTA_COMPRA, 24 NOTA_AJUSTE** (eram 42-45) — o que de
> quebra corrige a ordem de dependência: os retornos 55/65/NFS-e
> processavam ANTES das notas. As linhas antigas 22-30 deslocaram +3
> (25-33, mesma ordem relativa; CC-e segue SET_ON='N'). Catálogo final:
> **33 linhas = Seqs 1-16, 20-33, 38, 39, 40**; reservados 17-19, 34-37,
> 41+. Bancos já semeados se renumeram SOZINHOS: o bootstrap ganhou
> **enforcement idempotente do SEQ por (WAY, DESC_TABELA, KIND)** a cada
> start (`un_dm.EnforceSeqCatalogo`) — o SQL manual abaixo foi consolidado
> (só os INSERTs das linhas novas, já na numeração final).

## A hierarquia (D11)

```
TInvoiceSendWeb (avulsa — Seq 20 → /invoice, INTOCADA no comportamento)
  ├─ TInvoiceMerchandiseSendWeb          (INTERMEDIÁRIA — sem catálogo, sem registro)
  │    ├─ TInvoiceMerchandiseSaleSendWeb     (Seq 22 NOTA_VENDA  → /order-sale)
  │    ├─ TInvoiceMerchandisePurchaseSendWeb (Seq 23 NOTA_COMPRA → /order-purchase)
  │    └─ TInvoiceMerchandiseAdjustSendWeb   (Seq 24 NOTA_AJUSTE → /order-stock-adjust)
  └─ TInvoiceServiceSendWeb              (Seq 21 NOTA_SERVICO → /order-service)
```

- Os irmãos de mercadoria só variam o **PED_TIPO** (1/2/3, filtrado no
  `getSincronia` via `TipoPedido`), o **bloco do ramo** (sale/purchase/
  adjust) e **quais blocos opcionais viajam** (compra sem billing/listas;
  ajuste sem totalizer/billing/listas). O endpoint vem do catálogo.
- Payload completo: raiz `{id=NFL_CODIGO, terminal, deleted}` + `order` +
  ramo do pedido + `items` (filtrados por natureza) + `totalizer`/`billing`/
  `user` + `invoice{campos do /invoice sem id/terminal/deleted + sub-bloco
  merchandise|service}`.
- Conjugado: NOTA_VENDA (22) e NOTA_SERVICO (21) disparam sobre o MESMO
  registro — a mecânica `[KIND]` do SRC_LOG (patch 06) sustenta.

## Decisões tomadas onde a spec deixou aberto

1. **"Objeto completo" legado (D9) — NÃO reusado como serializador**:
   `TInvoiceDetachedSendWeb`/`FillDataObjetoDetached` NÃO serializam o
   processo inteiro — o Detached preenche só o bloco Nota (com resolução
   de CFOP via TB_NATUREZA) + observações. Essa parte **continua
   reaproveitada** (é o que alimenta `AddInvoiceBaseFields`); o resto do
   payload (pedido/itens/totalizer/billing/user) foi ABSORVIDO das
   `TOrder*SendWeb` e montado direto dos models — mesmo motivo do patch 06
   (typo no getter de ValorIcmsSt do model de destino). O arquivo
   `invoice_detached_send_web.pas` (legado, nunca registrado) ficou
   intocado.
2. **Arquivos aposentados = REMOVIDOS** (precedente dos `rest_*`):
   `order_sale_send_web.pas`, `order_purchase_send_web.pas`,
   `order_stock_adjust_send_web.pas`, `order_service_send_web.pas`
   deletados; comentário de registro histórico no `initialization` do
   uMain. `invoice_merchandise_send_web.pas` PERMANECE (é a intermediária).
3. **Helpers de processo vivem na BASE (`TInvoiceSendWeb`)**: os blocos de
   pedido (`AddOrderBlock`/`AddItemsBlock`/`AddTotalizerBlock`/
   `AddBillingBlock`/`AddUserBlock`/`CarregaItens`) são `protected` na
   avulsa porque a `TInvoiceServiceSendWeb` herda DIRETO dela (letra do
   D11) e também precisa deles — sem isso o serviço duplicaria tudo da
   intermediária. A avulsa nunca os chama (EM = nota sem itens).
4. **`TInvoiceServiceSendWeb` filtra PED_TIPO=1**: domínio da spec
   ("pedido de serviço é PED_TIPO=1"); compra/ajuste jamais viram processo
   de serviço (o `service.customerDocument` seria o fornecedor — errado).
5. **Trigger real é `TG_SRC_PEDIDO`** (não "TG_SRC_TB_PEDIDO" como no
   rascunho da tarefa): `EnsureTriggers` remove o prefixo `TB_` ao gerar o
   nome — o DROP do bootstrap e o SQL manual usam o nome real.
6. **Correção de tabela herdada de graça**: as `TOrder*SendWeb` passavam
   `PED_CODIGO` ao `getListByNFPorNatureza`, que filtra por `ITF_CODNFL`
   (código da NOTA) — itens só apareciam quando os códigos coincidiam.
   Na hierarquia nova o vínculo é o `NFL_CODIGO` real.
7. **Fila órfã de TB_PEDIDO limpa no bootstrap**: sem KIND no catálogo, as
   linhas pendentes de TB_PEDIDO em TB_SINCRONIA nunca mais seriam
   consumidas nem limpas (a limpeza de 48h só pega SRC_LOG OK) —
   `DELETE FROM TB_SINCRONIA WHERE SRC_TABELA='TB_PEDIDO'` a cada start.
8. **Enforcement do SEQ no bootstrap (renumeração 2026-07-27)**: o seed
   continua rodando só com a tabela VAZIA, mas em banco já semeado o
   `SeedListaSincroniaIfEmpty` agora chama `EnforceSeqCatalogo` — para
   cada linha do catálogo canônico, `UPDATE ... SET SEQ = <canônico>
   WHERE WAY/DESC_TABELA/KIND = ... AND COALESCE(SEQ,-1) <> <canônico>`.
   **Fase única** (sem `SEQ = SEQ + 1000` intermediário): a PK da tabela é
   `(WAY, DESC_TABELA, KIND)` e SEQ não tem PK/UNIQUE/índice — duplicidade
   transitória de SEQ durante o loop não viola constraint e ao final todos
   os SEQs canônicos são únicos; UPDATE de 0 linhas = no-op idempotente.
   Consequência: as linhas MORTAS não podem mais ser deletadas por SEQ
   (o 21 antigo da NOTA_MERCADORIA foi reutilizado pela NOTA_SERVICO) —
   os DELETEs do bootstrap viraram por TABELA/KIND (`TB_PEDIDO` inteira +
   `TB_NOTA_FISCAL`/`NOTA_MERCADORIA`). Só os **INSERTs** das linhas
   novas continuam manuais (abaixo).

## O que mudou, arquivo a arquivo

### `classes/invoice_send_web.pas` (BASE — comportamento da avulsa intocado)
- `FCtrl` foi de `private` para `protected`; JSON da avulsa idêntico ao
  anterior (mesmos pares, mesma ordem), agora montado com
  `AddInvoiceBaseFields` (campos do /invoice sem id/terminal/deleted).
- `IssuerFlag` virtual (regra EE/EM → 'S' preservada; compra sobrescreve).
- Helpers `protected` de processo: `CarregaItens` (guarda o total
  `FItensNota` antes do refiltro por natureza — totalizer do conjugado leva
  o TOTAL, patch 06), `AddOrderBlock`, `AddItemsBlock(IncluiListas)`,
  `AddTotalizerBlock`, `AddBillingBlock` (lookup FormaPagto), `AddUserBlock`
  (cascata `DM.GetUserSyncRef` de PED_CODUSU).

### `classes/invoice_merchandise_send_web.pas` (vira INTERMEDIÁRIA)
- Herda de `TInvoiceSendWeb`; SEM linha no catálogo e SEM RegisterClass.
- Template `GenerateJson`: `NotaAvulsa=False` + `TipoPedido=PedTipo`
  (filtro novo no `getSincronia`) → skip de mercadoria do patch 06
  (`ValorProdutos<=0` e não `VerificaProduto`) → `FillDataObjetoDetached`
  (nota+pedido) → `CarregaItens(False)` → raiz + order + `AddRamoPedido`
  (abstrato) + items + totalizer/billing (flags virtuais) + user +
  `AddInvoiceBlock` (invoice{base+merchandise — mesmo bloco do patch 06,
  lido direto do model}).
- Virtuais dos filhos: `PedTipo`, `AddRamoPedido` (abstratos);
  `UsaListasDeItem`/`UsaTotalizer`/`UsaBilling` (default True = venda).

### `classes/invoice_merchandise_sale_send_web.pas` (NOVA — Seq 22)
- `PedTipo=1`; bloco `sale {number, customerDocument, salesmanDocument}`
  (documentos via `DM.GetDocumentByEmpCodigo` de PED_CODEMP/PED_CODVDO).

### `classes/invoice_merchandise_purchase_send_web.pas` (NOVA — Seq 23)
- `PedTipo=2`; bloco `purchase {number, providerDocument, approved}`;
  sem billing/listas de item; `IssuerFlag='N'` (nota emitida pelo
  fornecedor; `entityDocument` da base já é o fornecedor — NFL_CODEMP).

### `classes/invoice_merchandise_adjust_send_web.pas` (NOVA — Seq 24)
- `PedTipo=3`; bloco `adjust {number, entityDocument opcional}`; sem
  totalizer/billing/listas; TODO do `direction` (E/S) herdado — sem fonte
  no Firebird (Rodada 4).

### `classes/invoice_service_send_web.pas` (REESCRITA — Seq 21)
- Herda da AVULSA (D11); `TipoPedido=1`; skip de serviço do patch 06
  (`ValorServico<=0` e não `VerificaServico`); payload completo com
  `service {number, customerDocument}` + items PRO_TIPO='S' (sem listas)
  + totalizer/billing/user + `invoice{base + service{totalValue=
  NFL_VL_TL_SRV}}`. Endpoint muda no catálogo: `/invoice-service` →
  `/order-service`.

### `classes/order_*_send_web.pas` (4 arquivos) — REMOVIDOS
- `TOrderSaleSendWeb`, `TOrderPurchaseSendWeb`, `TOrderStockAdjustSendWeb`,
  `TOrderServiceSendWeb` aposentadas (payloads absorvidos pela hierarquia).
- `/invoice-merchandise` e `/invoice-service` PERMANECEM na web como canal
  de nota isolada (reenvio avulso), mas SAEM do catálogo do Delphi (D10).

### `origen/controller/ControllerNotaFiscal.pas`
- `getSincronia` (ramo NotaAvulsa=False): com `TipoPedido > 0` ganha
  `AND (P.PED_TIPO=:PED_TIPO)` no join já existente — é o ÚNICO WHERE que
  varia entre os irmãos (D11). `TipoPedido=0` = comportamento antigo.

### `origen/controller/ControllerSincronia.pas` (catch-up)
- `SqlTBPedidoAtualiza`/`SqlTBPedidoDeleta` REMOVIDAS (D8) + ramos
  TB_PEDIDO de `getSqlAtualiza`/`getSqlDeleta` removidos.
- `SqlTBNotaFiscalAtualiza`/`Deleta`: NOTA_AVULSA → `nfl_tipo='EM'`;
  NOTA_VENDA/NOTA_COMPRA/NOTA_AJUSTE → `nfl_tipo<>'EM'` + INNER JOIN
  TB_PEDIDO por NFL_CODPED com `ped_tipo` 1/2/3 (`KindNotaProcesso` +
  `KindToPedTipo` remapeado para KINDs de nota); NOTA_SERVICO →
  `nfl_tipo<>'EM'` sem join (a classe filtra).
- `saveReturn`: mecânica `[KIND]` MANTIDA (conjugado = NOTA_VENDA e
  NOTA_SERVICO no mesmo registro), condição reduzida a TB_NOTA_FISCAL.

### `function/un_sincronia_seed.pas` + espelho `00b_seed_tb_lista_sincronia.sql`
- Array `[0..34]` → `[0..32]` (35 → **33 linhas**).
- REMOVIDAS (KINDs): PEDIDO_VENDA, PEDIDO_COMPRA, AJUSTE_ESTOQUE (as três
  de TB_PEDIDO), NOTA_MERCADORIA, PEDIDO_SERVICO (criada no patch 06 e já
  superada).
- NOTA_SERVICO: endpoint `/invoice-service/sincronize` →
  **`/order-service/sincronize`** (classe continua TInvoiceServiceSendWeb).
- NOVAS: NOTA_VENDA (TInvoiceMerchandiseSaleSendWeb → /order-sale),
  NOTA_COMPRA (TInvoiceMerchandisePurchaseSendWeb → /order-purchase),
  NOTA_AJUSTE (TInvoiceMerchandiseAdjustSendWeb → /order-stock-adjust).
- **Numeração final (renumeração 2026-07-27)**: 20 NOTA_AVULSA,
  **21 NOTA_SERVICO, 22 NOTA_VENDA, 23 NOTA_COMPRA, 24 NOTA_AJUSTE**,
  25 MOVIMENTO (estoque), 26-28 FINANCEIRO (título/extrato/caixa),
  29 RETORNO_55, 30 RETORNO_65, 31 RETORNO_NFSE, 32 ARQUIVO,
  33 RETIFICACAO ('N'); 38-40 inalteradas.
- Aritmética: Seqs 1–16 (16) + 20–33 (14) + 38/39/40 (3) = **33**
  (32 ativas; só a Seq 33/CC-e segue 'N'). Conferida nos dois arquivos
  (33 registros no .pas, 33 INSERTs no .sql).

### `un_dm.pas` (bootstrap)
- `TriggerExiste` NOVO (molde GeneratorExiste — Firebird 2.5/5.0 não tem
  DROP TRIGGER IF EXISTS).
- `SeedListaSincroniaIfEmpty` (a cada start, mesmo padrão TB_REST_*):
  - `DELETE FROM TB_LISTA_SINCRONIA WHERE DESC_TABELA='TB_PEDIDO'` +
    `DELETE ... WHERE DESC_TABELA='TB_NOTA_FISCAL' AND KIND='NOTA_MERCADORIA'`
    (por TABELA/KIND — nunca por SEQ, reutilizado na renumeração);
  - `DROP TRIGGER TG_SRC_PEDIDO` se existir (com as linhas fora do
    catálogo, `EnsureTriggers` não o recria);
  - `DELETE FROM TB_SINCRONIA WHERE SRC_TABELA='TB_PEDIDO'` (fila órfã);
  - banco já semeado → **`EnforceSeqCatalogo`** (decisão 8 acima): impõe o
    SEQ canônico por (WAY, DESC_TABELA, KIND), fase única, idempotente.
- Perfil PDV inalterado (Seqs 21–24 são movimento — ficam 'S'; o UPDATE do
  perfil desliga SEQ 1-16 e 38/39/40, intocados pela renumeração).

### `uMain.pas`
- `uses`: saem as 4 units `order_*_send_web` e a
  `invoice_merchandise_send_web` (intermediária não é registrada); entram
  as 3 units novas.
- RegisterClass/UnRegisterClass ESPELHADOS: +TInvoiceMerchandiseSaleSendWeb,
  +TInvoiceMerchandisePurchaseSendWeb, +TInvoiceMerchandiseAdjustSendWeb;
  −TInvoiceMerchandiseSendWeb, −TOrderSaleSendWeb, −TOrderPurchaseSendWeb,
  −TOrderServiceSendWeb, −TOrderStockAdjustSendWeb.
  (TInvoiceServiceSendWeb continua registrada — foi reescrita.)

## Bancos JÁ semeados — SQL manual NECESSÁRIO (consolidado 2026-07-27)

O bootstrap faz sozinho, no próximo start: os DELETEs das linhas mortas
(TB_PEDIDO + NOTA_MERCADORIA, por TABELA/KIND), o DROP do trigger, a
limpeza da fila órfã **e a renumeração inteira** (`EnforceSeqCatalogo`
impõe o SEQ canônico por WAY+DESC_TABELA+KIND — a antiga "UPDATE Seq 42"
deste patch morreu; qualquer resíduo de numeração velha é corrigido
automaticamente). O que ele NÃO faz (seed só roda com tabela vazia) é
criar as linhas novas — rodar na mão em cada banco dev/cliente, já com a
**numeração final**:

```sql
/* UPDATE OR INSERT (Firebird 2.1+): idempotente pela PK (WAY, DESC_TABELA,
   KIND) — cobre tanto banco sem as linhas quanto banco que já rodou a
   versão anterior deste patch (NOTA_SERVICO com Seq 42 / endpoint
   /invoice-service vira Seq 21 / /order-service). */

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_SERVICO', 'Processo de servico (pedido+nota, ramo do conjugado)', 21,
   'NFL_CODIGO', NULL, 'D9/D10/D11 - envia quando NFL_VL_TL_SRV > 0 OU ha item PRO_TIPO=S; objeto completo c/ bloco invoice{service}; conjugado dispara Seqs 22 e 21 no MESMO id', 'S',
   'TInvoiceServiceSendWeb', '/order-service/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_VENDA', 'Processo de venda (pedido+nota mercadoria)', 22,
   'NFL_CODIGO', NULL, 'D9/D10/D11 - PED_TIPO=1 (join NFL_CODPED); itens PRO_TIPO<>S; invoice{merchandise}', 'S',
   'TInvoiceMerchandiseSaleSendWeb', '/order-sale/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_COMPRA', 'Processo de compra (pedido+nota mercadoria)', 23,
   'NFL_CODIGO', NULL, 'D9/D10/D11 - PED_TIPO=2; issuer=N; entityDocument = fornecedor; invoice{merchandise}', 'S',
   'TInvoiceMerchandisePurchaseSendWeb', '/order-purchase/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

UPDATE OR INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_AJUSTE', 'Processo de ajuste de estoque (pedido+nota)', 24,
   'NFL_CODIGO', NULL, 'D9/D10/D11 - PED_TIPO=3; entityDocument opcional; invoice{merchandise}', 'S',
   'TInvoiceMerchandiseAdjustSendWeb', '/order-stock-adjust/sincronize')
MATCHING (WAY, DESC_TABELA, KIND);

COMMIT;
```

Se preferir NÃO esperar o próximo start do Sincronizador, o mesmo efeito do
bootstrap na mão (deleções + renumeração das linhas antigas 22-30 → 25-33):

```sql
DELETE FROM TB_LISTA_SINCRONIA WHERE DESC_TABELA = 'TB_PEDIDO';
DELETE FROM TB_LISTA_SINCRONIA
 WHERE DESC_TABELA = 'TB_NOTA_FISCAL' AND KIND = 'NOTA_MERCADORIA';
DROP TRIGGER TG_SRC_PEDIDO;                          /* se existir */
DELETE FROM TB_SINCRONIA WHERE SRC_TABELA = 'TB_PEDIDO';
/* deslocamento +3 das linhas antigas (ordem decrescente — SEQ nao tem
   UNIQUE, mas evita cruzar com 25 já ocupado se rodar duas vezes) */
UPDATE TB_LISTA_SINCRONIA SET SEQ = 33 WHERE DESC_TABELA = 'TB_CARTA_CORRECAO'   AND KIND = 'RETIFICACAO';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 32 WHERE DESC_TABELA = 'TB_ARQUIVOS'         AND KIND = 'ARQUIVO';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 31 WHERE DESC_TABELA = 'TB_RETORNO_NFS'      AND KIND = 'RETORNO_NFSE';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 30 WHERE DESC_TABELA = 'TB_RETORNO_NFC'      AND KIND = 'RETORNO_65';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 29 WHERE DESC_TABELA = 'TB_RETORNO_NFE'      AND KIND = 'RETORNO_55';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 28 WHERE DESC_TABELA = 'TB_CASHIER'          AND KIND = 'FINANCEIRO';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 27 WHERE DESC_TABELA = 'TB_MOVIM_FINANCEIRO' AND KIND = 'FINANCEIRO';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 26 WHERE DESC_TABELA = 'TB_FINANCEIRO'       AND KIND = 'FINANCEIRO';
UPDATE TB_LISTA_SINCRONIA SET SEQ = 25 WHERE DESC_TABELA = 'TB_CTRL_ESTOQUE'     AND KIND = 'MOVIMENTO';
COMMIT;
```

Conferência final esperada: `SELECT COUNT(*) FROM TB_LISTA_SINCRONIA` =
**33** (32 ativas; Seq 33/CC-e 'N'); Seqs = 1-16, 20-33, 38, 39, 40.
PDV: nada a fazer (21–24 são movimento).

## Pendências

1. **Valdo**: compilar o Sincronizador — 3 units novas
   (`invoice_merchandise_sale/purchase/adjust_send_web.pas`) e 4 removidas;
   como o .dpr não lista as classes de envio (resolvem por search path,
   mesmo caso do patch 06), em princípio basta recompilar.
2. **Valdo**: SQL manual acima nos bancos dev/cliente já semeados.
3. **Teste ponta a ponta** com a setes-sync desta sessão no ar: nota de
   venda pura → /order-sale com invoice; conjugada → /order-sale +
   /order-service no MESMO id (2 marcas [KIND] no SRC_LOG); compra →
   /order-purchase (issuer N); ajuste → /order-stock-adjust; avulsa (EM)
   → /invoice intocada.
4. Pedido editado após faturamento sem tocar a nota NÃO reenvia (perda
   aceita — Q4/D8); se doer na prática, o gatilho de reenvio teria de vir
   de um toque na nota.
