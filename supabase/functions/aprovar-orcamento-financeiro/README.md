# Function/RPC: aprovar orçamento para financeiro

Este diretório documenta a RPC de banco:

```sql
public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
```

Não é uma Edge Function remota.

## Responsabilidade

Executar a transição de orçamento aprovado para itens, parcelas e boletos de forma transacional e rastreável por `orcamento_id`.

## Entrada

- `p_orcamento_id uuid`: id de `public.orcamentos`.

## Pré-condições

O orçamento precisa ter:

- `projeto_id` preenchido;
- itens em `public.orcamento_itens`;
- `frete_tipo` preenchido com `com_frete` ou `sem_frete`;
- `frete_valor` coerente com o tipo de frete;
- prazo de pagamento interpretável por `prazo_pagamento_dias` e/ou `condicoes_pagamento`;
- forma de pagamento e quantidade de parcelas compatíveis com o cálculo financeiro.

Orçamentos antigos sem prazo/frete estruturado devem ser editados antes da aprovação.

## Efeitos esperados

A RPC deve:

- aprovar o orçamento;
- gravar histórico em `public.historico_status_orcamentos`;
- criar/atualizar itens aprovados em `public.projeto_itens`;
- criar parcelas em `public.projeto_parcelas` com `orcamento_id`;
- criar boletos/pendências financeiras com `boletos.orcamento_id`;
- manter o vínculo com projeto e cliente por relacionamento, sem duplicar chave desnecessária no financeiro.

## Idempotência

O fluxo novo deve ser idempotente por `orcamento_id`: chamar a aprovação novamente não deve duplicar itens, parcelas ou boletos do mesmo orçamento. Qualquer evolução precisa preservar essa regra.

## Erros esperados

Mensagens úteis devem orientar correção operacional, por exemplo:

- orçamento inexistente;
- orçamento sem projeto vinculado;
- orçamento sem itens;
- orçamento sem frete estruturado;
- orçamento sem prazo de pagamento interpretável;
- conflito de parcela/boletos que viole a unicidade do fluxo.

## Retorno

A chamada deve retornar um resultado JSON/record indicando sucesso, orçamento, projeto, quantidade de parcelas/boletos criados ou reaproveitados e mensagens relevantes para a UI.

## Regras negativas

- Não usar `venda_id` no fluxo orçamento -> financeiro.
- Não depender de `public.fn_aprovar_orcamento()` nem de `public.orcamentos.trg_aprovar_orcamento`; removidos pela SPEC-005.
- Não chamar `process-billing-automation` para o fluxo novo; ela ainda existe remotamente como legado, mas deve ser tratada como pendência de remoção.

## Observação

Se no futuro existir uma Edge Function para orquestrar integrações externas, ela deve continuar chamando uma operação central no banco para preservar consistência transacional.
