---
titulo: "SPEC-063 — Dashboard Financeiro: Checar Permissão do Hub Antes de Liberar Acesso"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - Dashboard Financeiro (dashboard-empresa-40d7d, Skip projectId 41135)
---

# SPEC-063 — Dashboard Financeiro: Checar Permissão do Hub Antes de Liberar Acesso

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — `src/hooks/use-auth.tsx` (Skip, `projectId 41135`): adicionar estado `hasAccess` (`boolean | null`), calculado chamando a RPC `hub_pode_executar(p_usuario_id, 'dashboard-financeiro', null, null)` assim que a sessão é conhecida.
- [x] Item 2 — `src/components/Layout.tsx`: além do redirecionamento já existente para `/login` quando não há sessão, bloquear o acesso (tela "Acesso negado" + botão para sair) quando `hasAccess === false`. **Publicado em produção, versão `0.0.22`/`7f37a25`.**
- [x] Item 3 — Atualizar `supabase/db/domains/hub_ti.md` registrando que este é o primeiro sistema migrado para checar `hub_pode_executar` de verdade (em vez de só "estar logado").
- [x] Item 4 — Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Testar em produção: logar como Lana (financeiro@lucenera.com.br) e confirmar que `dashboard-empresa-40d7d.goskip.app` agora barra o acesso; logar como um usuário com papel que inclua "Dashboard Financeiro" e confirmar que continua funcionando normalmente.

## Objetivo

Usuário configurou pelo Hub (Central Lucenera → Papéis) que o papel "gerente" (atribuído à Lana, financeiro@lucenera.com.br) não tem acesso ao sistema "Dashboard Financeiro" — confirmado no banco: `papel_permissoes` do papel "gerente" lista 8 sistemas, e "Dashboard Financeiro" não está entre eles. Mesmo assim, a Lana consegue abrir `https://dashboard-empresa-40d7d.goskip.app` e ver tudo. Causa raiz: esse app não faz **nenhuma** checagem de permissão granular — `Layout.tsx` só verifica se existe uma sessão Supabase válida (`session`), e como todos os sistemas do ecossistema compartilham o mesmo backend de autenticação, qualquer login válido em qualquer sistema Lucenera basta para entrar aqui.

## Decisões aprovadas

- Corrigir **só** o Dashboard Financeiro nesta SPEC — o mesmo padrão de lacuna (nenhum sistema-satélite consulta `hub_pode_executar`, todos só checam "está logado") existe nos outros 7 sistemas, mas isso é uma migração maior, documentada como pendência crônica em `supabase/db/domains/hub_ti.md` ("migrar sistema por sistema para consultar `hub_pode_executar`"), e foi conscientemente deixada de fora do escopo desta SPEC a pedido do usuário.
- Usar a RPC já existente `hub_pode_executar(p_usuario_id, p_system_slug, p_modulo_chave, p_acao)` (SPEC-006), com `p_system_slug = 'dashboard-financeiro'` (slug real confirmado em `systems`) e `p_modulo_chave`/`p_acao` = `null` (checagem de sistema inteiro, mesmo padrão dos grants existentes de "gerente", todos com `modulo_id`/`acao` `NULL`).
- Não criar nenhuma tabela/coluna nova — a permissão já está 100% modelada e correta no banco; só falta o frontend consultá-la.

## Definição da SPEC

### Estado atual confirmado (leitura direta do Supabase real, 2026-08-05)

- `usuarios` de Lana: `role = 'admin'` (campo legado) — **não usado por este app**, então não é a causa do bug aqui (mas é uma inconsistência à parte: o campo legado `usuarios.role` dela nunca foi atualizado quando o papel granular "gerente" foi atribuído; não afeta esta SPEC, só registro).
- `usuario_papeis` de Lana: papel = "gerente".
- `papel_permissoes` do papel "gerente": 8 sistemas concedidos (`modulo_id`/`acao` `NULL` = sistema inteiro), **"Dashboard Financeiro" não está na lista**.
- `hub_sistemas_permitidos(lana_id)` já retorna corretamente a lista sem Dashboard Financeiro — usada hoje só para decidir quais cards aparecem no Hub, não para bloquear acesso direto.
- `dashboard-empresa-40d7d` (Skip `projectId 41135`): `App.tsx` não tem nenhum wrapper de permissão; `Layout.tsx` só verifica `session` (login válido); `use-auth.tsx` não conhece `hub_pode_executar` nem `usuarios.role`. Resultado: qualquer usuário autenticado no ecossistema abre esse app e vê Contas a Pagar, Contas a Receber, Estoque, Sync, Logs — sem exceção.

### Mudança proposta

`use-auth.tsx`:
- Nova função `checkAccess(userId: string)`: `supabase.rpc('hub_pode_executar', { p_usuario_id: userId, p_system_slug: 'dashboard-financeiro', p_modulo_chave: null, p_acao: null })`, seta `hasAccess`.
- Chamada nos dois pontos que já resolvem `empresaId` (`onAuthStateChange` e `getSession`).
- `hasAccess` exposto no contexto (`boolean | null`, `null` = ainda checando).

`Layout.tsx`:
- Mantém o `if (loading) return <spinner>`.
- Mantém `if (!session) return <Navigate to="/login" />`.
- Novo: `if (hasAccess === false) return <AcessoNegado />` — tela simples informando que o usuário não tem permissão para este sistema, com botão "Sair" (`signOut()` + redirect para `/login`).

## Impacto no banco

Nenhum. Reaproveita `hub_pode_executar`, já publicada.

## Impacto em telas

Só `dashboard-empresa-40d7d` (Dashboard Financeiro) ganha a tela de "Acesso negado". Nenhum outro sistema muda.

## Regras de permissão

Usa a mesma fonte de verdade já usada pelo Hub (`hub_pode_executar`/`papel_permissoes`/`usuario_permissao_excecoes`) — nenhuma regra nova é criada, só passa a ser **aplicada** neste app.

## Análise obrigatória de ecossistema

- Depende de `systems`, `papeis`, `papel_permissoes`, `usuario_papeis`, `usuario_permissao_excecoes` (via `hub_pode_executar`) e de `usuarios`/`auth.users` indiretamente. Não depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`.
- Afeta só Hub/TI (aplicação da regra) e o próprio Dashboard Financeiro. Nenhum outro domínio muda.
- Nenhum dado duplicado — reaproveita a RPC existente.
- Nenhuma migration nova, nenhum conflito.
- `supabase/db/domains/hub_ti.md` atualizado para registrar que este é o primeiro sistema efetivamente migrado.

## Critérios de aceite

- Lana (papel "gerente", sem grant para "dashboard-financeiro") loga e é barrada com uma tela clara, não um erro genérico.
- Usuário com papel/exceção que inclua "dashboard-financeiro" continua acessando normalmente.
- Nenhuma regressão nas outras telas do Dashboard Financeiro para quem tem acesso.

## Testes/verificações obrigatórios

- QA pipeline do Skip (`skip_project_apply_changes`) precisa passar antes de publicar.
- Teste manual descrito em "Passos manuais do usuário".

## Achado à parte (fora do escopo desta SPEC, registrado para o usuário)

`src/pages/Login.tsx` deste sistema (`dashboard-empresa-40d7d`) tem **credenciais reais pré-preenchidas no código-fonte**: `useState('pedro@lucenera.com.br')` e `useState('Skip@Pass')` como valores default dos campos de email/senha — visíveis a qualquer pessoa que abra o DevTools ou o código-fonte da página, mesmo sem logar. Isso não foi corrigido nesta SPEC (fora do pedido original) mas é um risco de segurança real e deveria ser removido separadamente.

## Realizado

### 2026-08-05

- SPEC criada.
- `use-auth.tsx`/`Layout.tsx` implementados e publicados em produção no Skip (`projectId 41135`, versão `0.0.22`/`7f37a25`), QA (build+testes) ok antes de publicar.
- Submodule local `dashboard-lucenera-b02z85wa3` sincronizado (só os 2 arquivos tocados, sem mexer no WIP pré-existente de `ContasPagarFoco.tsx`/`ContasReceberFoco.tsx`), commit `af31d93`, push feito.
- `supabase/db/domains/hub_ti.md` e `CHANGELOG.md` atualizados.

## Pendências

- [ ] Teste manual em produção (logar como Lana, confirmar bloqueio) ainda não foi feito pelo usuário.
- [ ] Credenciais reais expostas em `Login.tsx` deste mesmo sistema (`pedro@lucenera.com.br`/`Skip@Pass` pré-preenchidas no código-fonte, visíveis sem login) — achado registrado, correção fora do escopo combinado com o usuário para esta SPEC.
- [ ] Pendência crônica maior, não desta SPEC: migrar os outros 7 sistemas-satélite (CRM, RH, Cadastro, Orçamentos, Necessidade de Compra, Administração Bancária, Sistema de Entregas) para o mesmo padrão de checagem via `hub_pode_executar` — hoje todos só verificam login, não permissão granular.
