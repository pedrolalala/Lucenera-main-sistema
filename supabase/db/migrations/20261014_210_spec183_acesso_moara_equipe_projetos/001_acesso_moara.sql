-- SPEC-183 (14/10): Moara (Assistente Projetista, depto Projetos, conta criada em 08/10) entrava na Central e via
-- "Sem acesso configurado": não tinha papel nem sistema. Recebe o papel equipe_projetos (ações) e os mesmos 8 sistemas
-- do resto da Equipe de Projetos (visibilidade, igual à migration 208). Só acrescenta.

INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id
FROM public.usuarios u
JOIN public.papeis p ON p.nome = 'equipe_projetos'
WHERE lower(u.email) = 'moara@lucenera.com.br'
ON CONFLICT DO NOTHING;

INSERT INTO public.user_system_access (user_id, system_id)
SELECT u.id, s.id
FROM public.usuarios u
CROSS JOIN public.systems s
WHERE lower(u.email) = 'moara@lucenera.com.br'
  AND s.slug IN ('orcamentos', 'crm', 'cadastro', 'separacao-parcial', 'logistica', 'ubiqua', 'showroom', 'memoria')
ON CONFLICT (user_id, system_id) DO NOTHING;
