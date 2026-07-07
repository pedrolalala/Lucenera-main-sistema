# Migration 20260707_028 - SPEC-008 (Conciliação de Retorno Bancário e Baixa Automática de Parcelas)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-008_Conciliacao_Retorno_Bancario_Baixa_Parcelas.md`.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_tabelas.sql` | `retorno_bancario_arquivos`, `retorno_bancario_registros`, RLS de leitura para `authenticated`. |
| `002_rpc.sql` | `processar_retorno_bancario` (baixa/divergência/não-encontrado em uma transação). |
| `003_fix_trigger_parcelas_sem_updated_at.sql` | Correção de bug pré-existente (ver abaixo), aprovada pelo usuário. |
| `004_fix_hash_unique_para_forcar.sql` | Correção de bug próprio encontrado em teste (ver abaixo), aprovada pelo usuário. |

## Correções em relação ao desenho original da SPEC

- `public.transacao_tipo` real é `('receita','despesa','transferencia')`, não inclui `'entrada'` (placeholder usado no desenho da SPEC) — a RPC usa `'receita'`.
- `boletos.nosso_numero` já tinha `UNIQUE` (`boletos_nosso_numero_key`) — a pendência da SPEC sobre isso já estava resolvida.
- `projeto_parcelas.transacao_id` já existe na tabela (não estava no desenho original da SPEC) — a RPC agora popula essa coluna, melhorando a rastreabilidade parcela → transação.

## Bugs encontrados e corrigidos durante a implementação (autorizados pelo usuário via pergunta explícita)

1. **Trigger órfão em `projeto_parcelas`** (`003_fix_trigger_parcelas_sem_updated_at.sql`): o trigger `update_parcelas_updated_at` chamava `update_updated_at_column()`, que faz `NEW.updated_at = NOW()` incondicionalmente — mas `projeto_parcelas` não tem coluna `updated_at`. Qualquer `UPDATE` nessa tabela falhava em produção, inclusive o update direto que `RetornoBoletos.tsx` já tentava fazer antes desta SPEC. Nenhum frontend depende de `projeto_parcelas.updated_at` (confirmado por grep em Orçamentos e Financeiro). Corrigido removendo o trigger.
2. **`hash_conteudo UNIQUE` impedia forçar reprocessamento** (`004_fix_hash_unique_para_forcar.sql`): ao testar o fluxo de "forçar", a nova linha de auditoria com o mesmo hash colidia com a constraint `UNIQUE`. O bloqueio de reprocessamento normal já é feito na própria RPC (`EXISTS ... WHEN NOT p_forcar`), então a constraint virou índice comum.

## Decisão de permissão

RPC liberada para qualquer `authenticated` (mesmo padrão de `aprovar_orcamento_financeiro`). Não há distinção de role para quem processa retorno bancário nesta rodada.

## Aplicado em

2026-07-07, via `psql "$SUPABASE_DB_URL"` para os 4 arquivos em sequência.

## Verificação pós-aplicação

Executada em transação com `ROLLBACK` (nenhum dado de teste ficou no banco), usando um boleto real (`ORC-ORC0005-P1/P2`, `valor=1318.48`):

1. **Aplicado**: valor exato → `boletos.status='pago'`, `projeto_parcelas.status='paga'`, `transacoes` criada com `tipo='receita'`, `projeto_parcelas.transacao_id` populado.
2. **Divergente**: valor diferente → nada é alterado em `boletos`/`projeto_parcelas`/`transacoes`, registro fica `divergente`.
3. **Não encontrado**: `nosso_numero` inexistente → registro `nao_encontrado`, resto do lote não é abortado.
4. **Bloqueio de reprocessamento**: mesmo hash sem `p_forcar` → exceção clara, nada é alterado.
5. **Forçar reprocessamento**: mesmo hash com `p_forcar=true` → processa normalmente, novo registro em `retorno_bancario_arquivos` com `forcado=true`.

## Depois da aplicação

- Reextrair `supabase/db/current/`.
- Marcar SPEC-008 como implementada em "Realizado" (backend). Frontend (`RetornoBoletos.tsx`) é o próximo passo desta mesma SPEC.
- Homologação com arquivo de retorno real e homologação bancária do CNAB (`FIN-08`) continuam como pré-requisitos separados antes de produção real, conforme a própria SPEC já registrava.
