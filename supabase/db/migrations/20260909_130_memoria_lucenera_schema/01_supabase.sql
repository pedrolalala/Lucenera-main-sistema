-- Memória Lucenera — núcleo isolado no mesmo projeto Supabase operacional.
-- Nenhum objeto da memória é criado no schema public.
begin;

create extension if not exists pgcrypto;
create schema if not exists memoria;
revoke all on schema memoria from public, anon;
grant usage on schema memoria to authenticated, service_role;

do $$ begin create type memoria.visibility_level as enum ('private','shared','company','public'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.knowledge_status as enum ('draft','review','approved','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.decision_status as enum ('open','decided','reviewed','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.project_status as enum ('idea','active','paused','completed','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.file_processing_status as enum ('uploaded','queued','extracting','analyzing','awaiting_review','approved','failed','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.inbox_processing_status as enum ('new','processing','awaiting_review','approved','rejected','failed'); exception when duplicate_object then null; end $$;
do $$ begin create type memoria.citation_support_type as enum ('supports','contradicts','contextualizes'); exception when duplicate_object then null; end $$;

create table if not exists memoria.entities (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null, canonical_name text not null, alternative_names jsonb not null default '[]'::jsonb, domain text,
  short_description text, detailed_description text, status text not null default 'active',
  visibility memoria.visibility_level not null default 'private', image_url text, website_url text,
  external_identifiers jsonb not null default '{}'::jsonb, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table if not exists memoria.knowledge_items (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  knowledge_type text not null, title text not null, summary text, content text, domain text, subcategory text,
  status memoria.knowledge_status not null default 'draft', confidence integer check (confidence between 0 and 100),
  visibility memoria.visibility_level not null default 'private', source_mode text check (source_mode in ('personal','external','mixed')),
  valid_from date, reviewed_at timestamptz, next_review_at timestamptz, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table if not exists memoria.projects (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null, project_type text, description text, objective text, domain text,
  status memoria.project_status not null default 'idea', start_date date, end_date date,
  visibility memoria.visibility_level not null default 'private', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table if not exists memoria.experiences (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  experience_type text not null, title text not null, description text, domain text,
  entity_id uuid references memoria.entities(id), project_id uuid references memoria.projects(id),
  location_entity_id uuid references memoria.entities(id), occurred_at timestamptz,
  rating numeric(3,1) check (rating between 0 and 10), would_repeat boolean, would_recommend boolean,
  personal_notes text, highlights text, negative_points text,
  visibility memoria.visibility_level not null default 'private', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table if not exists memoria.decisions (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null, decision_type text, context text, domain text, options_considered jsonb not null default '[]'::jsonb,
  decision_taken text, reasoning text, expected_result text, risks text, decision_date date, review_date date,
  actual_result text, lessons_learned text, status memoria.decision_status not null default 'open',
  visibility memoria.visibility_level not null default 'private', metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table if not exists memoria.files (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  original_filename text not null, storage_path text not null, mime_type text, file_size bigint check (file_size >= 0),
  checksum text, processing_status memoria.file_processing_status not null default 'uploaded', extracted_text text,
  language text, visibility memoria.visibility_level not null default 'private', created_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists memoria.sources (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null, title text not null, author text, publisher text, url text, domain text, publication_date date,
  accessed_at timestamptz, language text, reliability integer check (reliability between 0 and 100), notes text,
  file_id uuid references memoria.files(id), visibility memoria.visibility_level not null default 'private',
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists memoria.relations (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null, source_id uuid not null, relation_type text not null, target_type text not null, target_id uuid not null,
  description text, confidence integer check (confidence between 0 and 100), created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), check (not (source_type = target_type and source_id = target_id))
);

create table if not exists memoria.citations (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  knowledge_item_id uuid not null references memoria.knowledge_items(id), source_id uuid not null references memoria.sources(id),
  locator text, excerpt text, support_type memoria.citation_support_type not null default 'supports', notes text,
  created_at timestamptz not null default now()
);

create table if not exists memoria.record_versions (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null, record_id uuid not null, version_number integer not null, snapshot jsonb not null,
  change_reason text, changed_at timestamptz not null default now(), changed_by uuid not null references auth.users(id),
  unique (record_type, record_id, version_number)
);

create table if not exists memoria.inbox_items (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  input_type text not null, title text, raw_text text, domain text, file_id uuid references memoria.files(id), url text, source_channel text,
  processing_status memoria.inbox_processing_status not null default 'new', visibility memoria.visibility_level not null default 'private',
  original_transcription text, transcript_language text, metadata jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists memoria.domains (
  id uuid primary key default gen_random_uuid(), owner_id uuid references auth.users(id) on delete cascade,
  name text not null, slug text not null, active boolean not null default true, created_at timestamptz not null default now(),
  unique (owner_id, slug)
);

alter table memoria.inbox_items add column if not exists original_transcription text;
alter table memoria.inbox_items add column if not exists transcript_language text;
alter table memoria.inbox_items add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table memoria.entities add column if not exists domain text;
alter table memoria.knowledge_items add column if not exists subcategory text;
alter table memoria.projects add column if not exists domain text;
alter table memoria.experiences add column if not exists domain text;
alter table memoria.decisions add column if not exists domain text;
alter table memoria.sources add column if not exists domain text;
alter table memoria.inbox_items add column if not exists domain text;

create index if not exists entities_name_idx on memoria.entities using gin (to_tsvector('simple', canonical_name));
create index if not exists entities_type_idx on memoria.entities(entity_type);
create index if not exists entities_owner_idx on memoria.entities(owner_id);
create index if not exists knowledge_owner_idx on memoria.knowledge_items(owner_id);
create index if not exists knowledge_domain_idx on memoria.knowledge_items(domain);
create index if not exists knowledge_review_idx on memoria.knowledge_items(next_review_at);
create index if not exists knowledge_search_idx on memoria.knowledge_items using gin (to_tsvector('portuguese', coalesce(title,'') || ' ' || coalesce(summary,'') || ' ' || coalesce(content,'')));
create index if not exists experiences_owner_idx on memoria.experiences(owner_id);
create index if not exists decisions_owner_idx on memoria.decisions(owner_id);
create index if not exists projects_owner_idx on memoria.projects(owner_id);
create index if not exists sources_owner_idx on memoria.sources(owner_id);
create index if not exists relations_source_idx on memoria.relations(source_type, source_id);
create index if not exists relations_target_idx on memoria.relations(target_type, target_id);
create index if not exists relations_owner_idx on memoria.relations(owner_id);
create index if not exists files_owner_checksum_idx on memoria.files(owner_id, checksum);
create index if not exists inbox_owner_status_idx on memoria.inbox_items(owner_id, processing_status);

create or replace function memoria.touch_updated_at() returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;

create or replace function memoria.archive_version() returns trigger language plpgsql security invoker set search_path = '' as $$
declare next_version integer;
begin
  select coalesce(max(version_number),0)+1 into next_version from memoria.record_versions
  where record_type = tg_table_name and record_id = old.id;
  insert into memoria.record_versions (owner_id,record_type,record_id,version_number,snapshot,change_reason,changed_by)
  values (old.owner_id,tg_table_name,old.id,next_version,to_jsonb(old),'Atualização automática',auth.uid());
  return new;
end;
$$;

create or replace function memoria.keep_original_transcription() returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.original_transcription is not null and new.original_transcription is distinct from old.original_transcription then
    raise exception 'A transcrição original não pode ser alterada';
  end if;
  return new;
end;
$$;

do $$ declare t text;
begin
  foreach t in array array['entities','knowledge_items','projects','experiences','decisions','sources','relations','inbox_items'] loop
    execute format('drop trigger if exists %I on memoria.%I', t || '_touch_updated_at', t);
    execute format('create trigger %I before update on memoria.%I for each row execute function memoria.touch_updated_at()', t || '_touch_updated_at', t);
  end loop;
end $$;

drop trigger if exists knowledge_items_archive_version on memoria.knowledge_items;
create trigger knowledge_items_archive_version before update on memoria.knowledge_items for each row execute function memoria.archive_version();
drop trigger if exists experiences_archive_version on memoria.experiences;
create trigger experiences_archive_version before update on memoria.experiences for each row execute function memoria.archive_version();
drop trigger if exists decisions_archive_version on memoria.decisions;
create trigger decisions_archive_version before update on memoria.decisions for each row execute function memoria.archive_version();
drop trigger if exists inbox_items_keep_original_transcription on memoria.inbox_items;
create trigger inbox_items_keep_original_transcription before update of original_transcription on memoria.inbox_items for each row execute function memoria.keep_original_transcription();

do $$ declare t text;
begin
  foreach t in array array['entities','knowledge_items','projects','experiences','decisions','files','sources','relations','citations','record_versions','inbox_items','domains'] loop
    execute format('alter table memoria.%I enable row level security', t);
    execute format('drop policy if exists %I on memoria.%I', t || '_owner_all', t);
    execute format('create policy %I on memoria.%I for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()))', t || '_owner_all', t);
  end loop;
end $$;

revoke all on all tables in schema memoria from public, anon;
grant select, insert, update, delete on all tables in schema memoria to authenticated;
grant all on all tables in schema memoria to service_role;
grant execute on all functions in schema memoria to authenticated, service_role;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('lucenera-memory-files','lucenera-memory-files',false,52428800,array[
  'application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain',
  'image/jpeg','image/png','image/webp','audio/mpeg','audio/mp4','audio/wav','audio/webm',
  'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "lucenera memory files owner access" on storage.objects;
create policy "lucenera memory files owner access" on storage.objects for all to authenticated
using (bucket_id='lucenera-memory-files' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='lucenera-memory-files' and (storage.foldername(name))[1]=(select auth.uid())::text);

commit;
