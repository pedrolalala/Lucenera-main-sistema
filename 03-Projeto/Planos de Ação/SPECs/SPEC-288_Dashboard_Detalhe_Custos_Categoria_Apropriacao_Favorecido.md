---
titulo: "SPEC-288 — Dashboard Financeiro: detalhe dos custos (categoria → apropriação → favorecido)"
status: pendente
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3)
  - Supabase (view v_financeiro_realizado_novo)
---

# SPEC-288 — Dashboard Financeiro: detalhe dos custos (categoria → apropriação → favorecido)

## Checklist de Ação

- [ ] Banco: coluna `favorecido` (nome do contato do título) no fim da `v_financeiro_realizado_novo` (migration 341).
- [ ] Dashboard: clicar numa categoria da lista "Por categoria" abre uma janela com as apropriações da categoria.
- [ ] Dashboard: clicar numa apropriação mostra para quem foi o dinheiro (favorecido), com número de pagamentos e total.
- [ ] Teste: totais da janela = total da categoria na lista; build e lint sem erro; tela conferida no navegador.

### Passos manuais do usuário

- [ ] Pedro publica o Dashboard: a conta do Filippo não tem escrita no repositório do sistema. Só depois de a migration 341 estar aplicada; antes disso a tela quebra, porque pede a coluna nova.

## Objetivo

Pedido do Filippo (14/11/2026): na lista de custos por categoria (SPEC-286), entrar em cada categoria e ir descendo nos níveis, como na análise do ano. Exemplo: Marketing → PUBLICIDADE → agência, fotógrafo etc. Não é a lista de todos os pagamentos, são totais por nível.

## Decisões aprovadas

- Três níveis: categoria (já existe) → apropriação → favorecido, sempre com totais.
- Segue o filtro de período e empresa da tela. Os totais batem com a lista da categoria.
- **Pessoal mostra também o nome das pessoas**, com o valor (Filippo, 14/11: "sì, anche i nomi"). Quem tem acesso ao Dashboard Financeiro passa a ver salário por pessoa.
- Ordem de publicação (regra de 10/11, reforçada em 14/11): commit → PR → merge na `main` → aplicar migration → publicar o Dashboard.

## Definição da SPEC

### Banco — migration `20261114_341_spec288_favorecido_view_realizado`

- `create or replace view` com a definição que está no ar em 14/11 (pg_get_viewdef) mais `left join contatos c on c.id = t.contato_id` e a coluna `c.nome as favorecido` no fim.
- Mesmos portões (`pode_acessar_sistema('dashboard-financeiro')`, `pode_ver_distribuicao_lucro()`), mesmo dono e mesmos grants (create or replace mantém).
- Ensaio em ROLLBACK (14/11):
  - as 18 colunas antigas ficam **idênticas**, linha a linha (md5 de 18.466 linhas);
  - mesmo número de linhas;
  - 1 despesa sem contato.
  - Em 2026, 100% dos títulos a pagar têm contato.
- `rollback.sql`: DROP + CREATE sem a coluna + grants. Antes, voltar o Dashboard.

### Dashboard

- `src/services/cash-flow.ts`:
  - `favorecido` em `COLUNAS` e em `FinanceiroRow`;
  - em `computeCustosPorCategoria`, cada apropriação ganha `pagamentos` e `favorecidos` (`nome`, `pagamentos`, `total`), do maior para o menor.
- `src/pages/Index.tsx`:
  - a linha da categoria vira clicável e abre um `Dialog` com o total da categoria e o período;
  - a tabela de apropriações mostra valor, % da categoria e nº de pagamentos;
  - clicar na apropriação abre a lista dos favorecidos.

## Realizado

## Pendências
