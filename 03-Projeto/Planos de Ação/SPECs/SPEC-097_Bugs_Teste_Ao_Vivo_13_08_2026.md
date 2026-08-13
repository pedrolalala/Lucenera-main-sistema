---
titulo: "SPEC-097 — Bugs achados e corrigidos no teste ao vivo de 13/08/2026"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Separação Parcial
  - CRM
  - Orçamentos
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

## Pendências

Nenhuma.
