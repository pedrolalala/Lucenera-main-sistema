# Migration 20260721_055 - Correção retroativa de base do domínio de compras

## Contexto

Durante a implementação da SPEC-038 (`03-Projeto/Planos de Ação/SPECs/SPEC-038_Impostos_Numeracao_Vinculo_Parcelas_Desconto_Compras.md`, seção "Achado crítico de grounding"), foi descoberto que a feature "Registrar Compra" nunca havia funcionado de fato: a tabela `public.pedidos_compra`, referenciada pelas RPCs `criar_pedido_compra_de_necessidade` e `criar_pedido_compra_lote` desde 2026-07-10, não existia no banco real. A migration que a criava (`supabase/db/migrations/20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`) havia sido redigida mas nunca aplicada, enquanto os arquivos irmãos (001-003, 005-008) da mesma pasta foram aplicados normalmente. `CREATE FUNCTION` não valida a existência de tabelas referenciadas — só a execução falha — por isso o problema passou despercebido por 11 dias e por diversas SPECs subsequentes (021, 022, 030, 033, 034, 035).

Antes de aplicar as migrations da SPEC-038 em cima de uma base quebrada, o usuário autorizou investigar e corrigir o problema de base primeiro. Esta pasta documenta, em arquivos de migration reproduzíveis, as 3 correções que foram então aplicadas diretamente no Supabase real via `psycopg2`/`SUPABASE_DB_URL` (a aplicação do `004_pedidos_compra.sql` em si já é um arquivo de migration existente e foi apenas executada, sem alterações — não duplicada aqui).

## Arquivos

| Arquivo | Função |
|---|---|
| `001_fk_pedido_compra_itens_pedido_id.sql` | Adiciona a FK `pedido_compra_itens.pedido_id → pedidos_compra.id ON DELETE CASCADE`, que não pôde ser criada na aplicação original de `004_pedidos_compra.sql` porque `pedido_compra_itens` já existia (criada por uma migration anterior sem a tabela `pedidos_compra`), então o `CREATE TABLE IF NOT EXISTS` daquele arquivo não teve efeito sobre a tabela já existente. |
| `002_solicitacoes_compra_colunas_opcionais.sql` | Remove `NOT NULL` de `solicitacoes_compra.projeto_id` e `solicitacoes_compra.quantidade_pedida` — as RPCs de pedido de compra criam solicitações sem projeto/cliente amarrado (necessidade de compra é agregada por produto, ver `supabase/db/domains/estoque_compras.md`, decisão da reunião 08/06/2026), o que só foi detectado ao testar essas RPCs pela primeira vez. |

## Status

**Já aplicada no Supabase real em 2026-07-21** (diretamente via `psycopg2`, com autorização explícita do usuário, antes das migrations `20260721_054_spec038_compras_melhorias`). Este arquivo captura o que já foi feito, para reprodutibilidade em outros ambientes e para manter `supabase/db/current/` reconciliável. Reaplicar é seguro — ambos os scripts são idempotentes.

## Verificação esperada (pós-aplicação)

- `SELECT conname FROM pg_constraint WHERE conrelid = 'public.pedido_compra_itens'::regclass;` inclui `pedido_compra_itens_pedido_id_fkey`.
- `SELECT is_nullable FROM information_schema.columns WHERE table_name = 'solicitacoes_compra' AND column_name IN ('projeto_id', 'quantidade_pedida');` retorna `YES` para ambas.
- `criar_pedido_compra_de_necessidade` e `criar_pedido_compra_lote` executam sem erro de FK ausente ou de `NOT NULL` violado (testado end-to-end em 2026-07-21, ver SPEC-038).
