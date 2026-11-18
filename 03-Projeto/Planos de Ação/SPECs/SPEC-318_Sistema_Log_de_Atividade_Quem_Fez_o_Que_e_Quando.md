---
titulo: "SPEC-318 — Sistema Log de Atividade (quem fez o quê, quando e o que mudou)"
status: código pronto, migration 377 NÃO aplicada, sistema NÃO publicado
data_ultima_modificacao: 2026-11-16
sistemas_envolvidos:
  - Log de Atividade (novo)
  - Hub / Central (card + slug)
---

# SPEC-318 — Sistema Log de Atividade (quem fez o quê, quando e o que mudou)

## Checklist de Ação

- [x] Confirmar com o usuário o formato (sistema novo separado, acesso só admin) e os recursos (ver Decisões)
- [x] Criar o sistema novo em `04-Sistemas/log-atividade/` (React + Vite + Tailwind/shadcn, mesmo padrão da Central) — código feito; repositório próprio `log-lucenera` AINDA NÃO criado (passo manual)
- [x] Migration (redigida em `20261116_377_spec318_log_atividade/`, NÃO aplicada): tabela `auditoria.log_visualizadores` (Pedro, Filippo) + função `auditoria.pode_ver_log()` + RPCs novas `auditoria_log_*` (as antigas ficam intactas)
- [x] Login pelo mesmo Supabase SP; quem não está na lista recebe 42501
- [x] Tela principal: lista de eventos com filtros de **usuário**, **data/hora (de–até, horário de Brasília)**, sistema, ação (`tipo`) e busca livre
- [x] Detalhe do evento: antes → depois campo a campo (`mudancas`), IP e navegador
- [x] Visão "Por usuário" (resumo via `auditoria_log_resumo_usuarios`)
- [x] Exportar o resultado filtrado para Excel
- [x] Separar visualmente as linhas "SQL direto (...)" das ações de usuários
- [ ] (Opcional, conforme decisão) atualização ao vivo dos eventos novos — NÃO feito (decisão pendente do usuário)
- [ ] Registrar em `systems` (slug `log-atividade`) + Acesso a Sistemas só Pedro e Filippo — NÃO feito (ver Passos manuais)
- [ ] Deploy Cloudflare Pages (NÃO feito) (`log-lucenera.pages.dev`) com variáveis do Supabase SP
- [x] Atualizar `04-Sistemas/00 - Sumario Sistemas.md` (linha "a publicar"), `CHANGELOG.md` e `COMO_CONSULTAR_O_LOG_DE_ATIVIDADE.md`

### Passos manuais do usuário

- [x] Aprovar esta SPEC e responder as perguntas de Decisões
- [ ] Criar o repositório `log-lucenera` no GitHub e o projeto no Cloudflare Pages (ou autorizar)
- [ ] Rodar `dry_run.sql` e `tests.sql` da 377 (em ROLLBACK) e depois aplicar `up.sql` no Supabase SP

## Objetivo

Ter um sistema à parte onde a Administração enxerga tudo que é feito nos sistemas Lucenera, no momento em que é feito, quem fez e o que mudou, filtrando por usuário e data. Hoje isso só dá por SQL (guia `03-Projeto/Auditoria/COMO_CONSULTAR_O_LOG_DE_ATIVIDADE.md`) ou pela aba Administração › Movimentação da Central (SPEC-206).

## Análise do estado atual

- O log já existe e já grava: `auditoria.eventos` (SPEC-206, migrations 221–224, 289). Colunas: `criado_em` (UTC), `usuario_id/nome`, `sistema`, `tipo`, `entidade`, `registro_id`, `referencia`, `mudancas` (jsonb `{campo:[antes,depois]}`), `ip`, `navegador`. Retenção de 12 meses.
- Leitura só por RPC `SECURITY DEFINER`, só admin: `auditoria_listar(p_de, p_ate, p_sistema, p_usuario, p_tipo, p_busca, p_limite, p_offset, p_incluir_telas)` e `auditoria_resumo_usuarios(p_de, p_ate)`. O schema `auditoria` não é exposto a `authenticated`.
- `financeiro_eventos` guarda o histórico do financeiro novo (títulos/parcelas/baixas) fora de `auditoria.eventos`.
- Já existe a UI na Central: `04-Sistemas/central-lucenera-dashboard-1c9ba/src/pages/admin/components/MovimentacaoTab.tsx` (pode ser a base de código do sistema novo).
- Fora do log (limite conhecido): importações e automações com chave de serviço, cron, e leitura de dados (só "abriu tela").

## Decisões propostas (aguardam confirmação)

- Sistema novo separado, slug `log-atividade`, card no Hub.
- **Acesso por LISTA de pessoas, não por papel admin.** O Vinicius é `admin` e NÃO pode ver o log (ele é um dos auditados). Hoje admin = Filippo, Lana, Pedro, Vinicius (conferido em 16/11/2026). Tabela nova `auditoria.log_visualizadores (usuario_id)`; **Lista aprovada em 16/11/2026: SOMENTE Pedro e Filippo** (nem Lana, nem Vinicius).
- **O log da Central/Hub (aba Movimentação, `auditoria_listar`, `auditoria_resumo_usuarios`) NÃO é alterado** (decisão do usuário). O sistema novo usa RPCs próprias, novas, travadas pela lista: `auditoria_log_listar`, `auditoria_log_resumo_usuarios`, `auditoria_log_filtros`. Consequência registrada: admins continuam vendo a aba antiga da Central.
- Sem mudança no que é gravado; reaproveitar as RPCs existentes.
- Horário exibido e filtrado sempre em `America/Sao_Paulo`.

## Definição da SPEC

### Banco

Nenhuma tabela nova. Possíveis ajustes pequenos, só se a tela precisar (migration em `supabase/db/migrations/AAAAMMDD_NNN_spec318_log_atividade/`, com up/rollback/dry_run):

1. RPC `auditoria_filtros()` (admin) devolvendo listas de `sistema`, `tipo` e `entidade` distintos para os selects.
2. RPC de eventos do financeiro novo (`financeiro_eventos`) unida à lista, se o usuário quiser ver baixas/parcelas no mesmo fluxo.
3. Para "ao vivo": tabela `auditoria.eventos` não está no Realtime; usar polling a cada 15 s com `p_de = último criado_em` (não expõe a tabela). Realtime direto só com nova decisão de segurança.

Regras do AGENTS.md: função nova com `REVOKE ALL ... FROM PUBLIC, anon`, trava `IF NOT coalesce(is_admin(), false)`, nada de `USING (true)`.

### Tela

| Área | Conteúdo |
|---|---|
| Filtros | Usuário (select por nome), data e hora de/até, sistema, ação, busca (referência/entidade), "mostrar telas abertas" |
| Lista | Quando, usuário, sistema, ação, entidade/referência; paginada (100) |
| Detalhe | Painel com antes → depois por campo, IP, navegador, id do registro |
| Por usuário | Cards/tabela com último login, ações no período, sistemas usados |
| Exportar | Excel do filtro atual (mesmas colunas da lista + mudanças em texto) |
| SQL direto | Badge próprio e filtro para ocultar |

### Permissão e segurança

- Qualquer logado não-admin recebe 42501 da RPC; a tela mostra "sem acesso".
- Entrada no Hub só para quem está na lista (Acesso a Sistemas, sem Vinicius).
- As RPCs antigas e a aba da Central não mudam (decisão do usuário): o Vinicius, sendo admin, continua vendo a aba antiga. Só o sistema novo é restrito.
- Teste obrigatório: como Vinicius (admin fora da lista) a RPC devolve 42501; como membro da lista devolve dados; como `anon` nega.
- Não exportar nem exibir IP/navegador fora da tela de detalhe.

## Critérios de aceite

1. Admin filtra "Vinicius, 13/11, 17:30–19:00" e obtém o mesmo resultado do relatório manual (8 contas criadas, 7 baixas, R$ 24.500,00).
2. Usuário não-admin não vê dado algum (testar como `authenticated` sem papel admin e como `anon`, em ROLLBACK).
3. Horários batem com Brasília.
4. Detalhe mostra antes → depois de um `mudou_status`.
5. Excel baixa com o filtro aplicado.

## Plano de rollback

Sistema novo é aditivo: desativar o card em `systems` e remover o deploy. Migration (se houver) tem `rollback.sql` que só remove RPCs novas.

## Documentos a atualizar

`04-Sistemas/00 - Sumario Sistemas.md`, `CHANGELOG.md`, `03-Projeto/Auditoria/COMO_CONSULTAR_O_LOG_DE_ATIVIDADE.md`, `supabase/docs` (RPCs novas, se houver).

## Realizado

16/11/2026 (agente implementador). Nada foi aplicado no banco real, nada foi publicado, sem commit/push.

- Migration `supabase/db/migrations/20261116_377_spec318_log_atividade/` (número 377: 373 é da SPEC-299; 374–376 já usados por SPEC-312/314/315): `up.sql`, `rollback.sql`, `dry_run.sql` (termina em ROLLBACK) e `tests.sql`. Cria `auditoria.log_visualizadores` (RLS ligado, sem grant, Pedro e Filippo), `auditoria.pode_ver_log()` e as RPCs `public.auditoria_log_listar` (com `p_sql_direto` = todos/ocultar/somente e coluna `sql_direto`), `auditoria_log_resumo_usuarios` (sem campos de senha) e `auditoria_log_filtros`. Todas SECURITY DEFINER, `search_path` vazio, trava `IS NOT TRUE` com 42501, REVOKE de PUBLIC/anon e GRANT só a authenticated. `auditoria_listar`/`auditoria_resumo_usuarios` e a aba da Central não foram tocadas.
- Sistema `04-Sistemas/log-atividade/` (sem git próprio ainda): login, filtros (usuário, de/até em Brasília, sistema, ação, busca, SQL direto, mostrar telas), lista paginada (100) com badge "SQL direto", detalhe antes → depois + IP/navegador, aba Por usuário, exportar Excel do filtro (exceljs, até 50.000 linhas, sem IP/navegador), tela "Sem acesso" para 42501. Horários via `America/Sao_Paulo`; o filtro de/até é interpretado como UTC-03:00 fixo (Brasil sem horário de verão). Este sistema NÃO se registra em `auditoria_registrar_tela`.
- Verificação: `tsc` (typecheck), `vite build`, `oxlint` (nos arquivos, exit 0) e `oxfmt --check` ok. Dry-run e tests.sql NÃO foram rodados (não se toca no banco real; o usuário roda).

### Teste manual (golden path) pendente do usuário

1. Após aplicar a 377: entrar como Pedro/Filippo, filtrar "Vinicius, 13/11, 17:30–19:00" e conferir com o relatório manual (8 contas criadas, 7 baixas, R$ 24.500,00).
2. Entrar como Vinicius (admin fora da lista) e Lana: tela "Sem acesso".
3. Abrir um evento `mudou_status`: antes → depois; conferir horários com Brasília; baixar o Excel com filtro aplicado; testar "Somente SQL direto"/"Ocultar".

### Passos manuais do usuário (adicionais)

- Rodar `dry_run.sql` e `tests.sql` da 377 e aplicar `up.sql` no SP.
- Criar o repositório `log-lucenera`, o projeto Cloudflare Pages (`log-lucenera.pages.dev`, variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` do SP) e publicar por wrangler.
- Registrar em `systems` (exemplo, ajustar `display_order`/colunas ao schema real antes): `INSERT INTO public.systems (slug, name, link, ...) VALUES ('log-atividade', 'Log de Atividade', 'https://log-lucenera.pages.dev', ...)` e liberar em Acesso a Sistemas só para Pedro e Filippo. O `systems.link` também faz o log atribuir o sistema dos eventos feitos nesse site.
- Depois de publicar: atualizar o endereço no `04-Sistemas/00 - Sumario Sistemas.md` e o ponteiro do submódulo.
- Rodar o agente `revisor` antes de qualquer commit.

## Pendências

- [ ] Decidir se `financeiro_eventos` entra na mesma lista (não implementado).
- [ ] Decidir sobre atualização ao vivo (polling 15 s; não implementado).
- [x] Formato, lista de acesso (Pedro e Filippo) e base de código (Central) decididos em 16/11/2026.
