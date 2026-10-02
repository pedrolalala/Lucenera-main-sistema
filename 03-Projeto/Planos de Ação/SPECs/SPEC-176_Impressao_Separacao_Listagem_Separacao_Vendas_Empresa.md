---
titulo: "SPEC-176 — Impressão da separação, listagem da Separação Parcial e empresa/busca em Vendas"
status: publicado (Separação Parcial 48801 v0.0.45, Vendas 59346 v0.0.14 — 02/10)
data_ultima_modificacao: 2026-10-02
sistemas_envolvidos:
  - Separação Parcial (separacao-parcial) — impressão "Pedido em Separação" + listagem de vendas
  - Vendas (vendas-lucenera) — listagem de vendas
dependencias:
  - SPEC-072 (Separação Parcial não mostra valores em dinheiro — mantido)
  - SPEC-091 / SPEC-093 / SPEC-138 / SPEC-144 (layout da impressão da separação)
  - SPEC-136 (número da venda distinto do orçamento)
  - SPEC-153 (sistema Vendas; empresa emitente = orcamentos.empresa_id)
  - SPEC-167 (orcamentos.previsao_entrega)
---

# SPEC-176 — Impressão da separação, listagem da Separação Parcial e empresa/busca em Vendas

Pedido do administrador repassado pelo usuário em 02/10/2026. Sem mudança de banco, regra de negócio,
RPC ou Edge Function: só exibição e usabilidade.

## Decisões confirmadas com o usuário (02/10)

- O documento chamado de "Necessidade de Compra" no pedido é a **impressão "Pedido em Separação"** do
  Separação Parcial (`imprimirListaSeparacao`), não a tela Necessidade de Compra do Compras.
- **Valor da venda NÃO entra na Separação Parcial** (continua valendo a SPEC-072). O valor fica na área de
  Vendas, que já mostra a coluna "Valor".
- Na listagem da Separação Parcial **sai a coluna do número do orçamento**; fica só o número da venda.

## 1. Impressão "Pedido em Separação" (separacao-parcial, `src/pages/SeparacaoParcialPage.tsx`)

- Logo da Lucenera no cabeçalho (mesma `LOGO_URL` já usada na tela).
- Layout reorganizado: cabeçalho com logo / título / número e datas; bloco do cliente em grade.
- Colunas: Local (L) · Cód. Ref. · Referência e descrição · Quantidade.
  - Sai a coluna "Conf.".
  - "Cód. Ref." e "Quantidade" centralizadas (cabeçalho e células).
  - Referência + descrição numa linha só, truncada com reticências; texto completo no `title` (tooltip na
    pré-visualização). No papel o tooltip não existe: o que passar da largura da coluna fica cortado.
- Rodapé: só os blocos de assinatura **Entregador** e **Recebedor** (nome, RG/CPF, data/hora).
  Saem "Ass. Conferente", a declaração de responsabilidade e "Separado por".
- Observações e totalizador continuam.

## 2. Listagem da Separação Parcial (mesmo arquivo + `src/services/separacaoParcialService.ts`)

- Colunas: Venda · Cliente — Projeto (mesma linha, ex.: "Pedro — 26.1609") · Empresa · Data da Venda ·
  Previsão de Entrega.
- Número exibido sem prefixo ("VENDA-0001" → "0001"); só exibição, o dado e a busca continuam iguais
  (a busca aceita "0001" ou "VENDA-0001").
- Data da venda = `orcamentos.aprovado_cliente_em` (fallback `data_emissao`); previsão = `orcamentos.previsao_entrega`;
  empresa = `orcamentos.empresa_id → empresas.nome`.

## 3. Vendas (vendas-lucenera, `src/pages/Vendas.tsx`)

- Coluna nova "Empresa Faturada" (`empresa.nome`, já carregada como emitente da nota).
- Campo de busca: número da venda, cliente, projeto ou empresa.
- Filtro por empresa (Select). Busca e filtro combinados (E).

## Critério de aceite

- Impressão sem "Conf.", sem conferente/declaração/"Separado por", com logo e só Entregador/Recebedor.
- Separação Parcial lista sem coluna de orçamento, número sem prefixo, com empresa e datas, sem valor.
- Vendas: filtrar por empresa + buscar texto ao mesmo tempo reduz a lista corretamente.

## Rollback

Reverter os commits dos dois sistemas e republicar a versão anterior no Skip.

## Complemento (confirmado pelo usuário em 02/10)

- Número no topo da impressão sem o orçamento: `ORC-0032-P3 / VENDA-0001` → `Venda 0001-P3`.
- Cabeçalho da venda aberta na Separação Parcial: sai "Orçamento:", fica "Venda: 0001".
- Histórico "Parciais desta venda" usa o mesmo código da impressão (`0001-P3`).
- Venda sem número (aprovada antes da SPEC-136) cai no número do orçamento — hoje nenhuma venda ativa está assim.
