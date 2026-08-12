# SPEC-081: Cliente/Vendedor não autopreenchiam, cliente sumia da busca, Arquiteto virou obrigatório

**Data:** 2026-08-12
**Sistemas:** Orçamentos (`gestao-financeira-clone-544cb`, Skip `32554`), CRM (`lucenera-crm-3bd29`, Skip `24580`)
**Status:** Publicado em produção

## Os 3 bugs + 1 observação

1. **Cliente não autopreenchia** ao selecionar um projeto no "Novo Orçamento" — a caixa informativa mostrava "CLIENTE: Vinicius Bortolin" corretamente, mas o campo "Cliente *" ficava vazio.
2. **Vendedor não autopreenchia** com o Responsável do Projeto — mostrava valor errado ou nenhum, quando deveria mostrar "Marina" (o responsável real do projeto de teste).
3. **Cliente cadastrado não aparecia na busca** — "Vinicius Bortolin" existe em `contatos` (`tipo='cliente'`, `ativo=true`) mas não aparecia buscando por "Vinicius" no campo Cliente.
4. **Observação:** o campo "Arquiteto(s)" do formulário de projeto (CRM) estava marcado como obrigatório — precisava voltar a ser opcional.

## Causa raiz dos bugs 1 e 3 (a mesma para os dois)

Investigação estática (leitura de código, verificação de RLS como `authenticated`, contagem de linhas) não encontrava nada de errado — o código de `handleProjectSelect` e a query de `clientes` pareciam corretos, e o contato existia com os dados certos. A causa só apareceu com reprodução ao vivo no navegador e inspeção do estado React real: o array `clientes` carregado por `useOptions()` tinha exatamente **1000 linhas**, um número redondo suspeito.

O PostgREST do projeto Supabase trunca silenciosamente qualquer resposta em **1000 linhas** (`db-max-rows`, o padrão da plataforma), **mesmo que o código peça `.limit(50000)`** — o parâmetro é ignorado acima do teto do servidor, sem erro nenhum. Como a query de `clientes` ordena por `codigo_legado DESC NULLS LAST`, os 1000 primeiros resultados são sempre os mesmos: só contatos **com** `codigo_legado` (importados do sistema legado Connect). Qualquer cliente sem `codigo_legado` — ou seja, **qualquer cliente cadastrado direto no sistema novo**, como "Vinicius Bortolin" — cai depois do corte e desaparece por completo do array, tanto do autopreenchimento (`SearchableSelect` não acha a opção pro `value` já setado) quanto da busca (a opção nunca existiu na lista pra começo de conversa).

**Escopo real do achado:** `clientes` tinha 2643 linhas reais (1643 invisíveis), `projetos` tinha 3703 (2703 invisíveis — inclusive projetos antigos, já que a ordenação por código também teria corte), `produtos` tinha 4726 (3726 invisíveis, embora esse array só alimente o matching de importação de XML, não a tela "Buscar Produtos", que já pagina via `.range()` corretamente). `arquitetos` (864) e `funcionarios` (35) ficaram por baixo do teto por enquanto, sem sintoma.

## Causa raiz do bug 2 (Vendedor)

`handleProjectSelect` ainda usava a lógica pré-SPEC-077: `projeto.responsavel_obra_id || projeto.responsavel_id` — o primeiro é o Engenheiro (`responsavel_obra_id` referencia `contatos`, não `funcionarios`), o segundo é uma FK morta pra `usuarios`. Nunca foi atualizado pra usar `responsavel_funcionario_id` (coluna adicionada na SPEC-077, horas antes na mesma sessão) — a fonte correta pra "Responsável do Projeto" = Vendedor.

## Correções

### `src/hooks/use-options.ts` (Orçamentos)
Novo helper `fetchAllPages()` que pagina via `.range()` em loop até esgotar os resultados, contornando o teto de 1000 do PostgREST. Aplicado às 3 queries que de fato passam de 1000 linhas hoje: `clientes`, `projetos`, `produtos` (tanto no `Promise.all` inicial quanto nas funções standalone `fetchClientes`/`fetchProjetos`, reusadas depois de criar cliente/projeto). `empresas`, `arquitetos`, `funcionarios` e `revenda_ubiqua` continuam com query simples — hoje seguros, mas o mesmo padrão se repetiria se crescerem além de 1000 linhas.

### `src/pages/BudgetFormPage.tsx` (Orçamentos)
`handleProjectSelect` reescrito: Vendedor passa a resolver, em ordem, `responsavel_funcionario_id` → correspondência única de nome (`responsavel_nome` contra `funcionarios.nome`, `ilike` **parcial** já que o texto legado costuma ser só o primeiro nome, ex. "Marina" contra "Marina Pousa Barbara Gregorio") → usuário logado (`funcionarios.usuario_id = auth.uid()`). Sempre reresolve (inclusive limpando pra `'none'`) a cada seleção de projeto — mas só quando `!isEditing`, preservando o comportamento de nunca sobrescrever uma escolha manual já feita ao editar um orçamento existente.

### `src/pages/ProjectNew.tsx` e `src/pages/ProjectDetail.tsx` (CRM)
Removido `.min(1, 'Selecione pelo menos um arquiteto')` do schema Zod (`ProjectNew.tsx`) e o guard de toast equivalente (`ProjectDetail.tsx`), junto com o `*` visual no label — `arquitetos` volta a ser opcional, mas a validação de soma = 100% continua ativa quando a lista não está vazia. Essa exigência tinha sido introduzida horas antes, na SPEC-077 do mesmo dia, a pedido explícito de uma tarefa anterior — a tarefa desta SPEC pediu explicitamente o oposto, então a obrigatoriedade foi revertida.

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos nos dois sistemas.
- Reprodução ao vivo no navegador (login manual do usuário, já que a automação não pode inserir credenciais): projeto "26.250 - vinicius teste" → Cliente autopreenche "Vinicius Bortolin", Vendedor autopreenche "Marina Pousa Barbara Gregorio", busca por "Vinicius" no campo Cliente mostra "VINICIUS BORTOLIN" e "Vinicius Bortolin".
- QA do Skip (setup/staticAnalysis/build/integrations/test) passou nos dois projetos antes do publish.

## Arquivos modificados

| Arquivo | Sistema | Mudança |
| --- | --- | --- |
| `src/hooks/use-options.ts` | Orçamentos | Paginação via `.range()` pra `clientes`, `projetos`, `produtos` |
| `src/pages/BudgetFormPage.tsx` | Orçamentos | Vendedor resolvido via `responsavel_funcionario_id` → nome → usuário logado |
| `src/pages/ProjectNew.tsx` | CRM | `arquitetos` volta a ser opcional no schema (criação) |
| `src/pages/ProjectDetail.tsx` | CRM | `arquitetos` volta a ser opcional na edição (guard removido) |

## Achado sistêmico pendente de decisão

O teto de 1000 linhas do PostgREST (`db-max-rows`) é uma configuração de projeto Supabase, não algo no código — provavelmente afeta outros sistemas (CRM, Compras etc.) que também usem `.limit()` acima de 1000 sem paginar. Duas opções pra considerar depois: (a) levantar o `db-max-rows` no Supabase (config global, benefício amplo, mas exige decisão e teste em todos os sistemas) ou (b) auditar e aplicar o mesmo padrão de paginação onde necessário, sistema por sistema. Não decidido nesta SPEC — fora do escopo dos 3 bugs relatados.
