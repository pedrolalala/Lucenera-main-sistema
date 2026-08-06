---
titulo: "SPEC-067 — Enviar para o Cliente: Download automático de PDF + E-mail pré-preenchido (mailto)"
status: aprovada — pronta para implementação
data_ultima_modificacao: 2026-08-06
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
dependencias:
  - SPEC-051 (fase de Rascunho; aba "Rascunho" e botão "Enviar para o Cliente" que esta SPEC estende)
---

# SPEC-067 — Enviar para o Cliente: Download automático de PDF + E-mail pré-preenchido (mailto)

> Pedido literal do usuário: "Então vamos lá. Em orçamentos, na área do rascunho, tem a opção enviar para o cliente. Como dentro do orçamento a gente tem que linkar com o cliente, dentro da planilha no Supabase de cliente tem o email e eu gostaria que quando eu apertasse enviar orçamento para o cliente automaticamente aparecesse o email do cliente. Então tipo um email pronto para enviar para o cliente e também automaticamente fazer o download do PDF com as informações!"

## Checklist de Ação

Esta mudança é só de frontend, sem migration nem alteração de RPC. Ela adiciona um comportamento novo em cima do fluxo de envio inicial já existente (`enviarOrcamentoCliente` → RPC `enviar_orcamento_para_cliente`), sem alterar a store nem a RPC.

- [x] Extrair um helper único (ex.: `src/lib/envio-inicial-cliente.ts` ou local a cada componente, a decidir na implementação) que, dado um `Budget` e o `token` retornado por `enviarOrcamentoCliente`, execute em sequência: (1) gerar e baixar o PDF via Edge Function `generate-report` (mesmo padrão já usado em `handleDownloadPdf` de `BudgetTableRow.tsx`, linhas 190-225); (2) montar a URL `mailto:` com destinatário, assunto e corpo (ver "Conteúdo do e-mail" abaixo); (3) abrir o `mailto:` (`window.location.href = mailtoUrl` ou `window.open(mailtoUrl)`, a decidir na implementação — ver Pendência P-4).
- [x] `src/components/budgets/DraftBudgetsTab.tsx` — `handleEnviar` (linha 50): **ganha o comportamento novo**. Depois do `enviarOrcamentoCliente` + copiar link (comportamento atual, mantido), acrescentar o download automático do PDF e a abertura do `mailto:`.
- [x] `src/components/budgets/BudgetTableRow.tsx` — `handleEnviarCliente` (linha 83), **apenas no branch de UI onde `normalizedStatus === 'rascunho'`** (botão "Enviar para o Cliente", linhas 279-294): **ganha o comportamento novo**, pelo mesmo motivo do item acima — é a mesma ação de envio inicial, só acessada a partir da lista "Todos" em vez da aba "Rascunho".
- [x] **Não tocar**: `src/components/budgets/BudgetTableRow.tsx`, botão de reenvio (`RefreshCw`) que aparece quando `normalizedStatus === 'enviado_cliente'` (linhas 307-322) ou `normalizedStatus === 'recusado_cliente'` (linhas 342-357). Ambos continuam chamando `handleEnviarCliente` sem o comportamento novo — a diferenciação **tem que ser feita dentro do componente/handler** (por exemplo, com um parâmetro `isEnvioInicial: boolean` passado para `handleEnviarCliente`, ou dois handlers separados que compartilham a chamada de store), nunca dentro da store `enviarOrcamentoCliente`, para não vazar o comportamento novo para o reenvio.
- [x] **Não tocar**: `src/components/budgets/ClientApprovalTab.tsx` — `handleEnviar` (linha 76, botão "Reenviar" nas linhas 303-317) continua exatamente como hoje: só RPC + copiar link + toast, sem download nem `mailto:`.
- [x] Confirmar que `useBudgetStore.enviarOrcamentoCliente` (linha 397) **não é alterada** — ela continua retornando só `{ token }`, sem saber se a chamada é envio inicial ou reenvio. Essa distinção de comportamento fica 100% no componente.
- [x] Tratar o caso de e-mail ausente (`budget.cliente?.email` nulo/vazio) conforme "Cliente sem e-mail cadastrado" abaixo.
- [x] Tratar falha na geração do PDF conforme "Falha na geração do PDF" abaixo.
- [x] Rodar `oxlint`, `prettier --check` e `vite build` no sistema após a implementação.

### Passos manuais do usuário

- [ ] Validar em navegador (Chrome/Edge, que são os clientes usados pela equipe) que o `mailto:` abre o cliente de e-mail padrão do sistema operacional corretamente, com assunto e corpo preenchidos e sem quebra de encoding em acentuação (`á`, `ã`, `ç`, etc. — `encodeURIComponent` deve resolver, mas precisa ser conferido visualmente).
- [ ] Validar golden path completo no navegador: abrir aba "Rascunho" → clicar "Enviar para o Cliente" → conferir que o PDF baixa automaticamente **e** o cliente de e-mail abre com os campos corretos.
- [ ] Repetir o mesmo teste a partir da lista "Todos" (`BudgetTableRow.tsx`, branch rascunho).
- [ ] Confirmar que a aba "Aprovação do Cliente" (reenvio) **não muda de comportamento** — nem baixa PDF nem abre `mailto:`.
- [ ] Rodar o agente `revisor` antes de qualquer commit.

## Objetivo

Hoje, "Enviar para o Cliente" (ação de envio inicial de um orçamento em rascunho) apenas chama a RPC `enviar_orcamento_para_cliente`, copia o link de aprovação para a área de transferência e mostra um toast — o usuário depois precisa manualmente baixar o PDF em outro botão e montar um e-mail do zero para anexar e enviar ao cliente.

Esta SPEC adiciona, apenas ao **envio inicial** (não ao reenvio), dois passos automáticos logo após o sucesso da RPC: (1) download automático do PDF do orçamento e (2) abertura de um `mailto:` pré-preenchido com destinatário, assunto e corpo prontos — incluindo instrução para o usuário anexar manualmente o PDF já baixado, já que `mailto:` não suporta anexos programáticos.

## Decisões aprovadas

- **P-1 — Escopo dos pontos de chamada**: o comportamento novo (download automático + `mailto:`) vale **apenas para o envio inicial de um orçamento em rascunho**:
  - `DraftBudgetsTab.tsx` (`handleEnviar`) — ganha o comportamento novo.
  - `BudgetTableRow.tsx` (`handleEnviarCliente`), branch `normalizedStatus === 'rascunho'` — ganha o comportamento novo (é a mesma ação de envio inicial, só que acessada pela lista "Todos").
  - `ClientApprovalTab.tsx` (`handleEnviar`, reenvio após recusa) — **não muda**.
  - `BudgetTableRow.tsx`, ícone de reenvio (`RefreshCw`) para status `enviado_cliente`/`recusado_cliente` — **não muda**.
  - A distinção entre os dois branches de `BudgetTableRow.tsx` acontece no componente/handler, não na store `enviarOrcamentoCliente`, para não vazar o comportamento novo para o reenvio.
- **P-2 — Cliente sem e-mail cadastrado**: destinatário sempre vem de `contatos.email` (via `budget.cliente?.email`). Quando esse campo for nulo/vazio, o PDF baixa normalmente e o `mailto:` abre mesmo assim, só com o campo "Para" vazio (`mailto:?subject=...&body=...`), deixando o usuário preencher manualmente. **Nota**: esta é uma inferência razoável para o caso específico de e-mail ausente, não uma resposta 100% explícita do usuário — pode precisar ser revisitada se o comportamento observado não for o esperado.
- **P-3 — Conteúdo do e-mail**: usar exatamente o texto abaixo (ver "Conteúdo do e-mail").
- **P-5 — Falha na geração do PDF**: se a Edge Function `generate-report` falhar, a ação inteira falha — mostrar toast de erro, **não** abrir o `mailto:`. O status do orçamento já mudado pela RPC `enviar_orcamento_para_cliente` **não é revertido** (não há uma segunda chamada de banco coberta por esta SPEC para desfazer isso) — ou seja, se a RPC teve sucesso e só o PDF falhou depois, o orçamento já fica `enviado_cliente` mesmo sem o PDF ter sido baixado. Essa é uma consequência aceita da ordem de operações (RPC primeiro, PDF depois). O usuário pode tentar novamente depois usando o botão "Baixar PDF" separado, que já existe e continua funcionando de forma independente desta SPEC.

## Definição da SPEC

### Estado atual

- **`enviarOrcamentoCliente`** (`useBudgetStore.ts`, linha 397): chama a RPC `enviar_orcamento_para_cliente(p_orcamento_id)`, que muda o status do orçamento para `enviado_cliente` e retorna `{ token }`. Não gera PDF nem envia e-mail — é puramente uma mudança de status + geração de token.
- **Download de PDF** já existe de forma independente em `handleDownloadPdf` (`BudgetTableRow.tsx`, linhas 190-225): chama a Edge Function `generate-report` via `fetch` autenticado (`Authorization: Bearer <access_token>`), recebe um `blob`, cria um link temporário (`<a download>`) e dispara o download no navegador. Este botão ("Baixar PDF", ícone `Printer`) continua existindo e funcionando de forma independente, em todos os status. Payload atual: `{ reportType: 'orcamento', format: 'pdf', filters: { id: budgetId } }` — sem `logoBase64` (parâmetro opcional da Edge Function, não usado atualmente; não é necessário decidir nada sobre logo para reaproveitar essa mesma chamada).
- **Três pontos hoje chamam `enviarOrcamentoCliente`**, todos com o mesmo comportamento atual (RPC + copiar link + toast):
  1. `DraftBudgetsTab.tsx::handleEnviar` (linha 50) — botão "Enviar para o Cliente" na aba "Rascunho".
  2. `BudgetTableRow.tsx::handleEnviarCliente` (linha 83) — usado em **dois** botões diferentes na mesma tabela "Todos": o botão "Enviar para o Cliente" quando `normalizedStatus === 'rascunho'` (linhas 279-294), e o ícone `RefreshCw` de reenvio quando o status é `enviado_cliente` (linhas 307-322) ou `recusado_cliente` (linhas 342-357).
  3. `ClientApprovalTab.tsx::handleEnviar` (linha 76) — botão "Reenviar" na aba "Aprovação do Cliente", só visível para `status === 'recusado_cliente'`.
- **Link de aprovação**: montado por `buildClientApprovalLink(orcamentoId, token)` em `src/lib/budget-status.ts`, formato `https://gestaofinanceiralucenera.goskip.app/aprovacao?orcamento_id=...&token=...`.
- **Dados do cliente disponíveis no `Budget`**: `budget.cliente?.nome`, `budget.cliente?.razao_social`, `budget.cliente?.email`, `budget.cliente?.nome_empresa` (tipo em `useBudgetStore.ts`, linhas 84-89), já vêm via join na query de `fetchBudgets` (`cliente:contatos!orcamentos_cliente_id_fkey(nome, razao_social, email, nome_empresa)`, linhas 145-149) — não precisa de query separada. Fonte real é a tabela `public.contatos` (coluna `email`, nullable) — não existe tabela `clientes` separada.

### Distinção obrigatória de escopo dentro de `BudgetTableRow.tsx`

Hoje o mesmo handler `handleEnviarCliente` atende dois botões visualmente e semanticamente diferentes:

| Branch | Condição | Comportamento hoje | Comportamento após esta SPEC |
|---|---|---|---|
| Envio inicial | `normalizedStatus === 'rascunho'` | RPC + copiar link + toast | RPC + copiar link + toast + **download PDF + mailto** |
| Reenvio (enviado) | `normalizedStatus === 'enviado_cliente'` | RPC + copiar link + toast | **sem mudança** |
| Reenvio (recusado) | `normalizedStatus === 'recusado_cliente'` | RPC + copiar link + toast | **sem mudança** |

A implementação precisa diferenciar esses branches — por exemplo, passando um parâmetro (`isEnvioInicial`) do JSX para o handler, ou criando dois handlers que compartilham só a chamada de `enviarOrcamentoCliente`. A store não deve ganhar nenhum parâmetro novo nem lógica de branch — ela continua sendo só "muda status + retorna token".

### Conteúdo do e-mail

**Assunto:**
```
Orçamento Nº {numero} - {empresa}
```

**Corpo:**
```
Olá {cliente},

Segue o orçamento Nº {numero} para sua análise e aprovação.

Para aprovar ou recusar o orçamento, acesse o link abaixo:
{link de aprovação}

O PDF do orçamento foi baixado automaticamente neste dispositivo.
Por favor, anexe o arquivo baixado a este e-mail antes de enviar.

Atenciosamente,
{empresa}
```

Mapeamento de variáveis (fonte real, todas já disponíveis no `Budget` carregado pela store):

- `{numero}` → `budget.numero` (fallback para o mesmo padrão usado em `handleDownloadPdf`, ex. `budgetId.split('-')[0].toUpperCase()`, se `numero` for nulo).
- `{empresa}` → `budget.empresa?.nome`.
- `{cliente}` → `budget.cliente?.razao_social || budget.cliente?.nome`.
- `{link de aprovação}` → `buildClientApprovalLink(budgetId, result.token)` (mesmo link já copiado para a área de transferência hoje).

Assunto e corpo devem ser passados por `encodeURIComponent` na montagem da URL `mailto:` (`mailto:{email}?subject={subject}&body={body}`), para preservar acentuação e quebras de linha. `mailto:` tem limite prático de tamanho por cliente de e-mail/SO (geralmente seguro até ~2000 caracteres) — o texto acima é curto o suficiente.

### Cliente sem e-mail cadastrado

Quando `budget.cliente?.email` for nulo ou string vazia:
- O PDF continua baixando normalmente.
- O `mailto:` abre mesmo assim, com o campo "Para" vazio: `mailto:?subject=...&body=...`.
- O usuário preenche o destinatário manualmente no cliente de e-mail que abrir.
- **Registrado como inferência do agente, não decisão explícita do usuário** — revisitar se, na prática, o comportamento esperado for diferente (ex.: bloquear o envio, ou avisar antes com um toast/confirmação).

### Falha na geração do PDF

Ordem de operações: (1) RPC `enviar_orcamento_para_cliente` → (2) download do PDF via `generate-report` → (3) abertura do `mailto:`.

Se o passo (2) falhar:
- Mostrar toast de erro (mesmo padrão de mensagem usado em `handleDownloadPdf`: `toast.error('Falha ao gerar o PDF', { description: error.message })`).
- **Não** abrir o `mailto:`.
- O orçamento já está com status `enviado_cliente` (passo 1 já foi concluído com sucesso) — isso não é revertido por esta SPEC. É uma consequência aceita da ordem de operações, não um bug.
- O usuário pode usar o botão "Baixar PDF" (`handleDownloadPdf`, já existente, inalterado) para tentar novamente depois, e montar o e-mail manualmente se precisar.

### Ordem/timing (risco técnico a registrar)

Sequência recomendada dentro do handler (`async`):

```
1. await enviarOrcamentoCliente(budget.id)              // RPC — já existe
2. await downloadBudgetPdf(budget.id, budget.numero)    // fetch + blob + <a download>.click() — se falhar, parar aqui (ver P-5)
3. window.location.href = buildBudgetMailto(...)        // não usar window.open()
4. (mantém) clipboard.writeText(link) + toast de sucesso
```

- Usar `window.location.href = mailtoLink`, **não** `window.open(mailtoLink)` — navegadores tratam `window.open` sem interação direta do usuário (ex.: depois de um `await` de rede) como pop-up e podem bloquear; `location.href` para um esquema `mailto:` não navega a página atual (o navegador delega ao protocolo externo) e não sofre o mesmo bloqueio de pop-up na maioria dos navegadores modernos.
- Risco a validar na homologação: a maioria dos navegadores não expõe um evento confiável de "download terminado" para blobs gerados via `<a download>` — a abertura do `mailto:` provavelmente vai ter que ser síncrona logo após o `a.click()`, sem esperar confirmação real do sistema operacional. Validar visualmente que os dois popups (download + cliente de e-mail) não brigam entre si nem são bloqueados por popup blocker do navegador; se necessário, inserir um pequeno atraso (`setTimeout` de ~300-500ms) entre o clique sintético de download e a navegação para o `mailto:`. Ajuste fino de implementação, não decisão de negócio.

### Análise de ecossistema

- **Depende de**: leitura de `orcamentos` (status, token, numero) e `contatos.email`/`nome`/`razao_social` (via join já existente no `Budget`) — **nenhuma escrita nova, nenhuma coluna nova**. Não toca `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` nem `user_system_access`.
- **Afeta**: exclusivamente Orçamentos. Não toca CRM, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI. Não muda o contrato de status (`enviado_cliente`, RPC `enviar_orcamento_para_cliente`) usado por outros sistemas/telas.
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum — o e-mail é lido direto de `contatos.email` via relacionamento já existente, nada é copiado/duplicado.
- **Migration antiga que contradiz o snapshot central**: não aplicável — sem migration nesta SPEC.
- **Exige atualizar `AI_DB_CONTEXT.md`**: não — nenhum objeto de banco novo ou alterado.
- **Padrão de acesso a dados já usado pelo sistema**: Zustand (`useBudgetStore.ts`) para RPCs/mutação de estado; chamada direta a Edge Function via `fetch` autenticado dentro do próprio componente para operações que não passam pela store (padrão já estabelecido em `handleDownloadPdf`, `BudgetTableRow.tsx`). Esta SPEC segue exatamente esse padrão: a nova lógica de download+mailto fica no componente (reaproveitando a mesma Edge Function `generate-report` do mesmo jeito que `handleDownloadPdf` já faz, via um helper compartilhado para não duplicar código em 2 lugares), não é movida para a store, e `enviarOrcamentoCliente` permanece inalterada.

## Critérios de aceite

- [ ] Na aba "Rascunho", clicar "Enviar para o Cliente" resulta em: status muda para `enviado_cliente` (conferir com `SELECT status FROM orcamentos WHERE id = ...`), PDF baixa automaticamente no navegador, cliente de e-mail abre com assunto/corpo/destinatário corretos, link copiado para a área de transferência (comportamento já existente, mantido).
- [ ] O mesmo golden path funciona a partir da lista "Todos" (`BudgetTableRow.tsx`), botão "Enviar para o Cliente" quando o orçamento está em `rascunho`.
- [ ] Na aba "Aprovação do Cliente" (`ClientApprovalTab.tsx`), clicar "Reenviar" em um orçamento `recusado_cliente` **não** baixa PDF nem abre `mailto:` — só RPC + copiar link + toast, igual hoje.
- [ ] Na lista "Todos", clicar no ícone de reenvio (`RefreshCw`) em orçamentos `enviado_cliente` ou `recusado_cliente` **não** baixa PDF nem abre `mailto:`.
- [ ] Se `budget.cliente?.email` for nulo, o `mailto:` ainda abre, com "Para" vazio.
- [ ] Se a geração do PDF falhar (simular desligando/quebrando a Edge Function ou testando com um `id` inválido), toast de erro aparece e o `mailto:` não abre.
- [ ] `oxlint`, `prettier --check` e `vite build` sem erros novos.

## Testes obrigatórios

Verificação manual (golden path no navegador) — este sistema não tem suíte automatizada:

- Criar/usar um orçamento de teste em Rascunho vinculado a um cliente **com** e-mail cadastrado em `contatos.email`; clicar "Enviar para o Cliente" (aba Rascunho); confirmar download do PDF e abertura do cliente de e-mail com os campos corretos.
- Repetir o mesmo teste a partir do botão "Enviar para o Cliente" na lista "Todos" (`BudgetTableRow.tsx`).
- Repetir com um cliente **sem** e-mail cadastrado; confirmar que o `mailto:` abre com "Para" vazio.
- Confirmar que o reenvio em `ClientApprovalTab.tsx` (status `recusado_cliente`) e o ícone `RefreshCw` em `BudgetTableRow.tsx` continuam sem baixar PDF nem abrir mailto.
- Testar em pelo menos 2 navegadores diferentes (comportamento de `mailto:` e bloqueio de pop-up varia por navegador).
- `oxlint`, `prettier --check` e `vite build` sem erros novos nos arquivos tocados.

## Realizado

**2026-08-06 — implementado pelo agente `implementador`.**

Sistema: `04-Sistemas/gestao-financeira-clone-544cb (1)`. Mudança só de frontend, sem migration nem alteração de RPC/store.

Arquivos criados:
- `src/lib/envio-inicial-cliente.ts` — helper compartilhado novo, com três funções exportadas:
  - `downloadBudgetPdf(budget)` — extraída de `handleDownloadPdf` (mesma chamada à Edge Function `generate-report`, mesmo payload `{ reportType: 'orcamento', format: 'pdf', filters: { id } }`); lança erro se a resposta não for `ok`.
  - `buildBudgetMailtoUrl(budget, token)` — monta a URL `mailto:{email}?subject=...&body=...` com o texto exato da seção "Conteúdo do e-mail" da SPEC, `encodeURIComponent` só em `subject` e `body` (não no e-mail, conforme especificado); usa `budget.cliente?.razao_social || budget.cliente?.nome` para `{cliente}`, `budget.empresa?.nome` para `{empresa}`, `budget.numero || id.split('-')[0].toUpperCase()` para `{numero}` e `buildClientApprovalLink` para `{link de aprovação}`; se `budget.cliente?.email` for nulo/vazio, o destinatário fica vazio (`mailto:?subject=...`).
  - `sendInitialBudgetPdfAndEmail(budget, token)` — chama `downloadBudgetPdf` e, só se ele tiver sucesso, faz `window.location.href = buildBudgetMailtoUrl(...)` (não usa `window.open`, conforme P-4/risco técnico da SPEC).

Arquivos alterados:
- `src/components/budgets/BudgetTableRow.tsx`:
  - `handleDownloadPdf` refatorado para reaproveitar `downloadBudgetPdf` do novo helper (remove duplicação; comportamento e toast de sucesso/erro mantidos idênticos).
  - `handleEnviarCliente` ganhou o parâmetro `isEnvioInicial: boolean`. Mantém o comportamento atual (RPC `enviarOrcamentoCliente` + copiar link + toast de sucesso) sempre; se `isEnvioInicial` for `true`, chama `sendInitialBudgetPdfAndEmail(budget, result.token)` dentro de um `try/catch` próprio — se falhar, mostra `toast.error('Falha ao gerar o PDF', { description })` sem propagar erro (a RPC já teve sucesso e o toast de "enviado" já apareceu, conforme P-5).
  - O botão "Enviar para o Cliente" (branch `normalizedStatus === 'rascunho'`) agora chama `handleEnviarCliente(true)`.
  - Os dois botões de reenvio (`RefreshCw`, branches `enviado_cliente` e `recusado_cliente`) agora chamam explicitamente `handleEnviarCliente(false)` — **sem mudança de comportamento observável**, só explicitando a distinção de escopo pedida na SPEC.
  - Removido o import direto de `supabase` (não é mais usado no componente após a extração do helper).
- `src/components/budgets/DraftBudgetsTab.tsx`:
  - `handleEnviar` mantém o comportamento atual (RPC + copiar link + toast) e, em seguida, chama `sendInitialBudgetPdfAndEmail(budget, result.token)` dentro de `try/catch` próprio, com o mesmo tratamento de erro de PDF (`toast.error('Falha ao gerar o PDF', ...)`, sem propagar).

Arquivos **não tocados** (conforme exigido pela SPEC): `src/components/budgets/ClientApprovalTab.tsx` (confirmado via `git status`/`git diff` — zero diff) e `src/stores/useBudgetStore.ts` (`enviarOrcamentoCliente` inalterada, ainda só retorna `{ token }`).

Verificações rodadas no sistema `04-Sistemas/gestao-financeira-clone-544cb (1)`:
- `npx oxlint src` — 14 warnings pré-existentes (nenhum nos arquivos tocados nesta SPEC), 0 erros.
- `npx prettier --check` nos 3 arquivos tocados (`BudgetTableRow.tsx`, `DraftBudgetsTab.tsx`, `envio-inicial-cliente.ts`) — "All matched files use Prettier code style!". (Um `prettier --check .` full-repo aponta 154 arquivos pré-existentes com warning, incluindo `ClientApprovalTab.tsx` — confirmado que esse arquivo não foi tocado por esta SPEC, warning já existia antes.)
- `npx vite build` — build concluído com sucesso (`✓ built in 2.51s`), sem erros novos; só o warning pré-existente de chunk size (>500kB), não relacionado a esta mudança.

Nenhuma migration nesta SPEC (confirmado no próprio texto da SPEC). Nenhum deploy/publish feito — decisão do usuário.

### O que ficou pendente de homologação manual (não pode ser verificado pelo agente)

- Abrir o `mailto:` de fato no navegador e conferir se o cliente de e-mail padrão do SO abre com destinatário, assunto e corpo corretos, sem quebra de acentuação.
- Golden path completo: aba "Rascunho" → "Enviar para o Cliente" → PDF baixa + e-mail abre.
- Mesmo golden path a partir da lista "Todos" (`BudgetTableRow.tsx`, branch rascunho).
- Confirmar visualmente que o reenvio (`ClientApprovalTab.tsx` e o ícone `RefreshCw`) continua sem baixar PDF nem abrir mailto (a leitura do código confirma que a lógica não foi acionada nesses branches, mas a checagem visual/funcional é do usuário).
- Testar cliente sem e-mail cadastrado (mailto com "Para" vazio).
- Simular falha da Edge Function `generate-report` (id inválido ou função fora do ar) e confirmar toast de erro sem abertura do mailto.
- Testar em pelo menos 2 navegadores (comportamento de `mailto:`/pop-up varia).
- Validar timing entre o clique sintético de download e a navegação para `mailto:` (P-4 — se necessário, ajustar com um pequeno `setTimeout`; não foi adicionado nenhum atraso nesta implementação, seguindo a sequência síncrona já usada em `handleDownloadPdf`).

## Pendências

- [x] **P-1 — Escopo dos 3 pontos de chamada** (resolvida em 2026-08-06, decisão do usuário): comportamento novo vale só para envio inicial (`DraftBudgetsTab.tsx::handleEnviar` e o branch `rascunho` de `BudgetTableRow.tsx::handleEnviarCliente`); `ClientApprovalTab.tsx` e o branch de reenvio (`RefreshCw`) de `BudgetTableRow.tsx` não mudam. Diferenciação feita no componente/handler, não na store.
- [x] **P-2 — Cliente sem e-mail cadastrado** (resolvida em 2026-08-06, com ressalva): destinatário sempre vem de `contatos.email`; quando ausente, PDF baixa e `mailto:` abre com "Para" vazio. Essa resposta específica ao cenário de e-mail ausente é uma inferência razoável do agente, não confirmação explícita do usuário — registrar como ponto a revisitar se o comportamento na prática não for o esperado.
- [x] **P-3 — Texto do e-mail** (resolvida em 2026-08-06, decisão do usuário): assunto e corpo definidos exatamente como especificado na seção "Conteúdo do e-mail" acima.
- [ ] **P-4 — Timing/ordem entre download do PDF e abertura do mailto** (pendência técnica, não decisão de negócio): definir na implementação se o `mailto:` deve abrir só depois que o download do PDF for confirmado como concluído no navegador, ou imediatamente em sequência (a maioria dos navegadores não expõe um evento confiável de "download terminado" para blobs gerados via `<a download>`). Validar visualmente que os dois popups (download + cliente de e-mail) não brigam entre si nem são bloqueados por popup blocker do navegador.
- [x] **P-5 — Falha na geração do PDF** (resolvida em 2026-08-06, decisão do usuário): ação inteira falha com toast de erro, `mailto:` não abre. Status já mudado pela RPC não é revertido (consequência aceita da ordem de operações, não bug). Botão "Baixar PDF" separado continua disponível para nova tentativa manual.
