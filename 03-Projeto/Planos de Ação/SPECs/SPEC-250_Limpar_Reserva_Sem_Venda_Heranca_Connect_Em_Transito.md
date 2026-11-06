---
titulo: "SPEC-250 — Limpar a reserva sem venda (herança Connect) que ficou em trânsito e está inflando o Estoque Geral"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Banco (Supabase SP) — saldos de estoque por setor, `connect_reserva_ambiente`, `connect_reserva_tratamento`
  - Cadastro (aba de setores da peça), Venda Parcial (Tratar), Movimentação de Peças
---

# SPEC-250 — Limpar a reserva sem venda (em trânsito)

> Origem: reunião 06/11 (min. 38–48 e 105–115). Relacionadas: SPEC-232 (conta de estoque), SPEC-243 (herança e "Tratar"), SPEC-244 (operação paralela).
> **Conflita** com a regra "a herança sem cliente nunca muda" (SPEC-243) e com "Connect é herança, não mexe em quantidade". Precisa de OK explícito antes de implementar.

## Checklist de Ação

- [ ] A. Relatório (só leitura): por peça, a quantidade em "Reserva sem venda (herança Connect)", o Estoque Geral, a Separação e o Disponível, e a conta `Geral − (Separação + Reserva com venda + Disponível)`.
- [ ] B. Função `limpar_reserva_sem_venda_connect(p_itens, p_aplicar boolean default false)` (modo teste devolve o que faria; só a administração/Matheus aplica).
- [ ] C. Log por peça (quem, quando, quantidade, saldo antes e depois). Nada é apagado: o setor fica oculto e o histórico consultável.
- [ ] D. Tela: lista de conferência com botão "Aplicar nos itens marcados" (Cadastro ou Movimentação de Peças).
- [ ] E. Conferência por amostra (Vitória): 10 peças comparadas com a Connect depois que o Matheus baixar as listas.

### Passos manuais do usuário

- [ ] Matheus baixa na Connect as listas de entrega de 05/11 (só depois a Connect desce o Estoque Geral).
- [ ] Vitória confere ~10 peças (itens de teste: 12757, 9931, 9988, 10614) entre os dois sistemas.
- [ ] Responder as perguntas da seção Pendências.

## Objetivo

Peças que estavam em separação na Connect (pedido de entrega já pedido, saiu da Reserva) na hora da carga **não vieram com venda**. No sistema novo elas ficaram em "Reserva sem venda (herança Connect)", somam no Estoque Geral e **nunca vão escoar** (não existe venda para entregá-las). Resultado: o Estoque Geral do sistema novo fica maior que o da Connect depois que a entrega é baixada lá.

## Exemplos da reunião

| Peça | Connect | Sistema novo | Diagnóstico |
|---|---|---|---|
| 12757 | Geral 5, Disponível 4, 1 em separação | Geral 5, Disp. 4, "reserva sem venda" 1 | Quando o Matheus baixar a entrega, a Connect vai a 4/4; o novo continua 5. |
| 9931 | Separação 4 | Geral 6 | Geral = Separação + Reserva + Disponível; 2 unidades sem escoamento. |
| 10614 | 245 disponível | 31 → 27 depois da baixa (4 da Vânia) | Bate quando a lista for baixada. |
| 9988 | (2 un. na lista de ontem) | 83 | Pode ter outras listas; conferir. |

## Decisões aprovadas

- O setor "em trânsito" (aguardando separar / separado) **já existe** nas vendas do sistema; o que faltou foi a herança. Não criar setor novo.
- Regra proposta pelo Vinicius: toda peça em **Reserva sem venda (herança Connect)** sai desse setor **e a mesma quantidade é subtraída do Estoque Geral**. Mesmo efeito do `entregue_baixa_estoque` do Tratar (SPEC-243).
- **Primeiro listar, depois aplicar.** Conferir ~10 itens. Não deletar nada: ocultar e manter log.

## Definição da SPEC

### Cuidado: "sem venda" tem dois significados

A SPEC-243 mediu 7.793 unidades de "reserva sem dono" (sem cliente na planilha). Parte pode ser reserva real de venda da Connect que não foi ligada a cliente, não peça em trânsito. Limpar tudo às cegas pode **zerar reserva legítima**. Por isso:

1. O relatório (A) separa: (a) reserva sem venda **igual** à diferença do Estoque Geral (trânsito provável); (b) o restante (conferir).
2. Só (a) entra no "Aplicar" automático. (b) segue para o Tratar (manual).

### Efeito na conta (por peça, quantidade q)

- Reserva sem venda −q; Estoque Geral −q; Reservado total −q; Separação e Disponível inalterados.
- Movimento no kardex com tipo próprio (ex.: `ajuste_em_transito_connect`) e observação fixa.
- Respeitar `exigir_sem_operacao_paralela`: depois do marco as importações da Connect estão paradas; a função não reimporta nada.

### Ordem

1. Relatório (A) → Pedro entrega a lista ao Matheus/Vitória.
2. Matheus baixa as listas de ontem na Connect.
3. Conferência por amostra.
4. Aplicar (B/D) em lote, com ensaio em ROLLBACK antes e antes×depois do estoque total por setor.

## Critérios de aceite

- Em ensaio com ROLLBACK, as 4 peças de teste ficam com o mesmo Estoque Geral da Connect depois da baixa.
- Estoque total e financeiro antes×depois iguais, exceto pelas quantidades limpas (que somem do Geral e do Reservado na mesma medida).
- A função recusa quem não é Matheus/administração; `anon` sem execução; log gravado.

## Realizado

Nada implementado (SPEC criada em 06/11).

## Pendências

- [ ] Confirmar que "Reserva sem venda" = trânsito para **todas** as peças ou só para as que a conta do Geral mostra diferença (ver cuidado acima).
- [ ] Decidir quem executa: só Matheus e administração (como o Tratar) ou também a Vitória.
- [ ] Ajustar o texto da SPEC-243/244 (regra "herança sem cliente nunca muda") quando esta SPEC for aprovada.
- [ ] Definir se o relatório (A) vira tela permanente ("Divergências Connect × novo") para a conferência periódica.
