---
titulo: "SPEC-070 — Voltar Orçamento para Rascunho (Enviado ao Cliente / Recusado)"
status: aprovada — pronta para implementação
data_ultima_modificacao: 2026-08-06
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - Supabase (banco central)
dependencias:
  - SPEC-051 (fase de Rascunho; contrato de status que esta SPEC estende com um caminho de volta)
  - SPEC-031 (padrão de RPC "devolver com motivo obrigatório" — `equipe_devolver_orcamento_cliente`, usado como modelo)
  - SPEC-067 (ação "Enviar para o Cliente" cujo efeito esta SPEC permite desfazer)
---

# SPEC-070 — Voltar Orçamento para Rascunho (Enviado ao Cliente / Recusado)

> Pedido literal do usuário: "eu apertei em enviar para o cliente, porém agora foi para Enviado para o Cliente e não consigo voltar pensando que o cliente pode pedir para alterar a gente tem que ter a possibilidade de voltar para o rascunho!"

## Checklist de Ação

### Banco (migration nova — nenhuma aplicada ainda)

- [x] Criar migration em `supabase/db/migrations/20260806_082_spec070_voltar_orcamento_rascunho/` com a RPC nova `public.voltar_orcamento_rascunho(p_orcamento_id uuid, p_motivo text)`, modelada diretamente em cima de `equipe_devolver_orcamento_cliente` (`supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/003_rpcs_equipe_aprovar_devolver.sql`, linhas 70-133) — mesma estrutura de validação, mesmo padrão de erro.
- [x] A função deve: validar `p_motivo` não vazio (`RAISE EXCEPTION` caso contrário, mesmo texto de padrão usado em `equipe_devolver_orcamento_cliente`); validar `role IN ('admin', 'gerente')` (sem fallback de `hub_pode_executar`, diferente do modelo — ver "Decisões aprovadas" P-2); validar que o orçamento está em `status IN ('enviado_cliente', 'recusado_cliente')` (senão `RAISE EXCEPTION`, mesmo padrão de mensagem com número do orçamento); fazer `UPDATE orcamentos SET status = 'rascunho', token_aprovacao_cliente = NULL`; inserir em `historico_status_orcamentos` a transição com `observacao = p_motivo`.
- [x] `GRANT EXECUTE ON FUNCTION public.voltar_orcamento_rascunho(uuid, text) TO authenticated;` (a checagem de papel é feita dentro da função, não via `GRANT`, mesmo padrão do modelo).
- [x] Atualizar `supabase/db/current/` — a função nova foi adicionada em `03_functions.sql` (ordem alfabética, ao final do arquivo). **Não foi feita** a reextração completa do snapshot do domínio Orçamentos (divergência pré-existente desde a SPEC-031/051, ver achado na SPEC) porque isso exigiria consulta direta ao Supabase real (`pg_get_functiondef` de todas as funções do domínio), fora do escopo desta execução sem autorização explícita — sinalizado novamente em `supabase/db/domains/orcamentos.md`.
- [x] Atualizar `supabase/db/domains/orcamentos.md` com a nova transição (seção "SPEC-070 — Voltar orçamento para Rascunho").

### Frontend (`gestao-financeira-clone-544cb (1)`)

- [x] `src/stores/useBudgetStore.ts`: nova action `voltarOrcamentoRascunho(budget: Budget, motivo: string): Promise<any>`, mesmo padrão de `equipeDevolverOrcamentoCliente` — chama a RPC nova, trata erro, `fetchBudgets()` no final.
- [x] `src/components/budgets/BudgetTableRow.tsx`: novo botão "Voltar para Rascunho" (ícone `Undo2`), visível quando `normalizedStatus === 'enviado_cliente'` OU `normalizedStatus === 'recusado_cliente'` **e** `canApproveFinancial` (`canApproveQuotes || role === 'admin' || role === 'gerente'`, mesma variável já existente no arquivo — não usa `canManageClient`, que inclui `operador`). Dialog de motivo obrigatório (`Dialog`/`DialogContent`/`Textarea`, botão desabilitado enquanto `!motivo.trim()`), mesmo padrão de `TeamApprovalTab.tsx`.
- [x] `src/components/budgets/ClientApprovalTab.tsx`: mesmo botão "Voltar para Rascunho", mesma restrição (`canApproveFinancial`, nova variável adicionada ao componente — o `canManage`/`APPROVAL_ROLES` existente inclui `operador` e não foi reaproveitado para este botão), mesmo dialog de motivo.
- [x] Após sucesso, o orçamento desaparece da aba "Aprovação do Cliente" e passa a aparecer na aba "Rascunho" (`DraftBudgetsTab.tsx`) — confirmado por leitura do filtro (`isDraftStatus`), nenhum código extra necessário.
- [x] Atualizar `supabase/AI_DB_CONTEXT.md` do sistema com a nova transição de status (seção "SPEC-070").

### Passos manuais do usuário

- [ ] Confirmar o texto exato do dialog/motivo (proposto abaixo, mas não testado com o usuário — ver Pendência P-1).
- [ ] Rodar a migration `supabase/db/migrations/20260806_082_spec070_voltar_orcamento_rascunho/001_voltar_orcamento_rascunho.sql` no Supabase real após revisão.
- [ ] Homologar no navegador: enviar um orçamento de teste ao cliente, usar "Voltar para Rascunho", confirmar que ele aparece na aba Rascunho, que o link antigo (token anterior) não funciona mais, e que o histórico registra o motivo informado.
- [ ] Repetir o teste a partir de um orçamento em `recusado_cliente`.
- [ ] Confirmar que um usuário sem papel `admin`/`gerente` não vê o botão (ou, se vir, recebe erro de permissão da RPC).
- [ ] Publicar a mudança de frontend no Skip (projectId do sistema `gestao-financeira-clone-544cb`) — não feito nesta execução (só editado localmente no submodule).
- [ ] Rodar o agente `revisor` antes de qualquer commit.

## Objetivo

Hoje, uma vez que um orçamento sai de `rascunho` (via "Enviar para o Cliente", SPEC-051/067), **não existe nenhum caminho, manual ou automático, de volta para `rascunho`** — nem para `enviado_cliente`, nem para `recusado_cliente`, nem para nenhum estágio posterior. Se o cliente pedir uma alteração antes de aprovar, a equipe não tem como reabrir o orçamento para edição dentro do fluxo formal — precisaria criar um orçamento novo do zero ou editar por fora do contrato de status (o que o sistema não impede tecnicamente, mas deixa o orçamento num estado inconsistente: editado enquanto ainda marcado como "enviado ao cliente").

Esta SPEC cria uma ação explícita "Voltar para Rascunho", disponível apenas quando o orçamento está em `enviado_cliente` ou `recusado_cliente`, restrita a `admin`/`gerente`, que exige um motivo e invalida o link de aprovação que o cliente já tinha recebido.

## Decisões aprovadas

Decisões tomadas pelo usuário nesta conversa (via pergunta direta, não devem ser reabertas):

1. **P-1 — Escopo**: a ação só existe para orçamentos em `enviado_cliente` ou `recusado_cliente`. Não se estende a `Aprovação da Equipe`, `Aprovação Financeira` nem `Orçamento Aprovado` — desfazer uma aprovação já registrada por essas etapas fica fora do escopo desta SPEC (se for necessário no futuro, é uma SPEC nova, com suas próprias implicações, ex. sobre `historico_status_orcamentos` e possíveis efeitos em `projeto_itens`/`projeto_parcelas` que só passam a existir a partir de `Orçamento Aprovado`).
2. **P-2 — Permissão**: restrita a `role IN ('admin', 'gerente')`. Diferente do modelo `equipe_devolver_orcamento_cliente`, esta RPC **não** tem fallback via `hub_pode_executar` para outros papéis — decisão literal do usuário ("só admin/gerente"), mais simples que o modelo e sem exigir estender o CHECK constraint de módulos do Hub com um valor novo.
3. **P-3 — Token de aprovação**: o `token_aprovacao_cliente` é **invalidado** (setado para `NULL`) ao voltar para rascunho — o link que o cliente já tinha recebido deixa de funcionar. Não é gerado nenhum token novo neste momento (só voltará a existir um token quando o orçamento for reenviado, via `enviar_orcamento_para_cliente`, que já gera um token novo do zero).
4. **P-4 — Motivo obrigatório**: `p_motivo` é obrigatório, com a mesma validação (`RAISE EXCEPTION` se vazio/só espaço) e o mesmo destino (`historico_status_orcamentos.observacao`) do padrão já usado em `equipe_devolver_orcamento_cliente`.

Decisão de implementação assumida pelo agente, não confirmada explicitamente com o usuário (ver Pendência P-1 na seção final, numeração reaproveitada intencionalmente pois é a única pendência restante):

- **Campos de data/autoria do envio** (`enviado_cliente_em`, `enviado_cliente_por`, `recusado_cliente_em`) **não são apagados** ao voltar para rascunho — ficam como registro histórico de que aquele envio/recusa aconteceu (o `historico_status_orcamentos` já registra a transição completa de qualquer forma). Só o campo com efeito de segurança prático (o token) é limpo. Se o usuário preferir apagar também essas datas, é um ajuste pequeno na mesma migration.

## Definição da SPEC

### Estado atual (confirmado por leitura direta do código)

- **Nenhuma função ou trigger hoje escreve `status = 'rascunho'`** em um orçamento já existente — confirmado por busca em `useBudgetStore.ts`, `supabase/db/current/03_functions.sql` e todas as migrations do domínio Orçamentos.
- **`equipe_devolver_orcamento_cliente`** (SPEC-031) é a única RPC de "devolução" que existe hoje, mas opera só entre `Aprovação da Equipe` e `enviado_cliente` — um nível acima do que esta SPEC cobre. Serve de modelo direto de implementação (mesma estrutura de validação de papel, motivo obrigatório e guarda de status de entrada).
- **`cliente_recusar_orcamento`** (linha 1463 de `supabase/db/current/03_functions.sql`) é o único caminho para `recusado_cliente`, e a partir daí o único caminho documentado hoje é reenviar (`enviar_orcamento_para_cliente`), nunca voltar a rascunho.
- **Achado de divergência confirmado nesta investigação**: `supabase/db/current/03_functions.sql` está desatualizado para todo o domínio Orçamentos desde pelo menos a SPEC-031 (18/07/2026) — não contém `equipe_aprovar_orcamento`, `equipe_devolver_orcamento_cliente`, nem o texto atual (pós SPEC-019) de `handle_orcamento_workflow()`. A migration desta SPEC deve ser escrita a partir do texto real das migrations aplicadas (`20260718_050_...`, `20260727_066_...`), não do snapshot local, e a reextração do snapshot (item já pendente antes desta SPEC) deveria ser feita junto.
- **UI hoje**: para `enviado_cliente`, `BudgetTableRow.tsx` (linhas 288-332) e `ClientApprovalTab.tsx` só oferecem Copiar Link, Reenviar (regenerar token) e Aprovar Manualmente. Para `recusado_cliente`, só Reenviar. Nenhuma ação de "desfazer" existe em nenhum dos dois.
- **Padrão de UI para ação com motivo obrigatório já existe** em `TeamApprovalTab.tsx` (linhas 74-84, 169-172, 382-411): estado local `returnBudget`/`motivo`/`submitting`, `Dialog` com `Textarea`, botão de confirmar desabilitado enquanto `!motivo.trim()`. Esta SPEC reaproveita exatamente esse padrão.
- **Papéis já usados no arquivo**: `BudgetTableRow.tsx` já tem duas variantes de checagem de papel — `canManageClient` (`admin`/`gerente`/`operador`, linha 74-75, usada para "Aprovar Manualmente") e `canApproveFinancial` (`admin`/`gerente` apenas, via `canApproveQuotes` do hook `useAuth` ou role direto, linhas 76-77). A ação nova usa a segunda variante (mais restrita), não a primeira.

### Mudança proposta no banco

Nova função `public.voltar_orcamento_rascunho(p_orcamento_id uuid, p_motivo text) RETURNS jsonb`, modelada em `equipe_devolver_orcamento_cliente`:

```sql
CREATE OR REPLACE FUNCTION public.voltar_orcamento_rascunho(
  p_orcamento_id uuid,
  p_motivo text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo antes de voltar o orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF v_user_role NOT IN ('admin', 'gerente') THEN
    RAISE EXCEPTION 'Apenas admin ou gerente podem voltar um orçamento para rascunho.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status NOT IN ('enviado_cliente', 'recusado_cliente') THEN
    RAISE EXCEPTION 'Orçamento % não pode voltar para rascunho a partir do status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'rascunho',
      token_aprovacao_cliente = NULL
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'rascunho', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'rascunho');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.voltar_orcamento_rascunho(uuid, text) TO authenticated;
```

Este texto é uma proposta pronta para revisão — a migration real deve ser escrita/ajustada pelo agente `implementador` conforme o texto vivo das funções relacionadas no Supabase real, seguindo `AGENTS.md` ("confirmar diretamente no Supabase real antes de escrever qualquer `CREATE OR REPLACE`" quando a função tocar em algo compartilhado — aqui é função nova, mas os nomes de coluna de `orcamentos` devem ser conferidos).

### Mudança proposta no frontend

| Arquivo | Mudança |
|---|---|
| `src/stores/useBudgetStore.ts` | Nova action `voltarOrcamentoRascunho(budget, motivo)`, mesmo padrão de `equipeDevolverOrcamentoCliente`. |
| `src/components/budgets/BudgetTableRow.tsx` | Novo botão "Voltar para Rascunho" (ícone `Undo2`) nos branches `enviado_cliente`/`recusado_cliente`, restrito a `canApproveFinancial` (admin/gerente). Abre dialog de motivo obrigatório antes de confirmar. |
| `src/components/budgets/ClientApprovalTab.tsx` | Mesmo botão, mesma restrição, mesmo dialog — ou reaproveitar um componente de dialog compartilhado se fizer sentido na implementação (não obrigatório, mas evita duplicar o `Dialog`/`Textarea` de motivo entre os dois arquivos). |

### Texto proposto do dialog (motivo)

Título: `Voltar para Rascunho`
Descrição: `O orçamento voltará para a fase de Rascunho e o link de aprovação enviado ao cliente deixará de funcionar. Descreva o motivo (ex.: "Cliente pediu alteração no item X").`
Placeholder do campo: `Motivo da alteração...`
Botão de confirmação desabilitado enquanto o campo estiver vazio (mesmo padrão de `TeamApprovalTab.tsx`).

### Análise de ecossistema

- **Depende de**: `orcamentos` (status, token_aprovacao_cliente) e `historico_status_orcamentos`. Não depende de `projeto_itens`, `projeto_parcelas`, `boletos`, `usuarios` (só leitura de `role`), `systems` ou `user_system_access`.
- **Afeta**: exclusivamente Orçamentos. Como o escopo está limitado a `enviado_cliente`/`recusado_cliente` (antes de qualquer aprovação), não há impacto em dados financeiros/operacionais já gerados — `projeto_itens`/`projeto_parcelas`/reservas de estoque só passam a existir a partir de `Orçamento Aprovado`, fora do alcance desta SPEC.
- **Dado duplicado que deveria ser derivado por relacionamento**: nenhum.
- **Migration antiga que contradiz o snapshot central**: sim — reforça o achado já registrado de que `supabase/db/current/03_functions.sql` está desatualizado para todo o domínio Orçamentos desde a SPEC-031. Esta SPEC não pode ser implementada com segurança sem ler o texto real das migrations aplicadas (ou o banco real).
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim, tanto do sistema quanto `supabase/db/domains/orcamentos.md` (repo central).
- **Padrão de acesso a dados**: Zustand (`useBudgetStore.ts`) chamando `supabase.rpc(...)`, mesmo padrão de `equipeDevolverOrcamentoCliente`. UI de motivo obrigatório via `Dialog`/`Textarea`, mesmo padrão já usado em `TeamApprovalTab.tsx` — nenhum padrão novo introduzido.

## Critérios de aceite

- [ ] Um orçamento em `enviado_cliente` com o botão "Voltar para Rascunho" acionado por um usuário `admin`/`gerente`, com motivo preenchido, passa a ter `status = 'rascunho'` e `token_aprovacao_cliente = NULL`.
- [ ] O mesmo funciona a partir de `recusado_cliente`.
- [ ] Tentar acionar sem motivo é bloqueado na UI (botão desabilitado) e, se contornado, pela RPC (`RAISE EXCEPTION`).
- [ ] Um usuário sem papel `admin`/`gerente` não vê o botão (ou recebe erro de permissão da RPC, se acionado por outro caminho).
- [ ] Tentar chamar a RPC para um orçamento em qualquer outro status (`rascunho`, `Aprovação da Equipe`, `Aprovação Financeira`, `Orçamento Aprovado`) falha com erro claro, sem alterar o orçamento.
- [ ] O link de aprovação antigo (com o token anterior) para de funcionar — acessar a URL de aprovação com o token antigo deve dar erro (orçamento não encontrado para aquele token, comportamento já existente das RPCs de aprovação do cliente quando o token não bate).
- [ ] `historico_status_orcamentos` registra a transição com o motivo informado.
- [ ] O orçamento passa a aparecer na aba "Rascunho" e some da aba "Aprovação do Cliente", sem código extra além da mudança de status (filtros já são por status).
- [x] `oxlint`, `prettier --check` e `vite build` sem erros novos (checagem estática confirmada; os demais critérios de aceite acima dependem da migration aplicada + homologação manual no navegador, não confirmável pelo agente implementador).

## Testes obrigatórios

### Banco (manual, sem suíte automatizada)

- Chamar `voltar_orcamento_rascunho` num orçamento de teste em `enviado_cliente`, com usuário `admin`, motivo preenchido — confirmar `status = 'rascunho'`, `token_aprovacao_cliente IS NULL`, linha nova em `historico_status_orcamentos`.
- Repetir a partir de `recusado_cliente`.
- Chamar sem motivo (string vazia) — confirmar `RAISE EXCEPTION`, orçamento inalterado.
- Chamar com um usuário de papel diferente de `admin`/`gerente` — confirmar erro de permissão.
- Chamar num orçamento em `rascunho` ou `Aprovação da Equipe` — confirmar erro de status inválido, orçamento inalterado.

### Frontend (verificação manual, sem suíte automatizada)

- Fluxo completo pela UI: enviar um orçamento de teste ao cliente (SPEC-067), depois usar "Voltar para Rascunho" com um motivo, confirmar que ele aparece na aba Rascunho.
- Confirmar que o link de aprovação copiado anteriormente (com o token antigo) não funciona mais ao ser acessado.
- Confirmar que o botão não aparece (ou está desabilitado) para um usuário sem papel `admin`/`gerente`.
- `oxlint`, `prettier --check` e `vite build` sem erros novos.

## Realizado

**2026-08-06 — implementação pelo agente `implementador`.**

### Banco (migration redigida, NÃO aplicada no Supabase real)

- `supabase/db/migrations/20260806_082_spec070_voltar_orcamento_rascunho/001_voltar_orcamento_rascunho.sql`: `CREATE OR REPLACE FUNCTION public.voltar_orcamento_rascunho(p_orcamento_id uuid, p_motivo text)` — texto idêntico ao proposto na SPEC, conferido contra `supabase/db/current/01_schema_full.sql` (colunas `orcamentos.status`, `orcamentos.token_aprovacao_cliente`, `orcamentos.numero` existem como no proposto; `orcamentos.status` não tem `CHECK` constraint, é `text` livre — seguro usar os literais `'enviado_cliente'`/`'recusado_cliente'`/`'rascunho'`). `GRANT EXECUTE ... TO authenticated` incluído.
- `supabase/db/current/03_functions.sql`: função nova adicionada ao final do arquivo (ordem alfabética), com nota explícita de que a reextração completa do domínio (pendência crônica desde SPEC-031) não foi feita nesta execução.
- `supabase/db/domains/orcamentos.md`: nova seção "SPEC-070 — Voltar orçamento para Rascunho (2026-08-06)".

### Frontend (`04-Sistemas/gestao-financeira-clone-544cb (1)`, apenas local — não publicado no Skip)

- `src/stores/useBudgetStore.ts`: action `voltarOrcamentoRascunho(budget, motivo)` adicionada, mesmo padrão de `equipeDevolverOrcamentoCliente`.
- `src/components/budgets/BudgetTableRow.tsx`: botão "Voltar para Rascunho" (ícone `Undo2`) nos branches `enviado_cliente` e `recusado_cliente`, restrito a `canApproveFinancial` (variável já existente no arquivo, admin/gerente). Dialog de motivo obrigatório (`Dialog`/`Textarea`), texto conforme "Texto proposto do dialog" da SPEC.
- `src/components/budgets/ClientApprovalTab.tsx`: mesmo botão e dialog; nova variável local `canApproveFinancial` adicionada ao componente (o `canManage`/`APPROVAL_ROLES` pré-existente inclui `operador` e não foi usado para este botão, conforme decisão P-2).
- `supabase/AI_DB_CONTEXT.md` do sistema: nova seção "SPEC-070 — Voltar Orçamento para Rascunho (2026-08-06)".

### Verificação estática

- `npm run lint` (oxlint): 0 erros, 14 warnings pré-existentes no repositório (nenhum nos 3 arquivos tocados por esta SPEC).
- `npx prettier --check`: falhou inicialmente em `BudgetTableRow.tsx`/`ClientApprovalTab.tsx` (indentação do JSX novo); corrigido com `prettier --write` nos 2 arquivos; recheck passou limpo.
- `npm run build` (`vite build`): sucesso, sem erros novos (warning de chunk >500kB é pré-existente/genérico do bundle, não relacionado a esta mudança).

### Pendente (fora do alcance do agente implementador)

- Migration não aplicada no Supabase real.
- Frontend editado só no submodule local — não publicado no Skip.
- Nenhuma homologação manual no navegador foi feita (golden path: enviar orçamento de teste, voltar para rascunho, confirmar token antigo invalidado, confirmar aparecimento na aba Rascunho, confirmar histórico com motivo).
- Reextração completa do snapshot `supabase/db/current/` para o domínio Orçamentos continua pendente (débito pré-existente, apenas reforçado aqui).

## Pendências

- [ ] **P-1 — Texto exato do dialog de motivo**: o texto proposto nesta SPEC ("Descreva o motivo...") não foi confirmado literalmente com o usuário — só o requisito de que o motivo seja obrigatório. Pode ser ajustado livremente na implementação sem precisar de nova aprovação, desde que mantenha o campo obrigatório.
- [ ] **Datas de envio/recusa não são limpas** (`enviado_cliente_em`, `enviado_cliente_por`, `recusado_cliente_em`): decisão do agente, não confirmada explicitamente — ver "Decisões aprovadas" acima. Revisitar se o usuário esperar que esses campos também sejam apagados ao voltar para rascunho.
- [ ] **Sem fallback de permissão via Hub** (diferente do modelo `equipe_devolver_orcamento_cliente`, que aceita `hub_pode_executar` para papéis não-admin/gerente): decisão literal do usuário ("só admin/gerente"), registrada aqui para o caso de precisar ser estendida no futuro.
