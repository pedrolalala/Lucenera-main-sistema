---
titulo: "SPEC-240 — Caixa fechada: quantidade do pedido de compra arredonda para a caixa"
status: no ar
data_ultima_modificacao: 2026-10-29
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee) — Fechar pedido (ModalGerarCompraItemOrcamento), usado pela Necessidade de Compra e pelo Pedido Avulso
  - Banco (Supabase SP) — produtos.multiplo_compra (já existe), produto_fornecedores.observacao/qtd_minima
---

# SPEC-240 — Caixa fechada: quantidade do pedido de compra arredonda para a caixa

> Origem: reunião com o Filippo em 29/10/2026 (`02-Reunioes/40 Lucenera (Filippo]) - 29.10.2026_ Necessidade de
> compra/Reunião.01`). Relacionadas: SPEC-026 (criou `multiplo_compra`), SPEC-066 C (observação "caixa fechada" em
> `produto_fornecedores`), SPEC-209/222 (Fechar pedido), SPEC-221 (comprar a mais vai para estoque), SPEC-214 (card que
> pede o e-mail do fornecedor quando falta), SPEC-237 (vínculo peça-fornecedor).

## O que foi pedido (reunião 29/10)

- Para a Lucenera é conveniente comprar **caixa fechada**. Hoje não existe essa informação na planilha de produto.
- Na **segunda tela** da Necessidade de Compra (a que abre depois de escolher as peças, onde se corrige a quantidade —
  o "Fechar pedido"), ter um campo **Itens por caixa**, **opcional**, preenchido aos poucos pela Débora quando ela
  trabalhar com a peça ("ela vai fazer durante a vida"; não precisa envolvê-la agora).
- **Uma vez preenchido, vira regra** da peça: toda compra seguinte já vem com a quantidade **arredondada para cima**
  até fechar a caixa. Exemplo do Filippo: precisa de 38, caixa de 10 → compra **40**.
- Mesma ideia do card do e-mail do fornecedor (SPEC-214): o dado falta, preenche ali mesmo e fica gravado no cadastro.
- Cuidado pedido pelo Filippo: toda alteração **bem explicada**, sem coluna nova à toa, sistema **limpo**; a coluna
  pode ser criada/descrita manualmente no Supabase em vez de "tudo por prompt".

## Estado encontrado (29/10)

- **A coluna já existe:** `produtos.multiplo_compra integer` (SPEC-026), com descrição no banco: *"Múltiplo de compra /
  MOQ ("caixa fechada") — pedidos devem ser arredondados para o múltiplo mais próximo deste valor. Default 1 (sem
  restrição)."* Todas as 4.918 peças estão com **1** (nenhuma regra). **Nenhuma tela ou função usa** — não precisa
  criar coluna nova.
- Compras já pode gravar nela: a política `spec069_produtos_update` libera UPDATE em `produtos` para quem pode editar na
  Necessidade de Compra.
- Já existe no Fechar pedido um botão "Adicionar observação" (`ObservacaoCaixaFechada.tsx`, SPEC-066 C) que grava
  observação + "Quantidade mínima (caixa fechada)" em `produto_fornecedores.qtd_minima`. É **só informativo** (não mexe
  na quantidade) e `qtd_minima` está vazia nas 4.303 linhas.
- **Problema achado:** a carga da SPEC-237 (28/10) gravou `observacao = 'SPEC-237: planilha Produtos da Connect
  (14/10/2026), nmFornecedor'` nos 4.303 vínculos (é a marca usada pelo rollback da 257). O Fechar pedido mostra esse
  texto técnico, em destaque amarelo, como "observação" de toda peça que tem fornecedor.
- A tela já mostra "+N a mais (estoque)" quando a quantidade passa do que as vendas pedem; o vínculo com as vendas
  reparte só o que elas precisam e o resto fica para estoque (SPEC-221). O arredondamento da caixa cai nesse caminho
  sem mudança no banco.

## Proposta

### A. Itens por caixa no Fechar pedido
1. Fonte única: `produtos.multiplo_compra` (é da **peça**, como o Filippo pediu: "coluna que está em produtos").
   O campo "Quantidade mínima (caixa fechada)" do popover passa a ler/gravar `multiplo_compra`; `qtd_minima` deixa de
   ser usada (está vazia — nada a migrar). A observação livre continua em `produto_fornecedores`.
2. Na linha da peça, um selo "Caixa: 10" quando `multiplo_compra > 1`; "Itens por caixa" vazio quando é 1.
3. Ao abrir o Fechar pedido, quantidade = necessidade arredondada **para cima** ao múltiplo
   (`ceil(qtd / caixa) × caixa`). Ex.: 38 → 40. Ao lado: "38 p/ vendas · +2 caixa fechada (estoque)".
4. Preencheu/alterou "Itens por caixa" na tela → grava na peça e **recalcula a linha na hora**. Vale para todas as
   compras seguintes (Necessidade de Compra e Pedido Avulso, que usam a mesma tela).
5. Vazio ou 1 = sem regra (como hoje). Só número inteiro ≥ 1.

### B. Limpar a observação técnica da SPEC-237
- Tirar o texto `SPEC-237: ...` da observação dos 4.303 vínculos (o vínculo continua) e trocar a marca do rollback da
  257 por outro critério (data de criação da carga). Assim a observação volta a ser só o que a Débora escrever.

### C. Sem mudança
- Necessidade de Compra (grid principal) continua mostrando a necessidade real; o arredondamento só acontece no pedido.
- Nenhuma coluna nova no banco. Se o usuário preferir, a única mudança de banco (descrição da coluna) pode ser feita à
  mão no Supabase.

## Decisões (usuário, 29/10)

- [x] Quantidade digitada fora da caixa: **aceita com aviso amarelo** "Não fecha caixa de N" (o fornecedor às vezes
      vende avulso).
- [x] Caixa **por peça** (`produtos.multiplo_compra`).
- [x] Só **a Débora e a administração** alteram "Itens por caixa": lista `produto_caixa_editores` (Débora) + role
      `admin` + papel `administracao_comercial` (Carol, Lana, Filippo, Vinicius, Pedro). Travado no banco por gatilho.
- [x] B: **não limpar** a observação técnica da SPEC-237 no banco. Em vez disso, a tela **esconde** observação que começa
      com "SPEC-237:" (o dado e a marca do rollback da 257 continuam). Se a Débora escrever uma observação nova na peça,
      ela substitui a marca daquele vínculo (o rollback da 257 deixa de achar só esse).
- [x] Mostrar e editar a caixa também no **Cadastro** (edição da peça).

## Checklist de Ação

- [x] Usuário responder as decisões (29/10).
- [x] Migration 260 (`20261029_260_spec240_caixa_fechada`): descrição da coluna, CHECK ≥ 1, `produto_caixa_editores`
      (Débora), `pode_editar_caixa_fechada()`, gatilho `trg_produtos_multiplo_compra_editor` (só trava quem está logado;
      scripts/serviço passam). Dry-run 29/10: Débora e Carol podem, Matheus é barrado; trocar `multiplo_compra` não
      muda nenhuma outra coluna da peça (preço/custo) — conferido em 50 peças.
- [x] Compras: popover "Caixa / observação" com **Itens por caixa** (inteiro; desabilitado para quem não pode);
      quantidade abre arredondada; salvar a caixa recalcula a linha na hora; aviso "Não fecha caixa de N";
      "+N a mais (caixa fechada, estoque)"; observação "SPEC-237: ..." escondida; `qtd_minima` deixou de ser gravada.
- [x] Cadastro: campo **Itens por caixa** na edição da peça (somente leitura para quem não pode).
- [x] Aplicar a 260 (29/10) e publicar Compras (`ca6e46d`) e Cadastro (`93264ad`).
- [ ] Teste: peça com necessidade 38, preencher caixa 10 → linha vira 40, "+2 caixa fechada (estoque)"; fechar o pedido
      e conferir que a venda recebeu 38 e o pedido tem 40; abrir outra compra da mesma peça → já vem arredondada.

## Critérios de aceite

- Peça sem caixa (1/vazio): Fechar pedido igual a hoje.
- Peça com caixa N: quantidade inicial é o menor múltiplo de N ≥ necessidade; o excedente aparece como estoque e não
  é vinculado a venda.
- Preencher a caixa uma vez faz a regra valer nas compras seguintes, sem retrabalho.
- Nenhum texto técnico ("SPEC-237: ...") aparece como observação para o usuário.
