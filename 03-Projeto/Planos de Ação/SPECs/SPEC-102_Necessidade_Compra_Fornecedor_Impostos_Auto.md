---
titulo: "SPEC-102 — Necessidade de Compra: fornecedor e impostos pré-preenchidos + valor do pedido com BDI"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, Skip 40326) — `ModalRegistrarCompra.tsx`
  - Supabase (banco central) — RPC `criar_pedido_compra_de_necessidade`
dependencias:
  - SPEC-038 (mecanismo de pré-preenchimento de custo/ICMS/IPI/ST — já existe, só não dispara sozinho)
  - SPEC-066 (fornecedor via `contatos`/`marcas.fornecedor_id`)
---

# SPEC-102 — Necessidade de Compra: fornecedor e impostos pré-preenchidos + valor do pedido com BDI

> Origem: reunião Vinícius 14/08/2026 ([69:44]-[72:28], [77:03]-[77:31]).

## Objetivo

Três pedidos com a mesma causa raiz e um terceiro relacionado:

1. Ao abrir "Registrar Pedido de Compra" a partir da Necessidade de Compra, o fornecedor deveria vir pré-selecionado do cadastro do produto/marca (hoje não vem).
2. Como consequência, os campos de imposto (ICMS/IPI/ST) também deveriam vir pré-preenchidos (o mecanismo já existe, SPEC-038, só não dispara).
3. O valor final do pedido, que alimenta o fluxo de caixa como previsão de pagamento, deve incluir os custos indiretos (impostos/BDI) — hoje só usa o preço de custo seco, subestimando o valor real a pagar.

## Decisões aprovadas

Regra de negócio, citada pelo Vinícius sobre o item 3 ([72:03]-[72:28]):

> "Pra que o valor final do pedido seja bem próximo da realidade, porque esse valor final, teoricamente depois ele vai entrar lá no fluxo de caixa como uma previsão de pagamento. Então se ele não vem os dados dos impostos vem só os dados do preço de custo e depois eu tenho mais 40% de imposto. Então um pedido de 10 mil não é só 10 mil que vou pagar, vou pagar 14."

E sobre o que o fornecedor efetivamente vê ([71:36]-[71:52]): o pedido enviado pro fornecedor mostra só preço de custo + quantidade (ele não precisa ver o BDI interno) — a diferença é só de **visibilidade** entre o pedido "pro fornecedor" e o valor "pra nós, interno/financeiro".

## Definição da SPEC

### Causa raiz confirmada no código (itens 1 e 2)

`04-Sistemas/compras-lucenera-3o23t98ee/src/components/compra/ModalRegistrarCompra.tsx`:

- O `produto` recebido como prop já traz `fornecedor_id`/`fornecedor_nome` (vêm de `vw_necessidade_compra`, que já resolve `COALESCE(p.fornecedor_principal_id, mk.fornecedor_id)`).
- Mas ao abrir o modal (linha 74-82), o `useEffect` reseta o formulário pro estado vazio, **sem usar** `produto.fornecedor_id`:
  ```js
  useEffect(() => {
    if (!open || !produto) return
    setForm({ ...EMPTY, quantidade: String(produto.necessidade_compra) })  // fornecedorId fica '' (EMPTY)
    ...
  }, [open, produto])
  ```
- O mecanismo de pré-preencher impostos (`preencherImpostos`, linha 122-140, da SPEC-038) só é chamado dentro de `selecionarFornecedor` (linha 142-151) — ou seja, **só dispara depois que o usuário escolhe manualmente um fornecedor na lista**. Como o fornecedor nunca vem pré-selecionado, o usuário só vê os campos de imposto preenchidos se escolher manualmente o mesmo fornecedor que já estava no cadastro do produto.

### Causa raiz confirmada no banco (item 3)

RPC `criar_pedido_compra_de_necessidade` (`03_functions.sql`), linha que grava `pedidos_compra.valor_total`:
```sql
valor_total, ...
) VALUES (
  ...
  p_quantidade * p_custo_unitario,  -- só custo seco, sem ICMS/IPI/ST
  ...
```
Apesar de `custo_liquido`/`valor_icms`/`valor_ipi`/`valor_st` serem gravados por item em `pedido_compra_itens` (linhas seguintes da mesma função), eles **não entram** no cálculo de `pedidos_compra.valor_total`. Mesmo comportamento em `criar_pedido_compra_lote` (usada pelo "Fechar Pedido em Lote") — precisa confirmar se tem o mesmo problema, ela não foi lida em detalhe nesta investigação.

### Proposta (não implementar sem aprovação)

1. No `useEffect` de abertura do modal, se `produto.fornecedor_id` existir, chamar a mesma lógica de `selecionarFornecedor` automaticamente (preenche nome + dispara `preencherImpostos`) — usuário continua podendo trocar depois.
2. `criar_pedido_compra_de_necessidade` (e a versão em lote): somar `custo_liquido + valor_icms + valor_ipi + valor_st` (multiplicado pela quantidade, conforme a unidade de cada campo) ao calcular `pedidos_compra.valor_total`, em vez de só `p_quantidade * p_custo_unitario`.
3. **Sem mudar o que é impresso/enviado pro fornecedor** — a proposta do Vinícius já contempla isso: o documento do pedido continua mostrando só custo + quantidade; só o `valor_total` interno (usado no financeiro) muda.

## Análise de ecossistema

- **Depende de**: `produtos`, `marcas`, `contatos` (fornecedor), `pedidos_compra`, `pedido_compra_itens`.
- **Afeta**: só o fluxo de criação de pedido em Compras. Pode afetar o Fluxo de Caixa (`v_cash_flow_lucenera`) se essa view consumir `pedidos_compra.valor_total` como previsão — precisa confirmar antes de mudar a fórmula, pra não gerar uma mudança retroativa inesperada em relatórios já publicados.
- **Migration antiga que contradiz**: nenhuma — `custo_liquido`/impostos já existem em `pedido_compra_itens` desde a SPEC-038, só nunca foram somados no total.

## Realizado

### 2026-08-15

- **Item 3 (BDI no valor_total): achado que corrige a própria SPEC — não era bug.** Investigação mais funda mostrou que **todos os 3 pontos de entrada de UI** que chamam `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` (`ModalRegistrarCompra.tsx`, `ModalPedidoLote.tsx`, `ModalGerarCompraItemOrcamento.tsx`) já somam `custoLiquido + valorIcms + valorIpi + valorSt` **antes** de mandar pro parâmetro `p_custo_unitario` das RPCs. Como `valor_total = p_quantidade * p_custo_unitario`, o valor gravado **já inclui os impostos hoje** — a leitura isolada da RPC (sem seguir de onde vem `p_custo_unitario`) levou a uma conclusão errada na primeira passada desta SPEC. Nenhuma migration foi aplicada pra esse item. Confirmado também que nenhuma view de fluxo de caixa (`v_cash_flow_lucenera`, `vw_fluxo_caixa_projetado`) referencia `pedidos_compra` hoje — a preocupação de impacto retroativo também não se aplica.
- **Itens 1 e 2 (fornecedor + impostos pré-preenchidos): bug real, corrigido.** `ModalRegistrarCompra.tsx`: o `useEffect` de abertura passou a chamar `selecionarFornecedor` automaticamente quando `produto.fornecedor_id`/`fornecedor_nome` já vêm resolvidos de `vw_necessidade_compra` — reaproveita o mesmo caminho que já disparava `preencherImpostos` (SPEC-038), sem duplicar lógica. Usuário continua podendo trocar o fornecedor manualmente.
- Drift encontrado e corrigido antes de publicar: o arquivo local estava bem desatualizado em relação ao Skip (faltavam os campos "Empresa"/"Perfil" adicionados por outra SPEC) — sincronizado a partir do Skip antes de aplicar o fix.
- Publicado Skip 40326 v0.0.62 — QA limpo. Testado ao vivo: produto 10289 (marca Interlight) — ao abrir "Registrar Pedido de Compra" pela Necessidade de Compra, fornecedor já veio pré-selecionado ("INTERLIGHT SISTEMAS DE ILUMINACAO LTDA") e custo líquido pré-preenchido (R$ 275,12), sem precisar escolher manualmente.

## Pendências

Nenhuma.
