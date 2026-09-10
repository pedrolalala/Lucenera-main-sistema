-- Memória Lucenera | Organização da Memória no schema isolado `memoria`.
-- Execute depois de supabase.sql. O script é repetível.
begin;

do $$ begin
  create type memoria.memory_rule_type as enum (
    'general_principle','extraction','relevance','classification','structuring',
    'naming','relationship','consolidation','provenance','updating','conflict',
    'deduplication','user_preference'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type memoria.memory_rule_scope as enum ('global','domain');
exception when duplicate_object then null; end $$;

do $$ begin
  create type memoria.memory_rule_origin as enum (
    'user_manual','ai_learned_candidate','ai_learned_confirmed','system_default'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type memoria.memory_rule_status as enum (
    'candidate','active','inactive','rejected','superseded'
  );
exception when duplicate_object then null; end $$;

create table if not exists memoria.memory_organization_rules (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null,
  rule_type memoria.memory_rule_type not null,
  scope memoria.memory_rule_scope not null default 'global',
  domain text,
  origin memoria.memory_rule_origin not null default 'user_manual',
  status memoria.memory_rule_status not null default 'active',
  priority integer not null default 50 check (priority between 0 and 100),
  confidence integer check (confidence between 0 and 100),
  rationale text,
  examples_positive jsonb not null default '[]'::jsonb,
  examples_negative jsonb not null default '[]'::jsonb,
  activated_at timestamptz,
  version integer not null default 1 check (version > 0),
  supersedes_rule_id uuid references memoria.memory_organization_rules(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint memory_rule_domain_scope check (
    (scope = 'global' and domain is null) or
    (scope = 'domain' and nullif(trim(domain), '') is not null)
  ),
  constraint memory_rule_candidate_activation check (
    not (origin = 'ai_learned_candidate' and status = 'active')
  ),
  constraint memory_rule_no_self_supersede check (supersedes_rule_id is null or supersedes_rule_id <> id)
);

create table if not exists memoria.memory_organization_feedback (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  context_type text not null,
  context_id uuid,
  domain text,
  proposal_before jsonb not null,
  accepted_after jsonb not null,
  diff jsonb not null default '{}'::jsonb,
  changed_fields text[] not null default '{}',
  source_type text,
  source_id uuid,
  explanation text,
  pattern_signature text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists memoria.memory_organization_rule_evidence (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  rule_id uuid not null references memoria.memory_organization_rules(id) on delete cascade,
  feedback_id uuid not null references memoria.memory_organization_feedback(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (rule_id, feedback_id)
);

create table if not exists memoria.memory_organization_rule_versions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  rule_id uuid not null references memoria.memory_organization_rules(id) on delete cascade,
  version_number integer not null,
  snapshot jsonb not null,
  change_reason text,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id),
  unique (rule_id, version_number)
);

create table if not exists memoria.memory_organization_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  minimum_evidence integer not null default 3 check (minimum_evidence between 2 and 20),
  minimum_confidence integer not null default 70 check (minimum_confidence between 0 and 100),
  minimum_diverse_contexts integer not null default 2 check (minimum_diverse_contexts between 1 and 20),
  updated_at timestamptz not null default now()
);
alter table memoria.memory_organization_settings
  add column if not exists minimum_diverse_contexts integer not null default 2
  check (minimum_diverse_contexts between 1 and 20);

create table if not exists memoria.memory_organization_conflicts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  rule_a_id uuid not null references memoria.memory_organization_rules(id) on delete cascade,
  rule_b_id uuid not null references memoria.memory_organization_rules(id) on delete cascade,
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  description text,
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (rule_a_id <> rule_b_id)
);

create index if not exists memory_rules_owner_status_idx
  on memoria.memory_organization_rules(owner_id, status);
create index if not exists memory_rules_scope_domain_idx
  on memoria.memory_organization_rules(owner_id, scope, domain) where deleted_at is null;
create index if not exists memory_feedback_pattern_idx
  on memoria.memory_organization_feedback(owner_id, pattern_signature, created_at desc);
create index if not exists memory_evidence_rule_idx
  on memoria.memory_organization_rule_evidence(owner_id, rule_id);
create unique index if not exists memory_conflict_pair_idx
  on memoria.memory_organization_conflicts(owner_id, least(rule_a_id, rule_b_id), greatest(rule_a_id, rule_b_id))
  where status = 'open';

create or replace function memoria.archive_memory_organization_rule()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  insert into memoria.memory_organization_rule_versions(
    owner_id, rule_id, version_number, snapshot, change_reason, changed_by
  ) values (
    old.owner_id, old.id, old.version, to_jsonb(old),
    coalesce(new.metadata->>'change_reason', 'Atualização da regra'), auth.uid()
  );
  new.version = old.version + 1;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists memory_organization_rule_versions on memoria.memory_organization_rules;
create trigger memory_organization_rule_versions
before update on memoria.memory_organization_rules
for each row execute function memoria.archive_memory_organization_rule();

create or replace function memoria.touch_memory_organization_settings()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists memory_organization_settings_touch on memoria.memory_organization_settings;
create trigger memory_organization_settings_touch
before update on memoria.memory_organization_settings
for each row execute function memoria.touch_memory_organization_settings();

alter table memoria.memory_organization_rules enable row level security;
alter table memoria.memory_organization_feedback enable row level security;
alter table memoria.memory_organization_rule_evidence enable row level security;
alter table memoria.memory_organization_rule_versions enable row level security;
alter table memoria.memory_organization_settings enable row level security;
alter table memoria.memory_organization_conflicts enable row level security;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'memory_organization_rules','memory_organization_feedback',
    'memory_organization_rule_evidence','memory_organization_rule_versions',
    'memory_organization_settings','memory_organization_conflicts'
  ] loop
    execute format('drop policy if exists %I on memoria.%I', table_name || ' owner access', table_name);
    execute format(
      'create policy %I on memoria.%I for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()))',
      table_name || ' owner access', table_name
    );
  end loop;
end $$;

-- Garante que evidências nunca conectem objetos pertencentes a usuários diferentes.
create or replace function memoria.validate_memory_rule_evidence_owner()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (
    select 1 from memoria.memory_organization_rules r
    join memoria.memory_organization_feedback f on f.id = new.feedback_id
    where r.id = new.rule_id and r.owner_id = new.owner_id and f.owner_id = new.owner_id
  ) then raise exception 'Regra, feedback e evidência devem possuir o mesmo proprietário'; end if;
  return new;
end;
$$;
drop trigger if exists validate_memory_rule_evidence_owner on memoria.memory_organization_rule_evidence;
create trigger validate_memory_rule_evidence_owner
before insert or update on memoria.memory_organization_rule_evidence
for each row execute function memoria.validate_memory_rule_evidence_owner();

-- Impede referências cruzadas entre proprietários em conflitos e linhagens de regras.
create or replace function memoria.validate_memory_rule_owner_references()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_table_name = 'memory_organization_conflicts' and not exists (
    select 1 from memoria.memory_organization_rules a
    join memoria.memory_organization_rules b on b.id = new.rule_b_id
    where a.id = new.rule_a_id and a.owner_id = new.owner_id and b.owner_id = new.owner_id
  ) then raise exception 'As regras do conflito devem possuir o mesmo proprietário'; end if;
  if tg_table_name = 'memory_organization_rules' and new.supersedes_rule_id is not null and not exists (
    select 1 from memoria.memory_organization_rules prior
    where prior.id = new.supersedes_rule_id and prior.owner_id = new.owner_id
  ) then raise exception 'A regra substituída deve possuir o mesmo proprietário'; end if;
  return new;
end;
$$;
drop trigger if exists validate_memory_conflict_owner on memoria.memory_organization_conflicts;
create trigger validate_memory_conflict_owner
before insert or update on memoria.memory_organization_conflicts
for each row execute function memoria.validate_memory_rule_owner_references();

drop trigger if exists validate_memory_supersedes_owner on memoria.memory_organization_rules;
create trigger validate_memory_supersedes_owner
before insert or update of supersedes_rule_id, owner_id on memoria.memory_organization_rules
for each row execute function memoria.validate_memory_rule_owner_references();

revoke all on memoria.memory_organization_rules, memoria.memory_organization_feedback,
  memoria.memory_organization_rule_evidence, memoria.memory_organization_rule_versions,
  memoria.memory_organization_settings, memoria.memory_organization_conflicts from public, anon;
grant select, insert, update, delete on memoria.memory_organization_rules, memoria.memory_organization_feedback,
  memoria.memory_organization_rule_evidence, memoria.memory_organization_rule_versions,
  memoria.memory_organization_settings, memoria.memory_organization_conflicts to authenticated;
grant all on memoria.memory_organization_rules, memoria.memory_organization_feedback,
  memoria.memory_organization_rule_evidence, memoria.memory_organization_rule_versions,
  memoria.memory_organization_settings, memoria.memory_organization_conflicts to service_role;

commit;
