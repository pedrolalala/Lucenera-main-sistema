---
titulo: "SPEC-053 — Correções do Cadastro de Produto (código automático, criação rápida de marca/fornecedor, referência livre)"
status: implementado e publicado em produção (Skip) em 2026-08-04 (código automático, botões "+", separadores visuais); migration confirmada aplicada no Supabase real — pendente homologação no navegador e esclarecimento sobre "diferença de cor" (item bloqueado, propositalmente não implementado)
data_ultima_modificacao: 2026-07-27
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe)
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - Supabase (banco central)
dependencias:
  - SPEC-018 (criar produto dentro do modal de orçamento)
  - SPEC-030/034 (marcas.fornecedor_id)
---

# SPEC-053 — Correções do Cadastro de Produto

> Origem: reunião com Vinicius em 27/07/2026, `02-Reunioes/12. lucenera (Vinicius) - 27.07.2026_ correcoes necessarias/Reunião.02.txt` e `Reunião.03.txt`. Desmembrada de uma SPEC única por decisão do usuário em 2026-07-27.

## Checklist de Ação

- [x] `cadastro-lucenera-b86fe/src/components/forms/PecaForm.tsx`: tornar `codigo_produto` somente leitura e gerado automaticamente. Campo virou display-only (`Input readOnly disabled`), mostra "gerado automaticamente ao salvar" na criação e o valor real ao editar; o código gerado também aparece no toast de sucesso após salvar.
- [x] Migration nova: **sequence Postgres** (decisão do usuário, 2026-07-27: buracos na numeração são aceitáveis) para `produtos.codigo_produto` — `CREATE SEQUENCE`, `ALTER COLUMN codigo_produto SET DEFAULT nextval(...)`, `setval` inicial em `MAX(codigo_produto)+1`. Redigida em `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/001_sequence_codigo_produto.sql`, incluindo `NOT NULL` (achado da revisão). **Aplicada no Supabase real em 2026-07-27** — confirmado por leitura direta (`column_default = nextval(...)`, `is_nullable = NO`).
- [x] `gestao-financeira-clone-544cb (1)/src/services/productCatalogService.ts` + RPC `criar_produto_orcamento`: remover a validação obrigatória de `codigo_produto` e deixar de aceitar valor vindo do payload, confiando no `DEFAULT` da coluna. RPC reescrita em `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/002_criar_produto_orcamento_sem_codigo.sql` (corpo extraído do `db/current/03_functions.sql` real, só removendo o trecho de `codigo_produto`; resto do comportamento preservado). **Aplicada no Supabase real em 2026-07-27** — confirmado que a função real não menciona mais `codigo_produto`.
- [x] `cadastro-lucenera-b86fe/src/services/produtos.ts` + `PecaForm.tsx`: removido `codigo_produto` do payload de `createProduto()` (já não fazia parte do schema zod do formulário); `createProduto()` já usava `.select().single()`, então o valor gerado volta no retorno do insert e é exibido no toast.
- [x] `PecaForm.tsx` e `ProductCreateModal.tsx`: confirmado que `referencia` é `z.string().optional()` sem regex/máscara em nenhum dos dois formulários, e sem `CHECK` em `produtos.referencia` no schema real — nenhuma mudança de código foi necessária; nenhuma restrição nova foi adicionada.
- [x] `PecaForm.tsx`: adicionado botão "+" ao lado do `SelectField` de Marca, abrindo `MarcaQuickCreateDialog` (campo obrigatório `nome`; opcionais `fornecedor_id`, `prazo_entrega_dias`). Ao salvar, a marca é inserida, a lista local é atualizada e a marca recém-criada já fica selecionada.
- [x] `PecaForm.tsx`: adicionado botão "+" ao lado do `SelectField` de Fornecedor, abrindo `FornecedorQuickCreateDialog` (`contatos.tipo = 'fornecedor'`; campo obrigatório `nome`; opcionais `cnpj`/`razao_social`). Mesmo comportamento de auto-seleção.
- [x] Replicados os dois botões "+" em `gestao-financeira-clone-544cb (1)/src/components/budgets/ProductCreateModal.tsx`, com os mesmos diálogos de criação rápida (implementação própria nesse arquivo, já que é um repositório/app separado).
- [x] `PecaForm.tsx`: aplicado separador visual — cada um dos 4 blocos agora tem `border-2` colorida própria (âmbar/Dados Básicos, azul/Engenharia de Custos, violeta/Dados Fiscais, verde/Estoque Integrado) além do `border-b` já existente sob o título.
- [ ] Adicionar campo de "cor"/"diferença de cor" em `produtos` — **propositalmente NÃO implementado nesta rodada**, continua bloqueado até Vinicius confirmar o formato (ver Pendências); nenhuma coluna equivalente existe hoje em `produtos`.
- [x] Verificado: `marcas_insert` e `contatos_insert` (para `authenticated`) **existem** no schema real (`supabase/db/current/01_schema_full.sql`, linhas ~12964 e ~13783) — não é o cenário "RLS sem policy = deny-all silencioso" da SPEC-049. Achado relevante durante a verificação: `contatos_insert` libera `admin`, `gerente` e `operador`; `marcas_insert` libera só `admin` e `gerente` (exclui `operador`). Ou seja, um usuário `operador` consegue criar fornecedor pelo "+", mas não consegue criar marca pelo "+" (RLS vai rejeitar o INSERT com erro explícito, não silenciosamente). Não decidido/alterado neste SPEC — ver Pendências.

### Passos manuais do usuário

- [ ] Esclarecer o que significa "diferença de cor" no produto: campo de texto simples no mesmo item, ou variação real de produto (nova referência/SKU/estoque por cor)?
- [ ] Confirmar que a restrição de formato relatada por Vinicius no campo "referência do fornecedor" (só aceitava traço e número) realmente existe na versão publicada em produção — não foi encontrada nenhuma máscara/regex/CHECK para esse campo neste espelho local do código.
- [ ] **Aplicar manualmente** a migration `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/` (dois arquivos: `001_sequence_codigo_produto.sql` e `002_criar_produto_orcamento_sem_codigo.sql`) no Supabase real — este agente não aplica migrations. Confirmar que o `setval` inicial (`MAX(codigo_produto)+1`) não colide com nenhum `codigo_produto` já existente.
- [ ] Depois de aplicar a migration, reextrair `supabase/db/current/` (schema + functions) para refletir o novo `DEFAULT` da coluna e o corpo atualizado de `criar_produto_orcamento`.
- [ ] Decidir (decisão de acesso/permissão, não técnica) se `marcas_insert` deveria liberar também o role `operador`, para ficar simétrico com `contatos_insert` — hoje um usuário `operador` consegue criar fornecedor pelo "+" em `PecaForm`/`ProductCreateModal`, mas não consegue criar marca pelo mesmo botão (RLS rejeita o INSERT). Ver Checklist.
- [ ] Homologação manual no navegador em ambos os sistemas: criar produto novo em Cadastro e em Orçamentos e conferir código sequencial sem colisão; criar marca via "+" (como usuário `admin`/`gerente`); criar fornecedor via "+"; salvar `referencia` com letras/`/`/`*`; conferir separação visual dos 4 blocos em `PecaForm.tsx`.

## Objetivo

Corrigir o cadastro de produto para: gerar `codigo_produto` automaticamente (sem edição manual), permitir criar marca/fornecedor sem sair da tela, liberar o formato do campo `referencia`, e melhorar a separação visual dos blocos do formulário — a partir do que Vinicius apontou em reunião.

## Decisões aprovadas

- **Geração de `codigo_produto` (decisão do usuário, 2026-07-27)**: sequence do Postgres, não RPC dedicada. Motivo: existem dois caminhos de INSERT independentes (Cadastro grava direto, Orçamentos passa por RPC) — uma sequence com `DEFAULT` cobre os dois automaticamente e qualquer INSERT futuro, sem depender de nenhum código-fonte lembrar de chamar uma função auxiliar. Buracos na numeração (se um INSERT falhar após consumir um número) são aceitáveis para o negócio.
- `referencia` de produto não tem nenhuma restrição de formato no banco (sem `CHECK`) nem no código-fonte atual — a mudança pedida por Vinicius é, na pior hipótese, garantir explicitamente que nenhuma máscara restritiva seja adicionada, não remover uma que exista hoje neste espelho.

## Definição da SPEC

### Estado atual

Existem **dois formulários de criação de produto** que gravam na mesma tabela canônica `produtos`, com lógica de cálculo de custo praticamente duplicada entre os dois códigos-fonte:

| Sistema | Arquivo | Caminho de gravação |
|---|---|---|
| Cadastro | `cadastro-lucenera-b86fe/src/components/forms/PecaForm.tsx` | INSERT direto via `services/produtos.ts` `createProduto()` |
| Orçamentos | `gestao-financeira-clone-544cb (1)/src/components/budgets/ProductCreateModal.tsx` | RPC `criar_produto_orcamento` (SPEC-018) |

Qualquer mudança nesta SPEC precisa ser aplicada nos dois lugares.

### Tabela de gaps

| Pedido de Vinicius | Estado hoje | Classificação |
|---|---|---|
| Cadastrar marca via "+" no próprio formulário | Não existe em nenhum dos 2 formulários; nenhuma tela de criação rápida de `marcas`/`contatos` existe hoje | claro, ação simples |
| Cadastrar fornecedor via "+" no próprio formulário | Idem acima | claro |
| "Diferença de cor" no produto | Nenhuma coluna `cor`/variação existe em `produtos` | ambíguo — bloqueado, ver Pendências |
| Divisor/borda colorida entre os blocos | Hoje só um `border-b` fino sob cada título de seção | claro, CSS puro |
| Código sequencial automático, campo não editável | `codigo_produto` é `<Input type="number">` livremente editável nos dois formulários; `sku` (campo separado) já é auto-gerado via RPC `get_next_sku` | decidido — sequence |
| Referência aceitar letras, `/`, `*` | Nenhuma restrição encontrada no código-fonte atual nem `CHECK` no banco | claro; ver Pendência sobre drift com produção |

### Análise de ecossistema

- **Depende de**: `produtos`, `marcas`, `contatos` (fornecedores). Não depende de `orcamentos`, `projetos`, `estoque_*`.
- **Afeta**: Cadastro (`PecaForm.tsx`, alvo principal), Orçamentos (`ProductCreateModal.tsx`, alvo secundário). Não afeta CRM, Compras, Financeiro, RH, Hub/TI diretamente.
- **Observação de ecossistema (fora do escopo)**: dois formulários de produto divergentes, lógica de custo duplicada — mesma observação da SPEC-052 sobre falta de fonte única de verdade de UI.

## Critérios de aceite

- Criar um produto novo em `cadastro-lucenera-b86fe` e em `gestao-financeira-clone-544cb (1)` não permite digitar/editar `codigo_produto` manualmente e gera um valor sequencial sem colisão.
- Salvar `referencia` com letras, `/` e `*` não é rejeitado em nenhum dos dois formulários.
- Botão "+" ao lado de Marca cria uma marca nova sem sair do formulário de produto, e ela aparece imediatamente selecionável.
- Botão "+" ao lado de Fornecedor cria um fornecedor novo (`contatos.tipo = 'fornecedor'`) sem sair do formulário de produto.
- Os 4 blocos do formulário em `PecaForm.tsx` têm separação visual clara.

## Testes obrigatórios

Verificação manual no navegador em ambos os sistemas (sem suíte automatizada): criar produto e conferir código automático sem colisão; criar marca/fornecedor via "+"; salvar referência com caracteres especiais.

## Realizado

**2026-07-27** — Implementação pelo agente `implementador`:

- **Banco (migration redigida, não aplicada)**: `supabase/db/migrations/20260727_068_spec053_codigo_produto_sequence/`
  - `001_sequence_codigo_produto.sql`: cria `public.produtos_codigo_produto_seq`, `setval` inicial em `MAX(codigo_produto)+1`, `ALTER TABLE produtos ALTER COLUMN codigo_produto SET DEFAULT nextval(...)`, `ALTER SEQUENCE ... OWNED BY produtos.codigo_produto`.
  - `002_criar_produto_orcamento_sem_codigo.sql`: `CREATE OR REPLACE FUNCTION public.criar_produto_orcamento(p_payload jsonb)` — corpo extraído do `db/current/03_functions.sql` real (linhas 1522-1677 no momento da extração), removendo só a validação/uso de `codigo_produto` do payload; todo o resto (validação de nome, marca, categoria, fornecedor, SKU duplicado, checagem de role) preservado igual.
  - **Achado**: `supabase/db/current/01_schema_full.sql` está desatualizado em relação ao banco real para `public.marcas` — não lista `fornecedor_id` (SPEC-030, migration `20260716_049`) nem `prazo_entrega_dias` (migration `20260715_041`), embora ambas as colunas já estejam documentadas como aplicadas no `CHANGELOG.md` e em `supabase/db/domains/estoque_compras.md`. Os nomes de coluna usados nesta SPEC (`marcas.fornecedor_id` uuid, `marcas.prazo_entrega_dias` integer) foram confirmados lendo os arquivos de migration originais, não o snapshot `db/current`. Recomenda-se reextrair `db/current/` na próxima oportunidade — o mesmo tipo de drift já é mencionado como pendência em `ai_context_global.md`.
  - `supabase/db/domains/cadastros.md` atualizado com uma seção nova documentando essa mudança e o estado "migration redigida, pendente de aplicação".
- **Cadastro (`cadastro-lucenera-b86fe`)**:
  - `src/services/produtos.ts`: adicionadas `createMarca()` e `createFornecedor()` (INSERT direto em `marcas`/`contatos`, com cast `as any` para `fornecedor_id`/`prazo_entrega_dias` de `marcas` por não estarem nos tipos gerados — mesmo padrão já usado no arquivo para views fora dos tipos).
  - `src/components/forms/PecaForm.tsx`: `codigo_produto` removido do schema zod e virou campo somente leitura (mostra "gerado automaticamente ao salvar" na criação, valor real na edição, e no toast de sucesso pós-criação); `checkCodigoExists` deixou de ser chamado no submit; botões "+" para Marca e Fornecedor abrindo `MarcaQuickCreateDialog`/`FornecedorQuickCreateDialog` (modais locais no mesmo arquivo), com auto-seleção do item recém-criado; separação visual (`border-2` colorida por bloco) aplicada aos 4 blocos do formulário.
- **Orçamentos (`gestao-financeira-clone-544cb (1)`)**:
  - `src/services/productCatalogService.ts`: `codigo_produto` removido de `ProductCatalogPayload` (não é mais parte do payload enviado à RPC); adicionado como campo opcional de retorno em `ProductCatalogItem`; adicionadas `createMarcaQuick()`/`createFornecedorQuick()` espelhando as funções equivalentes do Cadastro.
  - `src/components/budgets/ProductCreateModal.tsx`: `codigo_produto` removido do schema zod e do formulário (campo virou display-only "gerado automaticamente ao salvar"); botões "+" replicados para Marca e Fornecedor com os mesmos diálogos de criação rápida (implementação própria neste arquivo); toast de sucesso pós-criação passa a exibir o `codigo_produto` retornado pela RPC.
- **Item propositalmente pulado**: "diferença de cor" em `produtos` — não implementado, conforme instrução explícita da tarefa; permanece bloqueado até Vinicius definir o formato.
- **Verificações rodadas** (sem suíte automatizada nos dois sistemas):
  - `cadastro-lucenera-b86fe`: `npm run lint` (oxlint) sem novos erros/warnings introduzidos; `npm run format:check` (oxfmt) — `PecaForm.tsx` precisou de `oxfmt` (auto-fix aplicado, sem mudança de lógica); `npm run build` (vite build) ok.
  - `gestao-financeira-clone-544cb (1)`: `npm run lint` (oxlint) sem novos erros/warnings introduzidos; `npx prettier --check`/`--write` nos dois arquivos editados (só formatação); `npm run build` (vite build) ok.
- **Não testado neste agente** (precisa de homologação manual no navegador, listada em "Passos manuais do usuário"): golden path de criação de produto em ambos os sistemas, criação de marca/fornecedor via "+", verificação de RLS na prática com um usuário `operador` tentando criar marca.

**2026-07-27 — revisão (agente revisor) e correções:**

- Achado 🔴 crítico: `codigo_produto` era `integer` **sem `NOT NULL`** — `UNIQUE` do Postgres permite múltiplos `NULL`, então publicar o frontend (que já parou de enviar o campo) antes de aplicar a migration, ou qualquer outro caminho de insert que envie `NULL` explicitamente, gravaria produto com `codigo_produto` ausente **silenciosamente**, quebrando casamento por código em buscas e no import de XML Connect sem nenhum erro visível. Corrigido em `001_sequence_codigo_produto.sql`: adicionado backfill defensivo (`UPDATE ... WHERE codigo_produto IS NULL`, usando a própria sequence) seguido de `ALTER TABLE produtos ALTER COLUMN codigo_produto SET NOT NULL` — qualquer insert fora de ordem agora falha alto, com erro claro, em vez de gravar valor ausente.
- Achado 🟡: `supabase/AI_DB_CONTEXT.md` de Orçamentos ainda dizia que a RPC valida/preserva `codigo_produto` do payload — desatualizado desde esta SPEC. Corrigido: as duas menções agora refletem que `codigo_produto` é gerado pelo `DEFAULT` da coluna, sem validação própria na RPC.
- Achado 🟡: warnings novos de `catch (e)` sem uso nos dois `QuickCreateDialog` de `PecaForm.tsx`, e mensagens de erro genéricas demais ("Falha ao criar marca/fornecedor", sem detalhe). Corrigido: `catch (e: any)` com `e?.message` no toast, igual ao padrão já usado no lado Orçamentos — zero warnings novos após a correção (confirmado via `oxlint`).
- Achado 🟡 (menor): `checkCodigoExists()` em `cadastro-lucenera-b86fe/src/services/produtos.ts` ficou órfã após a remoção do seu único chamador. Removida.
- `npx tsc --noEmit` e `npx oxlint` limpos em `cadastro-lucenera-b86fe` após as correções (únicos warnings restantes são pré-existentes, confirmados via comparação antes/depois: tipo `Produto` não usado e um `catch (e)` legado em outro trecho do arquivo, nenhum dos dois introduzido por esta SPEC).

## Pendências

- [ ] Esclarecer o que é "diferença de cor" no produto — campo de texto simples ou variação real de produto (referência/SKU/estoque próprios por cor)? Bloqueia o item correspondente do checklist.
- [ ] Confirmar se a restrição de formato no campo "referência do fornecedor" existe de fato em produção (não encontrada neste espelho local) — pode indicar drift entre o publicado no Skip e este repositório.
- [ ] Aplicar manualmente a migration `20260727_068_spec053_codigo_produto_sequence` no Supabase real e reextrair `supabase/db/current/` depois.
- [ ] Decidir se `marcas_insert` deve passar a liberar o role `operador` (hoje só `admin`/`gerente`), para ficar simétrico com `contatos_insert` (`admin`/`gerente`/`operador`) — achado durante a verificação de RLS pedida pela SPEC, não é uma correção automática deste agente.
- [ ] Reextrair `supabase/db/current/01_schema_full.sql`: o snapshot atual não reflete `marcas.fornecedor_id` (SPEC-030) nem `marcas.prazo_entrega_dias` (migration `20260715_041`), que já estão aplicadas no banco real segundo `CHANGELOG.md`/`estoque_compras.md`. Achado incidental desta SPEC, não causado por ela.
