---
titulo: "SPEC-114 — Melhorar busca/seleção de boleto na tela de emissão de nota fiscal"
status: concluído
data_ultima_modificacao: 2026-08-16
sistemas_envolvidos:
  - Admin Bancária (retorno-bancario-bradesco-5392a) — `NotasFiscais.tsx`
dependencias:
  - project_admin_bancaria_tipo_operacao_perfil (achado anterior no mesmo arquivo)
---

# SPEC-114 — Melhorar busca/seleção de boleto na tela de emissão de nota fiscal

> Origem: reunião Vinícius 14/08/2026 ([48:13]-[49:33]).

## Objetivo

Facilitar a seleção do boleto correto ao vincular uma nota fiscal, quando existem várias parcelas (P1, P2, P3...) da mesma venda com valores parecidos — hoje é difícil saber qual boleto é qual. Citação: *"A gente tem que pesquisar aqui pela venda ou pelo nome do cliente."* / *"mas tem três boletos pra gerar no caso... Vão ter três parcelas, o P1, P2 e P3."* — na prática, o Vinícius teve dificuldade real de identificar visualmente qual das 3 parcelas era a certa (chegou a confundir o número do orçamento/projeto com o valor da venda).

## Estado atual confirmado no código

`04-Sistemas/retorno-bancario-bradesco-5392a/src/pages/NotasFiscais.tsx`:

- `fetchBoletosNF()` (linha 131-147) já busca `nosso_numero, numero_documento, nome_pagador, valor, vencimento, orcamento_id, status` filtrando `tipo = 'Nota Fiscal'` — os dados úteis (nome do cliente, vencimento) **já vêm no `select`**, mas a maior parte não é exibida.
- A lista/seleção de boleto (2 lugares no arquivo — `<Select>` linha 383-394 e a lista de cards do modal "Vincular a um Boleto", linha 519-561) mostra só `{nosso_numero} — {valor}`. **Não mostra** `nome_pagador`, `vencimento`, nem qualquer indicação de qual parcela (P1/P2/P3) é.
- **Não existe campo de busca livre** (por venda, por nome de cliente) em nenhum dos dois seletores — é uma lista fixa pra rolar/escolher visualmente.
- Quando `orcamentoId` está presente na URL (linha 140-142), a lista já filtra pra só os boletos daquele orçamento — o que ajuda, mas não resolve o problema quando o próprio orçamento já tem 3 parcelas parecidas.
- Não existe, na tabela `boletos`, um campo explícito de "número da parcela" (P1/P2/P3) nesta leitura — teria que confirmar se esse número existe em algum outro campo (`numero_documento`?) ou se precisa ser derivado/adicionado.

## Proposta (não implementar sem aprovação)

1. Adicionar campo de busca livre (texto) no topo dos dois seletores de boleto, filtrando por `nome_pagador`, `nosso_numero` ou `numero_documento` em tempo real.
2. Exibir, em cada linha/opção, além de `nosso_numero — valor`: `nome_pagador`, `vencimento`, e (se existir ou puder ser derivado) o número da parcela.
3. Confirmar se existe/precisa existir um campo de número de parcela explícito em `boletos` — se não existir, é uma mudança de schema, fora do escopo de só melhorar a busca (reportar como achado separado).

## Análise de ecossistema

- **Depende de**: `boletos` (nosso_numero, nome_pagador, valor, vencimento, orcamento_id, tipo).
- **Afeta**: só a tela de emissão/vinculação de nota fiscal no Admin Bancária. Puramente UX de busca — não muda a regra de vinculação em si.

## Realizado

### 2026-08-16

- Usuário confirmou seguir com a proposta ("vamos corrigir isso com a proposta").
- **P-1 resolvido sem mudança de schema**: como não existe campo de "número de parcela" em `boletos`, o rótulo P1/P2/P3 é derivado no frontend — agrupa os boletos por `orcamento_id` e ordena por `vencimento` crescente (só quando há 2+ boletos no mesmo orçamento; não aparece pra boleto avulso).
- Adicionado `Input` de busca livre (filtra por `nome_pagador`, `nosso_numero` ou `numero_documento`, case-insensitive) nos dois seletores: o `<Select>` do formulário "Registrar Nova Nota" e a lista de cards do modal "Vincular a um Boleto".
- Cada opção/linha agora mostra: badge `P{n}` (quando aplicável), `nosso_numero`, `nome_pagador`, `vencimento` formatado, e `valor` — em vez de só `{nosso_numero} — {valor}`.
- **Achado extra durante o teste ao vivo**: um bug pré-existente (`getOrcamentoFromNota(notas[0])` sem guarda contra `notas[0]` undefined) deixava a tela **inteira em branco** (crash silencioso) sempre que um orçamento tinha boleto mas nenhuma NF registrada ainda — cenário comum, já que boletos costumam existir antes da nota fiscal ser emitida. Corrigido junto (guarda `nota ?`).
- P-2 não se aplicou: a busca por texto livre já resolveu o caso relatado na reunião; não foi pedido filtro adicional por dropdown de venda/projeto.
- Publicado em produção (Skip 36395, v0.0.64). Testado ao vivo com orçamento real de 13 parcelas: labels `P1`..`P13` corretos por ordem de vencimento; busca por "P13" filtrou pra 1 resultado no modal; sem erros no console.

## Pendências

Nenhuma.
