---
titulo: "SPEC-043 — Otimização de Performance do CRM"
status: pendente
data_ultima_modificacao: 2026-07-23
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-043 — Otimização de Performance do CRM

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** (repositório `pedrolalala/lucenera-crm`) não estava carregado como submodule em `04-Sistemas/` no momento do diagnóstico — mesma situação já registrada na SPEC-042. Em 2026-07-23, o usuário aprovou e o submodule foi registrado em `04-Sistemas/lucenera-crm-3bd29 (1)/` (`git submodule add -f`), apontando para `heads/main` do GitHub (commit `9078947`).

**Defasagem conhecida:** esse commit do GitHub `main` é **anterior** às mudanças da SPEC-042 (formulário completo de cliente, edição de vínculos no Sheet de Projeto) e a qualquer mudança desta SPEC-043 — todas existem apenas na versão publicada no Skip (projeto "Lucenera CRM", `projectId 24580`, versão `0.0.273`, hash `16f6c06`), porque o push Skip→GitHub nunca foi confirmado (não há ferramenta de sincronização Skip→GitHub via MCP). Ou seja: o diagnóstico desta SPEC foi feito lendo o código-fonte real via MCP Skip, que continua sendo a fonte hospedada/publicada em produção (`https://lucenera-crm-3bd29.goskip.app`) — **não confiar no conteúdo local do submodule até o push ser confirmado** (ver pendência abaixo).

**Limitação importante:** o projeto Skip não está integrado com Skip Cloud (`skip_cloud_list_logs` retorna "Project is not integrated with Skip Cloud"), então não existe log real de requests/tempo de resposta para confirmar quantitativamente a lentidão relatada. Todo o diagnóstico abaixo é por leitura de código-fonte e do schema do banco (snapshot central `supabase/db/current/`), não por medição direta. Recomenda-se medir antes/depois de cada mudança (ver "Testes/verificações obrigatórias").

## Checklist de Ação

- [ ] Item 1 — Substituir o full-fetch paginado em lotes de 1000 em `getProjetos()` (`src/services/projetos.ts`) por paginação real de servidor (filtros e `.range()` aplicados conforme a tela que consome, sem carregar a tabela inteira por padrão). **Não feito em 2026-07-23** — exigiria mudar a UI de listagem (paginação visível, filtros no servidor), o que o usuário pediu para não fazer nesta rodada ("sem alterar nada estrutural do sistema"). `getProjetos()` continua buscando a tabela inteira, porém agora só é chamado 1x por sessão em vez de 3x (ver Item 2/3).
- [x] Item 2 — Eliminar as chamadas duplicadas e independentes a `getProjetos()` hoje disparadas por `useProjectStore.tsx`, `src/pages/Index.tsx` e `src/pages/Projetos.tsx`. **Feito em 2026-07-23**, mas sem introduzir `@tanstack/react-query` (evitado por ser uma dependência/arquitetura nova — o usuário pediu para não alterar nada estrutural): `Index.tsx` e `Projetos.tsx` passaram a consumir `useProjectStore()` (que já existia) em vez de chamar `getProjetos()` por conta própria. Resultado prático equivalente ao cache/dedupe pedido, com uma mudança bem menor.
- [x] Item 3 — Fazer `src/pages/Projetos.tsx` consumir os dados via a store/cache único em vez de refazer seu próprio `getProjetos()`. **Feito em 2026-07-23.**
- [x] Item 4 — Adicionar debounce/throttle nos handlers `postgres_changes` de `useProjectStore.tsx` (canais `proj_changes`/`cont_changes`) e remover a duplicidade do canal `dashboard_changes` em `src/pages/Index.tsx`. **Feito em 2026-07-23** — debounce de 1,5s nos dois canais da store e no canal do dashboard; o canal do dashboard não busca mais a lista completa de projetos (isso já vem da store), só a RPC de estatísticas e os 5 projetos recentes.
- [ ] Item 5 — Trocar `refreshContacts` (`select('*').limit(5000)`) por busca sob demanda/paginada. **Não feito em 2026-07-23** — adiado por prudência: várias telas dependem de `useProjectStore().contacts` com todas as colunas (não auditadas uma a uma nesta rodada); mudar o `select` sem confirmar cada consumidor tinha risco de regressão. Fica para uma rodada futura, com levantamento prévio de quais colunas cada tela realmente usa.
- [ ] Item 6 — Mover as agregações do dashboard para a RPC `get_dashboard_stats`. **Não feito em 2026-07-23** — a RPC existente cobre só contadores gerais (`activeProjects`, `clientsCount`, etc.), não necessariamente todas as quebras que `DashboardCharts`/`DashboardMetrics` calculam hoje a partir do array completo; trocar exigiria conferir cada gráfico um a um. Como o Item 2 já elimina os fetches duplicados, o custo de recalcular no cliente deixou de ser o gargalo principal — baixa prioridade agora.
- [ ] Item 7 — Code splitting por rota (`React.lazy` em `App.tsx` + `manualChunks`). **Não feito em 2026-07-23** — adiado por ser uma mudança de configuração de build (o projeto usa Rolldown via `rolldownOptions`, não o Rollup padrão) sem relação direta com o sintoma de "trava"/"não responde por horas" relatado, que é sobre dado e realtime, não sobre o bundle inicial.
- [ ] Item 8 — Índices em `projetos.arquiteto_id`, `projetos.responsavel_id`, `projeto_itens.projeto_id`. **Fora do escopo desta rodada** — envolve migration no Supabase, e o usuário pediu explicitamente para não alterar nada estrutural no Supabase.
- [ ] Item 9 — Auditoria/consolidação de políticas RLS. **Fora do escopo desta rodada** — mesma razão do Item 8.

### Passos manuais do usuário

- [x] Decidir se o repositório `lucenera-crm` deve ser adicionado como submodule em `04-Sistemas/` — **aprovado e feito em 2026-07-23**: `git submodule add -f https://github.com/pedrolalala/lucenera-crm.git "04-Sistemas/lucenera-crm-3bd29 (1)"`, apontando para `heads/main` (commit `9078947`). Ver nota abaixo sobre defasagem em relação ao Skip.
- [ ] Avaliar habilitar a integração Skip Cloud neste projeto para termos logs reais de request/tempo de resposta e conseguirmos medir o "antes"/"depois" de forma objetiva, não só por leitura de código.
- [x] ~~Aprovar a introdução de `@tanstack/react-query`~~ — **decisão em 2026-07-23**: não introduzida; o usuário pediu para não alterar nada estrutural, então o Item 2 foi resolvido reaproveitando a store já existente (ver Checklist).
- [x] ~~Priorizar entre os itens 1–9~~ — **decisão em 2026-07-23**: usuário aprovou implementar "o que for necessário" com a restrição de não mudar nada estrutural no sistema nem no Supabase; nessa leitura, priorizei e implementei os Itens 2/3/4 (maior impacto, menor risco/estrutura) e deixei os Itens 1/5/6/7 (mudam UI ou build) e 8/9 (mudam o Supabase) para uma rodada futura, se o usuário quiser.
- [ ] **Testar na prática se a sensação de travamento melhorou** (não há telemetria disponível para medir objetivamente — ver "Realizado" 2026-07-23). Usar o CRM em produção (`https://lucenera-crm-3bd29.goskip.app`) por alguns dias e reportar se ainda trava/demora.

## Objetivo

O usuário relata que o CRM está com desempenho muito baixo no dia a dia: telas demoram muito para carregar, o sistema trava, e em alguns momentos parece simplesmente parar de responder por horas. O objetivo desta SPEC é diagnosticar, com evidência no código-fonte real do CRM e no schema do banco, as causas prováveis dessa lentidão, e propor um conjunto de mudanças técnicas (frontend, dados e banco) para resolvê-las, sem alterar o comportamento funcional das telas.

## Decisões aprovadas

Nenhuma decisão de implementação foi fechada ainda — esta SPEC registra um diagnóstico técnico novo e depende de aprovação do usuário sobre prioridade e escopo (ver "Passos manuais do usuário") antes de qualquer código ser alterado.

## Definição da SPEC

### 1. Estado atual — Diagnóstico (por evidência de código)

**Achado 1 — `getProjetos()` sempre carrega a tabela `projetos` inteira (`src/services/projetos.ts`). Severidade: alta.**

```js
while (hasMore) {
  const { data } = await supabase.from('projetos').select(`
    *, cliente:cliente_id(nome), arquiteto:arquiteto_id(nome),
    responsavel:responsavel_id(nome), engenheiro:responsavel_obra_id(nome),
    projeto_parcelas(*)
  `).range(from, from + step - 1)   // step = 1000, loop até esgotar a tabela
}
```

Não existe paginação de UI real: é um loop que busca a tabela inteira em lotes de 1000, com 4 lookups de FK e o array completo de parcelas por linha, mais uma query extra a `vw_dashboard_crm_fechamento` mesclada no cliente. Essa função é chamada de forma independente em três lugares (`useProjectStore.tsx`, `src/pages/Index.tsx`, `src/pages/Projetos.tsx`) — ou seja, o mesmo dataset pesado é buscado até 3 vezes ao navegar entre telas.

**Achado 2 — Realtime dispara refetch completo, sem debounce, para todos os usuários conectados. Severidade: alta.**

`useProjectStore.tsx` assina `postgres_changes` em `projetos` e `contatos`:

```js
supabase.channel('proj_changes').on('postgres_changes', { event: '*', table: 'projetos' }, refreshProjects)
supabase.channel('cont_changes').on('postgres_changes', { event: '*', table: 'contatos' }, refreshContacts)
```

Qualquer INSERT/UPDATE/DELETE em `projetos` (ex.: um usuário editando uma parcela) dispara o full-fetch do Achado 1 em **todos os navegadores abertos** ao mesmo tempo. `refreshContacts` faz `select('*').limit(5000)` a cada evento em `contatos`. `src/pages/Index.tsx` ainda abre um canal próprio (`dashboard_changes`) ouvindo as mesmas tabelas e chamando `getProjetos()` de novo — duplicando a mesma query pesada por evento.

**Achado 3 — `src/pages/Projetos.tsx` ignora a store global e refaz o fetch. Severidade: alta.**

```js
const loadProjetos = () => { setLoading(true); getProjetos().then(setProjetos)... }
useEffect(() => { loadProjetos() }, [])
```

Confirma, para performance, o mesmo padrão de abandono da store já registrado na SPEC-042 (lá era sobre `contacts` não confiável). Todos os filtros e o cálculo de valor total (`filteredProjetos`, `getUnique`, somas) rodam em `.filter()`/`.reduce()` sobre o array completo no cliente — nenhum filtro é aplicado no servidor.

**Achado 4 — Dashboard recalcula agregações no cliente em vez de usar a RPC já existente. Severidade: média.**

`DashboardCharts.tsx`/`DashboardMetrics.tsx` fazem `reduce()` sobre o array completo de projetos para contagens por status e somas, embora já exista `get_dashboard_stats` (RPC criada em `supabase/migrations/20260429192055_dashboard_stats_rpc.sql`, no domínio `crm` — ver `supabase/db/domains/crm.md`) para fazer essa conta no banco. `DashboardMetrics` ainda soma um `select('*', {count:'exact', head:true})` em `contatos` no mount.

**Achado 5 — Ausência de cache/dedupe de requisições no cliente. Severidade: média (multiplicador dos achados 1–3).**

`package.json` não tem `@tanstack/react-query`, `swr` nem equivalente. Cada navegação ou remount refaz fetch do zero, sem `staleTime` e sem dedupe de chamadas concorrentes — é o que permite os Achados 1 e 3 coexistirem (3 componentes pedindo a mesma coisa ao mesmo tempo).

**Achado 6 — Zero code splitting por rota. Severidade: média (afeta o primeiro carregamento).**

`src/App.tsx` importa todas as ~12 páginas estaticamente (nenhum `React.lazy`), e `vite.config.ts` não define `manualChunks`. O bundle inicial inclui `recharts` e todos os componentes de todas as páginas, mesmo em telas que não usam gráfico.

**Achado 7 — Índices possivelmente ausentes em FKs específicas. Severidade: a confirmar.**

O histórico de migrations do próprio repositório `lucenera-crm` (`supabase/migrations/*.sql`, 18 arquivos) só tem um `CREATE INDEX` em todo o histórico (`idx_projetos_responsavel_obra_id`). Isso por si só **não** prova ausência de índice em produção — o snapshot central (`supabase/db/current/`) já mostra índices existentes que não aparecem nas migrations locais do CRM (`idx_projetos_cliente_id`, `idx_projetos_status`, `idx_projetos_empresa_status`, `idx_projetos_nome`, `idx_parcelas_projeto/status/vencimento`, índices em `contatos.nome/cpf/email/tipo/empresa`), confirmando a regra do `AGENTS.md` de que as migrations dentro de `04-Sistemas/*/supabase/migrations` não são fonte final do banco. **Não confirmado**: índice em `projetos.arquiteto_id`, `projetos.responsavel_id` e `projeto_itens.projeto_id` — precisa ser checado direto no snapshot central antes de criar migration (Item 8).

**Achado 8 — RLS não é a causa raiz confirmada, mas há debito técnico a auditar. Severidade: baixa/média.**

As policies lidas têm condição simples (`USING (true)`), então RLS complexo com subquery **não** é a causa principal da lentidão. Porém o snapshot central mostra volume alto de policies por tabela (`contatos`=14, `projetos`=16, `projeto_parcelas`=10, `orcamentos`=14) — Postgres avalia todas as policies permissivas aplicáveis a cada query, então esse número alto tem custo cumulativo mesmo com condições simples, e vale auditoria/consolidação (Item 9) — não é urgente como os achados 1–3.

**Achado 9 (informativo) — Nenhum registro anterior do problema.** `supabase/AI_DB_CONTEXT.md` do CRM não tem nenhuma nota de performance/query lenta — este é o primeiro levantamento formal.

### 2. Mudança proposta

Ver Checklist de Ação acima — cada item corresponde a um achado. Ordem de prioridade sugerida (a validar com o usuário):

1. **Alta prioridade / maior impacto:** Itens 1, 2, 3, 4 — atacam diretamente o full-fetch triplicado e o realtime storm, que são a causa mais provável de "trava" e "não responde por horas" (muitos requests pesados simultâneos/concorrentes podem esgotar conexões do pool do Supabase ou travar a aba do navegador).
2. **Média prioridade:** Itens 5, 6, 7 — reduzem carga adicional e o tempo do primeiro carregamento.
3. **A confirmar antes de agir:** Itens 8 e 9 — dependem de checar o snapshot central antes de qualquer migration.

### Impacto no banco

- Possível criação de índice(s) novos (Item 8), condicionada à confirmação de que estão realmente ausentes — migration em `supabase/db/migrations/YYYYMMDD_NNN_indices_crm_performance/`.
- Possível consolidação de RLS policies (Item 9) — mudança sensível, precisa de teste extensivo de permissão antes de aplicar (risco de quebrar acesso se malfeita).
- Nenhuma mudança de schema (colunas/tabelas) é necessária para os Itens 1–7 — são mudanças de frontend/consulta, não de estrutura de dados.

### Impacto em telas

- `src/pages/Index.tsx` (Dashboard) — Itens 2, 4, 6.
- `src/pages/Projetos.tsx` (listagem/kanban) — Itens 1, 2, 3.
- `src/stores/useProjectStore.tsx` — Itens 1, 2, 4, 5.
- `src/components/dashboard/DashboardCharts.tsx`, `DashboardMetrics.tsx` — Item 6.
- `src/App.tsx`, `vite.config.ts` — Item 7.
- Nenhuma mudança visual/de comportamento esperada para o usuário final além de "carregar mais rápido" — os critérios de aceite abaixo exigem paridade funcional.

### Regras de permissão

Nenhuma mudança de permissão de usuário prevista nos Itens 1–8. Item 9 (consolidação de RLS) precisa manter exatamente o mesmo resultado de acesso por perfil — é auditoria/limpeza, não mudança de regra de negócio.

### Critérios de aceite

- Nenhuma tela perde dado ou funcionalidade hoje existente (parcelas, filtros, badges, combobox de busca da SPEC-042, dashboard) — apenas performance muda.
- Navegar entre `/`, `/projetos` e `/projetos/:id` não deve disparar mais de uma busca da lista completa de projetos por sessão de navegação (hoje são 2–3 chamadas independentes).
- Um evento realtime em `projetos`/`contatos` não deve mais disparar full-fetch de 5000 registros de `contatos` nem full-fetch de `projetos` em paralelo em múltiplos componentes.
- O dashboard usa a RPC `get_dashboard_stats` para contagens/somas em vez de recalcular sobre o array completo no cliente.
- Bundle inicial (medido via `npm run build` + `vite-bundle-visualizer` ou equivalente) reduz de tamanho após o code splitting por rota.

### Testes/verificações obrigatórias

- Medir manualmente (Network tab do navegador) o tempo de carregamento e o número de requests de `/`, `/projetos` e `/projetos/:id` **antes** de qualquer mudança, para servir de baseline (não existe log de produção disponível — ver limitação na "Nota sobre origem do código").
- Repetir a mesma medição **depois** de cada item implementado, documentando o resultado no bloco "Realizado" desta SPEC.
- Confirmar que o combobox de busca de contatos (SPEC-042) continua funcionando após qualquer mudança no fetch de `contatos`.
- Rodar `npx tsc --noEmit`, `npx oxlint` e `npm run build` no clone/projeto Skip após as mudanças (mesmo padrão de verificação já usado na SPEC-042).
- Se o Item 9 (RLS) for implementado, testar login com pelo menos um usuário de cada perfil relevante e confirmar que o conjunto de dados visíveis não muda antes/depois da consolidação.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `projetos`, `contatos`, `projeto_parcelas`, `projeto_itens` e `usuarios_crm` são consultados pelas telas analisadas.
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Afeta primariamente o CRM. Como `projetos`/`contatos`/`projeto_parcelas` são consultados por outros sistemas do ecossistema, qualquer mudança de índice ou RLS (Itens 8–9) precisa ser validada quanto a não regressão nesses outros sistemas antes de aplicar em produção.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não é o foco desta SPEC — nenhum achado envolve duplicação de dado.
- **Existe migration antiga que contradiz o snapshot central?** Sim — as migrations locais do repositório `lucenera-crm` não refletem todos os índices já existentes no snapshot central (`supabase/db/current/`), confirmando que não devem ser tratadas como fonte final (ver Achado 7).
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim, se os Itens 8 ou 9 forem implementados — atualizar `supabase/AI_DB_CONTEXT.md` do CRM registrando os índices adicionados e/ou a consolidação de RLS.

## Realizado

### 2026-07-23

- Usuário aprovou implementar, com uma restrição explícita: nenhuma mudança estrutural no sistema nem nos dados/schema do Supabase nesta rodada — só otimizações de aplicação (Itens 8 e 9, que envolvem o banco, ficaram de fora por definição).
- Implementado direto no projeto Skip (`projectId 24580`, já que o submodule local `04-Sistemas/lucenera-crm-3bd29 (1)/` está desatualizado em relação à produção — ver "Nota sobre origem do código").
- `src/stores/useProjectStore.tsx`: reescrito para expor `loading` no contexto, e os dois canais de realtime (`proj_changes`/`cont_changes`) passaram a chamar `refreshProjects`/`refreshContacts` com debounce de 1,5s em vez de a cada evento individual.
- `src/pages/Index.tsx`: removido o fetch próprio de `getProjetos()` (`fetchAllProjetos`) e o estado `projetos`/`loadingProjetos` locais — passou a consumir `projects`/`loading` de `useProjectStore()`. O canal `dashboard_changes` deixou de rebuscar a lista completa de projetos a cada evento; agora só dispara (com debounce de 1,5s) a RPC `get_dashboard_stats` e a busca dos 5 projetos recentes, que não vêm da store.
- `src/pages/Projetos.tsx`: removido `loadProjetos()`/`getProjetos()` próprio — passou a consumir `projects`/`loading`/`refreshProjects` de `useProjectStore()`. `handleSave` e `handleDelete` chamam `refreshProjects()` da store em vez de refazer o fetch local.
- Efeito combinado: navegar entre `/`, `/projetos` e voltar não dispara mais 2–3 buscas independentes da tabela `projetos` inteira (com 4 joins + parcelas) — passa a haver **uma única busca compartilhada**, mantida viva por realtime debounced. Qualquer alteração em `projetos`/`contatos` (por qualquer usuário) também deixou de disparar um refetch completo imediato em todos os navegadores conectados a cada linha alterada — agora é agrupado em uma única busca por janela de 1,5s.
- QA completo no Skip (`skip_project_apply_changes`, modo `development`): `setup`, `staticAnalysis`, `build`, `integrations` e `test` todos `ok`. Publicado como versão `0.0.274` (hash `4e1d103`), `isPublished: true` em `https://lucenera-crm-3bd29.goskip.app`.
- Nenhuma mudança de schema, dado ou RLS no Supabase. Nenhuma dependência nova adicionada (`@tanstack/react-query` foi deliberadamente descartado a favor de reaproveitar a store já existente).
- **Não medido objetivamente**: como registrado na "Nota sobre origem do código", não há integração Skip Cloud para logs de request/tempo — não há como comparar tempo de carregamento antes/depois numericamente. A melhoria esperada é estrutural (menos requests, sem storm de realtime), mas o usuário deve validar na prática se a sensação de travamento melhorou.

## Pendências

- [ ] Confirmar/realizar o push do commit publicado no Skip (agora versão `0.0.274`, hash `4e1d103`, já incluindo as otimizações desta SPEC) para o `main` do GitHub `pedrolalala/lucenera-crm` — o submodule local registrado em 2026-07-23 continua apontando para o commit antigo `9078947`, agora ainda mais defasado (sem SPEC-042 nem SPEC-043). Mesma pendência já registrada na SPEC-042; não há ferramenta MCP para sincronizar Skip→GitHub, verificar na interface web do Skip.
- [ ] Testar na prática, em produção (`https://lucenera-crm-3bd29.goskip.app`), se a sensação de travamento/lentidão melhorou depois das mudanças de 2026-07-23 — não há telemetria (Skip Cloud não integrado) para confirmar numericamente.
- [ ] Se ainda travar/demorar depois da validação acima, avaliar retomar os Itens 1 (paginação real de servidor), 5 (reduzir payload de `refreshContacts`), 6 (dashboard via RPC) e 7 (code splitting) — todos ficaram de fora desta rodada por mudarem UI/build, não por não serem úteis.
- [ ] Itens 8 (índices) e 9 (RLS) permanecem fora de escopo enquanto a restrição de "não alterar nada estrutural no Supabase" estiver valendo; retomar apenas se o usuário aprovar explicitamente uma mudança de banco.
- [ ] Confirmar diretamente no snapshot central (`supabase/db/current/`) se `projetos.arquiteto_id`, `projetos.responsavel_id` e `projeto_itens.projeto_id` têm índice — Achado 7 não foi confirmado com certeza, apenas as migrations locais do CRM (que não são fonte confiável) não os mostram. Só relevante se o Item 8 for retomado.
- [ ] Avaliar se vale habilitar a integração Skip Cloud no projeto do CRM para obter logs reais de request/tempo de resposta, permitindo medir objetivamente qualquer melhoria futura (hoje não há essa telemetria).
