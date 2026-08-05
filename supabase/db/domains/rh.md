# Domínio: RH

## Papel no ecossistema

RH concentra dados de funcionários, equipes, cargos e responsáveis.

## Relação com outros domínios

- CRM pode atribuir responsáveis por tarefa.
- Projetos já possuem responsável.
- Hub/TI pode usar usuários/funcionários para permissões e acesso.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a RH:

- `public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date)`: consulta faltas injustificadas por funcionário/período.
- `public.handle_new_auth_user()` e `public.handle_new_user()`: criação/vínculo inicial de usuário, com impacto em pessoas/acesso.
- `public.get_vendedores()`: consulta vendedores, útil para atribuições comerciais.
- Funções genéricas de `updated_at` também afetam tabelas de funcionários.

Triggers relacionadas:

- `auth.users.on_auth_user_created`
- `public.funcionarios.funcionarios_updated_at`
- `public.usuarios.usuarios_updated_at`

Edge Functions relacionadas:

- `welcome-email`: e-mail de boas-vindas.
- `sync-teams`: integração/simulação Microsoft Teams.

Observação: functions locais encontradas apenas no projeto de RH não são fonte de verdade e não devem ser promovidas sem revisão específica.

## Férias e período aquisitivo (SPEC-058)

- `public.periodos_aquisitivos`: um registro por período aquisitivo de férias aberto para um `funcionario_id` (`data_inicio`, `data_fim`). Não existe hoje nenhuma tela, RPC ou trigger que crie `periodos_aquisitivos` automaticamente (ex. a partir da data de admissão) — é populado manualmente/por SQL direto.
- `public.ferias`: um registro por solicitação/lançamento de férias, com `funcionario_id`, `periodo_aquisitivo_id`, `data_inicio`, `data_fim`, `dias`, `status`. A partir da SPEC-058, `periodo_aquisitivo_id` é **nullable** (antes era `NOT NULL`) — permite lançar férias mesmo quando o funcionário não tem período aquisitivo cadastrado (ex. funcionário novo, fechamento coletivo de dezembro).
- `public.vw_controle_ferias_clt`: view de saldo de férias, `direito_total_acumulado = periodos_aquisitivos × 30`, usada para calcular `saldo_disponivel`. Faz **INNER JOIN** entre `periodos_aquisitivos` e `funcionarios` — não foi alterada pela SPEC-058.
- Consequência aceita e intencional: `ferias` lançadas com `periodo_aquisitivo_id IS NULL` ficam **de fora** de `vw_controle_ferias_clt` (não aparecem em `VacationBalances.tsx`, não entram no cálculo de saldo, não descontam nada de ninguém). O formulário de férias (`VacationForm.tsx`) permite submeter mesmo sem período aquisitivo ou acima do saldo disponível — os alertas visuais continuam aparecendo, apenas deixaram de bloquear o botão de submit.

## Folga compensatória (SPEC-058)

- Não existe (e não foi criada) uma modelagem de crédito/saldo de folgas espelhando `periodos_aquisitivos`/`ferias`. A folga compensatória é tratada como mais um valor de `status` em `public.controle_falta` (tabela de "Controle de Faltas", usada também para licenças e atestados).
- Valor de status: `'folga'`, incluído no `CHECK controle_ponto_status_check` de `controle_falta`.
- O motivo (ex. "atuou nas eleições como mesário") fica registrado apenas no campo `justificativa` (texto livre, já existente) — não há catálogo estruturado de motivos de folga.
- `'folga'` não reduz `dias_trabalhados` nem desconto de VR/VT em `Folha.tsx` — a folha só reage explicitamente a `falta_injustificada`/`ausente`, `atestado` e `licenca_maternidade`; qualquer status não tratado (incluindo `'folga'`) não afeta o cálculo por padrão.
- Cada um dos 3 componentes de front da tela "Controle de Faltas" (`FaltasDialog.tsx`, `FaltasTabela.tsx` com `STATUS_CONFIG`, `FaltasCalendario.tsx` com `STATUS_MAP`) mantém sua própria lista hardcoded de status — não há enum central; um novo status precisa ser adicionado nos 3 lugares e no `CHECK` do banco.
- Fora de escopo por decisão explícita: crédito/saldo de folgas para uso futuro em datas flexíveis (Opção B da SPEC-058) — avaliar apenas se esse padrão de folga por convocação se tornar recorrente.

## SPEC-064 — Perfil Ribeirão/São Paulo (2026-08-05)

**Achado**: `dashboard-rh-lucenera-5fe9c` tem 2 tabelas de funcionário — `funcionarios` (legada, 29 linhas, usada por Férias/Faltas) e `funcionarios_novo` (28 linhas, tela real de Cadastro via `EmployeeForm.tsx`, exposta por `vw_funcionarios_completo`). Ambas ganharam `perfil` (`text`, `CHECK IN ('ribeirao','sao_paulo')`, nullable) — rótulo puramente informativo (local de admissão), sem nenhum efeito em cálculo de folha/VR/VT/férias. `vw_funcionarios_completo` recriada expondo a coluna. Implementado em `EmployeeForm.tsx`/`funcionarios.ts`, Skip `projectId 23919`.

## Ação a ser realizada

Consolidar vínculo entre funcionário, usuário de sistema, permissões e responsabilidade operacional. Evitar duplicação entre cadastro de funcionário e perfil de login.
