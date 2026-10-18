# Patch 10 — Preço sem inversão + indEscala real + aplicação em texto (D-SY2, D-SY5, D-SY6)

> ## ✅ APLICADO em 2026-10-17 (Claude Code) — compilação de conferência OK; **aguarda o build oficial e o reenvio do Valdo**
>
> Origem: `Infra-IA/setes-sync/verificacao-comissao-margem-mercadoria.md` (verificação só leitura
> pedida pela frente de produtos, D-PR26) — Valdo: "pode seguir com as recomendações".
> SQL manual no Firebird: **NENHUM**. Depois de compilar: **reenviar os produtos** (abaixo).

## O que mudou

| Decisão | Arquivo | Mudança |
|---|---|---|
| D-SY2 | `destiny/controller/ControllerPrice.pas` | `updateList` REMOVIDO (declaração + corpo). Não tinha chamador e copiava a inversão de 2013 (margem ← `aliq_kickback`, comissão ← `aliq_profit`). Comentário no lugar avisa para não ressuscitar. `Datasnap.DBClient` segue no `uses` (sem efeito) |
| D-SY5 | `classes/merchandise_send_web.pas` | `manufSignIndScale` deixa de ir `'N'` FIXO: vai `INDESCALA` (`FCtrl.Registro.IndicacaoEscala` — o model `origen/model/tblProduto.pas:281-282` já tinha o campo e o DAO já o lia). `NormalizeIndEscala`: maiúscula + trim; fora de S/N vai `''` (= ausente → NULL na web; o setes-sync recusaria outro valor com 400) |
| D-SY6 | `classes/merchandise_send_web.pas` | `application` vai em TEXTO: `DecodeAplicacao` faz `String(DecodeBase64(AnsiString(valor)))` — o MESMO do legado (`G16/Arquivos/Un_Produtos.pas:1469`, unit `synacode`, já usada pelo `ControllerArquivo`). Tolerância: valor sem forma de Base64 (alfabeto, tamanho múltiplo de 4, `=` só no fim) ou que decodificado traz caractere de controle (fora TAB/CR/LF) segue como está |

Lado setes-sync (mesma entrega, já testado — 37/37 jest, `tsc` limpo): `manufSignIndScale` sem default
(vazio/ausente = NULL, antes virava `'S'`), Swagger de `composition`/`application`/`manufSignIndScale`
corrigido, teste novo `src/__tests__/merchandise.body.test.ts`.

**Não entrou (decidido, mas TRAVADO)**: D-SY3 — trocar `kickbackProduct ← CLB_CALC_COM_VDA` por
`CLB_COM_VDA`. Espera a D-SY4 (a frente de comissão decide a fórmula antes); ligar agora zeraria a
comissão dos produtos com `PRC_AQ_COM = 0`.

## Compilar

- **Compilação de conferência JÁ feita** (2026-10-17): `msbuild Sincronizador.dproj` Debug/Win32 com saída numa pasta
  temporária — 0 erro, 0 aviso nas units alteradas. O `destiny/controller/ControllerPrice.pas` não entra no executável
  (nem compila neste projeto: o `BaseController` do destiny usa `MainModule`, do uniGUI). Falta o build oficial do Valdo.
- Texto do código em ASCII de propósito (o `merchandise_send_web.pas` não tem BOM; o Delphi lê como ANSI).
- `synacode` vem da Synapse (mesmo caminho de biblioteca que já compila o `ControllerArquivo`).
- `CharInSet`, `UpperCase`, `Trim` estão em `System.SysUtils` (já no `uses` da interface).

## Depois de compilar — reenviar os produtos

Configuração → **Primeira carga** → marcar só **Produtos**, **sem período** (`Fc_Produto`, `Task/tas_config.pas`).
⚠️ Rebobinar `TB_LISTA_SINCRONIA.LAST_UPDATE` NÃO serve: o envio lê a fila `TB_SINCRONIA` e a limpeza
de 48h já tirou os produtos enviados com OK.

## Como conferir (MySQL, só leitura)

```sql
SELECT manuf_sign_ind_scale, COUNT(*) FROM <schema>.tb_merchandise GROUP BY 1;   -- S/N/NULL, não só 'N'
SELECT id, LEFT(CAST(application AS CHAR), 60) FROM <schema>.tb_merchandise
 WHERE application IS NOT NULL AND application <> '' LIMIT 10;                 -- texto legível, não Base64
```

Caso de prova no Firebird: um produto com a aba Aplicação preenchida com acento e quebra de linha
(ex.: "Aplicação: Gol 1.6" + Enter + "Palio") e um com indEscala desmarcado → reenviar → conferir acima.
