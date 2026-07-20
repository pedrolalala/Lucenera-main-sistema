# Migration 20260719_053 - SPEC-037 (Catálogo Ubiqua: backorder sem estoque e necessidade de importação)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-037_Ubiqua_Backorder_Sem_Estoque_e_Necessidade_Importacao.md` (Checklist de Ação, itens de migration).

Toda a marca Ubiqua vendida no catálogo (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`) é importada pela empresa do usuário — "sem estoque" e "aguardando importação" são o mesmo conceito. O frontend passou a permitir adicionar ao orçamento uma peça sem estoque (pedido sob encomenda), avisando o cliente do prazo de até 3 meses. Esta migration dá ao time de compras uma forma de rastrear a demanda pendente de importação.

## Decisão de modelagem (ver SPEC-037, seção "Mudança 3")

Comparadas 3 alternativas: (A) view só sobre `revenda_ubiqua.disponivel` atual — descartada por perder histórico quando o estoque é reposto; (B) tabela nova cadastrada manualmente pelo time de compras — descartada por contrariar o precedente já documentado em `supabase/db/domains/estoque_compras.md` (necessidade de compra agregada por produto, não cadastro manual); **(C) coluna snapshot booleana + view agregada por produto — escolhida**, por preservar o histórico real de demanda e derivar tudo por relacionamento, sem duplicação manual.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_sem_estoque_no_pedido.sql` | Adiciona `itens_orcamento_ubiqua.sem_estoque_no_pedido boolean NOT NULL DEFAULT false` — snapshot de se a variante estava sem estoque no momento do pedido. |
| `002_vw_necessidade_importacao_ubiqua.sql` | Cria a view `vw_necessidade_importacao_ubiqua`, agregando por produto (`revenda_ubiqua.id`) a quantidade pendente de importação em orçamentos ativos (não cancelados/rejeitados). `SECURITY INVOKER`, `GRANT SELECT` para `authenticated`. |

## Limitação conhecida

Itens de orçamento salvos **antes** desta migration ficam com `sem_estoque_no_pedido = false` por default — não há como saber retroativamente se estavam sem estoque no momento do pedido antigo (dado não existe historicamente). A view só reflete demanda de backorder a partir da aplicação desta migration em diante, sem backfill possível.

## Status

**Rascunhada, não aplicada no Supabase real.** Aplicação é passo manual do usuário (ver SPEC-037, "Passos manuais do usuário").

## Verificação esperada (pós-aplicação, manual)

- `NewQuote.tsx` grava `sem_estoque_no_pedido = true` em `itens_orcamento_ubiqua` quando o item foi adicionado com `disponivel <= 0` no carrinho.
- `SELECT * FROM vw_necessidade_importacao_ubiqua;` lista os produtos com demanda pendente, sem duplicar linhas por cliente.
- Um orçamento cancelado ou rejeitado não aparece agregado na view.
