---
titulo: "SPEC-145 — Enquadramento dos cards (fim da rolagem lateral) em Separação Parcial e Projetos do CRM"
status: pendente
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Separação (separacao-parcial) — `SeparacaoParcialPage.tsx` (tabela de itens da venda)
  - CRM (lucenera-crm) — `Projetos.tsx` (tabela principal) e `Layout.tsx` (largura do container)
---

# SPEC-145 — Enquadramento dos cards (fim da rolagem lateral) em Separação Parcial e Projetos do CRM

> Origem: usuário reportou que dois cards do sistema exigem rolagem horizontal pra ver todo o conteúdo — a tabela de itens da tela de Separação Parcial (após abrir uma venda) e a tabela principal de Projetos do CRM. Confirmado ao vivo pelo usuário (colando a estrutura de colunas real de cada tela) quais eram exatamente as duas telas, depois de uma primeira tentativa errada de identificação.

## Checklist de Ação

- [x] `separacao-parcial/src/pages/SeparacaoParcialPage.tsx`: remover `max-w-[1400px]` do `<main>`, remover `truncate`/`max-w-[…px]` das colunas Referência/Descrição/Local (L), compactar (padding + `whitespace-nowrap`) as colunas numéricas (Q. Dev., Q. Venda, E. Futura, Transferido, Reserva, À Separar, Ag. Separar, Separado, Entregue).
- [x] `lucenera-crm-3bd29/src/components/Layout.tsx`: remover `max-w-[1400px]` do `<main>` (afeta todas as páginas do CRM, não só Projetos — decisão abaixo).
- [x] `lucenera-crm-3bd29/src/pages/Projetos.tsx`: remover `min-w-[700px]` forçado, remover `truncate`/`max-w-[…px]` das colunas Projeto/Responsável/Engenheiro-Arquiteto/Cidade, compactar as colunas curtas (Código, Nível, Data Entrada, Status, Data Fechamento, Valor Total, Estado, Ações).
- [x] `npx tsc --noEmit` + `npm run build` nos dois sistemas (sem erros).
- [x] Validação visual: mockup HTML isolado (mesmas classes Tailwind) com texto longo real (ex.: descrição de peça, nome de projeto) confirmando que o texto quebra linha, as colunas numéricas ficam compactas e a tabela não gera scroll horizontal em 1920px.
- [ ] Validar ao vivo dentro do app publicado (login real), em resolução de monitor de operação — não foi possível logar nas duas telas nesta sessão (sem credencial de teste à mão); a validação até aqui foi via `tsc`/`build` limpos + mockup estático com as mesmas classes.
- [ ] `skip_project_apply_changes` (QA) + `skip_project_publish` dos dois sistemas.

### Passos manuais do usuário

- [ ] Nenhum previsto — mudança é só CSS/layout (classe Tailwind), não mexe em schema nem em dado.

## Objetivo

As duas telas usam `<table>` do shadcn/ui com larguras fixas (`max-w-[…px] truncate`) nas colunas de texto e paddings padrão (16px) em todas as colunas — inclusive as numéricas curtas. A soma ultrapassa a largura do container, then o `overflow-x-auto` do wrapper força rolagem lateral pra ver colunas à direita (inclusive a de ação). Objetivo: cada card ocupar a largura total disponível, colunas de texto (Descrição/Projeto/Responsável/etc.) crescerem e quebrarem linha em vez de truncar com reticências, colunas numéricas ficarem compactas, e a rolagem lateral deixar de ser necessária em resolução de monitor de operação.

## Decisões aprovadas

- **Como funciona sem `table-layout: fixed` nem % explícito por coluna**: as tabelas usam layout `auto` (padrão do navegador, sem `table-layout: fixed` em nenhum dos dois `table.tsx`). Colunas numéricas ganharam `whitespace-nowrap` (não quebram, ficam do tamanho do conteúdo) + padding reduzido (`px-2`/`px-3` em vez do `p-4`/`px-4` padrão). Colunas de texto (Descrição, Projeto, Responsável, Engenheiro/Arquiteto, Cidade, Referência, Local) perderam `truncate`/`max-w-[…px]` — sem `whitespace-nowrap`, o `<td>` volta ao comportamento padrão do navegador (quebra linha) e, como é a única coluna "elástica" da linha, o navegador aloca nela todo o espaço que sobrar depois das colunas de largura fixa. Não foi necessário `flex`/`grid` nem reescrever a tabela.
- **`max-w-[1400px]` removido no `<main>` das duas telas**: no CRM isso está no `Layout.tsx` compartilhado por todas as páginas (Dashboard, Contatos, Configurações etc.), não só Projetos — decisão consciente de aplicar globalmente em vez de criar uma exceção só pra essa página, já que o pedido do usuário foi "aproveitar o espaço em branco desperdiçado" e o `SidebarInset` do shadcn já delimita corretamente o espaço disponível (não tem risco de sobrepor a sidebar). Páginas com grid/flex responsivo simplesmente ganham mais respiro lateral — não achamos layout que quebre com container mais largo, mas isso ainda não foi validado visualmente ao vivo (ver pendência abaixo).
- **Overflow-x-auto mantido como rede de segurança**: não foi removido o wrapper `overflow-x-auto` em nenhuma das duas tabelas — ele só deixa de ser acionado nas larguras normais de operação depois da compactação de colunas; em telas muito estreitas (ex. janela redimensionada bem pequena) ele evita que a tabela "quebre" o layout da página, em vez de eliminar a rolagem por completo em qualquer largura (fisicamente não dá pra garantir isso com 13 colunas numa tela muito estreita).
- **Arquivos `SystemSwitcher.tsx`/`useSistemasPermitidos.ts` (não rastreados em ambos submodules) não foram tocados** — são trabalho em andamento de outra sessão/tarefa (já referenciado em `Layout.tsx` mas ainda sem commit); os commits desta SPEC tocam só os arquivos relacionados ao enquadramento dos cards.

## Definição da SPEC

### Antes → Depois (padrão aplicado nas duas tabelas)

| Tipo de coluna | Antes | Depois |
|---|---|---|
| Texto principal (Descrição / Projeto) | `max-w-[Npx] truncate` (corta com reticências) | sem `max-w`, `min-w-[200/220px]`, quebra linha — cresce pra ocupar o espaço livre |
| Texto secundário (Referência, Local, Responsável, Eng./Arquiteto, Cidade) | `max-w-[Npx] truncate` + `title=` pro tooltip | sem `max-w`/`truncate`/`title`, `break-words` — quebra linha em vez de cortar |
| Numérica/curta (Q.*, Reserva, Separado, Entregue, Código, Data, Status, Estado, Ações) | padding padrão (`p-4`/`px-4`), sem `whitespace-nowrap` explícito | `whitespace-nowrap` + `px-2`/`px-3` (padding reduzido) |
| Container da página (`<main>`) | `max-w-[1400px] w-full mx-auto` | `w-full` (sem teto de largura) |
| Wrapper da tabela (CRM) | `min-w-[700px]` (forçava scroll em containers menores) | removido |

### Por que isso resolve sem CSS Grid/Flex na tabela

Com `table-layout: auto` (padrão), o navegador calcula a largura de cada coluna a partir do conteúdo. Colunas `whitespace-nowrap` viram "rígidas" (largura = conteúdo, não encolhem nem crescem). A única coluna sem `whitespace-nowrap` (Descrição/Projeto) é a que sobra pra "elástica": ela recebe toda a largura que não foi consumida pelas colunas rígidas, e por não ter `nowrap` o texto quebra em vez de estourar a largura do container. É o mesmo efeito prático de um `flex-grow: 1`, só que nativo de tabela HTML — sem reescrever pra `<div>`/grid.

## Realizado

### 2026-09-15

- Aplicado o padrão acima nas duas tabelas (`SeparacaoParcialPage.tsx` e `Projetos.tsx`) e no container global do CRM (`Layout.tsx`) e da Separação Parcial (`SeparacaoParcialPage.tsx`, `<main>`).
- `npx tsc --noEmit` e `npm run build` rodados nos dois sistemas — sem erro.
- Validação visual feita via mockup HTML estático (mesmas classes Tailwind, mesma estrutura de `<table>`), com texto de descrição/nome de projeto propositalmente longo, em viewport largo — confirmado: texto quebra linha, colunas numéricas compactas, sem scrollbar horizontal.
- Não foi possível logar nos apps reais nesta sessão (sem credencial de teste registrada em memória) — falta validação ao vivo antes de publicar.

## Pendências

- [ ] Validar ao vivo (login real) nas duas telas, em monitor de operação, antes de publicar via Skip — a validação desta sessão foi por mockup estático com as mesmas classes CSS, não pela aplicação rodando de verdade.
- [ ] Publicar (`skip_project_apply_changes` + `skip_project_publish`) nos dois sistemas depois da validação ao vivo.
