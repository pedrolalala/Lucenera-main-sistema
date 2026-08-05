---
titulo: "SPEC-058 — RH: Férias sem Bloqueio Duro e Lançamento de Folga Compensatória"
status: em execução (Pedido 1 e Pedido 2 Opção A publicados em produção; falta só as datas da Cris)
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - dashboard-rh-lucenera-5fe9c (RH)
---

# SPEC-058 — RH: Férias sem Bloqueio Duro e Lançamento de Folga Compensatória

## Checklist de Ação

### Pedido 1 — Remover bloqueio duro no lançamento de Férias

- [x] Confirmar com o usuário a decisão de UX de fricção (Pendência P-01/P-02) antes de codar — resolvido: 100% livre, sem confirmação extra
- [x] Migration `supabase/db/migrations/20260804_074_rh_ferias_periodo_opcional/001_periodo_aquisitivo_nullable.sql`: `ALTER TABLE public.ferias ALTER COLUMN periodo_aquisitivo_id DROP NOT NULL;` — **redigida, não aplicada no Supabase real** (renumerada de `072` para `074`, ver nota abaixo)
- [x] `VacationForm.tsx` — removido `isExceedingBalance` e `!periodoId` da condição `disabled` do botão de submit, mantendo os `<Alert>` visuais inalterados (salvo o texto do alerta de período ausente, ver item seguinte)
- [x] `VacationForm.tsx` — em `handleSubmit`, enviado `periodo_aquisitivo_id: periodoId || null` no `insert`/`update`
- [x] `VacationForm.tsx` — ajustada a mensagem do alerta de período ausente removendo "O agendamento é bloqueado"
- [x] (P-02 resolvida a favor de "sem fricção") Nenhum `AlertDialog`/`window.confirm` adicionado — submit é livre
- [x] Atualizado `supabase/db/domains/rh.md` com `ferias`, `periodos_aquisitivos`, `vw_controle_ferias_clt` e o comportamento de férias sem período aquisitivo

### Pedido 2 — Lançamento de folga compensatória

- [x] **Bloqueante:** decisão do usuário/RH entre Opção A e Opção B de desenho (ver Pendência P-05) — resolvido: Opção A
- [x] Opção A (novo valor de status em `controle_falta`) implementada:
  - [x] Migration `supabase/db/migrations/20260804_075_rh_controle_falta_folga/001_add_status_folga.sql`: dropa e recria `controle_ponto_status_check` incluindo `'folga'::text` — **redigida, não aplicada no Supabase real** (renumerada de `073` para `075`, ver nota abaixo)
  - [x] `FaltasDialog.tsx` — adicionado novo `SelectGroup` "Folgas / Compensações" com `SelectItem value="folga"` ("Folga Compensatória")
  - [x] `FaltasTabela.tsx` — adicionada entrada `folga: { label: 'Folga', color: 'bg-teal-500/10 ...' }` em `STATUS_CONFIG`
  - [x] `FaltasCalendario.tsx` — adicionada entrada `folga: 'Folga Compensatória'` em `STATUS_MAP`; cai no bucket visual `isLicenca` por exclusão (não é `isFalta` nem `isMedica`), sem necessidade de filtro/cor próprios
  - [x] Confirmado (não implementado, pois já é o comportamento padrão): `'folga'` não é tratado em `Folha.tsx` (que só reage a `falta_injustificada`/`ausente`, `atestado`, `licenca_maternidade`), logo não reduz `dias_trabalhados` nem `valor_vr_vt` — `Folha.tsx` não foi alterado
- [ ] Opção B — **fora de escopo deste ciclo**, não implementada
- [ ] Registrar os 3 dias da funcionária Cris — **pendente**: datas exatas ainda não informadas pelo usuário (Pendência P-07). Funcionalidade está pronta; quando as datas chegarem, basta um registro normal em Faltas com status "Folga"
- [x] Atualizado `supabase/db/domains/rh.md` com o desenho de "folga" (Opção A) escolhido

### Passos manuais do usuário

- [x] Decidir a Pendência P-01/P-02 (grau de fricção da UX de férias) — decidido: sem fricção
- [x] Decidir a Pendência P-03 (tornar `ferias.periodo_aquisitivo_id` nullable via migration) — decidido: sim
- [x] Decidir a Pendência P-05 (Opção A vs Opção B para folga) — decidido: Opção A
- [ ] Informar as 3 datas exatas em que a Cris vai usar a folga (Pendência P-07), para o lançamento poder ser feito
- [x] Rodar as duas migrations abaixo no Supabase real — **aplicadas em 2026-08-05**:
  - `supabase/db/migrations/20260804_074_rh_ferias_periodo_opcional/001_periodo_aquisitivo_nullable.sql`
  - `supabase/db/migrations/20260804_075_rh_controle_falta_folga/001_add_status_folga.sql`
- [ ] Homologar no navegador: (a) lançar férias para funcionário sem período aquisitivo e confirmar que salva; (b) lançar férias acima do saldo disponível e confirmar que salva; (c) lançar a folga da Cris (quando as datas chegarem) e confirmar que aparece na tabela e no calendário de Faltas
- [ ] Rodar o agente `revisor` antes de qualquer commit — **não rodado nesta publicação** (ver nota abaixo)

**Nota sobre numeração das migrations:** a SPEC original previa `20260804_072_...` e `20260804_073_...`, mas quando a implementação começou o número `072` já estava em uso por `20260804_072_pedido_compra_empresa_explicita` (outra SPEC, criada em paralelo). Para preservar a sequência global de migrations, as pastas desta SPEC foram renumeradas para `074` e `075`.

## Objetivo

A gerente do RH pediu duas mudanças no sistema RH (`dashboard-rh-lucenera-5fe9c`):

1. Remover os bloqueios duros do formulário de Férias que hoje impedem o registro quando o funcionário não tem período aquisitivo completo (caso de funcionário novo, ex. fechamento coletivo de dezembro) ou quando o pedido excede o saldo acumulado (caso de antecipação de férias por flexibilidade da empresa). Ela quer poder lançar mesmo assim.
2. Ter um lugar para lançar "folga" — dias de folga a que um funcionário tem direito por ter trabalhado nas eleições como mesário (direito legal, dado pelo governo). Não existe hoje nenhum conceito de "folga" no sistema. Pedido concreto e imediato: lançar 3 dias de folga para a funcionária Cris, que atuou nas eleições.

## Decisões aprovadas

- O cálculo de saldo de férias (`vw_controle_ferias_clt`, `direito_total_acumulado = periodos_aquisitivos × 30`) **não muda** nesta SPEC — a mudança é só sobre a UI permitir ou não submeter o formulário, não sobre quanto cada funcionário acumula de direito.
- O alerta visual de saldo excedido e de período aquisitivo ausente deve continuar visível ao usuário — a mudança é tirar o bloqueio do botão de submit, não esconder a informação.
- Não será criado nenhum mecanismo automático de geração de `periodos_aquisitivos` (ex. calcular a partir da data de admissão) — isso seria inventar uma regra de negócio de RH/CLT que não foi pedida nem confirmada.
- Não será decidido nesta SPEC um catálogo fixo de motivos de folga — o motivo "trabalhou nas eleições / mesário" é registrado como texto livre até uma decisão específica sobre estrutura (Pendência P-08).

## Definição da SPEC

### Pedido 1 — Remover bloqueio duro de Férias

#### Estado atual (confirmado no código e no schema)

| Peça | Local | Comportamento hoje |
|---|---|---|
| Bloqueio por período aquisitivo ausente | `VacationForm.tsx:112-121` busca `periodos_aquisitivos` por `funcionario_id`; se vazio, `periodoId` nunca é setado | Alert "O agendamento é bloqueado" (linhas 348-356); botão de submit fica `disabled` porque `!periodoId` está na condição (linha 369) |
| Bloqueio por saldo insuficiente | `isExceedingBalance = calculatedDays > availableDays` (linha 137), `availableDays` vem de `vw_controle_ferias_clt.saldo_disponivel` | Alert destrutivo (linhas 338-346); botão de submit fica `disabled` porque `isExceedingBalance` está na condição (linha 369) |
| Coluna `ferias.periodo_aquisitivo_id` | `01_schema_full.sql:4962` | `uuid NOT NULL` — hoje é **impossível** inserir uma linha em `ferias` sem um período aquisitivo válido, mesmo que a UI permitisse |
| View de saldo | `05_views.sql:72-90` | `vw_controle_ferias_clt` usa `INNER JOIN` entre `periodos_aquisitivos` e `funcionarios`; funcionário sem nenhum período **não aparece na view**, então `globalBalance` fica `{ saldo_disponivel: 0 }` (fallback do `.maybeSingle()` em `VacationForm.tsx:108`) |
| Criação de `periodos_aquisitivos` | busca em todo `src/`, `03_functions.sql`, `04_triggers.sql` | **Não existe** nenhuma tela, RPC ou trigger que crie `periodos_aquisitivos`. É uma tabela hoje só populável via SQL direto — achado relevante: mesmo removendo o bloqueio da UI, não há hoje um fluxo formal para "abrir" o período aquisitivo de um funcionário novo |

#### Mudança proposta

1. **Saldo excedido**: remover `isExceedingBalance` da condição `disabled` do botão (linha 369). Não requer migration — `ferias.dias` é sempre preenchido, `periodo_aquisitivo_id` continua sendo o período selecionado normalmente. O alerta continua visível, só deixa de travar o clique.
2. **Período aquisitivo ausente**: como `periodo_aquisitivo_id` é `NOT NULL` hoje, a única forma de permitir o registro sem período é:
   - Migration tornando a coluna nullable (`DROP NOT NULL`), e o front envia `null` quando não há período selecionado; **ou**
   - Manter `NOT NULL` e a gerente continuar sem poder lançar até criar manualmente um período aquisitivo via SQL (o que na prática não resolve o pedido dela).

   Recomendação: seguir o primeiro caminho (nullable). Consequência aceita: uma "férias" sem `periodo_aquisitivo_id` fica de fora de `vw_controle_ferias_clt` (que faz `INNER JOIN`), ou seja, não entra em nenhum controle de saldo, não desconta nada de ninguém e não aparece em `VacationBalances.tsx`. Isso é coerente com "deixa livre" — mas precisa ser validado como comportamento aceitável (Pendência P-04), porque significa que essas férias "livres" ficam sem rastro de saldo formal.

#### Critérios de aceite

- [ ] Funcionário sem nenhuma linha em `periodos_aquisitivos` consegue clicar em "Solicitar" no formulário de férias e o registro é salvo em `ferias` sem erro
- [ ] Funcionário com saldo disponível menor que os dias solicitados consegue clicar em "Solicitar" e o registro é salvo
- [ ] Os alertas visuais (saldo excedido / período ausente) continuam aparecendo nos dois casos acima — não foram removidos, só pararam de bloquear
- [ ] `SELECT * FROM ferias WHERE periodo_aquisitivo_id IS NULL;` retorna os registros lançados sem período (conferência manual, se a opção nullable for aprovada)
- [ ] Build/lint do sistema RH sem novo erro introduzido

### Pedido 2 — Folga compensatória

#### Estado atual (confirmado)

- Não existe tabela, coluna, enum nem tela com o conceito "folga" em nenhum lugar do sistema RH nem do schema central.
- `controle_falta.status` tem `CHECK` fixo com 12 valores (nenhum é "folga"); é usada na tela "Controle de Faltas" (`Faltas.tsx` → `FaltasTabela.tsx` + `FaltasCalendario.tsx`, com dialog de criação `FaltasDialog.tsx`).
- Cada um desses 3 componentes tem sua **própria lista hardcoded** de status (não há um enum central no front) — qualquer novo status precisa ser adicionado nos 3 lugares, mais o `CHECK` no banco.
- `Folha.tsx` só reage a 4 status específicos ao calcular desconto/VR-VT; um status novo não tratado explicitamente não afeta pagamento por padrão.

#### Duas opções de desenho

**Opção A — Novo valor de status em `controle_falta` (recomendada para MVP)**

- Adiciona `'folga'` (ou nome equivalente, ver Pendência P-08) ao `CHECK` de `controle_falta.status`.
- Usa a coluna `justificativa` (já existe, texto livre) para registrar o motivo ("Folga compensatória — atuação como mesário nas eleições").
- Prós: migration pequena, reaproveita 100% da tela/fluxo de Faltas já existente, RLS já é permissiva (nada novo a configurar).
- Contras: só permite marcar um **dia específico** já decidido. Não representa "a Cris tem 3 dias de folga disponíveis para usar quando quiser" — só dá para registrar depois que as datas já foram escolhidas. Não é uma modelagem de saldo/crédito.

**Opção B — Crédito/saldo de folgas (espelhando o modelo de férias)**

- Nova tabela de crédito (equivalente a `periodos_aquisitivos`) registrando que um funcionário ganhou N dias de folga por um motivo específico, e nova tabela/mecanismo de uso (equivalente a `ferias`) para consumir esse crédito em datas futuras, com uma view de saldo (equivalente a `vw_controle_ferias_clt`).
- Prós: representa corretamente o caso de uso dela — "ela tem 3 dias disponíveis para usar quando quiser", e permite RH acompanhar saldo de folgas pendente de uso, igual já faz com férias.
- Contras: escopo bem maior — tabela nova, tela nova, entrada de menu nova, decisão de RLS nova. Não é um ajuste pontual.

**Recomendação:** implementar a Opção A agora para resolver o pedido concreto e urgente (lançar os 3 dias da Cris), e avaliar a Opção B depois **apenas se** esse padrão de "folga compensatória por convocação eleitoral/serviço público" for recorrente o suficiente para justificar um módulo de saldo dedicado. Essa recomendação não é decisão fechada — fica como Pendência P-05 para o usuário validar com a gerente do RH.

#### Lançamento imediato dos 3 dias da Cris

Depende da opção escolhida e das datas exatas (não informadas na transcrição — ver Pendência P-07):

- **Se Opção A implementada:** inserir 3 linhas em `controle_falta` (uma por data), `funcionario_id` da Cris, `status = 'folga'` (ou nome final decidido), `justificativa = 'Folga compensatória — atuação como mesário nas eleições'`.
- **Se Opção B implementada:** inserir 1 linha de crédito (3 dias, motivo "eleições/mesário") e, quando as datas forem escolhidas, 1 registro de uso do crédito.
- **Se nenhuma opção estiver implementada ainda e o lançamento não puder esperar:** não há como registrar isso corretamente sem reaproveitar um status existente que mentiria sobre o motivo real (ex. usar `'licenca_militar'` seria dado incorreto/auditoria quebrada) — não é recomendado. A alternativa é a gerente controlar essas datas fora do sistema até a Opção A ser implementada (migration pequena, deve ser rápida) e então lançar corretamente.

#### Regras explícitas

| # | Regra |
|---|---|
| RN-01 | O motivo "trabalhou nas eleições (mesário)" precisa ficar rastreável — no mínimo via `justificativa` (texto livre, já existe). Se o usuário quiser um catálogo estruturado de motivos (dropdown), isso é uma extensão futura, não decidida aqui (Pendência P-08). |
| RN-02 | Um novo status de folga não deve, por padrão, contar como falta injustificada nem reduzir salário/VR-VT em `Folha.tsx`, a menos que explicitamente decidido em contrário (Pendência P-06). |
| RN-03 | Qualquer novo valor de status precisa ser adicionado consistentemente nos 3 arquivos de front que hoje duplicam a lista de status (`FaltasDialog.tsx`, `FaltasTabela.tsx`, `FaltasCalendario.tsx`), além do `CHECK` no banco — não há um enum central hoje para evitar essa duplicação; não é escopo desta SPEC criar essa centralização. |

#### Critérios de aceite

- [ ] (Opção A) É possível selecionar "Folga" ao registrar um novo item em Controle de Faltas, e o registro aparece na tabela e no calendário dessa tela
- [ ] (Opção A) `SELECT * FROM controle_falta WHERE funcionario_id = <id da Cris> AND status = 'folga'` retorna as 3 linhas lançadas, com `justificativa` mencionando eleições/mesário
- [ ] (Opção B) Existe uma visualização de saldo de folgas disponível por funcionário, análoga ao card de saldo de férias
- [ ] Build/lint do sistema RH sem novo erro introduzido pela mudança

## Realizado

**2026-08-05** — Publicado em produção. Migrations `20260804_074`/`20260804_075` aplicadas no Supabase real. Código publicado via Skip (`projectId 23919`, versão `0.0.217`/`9b88f1d`) junto com a SPEC-062 (busca de colaborador, mesmo arquivo `VacationForm.tsx`). Submodule local sincronizado, commit `989fd15`, push feito para `origin/main` (`dashboard-rh-lucenera-6g2endmv7`). **Nota**: publicação feita direto pelo orquestrador (fora do fluxo padrão planner→implementador→revisor) a pedido explícito do usuário ("vamos publicar alterando o que foi pedido também"); o agente `revisor` não foi executado antes do commit — recomenda-se rodá-lo numa próxima sessão se surgir dúvida sobre o código publicado.

**2026-08-04** — Implementados Pedido 1 (completo) e Pedido 2 Opção A (completo, exceto lançamento das datas da Cris) no sistema `dashboard-rh-lucenera-5fe9c`.

Arquivos alterados:
- `src/components/vacation/VacationForm.tsx` — bloqueio duro removido (saldo excedido e período aquisitivo ausente), `periodo_aquisitivo_id` enviado como `periodoId || null`, texto do alerta de período ausente ajustado
- `src/components/faltas/FaltasDialog.tsx` — novo `SelectGroup` "Folgas / Compensações" com `SelectItem value="folga"`
- `src/components/faltas/FaltasTabela.tsx` — nova entrada `folga` em `STATUS_CONFIG` (label "Folga", cor teal)
- `src/components/faltas/FaltasCalendario.tsx` — nova entrada `folga` em `STATUS_MAP`
- `supabase/db/domains/rh.md` — novas seções "Férias e período aquisitivo (SPEC-058)" e "Folga compensatória (SPEC-058)"

Migrations criadas (redigidas, **não aplicadas** no Supabase real):
- `supabase/db/migrations/20260804_074_rh_ferias_periodo_opcional/001_periodo_aquisitivo_nullable.sql`
- `supabase/db/migrations/20260804_075_rh_controle_falta_folga/001_add_status_folga.sql`

Verificação:
- `npm run lint` (oxlint) — sem novos avisos/erros introduzidos; avisos pré-existentes de `react-hooks/exhaustive-deps` em `FaltasDialog.tsx`/`FaltasCalendario.tsx` já existiam antes desta mudança
- `npm run build` (vite build) — build concluído com sucesso, sem erros
- `npm run format:check` (oxfmt) — reporta divergências em 123 arquivos do sistema, mas isso é um estado pré-existente do repositório (afeta arquivos não tocados por esta SPEC, ex. `main.css`, Edge Functions em `supabase/functions/`); não foi rodado `oxfmt` sem `--check` para não introduzir um diff de formatação massivo e não relacionado a esta SPEC

Não implementado (fora de escopo por decisão explícita do usuário):
- Opção B (crédito/saldo de folgas)
- Lançamento real dos 3 dias de folga da Cris — aguardando as datas exatas (Pendência P-07)

Testes manuais pendentes (não podem ser confirmados pelo implementador):
- Lançar férias para funcionário sem período aquisitivo e confirmar que salva sem erro (depende da migration `074` estar aplicada)
- Lançar férias acima do saldo disponível e confirmar que salva
- Confirmar visualmente que os alertas de saldo excedido / período ausente continuam aparecendo, sem bloquear o botão
- Selecionar "Folga Compensatória" no dialog de Faltas e confirmar que o registro aparece na tabela (badge "Folga", cor teal) e no calendário de Faltas (depende da migration `075` estar aplicada)

## Pendências

- [x] P-01 — Resolvida: "deixa livre" é literal — só remover o `disabled` do botão. Alertas visuais mantidos, apenas a frase "O agendamento é bloqueado" foi ajustada por não ser mais verdade.
- [x] P-02 — Resolvida: 100% livre, sem nenhuma confirmação extra (nem dialog, nem `window.confirm`).
- [x] P-03 — Resolvida: sim, `ferias.periodo_aquisitivo_id` tornou-se nullable. Migration redigida em `20260804_074_rh_ferias_periodo_opcional`, aplicação real pendente do usuário.
- [x] P-04 — Resolvida: aceito que férias sem período aquisitivo fiquem de fora de `vw_controle_ferias_clt` e de `VacationBalances.tsx`. A view não foi alterada nesta SPEC.
- [x] P-05 — Resolvida: Opção A implementada. Opção B não implementada, fora de escopo deste ciclo.
- [x] P-06 — Resolvida: `'folga'` não reduz `dias_trabalhados` nem desconto de VR/VT — comportamento padrão confirmado, `Folha.tsx` não foi alterado.
- [ ] P-07 — **Ainda pendente.** Datas exatas da folga da Cris não informadas; lançamento real não foi feito. Funcionalidade está pronta para receber o lançamento assim que as datas chegarem (registro normal em Faltas com status "Folga").
- [x] P-08 — Resolvida: motivo fica só em `justificativa` (texto livre); nenhum catálogo estruturado de motivos foi criado.
- [ ] P-09 — Fora de escopo desta SPEC (mantida em aberto conforme já registrado; `rh.md` foi atualizado apenas nas partes tocadas por esta SPEC — férias e folga).
- [ ] P-10 — Não se aplica neste ciclo, já que a Opção B não foi implementada.
