-- SPEC-201 B (15/10/2026): eletricista não podia ser cadastrado por ninguém.
-- O enum contatos.tipo já tem 'eletricista', mas o trigger handle_contato_tipo copia
-- o tipo para contato_tipos, cujo CHECK não aceitava o valor. Aditivo: todos os
-- valores atuais continuam permitidos.
BEGIN;

ALTER TABLE public.contato_tipos DROP CONSTRAINT contato_tipos_tipo_check;
ALTER TABLE public.contato_tipos ADD CONSTRAINT contato_tipos_tipo_check
  CHECK (tipo = ANY (ARRAY['cliente', 'arquiteto', 'engenheiro', 'eletricista', 'fornecedor', 'funcionario',
                           'outro', 'construtora', 'escritorio_arquitetura', 'incorporadora']));

COMMIT;
