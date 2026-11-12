---
titulo: "SPEC-287 — Financeiro: Acordo (renegociação de parcelas) — levantamento da Reunião 47"
status: não iniciado
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Consultar Duplicatas / Adm. Bancária (04-Sistemas/retorno-bancario-bradesco-5392a)
  - Contas a Receber e Contas a Pagar (financeiro_titulos, financeiro_parcelas, financeiro_baixas, financeiro_renegociacoes)
  - Orçamentos / Vendas (só consulta: plano de parcelas e nota fiscal)
---

# SPEC-287 — Acordo (renegociação de parcelas)

**Origem:** Reunião 47 (Lana, 10/11/2026, "Admin bancário: questão de editar e amostra") — arquivo `02-Reunioes/47 Lucenera (Lana) 10.11.2026_ Admin bancario questão de editar e amostraa/01. Reunião`. Pergunta do usuário em 12/11: "o acordo falado na reunião já foi ajeitado?" **Resposta: não.** Esta SPEC é só o levantamento e as perguntas; **nada foi implementado nem alterado**.

## Checklist de Ação

- [ ] Usuário e Filippo/Lana respondem as perguntas em aberto (seção 5)
- [ ] Decidir o desenho (seção 6) e aprovar esta SPEC
- [ ] Banco: função de acordo e regras (depois da aprovação)
- [ ] Consultar Duplicatas: ligar o botão "Acordo" (hoje só mostra "ainda não implementado")
- [ ] Contas a Receber / a Pagar: mostrar o vínculo do acordo
- [ ] CHANGELOG, snapshot do banco, contexto dos sistemas

### Passos manuais do usuário

- [ ] Responder as perguntas da seção 5 (com a Lana, a Carol e o Filippo)
- [ ] Definir a matriz de acesso do acordo (quem cria, quem aprova) — citada pelo usuário na reunião
- [ ] Testar com a Lana/Carol com um caso real

## Objetivo

Permitir que o financeiro **renegocie parcelas** como a Lucenera faz hoje na Connect: juntar contas, mudar valores/datas/forma, aplicar desconto, vincular a compra, tudo com rastro (quem, quando, por quê) e **sem perder o vínculo com as parcelas originais**.

## O que foi dito na reunião (evidência, não decisão final)

1. **Parcelas desiguais.** Venda em 3 parcelas: a Carol lançou 3 iguais, mas o combinado era **30% na 1ª parcela** (paga no Pix, "porque a gente não entregou o material ainda") e as demais **iguais, em boleto**; o valor total é de "R$ 8.000 e alguma coisa" na primeira. Quando o material é entregue, registra-se a nota fiscal e saem os boletos.
2. **Acordo com arquiteta.** A arquiteta compra, faz-se um acordo e a compra vai sendo **descontada das RTs** dela. Gera conta a pagar e a receber, vinculadas à compra.
3. **Vários pedidos em um acordo.** Cliente com várias compras/pedidos: vincula tudo em **uma parcela só**, que sai na nota fiscal e libera os pedidos.
4. **Desconto no acordo.** Ex.: quem paga no Pix com 10% de desconto: o acordo "tira a porcentagem" do total.
5. **Baixa.** Funciona como é (boleto, Pix, caixa dinheiro), **sem adaptar nada por causa da Connect**. Foi feita normalmente na reunião.
6. O acordo muda a forma real de pagamento mesmo (combinou boleto, pagou no cartão): não é só trocar a forma, é refazer a conta.

## Estado atual (verificado em 12/11/2026, somente leitura)

- **Tela:** botão "Acordo" em `ConsultarDuplicatas.tsx` chama `handleNaoImplementado('Acordo')` → mensagem "ainda não implementado. Aguardando definição do fluxo".
- **Banco:** já existe base para o acordo no modelo novo da SPEC-258:
  - `financeiro_renegociacoes` (`parcela_origem_id`, `parcela_nova_id`, `grupo_acordo`, `criado_em`, `criado_por`): **0 registros**;
  - situação de parcela `renegociada` e `substituida` (enum `fin_situacao`); tipo de baixa `renegociacao`, `abatimento`, `compensacao`;
  - títulos com `substitui_titulo_id`, `titulo_base_id`, `titulo_compensado_id`; origens `permuta`, `adiantamento`, `devolucao`, `manual`;
  - baixas já existentes: 106 `abatimento`, 0 `renegociacao`. Não há função de acordo (só `financeiro_baixar`, `financeiro_baixar_lote`).
- **Legado da Connect:** os "acordos" antigos (293 "Acordo" e 489 "Acordo Valor Zerado" no Receber; 878 códigos de duplicata repetidos) vieram copiados no legado; a SPEC-245 (G14) e a SPEC-258 (pergunta 20, crítica) deixam isso sem decisão.
- **Orçamento:** o plano de parcelas do orçamento já tem valor por parcela com redistribuição (SPEC-156, `parcelas_config`), então "30% na 1ª + resto igual" parece possível na venda. Não testei na tela. A Carol lançou 3 iguais, possivelmente por desconhecer o recurso.
- **Permissão:** SPEC-269 diz que a Carol terá acesso a "acordos (a desenvolver)".

## Casos de acordo (tabela de trabalho)

| # | Caso | O que acontece com as parcelas originais | O que nasce |
|---|---|---|---|
| A | Refazer parcelas da mesma venda (30% + resto igual, nova data/forma) | ficam `renegociada` (sem apagar) | novo título/parcelas vinculados, `grupo_acordo` |
| B | Juntar várias parcelas/compras do cliente numa só | `renegociada` | 1 parcela (ou plano) com vínculo a todas |
| C | Desconto (ex.: 10% no Pix) | `renegociada` | parcela nova com valor menor + `abatimento` registrado com motivo |
| D | Acordo com arquiteta: compra abatida das RTs | parcela da compra e RTs ligadas | a pagar (RT) compensa o a receber (`compensacao`) |
| E | Mudou a forma real (boleto → cartão) | boleto cancelado/baixado sem pagamento | nova parcela na forma real |

## Perguntas em aberto (precisam de resposta antes de implementar)

1. **Quem cria e quem aprova** um acordo (Lana? Carol? só admin)? E acima de qual desconto precisa de aprovação?
2. **Desconto no acordo é perdão/abatimento** (fora da receita realizada, como a SPEC-258 propõe) ou ajuste do preço da venda (muda o valor da venda)?
3. **Caso A:** o acordo é feito na parcela do Contas a Receber ou deve voltar ao orçamento (corrigir o plano da venda)? Se a parcela já foi paga (o 30% no Pix), ela fica como está e só o resto é refeito?
4. **Caso B:** a "parcela única na nota fiscal" é gerada na emissão da nota (Vendas) ou no acordo? Como fica o vínculo com cada pedido liberado?
5. **Caso D:** como o abatimento das RTs funciona: desconta a cada RT que vence, até quitar a compra? Tem teto por RT?
6. **Boleto já emitido** (CNAB) quando há acordo: cancela o boleto antigo e emite novo? Quem faz a baixa de cancelamento no banco?
7. **Acordos antigos da Connect** (293 + 489): ficam só como histórico ou precisam virar `financeiro_renegociacoes`? (pergunta 20 da SPEC-258)
8. **Matriz de acesso** (citada na reunião): quem vê/cria acordo; a Lana poderá criar sem a Carol?

## Desenho proposto (para aprovar; não implementado)

- **Uma função só** `financeiro_criar_acordo(parcelas_origem[], novo_plano[], motivo, desconto, aprovado_por?)`, `SECURITY DEFINER`, com trava de papel e `pode_acessar_sistema`, em uma transação:
  1. valida que as parcelas de origem são do mesmo contato/empresa e estão `firme`/`prevista` (sem baixa total);
  2. marca origem como `renegociada`, registra `financeiro_renegociacoes` (um `grupo_acordo` por acordo) e o desconto como `abatimento` com motivo;
  3. cria o novo título/parcelas (`origem_tipo = 'manual'` ou nova origem `acordo`, a decidir) com `substitui_titulo_id`;
  4. soma de valores confere (originais − desconto = novas), senão aborta.
- **Tela:** botão "Acordo" em Consultar Duplicatas abre um diálogo: parcelas selecionadas, novo plano (valor ou % por parcela, data, forma), desconto, motivo obrigatório, resumo "antes × depois".
- **Rastro:** tudo em `financeiro_eventos`/auditoria; as parcelas originais continuam visíveis com selo "renegociada → acordo nº X".
- **Não faz:** não apaga nada, não mexe em estoque, não toca no legado sem a lista aprovada (regra da SPEC-245).

## Critérios de aceite (rascunho)

- Caso A: parcela de R$ 8.000+ virou 30% (Pix, paga) + 2 iguais em boleto; soma = original; original aparece `renegociada`.
- Caso C: 10% de desconto vira `abatimento` com motivo; receita realizada não infla.
- Acordo recusado se soma não bate, se a parcela já está paga/baixada, ou se o usuário não tem a permissão.
- Teste como `anon` e como usuário sem Financeiro (AGENTS.md, segurança), tudo em ROLLBACK antes de aplicar.

## Rollback

Nada aplicado. Quando houver migration: `rollback.sql` removendo a função; os acordos criados ficam reversíveis por `estorno` das parcelas novas e volta de `renegociada` para `firme` (a definir com o desenho final).

## Realizado

### 2026-11-12

- Levantamento da Reunião 47 e do estado do sistema (somente leitura). SPEC criada. Nenhum código, banco ou dado alterado.

## Pendências

- [ ] Responder as 8 perguntas da seção "Perguntas em aberto" com a Lana, a Carol e o Filippo.
- [ ] Confirmar com a Carol se o plano de parcelas do orçamento já permite "30% na 1ª + resto igual" (caso A na venda) e orientá-la, sem precisar de acordo nesse caso.
- [ ] Aprovar o desenho e então implementar (função de acordo, botão "Acordo", vínculo nas telas de Contas a Receber/Pagar).
- [ ] Registrar a decisão da pergunta 20 da SPEC-258 (acordo = perdão/abatimento?) na SPEC-258 quando respondida.
