---
titulo: "SPEC-196 — Segurança dos dados financeiros (quem pode ler e alterar o financeiro direto no banco)"
status: Fases 0, 1, 2a e 2b APLICADAS (11/10)
data_ultima_modificacao: 2026-10-11
origem: "achado durante a SPEC-195 F2 (11/10/2026) + pedido do usuário"
sistemas_envolvidos:
  - Supabase Ohio (vcvcwzmbiftcawncibke) — tabelas e views financeiras, políticas RLS e grants
  - Administração Bancária (retorno-bancario-bradesco-5392a)
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3, Skip 41135)
  - RH Lucenera (dashboard-rh-lucenera-5fe9c)
  - Orçamentos, CRM, Separação Parcial, Vendas (leem parcelas/boletos/notas)
  - Edge Functions (usam service_role — não são afetadas)
  - scripts/ (conexão direta postgres — não são afetados)
relacionadas: [SPEC-069, SPEC-183, SPEC-195]
---

# SPEC-196 — Segurança dos dados financeiros

## Por quê

As telas escondem o que cada um não pode ver, mas o **banco não esconde**. Todo site do sistema leva dentro uma chave
pública (a "anon key") — é normal, desde que o banco faça a proteção (RLS). Hoje, para o financeiro, ele não faz:
qualquer pessoa com essa chave, ou com qualquer login (inclusive os 5 auxiliares de estoque criados em 11/10), consegue
ler — e em várias tabelas **alterar** — o financeiro inteiro chamando o banco direto, sem passar por tela nenhuma.

Também anula a decisão da SPEC-195 F2: a Distribuição de Lucro que tiramos do Dashboard continua legível por
`vw_transacoes_completas`, sem login.

## O que foi medido (11/10, só leitura, tudo em ROLLBACK)

Teste real como **visitante sem login** (`anon`) e como **auxiliar de estoque** (João Gabriel, papel `estoque`):

| Tabela / view | Sem login lê | Auxiliar lê | Auxiliar consegue alterar |
|---|---:|---:|:---:|
| `staging_conta_pagar` (contas a pagar Connect) | **13.863** | 13.863 | — |
| `staging_conta_receber` | **4.357** | 4.357 | — |
| `stg_duplicatas_vigentes` | **9.946** | 9.946 | — |
| `vw_transacoes_completas` (inclui retiradas de lucro) | **22.649** | 22.649 | — |
| `vw_conferencia_financeira` | **22.649** | 22.649 | — |
| `vw_financeiro_projetos` | **4.119** | 4.119 | — |
| `transacoes` | 0 | 22.649 | **sim** |
| `negociacoes` | 0 | 13.687 | (política `write = true`) |
| `projeto_parcelas` | 0 | 410 | **sim** |
| `folha_pagamento` (salários) | 0 | 32 (**só a própria folha** — correção 11/10) | não |
| `funcionarios_financeiro` (dados bancários/salário) | 0 | 27 | **sim** |
| `plano_de_contas` | 0 | 159 | (política `write = true`) |
| `projeto_parcelas_backup_migration` | 0 | 4.742 | — |
| `boletos`, `contas_bancarias`, `notas_fiscais`, `remessas` | 0 | 0 | não — **já protegidas** (SPEC-069) |

Causas:
1. As 3 tabelas `staging_*`/`stg_*` estão **sem RLS** e com permissão para `anon`.
2. As views `vw_transacoes_completas`, `vw_conferencia_financeira`, `vw_financeiro_projetos` pertencem ao `postgres`
   (pulam o RLS das tabelas de baixo) e têm permissão para `anon`.
3. Várias tabelas têm políticas antigas `USING (true)` para qualquer logado (ex.: `authenticated_all_transacoes`,
   `negociacoes_write`, `plano_contas_write`, `fn_fin_*_auth`), que anulam as políticas boas que existem do lado —
   no Postgres basta **uma** política permissiva liberar.

Quem usa cada coisa (conferido no código em 11/10):
- `staging_*`, `stg_duplicatas_vigentes`, `vw_transacoes_completas`, `vw_conferencia_financeira`,
  `vw_financeiro_projetos`: **nenhuma tela**. Só scripts (conexão direta) e Edge Functions (service_role).
- `transacoes`/`negociacoes`/`plano_de_contas`: Administração Bancária (duplicatas, baixa, contas em aberto), Dashboard
  (Transações), views do Dashboard.
- `projeto_parcelas`: CRM (projetos), Orçamentos, Adm. Bancária. `boletos`: Separação Parcial, Adm. Bancária.
- `folha_pagamento`/`funcionarios_financeiro`: só o RH (que só Lana, Vinícius, Filippo e Pedro acessam).

## Plano

### Fase 0 — fechar o que está aberto sem login (URGENTE, risco baixo)

Nenhuma tela lê esses objetos, então nada quebra para o usuário.
- [x] **0.1** `staging_conta_pagar`, `staging_conta_receber`, `stg_duplicatas_vigentes`: ligar RLS **sem política**
  (só scripts/postgres e service_role leem) e `REVOKE ALL ... FROM anon, authenticated`.
- [x] **0.2** `vw_transacoes_completas`, `vw_conferencia_financeira`, `vw_financeiro_projetos`: `REVOKE ALL ... FROM
  anon, authenticated` (scripts e Edge Functions continuam).
- [x] **0.3** `REVOKE ALL FROM anon` em **todas** as tabelas/views financeiras listadas acima (hoje o RLS segura, mas
  qualquer política nova mal escrita reabre). Conferir antes que nenhuma página pública (aprovação de orçamento pelo
  cliente por token, site do showroom) lê alguma delas sem login.
- [x] **0.4** `projeto_parcelas_backup_migration` (cópia antiga, 4.742 linhas): fechar para `authenticated` ou apagar
  (pergunta 3).
- [x] **0.5** Teste: repetir a tabela acima — "sem login" tem que dar 0/negado em tudo.

### Fase 1 — financeiro só para quem tem o sistema liberado

Regra (mesma da SPEC-183: Acesso a Sistemas = o que a pessoa vê):
- **Ler** transações, negociações, plano de contas, contas bancárias, remessas, retornos: quem tem **Administração
  Bancária** ou **Dashboard Financeiro** liberado (+ admin).
- **Alterar**: só quem tem **Administração Bancária** com papel que permite editar (hoje
  `hub_pode_executar(..., 'financeiro', ..., 'editar')`), + admin. As RPCs de baixa/estorno continuam como estão.
- **Parcelas e boletos do projeto** (`projeto_parcelas`, `boletos`): ler também quem tem Orçamentos, CRM ou Separação
  Parcial (é o que essas telas mostram); alterar só pelas RPCs/Adm. Bancária.
- **Folha e dados financeiros de funcionário** (`folha_pagamento`, `funcionarios_financeiro`): só quem tem **RH
  Lucenera** liberado (Lana, Vinícius, Filippo, Pedro).
- **Distribuição de Lucro**: em `transacoes` e nas views, mesma regra da migration 196
  (`pode_ver_distribuicao_lucro()` — Filippo, Pedro, Vinícius).

Como:
- [x] **1.1** Função `pode_acessar_sistema(slug)` `SECURITY DEFINER STABLE` (admin ou `user_system_access`), usada nas
  políticas sempre como `(SELECT public.pode_acessar_sistema('...'))` — chamada por linha deixa tudo lento (já
  aconteceu: ver `reference_rls_hub_pode_executar_por_linha`).
- [x] **1.2** Apagar as políticas `USING (true)` duplicadas e deixar **uma** política por operação em cada tabela.
- [x] **1.3** Teste por perfil (como `authenticated`, em ROLLBACK), com uma pessoa de cada área: Lana (financeiro),
  Vinícius (admin), Débora (estoque/compras), Marina (projetos), João (auxiliar), Mariane. Conferir contagens e que
  cada tela continua abrindo: Adm. Bancária (todas as páginas), Dashboard (todas as abas), RH (Folha), CRM (projeto),
  Orçamentos (resumo financeiro), Separação Parcial (boletos), Vendas.
- [x] **1.4** Medir o tempo das telas antes/depois (Dashboard carrega ~17 mil linhas).
- [x] **1.5** Publicar nada de front, se possível (a mudança é só no banco). Se alguma tela quebrar, corrigir a tela,
  não reabrir a política.

### Fase 2 — revisão do resto (depois)

- [ ] **2.1** Outras tabelas com `USING (true)` fora do financeiro (`contatos`, `contato_tipos`, `contato_origens`,
  `categorias_financeiras`, `notas_fiscais_compra`, `recebimentos_compra`…): levantar e decidir uma a uma.
- [x] **2.2** Regra para o futuro no `AGENTS.md`: tabela nova sempre com RLS ligado, nunca `USING (true)` em dado
  financeiro/pessoal, view financeira nunca com grant para `anon`.

## Riscos

- Alguma tela pode estar lendo uma tabela financeira que o levantamento por código não pegou (ex.: código só no
  Skip). Por isso o teste 1.3 abre cada tela, e cada fase tem `rollback.sql`.
- Edge Functions e scripts usam service_role/postgres e **não** passam pelo RLS — não são afetados.

## Respostas do usuário (11/10)

1. Fase 0: aplicar já — feito.
2. **Dashboard Financeiro é só para Vinícius, Pedro e Filippo.** Por isso a Fase 1 não dá passe livre a "admin":
   vale só o que está liberado em Acesso a Sistemas (Pedro ganhou a linha do Dashboard, que faltava).
3. `projeto_parcelas_backup_migration`: **fica fechada como está** (não apagar).

## Realizado

### 11/10 — Fase 0 aplicada (aprovada pelo usuário)

- Migration `20261011_198_spec196_fase0_fechar_financeiro_sem_login` (rollback.sql gerado a partir dos grants reais
  de antes):
  - RLS ligado sem política em `staging_conta_pagar`, `staging_conta_receber`, `stg_duplicatas_vigentes`;
  - fechados para **sem login e logado** (nenhuma tela usa): os 3 staging, `vw_transacoes_completas`,
    `vw_conferencia_financeira`, `vw_financeiro_projetos`, `vw_staging_resumo`, `projeto_parcelas_backup_migration`
    (fechada, não apagada — pergunta 3 em aberto);
  - fechados só para **sem login**: 20 tabelas e 10 views financeiras, incluindo `vw_funcionarios_completo` (27
    funcionários) e `vw_comissao_mensal` (11), que também estavam abertas sem login (achadas no levantamento).
- Conferido antes de aplicar: nenhuma tela nem Edge Function lê os objetos fechados para logado; `generate-report`
  usa a chave anon + login do usuário, mas não lê nenhum deles.
- Conferido depois, **de fora** (API pública com a chave anon): todos os objetos acima → HTTP 401; o site público do
  Showroom (`vw_showroom_publico`) continua respondendo. Scripts com conexão direta continuam lendo o staging.
- Logado: nada mudou ainda (auxiliar continua lendo `transacoes`, `folha_pagamento` etc.) — é a Fase 1.

### 11/10 — Fase 1 APLICADA (aprovada pelo usuário; Kimberly não precisa mais de acesso)

Migration `20261011_199_spec196_fase1_financeiro_por_sistema` (rollback.sql recria as políticas e views de antes).
Função `pode_acessar_sistema(slug)` (Acesso a Sistemas; scripts/service_role passam). Achado no teste: a folha de
pagamento inteira (771) aparecia para quem é "gerente/admin" no cadastro de usuários (Mariane, Kimberly) — a Fase 1
passa a folha para **RH + a própria folha**.

Dry-run por perfil (antes → depois):

| Perfil | Transações | Parcelas | Folha | Dados fin. funcionários | Dashboard (v_financeiro) |
|---|---|---|---|---|---|
| Lana (Adm. Bancária, RH) | 22.649 → 22.649 | 410 → 410 | 771 → 771 | 27 → 27 | 17.476 → **0** (não tem Dashboard) |
| Vinícius / Pedro / Filippo | igual | igual | igual | igual | igual |
| Marina, Mariane (Projetos/CRM) | 22.649 → **0** | 410 → 410 | própria | 27 → **0** | → **0** |
| Débora (Estoque/Compras) | → **0** | 410 → 410 (só ler) | própria | → **0** | → **0** |
| João (auxiliar) | → **0** | 410 → 410 (só ler) | própria | → **0** | → **0** |
| Kimberly (adapta.org) | → **0** | → **0** | 771 → **0** | → **0** | → **0** |

Tempo: v_financeiro_realizado 0,29–0,30 s antes e depois (sem perda). Boletos/contas bancárias/remessas não mudam
(já protegidos pela SPEC-069).

Conferido depois de aplicar, com **login real** do João (auxiliar) pela API: transações 0, negociações 0, dados
financeiros de funcionários 0, Dashboard 0, views de funcionários/comissão 0, staging 403; parcelas 410 (só leitura,
Separação Parcial); folha 32 (só a própria). Nenhuma tela foi republicada (mudança só no banco).

Pendente: Lana abrir as telas da Administração Bancária e do RH na segunda (o teste por perfil deu acesso igual ao de
antes, mas vale a conferência na tela) e decidir se o login da Kimberly deve ser bloqueado de vez.

- 11/10: **login da Kimberly (kimberly@adapta.org) bloqueado** a pedido do usuário — ban no Supabase Auth (até 2126,
  pela API de admin) + `usuarios.ativo = false`. Cadastro e papéis mantidos; para reativar: tirar o ban
  (`ban_duration: "none"`) e voltar `ativo = true`.

### 11/10 — Fase 2a APLICADA (aprovada pelo usuário: "pode fazer a Fase 2")

Varredura dos 196 objetos do banco como sem login e como auxiliar. Achados além do financeiro: `funcionarios` com RLS
**desligado** (36 cadastros legíveis — e alteráveis — sem login), `vw_historico_faltas` (95), backups do RH
`_bkp_*` (faltas 137, férias 12) e de acessos, auditoria (`logs_auditoria`), projetos dos clientes
(`vw_projetos_*`, até 4.119), orçamentos com token (política `anon_can_read_orcamento_by_token`), catálogo/vendas
Ubiqua, estoque — tudo sem login. Com login: auxiliar alterava `estoque_itens`, `funcionarios`,
`funcionarios_detalhes/beneficios` e `user_roles_separacao` (permissões da Separação).

Migration `20261011_200_spec196_fase2_sem_login_e_rh` (rollback.sql com grants/políticas/RLS de antes):
- `REVOKE ALL FROM anon` em **146 objetos** — sobra só o site público do Showroom (`vw_showroom_publico`,
  `showroom_import_pecas`). A aprovação do orçamento pelo cliente usa RPCs `SECURITY DEFINER`
  (`buscar_orcamento_para_aprovacao`, `aprovar_/recusar_orcamento_cliente_publico`) e continua funcionando;
- RLS ligado em `funcionarios` (as políticas por papel que já existiam passam a valer), backups `_bkp_*` e staging de
  import; backups e staging sem uso fechados também para logado; `staging_pedido_compra` só Dashboard;
- `funcionarios_detalhes` e `funcionarios_beneficios_empresas`: só RH; `user_roles_separacao`: só admin grava;
  `estoque_itens`: some a escrita aberta (ficam as regras por papel admin/gerente/operador).
- Conferido de fora (API pública): tudo 401, Showroom 200, RPC de aprovação responde normalmente. Logado: Lana,
  Vinícius e Mariane iguais; auxiliar não altera mais funcionários/estoque/permissões.
- Regra para o futuro gravada no `AGENTS.md` ("Segurança do banco").

### Fase 2b — APLICADA em 11/10 (ver abaixo); lista original

- `orcamentos`: a política `anon_can_read_orcamento_by_token` também deixa **qualquer logado** ver todo orçamento com
  token, e `anon_insert_orcamentos` deixa inserir sem regra — trocar pelas regras do Hub (SPEC-069).
- Tabelas com escrita aberta a qualquer logado, usadas pela Logística/Separação/Garantia: `separacoes`,
  `separacao_arquivos`, `entregas_pendentes`, `entregas_finalizadas`, `garantia_itens`, `garantia_protocolos`,
  `projetos_fechados`, `historico_status_orcamentos`, `contato_tipos`, `empresas`, `quotes`/Ubiqua.
- `contatos` (clientes, CPF/CNPJ, telefones) legível por qualquer logado — decidir quem precisa.
- Supabase continua dando grant a `anon` em tabela NOVA por padrão (regra no AGENTS.md cobre).

### 11/10 — Fase 2b APLICADA (aprovada pelo usuário)

Migration `20261011_201_spec196_fase2b_operacional_por_sistema` (rollback.sql recria as políticas de antes). Função
`pode_acessar_algum(slugs[])` = admin ativo **ou** algum dos sistemas em Acesso a Sistemas (scripts/service_role passam).
- `orcamentos` e `historico_status_orcamentos`: só quem tem algum sistema interno (saem as políticas `USING (true)` e as
  de `anon`). **Fecha a leitura dos orçamentos da Lucenera pelos representantes Ubiqua** e por contas sem sistema.
  O histórico deixa de poder ser editado (só inserir).
- `separacoes` (leitura), `separacao_arquivos`, `entregas_pendentes`, `entregas_finalizadas`: Logística ou Separação
  Parcial. `garantia_itens`/`garantia_protocolos`: Controle de Garantia.
- `projetos_fechados`: RH/CRM/financeiro/Dashboard leem; RH ou admin gravam.
- `contato_tipos`: grava quem cadastra contato (Orçamentos, CRM, Compras, Adm. Bancária, Cadastro).
- `empresas`: todos leem; só admin altera.
- `contatos`: **mantido** legível por qualquer logado (9 sistemas usam); gravação já era por papel/Hub.

Dry-run por perfil: Vinícius, Lana, Marina, Débora, João, Matheus iguais nas telas que usam; João/Matheus perdem a
Garantia (não têm o sistema); só admin altera empresas; conta sem sistema (Moara) → 0. Conferido depois com **login
real** do João: orçamentos 20, separações 441, entregas 2, garantia 0, projetos fechados 0. Contas sem sistema
(erp.lucenera@gmail.com, marianelighting@outlook.com, vinicius_bortolin@hotmail.com, moara@) continuam vendo o catálogo
Ubiqua (produtos 74, revendas 87, orçamentos Ubiqua 23) e veem 0 orçamentos Lucenera.

Fica para depois (anotado): tabelas Ubiqua (`orcamentos_revenda_ubiqua`, `revenda_ubiqua`, `quotes`) — cada
representante vê os orçamentos/revendas de todos os outros; gatilhos `propagate_contato_nome`/`propagate_projeto_codigo`
rodam com a permissão de quem edita o contato/projeto (já não atualizavam a separação de quem não tem Logística — era
assim antes).
