---
titulo: "SPEC-255 — Garantia e outras saídas sem cobrança: sem revisão financeira, número próprio (G) e rótulo visível"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — tipo de operação, fluxo de aprovação
  - Venda Parcial / Logística — rótulo e filtro
  - Banco (Supabase SP) — `aprovar_orcamento_financeiro`, numeração de venda
---

# SPEC-255 — Garantia e saídas sem cobrança

> Origem: reunião 06/11 (min. 115–138). **Ajusta a SPEC-233** (ainda "não iniciado"), que previa bloquear a aprovação de "Outros" e "SAC" — o que quebraria o fluxo de garantia que a equipe já usa. Relacionadas: SPEC-234, SPEC-156 (Controle de Garantia).

## Checklist de Ação

- [ ] A. A garantia (e uso e consumo, bonificação, e demais saídas sem cobrança da SPEC-233, classe D) **pula a Revisão Financeira**: ao confirmar, vai direto do aprovado pela equipe para a venda.
- [ ] B. **Não gera** parcelas, boletos nem financeiro (confirmado no teste); manter.
- [ ] C. Número próprio: venda de garantia com prefixo **G** (ex.: G1473) em vez de V; mesma ideia para outros tipos sem cobrança, se o Vinicius quiser.
- [ ] D. Rótulo "Garantia" (cor amarela) na lista de vendas, na Venda Parcial e na Logística; filtro por tipo.
- [ ] E. Garantia **não exige** venda de origem (diferente da devolução): a peça pode ter anos (ex.: garantia de 5 anos de fornecedor anterior). O campo hoje em vermelho "selecione o tipo" deve parar de bloquear.
- [ ] F. Ajustar a SPEC-233: GARANTIA, USO E CONSUMO e BONIFICAÇÃO ficam permitidos, classe D (saída sem cobrança), em vez de bloqueados na Fase 0.
- [ ] G. Data da operação: decidir se pode ser retroativa (a Vitória lançou na Connect na véspera).

### Passos manuais do usuário

- [ ] Matheus e Vitória: lançar no sistema novo as garantias que já saíram na Connect (a de ontem: Rodrigo Motti, 4 un. da peça 11636, e as demais da véspera).

## Objetivo

Garantia, uso e consumo e bonificação não geram financeiro, portanto não deveriam depender da Lana ou da Carol aprovarem a revisão, e devem ser reconhecíveis à primeira vista.

## Decisões aprovadas (reunião)

- Garantia faz **só estoque**: sai do estoque geral para o cliente, sem parcela, sem boleto.
- O Matheus não pode ficar dependente do financeiro para liberar uma garantia.
- Garantia sem estoque disponível entra em **Entrega Futura** e depois a equipe usa Transferir (SPEC-251).
- Teste feito: orçamento tipo Outros → Garantia, empresa Lutineira, desconto 0, sem frete → aprovado → **gerou venda 1473, não gerou financeiro** ("a regra está ok").

## Definição da SPEC

### Como está (teste da reunião)

1. O orçamento caiu em **rascunho**, passou por "aprovação da equipe" e foi para **revisão financeira**, onde precisou de alguém com acesso (Lana/Carol).
2. Aprovado, gerou venda com número de venda comum, sem identificar que é garantia.
3. A SPEC-233 prevê bloquear "Outros" na aprovação; hoje o comportamento real é "aprova como venda".

### Mudança proposta

| Parte | Mudança |
|---|---|
| `aprovar_orcamento_financeiro` | Para classe D, aprovar na etapa da equipe sem passar pela revisão financeira; continuar sem financeiro. |
| Numeração | Série própria `G` para garantia (a conferir se o número vem de sequência única de vendas; ver SPEC-232 sobre vendas do sistema × Connect). |
| Telas | Rótulo/cor e filtro por tipo em Orçamentos, Venda Parcial e Logística. |
| Cadastro do tipo | Garantia sem exigir venda de origem. |

## Critérios de aceite

- Garantia aprovada pelo Matheus não aparece na fila da revisão financeira.
- Nenhuma parcela/boleto/financeiro gerado; estoque conforme a regra D.
- O número aparece como G e a Venda Parcial mostra o rótulo.
- Devolução continua exigindo a venda de origem.

## Realizado

Nada implementado.

## Pendências

- [ ] Vinicius confirmar quais tipos entram na classe sem revisão financeira (garantia, uso e consumo, bonificação, outros?).
- [ ] Confirmar o prefixo G e se bonificação/uso e consumo têm série própria.
- [ ] Decidir se a data pode ser retroativa e quem pode.
- [ ] Revisar a SPEC-233 inteira à luz desta (a Fase 0 de bloqueio não deve ser aplicada para esses tipos).
- [ ] Verificar o vínculo com o Controle de Garantia (SPEC-156): a garantia do orçamento cria o registro lá?
