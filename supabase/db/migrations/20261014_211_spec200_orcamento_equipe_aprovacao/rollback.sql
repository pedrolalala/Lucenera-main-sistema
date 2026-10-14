-- Rollback da migration 211 (SPEC-200). As funções originais estão em rollback_funcoes_originais.sql:
-- rodar ESTE arquivo e depois aquele.
BEGIN;
DROP POLICY IF EXISTS spec200_orcamentos_equipe ON public.orcamentos;
DROP TRIGGER IF EXISTS trg_1_orcamento_equipe_digitador ON public.orcamentos;
DROP FUNCTION IF EXISTS public.orcamento_definir_equipe_digitador();
DELETE FROM public.papel_permissoes pp USING public.modulos m
  WHERE pp.modulo_id = m.id AND m.chave = 'aprovacao_cliente';
DELETE FROM public.modulos WHERE chave = 'aprovacao_cliente';
COMMIT;
-- Depois de rodar rollback_funcoes_originais.sql (que não usa mais as funções abaixo):
-- DROP FUNCTION public.orcamento_da_minha_equipe(uuid, uuid); DROP FUNCTION public.orcamentos_equipe_restrita();
-- ALTER TABLE public.orcamentos DROP COLUMN equipe_id;
