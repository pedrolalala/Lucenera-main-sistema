-- SPEC-258 Fase 1B: desfaz funcoes e views (nao toca nas tabelas da 1A).
DROP VIEW IF EXISTS public.vw_financeiro_novo_integridade;
DROP VIEW IF EXISTS public.vw_fluxo_caixa;
DROP VIEW IF EXISTS public.vw_historico_baixas;
DROP VIEW IF EXISTS public.vw_contas_a_pagar;
DROP VIEW IF EXISTS public.vw_contas_a_receber;
DROP VIEW IF EXISTS public.vw_financeiro_parcelas;
DROP FUNCTION IF EXISTS public.financeiro_aceitar_pendencia(uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_resolver_pendencia(uuid);
DROP FUNCTION IF EXISTS public.financeiro_abrir_pendencia(text, text, uuid, uuid, uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_estornar(uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_baixar(uuid, public.fin_baixa_tipo, numeric, date, uuid, text, text, numeric, numeric, numeric, uuid, text, text);
DROP FUNCTION IF EXISTS public.financeiro_cancelar_titulo(uuid, text);
DROP FUNCTION IF EXISTS public.financeiro_substituir_previsao(uuid, jsonb);
DROP FUNCTION IF EXISTS public.financeiro_confirmar_parcelas(uuid);
DROP FUNCTION IF EXISTS public.financeiro_criar_titulo(jsonb, jsonb);
DROP FUNCTION IF EXISTS public.financeiro_exige(public.fin_especie);
