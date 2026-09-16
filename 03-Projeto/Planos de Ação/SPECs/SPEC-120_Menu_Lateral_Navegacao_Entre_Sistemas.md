---
titulo: "SPEC-120 — Menu Lateral de Navegação Entre Sistemas (Switcher Global)"
status: concluído (feature em produção, publicada via Skip nos 10 sistemas) — ACHADO 2026-09-16: os arquivos locais (git) de 8 dos 9 satélites nunca foram commitados/pushados, criando um gap entre o histórico de código e o que está de fato publicado; ver Pendências
data_ultima_modificacao: 2026-09-16
sistemas_envolvidos:
  - Hub / Central (central-lucenera-dashboard-1c9ba, Skip 37750)
  - Orçamentos (gestao-financeira-clone-544cb (1), Skip 32554)
  - Administração Bancária / Financeiro (retorno-bancario-bradesco-5392a, Skip 36395)
  - CRM (lucenera-crm-3bd29 (1), Skip 24580)
  - Estoque/Compras — Necessidade de Compra (compras-lucenera-3o23t98ee, Skip 40326)
  - Logística (lucenera-logistics-b7cd1, Skip 24039)
  - Cadastro (cadastro-lucenera-b86fe, Skip 36668)
  - RH (dashboard-rh-lucenera-5fe9c, Skip 23919)
  - Dashboard Financeiro satélite (dashboard-lucenera-b02z85wa3, Skip 41135)
  - Separação Parcial (separacao-parcial, Skip 48801 — não confirmado via skip_project_list)
dependencias:
  - SPEC-006 (RPC hub_sistemas_permitidos — fonte de dados de permissão)
  - SPEC-007 (cross-system-auth.ts / redirectWithCode / consumeCodeFromUrl — SSO sem novo login)
  - SPEC-063 (precedente de sistema-satélite consultando permissão do Hub — não é o mesmo mecanismo, ver Definição)
---

# SPEC-120 — Menu Lateral de Navegação Entre Sistemas (Switcher Global)

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Criar/adotar o helper `cross-system-auth.ts` em RH (`dashboard-rh-lucenera-5fe9c`) — criado do zero + `consumeCodeFromUrl('rh')` wired no bootstrap de autenticação (`use-auth.tsx`, reconstruído em cima do conteúdo real do Skip, não do checkout local desatualizado).
- [x] Criar hook compartilhado `useSistemasPermitidos(currentSlug)` — autocontido (resolve o próprio usuário via `supabase.auth`), replica `hub_sistemas_permitidos` + fallback admin + fallback `user_system_access`, exclui `ubiqua` e o próprio sistema.
- [x] Criar `SystemSwitcher.tsx` — consome o hook, ordena por `display_order`, usa `icon_name`/`name`/`link`/`slug` de `public.systems`.
- [x] Reaproveita `redirectWithCode(system.link, '/', system.slug)` ao clicar — nenhum link `<a>`/`window.location.href` direto novo.
- [x] Replicado nos 9 sistemas satélite + Hub (10 repositórios).
- [x] Hub como item fixo do menu nos satélites (`showHubLink`, default `true`; `false` só no próprio Hub).
- [x] Montado no wrapper de layout mais alto de cada sistema — mapeamento real confirmado nas Pendências abaixo (não uniforme: `Layout.tsx`, `layout/AppLayout.tsx` ou `App.tsx` conforme o sistema).
- [ ] Atualizar `AI_DB_CONTEXT.md` de RH registrando a adoção do SSO cross-sistema pela primeira vez. **Não feito nesta rodada.**
- [ ] Atualizar `supabase/db/domains/hub_ti.md` registrando a extensão do consumo de `hub_sistemas_permitidos`/`redirectWithCode` para todos os satélites. **Não feito nesta rodada.**
- [x] Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Homologar manualmente no navegador, sistema por sistema (golden path: abrir sistema A → clicar no menu → chegar autenticado no sistema B sem tela de login) — nenhum dos sistemas tem suíte de testes automatizada, e isso **ainda não foi testado ao vivo** apesar de já estar publicado em produção.
- [x] Confirmar o `projectId` real do Skip para `separacao-parcial` — `48801`, confirmado via `skip_project_list`.
- [ ] Decidir, separadamente desta SPEC, se/quando o gap de enforcement identificado na SPEC-063 (a maioria dos sistemas satélite só verifica "sessão válida", não `hub_pode_executar`, para bloquear acesso direto por URL) deve ser fechado — esta SPEC decide apenas o que **aparece** no menu, não o que é **bloqueado** por URL direta.

## Objetivo

Hoje os sistemas do ecossistema Lucenera cadastrados na Central (Hub + 9 satélites — ver escopo abaixo) são deployments/domínios separados. O único ponto central de navegação entre eles é a grade de cards do Hub (`central-lucenera-dashboard-1c9ba`) — para ir de um sistema satélite a outro, o usuário precisa voltar manualmente ao Hub (ou já ter a URL de destino). Esta SPEC cria um menu de navegação persistente, no canto lateral direito, presente em todos esses sistemas, que lista apenas os sistemas que o usuário logado tem permissão de visualizar e permite trocar de sistema sem passar de novo pelo Hub e sem novo login.

**Escopo confirmado em 2026-08-24: Ubiqua/Catálogo de Peças fica FORA desta SPEC** — não faz parte do sistema operacional oficial da Lucenera dentro da Central (decisão do usuário). O foco é exclusivamente nos sistemas já cadastrados como visíveis/operacionais no Hub: Orçamentos, Administração Bancária/Financeiro, CRM, Compras/Necessidade de Compra, Logística, Cadastro, RH, Dashboard Financeiro satélite e Separação Parcial (9 satélites) + o próprio Hub.

## Decisões aprovadas

- O menu deve existir no Hub e nos 9 sistemas satélite dentro da Central — Ubiqua está fora de escopo (decisão do usuário em 2026-08-24: não faz parte do sistema operacional oficial da Lucenera).
- O filtro de visibilidade deve respeitar a permissão real de cada usuário por sistema — não uma lista fixa igual para todos.
- Não deve haver login duplicado ao trocar de sistema pelo menu (implícito no objetivo — navegar sem repetir login é o motivo de existir do menu).
- **Decisão 1 (2026-08-24):** o Hub aparece sempre no menu dos sistemas satélite, como link fixo fora da lista vinda de `hub_sistemas_permitidos` (a RPC exclui o Hub por design da SPEC-006) — qualquer usuário autenticado pode sempre voltar à porta de entrada.
- **Decisão 2 (2026-08-24):** o menu é uma barra fixa retrátil no canto lateral direito — sempre presente, colapsada mostrando só ícones, expande ao interagir; não invade o conteúdo da tela quando fechada.
- **Decisão 3 (2026-08-24):** navegação sempre na mesma aba, mantendo o comportamento real que já existe hoje no Hub via `redirectWithCode`. A inconsistência de texto do Hub ("abre em nova guia") fica registrada como achado, sem correção obrigatória nesta SPEC.
- **Decisão 4:** modelo de distribuição confirmado como replicação manual do componente/hook por repositório — não existe monorepo nem pacote npm compartilhado hoje entre os sistemas, e criar essa infraestrutura está fora do escopo desta SPEC.

## Definição da SPEC

### Estado atual confirmado em código (2026-08-24)

**Catálogo de sistemas (fonte única, não duplicar):** `public.systems` — colunas `id, name, description, link, icon_name, display_order, slug, visivel_no_hub`. 11 linhas no total, mas esta SPEC cobre só 10: `hub` (`visivel_no_hub = false`, por auto-governança da SPEC-006) + `financeiro`, `cadastro`, `crm`, `orcamentos`, `logistica`, `rh`, `necessidade-de-compra`, `dashboard-financeiro`, `separacao-parcial`. A linha `ubiqua` continua existindo na tabela (usada pela RPC/Hub normalmente), mas fica **fora do escopo desta SPEC** — não recebe o menu, e a lista de destinos do menu nos demais sistemas deve excluir `ubiqua` explicitamente (filtro extra no hook, não basta confiar em `hub_sistemas_permitidos` sozinha, já que ela devolveria `ubiqua` normalmente para quem tem permissão).

**RPC de permissão (SPEC-006), já filtra por `visivel_no_hub = true`:**
```sql
CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
RETURNS SETOF public.systems ...
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE (pp.acao = 'visualizar' OR pp.acao IS NULL)
    AND s.visivel_no_hub = true
```
Consequência direta para esta SPEC: **o Hub nunca aparece** no resultado desta RPC, mesmo para um admin — a exclusão é por design da SPEC-006 (evitar o Hub aparecer como card de si mesmo), não um bug. Isso vira decisão pendente abaixo.

**Como o Hub hoje consome essa RPC (`central-lucenera-dashboard-1c9ba/src/pages/Dashboard.tsx`)** — é o padrão a ser reaproveitado, não recriado:
```ts
if (profile?.role === 'admin') {
  // busca todos os systems com visivel_no_hub = true
} else {
  const { data } = await supabase.rpc('hub_sistemas_permitidos', { p_usuario_id: user.id })
  // fallback se data vazio: JOIN user_system_access (legado)
}
```
Abertura de sistema já usa SSO, não link cru:
```ts
await redirectWithCode(system.link, '/', system.slug)
```

**`cross-system-auth.ts` (SPEC-007) — inventário real por sistema, confirmado via grep, não por suposição:**

| Sistema | Tem `src/lib/cross-system-auth.ts`? | Chama `consumeCodeFromUrl()` (é destino)? | Chama `redirectWithCode()` em algum ponto (já é origem)? |
|---|---|---|---|
| Hub | Sim | N/A (é a origem típica) | Sim — `Dashboard.tsx` |
| Orçamentos | Sim | Sim — `use-auth.tsx` | Sim — `FinanceResultModal.tsx` |
| CRM | Sim | Sim — `use-auth.tsx` | Sim — `ProjectDetail.tsx` |
| Admin Bancária/Financeiro | Sim | Sim — `use-auth.tsx` | Não encontrado |
| Compras/Necessidade de Compra | Sim | Sim — `use-auth.tsx` | Não encontrado |
| Logística | Sim | Sim — `AuthContext.tsx` | Não encontrado |
| Cadastro | Sim | Sim — `use-auth.tsx` | Não encontrado |
| Dashboard Financeiro satélite | Sim | Sim — `use-auth.tsx` | Não encontrado |
| Separação Parcial | Sim | Sim — `AuthContext.tsx` | Não encontrado |
| RH | **Não** | **Não** | **Não** |
| ~~Ubiqua~~ | *(fora de escopo — decisão do usuário 2026-08-24)* | | |

Leitura prática (10 sistemas em escopo: Hub + 9 satélites): 9 dos 10 já sabem **receber** um `sso_code` (são destino válido hoje). Só 3 (Hub, CRM, Orçamentos) já **geram** código para sair para outro sistema. Esta SPEC precisa, portanto, de: (a) criar o arquivo + wiring do zero em RH, o único gap restante; (b) adicionar novos pontos de chamada de `redirectWithCode` (o próprio menu) nos 7 sistemas que hoje só recebem. Não é necessário criar/alterar nenhuma Edge Function nem tabela — a infraestrutura de SSO da SPEC-007 já está publicada e ativa (`generate-cross-system-code`, `exchange-cross-system-code`, `cross_system_session_codes`).

**Achado colateral, fora do escopo desta SPEC mas relevante para a decisão de "nova aba vs. mesma aba":** o texto da tela do Hub diz "Os módulos abrirão em uma nova guia", mas o código (`openSystem` → `redirectWithCode` → `window.location.href = nextUrl`) navega na **mesma aba**. Ou seja, o comportamento real já em produção hoje é mesma aba, mesmo que a cópia da tela diga o contrário — não corrigido aqui, só registrado para informar a decisão pendente 3.

**Achado adicional (2026-08-24, durante o início da implementação): a cópia de `cross-system-auth.ts` já divergiu entre sistemas** — a tabela acima só checava presença do arquivo, não o conteúdo real de `redirectWithCode`. Comparação direta do código confirmou duas variantes:
- **Mesma aba** (`window.location.href = nextUrl`, sem `window.open`): Hub, Orçamentos, Admin Bancária/Financeiro, CRM.
- **Nova aba** (`window.open('', '_blank')` + `newTab.location.href`): Compras/Necessidade de Compra, Logística, Cadastro, Dashboard Financeiro satélite, Separação Parcial.

Nos 5 sistemas com a variante "nova aba", `redirectWithCode` nunca era chamado por nenhuma tela própria até agora (confirmado na tabela acima — só recebiam SSO, nunca geravam), então o comportamento de nova aba nunca foi exercitado em produção; corrigir para a variante mesma-aba do Hub, como parte da implementação desta SPEC (que passa a chamar `redirectWithCode` pela primeira vez nesses 5), não quebra nada existente e é exigido pela Decisão 3 já aprovada.

**Achado colateral, relacionado mas não coberto por esta SPEC (SPEC-063/hub_ti.md):** hoje só o Dashboard Financeiro satélite (SPEC-063) checa permissão granular de verdade (`hub_pode_executar`) antes de liberar a tela. Os outros 9 sistemas satélite só verificam "existe sessão Supabase válida" — ou seja, mesmo que o menu não mostre um sistema para um usuário sem permissão, ele ainda consegue abrir esse sistema colando a URL direto no navegador. O menu resolve a **descoberta**/conveniência de navegação, não o **controle de acesso** por URL direta — isso é uma lacuna pré-existente e documentada, não desta SPEC.

### Proposta técnica (a partir do padrão já estabelecido, sem inventar um novo)

1. **Fonte de dados**: `public.systems` + RPC `hub_sistemas_permitidos(p_usuario_id)` — mesma exata fonte do Hub hoje, incluindo os dois fallbacks (`role === 'admin'` vê tudo; RPC vazia cai para `user_system_access`). Nenhuma tabela nova.
2. **Hook compartilhado**: `useSistemasPermitidos()` — replica a lógica de `Dashboard.tsx` isolada num hook, já excluindo `ubiqua` do resultado, para não duplicar a mesma sequência de chamadas em 9 componentes diferentes copiados manualmente. Ainda assim, o **arquivo** do hook é replicado por repositório (sem monorepo/pacote compartilhado hoje — mesma limitação já registrada na SPEC-116).
3. **Componente de UI**: `SystemSwitcher.tsx` (nome de referência) — consome o hook, mostra ícone (`lucide-react`, campo `icon_name`, mesmo mapeamento `getIcon()` já usado no Hub) + nome de cada sistema permitido, ordenado por `display_order`.
4. **Navegação**: reaproveita `redirectWithCode(system.link, redirectTo, system.slug)` — sem token cru na URL, sem criar mecanismo de sessão paralelo.
5. **Cada sistema não lista a si mesmo** no próprio menu (mesma lógica implícita que o Hub já aplica ao se autoexcluir via `visivel_no_hub = false`) — assunção de UX razoável, não uma decisão de negócio em aberto.
6. **Ponto de montagem**: o wrapper de layout mais alto de cada app. Não confirmado uniformemente nesta investigação — cada sistema tem um padrão de shell próprio (alguns com `Layout.tsx` compartilhado envolvendo todas as rotas protegidas, outros com header/nav embutido por página). Quem implementar cada sistema precisa confirmar o ponto de montagem real daquele repositório antes de codar, não assumir que todos têm a mesma estrutura de `Layout.tsx` do Hub/CRM.

### Critérios de aceite

- Um usuário logado no sistema A vê, no menu lateral direito, apenas os sistemas para os quais `hub_sistemas_permitidos`/fallback retorna resultado, sempre excluindo Ubiqua — dois usuários com papéis diferentes veem listas diferentes.
- Clicar num item do menu abre o sistema de destino já autenticado, sem tela de login, usando o mesmo mecanismo de troca de código (`sso_code`) da SPEC-007.
- RH passa a se comportar como destino válido de SSO (mesmo teste da SPEC-007: chegar autenticado vindo de outro sistema) antes ou junto da entrada do menu nele.
- O menu não lista o próprio sistema em que o usuário já está, nem Ubiqua em nenhuma circunstância.
- Verificação manual no navegador (golden path: logar → abrir sistema A → usar o menu → chegar no sistema B sem novo login) em pelo menos 3 pares de sistemas diferentes — sem suíte de testes automatizada em nenhum dos apps em escopo, então esse é o critério de aceite real, não "rodar testes".

### Plano de rollback

- Componente/hook novo: reverter é remover o arquivo do repositório via git no Skip de cada sistema — sem migration, sem dado.
- Nenhuma alteração de schema é necessária por esta SPEC (reaproveita `systems`, `hub_sistemas_permitidos`, `cross_system_session_codes` já existentes) — o único trabalho de banco possível seria se a decisão pendente sobre "Hub no menu" exigir alterar a RPC (ver Pendências), e nesse caso o rollback é `CREATE OR REPLACE FUNCTION` de volta à versão atual, documentada acima.

## Realizado

### 2026-08-24

- `useSistemasPermitidos(currentSlug)` criado — versão **autocontida** (resolve o próprio usuário logado via `supabase.auth`, não depende do formato de `useAuth` de cada sistema, que varia muito entre os 10 repositórios). Replica a lógica do Hub (`Dashboard.tsx`): RPC `hub_sistemas_permitidos` com bypass admin e fallback `user_system_access`; sempre exclui `ubiqua` e o próprio sistema atual.
- `SystemSwitcher.tsx` criado — barra retrátil fixa no canto direito (Decisão 2), colapsada mostra só ícones, expande com um clique num botão de toggle (não hover). Hub aparece como link fixo nos satélites (Decisão 1); no próprio Hub, `showHubLink={false}`.
- **Achado durante a implementação, corrigido**: `redirectWithCode` (`cross-system-auth.ts`) tinha divergido entre cópias — Orçamentos/Admin Bancária/CRM já tinham evoluído pra uma versão melhor (mesma aba por padrão via `RedirectOptions.newTab` opcional, `sistema_origem` correto por sistema), enquanto Hub e os demais satélites ainda tinham `sistema_origem: 'hub'` fixo (errado quando o clique parte de outro sistema) e alguns abriam em nova aba (contradizendo a Decisão 3). Padronizados os 10 sistemas para a versão mais evoluída.
- **Achado crítico evitado**: ao ler o `use-auth.tsx` real do RH no Skip antes de publicar, ele já tinha a checagem `hasAccess`/`hub_pode_executar` (SPEC-069) que o checkout local (git) do submodule não tinha — publicar por cima da edição feita sobre o checkout local teria apagado essa proteção de acesso em produção. Reconstruída a edição em cima do conteúdo real do Skip.
- RH ganhou `src/lib/cross-system-auth.ts` (não existia, nem no git nem no Skip) e `consumeCodeFromUrl('rh')` wired no bootstrap de auth (mesma guarda de corrida `initialized` já usada em `cadastro-lucenera`) — passa a ser destino SSO válido pela primeira vez.
- Montado em todos os 10 sistemas (arquivo de wrapper por sistema, ver tabela nas Pendências): Hub, Orçamentos, Admin Bancária, CRM, Necessidade de Compra, Logística, Cadastro, RH, Dashboard Financeiro satélite, Separação Parcial.
- QA do Skip (`skip_project_apply_changes`) limpo nos 10 antes de publicar; publicado em produção nos 10 (`skip_project_publish`) com autorização explícita do usuário.
- `AI_DB_CONTEXT.md` de RH e `supabase/db/domains/hub_ti.md` **não atualizados nesta rodada** — ficam como pendência (ver abaixo).

## Mal-entendido registrado (2026-09-16)

Ao reportar um "Card" grande demais cobrindo informações da Separação Parcial, interpretei errado como sendo o `SystemSwitcher` e mudei a posição dele (canto direito centralizado → canto inferior direito). **Usuário corrigiu**: o pedido nunca foi sobre o menu lateral — era sobre diminuir um card próprio da tela de Separação Parcial (ainda não identificado nesta SPEC; ver SPEC-149/SeparacaoParcialPage.tsx ou pedido original do usuário). Reposicionamento do `SystemSwitcher` **revertido** (`db22604`, Skip 48801 v0.0.43) — o componente está de volta à posição original desta SPEC. O card real que precisa diminuir é tratado fora desta SPEC.

## Pendências

- [x] Confirmar o `projectId` real do Skip para `separacao-parcial` — **confirmado via `skip_project_list` (org 11458) em 2026-08-24: `48801`**, nome do projeto "Separação Parcial". Bate com a menção do CHANGELOG.
- [x] Confirmar, sistema por sistema, o arquivo real de wrapper de layout — **confirmado via busca direta no working tree local em 2026-08-24**:

| Sistema | Arquivo de wrapper |
|---|---|
| Hub | `src/components/Layout.tsx` |
| Orçamentos | `src/components/Layout.tsx` |
| Admin Bancária/Financeiro | `src/components/Layout.tsx` |
| CRM | `src/components/Layout.tsx` |
| Necessidade de Compra | `src/components/Layout.tsx` |
| Cadastro | `src/components/Layout.tsx` |
| RH | `src/components/Layout.tsx` |
| Dashboard Financeiro satélite | `src/components/Layout.tsx` |
| Logística | `src/components/layout/AppLayout.tsx` (pasta `layout/`, não arquivo solto) |
| Separação Parcial | **nenhum** — não tem `Layout.tsx`/`layout/`; só `src/App.tsx`. Precisa confirmar durante a implementação onde as rotas autenticadas são montadas nesse app (mais simples/recente que os demais). |

- [ ] Avaliar separadamente (fora desta SPEC) se o gap de enforcement descrito na SPEC-063 (a maioria dos sistemas satélite só verifica sessão válida, não permissão granular, para bloquear URL direta) deve ser fechado em conjunto — esta SPEC não resolve isso, só decide o que aparece no menu.
- [x] **`separacao-parcial` resolvido (2026-09-16)**: sem divergência real com o origin (nunca tinha sido commitado ali, diferente do caso do Cadastro) — comitado (`c9407ca`) e pushado.
- [ ] **Achado (2026-09-16), ainda pendente para os outros 7**: o `git status` local de `cadastro-lucenera-b86fe`, `central-lucenera-dashboard-1c9ba`, `compras-lucenera-3o23t98ee`, `dashboard-lucenera-b02z85wa3`, `lucenera-logistics-b7cd1`, `retorno-bancario-bradesco-5392a` e `dashboard-rh-lucenera-5fe9c` mostra `App.tsx`/`cross-system-auth.ts` modificados e `SystemSwitcher.tsx`/`useSistemasPermitidos.ts` como arquivos novos, **nenhum commitado** — todos com `mtime` de 2026-08-24, a mesma data desta SPEC. Isso é consistente com o padrão já conhecido do projeto ([[feedback_skip_deploy_separate_tree]]): a publicação em produção (linha 155 do "Realizado") foi feita direto na working tree do Skip, e o checkout local nunca foi sincronizado/commitado de volta para o git depois. **Não é evidência de que a feature esteja quebrada em produção** — é uma lacuna de controle de versão. Recomenda-se, antes de considerar esta SPEC 100% encerrada: (1) ler cada arquivo via `skip_file_read` e comparar com o checkout local (confirmar que são idênticos ou reconciliar diferenças); (2) commitar e pushar nos 8 sistemas; (3) atualizar o ponteiro do submódulo no repo central. Ver [[feedback_rollout_pendente_8_sistemas_nao_tocar]] (memória de sessão).
