---
titulo: "SPEC-014 — Itens Aprovados do Projeto Visíveis no CRM"
status: implementado no CRM, pendente badges ricos de estoque
data_ultima_modificacao: 2026-07-07
sistemas_envolvidos:
  - CRM
---

# SPEC-014 — Itens Aprovados do Projeto Visíveis no CRM

> Nota de origem: este documento era a SPEC-010 local escrita em 03/07/2026. Foi renumerado para SPEC-014 em 06/07/2026 para preservar a sequência `SPEC-009` a `SPEC-012` publicada no GitHub sem pular numeração.

## Checklist de Ação

- [x] `src/services/projetos.ts` — exportar tipo `ProjetoItem`, adicionar `projeto_itens?: ProjetoItem[]` ao tipo `Projeto`.
- [x] `src/services/projetos.ts` — incluir `projeto_itens(*)` no `select` de `getProjeto()` (bloco principal e no fallback de `PGRST200`).
- [x] `src/pages/ProjectDetail.tsx` — novo Card "Itens Aprovados do Projeto", somente leitura, ao lado do Card "Parcelas do Projeto" já existente.
- [x] Badge de situação por item: `Cancelado` (`validado = false`) ou `Ativo` como rótulo genérico enquanto a leitura detalhada de estoque da SPEC-010 não estiver liberada para o CRM.
- [x] Estado vazio: projeto sem nenhum `projeto_itens` mostra mensagem "Nenhum item aprovado ainda" em vez de Card vazio ou oculto.

### Passos manuais do usuário

- [ ] Nenhum — não há migration nem variável de ambiente nova nesta SPEC.

## Objetivo

Desde a SPEC-001, todo orçamento aprovado grava seus itens em `projeto_itens` (snapshot de produto, quantidade, preço, desconto, subtotal). Hoje esse dado só é visível abrindo diretamente o Supabase ou cruzando com o sistema de Orçamentos — **confirmado por leitura do código em 03/07/2026: não existe nenhuma referência a `projeto_itens` em nenhum componente do CRM**, só no `types.ts` gerado automaticamente. O responsável pelo projeto, que vive no CRM, não tem como ver o que foi efetivamente aprovado e comprometido para aquele projeto sem sair do sistema.

Esta SPEC fecha essa lacuna de visibilidade com uma mudança só de leitura, sem tocar em nenhuma regra de negócio de aprovação, cancelamento ou estoque.

## Decisões aprovadas

- Só leitura. Nenhuma ação de editar/excluir item aprovado nasce nesta SPEC — isso pertence ao fluxo de Orçamentos (aditivo/substituição, `SPEC-ORC-09`, ainda pendente).
- Itens de orçamento cancelado **continuam aparecendo na lista**, marcados como `Cancelado` — mesmo princípio de histórico visível já usado nas parcelas geradas por orçamento (que aparecem desabilitadas para edição, não somem).
- A situação de estoque (`Reservado`/`Entrega futura`/`Separado`/`Entregue`) depende da `SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md`, que cria os saldos operacionais por `projeto_item_id`. Esta SPEC é construída para funcionar mesmo que a rastreabilidade detalhada ainda não esteja implementada — nesse caso mostra um rótulo genérico `Ativo` em vez dos badges ricos. Não é um bloqueio de dependência dura.
- Nenhuma mudança de RLS é necessária: `projeto_itens` já tem a policy `pi_select ON public.projeto_itens FOR SELECT TO authenticated USING (true)` — confirmado no schema atual em 03/07/2026.

## Definição da SPEC

### Estado atual confirmado (03/07/2026)

- `src/services/projetos.ts`, função `getProjeto(id)` (linhas ~119-160): busca `projetos` com `cliente`, `arquiteto`, `responsavel`, `engenheiro` e `projeto_parcelas(*)` — **sem `projeto_itens`**. Mesma lacuna em `getProjetos()` (listagem).
- `src/pages/ProjectDetail.tsx` (900 linhas): não usa nenhum componente de abas (`Tabs`/`TabsTrigger`) — o layout é uma sequência de `Card`s. Já existe o precedente exato a seguir: o Card "Parcelas do Projeto" (linha ~587) exibe `projeto.projeto_parcelas`, com aviso "Parcelas geradas por orçamento aprovado não aparecem aqui para edição" para as linhas com `orcamento_id` preenchido.
- RLS: `CREATE POLICY pi_select ON public.projeto_itens FOR SELECT TO authenticated USING (true);` já existe — nenhuma mudança de banco necessária.

### Mudança em `src/services/projetos.ts`

```ts
export type ProjetoItem = Database['public']['Tables']['projeto_itens']['Row']

export type Projeto = Database['public']['Tables']['projetos']['Row'] & {
  cliente?: { nome: string } | null
  arquiteto?: { nome: string } | null
  responsavel?: { nome: string } | null
  engenheiro?: { nome: string } | null
  projeto_parcelas?: ProjetoParcela[]
  projeto_itens?: ProjetoItem[]   // novo
  ano_fechamento?: string | null
  mes_fechamento?: string | null
  data_fechamento?: string | null
}
```

No `select` de `getProjeto()` (e no fallback de `PGRST200`, para não regredir o que a SPEC-CRM-13/correção de `responsavel_obra_id` já resolveu):

```ts
.select(`
  *,
  cliente:cliente_id(nome),
  arquiteto:arquiteto_id(nome),
  responsavel:responsavel_id(nome),
  engenheiro:responsavel_obra_id(nome),
  projeto_parcelas(*),
  projeto_itens(*)
`)
```

### Novo Card em `src/pages/ProjectDetail.tsx`

| Coluna | Origem | Regra de exibição |
|---|---|---|
| Item | `projeto_itens.descricao` | Snapshot já salvo na aprovação (SPEC-ORC-04) — não busca `produtos` de novo. |
| Quantidade | `projeto_itens.quantidade` | — |
| Preço unitário | `projeto_itens.preco_unitario` | Formatado como moeda. |
| Desconto | `projeto_itens.desconto` | Formatado como `%`. |
| Subtotal | `projeto_itens.subtotal` | Coluna gerada no banco, só leitura. |
| Origem | `projeto_itens.orcamento_id` | `"Orçamento " + orcamento_id.slice(0,8)` até existir um número de orçamento populado de forma confiável em todos os casos; trocar por `orcamentos.numero` quando disponível. |
| Situação | `projeto_itens.validado` + `vw_estoque_saldos_projeto_item` | `!validado` → badge `Cancelado` (cinza); `q_entregue > 0` e sem saldo aberto → `Entregue` (verde); `q_separado > 0` → `Separado`; `q_reserva > 0` → `Reservado` (azul); `q_entrega_futura > 0` → `Entrega futura` (âmbar); `validado` sem rastreabilidade detalhada ainda → badge `Ativo` (azul). |

Estrutura do Card (mesma linguagem visual do Card "Parcelas do Projeto" já existente — `Card` / `CardHeader` / `CardTitle` com ícone / `CardContent` com tabela):

```tsx
<Card className="md:col-span-2">
  <CardHeader>
    <CardTitle className="flex items-center gap-2">
      <Package className="h-5 w-5" />
      Itens Aprovados do Projeto
    </CardTitle>
  </CardHeader>
  <CardContent>
    {(projeto.projeto_itens || []).length === 0 ? (
      <p className="text-sm text-muted-foreground">Nenhum item aprovado ainda.</p>
    ) : (
      <Table>
        {/* colunas conforme tabela acima, uma linha por projeto_itens */}
      </Table>
    )}
  </CardContent>
</Card>
```

### Critérios de aceite

- Abrir, no CRM, um projeto com orçamento aprovado mostra os itens (produto, quantidade, preço, desconto, subtotal, origem, situação) sem precisar abrir Orçamentos ou Cadastro.
- Um projeto sem nenhum orçamento aprovado mostra o estado vazio, não um Card quebrado ou ausente.
- Um item de orçamento cancelado continua na lista, com badge `Cancelado` — não desaparece.
- Nenhuma ação de escrita em `projeto_itens` é exposta nesta tela.
- A tela não faz nenhuma chamada nova ao Supabase além de incluir `projeto_itens(*)` no `select` já existente de `getProjeto()` (sem N+1 query por item).

## Realizado

### 2026-07-07

- Implementado no CRM (`04-Sistemas/lucenera-crm-3bd29 (1)`): `getProjeto()` agora carrega `projeto_itens(*)` no select principal e no fallback `PGRST200`; `getProjetos()` ficou sem `projeto_itens(*)` para não pesar a listagem.
- Adicionado o Card "Itens Aprovados do Projeto" em `src/pages/ProjectDetail.tsx`, somente leitura, com item, quantidade, preço unitário, desconto, subtotal, origem por `orcamento_id` e situação.
- Implementado estado vazio "Nenhum item aprovado ainda".
- Situação implementada como `Cancelado` quando `validado = false` e `Ativo` quando `validado = true`. Badges ricos de `Reservado`/`Entrega futura`/`Separado`/`Entregue` permanecem pendentes até o CRM poder consumir a visão de saldos da SPEC-010 com RLS/policy definida.
- Verificações locais no CRM: `node_modules/.bin/tsc --noEmit` passou; `node_modules/.bin/oxlint src` passou com avisos preexistentes fora desta SPEC; `node_modules/.bin/vite build` passou.

## Pendências

- [x] Implementar a mudança de tipo e `select` em `src/services/projetos.ts`.
- [x] Implementar o Card novo em `src/pages/ProjectDetail.tsx`.
- [x] Decidir se `getProjetos()` (listagem) também precisa de `projeto_itens(*)` ou se fica só em `getProjeto()` (detalhe) — decidido manter apenas no detalhe para evitar peso na query principal do CRM.
- [ ] Quando `orcamentos.numero` estiver disponível de forma confiável em todos os orçamentos, trocar o rótulo de origem (hoje baseado em `orcamento_id.slice(0,8)`) pelo número real.
- [ ] Revisitar o badge de situação depois que a `SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md` for implementada, para usar `vw_estoque_saldos_projeto_item` em vez do rótulo genérico `Ativo`.
