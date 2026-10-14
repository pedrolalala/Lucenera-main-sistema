-- SPEC-198 (14/10): Memória e Central de Solicitações também saem do Skip para a Cloudflare Pages.
-- Só a coluna systems.link; cada linha confere o link antigo.

UPDATE public.systems AS s SET link = v.novo
FROM (VALUES
  ('memoria',      'https://memoria-lucenera-2e074.goskip.app/',       'https://memoria-lucenera.pages.dev/'),
  ('solicitacoes', 'https://central-de-solicitacoes-cc2ec.goskip.app', 'https://solicitacoes-lucenera.pages.dev')
) AS v(slug, antigo, novo)
WHERE s.slug = v.slug AND s.link = v.antigo;
