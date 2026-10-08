---
titulo: "SPEC-186 — RH: saldo de férias pelo último período aquisitivo (regra provisória)"
status: pendente
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - RH Lucenera (dashboard-rh-lucenera-5fe9c) — só leitura da view, sem código novo
  - Supabase (vw_controle_ferias_clt)
---

# SPEC-186 — RH: saldo de férias pelo último período aquisitivo (regra provisória)

## Checklist de Ação

- [x] Migration `20261008_190_saldo_ferias_ultimo_periodo` (view recalculada pela admissão).
- [ ] Regra definitiva a partir do PDF de controle de férias que o usuário vai anexar (períodos e saldos reais por pessoa, inclusive férias tiradas antes do sistema).

### Passos manuais do usuário

- [ ] Anexar o PDF de controle de férias atual.
- [ ] Corrigir a admissão da Vitória Lidia da Silva (cadastrada como ano 205).

## Objetivo

Na tela de registrar férias o saldo vinha 0 para quase todos: a view só somava 30 dias por linha cadastrada à mão em `periodos_aquisitivos` (7 pessoas, 1 período cada).

## Decisões aprovadas

- (2026-10-08, usuário) Regra provisória "último período completo": cada 12 meses desde a admissão = 1 período; conta só o último período completo (30 dias) menos as férias Aprovadas que começam depois do fim dele. Menos de 1 ano de casa = 0.

## Definição

- `vw_controle_ferias_clt`: funcionários `status = 'Ativo'`, CLT (PJ fora), admissão válida (≥ 1950). Colunas antigas mantidas (`direito_total_acumulado`=30, `total_gozado`, `saldo_disponivel`); novas: `periodo_inicio`, `periodo_fim`, `data_limite_gozo` (= fim + 12 meses — o aviso "férias a vencer" da página inicial já lia essa coluna, que não existia).
- `periodos_aquisitivos` deixa de ser usada no saldo (a tela de registro ainda lista os períodos cadastrados para vincular).
- Limitação: férias tiradas antes do sistema não estão registradas; quem tirou férias do último período fora do sistema aparece com 30.

## Realizado

### 2026-10-08

- Migration 190 aplicada (dry-run antes): 21 pessoas com saldo, todas 30 (nenhuma férias registrada depois do fim do último período). Conferido como usuário autenticado (Lana).
- Achado: o registro de férias da Isabella (07–11/09/2026) foi excluído entre 12h50 e 13h10 de 08/10 — não pela migration 189 (que só mudou o status). Não recriado.

## Pendências

- [ ] Substituir a regra provisória pela do PDF (SPEC nova ou revisão desta).
- [ ] Confirmar se a exclusão das férias da Isabella foi intencional.
