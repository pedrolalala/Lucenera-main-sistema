# Migration group 20260706_020 - Normalizacao da aprovacao financeira

## SPEC

- `SPEC-016_Normalizacao_Aprovacao_Financeira_Orcamento.md`
- Base para `SPEC-017_Modal_Unificado_Aprovacao_Financeira_Orcamento.md`

## Objetivo

Normalizar o contrato do banco para que a aprovacao financeira seja feita por `orcamento_id`, no status oficial `Aprovação Financeira`, finalizando em `Orçamento Aprovado`.

## Principais alteracoes

- Recria `public.aprovar_orcamento_financeiro(uuid)` como RPC oficial por `orcamento_id`.
- Transforma `aprovar_orcamento_financeiro_base_spec001(uuid)` em wrapper legado.
- Descontinua `aprovar_projeto_financeiro(uuid)` e `finalizar_validacao_financeira(uuid,jsonb,jsonb)` com erro claro.
- Atualiza funcoes de aprovacao do cliente para terminarem em `Aprovação Financeira`.
- Atualiza `normalize_orcamento_status()` para normalizar `aprovado_cliente` e `aprovado_financeiro`.
- Ajusta `cancelar_orcamento(uuid,text)` para reverter efeitos tambem quando o status final for `Orçamento Aprovado`.
- Cria `vw_orcamentos_aprovacao_financeira_auditoria`.

## Impacto esperado

- Orçamentos passa a ser o unico sistema diretamente impactado.
- Administração Bancária / Financeiro continua consumindo artefatos por `orcamento_id`.
- CRM e Estoque continuam lendo projeto/itens; a RPC nao aprova projeto inteiro nem outros orçamentos do mesmo projeto.

## Rollback

Reaplicar as definicoes anteriores das funcoes a partir do snapshot em `supabase/db/current/03_functions.sql`. A view de auditoria pode ser removida sem perda de dados.
