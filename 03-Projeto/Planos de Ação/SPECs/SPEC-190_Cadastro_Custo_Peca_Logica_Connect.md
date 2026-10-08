---
titulo: "SPEC-190 — Cadastro: custo da peça na lógica da Connect (preço de custo → desconto → despesas/BDI → lucro → venda)"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - Cadastro Lucenera (cadastro-lucenera-b86fe, Skip 36668) — Consultar Produtos > Editar
  - Supabase (produtos)
  - scripts/importar_produtos_estoque.py (sync Connect)
origem: "02-Reunioes/28. Lucenera (viniciu) - 08.10.2026_ Custo peça"
---

# SPEC-190 — Custo da peça na lógica da Connect

## Problema (reunião Vinícius 08/10/2026)

Produto 12895: listagem mostrava R$ 142,29 (certo, igual à Connect) e o Editar R$ 155,36. O Editar
recalculava a venda sobre `produtos.preco_custo`, que a importação da Connect nunca atualizava (custo antigo:
51,84 x 47,48 da Connect; 10539: 564,55 x 601,00). Faltava também o campo de desconto do fornecedor.

Regras do Vinícius:
- **Preço de custo = tabela do fornecedor (vlCusto da Connect). O sistema de forma alguma pode mudar esse valor.**
- Tem que ter o campo **% desconto** (desconto combinado com o fornecedor, sobre o preço de custo).
- A tela segue a lógica do negócio, de cima pra baixo (mais didático).

## Lógica (registrada e conferida)

```
Preço de Custo        = vlCusto (tabela do fornecedor)                  -> produtos.preco_custo
Custo c/ Desconto     = Preço de Custo × (1 − % Desconto)               -> (calculado; produtos.porc_desconto)
BDI (R$)              = Custo c/ Desconto × (% Frete + % ST + % IPI + % Outras Despesas)
                                                                         -> porc_frete, porc_st, ipi_entrada, porc_despesas
Custo Total           = Custo c/ Desconto + BDI                         -> produtos.custo_total (vlCustoTotal)
Preço de Venda        = Custo Total × (1 + % Lucro)                     -> produtos.valor_venda (ValorVenda)
                                                                         -> % Lucro = produtos.margem_lucro (Lucro)
```

Exemplos: 12895 — 47,48 − 0% = 47,48; BDI 13,86% = 6,58; custo total 54,06; × 2,63209 = **142,29**.
10539 — 601,00 − 25% = 450,75; BDI (17,38% + 9,75%) = 122,29; custo total 573,04; × 2,5 = **1.432,59**.

Conferência na planilha `Produtos__2026-10-07.xlsx`: o Custo Total bate em **4.537/4.537** produtos; o Preço de
Venda bate em todos, menos 21 produtos (abaixo) e 3 diferenças de centavos (a planilha arredonda o % lucro em
3 casas). Observação: a coluna `vlCustoIndireto` da Connect aplica os impostos sobre o preço SEM desconto (ex.: 10539 = 163,05),
mas o `vlCustoTotal` usa o BDI sobre o custo com desconto (122,29) — vale a regra acima.

## Realizado (2026-10-08)

- [x] Cadastro v0.0.97 (1ª tentativa, ERRADA): derivava o preço de custo de custo_total ÷ (1+impostos) — ignorava o
  desconto (10539 aparecia ~450). Só exibição; nada gravado. Substituída.
- [x] Cadastro v0.0.98: conta acima; campo "% Desconto (fornecedor)" e "Custo c/ Desconto"; preço de custo sempre o gravado.
  Ao abrir, mostra custo_total/valor_venda gravados (Connect); só recalcula se alguém mudar um campo.
- [x] Cadastro v0.0.99: "Engenharia de Custos" na ordem do negócio — 1. Custo do fornecedor (preço de custo, % desconto,
  custo c/ desconto) → 2. Despesas (% frete, % ST, % IPI, % outras despesas → valor BDI, custo total) → 3. % Lucro → preço
  de venda. Frete entrou no BDI (sempre 0 na planilha hoje).
- [x] `scripts/importar_produtos_estoque.py`: passa a gravar `vlCusto → preco_custo` e `Lucro → margem_lucro` (com os
  triggers de preço desligados, como os demais campos). Gravação real: 3.643 produtos (só esses 2 campos; estoque, custo
  total e valor de venda já iguais à Connect). Conferido: `preco_venda` idêntico nos 3.643.
- [x] Pós-gravação, nos 4.536 ativos: a conta da tela dá o custo total da Connect em 100%.

## Pendências

- [ ] 21 produtos em que a própria Connect não segue a regra (venda ≠ custo total × (1 + lucro); parece preço digitado
  sem atualizar o % lucro) — conferir com o Sérgio: 9888, 8944, 9510, 9874, 9948, 9949, 9928, 8744, 8465, 9945, 9875,
  11548, 11895, 11596, 13082, 9483, 12242, 10921, 11157, 9353, 5341. A tela mostra o valor da Connect ao abrir.
- [ ] Trigger antigo `fn_atualizar_preco_venda` (trg_calculo_preco_venda / trg_atualizar_preco_venda) recalcula
  `produtos.preco_venda` = custo × 2,5 a cada save — não segue esta lógica. Não afeta Cadastro (usa `valor_venda`);
  verificar quem ainda lê `preco_venda` antes de mudar.
