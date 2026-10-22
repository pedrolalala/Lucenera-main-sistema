-- Rollback SPEC-219: remove empréstimos do Showroom.
-- ATENÇÃO: se já houver empréstimo real, copiar antes para o schema backup:
--   CREATE TABLE backup._bkp_showroom_emprestimos_AAAAMMDD AS SELECT * FROM public.showroom_emprestimos;
--   CREATE TABLE backup._bkp_showroom_emprestimo_itens_AAAAMMDD AS SELECT * FROM public.showroom_emprestimo_itens;
BEGIN;
DROP FUNCTION IF EXISTS public.showroom_emp_cancelar(text, text, uuid, text);
DROP FUNCTION IF EXISTS public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric);
DROP FUNCTION IF EXISTS public.showroom_emp_obter(text, text, uuid);
DROP FUNCTION IF EXISTS public.showroom_emp_listar(text, text, text, text);
DROP FUNCTION IF EXISTS public.showroom_emp_criar(text, text, uuid, uuid, date, text, jsonb);
DROP FUNCTION IF EXISTS public.showroom_emp_em_aberto_por_peca(text, text, integer[]);
DROP FUNCTION IF EXISTS public.showroom_emp_listar_empresas(text, text);
DROP FUNCTION IF EXISTS public.showroom_emp_buscar_cliente(text, text, text);
DROP FUNCTION IF EXISTS public.showroom_emp_status(uuid);
DROP TABLE IF EXISTS public.showroom_emprestimo_itens;
DROP TABLE IF EXISTS public.showroom_emprestimos;
COMMIT;
