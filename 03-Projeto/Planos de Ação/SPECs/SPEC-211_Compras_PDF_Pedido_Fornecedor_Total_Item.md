---
titulo: "SPEC-211 — Compras: PDF do pedido para o fornecedor e total do item na edição"
status: pendente
data_ultima_modificacao: 2026-10-20
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, compras-lucenera.pages.dev)
---

# SPEC-211 — Compras: PDF do pedido para o fornecedor e total do item na edição

## Checklist de Ação

- [x] Pedidos › Aguardando aprovar: botão **PDF** na linha do pedido, que baixa o pedido em PDF para enviar ao fornecedor
- [x] PDF no mesmo layout do PDF do orçamento, com as informações para o fornecedor
- [x] Editar pedido: coluna **Total do item (R$)** = quantidade × total por unidade (com impostos)
- [x] `vite build` ok; PDF gerado e conferido com o pedido real 1783 (1 página) e com 42 itens + parcelas + desconto (2 páginas)
- [x] Publicar (Cloudflare `compras-lucenera.pages.dev`)

### Passos manuais do usuário

- [ ] Em Pedidos › Aguardando aprovar, clicar em PDF e conferir o arquivo
- [ ] Em Editar pedido, conferir a coluna Total do item (ex.: 30 × R$ 17,00 = R$ 510,00)

## Objetivo

Pedido do usuário em 20/10/2026:
- "em pedidos, em aguardando aprovar, eu preciso que tenha um botão para exportar o PDF para enviar para o fornecedor
  ... pode ser igual orçamento atual, só que com as informações para o fornecedor";
- "dentro de editar pedido eu preciso trazer a soma dos itens, não só o valor unitário ... 30 peças que custam R$17,
  e logo embaixo a mesma peça com quantidade 6, e eu preciso visualizar o preço total também".

## Definição da SPEC

### PDF do pedido (fornecedor)

- Gerado no navegador com `pdf-lib` 1.17.1 (mesma biblioteca da Edge Function `generate-report` do orçamento),
  carregada só no clique. A Edge Function do orçamento não foi mexida: ela é compartilhada e tem várias cópias.
- `src/lib/pdf-pedido-fornecedor.ts` busca os dados e baixa o arquivo; `src/lib/pdf-pedido-fornecedor-desenho.ts`
  desenha (sem nada do navegador, para poder ser testado fora dele).
- Layout (igual ao orçamento):
  - logo Lucenera (mesmo recorte) e dados da **empresa que compra**: nome, razão social, CNPJ/IE, endereço, telefone;
  - à direita: "Aceite do Fornecedor", assinatura da empresa, data de impressão e de emissão, "1 de N";
  - "Pedido de compra para" + **fornecedor** (nome, razão social, CNPJ/CPF, endereço, CEP/cidade, telefone, e-mail);
    à direita, "Pedido de Compra" + número;
  - Comprador (quem criou o pedido), Previsão de entrega, Local de entrega;
  - itens: Código, Referência, Descrição, Un., Qtd., Vl. Unit. (preço de custo sem impostos), Subtotal;
  - caixa de totais: Total dos produtos, IPI, ST, Outras despesas (só os que existem), Desconto (%), **Valor Total**
    (o `valor_total` gravado no pedido);
  - Condições de pagamento: parcelas do pedido (número, vencimento, valor) ou o texto da condição;
  - Observações: a observação do pedido + "Favor mencionar o número do pedido na nota fiscal" + "Confirmar
    quantidades, preços e prazo de entrega antes do faturamento".
- Não vão para o fornecedor: L, cliente/venda de origem, nada do orçamento do cliente.
- Arquivo: `Pedido_Compra_<número>.pdf`.

### Editar pedido

- Nova coluna "Total do item (R$)" depois de "Total (R$/un.)": quantidade × total por unidade. Atualiza enquanto
  se digita; linha marcada "Tirar" fica riscada.

## Realizado

### 2026-10-20

- Compras: botão PDF em Aguardando aprovar; total do item na edição; `pdf-lib` adicionada (pnpm 11).
- Testado: PDF real do pedido 1783 (Stella, 7 itens) e versão com 42 itens/parcelas/desconto/observação em 2 linhas.
  Leitura dos dados conferida como a Débora (papel funcionário): pedido, empresa, fornecedor, comprador, itens, produtos.
- Observação: o valor total do pedido pode diferir em R$ 0,01 da soma das linhas (arredondamento dos impostos por unidade).
