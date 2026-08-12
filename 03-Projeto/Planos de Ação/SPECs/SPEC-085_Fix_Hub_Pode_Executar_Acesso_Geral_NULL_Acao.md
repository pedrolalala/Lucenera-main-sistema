# SPEC-085: Fix `hub_pode_executar` — checagem de acesso geral (p_acao NULL) sempre negava

**Data:** 2026-08-12
**Escopo:** Banco de dados (função compartilhada, usada por todos os sistemas via `hub_pode_executar`)
**Status:** Aplicado em produção

## Relato do usuário

Débora, com o papel `compras_e_entregas` (Cadastro em consulta, Necessidade de Compra e Sistema de Entregas), não conseguia acessar o sistema "Necessidade de Compra" — a tela mostrava "Acesso negado".

## Investigação

1. Conferido `usuario_papeis`: Débora tem o papel `compras_e_entregas` atribuído corretamente.
2. Conferido `papel_permissoes` desse papel para o sistema `necessidade-de-compra`: tem `criar`, `editar` e `visualizar` concedidos. O dado estava certo.
3. `04-Sistemas/compras-lucenera-3o23t98ee` local (git) não tinha nenhuma checagem de permissão em `ProtectedRoute.tsx` (só checava login) — mas o **Skip publicado** (projectId `40326`) tinha uma versão mais nova, com `hasAccess === false` renderizando exatamente "Acesso negado". `hasAccess` vem de `use-auth.tsx` chamando `hub_pode_executar(usuario_id, 'necessidade-de-compra', null, null)` — checagem de acesso ao sistema inteiro, sem ação/módulo específicos.
4. Testado o RPC direto no banco pro usuário da Débora: **retornava `false`**, apesar da permissão estar concedida.

## Causa raiz

Em `hub_pode_executar`, a checagem por papel usava:
```sql
WHERE ... AND (pp.acao IS NULL OR pp.acao = p_acao)
```
Quando o chamador passa `p_acao = NULL` (pedindo "esse usuário tem acesso a este sistema, seja qual for a ação" — o uso real de `ProtectedRoute`/gate de tela inteira), a comparação `pp.acao = p_acao` resulta em `NULL` em SQL (nunca `TRUE`), mesmo que `pp.acao` tenha um valor real como `'visualizar'`. Como nenhuma linha de `papel_permissoes` do papel `compras_e_entregas` para `necessidade-de-compra` tinha `acao IS NULL` (só linhas específicas: criar/editar/visualizar), a condição OR nunca virava `TRUE` — a função sempre retornava `false` para essa checagem de acesso geral, silenciosamente.

**Escopo real do bug** (query rodada antes do fix): **16 combinações de papel/sistema** sem nenhuma linha `acao IS NULL` — `administracao_comercial` (cadastro, necessidade-de-compra, orcamentos), `compras_e_entregas` (cadastro, necessidade-de-compra, separacao-parcial, logistica), `equipe_entrega` (orcamentos, separacao-parcial, logistica), `equipe_projetos` (cadastro, crm, necessidade-de-compra, orcamentos, separacao-parcial, logistica). Qualquer app satélite que cheque "tenho acesso a este sistema" com `p_acao = NULL` para esses papéis estava com esse gate quebrado — não era exclusivo da Débora nem de Necessidade de Compra.

O mesmo padrão de bug existia na checagem de exceções individuais (`usuario_permissao_excecoes`, `e.acao = p_acao`), sem efeito prático hoje (só 1 exceção cadastrada no banco, com ação específica não-nula, não relacionada a este caso) mas corrigido por consistência.

## Fix

`CREATE OR REPLACE FUNCTION public.hub_pode_executar` — adiciona `p_acao IS NULL OR` nas duas checagens (exceção individual e permissão por papel). Puramente aditivo: amplia exatamente o caso "chamador pergunta acesso geral" pra casar com qualquer linha de ação específica; não altera nenhuma checagem de ação específica já em uso (aprovar/criar/editar/visualizar continuam exigindo bater exatamente).

Migration: `supabase/db/migrations/20260812_102_fix_hub_pode_executar_null_acao/001_fix_hub_pode_executar_null_acao.sql`.

## Verificação

- Antes do fix: `hub_pode_executar(debora_id, 'necessidade-de-compra', null, null)` → `false`.
- Depois do fix: mesma chamada → `true`. `hub_pode_executar(debora_id, 'necessidade-de-compra', null, 'visualizar')` → `true` (permissão real dela). `hub_pode_executar(debora_id, 'necessidade-de-compra', null, 'aprovar')` → `false` (ação que ela **não** tem — confirma que o fix não passou a conceder mais do que o cadastrado).
- Spot-check num segundo papel afetado (Mariane, `equipe_projetos`): acesso geral a `crm`, `necessidade-de-compra` e `logistica` (todos concedidos pelo papel) confirmados `true` depois do fix.

## Não corrigido nesta SPEC

O submodule local `compras-lucenera-3o23t98ee` não tem a checagem de `hasAccess` em `ProtectedRoute.tsx` que já existe no Skip publicado — checkout local desatualizado (mesmo padrão já visto várias vezes nesta sessão com outros sistemas). Não sincronizado aqui por não ser necessário pro fix (o bug era 100% no banco, a Edge/RPC já estava certa depois da correção) — só registrado pra não confundir numa sessão futura.
