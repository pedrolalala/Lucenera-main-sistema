---
titulo: "SPEC-071 — Tipo de Operação Devolução no Fluxo de Orçamento"
status: implementado (homologação manual pendente)
data_ultima_modificacao: 2026-08-07
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1)) — mudança principal
  - Compras (compras-lucenera-3o23t98ee) — nenhuma mudança de código nova; formaliza que a aba "Devolução" da SPEC-054 não deve ser publicada/finalizada como estava desenhada
  - Supabase (banco central) — coluna nova em `orcamentos`/`orcamento_itens`, extensão de `aprovar_orcamento_financeiro`
dependencias:
  - SPEC-010 (estoque_saldos_projeto_item / vw_estoque_saldos_projeto_item)
  - SPEC-012 (vw_necessidade_compra / entrega futura)
  - SPEC-015 (RPC `registrar_devolucao_projeto_item`, aplicada — base desta SPEC)
  - SPEC-016/017/051 (contrato de status do orçamento: rascunho → enviado_cliente → Aprovação da Equipe → Aprovação Financeira → Orçamento Aprovado)
  - SPEC-040 (`projeto_itens.orcamento_item_id`/`l_fixo`)
  - SPEC-054 (RPC `registrar_devolucao_projeto_item_setor` e tela em Compras — redigidas, não aplicadas; escopo de frontend superado por esta SPEC)
  - SPEC-069 (RBAC — confirma que `equipe_projetos` já é "editar sem cadastrar" em Orçamentos)
---

# SPEC-071 — Tipo de Operação Devolução no Fluxo de Orçamento

> Origem: reunião `02-Reunioes/16. Lucenera (vinicius) - 07.08.2026. Contexto devolução e separação parcial/Reunião.01`, 2026-08-07. Substitui integralmente a versão anterior desta SPEC ("Mover Interface de Devolução de Estoque de Compras para Orçamentos"), cujo desenho (aba de devolução dentro do orçamento já aprovado, chamando `registrar_devolucao_projeto_item_setor`) partia de um entendimento incorreto do problema, confirmado como erro pelo próprio usuário. **Correção explícita**: a "Devolução de Compra" (devolver material ao fornecedor, fluxo da Débora) é uma coisa totalmente diferente do que esta SPEC trata — é o item "Devolução de Compra" da tabela de tipos de operação abaixo, fora de escopo aqui.

## Checklist de Ação

### Banco

- [x] Adicionado `orcamentos.natureza_operacao text NOT NULL DEFAULT 'venda' CHECK (natureza_operacao IN ('venda', 'devolucao'))` — **aplicado no Supabase real** (2026-08-07), migration `20260807_088_spec071_natureza_operacao_devolucao`. Os 26 orçamentos existentes ficaram retrocompatibilizados como `'venda'` automaticamente.
- [x] Adicionado `orcamento_itens.projeto_item_origem_id uuid REFERENCES projeto_itens(id)` — **aplicado**.
- [x] `aprovar_orcamento_financeiro` estendida com branch por `natureza_operacao` — **aplicado**. Quando `devolucao`: valida que todo item tem `projeto_item_origem_id`, chama `registrar_devolucao_projeto_item` por item (RPC da SPEC-015, sem alteração), gera `projeto_parcelas`/`boletos` com valor **negativo**, prefixo `DEV-` no `nosso_numero` do boleto, tipo `'Nota de Crédito'`. Ramo de venda preservado sem nenhuma alteração de lógica (mesmo texto original, só realocado para depois do `IF` de devolução).
- [x] `CHECK (valor > 0)` em `projeto_parcelas` trocado por `CHECK (valor <> 0)` (permite negativo, continua proibindo zero) — **aplicado**. Confirmado que `boletos` não tinha constraint de positividade (nenhuma alteração necessária lá).

### Frontend — Orçamentos (`gestao-financeira-clone-544cb (1)`)

- [x] Confirmado no Skip (projectId `32554`) que o working tree estava em sync (`clean` exceto `.skip.config.json`) antes e durante toda a edição — nenhum drift detectado.
- [x] Campo "Tipo de Operação" (Venda / Devolução) na criação de um novo orçamento — toggle de dois botões em `BudgetFormPage.tsx`, controla `natureza_operacao` (default "Venda"), travado (`disabled`) quando `isEditing`. Comportamento de orçamento de venda existente preservado byte a byte.
- [x] Quando `natureza_operacao = 'devolucao'`: novo serviço `services/devolucoesService.ts` (`getVendasOrigemParaDevolucao`) consulta `vw_estoque_saldos_projeto_item` filtrada por `cliente_id` (cruzando todos os projetos do cliente — P-2) + `status_operacional = 'ativo'`, calcula `quantidade_disponivel = q_reserva + q_entrega_futura + q_entregue` e complementa com `preco_unitario`/`desconto`/`l_fixo` via `projeto_itens` (a view não expõe esses campos). Novo `components/budgets/DevolucaoItemSearchModal.tsx` lista as vendas de origem e substitui o `ProductSearchModal` quando `natureza_operacao = 'devolucao'` (nos dois pontos de entrada: header do card "Itens do Orçamento" e estado vazio).
- [x] Validação client-side: `superRefine` do schema Zod exige `projeto_item_origem_id` em todo item quando `natureza_operacao = 'devolucao'`; a quantidade por linha é limitada no próprio modal ao `quantidade_disponivel` da venda escolhida (input `max`). A validação autoritativa continua sendo a RPC `registrar_devolucao_projeto_item`.
- [x] Fila "Aprovação Financeira" não precisou de alteração — orçamentos de devolução usam o mesmo campo `status`, sem código extra.
- [x] Badge "Devolução" (âmbar, ícone `Undo2`) adicionado em `BudgetTableRow.tsx`, acima do badge de status, quando `budget.natureza_operacao === 'devolucao'`.

### Frontend — Compras (`compras-lucenera-3o23t98ee`)

- [ ] Não prosseguir com a implementação/publicação da aba "Devolução" desenhada pela SPEC-054 (`DevolucaoEstoqueTab.tsx`/`ModalDevolucaoItem.tsx`/`services/devolucoes.ts` chamando `registrar_devolucao_projeto_item_setor`) como estava planejada — confirmado que ela nunca chegou a ser aplicada em produção (RPC "redigida, não aplicada", ver `supabase/db/domains/estoque_compras.md`), então não há nada para remover, só reorientar o backlog: marcar o escopo de frontend da SPEC-054 como superado por esta SPEC.
- [ ] Nenhuma alteração de código necessária em Compras por esta SPEC.

### Passos manuais do usuário

- [x] Decisão P-1: boleto/parcela negativa — resolvido em 2026-08-07.
- [x] Decisão P-2: busca por todos os projetos do cliente — resolvido em 2026-08-07.
- [x] Decisão P-3: mesmo pipeline completo de aprovação (equipe + cliente + financeiro) — resolvido em 2026-08-07.
- [ ] Confirmar quem pode registrar/aprovar uma devolução (papel/permissão) — herdado da SPEC-015/054, nunca resolvido; hoje a RPC `registrar_devolucao_projeto_item` está aberta a qualquer `authenticated`.
- [ ] Homologação manual no navegador do golden path completo (criar orçamento tipo Devolução → buscar venda de origem → salvar → aprovar → conferir `estoque_saldos_projeto_item`) — frontend publicado, mas ainda não testado por um humano no navegador.
- [x] Publicado via Skip (`projectId 32554`, versão `0.0.304`/`1f10abf`, QA completo: setup/staticAnalysis/build/integrations/test todos `ok`) — 2026-08-07.
- [ ] Atualizar `supabase/db/domains/orcamentos.md` e `supabase/db/domains/estoque_compras.md` registrando esta mudança de entendimento e o novo desenho.

## Objetivo

Formalizar "Devolução" como uma **natureza de operação dentro do fluxo normal de orçamento** — não uma tela separada, não uma ação dentro do orçamento de venda já aprovado. Um orçamento de devolução tem a mesma estrutura de um orçamento de venda (mesmo cliente, mesma empresa, mesmo arquiteto vinculado), mas cada item aponta para uma venda de origem específica e, ao ser aprovado financeiramente, devolve estoque físico e reduz necessidade de compra, em vez de reservar estoque e gerar cobrança positiva.

## Decisões aprovadas

- **P-1 (2026-08-07)**: o crédito financeiro da devolução vira boleto/parcela **negativa** — exige alterar `CHECK (valor > 0)` em `projeto_parcelas` (e o equivalente em `boletos`, se houver) para aceitar valores negativos quando a origem é uma devolução.
- **P-2 (2026-08-07)**: a busca de "vendas anteriores desse produto para este cliente" olha **todos os projetos do cliente** (`cliente_id`, não restrita a `projeto_id`) — cliente pode ter comprado o mesmo produto em obras diferentes.
- **P-3 (2026-08-07)**: o orçamento de devolução percorre o **mesmo pipeline completo** de uma venda (`rascunho → enviado_cliente → Aprovação da Equipe → Aprovação Financeira → Orçamento Aprovado`), incluindo aprovação do cliente por link.
- Devolução não é uma tela nova nem uma aba dentro do orçamento de venda já aprovado — é um orçamento próprio, com `natureza_operacao = 'devolucao'`, seguindo o mesmo pipeline de status de qualquer orçamento (ver P-3).
- "Devolução de Compra" (devolver ao fornecedor) é um tipo de operação diferente, fora de escopo desta SPEC — ver tabela de referência abaixo.
- A busca de "vendas anteriores desse produto para este cliente" usa a view já existente `vw_estoque_saldos_projeto_item` (SPEC-010), sem necessidade de view nova.
- O efeito de estoque da devolução reaproveita a RPC já aplicada `registrar_devolucao_projeto_item` (SPEC-015, cascata `q_entrega_futura → q_reserva → q_entregue`) — não a variante manual por setor da SPEC-054, que nunca foi aplicada e não é necessária para este fluxo (o usuário, na gravação, não escolhe setor manualmente, só quantidade e venda de origem).
- Escopo desta SPEC: implementar de verdade apenas Venda (já existe, intocada) e Devolução. Os demais tipos de operação descritos na reunião ficam documentados como referência/futuro (ver Anexo), sem trabalho de implementação nesta SPEC.
- Confirmação (não é decisão nova): a regra "equipe não pode adicionar peça" já está coberta pela SPEC-069 (`equipe_projetos` = "Editar sem cadastrar" em Orçamentos) — não é pendência, é validação de que o RBAC já implementado está alinhado com o que Vinícius espera.

## Definição da SPEC

### Estado atual confirmado no banco

- `orcamentos` (`supabase/db/current/01_schema_full.sql`, linha 5334) não tem nenhum campo de tipo/natureza de operação hoje.
- `aprovar_orcamento_financeiro` (`03_functions.sql`, linha 389) sempre: insere `projeto_itens` a partir de `orcamento_itens`; calcula parcelas positivas em `projeto_parcelas`; cria `boletos` com `tipo_operacao = 'CR'`; incrementa `estoque_itens.quantidade_reservada`. Não existe nenhum branch condicional — qualquer orçamento aprovado hoje é tratado como venda.
- `vw_estoque_saldos_projeto_item` (`05_views.sql`, linha 279) já expõe, por `projeto_item_id`: `cliente_id`, `produto_id`, `orcamento_numero`, `q_venda`, `q_reserva`, `q_entrega_futura`, `q_entregue`, `q_devolvida`, `status_operacional` — exatamente os dados necessários para "puxar tudo que tem de venda para esse cliente desse item" e calcular quanto ainda pode ser devolvido de cada venda (`q_reserva + q_entrega_futura + q_entregue`, que já desconta devoluções anteriores porque a RPC de devolução reduz esses três campos diretamente).
- `registrar_devolucao_projeto_item(p_projeto_item_id, p_quantidade, p_motivo)` (SPEC-015) está aplicada e testada em produção desde 07/07/2026; reduz saldos na ordem `q_entrega_futura → q_reserva → q_entregue`, nunca altera `projeto_itens.quantidade` (Q. Venda), aumenta `q_devolvida`, e reduz `estoque_itens.quantidade_reservada` pela parte que saiu de saldo aberto.
- `registrar_devolucao_projeto_item_setor` (SPEC-054, variante manual por setor) **não está aplicada** — confirmado por ausência no `supabase/db/current/`, consistente com o que `estoque_compras.md` já registrava ("redigida, não aplicada"). A SPEC-071 anterior assumia essa RPC como pronta; essa suposição estava incorreta.
- `projeto_parcelas.valor` tem `CONSTRAINT projeto_parcelas_valor_check CHECK (valor > 0)` — bloqueia literalmente qualquer tentativa de representar crédito como parcela negativa sem alteração de schema. Achado relevante para a Pendência P-1.
- O ENUM `CREATE TYPE public.tipo_operacao AS ENUM ('CR', 'CP')` já existe no schema (linha 268), sem nenhuma coluna usando esse tipo hoje (`boletos.tipo_operacao` e o futuro `notas_fiscais.tipo_operacao` da SPEC-066 são `text`, não o enum) — motivo adicional para não reaproveitar o nome `tipo_operacao` na coluna nova desta SPEC.

### Achado técnico herdado da versão anterior desta SPEC (ainda válido)

`orcamento_itens` (rascunho, antes da aprovação) e `projeto_itens` (pós-aprovação, com saldo operacional) são granularidades diferentes — `BudgetFormPage.tsx` só edita `orcamento_itens`. A devolução, tanto na modelagem da SPEC-015 quanto no fluxo desta SPEC, opera sobre `projeto_itens` (a venda de origem já aprovada), nunca sobre `orcamento_itens` de outro orçamento. Isso é coerente com o novo desenho: o orçamento de devolução tem seus **próprios** `orcamento_itens` (linhas da devolução em si), cada um apontando via `projeto_item_origem_id` para o `projeto_itens` da venda de origem.

### Fluxo proposto (espelha a gravação, [05:44]-[21:22])

1. Usuário cria um novo orçamento e seleciona "Tipo de Operação: Devolução" (`natureza_operacao = 'devolucao'`).
2. Preenche cliente, empresa, arquiteto — mesma estrutura de um orçamento de venda (debita CRT do arquiteto também, sem mudança de comportamento aqui).
3. Ao adicionar um item por código de produto, o sistema busca em `vw_estoque_saldos_projeto_item` filtrada por `cliente_id` (todos os projetos do cliente, P-2) e lista as vendas anteriores daquele produto para aquele cliente, com quantidade ainda disponível para devolução em cada uma, mostrando de qual projeto/orçamento cada uma veio.
4. Usuário escolhe a venda de origem e a quantidade a devolver; se exceder o disponível daquela venda, precisa dividir em mais de uma linha (cada uma com seu `projeto_item_origem_id`).
5. Orçamento percorre o mesmo pipeline completo de uma venda (rascunho → enviado ao cliente → aprovação da equipe → aprovação financeira → aprovado — P-3), incluindo o link de aprovação do cliente.
6. Ao chegar em `Aprovação Financeira`, aparece na mesma fila "Financeiro > Aprovar Orçamento" que já existe hoje.
7. Ao aprovar financeiramente: para cada item, chama `registrar_devolucao_projeto_item` contra o `projeto_item_origem_id`; gera `projeto_parcelas`/`boletos` com valor **negativo** (P-1); não cria `estoque_itens.quantidade_reservada` positivo nem parcelas/boletos de cobrança normais.
8. Efeito de compra: se a devolução reduzir `q_entrega_futura` de um item que já teve pedido de compra colocado e não pode mais ser cancelado, o material extra fica disponível em estoque quando chegar — a RPC de devolução não força cancelamento de pedido já feito (mesma regra já coberta por `vw_necessidade_compra`, que reage à redução de `q_entrega_futura`, e por SPEC-060 para cancelamento manual quando aplicável). Exemplo numérico da própria gravação ([18:28]-[20:48]): comprou 10, devolução de 5 depois do pedido já feito ao fornecedor → sobra 5 em estoque ao chegar, sem forçar cancelamento.

### Anexo de referência — outros tipos de operação (fora de escopo nesta SPEC)

Lista completa levantada na gravação, para não perder a informação. Nenhum destes será implementado por esta SPEC.

| Tipo de Operação | Move estoque? | Move financeiro? | Observação |
|---|---|---|---|
| Venda | Sim | Sim (fatura) | Já existe, intocado por esta SPEC |
| Devolução | Sim (volta) | Sim (crédito) | **Escopo desta SPEC** |
| Casa Cor Saída | Sim | Não | Material emprestado para evento |
| Casa Cor Entrada | Sim | Não | Não pode existir sem uma Casa Cor Saída antes |
| Saída p/ Industrialização | Não | Não | Gera NF de remessa para pintura/terceiro; requer "Nota de Retorno de Industrialização" depois |
| Bonificação | Sim | Não | |
| Uso-Consumo | Sim | Não | Ex.: trocar lâmpada queimada internamente |
| Descarte | Sim | Não | |
| Remessa p/ Conserto | Não | Não | Não move estoque pois já atendeu o cliente; devolução posterior |
| Devolução em Garantia | Não | Não | Similar a Remessa p/ Conserto |
| Devolução de Compra | — | — | Devolver ao fornecedor (fluxo da Débora) — **não é o assunto desta SPEC** |
| Remessa p/ Transporte | Não | Não | NF separada da NF de venda, para entrega parcial futura (a NF de venda "não tem validade" para transporte tempos depois) |
| Transferência | — | Não | Pegar peça reservada de um cliente emprestada para outro — ver nota abaixo |
| Garantia | — | — | Pouco detalhado na gravação |
| Outras Entradas/Saídas | — | — | Usado raramente — ajuste de migração/balanço, baixa prioridade |

### Nota — Separação Parcial (recomendação de SPEC própria, não desenhada aqui)

Detalhada em duas gravações: `Reunião.01` ([15:19]-[24:00], visão geral) e `Reunião.03` (explicação completa, dedicada só a este assunto — `Reunião.04` ainda está vazia no momento desta atualização, pode receber mais conteúdo depois). **Não é devolução** — é a visualização de uma venda específica, caminho "Comercial > Venda > Parcial" no Connect, mostrando por item: código interno, referência, descrição, classificação (L, vinculado ao projeto), e uma linha de colunas de quantidade por status.

**Regra de negócio detalhada (Reunião.03), coluna por coluna:**

- **Quantidade da venda**: fixa desde a criação da venda, **nunca se altera** independente do que acontecer depois (separação, transferência, devolução).
- **Ao efetivar a venda**, o sistema automaticamente distribui a quantidade vendida entre `reserva` (o que já tem em estoque físico disponível) e `entrega futura` (a diferença, o que falta comprar) — ex.: vendeu 40, tem 10 em estoque → reserva=10, entrega_futura=30.
- **Entrega futura**: material que a empresa pode até ter fisicamente, mas já está comprometido com outro cliente — não está disponível para ESTE cliente.
- **Ao entrar a compra** (nota de entrada vinculada ao cliente/venda/L específico), a quantidade que estava em entrega futura (nunca mais do que o que chegou) migra para reserva.
- **A Separar / Aguardando Separar / Separado / Entregue**: só é possível solicitar separação do que está em `reserva` (nunca de `entrega futura`). O usuário informa a quantidade a separar → gera uma "lista de entrega" → status vira `aguardando separar` → é enviada para o Matheus no aplicativo de separação → ele separa fisicamente e "baixa" a lista → status vira `separado` → depois da entrega física, nova baixa → status vira `entregue`. A lista de entrega registra: quem solicitou a separação, data da solicitação, quem fez a entrega, data da entrega, quem recebeu o material — tudo isso precisa ser visível/auditável.
- **Transferido**: só é possível transferir o que está em `reserva`. Ex.: cliente A tem 40 em reserva, cliente B vendeu 10 do mesmo produto mas está em entrega futura (sem estoque disponível) e não pode esperar a compra chegar — transferir 10 de A para B: A fica com reserva=30, entrega_futura=10 (perdeu fisicamente aquelas 10 unidades) e um registro informativo/histórico de `transferido=10`; B sai de entrega_futura e ganha reserva=10. Regra dura: nunca é possível transferir mais do que a quantidade total da própria venda.
- **Quantidade devolvida**: contador do total já devolvido daquele item, somado de qualquer status de origem (entrega futura, reserva ou entregue) — Vinícius **deferiu o detalhamento da regra de devolução para outra gravação** ("vou gravar a devolução em outro vídeo, melhor"); não tratar como definição fechada, é só o placeholder da coluna.

**Achado técnico importante (2026-08-07, verificado direto no Supabase real)**: o modelo de dados que Vinícius descreveu **já existe quase 1:1** no schema — `estoque_saldos_projeto_item` (SPEC-010) tem exatamente `q_reserva`, `q_entrega_futura`, `q_ag_separar`, `q_separado`, `q_entregue`, `q_devolvida`, `q_transferida_saida`, `status_operacional` (só falta uma coluna para a quantidade total vendida em si, que já existe em `projeto_itens.quantidade`, referenciada por `projeto_item_id`). Além disso, **o "aplicativo que o Pedro fez" para o Matheus provavelmente já é o sistema de Logística** (`lucenera-logistics-b7cd1`) — confirmado que já existem as tabelas `separacoes` (com `responsavel_id`, `solicitante`, `numero_venda`, `data_inicio_separacao`, `status`), `separacao_itens` (`produto_id`, `quantidade`, `separado` boolean) e `entregas` (`entregador_id`, `data_entrega`, `status`, `comprovante_url`, `avaliacao`) — que batem estruturalmente com a "lista de entrega" descrita (solicitante, datas, quem entregou, comprovante). **Ou seja, isso não é uma feature para construir do zero — é, muito provavelmente, uma tela nova que consulta/junta dados que já existem em dois sistemas diferentes** (`estoque_saldos_projeto_item` em Orçamentos/Compras + `separacoes`/`separacao_itens`/`entregas` em Logística), hoje sem nenhuma visualização unificada por venda. Confirmar essa hipótese de ligação (`separacoes.numero_venda`/`projeto_id` ↔ `estoque_saldos_projeto_item`/`projeto_itens`) é o primeiro passo de qualquer SPEC dedicada a isso.

**Recomendação**: SPEC própria (não cabe dentro desta SPEC de devolução), mas com escopo de investigação já bem mais estreito do que se imaginava — provavelmente é trabalho de "visualização/integração", não de "construir do zero".

### Nota — Transferência entre clientes (frontend pendente, backend já pronto)

Vinícius reclamou que o sistema atual não registra quem pegou material reservado de qual cliente para qual outro cliente ("o sistema não registra de quem pegou para quem foi", [26:35]). Confirmado que isso **já está resolvido no backend**: `transferencias_estoque`, `solicitar_transferencia_estoque`, `aprovar_transferencia_estoque`, `cancelar_transferencia_estoque` e `vw_transferencias_estoque` existem no Supabase real (ver SPEC-011, arquivo `03-Projeto/Planos de Ação/SPECs/SPEC-011_Transferencia_Reservas_Entre_Clientes.md`, todos os itens do checklist marcados como feitos) e já registram produto, quantidade, origem, destino, solicitante, aprovador e timestamps — exatamente o que ele descreveu como faltando. **Falta confirmar se existe frontend consumindo isso** em algum dos 8 sistemas (não verificado nesta SPEC). **Recomendação**: SPEC própria para ativar/construir o frontend, caso a checagem confirme que não existe.

### Nota de confirmação — permissão da equipe (SPEC-069)

Vinícius confirmou que "o pessoal de equipe não pode adicionar peça, já é uma regra que eu já coloquei" ([29:23]-[29:39]). Isso bate exatamente com a matriz de permissões já implementada (SPEC-069): o papel `equipe_projetos` tem "Editar sem cadastrar" em Cadastro/Orçamentos. Não é uma pendência — é confirmação de que o RBAC já existente está alinhado com a expectativa dele.

## Análise de ecossistema (obrigatória)

- **Depende de**: `orcamentos`, `orcamento_itens`, `projetos`, `projeto_itens`, `contatos` (cliente/arquiteto), `usuarios` (permissão de aprovação), `estoque_saldos_projeto_item`/`devolucoes_estoque`. Indiretamente, `boletos`/`projeto_parcelas` para o efeito financeiro (Pendência P-1) — não usa `venda_id` em nenhum ponto, consistente com o invariante do ecossistema.
- **Afeta**: Orçamentos (mudança principal — novo campo, novo fluxo de busca, extensão da RPC de aprovação) e, por reorientação de backlog, Compras (cancela o plano de publicar a aba de devolução da SPEC-054). Toca Financeiro apenas na extensão da aprovação (mesma RPC, mesmo botão "Aprovar Orçamento"). Não afeta CRM, Cadastro, Logística ou RH diretamente nesta rodada (a nota de Separação Parcial toca Logística, mas como SPEC futura).
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum novo. `vw_estoque_saldos_projeto_item` já deriva `cliente_id`/`orcamento_numero`/saldos por `JOIN`; a coluna nova `orcamento_itens.projeto_item_origem_id` é uma referência (FK), não uma cópia de dado.
- **Migration antiga que contradiz o snapshot central**: confirmado que `registrar_devolucao_projeto_item_setor` (SPEC-054) está redigida mas não aplicada — a SPEC-071 anterior tratava essa RPC como pronta, o que era incorreto. Nenhuma outra divergência nova encontrada nesta análise.
- **Exige atualizar `AI_DB_CONTEXT.md`**: não há `AI_DB_CONTEXT.md` específico para este caso, mas exige atualizar `supabase/db/domains/orcamentos.md` (nova natureza de operação, extensão da RPC de aprovação) e `supabase/db/domains/estoque_compras.md` (reorientação do escopo de frontend da SPEC-054).
- **Padrão de acesso a dados já usado pelo sistema afetado**: Orçamentos usa `services/*.ts` com chamadas diretas via cliente `supabase` e Zustand (`useBudgetStore`) para o estado da lista/formulário principal, com o contrato de status centralizado em `src/lib/budget-status.ts` (`APPROVED_STATUSES`, `isFinancialApprovalStatus`, etc.). A implementação desta SPEC deve seguir esse mesmo padrão — não introduzir estado/store novo nem um padrão de acesso a dados diferente.

## Critérios de aceite

(Dependem das Decisões P-1/P-2/P-3 estarem resolvidas antes de serem verificáveis.)

- Um orçamento com `natureza_operacao = 'devolucao'` não cria `projeto_itens`/`estoque_itens.quantidade_reservada` positivos ao ser aprovado — em vez disso, chama `registrar_devolucao_projeto_item` para cada item, reduzindo saldos na ordem `q_entrega_futura → q_reserva → q_entregue`.
- Tentar devolver mais do que a quantidade disponível de uma venda de origem específica é bloqueado (client-side e pela RPC).
- Um orçamento de venda comum (`natureza_operacao = 'venda'`, valor default) continua se comportando exatamente como hoje — nenhuma regressão no fluxo de venda.
- A busca de "vendas anteriores" retorna corretamente os `projeto_itens` do cliente/produto informados, com a quantidade ainda disponível para devolução calculada a partir de `vw_estoque_saldos_projeto_item`.
- Lint e build passam em Orçamentos após a mudança.

## Testes obrigatórios

Sem suíte automatizada (nenhum dos 8 sistemas tem testes reais). Verificação manual:

- SQL de conferência: criar um orçamento de devolução sintético em transação com `ROLLBACK`, repetindo o exemplo já validado na SPEC-015 (`q_entrega_futura=10, q_reserva=10, q_entregue=20`, devolução de 20 em uma linha) e conferindo `estoque_saldos_projeto_item` antes/depois.
- Navegador: golden path completo (criar orçamento tipo Devolução → buscar produto → escolher venda de origem → salvar como rascunho → avançar até Aprovação Financeira → aprovar → conferir saldo atualizado e o efeito financeiro definido pela P-1).
- Confirmar que um orçamento de venda comum, criado e aprovado no mesmo teste, não sofre nenhuma alteração de comportamento.

## Realizado

### 2026-08-07

- Backend completo aplicado no Supabase real (migration `20260807_088_spec071_natureza_operacao_devolucao`): `orcamentos.natureza_operacao`, `orcamento_itens.projeto_item_origem_id`, `aprovar_orcamento_financeiro` com branch de devolução, `projeto_parcelas_valor_check` permitindo negativo. Verificado: 26 orçamentos existentes retrocompatibilizados como `'venda'`.
- Segunda migration (`20260807_089_spec071_replace_orcamento_itens_origem`) aplicada no Supabase real: `replace_orcamento_itens` (RPC chamada toda vez que um orçamento existente é salvo) agora também persiste `projeto_item_origem_id` — sem isso, editar um orçamento de devolução já criado perderia o vínculo com a venda de origem.
- Frontend implementado e publicado: toggle "Tipo de Operação" em `BudgetFormPage.tsx`, novo `services/devolucoesService.ts` + `components/budgets/DevolucaoItemSearchModal.tsx` (busca de venda de origem via `vw_estoque_saldos_projeto_item` + `projeto_itens`), `useBudgetStore.ts` estendido (`Budget.natureza_operacao`, `BudgetItem.projeto_item_origem_id`, `fetchBudgets`/`addBudget`/`updateBudget` propagando o campo), badge "Devolução" em `BudgetTableRow.tsx`. Publicado no Skip (projectId `32554`, versão `0.0.304`/`1f10abf`), QA completo (setup/staticAnalysis/build/integrations/test) todos `ok`.
- Commitado no git local (`10736dd` backend; frontend a commitar nesta sessão), sem push ainda.

## Pendências

- [x] ~~P-1~~ resolvido: crédito vira parcela/boleto negativo.
- [x] ~~P-2~~ resolvido: busca cruza todos os projetos do cliente.
- [x] ~~P-3~~ resolvido: mesmo pipeline completo de aprovação.
- [ ] Definir quem pode registrar/aprovar uma devolução (papel/permissão) — pendência herdada da SPEC-015/054, nunca resolvida; hoje a RPC está aberta a qualquer `authenticated`.
- [ ] Confirmar se existe frontend consumindo `transferencias_estoque`/`solicitar_transferencia_estoque` em algum dos 8 sistemas (backend pronto desde a SPEC-011); se não existir, abrir SPEC própria.
- [ ] Avaliar formalmente se "Separação Parcial" vira SPEC própria (recomendação desta SPEC, não decisão fechada) — achado 2026-08-07: o modelo de dados já existe quase inteiro em `estoque_saldos_projeto_item` (Orçamentos/Compras) e em `separacoes`/`separacao_itens`/`entregas` (Logística); provável que seja SPEC de integração/visualização, não de construção do zero. `Reunião.04` (mesma pasta) ainda está vazia — pode receber mais contexto depois.
- [ ] Confirmar no Skip (projectId 32554) que o submodule local de Orçamentos está de fato em sync com produção antes de iniciar a implementação.
