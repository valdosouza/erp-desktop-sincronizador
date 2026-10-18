# Patch 11 — Medida pela abreviação + categoria por natureza + sincronia inativa (D-SY10, D-SY11, D-SY13)

> ## ✅ APLICADO em 2026-10-18 (Claude Code) — compilação de conferência OK; **aguarda o build oficial, o "Preparar o banco" e o reenvio do Valdo**
>
> Origem: `Infra-IA/setes-sync/verificacao-comissao-margem-mercadoria.md` §8.2/§8.6 (D-SY10, D-SY11) e §9.2/§9.4
> (D-SY13); execução registrada no §10 do mesmo arquivo. Decisões do Valdo de 2026-10-18.
> SQL manual no Firebird: **NENHUM** (a conversão roda no "Preparar o banco"). Depois de compilar: **Preparar o banco +
> Primeira carga** (abaixo).

## O que mudou

| Decisão | Arquivo | Mudança |
|---|---|---|
| D-SY10 | `classes/merchandise_send_web.pas` | `GetMeasureName` virou `GetMeasure(codigo, out abreviatura, out descricao)`: o produto manda `stock.measureAbbreviation` (= `MED_ABREVIATURA`, a CHAVE da medida na web) e `stock.nameMeasure` (= `MED_DESCRICAO`, atributo da criação). Medida inexistente no Firebird → abreviação `'UND'` (antes `'UND'` ia como DESCRIÇÃO e a web criava uma 2ª linha "UND" sem abreviação) e descrição vazia. O `/measure` (`measure_send_web.pas`) já mandava a abreviação — sem mudança |
| D-SY11 | `un_dm.pas` (`MigraGruposParaCategoria`) | A conversão grupo/subgrupo → `TB_CATEGORY` separa por NATUREZA: para cada grupo/subgrupo nasce a categoria `'P'` se houver produto que não é serviço (grupo/subgrupo sem produto fica `'P'`, como antes) e a categoria `'S'` (mesmo nome, árvore `'S'` própria — raiz `'S'` e filhas `'S'`) se houver produto `PRO_TIPO = 'S'`. Cada produto é reapontado (`PRO_CODCAT`) para a categoria da SUA natureza. Idempotência por descrição **e KIND**; o Passo 0 ("sujeira") confere o KIND (ver abaixo). PDV continua sem converter (Q8) |
| D-SY13 | `function/un_sync_key_state.pas` (**NOVO**) | Estado "sincronia inativa" no `CONFIG.INI` (seção `SISWEB`: `SincroniaInativa`, `SincroniaInativaDesde`, `SincroniaInativaMotivo` — persiste entre aberturas); regra ÚNICA da recusa (`IsRecusaDaChave`: 401 qualquer — A-SY1 — ou 403 `SYNC_KEY_INACTIVE`); consulta `GET /sync-key/status` |
| D-SY13 | `classes/general_web.pas` | O envelope lê o `code` do erro (`ErrorCode`) e expõe `AuthRefused` |
| D-SY13 | `function/un_send_to_web_server.pas`, `function/un_receive_from_web_server.pas` | Recusa da chave → NÃO grava `SRC_LOG` naquele registro (fica pendente na fila — nada se perde), não mexe no checkpoint, marca a sincronia inativa e interrompe o ciclo (registro e tabelas seguintes). `MarcarSincroniaInativa` nunca levanta exceção (falha ao gravar o INI vai para o `log_api_data.txt`; o motivo é gravado numa linha só, sem CR/LF de corpo de proxy). O recebimento passa a mandar a chave (`LcReceiveWeb.ApiKey` — antes não mandava; com a D-SY13 qualquer linha `WAY='R'` ativa derrubaria a sincronia inteira com 401) |
| D-SY13 | `function/un_sincroniza.pas` | Sincronia inativa → o ciclo não começa (nem recebe nem envia) |
| D-SY13 | `uMain.pas` / `uMain.dfm` | Menu **Tarefas → Ativar sincronia** (`MnuAtivarSincronia`); com o estado inativo os timers param (`AplicaSincroniaInativa`) e o botão Iniciar/F5 e os timers ficam INERTES (nem reposicionam o checkpoint); ao abrir o app, o estado já gravado mantém tudo parado |

Lado setes-sync (mesma entrega — `tsc` limpo, jest verde; números no §10.4 do registro): `sync.catalog.ts` com chave
por tabela (medida = abreviação) e a MESMA trava nomeada do setes-api (`GET_LOCK('setes_central.<tabela>', 10)` antes
da transação, só para CRIAR — o item vivo é reusado sem trava e o vínculo do cliente fica fora da seção global);
`/measure` com abreviação obrigatória; `/merchandise` com `stock.measureAbbreviation`; recusas tipadas
da chave (401 `SYNC_KEY_MISSING`/`SYNC_KEY_INVALID`, 403 `SYNC_KEY_INACTIVE`) e `GET /sync-key/status`. Contrato:
`Infra-IA/setes-sync/CONTRATOS_SYNC.md`.

## Compatibilidade (executável × servidor)

| Executável | setes-sync | Efeito |
|---|---|---|
| antigo | novo | medida pela DESCRIÇÃO (`nameMeasure`, aviso no log do servidor) — igual a antes, mas a medida cuja descrição não casa nasce na central com abreviação NULL, invisível à dedupe por abreviação (Q-SY20 — por isso servidor e executável no MESMO dia); chave inativa = 403 que o executável antigo grava no `SRC_LOG` de cada registro (estaciona, como antes) |
| novo | antigo | o servidor ignora `measureAbbreviation` e resolve por `nameMeasure` (igual a antes); chave inativa = 401 → o executável novo fica INATIVO (A-SY1), mas "Ativar sincronia" recebe 404 (rota inexistente) e **não reativa** — subir o setes-sync novo antes |
| novo | novo | o desenho completo |

**Ordem**: setes-sync novo no ar ANTES (ou junto) do setes-api com a medida por abreviação (D-SY10 item 5 — enquanto
um deduplica por descrição e o outro por abreviação, a central ganha linhas repetidas) → build oficial do sincronizador.

## Compilar

- **Compilação de conferência JÁ feita** (2026-10-18): `msbuild Sincronizador.dproj /t:Build /p:Config=Debug
  /p:Platform=Win32` com `DCC_ExeOutput`/`DCC_DcuOutput` numa pasta TEMPORÁRIA — 0 erro, nenhum aviso/dica nas units
  alteradas; `Sincronizador.res` com os mesmos bytes. Falta o build oficial do Valdo.
- `un_sync_key_state.pas` mora em `function\` (pasta do search path — o `.dpr`/`.dproj` não precisam mudar).
- Texto novo em ASCII (arquivos sem BOM são lidos como ANSI).

## Depois de compilar

### 1. Preparar o banco (conversão por natureza)

**Tarefas → Prepara Local** (`MnuPreparaLocalClick` → `DM.EnsureSincronia(True)`). O start automático NÃO converte.
⚠️ O "Preparar o banco" ZERA a fila `TB_SINCRONIA` no fim — inclusive o que estiver PENDENTE (ex.: movimentos acumulados
com a sincronia INATIVA). Antes de rodar: sincronia ativa e fila vazia (`SELECT COUNT(*) FROM TB_SINCRONIA WHERE
COALESCE(SRC_LOG, '') = ''` → 0); senão os pendentes só voltam por Primeira carga (com período, para os movimentos).

⚠️ **Pode cair no Passo 0 ("sujeira") e reconverter do zero**: a conversão só confia na `TB_CATEGORY` que ela mesma
produziria. Grupo/subgrupo que só tem SERVIÇO tinha uma categoria `'P'` (o que a conversão antiga gerava) — agora ela
não seria produzida → a tabela é zerada (`PRO_CODCAT` → NULL, `DELETE FROM TB_CATEGORY`, generator a 0) e reconvertida.
⚠️ Os ids NÃO são novos: com o generator a 0 eles RECOMEÇAM do 1 e podem cair em cima de ids vivos na web com outro
significado (o `/category` faz upsert pelo id e move a subárvore). Grupo misto (mercadoria + serviço) não suja: a `'P'`
continua certa e só nasce a `'S'`. O reset volta a acontecer sempre que a natureza de um grupo mudar no legado (ex.: o
último produto 'P' de um grupo vira 'S'). No fim, o "Preparar o banco" limpa a fila (`LimpaFilaSincroniaDoBootstrap`) —
**nada vai para a web sozinho**. Consequência na web até a Primeira carga terminar: nós com o id trocado, e as categorias
antigas que a reconversão não reproduzir ficam VIVAS lá (o DELETE do Firebird não viaja) → **Q-SY16**.

### 2. Reenviar categorias, medidas e produtos

**Configuração → Primeira carga → marcar Categorias, Medidas/Unidades e Produtos, SEM período** (`Fc_Categoria`,
`Fc_Medida` e `Fc_Produto` em `Task/tas_config.pas` — `Fc_Produto` cobre mercadoria E serviço; as categorias vão antes
dos produtos pela ordem do catálogo). ⚠️ Rebobinar `TB_LISTA_SINCRONIA.LAST_UPDATE` NÃO reenvia: o envio lê a FILA
(`TB_SINCRONIA`) e a limpeza de 48h já tirou o que foi enviado com OK. Idempotente na web (upsert).

## Reativar a sincronia (D-SY13)

Quando o setes-sync recusa a chave (Super desligou o interruptor da chave do estabelecimento — D-PR43 — ou a chave não
existe), o sincronizador para no registro em que recebeu a recusa, mostra "Sincronia INATIVA — chave recusada pelo
servidor" e não volta a sincronizar, nem pelo timer nem pelo Iniciar/F5. Os registros ficam PENDENTES na fila (sem
`SRC_LOG`).

1. Religar a chave na web (Super → cadastro do Estabelecimento → chave de sincronização ativa).
2. No sincronizador: **Tarefas → Ativar sincronia**. Ele consulta `GET /sync-key/status`:
   - **ativa** → limpa o estado, religa os timers; o próximo ciclo (ou Iniciar/F5) manda os pendentes;
   - **inativa / inexistente** → mensagem, nada muda;
   - **sem resposta** (servidor fora, setes-sync antigo sem a rota) → mensagem, nada muda.
   - 401 sem código `SYNC_KEY_*` pode vir de outro serviço no caminho (proxy, URL errada) — a mensagem manda conferir
     `FApiKey` e `FPathURL` (Q-SY19).
3. ⚠️ Limite conhecido: o setes-sync guarda a chave VÁLIDA em cache por até 5 min. Desligada a chave, o sincronizador
   pode ainda passar por até 5 min; a consulta do "Ativar sincronia" lê o banco e acerta o cache.
4. Instalação nova ou chave trocada: se o sincronizador rodou um ciclo com `FApiKey` vazio ou errado, ele já ficou
   INATIVO (401 — A-SY1). Depois de gravar a chave certa em Configurações, usar **Tarefas → Ativar sincronia**.

## Como conferir

Firebird (só leitura, ANTES do reenvio):

```sql
-- medidas com a MESMA abreviação e descrições diferentes: vão apontar para UMA linha central (D-SY10)
SELECT UPPER(TRIM(MED_ABREVIATURA)) AS ABREV, COUNT(*) AS N, LIST(MED_DESCRICAO, ' | ') AS DESCRICOES
  FROM TB_MEDIDA GROUP BY 1 HAVING COUNT(*) > 1;
-- medidas sem abreviação: resolvem pela descrição (aviso no log do setes-sync)
SELECT MED_CODIGO, MED_DESCRICAO FROM TB_MEDIDA WHERE COALESCE(TRIM(MED_ABREVIATURA), '') = '';
-- depois do Preparar o banco: produto em categoria de outra natureza (esperado: 0)
SELECT COUNT(*) FROM TB_PRODUTO P JOIN TB_CATEGORY C ON (C.ID = P.PRO_CODCAT)
 WHERE (P.PRO_TIPO = 'S' AND C.KIND <> 'S') OR (COALESCE(P.PRO_TIPO, '') <> 'S' AND C.KIND <> 'P');
SELECT KIND, COUNT(*) FROM TB_CATEGORY GROUP BY 1;
```

MySQL (só leitura, DEPOIS do reenvio; `<schema>` = schema do cliente):

```sql
SELECT p.kind AS produto, c.kind AS categoria, COUNT(*)
  FROM <schema>.tb_product p
  JOIN <schema>.tb_category c ON c.id = p.tb_category_id AND c.tb_institution_id = p.tb_institution_id
 WHERE p.deleted = 'N' GROUP BY 1, 2;                    -- serviço (S) só em categoria S
SELECT UPPER(TRIM(abbreviation)) AS abrev, COUNT(*) FROM setes_central.tb_measure
 WHERE deleted = 'N' AND abbreviation IS NOT NULL GROUP BY 1 HAVING COUNT(*) > 1;   -- esperado: nenhuma
```

Prova da D-SY13 (com o Valdo): desligar a chave do estabelecimento de ensaio na web → esperar até 5 min → alterar um
cadastro no Gestão → o ciclo para com "Sincronia INATIVA" e o registro fica com `SRC_LOG` vazio → fechar e abrir o
sincronizador (continua inativo) → religar a chave → Tarefas → Ativar sincronia → o registro sobe no ciclo seguinte.
