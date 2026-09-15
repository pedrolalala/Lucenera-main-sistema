-- SPEC-148 — Showroom /admin: peça composta, 1 foto para N produtos (Fluxo B).
--
-- RASCUNHO — não aplicar sem aprovação. DDL: 1 tabela nova + índice único + 2
-- RPCs de composição + recriação de 2 RPCs de leitura (com 2 colunas novas
-- cada) + redesenho de `vw_showroom_publico`.
--
-- Objetivo: representar, com uma única foto, um conjunto de vários produtos de
-- estoque vendidos fisicamente juntos (ex.: base + haste + cúpula). 1 produto
-- principal guarda a foto/nome; N produtos membros contribuem valor e limitam
-- a disponibilidade do conjunto. Depende da migration anterior
-- (001_fotos_estoque.sql, mesmo grupo) só por ordem de aplicação — não há FK
-- entre as duas.
--
-- 3 regras confirmadas por Pedro em 2026-09-15 (ver SPEC-148 §4.5, P-6/P-7/P-8):
-- (1) um produto só pode ser membro de 1 conjunto por vez (índice único);
-- (2) membro inativo dentro de um conjunto ativo zera a disponibilidade do
--     conjunto inteiro (conjunto some da vitrine);
-- (3) campo "quantidade" por membro disponível na UI desde o dia 1.

begin;

-- 1. Modelo de dados: showroom_grupo_itens ---------------------------------------
create table if not exists public.showroom_grupo_itens (
  codigo_produto_principal int not null references public.produtos(codigo_produto),
  codigo_produto_membro    int not null references public.produtos(codigo_produto),
  quantidade               int not null default 1 check (quantidade > 0),
  criado_em                timestamptz not null default now(),
  criado_por               text,
  primary key (codigo_produto_principal, codigo_produto_membro),
  check (codigo_produto_membro <> codigo_produto_principal)
);
comment on table public.showroom_grupo_itens is
  'SPEC-148: peca composta do showroom -- N produtos de estoque vinculados a 1 foto/produto '
  'principal. Nome exibido = produtos.nome do principal. Valor exibido = valor_venda do '
  'principal + soma(valor_venda * quantidade) dos membros. Estoque exibido = minimo de '
  '"conjuntos completos" possiveis entre principal e membros.';

-- Um produto so pode ser membro de, no maximo, 1 conjunto por vez (P-6, confirmado por Pedro).
create unique index if not exists showroom_grupo_itens_membro_unico
  on public.showroom_grupo_itens (codigo_produto_membro);

alter table public.showroom_grupo_itens enable row level security;
-- Sem policy de select/insert/update/delete p/ anon/authenticated -- so e lida/escrita via RPC
-- SECURITY DEFINER (showroom_definir_composicao/showroom_obter_composicao) e pela view publica
-- (que roda como owner/postgres, bypassa RLS -- mesmo padrao ja usado em vw_showroom_publico
-- desde a migration 126).

-- 2. RPCs de composição -----------------------------------------------------------
create or replace function public.showroom_definir_composicao(
  p_user text, p_senha text, p_codigo_produto_principal int, p_membros jsonb
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_membro record;
  v_count  int;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  if not exists (select 1 from public.produtos where codigo_produto = p_codigo_produto_principal and ativo) then
    raise exception 'produto principal % nao encontrado/ativo', p_codigo_produto_principal using errcode = 'P0002';
  end if;

  -- principal nao pode, ele mesmo, ja ser membro de outro conjunto
  if exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_membro = p_codigo_produto_principal) then
    raise exception 'produto % ja e membro de outro conjunto, nao pode virar principal', p_codigo_produto_principal using errcode = '22000';
  end if;

  -- valida o payload inteiro ANTES de tocar em qualquer dado (evita rollback no meio)
  for v_membro in
    select (elem->>'codigo_produto')::int as codigo_produto,
           coalesce((elem->>'quantidade')::int, 1) as quantidade
    from jsonb_array_elements(coalesce(p_membros, '[]'::jsonb)) elem
  loop
    if v_membro.codigo_produto is null or v_membro.codigo_produto = p_codigo_produto_principal then
      raise exception 'membro invalido (codigo % invalido ou igual ao principal)', v_membro.codigo_produto using errcode = '22000';
    end if;
    if v_membro.quantidade < 1 then
      raise exception 'quantidade invalida para produto %', v_membro.codigo_produto using errcode = '22000';
    end if;
    if not exists (select 1 from public.produtos where codigo_produto = v_membro.codigo_produto and ativo) then
      raise exception 'produto membro % nao encontrado/ativo', v_membro.codigo_produto using errcode = 'P0002';
    end if;
    if exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_principal = v_membro.codigo_produto) then
      raise exception 'produto % ja e principal de outro conjunto', v_membro.codigo_produto using errcode = '22000';
    end if;
    if exists (
      select 1 from public.showroom_grupo_itens g
      where g.codigo_produto_membro = v_membro.codigo_produto
        and g.codigo_produto_principal <> p_codigo_produto_principal
    ) then
      raise exception 'produto % ja pertence a outro conjunto', v_membro.codigo_produto using errcode = '22000';
    end if;
  end loop;

  delete from public.showroom_grupo_itens where codigo_produto_principal = p_codigo_produto_principal;

  insert into public.showroom_grupo_itens (codigo_produto_principal, codigo_produto_membro, quantidade, criado_por)
  select p_codigo_produto_principal, (elem->>'codigo_produto')::int, coalesce((elem->>'quantidade')::int, 1), p_user
  from jsonb_array_elements(coalesce(p_membros, '[]'::jsonb)) elem;

  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'codigo_produto_principal', p_codigo_produto_principal, 'membros', v_count);
end;
$$;

create or replace function public.showroom_obter_composicao(p_codigo_produto_principal int)
returns table (codigo_produto int, nome text, sku text, estoque_showroom int, valor_venda numeric, quantidade int)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.sku, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0), g.quantidade
  from public.showroom_grupo_itens g
  join public.produtos p on p.codigo_produto = g.codigo_produto_membro
  where g.codigo_produto_principal = p_codigo_produto_principal
  order by p.nome;
$$;

grant execute on function public.showroom_definir_composicao(text,text,int,jsonb) to anon, authenticated;
grant execute on function public.showroom_obter_composicao(int) to anon, authenticated;

-- `showroom_definir_composicao` é substituição total e idempotente da lista de membros de
-- um principal — mandar `[]` limpa o conjunto (produto volta a ser peça avulsa). Não existe
-- RPC separada de "remover 1 membro"; a UI sempre manda a lista completa de novo (mesmo
-- padrão "replace" já usado noutros pontos do ecossistema, ex. `replace_orcamento_itens`).

-- 3. Recriação de showroom_listar_produtos_estoque (nova) e showroom_buscar_produto -------
--    (já existe desde a migration 127) com as 2 colunas de composição.
drop function if exists public.showroom_listar_produtos_estoque(text);
create or replace function public.showroom_listar_produtos_estoque(p_termo text default null)
returns table (
  codigo_produto int, nome text, sku text, referencia text,
  estoque_showroom int, imagem_showroom_url text, marca text,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.sku, p.referencia,
         coalesce(p.estoque_showroom,0), p.imagem_showroom_url, m.nome,
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and coalesce(p.estoque_showroom,0) > 0
    and (
      p_termo is null or p_termo = ''
      or p.nome ilike '%'||p_termo||'%'
      or p.sku ilike '%'||p_termo||'%'
      or p.referencia ilike '%'||p_termo||'%'
      or p.codigo_produto::text = p_termo
    )
  order by (p.imagem_showroom_url is null) desc, p.nome
  limit 1000;
$$;
grant execute on function public.showroom_listar_produtos_estoque(text) to anon, authenticated;

drop function if exists public.showroom_buscar_produto(text);
create or replace function public.showroom_buscar_produto(p_termo text)
returns table (
  codigo_produto int, nome text, marca text, estoque_showroom int, valor_venda numeric,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0),
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.sku ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$$;
grant execute on function public.showroom_buscar_produto(text) to anon, authenticated;

-- Nota: hoje `produtos` com `estoque_showroom > 0` são ~266 (achado da SPEC-125). `limit 1000`
-- cobre isso com folga; se crescer muito, paginar (mesma lição da SPEC-081) -- ver P-4.

-- 4. Redesenho de vw_showroom_publico (contrato de colunas preservado) --------------------
drop view if exists public.vw_showroom_publico;

create view public.vw_showroom_publico as
with avulsas as (
  select
    p.codigo_produto, p.nome, m.nome as marca,
    coalesce(cp.nome, nullif(p.categoria, '')) as categoria,
    p.estoque_showroom::int as estoque_showroom,
    coalesce(p.valor_venda, 0)::numeric as valor_venda,
    nullif(p.descricao_tecnica, '') as descricao_tecnica,
    p.imagem_showroom_url, p.updated_at as atualizado_em
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  left join public.categorias_produto cp on cp.id = p.categoria_id
  where p.ativo
    and p.imagem_showroom_url is not null and p.imagem_showroom_url <> ''
    and coalesce(p.estoque_showroom, 0) > 0
    -- exclui quem e membro de algum conjunto (nao aparece avulso, ja esta "dentro" do principal)
    and not exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_membro = p.codigo_produto)
    -- exclui quem E principal de algum conjunto (esse vai pelo ramo "conjuntos" abaixo, com valor/estoque agregados)
    and not exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_principal = p.codigo_produto)
),
conjuntos_agregado as (
  select
    g.codigo_produto_principal,
    sum(coalesce(pm.valor_venda,0) * g.quantidade) as valor_membros,
    -- "quantos conjuntos completos dá pra montar" olhando só os membros; membro inativo conta
    -- como estoque 0 (P-7, confirmado por Pedro)
    min(floor((case when pm.ativo then coalesce(pm.estoque_showroom,0) else 0 end)::numeric / g.quantidade))::int as min_conjuntos_membros
  from public.showroom_grupo_itens g
  join public.produtos pm on pm.codigo_produto = g.codigo_produto_membro
  group by g.codigo_produto_principal
),
conjuntos as (
  select
    pr.codigo_produto, pr.nome, mpr.nome as marca,
    coalesce(cppr.nome, nullif(pr.categoria, '')) as categoria,
    least(coalesce(pr.estoque_showroom,0), coalesce(ca.min_conjuntos_membros, 0))::int as estoque_showroom,
    (coalesce(pr.valor_venda,0) + coalesce(ca.valor_membros,0))::numeric as valor_venda,
    nullif(pr.descricao_tecnica, '') as descricao_tecnica,
    pr.imagem_showroom_url, pr.updated_at as atualizado_em
  from conjuntos_agregado ca
  join public.produtos pr on pr.codigo_produto = ca.codigo_produto_principal
  left join public.marcas mpr on mpr.id = pr.marca_id
  left join public.categorias_produto cppr on cppr.id = pr.categoria_id
  where pr.ativo and pr.imagem_showroom_url is not null and pr.imagem_showroom_url <> ''
)
select * from avulsas
union all
select * from conjuntos where estoque_showroom > 0;

comment on view public.vw_showroom_publico is
  'SPEC-125 + SPEC-148: superficie somente-leitura e anonima do showroom. 1 linha por "peca '
  'exibida" -- avulsa (1 produto) ou conjunto (1 principal + N membros, valor somado, estoque '
  '= minimo de conjuntos completos). Mesmo contrato de colunas desde a SPEC-125.';

grant select on public.vw_showroom_publico to anon;
revoke insert, update, delete, truncate, references, trigger on public.vw_showroom_publico from anon, authenticated;

-- Contrato preservado: mesmas 9 colunas, `codigo_produto` continua sendo o identificador da
-- peça exibida (do principal, quando for conjunto) — PecaDetalhe.tsx/PecaCard.tsx/useVitrine.ts
-- não precisam mudar.
--
-- Casos que já se resolvem sozinhos pela fórmula (não são decisão de negócio):
-- - Principal desativado (ativo = false) -> some da vitrine (mesmo filtro de sempre).
-- - Principal com estoque_showroom = 0 -> LEAST(0, ...) zera o conjunto -> some da vitrine.

commit;
