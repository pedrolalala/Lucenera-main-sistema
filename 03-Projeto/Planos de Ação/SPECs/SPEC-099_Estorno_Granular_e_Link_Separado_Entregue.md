---
titulo: "SPEC-099 — Estorno granular de separação + link real Ag.Separar→Separado→Entregue"
status: pendente
data_ultima_modificacao: 2026-08-14
sistemas_envolvidos:
  - Separação Parcial (separacao-parcial, Skip 48801)
  - Logística (lucenera-logistics-b7cd1) — inicialmente sem mudança de código prevista, mas o teste ao vivo achou que o status 'Pronto' nunca aparecia nas telas do Matheus; fix aplicado nos filtros de `useSeparacoes.ts`/`useCalendarData.ts` (ver Realizado, continuação)
  - Supabase (banco central) — nova coluna em `separacao_itens`, RPC nova de estorno granular, 2 triggers novos
dependencias:
  - SPEC-072 (Separação Parcial — estrutura base, `separacao_itens.projeto_item_id`)
  - SPEC-089 (integração automática Separação→Logística — trigger `trg_separacao_pronta`, tabela `entregas`)
  - SPEC-090 (`estornar_separacao_parcial` original, granularidade de separação inteira — esta SPEC substitui a lógica interna, mantém a RPC como "reverter tudo")
  - SPEC-010 (`estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` — CHECK já antecipava os tipos `'separado'`/`'entregue'`, órfãos até esta SPEC)
---

# SPEC-099 — Estorno granular de separação + link real Ag.Separar→Separado→Entregue

> Origem: usuário testou reverter uma separação (venda com produto 10009 e 11461 juntos) esperando desfazer só 2 das 7 peças de um item — o estorno reverteu a separação inteira (os 2 itens, todas as quantidades). Na mesma conversa, pediu pra fechar o "link" que faltava entre Ag. Separar → Separado → Entregue no estoque (gap já registrado como pendência em sessões anteriores).

## Checklist de Ação

- [x] Adicionar `separacao_itens.quantidade_estornada numeric(10,2) DEFAULT 0 NOT NULL` (CHECK entre 0 e `quantidade`) — permite reverter parcialmente um item, várias vezes, até o total. **Aplicado no Supabase real.**
- [x] Criar RPC `estornar_item_separacao(p_separacao_item_id uuid, p_quantidade numeric, p_observacao text)` — reverte só a peça e a quantidade pedidas (não a separação inteira). Bloqueia se o item já foi fisicamente separado (`separacao_itens.separado = true`). **Aplicado e testado (banco + ao vivo no navegador).**
- [x] Refatorar `estornar_separacao_parcial(p_separacao_id, p_observacao)` para virar "reverter tudo": chama a RPC granular internamente para cada item ainda não totalmente estornado. **Aplicado e testado.**
- [x] Frontend (Separação Parcial): modal de estorno com lista de itens (restante por peça), campo de quantidade por peça, e dois botões — "Reverter tudo" e "Estornar peça(s) selecionada(s)". **Publicado em produção** (Skip 48801, v0.0.25) e testado ao vivo.
- [x] Trigger novo `sync_separado_ao_ficar_pronto` em `separacoes` (AFTER UPDATE OF status): quando o status de uma separação vira `'Pronto'`, move a quantidade de cada item **daquela separação** (só os com `projeto_item_id`, ainda não marcados `separado`) de `q_ag_separar` para `q_separado`, marca `separacao_itens.separado = true`, grava em `estoque_movimentos_projeto_item` (`tipo = 'separado'`). **Aplicado e testado.**
- [x] Trigger novo `sync_entregue_ao_finalizar_entrega` em `entregas` (AFTER UPDATE OF status): quando `entregas.status` vira `'Entregue'`, move a quantidade de cada item da separação vinculada de `q_separado` para `q_entregue`. **Aplicado e testado.**
- [x] **Decisão do usuário**: os 424 registros antigos de Logística não recebem nenhum link retroativo — ficam como estão, sem tentativa de backfill.
- [ ] Atualizar `supabase/db/domains/estoque_compras.md` e `logistica.md` com os triggers novos e o encerramento do gap "Ag Separar→Separado→Entregue vaporware".

### Passos manuais do usuário

- [ ] Aplicar a migration desta SPEC no Supabase real (a IA não aplica sozinha).
- [ ] Homologar o estorno granular e o link Pronto→Separado→Entregue com um caso real (ou fictício revertido) antes de liberar em produção.

## Objetivo

Duas correções, ambas descobertas testando a Separação Parcial ao vivo:

1. **Estorno granular**: hoje `estornar_separacao_parcial` reverte a separação inteira (todos os itens, toda a quantidade de cada um) — sem jeito de desfazer só uma peça ou só parte da quantidade. Passa a aceitar peça + quantidade específicas, mantendo a opção de reverter tudo de uma vez.
2. **Link real Ag.Separar→Separado→Entregue**: os campos `q_separado`/`q_entregue` de `estoque_saldos_projeto_item` existem desde a SPEC-010 mas nunca foram escritos por nenhuma função — ficam sempre em 0 na tela de Separação Parcial. Fecha esse gap conectando nos pontos que a própria Separação Parcial/Logística novas já usam (`status = 'Pronto'` e `entregas.status = 'Entregue'`), sem tentar religar o fluxo antigo do Matheus (que nunca teve granularidade de item pra começo de conversa).

## Decisões aprovadas

- **Granularidade do estorno**: por peça (`projeto_item_id`) e quantidade específica, com opção de "reverter tudo" continuando disponível. Confirmado pelo usuário: *"podendo pedir uma peça apenas e a quantidade e uma opção de extornar tudo pedido"*.
- **Onde conectar o link Separado/Entregue**: **não** no fluxo antigo de Logística (`separacoes.status IN ('material_solicitado','separado','finalizado')`) — investigação mostrou que esses 424 registros nunca têm `separacao_itens` vinculado (usam só o campo de texto livre `separacoes_parciais`), então não há nada pra sincronizar ali. Conecta no fluxo que a própria Separação Parcial/SPEC-089 já usa: `separacoes.status = 'Pronto'` (marca fisicamente separado) e `entregas.status = 'Entregue'` (marca entregue). Decisão do usuário: *"vamos fazer do jeito certo com o fluxo totalmente correto e deixar esses dados que já foram finalizados sem o link porque o fluxo não funcionava"*.
- **Sem backfill dos 424 registros antigos** — ficam como estão, decisão explícita do usuário (ver acima).

## Definição da SPEC

### Achado técnico — por que "conectar no fluxo antigo" não funcionaria

Investigação ao vivo no banco real:

- `SeparacaoPage.tsx` (tela do Matheus) só lista separações com `status IN ('material_solicitado', 'Em separação', 'separado')` — o status `'Pendente'` (o que a Separação Parcial usa ao criar uma separação nova) **não aparece nessa lista**. Ou seja, separações novas nunca aparecem na tela antiga do Matheus hoje.
- Todos os 424 registros com status antigo (`finalizado`: 415, `separado`: 7, `material_solicitado`: 2) têm **zero** `separacao_itens` vinculados — usam só `separacoes.separacoes_parciais` (texto livre, sem `projeto_item_id`). Não há como sincronizar `estoque_saldos_projeto_item` pra eles porque não existe o vínculo estruturado.
- As únicas separações com `separacao_itens.projeto_item_id` preenchido hoje (3 separações, 4 itens) estão todas com `status = 'Cancelado'` — nenhuma passou por `'Pronto'` ainda em produção real (só nos testes desta e da SPEC-098, todos revertidos).
- Conclusão: o único ponto de conexão que atinge dados que de fato têm saldo de estoque associado é a transição `Pendente → Pronto` (já disparada por `finalizarSeparacaoPronta`, SPEC-072/089) e, depois, `entregas.status → 'Entregue'` (tabela criada pela SPEC-089).

### Regras de negócio dos triggers novos

- **`Pronto` = fisicamente separado**: quando uma separação vira `'Pronto'`, os itens dela (com `projeto_item_id`) saem de `q_ag_separar` e entram em `q_separado`. Escopo é só os itens **daquela separação específica** — se a mesma venda tiver outra separação parcial anterior ainda em `'Pendente'`, ela não é afetada por este trigger (limitação conhecida do desenho atual do SPEC-089, não resolvida aqui — ver Pendências).
- **`Entregue` = fisicamente entregue**: quando a entrega vinculada (`entregas.separacao_id`) vira `'Entregue'`, os itens saem de `q_separado` e entram em `q_entregue`.
- **Idempotência**: `separacao_itens.separado boolean` (coluna que já existia, órfã desde a SPEC-072) passa a ser usada como guarda — só move pra `q_separado` uma vez por item.
- **`estornar_item_separacao` bloqueia item já `separado = true`**: depois que a peça saiu fisicamente da reserva pro chão do depósito (ou além), reverter para Reserva silenciosamente estaria errado — exigiria um fluxo de devolução física, que já existe separadamente (SPEC-015/054) e não faz parte desta SPEC.

### RPC granular proposta

```
estornar_item_separacao(
  p_separacao_item_id uuid,
  p_quantidade numeric,
  p_observacao text
) RETURNS jsonb
```

Valida: item existe, `p_quantidade > 0`, `p_quantidade <= (quantidade - quantidade_estornada)`, item não está `separado = true`. Move `q_reserva += p_quantidade`, `q_ag_separar -= p_quantidade` (mesma lógica da RPC atual, por item). Incrementa `separacao_itens.quantidade_estornada`. Se, depois desse estorno, **todos** os itens da separação estiverem com `quantidade_estornada = quantidade`, marca `separacoes.status = 'Cancelado'` e dispara o mesmo aviso ao Matheus que a RPC atual já faz (`entregas`/`entregas_pendentes`) — senão, separação continua `'Pendente'` com o restante ainda válido.

`estornar_separacao_parcial` (mantida, vira orquestradora): para cada item da separação com `quantidade - quantidade_estornada > 0`, chama `estornar_item_separacao` com a quantidade restante inteira.

## Análise de ecossistema (obrigatória)

- **Depende de**: `separacao_itens`, `separacoes`, `entregas`, `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`. Não depende de `boletos`/`projeto_parcelas`/`usuarios` além do já usado por `estornar_separacao_parcial`.
- **Afeta**: Separação Parcial (RPC nova + refator + frontend do estorno) e o banco (triggers novos). **Não** exige nenhuma mudança de código em Logística — os triggers reagem a updates que a tela já faz hoje (`entregas.status`), sem precisar publicar nada lá.
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum novo.
- **Migration antiga que contradiz o snapshot central**: nenhuma — na verdade fecha um gap que a própria SPEC-010 já tinha previsto (CHECK constraint com `'separado'`/`'entregue'` órfãos).
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim, do sistema `separacao-parcial`, e os domínios `estoque_compras.md`/`logistica.md`.

## Realizado

### 2026-08-14

- Migration `20260814_111_spec099_estorno_granular_link_separado_entregue` aplicada no Supabase real: coluna `quantidade_estornada`, RPC `estornar_item_separacao`, `estornar_separacao_parcial` refatorada, e os 2 triggers novos (`trg_sync_separado_ao_ficar_pronto`, `trg_sync_entregue_ao_finalizar_entrega`).
- Testado transacionalmente no banco (`BEGIN`/`ROLLBACK`) usando o item real de ORC-0022 (produto 9524): separar 2 → estornar 1 (parcial, separação continua `Pendente`) → estornar o restante (fecha a separação como `Cancelado`). Depois, cenário do link: `registrar_separacao_setor` → `UPDATE separacoes SET status='Pronto'` moveu `q_ag_separar→q_separado` e criou a `entrega` automaticamente (trigger já existente da SPEC-089) → `UPDATE entregas SET status='Entregue'` moveu `q_separado→q_entregue`. Tudo conferido e revertido.
- Frontend implementado em `separacao-parcial` (Skip 48801): modal de estorno reconstruído — lista os itens da separação com quantidade restante, campo de quantidade por peça, botões "Reverter tudo" e "Estornar peça(s) selecionada(s)". QA completo do Skip passou limpo. Publicado (`v0.0.25`, `ee7bda2`).
- **Testado ao vivo no navegador**, na venda ORC-0022 (a mesma que o usuário usou pra achar o bug): separou 3 unidades reais (Reserva 5→2, Ag.Separar 0→3) → estornou 1 unidade pelo modal granular (Reserva 2→3, Ag.Separar 3→2, separação continuou "Pendente" — confirmando que a outra peça/quantidade não foi tocada) → usou "Reverter tudo" nas 2 restantes (Reserva 3→5, Ag.Separar→0, separação virou "Cancelado"). Sem dado de teste residual — tudo foi feito e desfeito via ações reais do app, voltando ao estado original.

### 2026-08-14 (continuação — usuário testou o fluxo real e achou 2 bugs)

- Usuário clicou "Separar" numa venda real (ORC-0005) até completar (data de entrega preenchida, virou "Pronto") e reportou dois problemas: (1) o pedido não apareceu no sistema de Logística; (2) tentar estornar deu erro "Essa peça já foi fisicamente separada" mesmo sendo admin.
- **Causa raiz real do (1)**: nenhuma tela do Logística (`SeparacaoPage`/`useSeparacoes.ts`, `CalendarioPage`/`useCalendarData.ts`) lê a tabela `entregas`, e as duas só listam `status IN ('material_solicitado','Em separação','separado')` — o status `'Pronto'` (o que a Separação Parcial escreve) nunca esteve nessa lista. A entrega **foi criada corretamente** pelo trigger da SPEC-089 (confirmado no banco), só ficava invisível pro Matheus. Fix: `'Pronto'` adicionado aos filtros de `useSeparacoes.ts` e `useCalendarData.ts`, e ao tipo `StatusSeparacao`, no sistema Logística (Skip 24039, v0.0.86). **Testado ao vivo**: a venda "23.316 ROBERTA DEMETERCO" (a que ficou presa) passou a aparecer na tela do Matheus, dia 17/08, com os botões corretos.
- **Achado adicional, mais sério**: mesmo corrigido (1), o fluxo real do Matheus (`finalizarEntrega` em `useSeparacoes.ts`) finaliza direto em `separacoes.status = 'finalizado'` — **nunca toca a tabela `entregas`**. Isso significa que o trigger `sync_entregue_ao_finalizar_entrega` da SPEC-099 (baseado em `entregas.status = 'Entregue'`) nunca dispararia no uso real. Corrigido com um trigger novo, `sync_entregue_ao_finalizar_separacao`, em cima do ponto onde o Matheus de fato finaliza (`separacoes.status = 'finalizado'`) — mantém o trigger antigo (inofensivo, só não é o caminho real).
- **Causa raiz do (2)**: o guard "já separado" da SPEC-099 bloqueava geral, sem exceção. Usuário foi explícito: administrador deveria poder fazer isso. Fix: `estornar_item_separacao` agora libera admin/gerente mesmo com o item já `separado = true` (nesse caso retira de `q_separado` em vez de `q_ag_separar`); continua bloqueado pra todo mundo, sem exceção, se o item já estiver `entregue = true` (aí exige devolução física de verdade).
- Migration `20260814_112_fix_link_logistica_real_e_estorno_admin` aplicada no Supabase real. Testado transacionalmente: admin estornando item já separado (funcionou, retirou de `q_separado`), usuário comum tentando o mesmo (bloqueado corretamente), e o trigger novo de finalização (`q_separado`→`q_entregue` ao simular `status='finalizado'`) — todos conferidos e revertidos (`ROLLBACK`).
- A separação real da Roberta (23.316) **não foi alterada** — só passou a ficar visível; nenhuma ação foi tomada nela em nome do usuário.

### 2026-08-14 (continuação 2 — usuário perguntou se as peças aparecem vinculadas)

- Usuário perguntou se, ao criar uma separação, as peças (não só o vínculo com o projeto) aparecem no Logística. Conferido no código antes de responder: **não apareciam** — o card ativo (`SeparacaoCard.tsx`) nunca lia `separacao_itens`; existia um hook pronto pra isso (`useSeparacaoItens`), mas só usado na pasta duplicada/morta (`separação`, com cedilha) que a tela ativa não importa.
- Implementado `SeparacaoItensList.tsx` (mesmo padrão do `SeparacaoFiles.tsx` já existente) e adicionado ao painel "Detalhes" do card, listando código do produto + descrição + quantidade por peça.
- **Bug real achado no teste ao vivo, não relacionado à peças em si**: ao expandir "Detalhes" na venda real da Roberta, a tela quebrou (branco) — `separacao.numero_venda?.join(', ')` estourava porque `numero_venda` é `text` no banco para separações da Separação Parcial (guarda uma string, ex. `"ORC-0005"`), não array como o código sempre assumiu. Esse bug já existia antes desta sessão, só nunca tinha sido exercitado porque essas separações nunca apareciam. Corrigido com checagem `Array.isArray` (mesmo padrão que já existia, sem uso, na pasta duplicada com cedilha).
- Publicado Skip 24039 (v0.0.87 peças, v0.0.88 fix do crash). Testado ao vivo na venda real: expandiu sem quebrar, mostrou as 3 peças reais corretas (10009×7, 11461×3, 12395×3), batendo com o banco.

## Pendências

- [ ] **P-1**: Se uma venda tiver mais de uma separação parcial em aberto (`'Pendente'`) e só a última virar `'Pronto'` (por ser a que zerou a reserva), as separações anteriores da mesma venda não têm seu próprio `'Pronto'` disparado — os itens delas só migram pra `q_separado` se/quando algo mudar o status delas individualmente. Não resolvido nesta SPEC (limitação herdada da SPEC-089); documentar e avaliar se vira SPEC própria depois que houver caso real.
- [ ] **P-2**: `nosso_numero` (`boletos`) — Vinícius decidiu remover o campo (reunião 11/08) mas não definiu o substituto. É a chave que `processar_retorno_bancario` (SPEC-008) usa pra casar o retorno do banco com o boleto certo (tem `UNIQUE constraint`). Decisão que falta é de negócio: qual vai ser a nova chave de conciliação (ex.: `boletos.id`, outro número sequencial, ou manter algo no formato que o Bradesco exige no arquivo de remessa)? Sem essa resposta, remover o campo quebra a baixa automática de boletos. Bug relacionado já identificado e não corrigido de propósito: `aprovar_orcamento_financeiro` gera `nosso_numero` com prefixo duplicado ("ORC-ORC0022-P1") em 14 boletos, todos ainda `pendente_registro` — consertar o formato de um campo que vai ser removido seria trabalho descartável.
