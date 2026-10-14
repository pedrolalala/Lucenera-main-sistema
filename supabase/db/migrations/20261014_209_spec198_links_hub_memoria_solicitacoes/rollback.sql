-- Rollback da migration 209 (SPEC-198): volta Memória e Central de Solicitações para o Skip.

UPDATE public.systems AS s SET link = v.antigo
FROM (VALUES
  ('memoria',      'https://memoria-lucenera-2e074.goskip.app/',       'https://memoria-lucenera.pages.dev/'),
  ('solicitacoes', 'https://central-de-solicitacoes-cc2ec.goskip.app', 'https://solicitacoes-lucenera.pages.dev')
) AS v(slug, antigo, novo)
WHERE s.slug = v.slug AND s.link = v.novo;
