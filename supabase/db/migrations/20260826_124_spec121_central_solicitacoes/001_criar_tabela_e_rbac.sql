-- SPEC-121: Central de Solicitações (bugs e pedidos de alteração) com triagem por IA
--
-- Cria a tabela `solicitacoes`, cadastra o novo sistema em `public.systems`
-- e concede RBAC: todo papel existente ganha criar+visualizar no sistema
-- novo (toda a equipe pode abrir pedidos); admin_geral ganha também
-- aprovar (controla mudança de status no board).

-- 1. Novo sistema no catálogo (fonte usada pelo Hub/SystemSwitcher/hub_sistemas_permitidos)
insert into public.systems (name, description, slug, link, icon_name, display_order, visivel_no_hub)
values (
  'Central de Solicitações',
  'Registro e triagem de bugs e pedidos de alteração da equipe, com classificação automática por IA (estrutural x pontual).',
  'solicitacoes',
  'https://central-de-solicitacoes-cc2ec.goskip.app',
  'ClipboardList',
  100,
  true
)
on conflict (slug) do nothing;

-- 2. Tabela de pedidos
create table if not exists public.solicitacoes (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id),
  titulo text not null,
  descricao text not null,
  sistema_relacionado_id uuid references public.systems(id),
  tipo text not null check (tipo in ('bug', 'pedido_alteracao')),
  classificacao_ia text check (classificacao_ia in ('estrutural', 'pontual')),
  justificativa_ia text,
  confianca_ia numeric,
  status text not null default 'aberto'
    check (status in ('aberto', 'em_analise', 'aprovado', 'rejeitado', 'em_desenvolvimento', 'concluido')),
  spec_numero text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists idx_solicitacoes_status on public.solicitacoes(status);
create index if not exists idx_solicitacoes_usuario on public.solicitacoes(usuario_id);
create index if not exists idx_solicitacoes_sistema on public.solicitacoes(sistema_relacionado_id);

-- trigger simples pra manter atualizado_em em dia
create or replace function public.fn_solicitacoes_set_atualizado_em()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

drop trigger if exists trg_solicitacoes_atualizado_em on public.solicitacoes;
create trigger trg_solicitacoes_atualizado_em
  before update on public.solicitacoes
  for each row
  execute function public.fn_solicitacoes_set_atualizado_em();

-- 3. RLS
alter table public.solicitacoes enable row level security;

-- Qualquer autenticado ve todos os pedidos (transparencia - é o motivo do board existir)
drop policy if exists solicitacoes_select_autenticado on public.solicitacoes;
create policy solicitacoes_select_autenticado
  on public.solicitacoes for select
  to authenticated
  using (true);

-- Qualquer autenticado cria pedido em seu proprio nome
drop policy if exists solicitacoes_insert_proprio on public.solicitacoes;
create policy solicitacoes_insert_proprio
  on public.solicitacoes for insert
  to authenticated
  with check (usuario_id = auth.uid());

-- Autor edita titulo/descricao enquanto o pedido segue "aberto";
-- mudar status/classificacao/spec_numero exige hub_pode_executar(...,'aprovar')
drop policy if exists solicitacoes_update_autor_aberto on public.solicitacoes;
create policy solicitacoes_update_autor_aberto
  on public.solicitacoes for update
  to authenticated
  using (usuario_id = auth.uid() and status = 'aberto')
  with check (usuario_id = auth.uid());

drop policy if exists solicitacoes_update_aprovador on public.solicitacoes;
create policy solicitacoes_update_aprovador
  on public.solicitacoes for update
  to authenticated
  using (public.hub_pode_executar(auth.uid(), 'solicitacoes', null, 'aprovar'))
  with check (public.hub_pode_executar(auth.uid(), 'solicitacoes', null, 'aprovar'));

-- service_role (Edge Function) grava a classificacao da IA sem restricao
drop policy if exists solicitacoes_update_service_role on public.solicitacoes;
create policy solicitacoes_update_service_role
  on public.solicitacoes for update
  to service_role
  using (true)
  with check (true);

-- 4. RBAC: todo papel ganha criar+visualizar no sistema novo
do $$
declare
  v_system_id uuid;
  v_papel record;
begin
  select id into v_system_id from public.systems where slug = 'solicitacoes';

  for v_papel in select id from public.papeis loop
    insert into public.papel_permissoes (papel_id, system_id, modulo_id, acao)
    values (v_papel.id, v_system_id, null, 'criar')
    on conflict do nothing;

    insert into public.papel_permissoes (papel_id, system_id, modulo_id, acao)
    values (v_papel.id, v_system_id, null, 'visualizar')
    on conflict do nothing;
  end loop;

  -- admin_geral ganha tambem aprovar (mudar status no board)
  insert into public.papel_permissoes (papel_id, system_id, modulo_id, acao)
  select id, v_system_id, null, 'aprovar'
  from public.papeis
  where nome = 'admin_geral'
  on conflict do nothing;
end;
$$;
