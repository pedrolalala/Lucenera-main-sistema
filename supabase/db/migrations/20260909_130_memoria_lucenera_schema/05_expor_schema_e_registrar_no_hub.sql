-- SPEC-129 — passos no schema public / config da API.
-- Rodar no SQL Editor do Supabase (projeto Lucenera). Idempotente.

-- 1) Expor o schema `memoria` na API (equivale ao campo
--    "Project Settings → API → Exposed schemas" do painel).
--    Hoje o `authenticator` não tem `pgrst.db_schemas` customizado, então o valor
--    efetivo é o padrão do Supabase: `public, graphql_public`.
alter role authenticator set pgrst.db_schemas = 'public, graphql_public, memoria';
notify pgrst, 'reload config';

-- 2) Registrar a Memória Lucenera no Hub (tabela lida por Dashboard.tsx /
--    hub_sistemas_permitidos / SystemSwitcher). `visivel_no_hub = true` +
--    acesso liberado a todos (decisão fase 1 da SPEC-129).
insert into public.systems (slug, name, description, link, icon_name, display_order, visivel_no_hub)
values (
  'memoria',
  'Memória Lucenera',
  'Base de conhecimento institucional da Lucenera: entidades, conhecimentos, experiências, decisões e conexões.',
  'https://memoria-lucenera-2e074.goskip.app/',
  'BrainCircuit',
  11,
  true
)
on conflict (slug) do update set
  name           = excluded.name,
  description    = excluded.description,
  link           = excluded.link,
  icon_name      = excluded.icon_name,
  display_order  = excluded.display_order,
  visivel_no_hub = excluded.visivel_no_hub;

-- Verificação
select id, slug, name, link, icon_name, display_order, visivel_no_hub
from public.systems where slug = 'memoria';
