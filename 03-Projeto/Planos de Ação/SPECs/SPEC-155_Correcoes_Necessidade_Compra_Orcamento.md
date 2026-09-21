---
titulo: "SPEC-155 — Correções Necessidade de Compra + Orçamento (relatório de testes reais do Vinícius, 2026-09-21)"
status: P1 (bugs críticos) em correção; P2/P3/P4 planejados, aguardando execução/alinhamento
data_ultima_modificacao: 2026-09-21
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — Bug 1 e Bug 2 (P1)
  - Compras (compras-lucenera-3o23t98ee) — P2, P3, P4
dependencias:
  - SPEC-152 (Plano de Parcelas customizável — origem dos dois bugs de P1, regressão introduzida nela)
  - SPEC-038 (compras-lucenera, base do módulo de Compras)
---

# SPEC-155 — Correções Necessidade de Compra + Orçamento

> Origem: relatório de testes reais feitos pelo administrador geral (Vinícius) em produção, repassado pelo usuário em 2026-09-21 ("Prompt para o Cláudio"). Cobre 2 bugs críticos que bloqueiam o uso hoje (P1), ajustes de usabilidade em Necessidade de Compra (P2), uma nova regra de negócio para o fluxo de aprovação de pedido de compra (P3) e itens que dependem de alinhamento pessoal com o Vinícius antes de implementar (P4).

## PRIORIDADE 1 — Bugs críticos (bloqueiam o uso hoje)

### Bug 1 — `column "status" is of type parcela_status but expression is of type text`

**Sintoma relatado**: ao aprovar orçamento (ou depois de mudar a forma de pagamento e tentar salvar de novo), o sistema retorna esse erro de tipo do Postgres.

**Causa raiz confirmada** (2026-09-21, leitura direta do código): regressão da **SPEC-152**, introduzida por mim mesmo nesta mesma migration. Em
`supabase/db/migrations/20260917_152_melhorias_orcamento/005_aprovar_orcamento_financeiro_plano_parcelas.sql`,
duas ocorrências do mesmo padrão (ramo venda, linha ~464, e ramo devolução, linha ~284):

```sql
CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END,
```

Um `CASE` cujos dois ramos são literais de string sem contexto de tipo é resolvido pelo parser do Postgres
como `text` (diferente de um literal solto em `VALUES`, que herda o tipo da coluna de destino via coerção
implícita de "unknown"). A coluna `projeto_parcelas.status` é do enum `public.parcela_status`, que **não tem
cast de atribuição automático a partir de `text`** — daí o erro, em qualquer aprovação que passe por essas
duas linhas (ou seja: toda aprovação financeira desde que a SPEC-152 foi aplicada, 2026-09-17).

**Correção**: cast explícito do resultado do `CASE` para o enum, nos dois pontos:

```sql
(CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
```

- [x] Migration nova (`supabase/db/migrations/20260921_155_fix_cast_parcela_status/001_fix_cast_status.sql`)
      que recria a função `aprovar_orcamento_financeiro` com as duas linhas corrigidas — `CREATE OR REPLACE
      FUNCTION`, não é alteração de schema, então não há risco de dados, só corrige o bug de tipo. Causa
      raiz confirmada reproduzindo o erro exato num teste isolado contra o banco real (INSERT numa tabela
      temporária com coluna `parcela_status`, com e sem o cast) antes de escrever a correção. Dry-run
      (ROLLBACK) passou limpo — falta só a aplicação real (pendente de confirmação do usuário).
- [x] Verificado: grep por `CASE WHEN.*THEN '.*' ELSE '.*' END,` em todas as migrations não encontrou
      nenhuma outra ocorrência do mesmo padrão além das duas já corrigidas.

### Bug 2 — Permuta sem fornecedor só é acusada na aprovação, não na seleção

**Sintoma relatado**: ao selecionar "Permuta" numa parcela do Plano de Parcelas (aba "Pagamento e Totais"),
nada indica que o campo "Fornecedor da parcela" é obrigatório — o erro só aparece depois, ao tentar aprovar
financeiramente o orçamento (`FinancialApprovalDialog.tsx`, que apenas repassa a mensagem crua da RPC:
`Parcela X está marcada como permuta mas não tem fornecedor definido.`).

**Causa raiz confirmada**: o backend (`aprovar_orcamento_financeiro`, validação da SPEC-152) está correto e é
a fonte de verdade final — isso não muda. O problema é puramente de UX em
`04-Sistemas/gestao-financeira-clone-544cb (1)/src/pages/BudgetFormPage.tsx`:

- O `<Select>` de "Fornecedor da permuta" (por volta da linha 3410-3435) não tem nenhuma indicação visual de
  obrigatório (sem asterisco, sem borda vermelha, sem texto de erro inline) quando a parcela está com
  `forma_pagamento = 'permuta'` e o campo está vazio.
- Existe uma validação no `onSubmit` (linha ~1467) que lança erro se faltar o fornecedor, mas só dispara ao
  tentar **salvar o orçamento** — e só quando `!editandoAprovado`. Um orçamento já salvo sem essa checagem
  rodar (ex. editado num fluxo onde `editandoAprovado` é `true`) pode chegar até a tela de aprovação
  financeira sem nunca ter sido barrado antes.

**Correção**:

- [x] No `<Select>` de "Fornecedor da permuta": quando `formaLinha === 'permuta'`, placeholder passou a
      `Fornecedor da permuta *`, borda fica vermelha e aparece aviso inline abaixo do campo quando vazio.
      Banner vermelho consolidado adicionado também no rodapé do "Plano de Parcelas" (mesmo padrão do
      banner já existente de "soma das parcelas"), calculado com a mesma lógica de fallback do `onSubmit`.
      `npx tsc --noEmit` passou limpo.
- [x] Investigado: `editandoAprovado` só é `true` quando o orçamento JÁ está com `status = 'Orçamento
      Aprovado'` (parcelas reais já geradas) — não é o caminho relevante pra este bug (que acontece num
      orçamento ainda em "Aprovação Financeira", tentando aprovar pela primeira vez). Nesse caminho a
      validação de submit já rodava e bloqueava; o gap real era só a falta de indicação visual antes do
      submit, que é o que foi corrigido acima.
- [ ] `FinancialApprovalDialog.tsx` continua mostrando a mensagem da RPC como rede de segurança final (não
      alterado), mas o objetivo é o usuário nunca chegar lá sem o fornecedor preenchido.

## PRIORIDADE 2 — Módulo Necessidade de Compra

### Filtro da tela

- [x] Investigado: a tela `NecessidadeCompra.tsx` (lista de produtos, `vw_necessidade_compra`) já filtra
      `pendente > 0` no banco (confirmado via `pg_get_viewdef` direto em produção — `WHERE GREATEST(0,
      necessidade_compra - qtd_em_pedidos_abertos) > 0`, da SPEC-039). O relato do projeto "atendido"
      aparecendo é do painel expansível **"Ver projetos"** dentro de cada linha de produto
      (`NecessidadeCompraDetalhe.tsx`), que decidiu deliberadamente (SPEC-103, parte 1 revisão 2) mostrar
      TODO projeto vinculado ao produto, mesmo já coberto por pedido de compra em aberto — com checkbox
      desabilitado em vez de esconder a linha. O usuário agora quer o oposto (esconder).
- [x] Corrigido em `04-Sistemas/compras-lucenera-3o23t98ee/src/components/compra/NecessidadeCompraDetalhe.tsx`:
      novo `rowsPendentes = rows.filter((r) => !!r.item)` (`r.item` só existe quando
      `vw_necessidade_compra_item_orcamento` ainda reconhece saldo pendente de fato) — projeto sem saldo
      real deixa de aparecer no painel. `npx tsc --noEmit` passou limpo.

## PRIORIDADE 3 — Modal "Gerar Compra por Item de Orçamento" (usabilidade)

- [x] Modal aumentada (1040px → 1440px).
- [x] Coluna "Líquido (R$)" alargada (90px → 130px), valor exibido por inteiro.
- [x] Impostos (ICMS, IPI, ST) viraram somente leitura (deixaram de ser `<Input type="number">`),
      continuam vindo automaticamente do cadastro do produto via `getProdutoImpostosBulk`.
- [x] Validação de incremento decimal no campo ST resolvida como efeito colateral direto do item acima —
      não é mais um input numérico editável, não existe mais o que travar.
- [x] Campo Fornecedor adicionado, visível no corpo do formulário (antes só aparecia no título da modal).
- [x] Campo Empresa (emitente) adicionado — achado real no meio da implementação: este modal (Fluxo B)
      nunca coletava `empresa_id` nenhum, diferente do Fluxo A (`ModalPedidoLote.tsx`), que já tinha esse
      campo obrigatório. Todo pedido criado por aqui ficava sem empresa emitente vinculada. Corrigido:
      campo `<Select>` obrigatório, mesmo padrão do Fluxo A.
- [x] Campo de Desconto (%, opcional) adicionado — exige migration nova (nenhuma coluna equivalente
      existia em `pedidos_compra`), ver abaixo.
- [x] Campo de Local de entrega (opcional) adicionado — mesma migration.
- [x] Spinners (setinhas de incremento) removidos dos campos numéricos editáveis (quantidade, líquido,
      desconto) via classes Tailwind arbitrary-variant.

**Migration nova**: `supabase/db/migrations/20260921_155_modal_compra_desconto_local_entrega/001_pedidos_compra_desconto_local_entrega.sql`
— `pedidos_compra.desconto_percentual` (numeric(5,2), CHECK 0-100) e `pedidos_compra.local_entrega` (text),
+ `criar_pedido_compra_lote` recriada com 2 parâmetros novos no final da assinatura (`DEFAULT NULL`,
compatível com chamadas antigas) que aplicam o desconto sobre `valor_total` antes do INSERT. Dry-run
(ROLLBACK) passou limpo — falta só a aplicação real (mesma confirmação pendente do usuário que a migration
do Bug 1). `npx tsc --noEmit` passou limpo depois de todas as mudanças de frontend.

**Revisado pelo `revisor`** (comparou byte a byte contra `pg_get_functiondef` real de produção, confirmando
que a migration ainda não foi aplicada e que nenhuma lógica além do desconto/colunas novas mudou): sem
achado crítico. 1 aviso real corrigido antes do commit — o campo "Desconto negociado (%)" não clampava
0-100 na digitação (negativo inflava a prévia de "total com desconto" mas o submit descartava o valor
silenciosamente; >100 mostrava total negativo na prévia até a RPC rejeitar). Corrigido clampando
`descontoNum` em `[0, 100]` num único lugar, usado tanto na prévia quanto no valor enviado.

## PRIORIDADE 4 — Fluxo de aprovação de pedido de compra (nova regra de negócio)

> Fluxo desenhado pelo Vinícius — **alinhar o desenho com ele pessoalmente antes de fechar o design final**,
> conforme nota explícita do próprio relatório. Implementação abaixo é o entendimento a partir do texto
> recebido, não uma decisão de negócio já validada em todos os detalhes.

- [ ] Fluxo: envia pedido → aguarda devolutiva do fornecedor/gestor → devolutiva pode trazer alterações.
- [ ] Permitir editar o pedido depois de salvo, durante o ciclo de aprovação (hoje não é possível).
- [ ] Parcelas só devem ser geradas **depois** do pedido efetivamente aprovado (com as alterações da
      devolutiva já incorporadas) — não mais na criação do pedido.
- [ ] Parcelas aprovadas entram como previsibilidade de pagamento no fluxo de caixa, rotuladas "Pedido de
      compra em aberto" — **rótulo/estrutura exata de integração com fluxo de caixa fica pendente de
      alinhamento com o Vinícius** (não implementar essa parte sem confirmar onde e como o fluxo de caixa
      real consome isso).
- [ ] Revisar o carregamento infinito ("Carregando parcelas...") do pedido 1771 na tela Pedidos de Compra —
      no novo modelo (parcelas só existem pós-aprovação), o loading deve resolver para "sem parcelas ainda"
      em vez de girar infinitamente quando o pedido ainda não tem parcela.

## Pendências / alinhamento com Vinícius (não implementar ainda)

- [ ] Nomenclatura/dados fiscais no modal de compra ("C. PROD. OU DESPESA" e espelho dos impostos do
      cadastro de produto) — definir com o Vinícius antes da implementação final (pode mudar o resultado do
      item de P3 sobre impostos read-only).
- [ ] Estrutura e navegação do módulo de compras completo (Necessidade de Compra → Estoque → Solicitações →
      Cotações → Pedidos → Entrada de NF → Marcas) está em revisão — não redesenhar navegação como parte
      desta SPEC.

## Ordem de execução

1. Bug 1 (cast enum) — desbloqueia aprovar/salvar.
2. Bug 2 (validação de fornecedor da permuta no frontend).
3. Filtro da Necessidade de Compra (saldo > 0).
4. Modal de geração de compra (9 ajustes de usabilidade).
5. Fluxo de aprovação de pedido de compra (P4) — só depois de alinhar o desenho com o Vinícius.
