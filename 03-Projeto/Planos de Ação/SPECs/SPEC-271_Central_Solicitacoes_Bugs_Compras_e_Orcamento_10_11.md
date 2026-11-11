---
titulo: "SPEC-271 — Bugs da Central de Solicitações (10/11): produto no orçamento, peça 4349 e quantidades que somem"
status: migration 322 APLICADA em SP (10/11, testada como Murillo e Debora); Compras com commit local, deploy pendente
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Banco (função criar_produto_orcamento)
  - Compras (compras-lucenera-3o23t98ee): NecessidadeCompra.tsx, ModalGerarCompraItemOrcamento.tsx, lib/rascunho-pedido.ts
---

# SPEC-271 — Três bugs abertos na Central de Solicitações

## 1. Murillo não cria produto durante o orçamento (10/11 17:13)
- **Causa (reproduzida como Murillo, em ROLLBACK):** `criar_produto_orcamento` barra com
  `Permissão negada para criar produto. Role atual: funcionario`. O teste de role legado só aceitava `admin/gerente/operador`
  e vinha antes da matriz de papéis (`hub_pode_executar`), que já autoriza `orcamentos.criar` para ele. Atinge as 24 contas
  `funcionario` ativas que não são admin/gerente (a SPEC-265 corrigiu só o trigger de `estoque_itens`).
- **Correção:** migration `20261110_322_spec271_criar_produto_orcamento_funcionario` — `funcionario` entra no teste de role; a matriz continua
  decidindo; `viewer` segue barrado. `REVOKE` de PUBLIC/anon, `GRANT` para authenticated. Rollback: `rollback.sql`.
- **Dry-run (ROLLBACK):** Murillo OK, Debora OK, viewer barrado.

## 2. Peça 4349 da Nordecor "não aparece" (Débora, 10/11 14:02)
- **Não é defeito.** A peça existe (código 1547271, ativa, marca NORDECOR). A tela *Necessidade de Compra* lê `vw_necessidade_compra`, que só lista
  peça com necessidade > 0 (vendida sem estoque). Peça nova sem venda não entra; ela aparece normalmente no **Pedido avulso** (busca testada).
- **Correção na tela:** a mensagem de busca vazia explica isso e aponta o Pedido avulso. Resposta à Débora: usar Pedido avulso.

## 3. Quantidades alteradas voltam ao valor original (Débora, 09/11 13:41)
- **Causa:** o "carrinho" da Necessidade era `useState` da página (sumia ao trocar de aba) e o modal "Gerar compra" refazia todas as linhas
  do zero a cada abertura.
- **Correção:** `lib/rascunho-pedido.ts` guarda no navegador (localStorage, 24 h) o carrinho e as edições do modal (quantidade, custo,
  ST/IPI/outras, "Tirar" e cabeçalho do pedido). Quantidade digitada não é mais re-arredondada à caixa ao reabrir. Limpa ao gerar o pedido ou no
  botão "Limpar". Sem storage (janela privada) funciona como antes.
- **Fora do escopo:** o Pedido avulso tem estado próprio, não alterado.

## Checklist
- [x] Causas reproduzidas
- [x] Migration 322 escrita e testada em ROLLBACK
- [x] Aplicar a 322 em SP
- [ ] Build e deploy do Compras (wrangler), commit no repositório do sistema e ponteiro do submodule
- [ ] Murillo e Débora testarem
- [ ] Marcar as 3 solicitações como concluídas na Central
