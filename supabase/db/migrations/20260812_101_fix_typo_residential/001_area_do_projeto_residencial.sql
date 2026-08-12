-- SPEC-078 Bug 1: corrige o typo "Residential" (ingles) para "Residencial"
-- (portugues) no campo JSONB projetos.area_do_projeto->>'tipo'.
--
-- Achado durante a aplicacao: existe uma CHECK constraint real
-- (check_tipo_projeto_valido) que so permitia 'Residential' em ingles --
-- nao e so um valor de seed, e validacao de schema de verdade. Ordem
-- importa: precisa soltar a constraint, atualizar o dado, so depois
-- recriar a constraint com o valor novo -- senao a constraint nova
-- rejeita a linha antiga antes do UPDATE rodar.
BEGIN;

ALTER TABLE public.projetos DROP CONSTRAINT IF EXISTS check_tipo_projeto_valido;

UPDATE public.projetos
SET area_do_projeto = jsonb_set(area_do_projeto, '{tipo}', '"Residencial"')
WHERE area_do_projeto->>'tipo' = 'Residential';

ALTER TABLE public.projetos ADD CONSTRAINT check_tipo_projeto_valido
  CHECK (
    area_do_projeto IS NULL
    OR (area_do_projeto ->> 'tipo') IS NULL
    OR (area_do_projeto ->> 'tipo') = ANY (
      ARRAY['Residencial', 'Corporativo', 'Exposição Comercial', 'Paisagismo']
    )
  );

COMMIT;
