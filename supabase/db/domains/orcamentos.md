# Domínio: Orçamentos

## Papel no ecossistema

Orçamentos representam a proposta comercial antes de virar execução operacional.

Somente orçamento aprovado deve gerar itens em `projeto_itens`.

## Decisão atual

Ao aprovar um orçamento:

1. O sistema usa `orcamento_id` como chave principal de rastreio.
2. Os itens aprovados são levados para `projeto_itens`.
3. As parcelas são criadas em `projeto_parcelas` com `orcamento_id`.
4. Boletos são criados/disponibilizados na Administração Bancária com `boletos.orcamento_id`.
5. O financeiro exibe orçamento, projeto e cliente derivados do `orcamento_id`.

Não usar `venda_id` nesse fluxo.

Antes da aprovação, o orçamento precisa ter:

- projeto vinculado;
- itens válidos;
- prazo de cobrança interpretável (`prazo_inicio_cobranca_dias` e/ou `prazo_pagamento_dias`);
- frete estruturado (`frete_tipo = com_frete | sem_frete` e `frete_valor` coerente);
- forma de pagamento e quantidade de parcelas compatíveis com a RPC.

## Relação com planilhas da Connect

A planilha de vendas aprovada da Connect serve como histórico para identificar:

- orçamento aprovado;
- projeto relacionado pelo código antes do nome do cliente;
- itens aprovados;
- histórico comercial.

As demais movimentações com cliente devem ser tratadas como estoque/operação, não como venda aprovada.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Orçamentos/Projetos:

- `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`: RPC principal do fluxo orçamento aprovado -> itens/parcelas/boletos.
- `public.aprovar_orcamento_financeiro_base_spec001(p_orcamento_id uuid)`: base/refinamento da SPEC-001.
- `public._lucenera_parse_prazo_pagamento(...)`: interpreta prazos de pagamento para cálculo de parcelas/vencimentos.
- `public.fn_gerar_numero_orcamento()` e `public.set_orcamento_numero()`: geração/atribuição de número de orçamento.
- `public.fn_update_orcamento_timestamp()`: atualização de timestamp do orçamento.
- `public.sync_projeto_valor_total()`: sincroniza `projetos.valor_total` a partir de `projeto_itens.subtotal`.
- `public.gerenciar_fluxo_projeto()`: automação atual de fluxo/status de projeto.
- `public.trigger_fechar_projeto()` e `public.trigger_proteger_fechamento()`: automações de fechamento/proteção de projeto.
- `public.trigger_proteger_parcelas()`: proteção de parcelas legadas; desde a SPEC-005 libera inserções com `orcamento_id IS NOT NULL`.

Triggers relacionadas:

- `public.orcamentos.trigger_set_orcamento_numero`
- `public.orcamentos_revenda_ubiqua.trigger_auto_numero_orcamento`
- `public.orcamentos_revenda_ubiqua.trigger_orcamento_updated_at`
- `public.projeto_itens.trg_sync_valor_total`
- `public.projeto_parcelas.trg_proteger_parcelas`
- `public.projetos.trg_fechar_projeto`
- `public.projetos.trg_gerenciar_fluxo_projeto`
- `public.projetos.trg_proteger_fechamento`

Edge Functions relacionadas:

- `parse-budget-pdf`: leitura/processamento inicial de PDF de orçamento.
- `process-budget-pdf`: processamento/geração/envio relacionado a PDF de orçamento.
- `enviar-confirmacao-email`: confirmação por e-mail de orçamento, ainda simples e pendente de revisão.
- `salvar-projeto` e `update-project`: criação/atualização de projeto por Edge Function.

Observações:

- `public.fn_aprovar_orcamento()` e `public.orcamentos.trg_aprovar_orcamento` foram removidos pela SPEC-005 porque criavam projeto a partir de orçamento em um modelo antigo e bloqueavam a RPC nova.
- `process-billing-automation` ainda aparece no remoto como Edge Function legada, mas não deve ser usada nem evoluída; o fluxo novo deve usar a RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)`.
- `historico_status_orcamentos` é a tabela de auditoria do fluxo Lucenera; `historico_status_orcamento` permanece ligado à família Ubiqua/revenda.

## Ação a ser realizada

Manter a função/RPC `public.aprovar_orcamento_financeiro(p_orcamento_id uuid)` como ponto transacional do fluxo de aprovação. Ao evoluir, garantir que ela não dependa de `venda_id` e que o financeiro derive projeto/cliente via `orcamento_id -> orcamentos`.
