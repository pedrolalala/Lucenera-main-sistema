-- SPEC-023: adiciona empresa_id FK em funcionarios_beneficios_empresas
-- Elimina dependência de comparação de texto para o filtro de empresa no VT.

ALTER TABLE public.funcionarios_beneficios_empresas
  ADD COLUMN IF NOT EXISTS empresa_id uuid REFERENCES public.empresas(id);

-- Popular empresa_id a partir do texto existente (ILIKE para tolerar caixa)
UPDATE public.funcionarios_beneficios_empresas feb
SET empresa_id = e.id
FROM public.empresas e
WHERE feb.empresa_id IS NULL
  AND e.nome ILIKE feb.empresa;

-- Diagnóstico: registros que não encontraram correspondência
-- Execute antes de tornar NOT NULL para validar:
-- SELECT id, funcionario_id, empresa FROM public.funcionarios_beneficios_empresas
-- WHERE empresa_id IS NULL;

COMMENT ON COLUMN public.funcionarios_beneficios_empresas.empresa_id IS
'FK para empresas. Populado via SPEC-023. Futuramente substituir o campo texto empresa.';
