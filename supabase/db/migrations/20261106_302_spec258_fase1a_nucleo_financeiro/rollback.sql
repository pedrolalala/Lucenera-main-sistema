-- SPEC-258 Fase 1A: desfaz o núcleo novo. Só é seguro enquanto as tabelas estiverem VAZIAS (Fase 1). Depois que houver dados migrados, NÃO rodar:
-- o "antes" estaria no schema backup (Fase 2) e este rollback apagaria o histórico financeiro permanente.
DROP TABLE IF EXISTS public.financeiro_eventos;
DROP TABLE IF EXISTS public.financeiro_legado_ids;
DROP TABLE IF EXISTS public.financeiro_pendencias;
DROP TABLE IF EXISTS public.financeiro_renegociacoes;
DROP TABLE IF EXISTS public.financeiro_baixas;
DROP TABLE IF EXISTS public.financeiro_cobrancas;
DROP TABLE IF EXISTS public.financeiro_parcelas;
DROP TABLE IF EXISTS public.financeiro_titulos;
DROP TABLE IF EXISTS public.financeiro_regras_repasse;
DROP FUNCTION IF EXISTS public.financeiro_registrar_evento();
DROP FUNCTION IF EXISTS public.financeiro_titulo_legado_imutavel();
DROP FUNCTION IF EXISTS public.financeiro_parcela_legado_imutavel();
DROP FUNCTION IF EXISTS public.financeiro_baixa_valida();
DROP FUNCTION IF EXISTS public.financeiro_baixa_imutavel();
DROP FUNCTION IF EXISTS public.financeiro_recalcula_liquidado();
DROP FUNCTION IF EXISTS public.financeiro_parcela_liquidado_travado();
DROP TYPE IF EXISTS public.fin_pendencia_status;
DROP TYPE IF EXISTS public.fin_cobranca_meio;
DROP TYPE IF EXISTS public.fin_baixa_tipo;
DROP TYPE IF EXISTS public.fin_situacao;
DROP TYPE IF EXISTS public.fin_especie;
DROP TYPE IF EXISTS public.fin_origem;
DROP TYPE IF EXISTS public.fin_natureza;
