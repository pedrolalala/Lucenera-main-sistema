-- Desfaz a fase 2 da SPEC-206. Depois deste arquivo, rodar de novo
-- 20261019_221_spec206_auditoria_movimentacao/001_auditoria_movimentacao.sql (é idempotente e não apaga eventos):
-- ele recria auditoria.inserir, auditoria.fn_registrar, auditoria_listar e auditoria_resumo_usuarios da fase 1.
BEGIN;
DROP FUNCTION IF EXISTS public.auditoria_registrar_tela(text, text);
DROP FUNCTION IF EXISTS public.auditoria_registrar_acao(text, text, uuid);
DROP FUNCTION IF EXISTS public.auditoria_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean);
DROP FUNCTION IF EXISTS public.auditoria_resumo_usuarios(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS auditoria.inserir(uuid, text, text, text, text, text, jsonb, text, text, text);
COMMIT;
