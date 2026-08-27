---
titulo: "SPEC-121 — Central de Solicitações (bugs e pedidos de alteração) com triagem por IA"
status: concluído
data_ultima_modificacao: 2026-08-26 (implementado e publicado)
sistemas_envolvidos:
  - Novo sistema — "Central de Solicitações" (11º sistema do ecossistema, slug `solicitacoes`)
  - Hub / Central (central-lucenera-dashboard-1c9ba) — cadastro em `public.systems`, aparece no grid e no SystemSwitcher
  - Todos os 10 sistemas existentes — ganham o novo sistema na lista do SystemSwitcher (nenhuma alteração de código neles além disso)
dependencias:
  - SPEC-006 (RPC hub_sistemas_permitidos)
  - SPEC-069 (RBAC — papeis/usuario_papeis/papel_permissoes/hub_pode_executar)
  - SPEC-120 (SystemSwitcher — o novo sistema entra na lista de todo mundo automaticamente, sem replicar componente novo)
---

# SPEC-121 — Central de Solicitações (bugs e pedidos de alteração) com triagem por IA

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Contexto

Com os 10 sistemas em uso real pela equipe, pedidos de bug/alteração chegam hoje de forma informal (WhatsApp, verbal) e viram SPEC manualmente, uma a uma, sem um lugar central pra ver o que já foi pedido, o que é crítico e o que é só preferência. Esta SPEC cria um sistema dedicado para registrar e triar esses pedidos, com uma IA classificando cada um como **estrutural** (o sistema não funciona corretamente sem isso) ou **pontual** (alteração que não muda a funcionalidade central).

## Decisões aprovadas (2026-08-26)

- **Quem registra pedidos:** toda a equipe (qualquer usuário autenticado do ecossistema), não só o admin.
- **Classificação por IA:** automática, em tempo real — uma Edge Function chama uma LLM (Anthropic Claude) assim que o pedido é criado e grava `classificacao_ia` + `justificativa_ia`. Requer `ANTHROPIC_API_KEY` como secret no projeto Supabase — **ação pendente do usuário**, ver Pendências. A classificação é só uma etiqueta informativa no board — **não dispara nenhuma outra ação sozinha** (não cria SPEC, não muda status, não notifica ninguém).
- **Escopo deliberadamente NÃO 100% automático (correção do usuário em 2026-08-26):** o objetivo central deste sistema é ser **um lugar pra reportar e estruturar visualmente** os pedidos — não um pipeline automatizado. Isso significa:
  - **Sem geração automática de SPEC.** A relação com `03-Projeto/Planos de Ação/SPECs/` é só manual: quando o usuário quiser transformar um pedido específico em SPEC, ele aponta pra esse pedido nesta conversa e eu (Claude Code) leio a descrição estruturada direto do banco e gero a SPEC — sem fluxo de "sincronização em lote", sem gatilho automático por classificação ou status.
  - **Sem etapa de aprovação obrigatória.** Não há um papel "admin_geral aprova antes de virar SPEC" — qualquer pedido, em qualquer status, pode virar SPEC quando o usuário decidir apontar pra ele.
  - O valor do sistema é o usuário (e a equipe) não precisar mais reexplicar o pedido em texto corrido toda vez — a descrição estruturada already registrada no board é suficiente pra eu entender o pedido quando for implementá-lo.

## Definição da SPEC

### Novo sistema

- Nome de referência: **Central de Solicitações**. Slug: `solicitacoes`.
- Stack idêntica aos outros 10 sistemas (Skip + React + Supabase compartilhado) — mesma base de auth, RBAC e SSO (`cross-system-auth.ts`, `SystemSwitcher.tsx`, `useSistemasPermitidos.ts` replicados como em todos os outros).
- Cadastro em `public.systems`: nova linha (`name`, `slug='solicitacoes'`, `link`, `icon_name`, `display_order`, `visivel_no_hub=true`). A partir disso, **nenhum dos 10 sistemas existentes precisa de alteração de código** — o `SystemSwitcher` de cada um já lista dinamicamente qualquer sistema novo que `hub_sistemas_permitidos` devolver.

### Modelo de dados (Supabase, schema `public`, novo)

```sql
create table public.solicitacoes (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id),
  titulo text not null,
  descricao text not null,
  sistema_relacionado_id uuid references public.systems(id), -- opcional: a qual sistema o pedido se refere
  tipo text not null check (tipo in ('bug', 'pedido_alteracao')),
  classificacao_ia text check (classificacao_ia in ('estrutural', 'pontual')), -- null enquanto pendente/falhou
  justificativa_ia text,
  confianca_ia numeric,
  status text not null default 'aberto'
    check (status in ('aberto', 'em_analise', 'aprovado', 'rejeitado', 'em_desenvolvimento', 'concluido')),
  spec_numero text, -- preenchido quando uma SPEC real é gerada a partir deste pedido
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
```

**RLS proposta:**
- `insert`: qualquer usuário autenticado, só com `usuario_id = auth.uid()`.
- `select`: qualquer usuário autenticado vê **todos** os pedidos (transparência — é o motivo de existir o "planner" central, não só uma caixa de sugestões pessoal).
- `update`: o próprio autor pode editar título/descrição enquanto `status = 'aberto'`; mudar `status`, `spec_numero` ou reclassificar manualmente exige `hub_pode_executar(auth.uid(), 'solicitacoes', null, 'aprovar')`.

### Classificação por IA

Nova Edge Function `classificar_solicitacao`:
1. Recebe `solicitacao_id`.
2. Busca título, descrição, tipo e nome do sistema relacionado (se houver).
3. Chama a API da Anthropic com um prompt fechado pedindo JSON estruturado: `{ classificacao: "estrutural" | "pontual", justificativa: string, confianca: number }`.
   - Critério de "estrutural" a passar no prompt: o sistema fica incorreto, trava, perde dado ou impede um fluxo de trabalho sem essa mudança.
   - Critério de "pontual": preferência visual, conveniência, ou ajuste que não muda o resultado funcional.
4. Grava o resultado em `solicitacoes` (`classificacao_ia`, `justificativa_ia`, `confianca_ia`).
5. Chamada disparada pelo frontend logo após o `insert` (sem trigger assíncrono no banco — mais simples, mesmo padrão de outras Edge Functions do ecossistema).

Falha da IA (API fora do ar, erro de parsing) não deve bloquear a criação do pedido — o pedido fica salvo com `classificacao_ia = null` e pode ser reclassificado manualmente ou reenviado.

### UI (páginas do novo sistema)

- **Novo Pedido** (`/novo`): tipo (bug / pedido de alteração), sistema relacionado (select opcional com os 10 sistemas existentes), título, descrição. Ao salvar, mostra "Classificando..." e depois o resultado da IA.
- **Painel / Planner** (`/`): lista de todos os pedidos, filtrável por status, classificação, tipo e sistema relacionado. Destaque visual claro para "estrutural" vs "pontual".
- **Detalhe do pedido** (`/pedido/:id`): mostra classificação + justificativa da IA; quem tem permissão de aprovar pode mudar status e marcar para virar SPEC.

### RBAC

- Todo papel existente (os 5 legados + os 7 do SPEC-069) ganha `criar` + `visualizar` no novo sistema `solicitacoes` — todo mundo pode abrir e ver pedidos, sem exceção.
- Só quem já tem o papel `admin_geral` (Pedro, Vinicius, Filippo hoje) ganha `aprovar` — controla mudança de status no board (organização, não é um gate de aprovação de trabalho). Gerar uma SPEC a partir de um pedido não depende de nenhum status específico nem desse papel — é sempre uma ação manual do usuário apontando pra um pedido nesta conversa.

## Critérios de aceite

- Qualquer usuário autenticado consegue abrir um pedido novo (bug ou alteração) e ver a classificação da IA aparecer em poucos segundos.
- Todo usuário autenticado vê a lista completa de pedidos já registrados (não só os próprios).
- Só admin_geral consegue mudar o status de um pedido ou marcá-lo para virar SPEC.
- O novo sistema aparece automaticamente no `SystemSwitcher` dos outros 10 sistemas, para quem tiver permissão — sem precisar editar nenhum dos 10 sistemas existentes.
- Quando o usuário apontar pra um pedido específico nesta conversa e pedir pra virar SPEC, a descrição estruturada já registrada é suficiente (sem precisar reexplicar o pedido em texto corrido) pra eu gerar um arquivo `SPEC-XXX_*.md` real no formato padrão já usado pelo projeto.

## Plano de rollback

- Sistema novo, isolado: reverter é remover o projeto Skip e a linha em `public.systems` — não afeta nenhum sistema existente.
- Tabela nova sem FK de saída de outras tabelas — `DROP TABLE solicitacoes` não quebra nada fora dela.
- Edge Function nova, isolada — remover não afeta outras functions.

## Realizado

### 2026-08-26

- Migration `20260826_124_spec121_central_solicitacoes` aplicada em produção: tabela `solicitacoes` + RLS + linha nova em `public.systems` (slug `solicitacoes`) + RBAC (todo papel ganhou criar/visualizar; `admin_geral` ganhou também aprovar).
- Sistema novo criado no Skip (id 53113, `https://central-de-solicitacoes-cc2ec.goskip.app`) — login, board (kanban por status: aberto/em análise/aprovado/em desenvolvimento/concluído/rejeitado) com filtros por classificação e tipo, formulário de novo pedido, detalhe do pedido, `SystemSwitcher`/`useSistemasPermitidos`/`cross-system-auth.ts` replicados no mesmo padrão dos outros 10 sistemas.
- Edge Function `classificar_solicitacao` criada e deployada (via `supabase functions deploy`, CLI autenticada com Personal Access Token — mesmo bloqueio de `.env` corrompido de outras rodadas contornado com mv temporário) — chama Gemini (`gemini-3.6-flash`, não `gemini-2.0-flash`: modelo antigo foi descontinuado durante a implementação) e grava `classificacao_ia`/`justificativa_ia`/`confianca_ia`.
- Testado ponta a ponta em produção: criar pedido → IA classifica em poucos segundos → aparece no board com o badge certo. Pedido de teste removido após validar.
- `CHANGELOG.md` atualizado.

## Pendências

- [x] IA definida como Gemini (`gemini-3.6-flash`), não Anthropic — `GEMINI_API_KEY` cadastrada como secret da Edge Function via `supabase secrets set`.
- [x] Nome/slug confirmados: "Central de Solicitações" / `solicitacoes`.
- [ ] Confirmar se pedidos podem ser anônimos/de fora da equipe (ex: cliente reportando bug) — hoje o escopo é só equipe interna autenticada.
- [ ] Achado durante a implementação, corrigido: conta `pedrollaghi@gmail.com` (viewer) nunca tinha sido migrada pra `usuario_papeis` — sem nenhum papel, `hub_pode_executar` negava acesso a QUALQUER sistema pra essa conta, não só este. Corrigido inserindo o papel `viewer` pra ela. Vale checar se há outras contas na mesma situação.
