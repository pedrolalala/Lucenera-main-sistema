-- Rollback da 20261008_187 (SPEC-184): volta a view anterior (definição salva em _view_atual.sql)
-- e remove tabela/RPCs. Rodar o CREATE OR REPLACE VIEW de _view_atual.sql ANTES do DROP TABLE.
--   CREATE OR REPLACE VIEW public.vw_showroom_publico AS <conteúdo de _view_atual.sql>;
DROP FUNCTION IF EXISTS public.showroom_ocultar_peca(text, text, integer);
DROP FUNCTION IF EXISTS public.showroom_reexibir_peca(text, text, integer);
DROP FUNCTION IF EXISTS public.showroom_listar_ocultas(text, text);
DROP TABLE IF EXISTS public.showroom_ocultos;
NOTIFY pgrst, 'reload schema';
