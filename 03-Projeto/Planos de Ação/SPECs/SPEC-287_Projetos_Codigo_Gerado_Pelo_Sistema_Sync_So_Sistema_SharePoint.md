---
titulo: "SPEC-287 — Projetos: código gerado pelo sistema e sincronização só sistema → SharePoint"
status: pendente
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Supabase (trigger de código, cron, Edge Functions sharepoint-projetos-push e sharepoint-projetos-conferencia)
  - SharePoint / Microsoft 365 (lista "Organização Projetos", site LUCENERAPROJETOS345)
  - CRM / Cadastro (criação de projeto — sem mudança de tela)
---

# SPEC-287 — Projetos: código gerado pelo sistema e sincronização só sistema → SharePoint

## Checklist de Ação

- [x] Banco: `gerar_codigo_projeto()` — próximo número livre do ano (`AA.NNN`, último + 1), com trava contra dois cadastros simultâneos.
- [x] Banco: trigger de criação de projeto usa o código oficial em vez do provisório `PROV-NNNN`.
- [x] Banco: desligar o cron `sharepoint-projetos-pull` (a cada 5 min, 24h).
- [x] Banco: cron `sharepoint-projetos-conferencia` — dias úteis, 8h de São Paulo, só leitura.
- [x] Banco: `sharepoint_sync_log` aceita `direction = 'conferencia'` e `action = 'ok' | 'divergencia'`.
- [x] Edge Function `sharepoint-projetos-push`: a busca anti-duplicação por código só reaproveita o item da lista se o nome for o mesmo; código igual com nome diferente vira `conflict` no log e não grava nada.
- [x] Edge Function nova `sharepoint-projetos-conferencia`: compara código da lista × sistema e registra divergências, sem gravar em `projetos`.
- [ ] Teste com o primeiro projeto real criado no sistema (código, item na lista, fluxo do Power Automate, conferência). Não foi criado projeto de teste: queimaria um número real na lista e criaria um grupo no Teams.

### Passos manuais do usuário

- [ ] Filippo avisa a equipe: projeto novo só se cria no sistema; nada se cria, apaga ou renumera na lista.
- [ ] Alan bloqueia criação/edição de itens na lista "Organização Projetos" para a equipe (o app do sistema continua gravando).
- [ ] Combinar com Igor: o fluxo do Power Automate **não se relança**. Se falhar, as pastas se criam à mão (copiando a pasta modelo) com o código do sistema.
- [ ] Decidir a virada de ano (proposta: 1º/01/2027 começa em `27.001`, automático pelo ano).

## Objetivo

O sistema passa a ser a única fonte dos projetos. Hoje a sincronização vai nos dois sentidos: o sistema manda para a lista na hora, e a lista volta para o sistema a cada 5 minutos, 24 horas por dia, inclusive no fim de semana. Pela regra da SPEC-228, o código oficial também vinha da lista. Decisão do Filippo em 14/11/2026: o sistema gera o código, manda para a lista e nada volta.

## Decisões aprovadas (Filippo, 14/11/2026)

- Projeto novo nasce **só no sistema**. A lista recebe e nunca alimenta o sistema.
- O código é gerado pelo sistema: **primeiro número livre depois do último** (26.359 → 26.360, 26.361…).
- O fluxo do Power Automate continua igual. O item chega na lista **sem Código**, o fluxo numera e cria pasta e Teams. Como sistema e lista têm o mesmo último número, o fluxo dá o mesmo código. Não precisa mudar o fluxo (Igor).
- O fluxo **nunca se relança**: relançar queima um número e desalinha os dois lados. Se falhar, as pastas se fazem à mão com o código do sistema.
- Fica uma **conferência leve**, só leitura, uma vez por dia útil às 8h, que avisa se algum código da lista for diferente do sistema. Substitui o pull de 5 em 5 minutos.
- Ficam para depois: o sistema criar as pastas e o Teams sozinho, e eliminar a lista (Filippo, 14/11: "funciona do SharePoint, muitas frentes abertas").

## Definição da SPEC

### Estado antes (14/11/2026)

- `trg_projetos_codigo_provisorio` (SPEC-228): projeto sem código nasce `PROV-NNNN`.
- `trg_projetos_sharepoint_push` → Edge Function `sharepoint-projetos-push`: cria ou atualiza o item na lista, nunca envia `field_0`.
- Cron `sharepoint-projetos-pull` (jobid 1, `*/5 * * * *`) → `disparar_pull_sharepoint()` → Edge Function `sharepoint-projetos-pull`: cria e atualiza projetos a partir da lista e traz o código oficial.
- Alinhamento conferido em 14/11: último item da lista = 7248 = `26.359` = último código do sistema; nenhum `26.*` sem item na lista.
- Desde 01/10, todos os projetos novos (≈ 56) chegaram pelo pull, isto é, foram criados na lista.

### Banco (migration `20261114_340_spec287_codigo_projeto_sistema`)

1. `gerar_codigo_projeto()`:
   - `pg_advisory_xact_lock` para dois cadastros simultâneos não pegarem o mesmo número;
   - prefixo = ano de São Paulo com 2 dígitos;
   - número = maior sufixo numérico dos códigos `AA.NNN` daquele ano + 1, com 3 dígitos (`lpad`).
2. `trg_projetos_codigo_provisorio_fn()` passa a chamar `gerar_codigo_projeto()`. O nome do trigger fica igual para não mexer em mais nada. `gerar_codigo_provisorio_projeto()` e a sequence ficam (rollback).
3. `cron.unschedule('sharepoint-projetos-pull')`. A Edge Function e o `disparar_pull_sharepoint()` ficam, sem agendamento (rollback ou uso manual).
4. `disparar_conferencia_sharepoint()`: mesma URL do pull com o nome da função trocado, mesmo segredo. Cron `sharepoint-projetos-conferencia` = `0 11 * * 1-5` (8h de São Paulo).
5. CHECKs de `sharepoint_sync_log`: `direction` + `conferencia`; `action` + `ok`, `divergencia`.

### Edge Function `sharepoint-projetos-push`

- Se o projeto não tem `sharepoint_item_id` e a lista já tem um item com o mesmo código:
  - **mesmo nome** (Title) → é o mesmo projeto, numa tentativa anterior que gravou no Graph e não confirmou: reaproveita o item (PATCH), como hoje;
  - **nome diferente** → conflito: grava `conflict` no log e **não grava nada na lista**. Antes, o PATCH sobrescrevia o item de outro projeto.

### Edge Function nova `sharepoint-projetos-conferencia`

- Lê todos os itens da lista (`id`, `Title`, `field_0`, paginado) e todos os projetos com código `AA.NNN` ou `sharepoint_item_id`.
- Divergências registradas:
  1. item da lista com código diferente do projeto ligado a ele;
  2. item da lista sem projeto no sistema (criado direto na lista);
  3. projeto do sistema com `sharepoint_item_id` que não existe mais na lista;
  4. projeto criado há mais de 1 hora ainda sem item na lista (push falhou).
- Grava **uma linha** em `sharepoint_sync_log` (`direction='conferencia'`, `action='ok'` ou `'divergencia'`, detalhes em `campos_alterados`). Não grava em `projetos`.
- Itens antigos já conhecidos ficam fora para não repetir alarme todo dia:
  - itens só da lista criados antes de 14/11/2026;
  - projetos `PROV-0002`/`PROV-0003` (itens vazios do teste de 26/10, ver Pendências).

### Critérios de aceite

- Projeto criado no sistema nasce com o próximo código (`26.360`…), aparece na lista sem código, o fluxo numera **igual** e cria pasta e Teams.
- Nenhuma execução de `sharepoint-projetos-pull` depois da migration.
- Conferência roda num dia útil às 8h e grava `ok` quando está tudo alinhado.
- Projeto editado no sistema continua atualizando a lista (PATCH).

### Rollback

- `rollback.sql`: volta o trigger ao `PROV-NNNN`, reagenda o pull (`*/5 * * * *`), remove o cron e a função da conferência e volta os CHECKs.
- Push: republicar a versão 5 (igual à `main` antes desta SPEC).

## Realizado

### 2026-11-14

- Conferido antes de mudar: último item da lista (7248) = `26.359` = último código do sistema.
- Ensaio em transação com ROLLBACK: dois projetos de teste nasceram `26.360` e `26.361`; pull desagendado; conferência agendada; push enfileirado. Depois do ROLLBACK, banco igual ao anterior (pull agendado, nenhum projeto de teste, fila vazia).
- Publicadas as Edge Functions `sharepoint-projetos-conferencia` (v1) e `sharepoint-projetos-push` (v6).
- Migration `20261114_340_spec287_codigo_projeto_sistema` aplicada. Crons ativos: `sharepoint-projetos-conferencia` (`0 11 * * 1-5`), mais os dois que já existiam (férias e auditoria). `sharepoint-projetos-pull` desagendado. `gerar_codigo_projeto()` devolve `26.360`.
- Primeira conferência rodada à mão (20:51 UTC):
  - 4.062 itens na lista e 4.158 projetos no sistema;
  - **0 códigos diferentes**, nenhum item só na lista, nenhum projeto sem item;
  - 2 divergências antigas: `26.336` LUCIA SALOMÃO (item 7226) e `26.346` JULIA MARIA E VICTOR (item 7236) estão no sistema, mas o item foi apagado da lista.
- Os dois foram apagados do sistema a pedido do Filippo ("se não estão no SharePoint").
  - Antes de apagar: nenhuma ligação com orçamento, financeiro, separação, Connect ou qualquer outra tabela, a não ser 5 linhas do `sharepoint_sync_log`, que ficam com `projeto_id` nulo.
  - A Lucia Salomão que vale é a `26.252`.
  - Cópia em `backup._bkp_spec287_projetos_removidos`.
  - Conferência refeita às 21:28 UTC: **ok**, 4.062 itens na lista e 4.156 projetos.

## Pendências

- [ ] Projetos `PROV-0002` (item 7221) e `PROV-0003` (item 7163), "Projeto sem nome", criados pelo pull em 26/10/2026 durante o teste da SPEC-228, sem orçamento nem título financeiro: confirmar com Filippo se apaga (e se os itens ainda existem na lista).
- [ ] Primeiro projeto real criado no sistema depois de 14/11: conferir que o fluxo deu o mesmo código e criou pasta e Teams.
- [ ] Commit no repo central (SPEC, migration, Edge Functions, CHANGELOG) e publicação pela `main`, como manda a regra de 10/11. A mudança foi aplicada direto no Supabase e as funções foram publicadas pelo conector.
- [ ] Aviso da conferência: hoje fica só no `sharepoint_sync_log`. Ler na rotina da manhã (conferência diária) ou criar aviso por e-mail/Teams.
