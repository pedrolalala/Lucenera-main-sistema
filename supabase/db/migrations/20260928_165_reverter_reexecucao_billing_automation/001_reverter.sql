-- SPEC-165 (incidente 28/09/2026) — reverte a reexecução acidental da
-- migration legada 20260623190000_billing_automation, disparada pela etapa
-- "integrations" do Skip ao publicar a Administração Bancária (projeto
-- 36395). Ela rodou de novo no banco real e:
--   1. inseriu dados de teste (Empresa Teste Billing / Projeto Billing
--      Automation / 2 parcelas / 1 orçamento / 2 itens);
--   2. criou o bucket público `notas_fiscais` (não existia) + 2 policies;
--   3. recriou policies permissivas (USING true) que a SPEC-069 tinha
--      removido de propósito em orcamentos/boletos, e 2 redundantes em
--      projeto_parcelas.
-- Todos os ids abaixo foram conferidos: criados na mesma transação
-- (created_at = 2026-09-28 14:23:23.710268+00), nada mais os referencia.
-- O projeto de teste NÃO foi enviado ao SharePoint (sem linha em
-- sharepoint_sync_log; código PRJ-BILL não passa na trava de formato).

BEGIN;

DELETE FROM public.projeto_itens    WHERE projeto_id = '3f797b14-4926-41d0-9922-890cc4daf98e';
DELETE FROM public.projeto_parcelas WHERE projeto_id = '3f797b14-4926-41d0-9922-890cc4daf98e';
DELETE FROM public.orcamentos       WHERE id = 'ae42b297-730b-4b0a-97e9-f777529d60fd';
DELETE FROM public.projetos         WHERE id = '3f797b14-4926-41d0-9922-890cc4daf98e';
DELETE FROM public.empresas         WHERE id = 'a46083e1-bc2a-47c1-9ab6-a2dc3e26f9d8';

DROP POLICY IF EXISTS "Public notas_fiscais Read" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated notas_fiscais Insert" ON storage.objects;
-- O bucket (vazio) sai pela Storage API: DELETE /storage/v1/bucket/notas_fiscais
-- (storage.protect_delete bloqueia DELETE direto em storage.buckets).

-- Removidas pela SPEC-069 (20260806_085 / 20260810_091); voltam a sair.
DROP POLICY IF EXISTS authenticated_update_orcamentos ON public.orcamentos;
DROP POLICY IF EXISTS authenticated_select_boletos    ON public.boletos;
DROP POLICY IF EXISTS authenticated_insert_boletos    ON public.boletos;
DROP POLICY IF EXISTS authenticated_update_boletos    ON public.boletos;
-- Novas e redundantes (projeto_parcelas já tem as *_projeto_parcelas).
DROP POLICY IF EXISTS authenticated_select_parcelas   ON public.projeto_parcelas;
DROP POLICY IF EXISTS authenticated_update_parcelas   ON public.projeto_parcelas;

COMMIT;
