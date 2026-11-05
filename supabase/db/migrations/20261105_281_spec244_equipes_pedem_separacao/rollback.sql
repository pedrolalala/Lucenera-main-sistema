-- Rollback da 281: volta as políticas como estavam (só admin/gerente/operador em separacao_itens; delete de separacoes só pelo Hub).
BEGIN;
DROP POLICY IF EXISTS sep_itens_insert_hub ON public.separacao_itens;
DROP POLICY IF EXISTS sep_itens_update_hub ON public.separacao_itens;
DROP POLICY IF EXISTS separacoes_delete_vazia_propria ON public.separacoes;
COMMIT;
