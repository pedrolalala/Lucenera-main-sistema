---
titulo: "SPEC-188 — RH: controle de férias igual à planilha (períodos, lançamentos sem data, saldo)"
status: concluído
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - RH Lucenera (dashboard-rh-lucenera-5fe9c, Skip 23919)
  - Supabase (periodos_aquisitivos, ferias, ferias_lancamentos, vw_ferias_periodos, vw_controle_ferias_clt, pg_cron)
---

# SPEC-188 — RH: controle de férias igual à planilha

Substitui a regra provisória da SPEC-186.

## Checklist de Ação

- [x] Migration `20261008_191_ferias_controle_planilha` (tabela `ferias_lancamentos`, colunas `direito_dias`/`formalizacao`, `vw_ferias_periodos`, nova `vw_controle_ferias_clt`, `gerar_periodos_aquisitivos()` + cron diário 06:00 UTC).
- [x] Importar `01-Documento/01 - Planilhas/CONTROLE DE FÉRIAS ATUALIZADO (1).xlsx` (24 abas).
- [x] RH: "Período Aquisitivo Base" mostra o saldo de cada período e sugere o mais antigo com saldo.

### Passos manuais do usuário

- [ ] Lana: conferir os saldos na tela de férias contra a planilha.
- [ ] Corrigir na planilha/sistema as divergências listadas em "Realizado".

## Decisões (2026-10-08)

- A planilha é a fonte da verdade: substitui as férias e períodos existentes das 24 pessoas (cópia em `_bkp_ferias_20261008` / `_bkp_periodos_aquisitivos_20261008`).
- Dias de cada lançamento = saldo anterior − saldo da linha (o número que a Lana controla), não a coluna "Dias".
- Linha com datas cujo intervalo não bate com os dias descontados → vira lançamento sem data com as datas na descrição.
- Saldo por período = direito − férias aprovadas do período − lançamentos do período. Saldo total = soma; negativo de período anterior não conta (já levado como "Residual" no seguinte); negativo do mais recente conta.
- Períodos depois do último da planilha: criados automaticamente quando se completam (fim < hoje), vencimento = fim + 11 meses. PJ não gera. Sem histórico: só o último período completo.
- Admissões corrigidas pela planilha (funcionarios e funcionarios_novo): Thais 28/01/2019, Giovanna Nori 20/06/2023, Lana 12/02/2020, Vitória 27/01/2025. Teresinha → `funcionarios.status = 'Inativo'`.

## Realizado

### 2026-10-08

- Importados 51 períodos, 95 férias com data, 43 lançamentos sem data; 2 períodos gerados (Claudio 08/2025–07/2026, Vinicius 02/2025–02/2026). Conferido como Lana (24 saldos).
- RH Skip 23919 v0.0.231 (`9e63967`) publicado.
- Divergências da planilha (importadas como lançamento sem data, valendo o saldo): Marina 14/01/2025–04/05/2025 (111 dias corridos, desconta 21); Giovanna Nori 19/12/2025–11/01/2026 (24 corridos, desconta 21). Carol: "RESIDUAL FINAL 2025 −3" estava na coluna SALDO (lido como 3 dias consumidos).
- Achado no mesmo dia: o gatilho `handle_new_user` criou 14 funcionários duplicados ao criar as contas da SPEC-187; contas ligadas ao cadastro real (`usuario_id` + e-mail) e duplicados apagados (Rafaela não tinha cadastro: ficou a linha nova, renomeada).

## Pendências

- [ ] Tela para ver/editar os lançamentos sem data (recesso, venda, residual) — hoje só entram pelo banco/importação.
- [ ] Thais está como PJ no cadastro mas tem períodos CLT na planilha (não gera período novo automaticamente).
- [ ] Vitória com saldo −2 (planilha).
