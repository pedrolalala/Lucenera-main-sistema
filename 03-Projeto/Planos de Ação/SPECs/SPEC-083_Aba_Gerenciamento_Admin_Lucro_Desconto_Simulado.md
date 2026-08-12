# SPEC-083: Aba "Gerenciamento" (admin) — lucro por peça e desconto simulado

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Rascunho — aguardando confirmação das decisões em aberto antes de implementar

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

## Decisões em aberto (preciso da sua confirmação antes de implementar)

1. **Onde abre o painel**: modal grande (Dialog) sobre a tela atual, ou uma aba/seção que substitui o conteúdo da página (como um "tab" de verdade, saindo do formulário)? O pedido fala em "aba nova" — pode ser só um Dialog full-width com a tabela dentro (mais simples, não perde o estado do formulário embaixo) ou uma rota separada. Recomendo o Dialog, mais simples e não arrisca perder dados não salvos do orçamento em edição.
2. **Peças sem produto cadastrado** (avulsas, "Adicionar Item não Cadastrado"): como não têm `preco_custo`, como tratar na tabela — mostrar linha com custo "—"/não calculável e excluir do lucro total, ou pedir pro admin digitar um custo manual ali mesmo (só pra essa simulação, sem salvar)?
3. **O desconto simulado é só cálculo, ou pode ser aplicado de verdade?** Pelo exemplo dado (Vinícius decidindo "posso dar 15%?"), parece que é só uma calculadora — mas faz sentido ter um botão "Aplicar esse desconto ao orçamento" que preenche o campo `Desconto Global` já existente no formulário principal, pra não precisar digitar de novo? (Recomendo sim, evita retrabalho.)
4. **`role === 'admin'` sozinho, ou `admin` + `gerente`** (mesmo critério já usado pro botão "Aprovar Financeiro")? Dado que o pedido especifica "só administradores", vou seguir só `admin` a menos que você confirme que gerente também deve ver.
5. **Orçamento novo (ainda não salvo)**: a aba deve funcionar usando os itens já adicionados na tela (ainda em memória, sem `id` no banco) — os valores de venda vêm do formulário local, sem round-trip ao banco. Confirma que faz sentido mostrar a simulação mesmo antes de salvar?

## Fora de escopo (a menos que você peça)

- Nenhuma migration — todos os dados necessários (`preco_custo`, `preco_unitario`) já existem.
- Nenhuma mudança de RLS — a leitura de `produtos.preco_custo` já é permitida pra `authenticated` (mesma tabela já lida em outros pontos do sistema); o controle de acesso à aba é 100% no frontend (gate por `role`), como o padrão já usado em "Aprovar Financeiro".
- Réplica dessa aba em outros sistemas (CRM, Compras) — pedido foi só pro Orçamentos.
