# Migration group 20260625_003 — Remover `boletos.projeto_id`

## Decisão

Boletos devem ficar vinculados ao orçamento por `boletos.orcamento_id`.

O projeto já é obtido por:

```text
boletos.orcamento_id
  -> orcamentos.id
  -> orcamentos.projeto_id
  -> projetos.id
```

Portanto, manter `boletos.projeto_id` cria redundância e risco de divergência.

## Alteração

- Recria `public.aprovar_orcamento_financeiro(...)` sem limpeza de `boletos.projeto_id`.
- Recria `public.aprovar_orcamento_financeiro_base_spec001(...)` sem inserir `projeto_id` em `boletos`.
- Remove a FK `boletos_projeto_id_fkey`, se existir.
- Remove a coluna `public.boletos.projeto_id`, se existir.

## Observação

`projeto_id` continua existindo onde é parte natural do domínio de projeto, como:

- `orcamentos.projeto_id`;
- `projeto_itens.projeto_id`;
- `projeto_parcelas.projeto_id`;
- `transacoes.projeto_id`, quando aplicável.
