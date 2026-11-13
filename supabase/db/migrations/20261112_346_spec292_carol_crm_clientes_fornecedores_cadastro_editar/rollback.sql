-- Rollback SPEC-292: volta ao estado da migration 323 (Cadastro so visualizar, sem CRM). O modulo 'clientes' fica (inofensivo).
BEGIN;
DELETE FROM public.papel_permissoes pp USING public.papeis p, public.systems s
 WHERE pp.papel_id = p.id AND pp.system_id = s.id AND p.nome = 'assistente_administrativa'
   AND ((s.slug = 'crm') OR (s.slug = 'cadastro' AND pp.modulo_id IS NULL AND pp.acao IN ('criar', 'editar')));
DELETE FROM public.user_system_access a USING public.usuarios u, public.systems s
 WHERE a.user_id = u.id AND a.system_id = s.id AND lower(u.email) = 'caroline@lucenera.com.br' AND s.slug = 'crm';
NOTIFY pgrst, 'reload schema';
COMMIT;
