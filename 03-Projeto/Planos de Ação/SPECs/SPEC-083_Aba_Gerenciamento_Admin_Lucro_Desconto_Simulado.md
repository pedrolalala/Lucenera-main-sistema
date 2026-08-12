# SPEC-083: Aba "Gerenciamento" (admin) — lucro por peça e desconto simulado

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Publicado em produção (Skip 32554, v0.0.322, hash `32bbecb`)

## Pedido do usuário (resumo)

Uma aba nova, acessível só por administradores, tanto na criação quanto na edição de um orçamento, via um menu "⋮" (três pontinhos) no topo da tela → opção "Gerenciamento". Abre um painel com todas as peças do orçamento, mostrando por peça: valor de venda, valor de custo, lucro (R$) e percentual de lucro. Tem também um campo de percentual de desconto que recalcula automaticamente o lucro resultante — serve pra um admin (o exemplo dado foi o Vinícius) simular "posso dar 15% de desconto nesse orçamento? quanto sobra de lucro?" antes de decidir. É uma ferramenta de análise da negociação, não uma tela de edição do orçamento em si.

## O que já existe no código (investigado antes de escrever esta SPEC)

- `BudgetFormPage.tsx` já tem `const { role } = useAuth()` e já usa o padrão `role === 'admin' || role === 'gerente'` pra gatear uma ação sensível (botão "Aprovar Financeiro", linha ~1649) — mesmo padrão a reaproveitar aqui.
- Não existe hoje nenhum menu "⋮"/dropdown no cabeçalho do formulário de orçamento (nem em nenhum outro lugar do sistema Orçamentos) — precisa ser criado do zero, ao lado dos botões "Cancelar"/"Criar Orçamento"/"Exportar XML" já existentes no cabeçalho (mesma área, linha ~1646).
- `produtos` já tem os campos de custo necessários: `preco_custo`, `custo_total`, `percentual_lucro`, `margem_lucro`, `preco_venda`/`valor_venda`. A query que carrega itens do orçamento pra edição (`orcamento_itens(...)` em `BudgetFormPage.tsx` ~linha 463) hoje só busca `codigo_produto, referencia, nome, sku` do produto — **não busca `preco_custo`**, precisa ser incluído no select ou buscado à parte pela aba nova (o valor de venda de cada peça já existe no próprio item do orçamento, em `preco_unitario`).
- Peças "avulsas" (sem `produto_id` válido, criadas via "Adicionar Item não Cadastrado") não têm `preco_custo` cadastrado em lugar nenhum — não têm como calcular lucro real pra essas linhas.

## Comportamento proposto

- Botão "⋮" no cabeçalho do formulário (visível só se `role === 'admin'`), com uma opção "Gerenciamento" no menu.
- Ao clicar, abre um painel/aba (modal ou seção expansível — ver decisão em aberto #1) mostrando uma tabela: Peça | Qtd | Valor de Venda (unitário e/ou total) | Valor de Custo (unitário e/ou total) | Lucro (R$) | Lucro (%).
- Um campo "Desconto simulado (%)" no topo do painel: ao digitar, recalcula em tempo real o lucro de cada linha e o lucro total do orçamento **como se** esse desconto fosse aplicado — só um cálculo, não grava nada no orçamento (a menos que a decisão em aberto #3 defina o contrário).
- Totais no rodapé: Subtotal de venda, Subtotal de custo, Lucro total (R$ e %) — com e sem o desconto simulado.

## Decisões confirmadas pelo usuário

1. **Onde abre o painel**: Dialog (modal) sobre a tela atual — não sai do formulário, não arrisca perder dados não salvos.
2. **Peças sem produto cadastrado** (avulsas): admin digita um custo manual direto na tabela, só pra essa simulação — nunca é salvo em lugar nenhum.
3. **Desconto simulado**: pode ser aplicado de verdade — botão "Aplicar ao orçamento" preenche `desconto_tipo='percentual'` + `desconto_global` no formulário principal.
4. **Acesso**: `role === 'admin' || role === 'gerente'` — mesmo critério já usado no botão "Aprovar Financeiro".
5. **Orçamento novo (ainda não salvo)**: confirmado implicitamente pela escolha do Dialog — o painel lê `form.watch('itens')` diretamente (itens em memória), funciona igual em criação e edição, sem round-trip ao banco pros itens.

## Implementação

- **Novo componente** `src/components/budgets/GerenciamentoDialog.tsx`: recebe os itens do formulário (via prop, não busca sozinho), busca `produtos.preco_custo` pros produtos cadastrados presentes no orçamento (só quando o Dialog abre), permite custo manual por linha pras peças avulsas, calcula lucro/lucro% por linha e total com um desconto simulado (input percentual, aplicado uniformemente sobre a venda de cada linha antes do cálculo de lucro). Botão "Aplicar ao orçamento" chama a prop `onAplicarDesconto`.
- **`BudgetFormPage.tsx`**: novo botão "⋮" no cabeçalho (`DropdownMenu`, ícone `MoreVertical`), visível só pra admin/gerente, com item "Gerenciamento" que abre o dialog. Novo `produtoNomesMap` (via `useMemo` sobre `produtos` do `useOptions()`) resolve o nome de cada peça pro dialog. `onAplicarDesconto` escreve em `form.setValue('desconto_tipo', ...)` e `form.setValue('desconto_global', ...)`.
- Lucro % calculado como margem sobre a venda já com desconto (`lucro / venda_com_desconto * 100`), não markup sobre custo — assunção não confirmada explicitamente com o usuário, mas é a leitura mais comum de "percentual de lucro" nesse tipo de painel; fácil de trocar se o usuário quiser markup.

## Fora de escopo (não implementado)

- Nenhuma migration — todos os dados necessários (`preco_custo`, `preco_unitario`) já existiam.
- Nenhuma mudança de RLS — a leitura de `produtos.preco_custo` já é permitida pra `authenticated`; o controle de acesso à aba é 100% no frontend (gate por `role`), como o padrão já usado em "Aprovar Financeiro".
- Réplica dessa aba em outros sistemas (CRM, Compras) — pedido foi só pro Orçamentos.

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos.
- QA do Skip (setup/staticAnalysis/build/integrations/test) passou antes do publish.
- **Não verificado ao vivo na UI**: a conta de teste usada nesta sessão (`pedrollaghi@gmail.com`) tem `role='viewer'`, não `admin`/`gerente` — não vê o menu "⋮". Verificação ficou restrita a leitura de código + build + QA do Skip. Recomendo o usuário (ou alguém com role admin/gerente) testar na prática antes de considerar 100% validado.
