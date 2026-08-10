---
titulo: "SPEC-069 — Matriz de Permissões por Perfil (RBAC) nos Sistemas Lucenera"
status: implementado (Ficha Técnica/P6 fora, botões granulares de Cadastro/Orçamentos pendentes)
data_ultima_modificacao: 2026-08-10
sistemas_envolvidos:
  - Hub / Central
  - RH
  - CRM
  - Cadastro (Consulta de Produtos / "Luceneira")
  - Orçamentos
  - Necessidade de Compra / Estoque-Compras
  - Administração Bancária
  - Sistema de Entregas / Logística
  - Dashboard Financeiro
  - Ficha Técnica (sistema a confirmar — ver Pendência P6)
---

# SPEC-069 — Matriz de Permissões por Perfil (RBAC) nos Sistemas Lucenera

> Nota de numeração: esta SPEC passou por `SPEC-067` e `SPEC-068` antes de fechar em `SPEC-069` —
> ambos os números foram ocupados por outras SPECs criadas em paralelo
> (`SPEC-067_Enviar_Cliente_PDF_Automatico_Email_Mailto.md` e
> `SPEC-068_Correcoes_Orcamento_Cliente_Desconto_Sinal_Vendedor_Busca_Projeto.md`).

## Checklist de Ação

### Confirmações antes de qualquer migration

- [ ] Confirmar com o usuário as Pendências P1–P7 desta SPEC (slug real de Necessidade de Compra,
      nomes definitivos dos papéis, escopo de linha da Equipe de Entrega em Orçamentos, enforcement
      diferenciado de `contatos` por tipo, guard de aprovação financeira, **qual sistema é
      "Ficha Técnica" de verdade** — ver P6, granularidade dentro dos apps de Compras/Cadastro).
- [ ] Rodar `SELECT id, name, slug, visivel_no_hub FROM public.systems ORDER BY display_order;` no
      Supabase real para confirmar os slugs de todos os sistemas antes de escrever a migration de
      seed (7 foram fixados manualmente pela SPEC-006; os demais vieram de slugify automático, não
      documentado em nenhum arquivo do repositório) — e para checar se já existe algum candidato a
      "Ficha Técnica" além da linha legada `name = 'Fichas Técnicas'`/slug `ubiqua` (ver P6).

### Migration central (banco)

- [x] Criar os 6 papéis reutilizáveis em `public.papeis` (nomes provisórios — ver Pendência P2):
      `admin_geral`, `rh_administracao`, `administracao_comercial`, `compras_e_entregas`,
      `equipe_projetos`, `equipe_entrega`. **Aplicado no Supabase real** —
      `supabase/db/migrations/20260806_084_spec069_rbac_matriz_perfis/001_seed_papeis_permissoes.sql`.
- [x] Popular `public.papel_permissoes` para os 6 papéis × 9 sistemas já resolvidos (`hub`,
      `financeiro`, `cadastro`, `crm`, `orcamentos`, `necessidade-de-compra`, `logistica`, `rh`,
      `dashboard-financeiro`) conforme a matriz da seção "Matriz papel × sistema × nível × ações"
      — **44 linhas aplicadas e conferidas no Supabase real**, incluindo a ação nova `aprovar`
      (adicionada ao CHECK de `papel_permissoes.acao`/`modulo_acoes.chave` na mesma migration) para
      `administracao_comercial` em Orçamentos. **Não incluí "Ficha Técnica" neste lote** — depende
      da Pendência P6.
- [x] Atribuir os usuários reais aos papéis via `usuario_papeis`: Vinícius → `admin_geral`, Lana →
      `rh_administracao`, Débora → `compras_e_entregas`, Mariane → `equipe_projetos` — aplicado.
      **Carol**: usuário confirmou o e-mail (`caroline@lucenera.com.br`) na mesma sessão — conta
      criada via a RPC oficial `criar_usuario` (mesma usada pela tela "Novo Usuário" da Central,
      SPEC-059), role legado `funcionario`, senha temporária gerada e repassada ao usuário fora
      deste documento. Atribuída ao papel `administracao_comercial`. Sem pendência.
- [ ] Depois que P6 for resolvida (e a linha de `systems` para Ficha Técnica existir, nova ou
      reaproveitada): popular `papel_permissoes` para `equipe_projetos` e `admin_geral` nesse
      sistema (`equipe_projetos` = EDITAR, `admin_geral` = TOTAL, demais = SEM ACESSO), como um
      incremento separado desta mesma SPEC.
- [x] **Desbloqueado e aplicado (2026-08-06).** Investigado o código real da SPEC-031
      (`equipe_aprovar_orcamento`/`equipe_devolver_orcamento_cliente`): checa `usuarios.role`
      diretamente (`v_user_role IN ('admin','gerente')`), não a tabela `usuario_papeis` — remover o
      papel legado `gerente` de Lana/Mariane não afeta a aprovação de equipe da Mariane. Confirmado
      com o usuário e removido (`DELETE` em `usuario_papeis`).
- [x] Guard adicionado em `criar_produto_orcamento(p_payload jsonb)` — **achado**: já tinha checagem
      de role legado (admin/gerente/operador), a suposição inicial de "sem checagem nenhuma" estava
      desatualizada. Adicionada camada extra (AND, nunca amplia acesso) exigindo `criar` em
      `cadastro` OU `orcamentos` via `hub_pode_executar` — é isso que bloqueia especificamente quem
      só tem "Editar sem cadastrar" (`equipe_projetos`). Migration
      `20260806_086_spec069_rpc_guards_orcamentos`, **aplicada no Supabase real**.
- [x] Guard adicionado em `aprovar_orcamento_financeiro` — confirmado que realmente não tinha
      nenhuma checagem. Agora exige `hub_pode_executar(uid,'orcamentos',NULL,'aprovar')` — só
      Administrador Geral (via TOTAL/coringa) e Carol/`administracao_comercial` (ação `aprovar`
      explícita) passam. **Aplicado no Supabase real.**
- [x] RLS revisado e substituído nas tabelas onde confirmei, consultando `pg_policies` ao vivo (não
      o snapshot desatualizado), que havia policy `USING (true)` redundante neutralizando qualquer
      policy nova: **Administração Bancária** (`boletos`, `notas_fiscais`, `remessas`,
      `contas_bancarias`) e **RH** (`funcionarios_novo`). Migration
      `20260806_085_spec069_rls_financeiro_rh`, **aplicada e testada** (`hub_pode_executar`
      confirmado: Vinícius vê financeiro, Lana vê RH, Mariane não vê nenhum dos dois).
      **Deliberadamente não tocado**: `ferias`, `controle_falta`, `periodos_aquisitivos`,
      `funcionarios`, `custos_recorrentes` já tinham proteção real via `get_user_role()`/checagem de
      `usuarios.role`, incluindo autoatendimento do funcionário (`funcionario_id =
      get_my_funcionario_id()`) — substituir por `hub_pode_executar` quebraria esse autoatendimento
      sem necessidade. `feriados` (calendário compartilhado) também não tocado, baixa sensibilidade.
- [x] **Aplicado (2026-08-10)**, migration `20260810_091_spec069_rls_shared_tables`: `crm`/
      `orcamentos`/`cadastro` em `projetos`, `contatos` (com split cliente/arquiteto vs
      fornecedor, aprovado pelo usuário), `orcamentos`, `orcamento_itens`, usando OR entre os
      slugs que legitimamente escrevem cada tabela compartilhada.
- [x] **Aplicado (2026-08-10)**, mesma migration: `logistica` (`separacoes`, com OR para
      `separacao-parcial` também — o sistema novo da SPEC-072 escreve nessa tabela) e Compras
      (`solicitacoes_compra`, `pedido_compra_itens`, `cotacoes_compra`) + guards de RPC em
      `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade`/`cancelar_pedido_compra`/
      `atualizar_preco_custo_produto`. **Achado**: `entregas` e `pedidos_compra` já não tinham
      nenhuma policy `true` de escrita (já protegidas por role legado ou só alcançáveis via RPC
      guardada) — nenhuma mudança necessária nelas. **Deliberadamente não guardado**:
      `registrar_devolucao_projeto_item*` — já é chamada de dentro de
      `aprovar_orcamento_financeiro` (que já tem seu próprio guard de `aprovar`), e um guard novo
      ali arriscava quebrar o fluxo de devolução da SPEC-071 testado nesta mesma sessão. Fica para
      uma iteração futura, com mais cuidado.
- [x] Verificado com RLS real (não `SUPABASE_DB_URL`/service role): `SET ROLE authenticated` +
      JWT claims de Lana (`rh_administracao`, SEM ACESSO em orçamentos) → `UPDATE 0` linhas;
      mesmo teste com Vinícius (`admin_geral`) → `UPDATE 1` linha. Confirma que a policy nova
      está de fato sendo enforçada, não só existindo.
- [ ] Reextrair `supabase/db/current/` após todas as migrations desta SPEC — ainda não feito.

### Hub / Central (`central-lucenera-dashboard-1c9ba`) — **aplicado (2026-08-10)**

- [x] `src/pages/admin/components/RolesTab.tsx` estendido: o checkbox binário "Acesso total" virou
      um `Select` com 5 níveis (Total/Editar/Editar sem cadastrar/Consultar/Sem acesso) por
      papel×sistema — cada nível grava o conjunto de `acao` correspondente em `papel_permissoes`
      (`modulo_id` sempre `NULL`, permissão por módulo específico continua fora de escopo).
      Publicado (Skip `37750`, versão `0.0.38`).
- [x] Nenhuma mudança necessária em `AccessTab.tsx` (confirmado, sem alteração).

### Adoção por sistema (frontend + guard local, padrão já usado pela SPEC-063) — **os 7 restantes aplicados (2026-08-10)**

Padrão replicado em todos: `hasAccess` (boolean) adicionado ao contexto de auth de cada app,
calculado via `supabase.rpc('hub_pode_executar', { p_usuario_id, p_system_slug: '<slug>',
p_modulo_chave: null, p_acao: null })`; a rota protegida de cada app passou a checar
`hasAccess === false` e renderizar uma tela "Acesso negado" (mesmo texto/estrutura usados pela
SPEC-063 em Dashboard Financeiro). QA completo do Skip (setup/staticAnalysis/build/
integrations/test) rodado e publicado para cada um.

- [x] RH (`dashboard-rh-lucenera-5fe9c`, Skip `23919`): slug `rh`, publicado `0.0.221`.
- [x] CRM (`lucenera-crm-3bd29`, Skip `24580`): slug `crm`, publicado `0.0.292`.
- [x] Cadastro (`cadastro-lucenera-b86fe`, Skip `36668`): slug `cadastro`, publicado `0.0.52`.
      **Não feito**: esconder botão "Novo Produto" para papéis sem `criar` (`equipe_projetos`,
      `compras_e_entregas`) — o guard de página (`hasAccess`) e o RLS de `produtos` (SPEC-069
      anterior) já impedem a escrita real; falta só a UX de esconder o botão.
- [x] Orçamentos (`gestao-financeira-clone-544cb`, Skip `32554`): slug `orcamentos`, publicado
      `0.0.305`. Somado ao gate de role legado (`visitante`/`viewer`) que já existia. **Não
      feito**: esconder "Novo Orçamento" para `equipe_projetos` (sem `criar`) e deixar
      `equipe_entrega` só em modo leitura — mesma observação acima, o RLS já bloqueia a escrita
      de verdade, falta só a UX.
- [x] Necessidade de Compra (`compras-lucenera-3o23t98ee`, Skip `40326`): slug
      `necessidade-de-compra`, publicado `0.0.56`.
- [x] Administração Bancária (`retorno-bancario-bradesco-5392a`, Skip `36395`): slug `financeiro`,
      publicado `0.0.58`.
- [x] Sistema de Entregas (`lucenera-logistics-b7cd1`, Skip `24039`): slug `logistica`, publicado
      `0.0.81`.
- [x] Dashboard Financeiro (`dashboard-lucenera-b02z85wa3`): já adotado pela SPEC-063 — confirmado
      que nenhum dos 6 papéis novos (além de `admin_geral`) recebeu linha em `papel_permissoes`
      para esse sistema, sem alteração necessária.
- [ ] Ficha Técnica: **segue bloqueado — usuário confirmou pular por agora** (app Flask fora do
      Skip, sem link de produção confirmado, sem código que consulte `hub_pode_executar`;
      integrá-lo é um projeto à parte). Ver Pendência P6.

### Documentação

- [ ] Atualizar `supabase/db/domains/hub_ti.md` com a lista de sistemas adotados após esta SPEC.
- [ ] Atualizar `AI_DB_CONTEXT.md` de cada sistema tocado.
- [x] `CHANGELOG.md` atualizado (2026-08-10).

### Passos manuais do usuário

- [ ] Confirmar as Pendências P1–P7 antes de qualquer migration ser escrita.
- [ ] Resolver especificamente a Pendência P6 (qual sistema é "Ficha Técnica"): confirmar se é o
      repositório `https://github.com/pedrolalala/Lucenera-Power-point.git` (sistema novo, sem
      submodule local ainda) ou a linha já existente `systems.name = 'Fichas Técnicas'` (slug
      `ubiqua`, Catálogo de Peças Ubiqua). Se for o repo novo, alguém precisa cloná-lo/registrá-lo
      como submodule em `04-Sistemas/` e criar a linha correspondente em `public.systems` (com
      `slug` distinto de `ubiqua`, para não colidir com a linha legada) antes de qualquer trabalho
      de RLS/RPC/Layout para esse sistema.
- [ ] Fornecer e-mails/IDs reais de todos os usuários de "Equipe de Projetos" e "Equipe de Entrega"
      além de Mariane, para popular `usuario_papeis`.
- [ ] Rodar a migration no Supabase real (fora do escopo deste planejador).
- [ ] Homologar manualmente cada sistema logado como cada papel (golden path no navegador) antes de
      considerar a SPEC concluída — sem suíte de testes automatizada, nenhum dos sistemas tem.
- [ ] Decidir quem pode aprovar financeiramente orçamentos (Pendência P5) antes de aplicar o guard
      em `aprovar_orcamento_financeiro`.

## Objetivo

Hoje qualquer usuário autenticado no ecossistema Lucenera consegue, tecnicamente, ler e escrever em
praticamente qualquer tabela de qualquer sistema — a checagem de papel que existe hoje é só de UI
(esconder botão) em no máximo 2 sistemas (Dashboard Financeiro via SPEC-063, um trecho de Orçamentos
via SPEC-031), e a maior parte das tabelas tem RLS `USING (true)` para `authenticated` (confirmado em
`supabase/db/current/07_rls_policies.sql`). Esta SPEC define os papéis reutilizáveis pedidos pelo
usuário (Vinícius/Lana/Carol/Débora/Mariane e as duas equipes) como uma matriz
papel × sistema × nível de acesso sobre a infraestrutura de permissões já existente (SPEC-006:
`papeis`, `papel_permissoes`, `usuario_papeis`, RPC `hub_pode_executar`), e desenha — sistema por
sistema — como esse bloqueio passa a valer tanto na tela quanto na escrita direta no banco, não só
escondendo botão.

## Decisões aprovadas

- Hierarquia de níveis (do maior para o menor): **TOTAL** (ver/criar/editar/excluir/aprovar) →
  **EDITAR** (ver/criar/editar) → **EDITAR (SEM CADASTRAR)** (ver/editar, sem criar) →
  **CONSULTAR** (só ver) → **SEM ACESSO**.
- 6 papéis reutilizáveis fechados pelo usuário (não são permissão individual): Administrador Geral
  (Vinícius) — TOTAL em tudo; Gestão de RH (Lana) — TOTAL só em RH, SEM ACESSO no resto, único papel
  além do admin com acesso a RH; Administração Comercial (Carol) — EDITAR em Cadastro/Orçamentos/
  Necessidade de Compra; Operação de Compras e Entregas (Débora) — CONSULTAR em Cadastro, EDITAR em
  Necessidade de Compra e Sistema de Entrega; Equipe de Projetos (Mariane e demais) — EDITAR em
  CRM/Necessidade de Compra/Entrega(/Ficha Técnica, quando resolvida), EDITAR SEM CADASTRAR em
  Cadastro/Orçamentos; Equipe de Entrega — CONSULTAR em Orçamentos, EDITAR em Sistema de Entrega.
- Dashboard e Administração Bancária ficam exclusivos do Administrador Geral — nenhum outro papel
  listado tem qualquer nível de acesso a esses dois.
- O bloqueio precisa valer também na API/backend, não só escondendo botão no frontend.
- **"Luceneira" (item do pedido original) = o sistema Cadastro** (`cadastro-lucenera-b86fe`, slug
  `cadastro`) — confirmado pelo usuário. Não é um sistema separado, não é o Catálogo Ubiqua. Como
  `papel_permissoes` é puramente aditivo (linhas concedem, nunca revogam), a linha "Luceneira" e a
  linha "Consulta de Produtos" da planilha original do cliente se fundem sem conflito na mesma
  coluna `cadastro` desta matriz (ver seção seguinte).

## Definição da SPEC

### Infraestrutura já existente (SPEC-006, confirmada aplicada no Supabase remoto)

- Tabelas `modulos`, `modulo_acoes` (`chave IN ('criar','editar','deletar','visualizar')`),
  `papeis`, `papel_permissoes` (papel × sistema × módulo-ou-NULL × ação-ou-NULL),
  `usuario_papeis`, `usuario_permissao_excecoes`, `auditoria_permissoes`.
- RPC `hub_pode_executar(p_usuario_id, p_system_slug, p_modulo_chave, p_acao)` — confirmada no
  código real (`.../20260708_029_spec006_permissoes_granulares_hub/002_rpcs.sql`) com a semântica
  correta `(pp.acao IS NULL OR pp.acao = p_acao)` (o desenho original da SPEC tinha um bug de NULL
  já corrigido antes de aplicar).
- RPC `hub_sistemas_permitidos(p_usuario_id)` — default-deny: um papel sem nenhuma linha em
  `papel_permissoes` para um sistema simplesmente não aparece, o que já implementa "SEM ACESSO" sem
  nenhuma mudança de schema.
- **"EDITAR (SEM CADASTRAR)" já cabe no modelo sem mudar schema**: basta conceder `editar` +
  `visualizar` e não conceder `criar`.
- **Nenhum módulo (`modulos`) está cadastrado hoje para nenhum sistema além do próprio Hub**
  (módulo `permissoes`) e de um módulo pontual `aprovacao_equipe` em `orcamentos` (SPEC-031). Todos
  os 6 papéis desta SPEC usam `modulo_id NULL` (nível "sistema inteiro").

### Slugs confirmados de `systems` (via migration/código, não via SELECT ao vivo)

| Sistema no pedido | Pasta local | `systems.slug` |
|---|---|---|
| Hub / Central | `central-lucenera-dashboard-1c9ba` | `hub` (auto-governança, `visivel_no_hub=false`) |
| Administração Bancária | `retorno-bancario-bradesco-5392a` | `financeiro` |
| Cadastro (= "Consulta de Produtos" e "Luceneira" do pedido original) | `cadastro-lucenera-b86fe` | `cadastro` (confirmado: `systems.name = 'Consultar Produtos'`) |
| CRM | `lucenera-crm-3bd29 (1)` | `crm` |
| Orçamentos | `gestao-financeira-clone-544cb (1)` | `orcamentos` (confirmado em código real, `TeamApprovalTab.tsx`) |
| Sistema de Entrega | `lucenera-logistics-b7cd1` | `logistica` |
| RH | `dashboard-rh-lucenera-5fe9c` | `rh` |
| Dashboard | `dashboard-lucenera-b02z85wa3` | `dashboard-financeiro` (confirmado em código real, `use-auth.tsx` da SPEC-063) |
| Necessidade de Compra | `compras-lucenera-3o23t98ee` | **não confirmado** — ver Pendência P1 |
| Ficha Técnica | **não confirmado** — ver Pendência P6 | **não confirmado** |

Nota: existe hoje uma linha em `systems` com `name = 'Fichas Técnicas'` e `slug = 'ubiqua'`
(Catálogo de Peças Ubiqua, `catalogo-pecas-ubiqua-e6fa0`) — criada por um `UPDATE` da migration da
SPEC-006. **Não presumir que essa linha é o sistema "Ficha Técnica" do pedido atual** — ver
Pendência P6, isso não foi decidido nesta SPEC.

### Matriz papel × sistema × nível × ações

Ações gravadas em `papel_permissoes.acao` por nível (`modulo_id` sempre `NULL`):

| Nível | Ações gravadas |
|---|---|
| TOTAL | 1 linha, `acao = NULL` (equivale ao checkbox "Acesso total" já existente no `RolesTab.tsx`) |
| EDITAR | `criar`, `editar`, `visualizar` |
| EDITAR (SEM CADASTRAR) | `editar`, `visualizar` |
| CONSULTAR | `visualizar` |
| SEM ACESSO | nenhuma linha |

| Papel | hub | financeiro | cadastro | crm | orcamentos | compras* | logistica | rh | dashboard-financeiro | ficha_tecnica** |
|---|---|---|---|---|---|---|---|---|---|---|
| admin_geral (Vinícius) | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL | TOTAL |
| rh_administracao (Lana) | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | TOTAL | SEM ACESSO | SEM ACESSO |
| administracao_comercial (Carol) | SEM ACESSO | SEM ACESSO | EDITAR | SEM ACESSO | EDITAR | EDITAR | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO |
| compras_e_entregas (Débora) | SEM ACESSO | SEM ACESSO | CONSULTAR | SEM ACESSO | SEM ACESSO | EDITAR | EDITAR | SEM ACESSO | SEM ACESSO | SEM ACESSO |
| equipe_projetos (Mariane +) | SEM ACESSO | SEM ACESSO | EDITAR (SEM CADASTRAR) | EDITAR | EDITAR (SEM CADASTRAR) | EDITAR | EDITAR | SEM ACESSO | SEM ACESSO | EDITAR |
| equipe_entrega | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | CONSULTAR | SEM ACESSO | EDITAR | SEM ACESSO | SEM ACESSO | SEM ACESSO |
| dashboard_financeiro_acesso (Filippo, Pedro, Vinícius) | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | SEM ACESSO | TOTAL | SEM ACESSO |

\* coluna `compras` = Necessidade de Compra/Estoque-Compras — **P1 resolvida**: slug real confirmado
`necessidade-de-compra` (`SELECT slug FROM systems`), já usado no seed aplicado.
\** coluna `ficha_tecnica` = sistema pendente de identificação (P6); **não incluído no lote aplicado**
— só depois que P6 estiver resolvida e a linha em `systems` existir.

### Achado crítico (2026-08-06) — papéis legados (`gerente`/`admin`/`funcionario`/`operador`/`viewer`) conflitam com a matriz nova e bloqueiam a adoção segura

Ao conferir o seed aplicado no Supabase real, descobri que **Lana e Mariane continuam com o papel
legado `gerente`** em `usuario_papeis` (seed de compatibilidade da própria SPEC-006, "para não
quebrar o acesso de ninguém na migração"), além do papel novo e restrito que acabei de atribuir a
elas. O papel `gerente` tem `papel_permissoes` com `modulo_id NULL, acao NULL` (TOTAL/coringa) em
**Administração Bancária, RH, CRM, Orçamentos, Sistema de Entregas, Fichas Técnicas e Hub** —
exatamente os sistemas que a matriz nova pede como SEM ACESSO ou como nível mais baixo para essas
duas pessoas. `hub_pode_executar` combina os papéis de um usuário com OR (qualquer papel que libere,
libera) — então, **enquanto o papel `gerente` continuar atribuído, qualquer policy RLS ou guard de
RPC baseado em `hub_pode_executar` que eu escrever para RH/Administração Bancária vai deixar
Lana e Mariane passarem mesmo assim**, tornando o "hardening" cosmético para elas duas
especificamente. (Confirmei também que Débora não tem nenhum papel legado atribuído — sem conflito
para ela; Vinícius tem o legado `admin`, que é redundante com `admin_geral`, sem problema.)

**Por que não removi o papel `gerente` de Lana/Mariane sozinho**: o papel `gerente` legado também
concede `modulo_id NULL` em Orçamentos, e a SPEC-031 já usa um módulo `aprovacao_equipe` dentro de
Orçamentos que pode depender de `hub_pode_executar` — não confirmei se a etapa de "Aprovação da
Equipe" que Mariane usa hoje no fluxo real de orçamento depende desse grant legado para funcionar.
Remover o papel sem confirmar isso é uma mudança de acesso em produção com efeito colateral
desconhecido sobre um fluxo já em uso — por isso parei aqui em vez de decidir sozinho.

**Isso bloqueia, com segurança, os 3 itens seguintes desta SPEC** (guard de `criar_produto_orcamento`,
guard de `aprovar_orcamento_financeiro`, RLS de RH/Administração Bancária) até uma das duas opções
ser confirmada:

- **(a)** Remover o papel `gerente` de Lana e Mariane em `usuario_papeis` (mantendo só o papel novo
  e restrito) — provavelmente correto, mas preciso confirmar antes que isso não quebra a etapa de
  aprovação de equipe da Mariane em Orçamentos hoje.
- **(b)** Adicionar exceções explícitas de negação (`usuario_permissao_excecoes`, tipo `negar`) para
  Lana/Mariane nos sistemas que devem ficar SEM ACESSO — mais granular e não toca no papel `gerente`
  (preserva qualquer outro efeito dele), mas exige uma linha por ação (`criar`/`editar`/`deletar`/
  `visualizar`/`aprovar`) por sistema por usuária — mais verboso, porém mais seguro.

### Achado técnico crítico — RLS atual não vai enforçar nada sozinho

Confirmado em `supabase/db/current/07_rls_policies.sql`: praticamente toda tabela de negócio
(`orcamentos`, `orcamento_itens`, `produtos`, `projetos`, `contatos`, `boletos`, `notas_fiscais`,
`funcionarios`, `separacoes`, `entregas`, `solicitacoes_compra` etc.) tem **múltiplas policies
`PERMISSIVE` redundantes** com `USING (true)`/`WITH CHECK (true)` para `authenticated` — sobras de
migrations diferentes que nunca foram consolidadas. O Postgres combina policies `PERMISSIVE` da
mesma ação com **OR**. Isso significa que **simplesmente adicionar uma policy nova baseada em
`hub_pode_executar` não bloqueia nada** enquanto a policy antiga `USING (true)` continuar existindo
— as duas são avaliadas com OR e a antiga sempre libera. Toda migration de RLS desta SPEC precisa
`DROP POLICY` das antigas na mesma transação em que cria a nova.

### RPCs `SECURITY DEFINER` não são cobertas por RLS

`aprovar_orcamento_financeiro`, `criar_produto_orcamento`, `cancelar_pedido_compra`,
`criar_pedido_compra_lote`, `registrar_devolucao_projeto_item*`, `atualizar_preco_custo_produto`
etc. rodam com privilégio elevado e ignoram RLS da tabela por completo. O bloqueio para essas
precisa ser um `IF NOT hub_pode_executar(...) THEN RAISE EXCEPTION` **dentro do corpo da função**,
não uma policy de tabela.

### Tabelas compartilhadas entre sistemas

`produtos`, `contatos` e `projetos` são escritos por mais de um sistema (ex.: Cadastro e Orçamentos
os dois criam produto). A policy de uma tabela compartilhada não pode ficar amarrada a um único
slug — precisa ser o OR entre os slugs que legitimamente escrevem aquela tabela para a ação pedida.
Exemplo aplicado nesta matriz: INSERT direto em `produtos` (usado só pelo app Cadastro) exige
`hub_pode_executar(uid,'cadastro',null,'criar')`; o guard dentro de `criar_produto_orcamento` (RPC
chamada pelo app Orçamentos) exige `hub_pode_executar(uid,'orcamentos',null,'criar') OR
hub_pode_executar(uid,'cadastro',null,'criar')`.

As policies `anon_insert_orcamentos`/`anon_can_read_orcamento_by_token` (fluxo de aprovação do
cliente por link/token, SPEC-009) **não fazem parte deste RBAC interno** e não devem ser tocadas.

### Critérios de aceite

- Um usuário só com papel `equipe_entrega` autenticado, chamando a API do Supabase diretamente
  (sem passar pela UI), consegue `SELECT` em `orcamentos` mas recebe erro de RLS ao tentar `INSERT`
  ou `UPDATE`.
- Um usuário só com papel `equipe_projetos` chamando `criar_produto_orcamento` diretamente via
  `supabase.rpc(...)` recebe exceção e nenhum produto é criado; o mesmo usuário consegue `UPDATE`
  em um produto existente.
- Lana (papel `rh_administracao`) abrindo o CRM direto pela URL vê "Acesso negado" sem nenhum dado
  de projeto/cliente carregado.
- Vinícius (`admin_geral`) continua com acesso total em todos os sistemas, sem regressão.
- O Hub permite a um admin criar um papel novo com nível "Editar (sem cadastrar)" em um sistema sem
  precisar cadastrar módulo algum.

### Verificações obrigatórias (sem suíte automatizada)

- Lint/build de cada sistema tocado.
- `SELECT` de conferência em `papel_permissoes`/`usuario_papeis` batendo com a matriz acima.
- Teste manual golden-path logado como cada um dos 6 papéis, em cada sistema tocado.
- Tentativa manual de escrita direta (via `supabase-js`/`curl` com o JWT de um usuário de teste por
  papel) contra pelo menos uma tabela por sistema restrito, confirmando erro de RLS.

## Realizado

### 2026-08-06

- Migration `20260806_084_spec069_rbac_matriz_perfis` aplicada no Supabase real: 6 papéis criados,
  44 linhas de `papel_permissoes` (9 sistemas resolvidos), ação `aprovar` adicionada ao CHECK de
  `papel_permissoes`/`modulo_acoes`, `usuario_papeis` atribuído a Vinícius/Lana/Débora/Mariane.
- P1 resolvida: slug de Necessidade de Compra confirmado `necessidade-de-compra`.
- **Achado crítico descoberto ao conferir o seed**: Lana e Mariane tinham papel legado `gerente`
  (TOTAL em vários sistemas que deveriam ser SEM ACESSO para elas) atribuído, que neutralizaria
  qualquer RLS/RPC guard baseado em `hub_pode_executar` para essas duas. Investiguei o código real
  da SPEC-031 e confirmei que a aprovação de equipe da Mariane em Orçamentos depende de
  `usuarios.role` diretamente, não da tabela nova — usuário confirmou, papel `gerente` removido de
  ambas via `DELETE` em `usuario_papeis`. Sem impacto na aprovação de equipe.
- Carol: usuário forneceu o e-mail (`caroline@lucenera.com.br`) na mesma sessão. Conta criada via
  RPC `criar_usuario` (mesma da tela "Novo Usuário" da Central), atribuída ao papel
  `administracao_comercial`. Senha temporária gerada e comunicada ao usuário fora deste documento.
- **RLS endurecido e aplicado** em `boletos`/`notas_fiscais`/`remessas`/`contas_bancarias`
  (Administração Bancária) e `funcionarios_novo` (RH) — migration
  `20260806_085_spec069_rls_financeiro_rh`. Testado com `hub_pode_executar` direto: Vinícius vê
  financeiro, Lana vê RH, Mariane não vê nenhum dos dois.
- **Guards de RPC aplicados** em `criar_produto_orcamento` (camada extra sobre o role legado
  existente) e `aprovar_orcamento_financeiro` (não tinha nenhuma checagem antes) — migration
  `20260806_086_spec069_rpc_guards_orcamentos`.
- **Achado do usuário confirmado e corrigido**: `produtos` tinha o mesmo padrão de
  `contas_bancarias` (policy restrita neutralizada por `USING/WITH CHECK (true)` concorrente) —
  cadastro de produto pelo Cadastro (fora do fluxo de Orçamento) ainda não estava travado. Migration
  `20260806_087_spec069_rls_produtos` aplicada e testada: Vinícius/Carol criam produto, Mariane
  edita mas não cria.
- **Commitado no git** (repo central, local, sem push ainda): `.gitmodules` + submodule
  `lucenera-power-point`, `CHANGELOG.md`, os dois arquivos de SPEC, e as 5 migrations desta sessão
  (083 a 087).
- Repositório `Lucenera-Power-point` (Ficha Técnica) clonado como submodule
  `04-Sistemas/lucenera-power-point` (`git submodule add -f`, ainda não commitado). Achado: é um
  app Python/Flask com integração SharePoint, não um app React/Supabase como os outros 10 sistemas
  — sem `link` de produção confirmado e sem nenhum código que consulte `hub_pode_executar`. Não
  criei linha em `systems` nem `papel_permissoes` para ele — ver P6 atualizada.
- **Não iniciado nesta sessão**: extensão do `RolesTab.tsx` do Hub (task 12) e adoção frontend por
  sistema — telas escondendo botões conforme papel (task 13, 10 sistemas). RLS de `crm`/
  `orcamentos`/`cadastro`/`logistica`/`compras` (tabelas compartilhadas) também não iniciado.

### 2026-08-10

- **RLS estendido e aplicado** (migration `20260810_091_spec069_rls_shared_tables`): `projetos`,
  `contatos` (split cliente/arquiteto vs fornecedor — usuário aprovou explicitamente: "se for
  melhor separar os fornecedores por mim tudo bem"), `orcamentos`, `orcamento_itens`,
  `separacoes` (incluindo o sistema novo `separacao-parcial` da SPEC-072), `solicitacoes_compra`,
  `pedido_compra_itens`, `cotacoes_compra`. Guards de RPC em 4 funções de Compras. Testado com RLS
  real via `SET ROLE authenticated` (não só `SUPABASE_DB_URL`/service role): Lana bloqueada,
  Vinícius passa.
- **`RolesTab.tsx` do Hub estendido**: seletor de 5 níveis por papel×sistema, publicado.
- **Adoção frontend concluída nos 7 sistemas restantes** (RH, CRM, Cadastro, Orçamentos,
  Necessidade de Compra, Administração Bancária, Sistema de Entregas): `hasAccess` via
  `hub_pode_executar` + tela "Acesso negado", todos publicados no Skip com QA completo.
- **Decisões do usuário nesta sessão**: P6 (Ficha Técnica) — pular por agora, confirmado
  explicitamente. P3/P4 (filtro por linha) — adiado por agora (equipe_entrega vê todos os
  orçamentos, não só os que vai entregar); usuário adicionou que Equipe de Entrega também deve
  enxergar o sistema de Separação Parcial (já coberto — mesmo conjunto de papéis grantado em
  `logistica` e `separacao-parcial`, SPEC-072).
- **Não feito**: botões granulares de "Novo Produto" (Cadastro) e "Novo Orçamento" (Orçamentos)
  escondidos por papel — o RLS já bloqueia a escrita de verdade, essa é só uma melhoria de UX.
  Reextração de `supabase/db/current/` e atualização de `hub_ti.md`/`AI_DB_CONTEXT.md` também
  ficaram pendentes.

### 2026-08-10 (continuação — Dashboard Financeiro restrito a 3 pessoas)

- Usuário pediu que só Filippo, Pedro (`pedro@lucenera.com.br`, confirmado pelo usuário — existe
  também `pedrollaghi@gmail.com`, que fica de fora) e Vinícius tenham acesso ao Dashboard
  Financeiro, e reportou que "atualmente ninguém está conseguindo acesso".
- **Causa raiz confirmada**: o gating (`hasAccess` via `hub_pode_executar`) já estava certo desde
  a SPEC-063; só existia UMA linha em `papel_permissoes` para `dashboard-financeiro` — papel
  `admin_geral` (só o Vinícius tem). Filippo e Pedro tinham o campo legado `usuarios.role = 'admin'`
  (não usado por `hub_pode_executar`) mas zero linhas em `usuario_papeis` (RBAC novo) — por isso
  caíam direto em "Acesso negado".
- **Migration `20260810_094_dashboard_financeiro_acesso_restrito`**: papel novo e dedicado
  `dashboard_financeiro_acesso` (TOTAL só neste sistema, mesmo padrão de `rh_administracao`),
  atribuído aos 3 via `usuario_papeis`. Verificado com `hub_pode_executar` real: exatamente 3 dos
  11 usuários cadastrados têm acesso após a mudança; nenhum outro papel (legado ou novo) concede
  `dashboard-financeiro`.
- **"Campo para administrar dentro da Central" já existe** — não precisou construir nada novo: aba
  "Matriz de Acesso" (`AccessTab.tsx`, `/admin` → Matriz de Acesso) já deixa selecionar um usuário e
  marcar/desmarcar papéis via checkbox, incluindo o papel novo. Usuário só precisa saber que já
  existe.

### 2026-08-10 (continuação — bug de SSO da Central: clique em qualquer sistema "bugava" e voltava)

- Usuário reportou: depois de logar na Central, clicar em qualquer um dos 8 sistemas satélite
  "bugava" e o levava de volta para a Central (na prática, a aba nova ficava presa numa tela de
  login em vez de autenticar).
- **Reproduzido ao vivo** com usuário de teste descartável (criado e depois apagado, sem resíduo):
  clique em "Administração Bancária" abriu a aba com `?sso_code=...`, o código foi consumido (some
  da URL), mas a tela final mostrada foi a de login — nunca autenticou de fato.
- **Causa raiz, dois bugs diferentes, mesmo sintoma**, ambos pré-existentes (nenhum dos dois foi
  introduzido nesta sessão):
  - **5 sistemas nunca implementavam o consumo do SSO** (`consumeCodeFromUrl` não existia:
    Dashboard Financeiro, Cadastro, Necessidade de Compra, Sistema de Entregas, Separação Parcial)
    — o `?sso_code` chegava na URL e ninguém tentava trocá-lo por uma sessão; usuário caía direto
    na tela de login do sistema.
  - **3 sistemas tinham o consumo mas com race condition** (Administração Bancária, CRM,
    Orçamentos): `supabase.auth.onAuthStateChange` dispara um evento inicial com a sessão que já
    existia ANTES do `consumeCodeFromUrl` terminar de trocar o código (tipicamente nula, numa aba
    nova) — esse evento resolvia `loading = false` direto, e o `ProtectedRoute` interpretava
    "carregamento terminou + sem usuário" como não autenticado e mandava pra tela de login antes da
    troca real terminar. Confirmado via chamada direta às Edge Functions
    (`generate-cross-system-code`/`exchange-cross-system-code`) que a troca em si funcionava
    perfeitamente no servidor — o bug era 100% frontend, na corrida entre os dois efeitos.
- **Correção**: criado `src/lib/cross-system-auth.ts` nos 5 sistemas que não tinham; nos 8, a
  resolução de `loading`/sessão passou a esperar o `consumeCodeFromUrl` + `getSession()`
  terminarem antes de resolver — eventos de auth state anteriores a isso são ignorados (variável
  `initialized`/`initializedRef` conforme a complexidade de cada arquivo; Orçamentos tinha um
  segundo efeito acoplado para `role`/`canApproveQuotes`, tratado à parte). QA completo
  (setup/staticAnalysis/build/integrations/test) limpo nos 8, publicado em produção e sincronizado
  com o GitHub de cada submodule.
- Login direto (sem vir da Central) não é afetado — o efeito de auth state continua reagindo
  normalmente a login/logout manual, só não resolve mais o carregamento inicial antes da hora.

## Pendências

- [x] ~~Papel legado `gerente` conflitando com a matriz nova~~ resolvido — removido de Lana/Mariane,
      confirmado sem efeito na aprovação de equipe de Orçamentos.
- [x] ~~P1 — Slug real de Necessidade de Compra~~ resolvido: `necessidade-de-compra`.
- [ ] P2 — Nomes definitivos dos 6 papéis em `papeis.nome` (usei `admin_geral`, `rh_administracao`,
      `administracao_comercial`, `compras_e_entregas`, `equipe_projetos`, `equipe_entrega` como
      provisórios, já aplicados no banco — renomear depois é um `UPDATE papeis SET nome = ...`
      simples caso o usuário prefira outros nomes).
- [ ] P3 — **Adiado, confirmado pelo usuário (2026-08-10)**: "Equipe de Entrega: Orçamentos
      CONSULTAR" continua liberando ver TODOS os orçamentos, não só os da entrega da pessoa —
      filtro por linha (ex.: via `entregas.responsavel_id`) fica para uma SPEC incremental futura,
      não bloqueia o restante desta SPEC. O usuário confirmou à parte que Equipe de Entrega deve
      também ter acesso ao sistema novo de Separação Parcial (SPEC-072) — já coberto, mesmo
      conjunto de papéis grantado em `logistica` e `separacao-parcial`.
- [x] ~~P4~~ resolvida (2026-08-10): usuário aprovou explicitamente separar `contatos` por tipo
      ("se for melhor separar os fornecedores por mim tudo bem") — `CASE WHEN tipo = 'fornecedor'`
      aplicado na migration `20260810_091_spec069_rls_shared_tables` (fornecedor via
      `necessidade-de-compra`/`cadastro`, demais tipos via `crm`).
- [x] ~~P5 — Guard de `aprovar_orcamento_financeiro`~~ resolvido: usuário confirmou Administrador
      Geral + Carol (`administracao_comercial`, ação `aprovar`) — guard aplicado no Supabase real.
- [ ] P6 — **Confirmado pelo usuário (2026-08-10): pular por agora.** É o repositório
      `https://github.com/pedrolalala/Lucenera-Power-point.git` (clonado como submodule
      `04-Sistemas/lucenera-power-point`), mas **não é um app React/Supabase como os outros 10** —
      é uma aplicação **Python/Flask** ("Gerador de Fichas Técnicas PowerPoint",
      `app.py`/`app_production.py`), integrada ao Microsoft SharePoint via Graph API, sem
      `package.json`, sem cliente Supabase, sem login via `usuarios`/`auth.users`, sem `link` de
      produção confirmado (deploy via Cloudflared, não Skip). Continua fora do lote de
      seed/adoção — nenhuma linha em `public.systems` nem `papel_permissoes` para ele. Quando
      for retomado, alguém precisa: (1) confirmar a URL de produção real; (2) decidir como um app
      Flask externo vai validar permissão contra o Supabase (endpoint próprio? token
      compartilhado? SSO com o Hub?) — trabalho de integração novo, à parte.
- [ ] P7 — Granularidade dentro dos apps de Compras e Cadastro: "Necessidade de Compra" e "Consulta
      de Produtos" são nomeados no pedido como se fossem sistemas isolados, mas os apps reais
      (`compras-lucenera-3o23t98ee`, `cadastro-lucenera-b86fe`) cobrem mais telas (Marcas, Pedidos,
      Solicitações, Entrada de NF no caso de Compras; fornecedores/marcas/categorias no caso de
      Cadastro). O nível concedido nesta v1 vale para o sistema inteiro (nenhum módulo está
      cadastrado) — se o negócio quiser restringir só a uma tela específica dentro do app, é preciso
      cadastrar `modulos`/`modulo_acoes` para esse sistema primeiro, fora do escopo desta v1 a menos
      que confirmado.
