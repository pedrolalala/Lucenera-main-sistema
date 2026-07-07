# Adendo de Atualizacao - 03/07/2026

Este adendo cobre o periodo de 26/06/2026 a 03/07/2026 (semana de 26/06, uma sexta-feira, ate 03/07/2026). Foi produzido a partir de `git log` dos 8 repositorios de sistema e do repositorio central no GitHub (origin/main), leitura direta das migrations aplicadas ao Supabase e conferencia cruzada com `00_TASKS_GERAIS_ECOSSISTEMA.md` e os Escopos por sistema. Atualiza a pasta `03-Projeto` com o que foi implementado, corrigido e evoluido nessa janela.

## 1. Visao geral do periodo

76 commits relevantes (descontado ruido de auto-sync e bump de versao) em 6 sistemas com atividade. Orcamentos concentrou 29 deles. Gestao Financeira nao teve nenhum commit — segue nao publicado.

| Sistema | Commits relevantes | Destaque principal |
|---|---|---|
| Orcamentos (`gestao-financeira-clone-544cb`) | 29 | Fluxo de aprovacao financeira dedicado, configuracao de alcadas, selecao multi-produto |
| Cadastro (`cadastro-lucenera-b86fe`) | 13 | Catalogo/estoque avancado; modulos de Clientes e Projetos removidos da navegacao |
| Logistica (`lucenera-logistics-b7cd1`) | 12 | Dashboard de separacao/entrega; correcao de bug de enum no calendario; RLS nova |
| CRM (`lucenera-crm-3bd29`) | 10 | Login proprio via Supabase Auth; FK `responsavel_obra_id` em `projetos` |
| Hub / Central (`central-lucenera-dashboard-1c9ba`) | 7 | Painel administrativo; RLS em `systems`/`usuarios`; rebranding |
| RH (`dashboard-rh-lucenera-5fe9c`) | 4 | View `vw_funcionarios_completo`; RLS ligada pela primeira vez |
| Gestao Financeira (`retorno-bancario-bradesco-5392a`) | 0 | Nenhuma atividade — segue bloqueando o redirecionamento pos-aprovacao de boleto (ORC-05) |

## 2. Banco de dados central — 7 novos grupos de migration

Aplicados em `supabase/db/migrations/` entre 30/06 e 02/07. E o desenvolvimento mais estrutural do periodo: pela primeira vez existe reserva de estoque ligada a aprovacao do orcamento.

- **20260630_010 — Reserva de estoque na aprovacao.** Remove o trigger legado `trg_reserva_estoque` (disparava no evento errado — mudanca de status do projeto, nao aprovacao do orcamento). A propria funcao `aprovar_orcamento_financeiro_base_spec001` passa a incrementar `estoque_itens.quantidade_reservada` para cada item com produto vinculado, uma unica vez, de forma idempotente. Estoque negativo e permitido de proposito (venda futura). Itens sem `produto_id` sao ignorados. Pendencia registrada no proprio README da migration: falta rastreabilidade por item de projeto — hoje `quantidade_reservada` e um contador total por produto. Nota de 06/07/2026: a ideia inicial de `estoque_reservas` foi substituida pela SPEC-010, com `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item` por `projeto_item_id`.
- **20260630_011 — FK `equipes_projetos` → `funcionarios_financeiro`.** Formaliza com chave estrangeira um vinculo que existia como coluna solta.
- **20260630_012 — Comissao por equipe.** Adiciona `equipe_id` a `projetos`, cria trigger que vincula a equipe automaticamente pelo nome do responsavel, e a view `vw_comissao_mensal` (percentual da equipe x valor total dos projetos do mes).
- **20260701_013 — Fix de cast em `gerenciar_fluxo_projeto()`.** Comparacao com o literal `'Aprovado'` quebrava com erro de enum e bloqueava qualquer `UPDATE` de status no banco. Os ramos afetados sao codigo morto desde a SPEC-005 (aprovacao real ja nao passa por trigger), mas o erro de cast era real.
- **20260701_014 — Sincronizacao de codigo de produto.** Copia `codigo_legado` para `codigo_produto` onde este esta nulo (o frontend busca por `codigo_produto`; dados historicos so tinham o codigo legado do Connect).
- **20260702_015 — `cancelar_orcamento()`, primeira versao.** Se o orcamento estava aprovado, reverte a reserva de estoque e marca `status = 'cancelado'`, com historico. Idempotente.
- **20260702_016 — `cancelar_orcamento()` endurecida + fix em `trigger_fechar_projeto()`.** A versao da 015 revertia estoque mas deixava parcelas `pendente` e boletos `pendente_registro` orfaos, e itens aprovados continuavam `validado = true`. A versao nova cancela parcelas e boletos e desmarca a validacao dos itens, preservando tudo para auditoria (soft-cancel). Corrige tambem uma regressao real: `trigger_fechar_projeto()` reduzia estoque na linha `local='Reservado'` (sistema antigo) em vez de `quantidade_reservada` na linha `local='Estoque'` (sistema novo da migration 010) — a cada entrega finalizada, a reserva ficava inflada para sempre.

Fora do repositorio central, dois sistemas tambem versionaram migrations proprias: **CRM** adicionou `responsavel_obra_id` a `projetos`, com FK para `usuarios` (01/07); **Orcamentos** criou RLS para `logs_auditoria` junto com o fluxo de aprovacao financeira (03/07).

## 3. Orcamentos — o sistema mais ativo do periodo

- **Fluxo de aprovacao financeira** dedicado (`FinancialApprovalTab`, `FinancialApprovalDialog`), com auditoria em `logs_auditoria` (03/07).
- **Configuracao de alcadas de aprovacao** — tela `ApprovalSettings.tsx` (03/07).
- **Selecao multi-produto** — mais de dez commits entre 01/07 e 02/07 reescrevendo adicao em lote de itens, busca de catalogo e formatacao de codigo de circuito.
- SPEC-005 (26/06, Kimberly): remocao dos triggers legados que bloqueavam a aprovacao — ja registrada como concluida no checklist geral.

## 4. Demais sistemas

- **Cadastro**: catalogo avancado de pecas (filtro por marca/categoria, visao detalhada de estoque com priorizacao, busca por codigo de produto). Rotas `/clientes` e `/projetos` passaram a redirecionar para `/pecas` (30/06) — os dados nao foram apagados, so saíram do menu. Logo da empresa adicionado ao cabecalho (01/07).
- **CRM**: login proprio implementado via Supabase Auth (01/07). Correcao de schema formaliza o vinculo projeto-responsavel (`responsavel_obra_id`). Em 26/06, Kimberly removeu a reintroducao de `sync-fechamentos-automatica` por auto-sync e adicionou documentacao de contexto do banco em `supabase/`.
- **Logistica**: dashboard de separacao e entrega (cards com detalhe expandido, modal de finalizacao de entrega, upload de arquivos por separacao). Sete commits seguidos corrigindo o mesmo bug de enum divergente no calendario/filtro de status. RLS ligada pela primeira vez em `separacoes`, `separacao_arquivos` e `entregas_finalizadas`.
- **Hub / Central**: painel administrativo (`UsersTab`) e flag `ativo` em `systems` (29/06). RLS ligada em `systems` e `usuarios`, com policy `admin_all_*` checando `is_admin()` — mais restritiva que o padrao visto nos demais sistemas esta semana. Rebranding (logo Luce Nera, renomeacao de cards, modulo de RH renomeado para "RH Lucenera"). Nenhum commit toca modulos, papeis, acoes ou a RPC `hub_sistemas_permitidos` — a SPEC-006 (permissoes granulares) segue sem inicio.
- **RH**: view `vw_funcionarios_completo` criada juntando funcionario, detalhes, financeiro e beneficios. RLS ligada nas 4 tabelas de funcionario pela primeira vez.

## 5. Achado de seguranca (critico)

A mesma senha em texto plano (`Skip@Pass`) para o usuario `pedro@lucenera.com.br` foi commitada em **3 repositorios diferentes** via migration SQL (`crypt('Skip@Pass', gen_salt('bf'))` ou atualizacao direta de `auth.users.encrypted_password`):

- `lucenera-crm/supabase/migrations/20260701133912_seed_pedro_user_skip_pass.sql`
- `central-lucenera-dashboard/supabase/migrations/20260630174522_rename_cadastro_and_rls_policies.sql`
- `dashboard-rh-lucenera/supabase/migrations/20260629120922_vw_funcionarios_completo.sql`

Uma vez commitada e enviada ao GitHub, a senha deve ser tratada como exposta, independentemente de troca posterior — o historico do Git preserva o valor original. **Recomenda-se rotacionar a senha imediatamente.**

Achado relacionado, nao critico: **toda policy RLS nova criada esta semana usa `USING (true)`** para qualquer usuario autenticado, sem checar papel (excecao: Hub, que usa `is_admin()` para `systems`/`usuarios`). Reproduz, em codigo novo, o mesmo padrao que a pendencia critica 7 do checklist geral ja registrava como achado antigo. Ver secao 6 abaixo e a pendencia 7 atualizada em `00_TASKS_GERAIS_ECOSSISTEMA.md`.

Achado adicional de qualidade de dado: a mesma migration que ligou RLS no RH insere 4 funcionarios ficticios (Mariane Costa, Vinicius Santos, Tricia Almeida, Giovana Gonella) com CPF, RG, endereco e salario fabricados, condicionado a `funcionarios_novo` estar vazia — risco real de entrar como se fosse producao, contrariando o mesmo principio ja registrado para Cadastro (`CAD-08`, remocao de mocks residuais).

## 6. Decisoes que atualizam os documentos anteriores

- Onde o checklist geral registra `ORC-07` (integracao com Estoque/Compras) e `EST-05`/`EST-06` (recebimento e reserva) como pendentes, a leitura correta passa a ser **parcial**: existe reserva de estoque funcional ligada a aprovacao do orcamento (migration 010), mas implementada dentro de Orcamentos, nao no sistema de Estoque/Compras — que continua nao existindo. Fica pendencia de decisao: essa logica e a base do futuro Estoque/Compras (migra quando o sistema nascer) ou e uma ponte temporaria?
- `ORC-09` (cancelamento, aditivo e substituicao) passa de pendente para **parcial**: `cancelar_orcamento()` cobre cancelamento completo (estoque + parcelas + boletos + itens). Aditivo e substituicao seguem pendentes.
- `CRM-13` (projeto como cadastro unico) avanca com o FK `responsavel_obra_id`, mas o login proprio implementado no CRM esta em tensao com a `SPEC-HUB-05` (sessao unica via Hub/SSO) — o CRM deveria futuramente consumir a sessao central da `SPEC-007`, nao manter login proprio.
- `CAD-06` (projetos fora da responsabilidade do Cadastro) avanca: navegacao de Clientes/Projetos removida do Cadastro.
- `RH-05` (folha e integracao financeira) ganha avanco parcial inesperado: `vw_comissao_mensal` calcula comissao por equipe, mas nasceu no banco central, nao em um commit do sistema de RH — nenhum frontend consome a view ainda.
- Pendencia critica 7 (analise de seguranca do banco) e reforcada negativamente: as novas policies desta semana ja nascem permissivas, e ha agora um achado adicional de credencial exposta (secao 5 acima).
- `HUB-02`/`HUB-05` (SPEC-006/007) seguem sem nenhum avanco de codigo nesta janela.
