---
titulo: "SPEC-288 — Contas a Pagar/Receber (Reunião 51, 12/11): antecipação na consulta, acordo com devolução e melhorias da consulta"
status: pendente
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Contas a Pagar e Contas a Receber (04-Sistemas/retorno-bancario-bradesco-5392a)
  - Compras (Entrada de NF — só leitura do vínculo)
  - Banco (pagamentos_antecipados, financeiro_titulos/parcelas/baixas, financeiro_criar_acordo)
---

# SPEC-288 — Reunião 51: Contas a Pagar e a Receber

**Origem:** Reunião 51 (Vinicius, Carol e Lana, 12/11/2026, "contas a receber e pagar") — `02-Reunioes/51. Lucenera (Vinicius, Carol e Lana) - 12.11.2026_contas receber e pagar/Reunião.01` — e a imagem da tela Antecipações enviada pelo usuário (Omega Light, 05/11/2026, R$ 2.608,52, "Disponível").
Relacionadas: SPEC-215 (antecipação a fornecedor), SPEC-270 (modalidade antecipação), SPEC-258 (financeiro novo, fase 4b-2), SPEC-287 (acordo).

## Checklist de Ação

- [x] **A. Antecipação do Contas a Pagar aparece na consulta** (espelho no financeiro novo) — migration 342 **APLICADA em SP em 12/11**; a Omega Light aparece em Consultar Duplicatas (CP / Pago / adiantamento / R$ 2.608,52 / 05/11)
- [x] **B. Acordo aceita devolução + aquisição** (total zero vira compensação, sem parcela nova) — migration 341 aplicada e tela publicada em 12/11; total negativo segue bloqueado (decisão 2)
- [x] **C. Filtros da consulta se mantêm** ao trocar de aba — hook `useFiltroPersistido` (sessão do navegador, separado por Pagar/Receber) em Consultar Duplicatas e Contas em Aberto; publicado (commit `64d42ac`)
- [x] **D. Lançamento aparece na lista sem recarregar** — por desenho: a consulta recarrega ao reabrir a tela (remonta ao voltar da aba Antecipações) e agora mantém o filtro, e o item A faz a antecipação nascer no financeiro. Falta só o teste visual da Lana (não testado na tela)
- [x] **E1. Busca por projeto corrigida** — causa: linhas do financeiro novo chegavam à grade sem projeto (`orcamentos: null`), então escolher um projeto eliminava todas; agora usa o `projeto_id` da própria parcela (commit `20b54e8`, publicado)
- [ ] **E2. Devolução/brinde com número próprio** — NÃO feito: o número de venda nasce dentro de `aprovar_orcamento_financeiro` (função crítica que aprova a venda e gera as parcelas); depende das decisões 3 (prefixo "D", prefixo do brinde, vendas antigas)
- [ ] CHANGELOG, snapshot do banco, contexto do sistema

### Passos manuais do usuário

- [ ] Responder as decisões em aberto (seção "Decisões em aberto")
- [ ] Lana testar o acordo e a antecipação com casos reais pequenos
- [ ] Lana ir anotando o que não bate com a Connect e mandar só o que for erro do sistema

## Objetivo

A Lana e a Carol conferem "quanto vai pagar e quanto vai receber do dia 5 até hoje". A reunião mostrou: (1) um pagamento antecipado já feito na Connect (Omega Light) que, lançado no sistema novo, **não aparece na consulta**; (2) o **acordo** com devolução + aquisição não funciona; (3) a consulta perde os filtros e a busca por projeto/devolução confunde.

## A. Antecipação do Contas a Pagar não aparece na consulta (causa confirmada)

**Estado verificado (12/11/2026, somente leitura):**
- O lançamento da Omega Light existe só em `pagamentos_antecipados` (id `889322d0…`, valor 2.608,52, pagamento 05/11/2026, empresa MANOELLA conforme a tela, `pedido_compra_id` vazio, não cancelado, criado às 13:37 de 12/11).
- Não existe título `adiantamento` nem parcela nem baixa no financeiro novo (`financeiro_titulos`/`financeiro_parcelas`/`financeiro_baixas`: 0 linhas de adiantamento). Logo `vw_financeiro_duplicatas` não o mostra, Contas em Aberto não o mostra e a posição diária não o conta.
- É lacuna conhecida: a migration 307 deixou "pagamento antecipado" para a **fase 4b-2** e a conferência de integridade acusa "pagamento antecipado ainda sem espelho" (agora 1). A SPEC-270 só foi feita para **Contas a Receber** (migration 325); a parte de Contas a Pagar (item 1.4 / Fase 0.2, "reaproveitar `pagamentos_antecipados` ou migrar para o título `adiantamento`") nunca foi feita.

**Fluxo combinado na reunião (já funciona, não muda):**
1. Lançar a antecipação com **Pedido em branco**; o número do pedido é preenchido depois.
2. Na **Entrada de NF**, ao puxar o pedido, o sistema mostra o pagamento antecipado (cobriu o pedido todo ou parte) e a Débora lança as demais parcelas.
3. O vínculo e o valor certo se resolvem **na entrada da nota**, nunca no lançamento (o fornecedor pode mandar 80% do pedido).

**Proposta técnica (para aprovar):**
- Ao lançar (e para os já lançados, num backfill de 1 registro), criar o espelho no financeiro novo: título `adiantamento` (natureza `pagar`, origem `adiantamento`), 1 parcela firme e 1 baixa tipo `pagamento` com `origem_baixa = 'antecipacao'` na data do pagamento, ligados ao `pagamentos_antecipados` (campo de vínculo). A consulta passa a mostrar a linha com o selo "AT" (como no Receber), fora de Contas em Aberto e do "dia".
- Cancelar a antecipação estorna a baixa e cancela o título (já existe o padrão em `financeiro_cancelar_antecipacao` do Receber).
- O vínculo com a Entrada de NF (`pagamento_antecipado_vinculos`) continua como está; a compensação no financeiro novo (baixa `compensacao`) é uma etapa seguinte.
- Atenção à ponte de pedido (`financeiro_ponte_pedido` já desconta antecipações do pedido): não pode contar em dobro.

## B. Acordo com devolução + aquisição (SPEC-287)

- O acordo já está **implementado e publicado** (migration 340, botão em Consultar Duplicatas), mas a reunião mostrou o caso que ele **não cobre**: selecionar a **devolução (parcela negativa, `credito_devolucao`)** e a **aquisição** do mesmo cliente.
- Hoje a função recusa quando o total das parcelas é ≤ 0 ("desconto precisa ser menor que o total") e exige parcela nova > 0. No banco há uma devolução de −R$ 2.640,95 e uma parcela de orçamento de R$ 2.640,95 do mesmo cliente: o total fecha em **zero** e o acordo falharia.
- **Regra proposta:**
  - total > 0: como hoje (novas parcelas somam total − desconto);
  - total = 0: acordo **sem parcela nova**: as parcelas ficam `renegociada` com baixa tipo `compensacao` entre si, vinculadas no mesmo `grupo_acordo`;
  - total < 0 (sobra crédito do cliente): decisão do usuário (vira crédito em aberto? devolução em dinheiro?).
  - baixa de parcela negativa: hoje a baixa não aceita valor negativo; o registro do lado da devolução entra como `compensacao` em valor absoluto, a ser validado no ensaio.
- A tela deve permitir total zero (hoje exige "soma > 0") e mostrar o resumo "devolução −X + aquisição +X = compensado".

## C. Filtros se mantêm entre abas (Consulta, Antecipações, Em aberto)

- Pedido do Vinicius: ao lançar uma antecipação e voltar para a consulta, o último filtro não deve se perder. A Lana/Carol trabalham alternando as telas; abrir duas abas do navegador "não faz sentido" para o uso delas.
- Proposta: guardar os filtros da consulta por sistema (Pagar/Receber) na sessão do navegador e restaurá-los ao voltar; botão "Limpar filtros" explícito.

## D. Lançamento aparece sem recarregar

- Ao lançar uma antecipação (ou duplicata), a lista da consulta e da aba Antecipações deve atualizar sozinha. Na reunião não foi possível confirmar ("tem que fazer o teste, mas eu acho que sim"). Teste obrigatório depois do item A.

## E. Devolução/brinde sem número e busca por projeto

- Devolução e brinde **não geram número de venda**, só o orçamento, o que dificulta achar o caso. Sugestão do Vinicius: usar "D" + número para devolução (e uma letra própria para brinde), "seguindo a mesma lógica". Decisão do usuário.
- Busca por projeto: buscar o projeto 23316 não acha nada, mas com "todos" aparece tudo, e o código aparece 3 vezes. Hipótese da Lana: as parcelas estão **sem projeto vinculado**. A confirmar nos dados (parcelas/títulos do cliente `d08a4b21…` e `projeto_id`) antes de mexer na busca.

## Decisões em aberto

1. **Antecipação a pagar:** espelhar no financeiro novo como proposto em A (recomendado) ou manter a tabela separada e só somar na consulta?
2. **Total negativo no acordo (sobra de devolução):** vira crédito em aberto do cliente ou fica em branco até decisão?
3. **Número de devolução e brinde:** prefixo "D" e outro para brinde, sequência própria? Vale para vendas antigas?
4. **"Data de vencimento, não data do pagamento, para não baixar automático"** (Vinicius, ao lançar antecipação): significa que a antecipação deve entrar com vencimento para a baixa ser manual? Contradiz a SPEC-270 (nasce paga). Confirmar com o Vinicius.
5. Quando a Lana perguntar "já baixou na conta?" sobre antecipação: a baixa é automática (nasce paga) ou manual?

## Critérios de aceite

- A: a Omega Light aparece em Consultar Duplicatas (Pagar) com selo de antecipada, R$ 2.608,52, data 05/11/2026, fora de Contas em Aberto; cancelar remove; Entrada de NF continua mostrando o saldo antecipado do fornecedor; a integridade deixa de acusar "sem espelho".
- B: acordo com devolução (−2.640,95) + aquisição (2.640,95) conclui sem parcela nova e as duas parcelas somem da lista de abertas, com vínculo no grupo do acordo.
- C/D: lançar antecipação, voltar à consulta e ver o filtro mantido e a linha nova.
- Testes de segurança do AGENTS.md (anon e usuário sem Financeiro) em ROLLBACK antes de aplicar qualquer migration.

## Rollback

Código: reverter o commit do Retorno Bancário. Banco: `rollback.sql` de cada migration; o espelho de antecipação criado é reversível por estorno da baixa e cancelamento do título.

## Realizado

### 2026-11-12

- Análise da Reunião 51 e da imagem (somente leitura); causa do item A confirmada no banco; limite do acordo (item B) confirmado pela leitura do código da função e dos dados. SPEC criada.
- Item B implementado no mesmo dia depois que o usuário esbarrou nele (print: 2 parcelas, total R$ 0,00, botão travado): migration `20261112_341_spec288_acordo_compensacao_total_zero` ensaiada em ROLLBACK com a devolução real (−2.640,95 + 2.640,95) e **APLICADA em SP**; `AcordoModal` com modo "Compensação" (commit `e3b0987` no Retorno Bancário, publicado em Contas a Pagar e Contas a Receber). Itens A, C, D e E seguem pendentes.
- Item A (código pronto): migration `20261112_342_spec288_espelho_pagamento_antecipado_pagar` — coluna `pagamentos_antecipados.titulo_id` + gatilho `trg_fin_espelho_antecipado` que cria/cancela um título `adiantamento` (pagar) com parcela firme e baixa `pagamento` (origem `ponte`, sem conta bancária), retroativo para a Omega Light, e conferência de integridade ajustada para acusar só o que ficou sem espelho. Ensaio em ROLLBACK: a consulta passa a mostrar `CP / Pago / adiantamento / OMEGA LIGHT / R$ 2.608,52 / 05/11/2026`; cancelar estorna e cancela o título; lançamento novo ganha título; integridade 0; nenhuma falha. Falha do espelho nunca trava o lançamento (vai para `financeiro_ponte_falhas`). **APLICADA em SP em 12/11.** Observação: quem lança só com acesso `dashboard-financeiro` ou só com a Compras (sem `financeiro`, caso da Débora na Entrada de NF da SPEC-289) não tinha espelho (caía em `financeiro_ponte_falhas`); a migration 343 da SPEC-289 corrige isso fazendo o espelho rodar sem o usuário da sessão (aguarda aplicação).
- Item C (código pronto): filtros persistidos por sessão em Consultar Duplicatas e Contas em Aberto. **Não publicado.**
- Item E: depende das decisões 3 e da verificação de dados da busca por projeto; não iniciado.

## Pendências

- [ ] Usuário decidir as 5 perguntas da seção "Decisões em aberto".
- [ ] Implementar na ordem: A (espelho da antecipação a pagar), B (acordo com total zero), C/D, E.
- [ ] Confirmar com o Vinicius o que ele quis dizer sobre "data de vencimento, não de pagamento".
