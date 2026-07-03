# Migration group 20260625_006 — Remover `projeto_parcelas.venda_id`

## Decisão

`projeto_parcelas` não usa mais `venda_id`.

Parcelas do fluxo de orçamento aprovado devem ser rastreadas por `projeto_parcelas.orcamento_id`. O campo `projeto_id` continua existindo, porque a parcela ainda pertence a um projeto.

## Alteração

- Atualiza `public.aprovar_orcamento_financeiro_base_spec001(...)` para não inserir `venda_id`.
- Remove o índice `idx_parcelas_venda`, se existir.
- Remove a FK `projeto_parcelas_venda_id_fkey`, se existir.
- Remove a coluna `public.projeto_parcelas.venda_id`, se existir.

## Observação

O financeiro deve derivar orçamento, projeto e cliente por:

```text
projeto_parcelas.orcamento_id
  -> orcamentos.id
  -> orcamentos.projeto_id
  -> projetos.id
```
