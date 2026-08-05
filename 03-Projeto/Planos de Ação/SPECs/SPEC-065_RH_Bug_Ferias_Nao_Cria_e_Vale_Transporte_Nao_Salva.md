---
titulo: "SPEC-065 — RH: Nova Solicitação de Férias não cria + valor de Vale Transporte não salva"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - RH (dashboard-rh-lucenera-5fe9c)
---

# SPEC-065 — RH: Nova Solicitação de Férias não cria + valor de Vale Transporte não salva

> Origem: usuário reportou em 2026-08-05, logo após a publicação da SPEC-058/SPEC-062, que não consegue criar uma "Nova Solicitação de Férias" e não consegue alterar o valor do Vale Transporte de um funcionário.

## Checklist de Ação

- [ ] `EmployeeFinance.tsx` (`src/components/EmployeeFinance.tsx`, aba financeira do funcionário): corrigir o upsert de `funcionarios_beneficios_empresas` — hoje o `insert` não envia a coluna `empresa` (`NOT NULL` no banco, sem default) e os erros de `insert`/`update` dessa tabela não são verificados nem exibidos. Ver "Achado 1" abaixo para o fix completo.
- [ ] Reaproveitar (ou alinhar com) a função `upsertDetail`/`updateEmployee` já existente em `src/services/funcionarios.ts`, que já trata `empresa` e já propaga erro — hoje `EmployeeFinance.tsx` duplica essa lógica de forma mais frágil, em vez de reusar o serviço.
- [ ] Rodar, uma única vez, um backfill/checagem manual para os funcionários ativos hoje sem nenhuma linha em `funcionarios_beneficios_empresas` (6 de 28 — inclui pelo menos "Pedro Leonel Laghi") — depois do fix de código, cada um precisa ter o VT Diário salvo pelo menos uma vez para passar a existir a linha.
- [ ] Investigar "Nova Solicitação de Férias" com o sintoma exato do usuário (ver Pendências — não reproduzido nem localizado por análise estática de código/banco).

### Passos manuais do usuário

- [ ] Descrever o sintoma exato ao tentar criar uma Nova Solicitação de Férias: aparece alguma mensagem de erro (toast vermelho)? O botão "Solicitar" fica cinza/desabilitado mesmo com Colaborador, Data Início e Data Fim preenchidos? Ou o botão funciona mas a solicitação não aparece na lista depois? Print da tela ajuda.
- [ ] Confirmar em qual conta/papel (`admin`, `gerente` ou `funcionario`) o teste de férias foi feito.
- [ ] Autorizar o MCP do Skip nesta sessão (`/mcp` ou `claude mcp`) para eu poder confirmar se o código publicado em produção (`projectId 23919`) é de fato o mesmo lido no submodule local — hoje não tenho acesso a essa ferramenta na sessão atual, e a SPEC-058/062 já mostrou antes que "publicado" no submodule nem sempre bate com o que está no ar.
- [ ] Rodar o agente `revisor` antes de qualquer commit.
- [ ] Publicar a correção do Vale Transporte via Skip (`projectId 23919`) e homologar salvando o VT Diário de um funcionário sem benefício cadastrado ainda.

## Objetivo

Dois bugs relatados no RH, ambos após a publicação recente de SPEC-058 (férias sem bloqueio) e SPEC-062 (busca de colaborador):

1. Não é possível criar uma "Nova Solicitação de Férias".
2. Alterar o campo "VT Diário" na aba financeira do funcionário não salva o novo valor.

## Definição da SPEC

### Achado 1 — Vale Transporte: causa raiz confirmada

`EmployeeFinance.tsx` (`handleSave`, linhas ~116-132) faz o upsert de `funcionarios_beneficios_empresas` na mão, sem passar pela função de serviço já existente:

```ts
const benPayload = { valor_vt_dia: vtDia }   // <- falta "empresa"
if (existingBen) {
  await supabase.from('funcionarios_beneficios_empresas').update(benPayload).eq('id', existingBen.id)
} else {
  await supabase.from('funcionarios_beneficios_empresas').insert({ ...benPayload, funcionario_id: employee.id })
  // <- erro não verificado
}
```

Confirmado no schema real (`\d public.funcionarios_beneficios_empresas`): a coluna `empresa` é `character varying(100) NOT NULL`, sem valor default. Quando `existingBen` é `null` (funcionário sem nenhuma linha ainda nessa tabela), o `insert` acima **falha** por violar o `NOT NULL` de `empresa` — e como o `error` não é checado nem propagado, o `catch` do `handleSave` nunca dispara. O código segue em frente, salva `folha_pagamento` normalmente (essa tabela não exige `empresa`) e mostra o toast **"Dados financeiros atualizados com sucesso!"** — uma falsa confirmação. O `valor_vt_dia` nunca chega a existir no banco para esse funcionário.

Confirmado com uma consulta direta ao Supabase real: de 28 funcionários ativos em `funcionarios_novo`, **6 não têm nenhuma linha em `funcionarios_beneficios_empresas`** hoje — incluindo "Pedro Leonel Laghi". Ou seja, qualquer tentativa de definir o VT Diário desses 6 pela primeira vez falha silenciosamente. Para os outros 22 (que já têm uma linha), o `update` funciona normalmente, porque não mexe na coluna `empresa`.

Reforça o diagnóstico: existe uma função de serviço (`updateEmployee`/`createEmployee` em `src/services/funcionarios.ts`, via `upsertDetail`) que já faz esse mesmo upsert corretamente — já envia `empresa` e já usa `if (error) throw error`. `EmployeeFinance.tsx` não usa essa função; duplica a lógica de forma mais frágil.

**Fix proposto:**
- Trocar a chamada direta ao Supabase em `EmployeeFinance.tsx` por `updateEmployee(employee.id, {...})` (ou, no mínimo, incluir `empresa: employee.empresa` no `benPayload` e checar `error` em ambos os branches, com `toast` de erro se falhar).
- Confirmar de onde vem `employee.empresa` nesse contexto (a aba financeira não tem campo de Empresa visível) — se `employee.empresa` já vier preenchido do funcionário (via `vw_funcionarios_completo`), basta reenviar o mesmo valor; se puder vir vazio para algum funcionário, decidir com o usuário o que fazer (bloquear o salvamento do VT até a Empresa estar definida no cadastro principal, já que é campo obrigatório no banco).

### Achado 2 (atualizado 2026-08-05, sessão com acesso ao Skip) — causa raiz real encontrada

A análise estática anterior (tabela abaixo) checou período aquisitivo, constraints de status, triggers e RLS — mas não conferiu a definição completa da coluna `dias`. `\d public.ferias` no Supabase real mostra:

```
dias | integer | not null | generated always as (data_fim - data_inicio + 1) stored
```

`dias` é **coluna gerada pelo Postgres** — não pode receber valor explícito em `INSERT`/`UPDATE`. `VacationForm.tsx` enviava `dias: calculatedDays` em ambos os payloads, e o Postgres rejeita a operação inteira quando isso acontece. Confirmado que **nenhum dos 12 registros existentes em `ferias` foi criado pelo app** — todos têm o mesmo `created_at` exato (`2026-05-05 18:05:07`), ou seja, foram inseridos por seed/import direto no banco, nunca pela UI. Isso bate exatamente com o sintoma "não consegue criar" — era 100% reprodutível, sempre, para qualquer usuário.

**Fix**: removido `dias` dos dois payloads (`insert` e `update`) em `VacationForm.tsx` — o banco calcula sozinho a partir de `data_inicio`/`data_fim`. Publicado em produção (Skip `projectId 23919`, versão `0.0.219`/`42e7121`).

### Achado 2 (histórico) — análise estática original, não conclusiva

Conferido e **sem problema encontrado** em cada uma destas camadas:

| Camada | Verificação | Resultado |
|---|---|---|
| Coluna `ferias.periodo_aquisitivo_id` | `\d public.ferias` no Supabase real | `nullable`, sem "not null" — migration `20260804_074` confirmada aplicada de fato |
| `controle_ponto_status_check` | `pg_get_constraintdef` no Supabase real | já inclui `'folga'` — migration `20260804_075` confirmada aplicada de fato |
| Triggers em `ferias` | `pg_trigger` | nenhum trigger além dos internos |
| RLS `ferias` (insert) | `pg_policies` | permite `admin`/`gerente` ou dono (`funcionario_id = get_my_funcionario_id()`) — sem bloqueio aparente |
| RLS `funcionarios` (select, usado pelo combobox) | `pg_class.relrowsecurity` | RLS **desligada** nessa tabela — leitura livre para qualquer autenticado |
| FK `ferias.funcionario_id` | `pg_constraint` | aponta para `funcionarios` (tabela antiga) — bate com a tabela usada pelo combobox em `VacationForm.tsx` (não há mismatch com `funcionarios_novo`) |
| `VacationForm.tsx` (código local) | leitura completa do componente | combobox de Colaborador (SPEC-062) seta `employeeId` corretamente; `handleSubmit` monta o payload de `insert` compatível com o schema atual; botão de submit só desabilita por `!employeeId \|\| calculatedDays <= 0` (sem `isExceedingBalance`/`!periodoId`, conforme SPEC-058) |

**Conclusão desta análise:** o código lido no submodule local, hoje, deveria permitir criar uma solicitação de férias sem erro. Não foi possível reproduzir o bug sem acesso à sessão do usuário (console do navegador) nem ao ambiente publicado no Skip (MCP do Skip não autorizado nesta sessão — ver Pendências). Duas hipóteses seguem em aberto, nenhuma confirmada:

1. A versão publicada em produção (Skip, `projectId 23919`) não é exatamente esta versão local — já aconteceu antes neste projeto (SPEC-052/053/054).
2. O "não consegue criar" é, na prática, o botão "Solicitar" ficando desabilitado sem nenhuma explicação visível quando faltam Data Início/Data Fim ou quando `calculatedDays` fica ≤ 0 (ex.: Data Fim antes da Data Início) — comportamento correto, mas sem mensagem de erro, o que pode parecer um bug.

Não dá para decidir entre essas hipóteses (nem propor outras) sem o sintoma exato do usuário — ver Passos manuais do usuário.

## Critérios de aceite

- Definir o "VT Diário" de um funcionário que ainda não tem linha em `funcionarios_beneficios_empresas` salva com sucesso (linha nova criada, com `empresa` preenchida) e o valor persiste ao reabrir a aba.
- Qualquer erro real ao salvar dados financeiros do funcionário aparece como toast de erro, nunca como "sucesso" falso.
- Criar uma Nova Solicitação de Férias funciona de ponta a ponta no ambiente publicado (Skip), para o sintoma relatado pelo usuário.

## Testes obrigatórios

- Salvar VT Diário para um dos 6 funcionários hoje sem linha em `funcionarios_beneficios_empresas` (ex.: "Pedro Leonel Laghi") e conferir com uma consulta direta que a linha foi criada com o `valor_vt_dia` correto.
- Reproduzir a criação de Nova Solicitação de Férias no ambiente publicado, com o papel de usuário usado pelo relator do bug.

## Realizado

### 2026-08-05

- Causa raiz real do bug de férias encontrada (`dias` é coluna gerada, não uma falha de RLS/schema/trigger como a análise anterior supôs) e corrigida.
- Vale Transporte: `EmployeeFinance.tsx` agora sempre envia `empresa` no payload de `funcionarios_beneficios_empresas` e verifica erro em toda operação (nunca mais mostra "sucesso" falso). Funcionário sem "Empresa" definida no cadastro principal recebe um erro claro em vez de falhar silenciosamente.
- Ambos publicados em produção (Skip `projectId 23919`, versão `0.0.219`/`42e7121`), QA (build+testes) ok antes de publicar.
- Decisão tomada para a pendência de `employee.empresa` vazio: bloquear o salvamento com mensagem clara (opção já sugerida na SPEC), em vez de permitir valor vazio.

## Pendências

- [ ] Teste manual em produção: criar uma "Nova Solicitação de Férias" de ponta a ponta e confirmar que salva; salvar VT Diário de um funcionário sem "Empresa" definida e confirmar a mensagem de erro; salvar VT de um funcionário com Empresa definida e sem linha prévia em `funcionarios_beneficios_empresas` (ex.: "Pedro Leonel Laghi") e confirmar que a linha é criada.
- [ ] Backfill dos 6 funcionários ativos sem linha em `funcionarios_beneficios_empresas` não foi feito via script — com o fix, basta salvar o VT de cada um pela tela (fluxo normal) que a linha passa a existir. Se algum desses 6 não tiver "Empresa" definida no cadastro, é preciso preencher lá primeiro.
