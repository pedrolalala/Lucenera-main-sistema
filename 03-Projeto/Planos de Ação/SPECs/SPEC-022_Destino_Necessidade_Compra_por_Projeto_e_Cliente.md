---
titulo: "SPEC-022 — Destino da Necessidade de Compra por Projeto e Cliente"
status: planejado
data_ultima_modificacao: 2026-07-13
sistemas_envolvidos:
  - Supabase (banco central)
  - compras-lucenera-3o23t98ee (Necessidade de Compra)
dependencias:
  - SPEC-010 (estoque_saldos_projeto_item — fonte dos saldos por projeto_item_id)
  - SPEC-012 (vw_necessidade_compra — view de resumo já em produção)
---

# SPEC-022 — Destino da Necessidade de Compra por Projeto e Cliente

> A tela de Necessidade de Compra exibe o déficit total por produto, mas não
> mostra **para quem** o item vai. Esta SPEC adiciona a camada de detalhe:
> quais projetos e clientes estão aguardando cada produto em déficit.
>
> Alinhado com a RN-03 da SPEC-012: a compra não fica amarrada a um cliente
> fixo. O detalhe é **informação de contexto** para o comprador — não uma
> obrigação de destino.

---

## Checklist de Ação

### Backend
- [ ] Criar migration `20260713_038_spec022_necessidade_compra_detalhe`
- [ ] Criar view `vw_necessidade_compra_detalhe`
- [ ] `GRANT SELECT` para `authenticated`
- [ ] Aplicar no Supabase SQL Editor

### Frontend (`compras-lucenera-3o23t98ee`)
- [ ] Criar `src/services/necessidade-compra-detalhe.ts` (tipo + query)
- [ ] Criar `src/components/compra/NecessidadeCompraDetalhe.tsx` (sub-tabela expansível)
- [ ] Modificar `src/pages/NecessidadeCompra.tsx`: linhas expansíveis pelo contador de projetos
- [ ] Testar: expandir linha com 1 projeto, com vários, com `q_reserva` e `q_entrega_futura` diferentes
- [ ] Testar: produto sem `estoque_saldos_projeto_item` não quebra a view

---

## Objetivo

Quando a compradora vê que "PLAFON EMBUTIR LUZ DIFUSA — déficit 12 unidades",
ela precisa saber:

- Quais projetos geraram essa demanda
- Qual cliente está aguardando
- Quantas unidades cada projeto precisa (e se já está coberto ou não)

Essa informação permite priorizar o pedido de compra e comunicar prazos ao
cliente antes do material chegar.

---

## Diagnóstico da estrutura atual

```
estoque_itens (produto_id, quantidade, quantidade_reservada)
    → agregado por produto_id
    → não sabe de qual projeto veio cada reserva

projeto_itens (id, projeto_id, produto_id, quantidade, orcamento_id)
    → criado na aprovação do orçamento
    → é o elo entre produto e projeto

estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura, …)
    → saldo operacional detalhado por projeto_item_id
    → q_entrega_futura = quantidade sem cobertura física (= o que precisa comprar)
    → q_reserva = já coberto pelo estoque mas comprometido com esse projeto
```

O join completo para saber "quem espera o quê":

```
estoque_itens (produto_id, quantidade_reservada > quantidade)  ← filtra déficit
    ↓ produto_id
projeto_itens (produto_id → projeto_id, orcamento_id, quantidade)
    ↓ id → projeto_item_id
estoque_saldos_projeto_item (q_reserva, q_entrega_futura, status_operacional)
    ↓ projeto_id
projetos (codigo, nome)
    ↓ cliente_id / client_id
contatos (nome)   ← "para quem vai"
```

Esse caminho existe no banco — só faltava uma view que o exponha.

---

## Definição da SPEC

### View nova: `vw_necessidade_compra_detalhe`

Uma linha por `(produto_id, projeto_item_id)`. Só aparece quando:
1. O produto está em déficit (`quantidade_reservada > quantidade` em `estoque_itens`)
2. O saldo do item está ativo e tem reserva ou entrega futura

```sql
-- Migration: 20260713_038_spec022_necessidade_compra_detalhe/001_view_detalhe.sql

DROP VIEW IF EXISTS public.vw_necessidade_compra_detalhe;

CREATE VIEW public.vw_necessidade_compra_detalhe
WITH (security_invoker = true)
AS
-- Produtos em déficit real (fonte: estoque_itens)
WITH deficit AS (
    SELECT
        produto_id,
        SUM(quantidade)           AS qtd_estoque,
        SUM(quantidade_reservada) AS qtd_reservada
    FROM public.estoque_itens
    GROUP BY produto_id
    HAVING SUM(quantidade_reservada) > SUM(quantidade)
)
SELECT
    -- Produto
    d.produto_id,
    p.codigo_produto                                        AS produto_codigo,
    p.nome                                                  AS produto,

    -- Totais do déficit (repetido em cada linha para facilitar o frontend)
    d.qtd_estoque,
    d.qtd_reservada,
    GREATEST(0, d.qtd_reservada - d.qtd_estoque)           AS deficit_total,

    -- Projeto / orçamento
    pi.id                                                   AS projeto_item_id,
    pr.codigo                                               AS projeto_codigo,
    pr.nome                                                 AS projeto_nome,
    o.numero                                                AS orcamento_numero,

    -- Destino: cliente que aguarda o item
    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)    AS cliente_id,
    c.nome                                                  AS cliente,

    -- Quantidades por projeto
    pi.quantidade                                           AS qtd_vendida,
    esp.q_reserva,
    esp.q_entrega_futura

FROM deficit d
JOIN public.produtos p
    ON  p.id = d.produto_id
   AND  p.ativo = true
JOIN public.projeto_itens pi
    ON  pi.produto_id = d.produto_id
JOIN public.estoque_saldos_projeto_item esp
    ON  esp.projeto_item_id = pi.id
   AND  esp.status_operacional = 'ativo'
   AND  (esp.q_reserva > 0 OR esp.q_entrega_futura > 0)
LEFT JOIN public.projetos pr
    ON  pr.id = pi.projeto_id
LEFT JOIN public.orcamentos o
    ON  o.id = pi.orcamento_id
LEFT JOIN public.contatos c
    ON  c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id)

ORDER BY deficit_total DESC, p.nome, pr.codigo;

COMMENT ON VIEW public.vw_necessidade_compra_detalhe IS
'SPEC-022. Uma linha por (produto_id, projeto_item_id) para produtos em deficit.
Exibe projeto, cliente e quantidades por item para o modulo de Compras.
SECURITY INVOKER — respeita RLS das tabelas base.';

GRANT SELECT ON public.vw_necessidade_compra_detalhe TO authenticated;
```

### Interpretação das colunas de quantidade

| Coluna | Significado operacional |
|--------|------------------------|
| `qtd_vendida` | Quantidade total vendida nesse projeto_item (imutável após aprovação) |
| `q_reserva` | Já coberto pelo estoque físico — comprometido com este projeto |
| `q_entrega_futura` | **Não tem cobertura física** — é o que este projeto contribui para a necessidade de compra |
| `deficit_total` | Déficit total do produto (soma de todos os projetos) |

> **Regra:** `q_entrega_futura` de um projeto_item é a sua contribuição direta
> ao `necessidade_compra` da view de resumo. Se a soma de `q_entrega_futura`
> de todos os projetos de um produto for > 0, ele aparece na necessidade de compra.

---

### Serviço TypeScript

```typescript
// src/services/necessidade-compra-detalhe.ts

import { supabase } from '@/lib/supabase/client'

export interface NecessidadeCompraDetalheRow {
  produto_id: string
  produto_codigo: string | null
  produto: string
  qtd_estoque: number
  qtd_reservada: number
  deficit_total: number
  projeto_item_id: string
  projeto_codigo: string | null
  projeto_nome: string | null
  orcamento_numero: string | null
  cliente_id: string | null
  cliente: string | null
  qtd_vendida: number
  q_reserva: number
  q_entrega_futura: number
}

export async function getNecessidadeCompraDetalhe(
  produtoId: string,
): Promise<NecessidadeCompraDetalheRow[]> {
  const { data, error } = await (supabase as any)
    .from('vw_necessidade_compra_detalhe')
    .select('*')
    .eq('produto_id', produtoId)
    .order('q_entrega_futura', { ascending: false })

  if (error) throw error
  return (data ?? []) as NecessidadeCompraDetalheRow[]
}
```

---

### Componente `NecessidadeCompraDetalhe.tsx`

Sub-tabela que aparece quando o usuário expande uma linha de produto.

**Colunas:**

| Coluna | Campo | Observação |
|--------|-------|------------|
| Projeto | `projeto_codigo` + `projeto_nome` | código em badge, nome ao lado |
| Orçamento | `orcamento_numero` | — |
| Cliente | `cliente` | "para quem vai" |
| Qtd. vendida | `qtd_vendida` | quantidade total do item aprovado |
| Coberto | `q_reserva` | já tem estoque alocado |
| A comprar | `q_entrega_futura` | em vermelho — sem cobertura |

**Estado de carregamento:** spinner enquanto busca; mensagem "Nenhum projeto vinculado" se `data.length === 0`.

```tsx
// Esboço de interface

interface Props {
  produtoId: string
}

export function NecessidadeCompraDetalhe({ produtoId }: Props) {
  const [rows, setRows] = useState<NecessidadeCompraDetalheRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getNecessidadeCompraDetalhe(produtoId)
      .then(setRows)
      .finally(() => setLoading(false))
  }, [produtoId])

  if (loading) return <Loader2 className="animate-spin" />
  if (rows.length === 0) return <p>Nenhum projeto vinculado.</p>

  return (
    <Table>
      {/* colunas: Projeto | Orçamento | Cliente | Qtd.Vendida | Coberto | A Comprar */}
    </Table>
  )
}
```

---

### Modificação em `NecessidadeCompra.tsx`

**Padrão de interação: linha expansível**

1. Adicionar estado `expandedId: string | null` no componente
2. Transformar o badge `projetos_com_entrega_futura` em botão clicável
3. Ao clicar: alternar `expandedId` entre `produto_id` e `null`
4. Se `expandedId === r.produto_id`: renderizar `<NecessidadeCompraDetalhe produtoId={r.produto_id} />` em uma `<TableRow>` com `colSpan` total abaixo da linha do produto

**Comportamento esperado:**

```
┌──────┬──────────────────────┬───────┬────────────┬──────┬──────────────┐
│ Cód  │ Produto              │ Físico│ Reservada  │ Déf. │ Projetos     │
├──────┼──────────────────────┼───────┼────────────┼──────┼──────────────┤
│ 9543 │ PLAFON EMBUTIR...    │   0   │     12     │  12  │ ▼ 3 projetos │← expandido
├──────┴──────────────────────┴───────┴────────────┴──────┴──────────────┤
│  Projeto      │ Orçamento  │ Cliente        │ Vendido │ Coberto │ Comprar│
│  L-2025-01    │ ORC-0312   │ João Augusto   │    5    │    5    │    0  │
│  L-2025-03    │ ORC-0401   │ Studio Arq.    │    4    │    0    │    4  │
│  L-2025-07    │ ORC-0445   │ Maria Fernanda │    3    │    0    │    3  │
├──────┬──────────────────────┬───────┬────────────┼──────┼──────────────┤
│10009 │ PERFIL ALUMÍNIO...   │  218  │    225     │   7  │ ▶ 2 projetos │← fechado
```

**Ícone do botão:**
- `▶` fechado → `▼` aberto (usar `ChevronDown` / `ChevronRight` do lucide-react)
- Cor do badge: vermelho se `q_entrega_futura > 0` em algum projeto; âmbar se só `q_reserva`

---

## Regras de negócio

| # | Regra |
|---|-------|
| RN-01 | `q_entrega_futura > 0` significa que o projeto tem itens sem cobertura física — é a contribuição desse projeto ao déficit total |
| RN-02 | `q_reserva > 0` significa que o estoque físico já foi alocado a este projeto — está coberto, mas comprometido |
| RN-03 | A compra não tem dono fixo: ao chegar o material, o comprador decide qual projeto_item recebe (conforme SPEC-012 RN-03) |
| RN-04 | Um produto pode ter um projeto com `q_reserva > 0` e outro com `q_entrega_futura > 0` ao mesmo tempo — a view mostra ambos |
| RN-05 | Projetos com `status_operacional != 'ativo'` não aparecem — cancelamentos e encerramentos ficam fora do detalhe |
| RN-06 | Se `estoque_saldos_projeto_item` não tiver linha para um `projeto_item_id`, o projeto simplesmente não aparece no detalhe (não é erro) |

---

## Análise de ecossistema

- **Não altera** `vw_necessidade_compra` — view de resumo continua igual
- **Não altera** `estoque_itens`, `estoque_saldos_projeto_item` nem `projeto_itens` — view somente leitura
- **Não afeta** SPEC-021 (registrar pedido de compra) — as duas SPECs são independentes e complementares
- **Único sistema alterado:** `compras-lucenera-3o23t98ee` (frontend) + nova view no Supabase

---

## Critérios de aceite

- [ ] `vw_necessidade_compra_detalhe` retorna linhas para produtos com `quantidade_reservada > quantidade`
- [ ] Cada linha da view contém: produto, projeto_codigo, projeto_nome, orcamento_numero, cliente, qtd_vendida, q_reserva, q_entrega_futura
- [ ] Produtos sem `estoque_saldos_projeto_item` não aparecem na view (não geram erro)
- [ ] O badge de projetos na tabela de Necessidade de Compra é clicável
- [ ] Clicar expande uma sub-tabela abaixo da linha do produto
- [ ] Clicar novamente fecha a sub-tabela
- [ ] A sub-tabela mostra cliente na coluna "Para quem vai"
- [ ] A coluna "A comprar" (`q_entrega_futura`) aparece em vermelho quando > 0
- [ ] Produto com múltiplos projetos mostra uma linha por projeto
- [ ] Produto com 1 projeto expande e mostra a linha única corretamente

---

## Perguntas em aberto

| # | Pergunta | Impacto |
|---|----------|---------|
| P-01 | `projetos.codigo` (ex: `L-2024-05`) ou `projetos.nome` deve ser o identificador principal na coluna Projeto? | Layout do badge e da sub-tabela |
| P-02 | Deve aparecer também projetos que têm só `q_reserva > 0` (já coberto) ou apenas os que têm `q_entrega_futura > 0` (não coberto)? | Filtro no JOIN da view — hoje mostra ambos |
| P-03 | `estoque_saldos_projeto_item` está populado para todos os projetos ativos aprovados antes da SPEC-010 (2026-07-06)? Se não, projetos antigos não aparecem no detalhe | Pode exigir backfill |
| P-04 | A compradora (Débora) deve poder clicar no nome do projeto e abrir o projeto no CRM, ou o detalhe é só leitura? | Exigiria link cross-system para o app de projetos |
| P-05 | Deve haver ordenação específica no detalhe? Ex: projetos com `q_entrega_futura` maior primeiro, ou por data de aprovação do orçamento | Ajuste no `ORDER BY` da view |

---

## Pendências pós-implementação

- [ ] Validar com Débora se o detalhe de projetos cobre a necessidade operacional
- [ ] Verificar backfill de `estoque_saldos_projeto_item` para aprovações anteriores a 2026-07-06 (P-03 acima)
- [ ] SPEC-023 (possível): ao receber material, sugerir automaticamente qual `projeto_item_id` deve receber a re-reserva, ordenando pelos com maior `q_entrega_futura`
