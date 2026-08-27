---
titulo: "SPEC-055 — CRM: Links de Teams e Planner no Projeto + Abertura em Nova Aba (SharePoint/Teams/Planner/Orçamento)"
status: não iniciado
data_ultima_modificacao: 2026-07-28
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-055 — CRM: Links de Teams e Planner no Projeto + Abertura em Nova Aba

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** está registrado como submodule em `04-Sistemas/lucenera-crm-3bd29 (1)/`, mas esse submodule está desatualizado em relação à produção (mesma situação documentada nas SPEC-042/043/044/045/047). A implementação real acontece direto no projeto Skip "Lucenera CRM" (`projectId 24580`).

**Achado relevante desta leitura**: o mirror local já contém, em `ProjectDetail.tsx`, um card "Link do SharePoint"? **Não** — apesar da SPEC-045 estar marcada como `concluído` e ter sido publicada em produção (`0.0.284`), o arquivo local `src/pages/ProjectDetail.tsx` **não tem** esse card. Isso confirma, de novo, que o mirror local está atrás da produção real. O implementador precisa abrir o código-fonte real no Skip antes de aplicar qualquer diff — não usar o arquivo local como base de patch, só como referência de padrão.

## Checklist de Ação

- [ ] Item 1 — Migration `supabase/db/migrations/20260728_069_link_teams_planner_projeto/`: adicionar `projetos.link_teams` (text, nullable) e `projetos.link_planner` (text, nullable), mesmo padrão aditivo da SPEC-045 (`link_sharepoint`).
- [ ] Item 2 — `ProjectDetail.tsx` (Skip, `projectId 24580`): dois novos cards, "Link do Teams" e "Link do Planner", seguindo exatamente o mesmo padrão visual e de edição do card "Link do SharePoint" (SPEC-045) — leitura com link clicável (`target="_blank"`) ou texto "Nenhum link cadastrado ainda"; edição com `<Input type="url">` dentro do mesmo toggle Editar/Salvar/Cancelar já existente; campos incluídos no payload de `handleSave` (`link_teams: editForm.link_teams || null`, `link_planner: editForm.link_planner || null`).
- [ ] Item 3 — Botão "Gerar Orçamento" (`openBudgetSystem`): confirmar diretamente no código de produção (Skip) se já usa o padrão `redirectWithCode(destino, redirectTo, sistema, { newTab: true })` — que já existe implementado neste mirror local (ver "Achado" na Definição da SPEC). Se produção não usar esse padrão, aplicá-lo, para que o botão abra em nova aba como os demais 3 links.
- [ ] Item 4 — Script `scripts/sincronizar_links_planner.py`, espelhando a estrutura de `scripts/sincronizar_links_sharepoint.py` (`--min`/`--max`/`--dry-run`, só preenche quando `link_planner` está vazio, nunca sobrescreve). **Não implementável ainda** — depende de confirmar (a) o escopo de permissão do Graph API necessário e (b) a estrutura real de matching projeto↔plano do Planner (ver "Pendências").
- [ ] Item 5 — Script `scripts/sincronizar_links_teams.py`, mesma estrutura. **Bloqueado explicitamente** — depende de uma permissão nova no Azure AD que o Filippo vai resolver com o Alan fora desta SPEC, e de confirmar a estrutura real de matching projeto↔canal do Teams (ver "Pendências").
- [ ] Item 6 — Atualizar `supabase/db/domains/crm.md` (repo central) e `supabase/AI_DB_CONTEXT.md` do CRM com as 2 colunas novas e, quando implementados, os 2 scripts novos — mesmo padrão da SPEC-045/046.

### Passos manuais do usuário

- [ ] Filippo conversar com o Alan e conceder a permissão nova no Azure AD/Graph API necessária para ler canais do Teams (hipótese: `Team.ReadBasic.All` + `Channel.ReadBasic.All`, escopo exato a confirmar) — bloqueador explícito para o script de Teams.
- [ ] Confirmar com Filippo/Alan a estrutura real dos canais do Teams por projeto: é uma equipe única do Teams com um canal por projeto (nome do canal = código do projeto?), ou uma equipe por responsável, no mesmo padrão `PROJETOS<NOME>` já usado no SharePoint? Não decidir isso sem dado real — é dado técnico do Microsoft 365 da empresa, não uma escolha de produto.
- [ ] Confirmar o escopo de permissão do Graph necessário para o Planner (hipótese: `Group.Read.All` + `Tasks.Read.All`, a validar — a app "Lucenera Conexão Sharepoint para Skip" hoje só tem `Files.Read.All` concedido) e a estrutura de matching projeto↔plano do Planner (um plano por projeto? um plano por responsável com um "bucket" por projeto?).
- [ ] Decidir se o botão "Gerar Orçamento" continua existindo ou é removido — Filippo levantou a dúvida na reunião ("talvez não tenha necessidade... já dá pra acessar a situação do cliente por ali, fazer orçamento rápido de outro jeito") mas não fechou a decisão.
- [ ] Enquanto a sincronização automática de Teams/Planner não existe, preencher manualmente os links por projeto (mesmo caminho que o SharePoint usou antes da SPEC-046 existir).
- [ ] Confirmar em produção (Skip) se `openBudgetSystem` já abre em nova aba hoje; se sim, só falta validar com o Filippo que o comportamento está correto; se não, aplicar o Item 3.

## Objetivo

O detalhe do projeto no CRM (`/projeto/:id`) hoje só tem o link do SharePoint (SPEC-045/046). Cada projeto, ao ser criado, já dispara automações do Microsoft 365 que criam também um canal do Teams e um plano do Planner (mesma automação que cria a pasta do SharePoint, conforme já registrado na SPEC-047) — mas o CRM não mostra nem esses links. Esta SPEC estende o mesmo padrão já validado do SharePoint para Teams e Planner (coluna nova + card novo + script de sincronização), e corrige o botão "Gerar Orçamento", que hoje troca a janela inteira em vez de abrir em nova aba como os outros 3 links — quebrando o fluxo de trabalho do Filippo, que quer manter o CRM sempre aberto numa aba enquanto acessa os sistemas relacionados nas outras.

Contexto adicional (não é mudança de comportamento, só confirmação): o Filippo reafirmou na Reunião.01 que o orçamento pertence ao **projeto**, não ao **cliente** — um cliente pode ter vários projetos/códigos, e cada projeto tem seus próprios orçamentos. Isso já é o modelo de dados real (`orcamentos.projeto_id`, sem vínculo direto a cliente) e não precisa de mudança.

## Decisões aprovadas

- Seguir **exatamente** o mesmo padrão já validado nas SPEC-045/046 para Teams e Planner: nova coluna em `projetos` (`link_teams`, `link_planner`), novo card em `ProjectDetail.tsx` no mesmo fluxo Editar/Salvar/Cancelar (não modal separado), script de sincronização Python que só preenche quando o campo está vazio, nunca sobrescreve.
- Os 4 links do detalhe do projeto — SharePoint, Teams, Planner e o botão "Gerar Orçamento" — devem abrir em nova aba. Decisão explícita do Filippo: "assim a gente tem sempre essa janela aberta para poder trabalhar em cima".
- A sincronização automática do link do Teams fica **bloqueada** até uma permissão nova no Graph API ser concedida — o Filippo resolve isso com o Alan fora desta conversa/SPEC. Enquanto isso, os cards de UI e as colunas de banco já podem ser implementados e usados com preenchimento manual (mesmo caminho que o SharePoint usou entre a SPEC-045 e a SPEC-046).
- A restrição de visibilidade da coluna de "valores" na lista de projetos (Filippo vê tudo, cada chefe de equipe só vê o da própria equipe) fica **fora do escopo** desta SPEC — só registrada como pendência futura (ver "Pendências").
- Não removida a dúvida sobre manter/remover o botão "Gerar Orçamento" — Filippo não fechou essa decisão, então esta SPEC só corrige o comportamento técnico (abrir em nova aba) e registra a dúvida de manter/remover como pendência de decisão, sem decidir por ele.

## Definição da SPEC

### 1. Banco de dados

Duas colunas novas, aditivas, sem impacto em dado existente — mesmo padrão da migration `20260724_061_link_sharepoint_projeto` (SPEC-045):

```sql
-- supabase/db/migrations/20260728_069_link_teams_planner_projeto/up.sql

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS link_teams text;

COMMENT ON COLUMN public.projetos.link_teams IS
  'Link do canal do Teams do projeto (criado automaticamente pela automação Microsoft 365 na criação do projeto, junto com a pasta do SharePoint e o plano do Planner). Preenchido manualmente pelo usuário no CRM até a sincronização automática (SPEC-055) ser desbloqueada pela permissão do Graph API ainda não concedida.';

ALTER TABLE public.projetos
  ADD COLUMN IF NOT EXISTS link_planner text;

COMMENT ON COLUMN public.projetos.link_planner IS
  'Link do plano/quadro do Planner do projeto (criado automaticamente pela automação Microsoft 365 na criação do projeto). Preenchido manualmente pelo usuário no CRM; sincronização automática via Microsoft Graph API a implementar (escopo de permissão a confirmar, ver SPEC-055).';
```

```sql
-- supabase/db/migrations/20260728_069_link_teams_planner_projeto/down.sql

ALTER TABLE public.projetos DROP COLUMN IF EXISTS link_planner;
ALTER TABLE public.projetos DROP COLUMN IF EXISTS link_teams;
```

Número de migration confirmado contra `supabase/db/migrations/` real: a última pasta existente é `20260727_068_spec053_codigo_produto_sequence`, então `069` é o próximo livre.

**Observação sobre drift do snapshot**: `supabase/db/current/01_schema_full.sql` ainda **não** tem `link_sharepoint` (aplicado direto em produção pela SPEC-045, mas o snapshot completo nunca foi regenerado). Isso já era uma pendência anterior a esta SPEC — só fica reforçada: depois de aplicar as duas colunas novas, o snapshot central vai ficar ainda mais desatualizado se não for regenerado (ver "Pendências").

### 2. Frontend — `ProjectDetail.tsx`

Dois cards novos, mesmo padrão (`Card`/`CardHeader`/`CardTitle`/`CardContent`) do card "Link do SharePoint" descrito na SPEC-045:

- **"Link do Teams"**: leitura mostra link (`<a target="_blank" rel="noopener noreferrer">`, texto tipo "Abrir canal no Teams") ou "Nenhum link cadastrado ainda"; edição mostra `<Input type="url">` vinculado a `editForm.link_teams`.
- **"Link do Planner"**: mesmo padrão, vinculado a `editForm.link_planner`, texto "Abrir plano no Planner".
- Posição: logo após o card "Link do SharePoint" (SPEC-045) e antes de "Itens Aprovados do Projeto" — mesma área de cards de contexto adicional, dentro do grid `md:grid-cols-2` já existente.
- `handleSave`: incluir `link_teams: editForm.link_teams || null` e `link_planner: editForm.link_planner || null` no payload de `updateProjetoById`.
- Mesmo contorno técnico já usado na SPEC-045 para os campos não presentes no `types.ts` gerado (arquivo grande demais para patch na sessão anterior): usar cast `as any` nos pontos que leem/escrevem `link_teams`/`link_planner`, até que os tipos sejam regerados — documentar isso em `AI_DB_CONTEXT.md` do CRM.

**Importante**: como o mirror local não tem nem o card "Link do SharePoint" ainda, o implementador precisa localizar a posição real desse card no código de produção (Skip) antes de inserir os dois novos — não usar a estrutura deste arquivo local como referência de posição exata, só como referência de padrão visual (que é o mesmo em toda a SPEC-045).

### 3. Botão "Gerar Orçamento" — abrir em nova aba

**Achado no código local** (`ProjectDetail.tsx`, linhas 66-79):

```ts
const openBudgetSystem = async (projetoId: string) => {
  const redirectTo = `/budgets/new?projeto_id=${encodeURIComponent(projetoId)}`
  try {
    await redirectWithCode('https://gestaofinanceiralucenera.goskip.app', redirectTo, 'orcamentos', {
      newTab: true,
    })
  } catch {
    window.open(
      `https://gestaofinanceiralucenera.goskip.app${redirectTo}`,
      '_blank',
      'noopener,noreferrer',
    )
  }
}
```

E em `src/lib/cross-system-auth.ts`, `redirectWithCode` já suporta `newTab: true`: abre um `window.open('about:blank', '_blank', ...)` **síncrono** (antes de qualquer `await`, então não é bloqueado por popup blocker, pois roda dentro da pilha de chamada do clique), guarda o placeholder, troca `placeholder.location.href` pela URL final depois de resolver o código SSO via Edge Function `generate-cross-system-code`.

**Conclusão**: este mirror local (mesmo desatualizado) já contém o padrão técnico correto para abrir em nova aba via SSO cross-system. Isso gera uma dúvida real que só pode ser resolvida olhando o código de produção real no Skip: ou (a) a produção já tem esse mesmo código e o problema relatado pelo Filippo já foi resolvido antes da reunião (só falta validar com ele), ou (b) a produção está numa versão anterior sem `newTab: true` — inconsistente com "local está sempre atrás de produção", mas não impossível (pode ter havido uma correção aplicada e depois revertida, ou o histórico de sync do submodule não capturou todas as versões).

**Ação**: verificar o código real em produção antes de decidir se é preciso implementar algo novo ou só confirmar/homologar o que já existe. Se produção não tiver esse padrão, aplicar exatamente o mesmo (placeholder de nova aba + redirecionamento assíncrono), já testado neste mirror.

### 4. Scripts de sincronização — Teams e Planner

Mesma estrutura de `scripts/sincronizar_links_sharepoint.py` (autenticação client credentials, `--min`/`--max`/`--dry-run`, regra de nunca sobrescrever, relatório por projeto):

**Teams (`scripts/sincronizar_links_teams.py`) — bloqueado**:
- Hipótese de matching a confirmar: replicar o padrão `PROJETOS<RESPONSAVEL>` do SharePoint (uma equipe do Teams por responsável, um canal por projeto dentro dela) **ou** uma equipe única da empresa com um canal por projeto (nome do canal = código do projeto, ex. `26.211`). A estrutura do Teams pode ser bem diferente da do SharePoint (múltiplos sites vs. possivelmente uma equipe central com muitos canais) — **não presumir**, confirmar antes de escrever qualquer linha de matching.
- Permissão de aplicativo necessária no Graph: hipótese `Team.ReadBasic.All` + `Channel.ReadBasic.All` (a confirmar o escopo mínimo exato) — **ainda não concedida**. Filippo resolve com o Alan fora desta SPEC.
- Enquanto a permissão não existe, este item do checklist fica listado mas não implementável.

**Planner (`scripts/sincronizar_links_planner.py`) — pendência técnica a confirmar, não bloqueio de negócio explícito**:
- A app "Lucenera Conexão Sharepoint para Skip" hoje só tem `Files.Read.All` concedido (Microsoft Graph). Ler planos do Planner via aplicativo tipicamente exige `Group.Read.All` (para localizar o grupo/Team dono do plano) e `Tasks.Read.All` (ou `Tasks.ReadWrite.All`) — nenhum desses dois foi confirmado como concedido. Não presumir que a permissão atual já cobre; validar com uma chamada de teste ao Graph antes de escrever o script de produção.
- Estrutura de matching também incerta: um plano do Planner por projeto, ou um plano por responsável com um "bucket" por projeto? Mesma cautela do Teams — confirmar antes de implementar.

### Impacto no banco

Duas colunas novas em `projetos` (`link_teams`, `link_planner`), nullable, sem default além de `NULL`. Não afeta nenhuma query, view, RPC ou trigger existente.

### Impacto em telas

Só `ProjectDetail.tsx` (`/projeto/:id`). Nenhuma outra tela lista ou usa esses campos.

### Regras de permissão

Nenhuma mudança de permissão de usuário — mesma permissão de quem já pode editar projeto no CRM. A única mudança de permissão relevante é externa (Graph API / Azure AD), tratada como pendência bloqueante, não como regra de acesso do CRM.

### Critérios de aceite

- Cards "Link do Teams" e "Link do Planner" aparecem na página do projeto, mesma posição/padrão do "Link do SharePoint".
- Editar projeto permite preencher os dois campos manualmente; salvar persiste em `projetos.link_teams`/`link_planner`; recarregar mostra o valor salvo.
- Campos vazios não quebram a tela (mostram estado "sem link").
- Clicar em qualquer um dos 4 links/botões (SharePoint, Teams, Planner, Gerar Orçamento) abre em nova aba, mantendo a aba do CRM aberta.
- Scripts de Teams/Planner não fazem parte do critério de aceite desta rodada — ficam registrados como não implementáveis até as pendências de permissão/estrutura serem resolvidas.

### Testes/verificações obrigatórias

- Editar um projeto real, preencher os dois links manualmente, salvar, recarregar e conferir persistência (SELECT de conferência em `projetos.link_teams`/`link_planner`).
- Clicar nos 4 links/botões e confirmar visualmente (no navegador) que cada um abre uma nova aba, sem fechar/substituir a aba do CRM.
- QA completo do Skip (`skip_project_apply_changes`) antes de publicar, mesmo procedimento das SPEC-045/046.
- Não há suíte de testes automatizada no CRM — critério de aceite é 100% verificação manual/golden path + build/lint do Skip.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` ou `user_system_access`?** Sim — `projetos` (tabela compartilhada por CRM/Orçamentos/Financeiro/Estoque). As duas colunas novas são aditivas e não afetam os outros consumidores.
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI?** Só o CRM lê/escreve `link_teams`/`link_planner` e ajusta o botão de redirecionamento. O redirecionamento cross-system usa a Edge Function `generate-cross-system-code` (já existente, compartilhada — SPEC-007), sem alteração de contrato.
- **Existe dado duplicado que deveria ser derivado por relacionamento em vez de duplicado?** Não — mesmo raciocínio da SPEC-045: são campos de texto livre, sem tabela relacionada no Supabase para "canais do Teams" ou "planos do Planner".
- **Existe migration antiga que contradiz o snapshot central?** Não para as colunas novas. Existe, porém, uma pendência **já existente** (não causada por esta SPEC): `supabase/db/current/01_schema_full.sql` não reflete `link_sharepoint` (SPEC-045), e vai ficar ainda mais desatualizado depois desta SPEC se o snapshot não for regenerado.
- **Exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Sim — do CRM, e `supabase/db/domains/crm.md` no repo central (mesmo padrão da SPEC-045/046).
- **Qual sistema é afetado e qual padrão de acesso a dados ele já usa?** Só o CRM. Padrão já estabelecido e a ser seguido: componente de página (`ProjectDetail.tsx`) chama funções do arquivo `src/services/projetos.ts` (`getProjeto`, `updateProjetoById`) — não acesso direto ao Supabase client dentro do componente, não um store separado para esses campos. Esta SPEC não propõe nenhum padrão novo, só estende o payload já existente de `updateProjetoById`.

## Realizado

Nenhuma implementação ainda — esta SPEC registra o desenho aprovado em 2026-07-28, a partir da reunião com o Filippo e da leitura do código real (mesmo desatualizado) do CRM e dos scripts da SPEC-046.

## Pendências

- [ ] **Bloqueador confirmado — Teams**: a sincronização automática do link do Teams depende de uma permissão nova no Azure AD/Graph API (hipótese `Team.ReadBasic.All` + `Channel.ReadBasic.All`, escopo exato a confirmar) que ainda não está concedida. O Filippo vai resolver isso com o Alan fora desta conversa. Até lá, o script `sincronizar_links_teams.py` não pode ser implementado/rodado contra dados reais.
- [ ] **Estrutura do Teams por projeto a confirmar**: não se sabe se cada projeto tem um canal dentro de uma equipe única do Teams (nome do canal = código do projeto?) ou se existe uma equipe por responsável, como no SharePoint (`PROJETOS<NOME>`). Precisa ser confirmado com Filippo/Alan antes de escrever a lógica de matching do script — é dado técnico real do Microsoft 365, não uma decisão de produto a ser tomada nesta SPEC.
- [ ] **Escopo de permissão do Planner a confirmar**: a app existente só tem `Files.Read.All`. Ler Planner via Graph tipicamente precisa de `Group.Read.All` + `Tasks.Read.All` (ou `Tasks.ReadWrite.All`) — não confirmado se algum desses já está concedido. Precisa de uma chamada de teste ao Graph API antes de escrever o script de produção.
- [ ] **Estrutura do Planner por projeto a confirmar**: um plano do Planner por projeto, ou um plano por responsável com um bucket por projeto? Mesma cautela do Teams.
- [ ] **Decisão pendente — manter ou remover o botão "Gerar Orçamento"**: o Filippo levantou a possibilidade de o botão não ser mais necessário (já dá pra ver a situação do cliente ali e fazer orçamento rápido de outro jeito), mas não fechou a decisão. Esta SPEC só corrige o comportamento técnico (abrir em nova aba); a decisão de manter/remover fica em aberto.
- [ ] **Verificar se o problema do botão já foi resolvido em produção**: o código local (desatualizado) já mostra `openBudgetSystem` usando `redirectWithCode(..., { newTab: true })` com o padrão de placeholder de nova aba. Não é possível confirmar, sem olhar o código real do Skip, se a produção já tem essa correção (e o Filippo só não percebeu/testou) ou se produção está numa versão sem esse patch.
- [ ] **Pendência futura, fora do escopo desta SPEC**: restrição de visibilidade da coluna de "valores" na lista de projetos — Filippo vê os valores de todos os projetos, cada chefe de equipe deveria ver só os valores da própria equipe. Decisão do usuário nesta reunião foi deixar de fora desta rodada; registrar aqui só para não perder o pedido, sem desenhar a solução agora (vai exigir decisão de regra de acesso — RLS por equipe/responsável em `projetos`/`projeto_parcelas`, hoje sem essa granularidade).
- [ ] **Regenerar `supabase/db/current/01_schema_full.sql`**: o snapshot central já está desatualizado (não reflete `link_sharepoint` da SPEC-045) e vai ficar mais desatualizado ainda depois desta SPEC se não for regenerado a partir do Supabase real.
- [ ] **Preencher manualmente os links de Teams/Planner enquanto a automação não existe** — mesmo caminho que o SharePoint percorreu entre SPEC-045 (campo manual) e SPEC-046 (script de sincronização).
- [ ] **Atualizar `supabase/AI_DB_CONTEXT.md` do CRM e `supabase/db/domains/crm.md`** após a implementação dos itens não bloqueados (colunas + cards).
