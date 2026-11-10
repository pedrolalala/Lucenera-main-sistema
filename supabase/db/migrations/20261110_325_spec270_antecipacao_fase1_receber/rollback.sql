-- Rollback SPEC-270 Fase 1. Antes: nenhuma antecipacao pode existir (cancele/estorne antes), senao a coluna some junto com o dado.
DROP FUNCTION IF EXISTS public.financeiro_cancelar_antecipacao(uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_lancar_antecipacao(public.fin_natureza, uuid, text, uuid, uuid, date, date, numeric, uuid, uuid, text, text);
ALTER TABLE public.financeiro_titulos DROP COLUMN IF EXISTS responsavel_id;
