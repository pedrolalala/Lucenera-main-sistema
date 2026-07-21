# Migration 20260723_057 - SPEC-040 (Necessidade de Compra: granularidade por Item de Orçamento / L Fixo)

## Contexto

SPEC completa: `03-Projeto/Planos de Ação/SPECs/SPEC-040_Necessidade_Compra_Granularidade_L_Fixo.md`.

O usuário quer poder comprar uma peça específica identificada por
`[orçamento_id + produto_id + L Fixo]` (posição/linha do orçamento de
origem), sem misturar com outras posições do mesmo produto em outros
orçamentos — **sem remover** a visão agregada por produto (Fluxo A,
`vw_necessidade_compra`, SPEC-039) que continua em produção. As duas visões
passam a coexistir na mesma tela `/necessidade-compra`, em abas: "Por
Produto" (existente, inalterado) e "Por Item de Orçamento" (novo, Fluxo B).

As 6 decisões de negócio (P-01 a P-06) foram fechadas pelo usuário em
21/07/2026 (ver seção "Decisões do usuário" da SPEC-040).

## ATENÇÃO — esta pasta toca um domínio que não é só Compras

O arquivo `002_aprovar_orcamento_financeiro_l_fixo.sql` recria
`public.aprovar_orcamento_financeiro`, que é a **RPC transacional central do
domínio Orçamentos/Financeiro (SPEC-016)**, não uma função de Compras. Ela é
chamada sempre que um orçamento é aprovado financeiramente, criando
`projeto_itens`, `projeto_parcelas`, `boletos` e a reserva agregada em
`estoque_itens`. Qualquer sistema que dependa desse fluxo (CRM, Financeiro,
Administração Bancária) é afetado por esta migration, mesmo que o motivo da
mudança seja uma necessidade do sistema de Compras
(`compras-lucenera-3o23t98ee`).

A mudança real no corpo da função é mínima e isolada: o `INSERT INTO
public.projeto_itens (...)` passa a gravar duas colunas novas
(`orcamento_item_id`, `l_fixo`) a partir de `oi.id`/`oi.custom_id`, que já
estavam disponíveis no mesmo `SELECT ... FROM orcamento_itens oi`, sem
nenhum `JOIN` ou lógica adicional. Todo o resto do corpo da função
(validações, criação de parcelas/boletos, reserva agregada em
`estoque_itens`, histórico de status) foi copiado literalmente da última
migration real que recriou essa função —
`supabase/db/migrations/20260706_020_normalizacao_aprovacao_financeira_orcamento/001_normalizacao_aprovacao_financeira.sql`
— e conferido, linha a linha, contra `supabase/db/current/03_functions.sql`
antes de escrever esta migration. As duas fontes bateram identicamente, sem
divergência.

**Antes de aplicar em produção**: rodar
`SELECT pg_get_functiondef('public.aprovar_orcamento_financeiro(uuid)'::regprocedure);`
no Supabase real e comparar com o corpo desta migration. A SPEC-040
documenta um achado de possível drift entre `db/current` e o banco real
para uma função *irmã* (`aprovar_orcamento_financeiro_base_spec001`, um
wrapper legado) — não afeta `aprovar_orcamento_financeiro` propriamente
dita (conferida idêntica nas 3 fontes), mas reforça a cautela de conferir
antes de aplicar.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_projeto_itens_orcamento_item_id.sql` | `ALTER TABLE projeto_itens ADD COLUMN orcamento_item_id uuid REFERENCES orcamento_itens(id), ADD COLUMN l_fixo text` + índice. Aditiva, nullable, sem impacto em linhas existentes. |
| `002_aprovar_orcamento_financeiro_l_fixo.sql` | **Ver aviso acima.** Recria `aprovar_orcamento_financeiro` (domínio Orçamentos/Financeiro, SPEC-016) para gravar `orcamento_item_id`/`l_fixo` no `INSERT INTO projeto_itens`. Assinatura de parâmetros inalterada — `CREATE OR REPLACE FUNCTION`, sem `DROP FUNCTION`. |
| `003_backfill_orcamento_item_id_best_effort.sql` | Backfill dos `projeto_itens` já existentes (aprovados antes de 002 existir). Só preenche os pares `(orcamento_id, produto_id)` inequívocos (produto aparece 1 única vez naquele orçamento) — decisão do usuário P-05: casos ambíguos (mesmo produto em 2+ posições do mesmo orçamento) ficam `NULL` permanentemente, sem adivinhação e sem relatório de conferência. Idempotente (`WHERE projeto_itens.orcamento_item_id IS NULL`). |
| `004_vw_necessidade_compra_item_orcamento.sql` | View nova `vw_necessidade_compra_item_orcamento` — 1 linha por `projeto_item_id`, só onde `orcamento_item_id IS NOT NULL` (decisão P-06). Traz `orcamento_numero`, `l_fixo`, fornecedor em cascata (mesma resolução de `vw_necessidade_compra`), e `pendente_item` (déficit da linha descontando cobertura de `pedido_compra_item_origem`). **Não altera** `vw_necessidade_compra` nem `vw_necessidade_compra_detalhe` (SPEC-022/030/039), que continuam intactas para a aba "Por Produto". |

## Ordem de aplicação

Estritamente sequencial (001 → 002 → 003 → 004): `002` depende das colunas
criadas em `001`; `003` também depende de `001` e é mais seguro rodar depois
de `002` já estar em produção (para não competir com aprovações novas
acontecendo em paralelo, embora tecnicamente `003` só toque linhas com
`orcamento_item_id IS NULL`); `004` depende das colunas de `001`/dados de
`002`/`003`.

## Status

**Rascunhada, não aplicada.** Conforme regra do agente implementador,
nenhuma migration desta pasta foi executada contra o Supabase real —
aplicação é passo manual do usuário (orquestrador), incluindo a conferência
prévia de `aprovar_orcamento_financeiro` mencionada acima.

## Verificação esperada (pós-aplicação, passo manual do usuário)

- `SELECT column_name FROM information_schema.columns WHERE table_name = 'projeto_itens' AND column_name IN ('orcamento_item_id', 'l_fixo');` retorna 2 linhas.
- Aprovar um orçamento novo (`aprovar_orcamento_financeiro`) e conferir que os `projeto_itens` criados têm `orcamento_item_id`/`l_fixo` preenchidos, batendo com os `orcamento_itens` de origem — testar especificamente o cenário de validação da SPEC: orçamento com o mesmo produto em 2 posições (ex.: L01 e L35) deve gerar 2 `projeto_itens` distintos, cada um com seu próprio `orcamento_item_id`/`l_fixo`.
- `SELECT COUNT(*) FROM projeto_itens WHERE orcamento_item_id IS NOT NULL;` aumenta depois do backfill (003), refletindo os casos inequívocos entre os `projeto_itens` já existentes.
- `SELECT * FROM vw_necessidade_compra_item_orcamento LIMIT 20;` executa sem erro e retorna as colunas documentadas; nenhuma linha com `orcamento_item_id NULL` aparece (não é coluna exposta, mas a ausência de linhas legadas/ambíguas confirma o filtro).
- `vw_necessidade_compra` e `vw_necessidade_compra_detalhe` continuam funcionando exatamente como antes (sem regressão no Fluxo A).
- Reextrair `supabase/db/current/` depois de aplicar (pendência crônica do domínio, reforçada por esta SPEC).
