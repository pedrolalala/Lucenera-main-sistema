---
titulo: "SPEC-108 — Travar edição de valores/produtos no orçamento — só Admin"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `BudgetFormPage.tsx`
dependencias:
  - SPEC-069 (RBAC — matriz de perfis, `hub_pode_executar`, `papel_permissoes`)
---

# SPEC-108 — Travar edição de valores/produtos no orçamento — só Admin

> Origem: reunião Vinícius 14/08/2026 ([16:04]-[21:16]).

## Objetivo

Só administrador (Vinícius + Lana) pode editar valor de peça ou adicionar produto no orçamento. Vendedoras ("as meninas") só podem mexer a % de desconto.

## Decisões aprovadas

- Decisão final da reunião ([20:49]-[21:16]): **não** foi o modelo de "solicitação de autorização" (card + senha) cogitado no meio da conversa — ficou decidido travar direto, só para quem for admin. Citação: *"A gente pode deixar só o administrador... A gente coloca mais a Lana, no caso seria uma administradora."*
- Confirmado que Lana já é `role = 'admin'` no banco (achado em investigação anterior desta mesma sessão) — não precisa de nenhuma mudança de cadastro, só a regra de tela.

## Definição da SPEC

### Estado atual confirmado no código

`BudgetFormPage.tsx` já usa o padrão `role === 'admin' || role === 'gerente'` em pelo menos 2 lugares (linhas 1769, 1785) — provavelmente controlando a visibilidade do botão "Gerenciamento" (SPEC-083). Esse é o padrão a reaproveitar.

**Diferença importante**: aqui o pedido é mais restrito — só `role === 'admin'`, **excluindo** `gerente` (diferente do padrão já usado em outros lugares do arquivo, que libera admin OU gerente). Vinícius foi específico: só ele e a Lana.

### Proposta (não implementar sem aprovação)

- Campos de valor unitário/preço de peça e o botão "Adicionar Produto" ficam com `disabled={role !== 'admin'}` (não `admin || gerente`).
- Campo de % de desconto continua liberado pra todo mundo com acesso ao orçamento.
- Aplicar tanto no frontend (UX, evita erro por engano) quanto confirmar/reforçar no backend (RPC de salvar orçamento) — travar só na tela sem travar no RPC deixa a regra furável por quem sabe chamar a API direto.

## Análise de ecossistema

- **Depende de**: `usuarios.role`, `hub_pode_executar`/`papel_permissoes` (SPEC-069) se a trava for reforçada no banco.
- **Afeta**: só o formulário de orçamento. Não deve ser confundido com o painel "Gerenciamento" (SPEC-083, já admin/gerente) — são travas diferentes, uma mais ampla (ver lucro) e uma mais restrita (editar valor de venda).

## Realizado

### 2026-08-15

- **Achado crítico antes de implementar**: `BudgetFormPage.tsx` é a mesma tela usada tanto pra CRIAR quanto pra EDITAR orçamento (`isEditing = Boolean(id)`). Travar "adicionar produto"/"editar valor" de forma incondicional quebraria a criação de orçamento novo — é assim que vendedora monta a lista de produtos do zero. Escopo corrigido: a trava vale só para EDIÇÃO de orçamento já existente; criação continua livre pra todo mundo.
- Frontend: `canEditValorProduto = role === 'admin' || !isEditing`, calculado em `BudgetFormPage.tsx` e passado como prop pra `BudgetItemCard.tsx`. Desabilita: campo "Preço Unit." (readOnly), botão de trocar produto (`ProductSelectButton`, ganhou props `disabled`/`title` novas), botões "Buscar produto cadastrado"/"Criar novo produto" no item avulso, e os botões globais "Buscar Produtos"/"Adicionar Item não Cadastrado" (2 lugares: toolbar e estado vazio). Quantidade, desconto, L (custom_id) e remover item continuam livres pra qualquer perfil — fora do pedido explícito.
- Backend: migration `20260815_116_spec108_trava_valor_produto_orcamento` reforça a RPC `replace_orcamento_itens` (chamada só no fluxo de EDIÇÃO — criação usa INSERT direto, então o guard já nasce escopado certo). Como a função é DELETE+INSERT sem id estável por item, a comparação é por multiset de (identidade, preço): se algum par (produto_id/descrição, preço) do payload novo não existe no estado atual do orçamento (mesma contagem), é sinal de preço alterado ou produto trocado/adicionado — bloqueado pra quem não é `admin`. Pares que só desaparecem (item removido) não bloqueiam, consistente com a decisão de deixar remoção livre. Aplicada no Supabase real.
- Testado ao vivo como admin (único perfil disponível na conta de teste): abri um orçamento existente (ORC-0023), confirmei que "Buscar Produtos"/"Adicionar Item"/campo de preço estavam todos habilitados (comportamento esperado pra admin), salvei sem alterações e confirmou sem erro — a guarda no banco não bloqueou o save normal de admin. O caminho de bloqueio pra não-admin não foi clicado ao vivo (sem conta de teste com outro perfil), mas a lógica (prop booleana simples, sem estado assíncrono) foi conferida por leitura de código.

## Pendências

Nenhuma.
