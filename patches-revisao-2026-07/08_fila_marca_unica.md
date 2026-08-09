# Patch 08 — Fila de marca ÚNICA (Rodada 3 da fase Notas Mercadoria × Serviço, D13)

> ## ✅ APLICADO em 2026-07-27 (Claude Code)
>
> Spec: `Infra-IA/setes-sync/prompt_notas_mercadoria_servico.md`, seção
> "Rodada 3 — Correção da mecânica de fila (D13)". Correção do Valdo sobre
> os patches 06/07: **a mecânica `[KIND]` no SRC_LOG foi um ERRO DE
> ENTENDIMENTO e foi REMOVIDA**. Conceito correto: "guarda o registro
> alterado via tb_sincronia, mas efetua a sincronia através de PROCESSOS
> definidos nas classes executadas na factory" — a marca no SRC_LOG é
> **ÚNICA por registro e só de quem ENVIA**. **Aguarda compilação do
> Valdo**; SQL manual: **NENHUM** (ver seção própria).

## O conceito (D13)

- Uma classe cujo filtro NÃO casa com o registro "não tem nada pra enviar":
  ela **não marca o SRC_LOG e não loga erro** — o registro continua pendente
  para as classes seguintes do mesmo ciclo.
- Quem ENVIA (sucesso **ou** erro HTTP) grava o SRC_LOG como sempre
  (mensagem simples, sem prefixo).
- Isso funciona porque os filtros são **DISJUNTOS** — exatamente UMA classe
  reivindica cada registro. A nota CONJUGADA deixou de disparar duas classes:
  ela entra **INTEIRA por UM envio** (Seq 21 NOTA_SERVICO → /order-service,
  com os itens de mercadoria a bordo).
- Registro que **nenhuma** classe reivindica (ex.: PRO_TIPO='A', nota de
  processo sem pedido) fica sem marca e **PERMANECE na fila para
  verificação** (revisão do Valdo 2026-07-27 — a limpeza só remove
  >48h com envio OK) — nunca é "marcado como processado".

## Filtros finais (classe × filtro — Delphi e catch-up ALINHADOS)

| Seq | KIND | Classe | Filtro (disjunto) |
|---|---|---|---|
| 5 | CADASTRO | TMerchandiseSendWeb | TB_PRODUTO · PRO_TIPO IN ('P','M') |
| 40 | SERVICO | TServiceSendWeb | TB_PRODUTO · PRO_TIPO = 'S' |
| 20 | NOTA_AVULSA | TInvoiceSendWeb | NFL_TIPO = 'EM' |
| 21 | NOTA_SERVICO | TInvoiceServiceSendWeb | PED_TIPO=1 **E** nota COM item PRO_TIPO='S' (VerificaServico / EXISTS) |
| 22 | NOTA_VENDA | TInvoiceMerchandiseSaleSendWeb | PED_TIPO=1 **E** nota SEM item PRO_TIPO='S' (venda PURA / NOT EXISTS) |
| 23 | NOTA_COMPRA | TInvoiceMerchandisePurchaseSendWeb | PED_TIPO=2 |
| 24 | NOTA_AJUSTE | TInvoiceMerchandiseAdjustSendWeb | PED_TIPO=3 |

(PRO_TIPO='A' e nota `nfl_tipo<>'EM'` sem pedido: órfãos — permanecem na
fila para verificação, revisão do Valdo 2026-07-27.)

## O que foi REVERTIDO do patch 06

Em `origen/controller/ControllerSincronia.pas`:

- **`saveReturn`**: o ramo TB_NOTA_FISCAL que acumulava `[KIND]resultado`
  (SUBSTRING || concat, marca por KIND, truncagem em 60 chars) foi removido —
  voltou ao UPDATE simples `src_log = :src_log` para TODAS as tabelas.
- **`SqlKindPendente` REMOVIDA** (pendência por `NOT LIKE '%[KIND]%'`) — a
  pendência voltou ao formato pré-patch-06: `SRC_LOG is null or = ''`.
- **`DeleteProcessadosAntigos`**: o critério `%]OK%` morreu junto; regra
  final (revisão do Valdo): só remove >48h com `SRC_LOG='OK'` — ver
  "Limpeza da fila" abaixo.

O que **FICOU** do patch 06: a fila DISJUNTA de TB_PRODUTO por PRO_TIPO
(`SqlTBProdutoAtualiza/Deleta`) — ela expressa o filtro disjunto no catch-up
e não conflita com a marca única; `getListByNFPorNatureza`, `VerificaProduto`
e as correções D7 também permanecem.

## Marca só de quem envia — mecânica no motor

- **`classes/general_web.pas`**: campo protected `FSkip` + property pública
  `Skip`. O `send()` reseta `FSkip`/`FExternalCode`/`FClearExternalCode` por
  registro (de quebra corrige um vazamento: no skip, o externalCode do
  registro ANTERIOR podia sobrar e o write-back iria para a linha errada) e,
  se `GenerateJson` marcou `FSkip`, retorna SEM disparar HTTP e SEM levantar
  o erro "Não foi possivel gerar json".
- **`function/un_send_to_web_server.pas` (`SyncTable`)**: o bloco `Finally`
  só grava `saveReturn` + checkpoint (`SetLastUpdate`) quando
  `not LcSendWeb.Skip` — skip não marca SRC_LOG, não loga erro, não avança
  checkpoint; a barra de progresso segue normal.
- **Classes** — exits de filtro passaram a marcar `FSkip := True`:
  - `invoice_send_web.pas` (avulsa): registro fora do filtro EM/ausente;
  - `invoice_merchandise_send_web.pas` (intermediária): not exist ·
    `FiltroDisjuntoOk` (virtual, novo) · sem parte mercadoria · sem pedido;
  - `invoice_merchandise_sale_send_web.pas`: override `FiltroDisjuntoOk =
    not FCtrl.VerificaServico` (venda PURA);
  - `invoice_service_send_web.pas`: not exist · `not VerificaServico` ·
    sem pedido;
  - `merchandise_send_web.pas` / `service_send_web.pas`: PRO_TIPO fora do
    domínio da classe.
  Registro genuinamente quebrado nas DEMAIS classes (cadastros etc.) mantém
  o comportamento antigo (mensagem de erro no SRC_LOG).

## Payload NOVO da NOTA_SERVICO (ordem de serviço COMPLETA)

`TInvoiceServiceSendWeb` → `/order-service/sincronize` (contrato em
`CONTRATOS_SYNC.md`, já aceito pela web): raiz `{id=NFL_CODIGO, terminal,
deleted}` + `order` + `service{number, customerDocument}` + `items`
(PRO_TIPO='S', sem listas) + **quando a nota TEM parte mercadoria**
(`ValorProdutos > 0 OU VerificaProduto`): `sale{number, salesmanDocument}` +
`saleItems` (PRO_TIPO≠'S', COM stockListId/priceListId — espelhos dos blocos
do /order-sale) + `totalizer`/`billing`/`user` + `invoice{base +
service{totalValue=NFL_VL_TL_SRV} [+ merchandise{...} na conjugada]}`.

Reuso de helpers (nada duplicado):

- `AddItemsBlock` ganhou o parâmetro `NomeBloco` (default `'items'`) — o
  mesmo builder monta `items` e `saleItems`;
- o sub-bloco `merchandise` do bloco `invoice` SUBIU da intermediária para a
  BASE (`TInvoiceSendWeb.AddMerchandiseRamo`) — a intermediária e a
  conjugada usam o MESMO código;
- `getListByNFPorNatureza` refiltra a lista (serviço → mercadoria) DEPOIS de
  `CarregaItens(True)` guardar o total em `FItensNota` (totalizer segue com
  a contagem TOTAL da nota).

## Catch-up alinhado (fila disjunta)

`SqlTBNotaFiscalAtualiza/Deleta`:

- `KindNotaProcesso` passou a incluir **NOTA_SERVICO** (join TB_PEDIDO,
  `ped_tipo=1` via `KindToPedTipo`);
- novo `SqlItemServico(Kind)`: NOTA_SERVICO → `AND EXISTS (SELECT 1 FROM
  TB_ITENS_NFL IT INNER JOIN TB_PRODUTO PR ... AND PR.PRO_TIPO='S')`;
  NOTA_VENDA → `AND NOT EXISTS (...)`; demais KINDs → vazio. EXISTS com
  subselect roda igual no Firebird 2.5 e 5.0;
- NOTA_AVULSA (`nfl_tipo='EM'`) e COMPRA/AJUSTE (`ped_tipo` 2/3) como já
  estavam.

## Limpeza da fila (REVISADA pelo Valdo em 2026-07-27)

`DeleteProcessadosAntigos` apaga **somente registro com SRC_TIME > 48h E
envio OK (`SRC_LOG = 'OK'`)**. QUALQUER outra coisa PERMANECE na fila para
verificação: erros persistentes (409 etc.), pendentes (sincronizador
desligado por dias) e órfãos que nenhuma classe reivindica (PRO_TIPO='A',
nota sem pedido — SRC_LOG null). A versão intermediária deste patch
(limpeza por idade sem olhar o SRC_LOG) foi DESCARTADA pelo Valdo:
a fila retida é ferramenta de diagnóstico, não lixo. Consequência
consciente: órfãos e erros acumulam até inspeção/correção manual —
são exatamente o que se quer enxergar.

## Ordem de execução — USUÁRIO primeiro (revisão do Valdo, 2026-07-27)

O usuário (TB_USUARIO → /user/sincronize) subiu da Seq 39 para a **Seq 1** —
ele é a referência do bloco `user` de TODOS os movimentos; subir antes de
tudo reduz os 409 USER_NOT_SYNCED. Os cadastros antigos 1–16 empurraram
para **2–17**. Na sequência (mesma revisão), **transportadora (era 38) e
produto-serviço (era 40) vieram para 18/19**: são cadastros básicos — sem
eles as notas não podem ser usadas — e estavam DEPOIS do bloco de
movimento. Catálogo final: **33 linhas CONTÍGUAS = Seqs 1–19 (cadastros) +
20–33 (movimento)**; reservados 34+. Bancos já semeados se renumeram
sozinhos (`EnforceSeqCatalogo` por TABELA/KIND). **Perfil PDV corrigido
junto**: o UPDATE que desligava cadastros por faixa fixa (`1–16, 38–40`)
quebraria com a renumeração — virou `SEQ NOT BETWEEN 20 AND 33` (desliga
tudo que não é movimento, robusto a renumerações futuras). O INSERT manual
da Seq 39 do `prompt_indexacao_usuario_firebird.md` fica SUPERADO (usar
MATCHING por WAY/DESC_TABELA/KIND; o enforcement corrige o SEQ).

## UI — Lst_Process_Send mostra o PROCESSO (revisão do Valdo, 2026-07-27)

`un_send_to_web_server.pas` (`PreparaListBox`): a lista da tela exibia o
nome da TABELA, que não identifica mais o que está rodando (vários
processos na MESMA tabela — TB_NOTA_FISCAL nas Seqs 20–24). Agora exibe o
**DESC_PROCESS** do catálogo (fallback = tabela, para banco semeado antigo
com DESC_PROCESS vazio). O progresso continua por índice — sem outro efeito.

## Bancos JÁ semeados — SQL manual: NENHUM

- A mudança é toda de CÓDIGO (motor + classes + SQLs gerados em runtime).
- SRC_LOG antigo com marca `[KIND]...` em dev: sob a pendência nova
  (`SRC_LOG is null or ''`) a linha conta como PROCESSADA (log não-vazio) —
  não reprocessa nem trava. Com a limpeza revisada (só `SRC_LOG='OK'` sai),
  essas linhas FICAM na fila para verificação; para liberá-las, reprocessar
  com `UPDATE TB_SINCRONIA SET SRC_LOG=NULL WHERE SRC_LOG LIKE '%[%'`
  (reenvio inócuo — upserts idempotentes) ou deletá-las manualmente.
- As NOTEs das Seqs 21/22 no catálogo foram atualizadas no seed (canônico
  `un_sincronia_seed.pas` + espelho `00b`), mas NOTE é só documentação —
  bancos já semeados podem ficar com o texto antigo sem efeito funcional.

## Pendências

1. **Valdo**: compilar o Sincronizador (nenhuma unit nova/removida;
   RegisterClass/UnRegisterClass intocados) + smoke: venda pura →
   /order-sale; conjugada → **UM** envio /order-service (com sale/saleItems
   e invoice{service+merchandise}); compra/ajuste/avulsa inalterados;
   produto P/M × S — em TODOS os casos, SRC_LOG com marca ÚNICA.
2. ~~Valdo decidir sobre a limpeza por idade~~ — **DECIDIDO 2026-07-27**:
   limpeza só remove >48h com envio OK; o resto permanece para verificação
   (aplicado em `DeleteProcessadosAntigos`).
3. Rodada 4 (3 achados de DDL + rectification) segue pendente — inalterada
   por este patch.
