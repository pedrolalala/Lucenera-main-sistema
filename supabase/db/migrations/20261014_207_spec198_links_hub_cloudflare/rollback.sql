-- Rollback da migration 207 (SPEC-198): volta os links do Hub para o Skip.

UPDATE public.systems AS s SET link = v.antigo
FROM (VALUES
  ('hub',                   'https://central-lucenera-dashboard-1c9ba.goskip.app/dashboard', 'https://central-lucenera.pages.dev/dashboard'),
  ('crm',                   'https://lucenera-crm-3bd29.goskip.app/?v=1460a3e',              'https://crm-lucenera.pages.dev/'),
  ('rh',                    'https://dashboard-rh-lucenera-5fe9c.goskip.app/?v=930e4f5',     'https://rh-lucenera.pages.dev/'),
  ('cadastro',              'https://cadastro-lucenera-b86fe.goskip.app/',                   'https://cadastro-lucenera.pages.dev/'),
  ('orcamentos',            'https://gestaofinanceiralucenera.goskip.app/budgets',           'https://financeiro-lucenera.pages.dev/budgets'),
  ('necessidade-de-compra', 'https://pagina-em-branco-cdd79.goskip.app/?v=6994721',          'https://compras-lucenera.pages.dev/'),
  ('financeiro',            'https://retorno-bancario-bradesco-5392a.goskip.app/',           'https://adm-bancaria-lucenera.pages.dev/'),
  ('separacao-parcial',     'https://separacao-parcial-dff01.goskip.app/',                   'https://separacao-lucenera.pages.dev/'),
  ('dashboard-financeiro',  'https://dashboard-empresa-40d7d.goskip.app/',                   'https://dashboard-lucenera.pages.dev/'),
  ('showroom',              'https://tela-showroom-522b1.goskip.app/admin',                  'https://showroom-lucenera.pages.dev/admin'),
  ('vendas',                'https://pagina-de-vendas-9549c.goskip.app',                     'https://vendas-lucenera.pages.dev'),
  ('controle-producao',     'https://pagina-em-branco-e9c45.goskip.app',                     'https://producao-lucenera.pages.dev'),
  ('controle-garantia',     'https://pagina-em-branco-b044c.goskip.app',                     'https://garantia-lucenera.pages.dev')
) AS v(slug, antigo, novo)
WHERE s.slug = v.slug AND s.link = v.novo;
