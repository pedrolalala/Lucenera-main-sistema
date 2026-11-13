BEGIN;
DELETE FROM public.papel_permissoes pp USING public.papeis p, public.systems s
 WHERE pp.papel_id = p.id AND pp.system_id = s.id AND p.nome = 'estoque_entrada_nf'
   AND s.slug IN ('controle-producao','controle-garantia') AND pp.acao IN ('criar','editar');
NOTIFY pgrst, 'reload schema';
COMMIT;
