-- Novos tipos de contato (pedido do usuário, 09/10/2026):
--   * contato_tipos.tipo:     + 'escritorio_arquitetura', + 'incorporadora'
--   * contatos.tipo (enum contato_tipo): + 'escritorio_arquitetura', + 'incorporadora'
-- Mesmo padrão da migration 173 (construtora). Todos os valores atuais
-- continuam permitidos. O enum precisa dos valores porque o trigger
-- handle_contato_tipo copia contatos.tipo para contato_tipos.

-- Enum: ADD VALUE é aditivo e não reescreve a tabela.
ALTER TYPE public.contato_tipo ADD VALUE IF NOT EXISTS 'escritorio_arquitetura';
ALTER TYPE public.contato_tipo ADD VALUE IF NOT EXISTS 'incorporadora';

BEGIN;

ALTER TABLE public.contato_tipos DROP CONSTRAINT contato_tipos_tipo_check;
ALTER TABLE public.contato_tipos ADD CONSTRAINT contato_tipos_tipo_check
  CHECK (tipo = ANY (ARRAY['cliente', 'arquiteto', 'engenheiro', 'fornecedor', 'funcionario',
                           'outro', 'construtora', 'escritorio_arquitetura', 'incorporadora']));

COMMIT;
