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

## Fase 2 — Plano técnico (2026-09-21)

> Verificado ao vivo em 2026-09-21 (Management API, `psql` direto falhou por DNS de
> novo): schema `memoria` no Supabase real segue com só as 12 tabelas do núcleo —
> nenhuma das 3 migrations de fase 2 foi aplicada. Nenhuma das 4 Edge Functions
> existe em código em lugar nenhum do repo (nem versão OpenAI, nem Gemini) — precisam
> ser escritas do zero. `GEMINI_API_KEY` está no `.env` local e foi configurada como
> env var do projeto Skip 57204 (mas isso só vira `VITE_*` no build do frontend —
> **não** alimenta Edge Function nenhuma; ainda falta como secret de Edge Functions
> no Supabase).

> Base lida para este plano: `supabase/db/migrations/20260909_130_memoria_lucenera_schema/{02,03,04}_*.sql`,
> `supabase/db/domains/memoria.md`, `supabase/functions/chat-consulta/index.ts`,
> `supabase/functions/classificar_solicitacao/index.ts` (padrão de Edge Function + Gemini
> já estabelecido neste repo). Nenhum arquivo de frontend do app (`public/app/*.js`) existe
> neste repositório — eles vivem só no projeto Skip 57204; os campos exatos de
> `openVoiceReview` precisam ser lidos via `skip_file_read` no início da implementação,
> não foram re-verificados neste plano.

### Convenção adotada (consistente com o padrão já usado no repo)

Todas as 4 funções seguem o padrão de `chat-consulta` (não o de `classificar_solicitacao`,
que usa `service_role` porque roda como trigger de sistema): criam um client Supabase com
a **anon key + `Authorization` do usuário repassado**, para que `auth.uid()` resolva
corretamente dentro de RLS e das RPCs `security invoker`. Nenhuma das 4 funções usa
`SUPABASE_SERVICE_ROLE_KEY`. CORS via `../_shared/cors.ts` (mesmo módulo de
`classificar_solicitacao`). Erros do Gemini nunca viram 500 cru — sempre JSON
`{ error: "..." }` com status apropriado (400/401/404/422/502), replicando `chat-consulta`.

#### 1. Edge Function `interpret-memory`

**Request**: `POST`, `multipart/form-data`, campo `audio` (Blob, hoje `audio/webm` do
`MediaRecorder`). Headers: `Authorization: Bearer <jwt>`, `apikey`.

**Risco a resolver antes de codar de verdade (spike obrigatório)**: a lista oficial de MIME
types de áudio aceitos pelo Gemini (`generateContent` com `inlineData`) é
`audio/wav, audio/mp3, audio/aiff, audio/aac, audio/ogg, audio/flac` — **não inclui
`audio/webm`**. Plano de verificação, nesta ordem, antes de fechar a implementação:
1. Testar `inlineData: { mimeType: 'audio/webm', data: <base64> }` direto — alguns relatos
   de terceiros dizem que funciona mesmo fora da lista documentada (contêiner
   webm/opus é próximo de ogg/opus). Se der 200 com transcrição coerente, seguir com isso.
2. Se rejeitar (400 "unsupported mime type"), testar declarar `mimeType: 'audio/ogg'` no
   mesmo payload (mesmo blob, só troca o header) — chance de o decoder aceitar pelo codec
   real (Opus) e ignorar o nome do contêiner.
3. Se os dois falharem, o app precisa gravar em outro formato aceito nativamente
   (ex.: capturar PCM via Web Audio API e empacotar como `audio/wav`, ou usar uma lib de
   transcodificação client-side) — **isso é trabalho adicional fora da estimativa desta
   fase**, não decidir sozinho, voltar para o usuário com a opção antes de expandir escopo.
4. Limite de tamanho: manter o áudio dentro do limite prático de `inlineData` (~20MB
   antes de exigir a Files API do Gemini). Rejeitar com 413 e mensagem clara acima disso
   (não usar a Files API nesta fase — complexidade extra sem necessidade clara ainda).

**Fluxo**:
1. `createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization } } })`,
   `auth.getUser()` — sem usuário, 401.
2. Ler o `FormData`, pegar o campo `audio`; ausente/vazio → 400.
3. Converter para base64, montar `contents: [{ role:'user', parts: [{ inlineData: { mimeType, data } }, { text: PROMPT } ] }]` com `generationConfig: { responseMimeType: 'application/json' }` (mesmo padrão de `classificar_solicitacao`).
4. `PROMPT`/`systemInstruction` pede à IA: transcrever o áudio literalmente E devolver uma interpretação estruturada. **Schema de resposta a confirmar contra `openVoiceReview` em `public/app/app.js` antes de fechar** — proposta inicial mínima e estável:
   ```json
   { "transcription": "string",
     "structured": { "title": "string", "summary": "string", "domain": "string|null",
       "knowledge_type": "string|null", "tags": ["string"], "confidence": 0-100 } }
   ```
5. Chamar Gemini (modelo `gemini-2.0-flash` ou `gemini-1.5-flash`, alinhar com o que já
   está em uso nas outras 2 funções do repo — hoje há `gemini-1.5-flash` em
   `chat-consulta` e `gemini-3.6-flash` em `classificar_solicitacao`; escolher um e
   documentar por quê, não é decisão de negócio, é escolha técnica).
6. Parsear `candidates[0].content.parts[0].text` como JSON; se não for JSON válido → 502
   `{ error: 'Não foi possível interpretar o áudio.' }` (nunca inventar um resultado).
7. Retornar 200 com o JSON acima. **Não persiste nada no banco** — o app já tem o form de
   revisão que grava depois (mecanismo de salvar é código já existente em `app.js`, fora do
   escopo desta fase).
8. Timeout: 28s (mesmo valor de `classificar_solicitacao`, áudio pode demorar mais que texto).

**Pendência explícita**: se o app espera persistir o **áudio original** (não só a
transcrição) para proveniência, isso não está coberto aqui — decisão de produto em aberto,
não assumida.

#### 2. Edge Function `process-document`

**Pré-requisito de banco**: migration `03_document-ingestion.sql` aplicada (RPC
`save_document_analysis`) — a função em si não depende da RPC, mas o fluxo completo
(revisão → salvar) só fecha com ela.

**Request**: `POST` JSON `{ inbox_id, file_id }`, `Authorization: Bearer <jwt>`.

**Fluxo**:
1. Client user-scoped (padrão acima). `auth.getUser()` → 401 se ausente.
2. `select * from memoria.inbox_items where id=inbox_id and owner_id=user.id` e
   `select * from memoria.files where id=file_id and owner_id=user.id` — 404 se não achar
   (RLS já protege, mas checar explícito dá mensagem melhor que erro genérico do PostgREST).
3. Obter o texto do documento:
   - Se `files.extracted_text` já estiver preenchido (extração feita no cliente, ex. `.docx`
     via `mammoth`, já usado no app), usar direto.
   - Se `files.mime_type = 'application/pdf'`, baixar o binário do Storage
     (`lucenera-memory-files/<storage_path>`) e mandar pro Gemini como
     `inlineData: { mimeType: 'application/pdf', data: base64 }` — Gemini 1.5/2.x Flash lê
     PDF nativamente (texto + estrutura), evita reimplementar parser de PDF no Edge Function.
   - Outro tipo sem `extracted_text` → 422 `{ error: 'Formato não suportado ainda: extraia o texto antes de interpretar.' }` (não tentar inventar suporte a mais formatos aqui).
4. Atualizar `inbox_items.processing_status='processing'`, `files.processing_status='analyzing'` antes de chamar o Gemini.
5. Montar `systemInstruction` pedindo o JSON EXATAMENTE na forma que `save_document_analysis` espera (contrato lido de `03_document-ingestion.sql`):
   ```json
   { "source": { "source_type","title","author","publisher","publication_date","language","reliability","summary","domain","outline" },
     "entities": [{ "client_key","canonical_name","entity_type","alternative_names","short_description","domain","mentions" }],
     "knowledge_items": [{ "client_key","title","summary","content","domain","knowledge_type","confidence","tags","epistemic_type",
        "entity_keys":["..."], "related_knowledge_keys":["..."],
        "citations":[{"locator","excerpt","support_type":"supports|contradicts|contextualizes"}] }],
     "relations": [{ "source_kind":"entity|knowledge", "source_key","target_kind":"entity|knowledge","target_key","relation_type","description","confidence" }] }
   ```
   `client_key` é um identificador arbitrário (ex. `"e1"`, `"k1"`) que a própria IA inventa
   para poder referenciar entidades/conhecimentos entre si dentro da mesma resposta — a RPC
   usa esses keys só para resolver relações internas, não são gravados como estão.
6. Chamar Gemini com `responseMimeType: 'application/json'`. Parse falhou ou Gemini erro →
   `inbox_items.processing_status='failed'`, `files.processing_status='failed'`, retornar
   502/500 com mensagem.
7. Sucesso → `inbox_items.processing_status='awaiting_review'`,
   `files.processing_status='awaiting_review'`, retornar
   `200 { analysis: <jsonb acima>, inbox_id, file_id }`.
8. **Não chama `save_document_analysis`** — isso é feito pelo frontend depois da revisão
   do usuário (ver `document-ingestion.js` abaixo), porque a RPC precisa do JSON já
   **editado pelo usuário**, não o bruto da IA.

#### 3. Edge Function `process-document-section`

**Pré-requisito de banco**: migration `04_long-document-ingestion.sql` aplicada.

**Request**: `POST` JSON `{ section_id }`, `Authorization: Bearer <jwt>`.

**Fluxo**:
1. Auth + `select * from memoria.document_sections where id=section_id and owner_id=user.id`
   (join implícito com `document_ingestion_runs` via `run_id`, mas RLS já restringe por
   `owner_id` de ambas as tabelas) — 404 se não achar.
2. `select * from memoria.document_ingestion_runs where id = section.run_id` para pegar
   `title`, `domain`, `subcategory`, `language` (contexto do livro todo).
3. `update document_sections set status='processing' where id=section_id`.
4. Mesmo shape de `analysis` do `process-document` (entities/knowledge_items/relations),
   mas escopado **só ao conteúdo desta seção** (`section.content` + `section.context_before`
   como contexto de continuidade — evita a IA redefinir uma entidade já mencionada na seção
   anterior). `client_key`s só precisam ser únicos dentro desta chamada.
5. Gemini falhou → `document_sections.status='failed', error_message=<msg>` → 502.
6. Sucesso → `document_sections.status='awaiting_review', analysis=<jsonb>` →
   `document_ingestion_runs.processed_sections = processed_sections + 1` (incrementar, não
   travar se paralelo — usar `update ... set processed_sections = processed_sections + 1`
   atômico do Postgres) → retornar `200 { section_id, status:'awaiting_review', analysis }`.
7. **Não chama `save_long_document_analysis`** — só roda por seção; a consolidação final é
   a próxima função.

#### 4. Edge Function `consolidate-document-run`

**Pré-requisito de banco**: migration `04` aplicada.

**Request**: `POST` JSON `{ run_id, project_id? }`, `Authorization: Bearer <jwt>`.

**Fluxo** — é um wrapper fino, não reimplementa lógica que já está na RPC:
1. Client user-scoped (mesmo padrão — **importante**: aqui não dá pra usar `service_role`,
   porque `save_long_document_analysis` é `security invoker` e lê `auth.uid()` para todo
   `owner_id` gravado; com `service_role` a função ainda rodaria mas `auth.uid()` seria
   `null` e a RPC lançaria `'Autenticação obrigatória'`).
2. `const { data, error } = await client.rpc('save_long_document_analysis', { p_run_id: run_id, p_project_id: project_id ?? null })`.
3. Erro da RPC (ex. `"Ainda existem seções sem análise ou com falha"`,
   `"Este livro já foi organizado"`) → repassar a `error.message` verbatim com status 422 —
   são mensagens de negócio já decididas no SQL, a função só encaminha, não reinterpreta.
4. Sucesso → `200 { success:true, result: data }` (contadores retornados pela própria RPC:
   `source_id, created_entities, created_knowledge_items, created_citations, created_relations`).
5. Não precisa tocar `document_ingestion_runs`/`document_sections` diretamente — a RPC já
   faz isso (`status='approved'` no run, `status='approved'` nas seções).

#### 5. Frontend — os 3 arquivos que faltam

Carregados hoje só em comentário no `index.html` do Skip 57204
(`"SPEC-129 fase 2 (Edge Functions Gemini + migrations 02-04): memory-organization.js,
document-ingestion.js, book-ingestion.js"`). Precisam ser escritos como scripts vanilla
(mesmo estilo sem-build de `app.js`/`supabase-adapter.js` — **não** introduzir React aqui,
o sistema já tem um padrão estabelecido e a Opção A de porte foi a escolhida na SPEC).

**Antes de escrever qualquer um dos 3**: ler `public/app/app.js` e `supabase-adapter.js`
reais no Skip (`skip_file_read`) para confirmar nomes de funções globais esperadas
(`window.processDocument`, estrutura de `optionalRemoteTables`, helpers de CRUD genérico
já existentes no adapter) e reaproveitar, não duplicar.

**`document-ingestion.js`**
- Define `window.processDocument = async function(inboxId) { ... }` (hoje undefined,
  chamado pelo botão `data-process-document`).
- Passos: acha o `file_id` do item na Caixa de Entrada já carregada em memória pelo
  adapter → `supabase.functions.invoke('process-document', { body: { inbox_id: inboxId, file_id } })`
  → em sucesso, abre um modal/painel de revisão com `data.analysis` (listas editáveis de
  entidades/itens de conhecimento/relações — aceitar/rejeitar/editar cada item) → botão
  "Confirmar e salvar" chama
  `supabase.rpc('save_document_analysis', { p_inbox_id, p_file_id, p_analysis: <jsonb editado>, p_project_id: projetoSelecionado ?? null, p_applied_rule_ids: [] })`
  direto do cliente (não via Edge Function) → em sucesso, recarrega a Caixa de Entrada e
  mostra os contadores retornados.
- Guarda de indisponibilidade: como `save_document_analysis` só existe depois da migration
  03, envolver a chamada de `rpc` em `try/catch` e, se o erro tiver o código PostgREST de
  "função não encontrada" (`PGRST202`) ou mensagem equivalente, mostrar
  "Recurso ainda não disponível" em vez de erro cru — mesmo espírito do `optionalRemoteTables`
  do adapter, só que para RPC (que o adapter não cobre hoje).
- Estados de erro do `process-document` (400/404/422/502) → mensagem inline no item da
  Caixa de Entrada, sem travar a lista inteira.

**`book-ingestion.js`**
- Ação "Processar como livro" num item da Caixa de Entrada com arquivo grande:
  1. Insere uma linha em `memoria.document_ingestion_runs` (via PostgREST direto,
     `owner_id` resolvido pela sessão + RLS) com `inbox_id`, `file_id`, `title`, `language`,
     `domain`, `subcategory`, `target_words` (default da tabela = 2200, editável no form).
  2. Divide `files.extracted_text` em seções (~`target_words` palavras cada, com um trecho
     final da seção anterior como `context_before`) e insere uma linha por seção em
     `document_sections` (`status='prepared'`). **Algoritmo de corte exato (por palavra,
     por parágrafo, por capítulo) é detalhe de implementação, não bloqueante** — MVP: corte
     simples por contagem de palavras, locator genérico (`"Seção N"`), pode refinar depois.
  3. Para cada seção `prepared`, chama `process-document-section({section_id})` — em série
     ou com um limite pequeno de paralelismo (ex. 2-3 simultâneas) para não estourar rate
     limit do Gemini; atualiza uma barra de progresso local (`processed_sections/total_sections`,
     já disponível no `document_ingestion_runs` — mas atualizado pela Edge Function, então
     ler via realtime/poll simples).
  4. Tela de revisão por seção: lista `document_sections` do run, mostra `analysis` de cada
     uma (`awaiting_review`), permite editar/marcar `included=false` (update direto via
     PostgREST — RLS por `owner_id` já protege).
  5. Botão "Finalizar livro" → `supabase.functions.invoke('consolidate-document-run', { body: { run_id, project_id } })`
     → sucesso: mostra os contadores e marca o `run` como concluído na UI; erro 422 (ex.
     "ainda existem seções sem análise") → mostra a mensagem e mantém a tela de revisão
     aberta apontando quais seções faltam.
- Guarda de indisponibilidade: `document_ingestion_runs`/`document_sections` já estão em
  `optionalRemoteTables` do `supabase-adapter.js` (dado confirmado) — reaproveitar a mesma
  flag de disponibilidade que o adapter já calcula, em vez de reimplementar a detecção.

**`memory-organization.js`**
- CRUD simples sobre `memory_organization_rules`/`_settings`/`_conflicts` via PostgREST
  direto (sem Edge Function — é puro dado, sem chamada a IA). Pode ser implementado e
  publicado assim que a migration 02 estiver aplicada, **independente das 4 Edge
  Functions**.
- Tela mínima: listar regras ativas/candidatas, formulário de criar/editar regra
  (`title, description, rule_type, scope, domain, status, priority`), formulário de
  `memory_organization_settings` (um registro por `owner_id`, `minimum_evidence`,
  `minimum_confidence`, `minimum_diverse_contexts`), lista de conflitos abertos com botão
  resolver/dispensar (`update status='resolved'|'dismissed'`).
- **Fora do escopo desta função (decisão de produto em aberto, não assumida aqui)**: o
  loop automático de "aprender regra a partir de feedback do usuário" (quando/como gravar
  `memory_organization_feedback` a partir de edições feitas nas telas de revisão de voz/
  documento, e quando promover uma regra `candidate`→`active`). O MVP desta fase entrega
  só CRUD manual das regras; o aprendizado automático fica como pendência explícita.
- Reativar o item de nav "Organização" no `index.html`/`navItems` (hoje removido).

#### 6. Ordem de execução e checkpoints de autorização

| # | Passo | Exige autorização explícita do usuário? |
|---|---|---|
| 1 | Aplicar `02_memory-organization.sql` no Supabase real | **Sim** |
| 2 | Aplicar `03_document-ingestion.sql` no Supabase real | **Sim** |
| 3 | Aplicar `04_long-document-ingestion.sql` no Supabase real | **Sim** |
| 4 | Rodar `99_verify-isolation.sql`, anexar resultado ao README do grupo de migrations | Não (é só leitura) |
| 5 | Configurar secret `GEMINI_API_KEY` em Edge Functions → Secrets no Supabase (distinto da env var do Skip, que só vira `VITE_*`) | **Sim** |
| 6 | Spike do MIME type de áudio (script local/curl contra a API do Gemini, sem tocar produção) | Não |
| 7 | Escrever `interpret-memory`, deploy no Supabase real | **Sim** (deploy) |
| 8 | Escrever `process-document`, deploy | **Sim** (deploy) |
| 9 | Escrever `process-document-section` + `consolidate-document-run`, deploy | **Sim** (deploy) |
| 10 | Escrever `document-ingestion.js`, `book-ingestion.js`, `memory-organization.js` | Não (código) |
| 11 | Reativar nav items/scripts no `index.html` do Skip | Não, mas avisar (reexpor UI escondida de propósito na fase 1) |
| 12 | Rodar QA pipeline do Skip (lint/build) no preview | Não |
| 13 | Teste manual golden-path de cada fluxo (voz, documento simples, livro) no preview | Não |
| 14 | `skip_project_publish` em produção (57204) | **Sim** |

Ordem sugerida dentro dos passos "não-autorização": fazer o spike do áudio (6) **antes**
de escrever `interpret-memory` de verdade, para não retrabalhar o contrato de resposta.

#### 7. Critérios de aceite (verificação manual — sem suíte de testes automatizada)

- `select proname from pg_proc where pronamespace='memoria'::regnamespace and proname in ('save_document_analysis','save_long_document_analysis')` retorna as 2 linhas.
- `99_verify-isolation.sql` roda limpo após as migrations 02-04 (RLS ativo em todas as tabelas novas, nada fora de `memoria`).
- Golden path voz: gravar frase curta no app publicado → `interpret-memory` responde 200 com transcrição reconhecível e campos estruturados coerentes → form de revisão populado → salvar → linha correspondente aparece no banco.
- Golden path documento simples: anexar PDF/texto curto → "Interpretar com IA" → análise retornada em tempo razoável (<60s) → revisar → salvar → `select` em `memoria.sources/knowledge_items/entities/relations` confirma linhas novas com `owner_id` certo e contadores retornados pela RPC > 0.
- Golden path livro: documento longo → seções criadas → cada seção processada fica `awaiting_review` com `analysis` preenchida → `consolidate-document-run` com todas as seções revisadas retorna sucesso, `document_ingestion_runs.status='approved'`.
- Sem `GEMINI_API_KEY` configurada, cada uma das 4 funções responde com JSON de erro claro (nunca 500 cru, nunca trava o navegador).
- RLS: um segundo usuário autenticado não lê/edita `document_ingestion_runs`/`document_sections`/`memory_organization_*` de outro `owner_id` (checagem manual com 2 contas, como `authenticated` — não `service_role`).
- `oxlint`/`oxfmt`/`tsc`/build do Skip (QA pipeline) verde após os 3 arquivos novos + nav items reativados.
- Nenhuma alteração em `public.*` (`git diff`/histórico de migrations confirma).
- `CHANGELOG.md`, `supabase/db/domains/memoria.md` e a própria SPEC-129 atualizados refletindo o estado real pós-implementação.

#### 8. Pontos explicitamente deixados em aberto (não decididos aqui)

- Formato exato do JSON esperado por `openVoiceReview` em `app.js` — confirmar por leitura direta do arquivo real no Skip antes de fechar o contrato de `interpret-memory`.
- Se o áudio original da memória por voz deve ser persistido no bucket `lucenera-memory-files` para proveniência, ou só a transcrição.
- Algoritmo exato de corte de seções do livro (por palavra/parágrafo/capítulo) e formato do `locator`.
- Loop automático de aprendizado de regras (`memory_organization_feedback` → promoção de regra `candidate`→`active`) — MVP entrega só CRUD manual.
- Modelo Gemini a padronizar entre as 4 funções (`gemini-1.5-flash` vs `gemini-2.0-flash` vs `gemini-3.6-flash`, já há inconsistência entre `chat-consulta` e `classificar_solicitacao` no repo).
- Se o MIME `audio/webm` for rejeitado pelo Gemini nos dois testes do spike, expandir escopo para transcodificação client-side é uma decisão de produto/esforço adicional, não assumida aqui.

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
