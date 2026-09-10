-- Memória Lucenera | Ingestão documental revisada e transacional no schema `memoria`.
-- Execute no SQL Editor depois de supabase.sql.
begin;

create or replace function memoria.save_document_analysis(
  p_inbox_id uuid,
  p_file_id uuid,
  p_analysis jsonb,
  p_project_id uuid default null,
  p_applied_rule_ids jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_source_id uuid;
  v_entity_id uuid;
  v_knowledge_id uuid;
  v_source_record jsonb := coalesce(p_analysis->'source', '{}'::jsonb);
  v_entity_map jsonb := '{}'::jsonb;
  v_knowledge_map jsonb := '{}'::jsonb;
  v_entity_count integer := 0;
  v_knowledge_count integer := 0;
  v_citation_count integer := 0;
  v_relation_count integer := 0;
  item jsonb;
  cite jsonb;
  rel jsonb;
  key text;
  related_key text;
  source_uuid uuid;
  target_uuid uuid;
  source_table text;
  target_table text;
begin
  if v_owner is null then raise exception 'Autenticação obrigatória'; end if;
  if not exists (select 1 from memoria.files where id = p_file_id and owner_id = v_owner) then
    raise exception 'Arquivo não encontrado ou sem permissão';
  end if;
  if not exists (
    select 1 from memoria.inbox_items
    where id = p_inbox_id and file_id = p_file_id and owner_id = v_owner and processing_status <> 'approved'
  ) then raise exception 'Entrada não encontrada, já aprovada ou sem permissão'; end if;
  if p_project_id is not null and not exists (
    select 1 from memoria.projects where id = p_project_id and owner_id = v_owner and deleted_at is null
  ) then raise exception 'Projeto não encontrado ou sem permissão'; end if;
  if jsonb_typeof(p_analysis->'entities') <> 'array' or jsonb_typeof(p_analysis->'knowledge_items') <> 'array' then
    raise exception 'Análise documental inválida';
  end if;

  insert into memoria.sources(
    owner_id, source_type, title, author, publisher, publication_date, accessed_at,
    language, reliability, notes, domain, file_id, visibility, metadata
  ) values (
    v_owner,
    coalesce(nullif(v_source_record->>'source_type',''), 'documento'),
    coalesce(nullif(v_source_record->>'title',''), (select original_filename from memoria.files where id=p_file_id)),
    nullif(v_source_record->>'author',''), nullif(v_source_record->>'publisher',''),
    case when coalesce(v_source_record->>'publication_date','') ~ '^\d{4}-\d{2}-\d{2}$' then (v_source_record->>'publication_date')::date else null end,
    now(), nullif(v_source_record->>'language',''),
    greatest(0, least(100, coalesce((v_source_record->>'reliability')::integer, 70))),
    nullif(v_source_record->>'summary',''), nullif(v_source_record->>'domain',''),
    p_file_id, 'private',
    jsonb_build_object('outline',coalesce(v_source_record->'outline','[]'::jsonb),'ingestion_mode','document_ai_reviewed')
  ) returning id into v_source_id;

  for item in select value from jsonb_array_elements(p_analysis->'entities') loop
    key := nullif(item->>'client_key','');
    if key is null or nullif(item->>'canonical_name','') is null then continue; end if;
    select id into v_entity_id from memoria.entities
      where owner_id=v_owner and deleted_at is null and lower(canonical_name)=lower(item->>'canonical_name')
      order by created_at limit 1;
    if v_entity_id is null then
      insert into memoria.entities(
        owner_id, entity_type, canonical_name, alternative_names, short_description,
        domain, status, visibility, metadata
      ) values (
        v_owner, coalesce(nullif(item->>'entity_type',''),'outro'), item->>'canonical_name',
        coalesce(item->'alternative_names','[]'::jsonb), nullif(item->>'short_description',''),
        nullif(item->>'domain',''), 'active', 'private',
        jsonb_build_object('source_file_id',p_file_id,'mentions',coalesce(item->'mentions','[]'::jsonb),'created_by','document_ingestion')
      ) returning id into v_entity_id;
      v_entity_count := v_entity_count + 1;
    end if;
    v_entity_map := v_entity_map || jsonb_build_object(key, v_entity_id::text);
    insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
      values(v_owner,'sources',v_source_id,'mentions','entities',v_entity_id,'Entidade mencionada no documento.',90);
    v_relation_count := v_relation_count + 1;
    v_entity_id := null;
  end loop;

  for item in select value from jsonb_array_elements(p_analysis->'knowledge_items') loop
    key := nullif(item->>'client_key','');
    if key is null or nullif(item->>'title','') is null then continue; end if;
    insert into memoria.knowledge_items(
      owner_id, knowledge_type, title, summary, content, domain, status, confidence,
      visibility, source_mode, metadata
    ) values (
      v_owner, coalesce(nullif(item->>'knowledge_type',''),'anotação'), item->>'title',
      nullif(item->>'summary',''), nullif(item->>'content',''), nullif(item->>'domain',''),
      'review', greatest(0,least(100,coalesce((item->>'confidence')::integer,70))),
      'private','external',
      jsonb_build_object(
        'tags',coalesce(item->'tags','[]'::jsonb),
        'epistemic_type',coalesce(item->>'epistemic_type','mixed'),
        'source_file_id',p_file_id,
        'source_id',v_source_id,
        'document_client_key',key,
        'applied_rule_ids',coalesce(p_applied_rule_ids,'[]'::jsonb),
        'created_by','document_ingestion'
      )
    ) returning id into v_knowledge_id;
    v_knowledge_map := v_knowledge_map || jsonb_build_object(key, v_knowledge_id::text);
    v_knowledge_count := v_knowledge_count + 1;

    for cite in select value from jsonb_array_elements(coalesce(item->'citations','[]'::jsonb)) loop
      insert into memoria.citations(owner_id,knowledge_item_id,source_id,locator,excerpt,support_type,notes)
      values(
        v_owner,v_knowledge_id,v_source_id,nullif(cite->>'locator',''),nullif(cite->>'excerpt',''),
        case when cite->>'support_type' in ('supports','contradicts','contextualizes') then cite->>'support_type' else 'contextualizes' end,
        'Citação identificada durante ingestão documental e aceita na revisão.'
      );
      v_citation_count := v_citation_count + 1;
    end loop;

    for related_key in select jsonb_array_elements_text(coalesce(item->'entity_keys','[]'::jsonb)) loop
      if v_entity_map ? related_key then
        insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
        values(v_owner,'knowledge_items',v_knowledge_id,'mentions','entities',(v_entity_map->>related_key)::uuid,'Entidade contextual deste conhecimento.',90);
        v_relation_count := v_relation_count + 1;
      end if;
    end loop;
    insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
    values(v_owner,'sources',v_source_id,'source_for','knowledge_items',v_knowledge_id,'Conhecimento extraído e revisado a partir desta fonte.',100);
    v_relation_count := v_relation_count + 1;
    if p_project_id is not null then
      insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
      values(v_owner,'knowledge_items',v_knowledge_id,'part_of','projects',p_project_id,'Conhecimento associado ao projeto durante a ingestão.',100);
      v_relation_count := v_relation_count + 1;
    end if;
  end loop;

  for item in select value from jsonb_array_elements(p_analysis->'knowledge_items') loop
    if not (v_knowledge_map ? (item->>'client_key')) then continue; end if;
    for related_key in select jsonb_array_elements_text(coalesce(item->'related_knowledge_keys','[]'::jsonb)) loop
      if v_knowledge_map ? related_key and related_key <> item->>'client_key' then
        insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
        values(v_owner,'knowledge_items',(v_knowledge_map->>(item->>'client_key'))::uuid,'related_to','knowledge_items',(v_knowledge_map->>related_key)::uuid,'Relação conceitual identificada no documento.',80);
        v_relation_count := v_relation_count + 1;
      end if;
    end loop;
  end loop;

  for rel in select value from jsonb_array_elements(coalesce(p_analysis->'relations','[]'::jsonb)) loop
    source_table := case when rel->>'source_kind'='entity' then 'entities' else 'knowledge_items' end;
    target_table := case when rel->>'target_kind'='entity' then 'entities' else 'knowledge_items' end;
    source_uuid := case when rel->>'source_kind'='entity' then nullif(v_entity_map->>(rel->>'source_key'),'')::uuid else nullif(v_knowledge_map->>(rel->>'source_key'),'')::uuid end;
    target_uuid := case when rel->>'target_kind'='entity' then nullif(v_entity_map->>(rel->>'target_key'),'')::uuid else nullif(v_knowledge_map->>(rel->>'target_key'),'')::uuid end;
    if source_uuid is not null and target_uuid is not null and not (source_table=target_table and source_uuid=target_uuid) then
      insert into memoria.relations(owner_id,source_type,source_id,relation_type,target_type,target_id,description,confidence)
      values(
        v_owner,source_table,source_uuid,coalesce(nullif(rel->>'relation_type',''),'related_to'),target_table,target_uuid,
        nullif(rel->>'description',''),greatest(0,least(100,coalesce((rel->>'confidence')::integer,70)))
      );
      v_relation_count := v_relation_count + 1;
    end if;
  end loop;

  update memoria.inbox_items set
    processing_status='approved',
    metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'document_analysis_final',p_analysis,'document_source_id',v_source_id,'approved_at',now()
    )
  where id=p_inbox_id and owner_id=v_owner;
  update memoria.files set
    processing_status='approved', language=nullif(v_source_record->>'language',''), processed_at=now()
  where id=p_file_id and owner_id=v_owner;

  return jsonb_build_object(
    'source_id',v_source_id,'entity_map',v_entity_map,'knowledge_map',v_knowledge_map,
    'created_entities',v_entity_count,'created_knowledge_items',v_knowledge_count,
    'created_citations',v_citation_count,'created_relations',v_relation_count
  );
end;
$$;

revoke all on function memoria.save_document_analysis(uuid,uuid,jsonb,uuid,jsonb) from public;
grant execute on function memoria.save_document_analysis(uuid,uuid,jsonb,uuid,jsonb) to authenticated;

commit;
