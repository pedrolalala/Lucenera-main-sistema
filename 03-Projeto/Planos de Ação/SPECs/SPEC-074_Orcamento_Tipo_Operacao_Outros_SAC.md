---
titulo: "SPEC-074 — Orçamento: Tipo de Operação (Outros/SAC) + campo Tipo com subgrupos"
status: publicado em produção (Skip projectId 32554, v0.0.309/0fc4d3d) + push GitHub
data_ultima_modificacao: 2026-08-11
sistemas_envolvidos:
  - Orçamentos (gestão-financeira-clone-544cb, projectId Skip 32554) — BudgetFormPage.tsx, useBudgetStore.ts
  - Supabase (banco central) — CHECK ampliado + 1 coluna nova em orcamentos
dependencias:
  - SPEC-071 (natureza_operacao venda/devolucao — publicada e ATIVA no Skip; achado importante abaixo)
---

# SPEC-074 — Orçamento: Tipo de Operação (Outros/SAC) + campo Tipo

> Origem: pedido do usuário com especificação campo-a-campo (4 tipos de
> operação + listas de subgrupo por tipo), pedindo ajuste só de interface,
> preservando lógica de negócio/schema. Imagens de referência mencionadas
> no pedido não chegaram anexadas — usuário optou por seguir só com o texto.

## Achados críticos (investigação obrigatória antes de qualquer alteração)

1. **O toggle Venda/Devolução da SPEC-071 nunca chegou a este checkout
   local.** A SPEC-071 documenta "implementado e publicado", mas
   `natureza_operacao` só existia na tabela `orcamentos` e nos tipos
   gerados do Supabase — zero uso em `BudgetFormPage.tsx` ou em qualquer
   outro componente (`grep` confirmou). Mesmo padrão de gap já visto antes
   neste projeto (SPEC "realizado" ≠ "no ar"). Reportado ao usuário; optou
   por implementar os 4 tipos do zero neste checkout, em vez de esperar o
   Skip reconectar pra sincronizar primeiro.
2. **Schema não suportava a feature.** `natureza_operacao` tinha `CHECK`
   restrito a `'venda'`/`'devolucao'`; não existia coluna nenhuma pra
   guardar o subgrupo (campo "Tipo"). Contradiz a instrução de não alterar
   banco. Reportado; usuário autorizou as 2 mudanças aditivas abaixo.

## Migration aplicada (`20260811_097_orcamento_tipo_operacao_outros_sac`)

```sql
ALTER TABLE public.orcamentos DROP CONSTRAINT orcamentos_natureza_operacao_check;
ALTER TABLE public.orcamentos ADD CONSTRAINT orcamentos_natureza_operacao_check
  CHECK (natureza_operacao = ANY (ARRAY['venda','devolucao','outros','sac']));
ALTER TABLE public.orcamentos ADD COLUMN IF NOT EXISTS subgrupo text;
```

**Caveat de negócio (fora de escopo desta rodada, só sinalizado)**:
`aprovar_orcamento_financeiro()` só tem ramo explícito pra
`natureza_operacao = 'devolucao'`; `outros`/`sac` caem no ramo "venda" por
default na aprovação financeira. Se o comportamento esperado for diferente,
precisa de uma regra de negócio nova nessa função — não implementado aqui.

## Frontend (`BudgetFormPage.tsx`, `useBudgetStore.ts`)

- Novo Card "Tipo de Operação" (topo do formulário, antes de "Informações
  Gerais"): toggle de 4 botões com ícone (Venda=ShoppingCart,
  Devol.=Undo2, Outros=Package, SAC=Headset), estilo já usado no resto do
  sistema (`Button variant="default"` quando ativo, `"ghost"` quando não),
  `disabled` quando `isEditing` (mesma convenção da SPEC-071 original).
- Campo "Tipo": `Select` cujas opções vêm de `SUBGRUPOS_POR_TIPO[tipo]`
  (constante fixa no componente, não normalizada em tabela — mesma decisão
  já tomada pra outras listas fixas do sistema). Troca de tipo reseta o
  subgrupo escolhido (`form.setValue('subgrupo', ...)`).
- **Bug cosmético encontrado e corrigido durante o teste**: o Radix
  `Select` não exibia o valor no gatilho fechado quando havia só 1 opção
  auto-selecionada por código (caso do SAC) — o valor real já estava
  correto no formulário, só o texto ficava em branco até o usuário abrir o
  dropdown uma vez. Corrigido trocando por um campo somente-leitura fixo
  quando `opcoes.length === 1`, evitando depender dessa particularidade do
  componente.
- `Budget` (store): campos `natureza_operacao` e `subgrupo` adicionados à
  interface TypeScript.

## Listas de subgrupo (fixas no frontend)

| Tipo | Subgrupos |
|---|---|
| Venda | VENDAS, ENTREGA FUTURA |
| Devolução | TROCA DEV, CASA COR ENTRADA |
| Outros | CASA COR SAIDA, REMESSA TRANSP, RETORNO, TRANSFERENCIA, GARANTIA, OUTRAS ENTRADAS, OUTRAS SAIDAS, ACERTO CITEL, INVENTARIO, SAIDA INDUSTRIALIZACAO, BONIFICACAO, USO E CONSUMO, DESCARTE, REMESSA CONSERTO, DEV EM GARANTIA, DEV COMPRA |
| SAC | SAC |

## Verificação

- `npm run build` limpo (2 vezes — antes e depois do fix do bug cosmético).
- Testado ao vivo com usuário de teste descartável (criado via Admin API,
  papel `admin_geral`, apagado ao final — zero resíduo em produção): os 4
  tipos alternam corretamente, cada um carrega sua lista de subgrupo, SAC
  auto-seleciona a única opção.

## Escopo do que NÃO foi alterado

- Nenhuma regra de cálculo, aprovação ou fluxo de itens.
- `aprovar_orcamento_financeiro()` não foi tocada (ver caveat acima).
- Nenhum outro campo da tela de Orçamento.
- Nenhuma linha da lógica de Devolução da SPEC-071 (modal de busca de venda
  de origem, `applyDevolucaoSelection`, validação `projeto_item_origem_id`)
  — ver achado crítico abaixo sobre como isso quase foi apagado.

## Achado crítico ao publicar (2026-08-11, depois do MCP do Skip reconectar)

Ao tentar publicar via `skip_file_write`, descobri que o `BudgetFormPage.tsx`
e `useBudgetStore.ts` **reais publicados no Skip já tinham a SPEC-071
completa** (toggle Venda/Devolução, `DevolucaoItemSearchModal`,
`devolucoesService.ts`, validação de `projeto_item_origem_id`) — só não
tinha chegado neste checkout local, que estava sem nenhum desses arquivos.
Se eu tivesse sobrescrito com a versão "do zero" implementada antes (quando
o Skip estava desconectado), teria **apagado a SPEC-071 inteira de
produção**.

Corrigido: busquei o conteúdo real via `skip_file_read` (`BudgetFormPage.tsx`
2578 linhas, `useBudgetStore.ts`, `DevolucaoItemSearchModal.tsx`,
`devolucoesService.ts`), mapeei a estrutura real com um agente Explore, e
apliquei a extensão Outros/SAC + campo Tipo **em cima** do código real —
sem tocar em nenhuma linha da lógica de devolução. `npm run build` local só
passou depois de eu também trazer os 2 arquivos que faltavam
(`DevolucaoItemSearchModal.tsx`, `devolucoesService.ts`) pro checkout local.
Antes de aplicar/publicar, confirmei por diff byte-a-byte (`tr -d '\r'`,
já que Skip usa LF e o checkout local usa CRLF) que o conteúdo escrito no
Skip batia exatamente com o arquivo local.

**Lição**: local desatualizado neste projeto não é "faltam features novas
minhas" — pode significar "há features de outras SPECs já em produção que
eu nunca vi". Sempre ler o conteúdo real do Skip (`skip_file_read`) antes
de sobrescrever um arquivo grande/complexo, mesmo que o `git log` local
pareça coerente.

## Publicado

- Skip projectId `32554`, versão `0.0.309` / `0fc4d3d`, produção:
  https://gestao-financeira-clone-544cb.goskip.app — QA (setup, static,
  build, integrations, test) limpo em todos os estágios.
- Commit local `60bce31` (corrige o commit anterior que tinha o toggle "do
  zero"), push feito pro GitHub.

## Pendências

- [ ] **P-1**: decidir se `outros`/`sac` precisam de um ramo próprio em
  `aprovar_orcamento_financeiro()`, ou se o comportamento "tratar como
  venda" é aceitável.
- [ ] **P-2**: confirmar se as imagens de referência (não anexadas)
  indicavam algo além do que o texto já especificou.
- [ ] **P-3**: verificação visual ao vivo do merge final (toggle de 4 tipos
  dentro do código real com SPEC-071) não foi possível — automação de
  browser instável nesta sessão (timeout de screenshot, depois erro
  `params.clip.scale`). Validado por: `npm run build` limpo com a base real
  completa + QA do Skip limpo + diff byte-a-byte do conteúdo publicado.
  Recomendo uma conferência visual rápida na tela real assim que possível.
