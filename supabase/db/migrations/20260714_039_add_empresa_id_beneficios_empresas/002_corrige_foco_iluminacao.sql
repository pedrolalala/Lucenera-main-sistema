-- SPEC-023 patch: registros com empresa='Foco' apontam para 'FOCO ILUMINACAO'
-- O ILIKE exato não encontrou match pois "Foco" ≠ "FOCO ILUMINACAO" (nome parcial)

UPDATE public.funcionarios_beneficios_empresas
SET empresa_id = '436913c7-ebd3-44ac-a3b3-14e9b7fbd591'  -- FOCO ILUMINACAO
WHERE empresa ILIKE 'Foco'
  AND empresa_id IS NULL;

-- Verificação final: não deve retornar linhas após este patch
-- SELECT id, empresa FROM public.funcionarios_beneficios_empresas WHERE empresa_id IS NULL;
