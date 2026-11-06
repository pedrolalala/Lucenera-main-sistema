---
titulo: "SPEC-255 — Garantia e outras saídas sem cobrança: sem revisão financeira, número próprio (G) e rótulo visível"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1)) — tipo de operação, fluxo de aprovação
  - Venda Parcial / Logística — rótulo e filtro
  - Banco (Supabase SP) — `aprovar_orcamento_financeiro`, numeração de venda
---

# SPEC-255 — Garantia e saídas sem cobrança

> Origem: reunião 06/11 (min. 115–138). **Ajusta a SPEC-233** (ainda "não iniciado"), que previa bloquear a aprovação de "Outros" e "SAC" — o que quebraria o fluxo de garantia que a equipe já usa. Relacionadas: SPEC-234, SPEC-156 (Controle de Garantia).

## Checklist de Ação

- [x] A. A garantia (e uso e consumo, bonificação, e demais saídas sem cobrança da SPEC-233, classe D) **pula a Revisão Financeira**: ao confirmar, vai direto do aprovado pela equipe para a venda.
- [x] B. **Não gera** parcelas, boletos nem financeiro (confirmado no teste); manter.
- [x] C. Número próprio: a garantia aparece como **G + número do orçamento** (ORC-0005 → G0005) na lista e no cabeçalho da Venda Parcial. É só exibição: **não** se gera `numero_venda` (ver Realizado). Outros tipos sem cobrança mostram só o rótulo, sem código próprio, até o Vinicius pedir.
- [x] D. Rótulo "Garantia" (cor amarela) na lista de vendas, na Venda Parcial e na Logística; filtro por tipo.
- [x] E. Garantia **não exige** venda de origem (diferente da devolução): conferido que a regra do banco só exige venda de origem para devolução; na reunião a garantia foi criada e aprovada sem venda de origem (o vermelho era o campo Tipo ainda por escolher).
- [x] F. Ajustar a SPEC-233 (nota de topo na SPEC-233 explicando que a regra por tipo já está no banco via SPEC-234 A e que a Fase 0 de bloqueio não deve ser aplicada): GARANTIA, USO E CONSUMO e BONIFICAÇÃO ficam permitidos, classe D (saída sem cobrança), em vez de bloqueados na Fase 0.
- [ ] G. Data da operação: decidir se pode ser retroativa (a Vitória lançou na Connect na véspera).

### Passos manuais do usuário

- [ ] Aplicar as migrations 295 e 296 e publicar Orçamentos e Venda Parcial (aguarda o OK).
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

### 2026-11-06 (A, B, C, D, E, F — migrations 295 e 296 em rascunho com dry-run OK, NÃO aplicadas; código commitado, NÃO publicado)

- **Descoberta ao ler o banco:** a SPEC-234 A **já está no ar** (a SPEC-233 ficou "não iniciado" no papel): `aprovar_orcamento_financeiro` desvia Outros/SAC para `_aprovar_operacao_sem_financeiro` e `tipo_operacao_regra` classifica os tipos — **saída ao cliente** (GARANTIA, OUTRAS SAIDAS, BONIFICACAO, CASA COR SAIDA), **baixa direta** (USO E CONSUMO, DESCARTE) e **só nota** (REMESSA TRANSP, SAIDA INDUSTRIALIZACAO, REMESSA CONSERTO, DEV EM GARANTIA). Essas operações **não geram parcela, boleto nem número de venda** (o ORC-0005, garantia de teste, está aprovado sem número de venda). Por isso o item B já estava feito e o código "G" **não** vira `numero_venda`: um número de venda marcaria a garantia como venda efetivada e a deixaria virar origem de devolução (a regra de devolução exige `numero_venda`).
- **Migration 295 (`20261106_295_spec255_garantia_sem_revisao_financeira`):** `equipe_aprovar_orcamento` passa a chamar `_aprovar_operacao_sem_financeiro` logo depois da aprovação da equipe quando a regra é saída ao cliente, baixa direta ou só nota. Venda, devolução, empréstimo e tipo sem regra seguem como antes. Falha da operação (ex.: baixa maior que o Estoque Geral) desfaz a aprovação inteira. Dry-run com ROLLBACK, como admin, numa cópia da garantia: foi direto para "Orçamento Aprovado" (histórico: Aprovação da Equipe → Aprovação Financeira → Orçamento Aprovado), 0 boletos, 1 item de projeto criado, sem número de venda; uma venda comum continuou indo para a Aprovação Financeira (`requer_revisao_financeira = true`).
- **Migration 296 (`20261106_296_spec255_lista_venda_tipo_operacao`):** acrescenta `natureza_operacao` e `subgrupo` ao fim de `vw_venda_parcial_lista` (colunas antigas iguais; `security_invoker` e permissões mantidos; 316 linhas antes e depois).
- **Orçamentos (commit 34879ac):** mensagem na aprovação da equipe: "Operação sem cobrança: não passa pela revisão financeira e não gera financeiro" quando a função devolve `sem_revisao_financeira`.
- **Venda Parcial (commit 93c6e79):** rótulo amarelo com o tipo ("Garantia"...) e código **G0005** na lista e no cabeçalho da venda; venda comum não muda.
- `tsc` sem erro novo; builds ok só com São Paulo.

## Pendências

- [ ] Aplicar 295 e 296 e publicar (aguarda o OK). **Ordem:** a 296 antes de publicar a Venda Parcial (a tela lê as colunas novas).
- [ ] Avisar o Matheus: a garantia aprovada por ele já nasce "Orçamento Aprovado" (sem fila do financeiro) e sai do Estoque na hora; para a regra de baixa direta (uso e consumo, descarte) a aprovação falha se o Estoque Geral não cobrir.
- [ ] Item G (data retroativa): hoje o orçamento usa a data do dia; não foi alterado.
- [ ] Vinicius confirmar quais tipos entram na classe sem revisão financeira: a 295 aplicou aos 3 grupos do banco (saída ao cliente, baixa direta, só nota); se algum deve continuar passando pela Lana/Carol, é só tirar da lista.
- [ ] Confirmar o prefixo G e se bonificação/uso e consumo têm série própria.
- [ ] Decidir se a data pode ser retroativa e quem pode.
- [ ] Revisar a SPEC-233 inteira à luz desta (a Fase 0 de bloqueio não deve ser aplicada para esses tipos).
- [ ] Verificar o vínculo com o Controle de Garantia (SPEC-156): a garantia do orçamento cria o registro lá?
