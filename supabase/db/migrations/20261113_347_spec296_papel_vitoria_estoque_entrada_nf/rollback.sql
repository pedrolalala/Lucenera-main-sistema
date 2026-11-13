-- Rollback SPEC-296: Vitoria volta ao papel 'estoque' e aos 4 cards originais (cadastro, logistica, separacao-parcial, solicitacoes).
BEGIN;
DELETE FROM public.usuario_papeis up USING public.usuarios u, public.papeis p
 WHERE up.usuario_id = u.id AND up.papel_id = p.id AND lower(u.email) = 'vitoria@lucenera.com.br' AND p.nome = 'estoque_entrada_nf';
INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, p.id FROM public.usuarios u JOIN public.papeis p ON p.nome = 'estoque'
 WHERE lower(u.email) = 'vitoria@lucenera.com.br'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis x WHERE x.usuario_id = u.id AND x.papel_id = p.id);
DELETE FROM public.user_system_access a USING public.usuarios u, public.systems s
 WHERE a.user_id = u.id AND a.system_id = s.id AND lower(u.email) = 'vitoria@lucenera.com.br'
   AND s.slug IN ('orcamentos','controle-producao','controle-garantia','necessidade-de-compra');
DELETE FROM public.papeis WHERE nome = 'estoque_entrada_nf'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_papeis WHERE papel_id = papeis.id);
NOTIFY pgrst, 'reload schema';
COMMIT;
