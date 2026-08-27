---
titulo: "SPEC-049 — Card Lateral de Peça no Cadastro: Reserva por Cliente/Equipe e Pedido em Trânsito"
status: publicado em produção (2026-07-27, Skip v0.0.47/b81c1fd); RLS de equipes_projetos corrigida; aguardando validação visual do usuário
data_ultima_modificacao: 2026-07-27
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe)
  - Supabase (banco central)
dependencias:
  - SPEC-010 (estoque_saldos_projeto_item / vw_estoque_por_produto_projeto — fonte dos saldos por projeto_item_id)
  - SPEC-022 (vw_necessidade_compra_detalhe — mesmo padrão de join produto → projeto_itens → projetos/contatos, já em produção)
  - SPEC-039 (vw_necessidade_compra_pedido_detalhe — pedidos de compra em aberto por produto, com data_prevista_entrega)
---

# SPEC-049 — Card Lateral de Peça no Cadastro: Reserva por Cliente/Equipe e Pedido em Trânsito

> Pedido do usuário: "no card lateral quando clicamos no pedrolalala/cadastro-lucenera ele deve aparecer algumas informações adicionais, como por exemplo: a quantidade de peça reservada; Para quem é reservado, nome cliente, a equipe e informações sobre o pedido existente e informações de chegada".

## Checklist de Ação

### Backend
- [x] Criar migration `supabase/db/migrations/20260727_063_spec049_cadastro_reserva_detalhe/`
- [x] Criar view `vw_cadastro_produto_reserva_detalhe` (reserva ativa por projeto/cliente/equipe, derivada de `vw_estoque_por_produto_projeto` — não duplica tabela nem cria saldo paralelo)
- [x] `GRANT SELECT` para `authenticated`
- [x] Aplicar no Supabase — **aplicada em produção em 2026-07-27** via `psycopg2` (usuário confirmou explicitamente), validada com dado real (produto 11307/código, projeto 26.105, ORC-0010, cliente MARIANA FERNANDES DE JESUS, equipe Thairine). Reextração de `supabase/db/current/` ainda não feita (pendência crônica pré-existente do domínio de Compras).
- [ ] Reextrair `supabase/db/current/` para o domínio de Compras antes ou junto desta SPEC (ver P-05 — o snapshot atual está sem a tabela `pedidos_compra` e sem as views da SPEC-039, confirmado nesta análise) — **não feito nesta implementação**, pendência crônica pré-existente (ver `supabase/db/domains/estoque_compras.md`)
- [x] **Achado crítico #3 corrigido**: `equipes_projetos` tinha RLS habilitado sem nenhuma policy de leitura (deny-all silencioso para `authenticated` desde a migration `20260630_012`, nunca percebido porque nenhum consumo autenticado real existia até esta SPEC). Migration `supabase/db/migrations/20260727_064_spec049_rls_equipes_projetos/001_select_policy_equipes_projetos.sql` **aplicada em produção em 2026-07-27**, validada com `SET ROLE authenticated` (retorno correto: equipe "Thairine" para o produto 11307). Detalhes em `supabase/db/domains/estoque_compras.md`.

### Frontend (`cadastro-lucenera-b86fe`)
- [x] Adicionar `getReservasProduto(produtoId)` em `src/services/produtos.ts` (mesmo padrão das funções existentes no arquivo — `supabase.from(...).select('*').eq(...)`, sem RPC nem store)
- [x] Adicionar `getPedidosCompraEmTransito(produtoId)` em `src/services/produtos.ts`, lendo `vw_necessidade_compra_pedido_detalhe` filtrada por `produto_id` (view já existe e já tem `GRANT SELECT authenticated` — não requer nova migration para esta parte)
- [x] Alterar `src/components/pecas/PecaDetailsPanel.tsx`: adicionar duas seções novas abaixo de "Estoque por Local" — "Reservado por Cliente/Projeto" e "Pedido de Compra em Trânsito", seguindo o mesmo padrão visual (`Table`, `DetailRow`, badges, empty state) já usado no componente
- [ ] Testar: peça sem nenhuma reserva ativa (seção oculta ou empty state, igual ao "Saldo Zero" hoje) — **pendente, requer navegador + migration aplicada**
- [ ] Testar: peça com reserva de 1 projeto/cliente — **pendente**
- [ ] Testar: peça com reserva de vários projetos/clientes diferentes ao mesmo tempo — **pendente**
- [ ] Testar: peça com `q_entrega_futura > 0` e pedido de compra em aberto simultaneamente — **pendente**
- [ ] Testar: peça com pedido de compra em trânsito mas sem nenhuma reserva vinculada (compra sem dono fixo — RN-03 SPEC-012/022) — **pendente**
- [x] Adicionar `getFornecedorSugeridoProduto(produtoId)` em `src/services/produtos.ts` (seção adicional "Fornecedor Sugerido"), lendo `vw_necessidade_compra` filtrada por `produto_id` com `.maybeSingle()` (view já existe em produção, já com `GRANT SELECT authenticated` — não requer nova migration)
- [x] Alterar `src/components/pecas/PecaDetailsPanel.tsx`: adicionar seção "Fornecedor Sugerido" (linha de texto, não tabela), posicionada perto de "Pedido de Compra em Trânsito", visível apenas quando `pendente > 0`, com `useEffect`/`useState` isolado dos demais
- [ ] Testar: peça com `fornecedor_nome`/`pendente > 0` retornado por `vw_necessidade_compra` (ex.: produto código 11307) — **pendente, requer navegador**
- [ ] Testar: peça sem pendência de compra (`pendente = 0` ou sem linha na view) — seção "Fornecedor Sugerido" deve ficar oculta — **pendente**

### Passos manuais do usuário
- [x] Rodar a migration `supabase/db/migrations/20260727_063_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql` — **aplicada em produção em 2026-07-27**, validada com o produto código 11307 do exemplo real do usuário
- [x] Responder as perguntas em aberto (seção "Perguntas em aberto") antes da implementação — especialmente P-01 (qual campo de equipe) e P-02 (lista ou soma quando há múltiplos clientes) — resolvidas pelo usuário em 2026-07-27
- [ ] Validar visualmente no navegador (golden path: abrir Peças → clicar numa peça com reserva conhecida → conferir cliente/equipe/pedido) — sem suíte de teste automatizada neste sistema
- [x] Rodar lint/build do `cadastro-lucenera-b86fe` antes do deploy (Skip) — `oxlint`/`oxfmt` e `vite build` rodados nesta implementação (incluindo a seção "Fornecedor Sugerido"), sem erros novos
- [x] Publicar o sistema no Skip — **publicado em produção em 2026-07-27** (projeto Skip 36668 "Cadastro Lucenera", versão `0.0.47`/`b81c1fd`, `https://cadastro-lucenera-b86fe.goskip.app`). Achado importante: o projeto Skip tem cópia própria dos arquivos, separada do submodule local — os arquivos precisaram ser escritos direto via `skip_file_write` (MCP), não bastava editar o disco local. Confirmado por download do bundle JS de produção que as strings da SPEC-049 estão presentes.
- [ ] Reextrair `supabase/db/current/` do domínio de Compras (pendência crônica, ver `supabase/db/domains/estoque_compras.md`)
- [ ] Confirmar se existe `04-Sistemas/cadastro-lucenera-b86fe/supabase/AI_DB_CONTEXT.md` no repositório remoto do sistema (segue não encontrado no espelho local) e atualizá-lo se existir
- [ ] Resolver o estado de "untracked content" do submodule `cadastro-lucenera-b86fe` antes de commitar qualquer alteração de ponteiro de submodule

## Objetivo

Hoje o painel lateral de peça no Cadastro (`PecaDetailsPanel.tsx`, tela Peças) mostra apenas o estoque agregado por local (`estoque_itens`, via `getEstoqueItens`) — quantidade, reservado e disponível por "setor" (Estoque Geral, Showroom, Reserva, etc.), sem saber **para quem** aquela reserva é nem se há compra em andamento para cobrir a diferença.

Esta SPEC adiciona ao mesmo painel, sem trocar de tela, duas seções de leitura:
1. **Reservado por cliente/projeto/equipe** — que projeto gerou a reserva, para qual cliente, de qual equipe, e quanto já está coberto (`q_reserva`) vs. ainda aguardando compra (`q_entrega_futura`).
2. **Pedido de compra em trânsito** — se há pedido de compra em aberto para esse produto, com número, fornecedor/empresa e previsão de chegada.

## Decisões aprovadas

- Cadastro continua **somente leitura** sobre saldo/reserva (Escopo Cadastro, SPEC-CAD-05, atualização 06/07/2026: "Cadastro pode exibir 'Reservado por projeto/cliente' no detalhe da peça, lendo views derivadas de `estoque_saldos_projeto_item`, mas continua sem escrever reserva, transferência, compra ou movimento operacional"). Esta SPEC não cria nenhum formulário de escrita.
- A fonte de reserva é `estoque_saldos_projeto_item` / `projeto_itens` via `vw_estoque_por_produto_projeto` (SPEC-010) — não recriar `estoque_reservas` nem qualquer tabela paralela por cliente.
- Cliente, projeto, orçamento, equipe e produto continuam sendo lidos por `JOIN`, nunca duplicados numa tabela de saldo (invariante da SPEC-010).
- Compra não tem dono fixo (RN-03 da SPEC-012/022): a seção de "pedido existente / chegada" é agregada por **produto**, não amarrada a um cliente/reserva específico. Um pedido de compra em trânsito pode cobrir a necessidade de vários projetos ao mesmo tempo, ou nenhum ainda.
- Reaproveitar `vw_necessidade_compra_pedido_detalhe` (SPEC-039, já em produção, já com `GRANT SELECT authenticated`) para a parte de "informações de chegada" — não criar view nova equivalente no domínio de Compras.
- **P-01 resolvida (usuário, 2026-07-27):** "a equipe" do card é `projetos.equipe_id` (equipe comercial/vendas), não `equipe_responsavel_obra_id`.
- **P-02 resolvida (usuário, 2026-07-27):** múltiplas reservas da mesma peça aparecem como uma linha por projeto/cliente, sem agregação.

## Definição da SPEC

### Estado atual (confirmado no código)

`04-Sistemas/cadastro-lucenera-b86fe/src/components/pecas/PecaDetailsPanel.tsx`:
- Recebe `peca` (dados cadastrais + agregados de `vw_produtos_estoque_detalhado`) via props.
- Em `useEffect`, chama `getEstoqueItens(peca.id)` (`src/services/produtos.ts`), que lê `estoque_itens` bruto (`select('*').eq('produto_id', produtoId)`).
- `buildEstoquePorSetor` (`src/lib/estoque-sectors.ts`) agrupa por `local` (setor), somando `quantidade`/`quantidade_reservada`.
- Renderiza tabela "Estoque por Local" com Total / Reservado / Disponível — sem nenhuma referência a cliente, projeto, equipe ou pedido de compra.

**Padrão de acesso a dados do sistema (não propor padrão novo):** funções `async` simples em `src/services/*.ts`, chamando `supabase.from(...)`/`supabase.rpc(...)` diretamente, consumidas via `useState`/`useEffect` no componente. Sem React Query, sem store global para este painel.

### View nova: `vw_cadastro_produto_reserva_detalhe`

Uma linha por `(produto_id, projeto_item_id)` com reserva ativa (`q_reserva > 0` ou `q_entrega_futura > 0`), reaproveitando a view já existente e testada da SPEC-010:

```sql
-- Migration: YYYYMMDD_NNN_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql

CREATE OR REPLACE VIEW public.vw_cadastro_produto_reserva_detalhe
WITH (security_invoker = true)
AS
SELECT
    v.projeto_item_id,
    v.projeto_id,
    v.projeto_codigo,
    v.orcamento_id,
    v.orcamento_numero,
    v.produto_id,
    v.produto_codigo,
    v.cliente_id,
    c.nome                       AS cliente_nome,
    pr.equipe_id,
    eq.equipes                   AS equipe_nome,
    v.q_venda,
    v.q_reserva,
    v.q_entrega_futura,
    v.status_operacional
FROM public.vw_estoque_por_produto_projeto v
LEFT JOIN public.projetos pr          ON pr.id = v.projeto_id
LEFT JOIN public.contatos c           ON c.id = v.cliente_id
LEFT JOIN public.equipes_projetos eq  ON eq.id = pr.equipe_id
WHERE v.q_reserva > 0 OR v.q_entrega_futura > 0;

COMMENT ON VIEW public.vw_cadastro_produto_reserva_detalhe IS
'SPEC-049. Uma linha por (produto_id, projeto_item_id) com reserva ativa.
Reaproveita vw_estoque_por_produto_projeto (SPEC-010), soma cliente (contatos)
e equipe (projetos.equipe_id -> equipes_projetos). Somente leitura, consumida
pelo painel lateral de peca do Cadastro. SECURITY INVOKER.';

GRANT SELECT ON public.vw_cadastro_produto_reserva_detalhe TO authenticated;
```

**Colunas verificadas contra `supabase/db/current/01_schema_full.sql`:** `vw_estoque_por_produto_projeto` já existe em produção com exatamente essas colunas (linhas 6919-6940); `projetos.equipe_id -> equipes_projetos.id` e `equipes_projetos.equipes` (texto) confirmados via `09_schema_inventory.md`; `contatos.nome` é padrão usado em toda a base (ex.: SPEC-022).

### Seção "Pedido de compra em trânsito" — sem view nova

Reaproveitar `vw_necessidade_compra_pedido_detalhe` (já criada pela SPEC-039, `supabase/db/migrations/20260722_056_spec039_necessidade_compra_grid/003_vw_necessidade_compra_pedido_resumo.sql`), filtrando por `produto_id`:

```typescript
// src/services/produtos.ts (novo)
export async function getPedidosCompraEmTransito(produtoId: string) {
  const { data, error } = await supabase
    .from('vw_necessidade_compra_pedido_detalhe')
    .select('*')
    .eq('produto_id', produtoId)
  if (error) throw error
  return data
}
```

Colunas retornadas: `pedido_id`, `numero`, `status`, `empresa_nome`, `data_prevista_entrega`, `qtd_pendente`.

> **Atenção:** `supabase/db/current/01_schema_full.sql` e `09_schema_inventory.md` **não contêm** `pedidos_compra` nem as views da SPEC-039 — confirmado nesta análise (grep sem resultado nos dois arquivos). Isso é uma pendência crônica já registrada em `supabase/db/domains/estoque_compras.md`. Os nomes de coluna acima vêm do arquivo de migration real (`003_vw_necessidade_compra_pedido_resumo.sql`), não do snapshot. Recomenda-se reextrair `supabase/db/current/` antes de implementar esta SPEC, para não construir sobre suposição.

### UI proposta no `PecaDetailsPanel.tsx`

Abaixo de "Estoque por Local", duas novas seções (mesmo estilo visual — `Table`, badges arredondados, `Skeleton` no loading):

**Seção "Reservado por Cliente/Projeto"** (só aparece se `vw_cadastro_produto_reserva_detalhe` retornar linhas):

| Projeto | Cliente | Equipe | Qtd. Vendida | Reservado | Aguardando Compra |
|---|---|---|---|---|---|
| L-2025-03 | Studio Arq. | Comercial 2 | 4 | 4 | 0 |
| L-2025-07 | Maria Fernanda | Comercial 1 | 3 | 0 | 3 |

Se não houver reserva ativa: texto "Nenhuma reserva ativa para esta peça." (mesmo padrão do "Saldo Zero" já usado).

**Seção "Pedido de Compra em Trânsito"** (só aparece se `getPedidosCompraEmTransito` retornar linhas):

| Nº Pedido | Status | Empresa | Previsão de Chegada | Qtd. Pendente |
|---|---|---|---|---|
| PC-2026-0088 | Em Trânsito | Lucenera Matriz | 05/08/2026 | 12 |

Se não houver pedido em aberto: texto "Nenhum pedido de compra em trânsito para esta peça." Reaproveitar o dicionário de rótulos de status já existente em `compras-lucenera-3o23t98ee/src/services/necessidade-compra.ts` (`STATUS_PEDIDO_COMPRA_LABEL`) — **duplicar o dicionário no Cadastro** (não há import cross-repo entre sistemas), mantendo os mesmos textos (`rascunho`→"Pendente", `enviado`→"Pedido Emitido", `parcialmente_recebido`→"Em Trânsito", etc.) para não criar vocabulário divergente entre os dois sistemas.

### Seção adicional "Fornecedor Sugerido" (pedido do usuário, 2026-07-27, após ver o card real)

O usuário mostrou o produto código 11307 como exemplo real: na tela "Necessidade de Compra → Por Item de Orçamento" ele aparece com Fornecedor "STELLA IMPORTACAO..." e Pendente "1", mesmo **sem** nenhum pedido de compra real feito ainda. Confirmado por leitura direta do banco que esse "Fornecedor" não vem de um pedido existente — vem de `vw_necessidade_compra_item_orcamento`/`vw_necessidade_compra`, que resolve `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)` (produto tem fornecedor próprio? senão usa o da marca). É uma sugestão de compra, não um pedido em trânsito.

Adicionar mais uma seção (ou uma linha de resumo, acima ou junto de "Pedido de Compra em Trânsito") lendo `vw_necessidade_compra` filtrada por `produto_id` (view já existe em produção, já tem `GRANT SELECT` para `authenticated`, confirmado por consulta direta — não requer migration nova):

```typescript
// src/services/produtos.ts (novo)
export async function getFornecedorSugeridoProduto(produtoId: string) {
  const { data, error } = await supabase
    .from('vw_necessidade_compra')
    .select('fornecedor_nome, pendente, qtd_pedidos_abertos, qtd_em_pedidos_abertos, proxima_data_prevista_entrega, status_mais_critico')
    .eq('produto_id', produtoId)
    .maybeSingle()
  if (error) throw error
  return data
}
```

Exibir como linha simples (não tabela): "Fornecedor Sugerido: STELLA IMPORTACAO... · Pendente: 1". Só aparece se `pendente > 0`. Isso é independente da seção "Pedido de Compra em Trânsito" (que só mostra pedidos **já feitos**) — as duas podem aparecer juntas, uma só, ou nenhuma, dependendo do estado real do produto.

## Análise de ecossistema (obrigatória)

- **Depende de:** `projetos`, `contatos`, `produtos`, `projeto_itens` — sim, via as views reaproveitadas. Não depende de `orcamentos`/`boletos`/`usuarios`/`systems`/`user_system_access` diretamente (apenas indiretamente via `orcamento_numero`/`orcamento_id` já resolvido pela view existente).
- **Afeta:** Cadastro (leitura nova na tela Peças). Não afeta CRM, Orçamentos, Financeiro, RH ou Hub/TI. Tangencia Estoque/Compras apenas como **consumidor read-only** de views já publicadas por aquele domínio (mesmo padrão da SPEC-CAD-05).
- **Dado duplicado?** Não — `cliente_nome` e `equipe_nome` são resolvidos por `JOIN` na view nova, nunca gravados em `estoque_saldos_projeto_item` (respeita a invariante da SPEC-010).
- **Migration antiga contradizendo o snapshot central?** Sim, identificado nesta análise: `supabase/db/current/` está desatualizado para o domínio de Compras (tabela `pedidos_compra` e views da SPEC-039 ausentes de `01_schema_full.sql`/`09_schema_inventory.md`), embora estejam aplicadas em produção segundo `supabase/db/domains/estoque_compras.md`. Isso é uma pendência pré-existente, não causada por esta SPEC, mas relevante para quem for implementar.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Não foi encontrado `supabase/AI_DB_CONTEXT.md` dentro de `04-Sistemas/cadastro-lucenera-b86fe/` no estado atual do submodule local — se esse arquivo existir no repositório remoto do sistema, deve ser atualizado ao implementar.
- **Padrão de acesso a dados já usado pelo sistema:** funções simples em `src/services/*.ts` com `supabase.from(...)`, chamadas via `useEffect`/`useState` direto no componente — sem store global nem React Query para este painel. Esta SPEC segue esse padrão, sem introduzir um novo.

## Perguntas em aberto (decisão do usuário antes de implementar)

| # | Pergunta | Impacto | Status |
|---|----------|---------|--------|
| P-01 | Qual campo de equipe usar? | Define o `JOIN` da view | **Resolvida** — `equipe_id` (comercial/vendas) |
| P-02 | Lista por projeto ou soma agregada por cliente quando há múltiplas reservas? | Layout da seção "Reservado por Cliente/Projeto" | **Resolvida** — uma linha por projeto/cliente |
| P-03 | A seção de pedido de compra deve aparecer mesmo quando **não há nenhuma reserva** para aquela peça (produto com pedido em aberto mas ninguém aguardando ainda)? | Já decidido pela regra de negócio (compra não tem dono fixo) que isso é possível | Segue proposta padrão da SPEC (aparece mesmo assim) — não bloqueante |
| P-04 | Mostrar tanto `q_reserva` (já coberto fisicamente) quanto `q_entrega_futura` (ainda sem cobertura, aguardando compra) na mesma linha, ou tratar como duas seções separadas? | Proposto: mesma linha, duas colunas | Segue proposta padrão da SPEC — não bloqueante |
| P-05 | `supabase/db/current/` deve ser reextraído **antes** desta implementação, ou a implementação pode seguir com base nos arquivos de migration reais? | Risco de retrabalho se houver divergência (já aconteceu 2x neste domínio) | Implementador deve conferir os arquivos de migration reais da SPEC-039 diretamente (não confiar só no snapshot) antes de escrever a nova view/migration |
| P-06 | Itens aprovados antes de 06/07/2026 (pré-SPEC-010) tiveram backfill conservador 100% em `q_reserva` — está aceitável que reservas antigas apareçam sempre como "já coberto", mesmo que originalmente não fossem? | Já é uma limitação conhecida da SPEC-010, herdada por esta SPEC sem solução nova | Limitação aceita, herdada — não bloqueante |

## Realizado

**2026-07-27 — implementação de código concluída (agente implementador):**

- Migration redigida (NÃO aplicada no Supabase real, conforme regra do implementador): `supabase/db/migrations/20260727_063_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql`, criando `public.vw_cadastro_produto_reserva_detalhe` exatamente como especificado na seção "View nova" desta SPEC (reaproveita `vw_estoque_por_produto_projeto` da SPEC-010, `LEFT JOIN` em `projetos`/`contatos`/`equipes_projetos`, `security_invoker = true`, `GRANT SELECT ... TO authenticated`).
- Antes de escrever a migration, conferido (P-05) o arquivo real `supabase/db/migrations/20260722_056_spec039_necessidade_compra_grid/003_vw_necessidade_compra_pedido_resumo.sql`: as colunas de `vw_necessidade_compra_pedido_detalhe` batem exatamente com o que a SPEC já listava (`produto_id`, `pedido_id`, `numero`, `status`, `empresa_nome`, `data_prevista_entrega`, `qtd_pendente`) — nenhuma divergência encontrada em relação ao texto da SPEC.
- `04-Sistemas/cadastro-lucenera-b86fe/src/services/produtos.ts`: adicionadas `getReservasProduto(produtoId)` e `getPedidosCompraEmTransito(produtoId)`, com interfaces `ReservaProdutoRow`/`PedidoCompraEmTransitoRow`. As duas views ainda não existem nos tipos gerados (`src/lib/supabase/types.ts`), então o `.from(...)` usa cast `as any`, mesmo padrão já existente no arquivo para `get_next_sku`.
- `04-Sistemas/cadastro-lucenera-b86fe/src/components/pecas/PecaDetailsPanel.tsx`: duas seções novas somente leitura abaixo de "Estoque por Local" — "Reservado por Cliente/Projeto" (Projeto/Cliente/Equipe/Qtd. Vendida/Reservado/Aguardando Compra, uma linha por `projeto_item_id`, sem agregação — P-02) e "Pedido de Compra em Trânsito" (Nº Pedido/Status/Empresa/Previsão de Chegada/Qtd. Pendente). Mesmo padrão visual do componente (`Table`, badges arredondados, `Skeleton` de loading, empty state por seção). Dicionário `STATUS_PEDIDO_COMPRA_LABEL` duplicado localmente a partir de `compras-lucenera-3o23t98ee/src/services/necessidade-compra.ts` (mesmos textos, sem import cross-repo).
- `supabase/db/domains/estoque_compras.md` atualizado com uma entrada registrando a SPEC-049 e o status "redigida, ainda não aplicada".
- `CHANGELOG.md` atualizado com entrada de 2026-07-27.
- Verificação: `npx oxlint` e `npx oxfmt --check` rodados nos dois arquivos alterados (sem avisos novos — só um warning pré-existente não relacionado, `Type alias 'Produto' is declared but never used`). `npm run build` (`vite build`) rodado com sucesso no `cadastro-lucenera-b86fe`, sem erros.
- Nenhuma migration foi aplicada no Supabase real. Nenhum teste manual no navegador foi feito (fora do escopo do implementador).

**2026-07-27 — seção "Fornecedor Sugerido" implementada (agente implementador, continuação da SPEC):**

- `04-Sistemas/cadastro-lucenera-b86fe/src/services/produtos.ts`: adicionada `getFornecedorSugeridoProduto(produtoId)` exatamente como especificada na SPEC — lê `vw_necessidade_compra` filtrada por `produto_id`, colunas `fornecedor_nome, pendente, qtd_pedidos_abertos, qtd_em_pedidos_abertos, proxima_data_prevista_entrega, status_mais_critico`, com `.maybeSingle()`. Cast `as any` no `.from(...)`, mesmo padrão já usado no arquivo (a view não está nos tipos gerados). Nova interface `FornecedorSugeridoProdutoRow`. Nenhuma migration nova foi criada (view já existe em produção com `GRANT SELECT authenticated`, conforme a SPEC).
- `04-Sistemas/cadastro-lucenera-b86fe/src/components/pecas/PecaDetailsPanel.tsx`: adicionada seção "Fornecedor Sugerido" como linha de texto (não tabela) — "Fornecedor Sugerido: X · Pendente: Y" — posicionada imediatamente acima da seção "Pedido de Compra em Trânsito", com `useEffect`/`useState` isolado (`fornecedorSugerido`/`loadingFornecedorSugerido`) igual ao padrão das outras duas seções desta SPEC. Só renderiza quando `pendente > 0`; oculta em qualquer outro caso (sem linha na view, `pendente = 0` ou `null`). Independente da seção "Pedido de Compra em Trânsito" — nenhuma das duas depende da outra para aparecer.
- Nenhuma decisão de regra de negócio nova foi tomada — texto e condição de exibição seguem exatamente o que a SPEC já descrevia.
- Verificação: `npx oxlint` nos dois arquivos alterados — sem avisos novos (mesmo warning pré-existente e não relacionado, `Type alias 'Produto' is declared but never used`, em `produtos.ts`). `npx oxfmt --check` inicialmente apontou uma diferença de formatação em `PecaDetailsPanel.tsx` (quebra de linha do `useState` da nova seção); corrigido rodando `npx oxfmt` (sem `--check`) no mesmo arquivo. `npm run build` (`vite build`) rodado com sucesso, sem erros.
- Nenhuma migration foi aplicada no Supabase real nesta parte (não era necessária). Nenhum teste manual no navegador foi feito (fora do escopo do implementador).

## Pendências

- [x] Decisão do usuário sobre P-01 e P-02 (bloqueantes) — resolvidas em 2026-07-27.
- [x] Implementador conferiu os arquivos de migration reais da SPEC-039 (não só o snapshot `supabase/db/current/`) antes de escrever a view nova desta SPEC (P-05) — sem divergência encontrada.
- [ ] **Aplicar a migration `20260727_063_spec049_cadastro_reserva_detalhe/001_view_reserva_detalhe.sql` no Supabase real** (passo manual do usuário — o implementador nunca aplica migration).
- [ ] Reextrair `supabase/db/current/` (todo o domínio de Compras, incluindo esta view nova) depois de aplicar a migration.
- [ ] Validar visualmente no navegador (golden path descrito no Checklist) — sem suíte de teste automatizada neste sistema, incluindo a seção "Fornecedor Sugerido" (ex.: produto código 11307, que o usuário confirmou aparecer com fornecedor "STELLA IMPORTACAO..." e pendente "1").
- [ ] Rodar `npm run lint`/`npm run build` novamente depois de qualquer ajuste visual e publicar no Skip.
- [ ] Confirmar se existe `04-Sistemas/cadastro-lucenera-b86fe/supabase/AI_DB_CONTEXT.md` no repositório remoto do sistema (não encontrado no espelho local, confirmado novamente nesta implementação) — se existir, precisa ser atualizado.
- [ ] Verificar o estado de working tree do submodule `cadastro-lucenera-b86fe` (aparece como "untracked content" no `git status` do repo central, inclusive antes desta implementação) antes de commitar qualquer alteração de ponteiro de submodule.
- [ ] Rodar o agente `revisor` antes de qualquer commit.
