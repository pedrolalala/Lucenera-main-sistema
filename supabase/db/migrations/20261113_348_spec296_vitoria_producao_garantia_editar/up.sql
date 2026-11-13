-- SPEC-296 (13/11/2026): Vitoria passa a criar/editar em Controle de Producao e Controle de Garantia (antes so ver). Papel estoque_entrada_nf.
BEGIN;
INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, v.acao
  FROM public.papeis p
  JOIN public.systems s ON s.slug IN ('controle-producao','controle-garantia')
  CROSS JOIN (VALUES ('criar'),('editar')) AS v(acao)
 WHERE p.nome = 'estoque_entrada_nf'
   AND NOT EXISTS (SELECT 1 FROM public.papel_permissoes x WHERE x.papel_id = p.id AND x.system_id = s.id AND x.modulo_id IS NULL AND x.acao = v.acao);
NOTIFY pgrst, 'reload schema';
COMMIT;
