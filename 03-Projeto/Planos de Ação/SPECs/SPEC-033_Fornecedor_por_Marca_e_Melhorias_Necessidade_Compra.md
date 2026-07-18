---
titulo: "SPEC-033 — Fornecedor por Marca (tela) + Contexto de Estoque no Pedido em Lote + Coluna Disponível"
status: bug corrigido, revisado, commitado, pushado e republicado em produção — aguardando teste real do usuário
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee
---

# SPEC-033 — Fornecedor por Marca (tela) + Contexto de Estoque no Pedido em Lote + Coluna Disponível

## Checklist de Ação

- [x] Criar `src/services/marcas.ts` em `compras-lucenera-3o23t98ee`: `getMarcasComFornecedor(search?)` (lista `marcas` com fornecedor resolvido via `LEFT JOIN contatos` em `fornecedor_id` + contagem de produtos ativos vinculados via `marca_id`) e `atualizarFornecedorMarca(marcaId, fornecedorId)` (`UPDATE marcas SET fornecedor_id = ...`).
- [x] Criar `src/pages/Marcas.tsx` (rota `/marcas`): lista as ~110 marcas cadastradas, fornecedor atual (ou "sem fornecedor"), quantidade de produtos ativos impactados, campo de busca por nome de marca, e edição do fornecedor por linha reaproveitando a busca fuzzy `getFornecedores()` (`services/pedido-compra.ts`, já existente da SPEC-030) no mesmo padrão visual (`Input` + lista suspensa) já usado em `ModalRegistrarCompra.tsx` — sem inventar um componente/padrão novo de busca.
- [x] Adicionar rota `/marcas` em `src/App.tsx` e item de navegação ("Marcas") em `src/components/AppNav.tsx`.
- [x] Adicionar coluna "Disponível" em `src/pages/NecessidadeCompra.tsx`, lendo `r.qtd_disponivel` — campo que **já existe** na view `vw_necessidade_compra` (migration `20260716_049`, aplicada no Supabase real em 2026-07-17) e **já está tipado** em `NecessidadeCompraRow` (`services/necessidade-compra.ts:10`), mas nunca foi renderizado na tabela. Não exige nova query nem migration.
- [x] Ajustar larguras de coluna (`table-fixed`, breakpoints `hidden lg:table-cell`/`xl:table-cell`) para acomodar a coluna nova sem quebrar o layout responsivo já existente.
- [x] Melhorar `src/components/compra/ModalPedidoLote.tsx` para exibir, ao lado do campo de quantidade editável de cada linha, o estoque físico (`qtd_fisica`), a quantidade comprometida (`qtd_comprometida`) e o disponível (`qtd_disponivel`) daquele produto — os três já vêm em `itens: NecessidadeCompraRow[]` (prop já recebida pelo componente), sem nova query.
- [x] Rodar `oxlint`/`oxfmt`/`vite build` do sistema após as mudanças.
- [x] Commit + push em `compras-lucenera-3o23t98ee` (`1ebbace`, mesclado com `origin/main` sem conflito) e atualização do ponteiro do submodule no repo central.
- [x] Revisão pelo agente `revisor`: sem achado crítico (3 notas informativas — chamada de rede duplicada ao abrir edição, contagem O(n) de produtos por marca, sem lock otimista — nenhuma bloqueante). Lint/build confirmados de forma independente pelo revisor.
- [x] Publicado em produção via Skip MCP (projeto "Necessidade de Compra", id `40326`, host `pagina-em-branco-cdd79.goskip.app`) — versão `0.0.41`, `publishedRef 9c9729d`. Antes de escrever, conferi que os 4 arquivos modificados batiam exatamente com o baseline no Skip (sem divergência desta vez) — só os 2 arquivos novos e as edições planejadas foram aplicados.

### Passos manuais do usuário

- [x] Revisão pelo agente `revisor` sobre a correção: sem achado crítico nem de aviso. Confirmou que `.select('id').single()` cobre corretamente o caso de 0 linhas afetadas (`PGRST116`), que não há regressão no caminho de sucesso, que `Marcas.tsx` já propaga a mensagem nova corretamente, e que `marcas.ts` era o único ponto do sistema com esse padrão de risco.
- [x] Commit + push em `compras-lucenera-3o23t98ee` (`255d30b`) — sem divergência com `origin/main` desta vez.
- [x] Republicado em produção via Skip MCP — versão `0.0.42`, `publishedRef 6c7c8c3`, em `https://pagina-em-branco-cdd79.goskip.app`. QA do Skip limpo.
- [ ] **Pedro/Filippo usam a nova tela "Marcas"** (`/marcas`, já com a correção publicada) para mapear, marca a marca, qual fornecedor (`contatos`) corresponde a cada uma das ~110 marcas cadastradas. Esta é uma decisão de dado (qual fornecedor é qual), não algo que esta SPEC decide — a SPEC só entrega a ferramenta. **Este é o teste real que confirma se o bug foi de fato resolvido**: se a tentativa falhar agora, o toast vai mostrar um erro explícito (em vez de falso sucesso) — nesse caso, a causa provável passa a ser a suspeita de RLS/sessão registrada acima, não mais o bug de update silencioso.
- [ ] Confirmar que o usuário logado (Pedro/Filippo) tem `usuarios.role` em `admin` ou `gerente` — é a única condição que a policy `marcas_update` já existente permite para editar `marcas.fornecedor_id`. Se não tiver, o `UPDATE` será bloqueado pela RLS com erro, e o ajuste de role é uma decisão de Hub/TI, fora do escopo desta SPEC de Compras.
- [ ] Testar golden path no app publicado (`https://pagina-em-branco-cdd79.goskip.app/marcas`): editar o fornecedor de 2-3 marcas, confirmar que `vw_necessidade_compra` passa a preencher `fornecedor_id`/`fornecedor_nome` para os produtos daquela marca e que a checkbox de seleção em "Necessidade de Compra" passa a ficar habilitada para esses produtos. **Não testado manualmente no navegador nesta sessão** — só a QA automática do Skip (build real, sem erro) confirma que compila e roda.
- [ ] Testar "Fechar pedido em lote" com Física/Comprometida/Disponível visíveis no modal, confirmando que os valores batem com o que aparece na tabela principal.
- [ ] Testar a coluna "Disponível" com um produto que tenha saldo negativo (comprometida > física), confirmando que aparece o valor negativo (não floored em zero).
- [ ] Testar o botão "Remover" na tela "Marcas" (desvincula `fornecedor_id`, seta `null`) para confirmar que reverte o comportamento (produto volta a ficar fora do Pedido em Lote se não houver `produtos.fornecedor_principal_id`).

## Objetivo

A SPEC-030 Parte 2 já implementou, em código, o fluxo de "Pedido em Lote" (seleção múltipla de produtos por marca + fechamento de um único pedido de compra por fornecedor). Porém a funcionalidade está **100% travada hoje**: 0 dos 233 produtos com necessidade de compra têm `fornecedor_id` resolvido, porque o campo `marcas.fornecedor_id` (criado pela SPEC-030) nunca foi preenchido para nenhuma das 110 marcas cadastradas — não existe nenhuma tela para isso, só seria possível via SQL direto.

Esta SPEC entrega:

1. Uma tela para Pedro/Filippo mapearem marca → fornecedor pela UI (sem SQL), desbloqueando o Pedido em Lote de fato.
2. Contexto de estoque (física/comprometida/disponível) dentro do modal de Pedido em Lote, para o comprador decidir a quantidade com informação, não seguir cegamente a sugestão.
3. Uma coluna "Disponível" na tabela de Necessidade de Compra, mostrando o saldo real (que pode ser negativo), separada da coluna "Necessidade" (que já existe, sempre ≥ 0).

Esta SPEC **não inclui** o preenchimento em si dos ~110 mapeamentos marca → fornecedor — isso continua sendo trabalho manual de Pedro/Filippo, feito através da tela entregue aqui.

## Decisões aprovadas

Decisões já fechadas em SPEC-030 (Parte 2), não reabertas aqui:

- Resolução de fornecedor de um produto é em cascata: `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`.
- Modelo do Pedido em Lote é 1 pedido = 1 fornecedor fixo; produto sem fornecedor resolvido fica fora do lote.
- A fonte de verdade de "quem é fornecedor" é `contato_tipos.tipo = 'fornecedor'`, não `contatos.tipo`.
- `marcas.fornecedor_id` (nullable, `REFERENCES contatos(id)`) e a extensão de `vw_necessidade_compra` (com `marca_id`, `marca_nome`, `fornecedor_id`, `fornecedor_nome`, `qtd_disponivel`) já existem e **já estão aplicadas no Supabase real** desde 2026-07-17 (migrations `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/`). **Esta SPEC não cria nenhuma migration nova.**
- A policy `marcas_update` (`FOR UPDATE TO authenticated USING (usuarios.role IN ('admin','gerente'))`) já existe e já permite exatamente a operação que a nova tela precisa fazer — confirmado em `supabase/db/current/01_schema_full.sql:13818-13820`.

Decisões novas desta SPEC:

- A tela de mapeamento marca → fornecedor fica em `compras-lucenera-3o23t98ee` (não em Cadastro), como extensão direta do trabalho já feito pela SPEC-030 no mesmo sistema. Cadastro (`04-Sistemas/cadastro-lucenera-b86fe`) hoje não tem nenhuma tela de gestão de `marcas` — só um dropdown somente-leitura de marcas existentes dentro do formulário de produto (`Pecas.tsx`/`PecaForm.tsx`). `marcas.fornecedor_id` é um dado puramente operacional de compra (fornecedor padrão para fins de pedido), coerente com a divisão já registrada em `03-Projeto/00_INDICE.md`: "Cadastro edita informações cadastrais; Estoque/Compras consulta esses dados e gerencia informações operacionais". A tela nova **não** cria, renomeia nem desativa marca — só edita o vínculo `fornecedor_id` de marcas já existentes.
- A coluna "Disponível" **coexiste** com a coluna "Necessidade" já existente em `NecessidadeCompra.tsx` (não a substitui) — ver justificativa e ressalva em Pendências.
- A busca de fornecedor na nova tela reaproveita a mesma RPC `buscar_fornecedores_fuzzy` e o mesmo padrão de UI inline (`Input` + lista suspensa) já usados em `ModalRegistrarCompra.tsx`, em vez de introduzir um componente de combobox novo (`components/ui/command.tsx` existe no projeto mas não é usado em nenhum fluxo de busca de fornecedor hoje — não é o padrão estabelecido).

## Definição da SPEC

### 1. Diagnóstico da causa raiz (fato já verificado, não uma hipótese)

```sql
SELECT count(*) FROM vw_necessidade_compra;                          -- 233
SELECT count(*) FROM vw_necessidade_compra WHERE fornecedor_id IS NOT NULL; -- 0
SELECT count(*) FROM produtos WHERE fornecedor_principal_id IS NOT NULL;    -- 0
SELECT count(*) FROM marcas WHERE fornecedor_id IS NOT NULL;               -- 0 (de 110 marcas)
```

O checkbox de seleção em `NecessidadeCompra.tsx` (linha ~346-355) é:

```tsx
<Checkbox
  checked={selectedIds.has(r.produto_id)}
  disabled={!r.fornecedor_id}
  onCheckedChange={() => toggleSelect(r)}
  title={r.fornecedor_id ? undefined : 'Sem fornecedor resolvido (...) — fora do Pedido em Lote'}
/>
```

Como `fornecedor_id` é `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)` e ambas as pontas estão zeradas para os 233 produtos com necessidade, **nenhum produto do sistema pode ser selecionado hoje** — não é um bug de lógica de seleção nem de RLS, é ausência total de backfill de dado (registrado como pendência aberta desde a SPEC-030 e nunca resolvido). Isso bate exatamente com o relato do Pedro e com o print anexado (marca "ACEND", 7 produtos, nenhuma checkbox habilitada).

### 2. Nova tela "Marcas" (`/marcas`)

**Objetivo da tela:** dar a Pedro/Filippo um jeito de mapear `marcas.fornecedor_id` pela UI, sem SQL manual.

**Service novo — `src/services/marcas.ts`:**

```ts
export interface MarcaComFornecedor {
  id: string
  nome: string
  fornecedor_id: string | null
  fornecedor_nome: string | null
  qtd_produtos_ativos: number
}

export async function getMarcasComFornecedor(search?: string): Promise<MarcaComFornecedor[]> { ... }
export async function atualizarFornecedorMarca(marcaId: string, fornecedorId: string | null): Promise<void> { ... }
```

- `getMarcasComFornecedor`: `SELECT id, nome, fornecedor_id, fornecedor:contatos(nome)` em `marcas`, mais uma contagem de `produtos` ativos com `marca_id = marcas.id` (para ajudar Pedro/Filippo a priorizar — marcas com mais produtos afetados primeiro). Segue o mesmo padrão de "service function chama supabase-js direto, retorna interface tipada" já usado em todo o sistema (`necessidade-compra.ts`, `pedido-compra.ts`, `estoque-produtos.ts`) — sem store global, sem hook de dados genérico, sem `react-query` (o sistema não usa nenhuma lib de data-fetching, só `useState`/`useEffect` direto nas páginas).
- `atualizarFornecedorMarca`: `UPDATE marcas SET fornecedor_id = $1 WHERE id = $2`. Permite `null` para desvincular. Erros de RLS (usuário sem role `admin`/`gerente`) devem aparecer como toast destrutivo claro, não silenciosamente engolidos.

**Página nova — `src/pages/Marcas.tsx`:**

- Busca por nome de marca (client-side, como o filtro de marca já existe em `NecessidadeCompra.tsx` — sem necessidade de paginação/lote incremental como em Necessidade de Compra, pois são só ~110 linhas).
- Tabela: Marca | Fornecedor atual | Produtos ativos vinculados | Ação.
- Ordenação sugerida: marcas sem fornecedor primeiro (para focar o trabalho de backfill), depois por quantidade de produtos ativos (maior impacto primeiro) — é só uma sugestão de ordenação de UI, não uma decisão de dado.
- Edição do fornecedor por linha: reutiliza `getFornecedores()` (`services/pedido-compra.ts`) — o mesmo padrão de busca fuzzy tolerante a erro de digitação já usado em `ModalRegistrarCompra.tsx` (`Input` de busca + lista suspensa de resultados, sem componente de combobox novo).
- Rota `/marcas` adicionada a `App.tsx`; item "Marcas" adicionado a `AppNav.tsx` (ícone sugerido: `Tags`, do `lucide-react`, já usado em outros ícones do projeto na mesma lib).

**Nenhuma migration nova é necessária** — `marcas.fornecedor_id` e a policy `marcas_update` já existem e já estão aplicadas no Supabase real.

### 3. Contexto de estoque no `ModalPedidoLote.tsx`

Hoje a tabela do modal (linhas 142-190 do componente) só mostra Produto / Quantidade / Custo unitário. `NecessidadeCompraRow` (prop `itens`, já recebida pelo componente) já traz `qtd_fisica`, `qtd_comprometida` e `qtd_disponivel` para cada linha — **não é necessária nenhuma nova query**, só passar esses três valores para a exibição junto de cada linha da tabela (ex.: como texto auxiliar abaixo do nome do produto, ou como colunas extra somente-leitura antes da coluna Quantidade). Isso dá ao comprador o contexto que hoje só existe na tela de trás (`NecessidadeCompra.tsx`) mas se perde ao abrir o modal.

### 4. Coluna "Disponível" em `NecessidadeCompra.tsx`

- `vw_necessidade_compra.qtd_disponivel` já é calculado como `qtd_fisica - qtd_comprometida` (**sem** `GREATEST(0, ...)`, ou seja, pode ser negativo) — ver `002_vw_necessidade_compra_marca_fornecedor.sql:36-37`.
- `NecessidadeCompraRow.qtd_disponivel` já está no tipo TypeScript (`necessidade-compra.ts:10`) e já vem preenchido em toda chamada de `getNecessidadeCompra()` (usa `select('*')`).
- Falta só renderizar: nova `<TableHead>`/`<TableCell>` "Disponível", com destaque visual quando negativo (ex.: texto vermelho/ícone de alerta, seguindo o mesmo padrão visual já usado na coluna "Necessidade").
- Posição sugerida: entre "Comprometida" e "Necessidade" (mesma faixa de breakpoint responsivo, ex. `hidden lg:table-cell`, para não quebrar o layout `table-fixed` já existente — larguras percentuais das colunas precisam ser reajustadas).

### Sistema afetado e padrão de acesso a dados já usado

- Único sistema afetado: `compras-lucenera-3o23t98ee` (Estoque/Compras).
- Padrão já estabelecido no sistema (a seguir, não substituir): funções em `src/services/*.ts` chamando `supabase` (supabase-js) diretamente via `.from()`/`.rpc()`, retornando interfaces TypeScript tipadas; páginas em `src/pages/*.tsx` consumindo esses services via `useState`+`useEffect` local, sem store global (Redux/Zustand) nem lib de data-fetching (react-query/swr). Componentes de modal recebem dados já carregados via props (como `ModalPedidoLote` já recebe `itens: NecessidadeCompraRow[]`), sem re-buscar.

### Análise obrigatória de ecossistema

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Depende de `contatos` (fornecedores, já resolvidos via `contato_tipos.tipo = 'fornecedor'`) e de `produtos`/`marcas` (fora da lista, mas do mesmo domínio). Depende indiretamente de `usuarios.role` via a policy RLS `marcas_update`. Não depende de `projetos`, `orcamentos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `systems` nem `user_system_access`.
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Afeta apenas Estoque/Compras. Não afeta Cadastro (que mantém sua própria tela de produtos com dropdown somente-leitura de marca, sem tocar em `fornecedor_id`).
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não. `marcas.fornecedor_id` é um vínculo novo (FK), não duplica nada — é resolvido em cascata (`COALESCE`) sem duplicar em `produtos`.
- **Existe migration antiga que contradiz o snapshot central?** Não é contradição, é desatualização já conhecida: `supabase/db/current/` está desatualizado desde 2026-07-07 e ainda não reflete as migrations `20260716_049` (aplicadas no real em 2026-07-17) — pendência já registrada na SPEC-030, reafirmada aqui.
- **Exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Não existe `AI_DB_CONTEXT.md` em `compras-lucenera-3o23t98ee` (confirmado — nenhum arquivo com esse nome no submodule). `supabase/db/domains/estoque_compras.md` está desatualizado (não menciona `marcas.fornecedor_id` nem `vw_necessidade_compra` atual) — recomenda-se atualização, mas não bloqueia esta SPEC nem é responsabilidade do implementador de frontend.

### Critérios de aceite

- Em "Marcas", editar o fornecedor de uma marca persiste em `marcas.fornecedor_id` e reflete em `vw_necessidade_compra.fornecedor_id`/`fornecedor_nome` na próxima consulta.
- Usuário sem role `admin`/`gerente` tentando editar recebe erro claro (RLS bloqueia, toast explica o motivo) — não falha silenciosamente.
- Em "Necessidade de Compra", produtos cuja marca (ou produto) tem fornecedor resolvido passam a ter a checkbox de seleção habilitada.
- A coluna "Disponível" mostra valores negativos quando `qtd_comprometida > qtd_fisica`, sem aplicar `GREATEST(0, ...)`.
- O modal "Pedido em Lote" mostra física/comprometida/disponível por linha, sem nenhuma chamada de rede adicional além da já existente.
- Lint (`oxlint`/`oxfmt`) e `vite build` passam sem novo erro.
- Verificação manual (golden path no navegador) substitui suíte de testes automatizados — este sistema não tem testes automatizados reais.

## Realizado

**2026-07-18 — implementado pelo agente `implementador`** (código, ainda sem commit/push e sem homologação manual):

- `src/services/marcas.ts` (novo): `getMarcasComFornecedor(search?)` — consulta `marcas` (`id, nome, fornecedor_id, fornecedor:contatos(nome)`, com `ilike` opcional em `nome`) e resolve a contagem de produtos ativos por marca com uma segunda função auxiliar `contarProdutosAtivosPorMarca()`, que pagina `produtos` (só `marca_id`, `ativo = true`) em lotes de 500 — mesmo padrão de paginação já usado em `necessidade-compra.ts`/`estoque-produtos.ts`, porque não existe view agregada de contagem por marca. `atualizarFornecedorMarca(marcaId, fornecedorId)` faz `UPDATE marcas SET fornecedor_id = ...` e propaga erro de RLS (`error` do supabase-js) para o chamador tratar via toast.
- `src/pages/Marcas.tsx` (novo, rota `/marcas`): tabela com Marca / Fornecedor atual / Produtos ativos / Ação, busca por nome (debounce 400ms, mesmo padrão de `EstoqueProdutos.tsx`/`NecessidadeCompra.tsx`), ordenação client-side (marcas sem fornecedor primeiro, depois por quantidade de produtos ativos desc). Edição inline por linha: botão "Editar" troca a célula "Fornecedor atual" por um `Input` de busca + lista suspensa (mesmo padrão visual de `ModalRegistrarCompra.tsx`, reaproveitando `getFornecedores()` de `services/pedido-compra.ts`); clicar num resultado chama `atualizarFornecedorMarca` e atualiza o estado local sem recarregar a lista inteira; toast destrutivo claro em caso de erro (RLS ou outro). Também há um botão "Remover" (visível apenas quando a marca já tem fornecedor) para desvincular (`fornecedor_id = null`).
- `src/App.tsx`: rota `/marcas` adicionada dentro do grupo `<ProtectedRoute />`.
- `src/components/AppNav.tsx`: item "Marcas" (ícone `Tags` do `lucide-react`) adicionado ao fim da navegação.
- `src/pages/NecessidadeCompra.tsx`: nova coluna "Disponível" (`hidden xl:table-cell`, mesma faixa de breakpoint de "Comprometida"), posicionada entre "Comprometida" e "Necessidade", lendo `r.qtd_disponivel` sem nova query. Texto vermelho + `font-semibold` quando negativo, cinza padrão quando ≥ 0 (mesmo padrão de destaque condicional já usado no sistema, ex. `estoqueColor()` em `EstoqueProdutos.tsx`). Larguras de coluna redistribuídas (`table-fixed`): Código 16%→13%, Marca 12%→10%, Física 11%→9%, Comprometida 13%→10%, Necessidade 14%→12%, Projetos 10%→9%, Compra 10%→9%, nova Disponível 10% — a coluna "Produto" (sem largura fixa) ganhou mais espaço residual (10%→~14% em telas xl) em vez de menos, então o ajuste não aperta nenhuma coluna existente. `colSpan` dos estados de loading/vazio/detalhe atualizado de 9 para 10.
- `src/components/compra/ModalPedidoLote.tsx`: `LinhaLote` ganhou `qtdFisica`/`qtdComprometida`/`qtdDisponivel` (preenchidos a partir da prop `itens: NecessidadeCompraRow[]`, sem nova query). Exibidos como uma linha de texto auxiliar abaixo do nome/código do produto, na mesma célula "Produto" (não como colunas novas na tabela do modal, para não espremer os campos editáveis de Quantidade/Custo unitário que já são estreitos em telas menores) — "Física: N", "Comprometida: N" (âmbar) e "Disponível: N" (vermelho quando negativo, verde quando ≥ 0).
- Verificação: `npx oxlint src` sem novos erros/warnings (o único warning existente, em `Cotacoes.tsx`, é pré-existente e não relacionado a esta SPEC). `npx oxfmt --check` aponta os mesmos 115 arquivos com "format issues" tanto antes quanto depois das mudanças desta SPEC (confirmado via `git stash`) — é uma divergência de baseline do repositório (provável mismatch de versão/config do `oxfmt`), não introduzida aqui; nenhum arquivo tocado por esta SPEC está fora dessa lista pré-existente. `npx vite build` concluído com sucesso (o único warning do build, `duration-[800ms]` ambíguo no Tailwind, é pré-existente e não relacionado às mudanças).
- Não foi criada nenhuma migration — `marcas.fornecedor_id` e a policy `marcas_update` já existiam e já estavam aplicadas no Supabase real, conforme a SPEC confirmou.

## Bug real encontrado pós-publicação (2026-07-18, sessão seguinte)

Pedro reportou que, mesmo depois de usar a tela "Marcas" para vincular fornecedor a marcas, os checkboxes em "Necessidade de Compra" continuavam desabilitados. Diagnóstico confirmado por teste direto no Supabase real:

1. `SELECT count(*) FROM marcas WHERE fornecedor_id IS NOT NULL` retornava **0** mesmo depois da tentativa de Pedro pela UI — nada persistiu.
2. Testei um `UPDATE marcas SET fornecedor_id = ...` direto via conexão Postgres (bypassa RLS): funcionou perfeitamente, e `vw_necessidade_compra.fornecedor_id`/`fornecedor_nome` refletiram corretamente para os produtos da marca testada. Revertido logo em seguida (não era uma decisão de dado real, só teste). **Confirma que o banco, a view e a RLS não têm bug — o problema é só no caminho de escrita do frontend.**
3. Confirmado que `usuarios.id` bate com `auth.users.id` para todos os usuários (incluindo Pedro, `admin`), então a policy `marcas_update` deveria passar para o caso de uso normal.

**Causa raiz identificada**: `atualizarFornecedorMarca()` (`src/services/marcas.ts`) chama `supabase.from('marcas').update({...}).eq('id', marcaId)` **sem `.select()`**. Esse é um gotcha clássico do Supabase/PostgREST: com `Prefer: return=minimal` (o padrão quando não se encadeia `.select()`), se a policy `USING` de UPDATE bloquear a linha (RLS) ou o `.eq('id', ...)` não casar com nenhuma linha, o PostgREST responde `204 No Content` — **sem erro nenhum**. `atualizarFornecedorMarca` só verifica `if (error) throw error`, então uma atualização que afetou 0 linhas passa como sucesso: a tela mostra o toast "Fornecedor atualizado", atualiza o estado local otimisticamente, e o usuário segue confiante — mas nada foi salvo. Isso explica exatamente o sintoma relatado.

**Correção**: encadear `.select('id').single()` após o `.update()` e tratar a ausência de linha retornada como erro explícito (mensagem indicando possível falta de permissão admin/gerente), em vez de assumir sucesso pela ausência de `error`. Mesma correção aplicada ao caminho de "Remover" (que chama a mesma função com `fornecedorId = null`).

**Corrigido em 2026-07-18 (mesma sessão que encontrou o bug), pelo agente `implementador`:**

- `src/services/marcas.ts` — `atualizarFornecedorMarca(marcaId, fornecedorId)` agora encadeia `.select('id').single()` após o `.update()`. Trata `error` **ou** `!data` (0 linhas afetadas) como falha, lançando `new Error('Nenhuma marca foi atualizada. Verifique se seu usuário tem permissão de admin/gerente.')` — em vez de propagar o erro cru do Postgrest (`.single()` lança `PGRST116` quando 0 linhas retornam, que não é uma mensagem legível para o usuário final). Comentário no código explica o gotcha do `Prefer: return=minimal` para o próximo agente que ler o arquivo.
- Verificado que **não há outro ponto do sistema** (`compras-lucenera-3o23t98ee`) com o mesmo padrão de `.update()`/`.delete()` do Supabase-js sem `.select()` encadeado — busca em todo `src/` confirmou que `marcas.ts` era o único caso; as demais ocorrências de `.delete(`/`.update(` no código são `Set.delete()` (JS nativo), não chamadas Supabase.
- `src/pages/Marcas.tsx` — confirmado (sem alteração necessária) que `selecionarFornecedor` e `removerFornecedor` já têm `try/catch` em torno de `atualizarFornecedorMarca` e já propagam `err?.message` para o toast destrutivo (`title: 'Erro ao atualizar fornecedor'` / `'Erro ao remover vínculo'`). Com a correção do service, esses toasts agora vão mostrar a mensagem explícita de falha em vez de nunca disparar.
- Verificação: `npx oxlint src` sem novos erros/avisos (mesmo warning pré-existente em `Cotacoes.tsx`, não relacionado). `npx vite build` concluído com sucesso (mesmos warnings pré-existentes de Tailwind/chunk size, não relacionados).
- **Commitado (`255d30b`), revisado sem achado crítico, pushado e republicado em produção** (`0.0.42`/`6c7c8c3`) — aguardando o teste real do usuário na tela "Marcas" publicada.

**Suspeita adicional sobre a policy RLS (não confirmada 100%, registrada para o próximo diagnóstico caso o erro persista mesmo após esta correção):** o teste direto via conexão Postgres bypassa RLS por definição (superusuário/service role), então ele só provou que a tabela/coluna/view funcionam — não provou que a policy `marcas_update` de fato libera Pedro (`admin`) via `authenticated`. Pontos que não foram (e não podem ser, por este agente) verificados a partir daqui:
  - Se o cliente Supabase-js do frontend está de fato autenticado (sessão JWT válida, não anônima) no momento do `UPDATE` — se o token expirou silenciosamente ou o app está usando a `anon key` sem sessão, a policy `TO authenticated` bloqueia mesmo com `usuarios.role = 'admin'` correto no banco.
  - Se a policy `marcas_update` usa `auth.uid()` comparado contra `usuarios.id` (ou contra `usuarios.auth_user_id`, se esse for o nome real da coluna de vínculo) — um mismatch de nome de coluna faria a subquery da policy nunca casar, mesmo com os dois IDs "batendo" quando comparados manualmente fora do contexto RLS.
  - Se existe RLS também em `contatos` ou nas colunas usadas para resolver `fornecedor:contatos(nome)` no `SELECT` de `getMarcasComFornecedor` — isso afetaria leitura, não o `UPDATE`, mas poderia mascarar sintomas relacionados se testado em conjunto.
  Antes desta correção, o sintoma era indistinguível entre "bug de RLS" e "bug de update silencioso" porque nenhum erro aparecia em nenhum dos dois casos. Agora que o service lança erro explícito sempre que 0 linhas são afetadas, o próximo teste do usuário vai diferenciar definitivamente: se o toast de erro aparecer, é RLS/sessão (usar o checklist acima); se o toast de sucesso aparecer e a marca persistir de verdade, o bug está resolvido.

## Pendências

- [ ] **Backfill de `marcas.fornecedor_id` para as ~110 marcas** — decisão de dado de Pedro/Filippo (qual fornecedor corresponde a qual marca), feita através da tela entregue por esta SPEC. Sem isso, o Pedido em Lote continua vazio de itens selecionáveis mesmo depois desta SPEC implementada. **Com o bug de update silencioso corrigido, a próxima tentativa de Pedro deve funcionar de verdade — mas se ainda falhar, o toast agora vai mostrar um erro claro em vez de um falso sucesso, o que já é diagnóstico suficiente para o próximo passo (provavelmente checar se o usuário logado no app é mesmo um `admin`/`gerente`).**
- [ ] **Confirmar se "Disponível" e "Necessidade" devem coexistir ou se uma substitui a outra na tabela principal.** Esta SPEC decide por coexistência (justificativa: "Necessidade" já orienta a ação de compra — sempre ≥ 0 — e alimenta o card-resumo "Total unidades a comprar"; "Disponível" é o saldo real com sinal, que foi pedido explicitamente por Pedro: "quantos estão disponíveis ou negativos"). Se Pedro preferir substituir "Necessidade" por "Disponível" (ou remover uma delas), é um ajuste de UI simples a confirmar antes ou depois da implementação.
- [ ] **Bug já conhecido de threshold do `buscar_fornecedores_fuzzy`** (registrado nas Pendências da SPEC-030 Parte 2): `similarity()` do `pg_trgm` compara a string inteira, então buscas curtas (ex. "Stella") não batem contra nomes cadastrados longos (ex. "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA") — a busca retorna 0 resultados nesses casos. Esse bug afeta tanto o fluxo já existente em `ModalRegistrarCompra.tsx` quanto a nova tela "Marcas" desta SPEC, já que ambas reutilizam a mesma RPC. Não corrigido aqui — é uma correção de algoritmo (`word_similarity()`/`<%` em vez de `similarity()`), fora do escopo desta SPEC, mas relevante para o sucesso prático do backfill de 110 marcas.
- [ ] **Reextração do snapshot `supabase/db/current/`** — pendência já existente desde a SPEC-030 (desatualizado desde 2026-07-07, não reflete `marcas.fornecedor_id` nem a `vw_necessidade_compra` atual). Não bloqueia esta SPEC, mas deve ser feita para não confundir o próximo agente.
- [ ] **Atualizar `supabase/db/domains/estoque_compras.md`** para refletir `marcas.fornecedor_id`, `vw_necessidade_compra` (com `qtd_disponivel`/`marca_id`/`fornecedor_id`) e a RPC `criar_pedido_compra_lote` — documento está desatualizado desde antes da SPEC-030. Não bloqueia esta SPEC.
- [ ] **Local da tela "Marcas"**: esta SPEC propõe `compras-lucenera-3o23t98ee` por continuidade com a SPEC-030 e por ausência de tela equivalente em Cadastro. Se Pedro/Filippo preferirem centralizar gestão de marcas (incluindo `fornecedor_id`) dentro do sistema de Cadastro no futuro, isso é uma decisão de arquitetura maior, fora do escopo desta SPEC.
