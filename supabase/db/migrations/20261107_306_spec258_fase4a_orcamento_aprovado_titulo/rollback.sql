-- SPEC-258 Fase 4a: remove o espelho do funil. Os títulos/parcelas/baixas já espelhados PERMANECEM (histórico financeiro não se apaga);
-- depois do rollback, o que for gravado no funil antigo deixa de ser espelhado: antes de rodar, avise o financeiro.
DROP TRIGGER IF EXISTS trg_transacoes_financeiro_ponte ON public.transacoes;
DROP VIEW IF EXISTS public.vw_financeiro_ponte_integridade;
DROP FUNCTION IF EXISTS public.trg_financeiro_ponte();
DROP FUNCTION IF EXISTS public.financeiro_ponte_transacao(uuid);
DROP TABLE IF EXISTS public.financeiro_ponte_falhas;
-- as constraints relaxadas (origem 'ponte') ficam: baixas 'ponte' já existentes dependem delas.
