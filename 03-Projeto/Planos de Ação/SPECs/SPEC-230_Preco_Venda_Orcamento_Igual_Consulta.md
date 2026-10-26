---
titulo: "SPEC-230 — Preço de venda no Orçamento diferente da Consulta: produtos.preco_venda passa a seguir valor_venda (Connect)"
status: implementada
data_ultima_modificacao: 2026-10-26
sistemas_envolvidos:
  - Banco (produtos.preco_venda, trigger fn_atualizar_preco_venda)
  - Orçamentos (gestao-financeira-clone-544cb (1)) — lê preco_venda primeiro; muda sozinho
  - Compras, Cadastro, views vw_* que leem preco_venda — mudam sozinhos
---

# SPEC-230 — Orçamento com preço diferente da Consulta

> Pedido do usuário (26/10): "Dentro do orçamento o valor de venda da peça está vindo com uma diferença com o valor de
> consulta (que está correto) — peça 12822 na consulta 35,79 e no orçamento 42,95. Precisamos corrigir isso!!"

## Causa (conferido no banco 26/10)
- `produtos` tem dois preços: `valor_venda` (Connect, regra oficial da SPEC-190: custo − desconto + BDI, × (1 + lucro))
  e `preco_venda` (legado). O trigger `fn_atualizar_preco_venda` (trg_calculo_preco_venda, sem filtro de coluna)
  recalcula `preco_venda = custo total × 2,5` a cada UPDATE da peça.
- O Orçamento usa `preco_venda || valor_venda` (busca, tabela de itens, Multi-L, atualizar preços).
- 12822: `preco_venda` 42,95 (recálculo antigo) × `valor_venda` 35,79 (Connect, o certo).
- 4.479 de 4.545 peças com `valor_venda` estão diferentes (2.076 acima, 1.723 abaixo). Na SPEC-190 (08/10) eram
  iguais; o recálculo voltou a divergir depois.

## Definição
- Migration 246:
  - backup `backup._bkp_spec230_produtos_preco_venda` (id, codigo_produto, preco_venda);
  - `fn_atualizar_preco_venda`: `preco_venda := valor_venda` quando `valor_venda > 0`; sem `valor_venda` mantém a conta
    antiga (custo × 2,5). Continua sem recalcular em UPDATE só de estoque (SPEC-224);
  - acerta as peças: `preco_venda = valor_venda` onde diferente.
- Telas não mudam. Orçamentos já feitos **não** mudam sozinhos — usar "Atualizar preços" no orçamento se precisar.

## Checklist
- [x] Migration 246 + rollback (restaura preco_venda do backup e a função anterior)
- [x] Dry-run em ROLLBACK (12822 → 35,79; mudar custo/valor_venda continua coerente)
- [ ] Usuário conferir a 12822 num orçamento novo
