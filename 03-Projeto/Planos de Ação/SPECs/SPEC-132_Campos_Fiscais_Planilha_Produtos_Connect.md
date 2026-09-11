---
titulo: "SPEC-132 — Campos fiscais da planilha Produtos (export Connect 2026-09-10)"
status: concluído
data_ultima_modificacao: 2026-09-11
# Fase A e Fase B concluídas. Incidente de preco_venda (2026-09-10) corrigido e verificado.
sistemas_envolvidos:
  - Scripts (`scripts/importar_produtos_estoque.py`)
  - Supabase (banco central) — colunas de `public.produtos` + trigger `trg_atualizar_preco_venda`
  - Cadastro Lucenera / Consultar Produtos (exibição, se aplicável)
  - Compras / Necessidade de Compra (usa `icms_entrada`/`ipi_entrada`/`porc_st` no cálculo de custo)
---

# SPEC-132 — Campos fiscais da planilha Produtos (export Connect 2026-09-10)

> Origem: o export "Estoque" do Connect de 2026-09-10 (`Produtos__2026-09-10.xlsx`)
> passou a trazer 36 colunas (antes ~16), incluindo campos fiscais: `icmsST`, `ipi`,
> `frete`, `ncm`, `cest` e 4 pares "GrupoFiscal". Pedido do usuário: incorporar
> esses campos ao import "com cuidado".
>
> **Fase A já feita** (fora desta SPEC, sem migration): conserto do rename
> `CustoTotal → vlCustoTotal` + sync de `ncm`/`cest` (colunas já existiam, sem
> trigger). Esta SPEC é a **Fase B** — os campos que mexem em preço.

## Checklist de Ação

### Banco

- [ ] Definir mapeamento final `icmsST` (planilha) → coluna (**decisão parcial: `porc_st`**, que hoje NÃO entra na fórmula de preço)
- [ ] Definir mapeamento `ipi` (planilha) → `ipi_entrada`? (única coluna de IPI; "entrada" = na compra — confirmar semântica com Filippo)
- [ ] Definir mapeamento `frete` (planilha, sempre `0` hoje) → `porc_frete`? (é "propositalmente ignorado" na fórmula de preço)
- [ ] Migration para os pares "GrupoFiscal" que variam: `GrupoFiscalNContribuinte` (3 valores) e `GrupoFiscalRevenda` (2 valores) — ver §"GrupoFiscal"
- [ ] `codGrupoFiscal`/`GrupoFiscal`/`codGrupoFiscalIndustria`/`GrupoFiscalIndustria` = constantes ("Nacional"/1) → **não** criar coluna
- [ ] Avaliar sincronizar também o detalhamento de custo (`despesas`→`porc_despesas`, `desconto`→`porc_desconto`, `vlCustoIndireto`→`vl_custo_indireto`) — hoje só 375 produtos preenchidos

### Script

- [ ] `importar_produtos_estoque.py`: adicionar os campos fiscais definidos, respeitando a política de sobrescrita (**Connect = fonte da verdade**, sobrescreve)
- [ ] Se algum campo sincronizado disparar `trg_atualizar_preco_venda` (`icms_entrada`, `ipi_entrada`, `porc_despesas`): rodar num lote separado e conferir o impacto em `preco_venda` de ~4.500 produtos ANTES/DEPOIS

### Passos manuais do usuário

- [ ] Confirmar com o Filippo: `icmsST`→`porc_st` está ok mesmo sabendo que a fórmula de preço usa `icms_entrada` como "% ST"? (ver §"O trigger de preço")
- [ ] Confirmar semântica de `ipi` (planilha) — é IPI de compra (= `ipi_entrada`) ou de venda?
- [ ] Confirmar se os pares GrupoFiscal são úteis para algum fluxo (nota fiscal / Ubiqua) ou se ficam só como referência
- [ ] Autorizar a migration e a gravação (o classificador exige autorização explícita por ação de DDL/DML em produção)

## Objetivo

Levar os campos fiscais do export Connect para `public.produtos` sem alterar
silenciosamente o `preco_venda` do catálogo, e sem duplicar colunas que já existem.

## Decisões aprovadas

- **Escopo em 2 fases**: Fase A (rename + ncm/cest) já feita; Fase B (esta SPEC) para o resto.
- **Connect = fonte da verdade**: onde o campo for sincronizado, sobrescreve o valor atual (inclusive os ~375 já preenchidos por outra origem).
- **Filippo explicou a fórmula de custo (áudio 2026-09-10) e ela BATE com a função `fn_atualizar_preco_venda` do banco** (líquido = custo − desconto%; ST/IPI/despesas = líquido × %; BDI = soma dos três; custo total = líquido + BDI). Portanto:
  - **`icmsST` → `icms_entrada`** (é o que a fórmula usa como "% ST" — **não** `porc_st`)
  - **`ipi` → `ipi_entrada`** (IPI de compra, compõe o custo)
  - **`despesas` → `porc_despesas`**, **`desconto` → `porc_desconto`**, **`vlCusto` → `preco_custo`** (custo de tabela do fornecedor), **`frete` → `porc_frete`** (sempre 0)
- **O `× 2,5` (margem 150%) no último passo da função é um bug**: Pedro confirmou que 150% deve ser só o **padrão para peça NOVA** (evitar erro no cadastro), nunca sobrescrever o preço de peça já calculada. Peça existente segue a **margem real** (`margem_lucro`). Fix: `preco_venda := custo_total * (1 + COALESCE(NULLIF(margem_lucro,0), 150) / 100)`.

## Definição da SPEC

### Estado atual (verificado 2026-09-10)

`public.produtos` já tem estas colunas (a maioria vazia):

| Planilha | Coluna existente | Preenchidos hoje | Observação |
|---|---|---|---|
| `ncm` | `ncm` (varchar) | 372 / 4726 | **Fase A**: backfill 4.344 |
| `cest` | `cest` (text) | 2 | **Fase A**: backfill 1.099. Texto — pode ter zero à esquerda |
| `icmsST` | `porc_st` (numeric) ou `icms_entrada` | `porc_st` 1 não-zero; `icms_entrada` 375 | % (formato US) |
| `ipi` | `ipi_entrada` (numeric 5,2) | 375 | % |
| `frete` | `porc_frete` (numeric 5,2) | 375 | planilha só tem `0` |
| `despesas` | `porc_despesas` | 375 | não pedido pelo usuário |
| `desconto` | `porc_desconto` | 0 não-zero | não pedido |
| `vlCustoIndireto` | `vl_custo_indireto` | 373 | não pedido |
| 4 pares `GrupoFiscal*` | — | — | ver abaixo |

### O trigger de preço — o que muda

```
CREATE TRIGGER trg_atualizar_preco_venda
  BEFORE INSERT OR UPDATE OF preco_custo, porc_desconto, icms_entrada, ipi_entrada, porc_despesas
  ON public.produtos ... EXECUTE FUNCTION fn_atualizar_preco_venda();
```

`fn_atualizar_preco_venda` (verificado 2026-09-10) faz **exatamente** a conta que o Filippo
descreveu, exceto o passo 7:

| Passo | Função no banco |
|---|---|
| líquido = custo − desconto% | `v_valor_liquido = preco_custo − preco_custo × porc_desconto/100` |
| ST = líquido × ST% | `v_valor_st = v_valor_liquido × icms_entrada/100` |
| IPI = líquido × IPI% | `v_valor_ipi = v_valor_liquido × ipi_entrada/100` |
| despesas = líquido × despesas% | `v_valor_despesas = v_valor_liquido × porc_despesas/100` |
| BDI = ST + IPI + despesas | `v_bdi_total = st + ipi + despesas` |
| custo total = líquido + BDI | `v_custo_total = v_valor_liquido + v_bdi_total` |
| **preço venda = custo total × margem** | ❌ hoje: `NEW.preco_venda := v_custo_total * 2.5` (150% fixo) |

**Fix necessário (migration):** trocar o passo 7 por
`NEW.preco_venda := v_custo_total * (1 + COALESCE(NULLIF(NEW.margem_lucro, 0), 150) / 100)`.
150% vira só o default para peça nova sem margem.

**Colunas de margem:** `margem_lucro` (campo do form `PecaForm`, default 150) — preenchida em
4.714 produtos, `= 150` em só 121. `percentual_lucro` (o que o import grava de `Lucro`) —
4.346 produtos, e **igual a `margem_lucro` em 4.190**. Ou seja, na prática são o mesmo número;
a função deve usar `margem_lucro`.

**`preco_venda` × `valor_venda`:** os orçamentos usam `preco_venda || valor_venda`
(`EditableBudgetItemsTable.tsx`). `preco_venda` = saída da função (hoje `× 2.5`, 4.042
produtos). `valor_venda` = `ValorVenda` do Connect (4.353), gravado pelo import. Depois do fix
+ backfill fiscal, `preco_venda` deve ficar **≈ `valor_venda`** (mesma fórmula) — essa é a
conferência de sucesso.

**Impacto:** sincronizar os campos fiscais dispara a função para ~4.500 produtos. Como o
`custo_total` cresce (passa a incluir o BDI de ST/IPI/despesas que não existia), o `preco_venda`
**sobe** para o catálogo todo — é o efeito desejado ("trazer o custo completo"), mas é uma
mudança de preço visível e precisa de OK explícito + conferência de amostra contra o `ValorVenda`.

### GrupoFiscal

| Par | Valores distintos | Sugestão |
|---|---|---|
| `codGrupoFiscal` / `GrupoFiscal` | 1 / "Nacional" | não criar coluna |
| `codGrupoFiscalIndustria` / `GrupoFiscalIndustria` | 1 / "Nacional" | não criar coluna |
| `codGrupoFiscalNContribuinte` / `GrupoFiscalNContribuinte` | 1/2/3 → Nacional / Nacional Nao Contribuinte / Nacional Revenda | coluna `grupo_fiscal_nao_contribuinte text` (ou cod) |
| `codGrupoFiscalRevenda` / `GrupoFiscalRevenda` | 1/3 → Nacional / Nacional Revenda | coluna `grupo_fiscal_revenda text` |

Alternativa: uma única coluna `regime_fiscal jsonb` guardando os 4 pares crus, sem
comprometer com semântica antes do Filippo definir o uso.

## Decisão final (Pedro, 2026-09-10)

**Não recalcular preço.** O `custo_total` e o `valor_venda` que vêm da Connect (`vlCustoTotal`
/ `ValorVenda`) já são os valores reais e já são gravados pelo script (Fase A). O trigger
`fn_atualizar_preco_venda` **não deve ser mexido** e o `preco_venda` **não deve mudar**.

Os percentuais fiscais entram só como dado/referência, "igual à planilha":

| Planilha | Coluna | No trigger? |
|---|---|---|
| `icmsST` | `porc_st` (campo "% ST" do `PecaForm`) | não |
| `ipi` | `ipi_entrada` (campo "% IPI") | **sim** |
| `despesas` | `porc_despesas` | **sim** |
| `desconto` | `porc_desconto` | **sim** |
| `frete` | `porc_frete` (sempre 0) | não |
| `GrupoFiscalNContribuinte` | `grupo_fiscal_nao_contribuinte` text (**coluna nova**) | não |
| `GrupoFiscalRevenda` | `grupo_fiscal_revenda` text (**coluna nova**) | não |

`icms_entrada` **não** é escrito (evita a divergência form × trigger). `vlCusto`/`preco_custo`
não entram (não estão no pedido). `vlCustoIndireto`/`vlCustoTotal` já cobertos via `custo_total`.

## Plano de execução

1. **Migration** (`ADD COLUMN`, seguro): `produtos.grupo_fiscal_nao_contribuinte text`,
   `produtos.grupo_fiscal_revenda text`. Sem DDL no trigger.
2. **Script** `importar_produtos_estoque.py`: sincronizar `porc_st`, `ipi_entrada`,
   `porc_despesas`, `porc_desconto`, `porc_frete`, `grupo_fiscal_nao_contribuinte`,
   `grupo_fiscal_revenda`, "igual à planilha".
3. **Congelar `preco_venda`** sem tocar no trigger: para cada produto com campo fiscal
   alterado — (a) snapshot do `preco_venda` atual; (b) `update` dos campos fiscais
   (`ipi_entrada`/`porc_despesas`/`porc_desconto` disparam a função → `preco_venda` muda);
   (c) `update` imediato `preco_venda = <snapshot>` (não está no `UPDATE OF` → não redispara).
   Janela de inconsistência: milissegundos por linha.
4. **Dry-run** + conferência: nenhum `preco_venda` diferente do valor pré-execução.
5. Backfill.

## Incidente 2026-09-10 e correção

A 1ª execução do backfill usou "grava o campo fiscal → deixa o trigger recalcular →
regrava `preco_venda` de volta". **Não funcionou**: `produtos` tem um SEGUNDO trigger de
preço não documentado, `trg_calculo_preco_venda` (`BEFORE UPDATE` **sem** filtro de
coluna — dispara em QUALQUER update da linha, diferente do `trg_atualizar_preco_venda`
que só dispara nas 5 colunas fiscais). A própria regravação de `preco_venda` redisparava
esse segundo trigger. **~2.120 produtos ficaram com `preco_venda` inflado** (5–15% acima,
a fórmula `custo_total × 2,5` recalculada já com IPI/despesas novos).

**Correção aplicada:** script único (`scripts/_fase_b_rollback_preco_venda.py`) que
desligou os 2 triggers dentro de uma transação, restaurou `preco_venda` de um snapshot
pré-run (4.726 produtos) e religou os triggers. Verificado: **0 produtos divergentes do
snapshot pré-incidente**, triggers ambos ativos.

`scripts/importar_produtos_estoque.py` foi **reescrito**: a gravação real agora roda
numa única transação via `psycopg2`/`SUPABASE_DB_URL` com os 2 triggers de preço
**desligados do início ao fim** (não mais grava-e-devolve) — `preco_venda` nunca é
tocado, e o script confere isso no final (`preco_venda` antes×depois idêntico). Testado
com uma gravação real de 51 produtos (ciclo normal de estoque): confirmado.

## Pendências

- [x] `icmsST` → `porc_st`; `ipi` → `ipi_entrada`; grupos fiscais → 2 colunas de texto novas.
- [x] Migration `ADD COLUMN` aplicada; script atualizado; backfill rodado (2.884 `porc_st`,
      2.405 `ipi_entrada`, 4.352 grupo fiscal preenchidos).
- [x] Incidente do `preco_venda` corrigido e verificado (0 divergências); mecanismo
      corrigido para os próximos ciclos (triggers desligados em transação única).
- [ ] Nada pendente nesta SPEC — Fase B concluída. Próximo ciclo Connect usa o script já corrigido.
