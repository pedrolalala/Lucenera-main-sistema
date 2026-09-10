---
titulo: "SPEC-129 — Integrar a Memória Lucenera ao ecossistema interno e à Central"
status: pendente
data_ultima_modificacao: 2026-09-09
sistemas_envolvidos:
  - Sistema novo "Memória Lucenera" (fork do repo do Filippo → repo `pedrolalala/*` → submodule `04-Sistemas/memoria-lucenera`)
  - Supabase (banco central) — schema isolado `memoria` (núcleo já aplicado), 3 scripts complementares pendentes, `memoria` nos Exposed schemas, 4 Edge Functions
  - Hub / Central (`central-lucenera-dashboard-1c9ba`) — nova linha em `public.systems`, RBAC, SSO cross-system
  - Skip — novo projeto para hospedar o site
dependencias:
  - SPEC-125 (precedente de "sistema novo": fork + projeto Skip + submodule + env vars + linha em `public.systems`)
  - SPEC-120 (menu lateral `SystemSwitcher` / hook `useSistemasPermitidos` — navegação entre sistemas)
  - SPEC-069 (matriz RBAC / RPC `hub_sistemas_permitidos`, `user_system_access`)
  - Edge Functions `generate-cross-system-code` / `exchange-cross-system-code` já existentes no Hub (`src/lib/cross-system-auth.ts`)
---

# SPEC-129 — Integrar a Memória Lucenera ao ecossistema interno e à Central

> Origem: pedido direto do usuário. O chefe (Filippo) criou um sistema de
> armazenamento de memória institucional da empresa e mandou o repositório
> `github.com/filippogiorgibrasil/memoria-lucenera`. Objetivo: trazer o sistema
> para dentro do ecossistema Lucenera (submodule + Skip + banco central) e
> registrá-lo na Central como mais um sistema interno, com SSO.

## Checklist de Ação

### Repositório / submodule

- [x] Repo `github.com/pedrolalala/memoria-lucenera` **existe** — mas foi criado como **scaffold Skip React/Vite/TS/shadcn vazio** (`src/main.tsx`, `Index.tsx`, `skip.js`), **não** é cópia do app do Filippo
- [ ] Decidir a estratégia de porte (ver §"Estratégia de porte para o Skip") e povoar o repo
- [ ] Registrar como submodule em `04-Sistemas/memoria-lucenera` (`.gitmodules` + ponteiro)
- [ ] Registrar o sistema em `04-Sistemas/00 - Sumario Sistemas.md`
- [ ] Criar `04-Sistemas/memoria-lucenera/supabase/AI_DB_CONTEXT.md` apontando que o schema é `memoria` (isolado) e que o núcleo já está aplicado no banco central

### Banco de dados (schema `memoria`, isolado — não toca `public`)

- [x] `supabase.sql` (núcleo) — **JÁ APLICADO pelo usuário no Supabase real**: 12 tabelas em `memoria` (`entities`, `knowledge_items`, `projects`, `experiences`, `decisions`, `sources`, `relations`, `citations`, `files`, `record_versions`, `inbox_items`, `domains`), RLS ativo nas 12, 12 policies, 3 funções de trigger (`archive_version`, `keep_original_transcription`, `touch_updated_at`), bucket privado `lucenera-memory-files` criado
- [ ] Consolidar os 4 scripts do repo em `supabase/db/migrations/20260909_130_memoria_lucenera_schema/` (arquivos originais do Filippo, sem edição de regra) + `README.md` do grupo registrando o que já foi aplicado
- [ ] Aplicar `memory-organization.sql` no Supabase real (tabelas `memory_organization_*`) — **pendente**
- [ ] Aplicar `document-ingestion.sql` no Supabase real (RPC `save_document_analysis`) — **pendente**
- [ ] Aplicar `long-document-ingestion.sql` no Supabase real (tabelas `document_ingestion_runs`/`document_sections`, RPC `save_long_document_analysis`) — **pendente**
- [ ] Rodar `verify-isolation.sql` do repo e anexar o resultado ao README do grupo
- [ ] Documentar o novo schema em `supabase/db/domains/` (novo arquivo `memoria.md`) e em `supabase/db/current/`
- [ ] Confirmar que nenhuma policy nova em `memoria` referencia/afeta `public`

### Exposição à API

- [x] `memoria` exposto ao PostgREST via `ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, memoria'` + `NOTIFY pgrst, 'reload schema'/'reload config'` (2026-09-09, autorizado). Ver `05_expor_schema_e_registrar_no_hub.sql`.
- [x] Validado: `SET ROLE authenticated` consulta `memoria.entities/knowledge_items/inbox_items` sem erro (0 linhas, RLS ok); `anon` recebe 401 `permission denied for schema memoria` — **comportamento correto** (Filippo faz `revoke ... from anon`; o app exige login).
- [ ] (Durabilidade) confirmar/re-salvar `memoria` no campo **Settings → API → Exposed schemas** do painel — o valor do painel tem precedência sobre o `ALTER ROLE`.

### Edge Functions — adaptar de OpenAI para **Gemini**

> Decisão do usuário: usar Gemini (`GEMINI_API_KEY` já no `.env`), não OpenAI (custo).
> As 4 funções do repo do Filippo chamam a API da OpenAI (`gpt-4o-mini`, endpoint
> `chat/completions`, formato de resposta OpenAI). Cada uma precisa trocar: URL do
> endpoint, formato do corpo (`contents`/`parts` do Gemini), parsing da resposta
> (`candidates[].content.parts[].text`), e o secret lido (`GEMINI_API_KEY`).

- [ ] Adaptar + deploy de `interpret-memory` (memória por voz — inclui transcrição de áudio; confirmar se Gemini cobre o mesmo fluxo ou se a transcrição precisa de outra rota)
- [ ] Adaptar + deploy de `process-document` (ingestão simples)
- [ ] Adaptar + deploy de `process-document-section` (livros longos)
- [ ] Adaptar + deploy de `consolidate-document-run` (livros longos)
- [ ] Secret `GEMINI_API_KEY` em **Edge Functions → Secrets**
- [ ] (Opcional) secrets de config `MEMORIA_DB_SCHEMA=memoria`, `MEMORIA_STORAGE_BUCKET=lucenera-memory-files`, `GEMINI_MODEL`

### Hosting no Skip

- [x] Projeto Skip criado pelo usuário: **projectId 57204**, org "Org Lucenera" (11458), produção `https://memoria-lucenera-2e074.goskip.app`, preview `…--preview.goskip.app`
- [x] `projectId 57204` anotado (ver `reference_skip_project_ids`)
- [x] Porte **Opção A** executado via MCP do Skip: app do Filippo em `public/app/` (`app.js`, `supabase-adapter.js`, `memory-organization-core.js`, `long-document-core.js`, `styles.css`, `sso.js`), verificado byte-a-byte contra o fonte + `node --check` OK
- [x] `index.html` da raiz = shell React vazio (monta em `#root`, `App.tsx`/`Index.tsx`/`Layout.tsx` renderizam `null`) + markup e scripts do app do Filippo; `MEMORIA_CONFIG` inline com `%VITE_SUPABASE_URL%` / `%VITE_SUPABASE_PUBLISHABLE_KEY%` (Vite substitui no build — **confirmado funcionando** para a URL)
- [x] `.oxfmtrc.json` ignora `public/`; `vite.config.ts` é read-only no MCP (não deu p/ plugin de config — daí o `%VITE%` no HTML)
- [x] `skip_env_set VITE_SUPABASE_URL` = `https://vcvcwzmbiftcawncibke.supabase.co`
- [ ] `skip_env_set VITE_SUPABASE_PUBLISHABLE_KEY` = anon key (o classificador bloqueou a IA de ler o segredo do `.env`) — **passo do usuário**
- [x] `skip_env_set VITE_SUPABASE_PUBLISHABLE_KEY` — feito pelo usuário ("já conectei com o supabase")
- [x] QA pipeline do Skip **verde** (setup/static/build/integrations/test)
- [x] `skip_project_publish` — **PUBLICADO em produção** 2026-09-10, versão 0.0.7 `e270d8e`, `https://memoria-lucenera-2e074.goskip.app`. Verificado: `/` e `/app/*` HTTP 200; `MEMORIA_CONFIG` com URL + anon key (208 chars) substituídas no build.
- [ ] `memory-organization.js`, `document-ingestion.js`, `book-ingestion.js` + item 'organization' do menu: **fase 2** (Edge Functions Gemini + migrations 02-04). Removidos do `index.html`/`navItems` por ora.

### Integração com a Central

- [x] `INSERT` em `public.systems`: `slug='memoria'`, `name='Memória Lucenera'`, `link='https://memoria-lucenera-2e074.goskip.app/'`, `icon_name='BrainCircuit'`, `display_order=11`, `visivel_no_hub=true` (id `9463d897-bd1c-4781-a36e-3cdac23c101a`, 2026-09-09)
- [x] Acesso fase 1: liberado a todos (`visivel_no_hub=true`; admin vê por bypass; demais via `hub_sistemas_permitidos`/legado). RLS do app é por `owner_id`.
- [ ] Se algum dia o acesso virar restrito: popular `user_system_access` / matriz RBAC (SPEC-069) para o `system_id` acima
- [ ] Confirmar que a RPC `hub_sistemas_permitidos` e o hook `useSistemasPermitidos` já retornam o novo sistema sem código novo (são data-driven a partir de `systems`)

### SSO cross-system (login único)

- [x] Lidas `generate/exchange-cross-system-code` do Hub: **sem allowlist de `sistema_destino`**. `exchange` só casa o `sistema_destino` gravado no code (o Hub grava a partir do slug) — a linha `slug='memoria'` em `systems` basta. Mesmo projeto Supabase → `sb.functions.invoke` alcança as funções.
- [x] `public/app/sso.js` (novo): no bootstrap, se houver `?sso_code=`, cobre a tela com overlay "Entrando…", chama `exchange-cross-system-code` com `{code, sistema_destino:'memoria'}`, aplica `setSession`/`verifyOtp`, limpa a URL e recarrega — aí o `supabase-adapter.js` acha a sessão e abre o app. Sem `sso_code`, é inerte.
- [ ] Atalho de volta para a Central dentro do app (link simples pro Hub) — **pendente** (fase 2; `SystemSwitcher` React não se aplica a app vanilla)
- [ ] Testar ao vivo: logar no Hub → tile "Memória Lucenera" → abrir sem segundo login (depende do publish + env var)

### Documentação

- [x] `CHANGELOG.md` — bloco 2026-09-10 adicionado
- [x] `supabase/db/domains/memoria.md` — criado (schema isolado, núcleo x fase 2, isolamento, relações)
- [ ] `04-Sistemas/00 - Sumario Sistemas.md` — **arquivo não existe** no repo (AGENTS.md cita mas não há); pular ou criar o índice à parte
- [ ] `04-Sistemas/memoria-lucenera/supabase/AI_DB_CONTEXT.md` — quando o submodule existir
- [ ] Ponteiro do submodule commitado no repo central só depois do código estar no GitHub

### Passos manuais do usuário

- [ ] Criar o repo fork `pedrolalala/memoria-lucenera` no GitHub (a IA não cria repo remoto)
- [ ] Adicionar `memoria` aos Exposed schemas no painel Supabase
- [ ] Criar o projeto Skip e autorizar `skip_env_set` / `publish`
- [ ] Confirmar/cadastrar `OPENAI_API_KEY` nos Secrets das Edge Functions
- [ ] Autorizar explicitamente cada `apply` das 3 migrations complementares no Supabase real
- [ ] Decidir a política de acesso (quem vê o tile) e a semântica de `visibility` (`private` vs `company`) para memória institucional compartilhada
- [ ] `git push` do repo central quando os ponteiros estiverem prontos

## Objetivo

Registrar a "Memória Lucenera" como um sistema interno de primeira classe: código
versionado como submodule, banco no schema isolado `memoria` do projeto Supabase
central, deploy no Skip, tile na Central e login único (SSO) com os demais
sistemas — sem exigir um segundo login e sem tocar em nada do schema `public`.

## Decisões aprovadas

- **Repo**: sob nosso controle (`pedrolalala/memoria-lucenera`), não o repo do Filippo direto. Já criado — como **scaffold Skip React vazio** (não cópia do app).
- **Hosting**: Skip (mesmo pipeline/QA/deploy dos outros ~10 sistemas), não Netlify.
- **SSO**: integração completa agora — o app aceita o `sso_code` do `redirectWithCode` do Hub; sem segundo login.
- **Banco**: o schema `memoria` fica isolado; o núcleo (`supabase.sql`) já foi aplicado pelo usuário no banco real.
- **IA**: usar **Gemini** (`GEMINI_API_KEY`, gratuito), não OpenAI — as 4 Edge Functions do Filippo serão adaptadas.
- **Acesso (fase 1)**: tile **liberado para todos** os usuários internos. RLS do app já é por `owner_id`.
- **Acesso da IA a dados operacionais (`public` / "data center")**: **restrito, whitelist** — a IA só consulta um conjunto específico de informações, via RPC/Edge Function dedicada. **Fora do escopo desta SPEC** (fase futura); alinhado com o aviso do `INSTALACAO-LUCENERA.md` ("não dê acesso SQL direto da IA às tabelas da empresa").

## Definição da SPEC

### Estado atual verificado (2026-09-09)

| Item | Estado |
|---|---|
| `memoria.*` (12 tabelas do núcleo) | ✅ existe no Supabase real, RLS ativo, 12 policies |
| Bucket `lucenera-memory-files` | ✅ existe (privado) |
| `memory_organization_*`, `document_ingestion_runs`, `document_sections` | ❌ não aplicados |
| RPC `save_document_analysis` / `save_long_document_analysis` | ❌ não existem |
| `memoria` em Exposed schemas (PostgREST) | ❌ `pgrst.db_schemas` não inclui `memoria` |
| Linha em `public.systems` (`slug='memoria'`) | ❌ não existe |
| 4 Edge Functions | ❌ não deployadas |
| Arquivo `supabase/db/migrations/Filippo amarzenamento banco de dados/SQL` | ⚠️ vazio (0 bytes) — substituir pelo grupo `20260909_130_*` |

### O que o sistema é

- Site **estático puro**: `index.html` + `app.js` + `config.js` + `styles.css`, **sem build**, sem framework. `@supabase/supabase-js@2` e `mammoth` via CDN (`cdn.jsdelivr.net`).
- Auth próprio: e-mail/senha do Supabase Auth. Modo demo grava só em `localStorage`.
- `supabase-adapter.js` carrega as tabelas de `memoria` direto via PostgREST; degrada de forma graciosa quando as tabelas opcionais (org/ingestão) não existem (`optionalRemoteTables`).
- 4 Edge Functions usam `OPENAI_API_KEY` (só no servidor).

### Alterações no banco

Nenhuma alteração de regra nos scripts do Filippo — eles vão para
`supabase/db/migrations/20260909_130_memoria_lucenera_schema/` como recebidos, com
um `README.md` de grupo registrando ordem, o que já foi aplicado e o resultado do
`verify-isolation.sql`. As 3 migrations complementares só são aplicadas no real
com autorização explícita, uma a uma.

### Integração com a Central (data-driven)

O Hub lista sistemas a partir de `public.systems` + RBAC (`hub_sistemas_permitidos`
com bypass de admin para tudo que é `visivel_no_hub=true`, fallback legado
`user_system_access`). **Não precisa de código novo no Hub** — basta a linha em
`systems` e, se o acesso for restrito, os grants de RBAC.

### SSO — o que falta no app da Memória

O Hub já emite o código (`redirectWithCode` → `generate-cross-system-code`) e o
padrão de consumo está em `src/lib/cross-system-auth.ts::consumeCodeFromUrl`
(lê `?sso_code=`, troca em `exchange-cross-system-code`, `setSession`). O app
vanilla precisa de um equivalente mínimo no bootstrap (`sso.js` novo, carregado
antes de `app.js` decidir mostrar login):

```
1. const code = new URLSearchParams(location.search).get('sso_code')
2. se code: invoke('exchange-cross-system-code', { code, sistema_destino: 'memoria' })
3.   -> setSession({access_token, refresh_token})  (ou verifyOtp({token_hash, type:'magiclink'}))
4.   -> history.replaceState para remover ?sso_code
5. seguir o fluxo normal de sessão já existente
```

Pré-requisitos: linha `slug='memoria'` em `systems`; `memoria` exposto na API;
`config.js` com URL + publishable key do projeto central.

### Estratégia de porte para o Skip (DECISÃO EM ABERTO)

O repo `pedrolalala/memoria-lucenera` já existe, mas é um **scaffold Skip
React/Vite/TS/shadcn vazio** — `src/main.tsx` como entrypoint, `src/App.tsx` como
rota, `<script src="https://goskip.dev/skip.js">` protegido, QA do Skip roda
`oxlint`/`oxfmt`/`tsc`. O app do Filippo é **~2.500 linhas de JS puro sem build,
sem ESM** (`app.js`, `supabase-adapter.js`, `memory-organization*.js`,
`long-document-core.js`, `document-ingestion.js`, `book-ingestion.js`), montando o
DOM na mão. As duas coisas não se encaixam sem uma decisão:

| Opção | O que é | Prós | Contras |
|---|---|---|---|
| **A. Passthrough estático** | Jogar os arquivos do Filippo em `public/`, trocar o `index.html` raiz pelo dele (mantendo `skip.js`), esvaziar `src/`. `vite build` copia `public/` pra `dist/`. | Rápido; app roda igual ao original; pouco código novo. | Vai contra o grão do Skip (entrypoint/rotas/QA esperam React); `tsc`/`oxlint` sobre `src/` vazio; arquivos `@skip-protected`; manutenção futura estranha. |
| **B. Porte para React** | Reescrever a UI (`app.js`) como componentes React no scaffold; reaproveitar a lógica agnóstica (`*-core.js`, adapter) como módulos. | Encaixa no Skip, na QA, no SSO (`SystemSwitcher`/`cross-system-auth` são React) e no padrão dos outros 10 sistemas. | Trabalho grande — várias sessões; risco de regressão de comportamento vs. o app do Filippo. |
| **C. Host estático fora do Skip** | Publicar o app do Filippo como está (Cloudflare Pages / Skip static / Netlify); Central só aponta o link; SSO igual. | Menor esforço; zero reescrita. | Usuário já descartou Netlify e pediu Skip; fora do pipeline/QA. |

Recomendação: **A** para entregar rápido e validar o fluxo ponta a ponta (SSO +
Central + banco), com **B** como evolução planejada depois. Precisa da confirmação
do usuário antes de executar.

### Critérios de aceite

- [ ] Submodule `04-Sistemas/memoria-lucenera` clona e o app abre publicado.
- [ ] `memoria` exposto na API; app carrega dados reais de um usuário `authenticated` (não demo).
- [ ] As 3 migrations complementares aplicadas e `verify-isolation.sql` limpo, OU decisão explícita de adiar as features de ingestão/organização.
- [ ] Tile "Memória Lucenera" aparece na Central para os usuários certos.
- [ ] Login no Hub → tile → app abre sem segundo login, mesmo `auth.uid()`.
- [ ] Nenhuma tabela/policy nova em `public`; `GET /rest/v1/<tabela public>` inalterado.
- [ ] `CHANGELOG.md` e docs de sistema/banco atualizados; ponteiro do submodule só após push do fork.

## Realizado

### 2026-09-09

- Investigação inicial: clonado o repo do Filippo, mapeada a arquitetura (site no-build + schema `memoria` + 4 Edge Functions OpenAI + bucket privado).
- Verificado o Supabase real: núcleo `supabase.sql` já aplicado (12 tabelas, RLS, 12 policies, bucket). Scripts 2–4 e Exposed schemas ainda pendentes.
- Verificado que o arquivo `supabase/db/migrations/Filippo amarzenamento banco de dados/SQL` estava vazio — **removido** e substituído pelo grupo `20260909_130_memoria_lucenera_schema/` (4 SQL do Filippo + `99_verify-isolation.sql` + `README.md`).
- Mapeado o mecanismo da Central (`public.systems` + `hub_sistemas_permitidos` + `cross-system-auth.ts`).
- Verificado que `github.com/pedrolalala/memoria-lucenera` já existe, mas é um **scaffold Skip React vazio**, não a cópia do app do Filippo.
- SPEC criada. Decisões fechadas: repo próprio, Skip, SSO completo, **Gemini no lugar de OpenAI**, tile liberado pra todos, acesso da IA a dados operacionais é fase futura com whitelist.
- **Banco de produção (autorizado pelo usuário):** `memoria` exposto ao PostgREST; `public.systems` ganhou a linha `slug='memoria'` (`link` → `https://memoria-lucenera-2e074.goskip.app/`). Verificado: `authenticated` lê `memoria.*` sob RLS; `public` intacto.
- Lidas as Edge Functions `generate/exchange-cross-system-code` do Hub: **sem allowlist de destino**, mesmo projeto Supabase → SSO da Memória não exige mudança no Hub, só o consumo do `?sso_code=` no app.
- Projeto Skip localizado: id **57204**, org "Org Lucenera" (11458), produção `https://memoria-lucenera-2e074.goskip.app`.
- Estratégia de porte **A** executada via MCP do Skip: shell React vazio + app do Filippo em `public/app/`. Arquivos conferidos byte-a-byte contra o fonte, `node --check` OK. QA do Skip verde (v0.0.5 `69b13a1`). Preview serve `/`, `/app/app.js`, `/app/styles.css` (HTTP 200). `%VITE_SUPABASE_URL%` substituído no build (confirmado); falta `VITE_SUPABASE_PUBLISHABLE_KEY`.
- `sso.js` escrito. `memory-organization.js`/`document-ingestion.js`/`book-ingestion.js` adiados p/ fase 2 (Edge Functions Gemini).
- Usuário configurou `VITE_SUPABASE_PUBLISHABLE_KEY` no Skip. Rebuild confirmou URL + anon key (208 chars) substituídas.
- **PUBLICADO em produção** 2026-09-10 (v0.0.7 `e270d8e`, `https://memoria-lucenera-2e074.goskip.app`). `CHANGELOG.md` atualizado.
- Falta: teste ao vivo do SSO pelo Hub; submodule (GitHub tem só o scaffold — Skip não sincroniza pro Git sozinho); docs de sistema/domínio; fase 2.

## Pendências

- [ ] `VITE_SUPABASE_PUBLISHABLE_KEY` (anon key) não configurada no Skip (projectId 57204) — a IA foi bloqueada de ler o segredo do `.env`. Sem ela o app publica em modo demo. Passo do usuário: `skip_env_set` (colar a chave) ou setar na UI de Environment Variables do Skip.
- [ ] `skip_project_publish` do projeto 57204 não executado (aguarda a env var acima).
- [ ] Submodule `04-Sistemas/memoria-lucenera` não registrado — o GitHub `pedrolalala/memoria-lucenera` só tem o scaffold; o Skip não sincroniza a árvore dele pro Git automaticamente. Definir como levar o código do Skip pro repo GitHub antes de virar submodule (push manual do usuário, ou export do Skip).
- [ ] Migrations `02_memory-organization.sql`, `03_document-ingestion.sql`, `04_long-document-ingestion.sql` não aplicadas — memória por voz, ingestão de documentos e camada de organização indisponíveis (o app degrada; itens já retirados do menu/`index.html`).
- [ ] 4 Edge Functions não adaptadas para Gemini nem deployadas; `GEMINI_API_KEY` não configurado nos Secrets do Supabase. `interpret-memory` faz transcrição de áudio (confirmar rota equivalente no Gemini).
- [ ] Teste ao vivo do SSO (Hub → tile → sem 2º login) — depende do publish.
- [ ] Atalho de volta pra Central dentro do app da Memória.
- [ ] (Durabilidade) `memoria` nos Exposed schemas do painel Supabase — hoje só via `ALTER ROLE authenticator` (o painel tem precedência).
- [ ] Docs de sistema/banco: `04-Sistemas/00 - Sumario Sistemas.md`, `04-Sistemas/memoria-lucenera/supabase/AI_DB_CONTEXT.md`, `supabase/db/domains/memoria.md`, `CHANGELOG.md`.
- [ ] Acesso restrito/whitelist da IA aos dados operacionais (`public`) — fase futura, sem SPEC própria ainda.
