-- SPEC-125 — Site publico do Showroom Lucenera (vitrine de pronta entrega).
--
-- Escopo desta migration (RASCUNHO — nao aplicar sem aprovacao do usuario):
--   1. produtos.imagem_showroom_url  -> nova coluna (nullable, sem default)
--   2. vw_showroom_publico           -> unica superficie de dados anonima
--   3. GRANT SELECT da view para anon
--   4. bucket de Storage publico `showroom-lucenera` + leitura anon
--
-- Decisao de seguranca (SPEC-125 P-6): a tabela `produtos` continua com RLS
-- `authenticated` + hub_pode_executar (SPEC-069/087). NAO abrimos policy `anon`
-- em `produtos`. A view abaixo e criada SEM `security_invoker`, entao roda com
-- os privilegios do dono (postgres, bypassa RLS) e expoe SOMENTE a whitelist de
-- colunas — nada de custo, margem, fiscal, fornecedor. O linter do Supabase vai
-- marcar `security_definer_view`: e intencional aqui.

begin;

-- 1. Coluna de foto do showroom -------------------------------------------------
alter table public.produtos
  add column if not exists imagem_showroom_url text;

comment on column public.produtos.imagem_showroom_url is
  'URL publica da foto da peca no showroom (bucket showroom-lucenera). '
  'Preenchida pelo import da lista do showroom (SPEC-125). NULL = nao aparece na vitrine.';

-- indice parcial: a vitrine sempre filtra por foto + estoque_showroom > 0
create index if not exists produtos_showroom_vitrine_idx
  on public.produtos (estoque_showroom)
  where imagem_showroom_url is not null and ativo;

-- 2. View publica da vitrine ---------------------------------------------------
drop view if exists public.vw_showroom_publico;

create view public.vw_showroom_publico as
select
  p.codigo_produto,
  p.nome,
  m.nome                              as marca,
  coalesce(cp.nome, nullif(p.categoria, '')) as categoria,
  p.estoque_showroom::int             as estoque_showroom,
  coalesce(p.valor_venda, 0)::numeric as valor_venda,
  nullif(p.descricao_tecnica, '')     as descricao_tecnica,
  p.imagem_showroom_url,
  p.updated_at                        as atualizado_em
from public.produtos p
left join public.marcas             m  on m.id  = p.marca_id
left join public.categorias_produto cp on cp.id = p.categoria_id
where p.ativo
  and p.imagem_showroom_url is not null
  and p.imagem_showroom_url <> ''
  and coalesce(p.estoque_showroom, 0) > 0;

comment on view public.vw_showroom_publico is
  'SPEC-125: superficie somente-leitura e anonima do showroom. Whitelist de '
  'colunas de produtos; ja filtra ativo + foto + estoque_showroom > 0. '
  'Sem security_invoker de proposito (bypassa RLS de produtos, expondo so estas colunas).';

-- 3. Acesso anonimo APENAS a view (somente leitura) -----------------------------
grant usage on schema public to anon;
grant select on public.vw_showroom_publico to anon;
-- O Supabase tem ALTER DEFAULT PRIVILEGES concedendo ALL em tabelas/views novas
-- para anon/authenticated. Tiramos tudo que nao seja SELECT (a view tem JOIN,
-- entao nem e atualizavel, mas deixamos explicito):
revoke insert, update, delete, truncate, references, trigger
  on public.vw_showroom_publico from anon, authenticated;
-- (nenhum grant novo em public.produtos)

-- 4. Storage: bucket publico de fotos do showroom ------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'showroom-lucenera',
  'showroom-lucenera',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

drop policy if exists "showroom_lucenera_public_read" on storage.objects;
create policy "showroom_lucenera_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'showroom-lucenera');

-- Upload/replace/delete: so via service_role (script de import da SPEC-125).
-- service_role ignora RLS, entao nao precisa de policy explicita de escrita.

commit;
