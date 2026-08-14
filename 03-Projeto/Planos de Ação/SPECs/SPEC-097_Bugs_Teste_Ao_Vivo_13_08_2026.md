---
titulo: "SPEC-097 — Bugs achados e corrigidos no teste ao vivo de 13/08/2026"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
  - CRM
  - Orçamentos
  - Compras / Necessidade de Compra
  - Banco de dados (função aprovar_orcamento_financeiro)
---

# SPEC-097 — Bugs achados e corrigidos no teste ao vivo de 13/08/2026

> Origem: pedido do usuário pra testar ao vivo tudo que tinha sido
> publicado nas SPECs 088-096 (fechamento da reunião com Vinícius de
> 11/08), e depois construir um projeto fictício de ponta a ponta
> (CRM → Orçamentos) especificamente pra achar bugs que o teste anterior
> não tinha coberto. Nenhuma dessas correções estava planejada — todas
> foram achadas reagindo a comportamento real da aplicação, não por
> revisão de código.

## Checklist de Ação

- [x] Corrigir embed ambíguo em `listarParciaisPorVenda` (Separação Parcial)
- [x] Corrigir SPEC-096 incompleta — `ContatoDetail.tsx` (CRM)
- [x] Preencher endereço/telefone automaticamente ao finalizar separação (Separação Parcial)
- [x] Corrigir `custom_id` vazio ao adicionar L (Orçamentos)
- [x] Corrigir `subgrupo` vazio ao criar orçamento novo (Orçamentos)
- [x] Corrigir painel "Responsável (Sistema)" lendo campo morto (Orçamentos)
- [x] Corrigir título hardcoded do "Resumo Fiscal" (Orçamentos)
- [x] Corrigir prioridade errada de `descricao` em `projeto_itens` (RPC `aprovar_orcamento_financeiro`) + backfill retroativo

### Passos manuais do usuário

- [x] Nenhum — todas as correções foram publicadas e verificadas ao vivo pela própria sessão.

## Objetivo

Registrar formalmente 6 bugs reais de produção — nenhum coberto pelo QA
automatizado do Skip (build/lint/test) — encontrados exclusivamente por
clicar nas telas reais e, no caso dos 3 últimos, por montar um projeto de
teste completo do zero e tentar seguir o fluxo até o fim. Todos corrigidos,
publicados e confirmados ao vivo no mesmo dia.

## Decisões aprovadas

- Deixar o projeto de teste (`99.901 — TESTE BUG SWEEP`, cliente "TESTE BUG
  SWEEP CLIENTE", orçamento `ORC-0021`) em produção, claramente identificado
  no nome — não seria seguro/necessário apagar via SQL manual no meio da
  sessão, e o registro serve de evidência de que o fluxo funciona de ponta
  a ponta.

## Definição da SPEC

### 1. Embed ambíguo em `listarParciaisPorVenda` (Separação Parcial)

**Causa raiz**: a migration da SPEC-090 adicionou `alterado_por` como 2ª FK
de `separacoes` para `usuarios`. Com 2 FKs pro mesmo destino, o embed
implícito `usuarios(nome)` já usado no serviço virou ambíguo pro PostgREST
— quebrava o carregamento do histórico de parciais em produção.

**Fix**: `usuarios!responsavel_id(nome)` — aponta explicitamente pra FK
certa. Arquivo: `separacaoParcialService.ts`.

**Publicado**: Skip 48801, v0.0.21 (hash `99202ce`).

### 2. SPEC-096 incompleta — layout do cadastro de cliente (CRM)

**Causa raiz**: a correção original (reordenar Tipo Cliente/RG/Inscrição
Estadual) só foi aplicada em `ClientFormFields.tsx`, componente usado
apenas no modal "Novo Cliente" (`Clientes.tsx`). A tela real de
visualizar/editar um cliente já existente (`/contatos/clientes/:id`) usa
um componente totalmente separado, `ContatoDetail.tsx`, com sua própria
lista `FIELD_CONFIGS.cliente` hardcoded — nunca alcançado pela mudança
original.

**Fix**: mesmo reordenamento (`tipo_cliente` logo após `cpf_cnpj`; `rg` e
`inscricao_estadual` adjacentes) aplicado também em `ContatoDetail.tsx`.

**Publicado**: Skip 24580, v0.0.303 (hash `51daa56`).

### 3. Entrega automática sem endereço (Separação Parcial → Logística)

**Causa raiz**: `finalizar_separacao_parcial_pronta` (RPC da SPEC-089)
marca a separação como `Pronto`, disparando o trigger `trg_separacao_pronta`
que cria a `entrega` automaticamente — mas `separacoes.endereco_entrega`
nunca é preenchido em nenhum ponto do fluxo novo de Separação Parcial
(diferente do fluxo antigo de Logística, onde o usuário digitava esse
campo manualmente antes de marcar Pronto). A entrega nascia sem endereço;
a tela de Logística mostrava literalmente "N/A" pro entregador.

**Fix**: a RPC passou a preencher `endereco_entrega`/`telefone` a partir do
cadastro do cliente (`contatos.endereco_entrega`, fallback pro endereço
principal) no momento de marcar como Pronto — só quando os campos ainda
estiverem vazios (`COALESCE`, nunca sobrescreve).

**Migration**:
`supabase/db/migrations/20260813_106_finalizar_separacao_preenche_endereco/001_finalizar_separacao_preenche_endereco.sql`,
aplicada em produção com autorização explícita do usuário.

### 4. `custom_id` vazio ao adicionar L (Orçamentos → busca de produto)

**Causa raiz**: em `LQuantityRepeater.tsx`, `handleAdd` inicializava um L
novo com `{ custom_id: '', quantidade: 1 }`. O `<Input>` correspondente
tem `placeholder="L01"` — visualmente idêntico a um valor real preenchido
(texto cinza claro), mas o valor de fato era string vazia. O botão
"Confirmar Seleção" ficava `disabled` (a validação `validarEntries` exige
código não-vazio), e por estar `disabled` o clique nem chegava a disparar
o `toast.error` que existiria se o handler rodasse — o usuário via um
botão morto, sem nenhuma explicação. Isso travava silenciosamente **todo**
fluxo de adicionar item a qualquer orçamento no sistema, sempre que o
usuário confiava no que via no campo em vez de digitar por cima.

**Fix**: `handleAdd` gera um código real (`L01`, `L02`...) que bate com o
que o placeholder já prometia visualmente.

**Publicado**: Skip 32554, v0.0.330 (hash `66738ce`).

### 5. `subgrupo` (campo "Tipo") vazio ao criar orçamento novo

**Causa raiz**: `SUBGRUPOS_POR_TIPO.venda = ['VENDAS']` — só 1 opção. Quando
há só 1 opção, o campo "Tipo" renderiza um `<Input value={opcoes[0]}
disabled readOnly>`, completamente desconectado do `field.onChange` do
react-hook-form. O preenchimento real de `subgrupo` só acontecia dentro do
`onClick` do botão "Venda" em "Tipo de Operação" — mas como "Venda" já
vem selecionado por padrão, esse clique nunca acontece organicamente.
Resultado: criar um orçamento novo sem trocar o Tipo de Operação falhava
a validação "Selecione o Tipo" sem nenhum aviso visível até rolar a tela
pro topo, depois de já ter clicado em "Criar Orçamento".

**2 tentativas de fix**:
1. **1ª tentativa (insuficiente)**: `useEffect` sincronizando `subgrupo`
   sempre que `naturezaOperacao` tivesse só 1 opção. Corrigiu o caso
   isolado (form limpo, submit imediato), mas voltava a falhar no fluxo
   completo — `handleProjectSelect` é assíncrono e faz várias chamadas
   `form.setValue` em sequência; havia uma race condition real entre o
   efeito e esse carregamento que podia deixar `subgrupo` vazio de novo
   mesmo depois de já ter sido preenchido uma vez. Confirmado
   empiricamente repetindo o fluxo completo várias vezes: às vezes passava,
   às vezes falhava.
2. **2ª tentativa (definitiva)**: em vez de depender de um efeito rodar na
   ordem certa, `subgrupo: 'VENDAS'` foi escrito direto no `defaultValues`
   do `useForm` — o valor já nasce correto, sem nenhuma corrida possível.
   O `useEffect` da 1ª tentativa foi mantido como reforço (idempotente, não
   atrapalha).

**Achado colateral**: consulta em produção mostrou só 1 orçamento criado
manualmente (fora de import de XML/PDF) nos últimos 7 dias — o bug era
raro na prática porque a maioria dos orçamentos reais nasce de import, mas
genuíno para o fluxo manual.

**Publicado**: Skip 32554, v0.0.331 (hash `bba7152`, 1ª tentativa) →
v0.0.332 (hash `127d14d`, fix definitivo).

### 6. Painel "Responsável (Sistema)" sempre "Não encontrado"

**Causa raiz**: lia `projeto.responsavel_id`, FK legada pra `usuarios`,
morta desde a SPEC-077 (o Responsável do projeto passou a vir de
`responsavel_funcionario_id` → `funcionarios`). Cosmético — o campo
funcional "Vendedor" do orçamento já usava a FK certa — mas mostrava
informação incorreta pro usuário em todo projeto, sempre.

**Fix**: passou a ler `projeto.responsavel_funcionario_id` →
`funcionarios.nome`.

**Publicado**: Skip 32554, v0.0.329 (hash não registrado à parte, mesmo
lote da correção nº5).

### Verificação final — fluxo de ponta a ponta

Depois do fix definitivo do item 5, o fluxo completo (CRM: criar
cliente+projeto → Orçamentos: selecionar projeto, empresa, adicionar item
via busca de produto, preencher pagamento, criar orçamento) foi repetido do
zero, sem nenhum clique de submit intermediário, e **concluído com
sucesso**: orçamento `ORC-0021` criado em produção, status rascunho,
R$ 9.368,72, vinculado ao projeto de teste `99.901`.

## Realizado

### 2026-08-13

- 6 bugs corrigidos, publicados e verificados ao vivo (detalhes acima).
- Submodules locais sincronizados: `separacao-parcial` (commits `7ca9f59`,
  migration aplicada direto no Supabase), `lucenera-crm-3bd29` (commit
  `e5cbd96`), `gestao-financeira-clone-544cb` (commits `a1fe428`,
  `686fe49`).
- CHANGELOG.md e memória atualizados com todos os achados.

### 2026-08-13 (continuação — avançar ORC-0021 até aprovação financeira)

Pedido do usuário: continuar o teste ao vivo verificando/corrigindo
qualquer bug fora do padrão já estabelecido. `ORC-0021` estava em
rascunho (deixado assim no fim da sessão anterior); avançado pela sessão
até `Orçamento Aprovado`, achando 2 bugs reais novos:

**7. Título do "Resumo Fiscal" hardcoded (Orçamentos)**

`FiscalSummaryDialog.tsx` tinha `"Resumo Fiscal (NF 4740 - Roberta
Lucchesi)"` escrito literalmente no JSX — aparecia idêntico em qualquer
orçamento, sem nenhuma relação com o cliente/valor real sendo exibido
(esses continuavam corretos, só o título estava errado). Fix: título
passa a usar `budget.numero` e o nome do cliente real do orçamento.
Publicado Skip 32554, v0.0.333 (hash `8d97603`).

**8. Descrição errada em `projeto_itens` — bug sistêmico desde SPEC-040 (23/07)**

`aprovar_orcamento_financeiro` gravava a descrição do item com
`COALESCE(oi.descricao, oi.custom_id, p.nome, 'Item do Orçamento')` — como
`oi.custom_id` é o código de circuito ("L01"), ele sempre ganhava do nome
real do produto sempre que preenchido (não é exclusivo do fix do bug #4
desta SPEC — qualquer item com `custom_id` digitado manualmente antes
disso já sofria o mesmo problema). Achado ao ver "L01" no lugar do nome
do produto no Resumo Fiscal do `ORC-0021` recém-aprovado. Consulta em
produção confirmou **12 itens errados em 5 orçamentos de clientes reais**
(ORC-0005, ORC-0006, ORC-0007, ORC-0009, ORC-0010), com datas desde
26/06/2026 — não era um problema novo, só nunca detectado.

Fix: `COALESCE(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento')`
— nome do produto prioritário sobre o código de circuito. Migration
`supabase/db/migrations/20260813_107_fix_descricao_projeto_itens_prioridade_custom_id/001_fix_descricao_projeto_itens.sql`
aplicada em produção **com autorização explícita do usuário** (bug já
afetava dados reais de clientes, não só o item de teste), incluindo
`UPDATE` retroativo das 13 linhas já erradas. Confirmado 0 linhas
restantes com o problema após o backfill.

**Verificação adicional do fluxo**: `historico_status_orcamentos` do
`ORC-0021` confirma nenhuma etapa pulada (`enviado_cliente` → `Aprovação
da Equipe` → `Aprovação Financeira` → `Orçamento Aprovado`). RPC criou 1
`projeto_item`, 1 `projeto_parcela`, 1 `boleto`, todos corretos. Como o
produto de teste escolhido não tinha estoque físico, o item foi roteado
corretamente para Necessidade de Compra (`vw_necessidade_compra` mostra
projeto `99.901`/cliente `TESTE BUG SWEEP CLIENTE` corretamente na tela
de Compras) em vez de Separação — fluxo de Separação/Logística/Entrega
**não foi exercitado até o fim** nesta rodada por essa razão (não é um
bug, é limitação do produto de teste escolhido).

Submodule local `gestao-financeira-clone-544cb (1)` sincronizado (commit
`f580ca0`).

## Pendências

- Fluxo de Separação → Logística → Entrega não foi testado ponta a ponta
  nesta rodada (o item do orçamento de teste não tinha estoque físico,
  então foi para Necessidade de Compra em vez de Separação). Repetir o
  teste com um produto que tenha estoque físico disponível, se o objetivo
  for validar especificamente essa parte do fluxo.
