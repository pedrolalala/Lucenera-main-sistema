---
titulo: "SPEC-185 — RH: férias sem etapa de aprovação"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - RH Lucenera (dashboard-rh-lucenera-5fe9c, Skip 23919)
  - Supabase (ferias)
---

# SPEC-185 — RH: férias sem etapa de aprovação

## Checklist de Ação

- [x] Nova solicitação de férias grava `status = 'Aprovado'` (VacationForm).
- [x] Tirar os botões Aprovar/Rejeitar da tabela de férias (VacationTable/Ferias).
- [x] Migration `20261008_189_ferias_sem_aprovacao`: default `Aprovado` + pendentes → Aprovado.
- [x] Publicar o RH (Skip 23919).

### Passos manuais do usuário

- [ ] Lana: registrar uma férias nova e conferir que aparece como Aprovado e no calendário.

## Objetivo

Só a Lana usa o RH; ela recebe o pedido de férias por e-mail ou conversa e só registra. A etapa "Pendente → Aprovar" não faz sentido.

## Decisões aprovadas

- (2026-10-08, usuário) Sem aprovação: registrou = aprovado; o que está pendente vira aprovado; tirar o "aprovar".

## Definição

- `ferias.status` default `Aprovado`; o CHECK segue aceitando Pendente/Rejeitado/Cancelado (histórico).
- `vw_controle_ferias_clt` soma só `Aprovado` → férias registradas passam a contar no saldo na hora.
- Em 08/10 havia 1 pendente (Isabella Miguel Jacob, 07/09–11/09/2026) e 12 aprovadas.

## Realizado

### 2026-10-08

- Migration 189 aplicada (dry-run antes; sem trigger em `ferias`): 1 pendente → Aprovado, 13 aprovadas no total.
- RH Skip 23919 v0.0.230 (`9462f43`) publicado; bundle sem "Rejeitar"/"Solicitação marcada como"; nenhuma Edge Function republicada.

## Pendências

- [ ] Nenhuma além do checklist.
