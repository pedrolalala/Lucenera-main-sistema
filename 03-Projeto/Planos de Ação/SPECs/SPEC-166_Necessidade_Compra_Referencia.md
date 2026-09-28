---
titulo: "SPEC-166 — Referência do produto na Necessidade de Compra"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee)
---

# SPEC-166 — Referência do produto na Necessidade de Compra

## Checklist de Ação

- [x] `vw_necessidade_compra` passa a expor `referencia` (produtos.referencia) como última coluna
- [x] Tela Necessidade de Compra: coluna "Referência" ao lado de "Código"
- [x] Busca da tela passa a casar também pela referência (multi-termo, mesma regra SPEC-116)
- [x] Publicar o Compras no Skip (projectId 40326) — v0.0.78 (`e117587`)
- [x] Alinhar a cópia de `supabase/functions/generate-report` do Compras com a versão no ar (evitar regressão do PDF)

### Passos manuais do usuário

- [x] Autorizar a publicação no Skip
- [ ] Testar na tela: buscar por uma referência (ex.: `LUC55-BR`, `EKPF22`)

## Objetivo

O pessoal de Compras pesquisa os itens pela referência do fabricante. A tela Necessidade de Compra só mostrava código interno, nome e marca, e a busca não achava pela referência.

## Decisões aprovadas

- Pedido do usuário em 28/09/2026: "Dentro de necessidade de compra precisa ter também a referência. A partir da referência, o pessoal faz as pesquisas, com o filtro."
- Referência = `produtos.referencia` (mesmo campo usado no restante do ecossistema).

## Definição da SPEC

- Migration `supabase/db/migrations/20260928_166_necessidade_compra_referencia/001_vw_necessidade_compra_referencia.sql` — recria a view a partir da definição real (`pg_get_viewdef`), mantendo colunas, ordem, filtro `pendente > 0` e `security_invoker=true`; só acrescenta `referencia` no fim.
- Frontend: `src/services/necessidade-compra.ts` (tipo + `referencia.ilike` no `.or()` de cada termo) e `src/pages/NecessidadeCompra.tsx` (coluna nova, placeholder da busca).

## Realizado

### 2026-09-28

- Migration aplicada no Supabase real (dry-run com ROLLBACK antes): 237 linhas antes e depois, mesmo total pendente (4891,30), 237/237 com referência preenchida.
- Busca testada via PostgREST com a mesma sintaxe do app (`LUC55-BR`, `EKPF22`, `3649-AB`) — todas retornam o produto certo.
- Frontend alterado no repositório local do Compras; `tsc --noEmit` ok.

### 2026-09-28 (publicação)

- Conferência antes de publicar: as 3 migrations legadas do Skip 40326 já estão em `schema_migrations` (não reexecutam). Das 16 Edge Functions copiadas no Compras, 15 eram idênticas ao que está no ar; `generate-report` era cópia antiga (sem SPEC-152/158/164) e foi substituída pela versão no ar antes do apply.
- Skip 40326 v0.0.78 (`e117587`) aplicado (QA ok em todas as etapas) e publicado. O apply redeployou só `generate-report` (v100), com conteúdo idêntico ao da v99 (difere só na formatação feita pelo Skip); `schema_migrations` inalterado (239). Chunk `necessidade-compra` do bundle publicado contém a busca por referência.
- Repositório do Compras: commit `a61f162` (pushado).

## Pendências

- [ ] Testar na tela publicada (logado): coluna Referência e busca por `LUC55-BR` / `EKPF22`.
