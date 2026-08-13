---
titulo: "SPEC-091 — Gerar PDF automaticamente ao clicar em Separar"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.2)
  - 03-Projeto/Planos de Ação/SPECs/SPEC-093_Layout_Impressao_Lista_Entrega.md (mesma implementação, unificadas)
---

# SPEC-091 — Gerar PDF automaticamente ao clicar em Separar

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [05:37]-[06:35]). Catalogado como item 2.2 na SPEC-086. Unificada com a
> SPEC-093 (mesmo documento resolve as duas).

## Checklist de Ação

- [x] Definir conteúdo do documento (cabeçalho venda/cliente/projeto/data +
      tabela código/referência/descrição/quantidade)
- [x] Implementação via impressão nativa do navegador (`window.print()`),
      não Edge Function/`pdf-lib` — decisão tomada na implementação (ver
      "Mudança de abordagem" abaixo)
- [x] `handleSeparar` em `SeparacaoParcialPage.tsx` abre e imprime
      automaticamente assim que a separação é confirmada

## Objetivo

Hoje `handleSeparar` em `SeparacaoParcialPage.tsx` só grava a separação no
banco (`criarSeparacaoParcial`) e mostra um toast de sucesso — não gera
nenhum arquivo. O Vinícius pediu que, ao clicar em "Separar", o sistema já
gere automaticamente o PDF da lista pro Matheus imprimir e levar pra
separação física.

## Mudança de abordagem (2026-08-13)

O plano original avaliava `pdf-lib` (padrão já usado na SPEC-084) via Edge
Function nova ou client-side. Na implementação, optou-se por uma terceira
via, mais simples e sem dependência nova: abrir uma janela com o documento
formatado em HTML e chamar `window.print()` — o navegador oferece nativamente
"Salvar como PDF" ou impressão direta na mesma caixa de diálogo. Vantagens:
zero biblioteca nova, zero Edge Function nova (o projeto Skip 48801 não
tinha nenhuma), e resolve ao mesmo tempo o layout de impressão pedido na
SPEC-093 — por isso as duas SPECs foram unificadas num único documento
impresso.

## Realizado

### 2026-08-13

- `imprimirListaSeparacao()` em `SeparacaoParcialPage.tsx`: monta um
  documento HTML (cabeçalho com venda/cliente/projeto/responsável/data +
  tabela dos itens separados nessa ação) numa janela nova e chama
  `window.print()` imediatamente.
- Disparado automaticamente dentro de `handleSeparar`, logo após o sucesso
  de `criarSeparacaoParcial` — sem clique extra.
- Publicado Skip 48801, v0.0.20, QA limpo.

## Pendências

Nenhuma.
