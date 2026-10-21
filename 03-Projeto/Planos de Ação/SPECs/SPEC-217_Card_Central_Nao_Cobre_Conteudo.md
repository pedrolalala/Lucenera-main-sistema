---
titulo: "SPEC-217 — Card lateral da Central (trocar de sistema) não cobre mais a tela"
status: pendente
data_ultima_modificacao: 2026-10-21
sistemas_envolvidos:
  - Os 12 sistemas que têm o card (SystemSwitcher): Hub, Consultar Produtos/Cadastro, Central de Solicitações,
    Necessidade de Compra, Dashboard Financeiro, RH, Orçamentos, CRM, Sistema de Entregas, Administração Bancária,
    Separação Parcial, Vendas
---

# SPEC-217 — Card da Central não cobre colunas nem a barra de rolagem

## Checklist de Ação

- [x] SystemSwitcher reserva a faixa do card (3rem = largura do card recolhido) no lado direito da página
- [x] `vite build` dos 12 sistemas
- [x] Conferido no Chrome com uma tela no formato de Contas em Aberto: última coluna e barra de rolagem terminam onde o card começa
- [ ] Publicar
- [ ] Sistema de Entregas: publicar no Lovable

### Passos manuais do usuário

- [ ] Adm. Bancária › Contas em Aberto: conferir que a coluna VL Pago aparece inteira
- [ ] Consultar Produtos: conferir a última coluna
- [ ] Notebook (tela menor): conferir que nada fica embaixo do card

## Objetivo

Pedido do usuário em **21/10/2026**: na Necessidade de Compra › Pedidos, o card lateral da Central Lucenera (para
trocar de sistema) não atrapalha — a barra de rolagem aparece à esquerda do card. Na Administração Bancária o card
fica por cima da coluna "VL Pago"; no Consultar Produtos também. Corrigir em todos os sistemas, passando um pente fino.

## Definição da SPEC

- Causa: o card é `fixed` no canto direito (48 px recolhido). Na Necessidade de Compra o conteúdo fica numa coluna
  centralizada de no máximo 1600 px, então em monitor largo sobra espaço à direita para o card; nos outros sistemas o
  conteúdo ocupa a largura toda e o card cobre a última coluna e a barra de rolagem. Em tela menor (notebook) a
  Necessidade de Compra também ficaria coberta.
- Correção (igual nos 12, no próprio `SystemSwitcher.tsx`): enquanto o card aparece (usuário logado), a página
  (`<html>`) ganha `padding-right: 3rem` e `overflow-x: hidden` (as telas de carregamento com `w-screen` não criam
  rolagem lateral). Assim o conteúdo e a rolagem terminam antes do card, em qualquer tamanho de tela, sem mexer tela
  por tela. Card aberto (expandido) continua por cima, só enquanto está aberto.
- Pente fino: os outros 5 sistemas (Catálogo Ubiqua, Garantia, Produção, Memória, Showroom) não têm o card.
- Sem banco.

## Rollback

- Tirar o `useEffect` marcado SPEC-217 do `SystemSwitcher.tsx` do sistema.

## Realizado

### 2026-10-21

- `useEffect` no SystemSwitcher dos 12 sistemas; build ok nos 12.
