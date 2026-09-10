-- Memória Lucenera | Processamento padronizado de livros e documentos longos no schema `memoria`.
-- Execute uma vez no SQL Editor, depois de supabase.sql e document-ingestion.sql.
begin;

create table if not exists memoria.document_ingestion_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  inbox_id uuid not null references memoria.inbox_items(id) on delete cascade,
  file_id uuid not null references memoria.files(id) on delete cascade,
  title text not null,
  language text,
  domain text,
  subcategory text,
  status text not null default 'prepared' check (status in ('prepared','processing','awaiting_review','approved','failed','archived')),
  target_words integer not null default 2200 check (target_words between 800 and 4000),
  total_sections integer not null default 0,
  processed_sections integer not null default 0,
  source_metadata jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(owner_id,inbox_id)
);

-- Classificação em dois níveis. As instruções são idempotentes e também
-- atualizam instalações que já possuíam as tabelas antes desta versão.
alter table memoria.document_ingestion_runs add column if not exists subcategory text;
alter table memoria.knowledge_items add column if not exists subcategory text;

create table if not exists memoria.document_sections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  run_id uuid not null references memoria.document_ingestion_runs(id) on delete cascade,
  section_index integer not null,
  title text not null,
  locator text not null,
  content text not null,
  context_before text,
  word_count integer not null default 0,
  included boolean not null default true,
  status text not null default 'prepared' check (status in ('prepared','processing','awaiting_review','approved','failed','skipped')),
  analysis jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id,section_index)
);

create index if not exists document_ingestion_runs_owner_status_idx on memoria.document_ingestion_runs(owner_id,status);
create index if not exists document_ingestion_runs_file_idx on memoria.document_ingestion_runs(file_id);
create index if not exists knowledge_items_owner_domain_subcategory_idx on memoria.knowledge_items(owner_id,domain,subcategory) where deleted_at is null;
create index if not exists document_sections_run_index_idx on memoria.document_sections(run_id,section_index);
create index if not exists document_sections_owner_status_idx on memoria.document_sections(owner_id,status);

alter table memoria.document_ingestion_runs enable row level security;
alter table memoria.document_sections enable row level security;

drop policy if exists document_ingestion_runs_owner_all on memoria.document_ingestion_runs;
create policy document_ingestion_runs_owner_all on memoria.document_ingestion_runs
  for all to authenticated using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));

drop policy if exists document_sections_owner_all on memoria.document_sections;
create policy document_sections_owner_all on memoria.document_sections
  for all to authenticated using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));

create or replace function memoria.save_long_document_analysis(
  p_run_id uuid,
  p_project_id uuid default null
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_run memoria.document_ingestion_runs%rowtype;
  v_source_id uuid;
  v_entity_id uuid;
  v_knowledge_id uuid;
  v_entity_map jsonb;
  v_knowledge_map jsonb;
  v_seen_knowledge jsonb := '{}'::jsonb;
  v_entity_count integer := 0;
  v_knowledge_count integer := 0;
  v_citation_count integer := 0;
  v_relation_count integer := 0;
  section_row memoria.document_sections%rowtype;
  item jsonb;
  cite jsonb;
  rel jsonb;
  local_key text;
  related_key text;
  normalized_title text;
  source_uuid uuid;
  target_uuid uuid;
  source_table text;
  target_table text;
begin
  if v_owner is null then raise exception 'Autenticação obrigatória'; end if;
  select * into v_run from memoria.document_ingestion_runs where id=p_run_id and owner_id=v_owner for update;
  if not found then raise exception 'Processamento não encontrado ou sem permissão'; end if;
  if v_run.status='approved' then raise exception 'Este livro já foi organizado'; end if;
  if exists(select 1 from memoria.document_sections where run_id=p_run_id and owner_id=v_owner and included and status not in ('awaiting_review','approved')) then
    raise exception 'Ainda existem seções sem análise ou com falha';
  end if;
  if p_project_id is not null and not exists(select 1 from memoria.projects where id=p_project_id and owner_id=v_owner and deleted_at is null) then
    raise exception 'Projeto não encontrado ou sem permissão';
  end if;

  insert into memoria.sources(owner_id,source_type,title,author,publisher,publication_date,accessed_at,language,reliability,notes,domain,file_id,visibility,metadata)
  values(
    v_owner,coalesce(nullif(v_run.source_metadata->>'source_type',''),'livro'),v_run.title,
    nullif(v_run.source_metadata->>'author',''),nullif(v_run.source_metadata->>'publisher',''),
    case when coalesce(v_run.source_metadata->>'publication_date','') ~ '^\d{4}-\d{2}-\d{2}$' then (v_run.source_metadata->>'publication_date')::date else null end,
    now(),nullif(v_run.language,''),greatest(0,least(100,coalesce((v_run.source_metadata->>'reliability')::integer,70))),
    nullif(v_run.source_metadata->>'summary',''),nullif(v_run.domain,''),v_run.file_id,'private',
    jsonb_build_object('ingestion_mode','long_document_sections','run_id',v_run.id,'total_sections',v_run.total_sections)
  ) returning id into v_source_id;

  for section_row in
    select * from memoria.document_sections where run_id=p_run_id and owner_id=v_owner and included and status in ('awaiting_review','approved') order by section_index
  loop
    v_entity_map := '{}'::jsonb;
    v_knowledge_map := '{}'::jsonb;

    for item in select value from jsonb_array_elements(coalesce(section_row.analysis->'entities','[]'::jsonb)) loop
      local_key := nullif(item->>'client_key','');
      if local_key is null or nullif(item->>'canonical_name','') is null then continue; end if;
      select id into v_entity_id from memoria.entities
        where owner_id=v_owner and deleted_at is null and lower(canonical_name)=lower(item->>'canonical_name') order by created_at limit 1;
      if v_entity_id is null then
        insert into memoria.entities(owner_id,entity_type,canonical_name,alternative_names,short_description,domain,status,visibility,metadata)
        values(v_owner,coalesce(nullif(item->>'entity_type',''),'outro'),item->>'canonical_name',coalesce(item->'alternative_names','[]'::jsonb),
          nullif(item->>'short_description',''),nullif(item->>'domain',''),'active','private',
          jsonb_build_object('source_file_id',v_run.file_id,'source_section_id',section_row.id,'mentions',coalesce(item->'mentions','[]'::jsonb),'created_by','long_document_ingestion'))
        returning id into v_entity_id;
        v_entity_count := v_entity_count+1;
      end if;
      v_entity_map := v_entity_map || jsonb_build_object(local_key,v_entity_id::text);
      insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
      values(v_owner,'sources',v_source_id,'mentions','entities',v_entity_id,'Entidade mencionada em '||section_row.locator||'.',90);
      v_relation_count := v_relation_count+1;
      v_entity_id := null;
    end loop;

    for item in select value from jsonb_array_elements(coalesce(section_row.analysis->'knowledge_items','[]'::jsonb)) loop
      if coalesce((item->>'included')::boolean,true)=false then continue; end if;
      local_key := nullif(item->>'client_key','');
      normalized_title := lower(regexp_replace(coalesce(item->>'title',''),'\s+',' ','g'));
      if local_key is null or normalized_title='' then continue; end if;
      if v_seen_knowledge ? normalized_title then
        v_knowledge_id := (v_seen_knowledge->>normalized_title)::uuid;
      else
        insert into memoria.knowledge_items(owner_id,knowledge_type,title,summary,content,domain,subcategory,status,confidence,visibility,source_mode,metadata)
        values(v_owner,coalesce(nullif(item->>'knowledge_type',''),'anotação'),item->>'title',nullif(item->>'summary',''),nullif(item->>'content',''),
          coalesce(nullif(item->>'domain',''),nullif(v_run.domain,'')),coalesce(nullif(item->>'subcategory',''),nullif(v_run.subcategory,'')),'review',greatest(0,least(100,coalesce((item->>'confidence')::integer,70))),
          'private','external',jsonb_build_object('tags',coalesce(item->'tags','[]'::jsonb),'epistemic_type',coalesce(item->>'epistemic_type','mixed'),
            'source_file_id',v_run.file_id,'source_id',v_source_id,'source_section_id',section_row.id,'source_locator',section_row.locator,
            'document_client_key',local_key,'created_by','long_document_ingestion'))
        returning id into v_knowledge_id;
        v_seen_knowledge := v_seen_knowledge || jsonb_build_object(normalized_title,v_knowledge_id::text);
        v_knowledge_count := v_knowledge_count+1;
      end if;
      v_knowledge_map := v_knowledge_map || jsonb_build_object(local_key,v_knowledge_id::text);

      for cite in select value from jsonb_array_elements(coalesce(item->'citations','[]'::jsonb)) loop
        if not exists(select 1 from memoria.citations where owner_id=v_owner and knowledge_item_id=v_knowledge_id and source_id=v_source_id and coalesce(excerpt,'')=coalesce(cite->>'excerpt','')) then
          insert into memoria.citations(owner_id,knowledge_item_id,source_id,locator,excerpt,support_type,notes)
          values(v_owner,v_knowledge_id,v_source_id,coalesce(nullif(cite->>'locator',''),section_row.locator),nullif(cite->>'excerpt',''),
            case when cite->>'support_type' in ('supports','contradicts','contextualizes') then cite->>'support_type' else 'contextualizes' end,
            'Citação original preservada durante ingestão por seção.');
          v_citation_count := v_citation_count+1;
        end if;
      end loop;
      for related_key in select jsonb_array_elements_text(coalesce(item->'entity_keys','[]'::jsonb)) loop
        if v_entity_map ? related_key then
          insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
          values(v_owner,'knowledge_items',v_knowledge_id,'mentions','entities',(v_entity_map->>related_key)::uuid,'Entidade contextual do conhecimento.',90);
          v_relation_count := v_relation_count+1;
        end if;
      end loop;
      if not exists(select 1 from memoria.relations where owner_id=v_owner and source_type='sources' and source_id=v_source_id and relation_type='source_for' and target_type='knowledge_items' and target_id=v_knowledge_id) then
        insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
        values(v_owner,'sources',v_source_id,'source_for','knowledge_items',v_knowledge_id,'Conhecimento extraído de '||section_row.locator||'.',100);
        v_relation_count := v_relation_count+1;
      end if;
      if p_project_id is not null then
        insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
        values(v_owner,'knowledge_items',v_knowledge_id,'part_of','projects',p_project_id,'Conhecimento associado ao projeto durante a ingestão.',100);
        v_relation_count := v_relation_count+1;
      end if;
    end loop;

    for item in select value from jsonb_array_elements(coalesce(section_row.analysis->'knowledge_items','[]'::jsonb)) loop
      if not (v_knowledge_map ? coalesce(item->>'client_key','')) then continue; end if;
      for related_key in select jsonb_array_elements_text(coalesce(item->'related_knowledge_keys','[]'::jsonb)) loop
        if v_knowledge_map ? related_key and related_key<>item->>'client_key' then
          insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
          values(v_owner,'knowledge_items',(v_knowledge_map->>(item->>'client_key'))::uuid,'related_to','knowledge_items',(v_knowledge_map->>related_key)::uuid,
            'Relação conceitual identificada dentro da seção.',80);
          v_relation_count := v_relation_count+1;
        end if;
      end loop;
    end loop;

    for rel in select value from jsonb_array_elements(coalesce(section_row.analysis->'relations','[]'::jsonb)) loop
      source_table := case when rel->>'source_kind'='entity' then 'entities' else 'knowledge_items' end;
      target_table := case when rel->>'target_kind'='entity' then 'entities' else 'knowledge_items' end;
      source_uuid := case when rel->>'source_kind'='entity' then nullif(v_entity_map->>(rel->>'source_key'),'')::uuid else nullif(v_knowledge_map->>(rel->>'source_key'),'')::uuid end;
      target_uuid := case when rel->>'target_kind'='entity' then nullif(v_entity_map->>(rel->>'target_key'),'')::uuid else nullif(v_knowledge_map->>(rel->>'target_key'),'')::uuid end;
      if source_uuid is not null and target_uuid is not null and not(source_table=target_table and source_uuid=target_uuid) then
        insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
        values(v_owner,source_table,source_uuid,coalesce(nullif(rel->>'relation_type',''),'related_to'),target_table,target_uuid,
          nullif(rel->>'description',''),greatest(0,least(100,coalesce((rel->>'confidence')::integer,70))));
        v_relation_count := v_relation_count+1;
      end if;
    end loop;
    update memoria.document_sections set status='approved',updated_at=now() where id=section_row.id;
  end loop;

  update memoria.document_ingestion_runs set status='approved',processed_sections=total_sections,updated_at=now(),completed_at=now() where id=v_run.id;
  update memoria.inbox_items set processing_status='approved',updated_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('long_document_run_id',v_run.id,'document_source_id',v_source_id,'approved_at',now()) where id=v_run.inbox_id and owner_id=v_owner;
  update memoria.files set processing_status='approved',language=nullif(v_run.language,''),processed_at=now() where id=v_run.file_id and owner_id=v_owner;

  return jsonb_build_object('source_id',v_source_id,'created_entities',v_entity_count,'created_knowledge_items',v_knowledge_count,'created_citations',v_citation_count,'created_relations',v_relation_count);
end;
$$;

revoke all on function memoria.save_long_document_analysis(uuid,uuid) from public;
grant execute on function memoria.save_long_document_analysis(uuid,uuid) to authenticated;

revoke all on memoria.document_ingestion_runs, memoria.document_sections from public, anon;
grant select, insert, update, delete on memoria.document_ingestion_runs, memoria.document_sections to authenticated;
grant all on memoria.document_ingestion_runs, memoria.document_sections to service_role;

commit;
