---
titulo: "SPEC-123 — Auditoria de performance: carregamento inicial lento (CRM, Cadastro e padrão replicado nos 10 sistemas)"
status: pendente
data_ultima_modificacao: 2026-08-28 (itens 1, 2 e 3 implementados e publicados; itens 4-6 continuam só diagnosticados)
sistemas_envolvidos:
  - CRM (lucenera-crm-3bd29, Skip 24580) — evidência principal (Clientes.tsx, Arquitetos.tsx, Projetos.tsx/getProjetos())
  - Cadastro (cadastro-lucenera-b86fe, Skip 36668) — evidência principal (Pecas.tsx/getProdutosEstoqueFiltradoBatched)
  - Padrão replicado (auth duplicado + zero code-splitting) — provavelmente os outros 8 sistemas também, ver Pendências
  - RH (dashboard-rh-lucenera-5fe9c) — referência técnica: único sistema que já faz code-splitting por rota
dependencias:
  - SPEC-116 (busca universal — já tinha identificado "client-side, array já carregado" como padrão em várias telas, sem tratar como problema de performance)
  - SPEC-120 (SystemSwitcher / useSistemasPermitidos — replicado nos 10 sistemas, parte do diagnóstico de query duplicada)
---

# SPEC-123 — Auditoria de performance: carregamento inicial lento

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Esta é uma SPEC de **diagnóstico e planejamento** — nenhuma mudança de código foi feita ainda. O objetivo é alinhar o plano antes de implementar.

## Origem

Pedido direto do usuário: o sistema está demorando para abrir, suspeita de carregamento de todos os dados de uma vez sem paginação/lazy loading. Volumes informados: ~4.000+ peças, 2.646 clientes, 864 arquitetos, 3.714 projetos.

## Metodologia

Nada abaixo é suposição — cada item foi confirmado lendo o código real (`04-Sistemas/`) e/ou consultando o banco de produção direto (índices via `pg_indexes`, contagem de linhas e tamanho de tabela via `psycopg2`). Sistemas auditados em profundidade: CRM e Cadastro (as duas telas com os maiores volumes citados pelo usuário). Os outros 8 sistemas replicam o mesmo código-base de autenticação (confirmado por grep) e muito provavelmente o mesmo padrão de tela — ver Pendências para o que falta confirmar tela a tela.

## 1. DIAGNÓSTICO

### 1.1 Achado que NÃO é o problema (índices já existem)

Antes de tudo: **as tabelas grandes já têm índice em toda coluna usada em filtro/join** — `produtos` (marca_id, categoria_id, sku, referencia, codigo_produto, ativo — 16 índices), `contatos` (tipo, cidade/estado, cpf/cnpj, e 3 índices de busca textual: GIN trigram, GIN unaccent+trigram, tsvector), `projetos` (cliente_id, arquiteto_id, responsavel_id, status, empresa_id, tsvector). Consultado direto em produção (`pg_indexes`). **Não é um problema de índice faltando** — descartar essa hipótese economiza esforço em algo que não vai mover a agulha.

Tamanho real das tabelas em produção (`pg_total_relation_size`): `produtos` 6,2 MB, `contatos` 5,8 MB, `projetos` 6,4 MB. Não é "big data" — o volume total cabe inteiro na memória de qualquer navegador moderno. O problema não é volume absoluto, é **como e quando** esse volume é buscado e processado.

### 1.2 Causa raiz #1 — telas de alto volume buscam a tabela inteira, sem paginação, e filtram no navegador

Confirmado em 3 telas do CRM e 1 do Cadastro (arquivo + linha):

| Tela | Arquivo:linha | Query | Problema |
|---|---|---|---|
| Clientes (CRM) | `pages/contatos/Clientes.tsx:142-147` | `.from('contatos').select('*').eq('tipo','cliente').order('created_at').limit(10000)` | Busca as 2.646 linhas inteiras (todas as colunas) a cada vez que a tela monta. Filtro por nome/cidade/status acontece depois, em JS (`filteredClients`, linha 161). |
| Arquitetos (CRM) | `pages/contatos/Arquitetos.tsx:189` | `.from('contatos').select('*').eq('tipo','arquiteto')` | Mesmo padrão, **sem nem um `.limit()`** — busca as 864 linhas inteiras sempre. |
| Projetos (CRM) | `services/projetos.ts:31-134` (`getProjetos()`) | `while(hasMore)` paginando de 1000 em 1000, **sequencialmente** (`await` dentro do loop, não paralelo), com `select('*')` + 6 relações embutidas por linha (`cliente`, `arquiteto`, `responsavel`, `engenheiro`, `projeto_arquitetos(...)`, `responsavel_funcionario`, **`projeto_parcelas(*)`** — 1:N) | Para 3.714 projetos: 1 query prévia (`vw_dashboard_crm_fechamento`, sem limite) + 4 idas ao banco em série (1000+1000+1000+714) antes da tela renderizar qualquer linha. Confirmado no banco: join projetos×parcelas = 3.864 linhas (baixo fan-out, mas ainda assim 4-5 round-trips sequenciais). Filtro (`filteredProjetos`, linha 271) também é 100% client-side. |
| Peças e Produtos (Cadastro) | `services/produtos.ts` (`getProdutosEstoqueFiltradoBatched`) | Sem termo de busca: pagina em lotes de 500 até trazer os ~4.700 produtos ativos, cada um com join de marca/categoria/estoque_itens | Abrir a tela **sem digitar nada** já dispara a busca completa do catálogo. (Já documentado como comportamento conhecido nas SPEC-100/116/122; nunca foi tratado como problema de performance até agora.) |

Em nenhum dos 4 casos existe paginação de verdade (nem no backend nem na UI) — a "paginação em lotes" que existe (`step`/`batchSize`) é só para não estourar limite de URL/payload numa única request, não para limitar quanto é carregado. A tela só renderiza depois que **tudo** chegou.

### 1.3 Causa raiz #2 — checagem de permissão duplicada em toda navegação, em todos os sistemas

Cada um dos ~10 sistemas replica dois hooks independentes que checam a mesma coisa de formas diferentes, ambos disparando ao montar qualquer página protegida:

- `hooks/use-auth.tsx` — ao resolver `user.id`, dispara **2 queries em paralelo entre si**: RPC `hub_pode_executar` (gate de acesso ao sistema) e `usuarios.select('role')` (grep confirmou esse padrão replicado em Cadastro, Compras, RH, Retorno Bancário, CRM — pelo menos 5 dos 10).
- `hooks/useSistemasPermitidos.ts` (SPEC-120, usado pelo `SystemSwitcher` do menu lateral, presente em todos os 10) — faz **de novo** `supabase.auth.getUser()` e **de novo** `usuarios.select('role')` (idêntico ao que `use-auth.tsx` já buscou), e só depois decide entre `systems` (bypass admin), RPC `hub_sistemas_permitidos`, ou fallback `user_system_access`.

Resultado: toda vez que uma página carrega, saem **pelo menos 4 requisições relacionadas a permissão** (2 de cada hook) quando 2 bastariam, porque os dois hooks não compartilham o que já sabem um do outro. Isso não trava a tela sozinho (o `ProtectedRoute` não espera `hasAccess`/`useSistemasPermitidos` para renderizar os filhos), mas soma latência de rede real em paralelo com o carregamento de dados da página — e cada round-trip para o Supabase tem custo de rede não-trivial (confirmado empiricamente: consultas simples de `count(*)` levaram 270-590ms cada a partir deste ambiente).

### 1.4 Causa raiz #3 — nenhum sistema divide o bundle JavaScript por rota (exceto um)

`App.tsx` de cada sistema importa **todas** as páginas de forma estática no topo do arquivo (`import Clientes from './pages/contatos/Clientes'`, etc.) — confirmado no CRM (13 páginas importadas eager) e por grep nos demais. Isso significa que o JS de toda tela do sistema (Clientes, Projetos, Arquitetos, Orçamentos, Configurações...) entra no mesmo bundle inicial, baixado e parseado antes da primeira tela aparecer — mesmo que o usuário só precise abrir uma tela.

**Achado importante**: o sistema de RH (`dashboard-rh-lucenera-5fe9c/src/App.tsx`) **já resolve isso em produção** — usa `lazy(() => import(...))` + `<Suspense>` para todas as 13 páginas. Não é preciso inventar um padrão novo: é só replicar o que já está validado e rodando.

### 1.5 Não investigado nesta rodada (ver Pendências)

- Confirmação tela-a-tela nos outros 8 sistemas (Estoque/Compras, Logística, RH fora do padrão de auth, Admin Bancária, Orçamentos, Hub, RH, Central de Solicitações) — a amostra de CRM+Cadastro já é suficiente para confirmar o padrão arquitetural, mas cada tela precisa ser conferida individualmente antes de mexer nela.
- Medição de tempo real "ponta a ponta" no navegador (Network tab / Lighthouse) para cada tela antes/depois — o diagnóstico aqui é por leitura de código + medição server-side, não por captura de timing real de usuário.
- `Engenheiros.tsx`, `Eletricistas.tsx`, `Fornecedores.tsx` (CRM) não lidos linha a linha nesta rodada, mas o padrão em `Clientes.tsx`/`Arquitetos.tsx` (mesma tabela `contatos`, filtrando por `tipo`) é forte indício de que sofrem do mesmo problema.

## 2. PLANO DE AÇÃO PRIORIZADO

| # | Prioridade | Ação | Arquivos afetados | Risco | Esforço | Impacto esperado |
|---|---|---|---|---|---|---|
| 1 | **Baixo risco / imediato** | Code-splitting por rota (lazy + Suspense) em todos os `App.tsx`, replicando o padrão já em produção no RH | `App.tsx` de cada um dos 9 sistemas restantes | Muito baixo — puramente estrutural, zero mudança de comportamento visível, padrão já validado em produção | Baixo (1 sistema por vez, ~15-30 min cada, mecânico) | Reduz o bundle inicial de cada sistema para só o código da tela aberta — melhora especialmente o primeiro carregamento (login → primeira tela) |
| 2 | **Baixo risco / imediato** | Adicionar `.limit()` sensato (ex.: 50-100) + paginação real (botão "carregar mais" ou paginação de tabela) em `Arquitetos.tsx`, com o mesmo padrão *visual* que a tela já usa hoje | `pages/contatos/Arquitetos.tsx` | Baixo — tela tem 864 linhas, cabe fácil numa paginação simples sem mudar nenhuma regra de negócio | Baixo | Elimina a única query da CRM sem `.limit()` nenhum; menor payload por abertura de tela |
| 3 | **Médio risco** | Consolidar `use-auth.tsx` + `useSistemasPermitidos.ts` pra não duplicar `usuarios.select('role')` e a resolução de `userId` — `useSistemasPermitidos` passa a receber o `user`/`role` já resolvidos por `useAuth()` em vez de resolver de novo | `hooks/use-auth.tsx` + `hooks/useSistemasPermitidos.ts` (replicado nos 10 sistemas) | Médio — mexe em código de autenticação/permissão usado em todo lugar; precisa de teste ao vivo em cada sistema antes de publicar, um de cada vez | Médio (mesma mudança, 10 repositórios) | Corta pela metade as requisições de permissão por navegação; ganho mais perceptível em conexões lentas/alta latência |
| 4 | **Médio risco** | Paginação real (server-side, com `.range()`) em Clientes.tsx e Peças e Produtos, substituindo "buscar tudo até 10000/500-em-500" por página de 20-50 itens + busca server-side já existente (`buscar_produtos_fuzzy`, ou equivalente novo pra contatos) | `pages/contatos/Clientes.tsx`, `services/produtos.ts` (Cadastro) | Médio — muda a forma de carregar dado, precisa preservar 100% do comportamento de filtro/busca já existente (SPEC-116/122); risco de regressão nos filtros combinados | Médio-Alto (por tela) | Maior ganho absoluto de payload/tempo nas duas telas mais citadas pelo usuário |
| 5 | **Estrutural maior** | Reescrever `getProjetos()` para não buscar as 3.714 linhas com todas as relações de uma vez — paginação real na tela de Projetos + mover o `projeto_parcelas(*)` (que só é usado no detalhe/sheet) pra ser buscado só quando o usuário abre um projeto específico, não na listagem | `services/projetos.ts`, `pages/Projetos.tsx` | Alto — `getProjetos()` alimenta múltiplos filtros dinâmicos (`getUnique()` sobre responsável/arquiteto/engenheiro/cidade, anos de fechamento) que hoje dependem do dataset completo estar em memória; paginar exige repensar de onde vêm as opções desses filtros (RPC de distinct values, por exemplo) | Alto | Maior ganho single-point nesta auditoria — é a query mais pesada encontrada — mas é a que mais precisa de desenho cuidadoso pra não quebrar os filtros dinâmicos |
| 6 | **Estrutural maior** | Realtime subscription de `Clientes.tsx` (refetch completo em qualquer mudança em `contatos` tipo=cliente) — trocar por atualização incremental (merge da linha que mudou) em vez de re-buscar as 2.646 linhas inteiras a cada evento | `pages/contatos/Clientes.tsx` | Médio-Alto — precisa garantir que o merge incremental não deixe a lista dessincronizada em nenhum caso (insert/update/delete) | Médio | Só importa sob uso concorrente (vários usuários mexendo em clientes ao mesmo tempo) — menor prioridade que os itens acima, mas fica documentado |

## 3. IMPLEMENTAÇÃO SUGERIDA (as 3 de maior impacto / menor risco)

### 3.1 Code-splitting por rota (item #1)

**Antes** (padrão atual em 9 dos 10 sistemas, exemplo do CRM):
```tsx
import Clientes from './pages/contatos/Clientes'
import Arquitetos from './pages/contatos/Arquitetos'
// ...13 imports estáticos
```

**Depois** (padrão já em produção no RH, `dashboard-rh-lucenera-5fe9c/src/App.tsx`):
```tsx
import { Suspense, lazy } from 'react'

const Clientes = lazy(() => import('./pages/contatos/Clientes'))
const Arquitetos = lazy(() => import('./pages/contatos/Arquitetos'))
// ...

// dentro do JSX de rotas:
<Suspense fallback={<LoadingFallback />}>
  <Routes>...</Routes>
</Suspense>
```
Nenhuma mudança de comportamento — mesmas rotas, mesmos componentes, só o momento em que o código é baixado muda.

### 3.2 Limite em Arquitetos.tsx (item #2)

**Antes**:
```ts
const { data, error } = await supabase.from('contatos').select('*').eq('tipo', 'arquiteto')
```

**Depois** (mesmo padrão que outras telas do próprio ecossistema já usam):
```ts
const { data, error } = await supabase
  .from('contatos')
  .select('*')
  .eq('tipo', 'arquiteto')
  .order('nome')
  .limit(1000) // 864 hoje; teto de segurança, não muda o resultado atual
```
Passo intermediário seguro antes de uma paginação de verdade (item #4) — hoje simplesmente não existe nenhum teto.

### 3.3 Consolidar as duas checagens de auth (item #3)

**Antes**: `useSistemasPermitidos(currentSlug)` resolve `userId` do zero (`getUser()` + `onAuthStateChange` próprios).

**Depois**: recebe o usuário já resolvido por `useAuth()` como parâmetro:
```ts
// App.tsx / Layout.tsx
const { user, role } = useAuth()
const { sistemas, loading } = useSistemasPermitidos(currentSlug, user?.id, role)
```
```ts
// useSistemasPermitidos.ts — remove o próprio getUser()/onAuthStateChange,
// recebe userId e role (quando role === 'admin' já sabe pular direto pro
// bypass, sem nova query em `usuarios`)
export function useSistemasPermitidos(currentSlug: string, userId?: string, role?: string | null) { ... }
```
Elimina 2 das 4 requisições de permissão por navegação (1 `getUser()` e 1 `usuarios.select('role')` duplicados).

## 4. VALIDAÇÃO — critérios de aceite por mudança

- **Code-splitting (#1)**: navegar entre todas as rotas do sistema depois da mudança — cada tela deve carregar e funcionar exatamente igual a antes (mesmos dados, mesmos formulários, mesmas ações). Verificar na aba Network do navegador que o JS de uma tela só é baixado quando essa rota é visitada pela primeira vez.
- **Limite em Arquitetos (#2)**: contagem de arquitetos exibidos deve ser igual à contagem atual (864, ou o que for no momento do teste) — comparar antes/depois. Buscar por nome deve continuar achando qualquer arquiteto cadastrado.
- **Consolidação de auth (#3)**: testar login com pelo menos 3 papéis diferentes (admin, um papel legado, um papel novo do SPEC-069) em pelo menos 2 sistemas — o menu lateral (SystemSwitcher) deve mostrar exatamente os mesmos sistemas que mostrava antes da mudança, e o gate de acesso (`hasAccess === false` → "Acesso negado") deve continuar bloqueando quem não tem permissão.
- **Paginação real (#4/#5)**: para cada filtro combinado que existe hoje na tela (ex.: nome + cidade + status em Clientes; responsável + arquiteto + cidade + ano/mês de fechamento em Projetos), confirmar que o resultado filtrado é idêntico ao que a versão atual (client-side, dataset completo) retornava — não pode haver filtro que "some" porque as opções do dropdown deixaram de vir do dataset completo.
- Todas as mudanças: sem suíte de testes automatizada em nenhum dos 10 sistemas (padrão já conhecido do projeto) — validação é sempre manual, ao vivo no navegador, golden path + pelo menos 1 caso de borda por tela alterada.

## Realizado

### 2026-08-28

- **Item 2 (limite em Arquitetos)** — implementado exatamente como planejado: `.order('nome').limit(1000)` adicionado em `Arquitetos.tsx` (CRM, Skip 24580). Publicado.
- **Item 1 (code-splitting por rota)** — implementado nos 9 sistemas que não tinham (RH já tinha, referência): CRM, Cadastro, Compras, Logística, Admin Bancária, Orçamentos, Dashboard Financeiro, Separação Parcial, Hub. Mesmo padrão `lazy()` + `<Suspense>` do RH, replicado preservando a estrutura de rotas de cada sistema (alguns têm múltiplos `<Routes>` em branches diferentes — ex.: Compras tem um branch só para `/login`; cada branch ganhou seu próprio `<Suspense>`). **Bug pego antes de publicar**: na primeira versão do Cadastro, `<Login />` (lazy) ficava fora do `<Suspense>` porque o componente decidia entre login/rotas com `if (!user) return <Login />` antes do bloco `<Suspense><Routes>`; corrigido movendo a decisão pra dentro do `<Suspense>` (ternário). QA automático do Skip (build+lint+test) passou nos 9; testado ao vivo depois de publicar em Hub, Orçamentos, CRM e Cadastro (dados carregando normalmente, sem regressão visível).
- **Item 3 (consolidar auth) — escopo revisado durante a implementação**: ao ler `SystemSwitcher.tsx` (SPEC-120) de perto, achei um comentário explícito dizendo que `useSistemasPermitidos` foi feito **propositalmente autocontido** — resolve o próprio usuário sozinho pra não depender do formato de `useAuth()` de cada sistema (que varia: `role`, `profile.role`, `user.app_role`, alguns nem têm). O plano original desta SPEC (passar `user`/`role` de fora pra dentro do hook) teria desfeito essa decisão de arquitetura deliberada. Achado reportado ao usuário antes de codar; decisão: manter os dois hooks autocontidos e resolver a duplicação só com um **cache leve em memória** (por aba, por `userId`) num arquivo novo `src/lib/usuario-role-cache.ts`, compartilhado entre `use-auth.tsx` e `useSistemasPermitidos.ts` só onde as duas fazem literalmente a mesma query (`usuarios.select('role')`).
  - **Achado adicional ao ler os 10 `use-auth.tsx`/`AuthContext.tsx` completos**: a duplicação real é muito mais estreita do que a hipótese original desta SPEC. Só **CRM e RH** têm de fato a mesma query (`usuarios.select('role')`) duplicada entre os dois hooks. Os outros 8 não duplicam: Cadastro/Compras/Admin Bancária só checam `hasAccess` (sem buscar `role` separadamente), Orçamentos busca uma coluna extra (`can_approve_quotes`, formato incompatível com o cache), Dashboard Financeiro busca `empresa_id` de `funcionarios` (não `role`), Hub busca `usuarios.select('*')` num único lugar (não usa `useSistemasPermitidos` nele mesmo, não precisa), Logística e Separação Parcial não buscam `role` nenhuma.
  - Aplicado: `usuario-role-cache.ts` novo + `useSistemasPermitidos.ts` usando o cache em **9 sistemas** (todos exceto Hub, que não usa esse hook). `use-auth.tsx` também usando o cache (dedup real com `useSistemasPermitidos`) só em **CRM e RH** — os dois únicos onde a query duplicada existia de fato.
  - Testado ao vivo via `javascript_tool` (as ferramentas de árvore de acessibilidade/screenshot ficaram instáveis nesta sessão, aparentemente por interferência de uma extensão do Chrome — não é bug do app): confirmado que o menu "Trocar de sistema" no CRM lista corretamente os 10 sistemas depois da mudança, sem erro de console.

## Plano de rollback

- Item #1 (lazy loading): reverter é trocar `lazy(() => import(...))` de volta pra `import` estático — mudança isolada em 1 arquivo por sistema, sem tocar em banco.
- Item #2 (limite): reverter é remover o `.limit()` — sem risco de perda de dado (só leitura).
- Item #3 (consolidar auth): reverter é devolver `useSistemasPermitidos` pra resolver `userId` sozinho — sem migration, só código de front.
- Itens #4/#5/#6: cada um deve ser feito com uma SPEC própria e mais detalhada antes de codar, dado o risco médio/alto — este documento é o diagnóstico, não a especificação técnica final desses itens.

## Pendências

- [ ] Confirmar tela a tela (grep + leitura) o mesmo padrão nos 8 sistemas não auditados em profundidade nesta rodada.
- [ ] Medir tempo real de carregamento no navegador (antes de qualquer mudança) para ter uma baseline comparável — esta auditoria mediu banco e leu código, não capturou timing de usuário real.
- [ ] Decidir a ordem de rollout dos itens #1/#2/#3 pelos 10 sistemas — um de cada vez, ou em lote por item (ex.: lazy-loading em todos, depois a próxima ação)?
- [ ] Para o item #5 (Projetos): desenhar de onde vêm as opções dos filtros dinâmicos (`getUnique()`) se `getProjetos()` deixar de trazer o dataset completo — provavelmente precisa de uma RPC de "valores distintos" nova. Não decidido nesta SPEC.
- [ ] `Engenheiros.tsx`, `Eletricistas.tsx`, `Fornecedores.tsx` (CRM): confirmar se têm o mesmo `select('*')` sem paginação antes de decidir se entram no mesmo lote do item #2/#4.
