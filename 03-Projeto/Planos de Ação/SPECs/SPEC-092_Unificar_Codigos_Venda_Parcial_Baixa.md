---
titulo: "SPEC-092 — Unificar os códigos de venda, parcial e baixa da Separação"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.6)
---

# SPEC-092 — Unificar os códigos de venda, parcial e baixa

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [04:38]-[05:03]). Catalogado como item 2.6 na SPEC-086.

## Checklist de Ação

- [ ] Decidir o esquema de numeração com o usuário (ver "Decisões
      pendentes")
- [ ] Migration (se aprovado esquema sequencial): coluna
      `numero_parcial` (ou nome definido) em `separacoes`, populada por
      sequence/função
- [ ] Frontend `SeparacaoParcialPage.tsx`: trocar
      `p.id.split('-')[0].toUpperCase()` (fragmento de UUID) pelo código
      real na coluna "Parcial" do histórico

### Passos manuais do usuário

- [ ] Decidir o esquema de numeração antes de implementar

## Objetivo

Durante o teste, o Vinícius aponta 3 códigos diferentes convivendo no mesmo
fluxo — "o da venda é a 3667. A parcial é 3867... esse código podia ser o
mesmo da parcial" — e conclui que o código da "baixa" (separação) devia ser
igual ao da "parcial", não um terceiro número.

## Achado técnico (2026-08-13, confirmado no código)

A tela hoje (`SeparacaoParcialPage.tsx` → tabela "Parciais desta venda")
mostra como "código" da separação isto:

```ts
{p.id.split('-')[0].toUpperCase()}
```

Ou seja, **não existe hoje nenhum código sequencial/de negócio pra
separação** — é só os 8 primeiros caracteres do UUID gerado pelo banco,
sem relação nenhuma com o "código da parcial" (3867) mencionado na reunião
(que parece vir do sistema legado Connect, reimportado ou gerado por outra
lógica). `numero_venda` (o único código "de negócio" que a tabela
`separacoes` já tem) é o número do orçamento/venda, e esse já está correto
e separado — o problema é só a ausência de um código de negócio pra
identificar a separação/parcial em si.

## Decisões pendentes

- **Esquema de numeração**: sequencial simples por tabela (`nextval` de uma
  sequence nova), ou baseado no `numero_venda` (ex.: `numero_venda` + sufixo
  incremental, tipo `3667-1`, `3667-2` pra cada parcial daquela venda)? A
  reunião não deixa claro qual formato o Vinícius espera — os números
  citados (3667, 3867) parecem legado do Connect, não necessariamente o
  padrão a replicar daqui pra frente.
- Esse código novo substitui o uso do `id` (uuid) em toda parte que hoje
  referencia a separação, ou é só um campo de exibição adicional?

## Decisão final (implementação, 2026-08-13)

Sem migration: o código passou a ser **derivado no frontend** a partir do
`numero_venda` + posição sequencial da parcial dentro daquela venda —
`{numero_venda}-P{n}` (ex.: `3667-P1`, `3667-P2`), calculado por ordem
cronológica de criação (estável mesmo com a lista exibida do mais novo pro
mais antigo). Não precisou de coluna nova nem sequence — o `id` (uuid)
continua existindo por trás como chave real, só a exibição mudou.

## Realizado

### 2026-08-13

- `SeparacaoParcialPage.tsx`: `numerosParciais` (useMemo) numera as
  parciais por ordem de criação; coluna "Parcial" na tabela "Parciais desta
  venda" passou a mostrar `{numero_venda}-P{n}` em vez do fragmento de UUID.
- Publicado Skip 48801, v0.0.20 (junto com SPEC-091/093), QA limpo.

## Pendências

Nenhuma.
