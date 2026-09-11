---
titulo: "SPEC-130 — Sincronização em Duas Vias: Projetos do Sistema ⇄ Lista SharePoint 'Organização Projetos'"
status: pendente
data_ultima_modificacao: 2026-09-11
sistemas_envolvidos:
  - CRM (lucenera-crm, Skip projectId 24580)
  - Supabase (Edge Functions + migration + pg_cron)
  - SharePoint / Microsoft 365 (site LUCENERAPROJETOS345 — fora do ecossistema, coordenação com Alan)
---

# SPEC-130 — Sincronização em Duas Vias: Projetos do Sistema ⇄ Lista SharePoint "Organização Projetos"

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Relação com SPECs anteriores

- **SPEC-045 / SPEC-046** — primeira integração (só leitura do link da pasta do SharePoint para `projetos`).
- **SPEC-047** — desenho de um pull diário SharePoint → `projetos` (nunca implementado; a Edge Function `sync-sharepoint` atual mapeia colunas que não existem e nunca rodou com sucesso).
- **Esta SPEC-130 substitui e amplia a SPEC-047**: em vez de pull diário de mão única, faz sincronização **nas duas direções**, com o lado sistema → SharePoint em tempo quase real. A SPEC-047 passa a `status: concluído`/obsoleta apontando para cá quando esta for implementada.

## Checklist de Ação

> **Status em 2026-09-11**: migration **aplicada no Supabase real** e as 2 Edge Functions **deployadas**. **Push automático testado ao vivo com sucesso** (projeto "teste" 26.268 → item SharePoint `7152`, criado sozinho pela trigger, sem chamada manual). Pull ainda em validação (cron agendado, aguardando 1ª execução pós-fix). Ver "Realizado" pra detalhes, inclusive um ajuste feito depois do primeiro teste (header `Authorization` exigido pela plataforma do Supabase, corrigido na migration `011_ajuste_authorization_header.sql`).

- [ ] Item 1 — Migration (rascunho, **não aplicar** sem aprovação): colunas de controle em `projetos` (`sharepoint_item_id`, `sync_hash`, `last_synced_at`, `last_sync_source`, `last_synced_by`). **Rascunho pronto** (`001_colunas_controle_sync.sql`).
- [ ] Item 2 — Migration: tabela `sharepoint_sync_log` (auditoria de cada push/pull/conflito/erro, com quem alterou dos dois lados). **Rascunho pronto** (`002_tabelas_apoio_sync.sql` + RLS em `003_rls_tabelas_sync.sql`).
- [x] Item 3 — Migration: tabela `sharepoint_status_map`. **Seed parcial aplicado (2026-09-11, decisão do usuário)**: 3 valores que já batem exatamente (`Proposta Sinal`, `Elaboração Orçamento`, `Contrato de Projeto`). Resto da tabela ainda depende do Vinícius.
- [ ] Item 4 — Migration: RPC/sequence `gerar_codigo_projeto()` replicando o formato atual do código (ex. `AA.NNN` → `26.267`), tornando o **sistema a fonte única do código**. **Rascunho pronto** (`004_funcao_gerar_codigo_projeto.sql`), auto-corretiva contra `MAX(codigo)` real.
- [ ] Item 5 — Migration: trigger `AFTER INSERT OR UPDATE OF (colunas sincronizadas) ON projetos` que chama a Edge Function de push via `pg_net`. **Rascunho pronto, com desvio de design** (`006_trigger_push_sharepoint.sql` + `007_trigger_stamp_sync_meta.sql` + `008_rpc_confirmar_push_sharepoint.sql`): o anti-eco não usa mais comparação de hash como mecanismo de segurança — usa `last_sync_source`, mantido sempre correto por uma trigger BEFORE dedicada (ver "Realizado"). `sync_hash` virou só otimização. Também requer habilitar `pg_net`/`pg_cron` (`005_extensoes_pg_net_pg_cron.sql`) — **nenhum dos dois estava habilitado neste projeto**.
- [ ] Item 6 — Edge Function nova `sharepoint-projetos-push`. **Rascunho pronto** (`supabase/functions/sharepoint-projetos-push/index.ts`), não deployada.
- [ ] Item 7 — Edge Function nova `sharepoint-projetos-pull`, substituindo `sync-sharepoint`. **Rascunho pronto, não testado ao vivo** (`supabase/functions/sharepoint-projetos-pull/index.ts` + `009_rpc_aplicar_pull_sharepoint.sql`) — a paginação da query `delta` precisa de homologação real antes do cron valer (Item 11).
- [ ] Item 8 — Agendar a `sharepoint-projetos-pull` via `pg_cron`. **Rascunho pronto** (`010_cron_pull_sharepoint.sql`, intervalo de 5 min), inerte até os secrets do Vault existirem.
- [x] Item 9 — Script `scripts/backfill_sharepoint_projetos.py` escrito. Não usa Edge Function/pg_net (sem limite de 5s) — usa a mesma RPC `aplicar_pull_sharepoint` do pull incremental (sem lógica duplicada), pagina pelo `/items/delta` inteiro, e salva o `deltaLink` final em `sharepoint_sync_state` ao terminar (só quando roda sem `--limit`), habilitando o cron a virar incremental de verdade dali em diante. Suporta `--dry-run` e `--limit N`. Dry-run em amostra de 20 itens: sem erro, todos já casavam por código com projetos existentes (esperado — são os itens mais antigos da lista). Dry-run completo (3.781 itens) rodando.
- [ ] Item 10 — Atualizar `04-Sistemas/<crm>/supabase/AI_DB_CONTEXT.md`, `supabase/db/domains/crm.md` (e `hub_ti.md` se couber) e `CHANGELOG.md`.
- [x] Item 11 — Homologado ponta a ponta (2026-09-11): push automático (com anti-duplicação) e pull automático incremental confirmados funcionando ao vivo, cron reativado e limpo. Falta só confirmação humana de que a automação de pasta/Teams/Planner disparou nos itens de teste — não bloqueia o cron, é conferência.

### Passos manuais do usuário

- [ ] **Alan** — criar/elevar a permissão do app **`Sites.Selected` (application)** e conceder acesso **só ao site `LUCENERAPROJETOS345`**, role `write` (`POST /sites/{site-id}/permissions`). Dar **admin consent**. Decisão do usuário: **nada além da lista "Organização Projetos" pode ser alterado** — `Sites.ReadWrite.All` está descartado. Obs.: o Graph só concede acesso no nível de **site**, não de lista; a garantia "só essa planilha" é reforçada pelo código da Edge Function, que só chama esse `list-id`.
- [ ] **Alan** — confirmar que a automação existente (criação de pasta / Teams / Planner) dispara quando o item é criado por **app-only (service principal via Graph)**, e não só por criação manual/Power Automate com usuário.
- [ ] **Alan** — enviar os **nomes internos reais das colunas** da lista (`GET /sites/{site-id}/lists/{list-id}/columns`) e confirmar o `displayName` exato da lista (o código atual procura `"Organização Projetos"`; a mensagem do Alan citou `"Organização de Projetos"`).
- [ ] **Alan / Vinícius** — **desligar a geração de código no SharePoint** (coluna calculada / passo do fluxo) e definir a **data de virada** a partir da qual o código nasce só no sistema.
- [ ] **Vinícius** — preencher a tabela de de-para de status (`projeto_status` do CRM ⇄ valores de status da lista).
- [ ] **Vinícius / equipe** — comunicar às meninas a mudança de processo: criação de projeto passa a ser pelo sistema; definir quais campos elas ainda podem editar direto na lista.
- [ ] Confirmar que o secret `SHAREPOINT_CLIENT_SECRET` no Supabase está com o **Valor** do segredo e não com o **ID** dele (mesma pegadinha das SPEC-046/047) — e que é o da app **nova** ("Lucenera CRM"), não a antiga.
- [ ] **Rodar o `revisor`** (ou revisão equivalente) na migration `20260911_132_sharepoint_projetos_sync_2via/` e nas 2 Edge Functions antes de aplicar — mexe em extensão de banco (`pg_net`/`pg_cron`, nunca habilitadas neste projeto) e em RPCs `security definer`.
- [ ] Aplicar a migration no Supabase real (depois de revisada).
- [ ] Gerar um segredo aleatório e configurar como `SHAREPOINT_SYNC_SECRET` nos secrets das 2 Edge Functions **e** no Vault (`select vault.create_secret('<segredo>', 'sharepoint_sync_secret');`) — precisa ser o mesmo valor nos dois lugares.
- [ ] Depois de deployar as 2 functions, criar no Vault: `sharepoint_push_url` (URL da `sharepoint-projetos-push`) e `sharepoint_pull_url` (URL da `sharepoint-projetos-pull`) — sem isso as triggers/cron ficam inertes (por design).
- [ ] Deploy das 2 Edge Functions (`sharepoint-projetos-push`, `sharepoint-projetos-pull`).
- [ ] Rodar o Item 9 (script de backfill) antes de deixar o cron do pull ligado de verdade.

## Objetivo

Hoje o cadastro de projeto é feito em dois lugares (sistema/CRM e lista "Organização Projetos" do SharePoint), em trabalho duplicado manual. Esta SPEC liga os dois: **qualquer criação ou edição de projeto em um lado reflete no outro automaticamente**, com auditoria de quem alterou, sem loop de eco e sem sobrescrita silenciosa. O `POST` de criação de item no SharePoint continua sendo o gatilho das automações de pasta/Teams/Planner que já existem lá.

## Decisões aprovadas

- **Direção: duas vias (opção C).** Sistema → SharePoint em tempo quase real (trigger no banco → Edge Function). SharePoint → sistema por varredura `delta` no `pg_cron` (proposto: 5 min). Webhook do Graph fica como evolução v2 (assinaturas de lista expiram rápido e exigem cron de renovação).
- **Código do projeto: fonte única no sistema.** O SharePoint para de gerar. RPC/sequence no banco replica o formato atual. Precisa de data de virada.
- **Criar projeto: permitido nos dois lados.** Cada linha de `projetos` guarda o `sharepoint_item_id` que amarra o par.
- **Exclusão nunca propaga.** Só o flag `arquivado` sincroniza (nos dois sentidos).
- **Anti-eco:** cada projeto guarda `sync_hash` + `last_sync_source` + `last_synced_at`. Uma alteração cujo hash é igual ao último que aquele lado gravou é ignorada.
- **Conflito (mesmo projeto editado nos dois lados entre um sync e outro):** ~~*last-write-wins* no **item inteiro**~~ — **substituído em 2026-09-11** (decisão do usuário, temporária): nesta fase, **SharePoint é tratado como fonte de verdade** para tudo que é sincronizado; o pull sempre aplica o que vier de lá, sem checagem de conflito. Motivo: a detecção original comparava `updated_at` (tocado por qualquer sistema, não só por edição relevante), que o revisor já tinha marcado como frágil, e simplifica o combate à duplicação do push (ver "Realizado"). **Duas vias com conflito de verdade voltam numa fase futura**, quando push e pull rodarem simultâneos de forma madura.
- **Log de quem alterou:** no lado sistema, gravar o usuário do CRM (`last_synced_by` / `changed_by_usuario_id`). No lado SharePoint, gravar o `lastModifiedBy` que o Graph retorna no item.
- **Status:** sincroniza pelos dois lados **via tabela de de-para**. Valor fora da tabela não sincroniza e vai para o log.
- **Arquiteto / responsável de obra:** sistema → SharePoint escreve o nome. SharePoint → sistema só vincula quando o nome **bate exato** com um registro de `contatos`; senão deixa em branco e loga (nunca fuzzy match, para não vincular na pessoa errada).
- **Escopo de acesso mínimo (decisão do usuário):** a integração só pode ler/escrever a lista **"Organização Projetos"** no site `LUCENERAPROJETOS345`. Nenhuma outra lista, site, biblioteca ou coluna fora do mapa de campos. Permissão via `Sites.Selected` (nunca `Sites.ReadWrite.All`); a Edge Function tem um único `list-id` fixo e recusa qualquer outro alvo.
- **Implementar agora tudo que dá para assumir como padrão** (itens acima); o que depende de terceiro fica em "Pendências".

## Definição da SPEC

### 1. Estado atual (verificado)

- **Tabela `projetos`** (colunas reais relevantes): `id`, `codigo varchar(50) NOT NULL`, `nome`, `nivel_estrategico` (enum `projeto_nivel`), `status` (enum `projeto_status`, default `'Estudo Inicial'`), `cidade`, `estado varchar(2)`, `data_entrada date`, `arquivado bool`, `arquiteto_id`, `responsavel_obra_id`, `responsavel_nome text`, `"Nome Arquiteto" text`, `codigo_legado int`, `updated_at`, `created_by`.
- **SharePoint:** site `lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345`; lista alvo resolvida hoje como `"Organização Projetos"`. Colunas conhecidas por leitura via Graph (SPEC-047, 2026-07-24): `field_0` = código (`26.211`), `Title` = nome, `field_9` = responsável, `field_4` = cidade, `N_x00ed_velEstrat_x00e9_gico` = nível (`"Nível 4"`), `Arquivado` = bool, `field_6` = data, `EstadoLookupId` = estado (lookup, id e não texto), `field_10` = status (`"Contrato de Projeto"`), `field_2` = arquiteto (texto), `Respons_x00e1_veldaObra` = responsável de obra (texto).
- **Edge Function `sync-sharepoint`:** pull de mão única, protegida por usuário admin; monta payload com colunas inexistentes (`responsavel`, `prazo`, `valor`, `observacoes`) — nunca rodou com sucesso. **Será substituída** pela `sharepoint-projetos-pull`.
- **Secrets já existentes no Supabase:** `SHAREPOINT_TENANT_ID`, `SHAREPOINT_CLIENT_ID`, `SHAREPOINT_CLIENT_SECRET` (validar o valor do secret — ver passos manuais).

### 2. Endpoints Microsoft Graph (conforme repassado pelo Alan)

| Passo | Chamada |
|---|---|
| Token | `POST https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token` — body x-www-form-urlencoded: `client_id`, `client_secret`, `scope=https://graph.microsoft.com/.default`, `grant_type=client_credentials` |
| Site | `GET https://graph.microsoft.com/v1.0/sites/lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345` |
| Lista | `GET https://graph.microsoft.com/v1.0/sites/{site-id}/lists?$filter=displayName eq 'Organização Projetos'` |
| Criar item | `POST https://graph.microsoft.com/v1.0/sites/{site-id}/lists/{list-id}/items` — body `{ "fields": { ... } }` → **201 Created** (dispara as automações do SharePoint) |
| Atualizar item | `PATCH https://graph.microsoft.com/v1.0/sites/{site-id}/lists/{list-id}/items/{item-id}/fields` |
| Ler mudanças | `GET https://graph.microsoft.com/v1.0/sites/{site-id}/lists/{list-id}/items/delta` (guardar o `@odata.deltaLink` entre execuções) |

Permissão hoje: `Sites.Read.All` (só leitura). Necessário: `Sites.Selected` (application) + concessão de escrita **só** ao site `LUCENERAPROJETOS345` + admin consent. `Sites.ReadWrite.All` está descartado por decisão do usuário (não pode dar acesso ao tenant inteiro).

### 3. Mapa de campos (v1)

Direção: **⇄** = duas vias; **→SP** = só sistema para SharePoint; **→SIS** = só SharePoint para sistema.

| `projetos` | Coluna na lista | Direção | Regra / transformação |
|---|---|---|---|
| `codigo` | `field_0` (Codigo) | ⇄ na criação; depois imutável | Gerado pelo sistema. Em item criado na lista sem código, o sistema gera e faz `PATCH` de volta. |
| `nome` | `Title` | ⇄ | *last-write-wins* de item |
| `responsavel_nome` | `field_9` | ⇄ | texto dos dois lados, seguro |
| `cidade` | `field_4` | ⇄ | *last-write-wins* de item |
| `arquivado` | `Arquivado` | ⇄ | substitui "exclusão"; *last-write-wins* de item |
| `data_entrada` | `field_6` (display: "Data Entrada") | ⇄ | Confirmado: preenchido automaticamente na criação — é mesmo a data de entrada do projeto, não um campo alheio (revisão da ressalva anterior) |
| `nivel_estrategico` | `N_x00ed_velEstrat_x00e9_gico` | ⇄ | transformar `"Nível N"` ⇄ enum `projeto_nivel` (confirmar valores do enum) |
| `status` | `field_10` | ⇄ | via `sharepoint_status_map`; valor fora do mapa não sincroniza + loga |
| `arquiteto_id` / `"Nome Arquiteto"` | `field_2` | →SP nome; →SIS só match exato em `contatos` | sem fuzzy; sem match → branco + log |
| `responsavel_obra_id` | `Respons_x00e1_veldaObra` | →SP nome; →SIS só match exato em `usuarios` | **correção 2026-09-11**: a FK real (`projetos_responsavel_obra_id_fkey`) aponta pra `public.usuarios`, não `contatos` como o texto original desta linha dizia — sem fuzzy; sem match → branco + log |
| `estado` | `EstadoLookupId` | ⇄ | **implementado 2026-09-11** (era v2/fora de escopo, virou prioridade — achado que a automação de criação de grupo provavelmente exige) — via `sharepoint_estado_map`, lista "Estados" (`946a5bd0-0e6e-4da2-9cce-3e1067a4bf47`) |
| `link_sharepoint` (confirmar coluna) | **em aberto** | →SIS | Ver "Achados 2026-09-11" — a coluna "Caminho" da lista **não é** o link por projeto (é o mesmo valor pra todo item, é o path da lista). Onde mora o link real da pasta ainda não está identificado; **pendência nova**. |

### 3.1 Achados de 2026-09-11 (amostra real de 3 linhas + teste de conectividade)

- **Convenção de vazio**: campos texto sem valor (ex. Arquiteto Responsável, Responsável da Obra) vêm como o caractere literal **`.`**, não string vazia nem `null`. As transformações de push/pull precisam tratar `.` ⇄ vazio/`NULL` nos dois sentidos.
- **`Estado` vem com espaço à esquerda** (`" SP"`) — aplicar `trim()` na leitura.
- **Formato do código confirmado**: `AA.NNN` (ex. `26.267`, `26.266`, `26.265`), bate com o design da RPC `gerar_codigo_projeto()`.
- **"Tipo de Item"** não é campo de negócio — é o Content Type padrão do SharePoint (`fields.ContentType.name`, sempre `"Item"` nesta lista). Não entra no mapa de sincronização.
- **Lista confirmada como a correta, sem ambiguidade**: o `ListId` (`7F7672F7-55FE-472F-9428-9DF6223D9AFA`) e o `ContentTypeId` do link de "criar projeto" que a equipe usa manualmente batem exatamente com os que a function de teste recebeu ao gravar o item `7151`. URL da lista: `https://lucenera.sharepoint.com/sites/LUCENERAPROJETOS345/Lists/Organizao%20Projetos/AllItems.aspx` (nome interno da URL é "Organizao Projetos", sem acento — coerente com o `displayName` "Organização Projetos" com acento).
- **"Caminho" não é o link da pasta do projeto** — apareceu com o **mesmo valor em 3 projetos diferentes** (`sites/LUCENERAPROJETOS345/Lists/Organizao Projetos`), batendo com o `webUrl` da lista em si (confirmado no teste de conectividade). É campo de sistema, igual pra todo item. **Onde mora o link real da pasta por projeto (o que a SPEC-046 lia) ainda não foi identificado nesta lista** — pendência nova, perguntar ao Alan se existe em outra lista/biblioteca ou se essa informação não está mais disponível por aqui.

### 4. Alterações no banco (migration — rascunho)

Pasta proposta: `supabase/db/migrations/20260911_132_sharepoint_projetos_sync_2via/`

- `ALTER TABLE projetos ADD COLUMN sharepoint_item_id text` (único quando não nulo)
- `ADD COLUMN sync_hash text` — hash do conjunto de campos sincronizados na última gravação
- `ADD COLUMN last_synced_at timestamptz`
- `ADD COLUMN last_sync_source text CHECK (last_sync_source IN ('sistema','sharepoint'))`
- `ADD COLUMN last_synced_by uuid` (FK `usuarios`, nulo quando a origem foi o SharePoint)
- `CREATE TABLE sharepoint_sync_log (id, created_at, projeto_id, sharepoint_item_id, direction text CHECK (direction IN ('push','pull')), action text CHECK (action IN ('create','update','skip','conflict','error')), source text, changed_by_usuario_id uuid, changed_by_sharepoint text, campos_alterados jsonb, payload_hash text, resultado text, erro text)`
- `CREATE TABLE sharepoint_status_map (projeto_status public.projeto_status PRIMARY KEY, sharepoint_valor text NOT NULL)` — **sem seed**
- `CREATE TABLE sharepoint_sync_state (chave text PRIMARY KEY, valor text)` — guarda o `deltaLink` e o cache de `site-id`/`list-id`
- `CREATE FUNCTION gerar_codigo_projeto() RETURNS varchar` — replica o formato atual (confirmar: `AA.NNN`, sequência anual); usar como `DEFAULT` ou chamada explícita no fluxo de criação do CRM
- Trigger `trg_projetos_sharepoint_push AFTER INSERT OR UPDATE OF nome, codigo, responsavel_nome, cidade, arquivado, data_entrada, nivel_estrategico, status, arquiteto_id, responsavel_obra_id ON projetos` → `pg_net` `POST` para a Edge Function `sharepoint-projetos-push` com header `x-sync-secret`. Guarda de anti-eco: se `NEW.last_sync_source = 'sharepoint'` e `NEW.sync_hash` = hash calculado agora, **não dispara**.

Impacto: só `projetos` (colunas novas) + 4 tabelas novas de apoio. Sem mudança destrutiva.

### 5. Fluxo push (sistema → SharePoint)

1. Trigger dispara a Edge Function com o `projeto_id`.
2. Função carrega o projeto, calcula `sync_hash` dos campos do mapa; se igual ao `sync_hash` atual e `last_sync_source='sharepoint'`, sai (eco).
3. Token Graph (cacheado em memória até expirar) → `site-id`/`list-id` (cacheados em `sharepoint_sync_state`).
4. Sem `sharepoint_item_id` → `POST` cria item; grava `sharepoint_item_id` do retorno. Com `sharepoint_item_id` → `PATCH .../items/{id}/fields`.
5. Atualiza `sync_hash`, `last_synced_at=now()`, `last_sync_source='sistema'`, `last_synced_by=<usuário do CRM>`.
6. Grava `sharepoint_sync_log` (`direction='push'`, `action`, `campos_alterados`, `changed_by_usuario_id`).
7. Erro do Graph → log `action='error'` + reenfileira (retry com backoff); o projeto nunca fica sem tentativa de ir para a lista.

### 6. Fluxo pull (SharePoint → sistema)

1. `pg_cron` (5 min) chama a Edge Function `sharepoint-projetos-pull`.
2. Token Graph → `GET .../items/delta` a partir do `deltaLink` salvo; paginação até o novo `deltaLink`; persiste.
3. Para cada item alterado:
   - casa por `sharepoint_item_id`; fallback por `codigo`.
   - calcula hash dos campos do mapa; se igual ao `sync_hash` do projeto → `action='skip'` (eco do próprio push).
   - se `item.lastModifiedDateTime` > `projetos.updated_at` → aplica (com transformações e regras de arquiteto/status). Caso contrário e houver divergência real → `action='conflict'` no log com os dois valores, **sistema mantém o seu**.
   - item sem correspondente e com dados válidos → cria projeto novo (gera código se faltar e faz `PATCH` de volta).
4. Atualiza `sync_hash`, `last_synced_at`, `last_sync_source='sharepoint'`, `last_synced_by=NULL`; grava log com `changed_by_sharepoint = item.lastModifiedBy`.

### 7. Regras de permissão

- Edge Functions rodam com Service Role + header de segredo compartilhado (`x-sync-secret`) validado na entrada — não dependem de usuário logado (disparo por trigger e por cron).
- Sem botão novo na UI. A criação/edição normal de projeto no CRM já é o gatilho.
- App do Graph: `Sites.Selected` com escrita concedida **só** ao site `LUCENERAPROJETOS345`. A Edge Function guarda um único `list-id` (o da "Organização Projetos") e recusa qualquer outro alvo — não cria/altera outras listas, sites ou colunas fora do mapa.

### 8. Backfill e virada

1. Rodar o script de backfill em dry-run: relatório de quantos projetos casam por `codigo` com itens da lista, quantos ficam órfãos de cada lado.
2. Preencher `sharepoint_item_id` + `sync_hash` inicial nos casados (sem disparar push/pull).
3. Tratar órfãos manualmente com o Vinícius (projeto que só existe num lado).
4. Congelar edições nos dois lados por uma janela curta, ligar o push, ligar o cron do pull, homologar com 1 projeto de teste.
5. Só então comunicar liberado para as meninas.

### 9. Critérios de aceite

- Criar projeto no CRM → item aparece na lista em segundos, com código gerado pelo sistema, e a automação de pasta/Teams dispara.
- Editar `nome`/`cidade`/`responsável` na lista → volta pro CRM em até 1 ciclo do cron, sem duplicar.
- Arquivar num lado → arquiva no outro; nada é excluído de fato.
- Editar o mesmo projeto nos dois lados na mesma janela → um lado ganha, o outro fica registrado em `sharepoint_sync_log` como `conflict`.
- Nenhum loop: um push não gera um pull que gera outro push (verificável pelo `sharepoint_sync_log` — sequência `push` → `skip`).
- Status com valor fora do de-para → não sincroniza, aparece no log.
- Arquiteto sem match exato em `contatos` → campo fica em branco no CRM, com log.

### 10. Rollback

- Desativar o `pg_cron` do pull e desabilitar o trigger de push (`ALTER TABLE projetos DISABLE TRIGGER trg_projetos_sharepoint_push`).
- As colunas de controle e tabelas de log podem ficar (inertes). `down.sql` remove tudo se necessário.
- Sem o sync, os dois lados voltam ao cadastro manual atual — nenhum dado é perdido.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `projetos` (leitura e escrita das colunas do mapa + colunas novas de controle) e `contatos` (match de arquiteto/responsável de obra por nome exato). `usuarios` para `last_synced_by`.
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Principalmente o **CRM** (onde o projeto é criado/editado). Projetos criados/atualizados pelo sync aparecem normalmente para Orçamentos/Financeiro/Logística que leem `projetos` — mesmo contrato de sempre, sem mudança de API.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** O objetivo é justamente eliminar a duplicação manual sistema ⇄ SharePoint. As colunas novas são controle de sincronização, não duplicação de negócio.
- **Existe migration antiga que contradiz o snapshot central?** Verificar a existência real da coluna `projetos.link_sharepoint` (migration `20260724_061_link_sharepoint_projeto`) — o dump de schema consultado não a listou; confirmar antes de mapear `LinkPasta`.
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim — registrar as 2 Edge Functions novas, o cron, as colunas/tabelas de controle e o mapa de campos v1; e marcar a `sync-sharepoint` antiga como substituída.

## Realizado

Nenhuma implementação do pipeline definitivo ainda. Esta SPEC registra o desenho aprovado em conversa de 2026-09-10 (direção duas vias, código como fonte única no sistema, log de quem alterou dos dois lados, conflito por *last-write-wins* de item com registro, arquiteto/status com regra conservadora).

### 2026-09-11

- Validado, via a SPEC-131 (function temporária `sharepoint-teste-conexao`), que a app "Lucenera CRM" com `Sites.Selected` grava de verdade na lista "Organização Projetos" (item de teste `7151`, 201 Created). Confirma `field_9` = responsável/vendedor. Achado: `field_6` parece ser automático (data/hora de criação), não um dado de usuário — corrige a suposição da SPEC-047 sobre `data_entrada`.
- Fechado o mapa de campos de negócio por amostra real de 3 linhas + confirmação de que o `ListId`/`ContentTypeId` do formulário de criação manual batem com os da function de teste (ver achados acima na seção 3).
- **Escrito o rascunho completo da migration** `supabase/db/migrations/20260911_132_sharepoint_projetos_sync_2via/` (10 arquivos: colunas de controle, tabelas de apoio, RLS, `gerar_codigo_projeto()`, extensões `pg_net`/`pg_cron`, trigger de push, trigger de stamping, RPCs `confirmar_push_sharepoint`/`aplicar_pull_sharepoint`, cron do pull) e as **2 Edge Functions definitivas** (`supabase/functions/sharepoint-projetos-push/index.ts`, `supabase/functions/sharepoint-projetos-pull/index.ts`). **Nada aplicado nem deployado.**
- **Descoberta que forçou mudar o design do anti-eco**: `pg_net` e `pg_cron` não estavam habilitados neste projeto (conferido direto no banco: `pg_available_extensions`), e a comparação por hash entre PL/pgSQL e Deno (linguagens diferentes, serialização diferente) seria frágil pra decidir loop. Trocado por um mecanismo mais simples e robusto: uma trigger BEFORE (`trg_projetos_stamp_sync_meta`) garante que `last_sync_source` está sempre correto em toda escrita normal (marca 'sistema' + `auth.uid()`), e só a RPC de pull (`aplicar_pull_sharepoint`, via flag de sessão `app.sync_em_andamento`) consegue gravar 'sharepoint' de verdade. A trigger de push só olha `NEW.last_sync_source` — sem hash no caminho crítico. `sync_hash` continua existindo, mas só como otimização (evita reenvio à toa) e auditoria, não como mecanismo de segurança.
- **Correção de schema**: `responsavel_obra_id` referencia `public.usuarios`, não `contatos` (a FK real é `projetos_responsavel_obra_id_fkey → usuarios`) — o texto original desta SPEC estava errado nisso; corrigido no mapa de campos e no código.
- **Segredos**: URL das 2 functions e o segredo compartilhado (`x-sync-secret`) ficam no Supabase Vault (`supabase_vault`, já habilitado), nunca hardcoded em `.sql` versionado — as triggers/cron ficam inertes até alguém criar esses secrets manualmente (ver "Passos manuais").
- **Push testado ao vivo com sucesso, automático, sem chamada manual**: editei o projeto "teste" (`26.268`, responsável Mariane) no banco real → a trigger disparou sozinha → item `7152` criado na lista SharePoint → `sharepoint_sync_log` registrou `action=create, resultado=ok`. Antes disso, corrigido um problema real: a plataforma do Supabase exige header `Authorization` (JWT) em toda Edge Function por padrão, além da nossa própria autenticação (`x-sync-secret`) — a trigger não mandava esse header, `pg_net` recebia `401 Missing authorization header` (visível em `net._http_response`). Fix aplicado (`011_ajuste_authorization_header.sql`): manda `Authorization: Bearer <anon key>` também — o anon key não é segredo, só satisfaz a checagem da plataforma; quem protege de verdade continua sendo o `x-sync-secret`. Anon key guardado no Vault (`supabase_anon_key`).
- **Revisão (`revisor`) rodada e corrigida no mesmo dia** — relatório em `03-Projeto/Auditoria/2026-09-11_auditoria_spec130_sharepoint_projetos_sync.md`. 2 achados 🔴 corrigidos e reployados:
  - **Duplicação no push**: antes de criar item novo, agora busca por `codigo` na lista primeiro (não se repete) — protege contra duplicar quando uma tentativa anterior gravou no Graph mas falhou antes de confirmar no banco. **Testado ao vivo**: zerei o `sharepoint_item_id` do projeto "teste" de propósito (simulando a falha) e editei de novo — reencontrou o item `7152` (não criou um `7153`).
  - **Filtro do pull com risco de injeção**: trocado o `.or()` com string concatenada por duas consultas `.eq()` parametrizadas separadas.
  - Achado 🟡 do `GRANT` de `disparar_pull_sharepoint()` também corrigido (`012_fix_grant_disparar_pull.sql`).
- **Decisão do usuário (2026-09-11, resolve a duplicação de outro ângulo + simplifica)**: **SharePoint passa a ser tratado como fonte de verdade nesta fase**, para todos os campos sincronizados — o pull não segura mais por "o sistema editou depois" (removida a lógica de conflito por `updated_at`, que o revisor já tinha marcado como frágil). Só pula quando o conteúdo já está idêntico. Usuário confirmou: **é temporário** — a detecção de conflito de verdade (duas vias simultâneas) volta numa fase futura.
- **Backfill rodado com sucesso (2026-09-11)**: `scripts/backfill_sharepoint_projetos.py` processou os 3.975 itens da lista via `/items/delta` (fora do limite de 5s do `pg_net`, usando a mesma RPC do pull incremental). Resultado: **306 projetos criados, 3.669 atualizados, 0 erros**. A faixa que faltava (`26.181`–`26.267`) foi de 1 para 85 projetos no banco. `projetos` foi de 3.781 para 4.087. `deltaLink` inicial salvo em `sharepoint_sync_state`. Um run anterior foi morto pelo SO por pouca memória aos ~2.311 itens (sem dano — RPC é idempotente); o script ganhou reconexão automática de banco depois que a 1ª tentativa de dry-run caiu no meio por causa de "server closed the connection".
- **Cron do pull reativado e confirmado funcionando incremental**: depois do backfill, `cron.alter_job(active => true)`. Descoberta extra: mesmo o pull incremental (0 itens a processar) estourava os mesmos 5s do `pg_net` — o trabalho de fundo da function (token do Graph, carregar contatos/usuários) já consome perto disso. Corrigido aumentando `timeout_milliseconds` (`013_aumentar_timeout_pg_net.sql`: 20s no push, 60s no pull — seguro, `pg_net` é assíncrono, não trava nada). **Confirmado ao vivo**: tick seguinte do cron voltou `200, processados:0, timed_out:false`.
- **Bug real achado pelo usuário e corrigido**: `data_entrada` (field_6) ficava sempre em branco depois de qualquer sincronização — a SPEC já tinha sido corrigida confirmando que o campo é a data de entrada real (não automático), mas o código do pull/backfill ficou desatualizado mandando `NULL` sempre. Corrigido em `sharepoint-projetos-pull/index.ts` e `backfill_sharepoint_projetos.py`; reprocessado tudo — **4.087 de 4.087 projetos com Data Entrada preenchida**, valores conferidos batendo com a amostra real.
- **Status parcialmente semeado (decisão do usuário)**: `sharepoint_status_map` recebeu os 3 valores que já batiam exatamente entre o SharePoint e o enum (`Proposta Sinal`, `Elaboração Orçamento`, `Contrato de Projeto`) — o restante continua em branco até o Vinícius fechar o de-para completo. Reprocessado: 602 + 211 + 11 projetos passaram a ter esses status sincronizados, sem alterar nenhum status pré-existente de outras origens (`Obra Finalizada`, `Não Fechou` etc. — protegidos pelo `COALESCE` da RPC).
- **Achado do usuário sobre a automação não disparar**: nenhum dos 3 primeiros testes (`7151`/`7152`/`7154`) tinha o Estado preenchido — a lista mostra "Informações necessárias" pra campo obrigatório vazio, sinal forte de que a automação de criação de grupo exige isso. A teoria de "nome do responsável muito longo" foi descartada com evidência (o teste com nome curto "Mariane" também não criou grupo).
- **Implementado Estado (lookup)**: achada a lista "Estados" no site (28 itens: 27 UF + DF + 1 extra), mapa `sharepoint_estado_map` criado e semeado com os IDs reais (migration `014`). RPC `aplicar_pull_sharepoint` ganhou o parâmetro `p_estado` (`015`, precisou DROP+CREATE por mudar assinatura). Push e pull atualizados pra resolver `EstadoLookupId` nos dois sentidos. Trigger de push atualizada pra disparar também quando só `estado` muda (`016`).
- **Teste completo (código `26.286`, item `7157`)**: projeto criado com nível, status mapeado ("Proposta Sinal") e estado ("SP") todos preenchidos — push gravou sem erro, conferido via Graph: `field_10="Proposta Sinal"`, `EstadoLookupId=1` (SP), `Nível 2`. Primeiro teste com informação completa — aguardando confirmação humana se o grupo/pasta foi criado desta vez.
- **Item 11 (homologação ponta a ponta) considerado atendido tecnicamente**: push testado com sucesso (incl. anti-duplicação), pull testado com sucesso (backfill completo + incremental limpo). Falta só a confirmação humana da automação de pasta/Teams nos itens de teste (pendência separada).
- **Pull: achado crítico de escala, cron PAUSADO.** (nota histórica — já reativado, ver acima) A lista "Organização Projetos" tem **3.781 itens** (`public.projetos` também, contagem real). A primeira execução do pull (sem `deltaLink` salvo ainda) precisa varrer a lista inteira — excedeu o timeout padrão do `pg_net` (5000ms, `net._http_response.timed_out = true`). Rodar isso a cada 5 min sem `deltaLink` estabelecido seria uma varredura completa repetida, pesada pro Graph e pro banco. **Pausei o cron** (`select cron.alter_job(job_id => 1, active => false);`) até o Item 9 (script de backfill) existir e rodar uma vez de forma controlada, estabelecendo o `deltaLink` inicial antes de reativar. Ver Pendências.

## Pendências

- [x] Elevação da permissão do app para `Sites.Selected` (escrita no site) + admin consent — concluído por Alan (SPEC-131, 2026-09-11), testado com sucesso.
- [x] Nomes internos das colunas de negócio — obtidos por amostra real em 2026-09-11 (ver tabela da seção 3) para Codigo/Nível/Projeto/Responsável/Data Entrada/Status/Arquiteto/Responsável da Obra/Cidade/Estado/Arquivado. Falta só a confirmação formal do Alan via `GET /lists/{id}/columns` (não bloqueia mais a implementação, é conferência).
- [x] Formato do código confirmado por amostra real: `AA.NNN` (ex. `26.267`).
- [ ] **Nova pendência (2026-09-11)**: onde mora o link da pasta por projeto (usado pela SPEC-046) — a coluna "Caminho" da lista **não é isso** (é um path de sistema, igual em todo item). Depende do Alan.
- [x] `displayName`/lista corretos confirmados sem ambiguidade — `ListId` e `ContentTypeId` do formulário real de criação batem exatamente com os da function de teste (2026-09-11).
- [ ] Completar a tabela `sharepoint_status_map` (3 de N valores já semeados — ver "Realizado"). Depende do Vinícius.
- [ ] Confirmar que a automação de pasta/Teams/Planner dispara em item criado por app-only (service principal) — ainda não verificado para o item de teste `7151` (SPEC-131).
- [ ] **Data de virada** em que o SharePoint para de gerar código. Depende do Alan/Vinícius.
- [ ] Valores do enum `projeto_nivel` e estabilidade do texto `"Nível N"` na lista, para a transformação de `nivel_estrategico`.
- [x] `estado` (lookup `EstadoLookupId`) — implementado 2026-09-11, ver "Realizado".
- [ ] Confirmar com o Alan/usuário se o grupo/pasta foi criado no teste `26.286`/item `7157` (1º teste com Nível+Status+Estado todos preenchidos).
- [ ] Expandir `sharepoint_status_map` além dos 3 valores já semeados — hoje qualquer status fora do mapa (a maioria) ainda não é enviado no push, o que pode continuar bloqueando a automação em projetos com outro status.
- [ ] Convenção de campo vazio = caractere literal `.` (não string vazia) — implementar transformação nos dois sentidos.
- [ ] Decisão delta-poll (v1, proposto 5 min) vs webhook do Graph (v2, com cron de renovação de assinatura).
- [ ] **Rotacionar o client secret da app "Lucenera CRM"** — exposto por engano num comando de diagnóstico em 2026-09-11 (ver SPEC-131), tratado como comprometido.
- [ ] Definir com a equipe quais campos as meninas ainda podem editar direto na lista após a virada.
