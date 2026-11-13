-- SPEC-287 rollback: remove a funcao e a sequencia. ATENCAO: acordos ja criados continuam no financeiro
-- (parcelas originais 'renegociada' + baixas 'renegociacao'/'abatimento'); desfazer um acordo especifico e manual.
BEGIN;
DROP FUNCTION IF EXISTS public.financeiro_criar_acordo(uuid[], jsonb, numeric, text);
DROP SEQUENCE IF EXISTS public.seq_financeiro_acordo;
COMMIT;
