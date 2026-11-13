BEGIN;
DELETE FROM public.usuario_permissao_excecoes e USING public.usuarios u, public.systems s
 WHERE e.usuario_id = u.id AND e.system_id = s.id AND lower(u.email) = 'matheus@lucenera.com.br'
   AND s.slug IN ('controle-producao','controle-garantia') AND e.modulo_id IS NULL AND e.acao IN ('criar','editar') AND e.tipo = 'conceder'
   AND e.justificativa LIKE 'SPEC-296:%';
NOTIFY pgrst, 'reload schema';
COMMIT;
