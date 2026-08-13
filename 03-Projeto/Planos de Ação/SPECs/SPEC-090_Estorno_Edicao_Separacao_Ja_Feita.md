---
titulo: "SPEC-090 — Estorno/edição de separação já registrada, com observação, log e aviso ao logístico"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
  - Logística
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.4)
  - 03-Projeto/Planos de Ação/SPECs/SPEC-072_Novo_Sistema_Separacao_Parcial_por_Setor.md
---

# SPEC-090 — Estorno/edição de separação já registrada

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [07:41]-[10:38]). Catalogado como item 2.4 na SPEC-086.

## Checklist de Ação

- [ ] Migration: RPC `estornar_separacao_setor(p_projeto_item_id,
      p_quantidade, p_separacao_id, p_observacao text)` — devolve
      `q_ag_separar → q_reserva`, exige `p_observacao` não vazio, grava
      `estoque_movimentos_projeto_item` com `tipo='cancelamento'`
- [ ] Migration: coluna `alterado_apos_registro boolean DEFAULT false` +
      `alterado_em`/`alterado_por` em `separacoes` (aviso visual, ver
      "Decisão sobre notificação" abaixo)
- [ ] Frontend `SeparacaoParcialPage.tsx`: botão "Estornar"/"Editar" por
      linha de `parciais` (histórico), abrindo modal com campo de
      observação obrigatório
- [ ] Frontend Logística: badge/alerta visível quando
      `alterado_apos_registro = true` numa entrega já em andamento

### Passos manuais do usuário

- [ ] Confirmar a abordagem de aviso ao logístico (badge vs. sistema de
      notificação completo — ver achado abaixo)

## Objetivo

Hoje, depois de registrar uma separação em `SeparacaoParcialPage.tsx`, não
existe nenhuma forma de desfazer ou corrigir — só o botão "Separar", que cria
mais uma linha. O Vinícius descreveu um caso muito comum: "acontece muito,
muito, muito, muito" a pessoa perceber que separou a quantidade errada e
precisar corrigir. As duas opções que ele pede: **estornar a separação
inteira** ou **editar** (corrigir só a quantidade errada, sem mexer no
resto). Em ambos os casos, exige registrar uma observação obrigatória
("toda vez que fizer uma alteração, a pessoa tem que justificar") e, se a
separação já estiver em andamento na Logística, **avisar o logístico** —
"porque aí ele pode fazer entrega sem ver".

## Achado técnico (2026-08-13, confirmado direto no banco)

- `estoque_movimentos_projeto_item.tipo` já tem `'cancelamento'` como valor
  permitido no CHECK constraint, mas **nenhuma RPC usa esse tipo hoje** — só
  existe `registrar_separacao_setor`, que sempre soma (nunca subtrai). É
  preciso criar o caminho inverso do zero.
- **Não existe nenhuma tabela de notificação em todo o ecossistema** (0
  tabelas `notif*` em todo o schema, os 10 sistemas incluídos). Construir um
  sistema de notificação de verdade (por usuário, com leitura/não-lida) é um
  escopo bem maior do que este item da reunião — ver decisão abaixo.

## Decisões aprovadas

- Precisa de 2 caminhos: estornar a separação inteira, ou editar/corrigir
  parcialmente.
- Observação é obrigatória em qualquer uma das duas ações (não é campo
  opcional).
- O log de quem alterou e o motivo tem que ficar consultável (auditoria).

## Decisões pendentes

- **Aviso ao logístico**: construir notificação de verdade (tabela nova +
  UI de leitura, escopo maior, reaproveitável por outros fluxos no futuro)
  ou um **badge simples** ("⚠ alterado após separação") direto na tela de
  Logística, sem precisar de infraestrutura de notificação genérica? Dado
  que não existe nenhum sistema de notificação hoje em nenhum dos 10
  sistemas, a opção mais barata e proporcional ao pedido é o badge — mas
  fica como decisão do usuário.
- **Editar vs. estornar+recriar**: tecnicamente, "editar" pode ser
  implementado como um estorno automático seguido de um novo registro com a
  quantidade corrigida (reaproveita a mesma RPC de estorno + a
  `registrar_separacao_setor` já existente), em vez de uma terceira RPC de
  "editar" — mais simples e com o mesmo resultado auditável. Confirmar se
  essa simplificação é aceitável.
- Bloquear ou não a edição quando o item já está com status "Separado" (não
  só "Ag. Separar")? A fala do Vinícius é explícita: **tem que permitir
  mesmo assim** ("Não, tem que deixar... Tem que estornar, tem que
  deixar"), só avisando — confirmar que essa leitura está certa antes de
  implementar.

## Decisões finais (usuário, 2026-08-13)

- Badge/aviso simples aprovado (não notificação completa).
- "Editar" simplificado pra "estornar + separar de novo com a quantidade
  certa" — um único botão "Estornar", sem RPC de edição separada.
- Edição permitida mesmo com item já "Separado", só avisando (conforme a
  fala do Vinícius).

## Realizado

### 2026-08-13

- Migration `20260813_105_estornar_separacao_parcial`: `separacoes` ganha
  `alterado_apos_registro`/`alterado_em`/`alterado_por`; RPC
  `estornar_separacao_parcial(p_separacao_id, p_observacao)` devolve saldo
  pra reserva, exige motivo (valida no servidor), grava
  `estoque_movimentos_projeto_item` (`tipo='cancelamento'`) e anota aviso
  nas observações da `entrega` vinculada, se existir.
- `SeparacaoParcialPage.tsx`: botão "Estornar" por linha na tabela
  "Parciais desta venda" (some quando já `Cancelado`), modal com motivo
  obrigatório, badge vermelho pro status `Cancelado`.
- Publicado Skip 48801, v0.0.19, QA limpo.

## Pendências

Nenhuma.
