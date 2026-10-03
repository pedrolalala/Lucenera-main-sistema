---
titulo: "SPEC-180 — Rodada de testes 03/10: etapa Recebida na devolução, aviso de empresa, correções e desempenho do banco"
status: aplicada e publicada (Orçamentos 32554 v0.0.380, Separação Parcial 48801 v0.0.46 — 03/10)
data_ultima_modificacao: 2026-10-03
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb)
  - Separação Parcial (separacao-parcial)
  - Banco central (devolucoes_estoque, estoque_movimentos_projeto_item, 51 políticas RLS com hub_pode_executar)
dependencias:
  - SPEC-177 / SPEC-178 / SPEC-179
---

# SPEC-180 — Etapa Recebida, aviso de empresa, correções da rodada de testes e desempenho

Decisões do usuário em 03/10/2026, após a rodada de testes das SPECs 176–179.

## 1. Etapa "Recebida" na devolução (migration `20261003_182_devolucao_recebimento`)

- Só devolução de **Entregue** (material com o cliente) passa por ela. Na aprovação: baixa `q_entregue` →
  `q_devolvida` e grava `devolucoes_estoque.status = 'aguardando_recebimento'`, **sem** liberar a reserva do produto.
- Na **Separação Parcial**, botão "Devoluções a receber" (com contador) lista `vw_devolucoes_aguardando_recebimento`;
  "Confirmar recebimento" chama `confirmar_recebimento_devolucao(id, observação)`: libera a reserva (o disponível sobe),
  status `recebida`, `recebido_em/recebido_por/observacao_recebimento`, movimento `devolucao_recebida`.
- Reserva / Em separação / Entrega futura seguem com efeito na aprovação (SPEC-179).
- Dry-run (ROLLBACK): aprovar 2 entregue → reserva 13 inalterada, aparece na lista; confirmar → 11; 2ª confirmação recusada.

## 2. Venda de outra empresa: aviso, sem trava

- A devolução continua herdando empresa/vendedor/arquitetos da venda na 1ª seleção, mas o campo Empresa fica
  editável. Linha de venda de outra empresa pode entrar; aparece aviso na linha e um toast ao escolher; ao salvar,
  toast "Atenção: venda de outra empresa" sem bloquear. Continuam bloqueando: venda sem número e quantidade acima do saldo.

## 3. Correções achadas na rodada de testes

| Bug | Correção |
|---|---|
| Orçamento aberto por link direto/F5 vinha sem arquiteto (salvar podia apagar o vínculo) | `BudgetFormPage` busca `arquitetos`/`arquiteto` no carregamento direto |
| Barra de totais não grudava no rodapé | `Layout.tsx`: `overflow-x-clip` em vez de `overflow-x-hidden` |
| L da venda renumerado na devolução (L15 → L02) | linha de devolução usa o `l_fixo` da venda |
| Previsão de entrega 1 dia antes na impressão da separação | `fmtDia` (data sem fuso) |

## 4. Limpeza de teste (migration `20261003_180_limpar_transferencia_teste`)

As 2 trocas de reserva de teste entre os aros da VENDA-0001 e VENDA-0002 (ida 15/09, volta 22/09) foram apagadas:
2 `transferencias_estoque`, 4 movimentos e `q_transferida_saida` 5 → 0 nos dois itens. Saldos de reserva inalterados.

## 5. Desempenho (migration `20261003_181_rls_hub_pode_executar_uma_vez_por_consulta`)

- Causa principal no banco: 51 políticas RLS chamavam `hub_pode_executar(auth.uid(), …)` (VOLATILE) **por linha** —
  em `produtos` até 3 chamadas × 4.886 linhas, cada uma lendo usuários/papéis/permissões (milhões de seq scans).
- Correção: função `STABLE` e chamadas envolvidas em `(SELECT …)` (avaliadas 1 vez por consulta). Mesmas linhas
  retornadas; usuário sem permissão continua com 0. `rollback.sql` guarda o texto original das 51 políticas.
- Medido: 3 páginas de produtos 1.099 ms → 26 ms (dry-run); no ar, 5 páginas ≈ 50 ms com cache quente.

### Pontos de lentidão que ficam (não alterados)

- Banco em **us-east-2 (Ohio)**: cada requisição do Brasil paga ~150 ms de ida e volta. Migrar para São Paulo
  (sa-east-1) exige criar outro projeto e migrar tudo — decisão do usuário.
- Instância pequena (sem add-on de compute): picos quando o esquema é recarregado (cada publicação/migration
  faz o PostgREST reler o esquema; consultas de até dezenas de segundos em pg_stat_statements).
- A tela de orçamento baixa catálogos inteiros ao abrir (produtos, clientes, projetos, até 50 mil itens da Ubiqua).
- Tarefa agendada `sharepoint-projetos-pull` a cada 5 min (~95 ms cada) e o Realtime (consultas de WAL) rodam sempre.
