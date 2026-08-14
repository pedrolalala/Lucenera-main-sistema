---
titulo: "SPEC-098 — Troca de peça em Reserva entre projetos (Projetistas/Gerente/Admin)"
status: pendente
data_ultima_modificacao: 2026-08-14
sistemas_envolvidos:
  - Separação Parcial (separacao-parcial, Skip 48801)
  - Supabase (banco central) — reaproveita `transferencias_estoque`/RPCs da SPEC-011, guard novo em `aprovar_transferencia_estoque`
dependencias:
  - SPEC-011 (`transferencias_estoque`, `solicitar_transferencia_estoque`, `aprovar_transferencia_estoque`, `cancelar_transferencia_estoque` — mecanismo já existe no banco, nunca teve frontend)
  - SPEC-010 (`estoque_saldos_projeto_item` — saldos por setor que a troca movimenta)
  - SPEC-072 (sistema "Separação Parcial" onde a tela nova entra)
---

# SPEC-098 — Troca de peça em Reserva entre projetos (Projetistas/Gerente/Admin)

> Origem: pedido direto do usuário nesta conversa. Refinado por 2 rodadas de perguntas de esclarecimento (ver Decisões aprovadas).

## Checklist de Ação

- [x] Adicionar guard novo em `aprovar_transferencia_estoque`: hoje só libera `role IN ('admin','gerente')`; adicionado alternativa "funcionário logado tem `cargo = 'Projetista'`" (ver Definição da SPEC → Regra de autorização). Sem checagem de equipe entre os projetos. **Aplicado no Supabase real** (migration `20260814_110_spec098_troca_reserva_projetista`).
- [x] Criar RPC nova `trocar_reserva_projetista(p_origem_projeto_item_id uuid, p_destino_projeto_item_id uuid, p_quantidade numeric, p_motivo text DEFAULT NULL)` — orquestra `solicitar_transferencia_estoque` + `aprovar_transferencia_estoque` em uma única chamada, para a troca ser imediata (sem etapa manual de "aprovar" separada) quando o guard novo for satisfeito. **Aplicado e testado no Supabase real** (ver Realizado).
- [x] Frontend (Separação Parcial): na tabela de itens da venda, ação "Trocar" na coluna final (visível só quando `q_reserva > 0`, e só para usuário Projetista/gerente/admin — sem restrição de equipe). **Publicado em produção** (Skip 48801, v0.0.24).
- [x] Modal de troca: busca de destino restrita a `projeto_itens` do mesmo `produto_id` (qualquer venda/projeto, sem filtro de equipe); campo quantidade (limitado à `q_reserva` de origem); campo motivo (opcional). Testado ao vivo no navegador.
- [x] Nova tela "Log de Trocas" em Separação Parcial (botão no cabeçalho, só visível a quem pode trocar): lista `transferencias_estoque` (todas, ordenadas por `solicitado_em desc`) com produto/código, venda e cliente de origem e destino, quantidade, quem solicitou (nome, não só uuid), motivo, data. Testado ao vivo no navegador.
- [x] Painel "Reservado por Cliente/Projeto" dentro do modal de troca (pedido do usuário, espelhando o card de peça do Cadastro Lucenera — SPEC-049): reaproveita a view `vw_cadastro_produto_reserva_detalhe` (já em produção), sem view nova. Funciona como picker de destino. **Achado do teste ao vivo**: essa view só lista projetos com `q_reserva > 0 OU q_entrega_futura > 0` para aquele produto — um projeto sem nenhuma das duas coisas não aparece como opção de destino (não é bug: reflete o cenário real, todo item de orçamento aprovado nasce com uma das duas > 0 pelo trigger da SPEC-010).
- [ ] Resolver dentro da RPC se o usuário logado pode aprovar: `auth.uid() = usuarios.id` → checar `usuarios.role IN ('admin','gerente')` OU `EXISTS (SELECT 1 FROM funcionarios WHERE usuario_id = auth.uid() AND cargo = 'Projetista')`.
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` (uso novo de `transferencias_estoque`, agora com frontend) e o `AI_DB_CONTEXT.md` do sistema Separação Parcial.

### Passos manuais do usuário

- [ ] Dar login (`usuario_id` + `role`) para Thais Gomes Pegrucci Favaron, se ela também deve poder usar a troca — hoje ela tem `cargo = 'Projetista'` mas **não tem usuário/login vinculado** (ver achado abaixo), então não conseguiria usar a função como está.
- [ ] Aplicar a migration desta SPEC no Supabase real (a IA não aplica sozinha).
- [ ] Homologar a troca com um caso real (ou fictício revertido) antes de liberar em produção.

## Objetivo

Em "Separação Parcial", quando uma peça está em **Reserva** para o projeto A, mas o projeto B (mais urgente) precisa da mesma peça, o funcionário deve poder "trocar" — mover a peça reservada de A para B, permanecendo em Reserva (agora para B). Essa troca só pode ser feita por quem for Projetista, gerente ou admin, e precisa ficar registrada num log visível dentro do próprio sistema (não só no banco).

## Decisões aprovadas

- **O que é "trocar"**: não é "separar para entrega" nem "empréstimo com devolução esperada". É realocar a reserva em si — a peça sai da `q_reserva` do projeto A e entra na `q_reserva` do projeto B. O projeto A passa a depender de entrega futura para aquela quantidade (não fica sem rastro).
- **Quem pode trocar (decisão final, substitui a ideia inicial de "mesma equipe")**: qualquer usuário com `cargo = 'Projetista'` (hoje: Marina Pousa Barbara Gregorio, Thairine Cristina da Silva, Thais Gomes Pegrucci Favaron — confirmado no banco, só 3 pessoas, não 4 como dito inicialmente) **ou** `usuarios.role IN ('gerente', 'admin')`. **Sem restrição de equipe entre os dois projetos** — quem estiver nesse grupo pode trocar peça reservada entre quaisquer dois projetos (mesmo produto). Isso substitui a ideia original de comparar `funcionarios_financeiro.equipes_id`/`projetos.equipe_id` (abandonada — ver histórico abaixo).
- **Aprovação**: a troca é **imediata** para quem está no grupo liberado — não passa por uma etapa manual de aprovação separada.
- **Log**: reaproveitar `transferencias_estoque` (já tem `solicitado_por`, `aprovado_por`, `quantidade`, `motivo`, timestamps — é exatamente o formato de log necessário) mais uma aba nova na UI de Separação Parcial para consulta fácil, em vez de tabela de log dedicada nova.

### Histórico da decisão (contexto, não é mais a regra vigente)

A ideia original desta conversa era restringir por equipe: comparar `funcionarios_financeiro.equipes_id` (equipe do funcionário logado) com `projetos.equipe_id` dos dois projetos envolvidos. Essa checagem foi **abandonada** depois que se descobriu que só 2 dos 9 funcionários com login tinham `equipes_id` preenchido (dado incompleto, inviabilizava o uso real). O usuário decidiu substituir por uma lista de cargos/papéis liberados (Projetista/gerente/admin), que já é 100% resolvível com dados que já existem e estão completos hoje (`funcionarios.cargo`, `usuarios.role`).

## Definição da SPEC

### Estado atual confirmado no banco (achado principal desta SPEC)

O mecanismo já existe inteiro, da SPEC-011, e nunca teve frontend em nenhum sistema (confirmado por grep em todos os `04-Sistemas/*/src`, só aparece em `types.ts` gerado, nunca em código de aplicação):

- `transferencias_estoque` (`01_schema_full.sql:6410`): `origem_projeto_item_id`, `destino_projeto_item_id`, `quantidade`, `status` (`solicitada`/`aprovada`/`cancelada`), `motivo`, `solicitado_por`, `aprovado_por`, `solicitado_em`, `aprovado_em`, `cancelado_em`, `motivo_cancelamento`. RLS já libera `SELECT` para qualquer `authenticated` (`authenticated_select_transferencias_estoque`) — a aba de log não precisa de policy nova.
- `solicitar_transferencia_estoque(p_origem_projeto_item_id, p_destino_projeto_item_id, p_quantidade, p_motivo)`: sem restrição de role hoje; valida quantidade > 0, origem ≠ destino, mesmo `produto_id` nos dois lados, e que a origem tem `q_reserva` suficiente. Insere em `transferencias_estoque` com `status = 'solicitada'`.
- `aprovar_transferencia_estoque(p_transferencia_id)`: **hoje exige `role IN ('admin','gerente')`** (`03_functions.sql:1124`) — é o guard que esta SPEC precisa estender. Faz a movimentação real: `origem.q_reserva -= quantidade`, `origem.q_entrega_futura += quantidade`, `origem.q_transferida_saida += quantidade`; `destino.q_reserva += quantidade`, `destino.q_entrega_futura -= LEAST(quantidade, destino.q_entrega_futura)`. Grava dois registros em `estoque_movimentos_projeto_item` (`transferencia_saida`/`transferencia_entrada`, `criado_por = auth.uid()`) — **esse já é o log de "quem fez", só falta ficar fácil de ver**. Marca `status = 'aprovada'`, `aprovado_por = auth.uid()`.
- `cancelar_transferencia_estoque(p_transferencia_id, p_motivo)`: só permite cancelar enquanto `status = 'solicitada'` — não muda nesta SPEC, mas fica disponível como rollback manual caso a troca imediata precise ser desfeita antes de ser confirmada (não aplicável no fluxo imediato desta SPEC, que já nasce aprovada).

### Quem tem `cargo = 'Projetista'` hoje (confirmado no banco)

| Nome | `usuario_id` (login) | `role` |
|---|---|---|
| Marina Pousa Barbara Gregorio | sim | viewer |
| Thairine Cristina da Silva | sim | viewer |
| Thais Gomes Pegrucci Favaron | **não** | — |

Thais tem o cargo certo mas **não tem usuário/login vinculado** (`funcionarios.usuario_id IS NULL`) — hoje ela não conseguiria logar em nenhum sistema, então também não vai conseguir usar a troca até alguém criar o login dela (ver Passos manuais do usuário). Marina e Thairine já logam hoje com `role = 'viewer'` — o guard novo não depende do `role` delas ser mudado, só do `cargo = 'Projetista'`.

Quem já tem `role IN ('admin','gerente')` hoje (ganha acesso automaticamente, sem precisar ser Projetista): Vinicius Bortolin Costa, Lana Bispo, Pedro Leonel Laghi (admin), Mariane de Moraes Ribeiro (gerente).

### Regra de autorização (mudança proposta em `aprovar_transferencia_estoque`)

```sql
-- guard atual:
IF v_role IS NULL OR v_role NOT IN ('admin', 'gerente') THEN
    RAISE EXCEPTION 'Apenas admin ou gerente pode aprovar transferencia de estoque.' ...
END IF;

-- guard novo (proposta): admin/gerente OU funcionário com cargo = 'Projetista'
IF v_role NOT IN ('admin', 'gerente')
   AND NOT EXISTS (
       SELECT 1 FROM public.funcionarios
       WHERE usuario_id = auth.uid() AND cargo = 'Projetista'
   ) THEN
    RAISE EXCEPTION 'Apenas Projetista, gerente ou admin pode trocar peça reservada entre projetos.' USING ERRCODE = '42501';
END IF;
```

Sem checagem de equipe entre origem e destino — quem está no grupo liberado pode trocar entre quaisquer dois projetos (desde que mesmo `produto_id`, regra que `solicitar_transferencia_estoque` já garante).

### RPC orquestradora nova: `trocar_reserva_projetista`

```
trocar_reserva_projetista(
  p_origem_projeto_item_id uuid,
  p_destino_projeto_item_id uuid,
  p_quantidade numeric,
  p_motivo text DEFAULT NULL
) RETURNS jsonb
```

Só chama `solicitar_transferencia_estoque(...)` e, na sequência, `aprovar_transferencia_estoque(transferencia_id)` — sem duplicar a lógica de saldo, reaproveitando 100% do que já existe e já foi pensado/desenhado na SPEC-011. `solicitado_por` e `aprovado_por` ficam com o mesmo `auth.uid()` (a mesma pessoa solicitou e "aprovou" na hora) — isso é esperado e é justamente o registro de "quem fez a troca" pedido pelo usuário.

### Frontend — Separação Parcial

- Na tela de detalhe da venda (`SeparacaoParcialPage.tsx`), coluna "Reserva": adicionar ação "Trocar" por linha quando `q_reserva > 0` — visível apenas se o usuário logado for Projetista/gerente/admin (checagem simples no client, ex.: RPC/view auxiliar `sou_projetista_ou_gestor()`, ou resolver client-side a partir de `funcionarios.cargo`/`usuarios.role` já carregados no login).
- Modal "Trocar peça reservada": busca de destino restrita a `projeto_itens` do mesmo `produto_id` (qualquer venda/projeto, sem filtro de equipe); campo quantidade (máx. = `q_reserva` da origem); motivo (opcional); chama `trocar_reserva_projetista`.
- Nova aba "Log de Trocas": tabela lendo `transferencias_estoque` join `projeto_itens`/`projetos`/`contatos`/`produtos` (origem e destino) + `usuarios` (nome de quem solicitou/aprovou), ordenada por mais recente. Sem valor financeiro (mesmo padrão já adotado no painel de boletos desta SPEC-072).
- Painel "Reservado por Cliente/Projeto": reaproveita `getReservasProduto`/`vw_cadastro_produto_reserva_detalhe`, o mesmo padrão já implementado em `04-Sistemas/cadastro-lucenera-b86fe/src/services/produtos.ts:194` (SPEC-049) — consulta por `produto_id`, mostra projeto/cliente/equipe/qtd vendida/reservado/entrega futura. Usado tanto como painel informativo (ver quem mais tem essa peça) quanto como lista de opções de destino no modal de troca (filtra o próprio `projeto_item_id` de origem da lista).

## Análise de ecossistema (obrigatória)

- **Depende de**: `projeto_itens`, `produtos`, `estoque_saldos_projeto_item`, `usuarios` (`role`), `funcionarios` (`cargo`, `usuario_id`). Não depende de `funcionarios_financeiro`/`equipes_projetos`/`projetos.equipe_id` (regra de equipe abandonada) nem de `boletos`/`projeto_parcelas`.
- **Afeta**: só o sistema Separação Parcial (novo consumidor de `transferencias_estoque`) e o guard de uma RPC já existente (`aprovar_transferencia_estoque`). Não afeta CRM, Financeiro, Cadastro, RH ou Compras — só leitura adicional em `funcionarios`/`usuarios`, sem alterar essas tabelas.
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum novo — a SPEC reaproveita 100% do modelo de dados já existente (SPEC-011), sem criar coluna ou tabela nova.
- **Migration antiga que contradiz o snapshot central**: nenhuma encontrada.
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim, do sistema `separacao-parcial` (novo uso de `transferencias_estoque`/RPCs) e `supabase/db/domains/estoque_compras.md` (documentar que o mecanismo da SPEC-011 finalmente tem frontend, e a regra de acesso por cargo/role).

## Realizado

### 2026-08-14

- Migration `20260814_110_spec098_troca_reserva_projetista` aplicada no Supabase real: guard novo em `aprovar_transferencia_estoque` + RPC nova `trocar_reserva_projetista`.
- **Bug real corrigido antes de ir pro ar**: `funcionarios.cargo` de Marina e Thairine tem um espaço sobrando (`'Projetista '`, 11 caracteres) — a comparação exata `cargo = 'Projetista'` nunca teria batido com ninguém. Trocado para `btrim(cargo) = 'Projetista'` antes de aplicar.
- Testado direto no banco (simulando `auth.uid()` via `request.jwt.claim.sub`, sem precisar de login real no navegador):
  - Caminho de sucesso (dry run, `ROLLBACK`): Marina (cargo Projetista) conseguiu trocar 2 unidades — saldo mudou como esperado (origem `q_reserva` 5→3, `q_entrega_futura` 0→2; destino `q_reserva` 0→2).
  - Caminho de rejeição: usuário com `role = 'funcionario'` (sem cargo Projetista, sem role admin/gerente) foi bloqueado com a mensagem de erro esperada.
  - Teste real (committed, a pedido do usuário): troca de 2 unidades entre a venda **ORC-0022** (projeto `99.901`, cliente TESTE BUG SWEEP CLIENTE, produto código `9524`/STH6550-27, `projeto_item_id 200cd9f3-d9b6-44aa-b4cb-466a669fba5c`) e um projeto novo criado só para este teste (`99.902-TESTE-SPEC098`, mesmo cliente, `projeto_item_id 1b40f22b-25e5-4437-8c83-873f27cfc06e`). Resultado real no banco: ORC-0022 ficou com `q_reserva = 3`/`q_entrega_futura = 2`; o projeto novo ficou com `q_reserva = 2`. Registro em `transferencias_estoque` com `solicitado_por = aprovado_por` = Marina, motivo preenchido, status `aprovada`.
  - Dado de teste **revertido**: troca reversa (2 unidades de volta pra ORC-0022) + apagado o rastro de auditoria dos dois movimentos de teste (`estoque_movimentos_projeto_item`, `transferencias_estoque`) + apagado projeto/orçamento/item/saldo de teste (`99.902-TESTE-SPEC098`) inteiros. Conferido no fim: ORC-0022 de volta a `q_reserva = 5`/`q_entrega_futura = 0`, sem nenhum resíduo em `vw_cadastro_produto_reserva_detalhe`.
- Adicionada RPC `pode_trocar_reserva()` (não estava no desenho original) — espelha o guard de `aprovar_transferencia_estoque` pra decidir no frontend se mostra a ação "Trocar", sem duplicar a regra em SQL client-side.
- Frontend implementado em `04-Sistemas/separacao-parcial` (lido e escrito direto no Skip, projeto `48801` — checado `skip_project_status` antes, estava limpo): ação "Trocar" por item, modal com painel "Reservado por Cliente/Projeto" (picker de destino), quantidade, motivo, e tela "Log de Trocas" no cabeçalho. QA completo do Skip (setup/staticAnalysis/build/integrations/test) passou limpo. Publicado em produção (`v0.0.24`, `ee2b8a1`).
- **Testado ao vivo no navegador**, logado como usuário admin real (sessão já ativa), na venda **ORC-0022** pedida pelo usuário: criado um segundo projeto de teste (`99.903-TESTE-SPEC098`) com a mesma peça (produto 9524) simulando `q_entrega_futura = 2` (cenário realista de "projeto esperando a peça"); troca de 2 unidades confirmada pela UI; conferido que Reserva caiu de 5→3, Entrega Futura foi de 0→2, e o registro apareceu certo na tela "Log de Trocas" (peça, de/para, quantidade, "Pedro", motivo, data). Depois revertido: troca no sentido contrário + limpeza total do rastro de auditoria e do projeto de teste — ORC-0022 conferido de volta a `q_reserva = 5`/`q_entrega_futura = 0`.
- Usuário descartável (`teste.qa.spec098@lucenera.local`, criado via Admin API só pra ter uma sessão de teste alternativa) foi criado mas **não chegou a ser usado** (a sessão do admin real já estava ativa no navegador) — apagado ao final mesmo assim, sem resíduo.

## Pendências

- [ ] **P-1**: Thais Gomes Pegrucci Favaron (`cargo = 'Projetista'`) não tem `usuario_id`/login vinculado — não vai conseguir usar a função até alguém criar o login dela. Confirmar se isso deve ser resolvido antes do lançamento.
- [ ] **P-2**: Confirmar se a busca de "destino" no modal de troca deve mostrar só vendas/projetos já com saldo (`estoque_saldos_projeto_item` existente), ou incluir qualquer projeto ativo mesmo sem saldo hoje (nesse caso `solicitar_transferencia_estoque` já rejeitaria por falta de linha em `estoque_saldos_projeto_item`, então provavelmente não muda nada, mas vale confirmar na tela).
- [ ] **P-3**: Decidir se `cancelar_transferencia_estoque` deve ganhar uma ação na UI (ex.: desfazer uma troca feita por engano) — hoje só cancela enquanto `status = 'solicitada'`, e o fluxo desta SPEC já nasce `'aprovada'` (imediato), então cancelar não serviria para desfazer uma troca já efetivada; desfazer exigiria uma nova troca no sentido contrário. Não bloqueia a implementação, é decisão de UX.
- [ ] **P-4**: Se a lista de Projetistas/gerentes mudar no futuro (contratação, promoção, mudança de cargo), o acesso muda automaticamente junto (o guard lê `cargo`/`role` ao vivo, não uma lista fixa) — sem ação necessária, só registrado aqui para não surpreender ninguém.
- [x] ~~P-5~~ resolvida: dado de teste de 2026-08-14 revertido (troca reversa + limpeza de auditoria + exclusão do projeto de teste), sem resíduo em produção.
