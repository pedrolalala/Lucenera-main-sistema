# Migration group 20260625_008 — Auditoria e parcelas do orçamento aprovado

## Decisão

O fluxo novo de aprovação deve gravar histórico próprio contra `public.orcamentos(id)` e preservar parcelas geradas por orçamento aprovado.

`public.historico_status_orcamento` permanece ligado à família Ubiqua/revenda. O fluxo novo usa `public.historico_status_orcamentos`.

## Alteração

- Cria `public.historico_status_orcamentos` com FK para `public.orcamentos(id)`.
- Atualiza `public.aprovar_orcamento_financeiro_base_spec001(...)` para gravar histórico obrigatório sem silenciar `foreign_key_violation`.
- Substitui a unicidade antiga de `projeto_parcelas` por índices únicos parciais:
  - `(orcamento_id, numero_parcela)` quando `orcamento_id IS NOT NULL`;
  - `(projeto_id, numero_parcela)` quando `orcamento_id IS NULL`.

## Observação

Esta migration corresponde à SPEC-004 e foi espelhada da migration aplicada no sistema de Orçamentos.
