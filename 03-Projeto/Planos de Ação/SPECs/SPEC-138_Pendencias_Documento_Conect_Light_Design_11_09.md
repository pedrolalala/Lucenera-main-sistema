---
titulo: "SPEC-138 — Pendências do documento \"LUCENERA — LIGHT DESIGN / Prompts de Solicitação Conect\" (11/09/2026)"
status: "Prompts 5/6/7 implementados no código (Skip 48801 v0.0.29, QA verde, NÃO publicado em produção); Prompt 4 bloqueado por falta de localização da tela"
data_ultima_modificacao: 2026-09-14
sistemas_envolvidos:
  - Separação (separacao-parcial) — `SeparacaoParcialPage.tsx` (tabela de itens, função `imprimirListaSeparacao`, bloco "Boletos desta venda")
  - Não localizado com certeza (Prompt 4 — ver "Pendências")
dependencias:
  - SPEC-135 (Prompts 1 e 2 do documento — código pronto, migration NÃO aplicada)
  - SPEC-136 (Prompts 3 e 3A do documento — código pronto, migration NÃO aplicada; Prompt 3A confirmado 100% implementado no código nesta investigação)
---

# SPEC-138 — Pendências do documento "Prompts de Solicitação — Sistema Conect" (11/09/2026)

> Origem: `01-Documento/01 - Planilhas/LUCENERA — LIGHT DESIGN DEPARTAMENTO DE E.V..docx`,
> elaborado por Laghi (D.E.V.) em 11/09/2026. O documento reúne 7 "prompts" prontos
> para gerar chamados formais de melhoria/correção para o que ele chama de "sistema
> Conect" — mas a investigação confirmou que os itens 1, 2, 3 e 3A descrevem, na
> verdade, comportamento do **nosso próprio ecossistema** (Orçamentos e Separação),
> não de um ERP terceiro: eles já viraram SPEC-135 e SPEC-136 no mesmo dia
> (11/09/2026), antes mesmo deste documento ser revisado. Esta SPEC-138 é o
> fechamento da auditoria pedida: confirma o que já está coberto e cobre os 4 itens
> que ainda não tinham nenhuma SPEC (Prompts 4, 5, 6 e 7).

## Checklist de Ação

- [ ] Confirmar com o usuário a tela exata do Prompt 4 (contraste) — não localizada com certeza nesta investigação (ver "Investigação — Prompt 4"). **Bloqueado, nenhum código escrito para este item.**
- [x] Decidir gatilho de liberação de boletos do Prompt 7 — **decisão default tomada nesta sessão** (usuário não fechou isso no documento): libera na 1ª baixa parcial confirmada, não só na entrega 100%. Reversível se o usuário preferir o outro critério.
- [x] Decidir escopo do Prompt 5 — **decisão default tomada nesta sessão**: implementado só na tela de Separação por ora; virar padrão de design system para outras grades do ERP fica como decisão separada, não tomada aqui.
- [x] Implementar Prompt 5 — coluna de ação "Trocar" fixa (`sticky right-0`) + truncate em Referência/Local (L). **Feito.**
- [x] Implementar Prompt 6 — impressão ganhou coluna "Local (L)", marcação em branco por item, totalizador de itens/peças e campo de observações. **Feito.**
- [x] Implementar Prompt 7 — "Boletos desta venda" só aparece após `houveBaixaRegistrada`. **Feito.**
- [x] Implementar Prompt 4 — usuário confirmou que é a própria tela de Separação; referências de orçamento/venda/código passaram a `#333333` + semibold + `tracking-wide`. **Feito.**
- [x] Rodar QA do Skip 48801 (`skip_project_apply_changes`) — setup/staticAnalysis/build/integrations/test todos verdes nas duas rodadas (v0.0.29 e v0.0.30).
- [x] **Publicar em produção** (`skip_project_publish` 48801) — usuário confirmou; publicado em `https://separacao-parcial-dff01.goskip.app` (versão `0.0.30`, ref `7d7f34d`).
- [x] Push dos commits locais (`eaa44c4`, `d7e0965`) para `origin/main` do submodule `separacao-parcial` no GitHub — feito.
- [x] Atualizar ponteiro do submodule `04-Sistemas/separacao-parcial` no repositório central e commitar lá (commit `9320e0c`).
- [x] Atualizar `CHANGELOG.md` do repositório central.
- [ ] Push do commit `9320e0c` do repositório central para `origin` (`pedrolalala/Lucenera-main-sistema`) — **não feito**, não foi pedido explicitamente; commitado localmente.
- [ ] Teste ao vivo de cada item (4, 5, 6, 7) em produção.
- [ ] Lembrar separadamente: **aplicar as migrations pendentes das SPEC-135 e SPEC-136 no Supabase real** — nenhum dos Prompts 1/2/3/3A está de fato em produção ainda, mesmo com o código pronto (ver "Status por prompt" abaixo). Isso não é escopo de código desta SPEC, é ação operacional pendente de outra SPEC.

## Status por prompt do documento

| # | Prompt | Prioridade (doc.) | Módulo | Status |
|---|--------|--------------------|--------|--------|
| 1 | Alteração de data de pagamento não deve reiniciar aprovação | Alta | Aprovação Financeira | ✅ Coberto por **SPEC-135** — código pronto, **migration não aplicada** |
| 2 | Bloqueio de faturamento com peça sem cadastro | Alta | Validação Cadastral / Faturamento | ✅ Coberto por **SPEC-135** — código pronto, **migration não aplicada** |
| 3 | Geração de número de venda na aprovação | Alta | Orçamento → Venda / FF | ✅ Coberto por **SPEC-136** — código pronto, **migration não aplicada** |
| 3A | Exibição do número da venda na Separação | Alta | Separação / Expedição | ✅ Coberto por **SPEC-136** — **confirmado 100% implementado no código** nesta investigação (ver abaixo); só falta a mesma migration da SPEC-136 |
| 4 | Contraste das referências (texto laranja em fundo bege) | Baixa | UI/UX | ❌ **Bloqueado** — tela exata não localizada, precisa print/nome do usuário |
| 5 | Layout / rolagem horizontal + coluna de ação fixa | Média | Telas operacionais | ✅ **Implementado** (Skip 48801 v0.0.29, QA verde) — **não publicado em produção** |
| 6 | Padronização da lista de separação (localizador "L", marcação, totalizador, observações) | Alta | Logística / Separação | ✅ **Implementado** (Skip 48801 v0.0.29, QA verde) — **não publicado em produção** |
| 7 | Ocultar boletos até a baixa de entrega | Média | Vendas / Financeiro | ✅ **Implementado** (Skip 48801 v0.0.29, QA verde) — **não publicado em produção** |

## Investigação

### Prompt 3A — por que já está pronto (evidência)

`04-Sistemas/separacao-parcial/src/pages/SeparacaoParcialPage.tsx`:

- Lista de busca de vendas (linhas 660-661): colunas separadas `Orçamento` e `Venda`.
- Filtro de texto (`vendasFiltradas`, linhas 214-222): já casa tanto por `orcamentoNumero` quanto por `vendaNumero` — o placeholder "Filtrar por número da venda ou cliente..." (linha 639) já corresponde ao comportamento real.
- Tela de detalhe (linhas 696-706): dois campos rotulados "Orçamento:" e "Venda:" lado a lado (comentário no código já cita a SPEC-136 explicitamente).
- Impressão (`imprimirListaSeparacao`, linhas 107-137): mostra as duas linhas "Venda: ..." e título com o número do orçamento.

Ou seja: o único motivo de o Prompt 3A ainda não estar em produção é a migration da SPEC-136 (coluna `orcamentos.numero_venda` + RPC) não ter sido aplicada no Supabase real — sem ela, `vendaNumero` chega sempre `null`/"—" do banco. Nenhum código novo é necessário para o Prompt 3A.

### Prompt 4 — tela não localizada

O documento não nomeia a tela. Buscas por padrões de "texto laranja sobre fundo bege" nas referências de orçamento/venda (`text-orange-*`, `text-amber-*` sobre fundos bege/`amber-50`/`#f5f5dc` etc.) nos sistemas mais prováveis (Separação, Orçamentos/`gestao-financeira-clone-544cb`) não bateram com um componente óbvio — a tela de Separação usa `text-primary` (azul-marinho escuro no tema atual, não laranja) para os números de orçamento/venda. É possível que a tela em questão seja uma view do sistema legado Conect (fora deste repositório) ou uma tela específica ainda não identificada dentro do nosso ecossistema.

**Antes de implementar**: pedir ao usuário um print de tela ou o nome do sistema/página onde aparece esse texto laranja sobre bege.

### Prompt 5 — evidência exata

`04-Sistemas/separacao-parcial/src/pages/SeparacaoParcialPage.tsx`, linhas 728-826:

- Tabela de itens da venda tem 13 colunas (`Código, Referência, Descrição, Classificação, Q. Dev., Q. Venda, E. Futura, Transferido, Reserva, À Separar, Ag. Separar, Separado, Entregue`) mais uma 14ª coluna de ação quando `podeTrocar` é verdadeiro.
- A tabela está dentro de `<div className="overflow-x-auto">` (linha 728) — confirma a rolagem horizontal relatada.
- O botão de ação por linha é literalmente **"Trocar"** (linhas 807-819, `<Button>...Trocar</Button>`, SPEC-098) — bate exatamente com a descrição do documento ("botão 'Trocar' fica no extremo direito"), confirmando que esta é a tela do Prompt 5.

O documento pede que a diretriz vire padrão global do ERP, não ajuste pontual desta tela — mas a única evidência concreta encontrada é esta tela. Recomendação: implementar aqui primeiro (menor risco, tela já identificada) e decidir separadamente, com o usuário, se vale abrir uma SPEC de design system para as demais grades do ecossistema.

### Prompt 6 — o que já existe vs. o que falta

- O campo "L" (localizador) **já existe na tela**, mas com outro nome: coluna "Classificação" (linha 735/761), alimentada por `item.classificacao`, que vem de `projeto_itens.l_fixo` (`separacaoParcialService.ts` linha 224) — que por sua vez é o snapshot de `orcamento_itens.custom_id` digitado na criação do orçamento (ver SPEC-040/SPEC-079, domínio `estoque_compras.md`). Ou seja: o dado já está disponível, só falta:
  1. Levar esse mesmo campo para a **impressão** (`imprimirListaSeparacao`, linhas 82-141) — hoje a função só recebe/imprime `descricao`, `codigo`, `referencia`, `quantidade`, sem `classificacao`/`l_fixo`.
  2. (Opcional, a decidir) renomear a coluna em tela de "Classificação" para algo mais claro tipo "Local (L)", já que é isso que o campo representa na prática.
- A impressão também não tem: coluna de marcação/conferência por item (checkbox ou quadrado vazio, preenchido a mão no papel — não precisa ser persistido no banco, é só layout de impressão), resumo totalizador no rodapé (total de itens e total de peças) e campo de observações (pendências, avarias, substituições).
- `imprimirListaSeparacao` é chamada em um único ponto (linha 347) logo após uma separação ser confirmada — os dados de `itensSeparados` vêm da própria ação de separar, então o enriquecimento é só na função de montagem do HTML impresso (linhas 95-137), sem mudança de banco.

### Prompt 7 — estado atual sem gate

`SeparacaoParcialPage.tsx`, linhas 886-990 aprox.: o grid `grid-cols-1 lg:grid-cols-2` renderiza "Parciais desta venda" e "Boletos desta venda" lado a lado, **sempre que uma venda está carregada** — não há nenhuma condição hoje ligada a baixa/entrega. Achado complementar: a SPEC-072 já havia removido valor e vencimento desse bloco (comentário na linha ~952: "Separação Parcial não é tela financeira"), deixando só número do boleto (`nossoNumero`) e contagem de parcelas pendentes — ou seja, o bloco já é bem mais enxuto do que o documento supõe, mas ainda aparece **antes** de qualquer baixa, que é o problema relatado.

O documento não define se a liberação deve ocorrer na primeira baixa parcial ou só na baixa 100% — precisa de decisão do usuário (ver "Decisões pendentes").

Não foi localizada, dentro deste repositório, uma tela com exatamente os campos "Código, Data Baixa, Funcionário, Responsável Retirou" citados no documento como estado desejado da "área de baixa" — o mais próximo é a tabela "Parciais desta venda" já existente (colunas `Parcial, Funcionário, Data, Itens, Status`). É possível que o documento descreva a tela do Conect legado como referência de campos, não uma tela nossa a replicar 1:1. Precisa confirmação do usuário antes de redesenhar esse bloco.

## Escopo de implementação (quando aprovado)

### Prompt 5 — eliminar rolagem horizontal

- Trocar a estratégia de largura fixa por: (a) truncar/quebrar colunas de texto longo (`Descrição` já trunca com `max-w-[240px] truncate`, mas `Referência`/`Classificação` não), (b) tornar a coluna de ação (`Trocar`) `sticky right-0` dentro do `overflow-x-auto`, e/ou (c) esconder colunas de baixo valor informativo em telas menores. Escolher a combinação depois de testar a tabela real (13-14 colunas é muito para caber sem nenhuma rolagem em telas comuns — pode ser preciso aceitar rolagem residual só em telas pequenas, eliminando o caso comum de desktop).

### Prompt 6 — enriquecer impressão da lista de separação

Em `imprimirListaSeparacao` (linhas 82-141):
- Adicionar `classificacao`/`l_fixo` como coluna "Local (L)" na tabela impressa (o dado já chega até a função que monta `itensSeparados`, linha 347 — só precisa ser incluído no tipo do parâmetro e na linha da tabela HTML).
- Adicionar coluna de marcação (quadrado vazio `☐` ou célula em branco com borda, sem checkbox interativo — é papel).
- Adicionar rodapé com totais: nº de itens (linhas) e soma de `quantidade`.
- Adicionar campo "Observações" em branco no final do documento impresso (pendências/avarias/substituições, preenchido a mão).

### Prompt 7 — ocultar boletos até a baixa

- Calcular uma condição de "já houve baixa" a partir dos dados já carregados (ex.: `parciais.some(p => p.status === <status de entregue/finalizado>)` ou usar os campos `q_entregue`/`q_separado` dos itens da venda — depende da decisão de gatilho) e usar essa condição para exibir ou não o card "Boletos desta venda". Enquanto oculto, pode-se manter o espaço com uma mensagem neutra ("Disponível após a baixa da entrega") em vez de simplesmente sumir o grid (evita layout pulando de 2 para 1 coluna).

### Prompt 4 — pendente de identificação da tela

Sem escopo de implementação até a tela ser confirmada.

## Decisões pendentes (usuário)

- **Prompt 4**: qual sistema/tela apresenta o texto laranja sobre fundo bege? (print ou nome da página)
- **Prompt 6**: confirmar que a marcação por item é só visual/impressa (não precisa virar campo no banco) — assunção de baixo risco desta SPEC, fácil de reverter se o usuário quiser persistir a conferência.
- **Prompt 7**: gatilho de liberação dos boletos — primeira baixa parcial ou só na baixa 100%? (o documento explicitamente deixa isso em aberto)
- **Prompt 5**: implementar só nesta tela agora, ou abrir SPEC própria de design system para aplicar o mesmo padrão a outras grades do ERP (Orçamentos, Compras, CRM, etc.)?

## Critérios de aceite

- [ ] Prompt 5: a tabela de itens da venda em Separação não exige rolagem horizontal em resolução de desktop comum (≥1366px); o botão "Trocar" continua acessível sem precisar rolar.
- [ ] Prompt 6: a lista impressa de separação mostra o localizador "L" (mesmo dado da coluna "Classificação" em tela), tem espaço de marcação por item, totalizador de itens/peças no rodapé e campo de observações.
- [ ] Prompt 7: o bloco "Boletos desta venda" não aparece antes do gatilho de baixa decidido com o usuário; volta a aparecer normalmente depois.
- [ ] Prompt 4: implementado conforme a tela identificada (cor do texto ~`#333333` ou similar, peso semibold, leve `letter-spacing`, mantendo o fundo).
- [ ] `pnpm run lint`/`pnpm run build` passam no(s) sistema(s) tocados.
- [ ] Teste ao vivo de cada um dos 4 itens.

## Observações finais

- Os Prompts 1, 2, 3 e 3A **não precisam de nenhum código novo** — já estão prontos em SPEC-135 e SPEC-136. O único bloqueio para eles chegarem à produção é aplicar as duas migrations pendentes no Supabase real (comandos já documentados em cada SPEC). Recomenda-se resolver isso antes ou em paralelo à implementação dos itens 4-7 desta SPEC, já que é trabalho zero de código, só uma ação operacional represada há 2 dias.
- Esta SPEC não reabre nenhuma decisão já fechada nas SPEC-135/136 (ex.: formato `VENDA-0001`, regra de reset de aprovação, bloqueio de peça sem cadastro).

## Como publicar (Prompts 5/6/7)

Código já escrito, testado (typecheck + `oxlint` + `vite build` locais limpos) e replicado no working tree do Skip (`skip_file_write` + `skip_project_apply_changes`, QA 100% verde, versão `0.0.29`). Faltam 4 passos manuais/decisórios antes de considerar isso "no ar":

1. **Publicar no Skip**: `skip_project_publish` no projeto `48801` — sobe a versão `0.0.29` para `https://separacao-parcial-dff01.goskip.app` (produção, sistema usado hoje pela expedição). Não fiz isso automaticamente porque é uma tela em uso operacional ativo — confirmar com o usuário antes.
2. **Push do commit local**: commit `eaa44c4` em `04-Sistemas/separacao-parcial` (branch `main`) para `origin/main` (`https://github.com/pedrolalala/separacao-parcial`). Só esse arquivo (`src/pages/SeparacaoParcialPage.tsx`) foi tocado e commitado — o submodule tem outras mudanças não commitadas (`App.tsx`, `cross-system-auth.ts`, `separacaoParcialService.ts`, `SystemSwitcher.tsx`, `useSistemasPermitidos.ts`) que **não são desta SPEC** e não foram tocadas.
3. **Atualizar o ponteiro do submodule** no repositório central e commitar lá (depois do push acima).
4. **Atualizar `CHANGELOG.md`** do repositório central com esta entrega.

## Realizado

### 2026-09-14

- Implementados Prompts 5, 6 e 7 diretamente em `04-Sistemas/separacao-parcial/src/pages/SeparacaoParcialPage.tsx`:
  - **Prompt 5**: colunas `Referência` e `Local (L)` (renomeada de "Classificação") ganharam `max-w` + `truncate`; coluna de ação "Trocar" (`podeTrocar`) virou `sticky right-0` tanto no header quanto nas células, com sombra lateral pra indicar que há conteúdo fixo.
  - **Prompt 6**: `imprimirListaSeparacao` passou a receber `classificacao` em cada item e imprime coluna "Local (L)", coluna de marcação em branco (`☐`), rodapé com total de itens/peças e um bloco de "Observações" com 3 linhas em branco.
  - **Prompt 7**: nova constante `houveBaixaRegistrada` (`parciais.some(p => p.status !== 'Cancelado')`) — enquanto falsa, o card "Boletos desta venda" mostra "Disponível após a baixa da entrega/parcial." em vez do conteúdo.
- Antes de escrever no Skip, comparei o arquivo do working tree do Skip (`skip_file_read`) contra o HEAD local (`git show HEAD:...`) — só havia diferenças triviais de formatação (quebra de linha do Prettier do Skip), sem divergência de conteúdo, então era seguro escrever por cima.
- `npx tsc --noEmit`, `npx oxlint src` e `npm run build` rodados localmente — limpos (1 warning pré-existente de variável não usada, não relacionado a esta mudança).
- `skip_file_write` + `skip_project_apply_changes` (modo development) no projeto `48801` — QA completo (setup/staticAnalysis/build/integrations/test) verde, versão `0.0.29`, preview em `https://separacao-parcial-dff01--preview.goskip.app`.
- Commit local `eaa44c4` só com o arquivo tocado (não peguei as outras mudanças já pendentes no submodule, que são de outra frente de trabalho).
- **Não publicado em produção nem pushado ao GitHub** — decisão deliberada de não empurrar sozinho uma mudança em sistema operacional ativo sem confirmação explícita do usuário.
- Prompt 4 permanece bloqueado — nenhuma tela identificada com certeza suficiente para implementar.
