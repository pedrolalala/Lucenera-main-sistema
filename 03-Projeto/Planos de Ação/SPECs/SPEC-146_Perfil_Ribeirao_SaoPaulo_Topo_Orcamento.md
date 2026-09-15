---
titulo: "SPEC-146 — Campo Perfil (Ribeirão/São Paulo) movido para o topo do orçamento"
status: concluído
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Orçamentos Aprovação (gestao-financeira-clone-544cb) — `BudgetFormPage.tsx`
---

# SPEC-146 — Campo Perfil (Ribeirão/São Paulo) movido para o topo do orçamento

> Origem: usuário testou o fix da SPEC-145 (enquadramento de cards) em Novo Orçamento/edição de orçamento, confirmou que o sistema está funcional, e pediu um ajuste de posição: o campo "Perfil" (Ribeirão/São Paulo) estava lá embaixo, na seção "Pagamento e Totais", e deveria ficar no topo, junto com "Empresa", em "Informações Gerais".

## Checklist de Ação

- [x] `BudgetFormPage.tsx`: mover o `FormField name="perfil"` de "Pagamento e Totais" (ficava logo antes de "Desconto Global") para "Informações Gerais", como segundo campo do mesmo grid de 2 colunas que já tinha só "Empresa" sozinha — não mexe em lógica, schema nem nome do campo, só posição no JSX.
- [x] `npx tsc --noEmit` no submodule local — sem erro (fix testado ali antes de decidir onde aplicar de verdade).
- [x] **Achado de drift**: o submodule local (`gestao-financeira-clone-544cb (1)`) tinha ~17 arquivos com mudanças não commitadas, incluindo o próprio `BudgetFormPage.tsx` (~200 linhas de diff alheio a esta SPEC) — provavelmente trabalho em andamento de outra sessão/tarefa, não relacionado. Por isso a mudança desta SPEC **não foi aplicada por cima do arquivo local**: o edit local foi revertido de volta ao estado em que foi encontrado (sem tocar nas outras ~200 linhas alheias), e o fix real foi aplicado direto no Skip via `skip_file_patch`, depois de confirmar por `skip_file_read` que o trecho relevante (Empresa + Perfil) do Skip batia byte a byte com a versão limpa do git (sem o diff alheio).
- [x] `skip_project_apply_changes` (QA completo `ok:true`) + `skip_project_publish` no projeto 32554 (v0.0.366, `f1d3ea5`).
- [x] Confirmado ao vivo via `curl` no bundle de produção (`BudgetFormPage-*.js`): a ordem das strings no bundle minificado mostra "Perfil"/"Ribeirão"/"São Paulo" entre "Empresa" e "Código do Projeto" (Informações Gerais), bem antes de "Forma de Pagamento"/"Frete" (Pagamento e Totais) — o campo está mesmo no topo agora.

### Passos manuais do usuário

- [ ] Nenhum previsto — mudança é só posição de um campo já existente no formulário, não mexe em schema nem em dado.

## Objetivo

O campo "Perfil" (ribeirão/são paulo — usado no cálculo/roteamento fiscal e operacional do orçamento) ficava no fim do formulário, na seção "Pagamento e Totais", pouco visível. Usuário pediu pra mover pro topo, ao lado de "Empresa", em "Informações Gerais", já que é uma decisão tomada no início do preenchimento do orçamento.

## Decisões aprovadas

- Nenhuma decisão de negócio nova — é reposicionamento puro de um campo já existente (`name="perfil"`, mesmo componente `<Select>`, mesmas opções `ribeirao`/`sao_paulo`).
- **Não confundir com o card "SPEC-078 (Bug 3)"** que já existe logo abaixo de Empresa (logo + nome + endereço da empresa) — esse é outro conceito (dados cadastrais da empresa selecionada), ficou exatamente onde estava; o campo Perfil novo entra como coluna ao lado de Empresa, antes desse card.
- Repositório local (`04-Sistemas/gestao-financeira-clone-544cb (1)`) não recebeu commit desta mudança — está com um volume grande de alterações não commitadas alheias a esta SPEC (mesmo arquivo `BudgetFormPage.tsx` incluso). Fix aplicado só no Skip (fonte real de produção); sincronizar o submodule local fica pendente de uma limpeza separada, fora do escopo desta SPEC.

## Definição da SPEC

### Antes → Depois

| Onde | Antes | Depois |
|---|---|---|
| Seção | "Pagamento e Totais" (perto do fim, antes de "Desconto Global") | "Informações Gerais" (logo no início, ao lado de "Empresa") |
| Estrutura | `FormField` solto, sozinho numa coluna do grid de "Pagamento e Totais" | Segundo campo do grid `grid-cols-1 md:grid-cols-2` que antes só tinha "Empresa" (agora "Empresa" \| "Perfil" lado a lado) |
| Campo/lógica | `name="perfil"`, `<Select>` com `ribeirao`/`sao_paulo` | Idêntico — só mudou de lugar no JSX |

## Realizado

### 2026-09-15

- Testado local primeiro (`tsc` limpo) pra validar a relocação antes de decidir onde publicar de verdade.
- `skip_project_status` (32554): clean, só `.skip.config.json` pendente. `skip_file_read` confirmou que o trecho de Empresa/Perfil do Skip batia exatamente com a versão "limpa" do git (sem o diff alheio de ~200 linhas que o submodule local tinha no mesmo arquivo).
- Fix aplicado via `skip_file_patch` (2 blocos: remove de "Pagamento e Totais", insere ao lado de "Empresa").
- `skip_project_apply_changes` (produção) — QA `ok:true` em todos os estágios. `skip_project_publish` — v0.0.366/`f1d3ea5`, `https://gestao-financeira-clone-544cb.goskip.app`.
- Confirmado no bundle de produção via `curl` + análise de posição das strings (Perfil aparece entre Empresa e Código do Projeto, bem antes de Forma de Pagamento/Frete).

## Pendências

- [ ] O submodule local `04-Sistemas/gestao-financeira-clone-544cb (1)` tem um volume grande de mudanças não commitadas em ~17 arquivos (incluindo `BudgetFormPage.tsx`) que não são desta SPEC — não investigado a fundo nesta sessão. Recomenda-se, numa sessão futura, decidir se é trabalho a retomar/commitar ou lixo a descartar, antes de tentar sincronizar esse submodule com o Skip de novo (ver [[feedback_skip_deploy_separate_tree]]).
