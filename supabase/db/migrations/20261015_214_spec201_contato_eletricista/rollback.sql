-- Só funciona se não houver linha 'eletricista' em contato_tipos.
BEGIN;
ALTER TABLE public.contato_tipos DROP CONSTRAINT contato_tipos_tipo_check;
ALTER TABLE public.contato_tipos ADD CONSTRAINT contato_tipos_tipo_check
  CHECK (tipo = ANY (ARRAY['cliente', 'arquiteto', 'engenheiro', 'fornecedor', 'funcionario',
                           'outro', 'construtora', 'escritorio_arquitetura', 'incorporadora']));
COMMIT;
