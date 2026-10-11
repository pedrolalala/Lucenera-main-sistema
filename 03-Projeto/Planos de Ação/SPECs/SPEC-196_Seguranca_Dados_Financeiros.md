---
titulo: "SPEC-196 — Segurança dos dados financeiros (quem pode ler e alterar o financeiro direto no banco)"
status: Fase 0 APLICADA (11/10); Fase 1 aguardando respostas 2 e 3
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
| `folha_pagamento` (salários) | 0 | **32** | não |
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
- [ ] **1.1** Função `pode_acessar_sistema(slug)` `SECURITY DEFINER STABLE` (admin ou `user_system_access`), usada nas
  políticas sempre como `(SELECT public.pode_acessar_sistema('...'))` — chamada por linha deixa tudo lento (já
  aconteceu: ver `reference_rls_hub_pode_executar_por_linha`).
- [ ] **1.2** Apagar as políticas `USING (true)` duplicadas e deixar **uma** política por operação em cada tabela.
- [ ] **1.3** Teste por perfil (como `authenticated`, em ROLLBACK), com uma pessoa de cada área: Lana (financeiro),
  Vinícius (admin), Débora (estoque/compras), Marina (projetos), João (auxiliar), Mariane. Conferir contagens e que
  cada tela continua abrindo: Adm. Bancária (todas as páginas), Dashboard (todas as abas), RH (Folha), CRM (projeto),
  Orçamentos (resumo financeiro), Separação Parcial (boletos), Vendas.
- [ ] **1.4** Medir o tempo das telas antes/depois (Dashboard carrega ~17 mil linhas).
- [ ] **1.5** Publicar nada de front, se possível (a mudança é só no banco). Se alguma tela quebrar, corrigir a tela,
  não reabrir a política.

### Fase 2 — revisão do resto (depois)

- [ ] **2.1** Outras tabelas com `USING (true)` fora do financeiro (`contatos`, `contato_tipos`, `contato_origens`,
  `categorias_financeiras`, `notas_fiscais_compra`, `recebimentos_compra`…): levantar e decidir uma a uma.
- [ ] **2.2** Regra para o futuro no `AGENTS.md`: tabela nova sempre com RLS ligado, nunca `USING (true)` em dado
  financeiro/pessoal, view financeira nunca com grant para `anon`.

## Riscos

- Alguma tela pode estar lendo uma tabela financeira que o levantamento por código não pegou (ex.: código só no
  Skip). Por isso o teste 1.3 abre cada tela, e cada fase tem `rollback.sql`.
- Edge Functions e scripts usam service_role/postgres e **não** passam pelo RLS — não são afetados.

## Perguntas abertas

1. Pode aplicar a **Fase 0 já** (risco baixo, nenhuma tela usa)? Recomendo sim, hoje.
2. Fase 1: quem tem **Dashboard Financeiro** pode ler as transações (somente leitura), ou só quem tem Adm. Bancária?
3. `projeto_parcelas_backup_migration`: apagar a tabela (é uma cópia de migração antiga) ou só fechar?

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
