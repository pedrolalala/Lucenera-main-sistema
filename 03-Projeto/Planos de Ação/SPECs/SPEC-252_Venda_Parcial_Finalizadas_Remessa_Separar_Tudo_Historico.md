---
titulo: "SPEC-252 — Venda Parcial: vendas finalizadas em destaque, remessa de transporte em aba separada, Separar tudo, histórico de entregas e entregas antigas sem lista"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Venda Parcial (04-Sistemas/separacao-parcial)
  - Logística (lucenera-logistics) — só para ligar o histórico
  - Banco (Supabase SP) — leitura de saldos por venda; classificação de remessa de transporte
---

# SPEC-252 — Venda Parcial: visual e fluxo

> Origem: reunião 06/11 (min. 48–61, 93–101). Relacionadas: SPEC-235, SPEC-243 (Tratar e "entregue, estoque já ajustado"), SPEC-244 (liberar herança sem data para separar), SPEC-234 (NF de remessa).

## Checklist de Ação

- [ ] A. **Vendas finalizadas** (nada mais a entregar) continuam na mesma lista, mas **esmaecidas (cinza)** ou com **tag verde "Finalizado"**, no fim ou no mesmo lugar. Sem guia nova.
- [ ] B. **Remessa de transporte** (venda criada só para emitir NF de remessa, tipo "Outros → Remessa transporte") sai da lista das equipes e vai para uma **aba própria de consulta** (Matheus e Vinicius).
- [ ] C. Botão **Separar tudo** na venda (pedido do Vinicius): preenche a quantidade de todos os itens com o que está em Reserva, respeitando o limite de cada item.
- [ ] D. **Histórico de entregas dentro da venda**: cada parcial com data solicitada, data prevista e data entregue, e o acesso à lista (sem depender de salvar PDF em pasta).
- [ ] E. Estorno parcial antes da entrega (já existe, com motivo): conferir que o item volta para Reserva e que o Matheus é avisado da lista corrigida.
- [ ] F. **Entregas antigas sem lista de entrega** (ver abaixo): decisão e tratamento.
- [ ] G. Venda pesquisada por cliente com várias vendas: ver rápido quais ainda têm pendência (efeito de A).

### Passos manuais do usuário

- [ ] Decidir a regra do item F.
- [ ] Mostrar à equipe como pedir a separação (a reunião mostrou mas não executou).

## Objetivo

Deixar a Venda Parcial legível para quem tem muitas vendas do mesmo cliente, retirar ruído (remessa de transporte) e fechar buracos do processo de separação.

## Decisões aprovadas (reunião)

- Finalizadas **na mesma tela**, com cor e tag (a ideia de uma guia "Finalizadas" foi descartada).
- Remessa de transporte em **aba separada**: ninguém da equipe consulta; é registro de movimentação.
- Entrega continua sendo registrada no Logística (finalizados, foto da folha assinada); a Venda Parcial mostra o resumo por parcial.
- Não copiar o hábito de "salvar o PDF numa pasta do computador": o importante é ver a lista no sistema.

## Definição da SPEC

### F — Entregas antigas sem lista (ponto em aberto)

Situação: vendas importadas da Connect com Reserva, cuja mercadoria **já foi entregue** sem nunca ter feito a lista de entrega. O Estoque Geral já está descontado ("a foto do estoque é com ela entregue"). Se a equipe fizer a separação até o fim, o sistema gera uma saída **irreal** (ex.: 100 em estoque que já não têm os 20 entregues → 80).

Duas falas na reunião:

1. "Não pode gerar a saída: tem que eliminar isso."
2. "Pode fazer a baixa normal; o disponível deve ser zero ou é do showroom; mas tem que fazer na Connect também."

Já existe a ação do **Tratar** (SPEC-243): `entregue_estoque_ja_ajustado` (Reserva −q, Entregue +q, Estoque Geral sem mudança). Proposta: usar essa ação para esses casos, por Matheus, após conferir na planilha a data da entrega. Se o Matheus preferir que as meninas façam, abrir a ação para a Vitória.

### Efeito de C (Separar tudo)

Respeitar a liberação da SPEC-244: na venda da Connect, só itens liberados (Reserva sem data) entram no "tudo". Itens com data na Connect ficam de fora, com aviso.

### Remessa de transporte (B)

Critério para identificar: orçamento com tipo de operação "Outros → Remessa transporte" (SPEC-233/234). A aba nova lista essas vendas com cliente, data e NF.

## Critérios de aceite

- Venda totalmente entregue aparece cinza/tag em qualquer pesquisa por cliente; as com pendência aparecem normais.
- Venda de remessa de transporte não aparece na lista da equipe e aparece na aba nova.
- "Separar tudo" não permite quantidade acima da Reserva e ignora itens bloqueados da Connect.
- Para uma entrega antiga tratada, o Estoque Geral não muda e o histórico mostra quem tratou.

## Realizado

Nada implementado.

## Pendências

- [ ] Decidir a regra do item F (usar Tratar `entregue_estoque_ja_ajustado` por Matheus × liberar para Vitória × outra).
- [ ] Confirmar o aviso ao Matheus quando alguém estorna uma lista que ele já recebeu.
- [ ] Confirmar com o Matheus se o histórico por parcial na Venda Parcial substitui a consulta em "Finalizados" da Logística ou só complementa.
- [ ] Confirmar o tipo exato usado para identificar a remessa de transporte no banco.
