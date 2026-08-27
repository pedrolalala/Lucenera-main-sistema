-- Migration 20260811_098
-- Achado: a migration 20260718_050 (SPEC-031) criou as RPCs de aprovação do
-- cliente (aprovar_orcamento_cliente_manual, aprovar_orcamento_cliente_publico,
-- aprovar_orcamento_cliente, adm_aprovar_pelo_cliente, cliente_aprovar_orcamento)
-- que movem orcamentos.status para 'Aprovação da Equipe', mas nunca atualizou
-- o CHECK constraint orcamentos_status_check para permitir esse valor. Toda
-- aprovação de cliente (manual, por token público, ou pelo admin) vem
-- quebrando desde 18/07 com:
--   new row for relation "orcamentos" violates check constraint "orcamentos_status_check"
--
-- Aditiva: só amplia a lista de valores permitidos, nenhum dado muda.

ALTER TABLE public.orcamentos DROP CONSTRAINT orcamentos_status_check;

ALTER TABLE public.orcamentos ADD CONSTRAINT orcamentos_status_check
  CHECK (status = ANY (ARRAY[
    'rascunho'::text,
    'aguardando_aprovacao'::text,
    'enviado_cliente'::text,
    'recusado_cliente'::text,
    'expirado'::text,
    'cancelado'::text,
    'Aprovação Financeira'::text,
    'Orçamento Aprovado'::text,
    'aprovado_cliente'::text,
    'aprovado'::text,
    'aprovado_financeiro'::text,
    'pendente_aprovacao_financeira'::text,
    'Aprovação da Equipe'::text
  ]));
