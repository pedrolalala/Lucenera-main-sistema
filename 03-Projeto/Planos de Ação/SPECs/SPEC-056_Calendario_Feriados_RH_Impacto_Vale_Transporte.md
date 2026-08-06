---
titulo: "SPEC-056 — Calendário de Feriados no RH com Impacto no Vale Transporte"
status: implementado localmente — migration e publicação no Skip pendentes de confirmação
data_ultima_modificacao: 2026-08-06
sistemas_envolvidos:
  - dashboard-rh-lucenera-5fe9c (RH)
---

# SPEC-056 — Calendário de Feriados no RH com Impacto no Vale Transporte

## Checklist de Ação

- [ ] Criar tabela `public.feriados` no Supabase (migration `supabase/db/migrations/20260804_071_rh_feriados/`)
- [ ] Aplicar RLS em `public.feriados` conforme decisão tomada na Pendência P-04
- [ ] Reaproveitar `public.update_updated_at_column()` (já existe) para o trigger de `updated_at` de `feriados` — não criar função nova
- [ ] Criar `src/services/feriados.ts` no sistema RH (`fetchFeriados`, `createFeriado`, `updateFeriado`, `deleteFeriado`/`desativarFeriado`), seguindo o mesmo padrão de `src/services/empresas.ts`
- [ ] Atualizar `src/hooks/use-feriados.ts` para buscar também `public.feriados` do ano selecionado e mesclar com o resultado da BrasilAPI, mantendo o formato `{ date, name, type }` já consumido por `vale-transporte.ts`
- [ ] Remover o array hardcoded `SP_HOLIDAYS` de `src/lib/vale-transporte.ts` (linha 37) — feriado estadual de SP passa a vir do banco como um registro manual `tipo = 'estadual'`, não mais fixo no código
- [ ] Criar nova tela `src/pages/Feriados.tsx` (ou seção dedicada dentro de uma tela de Calendário, a critério do implementador) listando feriados do ano (nacionais/auto e manuais) com formulário de criar/editar/remover feriado manual
- [ ] Registrar rota `/feriados` em `src/App.tsx` e item de menu em `src/components/AppSidebar.tsx`
- [ ] Atualizar `supabase/db/domains/rh.md` documentando a tabela `feriados` e seu papel no cálculo de VT
- [ ] Investigar e resolver a divergência de schema descrita na seção "Achado crítico" antes de mexer em `vale-transporte.ts`/`ValeTransporte.tsx` (ver Pendência P-01)

### Passos manuais do usuário

- [ ] Rodar a migration de `feriados` no Supabase real (ou autorizar o implementador a rodar via `SUPABASE_DB_URL`)
- [ ] Decidir as perguntas em aberto na seção "Pendências" antes da implementação (especialmente P-01, P-02 e P-04, que mudam o desenho técnico)
- [ ] Homologar no navegador: cadastrar um feriado manual (ex.: emenda) e conferir que o VT de TODOS os funcionários do mês muda no lote calculado em `/vale-transporte`
- [ ] Validar com o financeiro/RH se o feriado estadual de 9 de julho (hoje hardcoded) deve ser recriado como registro manual `tipo = 'estadual'` na migração de dados, para não perder esse feriado ao remover `SP_HOLIDAYS`

## Objetivo

Hoje o RH busca feriados nacionais ao vivo na BrasilAPI (`use-feriados.ts`), mas não existe nenhum lugar no sistema para cadastrar feriados que a API não cobre — feriado estadual, municipal, ponto facultativo ou "emenda" (quando a empresa decide emendar um feriado com o fim de semana). A única exceção hoje é um feriado de SP (9 de julho) hardcoded direto no código-fonte de `vale-transporte.ts`, que só pode ser alterado com deploy.

Esta SPEC cria uma tabela de feriados no Supabase e uma tela no RH para cadastrar/editar/remover feriados manualmente, mesclando-os com os feriados nacionais da BrasilAPI. O resultado dessa mescla continua alimentando `calcularDiasUteis`/`countFeriadosInMonth`, que já reduzem o Vale Transporte de TODOS os funcionários do lote calculado quando há um feriado a mais no mês — essa mecânica já existe e é preservada, apenas passa a receber feriados configuráveis pela UI em vez de só os da API + um hardcode.

## Decisões aprovadas

- Um feriado cadastrado deve afetar o Vale Transporte de TODOS os funcionários, não de um funcionário específico — porque `diasUteis`/`feriadosCount` são calculados uma vez por lote (ano/mês/empresa) e usados para todos os funcionários daquele lote em `buildCalculos`. Isso já é como o sistema funciona hoje com os feriados da BrasilAPI e com o hardcode de SP; esta SPEC generaliza o mecanismo, não o inventa.
- O cadastro de feriados precisa suportar pelo menos: data, descrição, e um tipo que diferencie nacional / estadual / municipal / ponto facultativo / emenda — porque o usuário explicitamente pediu isso ("pode ter um dia que emendou ou não").
- O array `SP_HOLIDAYS` hardcoded em `vale-transporte.ts` deixa de ser a forma de cadastrar feriados fora da BrasilAPI; passa a ser um registro na tabela nova.

## Definição da SPEC

### Estado atual (confirmado no código e no schema)

| Peça | Arquivo/Local | Comportamento hoje |
|---|---|---|
| Busca de feriados nacionais | `src/hooks/use-feriados.ts` | `fetch` direto na BrasilAPI a cada render/troca de ano, sem cache, sem persistência no banco |
| Feriado extra hardcoded | `src/lib/vale-transporte.ts:37` | `const SP_HOLIDAYS = [{ month: 6, day: 9 }]` — mês 0-indexado = 9 de julho, aplicado a **todo** funcionário, independente de empresa/cidade |
| Mescla feriados + cálculo | `src/lib/vale-transporte.ts` — `getHolidayKeys`, `calcularDiasUteis`, `countFeriadosInMonth` | Junta API + `SP_HOLIDAYS` num `Set`, conta dias úteis do mês excluindo fins de semana e feriados |
| Consumo do cálculo | `src/pages/ValeTransporte.tsx` — `fetchCalculos()` | Chama `useFeriados(year)`, depois `calcularDiasUteis`/`countFeriadosInMonth`/`buildCalculos`; `diasLiquidos = diasUteis - diasFaltados`, `valorTotal = diasLiquidos * valor_vt_dia`, aplicado a todos os funcionários do lote |
| Tabela de feriados no banco | `supabase/db/current/01_schema_full.sql` | **Não existe.** Nenhuma tabela `feriados` ou equivalente. `supabase/db/domains/rh.md` também não documenta Vale Transporte, faltas, férias nem avaliações — está desatualizado em relação ao que o sistema RH já implementa |
| Controle de acesso à tela de VT hoje | `src/App.tsx` | Rota `/vale-transporte` protegida por `AdminGerenteRoute` (funcionário comum é redirecionado para `/faltas`); mesmo padrão vale para `/configuracoes`, `/comissao`, `/folha-pagamento`, `/avaliacoes`, `/relatorios`, `/cargos` |
| Papel/role do usuário | `usuarios.role` (enum `usuario_role`, valores incluindo `admin`, `gerente`, `operador`, `funcionario`) | Já é a fonte canônica de papel, lida em `use-auth.tsx` (`supabase.from('usuarios').select('role')`) — não inventar um sistema de permissão paralelo dentro do RH |

### Achado crítico — divergência de schema em `funcionarios_beneficios_empresas`

`ValeTransporte.tsx` (linha 103) faz hoje:

```ts
supabase.from('funcionarios_beneficios_empresas')
  .select('funcionario_id, empresa, empresa_id, valor_vt_dia')
```

ou seja, o código em produção já espera uma coluna `empresa_id` nessa tabela. A **SPEC-023** (`03-Projeto/Planos de Ação/SPECs/SPEC-023_Fix_Filtro_Empresa_Vale_Transporte_Lote_Recibos.md`), com `status: implementado`, documenta a migration `20260714_039_add_empresa_id_beneficios_empresas` que adiciona essa coluna, com checklist marcado `[x]`. Porém `supabase/db/current/01_schema_full.sql` (linha 5059-5064) mostra `funcionarios_beneficios_empresas` com **apenas** `id, funcionario_id, empresa, valor_vt_dia` — sem `empresa_id`.

Isso é uma contradição entre o snapshot central e uma migration supostamente aplicada (violação do que `AGENTS.md`/`COMO_CRIAR_SPEC.md` pedem para verificar). Duas explicações possíveis, e o implementador precisa checar qual é real antes de tocar em `vale-transporte.ts`/`ValeTransporte.tsx`:

1. A migration da SPEC-023 foi de fato aplicada no Supabase real, e `db/current/01_schema_full.sql` só não foi reextraído depois — nesse caso o banco real tem `empresa_id` e está tudo certo, só falta atualizar o snapshot central.
2. A migration nunca chegou ao Supabase real (mesmo padrão de divergência já registrado no `CHANGELOG.md` para SPEC-042/043/044/052/053/054 — código pronto que não chegou à produção) — nesse caso a query em produção falha silenciosamente (o código não trata `error` no destructuring de `benefData`), `benefData` fica vazio, e **todo o cálculo de VT já está quebrado hoje**, achando 0 funcionários com benefício.

Esta SPEC **não resolve** esse achado (não é o escopo do pedido do usuário), mas ele bloqueia com segurança qualquer edição em `fetchCalculos()`/`vale-transporte.ts` até confirmado — ver Pendência P-01.

### Tabela nova — `public.feriados`

Desenho para o implementador (não aplicar por este agente; migration em `supabase/db/migrations/20260804_071_rh_feriados/001_create_feriados.sql`):

```sql
CREATE TABLE public.feriados (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    data date NOT NULL,
    descricao text NOT NULL,
    tipo text NOT NULL,
    observacao text,
    ativo boolean DEFAULT true NOT NULL,
    criado_por uuid REFERENCES public.usuarios(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feriados_tipo_check CHECK (tipo IN ('nacional', 'estadual', 'municipal', 'ponto_facultativo', 'emenda')),
    CONSTRAINT feriados_data_descricao_key UNIQUE (data, descricao)
);

CREATE INDEX idx_feriados_data ON public.feriados USING btree (data);

CREATE TRIGGER feriados_updated_at
    BEFORE UPDATE ON public.feriados
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.feriados ENABLE ROW LEVEL SECURITY;
-- Policies de RLS: ver Pendência P-04 antes de escrever — não decidido nesta SPEC.
```

Notas de desenho:

- `ativo boolean` em vez de `DELETE` físico — permite "remover" um feriado da tela sem perder o histórico de que ele existiu (relevante porque o VT já calculado de meses passados não deve mudar retroativamente sem rastro). Confirmar com o usuário se esse é o comportamento esperado (Pendência P-03).
- `UNIQUE (data, descricao)` evita duplicar o mesmo feriado, mas permite duas datas diferentes com a mesma descrição (ex.: feriado móvel de anos diferentes) e duas descrições diferentes na mesma data (ex.: dois motivos coincidindo).
- **Não** foi incluída coluna de escopo por empresa/cidade (`empresa_id`) nesta v1 — feriados cadastrados valem para todos os funcionários/empresas, replicando o comportamento atual do hardcode `SP_HOLIDAYS` (que hoje já é aplicado a todo mundo, independente da cidade da empresa). Se for necessário feriado municipal por empresa/cidade, isso é uma extensão de schema futura — ver Pendência P-02.
- Não foi criada coluna `origem` (`brasilapi` vs `manual`): a tabela armazena **apenas** feriados cadastrados manualmente. Os nacionais continuam vindo ao vivo da BrasilAPI e são mesclados em memória no frontend, sem duplicar dado. Isso é consistente com "Existe dado duplicado que deveria ser derivado por relacionamento em vez de duplicado?" — aqui a resposta é: não duplicar os feriados nacionais no banco, só os que a API não cobre.

### Integração com `use-feriados.ts` e `vale-transporte.ts`

Fluxo proposto (implementação é do agente `implementador`, aqui só o contrato):

1. `useFeriados(year)` passa a disparar duas buscas em paralelo: a chamada atual à BrasilAPI e uma chamada nova a `feriados` do serviço `src/services/feriados.ts` filtrando `data` dentro do ano e `ativo = true`.
2. Os registros manuais são mapeados para o mesmo formato que a BrasilAPI já devolve (`{ date: 'YYYY-MM-DD', name: descricao, type: tipo }`) e concatenados ao array retornado por `useFeriados`.
3. `vale-transporte.ts` não muda a assinatura de `getHolidayKeys`/`calcularDiasUteis`/`countFeriadosInMonth` — eles já recebem `feriados: any[]` e só usam `f.date`. Basta remover o bloco `SP_HOLIDAYS` (linha 37 e o `forEach` na linha 60), porque o feriado estadual passa a chegar pela lista mesclada.
4. `ValeTransporte.tsx` não precisa de nenhuma mudança de lógica — continua chamando `useFeriados(year)` e passando o resultado adiante. O card "Gestão de Vale Transporte" automaticamente passa a refletir qualquer feriado manual cadastrado.

### Regras de negócio explícitas

| # | Regra |
|---|---|
| RN-01 | Um feriado cadastrado em `feriados` (com `ativo = true`) conta como feriado para **todos** os funcionários de **todas** as empresas no cálculo de dias úteis do mês — não há filtro por funcionário individual. |
| RN-02 | O impacto no VT é indireto: o feriado reduz `diasUteis` do mês, que reduz `diasLiquidos = diasUteis - diasFaltados` de cada funcionário, que reduz `valorTotal = diasLiquidos * valor_vt_dia`. Nenhuma lógica nova de cálculo é criada — o mecanismo já existe em `buildCalculos`. |
| RN-03 | Um feriado que cai em fim de semana não conta (mesma regra que já existe hoje para os feriados da BrasilAPI e para `SP_HOLIDAYS` — `calcularDiasUteis` já pula sábado/domingo antes de checar `holidayKeys`). |
| RN-04 | O cadastro manual de feriado não deve duplicar um feriado que a BrasilAPI já retorna para aquele ano (evitar contar o mesmo feriado duas vezes na contagem de `feriadosCount`) — o formulário deve, no mínimo, checar `UNIQUE(data, descricao)`; deduplicação por data pura (independente de descrição) é uma pergunta em aberto (Pendência P-05). |

### Critérios de aceite

- [ ] Tela de Feriados lista, para um ano selecionado, os feriados nacionais vindos da BrasilAPI (somente leitura, sem botão de editar/remover) junto com os feriados manuais cadastrados (com botões de editar/remover)
- [ ] Formulário de novo feriado exige `data`, `descricao` e `tipo`; salva e aparece na lista sem reload de página
- [ ] Editar/remover um feriado manual reflete imediatamente na lista
- [ ] Em `/vale-transporte`, calcular o lote de um mês com um feriado manual cadastrado em dia útil reduz `diasUteis`/`diasLiquidos`/`valorTotal` de **todos** os funcionários do lote em relação ao mesmo cálculo sem o feriado (conferir via comparação antes/depois, não via teste automatizado — nenhum dos 8 sistemas tem suíte de testes real)
- [ ] `SELECT * FROM feriados` confere que o feriado de 9 de julho de SP (se recriado como registro manual) aparece com `tipo = 'estadual'`
- [ ] Build/lint do sistema RH passam sem erro novo introduzido pela mudança
- [ ] Usuário sem papel admin/gerente não consegue acessar a tela nova (se a Pendência P-04 for resolvida mantendo o padrão `AdminGerenteRoute`)

## Realizado

**2026-08-06 — implementado localmente, aguardando confirmação para aplicar migration e publicar:**

- Banco: migration `supabase/db/migrations/20260806_079_spec056_feriados/001_create_feriados.sql` redigida (tabela `feriados`, RLS permissiva para `authenticated`, trigger de `updated_at` reaproveitando `public.update_updated_at_column()` já existente). **Ainda não aplicada no Supabase real** — pendente de confirmação explícita do usuário antes de rodar contra `SUPABASE_DB_URL`.
- Frontend (`dashboard-rh-lucenera-5fe9c`, local — ainda não publicado no Skip `projectId 23919`):
  - `src/hooks/use-feriados.ts`: passou a mesclar BrasilAPI + `public.feriados` (`ativo = true`) do ano selecionado.
  - `src/lib/vale-transporte.ts`: removido o hardcode `SP_HOLIDAYS`.
  - `src/components/faltas/FeriadoDialog.tsx` (novo): form de criar/editar/remover (soft-delete) feriado manual, mesmo padrão visual de `FaltasDialog.tsx`.
  - `src/components/faltas/FaltasCalendario.tsx`: botão "+ Feriado" e itens de feriado manual clicáveis para edição, ambos restritos a `user.app_role IN ('admin','gerente')`; feriados nacionais (BrasilAPI) continuam somente leitura para todos. Não foi criada tela/rota nova — reaproveitado o card "Calendário de Registros e Feriados" que já existia dentro de `Faltas.tsx` (Controle de Faltas).
  - `supabase/db/domains/rh.md` atualizado.
- Build (`npm run build`) e lint (`oxlint`) dos arquivos alterados passaram sem erro novo.
- **Não testado no navegador** e **não verificado no Skip** (padrão do projeto: submodule local pode divergir do que está publicado — ver `feedback_skip_deploy_separate_tree`). Antes de publicar, é preciso ler o código real do Skip (`skip_file_read`) para os arquivos tocados e confirmar que não há trabalho não sincronizado que seria perdido.

## Pendências

- [x] P-01 — Confirmado direto no Supabase real via `psql`: `funcionarios_beneficios_empresas.empresa_id` **existe**. A migration da SPEC-023 foi aplicada; só o snapshot `db/current/01_schema_full.sql` está desatualizado. Cálculo de VT não está quebrado.
- [x] P-02 — Decisão do usuário (2026-08-05): feriados são globais (valem para todos), com foco em nacional/estadual de Ribeirão Preto (SP) — sem filtro por empresa/cidade nesta v1.
- [x] P-03 — Soft-delete (`ativo = false`), como já desenhado no schema original — preserva histórico de VT de meses passados.
- [x] P-04 — RLS permissiva para `authenticated` + controle de acesso só na UI (admin/gerente), mesmo padrão já usado em outras tabelas do RH. Confirmado pelo usuário.
- [x] P-05 — Deduplicação por data mantida como já era (`Set` de chaves `year-month-day`), sem mudança de comportamento.
- [x] P-06 — Sem backfill retroativo (decisão do usuário, 2026-08-05): tabela só passa a valer a partir do primeiro cadastro.
- [x] P-07 — Resolvido pelo usuário (2026-08-05): **não** criar tela/rota nova — reaproveitar o card "Calendário de Registros e Feriados" já existente em `Faltas.tsx` (Controle de Faltas). SPEC atualizada para refletir essa decisão em vez do desenho original (tela dedicada `/feriados`).
- [x] P-08 — Confirmado: não criar `AI_DB_CONTEXT.md` novo para este sistema; documentado só em `supabase/db/domains/rh.md`.

### Passos manuais do usuário (pendentes)

- [ ] Confirmar se posso aplicar a migration `20260806_079_spec056_feriados` no Supabase real.
- [ ] Confirmar se posso publicar (`skip_project_apply_changes` + `skip_project_publish`) o sistema RH no Skip (`projectId 23919`) com essas mudanças.
- [ ] Homologar no navegador: cadastrar um feriado manual (emenda) e conferir que o VT de todos os funcionários do mês muda no lote calculado em `/vale-transporte`.
- [ ] Validar se o feriado estadual de 9 de julho deve ser recriado manualmente como registro `tipo = 'estadual'` após a migration, já que o hardcode foi removido.
