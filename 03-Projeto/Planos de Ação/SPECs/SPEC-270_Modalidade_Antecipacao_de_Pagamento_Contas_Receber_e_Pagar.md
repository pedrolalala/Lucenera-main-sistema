---
titulo: "SPEC-270 — Nova modalidade \"Antecipação de pagamento\" em Contas a Receber e Contas a Pagar"
status: não iniciado
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Contas a Receber / Contas a Pagar (04-Sistemas/retorno-bancario-bradesco-5392a) — Cadastrar Duplicatas e Consultar Duplicatas
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — Aprovação Financeira
  - Dashboard Financeiro (04-Sistemas/dashboard-lucenera-b02z85wa3) — só conferir como a antecipação entra no fluxo
  - Compras (04-Sistemas/compras-lucenera-3o23t98ee) — só conferir o vínculo já existente da SPEC-215
  - Banco (supabase) — modelo financeiro novo (SPEC-258)
---

# SPEC-270 — Modalidade "Antecipação de pagamento"

> Origem: reunião 48 (Carol, 10/11/2026), `02-Reunioes/48. Lucenera (Carol) - 10.11.2026_ Contas a receber-contas a pagar atencipação de pagamento/01.Reunião`.
> Reunião é evidência, não decisão final: o que está em "Decisões" veio dela; o que está em "Proposta" é desenho meu para confirmar; o que está em "Perguntas" bloqueia a fase indicada.

## Checklist de Ação

**Fase 0 — antes de codar**
- [ ] 0.1 Confirmar com a Carol/Vinicius as perguntas P1–P7 (abaixo)
- [ ] 0.2 Confirmar o caminho de gravação real da tela Cadastrar Duplicatas (hoje grava em `boletos`, legado) e como `vw_financeiro_duplicatas` enxerga o lançamento novo

**Fase 1 — lançar a antecipação (Receber e Pagar)**
- [ ] 1.1 Banco: lançamento de antecipação no modelo novo (espécie `adiantamento`), com saldo a compensar
- [ ] 1.2 Cadastrar Duplicatas: seletor "Duplicata | Antecipação de pagamento" e formulário reduzido
- [ ] 1.3 Consultar Duplicatas: selo "Antecipada" e saldo; fora de Contas em Aberto / vencimentos do dia
- [ ] 1.4 Contas a Pagar: unificar com `pagamentos_antecipados` da SPEC-215 (sem duas portas diferentes)

**Fase 2 — usar a antecipação na Aprovação Financeira (Receber)**
- [ ] 2.1 Banco: função que lista as antecipações do cliente e função que compensa (baixa `compensacao`) contra as parcelas da venda
- [ ] 2.2 Orçamentos › Aprovação Financeira: bloco "Antecipações existentes" (valor, data, saldo, quanto usar)
- [ ] 2.3 Aviso "esse cliente tem antecipação" mesmo quando o usuário não usar

**Fase 3 — limite proporcional do sinal**
- [ ] 3.1 Regra: uso máximo = antecipação × (valor da compra ÷ valor total do projeto), só para o que for sinal
- [ ] 3.2 Tela mostra o teto e impede passar dele

**Fase 4 — LT/RT sobre a antecipação**
- [ ] 4.1 Decidir e implementar quando o RT nasce (ver P6); responsável = equipe do orçamento

**Entrega**
- [ ] Migration em rascunho + dry-run em ROLLBACK + revisor + aplicar; build/deploy; CHANGELOG; SPEC atualizada

### Passos manuais do usuário
- [ ] Responder P1–P7
- [ ] Testar o lançamento com a Carol (Receber e Pagar) e a aprovação financeira com um cliente que tenha antecipação

## Objetivo

Hoje a Carol não tem como lançar um dinheiro que entrou (ou saiu) **antes** de existir a venda/nota: ela cadastra como duplicata, que exige vencimento, parcelas e situação, e não conta a história certa. Pedido: uma modalidade própria, **"Antecipação de pagamento"**, **em Contas a Receber e em Contas a Pagar**, que:
1. se lança de forma simples (um valor, uma data de pagamento);
2. aparece na consulta de duplicatas marcada como antecipada;
3. aparece na **aprovação financeira** do cliente como "antecipações existentes", para a Carol decidir se abate do orçamento;
4. respeita a regra do **sinal proporcional** (não pode usar o sinal inteiro na primeira compra parcial).

## Decisões da reunião (não reabrir sem necessidade)

- "Não é duplicata, é antecipação de pagamento": **vale nos dois sistemas** (Contas a Pagar e Contas a Receber).
- Campos do lançamento: **data de emissão** (= data da operação recebida), **empresa**, **responsável**, **apropriação (grupo / subgrupo / apropriação)** — iguais aos da duplicata —, **situação** (não preenche: fica "em carteira", igual ao cadastro de duplicatas) e **observação** (opcional).
- Diferença para a duplicata: no lugar do **vencimento** entra a **data do pagamento**.
- **Responsável** = sempre a **equipe do orçamento** (arquitetura: chefe de equipe ou uma das meninas, ex.: Adriana). **Nunca a Carol**, porque o responsável é quem gera a LT.
- Depois de lançada, entra normalmente na **consulta de duplicatas**, **marcada como "antecipada"**, e **não aparece no "dia"** (vencimentos do dia / em aberto).
- Na **aprovação financeira** de um orçamento do cliente aparece **"Antecipações existentes"**, com o valor, para a Carol decidir se quer abater. Não é no aprovar orçamento comercial: é na etapa seguinte (aprovar financeiro), que é onde a Carol enxerga.
- Quando o pagamento já foi sincronizado com o cliente, na hora do orçamento tudo já coincide e o sinal já aparece.
- Há casos em que o sinal é usado e casos em que não. Quando usa, vale a **regra do proporcional**: ex.: projeto de R$ 100 mil, sinal de R$ 10 mil; primeira compra de R$ 16 mil não pode usar os R$ 10 mil — usa só a parte proporcional ao total (a Carol falou "R$ 1 mil" de cabeça; a conta exata daria R$ 1,6 mil — ver P4).

## Estado atual (verificado em 10/11/2026)

| Item | Situação |
|---|---|
| Modelo financeiro novo (SPEC-258) | Espécie `adiantamento` e origem `adiantamento` **já existem** no enum; baixa tipo `compensacao`; `titulo_compensado_id`; `origem_baixa = 'antecipacao'` previsto. Nada disso é usado ainda no a receber |
| Contas a Pagar | Já existe pagamento antecipado a **fornecedor** (SPEC-215): tabela `pagamentos_antecipados` (0 registros), `pagamento_antecipado_vinculos`, `vw_pagamentos_antecipados`, botão em Contas em Aberto, vínculo na Entrada de NF. A integridade da fase 4b acusa "pagamento antecipado ainda sem espelho (fase 4b-2)" |
| Contas a Receber | Nada equivalente. Existem `projeto_sinal` (0 linhas), `orcamentos.valor_sinal` e `contatos.valor_sinal_padrao` (SPEC-110), sem ligação com o financeiro novo |
| Cadastrar Duplicatas | `src/pages/CadastrarDuplicata.tsx` (933 linhas) grava em **`boletos`** (legado, por `conta_grupo_id`); campos: emissão, empresa, responsável (`usuarios`), contato, conta bancária, Grupo/Subgrupo/Apropriação, situação, gerar parcelas. Modo travado Pagar/Receber (`modo-sistema.ts`) |
| Aprovação financeira | `FinancialApprovalTab` / `FinancialApprovalDialog` em Orçamentos, **somente leitura por decisão de 14/09** (SPEC-133); aprova pela RPC `aprovar_orcamento_financeiro(p_orcamento_id)` |
| Devolução (precedente) | SPEC-258 fase 4d: título a receber negativo (`credito_devolucao`) que **nasce firme e fica em aberto**; a compensação (baixa `compensacao`) **nunca foi definida** — esta SPEC define o primeiro fluxo de compensação |
| RT (motor, migration 321) | Só reage a baixa `recebimento` de parcela de **venda**; baixa `compensacao` não gera RT |

## Proposta (a confirmar)

### 1. O lançamento
Seletor no topo do Cadastrar Duplicatas: **Duplicata | Antecipação de pagamento**. Antecipação mostra só: empresa, cliente (receber) ou fornecedor (pagar), responsável, data de emissão, **data do pagamento**, **valor**, Grupo/Subgrupo/Apropriação, conta bancária onde entrou/saiu, observação. Sem "Gerar parcelas", sem vencimento.

### 2. Como fica no banco (modelo novo)
- 1 título `adiantamento` (natureza `receber` ou `pagar`, origem `adiantamento`) + 1 parcela firme + 1 baixa (`recebimento`/`pagamento`, `origem_baixa = 'antecipacao'`) na data do pagamento. Saldo a compensar = valor − compensações.
- Gravação **só pelas funções porta única** do financeiro (`financeiro_criar_titulo` + baixa), nunca direto na tabela, e a tela de antecipação **não** passa por `boletos`.
- Contas a Pagar: reaproveitar `pagamentos_antecipados` (SPEC-215) ou migrá-la para o título `adiantamento`, mantendo o vínculo da Entrada de NF funcionando — decisão técnica da Fase 0.2/1.4.

### 3. Consulta
Aparece em Consultar Duplicatas com selo **"Antecipada"** e coluna de saldo; **não** entra em Contas em Aberto nem em "vencimentos do dia" (já está pago).

### 4. Aprovação financeira (Receber)
- Bloco **"Antecipações existentes"** do cliente (data, valor, saldo, observação) e campo "usar R$ ___" por antecipação. Escolher usar gera uma baixa `compensacao` contra a(s) parcela(s) da venda; **não é caixa novo** (não entra de novo no fluxo/no recebimento do mês).
- É a **única parte editável** do diálogo (que segue somente leitura para o resto, como decidido em 14/09).
- A RPC de aprovação ganha o parâmetro das antecipações a usar. **Cuidado:** `CREATE OR REPLACE FUNCTION` com parâmetro novo cria **overload** e quebra a produção (aprendido em 21/09); usar `DROP` da assinatura antiga na mesma migration ou função separada.

### 5. Proporcional do sinal
`uso_maximo = saldo_da_antecipação × (valor_da_compra ÷ valor_total_do_projeto)`, e nunca mais que o saldo. A tela mostra o teto; a função do banco recusa passar dele. Antecipação que **não** é sinal (pagamento adiantado comum) pode ser marcada como "sem proporcional" — ver P3.

### 6. LT/RT
Responsável = equipe do orçamento; a Carol nunca. O RT do arquiteto hoje nasce quando o cliente **paga** uma parcela da venda. Como a antecipação já foi paga antes, é preciso definir quando o RT dela nasce — ver P6.

## Perguntas de negócio

- [ ] **P1 — Quem é a antecipação:** vale por **cliente** ou por **projeto/orçamento**? (A reunião fala "do cliente", mas o proporcional usa o total do projeto.) Recomendado: nasce no cliente e pode (opcionalmente) apontar um projeto.
- [ ] **P2 — Situação:** a antecipação deve nascer **já recebida/paga** (com a baixa na data do pagamento) ou como "em carteira" aberta? A reunião diz "fica em carteira" e "não aparece no dia", o que sugere recebida mas ainda não aplicada. Recomendado: recebida na data, com saldo a compensar.
- [ ] **P3 — Sinal x adiantamento comum:** nem toda antecipação é sinal. O limite proporcional vale só para o sinal? Como o sistema sabe qual é qual (campo "É sinal?")?
- [ ] **P4 — Conta do proporcional:** o exemplo da reunião dá R$ 1,6 mil (10% de R$ 16 mil), a Carol disse "R$ 1 mil" de cabeça. Confirmar que a fórmula é sinal × compra ÷ total. E **de onde vem o "total do projeto"**: soma dos orçamentos aprovados do projeto, valor do orçamento-mãe ou valor informado à mão?
- [ ] **P5 — Pagar:** o botão "Lançar pagamento antecipado" da SPEC-215 (Contas em Aberto) continua, vira atalho para a nova modalidade ou some? E o proporcional vale também na Entrada de NF?
- [ ] **P6 — RT:** o RT sobre a venda paga com antecipação nasce (a) na **data da antecipação** (mês seguinte), (b) na **data em que a antecipação é aplicada** na venda (recomendado: é quando ela vira receita da venda) ou (c) nunca? Responder com Vinicius/Filippo (SPEC-258 fase 4c).
- [ ] **P7 — Quem é o "responsável":** lista de usuários da equipe do orçamento do projeto, ou qualquer usuário? Travar para que não seja a Carol?

## Critérios de aceite
- A Carol lança uma antecipação em Contas a Receber e em Contas a Pagar com os campos da reunião, sem vencimento/parcelas, e ela aparece em Consultar Duplicatas com o selo "Antecipada" e **fora** de Contas em Aberto/vencimentos do dia.
- Na Aprovação Financeira de um orçamento de um cliente com antecipação, o bloco "Antecipações existentes" aparece com o valor; usar gera compensação e reduz o saldo; não duplica caixa nem a posição diária.
- Não dá para usar mais que o teto proporcional nem mais que o saldo; erro claro na tela e no banco.
- Cancelar/estornar a compensação devolve o saldo.
- O responsável nunca é a Carol (regra na tela e no banco, ver P7).
- Auditoria financeira e `vw_financeiro_novo_integridade` continuam em zero violação.

## Testes obrigatórios
- Dry-run em ROLLBACK da migration; teste como Carol (assistente administrativa), como Lana e como `anon` (RLS: antecipação não pode vazar para quem não tem `financeiro`).
- Cenário do exemplo: projeto R$ 100 mil, sinal R$ 10 mil, compra R$ 16 mil → teto conforme P4; segunda compra reaproveita o saldo restante.
- Antecipação de 100% (não gera parcela a pagar) e antecipação parcial, no Pagar (já coberto na SPEC-215).
- Estorno da baixa da antecipação com compensação já feita deve ser recusado.

## Impacto / riscos
- Muda a **aprovação financeira** (caminho crítico de venda → contas a receber). Alterar a RPC com cuidado de overload e testar a aprovação sem antecipação (comportamento atual tem que continuar idêntico).
- Primeiro uso de `compensacao` no modelo novo: precisa constar em `vw_financeiro_*`/dashboard para não contar a antecipação duas vezes (uma ao receber, outra ao compensar).
- Contas a Pagar já tem `pagamentos_antecipados` com vínculo na Entrada de NF: não quebrar.

## Plano de rollback
Cada fase em migration própria com `rollback.sql`; front é aditivo (seletor de modalidade e bloco de antecipações atrás da existência de dados), então reverter o deploy volta ao comportamento atual.

## Documentos a atualizar quando implementar
CHANGELOG; esta SPEC; `supabase/docs` (modelo financeiro: uso da espécie `adiantamento` e da baixa `compensacao`); `AI_DB_CONTEXT.md` do sistema Contas a Pagar/Receber e do Orçamentos; relacionamento com SPEC-215, SPEC-258 e SPEC-110 (sinal padrão).

## Realizado
(nada ainda — SPEC criada em 10/11/2026 a partir da reunião 48)

## Pendências
- [ ] Responder as perguntas P1–P7 com a Carol (P1–P5, P7) e com Vinicius/Filippo (P6, P4) — sem isso as Fases 2–4 não começam.
- [ ] Fase 0.2: confirmar como a tela Cadastrar Duplicatas grava hoje e como a lista de duplicatas enxerga o novo lançamento.
- [ ] Registrar a reunião 48 no `02-Reunioes` (ata/decisões) se o índice de reuniões for mantido.
