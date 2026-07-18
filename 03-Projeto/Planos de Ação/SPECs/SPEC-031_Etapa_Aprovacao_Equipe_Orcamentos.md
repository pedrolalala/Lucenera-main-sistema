---
titulo: "SPEC-031 — Etapa 'Aprovação da Equipe' no Fluxo de Status de Orçamentos"
status: implementado — aguardando homologação e configuração de permissão
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - Hub / Central
  - Supabase (banco central)
dependencias:
  - SPEC-016 (contrato oficial de status: enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado)
  - SPEC-019 (aprovado_cliente_origem, reset pós-aprovação — confirmado existente no Supabase real em 2026-07-18, ver achado de grounding)
  - SPEC-006 (hub_pode_executar, papel_permissoes, modulos, modulo_acoes)
---

# SPEC-031 — Etapa "Aprovação da Equipe" no Fluxo de Status de Orçamentos

## Checklist de Ação

### Banco (migration nova)
- [x] Confirmar diretamente no Supabase real (não só no snapshot) se `orcamentos.aprovado_cliente_origem`, `financeiro_editar_orcamento`, `buscar_orcamento_para_aprovacao`, `recusar_orcamento_cliente_publico` e o trigger de reset da SPEC-019 existem — **confirmado em 2026-07-18: todos existem no Supabase real** (`aprovado_cliente_origem` é coluna real de `orcamentos`; as 3 funções existem; `trg_orcamento_item_change_reset` existe). O snapshot local estava desatualizado, não a SPEC-019. Ver "Achado crítico de grounding" (atualizado).
- [x] Confirmar com Pedro o valor bruto exato do novo status e o rótulo de UI — mantidas as propostas desta SPEC: `'Aprovação da Equipe'` (banco) / `'Revisão da Equipe (Pós-Visita)'` (UI).
- [x] Alterar as 5 funções que hoje terminam a aprovação do cliente em `'Aprovação Financeira'` para terminarem em `'Aprovação da Equipe'`: `aprovar_orcamento_cliente_publico`, `aprovar_orcamento_cliente_manual`, `aprovar_orcamento_cliente`, `adm_aprovar_pelo_cliente`, `cliente_aprovar_orcamento`. Aplicado em `supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/002_funcoes_aprovacao_cliente_para_equipe.sql`.
- [x] Criar RPC nova `equipe_aprovar_orcamento(p_orcamento_id uuid, p_observacao text)`: `Aprovação da Equipe -> Aprovação Financeira`. Aplicada (migration 003).
- [x] Criar RPC nova `equipe_devolver_orcamento_cliente(p_orcamento_id uuid, p_motivo text)`: `Aprovação da Equipe -> enviado_cliente`. Aplicada (migration 003).
- [x] Decidido: motivo de alteração de peça/cor reaproveita `historico_status_orcamentos.observacao` (proposta mínima) — `p_motivo` é obrigatório na RPC, sem coluna nova.
- [x] `handle_orcamento_workflow()`: **não alterado** — confirmado por leitura do trigger real que o bloco de reset só dispara para `v_old_status IN ('Aprovação Financeira', 'Orçamento Aprovado')`, não interfere em `'Aprovação da Equipe'`. `requer_revisao_financeira = true` passou a ser setado dentro de `equipe_aprovar_orcamento` (as 5 funções de aprovação do cliente agora setam `false`).
- [x] Decidido: `normalize_orcamento_status()` **mantido sem alteração** — o legado `aprovado_cliente` continua mapeando para `'Aprovação Financeira'` (atalho histórico, não passa pela etapa da equipe).
- [x] Confirmado que `cancelar_orcamento` não precisa de alteração de código (bloco de reversão só dispara para `status_anterior = 'aprovado'`, legado — um orçamento em `'Aprovação da Equipe'` cai no `UPDATE` genérico para `cancelado`).
- [x] Nome do módulo/ação no Hub decidido: módulo `aprovacao_equipe` no sistema `orcamentos`, ação **reaproveitada `'editar'`** (não se estendeu o CHECK constraint do Hub para incluir `'aprovar'` — mudança maior, fora de escopo). Módulo cadastrado em `public.modulos` via migration 001; **nenhum papel recebeu a permissão ainda** — é decisão de Pedro/Filippo, feita pela tela de administração de permissões do Hub (SPEC-006).
- [ ] Atualizar `supabase/db/current/` — não feito nesta sessão (pendência pré-existente do snapshot, ver Pendências).
- [ ] Atualizar `supabase/db/domains/orcamentos.md` com o novo contrato de 4 etapas — não feito nesta sessão.

### Frontend (`gestao-financeira-clone-544cb (1)`)
- [x] `src/lib/budget-status.ts`: adicionado `'Aprovação da Equipe'` a `getStatusLabel`/`getStatusBadgeClass`; criado `isTeamApprovalStatus(status)` e `TEAM_APPROVAL_STATUS`.
- [x] `src/pages/Budgets.tsx`: opção nova em `STATUS_OPTIONS`; `TabsTrigger`/`TabsContent` `aprovacao-equipe` adicionada — **sem gate de role na visibilidade da aba** (decisão desta implementação: a aba fica visível a todos os usuários autenticados, e os botões de ação dentro dela ficam desabilitados conforme a checagem de permissão via `hub_pode_executar`, ver abaixo).
- [x] `src/pages/BudgetFormPage.tsx`: opção nova em `STATUS_OPTIONS`.
- [x] Criado `src/components/budgets/TeamApprovalTab.tsx`, espelhando `FinancialApprovalTab.tsx`: lista orçamentos em `'Aprovação da Equipe'`, botão "Aprovar e Enviar ao Financeiro" (`equipe_aprovar_orcamento`) e botão "Devolver ao Cliente" (modal com `Textarea` de motivo obrigatório, chama `equipe_devolver_orcamento_cliente`). Checagem de permissão feita via `supabase.rpc('hub_pode_executar', { p_usuario_id, p_system_slug: 'orcamentos', p_modulo_chave: 'aprovacao_equipe', p_acao: 'editar' })` direto no componente (confirmado por pesquisa que não existe hook de permissão reutilizável no sistema — o único precedente é a chamada inline a `hub_sistemas_permitidos` em `Dashboard.tsx` do Hub central).
- [x] `src/components/budgets/BudgetTableRow.tsx`: **nenhuma alteração necessária** — badge já funciona via `getStatusLabel`/`getStatusBadgeClass` genéricos; ação centralizada em `TeamApprovalTab.tsx`, mesmo padrão da fila financeira.
- [x] `src/stores/useBudgetStore.ts`: adicionadas `equipeAprovarOrcamento(budget, observacao?)` e `equipeDevolverOrcamentoCliente(budget, motivo)`, mesmo padrão de `financialApprove`/`approveBudgetClient`.
- [x] Decidido não criar `teamApprovalService.ts` — as chamadas ficam direto no store, consistente com `approveBudgetClient`/`enviarOrcamentoCliente` (o sistema já mistura os dois padrões; `budgetApprovalService.ts` existe só para o fluxo financeiro).
- [x] Atualizado `supabase/AI_DB_CONTEXT.md` do sistema com o contrato de 4 etapas, as duas RPCs novas e o modelo de permissão.

### Passos manuais do usuário

- [x] ~~Confirmar diretamente no Supabase real se os objetos da SPEC-019 existem~~ — confirmado em 2026-07-18, todos existem.
- [x] ~~Decidir o valor bruto exato do novo status e o rótulo de UI~~ — mantidas as propostas desta SPEC.
- [x] ~~Decidir o nome do papel/permissão do Hub e a ação~~ — reaproveitada a ação `'editar'` existente (sem alterar CHECK constraint).
- [ ] **Conceder a permissão do módulo "Aprovação da Equipe" a pelo menos um papel/usuário no Hub** — sem isso, só `admin`/`gerente` conseguem agir na nova etapa (o módulo já está cadastrado, mas nenhum papel foi vinculado a ele; é decisão de Pedro/Filippo de quem deve aprovar, feita pela tela de administração de permissões do Hub).
- [ ] Decidir se a edição de peça/cor durante `'Aprovação da Equipe'` reabre a tela padrão de edição de orçamento (`BudgetFormPage.tsx`) sem UI nova (é o que existe hoje — a aba só tem os botões Aprovar/Devolver, a edição de itens continua na tela normal de orçamento) ou se precisa de tela dedicada de "revisão pós-visita".
- [x] ~~Decidir se `equipe_devolver_orcamento_cliente` deve gerar novo token e limpar aprovação anterior~~ — implementado que sim (mesmo padrão da SPEC-019).
- [x] ~~Rodar a migration no Supabase real~~ — aplicada em 2026-07-18.
- [ ] Homologar o fluxo completo com um orçamento real no navegador: cliente aprova -> cai em "Aprovação da Equipe" -> equipe decide (aprovar para financeiro OU devolver ao cliente) -> financeiro aprova. **Não testado no navegador nesta sessão** — só verificado lint/build limpos.
- [ ] Rodar `pnpm install` (ou publicar via Skip) no sistema `gestao-financeira-clone-544cb (1)` antes de testar — o `node_modules` local não existia no início desta sessão e foi instalado via `corepack pnpm install --frozen-lockfile` só para rodar lint/build.
- [ ] Reextrair `supabase/db/current/` e atualizar `supabase/db/domains/orcamentos.md` com o novo contrato de 4 etapas (não feito nesta sessão).

## Objetivo

Hoje, no contrato oficial da SPEC-016, assim que o cliente aprova um orçamento (`enviado_cliente -> Aprovação Financeira`), ele entra direto na fila financeira. Não existe nenhum espaço formal para a equipe, depois da aprovação do cliente e de uma visita técnica à obra, revisar/alterar peças e cores antes de seguir para o financeiro.

Esta SPEC insere uma nova etapa **"Aprovação da Equipe"** entre a aprovação do cliente e a aprovação financeira:

```text
enviado_cliente -> Aprovação da Equipe (NOVO) -> Aprovação Financeira -> Orçamento Aprovado
```

Com uma transição de retorno explícita `Aprovação da Equipe -> enviado_cliente`, para quando a equipe altera peças/cores na visita e precisa que o cliente aprove novamente a versão revisada.

## Decisões aprovadas

Decisões literais do Pedro nesta conversa — não reabrir sem necessidade:

1. **Posição no fluxo**: a nova etapa entra imediatamente após `enviado_cliente` e antes de `Aprovação Financeira`: `enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`.
2. **Quem aprova**: qualquer usuário com um papel/permissão específica no Hub (padrão da SPEC-006 — `hub_pode_executar`/`hub_sistemas_permitidos`, tabelas `modulos`, `modulo_acoes`, `papeis`, `papel_permissoes`, `usuario_papeis`), não restrito a quem está vinculado ao projeto. O nome exato do papel/permissão **não foi decidido** — pendência.
3. **O que a etapa representa**: depois da aprovação do cliente, a equipe faz uma visita à obra e pode precisar alterar peças/cores do orçamento. A etapa é o espaço para essa decisão. Se a equipe alterar algo, o orçamento pode voltar para `enviado_cliente` (reenviar ao cliente para aprovar a versão revisada) — portanto existem duas transições de saída de `Aprovação da Equipe`: avanço (`-> Aprovação Financeira`) e retorno (`-> enviado_cliente`).
4. Como consequência do item 3, a transição de saída de `enviado_cliente` quando o cliente aprova **deixa de ir direto para `Aprovação Financeira`** e passa a ir para `Aprovação da Equipe` primeiro — mudança de contrato nas 5 funções listadas abaixo, confirmadas por leitura direta do código real (não da narrativa de nenhuma SPEC anterior).

## Definição da SPEC

### Achado de grounding — RESOLVIDO em 2026-07-18

Ao ler `supabase/db/current/` (snapshot local) para confirmar o estado real antes de propor mudanças, a versão original desta seção apontou uma divergência aparente com o que a SPEC-019 declara como "Realizado": os objetos abaixo não apareciam no snapshot.

**Confirmado por query direta no Supabase real (não no snapshot) em 2026-07-18: todos existem.** O snapshot local estava desatualizado (não reextraído desde 2026-07-07, pendência já conhecida), não a SPEC-019.

| Objeto que a SPEC-019 diz existir | Ausente no snapshot local | Existe no Supabase real? |
|---|---|---|
| `orcamentos.aprovado_cliente_origem` | Sim | **Sim** (`information_schema.columns`, tipo `text`) |
| `financeiro_editar_orcamento(...)` | Sim | **Sim** (`p_orcamento_id, p_forma_pagamento, p_valor_total, p_itens, p_reiniciar_aprovacao`) |
| `buscar_orcamento_para_aprovacao(...)` | Sim | **Sim** |
| `recusar_orcamento_cliente_publico(...)` | Sim | **Sim** |
| `trg_orcamento_item_change_reset` (trigger de reset) | Sim | **Sim** (em `orcamento_itens`) |

Isso destravou o design de `equipe_devolver_orcamento_cliente` como planejado: regenerar `token_aprovacao_cliente` e limpar `aprovado_cliente_em`/`aprovado_cliente_origem` ao devolver ao cliente é seguro, pois as colunas realmente existem em produção. Implementado sem ajuste de escopo.

### Achado — funções que precisam mudar (lidas por completo em `supabase/db/current/03_functions.sql`)

Todas as 5 funções abaixo hoje fazem `UPDATE public.orcamentos SET status = 'Aprovação Financeira', ...` de forma independente (a string está hardcoded 5 vezes, não centralizada em uma função auxiliar). A mudança precisa ser replicada nas 5:

| Função | Linha (snapshot) | Guard atual de entrada | Efeito atual |
|---|---|---|---|
| `aprovar_orcamento_cliente_publico(p_orcamento_id, p_token)` | 331-385 | `status <> 'enviado_cliente'` → exceção; valida token | `status = 'Aprovação Financeira'`, `aprovado_cliente_em = now()`, `requer_revisao_financeira = true`, `token_aprovacao_cliente = NULL` |
| `aprovar_orcamento_cliente_manual(p_orcamento_id)` | 264-327 | `role NOT IN ('admin','gerente','operador')` → exceção; `status NOT IN ('enviado_cliente','recusado_cliente','aguardando_cliente','aguardando_aprovacao','rascunho')` → exceção | idem acima |
| `aprovar_orcamento_cliente(p_orcamento_id)` | 193-260 | mesmo guard de role e status da manual | idem acima |
| `adm_aprovar_pelo_cliente(p_orcamento_id, p_observacao)` | 67-117 | `status NOT IN ('aguardando_aprovacao','enviado_cliente','recusado_cliente')` → exceção (sem checagem de role) | idem acima |
| `cliente_aprovar_orcamento(p_orcamento_id, p_token)` | 1406-1460 | `status <> 'enviado_cliente'` → exceção; valida token (família legada, mas ainda mantida compatível pela SPEC-016) | idem acima |

**Mudança proposta**: nas 5, trocar o valor final de `'Aprovação Financeira'` para `'Aprovação da Equipe'`. Os guards de entrada (`status <> 'enviado_cliente'` etc.) não mudam — continuam exigindo que o orçamento esteja em `enviado_cliente`/equivalente antes de aceitar a aprovação do cliente.

**Pergunta em aberto que reflete diretamente no código**: `requer_revisao_financeira = true` é setado nessas 5 funções hoje porque, no contrato antigo, aprovação do cliente = entrada direta na fila financeira. Com a etapa nova no meio, esse flag deveria continuar sendo setado aqui (na aprovação do cliente) ou só quando a equipe aprovar (`Aprovação da Equipe -> Aprovação Financeira`)? Proposta desta SPEC: mover o `requer_revisao_financeira = true` para dentro de `equipe_aprovar_orcamento` (que é quem efetivamente coloca o orçamento na fila financeira) e as 5 funções acima passam a setar `requer_revisao_financeira = false` (ou não tocar no campo) ao entrar em `Aprovação da Equipe`. Isso é uma proposta, não uma decisão fechada — impacta o badge "Requer Revisão Financeira" em `BudgetTableRow.tsx` (linha ~79-80, `needsFinancialReview`).

### Achado — CHECK constraint do Hub não tem ação "aprovar"

Lendo `supabase/db/current/01_schema_full.sql` (linhas 5231-5236 e 5482-5489):

```sql
CREATE TABLE public.modulo_acoes (
    ...
    CONSTRAINT modulo_acoes_chave_check CHECK ((chave = ANY (ARRAY['criar','editar','deletar','visualizar'])))
);

CREATE TABLE public.papel_permissoes (
    ...
    CONSTRAINT papel_permissoes_acao_check CHECK ((acao = ANY (ARRAY['criar','editar','deletar','visualizar'])))
);
```

Não existe ação `'aprovar'` no modelo de permissão do Hub (SPEC-006) hoje. Além disso, confirmei em `supabase/db/migrations/20260708_029_spec006_permissoes_granulares_hub/004_seed_papeis_e_migracao.sql` que **não existe nenhuma linha em `modulos` para o sistema `orcamentos`** ainda — só o auto-cadastro do módulo "Permissões" do próprio Hub. Ou seja, adotar `hub_pode_executar` para esta etapa exige, no mínimo:

1. Criar um `modulos` novo (`system_id` = sistema `orcamentos`, `chave` a definir, ex. `aprovacao_equipe`);
2. Decidir se a ação é `'editar'` (reaproveitando o domínio existente) ou se vale a pena estender o CHECK constraint para incluir `'aprovar'` — isso é uma mudança na tabela da SPEC-006, que também afeta `usuario_permissao_excecoes.acao` (mesmo domínio de valores, ver SPEC-006 linha ~121).

Isto é bloqueador para a decisão nº 2 do Pedro ("papel/permissão específica no Hub") e está registrado como pendência — não decidi sozinho qual caminho tomar.

### Novo status — proposta (não decidida em valor final)

| Campo | Proposta desta SPEC | Status |
|---|---|---|
| Valor bruto salvo em `orcamentos.status` | `'Aprovação da Equipe'` (Title Case com acento, mesmo padrão de `'Aprovação Financeira'`/`'Orçamento Aprovado'`) | proposta, a confirmar |
| Rótulo de UI (`getStatusLabel`) | `'Revisão da Equipe (Pós-Visita)'` — evita colidir com `'Revisão Financeira Pendente'` já em uso | proposta, a confirmar |
| Classe de badge | `'bg-purple-50 text-purple-700 border-purple-200'` (cor nova, não reaproveitar âmbar do financeiro nem verde do aprovado) | proposta |

### Motivo da alteração de peça/cor — proposta mínima

Não existe hoje nenhuma coluna estruturada em `orcamento_itens` para "motivo da troca" (a tabela só tem `produto_id`, `descricao`, `quantidade`, `preco_unitario`, `desconto`, `peca_nova boolean`). Duas opções, nenhuma decidida:

1. **Mínima (proposta desta SPEC)**: reaproveitar `historico_status_orcamentos.observacao` (coluna `text` livre já existente) — a RPC `equipe_devolver_orcamento_cliente` grava o `p_motivo` ali junto com a transição `Aprovação da Equipe -> enviado_cliente`. Não requer alteração de schema em `orcamento_itens`.
2. **Estruturada**: criar coluna nova (ex. `orcamento_itens.motivo_alteracao_equipe text` ou tabela de auditoria por item) — permite rastrear item a item o que mudou, mas é decisão de modelagem que não deve ser tomada sem confirmar com o usuário se o nível de detalhe (por orçamento vs por item) é necessário.

### Novas RPCs propostas

```sql
-- Aprovação da Equipe -> Aprovação Financeira
CREATE OR REPLACE FUNCTION public.equipe_aprovar_orcamento(
  p_orcamento_id uuid,
  p_observacao text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
BEGIN
  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  -- Permissão: admin/gerente sempre podem (consistente com o restante do fluxo);
  -- demais usuários precisam da permissão granular do Hub (módulo/ação a definir).
  IF NOT (
    EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND u.role::text IN ('admin','gerente'))
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', '<modulo_pendente>', '<acao_pendente>')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para aprovar como equipe.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text,
          COALESCE(p_observacao, 'Aprovado pela equipe após visita à obra'));

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'Aprovação Financeira');
END;
$function$;

-- Aprovação da Equipe -> enviado_cliente (devolução para nova aprovação do cliente)
CREATE OR REPLACE FUNCTION public.equipe_devolver_orcamento_cliente(
  p_orcamento_id uuid,
  p_motivo text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
BEGIN
  IF p_motivo IS NULL OR btrim(p_motivo) = '' THEN
    RAISE EXCEPTION 'Informe o motivo da alteração antes de devolver ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  -- Mesma checagem de permissão de equipe_aprovar_orcamento (módulo/ação a definir).
  IF NOT (
    EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND u.role::text IN ('admin','gerente'))
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', '<modulo_pendente>', '<acao_pendente>')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para devolver orçamento ao cliente.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  -- ATENÇÃO: regeneração de token e limpeza de aprovado_cliente_* depende de
  -- confirmar se essas colunas existem de fato (ver "Achado crítico de
  -- grounding"). Se não existirem, remover as linhas correspondentes.
  UPDATE public.orcamentos
  SET status = 'enviado_cliente',
      token_aprovacao_cliente = public.gen_token_hex(),
      enviado_cliente_em = now(),
      enviado_cliente_por = auth.uid(),
      aprovado_cliente_em = NULL,
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'enviado_cliente', auth.uid()::text, p_motivo);

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'enviado_cliente');
END;
$function$;
```

> As duas funções acima são **propostas de conteúdo de migration**, não migrations aplicadas. `<modulo_pendente>`/`<acao_pendente>` são placeholders — não usar em produção sem substituir pelo módulo/ação reais decididos no Hub.

### Impacto em `aprovar_orcamento_financeiro`

Nenhuma mudança de guard necessária. A função já exige `orcamentos.status = 'Aprovação Financeira'` (`03_functions.sql:389+`) — com a etapa nova, o único caminho para chegar em `Aprovação Financeira` passa a ser `equipe_aprovar_orcamento`, o que é compatível sem alterar o guard existente. Nenhuma outra função no domínio Orçamentos assume que `Aprovação Financeira` é o único destino pós-cliente além das 5 já listadas.

### Impacto em `cancelar_orcamento`

Lido por completo (`03_functions.sql:1202-1374`). O bloco que reverte efeitos financeiros só dispara `IF v_status_anterior = 'aprovado'` — não `'Orçamento Aprovado'` (nota: isso já é uma divergência pré-existente entre o contrato oficial da SPEC-016 e o código real, encontrada durante esta leitura, **fora do escopo desta SPEC**, mas registrada como achado). Um orçamento em `'Aprovação da Equipe'` cancelado simplesmente cai no `UPDATE ... SET status = 'cancelado'` genérico (linha 1342), sem passar pelo bloco de reversão — o mesmo comportamento que já existe hoje para `enviado_cliente` e `'Aprovação Financeira'`. **Não é necessária nenhuma alteração de código em `cancelar_orcamento` para suportar o novo status.**

### Impacto em `historico_status_orcamentos`

Nenhuma alteração de schema necessária — é uma tabela de auditoria de texto livre (`status_anterior text`, `status_novo text`, `observacao text`). As duas RPCs novas só precisam inserir linhas nela, seguindo o padrão já usado pelas 5 funções de aprovação do cliente.

### Impacto em `trg_normalize_orcamento_status` / `trg_orcamento_workflow`

- `normalize_orcamento_status()` (função por trás de `trg_normalize_orcamento_status`): hoje mapeia o legado `aprovado_cliente -> 'Aprovação Financeira'`. Com a etapa nova, essa normalização deveria apontar para `'Aprovação da Equipe'`? Não decidido — depende de saber se `aprovado_cliente` (valor legado) ainda aparece em linhas reais do banco hoje (a SPEC-016 registrou que sim, havia linhas legadas). Se ainda houver, a normalização automática mudaria o destino de dado histórico sem contexto de "visita à obra" nenhuma — proposta: **não mudar** esse mapeamento legado (manter indo para `'Aprovação Financeira'` como hoje, tratando como atalho histórico), e só o fluxo novo (cliente aprovando a partir de agora) passa pela etapa da equipe. Isto é uma proposta, registrada como pendência para confirmação.
- `handle_orcamento_workflow()` (função por trás de `trg_orcamento_workflow`): o bloco `IF (NEW.status = 'Aprovação Financeira' AND v_old_status = 'enviado_cliente')` (linha 2473) nunca mais vai disparar a partir do fluxo novo (porque a transição direta `enviado_cliente -> Aprovação Financeira` deixa de existir). Ver proposta acima de mover esse efeito colateral (`requer_revisao_financeira = true`) para dentro de `equipe_aprovar_orcamento`. Não é necessário remover o bloco do trigger (fica como código morto inofensivo para o fluxo novo, mas continua útil caso alguma rota legada ainda grave `'Aprovação Financeira'` diretamente) — mas isso deveria ser confirmado, não presumido.

### Frontend — mapeamento de arquivos e padrão já estabelecido

O sistema já tem um padrão consistente e replicável para "fila de status + ação de transição", usado por `FinancialApprovalTab.tsx`/`ClientApprovalTab.tsx`. Esta SPEC **não propõe um padrão novo** — replica o mesmo:

| Arquivo | Mudança |
|---|---|
| `src/lib/budget-status.ts` | Adicionar `'Aprovação da Equipe'` em `getStatusLabel`/`getStatusBadgeClass`; criar `isTeamApprovalStatus(status)` espelhando `isFinancialApprovalStatus` |
| `src/pages/Budgets.tsx` | `STATUS_OPTIONS` (linha 22-34); nova `TabsTrigger`/`TabsContent` `aprovacao-equipe` entre `aprovacao-cliente` e `aprovacao-financeira` (linhas 88-149), condicionada a uma checagem de permissão (hoje a aba financeira usa `role === 'admin' || role === 'gerente'` direto no JSX — para a aba nova, avaliar se replica isso ou passa a chamar `hub_pode_executar` do cliente, ver Pendências) |
| `src/pages/BudgetFormPage.tsx` | `STATUS_OPTIONS` (linha 175-184); o botão condicional de "abrir modal financeiro" (linha ~1040-1044, hoje `budgetToEdit?.status === 'Aprovação Financeira'`) pode precisar de equivalente para a nova etapa, ou a ação fica só na aba nova (mais simples, replica o padrão financeiro) |
| `src/components/budgets/TeamApprovalTab.tsx` (novo) | Réplica de `FinancialApprovalTab.tsx`: lista orçamentos com `status === 'Aprovação da Equipe'`, botão "Aprovar e enviar ao Financeiro" (`equipe_aprovar_orcamento`) e botão "Devolver ao Cliente" (`equipe_devolver_orcamento_cliente`, com modal exigindo motivo) |
| `src/stores/useBudgetStore.ts` | Novas actions `equipeAprovarOrcamento`/`equipeDevolverOrcamentoCliente`, mesmo padrão de `financialApprove`/`approveBudgetClient` (linhas 121-125, 333-386) |
| `src/components/budgets/BudgetTableRow.tsx` | Badge funciona automaticamente via `getStatusLabel`/`getStatusBadgeClass`; `normalizeStatus('Aprovação da Equipe')` resulta em `'aprovacao_da_equipe'` (confirmado lendo `src/lib/utils.ts:8-16`) — usar essa string se alguma ação rápida for adicionada na tabela geral |
| `supabase/AI_DB_CONTEXT.md` (sistema) | Atualizar contrato de status de 3 para 4 etapas, citar as 2 RPCs novas |

## Análise de ecossistema (obrigatória por `COMO_CRIAR_SPEC.md`)

- **Depende de** `orcamentos`, `historico_status_orcamentos`, `usuarios`. Não depende de `boletos`, `projeto_itens`, `projeto_parcelas` diretamente — a etapa nova fica inteiramente antes de `aprovar_orcamento_financeiro`, que é quem gera esses artefatos; nenhum efeito financeiro/estoque é disparado por esta SPEC.
- **Afeta**: Orçamentos (mudança de contrato de status e RPCs) e Hub/TI (se a decisão nº 2 do Pedro for implementada via `hub_pode_executar`, exige cadastrar módulo novo em `modulos`/`modulo_acoes`, possivelmente estender CHECK constraint). Não afeta CRM, Financeiro, Cadastro, Estoque/Compras, Logística ou RH diretamente — nenhum desses lê `orcamentos.status` fora do que já é coberto pela SPEC-016/019 (confirmado por essas SPECs; não há motivo para achar diferente aqui, já que a mudança só insere um status novo no meio do funil, não altera os status finais que os outros sistemas já conhecem).
- **Dado duplicado**: nenhum novo. A proposta de motivo de alteração reaproveita `historico_status_orcamentos.observacao` em vez de criar coluna nova (opção 1 da seção "Motivo da alteração de peça/cor").
- **Migration antiga que contradiz o snapshot central**: sim, achado documentado acima — os objetos da SPEC-019 (`aprovado_cliente_origem`, `financeiro_editar_orcamento`, etc.) não aparecem em `supabase/db/current/`, apesar de a SPEC-019 marcar a re-extração como concluída. Isso não é causado por esta SPEC, mas precisa ser resolvido/confirmado antes de implementar SPEC-031, porque `equipe_devolver_orcamento_cliente` foi desenhada assumindo esse contrato.
- **`AI_DB_CONTEXT.md`**: sim, precisa ser atualizado (item no checklist).
- **Padrão de acesso a dados do sistema afetado**: o sistema de Orçamentos usa Zustand (`useBudgetStore.ts`) chamando `supabase.rpc(...)` diretamente dos componentes/store, sem camada de serviço obrigatória (`budgetApprovalService.ts` existe só para o fluxo financeiro, mas `useBudgetStore.ts` também chama RPCs direto). Esta SPEC não introduz um padrão novo — replica o mesmo mix já existente (store com actions que chamam RPC diretamente), consistente com `approveBudgetClient`/`financialApprove`.

## Critérios de aceite

- [ ] Cliente aprova um orçamento (via link público ou aprovação manual) e o orçamento fica em `'Aprovação da Equipe'`, não em `'Aprovação Financeira'`.
- [ ] `equipe_aprovar_orcamento` só executa com o orçamento em `'Aprovação da Equipe'`; falha com qualquer outro status.
- [ ] `equipe_aprovar_orcamento` bem-sucedido deixa o orçamento em `'Aprovação Financeira'` e ele aparece na fila existente (`FinancialApprovalTab.tsx`) normalmente.
- [ ] `equipe_devolver_orcamento_cliente` só executa com o orçamento em `'Aprovação da Equipe'` e com `p_motivo` preenchido; falha sem motivo.
- [ ] `equipe_devolver_orcamento_cliente` bem-sucedido deixa o orçamento em `'enviado_cliente'`, visível na aba de aprovação do cliente.
- [ ] Usuário sem a permissão do Hub definida (nem admin/gerente) recebe erro claro ao tentar `equipe_aprovar_orcamento`/`equipe_devolver_orcamento_cliente`.
- [ ] `aprovar_orcamento_financeiro` continua funcionando sem alteração de contrato, exigindo `'Aprovação Financeira'`.
- [ ] `historico_status_orcamentos` registra as 3 transições novas: `enviado_cliente -> Aprovação da Equipe`, `Aprovação da Equipe -> Aprovação Financeira`, `Aprovação da Equipe -> enviado_cliente`.
- [ ] Cancelar um orçamento em `'Aprovação da Equipe'` funciona (`cancelar_orcamento`) sem erro e sem tentar reverter efeitos financeiros inexistentes.

## Testes obrigatórios

### Banco (manual, via SQL/RPC — sem suíte automatizada, nenhum dos 8 sistemas tem)

- Chamar cada uma das 5 funções de aprovação do cliente em um orçamento de teste em `enviado_cliente` e confirmar que o status final é `'Aprovação da Equipe'`, não `'Aprovação Financeira'`.
- Chamar `equipe_aprovar_orcamento` num orçamento em `'Aprovação da Equipe'` e confirmar status final `'Aprovação Financeira'` e linha em `historico_status_orcamentos`.
- Chamar `equipe_aprovar_orcamento` num orçamento em `enviado_cliente` (fora de ordem) e confirmar que falha com erro claro.
- Chamar `equipe_devolver_orcamento_cliente` sem `p_motivo` e confirmar que falha.
- Chamar `equipe_devolver_orcamento_cliente` com motivo, confirmar status final `enviado_cliente` e (se a coluna existir de fato — ver achado de grounding) `token_aprovacao_cliente` novo.
- Chamar `aprovar_orcamento_financeiro` diretamente num orçamento ainda em `'Aprovação da Equipe'` (pulando a etapa) e confirmar que falha, preservando o guard existente.
- Chamar `cancelar_orcamento` num orçamento em `'Aprovação da Equipe'` e confirmar que só muda o status para `cancelado`, sem tentar reverter estoque/parcelas/boletos inexistentes.

### Frontend (verificação manual no navegador — sem suíte automatizada)

- Aprovar um orçamento como cliente (link público) e confirmar que ele aparece na nova aba/fila de equipe, não na financeira.
- Como usuário com a permissão da equipe, aprovar o orçamento pela nova aba e confirmar que ele some da fila de equipe e aparece na fila financeira.
- Como usuário com a permissão da equipe, devolver um orçamento ao cliente (com motivo) e confirmar que ele volta para a aba de aprovação do cliente com link renovado.
- Como usuário sem a permissão nova nem role admin/gerente, confirmar que os botões de ação da nova aba ficam desabilitados/ocultos.
- `pnpm run lint` e `pnpm run build` no sistema de Orçamentos sem erros novos.

## Realizado

### 2026-07-18

- **Grounding confirmado direto no Supabase real** (não só no snapshot): `orcamentos.aprovado_cliente_origem` existe como coluna real; `financeiro_editar_orcamento`, `buscar_orcamento_para_aprovacao`, `recusar_orcamento_cliente_publico` existem como funções; trigger `trg_orcamento_item_change_reset` existe. O snapshot local (`supabase/db/current/`) é que está desatualizado, não a SPEC-019 — achado da versão anterior desta SPEC estava errado nesse ponto.
- **Migration aplicada no Supabase real** (`supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/`, 3 arquivos, autorizado explicitamente por Pedro nesta sessão):
  - `001_modulo_hub_aprovacao_equipe.sql`: cadastra o módulo `aprovacao_equipe` em `public.modulos` para o sistema `orcamentos`. Não concede a nenhum papel.
  - `002_funcoes_aprovacao_cliente_para_equipe.sql`: `CREATE OR REPLACE` nas 5 funções de aprovação do cliente — passam a terminar em `'Aprovação da Equipe'` (antes `'Aprovação Financeira'`) e a setar `requer_revisao_financeira = false` (antes `true`).
  - `003_rpcs_equipe_aprovar_devolver.sql`: cria `equipe_aprovar_orcamento` e `equipe_devolver_orcamento_cliente`.
  - As três partes foram lidas por completo do banco real (`pg_get_functiondef`) antes de escrever a migration, para garantir que o `CREATE OR REPLACE` preservasse exatamente o comportamento existente (validações, mensagens de erro, guards) e só mudasse o destino da transição.
- **Frontend implementado e commitado nos arquivos do sistema** `04-Sistemas/gestao-financeira-clone-544cb (1)`: `src/lib/budget-status.ts`, `src/pages/Budgets.tsx`, `src/pages/BudgetFormPage.tsx`, `src/components/budgets/TeamApprovalTab.tsx` (novo), `src/stores/useBudgetStore.ts`. Ver Checklist acima para detalhe por arquivo.
- **Verificado**: `pnpm install --frozen-lockfile` (node_modules não existia), `pnpm run lint` (oxlint, 0 erros, 15 warnings — todos pré-existentes, nenhum nos arquivos novos/alterados desta SPEC) e `pnpm run build` (vite build, sucesso, único aviso é o chunk >500kB pré-existente) — todos limpos.
- **Commit + push do submodule `gestao-financeira-clone-544cb (1)`**: ao tentar dar push, `origin/main` estava 2 commits à frente do meu clone local (incluindo um "Auto-commit before sync" do próprio Skip) — um deles removia o bloco `STATUS_OPTIONS` de `BudgetFormPage.tsx` (código morto/não usado) por ter sido "limpo" em algum momento posterior à minha última sincronização. `git merge origin/main` gerou 1 conflito real nesse arquivo, resolvido descartando minha edição ali (era só adicionar uma linha a um bloco que deixou de existir — sem perda funcional). Lint/build rodados de novo após o merge, limpos (inclusive 1 warning a menos, exatamente o de `STATUS_OPTIONS` não usado). Push concluído (`066f2f3`).
- **Publicado em produção via Skip (MCP)**: o projeto Skip do sistema (`Orçamentos Aprovação`, id `32554`) estava numa versão (`0.0.293`/`5492ca4`) que não corresponde a nenhum commit no GitHub — divergência real de 3 estados (local/GitHub/Skip). Antes de escrever qualquer arquivo no Skip, li o conteúdo atual de cada um via `skip_file_read`: `budget-status.ts`, `Budgets.tsx` e `use-auth.tsx` batiam exatamente com meu baseline local (seguro sobrescrever), mas `useBudgetStore.ts` no Skip tinha um campo extra (`prazo_entrega_dias` na interface `Budget`) que não existe no GitHub — escrevi a versão final preservando esse campo, em vez de sobrescrever cegamente. `BudgetFormPage.tsx` não foi tocado no Skip (minha edição lá virou zero líquido depois do merge). Rodei `skip_project_apply_changes` (setup/lint/build/integrações/testes — todos `ok`) e depois `skip_project_publish`: publicado com sucesso (`versão 0.0.294`, `publishedRef 3dc0057`) em `https://gestao-financeira-clone-544cb.goskip.app`.
- **Testado**: só a pipeline de QA automática do Skip (build real da aplicação, sem erro). **Não testado manualmente no navegador** por um usuário logado (login como usuário de cada papel, aprovar/devolver um orçamento real). Nenhum papel tem a permissão do módulo `aprovacao_equipe` concedida ainda — só `admin`/`gerente` conseguem agir na nova etapa hoje.

## Pendências

- [ ] **Conceder a permissão do módulo "Aprovação da Equipe" a pelo menos um papel/usuário** pela tela de administração de permissões do Hub — sem isso só `admin`/`gerente` conseguem agir na nova etapa. **Já está em produção**, então isso é o único bloqueador restante para qualquer pessoa fora de admin/gerente conseguir usar.
- [ ] Homologar o golden path completo no app publicado (`https://gestao-financeira-clone-544cb.goskip.app`): cliente aprova -> orçamento cai em "Aprovação da Equipe" -> usuário com permissão aprova (vai para financeiro) ou devolve ao cliente (motivo obrigatório, gera link novo) -> financeiro aprova normalmente.
- [ ] Decidir se a edição de peça/cor durante `'Aprovação da Equipe'` precisa de uma tela dedicada de "revisão pós-visita", ou se a tela padrão de edição de orçamento (`BudgetFormPage.tsx`) já é suficiente (é o que existe hoje — nenhuma UI nova de edição foi criada, só os botões Aprovar/Devolver).
- [ ] Reextrair `supabase/db/current/` e atualizar `supabase/db/domains/orcamentos.md` com o novo contrato de 4 etapas — pendência que já existia antes desta SPEC (snapshot desatualizado desde 2026-07-07) e não foi resolvida aqui.
- [ ] Decidir se vale estender o CHECK constraint do Hub para incluir uma ação `'aprovar'` dedicada no futuro (hoje reaproveita `'editar'`, que é semanticamente impreciso — conceder "editar" no módulo de aprovação da equipe também autoriza, em tese, qualquer outra ação futura que reaproveite essa mesma ação nesse módulo).
- [ ] **Risco em aberto (já documentado na SPEC-030, reconfirmado aqui)**: o projeto Skip pode ter conteúdo que diverge do GitHub sem aviso — nesta sessão, `useBudgetStore.ts` no Skip tinha um campo (`prazo_entrega_dias`) que não existe em nenhum commit do GitHub. Vale investigar de onde veio esse campo (alguém editou direto pela UI do Skip? Skip gerou automaticamente a partir de alguma sincronização de schema?) para não perder dado/código Skip-only no futuro. Não investigado nesta sessão — só preservado por precaução.