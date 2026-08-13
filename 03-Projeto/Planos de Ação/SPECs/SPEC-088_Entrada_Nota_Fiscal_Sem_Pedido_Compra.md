---
titulo: "SPEC-088 — Entrada de nota fiscal de compra sem pedido de compra vinculado"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Compras / Necessidade de Compra
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.1)
  - 03-Projeto/Planos de Ação/SPECs/SPEC-066_Estrutura_Compras_Fornecedor_Marca_Medida_Fina_Entrada_Nota_Fiscal.md
---

# SPEC-088 — Entrada de nota fiscal de compra sem pedido de compra vinculado

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.01`,
> [11:52]-[12:54]). Catalogado como item 2.1 na SPEC-086.

## Checklist de Ação

- [x] Migration: `pedido_compra_id` em `notas_fiscais_compra` vira `nullable`
- [x] Migration: adicionar `fornecedor_id uuid REFERENCES contatos(id)`,
      `empresa_id uuid REFERENCES empresas(id)` e
      `produto_id uuid REFERENCES produtos(id)` (todos nullable) — só
      preenchidos quando `pedido_compra_id IS NULL`
- [x] Migration: CHECK garantindo que ou `pedido_compra_id` ou
      `fornecedor_id` está preenchido (nunca os dois nulos)
- [x] Frontend `EntradaNotaFiscal.tsx`: alternância "Tenho o número do
      pedido" / "Não tenho pedido (entrada avulsa)" antes do passo 1; no
      modo avulso troca a busca por pedido por busca de fornecedor
      (`getFornecedores`, mesma RPC fuzzy já usada em Pedidos), select de
      empresa e busca opcional de produto
- [x] `services/notas-fiscais-compra.ts`: `criarNotaFiscalCompra` aceita
      `pedido_compra_id: null` + `fornecedor_id`/`empresa_id`/`produto_id`
      no modo avulso; nova `buscarProdutosParaEntrada`
- [x] Histórico ("Últimas entradas"): mostra "Avulsa (sem pedido)" na coluna
      Pedido quando não há `pedido_compra_id`, com fornecedor/empresa vindo
      direto das novas colunas (fallback pro join do pedido quando existe)

### Passos manuais do usuário

- [x] Migration aplicada em produção (2026-08-13, confirmado pelo usuário)

## Objetivo

Hoje `EntradaNotaFiscal.tsx` (Compras/Necessidade de Compra) só libera o
formulário de registro depois de localizar um pedido de compra existente —
se a busca não encontra nada, o usuário fica travado, só com a mensagem
"Nenhum pedido encontrado". Na reunião, o Vinícius deu um caso real: "Estou
trazendo a Flos. Não tem pedido de compra no sistema. Uma hora eu vou ter
que dar entrada." — ou seja, existem compras que entram fisicamente sem
nunca ter passado por um pedido de compra formal no sistema, e mesmo assim
precisam de uma entrada de NF registrada. O próprio Vinícius já antecipa
como vai funcionar na prática: "a Débora vai ter que linkar com uma peça"
depois — ou seja, o vínculo com o produto pode acontecer em um segundo
momento, não necessariamente no mesmo formulário.

## Decisões aprovadas

- Precisa existir um caminho pra registrar uma entrada de NF sem pedido de
  compra vinculado.
- O vínculo com fornecedor deve ser explícito nesse fluxo (já que não vem
  mais do pedido) — buscar em `contatos WHERE tipo='fornecedor'`, mesmo
  padrão já usado em `FornecedorModal.tsx` (SPEC-066/075).

## Decisões tomadas na implementação

- Produto fica opcional no modo avulso — se a Débora não souber a peça na
  hora, salva sem e completa depois editando (não construímos tela de
  edição separada nesta rodada; o dado já fica gravável via
  `notas_fiscais_compra.produto_id`, edição futura é só UI).
- Entrada avulsa é sempre 1 produto (não array de itens) — bate com o
  relato da reunião, que só menciona 1 peça por vez.
- Empresa também virou campo direto no modo avulso (não estava no escopo
  original da SPEC-086, mas é necessária pra manter a mesma informação que
  o modo "com pedido" mostra via join) — mesma tabela `empresas` já usada
  em `getEmpresas()` (Pedidos de Compra).

## Definição da SPEC

### Estado atual (confirmado em banco, 2026-08-13)

```
notas_fiscais_compra.pedido_compra_id uuid NOT NULL REFERENCES pedidos_compra(id)
```

`pedido_compra_id` é hoje a única forma de a tabela existir — não há coluna
de fornecedor nem de produto direto. Isso bate exatamente com o
comportamento observado em `EntradaNotaFiscal.tsx`: o form de "2. Registrar
nota fiscal" só renderiza dentro de `{pedido && (...)}`.

### Migration proposta

```sql
ALTER TABLE public.notas_fiscais_compra
  ALTER COLUMN pedido_compra_id DROP NOT NULL,
  ADD COLUMN fornecedor_id uuid REFERENCES public.contatos(id),
  ADD COLUMN produto_id uuid REFERENCES public.produtos(id),
  ADD CONSTRAINT notas_fiscais_compra_origem_check
    CHECK (pedido_compra_id IS NOT NULL OR fornecedor_id IS NOT NULL);
```

### Frontend

`EntradaNotaFiscal.tsx` ganha um toggle no topo do card "1. Localizar
pedido" — "Tenho o número do pedido" / "Não tenho pedido (entrada avulsa)".
No modo avulso, troca a busca por pedido por um `SearchableSelect` de
fornecedor (obrigatório) + um de produto (conforme decisão pendente acima).
O restante do formulário (número da NF, data, valor, anexo, observação)
permanece igual.

## Realizado

### 2026-08-13

- Migration `20260813_103_notas_fiscais_compra_sem_pedido` aplicada em
  produção.
- `EntradaNotaFiscal.tsx` e `services/notas-fiscais-compra.ts` publicados
  no Skip (projectId 40326), versão 0.0.61, QA limpo, produção publicada.
- Smoke-test da query de embed (`fornecedor:contatos!fornecedor_id`,
  `empresa:empresas!empresa_id`) direto via REST contra produção — sem erro
  de ambiguidade de FK.
- Commit/push no submodule `compras-lucenera-3o23t98ee` (`4e52876`).

## Pendências

Nenhuma. Não existe ainda tela de edição pra completar o vínculo de produto
depois de criada a entrada avulsa — se isso virar necessidade real (Débora
frequentemente deixando em branco), é um item pequeno futuro, não bloqueia
esta SPEC.
