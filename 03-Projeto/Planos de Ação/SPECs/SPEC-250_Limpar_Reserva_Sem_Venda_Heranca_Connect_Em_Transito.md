---
titulo: "SPEC-250 — Limpar a reserva sem venda (herança Connect) que ficou em trânsito e está inflando o Estoque Geral"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Banco (Supabase SP) — saldos de estoque por setor, `connect_reserva_ambiente`, `connect_reserva_tratamento`
  - Cadastro (aba de setores da peça), Venda Parcial (Tratar), Movimentação de Peças
---

# SPEC-250 — Limpar a reserva sem venda (em trânsito)

> Origem: reunião 06/11 (min. 38–48 e 105–115). Relacionadas: SPEC-232 (conta de estoque), SPEC-243 (herança e "Tratar"), SPEC-244 (operação paralela).
> **Conflita** com a regra "a herança sem cliente nunca muda" (SPEC-243) e com "Connect é herança, não mexe em quantidade". Precisa de OK explícito antes de implementar.

## Checklist de Ação

- [x] A. Relatório (só leitura): por peça, a quantidade em "Reserva sem venda (herança Connect)", o Estoque Geral, a Separação e o Disponível — gerado em 06/11: `03-Projeto/Auditoria/SPEC-250_reserva_sem_venda_2026-11-06.csv` (ver Realizado).
- [x] B. Função `limpar_reserva_sem_venda_connect(p_itens jsonb, p_aplicar boolean default false, p_motivo text)` — **rascunho com dry-run OK, NÃO aplicada** (migration 298). Recebe a quantidade POR PEÇA (vinda das listas de entrega), modo teste por padrão, só Matheus/administração.
- [x] C. Log por peça (quem, quando, quantidade, saldo antes e depois): cada baixa grava um movimento em `movimentacoes_peca` (origem "Reserva sem venda (herança Connect)", destino "Baixa (entregue na Connect)", motivo obrigatório). Nada é apagado.
- [ ] D. Tela: lista de conferência com botão "Aplicar nos itens marcados" (Cadastro ou Movimentação de Peças).
- [ ] E. Conferência por amostra (Vitória): 10 peças comparadas com a Connect depois que o Matheus baixar as listas.

### Passos manuais do usuário

- [ ] Aplicar a migration 298 (aguarda o OK e a lista do Matheus).
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

### 2026-11-06 (A — relatório, só leitura; nada alterado no banco)

- **Arquivo:** `03-Projeto/Auditoria/SPEC-250_reserva_sem_venda_2026-11-06.csv` (162 peças com "reserva sem venda" diferente de zero; ordenado do maior para o menor; coluna `obs` marca os itens de teste da reunião, os de muita quantidade e os negativos). Mesma conta do Cadastro (`estoque-sectors.ts`): reservado em `estoque_itens` menos (reserva + entrega futura + separação do sistema e da Connect).
- **Totais:** **160 peças** com reserva sem venda positiva, somando **2.884 un.**; 2 peças negativas (−8 un., a tratar à parte). Faixas: 72 peças de 1 a 5 un. (179 un.), 76 peças de 6 a 50 un. (1.420 un.) e **12 peças com mais de 50 un. (1.285 un., 45% do total)**.
- **Itens de teste da reunião:** 12757 → 1 un. (Geral 5, Disponível 4: bate com o caso "trânsito"); 9931 → 2 un. (Geral 6, Separação 4); 10614 → 4 un. (as 4 da Vânia); **9988 → 83 un.**, mas a lista de entrega citava só **2** — ou seja, a maior parte dessas 83 não é trânsito.
- **Conclusão que muda o desenho:** "limpar tudo que está em reserva sem venda" **não é seguro**. A mesma conta mistura (a) peça em trânsito, que some do Geral quando o Matheus dá baixa na Connect, e (b) reserva legítima da Connect que só não tem cliente associado (a SPEC-243 já media 7.793 un. de "reserva sem dono" na herança). Limpar as 83 do 9988 zeraria reserva real e deixaria o Disponível maior que o verdadeiro.
- **Desenho proposto no lugar do "limpar tudo" (aguarda o seu OK):** a função `limpar_reserva_sem_venda_connect` recebe **a quantidade por peça** vinda das **listas de entrega que o Matheus baixou** (ex.: 12757 → 1, 9931 → 2, 10614 → 4, 9988 → 2), nunca passa da "reserva sem venda" atual da peça e do Estoque Geral, e faz: reserva sem venda −q, Estoque Geral −q (kardex e log como no Tratar). Modo teste primeiro, depois aplicar. Assim a quantidade real vem da lista, e o que não está em lista não é tocado.

## Pendências

- [x] Desenho aprovado em 06/11 (limpeza por quantidade vinda das listas de entrega baixadas, em vez de "limpar tudo").
- [ ] **As listas de entrega de 05/11 são PDFs da Connect, não planilha** (resposta do usuário em 06/11). Falta 1 ou 2 PDFs de exemplo (do Matheus) para eu ler o formato (código da peça e quantidade) e fazer a leitura no navegador, no mesmo padrão do pedido de compra em PDF (SPEC-247): o Matheus escolhe os PDFs, vê a prévia somada por peça (modo teste da função da migration 298) e confirma. Depois, conferir ~10 peças com a Vitória e o OK para aplicar a 298.
- [ ] Confirmar que "Reserva sem venda" = trânsito para **todas** as peças ou só para as que a conta do Geral mostra diferença (ver cuidado acima).
- [ ] Decidir quem executa: só Matheus e administração (como o Tratar) ou também a Vitória.
- [ ] Ajustar o texto da SPEC-243/244 (regra "herança sem cliente nunca muda") quando esta SPEC for aprovada.
- [ ] Definir se o relatório (A) vira tela permanente ("Divergências Connect × novo") para a conferência periódica.

### 2026-11-06 (B e C — migration 298 em rascunho, dry-run OK, NÃO aplicada)

- **Migration 298 (`20261106_298_spec250_limpar_reserva_sem_venda`):** função `limpar_reserva_sem_venda_connect(p_itens, p_aplicar, p_motivo)`. Entrada: `[{"codigo": 12757, "quantidade": 1}, ...]` (`codigo` = código da peça). Por peça: recusa se a quantidade passa da **reserva sem venda** (mesma conta do Cadastro) ou do **Estoque Geral**; ao aplicar, tira `q` do Estoque Geral e do reservado (o Disponível e a Separação não mudam) e registra o movimento. **Tudo ou nada** (uma peça com problema impede todas) e **motivo obrigatório** para aplicar. Modo teste devolve antes/depois por peça. Permissão: `pode_tratar_heranca_connect()` (Matheus e administração); `anon` sem execução.
- **Dry-run com ROLLBACK, como Matheus:** modo teste não grava; 9988 pedindo 84 (tem 83) é recusado; uma boa + uma ruim com aplicar: nada muda; sem motivo recusa; aplicando 12757 (1), 9931 (2) e 10614 (4): Geral 5→4, 6→4 e 213,5→209,5, **Disponível igual**, 3 movimentos registrados, Estoque Geral e reservado totais caíram só 7 (= 1+2+4), financeiro, saldos e reservas por cliente iguais; projetista (Marina) barrada.
- **Para aplicar de verdade falta:** a lista de peças e quantidades das listas de entrega de 05/11 (Matheus/Vitória), conferir ~10 peças e o seu OK para aplicar a 298. Rodar primeiro em modo teste com a lista inteira.
