---
titulo: "SPEC-145 — Enquadramento dos cards (fim da rolagem lateral) em Separação Parcial e Projetos do CRM"
status: concluído
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
- [x] `skip_file_read` nos dois projetos Skip (48801/24580) antes de escrever — achado: `Projetos.tsx`/`Layout.tsx` do CRM tinham divergido do submodule local (ver decisão abaixo); o fix foi então aplicado via `skip_file_patch` direto em cima do conteúdo real do Skip, não por cima do arquivo local.
- [x] `skip_project_apply_changes` (QA completo: setup/static/build/test — todos `ok:true`) + `skip_project_publish` nos dois projetos (separacao-parcial `48801` v0.0.40/`ebf5567`; Lucenera CRM `24580` v0.0.313/`c511568`).
- [x] Confirmado ao vivo por `curl` no bundle JS de produção (chunk `SeparacaoParcialPage-*.js` e `Projetos-*.js`): classes antigas (`max-w-[240px]`, `w-[160px]...whitespace-nowrap`, `max-w-[1400px]`) ausentes; classes novas (`break-words`, `min-w-[140px]`, `p-4 md:p-8 lg:p-10 w-full`) presentes — o fix está mesmo no ar, não só commitado.
- [x] Sincronizado `04-Sistemas/lucenera-crm-3bd29 (1)/src/pages/Projetos.tsx` local com o conteúdo real pós-patch do Skip (commit separado), corrigindo o drift achado nesta SPEC.

### Passos manuais do usuário

- [ ] Nenhum previsto — mudança é só CSS/layout (classe Tailwind), não mexe em schema nem em dado.

## Objetivo

As duas telas usam `<table>` do shadcn/ui com larguras fixas (`max-w-[…px] truncate`) nas colunas de texto e paddings padrão (16px) em todas as colunas — inclusive as numéricas curtas. A soma ultrapassa a largura do container, then o `overflow-x-auto` do wrapper força rolagem lateral pra ver colunas à direita (inclusive a de ação). Objetivo: cada card ocupar a largura total disponível, colunas de texto (Descrição/Projeto/Responsável/etc.) crescerem e quebrarem linha em vez de truncar com reticências, colunas numéricas ficarem compactas, e a rolagem lateral deixar de ser necessária em resolução de monitor de operação.

## Decisões aprovadas

- **Como funciona sem `table-layout: fixed` nem % explícito por coluna**: as tabelas usam layout `auto` (padrão do navegador, sem `table-layout: fixed` em nenhum dos dois `table.tsx`). Colunas numéricas ganharam `whitespace-nowrap` (não quebram, ficam do tamanho do conteúdo) + padding reduzido (`px-2`/`px-3` em vez do `p-4`/`px-4` padrão). Colunas de texto (Descrição, Projeto, Responsável, Engenheiro/Arquiteto, Cidade, Referência, Local) perderam `truncate`/`max-w-[…px]` — sem `whitespace-nowrap`, o `<td>` volta ao comportamento padrão do navegador (quebra linha) e, como é a única coluna "elástica" da linha, o navegador aloca nela todo o espaço que sobrar depois das colunas de largura fixa. Não foi necessário `flex`/`grid` nem reescrever a tabela.
- **`max-w-[1400px]` removido no `<main>` das duas telas**: no CRM isso está no `Layout.tsx` compartilhado por todas as páginas (Dashboard, Contatos, Configurações etc.), não só Projetos — decisão consciente de aplicar globalmente em vez de criar uma exceção só pra essa página, já que o pedido do usuário foi "aproveitar o espaço em branco desperdiçado" e o `SidebarInset` do shadcn já delimita corretamente o espaço disponível (não tem risco de sobrepor a sidebar). Páginas com grid/flex responsivo simplesmente ganham mais respiro lateral — não achamos layout que quebre com container mais largo, mas isso ainda não foi validado visualmente ao vivo (ver pendência abaixo).
- **Overflow-x-auto mantido como rede de segurança**: não foi removido o wrapper `overflow-x-auto` em nenhuma das duas tabelas — ele só deixa de ser acionado nas larguras normais de operação depois da compactação de colunas; em telas muito estreitas (ex. janela redimensionada bem pequena) ele evita que a tabela "quebre" o layout da página, em vez de eliminar a rolagem por completo em qualquer largura (fisicamente não dá pra garantir isso com 13 colunas numa tela muito estreita).
- **Arquivos `SystemSwitcher.tsx`/`useSistemasPermitidos.ts` (não rastreados em ambos submodules) não foram tocados** — são trabalho em andamento de outra sessão/tarefa (já referenciado em `Layout.tsx` mas ainda sem commit); os commits desta SPEC tocam só os arquivos relacionados ao enquadramento dos cards.
- **`Projetos.tsx` do CRM estava com drift real no Skip** (confirma de novo [[feedback_skip_deploy_separate_tree]] e [[feedback_crm_submodule_muito_desatualizado]]): o `skip_file_read` mostrou que a versão publicada já tinha sido reescrita independentemente (rótulos abreviados "Entrada"/"Fechamento"/"UF" — que batem exatamente com o que o usuário colou no chat —, layout `table-auto` mais compacto com `text-xs`/`px-2 py-3`, e **sem** o `onDoubleClick` de edição que o submodule local ainda tinha). O fix desta SPEC foi então enxertado (`skip_file_patch`) em cima da versão real do Skip, preservando as diferenças que já existiam lá (inclusive a ausência do duplo-clique, que não é escopo desta SPEC); depois disso, o submodule local foi sobrescrito pra bater com o Skip, não o contrário.

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

- Aplicado o padrão de enquadramento nas duas tabelas e no container global do CRM (`Layout.tsx`) e da Separação Parcial (`SeparacaoParcialPage.tsx`, `<main>`) — primeiro no submodule local (`tsc`/`build` limpos + mockup HTML estático confirmando visualmente a quebra de linha/ausência de scroll).
- Usuário pediu push + sync com o Skip. `git push` feito nos 3 repositórios (separacao-parcial, lucenera-crm, central).
- Antes de escrever no Skip: `skip_project_status` (ambos `clean`, só `.skip.config.json` pendente) + `skip_file_read` dos arquivos reais. Achado: `separacao-parcial` batia quase byte a byte com o local (só diferenças triviais de formatação fora da área do fix); **`Projetos.tsx`/`Layout.tsx` do CRM tinham divergido de verdade** (ver decisão acima) — os rótulos que o usuário colou no chat ("Entrada"/"Fechamento"/"UF") só existem na versão do Skip, não na do submodule.
- Fix aplicado via `skip_file_patch` (4 blocos em `SeparacaoParcialPage.tsx`, 1 em `Layout.tsx`, 5 em `Projetos.tsx` — adaptados à estrutura real do Skip, não um overwrite).
- `skip_project_apply_changes` (modo `production`) nos dois projetos — QA completo (`setup`/`staticAnalysis`/`build`/`integrations`/`test`) `ok:true` nos dois.
- `skip_project_publish` nos dois — `separacao-parcial-dff01.goskip.app` (v0.0.40/`ebf5567`) e `lucenera-crm-3bd29.goskip.app` (v0.0.313/`c511568`).
- Confirmação final por `curl` direto no bundle JS de produção (não só no commit/QA): baixado o chunk real de cada página, grep mostrou ausência das classes antigas e presença das novas — o fix está de fato servido aos usuários.
- Sincronizado o submodule local do CRM (`Projetos.tsx`) com o conteúdo pós-patch do Skip, commitado (`cf63385`) e enviado (`git push`), eliminando o drift achado nesta sessão.

## Pendências

Nenhuma — publicado, verificado ao vivo no bundle de produção, e submodule local sincronizado com o Skip.
