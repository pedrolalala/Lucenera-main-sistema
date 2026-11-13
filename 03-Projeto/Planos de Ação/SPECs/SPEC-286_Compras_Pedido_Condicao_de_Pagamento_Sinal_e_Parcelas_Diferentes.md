---
titulo: "SPEC-286 — Compras: pedido com sinal + parcelas de valores diferentes e sinal visível em Contas a Pagar"
status: pendente
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee)
  - Contas a Pagar (financeiro_titulos / financeiro_parcelas)
  - Banco (pedidos_compra, pedido_compra_parcelas, pagamentos_antecipados)
---

# SPEC-286 — Pedido de compra com sinal + parcelas diferentes

**Origem:** solicitação da Débora na Central de Solicitações (12/11/2026 14:19, id `71d0c134-ae73-4264-b2b6-fa6900df5686`, tipo `pedido_alteracao`, status `aberto`), título "PERMISSÃO PARA COLOCAR MAIS DE UMA CONDIÇÃO DE PAGAMENTO NO PEDIDO".

> Texto dela: "tem pedidos que precisamos dar um sinal e parcelarmos o resto. Por exemplo pedido nº 1802: serão 25% de entrada (pagamento adiantado), mais 3x (28, 42, 56). No nosso pedido coloquei como parcela o sinal sendo a 1ª. E nesse adiantamento, pagamento no ato ao fornecedor, essa pode aparecer nas contas a pagar? Já para aprovação do financeiro e pagamento?"

## Checklist de Ação

- [ ] Decidir com o usuário as perguntas da seção "Decisões em aberto"
- [x] Compras: permitir % por parcela no pedido (R$ aparece ao lado), com soma sempre = 100%
- [x] Banco: migration 339 redigida e ensaiada em ROLLBACK (coluna `condicoes_percentuais`, RPC `definir_percentuais_parcelas_pedido`, `gerar_parcelas_pedido_compra` usando os %) — APLICADA em SP em 12/11/2026
- [ ] Contas a Pagar: conferir na tela que a parcela do sinal aparece para aprovação e pagamento (decisões 2 e 3 em aberto)
- [x] CHANGELOG
- [ ] Snapshot do banco (`db/current`) e `AI_DB_CONTEXT.md` do Compras, depois de aplicar a 339

### Passos manuais do usuário

- [ ] Responder as decisões em aberto
- [ ] Testar com a Débora usando um pedido novo com sinal + parcelas diferentes
- [x] Aplicação da migration 339 autorizada e feita (12/11)
- [ ] Autorizar a publicação do Compras

## Objetivo

Hoje o pedido de compra aceita **uma** condição de pagamento por vez (A prazo, Por datas, À vista ou Antecipado) e divide o total **em partes iguais**. A Compras precisa fechar com o fornecedor casos como "25% de sinal no dia + o resto em 3 vezes" e ter o sinal na tela do financeiro para aprovar e pagar.

## Estado atual (verificado em 12/11/2026, só leitura)

- Tela: `CondicaoPagamentoCampo.tsx` grava texto em `pedidos_compra.condicoes_pagamento` (ex.: `12/11/2026, 10/12/2026, 24/12/2026, 07/01/2027`). O banco (`_lucenera_datas_parcelas` / `gerar_parcelas_pedido_compra`) gera as parcelas **iguais**.
- Pedido **1802** (ISLIGHT, R$ 8.592,40, `aprovado`): 4 parcelas de R$ 2.148,10 (a última 2.148,09 no centavo), nas datas 12/11, 10/12, 24/12, 07/01 (0, 28, 42, 56 dias). Como 25% de 8.592,40 = 2.148,10, **neste caso as partes iguais coincidem com "25% + 3 parcelas de 25%"**. A observação "ENTRADA DE 25% NO DIA 12/11 + 3X (28,42,56)" foi escrita à mão.
- Financeiro: o pedido 1802 já tem título a pagar (`financeiro_titulos`, origem `pedido_compra`) com 4 parcelas `prevista`; a 1ª (12/11) é o sinal. A ponte é `financeiro_ponte_pedido` (migration 307): cada parcela do pedido vira previsão.
- Pagamento antecipado já existe (`pagamentos_antecipados`, 0 registros ativos), mas é para "já foi pago": o pedido não gera parcela.
- Limitação real: se o sinal for **30%** e o resto 3x de 23,3%, a tela não permite; a Débora precisaria de valores por parcela.

## Decisões em aberto (perguntar ao usuário)

1. **Valor por parcela:** a regra geral é "cada parcela com valor em R$ ou em %, soma obrigatória = total do pedido"? (Recomendado.)
2. **Sinal em Contas a Pagar:** o sinal deve aparecer como parcela `prevista` (como hoje) ou como **título firme, para aprovação do financeiro assim que o pedido for aprovado**, antes da nota? Isso toca a SPEC-209 (F), SPEC-215 e SPEC-258 (fase 4b).
3. **Quem aprova e paga:** hoje a baixa da previsão é o fluxo da SPEC-258 (pop-up "parcelas já pagas?"). O sinal segue o mesmo fluxo ou ganha aprovação própria da Carol/financeiro?
4. **Pedido já aprovado:** quando o pedido já está `aprovado` (caso do 1802) e a Débora altera as parcelas, o fluxo é "voltar para edição" (como no histórico do 1802) ou pode editar direto?

## Definição da SPEC (proposta, depende da decisão 1 e 2)

1. `CondicaoPagamentoCampo`: no modo "Por datas", cada linha ganha campo de valor (R$ ou %). Padrão continua "partes iguais"; o usuário só preenche se quiser. Rótulo da 1ª linha opcional "Sinal / entrada".
2. Persistência: preferir gravar direto as parcelas (`pedido_compra_parcelas` com valor e vencimento) no salvar do pedido, mantendo `condicoes_pagamento` como texto de resumo. Sem mudar a ponte do financeiro, que já lê o valor de cada parcela.
3. Validação: soma das parcelas = total do pedido (considerando desconto e valor final negociado); diferença de centavos vai para a última parcela.
4. Contas a Pagar: conforme decisão 2; se for só previsão, nenhuma mudança de banco além do item 2; se for título firme do sinal, mudar a ponte para marcar a parcela do sinal como `firme`.
5. Não alterar pedidos já existentes: o 1802 continua como está (já correto).

## Critérios de aceite

- Pedido novo: sinal de 25% + 3 parcelas iguais do resto, com datas, salva e mostra os valores corretos.
- Pedido novo: sinal 30% + 2 parcelas de 35%, soma = total; soma errada bloqueia o salvar com mensagem clara.
- A parcela do sinal aparece em Contas a Pagar com o fornecedor e o número do pedido (comportamento conforme decisão 2).
- Pedidos antigos (partes iguais) continuam gerando as mesmas parcelas.
- Teste como `anon` e como usuário sem acesso a Compras (regras de RLS do AGENTS.md) se houver migration.

## Rollback

Código: reverter o commit do Compras. Banco: reaplicar a definição anterior da função alterada (migration com `rollback.sql`).

## Realizado

### 2026-11-12

- SPEC criada a partir da solicitação da Débora; levantamento do estado atual (somente leitura).
- Decisão adotada por padrão (usuário mandou começar): % por parcela, sinal segue como previsão em Contas a Pagar (decisão 2 e 3 não mudam).
- Migration 339 escrita, ensaiada em ROLLBACK e APLICADA em SP (12/11/2026). Os % ficam numa coluna à parte para o PDF, a Entrada de NF e o e-mail continuarem lendo só as datas.
- Compras: `CondicaoPagamentoCampo`, `EditarPedidoDialog`, `ModalGerarCompraItemOrcamento` e `services/pedido-compra.ts` alterados (código local, type-check sem erros novos).

## Pendências

- [ ] Perguntar ao usuário as 4 decisões em aberto (valor por parcela, sinal firme ou previsto, quem aprova o sinal, edição de pedido aprovado).
- [ ] Responder à Débora na Central que o pedido 1802 já está com o sinal como parcela prevista em Contas a Pagar, e combinar o que falta ver na tela do financeiro.
- [ ] Depois da decisão, implementar e mudar o status da solicitação na Central.
