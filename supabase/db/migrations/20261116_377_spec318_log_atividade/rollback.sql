-- Rollback da 377 (SPEC-318): remove so o que ela criou. auditoria.eventos e as RPCs antigas nao sao tocadas.
BEGIN;
DROP FUNCTION IF EXISTS public.auditoria_log_listar(timestamptz, timestamptz, text, uuid, text, text, int, int, boolean, text);
DROP FUNCTION IF EXISTS public.auditoria_log_resumo_usuarios(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.auditoria_log_filtros();
DROP FUNCTION IF EXISTS auditoria.pode_ver_log();
DROP TABLE IF EXISTS auditoria.log_visualizadores;
NOTIFY pgrst, 'reload schema';
COMMIT;
