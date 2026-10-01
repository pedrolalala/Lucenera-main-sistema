-- SPEC-173 — novos valores de cadastro de contatos (pedido do usuário, 01/10/2026):
--   * contato_origens.origem: + 'PROSPECCAO_SAO_PAULO'
--   * contato_tipos.tipo:     + 'construtora'
--   * contatos.tipo (enum contato_tipo): + 'construtora'
-- Todos os valores atuais continuam permitidos. contatos.tipo precisa do valor
-- também porque o trigger handle_contato_tipo copia contatos.tipo para
-- contato_tipos (sem os dois, cadastrar uma construtora falha).

-- Enum: ADD VALUE é aditivo e não reescreve a tabela.
ALTER TYPE public.contato_tipo ADD VALUE IF NOT EXISTS 'construtora';

BEGIN;

ALTER TABLE public.contato_origens DROP CONSTRAINT contato_origens_origem_check;
ALTER TABLE public.contato_origens ADD CONSTRAINT contato_origens_origem_check
  CHECK (origem = ANY (ARRAY['CRM_CLIENTE', 'CRM_ARQUITETO', 'CONNECT_CR', 'CONNECT_CP',
                             'FORNECEDOR', 'PROSPECCAO_SAO_PAULO']));

ALTER TABLE public.contato_tipos DROP CONSTRAINT contato_tipos_tipo_check;
ALTER TABLE public.contato_tipos ADD CONSTRAINT contato_tipos_tipo_check
  CHECK (tipo = ANY (ARRAY['cliente', 'arquiteto', 'engenheiro', 'fornecedor', 'funcionario',
                           'outro', 'construtora']));

COMMIT;
