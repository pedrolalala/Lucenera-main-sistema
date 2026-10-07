-- SPEC-164 — Copia o conteúdo existente das tabelas antigas para kb_itens.
--
-- COPIA, não move: knowledge_items/entities/sources ficam intactas (o app
-- antigo continua funcionando na rota oculta). Cada linha nova guarda
-- legado_tabela + legado_id (índice único) — rodar de novo não duplica.
--
-- Mapeamento (decisão do usuário 2026-09-24: o que não cabe nos 9 tipos vira
-- Procedimento interno):
--   knowledge_items diretriz_tecnica      -> regra_material
--     exceto subcategoria paisagismo      -> padrao_projeto
--     exceto "Testes em Andamento..."     -> teste_material
--   knowledge_items processo_interno,
--     regra_comercial, modelo_comunicacao -> procedimento
--   entities fornecedor                   -> marca
--   entities razao_social/empresa_grupo   -> procedimento ("Cadastro institucional — ...")
--   sources                               -> procedimento
-- Status: approved/review -> publicado; draft -> rascunho; archived -> arquivado.
-- origem = 'importada', origem_fonte = 'memoria_legado', origem_chave = id antigo.
-- O dado original completo fica em metadata.legado (nenhuma informação perdida).
-- Itens só são copiados se não estiverem com deleted_at.

BEGIN;

-- knowledge_items ------------------------------------------------------------
INSERT INTO memoria.kb_itens (
  tipo, titulo, resumo, campos, tags, project_code, status, origem, origem_fonte, origem_chave,
  legado_tabela, legado_id, autor_id, atualizado_por, metadata, created_at, updated_at, proxima_revisao
)
SELECT
  x.tipo,
  k.title,
  k.summary,
  CASE x.tipo
    WHEN 'regra_material' THEN jsonb_build_object(
      'material_aplicacao', initcap(replace(coalesce(k.subcategory, ''), '-', ' ')),
      'detalhamento', k.content)
    WHEN 'padrao_projeto' THEN jsonb_build_object('conceito', k.content)
    WHEN 'teste_material' THEN jsonb_build_object(
      'material', 'Fita LED 5000K',
      'resultado', k.content,
      'observacoes', 'Teste em andamento no momento da migração (status original: em revisão).')
    ELSE jsonb_build_object('passo_a_passo', k.content)
  END,
  array_remove(ARRAY[
    nullif(replace(coalesce(k.subcategory, ''), '-', ' '), ''),
    CASE k.knowledge_type
      WHEN 'regra_comercial'    THEN 'regra comercial'
      WHEN 'modelo_comunicacao' THEN 'modelo de texto'
      WHEN 'processo_interno'   THEN 'processo interno'
      WHEN 'diretriz_tecnica'   THEN 'diretriz técnica'
    END
  ], NULL),
  k.project_code,
  CASE k.status WHEN 'draft' THEN 'rascunho' WHEN 'archived' THEN 'arquivado' ELSE 'publicado' END::memoria.kb_status,
  'importada', 'memoria_legado', k.id::text,
  'knowledge_items', k.id, k.owner_id, k.owner_id,
  jsonb_build_object('legado', to_jsonb(k)),
  k.created_at, k.updated_at,
  CASE WHEN k.status = 'review' THEN current_date END
FROM memoria.knowledge_items k
CROSS JOIN LATERAL (
  SELECT CASE
    WHEN k.title ILIKE 'Testes em Andamento%'                        THEN 'teste_material'
    WHEN k.knowledge_type = 'diretriz_tecnica' AND k.subcategory = 'paisagismo' THEN 'padrao_projeto'
    WHEN k.knowledge_type = 'diretriz_tecnica'                        THEN 'regra_material'
    ELSE 'procedimento'
  END::memoria.kb_tipo AS tipo
) x
WHERE k.deleted_at IS NULL
ON CONFLICT (legado_tabela, legado_id) WHERE legado_id IS NOT NULL DO NOTHING;

-- entities: fornecedores -> marcas ------------------------------------------
INSERT INTO memoria.kb_itens (
  tipo, titulo, resumo, campos, tags, project_code, status, origem, origem_fonte, origem_chave,
  legado_tabela, legado_id, autor_id, atualizado_por, metadata, created_at, updated_at
)
SELECT
  'marca',
  e.canonical_name,
  e.short_description,
  jsonb_strip_nulls(jsonb_build_object(
    'segmento', e.detailed_description,
    'tipo_parceria', nullif(concat_ws(' · ',
        CASE WHEN e.metadata ? 'comissao_lucenera_pct' THEN 'Comissão Lucenera ' || (e.metadata->>'comissao_lucenera_pct') || '%' END,
        CASE WHEN e.metadata ? 'comissao_arquiteto_pct' THEN 'RT arquiteto ' || (e.metadata->>'comissao_arquiteto_pct') || '%' END), ''),
    'contato', nullif(concat_ws(' · ', e.metadata->>'cidade', e.metadata->>'telefone', e.website_url), ''),
    'observacoes_tecnicas', e.metadata->>'observacao')),
  ARRAY['fornecedor'],
  e.project_code,
  'publicado', 'importada', 'memoria_legado', e.id::text,
  'entities', e.id, e.owner_id, e.owner_id,
  jsonb_build_object('legado', to_jsonb(e)),
  e.created_at, e.updated_at
FROM memoria.entities e
WHERE e.deleted_at IS NULL AND e.entity_type = 'fornecedor'
ON CONFLICT (legado_tabela, legado_id) WHERE legado_id IS NOT NULL DO NOTHING;

-- entities: cadastro institucional -> procedimento --------------------------
INSERT INTO memoria.kb_itens (
  tipo, titulo, resumo, campos, tags, project_code, status, origem, origem_fonte, origem_chave,
  legado_tabela, legado_id, autor_id, atualizado_por, metadata, created_at, updated_at
)
SELECT
  'procedimento',
  'Cadastro institucional — ' || e.canonical_name,
  e.short_description,
  jsonb_strip_nulls(jsonb_build_object(
    'passo_a_passo', coalesce(e.metadata->>'diretriz_uso',
                              'Dados cadastrais para fichas de fornecedores e clientes. Confirmar antes qual razão social será usada na operação.'),
    'observacoes', concat_ws(E'\n',
      CASE WHEN e.metadata ? 'cnpj' THEN 'CNPJ: ' || (e.metadata->>'cnpj') END,
      CASE WHEN e.metadata ? 'inscricao_estadual' THEN 'Inscrição estadual: ' || (e.metadata->>'inscricao_estadual') END,
      CASE WHEN e.metadata ? 'inscricao_municipal' THEN 'Inscrição municipal: ' || (e.metadata->>'inscricao_municipal') END,
      CASE WHEN e.metadata ? 'conta_corrente_bradesco_ag_3427' THEN 'Conta corrente Bradesco (ag. 3427): ' || (e.metadata->>'conta_corrente_bradesco_ag_3427') END,
      CASE WHEN e.metadata ? 'nome_fantasia' THEN 'Nome fantasia: ' || (e.metadata->>'nome_fantasia') END,
      CASE WHEN e.metadata ? 'endereco_sede_faturamento' THEN 'Sede / faturamento: ' || (e.metadata->>'endereco_sede_faturamento') END,
      CASE WHEN e.metadata ? 'endereco_suprimentos' THEN 'Suprimentos: ' || (e.metadata->>'endereco_suprimentos') END,
      CASE WHEN e.metadata ? 'telefone_geral' THEN 'Telefone geral: ' || (e.metadata->>'telefone_geral') END,
      CASE WHEN e.metadata ? 'email_geral' THEN 'E-mail geral: ' || (e.metadata->>'email_geral') END,
      CASE WHEN e.metadata ? 'emails_nfe' THEN 'E-mails para NF-e: ' || (SELECT string_agg(v, ', ') FROM jsonb_array_elements_text(e.metadata->'emails_nfe') v) END,
      CASE WHEN e.metadata ? 'dados_bancarios_comuns' THEN 'Banco: ' || concat_ws(' · ',
             e.metadata#>>'{dados_bancarios_comuns,banco}',
             'agência ' || (e.metadata#>>'{dados_bancarios_comuns,agencia}'),
             'gerente ' || (e.metadata#>>'{dados_bancarios_comuns,gerente}'),
             e.metadata#>>'{dados_bancarios_comuns,telefone_gerente}') END,
      CASE WHEN e.metadata ? 'contatos' THEN 'Contatos:' || E'\n' || (
             SELECT string_agg('  ' || initcap(replace(area.key, '_', ' ')) || ': ' ||
                      (SELECT string_agg(concat_ws(' — ', p->>'nome', p->>'email', p->>'telefone'), '; ')
                       FROM jsonb_array_elements(area.value) p), E'\n')
             FROM jsonb_each(e.metadata->'contatos') area) END,
      CASE WHEN e.metadata ? 'principais_fornecedores_institucionais' THEN 'Fornecedores institucionais: ' ||
             (SELECT string_agg(v, ', ') FROM jsonb_array_elements_text(e.metadata->'principais_fornecedores_institucionais') v) END
    ))),
  ARRAY['cadastro', 'institucional', CASE e.entity_type WHEN 'razao_social' THEN 'razão social' ELSE 'grupo Lucenera' END],
  e.project_code,
  'publicado', 'importada', 'memoria_legado', e.id::text,
  'entities', e.id, e.owner_id, e.owner_id,
  jsonb_build_object('legado', to_jsonb(e)),
  e.created_at, e.updated_at
FROM memoria.entities e
WHERE e.deleted_at IS NULL AND e.entity_type IN ('razao_social', 'empresa_grupo')
ON CONFLICT (legado_tabela, legado_id) WHERE legado_id IS NOT NULL DO NOTHING;

-- sources -> procedimento ----------------------------------------------------
INSERT INTO memoria.kb_itens (
  tipo, titulo, resumo, campos, tags, project_code, status, origem, origem_fonte, origem_chave,
  legado_tabela, legado_id, autor_id, atualizado_por, metadata, created_at, updated_at
)
SELECT
  'procedimento',
  s.title,
  s.notes,
  jsonb_strip_nulls(jsonb_build_object('ferramentas', s.url, 'observacoes', s.notes)),
  ARRAY['link', 'referência'],
  s.project_code,
  'publicado', 'importada', 'memoria_legado', s.id::text,
  'sources', s.id, s.owner_id, s.owner_id,
  jsonb_build_object('legado', to_jsonb(s)),
  s.created_at, s.updated_at
FROM memoria.sources s
ON CONFLICT (legado_tabela, legado_id) WHERE legado_id IS NOT NULL DO NOTHING;

COMMIT;
