-- Devolve o papel admin a Caroline e remove o papel novo.
INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id FROM public.usuarios u, public.papeis p
WHERE lower(u.email) = 'caroline@lucenera.com.br' AND p.nome = 'admin'
  AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis x WHERE x.usuario_id = u.id AND x.papel_id = p.id);
DELETE FROM public.usuario_papeis WHERE papel_id IN (SELECT id FROM public.papeis WHERE nome = 'assistente_administrativa');
DELETE FROM public.papel_permissoes WHERE papel_id IN (SELECT id FROM public.papeis WHERE nome = 'assistente_administrativa');
DELETE FROM public.papeis WHERE nome = 'assistente_administrativa';
