-- SPEC-296 (13/11/2026): Matheus passa a criar/editar em Controle de Producao e Controle de Garantia (antes so ver, pelo papel estoque).
-- Excecao individual (nao mexe no papel estoque, que o Alexandre tambem usa).
BEGIN;
INSERT INTO public.usuario_permissao_excecoes (usuario_id, system_id, modulo_id, acao, tipo, justificativa)
SELECT u.id, s.id, NULL, v.acao, 'conceder', 'SPEC-296: Matheus lanca/edita producao e garantia (13/11/2026)'
  FROM public.usuarios u
  JOIN public.systems s ON s.slug IN ('controle-producao','controle-garantia')
  CROSS JOIN (VALUES ('criar'),('editar')) AS v(acao)
 WHERE lower(u.email) = 'matheus@lucenera.com.br'
   AND NOT EXISTS (SELECT 1 FROM public.usuario_permissao_excecoes e WHERE e.usuario_id = u.id AND e.system_id = s.id
                    AND e.modulo_id IS NULL AND e.acao = v.acao AND e.tipo = 'conceder');
NOTIFY pgrst, 'reload schema';
COMMIT;
