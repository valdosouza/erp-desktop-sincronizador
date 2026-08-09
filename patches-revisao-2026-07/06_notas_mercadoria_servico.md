# Patch 06 — Notas de Mercadoria × Serviço (Onda C da fase, D1–D7)

> ## ⚠️ SUPERADO EM PARTE pelo patch 08 (D13, 2026-07-27)
>
> A **mecânica `[KIND]` no SRC_LOG** descrita abaixo (saveReturn por KIND,
> `SqlKindPendente`, limpeza com `%]OK%`) foi um ERRO DE ENTENDIMENTO e foi
> **REMOVIDA** — a marca é ÚNICA por registro e só de quem ENVIA; classes com
> filtros DISJUNTOS pulam sem marcar. Ver `08_fila_marca_unica.md`.
> A fila disjunta de TB_PRODUTO por PRO_TIPO e o restante do patch permanecem.

> ## ✅ APLICADO em 2026-07-26 (Claude Code)
>
> Spec: `Infra-IA/setes-sync/prompt_notas_mercadoria_servico.md` (decisões D1–D7).
> Lado Delphi da fase: 3 classes NOVAS (serviço nos 3 níveis — produto, pedido,
> nota), filtro de natureza nas classes existentes, seed 32 → 35 linhas e correção
> dos bugs de catch-up (D7). **Aguarda compilação do Valdo + teste ponta a ponta**
> (produto S → /service; pedido conjugado → order-sale + order-service no MESMO id;
> nota conjugada → invoice-merchandise + invoice-service no MESMO id).

## O que mudou, arquivo a arquivo

### `classes/merchandise_send_web.pas` (D2)
- Skip por natureza: só envia `PRO_TIPO` 'P'/'M'. 'S' vai pela `TServiceSendWeb`;
  'A' (cardápio, restaurante aposentado) não sincroniza. Skip = mesmo padrão de
  registro ausente (FStrJson vazio → não envia).
- Bloco `product` ganhou o par `kind` com o PRO_TIPO ('P'/'M').

### `classes/service_send_web.pas` (NOVA — D2)
- `TServiceSendWeb` → `/service/sincronize` (Seq 40). Molde da merchandise SEM os
  blocos merchandise/stock e SEM os catálogos de marca/embalagem/medida.
- Payload: `{ id (PRO_CODIGO), deleted, product { description, categoryId,
  identifier, promotion, highlights, active, published, note } }`.
- Skip se `PRO_TIPO <> 'S'`.

### `classes/order_sale_send_web.pas` (D6)
- Itens refiltrados por `getListByNFPorNatureza(nota, False)` → só PRO_TIPO <> 'S'
  (kind 'Sale' na web). Pedido SÓ-serviço não viaja (0 itens → skip; a
  `TOrderServiceSendWeb` cobre).
- `totalizer.itemsQtde` continua com a contagem TOTAL de itens do pedido
  (guardada ANTES do refiltro) — as duas classes do conjugado mandam o MESMO
  totalizer (upsert idempotente na web, exigência da Onda B).

### `classes/order_service_send_web.pas` (NOVA — D1/D6)
- `TOrderServiceSendWeb` → `/order-service/sincronize` (Seq 41). Molde da sale;
  mesmo `Registro.Tipo := 1` (pedido de serviço É PED_TIPO=1 no legado).
- Bloco `service` no lugar de `sale`: `{ number (mesmo número do pedido),
  customerDocument }` — SEM salesmanDocument.
- Itens = `getListByNFPorNatureza(nota, True)` (só PRO_TIPO='S'), SEM
  stockListId/priceListId. 0 itens → skip.
- Blocos order/totalizer/billing/user idênticos ao sale (mesmos valores); o `id`
  é o MESMO NFL_CODIGO (D1: conjugado alimenta o MESMO tb_order, cada classe
  grava seu ramo).
- Desvio da letra da spec: o "tem item de serviço?" é respondido pela própria
  lista filtrada (Count > 0) em vez de instanciar um `TControllerNotaFiscal` só
  para chamar `VerificaServico` — semanticamente idêntico (mesma query) e mais
  barato. `VerificaServico` É usada na `TInvoiceServiceSendWeb`.

### `classes/invoice_merchandise_send_web.pas` (D1/D3)
- **orderId REMOVIDO** (D1): o vínculo é a própria PK compartilhada
  (tb_invoice.id = tb_order.id = NFL_CODIGO). O orderId antigo mandava
  PED_CODIGO e dava 409 eterno (achado da spec).
- Só envia quando a nota TEM parte mercadoria: `NFL_VL_TL_PROD > 0` OU
  `VerificaProduto` (método NOVO no controller). Nota só-serviço → skip.
- Bloco `merchandise` NOVO (ramo tb_invoice_merchandise): dtExit/tmExit (omitidos
  quando zerados), baseIcmsValue, icmsValue, baseIcmsStValue, icmsStValue,
  totalValue (NFL_VL_TL_PROD), freightValue, insuranceValue, expensesValue,
  ipiValue, discountValue (TB_PEDIDO.PED_VL_DESCONTO), totalQtty, indPres
  (TB_PEDIDO.PED_INDPRES). **Todos os campos pedidos existem no model** — nada
  foi omitido por inexistência.
- **Avaliação `FillDataObjetoMerchandise` vs `FillDataObjetoDetached`**: mantida
  a Detached + leitura DIRETA do model `TNotaFiscal` (e do TB_PEDIDO que o fill
  carrega). Motivos: (a) a FillDataObjetoMerchandise arrasta os blocos fiscais
  por item que o contrato descarta; (b) o model de destino
  (`destiny/model/tblinvoiceMerchandise.pas`) tem um typo legado — o getter de
  `ValorIcmsSt` lê `Fbase_icms_st_value` (campo da BASE), então o icmsStValue
  sairia ERRADO se passasse pelo objeto. Leitura direta é fiel à fonte.

### `classes/invoice_service_send_web.pas` (NOVA — D3)
- `TInvoiceServiceSendWeb` → `/invoice-service/sincronize` (Seq 42). Molde da
  invoice_merchandise nova: mesmo payload base do /invoice, sem orderId.
- Só envia quando `NFL_VL_TL_SRV > 0` OU `VerificaServico` (a função existia em
  `ControllerNotaFiscal.pas` e NUNCA tinha sido chamada — reusada agora).
- Bloco `service`: `{ totalValue: NFL_VL_TL_SRV }`.

### `origen/controller/ControllerItensNFL.pas`
- `getListByNFPorNatureza(CodigoNota, ApenasServico)` NOVO: molde do getListByNF
  com `INNER JOIN TB_PRODUTO ON PRO_CODIGO = ITF_CODPRO` e filtro
  `PRO_TIPO='S'`/`<>'S'`. **getListByNF original preservado** (outros fluxos).

### `origen/controller/ControllerNotaFiscal.pas`
- `VerificaProduto` NOVO: molde da `VerificaServico` com `PRO_TIPO <> 'S'`.

### `origen/controller/ControllerSincronia.pas` (D7 + mecânica do conjugado)
- **D7a — `SqlTBPedidoAtualiza`/`SqlTBPedidoDeleta`**: o parâmetro é o KIND
  textual do catálogo mas `PED_TIPO` é numérico — a comparação nunca casava (a
  carga histórica de pedidos não subia). Novo mapa `KindToPedTipo`:
  PEDIDO_VENDA→1, PEDIDO_COMPRA→2, AJUSTE_ESTOQUE→3, PEDIDO_SERVICO→1.
  (O Deleta tinha o MESMO bug e ganhou a mesma correção — extensão ao escopo
  pedido, sinalizada aqui.)
- **D7b — `SqlTBNotaFiscalAtualiza`/`SqlTBNotaFiscalDeleta`**: testavam
  'AVULSA'/'EM' mas o seed grava 'NOTA_AVULSA' → corrigido: NOTA_AVULSA →
  `nfl_tipo='EM'`; NOTA_MERCADORIA e NOTA_SERVICO → `nfl_tipo<>'EM'` (as classes
  filtram a natureza no envio).
- **ACHADO/CORREÇÃO estrutural (D6 — sem isso o conjugado NÃO funciona)**: a
  fila TB_SINCRONIA marca `SRC_LOG` por (tabela, registro); com dois KINDs sobre
  o MESMO registro (venda×serviço no pedido; mercadoria×serviço na nota), a
  primeira classe consumia a fila e a segunda nunca via o registro. Correções:
  - `saveReturn`: para TB_PEDIDO e TB_NOTA_FISCAL o log vira marca POR KIND
    (`[KIND]resultado`, acumulando — mensagem truncada em 60 chars porque
    SRC_LOG é VARCHAR(255) e a linha conjugada leva 2 marcas). Demais tabelas
    mantêm o comportamento original.
  - `SqlKindPendente`: pendência avaliada por KIND (`SRC_LOG NOT LIKE '%[KIND]%'`)
    nos SQLs de TB_PEDIDO/TB_NOTA_FISCAL. Efeito colateral aceito: linhas
    antigas com log sem marca ('OK') são reprocessadas UMA vez por KIND —
    inócuo (upserts idempotentes) e o backlog é pequeno (limpeza de 48h).
  - `DeleteProcessadosAntigos`: limpeza também pega linhas marcadas
    (`SRC_LOG LIKE '%]OK%'`).
  - **TB_PRODUTO** (Seq 5 × Seq 40) não tem conjugado — resolvido com fila
    DISJUNTA: `SqlTBProdutoAtualiza`/`Deleta` novos (molde TB_PEDIDO) com
    `PRO_TIPO IN ('P','M')` × `PRO_TIPO='S'`; ramais em getSqlAtualiza/Deleta.
    PRO_TIPO='A' não é selecionado por nenhum KIND (linhas ficam na fila até a
    limpeza não pegá-las — volume ~0, restaurante aposentado).
  - SQL novo compatível Firebird 2.5 E 5.0 (SUBSTRING FROM/FOR, COALESCE, `||`,
    LIKE — sem IDENTITY/BOOLEAN/funções 3.0+).

### `function/un_sincronia_seed.pas` + `un_dm.pas`
- Array `[0..31]` → `[0..34]`; 3 linhas novas (formato das irmãs Seq 5/17/20):
  - Seq 40 · TB_PRODUTO · KIND `SERVICO` · `TServiceSendWeb` · `/service/sincronize` · SET_ON='S'
  - Seq 41 · TB_PEDIDO · KIND `PEDIDO_SERVICO` · `TOrderServiceSendWeb` · `/order-service/sincronize` · SET_ON='S'
  - Seq 42 · TB_NOTA_FISCAL · KIND `NOTA_SERVICO` · `TInvoiceServiceSendWeb` · `/invoice-service/sincronize` · SET_ON='S'
- `un_dm.pas` (perfil PDV): Seq 40 é cadastro como a Seq 5 → o UPDATE do perfil
  PDV passou a desligar também a 40 (`SEQ IN (38, 39, 40)`).
- Espelho `patches-revisao-2026-07/00b_seed_tb_lista_sincronia.sql` RESSINCRONIZADO
  com o canônico (.pas): Seq 28 ativa (patch 04), restaurante removido (Seqs
  31–37 reservados), + Seqs 38/39/40/41/42; conferência 32 → **35 linhas**
  (34 ativas; só a Seq 30/CC-e segue 'N').

### `uMain.pas`
- `uses` + `RegisterClass`/`UnRegisterClass` (espelhados) das 3 classes novas:
  `TInvoiceServiceSendWeb`, `TOrderServiceSendWeb`, `TServiceSendWeb`.

## Bancos JÁ semeados — INSERT manual é NECESSÁRIO

Confirmado em `un_dm.pas` (`SeedListaSincroniaIfEmpty`): o seed **só roda com a
TB_LISTA_SINCRONIA vazia** (`if not TabelaVazia(...) then Exit`) — ele NÃO
ressemea linhas novas em bancos já semeados (o único ajuste incremental que ele
faz é o DELETE das TB_REST_*). Portanto, todo banco que já passou pelo bootstrap
precisa das 3 linhas na mão:

```sql
INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PRODUTO', 'SERVICO', 'Servico (product kind S)', 40,
   'PRO_CODIGO', NULL, 'D2 - PRO_TIPO=S vira SO tb_product (kind S)', 'S',
   'TServiceSendWeb', '/service/sincronize');

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_PEDIDO', 'PEDIDO_SERVICO', 'Pedido de servico (ramo do conjugado)', 41,
   'PED_CODIGO', NULL, 'D1/D6 - itens PRO_TIPO=S; mesmo tb_order do sale', 'S',
   'TOrderServiceSendWeb', '/order-service/sincronize');

INSERT INTO TB_LISTA_SINCRONIA
  (WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT)
VALUES
  ('E', 'TB_NOTA_FISCAL', 'NOTA_SERVICO', 'Nota fiscal de servico (ramo do conjugado)', 42,
   'NFL_CODIGO', NULL, 'D3 - NFL_VL_TL_SRV > 0 OU item PRO_TIPO=S', 'S',
   'TInvoiceServiceSendWeb', '/invoice-service/sincronize');

COMMIT;
```

Em PDV (terminal <> 0), desligar a 40 na mão (o perfil só é aplicado no seed
inicial): `UPDATE TB_LISTA_SINCRONIA SET SET_ON='N' WHERE SEQ = 40;`

Triggers: NENHUMA nova — TB_PRODUTO/TB_PEDIDO/TB_NOTA_FISCAL já estão no
catálogo (Seqs 5/17/20) e os TG_SRC_* existentes cobrem as linhas novas.

## Pendências

1. **Valdo**: compilar o Sincronizador (3 units novas no projeto .dproj, se o
   projeto não usa busca por pasta) + smoke ponta a ponta com a Onda B da
   setes-sync no ar (/service, /order-service, /invoice-service e os ajustes
   de /merchandise e /invoice-merchandise).
2. **Valdo**: INSERT manual acima nos bancos dev/cliente já semeados.
3. **Revisar a mecânica de marca por KIND** (saveReturn/SqlKindPendente): é a
   peça que faz o conjugado funcionar mas NÃO estava na letra da spec — se o
   Valdo preferir outra solução (ex.: coluna própria na fila), este patch é o
   ponto de partida.
4. Onda B (setes-sync) e Onda A (migrations 019–021) desta fase seguem por
   conta própria — este patch é só o lado Delphi (Onda C).
