# Migration 20260708_029 - SPEC-006 (Permissões Granulares no Hub)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-006_Permissoes_Granulares_no_Hub.md`.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_tabelas.sql` | 7 tabelas novas + `slug`/`visivel_no_hub` em `systems` + linha própria do Hub. RLS restrita a `is_admin()`. |
| `002_rpcs.sql` | `hub_pode_executar`, `hub_sistemas_permitidos` (com correção da semântica de `acao IS NULL`). |
| `003_trigger_auditoria.sql` | Auditoria automática nas 4 tabelas de configuração. |
| `004_seed_papeis_e_migracao.sql` | 5 papéis (espelhando `usuarios.role`), acesso total por papel/sistema, atribuição de usuários, módulo de permissões do próprio Hub (auto-governança). |

## Correções em relação ao desenho original da SPEC

- `systems` não tinha coluna `slug` — adicionada (`UNIQUE`, populada a partir do `name`).
- `pp.acao = p_acao` nunca é verdadeiro quando `acao` é `NULL` (semântica pretendida de "todas as ações") — corrigido para `(acao IS NULL OR acao = p_acao)` em `hub_pode_executar`.
- Nova coluna `systems.visivel_no_hub` para o Hub poder se auto-registrar (FK de `modulos.system_id`) sem aparecer como card na própria Central — resolve o problema óbvio de um sistema linkar para si mesmo.

## Estado local

Implementado localmente em 2026-07-07. Ainda precisa ser aplicado no Supabase
remoto e refletido em `supabase/db/current/` após nova extração do snapshot.

## Verificação pós-aplicação

Checagem esperada antes/depois da aplicação:
- Seed: 5 papéis, 40 `papel_permissoes` (5×8 sistemas), 8 `usuario_papeis`, 1 módulo + 4 ações do Hub.
- `hub_pode_executar(admin, 'orcamentos', qualquer_modulo, 'editar'|'deletar')` → `true`.
- `hub_sistemas_permitidos(admin)` → 7 sistemas (exclui corretamente o Hub via `visivel_no_hub`).
- RLS: usuário `viewer` autenticado direto na tabela `papel_permissoes` → 0 linhas (bloqueado, só admin lê/escreve direto; RPCs continuam acessíveis a todos via `SECURITY DEFINER`).

## Depois da aplicação

- Reextrair `supabase/db/current/`.
- Fase 2: reescrever `AccessTab.tsx`, criar `RolesTab.tsx`/`ExceptionsTab.tsx`, estender `LogsTab.tsx`/`AuditTab.tsx` no Hub.
- Nada consome `hub_pode_executar`/`hub_sistemas_permitidos` fora do Hub ainda — adoção pelos outros 8 sistemas é trabalho futuro, por decisão explícita da SPEC.
