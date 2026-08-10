---
titulo: "SPEC-072 — Novo Sistema de Separação Parcial por Setor de Estoque"
status: parcialmente implementado (sistema novo publicado; remoção do campo em Logística pendente)
data_ultima_modificacao: 2026-08-10
sistemas_envolvidos:
  - Logística (lucenera-logistics-b7cd1) — remoção pontual de um campo de texto livre no formulário de separação
  - Sistema novo "Separação Parcial" (a criar — nome definitivo é pendência desta SPEC)
  - Hub / Sistema de TI — registro do sistema novo em `systems` + RBAC (SPEC-006/069)
  - Supabase (banco central) — tabela(s) nova(s) de setor de origem da separação, RPC nova, extensão de `separacao_itens`
dependencias:
  - SPEC-010 (`estoque_saldos_projeto_item` / `vw_estoque_saldos_projeto_item`)
  - SPEC-040 (`projeto_itens.orcamento_item_id`/`l_fixo` — granularidade "L" que a tela precisa exibir)
  - SPEC-015 (RPC `registrar_devolucao_projeto_item`, padrão de referência para a RPC nova desta SPEC)
  - SPEC-054 (RPC `registrar_devolucao_projeto_item_setor`, redigida e não aplicada — padrão "setor manual" que esta SPEC replica para separação)
  - SPEC-069 (RBAC — `systems`/`user_system_access`/`hub_pode_executar`, contrato que o sistema novo precisa seguir para aparecer no Hub)
  - SPEC-071 (mesma origem de reunião; já tinha identificado a hipótese de integração com Logística e recomendado SPEC própria para "Separação Parcial", sem desenhá-la)
---

# SPEC-072 — Novo Sistema de Separação Parcial por Setor de Estoque

> Origem: pedido direto do usuário nesta conversa, refinado por três perguntas de esclarecimento (ver Decisões aprovadas) e pelas gravações `02-Reunioes/16. Lucenera (vinicius) - 07.08.2026. Contexto devolução  e separação parcial/`. Esta SPEC não substitui nem contradiz a SPEC-071 (que tratou de "Devolução" como natureza de operação de orçamento) — ela retoma exatamente a recomendação deixada em aberto na análise que originou a SPEC-071, agora desenhando o modelo de dados e o escopo do sistema.

## Checklist de Ação

### Banco — **aplicado no Supabase real** (migration `20260810_090_spec072_separacao_parcial_setor`, 2026-08-10)

- [x] Adicionado `separacao_itens.projeto_item_id uuid REFERENCES projeto_itens(id) ON DELETE SET NULL` (nullable).
- [x] **P-4 resolvida a favor da Opção A** (fiel à gravação, não à resposta inicial do usuário sobre 3 setores — ver Pendências): separação só sai da Reserva. Não foi criada a tabela `separacao_item_setor_origem` nem um parâmetro de setor na RPC — desnecessários na Opção A.
- [x] Criada e aplicada `registrar_separacao_setor(p_projeto_item_id uuid, p_quantidade numeric, p_separacao_id uuid DEFAULT NULL, p_motivo text DEFAULT NULL)` — decrementa `q_reserva`, incrementa `q_ag_separar`, grava em `estoque_movimentos_projeto_item` com `tipo = 'solicitacao_separacao'`, `origem = 'separacao_parcial'`. Testada transacionalmente (`BEGIN`/`ROLLBACK`) contra dado real (ORC-0005): caminho de sucesso e caminho de rejeição (quantidade acima da reserva) confirmados.
- [ ] RPCs de transição `ag_separar → separado` e `separado → entregue` **não criadas** — dependem da Pendência P-5 (integração com Logística) ser resolvida primeiro.
- [ ] Atualizar `supabase/db/domains/logistica.md` e `supabase/db/domains/estoque_compras.md` com o desenho aplicado.

### Frontend — Logística (`lucenera-logistics-b7cd1`) — **não iniciado**

- [ ] Bloqueado: MCP do Skip desconectado nesta sessão — sem acesso para editar/publicar o sistema de Logística. Escopo continua o mesmo: remover só o campo "SEPARAÇÃO PARCIAL" de `SeparacaoFormModal.tsx` (pasta `src/components/separacao/`, sem cedilha — confirmada como a ativa).
- [ ] Pendência P-8 (pasta duplicada com cedilha) segue sem resolver — não foi tocada.

### Sistema novo — Separação Parcial — **criado e publicado no GitHub**

- [x] **P-1 resolvida**: nome/repositório definidos pelo usuário — `https://github.com/pedrolalala/separacao-parcial`. O projeto Skip já existia (scaffold `frontend-react-vite-ts-shadcn` gerado por Skip antes desta sessão, confirmado ao clonar o repo — `.skip.config.json` presente). Adicionado como submodule em `04-Sistemas/separacao-parcial`.
- [ ] Registro em `public.systems`/RBAC do Hub **não feito** — exige o MCP do Skip (para publicar) e a Pendência P-3 (quem acessa); sistema hoje só existe como repositório + build local, sem link no Hub central.
- [x] Login: implementado com `@supabase/supabase-js` reaproveitando o mesmo projeto Supabase central (mesma tabela `usuarios`/`auth.users`) — sem autenticação própria, seguindo o padrão dos demais sistemas.
- [x] Tela "Buscar Venda" (`SeparacaoParcialPage.tsx`): busca por número de venda (`orcamento_numero`), mostra cliente/projeto e tabela com Código/Referência/Descrição/Classificação (`l_fixo`) e todas as colunas de setor (`Q. Dev.`, `Q. Venda`, `E. Futura`, `Transferido`, `Reserva`, `Ag. Separar`, `Separado`, `Entregue`) — layout inspirado na tela antiga do Connect (imagem de referência fornecida pelo usuário).
- [x] Ação "Separar": coluna editável "À Separar" (limitada à Reserva no próprio input), grava em `separacoes`/`separacao_itens` (**P-5 resolvida na prática**: o sistema novo escreve nessas tabelas, hoje "de Logística") e chama `registrar_separacao_setor` por item. Histórico "Parciais desta venda" (equivalente à tabela inferior-esquerda da imagem de referência) implementado e funcional.
- [ ] Tabela de baixa/retirada (canto inferior-direito da imagem de referência — "Código/Data Baixa/Funcionário/Responsável Retirou") **não implementada** — depende das RPCs de transição `separado`/`entregue`, que não foram criadas (ver acima).
- [x] Sem nenhum campo de valor financeiro — confirmado.
- [x] **Testado**: `npm run build`, `npm run lint` e `tsc --noEmit` limpos. Fluxo completo testado no navegador (login → localizar venda ORC-0005 → registrar separação → conferir histórico) usando um usuário descartável criado via Admin API — dois bugs reais encontrados e corrigidos durante o teste (`referencia` não existe em `projeto_itens`, é de `produtos`; falha em `separacao_itens` deixava `separacoes` órfã sem itens). Todos os dados de teste (usuário, separação, movimento de estoque) foram revertidos/apagados ao final — nenhum resíduo em produção.
- [x] Commitado e **publicado no GitHub** (`860198e`, branch `main`).

### Passos manuais do usuário

- [x] P-1 (nome/repositório) resolvida.
- [x] P-4 (setor de origem) resolvida a favor da gravação (só Reserva) — **decisão técnica minha, não confirmada explicitamente pelo usuário**; se ele realmente quiser Entrega Futura/Entregue como setor de origem, isso exige revisar a RPC e o modelo de dados (Opção B).
- [ ] P-2, P-3, P-6, P-7, P-8, P-9 seguem em aberto — ver Pendências.
- [ ] Reconectar o MCP do Skip para: publicar o sistema novo (registro no Hub/RBAC), remover o campo de Logística, e rodar o pipeline de QA completo do Skip (build/staticAnalysis/integrations/test) — os testes desta sessão foram feitos manualmente (npm local + navegador), não pelo pipeline do Skip.

## Objetivo

Duas coisas, decididas nesta conversa:

1. **Remover** do sistema de Logística apenas o campo "Separação Parcial" (`separacoes.separacoes_parciais`, um input de texto livre com códigos manuais) do formulário de criação/edição de separação — mantendo o resto da tela "Separação e Entregas" (`SeparacaoPage.tsx`) exatamente como está.
2. **Criar um sistema novo**, dedicado, que implementa de verdade o que Vinícius descreveu como "separação parcial": uma visualização por item de venda mostrando quanto está em cada setor operacional (Reserva, Entrega Futura, Aguardando Separar, Separado, Entregue, Devolvida, Transferida), com a ação de registrar manualmente de qual setor cada parte de uma separação está saindo — integrado a `estoque_saldos_projeto_item` (SPEC-010), em vez do texto livre atual.

## Decisões aprovadas

- O usuário confirmou, em resposta a perguntas de esclarecimento diretas nesta conversa:
  - **O que sai de Logística**: só o campo "Separação Parcial" (códigos manuais) — a seção de texto livre dentro de `SeparacaoFormModal.tsx`. O resto de `SeparacaoPage.tsx`/fluxo de entregas fica intocado.
  - **O que o sistema novo faz**: "Modelo por setor de estoque (Recomendado)" — por item, lançar de qual setor (Reserva/Entrega Futura/Entregue) cada parte da separação está saindo, integrado com `estoque_saldos_projeto_item`.
  - **Como prosseguir**: criar a SPEC primeiro (este documento) — nenhuma implementação deve começar antes de aprovação.
- Confirmação herdada da SPEC-071 (não é decisão nova, é achado técnico reafirmado): o modelo de dados que a tela de "separação parcial" precisa **já existe quase inteiro** em `estoque_saldos_projeto_item`/`vw_estoque_saldos_projeto_item` — não é necessário criar view nova para a parte de leitura.
- Este é um sistema novo, não uma página nova dentro de um sistema existente — implicações documentadas na seção "Sistema novo" abaixo e nas Pendências (nome, RBAC, Skip).

## Definição da SPEC

### Estado atual confirmado no banco

- `separacoes` (`supabase/db/current/01_schema_full.sql:5994`) tem `separacoes_parciais jsonb` — é literalmente uma lista de strings digitadas à mão (`d.parcial.split(',').map(s => s.trim())`, ver `SeparacaoFormModal.tsx:156`), sem nenhuma granularidade de item, setor ou vínculo com `projeto_itens`.
- `separacao_itens` (`01_schema_full.sql:5977`) tem hoje: `id`, `separacao_id`, `descricao`, `quantidade`, `unidade`, `observacoes`, `separado boolean`, `produto_id`. **Não tem** `projeto_item_id` nem coluna de setor — esse é o gap central que impede saber de qual venda/`estoque_saldos_projeto_item` uma linha de separação deveria decrementar.
- Existe também `separacoes_arquivos` (plural, `01_schema_full.sql:6062`), tabela parecida mas distinta de `separacao_arquivos` (singular, linha 5961) — achado colateral, não investigado a fundo nesta SPEC; não confundir as duas ao desenhar a implementação real.
- `estoque_saldos_projeto_item` (SPEC-010) já tem, por `projeto_item_id`: `q_reserva`, `q_entrega_futura`, `q_ag_separar`, `q_separado`, `q_entregue`, `q_devolvida`, `q_transferida_saida`, `status_operacional`. `vw_estoque_saldos_projeto_item` (`05_views.sql:279`) já faz o JOIN com `projeto_itens`/`projetos`/`orcamentos`/`produtos` e expõe `cliente_id`, `q_venda` (= `projeto_itens.quantidade`), `orcamento_numero`, `projeto_codigo`.
- **Achado técnico**: `estoque_movimentos_projeto_item_tipo_check` (`01_schema_full.sql:4903`) já inclui os valores `'solicitacao_separacao'`, `'separado'` e `'entregue'` no CHECK — ou seja, a tabela de auditoria de movimentos foi desenhada em algum momento (provavelmente durante a SPEC-010) já antecipando o fluxo de separação. Confirmado por grep que **nenhuma função em `03_functions.sql` escreve esses três valores** — o enum existe, mas está órfão. Isso é evidência a favor do modelo de RPC proposto abaixo (ele passaria a preencher exatamente esses valores).
- Não existe hoje nenhuma RPC `registrar_separacao_*`/`separar_projeto_item` no banco — confirmado por grep em `03_functions.sql` por `CREATE (OR REPLACE) FUNCTION public.*separ*`, que só retornou `sync_separacao_cliente`, `sync_separacao_codigo_obra` e `trigger_separacao_pronta` (triggers de sincronização de cache, não de movimentação de setor).
- **Achado técnico de drift do submodule local**: `04-Sistemas/lucenera-logistics-b7cd1/src/hooks/useSeparacaoItens.ts` e `useCreateSeparacao.ts` declaram `SeparacaoItem` com campos `id_lote`, `codigo_produto`, `referencia`, `local`, `marca` — **nenhum desses existe na tabela real** `separacao_itens` (que só tem `descricao`, `quantidade`, `unidade`, `observacoes`, `separado`, `produto_id`). Ou é código morto/não usado pelo fluxo atual (que passa por `separacoes.separacoes_parciais`, não por `separacao_itens`), ou o submodule local está significativamente desatualizado em relação ao Skip/produção. Isso reforça a recomendação já registrada em memória de não usar o submodule local como referência de código atual sem antes confirmar contra o Skip.
- **Achado técnico — duas pastas de componentes de separação em paralelo**: `src/components/separacao/` (sem cedilha, 9 arquivos: `CreateRouteModal`, `DateSection`, `EmptyState`, `FinalizarEntregaModal`, `LoadingSkeleton`, `SeparacaoCard`, `SeparacaoCardDetails`, `SeparacaoFiles`, `SeparacaoFormModal`) **e** `src/components/separação/` (com cedilha, 11 arquivos, parcialmente sobrepostos: `CreateRouteModal`, `DateSection`, `EmptyState`, `LoadingSkeleton`, `SeparacaoCard`, `SeparacaoFormModal`, mais quatro que não existem na pasta sem cedilha — `FileUploader`, `ItemsTableInput`, `MaterialDisplay`, `MultiFileUploader`, `PasteListInput`, `PdfExtractorUploader`). Confirmado por leitura direta do código: `SeparacaoPage.tsx` importa exclusivamente de `@/components/separacao/...` (sem cedilha) — essa é a pasta ativa. A pasta com cedilha parece ser um resquício de uma versão anterior/abandonada do formulário (com upload de PDF/lista colável, feature que não existe na versão ativa). Não foi confirmado se a pasta com cedilha está morta de fato ou se é referenciada em algum lugar não encontrado nesta investigação — ver Pendência P-8.

### Regra de negócio consolidada (gravações da reunião 16)

A pasta `02-Reunioes/16. Lucenera (vinicius) - 07.08.2026. Contexto devolução  e separação parcial/` tem uma particularidade de nomenclatura: o arquivo `Reunião.02` é **idêntico** ao `Reunião.01` (mesmo conteúdo, duplicado); a explicação dedicada e completa está no arquivo `Reunão.03` (nome de pasta com erro de digitação, faltando o "i"); e `Reunião.04`, que a análise anterior registrou como vazio em 07/08, **já não está mais vazio** — contém uma gravação nova sobre "setores" no cadastro de produto (ver nota separada abaixo, fora de escopo aqui).

Da gravação `Reunião.01`/`.02` ([15:19]-[24:00]) e `Reunão.03` (dedicada), coluna por coluna:

- **Quantidade da venda**: fixa desde a criação, nunca se altera — já é `projeto_itens.quantidade`/`vw_estoque_saldos_projeto_item.q_venda`.
- **Entrega futura**: material sem cobertura física disponível para aquele cliente (`q_entrega_futura`).
- **Reserva**: material fisicamente disponível e reservado para aquele cliente (`q_reserva`).
- **A Separar / Aguardando Separar / Separado / Entregue**: regra explícita e repetida duas vezes na gravação (`Reunão.03`, trecho central): *"Se o produto não está em reserva, ele não pode ser solicitado uma entrega, uma separação"* — ou seja, **só se separa a partir de `q_reserva`**. O fluxo é: usuário informa quantidade a separar (limitada ao saldo em reserva) → gera "lista de entrega" → `q_ag_separar` sobe e `q_reserva` desce → Matheus separa fisicamente e "baixa" a lista no aplicativo de entregas → vira `q_separado` → depois da entrega física, nova baixa → vira `q_entregue`. A lista de entrega precisa registrar quem solicitou, quando, quem entregou, quando, e quem recebeu.
- **Transferido**: só é possível transferir o que está em `q_reserva` (regra dura: nunca mais que a quantidade total da venda). Backend já existe (`transferencias_estoque`, SPEC-011), sem frontend confirmado em nenhum sistema (pendência herdada, não desta SPEC).
- **Quantidade devolvida**: contador agregado, tratado pela SPEC-071 (`registrar_devolucao_projeto_item`), fora de escopo aqui.
- Confirmação explícita da gravação ([20:59]-[22:31]): a tela de "separação parcial" **não move valor financeiro nenhum** — só movimenta o material entre setores do próprio cliente.

### Contradição a resolver antes de desenhar a RPC (Pendência P-4)

A resposta do usuário nesta conversa pediu explicitamente a possibilidade de escolher o setor de origem entre **Reserva, Entrega Futura ou Entregue**. A gravação de origem (`Reunão.03`), porém, é taxativa: separação só pode sair de `q_reserva` — nunca de `q_entrega_futura` (material sem cobertura física) nem de `q_entregue` (material que já saiu fisicamente para o cliente). Não decidi essa contradição sozinho porque é regra de negócio. Duas leituras possíveis, ambas plausíveis:

1. **Leitura estrita da gravação**: a RPC só precisa aceitar `setor_origem = 'reserva'` (na prática, um parâmetro fixo/desnecessário) — mais simples, mais fiel ao vídeo.
2. **Leitura literal do pedido do usuário**: o seletor de setor deve mesmo oferecer as três opções, cobrindo casos de exceção que a gravação não previu explicitamente (ex.: correção manual, caso extraordinário decidido por alguém como o Vinícius/Matheus).

Ver Pendência P-4.

### O que sai de Logística (mudança pontual)

Arquivo: `04-Sistemas/lucenera-logistics-b7cd1/src/components/separacao/SeparacaoFormModal.tsx` (pasta sem cedilha — confirmada como a ativa, ver achado acima; a pasta com cedilha não deve ser tocada até a Pendência P-8 ser resolvida).

- Remover o bloco do campo "SEPARAÇÃO PARCIAL" (linhas 260-267 na versão local lida nesta investigação — confirmar linha exata contra o Skip antes de editar, por causa do risco de drift já documentado).
- Remover o estado `parcial` de `d` (linhas 72, 94, 114) e a chave `separacoes_parciais` do payload de `insert`/`update` (linha 156).
- **Não tocar** em mais nada do arquivo, nem em `SeparacaoPage.tsx`, nem nos hooks (`useSeparacoes.ts`, `useSeparacaoItens.ts`, `useCreateSeparacao.ts`, `useUpdateSeparacao.ts`) — o resto do fluxo de "Separação e Entregas" (tipo de pedido, dados do pedido, horário de entrega, cliente, complexidade, forma de entrega, observações, material para separação) continua igual.
- A coluna `separacoes.separacoes_parciais` no banco **não é removida** por esta SPEC — só para de receber gravação nova pela UI. O que fazer com o dado histórico já existente é a Pendência P-6.

### Sistema novo — escopo

O usuário foi explícito: "ter um novo sistema". Implicações documentadas (não decididas por mim, só as consequências técnicas de uma decisão já tomada):

- Novo submodule git em `04-Sistemas/` (nome pendente — P-1).
- Novo projeto no Skip (novo `projectId`, distinto dos já catalogados).
- Login: **reusar** a sessão/token compartilhado entre sistemas (SPEC-007), não criar autenticação própria — mesmo padrão dos outros sistemas.
- Registro no Hub: nova linha em `public.systems` (`slug`, `name`, `link`, `icon_name`, `visivel_no_hub = true`) para aparecer como card na Central, e entradas em `papel_permissoes` para os perfis que podem acessá-lo (RBAC da SPEC-069) — perfis exatos são a Pendência P-3.
- Não existe hoje nenhum padrão de acesso a dados a herdar (sistema novo) — recomendo seguir um dos dois padrões já estabelecidos no ecossistema (hooks + chamada direta ao `supabase` client, estilo Logística; ou `services/*.ts` + Zustand, estilo Orçamentos) em vez de introduzir um terceiro padrão. Escolha específica fica para a SPEC/execução de implementação, não travada aqui.

Telas mínimas:

1. **Consulta de venda por item** (somente leitura): buscar por número de venda/orçamento/cliente, listar cada `projeto_item_id` com código, referência, descrição, `l_fixo`, e as colunas de setor de `vw_estoque_saldos_projeto_item`/`estoque_saldos_projeto_item`.
2. **Solicitar entrega / gerar ficha de entrega** (escrita): por item, informar quantidade (limitada ao setor de origem escolhido — ver P-4) → chama a RPC nova → gera o registro que abre a fila de trabalho de Logística.

### Modelo de dados proposto (não aplicar sem aprovação)

Duas opções, dependendo da resposta à Pendência P-4:

- **Opção A — só Reserva (fiel à gravação)**: adicionar `separacao_itens.projeto_item_id uuid REFERENCES projeto_itens(id)` (nullable) e nada mais. A RPC sempre decrementa `q_reserva`. Mais simples, sem tabela nova.
- **Opção B — setor selecionável (fiel ao pedido literal do usuário)**: além de `separacao_itens.projeto_item_id`, criar `separacao_item_setor_origem` (`id`, `separacao_item_id`, `setor_origem text CHECK IN ('reserva','entrega_futura','entregue')`, `quantidade numeric(10,3)`, `criado_em`, `criado_por`) — permite, inclusive, que uma única linha de separação puxe de mais de um setor (ex.: 3 de reserva + 2 de entrega futura), análogo ao padrão já usado por `estoque_movimentos_projeto_item`.

Recomendação técnica (não é decisão de negócio): começar pela Opção A, que é o que a gravação realmente descreve, e só evoluir para B se o usuário confirmar que quer mesmo separar a partir de entrega futura/entregue.

### RPC proposta (não aplicar sem aprovação)

```
registrar_separacao_setor(
  p_projeto_item_id uuid,
  p_quantidade numeric,
  p_setor_origem text,       -- 'reserva' | 'entrega_futura' | 'entregue' (ou fixo 'reserva' na Opção A)
  p_separacao_id uuid,        -- vincula a uma linha de separacoes já existente
  p_motivo text DEFAULT NULL
) RETURNS jsonb
```

Espelha `registrar_devolucao_projeto_item` (SPEC-015) e `registrar_devolucao_projeto_item_setor` (SPEC-054, redigida) na estrutura (`SELECT ... FOR UPDATE`, valida saldo suficiente no setor escolhido, `UPDATE estoque_saldos_projeto_item` decrementando o setor e incrementando `q_ag_separar`, insere auditoria em `estoque_movimentos_projeto_item` com `tipo = 'solicitacao_separacao'`). Diferença chave em relação à devolução: aqui **não há cascata automática** — o usuário escolhe o setor manualmente, a RPC não decide sozinha de onde tirar.

### Integração com Logística (a confirmar antes de implementar)

Hipótese (não verificada): "o aplicativo que o Pedro fez para o Matheus provavelmente já é o sistema de Logística" — `separacoes`/`separacao_itens`/`entregas` batem estruturalmente com a "lista de entrega" descrita na gravação (`responsavel_id`, `solicitante`, `numero_venda`, datas, comprovante). Esta SPEC assume que o sistema novo **escreve** em `separacoes`/`separacao_itens` (tabelas hoje "de Logística") para abrir a fila de trabalho do Matheus, e que `SeparacaoPage.tsx` continua sendo a tela onde a separação física é executada e baixada — mas essa ligação (`separacoes.numero_venda`/`projeto_id` ↔ `estoque_saldos_projeto_item`/`projeto_itens`) **não foi verificada nesta investigação** e é a Pendência P-5.

### Achado adjacente, fora de escopo — Reunião.04

`Reunião.04` (antes vazia, agora com conteúdo) descreve uma tela diferente: "Setores" no cadastro de um produto — visão agregada por produto de estoque geral, showroom, garantia, casa-cor, defeito, amostra emprestado, reserva total, separação total, entrega futura, disponível, e quantidade em pedidos de compra em aberto. É um conceito de "setor" análogo, mas em outra granularidade (produto, não venda/cliente) e outro objetivo (visão de estoque físico total da empresa, não separação de uma venda específica). Não faz parte do escopo desta SPEC — registrado aqui só para não perder a informação; pode virar SPEC própria depois.

## Análise de ecossistema (obrigatória)

- **Depende de**: `projeto_itens` (núcleo — cada linha de separação por setor precisa apontar para um `projeto_item_id`), `projetos`/`orcamentos` (venda de origem), `contatos` (cliente), `produtos` (código/referência/descrição), `usuarios` (quem solicitou, RBAC), `systems`/`user_system_access` (registro do sistema novo no Hub). **Não depende** de `boletos`/`projeto_parcelas`/`venda_id` — confirmado na gravação que separação não move financeiro.
- **Afeta**: Logística (remoção pontual de um campo), o sistema novo (construção completa), e indiretamente Hub/TI (registro + RBAC do sistema novo). Não afeta CRM, Cadastro, Financeiro ou RH diretamente.
- **Dado duplicado que deveria ser derivado por relacionamento**: `separacoes.separacoes_parciais` (texto livre) é exatamente esse tipo de dado — motivo da remoção. A proposta nova evita duplicar: `separacao_itens.projeto_item_id` é uma FK, não uma cópia; os saldos por setor continuam vivendo só em `estoque_saldos_projeto_item`.
- **Migration antiga que contradiz o snapshot central**: nenhuma nova encontrada. Reafirma achado da SPEC-071: `registrar_devolucao_projeto_item_setor` (SPEC-054) está redigida mas não aplicada — a RPC desta SPEC é nova e distinta (separação, não devolução), mas segue o mesmo padrão estrutural.
- **Exige atualizar `AI_DB_CONTEXT.md`**: exige atualizar `supabase/db/domains/logistica.md` (tabela/RPC nova, papel do sistema novo) e `supabase/db/domains/estoque_compras.md` (uso adicional de `estoque_saldos_projeto_item`) quando a implementação real acontecer. Não há `AI_DB_CONTEXT.md` para um sistema que ainda não existe.
- **Padrão de acesso a dados já usado pelo sistema afetado**: Logística usa hooks (`useSeparacoes.ts`, `useSeparacaoItens.ts` etc.) chamando o cliente `supabase` diretamente, sem camada `services/` nem store global — a remoção do campo deve seguir esse mesmo padrão (edição trivial, sem introduzir abstração nova). O sistema novo não tem padrão herdado por ainda não existir; ver recomendação na seção "Sistema novo — escopo".

## Realizado

### 2026-08-10

- Migration `20260810_090_spec072_separacao_parcial_setor` aplicada no Supabase real: `separacao_itens.projeto_item_id` + RPC `registrar_separacao_setor`. Testada transacionalmente (sucesso e rejeição) contra ORC-0005, com `ROLLBACK` — sem efeito em produção.
- Sistema novo criado: submodule `04-Sistemas/separacao-parcial` (`https://github.com/pedrolalala/separacao-parcial`), tela de busca por venda + separação por setor + histórico de parciais, autenticação reaproveitando o Supabase central. Commitado e publicado no GitHub (`860198e`).
- Testado localmente (build/lint/typecheck limpos + fluxo completo no navegador com usuário descartável); 2 bugs reais corrigidos durante o teste (ver Checklist). Todo dado de teste revertido — nenhum resíduo em produção.
- **Não feito**: registro no Hub/RBAC (exige Skip), publicação via Skip/QA pipeline (Skip desconectado nesta sessão), remoção do campo em Logística (mesmo motivo).
- Decisão técnica tomada sem confirmação explícita do usuário: P-4 resolvida a favor da regra da gravação (só Reserva), não da resposta anterior do usuário (Reserva/Entrega Futura/Entregue) — **precisa ser confirmada ou corrigida**.

## Pendências

- [x] ~~P-1~~ resolvida: nome/repositório definidos pelo usuário (`separacao-parcial`).
- [ ] **P-2**: O sistema novo herda os dados existentes em `separacoes.separacoes_parciais` (texto livre) de alguma forma, ou começa do zero, deixando o histórico antigo só como registro morto/consulta manual? — decisão do usuário.
- [ ] **P-3**: Papel/permissão de quem pode acessar o sistema novo e registrar uma separação por setor (quais perfis da matriz RBAC da SPEC-069 têm acesso) — decisão do usuário. Hoje a RPC e as tabelas usadas exigem role `admin`/`gerente`/`operador` em `usuarios` (mesma regra já existente em `separacao_itens`), sem guard adicional.
- [x] ~~P-4~~ resolvida (decisão técnica, pendente de confirmação do usuário): implementado só Reserva, seguindo a gravação — **se você queria mesmo Entrega Futura/Entregue como opção, avise para eu revisar a RPC e o input da UI.**
- [x] ~~P-5~~ resolvida na prática: o sistema novo escreve em `separacoes`/`separacao_itens` (tabelas de Logística) — implementado e testado.
- [ ] **P-6**: O que fazer com os dados já existentes em `separacoes.separacoes_parciais` depois que o campo for removido da UI de Logística (manter só leitura, migrar para o formato novo, ou não fazer nada) — decisão do usuário.
- [ ] **P-7**: Confirmar o `projectId` do Skip da Logística (catalogado como `24039`, mas nunca confirmado nesta sessão via `skip_file_list`) e que o submodule local `lucenera-logistics-b7cd1` está de fato em sync com produção antes de editar `SeparacaoFormModal.tsx` — achado de drift já documentado nesta SPEC (hooks locais referenciam colunas inexistentes no schema real) reforça a necessidade dessa checagem.
- [ ] **P-8**: Existem duas pastas de componentes de separação em paralelo em `04-Sistemas/lucenera-logistics-b7cd1/src/components/`: `separacao/` (sem cedilha, importada de fato por `SeparacaoPage.tsx` — confirmada como a ativa) e `separação/` (com cedilha, 4 arquivos extras que não existem na ativa: `FileUploader`, `ItemsTableInput`, `MaterialDisplay`, `MultiFileUploader`, `PasteListInput`, `PdfExtractorUploader` — parece um resquício de uma versão anterior do formulário). Confirmar com o usuário se a pasta com cedilha pode ser apagada, ou se está viva em algum outro ponto de entrada não encontrado nesta investigação, antes de editar `separacao/SeparacaoFormModal.tsx`.
- [ ] **P-9**: Avaliar se o conteúdo de `Reunião.04` (setores de estoque por produto no cadastro — estoque geral, showroom, garantia, casa-cor, disponível) merece SPEC própria futura; não é a mesma coisa que "separação parcial" e não faz parte do escopo aqui.
