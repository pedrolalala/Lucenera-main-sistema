---
titulo: "SPEC-323 — Central 18/11: entrada de NF avulsa com estoque (caso Flos), devolução presa na Aprovação Financeira e fatura de produção no Contas a Pagar"
status: pendente
data_ultima_modificacao: 2026-11-18
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal, Pedido avulso, busca de produto
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — Aprovação Financeira, fluxo de devolução
  - Contas a Pagar / a Receber (04-Sistemas/retorno-bancario-bradesco-5392a) — só verificação
  - Banco (notas_fiscais_compra, estoque_itens, orcamentos, financeiro_titulos)
---

# SPEC-323 — Central 18/11: entrada de NF avulsa com estoque (caso Flos), devolução presa na Aprovação Financeira e fatura de produção no Contas a Pagar

> Triagem da Central de Solicitações feita em 18/11/2026, em ordem de urgência. Esta SPEC reúne o que é bug/ajuste novo. O que já tem SPEC fica registrado na seção "Fora desta SPEC".

## Checklist de Ação

### A. Entrada de NF para peça com fornecedor diferente do cadastro (caso Flos SPA, peça 12052) — pedido da Debora, 18/11

- [x] A1. `buscarProdutosParaEntrada` (`services/notas-fiscais-compra.ts`) passa a achar também por `codigo_produto` (digitar `12052` acha a peça). Aplicar a mesma busca nos demais seletores de peça de Compras (Pedido avulso) que hoje só olham nome e referência.
- [x] A2. Garantir que nenhuma busca de peça em Compras filtre pelo fornecedor principal (`produtos.fornecedor_principal_id`): a nota ou o pedido pode ser de QUALQUER fornecedor, independente do fornecedor do cadastro da peça.
- [x] A3. (feito 18/11: RPC `registrar_entrada_nota_avulsa`, migration 387 aplicada, Compras no ar) Entrada avulsa com peça: campo **Quantidade** obrigatório quando houver peça; ao registrar, soma ao estoque geral (`estoque_itens`) e marca `estoque_somado_em`, reaproveitando a regra da entrada por pedido (`registrar_entrada_nota_compra`), sem duplicar a lógica no front.
- [ ] A4. (NÃO feito: a nota avulsa NÃO abre Contas a Pagar; a Flos já está paga/lançada na Connect) Decidir com o usuário (ver Decisões) se a nota avulsa gera Contas a Pagar; implementar conforme a decisão.
- [x] A5. (387 aplicada; corrige também o cancelamento de nota avulsa, que quebrava) Migration (se A3 exigir função nova): `supabase/db/migrations/20261118_NNN_spec323_entrada_nf_avulsa_estoque/` com up, rollback e dry_run (sem COMMIT embutido no dry_run).
- [ ] A6. Atualizar `04-Sistemas/compras-lucenera-3o23t98ee/supabase/AI_DB_CONTEXT.md` se houver função nova.

### B. Devolução já efetivada que continua na Aprovação Financeira (ORC-0071) — pedido da Caroline, 16/11

- [x] B1. Lido o gatilho `trg_financeiro_ponte_devolucao`: o crédito da devolução é criado quando a parcela negativa do orçamento nasce (envio ao cliente), NÃO na aprovação financeira. Logo, ORC-0071 com título no financeiro e ainda na fila é o comportamento previsto: falta alguém aprovar na Aprovação Financeira. Hipótese anterior (bug de status) descartada por ora.
- [ ] B2. Confirmar com a Caroline se ela consegue aprovar o ORC-0071 na Aprovação Financeira (acesso financeiro, SPEC-321 parte 2). Se der erro ao aprovar, corrigir a causa; se aprovar normal, fechar a solicitação. Opcional: na fila, indicar que a devolução já tem crédito lançado.
- [ ] B3. Não mudar o status do ORC-0071 por UPDATE: aprovar dispara número de venda, recebimento e estoque. A aprovação é da Caroline/financeiro pelo fluxo normal; só mexer no banco se a aprovação falhar e com "pode" do usuário.
- [ ] B4. Conferir se outras devoluções já aprovadas ficaram no mesmo estado (consulta: orçamentos em "Aprovação Financeira" com título não cancelado em `financeiro_titulos`). Em 18/11 só o ORC-0071 aparece.

### C. Fatura de entrada de produção aparecendo no Contas a Pagar — pedido da Debora, 17/11

- [ ] C1. Obter o print/número do documento que a Debora viu (não achei, em 18/11, título a pagar de produção nem entrada de NF em 17/11; só o adiantamento FOCO METALLO de 13/11, R$ 864,41).
- [ ] C2. Descobrir a origem do título (`origem_tipo`, `pedido_compra_id`, `nota_fiscal_compra_id`) e por que a entrada de produção o gerou.
- [ ] C3. Cancelar o título indevido pelo fluxo normal de cancelamento (com motivo), com "pode" do usuário.
- [ ] C4. Se a causa for regra (entrada de produção sempre cria título), decidir e corrigir para não repetir.

### D. Acordo do Caio Medici Madureira — pedido da Caroline, 17/11

- [ ] D1. Pedir à Caroline para repetir o acordo e mandar print da mensagem e das parcelas marcadas. Em 18/11 os dados estão corretos: 1 cadastro (código 1884), 7 parcelas abertas com mesmo `contato_id`, empresa FOCO ILUMINACAO, perfil ribeirao, natureza receber, total 35.808,30.
- [ ] D2. Se reproduzir, corrigir a checagem de `ConsultarDuplicatas.tsx` (`contato_id ?? nome_pagador`) ou a trava de `financeiro_criar_acordo`; senão encerrar a solicitação.

### E. Verificar e avisar (sem implementar)

- [ ] E1. Venda 8527 / pedido de compra 2013: confirmar que o material entra sem vínculo no disponível quando a Debora der a entrada da NF (SPEC-321 e 321 parte 2 já soltam o destino) — solicitação "Produtos vinculados à venda que foi estornada".
- [ ] E2. Confirmar com a Caroline que a permissão de estornar/excluir venda foi atendida pela SPEC-321 e 321 parte 2, e fechar a solicitação.
- [ ] E3. Atualizar o status na Central: SPEC-316 (vários fornecedores no pedido) → concluído; vincular SPEC-308 à solicitação "Produtos duplicados – preços revenda". Escrita em produção só com "pode".

### Passos manuais do usuário

- [ ] Responder as decisões abaixo (quantidade do 12052, Contas a Pagar da nota Flos).
- [ ] Pedir o print à Debora (item C) e à Caroline (item D).
- [ ] Dar o "pode" para cada escrita em produção (ORC-0071, cancelar título, status da Central, migration).

## Objetivo

Resolver os pedidos novos da Central em ordem de urgência: (1) permitir dar entrada em peça de fornecedor diferente do cadastro, achando a peça pelo código e somando ao estoque; (2) tirar a devolução já efetivada da fila de Aprovação Financeira e corrigir a causa; (3) remover a fatura indevida do Contas a Pagar; (4) fechar com evidência o caso do acordo.

## Decisões aprovadas

- O fornecedor da nota ou do pedido é livre: não depende do fornecedor principal da peça (usuário, 18/11).
- A SPEC cobre todos os pedidos abertos da Central, na ordem de prioridade definida em 18/11.
- Sem SPEC separada para os itens já cobertos (SPEC-316, SPEC-308, SPEC-321).

## Definição da SPEC

### Estado atual (verificado em 18/11/2026)

**A — Entrada avulsa (Compras):**
- `buscarProdutosParaEntrada` busca só em `nome` e `referencia`. Peça 12052 = LUMINARIA DE MESA TACCIA LED VIDRO, referência `F6602030`, ativa, fornecedor principal LUCENERA: digitar `12052` não retorna nada.
- FLOS SPA existe em `contatos` (tipo fornecedor, ativo, sem `canonical_id`); a entrada avulsa já permite escolhê-la.
- `criarNotaFiscalCompra` só insere em `notas_fiscais_compra` (número, data, valor, anexo, peça opcional). Não tem quantidade, não soma estoque e não gera Contas a Pagar.
- A entrada por pedido (`registrar_entrada_nota_compra`) soma estoque e permite "Trocar fornecedor (nota veio em outro nome)" (SPEC-215).
- Caminho provisório para a Debora: Pedido de compra avulso com o 12052 na Flos + entrada da nota. Não confirmado se o Pedido avulso aceita qualquer fornecedor.

**B — ORC-0071 (diagnóstico corrigido em 18/11):** devolução DEV-0011, subgrupo "TROCA DEV SEM VINCULO CONNECT", origem Connect 8367, R$ 1.343,89, aprovada pelo cliente em 13/11 (manual). Status "Aprovação Financeira", `requer_revisao_financeira = true`. Há 1 título `credito_devolucao` (origem `devolucao`) com parcela −1.343,89 firme, vencimento 13/11. É o único dos 11 orçamentos da fila com título gerado. O crédito nasce pela ponte `financeiro_ponte_devolucao` ao criar a parcela, antes da aprovação; portanto o orçamento está apenas aguardando a Aprovação Financeira (revisão pendente), não preso por bug.

**C — Fatura de produção:** sem candidato identificado; ver C1.

**D — Caio Medici Madureira:** não reproduzido; ver D1. A trava de tela compara `contato_id ?? nome_pagador`; a do banco exige mesma pessoa, empresa e natureza. A única parcela de outro contato (doc 2988, ROBERTA E PEDRO FELIPE) está paga e seria barrada antes, com outra mensagem.

### Mudança proposta

| Item | Mudança | Onde |
|---|---|---|
| A1/A2 | Busca por código; sem filtro por fornecedor da peça | Compras, services |
| A3 | Quantidade + soma ao estoque na entrada avulsa com peça | Compras (tela) + função de banco |
| A4 | Contas a Pagar da nota avulsa, conforme decisão | Compras / financeiro |
| B | Corrigir passagem de status e ajustar o ORC-0071 | Orçamentos + banco |
| C | Cancelar título indevido; corrigir causa se for regra | Banco / Compras |
| D | Só se reproduzir | Contas a Receber |

### Impacto no banco

- A3: possível função nova (ou parâmetro novo em `registrar_entrada_nota_compra`). Se for `CREATE OR REPLACE` com parâmetro novo, dropar a assinatura antiga para não criar overload (aprendizado de 21/09).
- Estoque: toda soma passa por `estoque_itens` com kardex/auditoria automáticos. Não rodar importador de estoque da Connect (SPEC-244).
- B e C: UPDATE/cancelamento pontual, com motivo, sem migration, salvo se a causa estiver em função.
- Segurança: função nova com `REVOKE ALL ... FROM PUBLIC, anon`, checagem de papel com `IS DISTINCT FROM`, permissão pelo acesso a Compras (`pode_acessar_sistema('compras')` dentro de `(SELECT ...)`).

### Análise de ecossistema

- Depende de `produtos`, `contatos`, `estoque_itens`, `notas_fiscais_compra`, `orcamentos`, `financeiro_titulos`; afeta Compras, Orçamentos, Financeiro e Estoque.
- Risco de duplicar saldo: a Connect já deu entrada da Flos. A quantidade somada aqui deve bater com a Connect e não pode ser somada de novo por nenhum importador.
- Custo da peça (`preco_custo`) não é legível por `authenticated`; a entrada não deve exibir nem gravar custo fora das rotas permitidas (SPEC-193).
- Atualizar `AI_DB_CONTEXT.md` de Compras se houver função nova; sem conflito conhecido com migrations antigas.

### Critérios de aceite

- A: digitar `12052` na entrada avulsa acha a peça; registrar nota da FLOS SPA com 12052 e quantidade soma ao estoque geral e aparece no kardex; a peça continua com fornecedor principal LUCENERA.
- B: ORC-0071 sai da Aprovação Financeira, mantém crédito −1.343,89 sem duplicar; uma nova devolução sem vínculo Connect aprovada no teste termina em "Orçamento Aprovado".
- C: título indevido cancelado com motivo e fora do Contas a Pagar; nova entrada de produção não repete.
- D: acordo do Caio gerado, ou solicitação fechada com explicação.

### Testes obrigatórios

- A: teste como usuário de Compras (não só como dono do banco), em ROLLBACK; conferir `quantidade_disponivel` pela `vw_consulta_estoque`.
- B: aprovar uma devolução de teste sem vínculo Connect em ROLLBACK e conferir status, título e `requer_revisao_financeira`.
- Verificar que o usuário sem acesso a Compras não executa a função nova (teste como `anon` e como usuário sem o sistema).

### Fora desta SPEC (já tratados)

- Vários fornecedores no mesmo pedido (Debora, 12/11): SPEC-316, no ar em 16/11.
- Produtos Ubiqua duplicados + Tabela 2 de revenda (Caroline, 13/11): SPEC-308, só desenho.
- Cancelar/estornar venda com pedido de compra: SPEC-321 e 321 parte 2, no ar.

### Pendentes de dados (sem SPEC própria por ora)

- Material em entrega futura no sistema e em reserva na Connect (Thais, 13/11): falta informar peça e venda.
- Centralizar impressos: pedido e desenhos no mesmo acesso (Debora, 16/11, Controle de Produção): melhoria, fica para depois dos itens A–D.

## Realizado

Nada implementado em 18/11/2026. Só levantamento e escrita da SPEC.

### 2026-11-18

- A1/A2 feitos em `04-Sistemas/compras-lucenera-3o23t98ee/src/services/notas-fiscais-compra.ts`: termo só com dígitos também casa `codigo_produto` (igualdade exata); a busca nunca filtrou por fornecedor. Sem erro de tipo novo no arquivo. NÃO commitado no repo do Compras, NÃO publicado.
- B1: gatilho lido; diagnóstico do ORC-0071 corrigido (ver acima). Nenhuma escrita em produção.
- Triagem da Central: 9 solicitações abertas ou em análise, 99 concluídas, 36 em desenvolvimento.
- Investigação somente leitura dos itens A, B, C e D (estado atual acima).

## Pendências

- [ ] Decisão do usuário: quantas unidades do 12052 chegaram e se a Connect já somou o saldo no sistema novo (evitar duplicar).
- [ ] Decisão do usuário: a nota avulsa da Flos deve gerar Contas a Pagar ou só estoque.
- [ ] Print/documento da fatura de produção que a Debora quer remover do Contas a Pagar.
- [ ] Print da mensagem e das parcelas marcadas no acordo do Caio (Caroline).
- [ ] Confirmar se o Pedido de compra avulso aceita fornecedor diferente do cadastro da peça (caminho provisório da Debora).
- [ ] Pedir à Caroline que aprove o ORC-0071 na Aprovação Financeira e avisar se der erro.
- [ ] Commit e publicação (wrangler) do Compras com a busca por código (A1/A2); ponteiro do submodule no repo central só depois do push do Compras.
- [ ] Atualizar status na Central (SPEC-316 concluída; SPEC-308 vinculada) com "pode" do usuário.
