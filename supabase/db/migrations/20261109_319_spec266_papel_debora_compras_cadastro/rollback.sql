BEGIN;
DELETE FROM public.usuario_papeis WHERE usuario_id = '78c716d7-9ca2-4449-8ac6-50c1905d21ef'
   AND papel_id IN (SELECT id FROM public.papeis WHERE nome = 'compras_cadastro_fornecedores');
INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT '78c716d7-9ca2-4449-8ac6-50c1905d21ef', id FROM public.papeis WHERE nome IN ('funcionario', 'compras_e_entregas')
ON CONFLICT DO NOTHING;
DELETE FROM public.papel_permissoes WHERE papel_id IN (SELECT id FROM public.papeis WHERE nome = 'compras_cadastro_fornecedores');
DELETE FROM public.papeis WHERE nome = 'compras_cadastro_fornecedores';
DELETE FROM public.modulo_acoes WHERE modulo_id IN (SELECT m.id FROM public.modulos m JOIN public.systems s ON s.id = m.system_id WHERE s.slug = 'crm' AND m.chave = 'fornecedores');
DELETE FROM public.modulos WHERE chave = 'fornecedores' AND system_id = (SELECT id FROM public.systems WHERE slug = 'crm');
COMMIT;
