---
titulo: "SPEC-105 — Devolução: \"buscar venda de origem\" não retornou nada no teste ao vivo"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `DevolucaoItemSearchModal.tsx`, `devolucoesService.ts`
dependencias:
  - SPEC-071 (fluxo de devolução dentro do orçamento — criou esse modal)
---

# SPEC-105 — Devolução: "buscar venda de origem" não retornou nada no teste ao vivo

> Origem: reunião Vinícius 14/08/2026 ([64:26]-[68:04]).

## Objetivo

Investigar (e corrigir, se for bug de verdade) por que a busca de "venda de origem para devolução" não retornou nenhum resultado durante o teste ao vivo na reunião.

## Definição da SPEC

### O que a reunião realmente mostra — não é um bug óbvio, precisa de teste dirigido

Diferente dos outros achados desta rodada de SPECs, este **não tem uma causa raiz clara de bug** — a leitura cuidadosa da transcrição sugere uma explicação alternativa plausível: o orçamento de teste usado ("Orçamento 20"/"Terras Altas") pode simplesmente não ter tido, até aquele momento, um "número de venda" gerado (ele fala isso explicitamente, [67:27]-[67:48]: *"além do orçamento, tem que criar um outro número, o número da venda... um orçamento, a partir que gera o financeiro, ele vira uma venda. E dessa venda a gente consegue fazer as pesquisas... aqui não vem ainda"*).

Ou seja: pode ser que a busca esteja funcionando certo e simplesmente não havia nada pra encontrar naquele orçamento específico (ele ainda não tinha passado pela aprovação financeira que gera o registro consultável).

### Estado atual confirmado no código

`04-Sistemas/gestao-financeira-clone-544cb (1)/src/services/devolucoesService.ts`, função `getVendasOrigemParaDevolucao`:
- Exige `clienteId` truthy — se o orçamento de teste não tinha cliente vinculado no momento do teste, a busca já retorna vazio sem nem consultar o banco (linha 27, `if (!clienteId) return []`).
- Consulta `vw_estoque_saldos_projeto_item` filtrando por `cliente_id` + `status_operacional = 'ativo'`, depois filtra em memória por `(q_reserva + q_entrega_futura + q_entregue) > 0` (linhas 54-57) — coerente com a regra da SPEC-071 (só interessa venda de origem com saldo devolvível).
- A query em si parece bem construída e defensiva; não achei um bug óbvio de sintaxe/filtro errado nesta leitura.

### Proposta

Não é possível confirmar se é bug real sem reproduzir com um cliente/orçamento que **com certeza** já passou pela aprovação financeira (tem `orcamento_numero` gerado e saldo em `estoque_saldos_projeto_item`). Antes de qualquer mudança de código, fazer um teste dirigido: abrir o fluxo de devolução escolhendo um cliente que já tem venda aprovada com saldo (ex.: mesma ORC-0005/ORC-0022 usadas nos testes desta sessão) e confirmar se a busca retorna algo. Só investigar mais fundo se o teste dirigido também falhar.

## Análise de ecossistema

- **Depende de**: `vw_estoque_saldos_projeto_item`, `contatos` (cliente).
- **Afeta**: só o fluxo de devolução dentro do orçamento (SPEC-071).

## Realizado

### 2026-08-15

- **Reproduzido sem precisar do usuário**: encontrei via SQL um cliente real (TERRAS ALTAS AGROPECUÁRIA LTDA, projeto 26.250 "vinicius teste", orçamento ORC-0020) com saldo real e confirmado em `vw_estoque_saldos_projeto_item` (14 linhas). Criei uma devolução nova selecionando esse projeto e cliquei "Buscar Venda de Origem" — confirmado: **é bug real**, não falta de dado.
- **Causa raiz confirmada**: `projetos.cliente_id` (o cliente "oficial" do projeto, usado pra pré-preencher o campo Cliente do orçamento) pode divergir do `cliente_id` que ficou gravado na venda original (`orcamentos.cliente_id`, herdado por `estoque_saldos_projeto_item`). No caso testado: o projeto tinha cliente_id de "Vinicius Bortolin", mas a venda real (ORC-0020) foi feita pra "Terras Altas Agropecuária" — a busca filtrava só por cliente_id do projeto e não achava nada. Levantamento em todos os projetos com saldo ativo: **2 de 7 tinham esse tipo de divergência**, e mais **2 de 7 tinham `projetos.cliente_id` NULL** (a busca nem rodava, `if (!clienteId) return []`) — só 3 de 7 (43%) funcionariam com a busca antiga.
- **Fix**: `getVendasOrigemParaDevolucao` (`devolucoesService.ts`) passou a aceitar `clienteId` E `projetoId`, casando por QUALQUER um dos dois (`.or()`) — mantém a busca cross-projeto por cliente (SPEC-071 P-2) e também encontra vendas do projeto atual mesmo se o cliente gravado nelas for outro. `DevolucaoItemSearchModal.tsx` e `BudgetFormPage.tsx` atualizados pra propagar o `projetoId` (via `projectDetails.id` na criação, `budgetToEdit.projeto_id` na edição).
- Publicado Skip 32554 v0.0.343. Testado ao vivo: recriei o cenário exato do bug (projeto 26.250) — a busca agora retorna as vendas reais de ORC-0020 (Arandela, Balizador Stella, Chip Plafon, etc.), antes retornava "Nenhuma venda com saldo disponível".

## Pendências

Nenhuma.
