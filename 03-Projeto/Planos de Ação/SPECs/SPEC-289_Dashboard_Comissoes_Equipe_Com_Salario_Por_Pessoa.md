---
titulo: "SPEC-289 — Dashboard Financeiro: comissões da equipe com o salário de cada pessoa"
status: pendente
data_ultima_modificacao: 2026-11-14
sistemas_envolvidos:
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3)
---

# SPEC-289 — Dashboard Financeiro: comissões da equipe com o salário de cada pessoa

## Checklist de Ação

- [x] Dashboard: na janela de detalhe da categoria "Comissões da equipe" (SPEC-288), tabela por pessoa: Comissão, Salário, Vale transporte e Total, com linha de total da equipe.
- [x] Teste: comissão total da tabela = total da categoria; build e lint sem erro; tela conferida no navegador.

### Passos manuais do usuário

- [ ] Pedro publica o Dashboard junto com a SPEC-288 (dois commits no mesmo arquivo de patch).

## Objetivo

Pedido do Filippo (14/11/2026): ver nas comissões da equipe, ao lado da comissão, o salário da mesma pessoa, a soma dos dois e o total de quanto a equipe custa.

## Decisões aprovadas (Filippo, 14/11/2026)

- **Só o Dashboard muda.** O banco não muda: a coluna `favorecido` da `v_financeiro_realizado_novo` (SPEC-288) já liga comissão e salário à mesma pessoa (mesmo contato).
- **Quem aparece:** quem recebeu PRÊMIO DE VENDAS no período e na empresa da tela.
- **Colunas:**
  - Comissão: PRÊMIO DE VENDAS.
  - Salário: SALARIOS E ORDENADOS, FÉRIAS, 13° SALARIO, ACERTOS e VALE DE FUNCIONARIO.
  - Vale transporte: VALE TRANSPORTE.
  - Total: a soma das três colunas.
- **Fica fora, com aviso na tela:**
  - INSS (DARF/GPS) e FGTS. São pagos numa guia única da empresa e não dá para separar por pessoa. O custo real de cada um é um pouco maior.
  - Treinamento, lanches, uniformes etc. Não são por pessoa.
- O salário continua contado na categoria Pessoal. Esta tabela só mostra lado a lado e não muda nenhum total da tela.

## Definição

- `src/services/cash-flow.ts`:
  - a função `computeRemuneracaoEquipe(rows)` devolve `{ nome, comissao, salario, valeTransporte, total }` por pessoa, do maior total para o menor;
  - usa as mesmas linhas da lista de categorias (despesa operacional paga, filtro da tela).
- `src/pages/Index.tsx`:
  - quando a categoria aberta é `comissoes`, a janela mostra a tabela por pessoa no lugar da tabela de apropriações (que lá tem uma linha só);
  - nas outras categorias a janela não muda.

## Realizado

### 2026-11-14

- Dashboard: commit `63a1808` no branch `spec/288-detalhe-custos` (em cima do `b02951a` da SPEC-288). Build e lint sem erro.
- Tela conferida no navegador com dados de 2026:
  - 13 pessoas;
  - soma das comissões R$ 976.671,39 = total da categoria;
  - total da equipe R$ 1.476.348,59 (comissão 976.671,39 + salário 454.401,90 + VT 45.275,30);
  - Marketing e as outras categorias continuam com a tabela de apropriações.
- Patch único 288 + 289 em `~/Desktop/Para-Pedro/SPEC-288-289-dashboard.patch`, com o PDF `SPEC-288-289-publicar-dashboard.pdf`.
  - Aplicado numa cópia limpa do `18b37ba`: resultado idêntico ao testado.
  - Os arquivos só da 288 foram retirados da pasta, para o Pedro não aplicar os dois.

## Pendências

- [ ] Pedro publica o Dashboard (aplica o patch 288 + 289 na `main` do sistema). Depois, atualizar o ponteiro do submodule no repositório central e mudar esta SPEC e a 288 para `concluído`.
