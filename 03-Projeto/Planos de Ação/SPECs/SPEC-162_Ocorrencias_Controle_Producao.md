---
titulo: "SPEC-162 — Controle de Produção: registro de ocorrências por pedido"
status: "CONCLUÍDA e PUBLICADA (24/09/2026) — migration aplicada no Supabase real (dry-run+COMMIT, junto
  com as da SPEC-161), Controle de Produção publicado no Skip v0.0.9, submodule d64bcba. Pendente: confirmar
  as 3 decisões assumidas e teste visual no navegador."
data_ultima_modificacao: 2026-09-24
sistemas_envolvidos:
  - Controle de Produção (`controle-de-producao`, Skip projectId 60535)
relacionado:
  - SPEC-156 (criou o sistema)
  - SPEC-161 (refinamentos; o código desta SPEC foi construído em cima dele)
---

## Pedido (Vinícius, 24/09/2026)

> "No app de controle de produção, preciso que crie um lugar para colocar ocorrências. Isso será preenchido
> pela produção em situações como, por exemplo: desenho errado, desenho incompleto, retrabalho de peça
> pronta, etc. Isso tem que ser permitido preencher em um pedido que ainda não está pronto ou que já foi
> concluído."

## Solução

- Tabela nova `producao_pedido_ocorrencias` (FK `producao_pedidos`, `ON DELETE CASCADE`): `categoria`,
  `descricao` (ambas obrigatórias), `registrado_por` (FK `usuarios`, preenchido pelo login),
  `registrado_em` (default `now()`). RLS: `authenticated` pode ler e inserir (mesmo padrão das tabelas da
  SPEC-161).
- **Sem checagem de status** em nenhuma camada — funciona em pedido em andamento e em pedido "Pronto".
- Categorias (lista no frontend, `text` no banco para aceitar categoria nova sem migration):
  Desenho errado, Desenho incompleto, Retrabalho de peça pronta, Outro.
- Append-only: não há editar/excluir ocorrência pela aplicação (é registro de fato, como handoff e
  alteração de prazo).
- UI: botão **"Ocorrência"** (vermelho) em toda linha da listagem → modal com tipo + descrição. Contador
  "N ocorrência(s)" abaixo do status (clicável, abre a linha). Seção "Ocorrências" no painel expansível,
  com tipo, descrição, quem registrou e quando.

## Decisões assumidas (confirmar com o usuário)

1. Categorias iniciais = as 3 citadas + "Outro".
2. Sem anexo de foto na ocorrência (pode ser útil em retrabalho — fica como evolução).
3. Sem campo "resolvida/tratativa" — só o registro.
4. Quem registra precisa ter login (mesma pendência da SPEC-161 P5: logins da produção ainda não existem
   em `usuarios`).

## Arquivos

- `supabase/db/migrations/20260924_161_producao_ocorrencias/001_producao_pedido_ocorrencias.sql`
- `04-Sistemas/controle-de-producao/src/services/producao.ts` (tipos, `listarOcorrencias`,
  `registrarOcorrencia`, `ocorrencias_count` na listagem)
- `04-Sistemas/controle-de-producao/src/components/producao/ModalOcorrenciaProducao.tsx` (novo)
- `04-Sistemas/controle-de-producao/src/components/producao/PedidoDetalhesExpandido.tsx`
- `04-Sistemas/controle-de-producao/src/pages/Producao.tsx`

Verificação: `tsc --noEmit`, `oxlint src` e `vite build` sem erros.

## Critérios de aceite

- [ ] Registrar ocorrência num pedido em andamento → aparece no painel e no contador.
- [ ] Registrar ocorrência num pedido "Pronto" → idem, sem bloqueio.
- [ ] Salvar sem tipo ou sem descrição → botão desabilitado (e banco rejeita string vazia).
- [ ] Nome de quem registrou + data/hora aparecem na lista.

## Atenção na aplicação

A listagem passa a embutir `producao_pedido_ocorrencias(count)` junto com as contagens da SPEC-161 — se o
frontend for publicado antes das migrations (SPEC-161 + esta), a listagem inteira quebra. Ordem: aplicar
migrations → publicar.

## Rollback

`DROP TABLE public.producao_pedido_ocorrencias;` + reverter os 4 arquivos do frontend.

## Realizado (revisão, 24/09/2026)

- Conferida a migration `20260924_161_producao_ocorrencias/001_producao_pedido_ocorrencias.sql` contra
  o snapshot real (`producao_pedidos.id` uuid, `usuarios.id` uuid — FKs corretas) e contra o padrão das
  3 migrations irmãs da SPEC-161 (`20260923_160_*`): mesma estrutura (`id`, FK com `ON DELETE CASCADE`,
  `criado/registrado_em timestamptz default now()`, índice btree no FK, RLS `authenticated`
  select+insert). Nenhuma correção necessária — código e migration já estavam consistentes com o
  restante do sistema.
- Revisado código contra os critérios de aceite: confirmado que não há checagem de status em nenhuma
  camada (banco, `registrarOcorrencia`, `ModalOcorrenciaProducao`) — pedido "Pronto" aceita ocorrência
  normalmente. Botão "Salvar" do modal fica desabilitado sem categoria/descrição (`podeSalvar`), e o
  banco tem `CHECK (btrim(...) <> '')` como segunda camada. `PedidoDetalhesExpandido` tem
  `useEffect([pedido.id, pedido.ocorrencias_count])`, então quando uma ocorrência é registrada com o
  painel aberto, `onSuccess={loadPedidos}` atualiza `ocorrencias_count` na listagem e isso já dispara o
  recarregamento da seção — sem gap.
- `npx tsc --noEmit -p .`: sem erros. `npx oxlint src`: sem erros (exit 0, sem findings). `npx vite
  build`: build OK (só o aviso padrão de chunk >500kB, pré-existente, não relacionado a esta SPEC).
- `CHANGELOG.md` do repo central atualizado (entrada 2026-09-24).
- **Pendência de documentação (pré-existente, não resolvida aqui)**: nenhum arquivo em
  `supabase/db/domains/` documenta `producao_pedidos*` — a própria SPEC-156 já registrou isso como
  pendência em aberto ("nenhum dos dois módulos [Produção/Garantia] ficou dentro de Estoque/Compras...
  fica como pendência de onde documentar os sistemas novos") e a SPEC-161 também não resolveu. Não
  decidi um domínio por conta própria para não inventar uma escolha de arquitetura de documentação que
  já foi explicitamente deixada em aberto; segue pendente junto com a de SPEC-156.
- `04-Sistemas/controle-de-producao/supabase/AI_DB_CONTEXT.md` não existe neste sistema — nada para
  atualizar, não foi criado (fora do escopo desta SPEC).

## Passos manuais do usuário (pendentes)

1. Aplicar a migration `supabase/db/migrations/20260924_161_producao_ocorrencias/` no Supabase real
   (junto com as migrations da SPEC-161, `20260923_160_*`, na mesma janela — a listagem embute as duas
   contagens juntas).
2. Testar o golden path no navegador: registrar ocorrência num pedido em andamento e num pedido
   "Pronto"; conferir que aparece no contador da linha, no painel expansível (com quem registrou e
   quando) e que salvar sem categoria/descrição não é possível.
3. Publicar no Skip (`controle-de-producao`, projectId 60535) só depois do passo 1.
4. Confirmar com o usuário as 3 decisões assumidas (categorias, sem foto, sem "resolvida") e a
   pendência de onde documentar `producao_pedidos*`/`garantia_*` em `supabase/db/domains/`.
5. Rodar o agente `revisor` antes de qualquer commit.
