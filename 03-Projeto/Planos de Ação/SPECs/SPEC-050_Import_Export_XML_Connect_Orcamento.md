---
titulo: "SPEC-050 — Importação e Exportação de XML (padrão Connect) no Novo Orçamento"
status: publicado no Skip — pendente de migration real no Supabase e homologação manual
data_ultima_modificacao: 2026-07-27
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb)
  - script python power point (consumidor futuro do XML exportado, referência do parser legado)
---

# SPEC-050 — Importação e Exportação de XML (padrão Connect) no Novo Orçamento

> Pedido do usuário: "preciso adicionar um novo campo no sistema de orçamento na aba novo orçamento. preciso usar o xml gerado pelo sistema, para importar um orçamento feito no sistema que está ativo atualmente na empresa e também preciso que quando um orçamento seja criado tenha a possibilidade de gerar um XML também, assim consigo ter um controle e seguir o mesmo padrão do sistema já existente [...] (connect_system é a empresa que fornece o sistema deve ser trocado para Laghi_systems)".

## Checklist de Ação

- [x] Migration: `orcamentos.origem_connect_cod_orcamento integer` + índice `UNIQUE` parcial (`WHERE origem_connect_cod_orcamento IS NOT NULL`) + `orcamentos.origem_connect_importado_em timestamptz` (rastreabilidade e idempotência do import). Redigida, **não aplicada no Supabase real** (ver Passos manuais).
- [x] Estender `src/hooks/use-options.ts` (`gestao-financeira-clone-544cb`): query de `empresas` passa a selecionar também `codigo, cnpj` (hoje só `id, nome`) — necessário para casar `cod_empresa`/`cnpj_empresa` do XML.
- [x] Novo módulo `src/lib/xml-budget-import.ts` — parser client-side (DOMParser) do XML Connect, porta simplificada da lógica de `04-Sistemas/script python power point/data_manager.py` (`OrçamentoParser`), sem a lógica de agrupamento/PowerPoint (`_agrupar_por_*`, `calcular_peso_produto`, `classificar_componente`), que não se aplica aqui. Resolve `cliente_id`/`empresa_id`/`produto_id` contra os arrays já carregados por `useOptions()`.
- [x] Novo módulo `src/lib/xml-budget-export.ts` — serializador que monta o XML a partir do `orcamento`/`itens` atuais, com raiz `<Laghi_systems>` em vez de `<connect_systems>`, preservando a estrutura interna de tags dos itens.
- [x] Novo componente `src/components/budgets/ImportConnectXmlModal.tsx` — upload de 1 arquivo `.xml`, mostra resumo (itens casados/não casados, cliente/empresa resolvidos ou não, e alerta de idempotência) antes de aplicar no formulário via `form.reset`/`replace` (mesmo padrão de `handleBatchComplete`).
- [x] Botão "Importar XML (Connect)" em `BudgetFormPage.tsx`, ao lado do botão "Importar PDFs" existente.
- [x] Botão "Exportar XML" em `BudgetFormPage.tsx`, na barra de ações do topo (ao lado de "Cancelar"/"Salvar Alterações"), visível apenas quando `isEditing && budgetToEdit` (orçamento já persistido).
- [x] Atualizar `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md` com as novas colunas de `orcamentos`.
- [x] Atualizar `supabase/db/domains/orcamentos.md` registrando as novas colunas e a decisão de idempotência por `origem_connect_cod_orcamento`.
- [x] Atualizar `CHANGELOG.md` após implementação.

### Passos manuais do usuário

- [x] Responder as perguntas da seção "Pendências" antes de qualquer implementação — usuário aprovou P-1, P-2, P-3 e P-6 explicitamente; P-4, P-5 e P-7 foram implementados com o comportamento padrão/recomendado já proposto pela própria SPEC (arredondamento sem bloqueio, export do estado em tela, nomes de coluna como redigidos); P-8 ficou fora do escopo (ver Pendências).
- [x] **Correção pós-revisão (2026-07-27)**: achado crítico do `revisor` — `quantidade`/`desconto` estavam sendo arredondados para inteiro no import (`Math.round(qtyRaw)`, `Math.max(1, ...)`), inflando/reduzindo valores financeiros silenciosamente para itens fracionários reais (ex. metro linear de perfil, `qtd_produto` `4,5`/`2,5` confirmados em XML real). Corrigido em `xml-budget-import.ts` (3 casas p/ quantidade, 2 casas p/ desconto, sem `Math.round` p/ inteiro) e espelhado em `xml-budget-export.ts` (`computeItemSubtotal`, `buildItemXml`). Também corrigido `findOrcamentoJaImportado()` para propagar erro de rede/permissão em vez de tratá-lo como "não importado ainda" (aviso do revisor). `vite build` re-executado após o fix, sem erros.
- [ ] Rodar a migration no Supabase real (`SUPABASE_DB_URL`) e confirmar via SELECT que as colunas novas existem.
- [ ] Homologar manualmente: importar um dos XMLs reais de exemplo (`04-Sistemas/script python power point/6702.xml` ou os de `Arquivos/XML para analise/`) na tela "Novo Orçamento" e conferir visualmente cliente/itens/valores antes de salvar.
- [ ] Homologar manualmente: reimportar o mesmo XML uma segunda vez e confirmar que o bloqueio de idempotência aparece.
- [ ] Homologar manualmente: exportar um orçamento real já salvo e abrir o XML gerado, conferindo a raiz `Laghi_systems` e a estrutura de itens.
- [x] Publicar a nova versão do sistema `gestao-financeira-clone-544cb (1)` (Skip, projeto 32554) — feito em 2026-07-27 (ver Realizado). Homologação manual (itens abaixo) ainda pendente, agora em produção.

## Objetivo

Permitir que, na tela "Novo Orçamento" do sistema de Orçamentos (`gestao-financeira-clone-544cb (1)`), o usuário possa:

1. **Importar** um arquivo XML no formato do ERP concorrente "Connect" (raiz `<connect_systems><orcamento>...`), preenchendo automaticamente cliente, empresa e itens do orçamento a partir dos dados do arquivo.
2. **Exportar** um orçamento criado no Lucenera para um arquivo XML na mesma estrutura, mas com a tag raiz trocada de `connect_systems` para `Laghi_systems` — identificando a origem como o sistema próprio (Laghi/Lucenera), mantendo compatibilidade estrutural com quem hoje lê esse formato (o script `04-Sistemas/script python power point`, que só depende dos elementos `<Item>` e é indiferente à tag raiz e ao cabeçalho).

Isso dá à empresa um caminho de migração gradual do Connect para o Lucenera sem perder o formato de dado já em uso operacional (planilhas, script de PowerPoint) e sem redigitação manual de orçamentos já lançados no sistema legado.

## Decisões aprovadas

- A raiz do XML exportado pelo Lucenera é `Laghi_systems`, distinta de `connect_systems` (usado pelo Connect) — decisão explícita do usuário, para diferenciar a origem do documento.
- A estrutura interna das tags de item (`<Item><indice>...</Item>`) deve permanecer idêntica entre import e export, para não quebrar compatibilidade com o parser existente em `04-Sistemas/script python power point/data_manager.py`.
- O parser Python existente (`OrçamentoParser` em `data_manager.py`) é a referência de campos e de like-for-like de parsing, mas sua lógica de agrupamento/hierarquia de peso (voltada para gerar slides de PowerPoint) não faz parte desta SPEC — aqui o XML só precisa virar linhas de `orcamento_itens`.
- `desc_classificacao` do XML mapeia para `orcamento_itens.custom_id` ("L Fixo"), mesmo conceito já confirmado no domínio de Orçamentos/Compras pela SPEC-040.
- `contatos.codigo_legado` é a chave de conciliação de cliente com o Connect (já era usada com esse papel antes desta SPEC, conforme `03-Projeto/00_INDICE.md` linha 78 e Escopo Cadastro SPEC-CAD-02) — reaproveitada aqui, não criada por esta SPEC.
- **Produto (decisão do usuário, 2026-07-27, verificado no banco real)**: `produtos.codigo_produto` e `produtos.codigo_legado` são, na prática, o mesmo valor — de 4.726 produtos, só 1 diverge (e esse 1 tem `codigo_legado` nulo). `codigo_produto` é a chave primária de match do `cod_produto` do XML (0 nulos, contra 1 nulo em `codigo_legado`), com `produtos.referencia` como fallback.
- `projeto_codigo` continua obrigatório no formulário mesmo após import de XML — o Connect não tem o conceito de "projeto" Lucenera, então esse campo nunca é preenchido automaticamente pelo import.
- **Produto sem match no XML (decisão do usuário, P-1)**: item entra no orçamento como "avulso" — sem `produto_id`, só com a `descricao` do XML — mesmo padrão já usado no import de PDF (`handleBatchComplete`).
- **Cliente sem match no XML (decisão do usuário, P-2)**: o import abre automaticamente o `ClientCreateModal` já existente. Como o XML só traz `cod_cliente` (não traz nome/CNPJ do cliente), o modal abre vazio/sem pré-preenchimento útil — usuário cadastra manualmente e o import retoma depois de criado.
- **`dt_devolucao` (decisão do usuário, P-3)**: ignorado no import — não mapeia para nenhum campo do Lucenera nesta SPEC.
- **`<cod_orcamento>` no XML exportado (P-6, assumindo a opção recomendada por falta de resposta direta do usuário — CONFIRMAR antes de implementar)**: usa `orcamentos.numero` (ex. `ORC-0010`), mesmo não sendo puramente numérico como no Connect.

## Definição da SPEC

### Estado atual (confirmado por leitura de código)

- `BudgetFormPage.tsx` já tem um fluxo de import equivalente para PDF: botão "Importar PDFs" → `BatchPdfImport` (dialog) → Edge Function `parse-budget-pdf` → `handleBatchComplete` (linha 859) → popula `form` via `form.reset`/`replace(sortItemsByCircuitId(...))`. **Não existe fluxo de export de XML nem de import de XML hoje.**
- `handleBatchComplete` já resolve cliente/empresa/vendedor/arquiteto por nome (fuzzy `includes`) e produto por `custom_id`/descrição contra o array `produtos` carregado por `useOptions()`. Para XML, a resolução deve ser **exata** por código (`codigo_legado`), não fuzzy por texto — o XML traz identificadores estruturados que o PDF não tem.
- `useOptions()` já carrega `clientes` com `codigo_legado` e `produtos` com `codigo_legado`/`codigo_produto`/`referencia`/`sku` — suficiente para resolução client-side sem round-trip ao banco. `empresas` **não** traz `codigo`/`cnpj` hoje — precisa de ajuste de query (item do checklist).
- `orcamento_itens` **não tem** coluna `subtotal` (diferente de `projeto_itens`, que tem `subtotal GENERATED ALWAYS`). Para export, o subtotal do item deve ser calculado em runtime: `quantidade * preco_unitario * (1 - desconto/100)`.
- Nenhuma tabela hoje guarda o `cod_orcamento` original do Connect — sem isso, reimportar o mesmo XML duas vezes cria dois orçamentos Lucenera distintos sem detecção.

### Migration necessária

```sql
-- supabase/db/migrations/20260727_065_spec050_import_export_xml_connect/001_orcamentos_origem_connect.sql
ALTER TABLE public.orcamentos
  ADD COLUMN origem_connect_cod_orcamento integer,
  ADD COLUMN origem_connect_importado_em timestamptz;

CREATE UNIQUE INDEX orcamentos_origem_connect_cod_orcamento_uidx
  ON public.orcamentos (origem_connect_cod_orcamento)
  WHERE origem_connect_cod_orcamento IS NOT NULL;
```

Não cria tabela nova, não cria trigger, não mexe em RLS (herda as policies já existentes de `orcamentos`; são colunas novas, não linhas/tabela nova).

**Pendência de nomenclatura**: nomes de coluna acima (`origem_connect_cod_orcamento`, `origem_connect_importado_em`) são uma proposta, não uma decisão fechada — confirmar com o usuário antes de escrever a migration real.

### Mapeamento de campos — Cabeçalho do XML → `orcamentos`

| Campo XML | Formato no XML | Campo Lucenera | Observação |
|---|---|---|---|
| `cod_orcamento` | inteiro (ex. `6702`) | `orcamentos.origem_connect_cod_orcamento` (novo) | chave de idempotência — import bloqueado se já existir orçamento com esse valor |
| `cod_empresa` | inteiro (ex. `1`) | resolve `empresas.id` via `empresas.codigo` | fallback se `cnpj_empresa` não achar |
| `cnpj_empresa` | `24.090.967/0001-63` | resolve `empresas.id` via `empresas.cnpj` | prioridade sobre `cod_empresa` (mais específico) |
| `cod_cliente` | inteiro (ex. `2552`) | resolve `orcamentos.cliente_id` via `contatos.codigo_legado` | **obrigatório no schema** (`cliente_id` não é nullable na prática pelo formSchema); sem match, ver Pendência P-2 |
| `cod_tabela_preco` | frequentemente vazio nos exemplos reais | sem destino | ignorar no import |
| `vl_total_orcamento` | `143833,89` (vírgula) | não persistido diretamente — `valor_total` é recalculado pelo formulário a partir dos itens | usar só como conferência/warning se divergir da soma calculada |
| `dt_orcamento` | `dd/mm/aaaa` | `orcamentos.data_emissao` | conversão de formato de data |
| `dt_devolucao` | `dd/mm/aaaa` | **incerto** — candidato: `orcamentos.validade` | ver Pendência P-3, nome sugere conceito diferente de "validade" |

### Mapeamento de campos — Item do XML (`<itens><Item>`) → `orcamento_itens`

| Campo XML | Formato | Campo Lucenera | Observação |
|---|---|---|---|
| `indice` | inteiro | usado só para ordenação do import, não persistido | `orcamento_itens` não tem coluna equivalente hoje |
| `desc_classificacao` | ex. `L01`, `P01` | `orcamento_itens.custom_id` | "L Fixo" — letra do XML deve ser preservada (parser Python já faz isso; `formatCircuitId` do frontend também preserva letras não-`L`, mas nunca testado com caso real de `P`) |
| `cod_produto` | inteiro (ex. `11261`) | resolve `orcamento_itens.produto_id` via `produtos.codigo_produto` | chave primária de conciliação — confirmado no banco real que `codigo_produto` e `codigo_legado` são o mesmo valor em 4.725 de 4.726 produtos; `codigo_produto` usado por ter 0 nulos (vs. 1 nulo em `codigo_legado`) |
| `referencia` | texto (ex. `3649-AB-S-PX`) | fallback: `produtos.referencia` | usado só se `cod_produto` não achar |
| `cod_setor` | inteiro | sem destino | ignorar |
| `cod_produto_grade` | inteiro | sem destino | ignorar |
| `desc_produto` | texto | `orcamento_itens.descricao` | sempre grava o snapshot textual, mesmo quando `produto_id` foi resolvido (diferente do comportamento atual do import de PDF, que zera `descricao` quando acha produto — proposta aqui é sempre preservar o texto original do XML) |
| `qtd_produto` | inteiro/decimal | `orcamento_itens.quantidade` | |
| `vl_unitario` | decimal com **vírgula**, até 3 casas (ex. `212,454`) | `orcamento_itens.preco_unitario` (`numeric(12,2)`) | conversão vírgula→ponto + arredondamento para 2 casas — ver Pendência P-4 (perda de precisão) |
| `desconto_produto` | decimal | `orcamento_itens.desconto` | |
| `vl_total_produto` | decimal | não persistido — recalculado (não existe coluna `subtotal` em `orcamento_itens`) | usar só como conferência/warning |
| `vl_tributos` | decimal | sem destino | ignorar |
| `vl_item_aux` | decimal | sem destino | ignorar |
| `desc_marca` | texto (ex. `LUCENERA`) | **não persistir** — deriva de `produtos.marca_id → marcas.nome` quando produto casado | evita duplicação de dado que já existe por relacionamento |
| `desc_categoria` | texto | **não persistir** — deriva de `produtos.categoria` quando produto casado | idem |
| `especificacao` | texto livre (pode conter dimensão de nicho) | sem destino direto | ignorar no import (não há campo equivalente em `orcamento_itens`) |
| `historico_orcamento` | texto livre (às vezes `"(Memo)"` vazio) | sem destino | ignorar |
| `saida`, `dev_haver`, `dev_troca`, `dev_defeito` | flags numéricas (0/-1) | sem destino | são flags operacionais/pós-venda do Connect (saída de estoque, devolução), não se aplicam a uma proposta ainda não aprovada — ignorar no import |

### Fluxo de importação (proposto)

1. Usuário clica "Importar XML (Connect)" na tela Novo/Editar Orçamento → abre `ImportConnectXmlModal`.
2. Upload de 1 arquivo `.xml` → parse client-side via `DOMParser` (módulo `xml-budget-import.ts`, portando a extração de campos de `OrçamentoParser.parse_xml()`).
3. Resolve `empresa_id` (por `cnpj_empresa`, fallback `cod_empresa`), `cliente_id` (por `cod_cliente` → `contatos.codigo_legado`) e `produto_id` por item (por `cod_produto` → `produtos.codigo_legado`, fallback `referencia`) contra os arrays já carregados por `useOptions()`.
4. Modal mostra um resumo antes de aplicar: quantos itens foram casados com produto, quantos ficaram "avulsos" (sem `produto_id`), se cliente/empresa foram resolvidos, e um aviso de idempotência (verifica se já existe `orcamentos.origem_connect_cod_orcamento` igual, via query pontual).
5. Ao confirmar, popula o `form` (mesmo padrão de `handleBatchComplete`: `form.reset(...)` para cabeçalho + `replace(sortItemsByCircuitId([...]))` para itens) — **não salva automaticamente**; o usuário revisa e clica "Criar Orçamento" normalmente.
6. `projeto_codigo` continua exigido manualmente — não vem do XML.

### Fluxo de exportação (proposto)

1. Botão "Exportar XML" visível apenas em modo edição (`isEditing && budgetToEdit`).
2. Módulo `xml-budget-export.ts` monta a árvore XML a partir do estado atual do formulário (`form.getValues()`), com raiz `<Laghi_systems><orcamento>...`, replicando a mesma estrutura de tags de item usada no import (inclusive as que não têm dado real — exportadas vazias/zero, mesmo padrão observado nos XMLs reais do Connect, ex. `cod_tabela_preco` frequentemente vazio).
3. Gera `Blob` e dispara download no navegador (`orcamento_<numero>.xml`) — sem Edge Function, sem escrita no banco.

### Tratamento de erro / dados não encontrados

Comportamento **decidido pelo usuário** (2026-07-27):

- Produto sem match → item importado sem `produto_id`, com `descricao` = `desc_produto` do XML (item "avulso", mesmo conceito já usado no domínio — ver `orcamentos.md`, caso ORC-0013).
- Cliente sem match → abre automaticamente o `ClientCreateModal` já existente (sem pré-preenchimento — o XML só traz `cod_cliente`, não nome/CNPJ); usuário cadastra e o import retoma.
- Empresa sem match → bloquear (campo obrigatório do formulário, `empresa_id`) — não perguntado diretamente ao usuário, segue o mesmo tratamento de "campo obrigatório sem match" já usado hoje no import de PDF; confirmar se deveria ter o mesmo tratamento do cliente (abrir cadastro) antes de implementar.
- `origem_connect_cod_orcamento` já existente no banco → bloquear import com mensagem clara ("Este orçamento Connect já foi importado como ORC-XXXX").

### Análise obrigatória de ecossistema

- **Depende de**: `orcamentos`, `contatos`, `produtos`, `projetos` (indiretamente, via `projeto_codigo` continuar obrigatório), `empresas`. Não depende de `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems`, `user_system_access` — esta SPEC atua inteiramente antes da aprovação financeira.
- **Afeta**: Orçamentos (sistema principal). Não afeta CRM, Financeiro, Estoque/Compras, Logística, RH ou Hub/TI diretamente — mas cria um formato de saída (XML export) que pode vir a ser consumido futuramente pelo `script python power point` (fora de escopo desta SPEC).
- **Dado duplicado que deveria ser derivado por relacionamento**: `desc_marca`/`desc_categoria` do XML — a proposta é **não** persistir esses campos em `orcamento_itens`, derivando sempre de `produtos.marca_id`/`produtos.categoria` via `produto_id`, evitando duplicação.
- **Migration antiga que contradiz o snapshot central**: não identificada relacionada a este domínio específico; nota-se (achado já documentado em `supabase/db/domains/estoque_compras.md`) que `aprovar_orcamento_financeiro` real diverge de `supabase/db/current/` em outros aspectos — não afeta esta SPEC, que atua só na criação/edição do orçamento, antes da aprovação.
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim, do sistema `gestao-financeira-clone-544cb (1)`, pelas colunas novas em `orcamentos`.
- **Padrão de acesso a dados já usado pelo sistema**: hooks (`useOptions`) + acesso direto ao client Supabase + store (`useBudgetStore`) para persistência. Sem camada `services/`. Os novos módulos (`xml-budget-import.ts`, `xml-budget-export.ts`) devem seguir esse mesmo padrão — acesso direto via `supabase` client e reaproveitamento dos arrays já carregados por `useOptions()`, sem introduzir uma camada de serviço nova que o sistema não usa hoje.

### Critérios de aceite (verificação manual, sem suíte de testes automatizada)

- Importar um dos XMLs reais de exemplo em ambiente de preview: cliente, empresa e itens aparecem corretamente preenchidos no formulário antes de salvar (golden path no navegador).
- Reimportar o mesmo XML uma segunda vez é bloqueado com mensagem clara.
- Exportar um orçamento salvo gera um arquivo `.xml` com raiz `Laghi_systems` e a mesma estrutura de tags de item do formato Connect, abrível/parseável sem erro.
- `npm run build` (ou equivalente do sistema) passa sem erros de tipo após as alterações.
- SELECT de conferência no Supabase confirma as colunas novas em `orcamentos` e o preenchimento correto de `origem_connect_cod_orcamento` após um import real.

## Realizado

**27/07/2026** — Implementação completa do código (agente implementador), a partir da SPEC já aprovada pelo usuário incluindo P-1, P-2, P-3 e P-6:

- Migration redigida (não aplicada): `supabase/db/migrations/20260727_065_spec050_import_export_xml_connect/001_orcamentos_origem_connect.sql` — `orcamentos.origem_connect_cod_orcamento integer`, `orcamentos.origem_connect_importado_em timestamptz`, índice único parcial `orcamentos_origem_connect_cod_orcamento_uidx`.
- `src/hooks/use-options.ts` (`gestao-financeira-clone-544cb (1)`): query de `empresas` passa a trazer `codigo, cnpj`.
- `src/lib/xml-budget-import.ts` (novo): `parseConnectXml()` (DOMParser, busca `<orcamento>`/`<Item>` independente da tag raiz — funciona tanto para XML `connect_systems` de entrada quanto, em tese, para reimportar um `Laghi_systems` exportado pelo próprio sistema), `resolveConnectXmlImport()` (resolve `empresa_id` por `cnpj` com fallback `codigo`, `cliente_id` por `contatos.codigo_legado`, `produto_id` por item via `produtos.codigo_produto` com fallback `referencia`, filtrando sempre pelo array `produtos` de origem `source === 'produtos'` para não casar acidentalmente com `revenda_ubiqua`) e `findOrcamentoJaImportado()` (query pontual de idempotência).
- `src/lib/xml-budget-export.ts` (novo): `buildConnectXmlExport()` monta o XML com raiz `Laghi_systems`, mesma ordem/estrutura de tags de item observada no XML real de exemplo (`04-Sistemas/script python power point/6702.xml`), usando `orcamentos.numero` como `<cod_orcamento>` (P-6); `downloadXmlFile()` dispara o download via `Blob`, sem Edge Function.
- `src/components/budgets/ImportConnectXmlModal.tsx` (novo): upload de 1 XML, parse + resolução + checagem de idempotência ao selecionar o arquivo, resumo visual (empresa/cliente/itens casados-avulsos, alerta de duplicidade), bloqueia aplicar quando há conflito de idempotência ou empresa não resolvida; quando cliente não resolvido, delega ao componente pai via `onClienteNaoEncontrado` (P-2).
- `src/pages/BudgetFormPage.tsx`: botão "Importar XML (Connect)" ao lado de "Importar PDFs"; botão "Exportar XML" na barra de ações do topo, visível só quando `isEditing && budgetToEdit`; `applyResolvedXmlImport()` popula o formulário (mesmo padrão de `handleBatchComplete`, preservando sempre a `descricao` do XML mesmo quando o produto foi casado — diferente do import de PDF); fluxo de retomada após cadastro de cliente via `ClientCreateModal` já existente (`pendingXmlImport`); `origem_connect_cod_orcamento`/`origem_connect_importado_em` só entram no payload de salvamento quando um import de XML foi de fato aplicado nesta sessão de edição (`connectOrigin`).
- `src/stores/useBudgetStore.ts`: `Budget` ganhou os dois campos opcionais novos, para o payload de `addBudget`/`updateBudget` tipar corretamente.
- Documentação: `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md` e `supabase/db/domains/orcamentos.md` atualizados com as novas colunas e a decisão de idempotência.
- Verificação: `oxlint src` (0 erros, 14 avisos pré-existentes em arquivos não tocados por esta SPEC), `prettier --check` (limpo nos arquivos tocados) e `vite build` (sucesso) rodados em `gestao-financeira-clone-544cb (1)`. Nenhum teste automatizado existe neste sistema — golden path no navegador (import de XML real, reimport bloqueado, export) ainda precisa ser validado manualmente pelo usuário.

**27/07/2026 (publicação)** — Os 7 arquivos alterados/criados por esta SPEC foram publicados no projeto Skip Cloud `gestao-financeira-clone-544cb (1)` (id 32554), que mantém working tree própria, separada do submodule local (ver `AGENTS.md`/lição já registrada em memória): `src/hooks/use-options.ts`, `src/stores/useBudgetStore.ts`, `src/lib/xml-budget-import.ts` (novo), `src/lib/xml-budget-export.ts` (novo), `src/components/budgets/ImportConnectXmlModal.tsx` (novo), `src/pages/BudgetFormPage.tsx`, `supabase/AI_DB_CONTEXT.md` — escritos via `skip_file_write`, commitados e buildados via `skip_project_apply_changes(mode=production)` (QA completa: setup/static/build/integrations/test todos `ok`), e publicados via `skip_project_publish` (versão `0.0.296`, ref `22458c0`). Confirmado no bundle real de produção (`https://gestao-financeira-clone-544cb.goskip.app`) via `curl` + grep pelas strings distintivas `Laghi_systems` e `origem_connect_cod_orcamento` — ambas presentes, ou seja, o app publicado (não só o commit) já serve o código novo. **A migration real no Supabase ainda não foi rodada** — as colunas `origem_connect_cod_orcamento`/`origem_connect_importado_em` não existem no banco ainda, então o app publicado vai falhar ao tentar gravar/ler esses campos até a migration ser aplicada (ver Passos manuais).

## Pendências

- [x] **P-1 resolvida (usuário, 2026-07-27)**: produto sem match → item avulso, sem `produto_id`, só com a `descricao` do XML.
- [x] **P-2 resolvida (usuário, 2026-07-27)**: cliente sem match → import abre o `ClientCreateModal` já existente automaticamente (sem pré-preenchimento, o XML não traz nome/CNPJ).
- [x] **P-3 resolvida (usuário, 2026-07-27)**: `dt_devolucao` ignorado no import, sem mapeamento.
- [x] **P-4 implementada com o padrão proposto (não confirmada explicitamente pelo usuário)**: `vl_unitario` do XML é arredondado para 2 casas (`orcamento_itens.preco_unitario numeric(12,2)`), sem aviso/bloqueio de divergência contra `vl_total_produto`/`vl_total_orcamento` do XML. Se o usuário quiser um aviso de divergência por item, isso ainda não existe e precisaria de nova iteração.
- [x] **P-5 implementada com o padrão proposto (não confirmada explicitamente pelo usuário)**: "Exportar XML" usa `form.getValues()` — reflete o estado atual em tela, incluindo edições ainda não salvas, não o último estado persistido no banco.
- [x] **P-6 resolvida (usuário aprovou explicitamente ao pedir a implementação, 2026-07-27)**: `<cod_orcamento>` no XML exportado usa `orcamentos.numero` (ex. `ORC-0010`).
- [x] **P-7 resolvida (usuário aprovou explicitamente ao pedir a implementação, 2026-07-27)**: nomes de coluna implementados exatamente como redigidos na SPEC — `orcamentos.origem_connect_cod_orcamento`, `orcamentos.origem_connect_importado_em`.
- [ ] **P-8 (esclarecimento de negócio, ainda em aberto — não implementada)**: itens de orçamento importados sem `produto_id` (avulsos) **não** ficam rastreáveis de volta ao `cod_produto`/`referencia` originais do XML — essa informação é descartada após o parse, só a `descricao` textual (`desc_produto`) é gravada. Se o usuário quiser conciliação futura por código original, é necessária uma coluna nova em `orcamento_itens` (fora do escopo desta implementação).
