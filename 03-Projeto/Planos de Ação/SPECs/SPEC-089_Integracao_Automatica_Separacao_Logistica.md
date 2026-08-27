---
titulo: "SPEC-089 — Integração automática entre Separação Parcial/Compras e Logística"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
  - Logística
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.3)
  - 03-Projeto/Planos de Ação/SPECs/SPEC-072_Novo_Sistema_Separacao_Parcial_por_Setor.md
---

# SPEC-089 — Integração automática entre Separação Parcial/Compras e Logística

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [06:24]-[07:41]). Catalogado como item 2.3 na SPEC-086.

## Checklist de Ação

- [x] Confirmar com o usuário a estratégia de integração — **Estratégia A**
      aprovada
- [x] Migration: RPC `finalizar_separacao_parcial_pronta(p_separacao_id,
      p_data_entrega)` — reconfere no servidor que a venda está 100%
      separada (nenhum item com `q_reserva > 0`), depois atualiza
      `separacoes.status = 'Pronto'` + `data_entrega`, disparando o trigger
      `trg_separacao_pronta` já existente
- [x] `SeparacaoParcialPage.tsx`: campo opcional "Data de entrega (se esta
      ação completar a venda)" ao lado do botão Separar; depois de separar,
      confere se a venda ficou 100% completa e, se sim e a data foi
      informada, chama a RPC nova
- [x] `entregador_id`: decisão do usuário — fica em branco, Logística
      assume/preenche depois (não é pedido na Separação Parcial)

### Passos manuais do usuário

- [x] Estratégia A aprovada, migration aplicada em produção (2026-08-13)

## Objetivo

O Matheus opera dois sistemas hoje: quando separa um pedido, precisa entrar
depois no sistema de Logística e refazer manualmente o mesmo registro pra
Entregas — "ele fica só com aquele sistema lá... ele já vai estar
operacional dentro de tudo que a gente tem" é a fala que resume o pedido.
Achado técnico importante durante a investigação: **essa integração já
existia, mas só pra um fluxo diferente do que a Separação Parcial (SPEC-072)
usa hoje** — esta SPEC conecta os dois sem duplicar a automação existente.

## Achado técnico (2026-08-13, confirmado direto no banco)

Existe um trigger `trg_separacao_pronta` em `separacoes` (`AFTER UPDATE OF
status, data_entrega`) que, quando `status` vira `'Pronto'` (com
`data_entrega` preenchida), **cria ou atualiza automaticamente uma linha em
`entregas`** — exatamente a automação pedida na reunião. O problema: esse
trigger só dispara na transição de `status`, e o fluxo atual de Separação
Parcial (`criarSeparacaoParcial` → `registrar_separacao_setor`, SPEC-072)
**nunca mudava o `status` de `separacoes`** — a linha era criada direto com
`status: 'Pendente'` e ficava assim; `registrar_separacao_setor` só move
saldo entre `q_reserva` e `q_ag_separar` em `estoque_saldos_projeto_item`,
sem tocar em `separacoes.status` nem em `entregas`.

Ou seja: a automação pedida na reunião já tinha sido construída uma vez, pro
fluxo antigo/completo de logística (`Rascunho → Pendente → Em separação →
Pronto → Enviado`), mas a Separação Parcial nova era um fluxo paralelo,
item-a-item, que nunca alimentava esse status.

## Decisões aprovadas

- **Estratégia A**: quando a última ação de "Separar" de uma venda deixa
  todos os itens com `q_reserva = 0`, a separação recém-criada é marcada
  como `Pronto` (com a data de entrega informada), disparando o trigger já
  existente — reaproveita infraestrutura testada em vez de duplicar lógica.
- `data_entrega` é pedida na hora de separar (campo opcional, só relevante
  se essa ação completar a venda).
- `entregador_id` fica em branco — Logística assume/preenche a entrega
  depois, não é responsabilidade da tela de Separação Parcial.

## Definição da SPEC

### Migration

`supabase/db/migrations/20260813_104_finalizar_separacao_parcial_pronta/001_finalizar_separacao_parcial_pronta.sql`
— `CREATE FUNCTION finalizar_separacao_parcial_pronta` (`SECURITY DEFINER`):
reconfere via `vw_estoque_saldos_projeto_item` que não sobra nenhum item com
`q_reserva > 0` para o `numero_venda` da separação antes de atualizar o
status — não confia no client.

### Frontend (`separacao-parcial`, Skip 48801)

- `separacaoParcialService.ts`: nova `finalizarSeparacaoPronta(separacaoId,
  dataEntrega)`.
- `SeparacaoParcialPage.tsx`: campo de data ao lado do botão "Separar";
  `handleSeparar` já retorna `separacaoId`; depois de re-buscar a venda,
  confere `vendaAtualizada.itens.every(i => i.q_reserva <= 0)` — se
  completo e com data informada, chama a RPC e mostra toast confirmando a
  criação automática da entrega.

## Realizado

### 2026-08-13

- Migration aplicada em produção; smoke-test com UUID inexistente confirmou
  erro correto ("Separação ... não encontrada"), sem tocar dado real.
- `SeparacaoParcialPage.tsx` e `separacaoParcialService.ts` publicados no
  Skip (projectId 48801), versão 0.0.18, QA limpo, produção publicada.
- Checkout local (`separacao-parcial`) estava atrás do origin (commits de
  auto-sync do Skip que o local nunca tinha buscado) — `git pull` antes de
  escrever, pra não sobrescrever nada; commit/push feito depois
  (`0ef3b85`).

### 2026-08-13 — correção (achada no teste ao vivo)

- **Bug real**: a nota de "Pendências" original tratava a ausência de
  `endereco_entrega` na entrega automática como comportamento já esperado
  — mas a decisão do usuário só cobria `entregador_id` (explicitamente "fica
  em branco, Logística assume depois"), nunca o endereço. Na prática,
  `separacoes.endereco_entrega` nunca é preenchido em nenhum ponto do fluxo
  novo (diferente do fluxo antigo de Logística, onde o próprio usuário
  digitava esse campo antes de marcar Pronto) — a tela
  `SeparacaoCardDetails.tsx` mostra literalmente `"N/A"` pro entregador.
  Achado só via inspeção do banco (nenhuma separação com status `Pronto`
  ainda existia em produção pra testar ao vivo o fluxo completo).
- Fix: `finalizar_separacao_parcial_pronta` passou a preencher
  `endereco_entrega`/`telefone` a partir do cadastro do cliente
  (`contatos.endereco_entrega`, fallback pro endereço principal) no
  momento de marcar como Pronto — só quando esses campos ainda estiverem
  vazios (`COALESCE`, nunca sobrescreve). `entregador_id` continua em
  branco, como decidido.
  Migration:
  `supabase/db/migrations/20260813_106_finalizar_separacao_preenche_endereco/001_finalizar_separacao_preenche_endereco.sql`,
  aplicada em produção. Smoke-test com UUID inexistente confirmou erro
  correto sem tocar dado real; lógica de montagem do endereço validada
  com `SELECT` somente-leitura contra clientes reais.

## Pendências

Nenhuma. `entregador_id` continua em branco por decisão do usuário —
Logística assume/preenche na hora de processar.
