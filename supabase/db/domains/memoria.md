# Domínio: Memória Lucenera (schema `memoria`)

> Origem: SPEC-129. Sistema de memória institucional criado pelo Filippo
> (`github.com/filippogiorgibrasil/memoria-lucenera`), trazido para o ecossistema
> como sistema interno (Skip projectId 57204 → `memoria-lucenera-2e074.goskip.app`,
> tile `slug='memoria'` em `public.systems`).

## Papel no ecossistema

Base de conhecimento institucional: entidades, conhecimentos, experiências,
decisões, projetos, fontes, relações e citações da empresa — mais uma camada de
"caixa de entrada" (voz / documento) e uma camada de regras de organização
aprendidas.

Não guarda dado operacional em tempo real (estoque, preço, disponibilidade). A
integração com dados de `public` será feita depois por uma função de consulta
restrita (RPC/Edge Function com whitelist), nunca acesso SQL direto — ver SPEC-129
e o aviso do `INSTALACAO-LUCENERA.md` do repo.

## Isolamento

- Tudo vive no schema **`memoria`**, criado por `supabase.sql`. **Nada** é criado
  em `public`.
- `revoke all on schema memoria from public, anon` + `grant usage ... to
  authenticated, service_role`. O `anon` **não** enxerga nada — o app exige login.
- RLS por `owner_id` em todas as tabelas (cada usuário só vê o que criou).
- Storage: bucket privado **`lucenera-memory-files`**, policies por `owner_id`.
- Exposto à API via `authenticator.pgrst.db_schemas = 'public, graphql_public,
  memoria'` (SPEC-129; equivalente ao campo "Exposed schemas" do painel).

## Tabelas (núcleo — `supabase.sql`, aplicado)

`entities`, `knowledge_items`, `projects`, `experiences`, `decisions`, `sources`,
`relations`, `citations`, `files`, `record_versions`, `inbox_items`, `domains`.

Triggers: `touch_updated_at`, `archive_version` (versiona antes de alterar),
`keep_original_transcription`.

**SPEC-134 (aplicada):** `project_code text` (texto livre, sem FK) em `entities`,
`knowledge_items`, `experiences`, `decisions`, `projects`, `sources`,
`inbox_items` + índice parcial por tabela (`where project_code is not null`).
Preenchido em todos os formulários de adicionar/editar informação do app (Skip
57204), inclusive captura rápida, upload de arquivo e revisão de memória por
voz — permite marcar qualquer registro com o código de um projeto operacional
Lucenera (ex.: `26.181`) para achar depois. Não confundir com `projects` (tipo
de registro interno da própria Memória Lucenera).

## Backfill manual da base de conhecimento (2026-09-21)

O usuário tentou 2x colocar o conteúdo institucional consolidado
(`01-Documento/01 - Planilhas/Mamoria_lucenera.txt`) no app — upload do
.docx + "interpretar com IA", e cadastro manual pelos formulários — e nenhuma
das duas gerou registro nenhum (confirmado: 0 linhas em todas as tabelas de
conteúdo antes do backfill). Causa: a fase 2 (abaixo) nunca foi implementada,
então um upload de documento não tem como virar conhecimento estruturado
sozinho — fica só em `memoria.files`/`memoria.inbox_items`, sem `extracted_text`.

Solução aplicada: `scripts/importar_memoria_base_conhecimento.py` transcreveu
o conteúdo à mão (31 `knowledge_items`, 21 `entities` — grupo + 3 razões
sociais + 17 fornecedores —, 2 `sources`, 3 `relations` ligando as razões
sociais ao grupo) direto via `SUPABASE_DB_URL`, contornando o app. Rerun-safe
(`metadata.import_batch = 'base_conhecimento_2026_09_21'`).

## Tabelas (fase 2 — NÃO aplicadas)

- `memory-organization.sql` → `memory_organization_rules` / `_feedback` /
  `_rule_evidence` / `_rule_versions` / `_settings` / `_conflicts`.
- `document-ingestion.sql` → RPC `save_document_analysis`.
- `long-document-ingestion.sql` → `document_ingestion_runs`, `document_sections`,
  RPC `save_long_document_analysis`.

Enquanto não aplicadas, o app degrada de forma graciosa (o adapter faz `try/catch`
por tabela opcional) e os menus/telas correspondentes ficam fora.

## Edge Functions (fase 2 — NÃO deployadas)

`interpret-memory`, `process-document`, `process-document-section`,
`consolidate-document-run`. No repo do Filippo chamam a OpenAI; a decisão da
SPEC-129 é adaptá-las para **Gemini** (`GEMINI_API_KEY`).

## Relação com outros domínios

- **Hub/TI:** `public.systems` (`slug='memoria'`) + RBAC (`hub_sistemas_permitidos`).
  Login único via `exchange-cross-system-code` (mesmo projeto Supabase; o app
  consome `?sso_code=` em `public/app/sso.js`).
- **Auth:** `memoria.*.owner_id -> auth.users(id)`. A troca de SSO resolve o
  usuário pelo `public.usuarios` (e-mail) e devolve sessão.
- Nenhuma FK cruza de `memoria` para `public`.

## Reuniões de projeto: decisões e fila de revisão (SPEC-165 — aplicada em 2026-09-29)

- `kb_decisoes`: cada decisão de uma reunião (`reuniao_id` → `kb_itens` tipo `reuniao_projeto`,
  cascade), com `project_code` obrigatório e `excepcional` (solução pontual daquele projeto — fica só
  como histórico). Consulta por projeto em `/projeto/:codigo` no app.
- `kb_sugestoes`: fila de revisão das sugestões de aproveitamento para os demais temas.
  Nasce `pendente`; só curador muda o status e só a partir de `pendente`; `aprovada` exige
  `item_criado_id` de item existente do mesmo `tipo_destino` (o item é criado pela pessoa ao aprovar);
  conteúdo imutável depois de criada; bloqueada se `decisao_id` aponta decisão excepcional
  (trigger `kb_sugestoes_guardar`).
- Edge Function `interpretar-reuniao` (Gemini, com modelos de reserva): lê texto/.docx e devolve uma
  proposta; não grava nada.

## Base de conhecimento corporativa (SPEC-164 — aplicada em 2026-09-24)

Modelo novo ao lado das tabelas antigas (que ficam intactas e servem o app em `/legado`):

- `kb_itens` — um item por conhecimento. `tipo` (`memoria.kb_tipo`: reuniao_projeto, visita_obra,
  teste_material, regra_material, padrao_projeto, procedimento, marca, designer, vivencia_evento) →
  `categoria` gerada (`memoria.kb_categoria`: tecnico, comercial, operacional, projeto, aprendizado).
  Campos do template em `campos jsonb`; `tags text[]`; `status` (`kb_status`: rascunho, publicado,
  arquivado); `origem` (`kb_origem`: manual, importada) + `origem_fonte`/`origem_chave` únicos;
  `legado_tabela`/`legado_id` para o conteúdo copiado; `autor_id ON DELETE SET NULL`.
- `kb_itens_versoes` (snapshot antes de cada alteração), `kb_anexos` (storage `kb/<item_id>/`),
  `kb_sinonimos` (grupo, termo normalizado).
- RPCs: `kb_buscar(q, categoria, tipo, limite, prefixo)` e `kb_sugerir(q, limite)` — SECURITY INVOKER.
- RLS: `kb_eh_interno()` (usuário ativo em `public.usuarios`) lê publicados; rascunho/arquivado só
  autor ou curador; editar = autor ou curador; apagar = curador. Curador =
  `hub_pode_executar(uid, 'memoria', NULL, 'aprovar')` (admin e admin_geral).
