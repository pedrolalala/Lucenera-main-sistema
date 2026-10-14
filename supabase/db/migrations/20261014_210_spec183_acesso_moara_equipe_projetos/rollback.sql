-- Rollback da migration 210: tira o papel e os 8 sistemas da Moara.
DELETE FROM public.user_system_access
WHERE user_id = (SELECT id FROM public.usuarios WHERE lower(email) = 'moara@lucenera.com.br')
  AND system_id IN (SELECT id FROM public.systems
    WHERE slug IN ('orcamentos', 'crm', 'cadastro', 'separacao-parcial', 'logistica', 'ubiqua', 'showroom', 'memoria'));
DELETE FROM public.usuario_papeis
WHERE usuario_id = (SELECT id FROM public.usuarios WHERE lower(email) = 'moara@lucenera.com.br')
  AND papel_id = (SELECT id FROM public.papeis WHERE nome = 'equipe_projetos');
