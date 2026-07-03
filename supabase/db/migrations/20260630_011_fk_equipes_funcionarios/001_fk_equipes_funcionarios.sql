-- Migration 20260630_011 — FK equipes_projetos → funcionarios_financeiro
--
-- A coluna equipes_id já existe em funcionarios_financeiro mas ainda não
-- possui constraint de chave estrangeira apontando para equipes_projetos.
-- Esta migration cria o vínculo formal entre as duas tabelas.
--
-- Comportamento ao deletar equipe: SET NULL — o funcionário não é removido,
-- apenas perde o vínculo com a equipe excluída.

ALTER TABLE public.funcionarios_financeiro
  ADD CONSTRAINT funcionarios_financeiro_equipes_id_fkey
  FOREIGN KEY (equipes_id)
  REFERENCES public.equipes_projetos (id)
  ON DELETE SET NULL;
