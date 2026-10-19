---
titulo: "SPEC-207 — Separação Parcial: busca de item dentro da venda"
status: pendente
data_ultima_modificacao: 2026-10-19
sistemas_envolvidos:
  - Separação Parcial
---

# SPEC-207 — Separação Parcial: busca de item dentro da venda

## Checklist de Ação

- [x] Campo "Buscar item por código, referência, descrição ou L..." acima da tabela de itens da venda (`SeparacaoParcialPage.tsx`)
- [x] Filtro sem diferenciar maiúscula nem acento; botão X limpa
- [x] Contador "N de M linha(s) em X L"
- [x] Rodapé "Total em X L" somando as colunas das linhas filtradas (aparece quando sobra mais de 1 linha)
- [x] Aviso quando uma linha escondida pela busca tem quantidade em "À Separar" (ela continua valendo no Separar)
- [x] Busca zera ao voltar para a lista de vendas
- [x] Publicar (Cloudflare `separacao-lucenera.pages.dev`)

### Passos manuais do usuário

- [ ] Testar numa venda em que a mesma peça está em vários L

## Objetivo

Na venda, a mesma peça aparece em várias linhas, uma por L (local). Para ver a situação de uma peça era preciso
procurar linha a linha. A busca deixa só as linhas da peça e mostra o total dela somando todos os L.

## Decisões aprovadas

- Pedido do usuário em 19/10/2026: "incluir um mecanismo de busca/filtro … ver como está a situação de um determinado item, e no caso ele aparece em vários L".
- Só tela; nada muda no banco.

## Definição da SPEC

- A busca casa com código, referência, descrição ou L (`classificacao`).
- O filtro só esconde linhas. As quantidades já digitadas em "À Separar" ficam guardadas, e o botão Separar continua enviando todas, por isso aparece o aviso.
- O rodapé soma Q. Dev., Q. Venda, E. Futura, Transferido, Reserva, À Separar (o que foi digitado), Ag. Separar, Separado e Entregue.

## Realizado

### 2026-10-19

- Implementado em `separacao-parcial/src/pages/SeparacaoParcialPage.tsx`; `tsc` sem erros e `vite build` ok.

## Pendências

- [ ] Teste do usuário na Separação Parcial com uma venda que tenha a mesma peça em vários L.
