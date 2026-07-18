---
titulo: "SPEC-032 — Cabeçalho único (não repetido por linha) na lista de Itens do Orçamento"
status: implementado e publicado — aguardando conferência visual do usuário
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
dependencias: []
---

# SPEC-032 — Cabeçalho único na lista de Itens do Orçamento

## Checklist de Ação

- [x] Extrair um cabeçalho de colunas único (`Luminária | Código Produto | Código de Referência | Produto | Qtd | Preço Unit. | Desc % | Subtotal`), renderizado uma vez acima da lista de itens, replicando exatamente a mesma grade de larguras (`shrink-0 lg:w-[60px]`, `lg:w-[110px]`, `lg:w-[130px]`, `flex-1`, `lg:w-[80px]`, `lg:w-[120px]`, `lg:w-20`, `lg:w-28`) usada em `BudgetItemCard.tsx` — componente novo `BudgetItemsHeader.tsx`, `hidden lg:flex`.
- [x] Remover o `FormLabel`/rótulo por campo de dentro de `BudgetItemCard.tsx` **apenas na largura `lg:` (desktop)** — classe `fieldLabelClass = 'lg:hidden text-[10px] ...'` aplicada a todos os rótulos por campo; mobile mantido sem alteração (confirmado pelo usuário: "não foque no celular").
- [x] Resolver a divergência de rótulo entre "Produto" e "Descrição do Produto" — cabeçalho fixo usa `Produto` (proposta original desta SPEC, sem objeção do usuário).
- [x] Ajustar `BudgetItemCard.tsx` para renderizar sem o próprio rótulo em desktop — `FormLabel` continua no DOM (mantém associação de acessibilidade), só fica visualmente oculto via `lg:hidden`, não removido.
- [ ] Verificar visualmente as duas larguras de tela (desktop `lg:` e mobile) depois da mudança — **não verificado no navegador nesta sessão**, só QA automática do Skip (build real, sem erro).
- [x] Rodar `oxlint`/`vite build` do sistema após a mudança — limpo, 0 erros, mesma contagem de warnings de antes (nenhum novo nos arquivos tocados).

## Objetivo

Na tela de edição de orçamento (`BudgetFormPage.tsx`), a seção "Itens do Orçamento" renderiza um `BudgetItemCard` por item (`src/components/budgets/BudgetItemCard.tsx`), e cada card repete o rótulo de cada coluna (`Luminária`, `Código Produto`, `Código de Referência`, `Produto`, `Qtd`, `Preço Unit.`, `Desc %`, `Subtotal`) acima do próprio campo. Em orçamentos com muitos itens, isso repete o mesmo texto dezenas de vezes, ocupando espaço vertical desnecessário (evidência: print anexado pelo usuário, mostrando os rótulos riscados em vermelho se repetindo a cada linha).

Esta SPEC move esses rótulos para um cabeçalho único, fixado uma vez no topo da lista — como um cabeçalho de tabela — em vez de repetir por item, para economizar espaço vertical na tela em telas largas (desktop), preservando a legibilidade no layout mobile empilhado.

## Decisões aprovadas

Nenhuma decisão de negócio nova aqui além do pedido do usuário ("cabeçalho aparece uma vez só, não repete por peça, para economizar espaço") — é uma mudança puramente visual/de layout, sem impacto em dado, RPC ou regra de negócio. Duas decisões de UI ficam em aberto (ver Pendências) porque afetam comportamento visível e não foram especificadas pelo usuário:

1. **Comportamento em mobile**: confirmado por Pedro em 2026-07-18 ("não foque no celular") — mobile fica exatamente como está hoje, sem nenhuma mudança. O cabeçalho único só existe a partir do breakpoint `lg:` (desktop); abaixo disso, cada campo mantém seu próprio rótulo, sem alteração de layout/design.
2. **Rótulo único para a coluna "Produto"**: hoje o campo mostra "Produto" (quando há `produto_id`) ou "Descrição do Produto" (item avulso). Proposta: cabeçalho fixo com o texto "Produto", cobrindo os dois casos. Alternativa seria manter dois cabeçalhos de coluna que aparecem/somem conforme o tipo predominante de item na lista — mais complexo, não recomendado sem necessidade clara.

## Definição da SPEC

### Arquivos envolvidos

- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/BudgetItemCard.tsx`: hoje cada campo (`custom_id`, `codigo_produto` read-only, `sku` read-only, `produto_id`/`descricao`, `quantidade`, `preco_unitario`, `desconto`, subtotal calculado) tem seu próprio `FormLabel`/`<span>` de rótulo, renderizado a cada card (uma vez por item do orçamento). As larguras de cada coluna já são fixas via classes Tailwind (`lg:w-[60px]`, `lg:w-[110px]`, `lg:w-[130px]`, `flex-1`, `lg:w-[80px]`, `lg:w-[120px]`, `lg:w-20`, `lg:w-28`) — o cabeçalho novo precisa replicar exatamente essas larguras para os textos ficarem alinhados com os campos abaixo.
- `04-Sistemas/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx` (linha ~1543, dentro do `CardContent` da seção "Itens do Orçamento", antes do `<div className="space-y-4">{fields.map(...)}</div>`): é onde o novo cabeçalho único deve ser inserido, uma vez, antes do loop que renderiza um `BudgetItemCard` por item.

### Abordagem técnica proposta

- Criar um componente novo (ex.: `BudgetItemsHeader.tsx`) com a mesma estrutura de `flex`/larguras de `BudgetItemCard.tsx`, mas só com os textos dos rótulos — sem inputs. Renderizado uma vez em `BudgetFormPage.tsx`, visível apenas em `lg:` (`hidden lg:flex`), imediatamente antes do `<div className="space-y-4">`.
- Em `BudgetItemCard.tsx`, cada `FormLabel`/rótulo de campo passa a ter uma classe condicional que o esconde em telas `lg:` e o mantém visível abaixo disso (ex.: `lg:hidden` nas classes atuais, mantendo os textos existentes) — assim o mesmo componente serve tanto para o card completo em mobile quanto para a versão "sem rótulo" em desktop, sem duplicar o JSX de cada campo.
- O botão de remover item (coluna sem rótulo hoje) não precisa de entrada no cabeçalho — pode ficar como uma célula vazia do mesmo tamanho, ou sem entrada nenhuma no cabeçalho (mais simples).

### O que esta SPEC não muda

- Nenhuma coluna é removida, renomeada (exceto a unificação "Produto"/"Descrição do Produto" descrita acima) ou tem seu comportamento alterado.
- Nenhuma mudança de banco, RPC ou validação — é puramente de apresentação.
- O agrupamento visual por luminária (badge/pill com o código do circuito entre grupos de itens, ex. `L17`, `L77`) continua exatamente como está — não é o que o usuário pediu para mudar.

## Critério de aceite

- Em tela larga (`lg:` e acima), os rótulos de coluna (`Luminária`, `Código Produto`, `Código de Referência`, `Produto`, `Qtd`, `Preço Unit.`, `Desc %`, `Subtotal`) aparecem **uma única vez**, no topo da lista de itens, alinhados com as colunas correspondentes de cada linha abaixo.
- Em tela estreita (mobile, abaixo de `lg:`), cada campo continua mostrando seu próprio rótulo, como hoje.
- Nenhuma funcionalidade existente (buscar produto, criar produto, editar quantidade/preço/desconto, remover item, cálculo de subtotal) muda de comportamento.
- `oxlint` e `vite build` do sistema passam sem novo erro.

## Realizado

### 2026-07-18

- **Frontend implementado** em `04-Sistemas/gestao-financeira-clone-544cb (1)`: `BudgetItemsHeader.tsx` (novo), `BudgetItemCard.tsx` (rótulos por campo com `lg:hidden`), `BudgetFormPage.tsx` (import + `{fields.length > 0 && <BudgetItemsHeader />}` antes da lista de itens).
- **Commit + push sem conflito** (`2e139e8`) — desta vez `origin/main` não tinha divergido do meu clone local (diferente da SPEC-031).
- **Publicado em produção via Skip MCP**: antes de escrever, li o estado atual de `BudgetFormPage.tsx` no Skip e descobri que ele tem um campo inteiro (`prazo_entrega_dias` — no `formSchema`, `defaultValues`, `form.reset`, payload do `onSubmit` e um `FormField` de UI completo) que **não existe em nenhum lugar do GitHub**. Não sobrescrevi esse arquivo por completo — usei `skip_file_patch` (SEARCH/REPLACE) para inserir só as 2 linhas necessárias (import de `BudgetItemsHeader` + `{fields.length > 0 && <BudgetItemsHeader />}`), preservando tudo o mais que já existia no Skip. `BudgetItemCard.tsx` foi conferido idêntico ao baseline antes de sobrescrever por completo (seguro). QA do Skip limpo (setup/lint/build/integrações/testes). Publicado: versão `0.0.295`, `publishedRef 9159433`, em `https://gestao-financeira-clone-544cb.goskip.app`.
- **Não verificado**: conferência visual manual no navegador (desktop e mobile) — só a QA automática do Skip (build sem erro) confirma que compila; não confirma que o alinhamento visual do cabeçalho bate exatamente com as colunas de cada linha.

## Pendências

- [ ] **Conferir visualmente no app publicado** (desktop: cabeçalho alinhado com as colunas; mobile: nada mudou) — não verificado nesta sessão.
- [ ] **Investigar a origem do campo `prazo_entrega_dias`** que existe no Skip mas não no GitHub (achado nesta sessão, mesma classe de risco já registrada na SPEC-031 sobre divergência Skip x GitHub) — pode ser um campo que alguém adicionou direto pela UI/IA do Skip e nunca foi trazido de volta pro repositório, ou um campo que existiu no GitHub e foi removido sem essa remoção ter sido propagada ao Skip. Vale decidir se esse campo deve ser trazido de volta para o código-fonte versionado (GitHub) ou removido do Skip.