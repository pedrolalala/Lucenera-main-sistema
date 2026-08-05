---
titulo: "SPEC-062 — RH: Campo de Colaborador com Busca em Nova Solicitação de Férias"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - RH (dashboard-rh-lucenera-5fe9c)
---

# SPEC-062 — RH: Campo de Colaborador com Busca em Nova Solicitação de Férias

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — `VacationForm.tsx` (Skip, `projectId 23919`): trocar o campo "Colaborador" de `<Select>` simples (lista de 29 funcionários, sem caixa de busca) para um combobox (`Popover` + `Command`, componentes já existentes no projeto) com caixa de busca real e clique para selecionar. **Publicado em produção, versão `0.0.216`/`dbdf1a5`.**
- [x] Item 2 — Manter inalterado o resto do formulário (período aquisitivo, datas, saldo) — fora de escopo desta SPEC. Confirmado: nenhuma outra parte do arquivo foi tocada.
- [x] Item 3 — Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Testar em produção: abrir "Nova Solicitação de Férias", digitar parte do nome de um colaborador na caixa de busca, clicar no resultado e confirmar que o nome fica selecionado no campo.

## Objetivo

Usuário reportou que, no formulário "Nova Solicitação de Férias" (RH), o campo "Colaborador" "não está habilitando adicionar o nome, apenas buscar". Confirmado com o usuário: o dropdown abre com a lista completa (hoje 29 funcionários ativos), digitar só pula/realça um nome (comportamento nativo de *typeahead* do componente `<Select>` do Radix — sem caixa de busca visível), e não fica claro/confiável como confirmar a seleção clicando. Não existe hoje nenhuma caixa de texto de busca real nesse campo.

## Decisões aprovadas

- Resolver substituindo o `<Select>` por um combobox de busca de verdade (`Command`/`cmdk`, já usado em outras partes do ecossistema, ex. `buscar_fornecedores_fuzzy` em Compras) — não uma tentativa de "consertar" o typeahead nativo do Radix Select, que não tem caixa de busca visível por design.
- Não mexer na lógica de período aquisitivo/saldo/bloqueio do mesmo formulário (isso já está em andamento numa SPEC separada, SPEC-058, com mudanças ainda não publicadas — não misturar as duas).
- Mantém a mesma fonte de dados (`funcionarios` onde `status = 'Ativo'`) e a mesma regra de restrição (usuário com `app_role = 'funcionario'` só pode selecionar a si mesmo, campo fica desabilitado).

## Definição da SPEC

### Estado atual confirmado

- `VacationForm.tsx`, campo "Colaborador": `<Select value={employeeId} onValueChange={setEmployeeId}>` com um `<SelectItem>` por funcionário ativo (29 hoje). `<Select>` do Radix não tem caixa de busca — só suporta pular para o próximo item que comece com a letra digitada (typeahead nativo do navegador/Radix), sem feedback visual de filtro.
- **Nota de sincronismo**: o submodule local `04-Sistemas/dashboard-rh-lucenera-5fe9c` tem esse mesmo arquivo modificado localmente (sem commit) pela SPEC-058 (remoção de bloqueio duro de saldo/período aquisitivo) — **essas mudanças não foram publicadas no Skip** (produção ainda tem o comportamento de bloqueio antigo). Esta SPEC-062 implementa **só** a troca do campo de busca, direto no Skip (fonte real de produção), sem incorporar o WIP local da SPEC-058 (que depende de 2 migrations ainda não aplicadas no Supabase real — misturar quebraria o formulário se a coluna `periodo_aquisitivo_id` continuar `NOT NULL`).

### Mudança proposta

Substituir o bloco do `<Select>` de "Colaborador" por:

- `Popover` + `Button` (trigger, mostra o nome selecionado ou "Selecione...", `disabled` nas mesmas condições de hoje: `user?.app_role === 'funcionario' || !!requestToEdit`).
- `Command` com `CommandInput` (caixa de busca real, filtra pelo nome digitado — `cmdk` já faz o filtro client-side por padrão) + `CommandList` + `CommandEmpty` + `CommandGroup` + um `CommandItem` por funcionário, `onSelect` chama `setEmployeeId` e fecha o popover.

## Impacto no banco

Nenhum.

## Impacto em telas

Só o campo "Colaborador" de `VacationForm.tsx` (RH). Nenhuma outra tela muda.

## Regras de permissão

Sem mudança — mesma condição de `disabled` já existente hoje.

## Análise obrigatória de ecossistema

- Depende de `funcionarios` (leitura, já usada hoje). Não depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` nem `user_system_access`.
- Afeta só RH. Nenhum outro domínio.
- Nenhum dado duplicado.
- Nenhuma migration nova, nenhum conflito com migration antiga.
- Não exige atualização de `AI_DB_CONTEXT.md`.

## Critérios de aceite

- Campo "Colaborador" mostra uma caixa de texto real para digitar/filtrar o nome.
- Clicar num resultado filtrado preenche o campo corretamente (`employeeId` atualizado).
- Comportamento de desabilitar o campo para usuário com papel "funcionario" ou em modo de edição continua idêntico ao anterior.
- Resto do formulário (período, datas, saldo, submit) inalterado nesta SPEC.

## Testes/verificações obrigatórios

- QA pipeline do Skip (`skip_project_apply_changes`) precisa passar antes de publicar.
- Teste manual descrito em "Passos manuais do usuário".

## Realizado

### 2026-08-05

- SPEC criada.
- Campo "Colaborador" trocado para combobox de busca (`Popover`+`Command`) direto no Skip, publicado em produção (`projectId 23919`, versão `0.0.216`/`dbdf1a5`), QA (build+testes) ok antes de publicar.
- `CHANGELOG.md` atualizado.

## Pendências

- [ ] Teste manual em produção (digitar nome, clicar, confirmar seleção) ainda não foi feito pelo usuário.
- [x] ~~Não relacionado a esta SPEC, mas achado no processo: o submodule local `dashboard-rh-lucenera-5fe9c` tem WIP da SPEC-058...~~ — **resolvido em 2026-08-05**: usuário pediu para publicar também, SPEC-058 foi aplicada e publicada junto (mesmo arquivo `VacationForm.tsx`, versão `0.0.217`/`9b88f1d`). Ver `SPEC-058_RH_Ferias_Sem_Bloqueio_e_Folga_Compensatoria.md`.
