-- Verificação somente leitura: não cria, altera nem exclui dados.
-- Execute depois dos quatro scripts de instalação.
select jsonb_build_object(
  'schema_memoria_existe', exists (
    select 1 from information_schema.schemata where schema_name = 'memoria'
  ),
  'tabelas_memoria', coalesce((
    select jsonb_agg(jsonb_build_object(
      'tabela', c.relname,
      'rls_ativo', c.relrowsecurity
    ) order by c.relname)
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'memoria' and c.relkind = 'r'
  ), '[]'::jsonb),
  'tabelas_public_homonimas', coalesce((
    select jsonb_agg(t.table_name order by t.table_name)
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_name in (
        'entities','knowledge_items','experiences','decisions','projects','sources',
        'relations','citations','files','record_versions','inbox_items','domains',
        'memory_organization_rules','memory_organization_feedback',
        'document_ingestion_runs','document_sections'
      )
  ), '[]'::jsonb),
  'bucket_memoria', coalesce((
    select jsonb_build_object('id', b.id, 'privado', not b.public, 'limite_bytes', b.file_size_limit)
    from storage.buckets b where b.id = 'lucenera-memory-files'
  ), '{}'::jsonb)
) as verificacao;
