---
titulo: "SPEC-064 — Perfil Ribeirão/São Paulo em CRM, RH, Orçamentos, Compras, Administração Bancária e Dashboard Financeiro"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - CRM (lucenera-crm)
  - RH (dashboard-rh-lucenera-5fe9c)
  - Orçamentos Lucenera (gestao-financeira-clone-544cb)
  - Necessidade de Compra (compras-lucenera-3o23t98ee)
  - Administração Bancária (retorno-bancario-bradesco-5392a)
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3)
---

# SPEC-064 — Perfil Ribeirão/São Paulo

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — Migration única (aditiva): `ADD COLUMN perfil text CHECK (perfil IN ('ribeirao','sao_paulo'))` (nullable, sem default) em `contatos`, `projetos`, `funcionarios`, `orcamentos`, `pedidos_compra`, `boletos`, `transacoes`. **Aplicada no Supabase real em 2026-08-05.**
- [x] Item 2 — CRM (`lucenera-crm`, Skip `projectId 24580`): campo "Perfil" no cadastro/edição de **cliente** (`contatos`) e de **projeto** (`projetos`), independentes um do outro, sem nenhuma lógica derivada. **Publicado em produção, versão `0.0.290`/`f1f98f0`.**
- [x] Item 3 — RH (`dashboard-rh-lucenera-5fe9c`, Skip `projectId 23919`): campo "Perfil" no cadastro/edição de funcionário. **Achado ao implementar**: RH tem 2 tabelas de funcionário — `funcionarios` (legada, Férias/Faltas) e `funcionarios_novo` (real, tela de Cadastro/`EmployeeForm.tsx`, via `vw_funcionarios_completo`). Migration complementar (`002_perfil_funcionarios_novo.sql`) adicionou a coluna também em `funcionarios_novo` e recriou a view. **Publicado em produção, versão `0.0.218`/`c742130`.**
- [x] Item 4 — Orçamentos Lucenera (`gestao-financeira-clone-544cb`, Skip `projectId 32554`): campo "Perfil" no orçamento (`orcamentos`), em `BudgetFormPage.tsx`. **Publicado em produção, versão `0.0.301`/`d55c64a`.**
- [x] Item 5 — Necessidade de Compra (`compras-lucenera-3o23t98ee`, Skip `projectId 40326`): campo "Perfil" manual na criação de pedido de compra (`pedidos_compra`) — `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade` ganham `p_perfil` opcional (migration `003_perfil_rpcs_pedido_compra.sql`, `DROP FUNCTION` antes de recriar). **Publicado em produção, versão `0.0.52`/`e616728`.**
- [x] Item 6 — Administração Bancária (`retorno-bancario-bradesco-5392a`, Skip `projectId 36395`): campo "Perfil" manual e editável em `boletos` (`Boletos.tsx`, criação e edição). **Publicado em produção, versão `0.0.55`/`87e9a2c`.**
- [x] Item 7 — Dashboard Financeiro (`dashboard-lucenera-b02z85wa3`, Skip `projectId 41135`): `transacoes` ganha `perfil` editável (nova tela `/transacoes`, `Transacoes.tsx` — lista até 300 lançamentos, filtro "só não classificadas", Select por linha, salva na hora); `v_financeiro_realizado` recriada expondo `perfil`; filtro "Ribeirão / São Paulo / Todos" em `ContasPagarFoco.tsx` e `ContasReceberFoco.tsx`. **Publicado em produção, versão `0.0.23`/`6cb8462`.**
- [x] Item 8 — Consultar Produtos, Sistema de Entregas e Fichas Técnicas: **fora de escopo** — decisão explícita do usuário (estoque só existe em Ribeirão; entrega e catálogo não precisam do campo).
- [x] Item 9 — Atualizar `supabase/db/domains/crm.md`, `rh.md`, `orcamentos.md`, `estoque_compras.md` com a coluna nova.
- [x] Item 10 — Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Classificar (uma vez, gradualmente) o perfil das `transacoes` já existentes na tela nova do Dashboard Financeiro — não há como inferir isso automaticamente do livro-caixa importado do Connect.
- [ ] Confirmar em cada sistema, após publicado, que o campo aparece e salva corretamente.

## Objetivo

A Lucenera está abrindo uma filial em São Paulo. Toda a operação financeira e de projetos continua sendo resolvida em Ribeirão Preto (não é uma nova empresa/CNPJ, não muda nenhuma regra de negócio) — mas o usuário precisa conseguir **visualizar** separadamente quanto entra e sai de dinheiro relacionado a São Paulo. Isso é puramente informativo: nenhuma regra de permissão, cálculo ou fluxo existente deve mudar de comportamento por causa do perfil.

## Decisões aprovadas

- **Perfil é só rótulo/visualização** — não influencia nenhuma lógica de negócio, cálculo, permissão ou fluxo existente (confirmado explicitamente pelo usuário). Nenhuma RPC de aprovação/cálculo é alterada além de aceitar e gravar o valor.
- **Sem herança/derivação automática** — cliente, projeto, orçamento, pedido de compra, boleto e transação têm cada um seu próprio campo `perfil`, preenchido manualmente, podendo divergir entre si (ex.: cliente sediado em SP com um projeto específico marcado como Ribeirão). Nenhuma tela deve calcular ou sobrescrever o perfil de uma entidade a partir de outra.
- **Campo fixo com 2 valores** (`'ribeirao' | 'sao_paulo'`), mesmo padrão já usado em `tipo_cliente`/`regime_apuracao` (texto + `CHECK`, sem enum novo, sem tabela de filiais). Se uma 3ª unidade abrir no futuro, é uma migration nova — aceito conscientemente pelo usuário em troca de simplicidade agora.
- **Consultar Produtos, Sistema de Entregas e Fichas Técnicas ficam de fora** — decisão explícita do usuário.
- **`transacoes` (livro-caixa importado do Connect, fonte real do Dashboard Financeiro) também precisa do campo**, com uma tela de classificação manual — sem isso, o filtro do dashboard nunca teria dado nenhum, porque o dashboard não lê `orcamentos`/`boletos`/`pedidos_compra` diretamente (ver "Achado crítico" abaixo).
- **Dashboard "novo" = filtro dentro do Dashboard Financeiro atual**, não um app duplicado — evita duplicar manutenção.

## Achado crítico (2026-08-05, muda o desenho do dashboard)

`ContasPagarFoco.tsx`/`ContasReceberFoco.tsx` do Dashboard Financeiro (`dashboard-lucenera-b02z85wa3`) leem `v_financeiro_realizado`, que é derivada de `transacoes` → `negociacoes` → `plano_de_contas` — **um livro-caixa importado do sistema legado Connect, sem nenhuma relação com `orcamentos`/`projetos`/`boletos`/`pedidos_compra`** (os dados "vivos" do ecossistema atual). `transacoes` já tem `empresa_id` (via `negociacoes`), mas as 4 `empresas` cadastradas são todas de Ribeirão Preto (entidades legais diferentes, não filiais geográficas) — não serve para representar "perfil".

Consequência: marcar cliente/projeto/orçamento/pedido/boleto com perfil **não** faz nada aparecer filtrado no dashboard atual, porque o dashboard nem olha para essas tabelas. Por isso o Item 7 inclui uma tela de classificação manual de `transacoes` — trabalho de classificação contínuo, sem forma de automatizar (não existe elo natural entre uma linha de `transacoes` e um cliente/projeto de São Paulo).

## Definição da SPEC — por sistema

### CRM (`contatos`, `projetos`)

- `contatos`: campo "Perfil" (Select Ribeirão/São Paulo, opcional) no formulário de cadastro/edição de cliente (mesmo padrão de `tipo_cliente`, SPEC-052 — `ClientFormFields.tsx`/`ContatoDetail.tsx` com `FieldType: 'select'`).
- `projetos`: campo "Perfil" no detalhe/edição do projeto (`ProjectDetail.tsx`), independente do perfil do cliente vinculado.
- Confirmar no código real do Skip (`projectId 24580`) os nomes de arquivo atuais antes de editar — não usar o submodule local como base (ver [[feedback_skip_deploy_separate_tree]]).

### RH (`funcionarios`)

- Campo "Perfil" no cadastro/edição de funcionário — local de admissão. Confirmar componente real (`EmployeeForm.tsx` ou equivalente) no Skip `projectId 23919` antes de editar.

### Orçamentos Lucenera (`orcamentos`)

- Campo "Perfil" no formulário/detalhe de orçamento. Confirmar componente real no Skip `projectId 32554` antes de editar.

### Necessidade de Compra (`pedidos_compra`)

- `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade`: novo parâmetro opcional `p_perfil text DEFAULT NULL` (mesmo padrão do `p_empresa_id` da SPEC-057/039 — `DROP FUNCTION` explícito antes de recriar, por causa da mecânica de overload do Postgres já documentada nessas SPECs).
- `ModalPedidoLote.tsx`/`ModalRegistrarCompra.tsx`: novo campo "Perfil" (opcional, sem trava — diferente de "Empresa", que é obrigatório).

### Administração Bancária (`boletos`)

- Campo "Perfil" editável na tela de boletos — confirmar componente real no Skip `projectId 36395` antes de editar (sistema ainda não explorado nesta sessão).

### Dashboard Financeiro (`transacoes`)

- Nova tela (ex. "Classificação de Transações" ou aba dentro de uma tela existente) listando `transacoes` (paginado) com Select de perfil por linha, gravando via nova RPC `atualizar_perfil_transacao(p_transacao_id, p_perfil)` (não há policy de `UPDATE` direta em `transacoes` hoje — confirmar e seguir o mesmo padrão RPC `SECURITY DEFINER` já usado em todo o ecossistema).
- `v_financeiro_realizado`: `CREATE OR REPLACE VIEW` incluindo `t.perfil`.
- `cash-flow.ts`: `FinanceiroRow` ganha `perfil: string | null`; nova função `filterByPerfil`.
- `ContasPagarFoco.tsx`/`ContasReceberFoco.tsx`: novo `Select` "Ribeirão / São Paulo / Todos", mesmo padrão dos filtros de Ano/Mês já existentes.

## Impacto no banco

- 7 `ALTER TABLE ... ADD COLUMN perfil text CHECK (...)` (aditivo, nullable, sem default — nenhum dado existente é afetado).
- `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade` recriadas com parâmetro novo (`DROP FUNCTION` antes, por causa do overload).
- RPC nova `atualizar_perfil_transacao`.
- `v_financeiro_realizado` recriada (`CREATE OR REPLACE VIEW`, só adiciona coluna).

## Impacto em telas

CRM (cliente + projeto), RH (funcionário), Orçamentos (orçamento), Necessidade de Compra (criação de pedido), Administração Bancária (boleto), Dashboard Financeiro (tela nova de classificação + filtro em 2 telas existentes). Consultar Produtos, Sistema de Entregas e Fichas Técnicas não mudam.

## Regras de permissão

Nenhuma nova — mesmo padrão de acesso já existente em cada sistema/RPC tocado.

## Análise obrigatória de ecossistema

- Depende de `contatos`, `projetos`, `orcamentos`, `pedidos_compra` — sim, todos ganham a coluna. `funcionarios`, `boletos`, `transacoes` também. Não depende de `usuarios`, `systems`, `user_system_access`.
- Afeta CRM, RH, Orçamentos, Estoque/Compras (Necessidade de Compra), Hub/TI (indiretamente, Administração Bancária) — não afeta Cadastro nem Logística.
- Nenhum dado duplicado — cada entidade tem seu próprio campo, deliberadamente sem sincronização (decisão aprovada).
- Nenhuma migration antiga contradiz esta — campo novo, nome sem colisão confirmado em todas as 7 tabelas.
- Exige atualizar `AI_DB_CONTEXT.md` dos sistemas tocados após implementar cada um.

## Critérios de aceite

- Cliente e projeto no CRM podem ter perfis diferentes entre si, ambos salvando corretamente.
- Funcionário, orçamento, pedido de compra e boleto ganham o campo, opcional, sem quebrar nenhum fluxo existente (criação/edição continuam funcionando sem preencher perfil).
- Dashboard Financeiro tem uma tela para classificar transações por perfil e um filtro Ribeirão/São Paulo/Todos nas 2 telas de Contas a Pagar/Receber, refletindo só as transações já classificadas.
- Nenhuma regra de aprovação, cálculo de saldo, permissão ou fluxo existente muda de comportamento.

## Testes/verificações obrigatórios

- QA pipeline do Skip (`skip_project_apply_changes`) precisa passar em cada sistema antes de publicar.
- Teste manual por sistema: salvar um registro com cada valor de perfil e confirmar persistência.
- Dashboard: classificar 2-3 transações de teste e confirmar que o filtro funciona.

## Realizado

### 2026-08-05

- SPEC criada, decisões de escopo fechadas com o usuário (perfil é só visualização, sem herança, campo fixo de 2 valores, filtro no dashboard existente em vez de app duplicado, achado crítico do livro-caixa desconectado resolvido com tela de classificação manual).
- Migration `20260805_077_spec064_perfil_ribeirao_sao_paulo` (4 arquivos) **aplicada no Supabase real**: coluna `perfil` em `contatos`, `projetos`, `funcionarios`, `funcionarios_novo` (achado: RH tem 2 tabelas de funcionário), `orcamentos`, `pedidos_compra`, `boletos`, `transacoes`; RPCs `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade` recriadas com `p_perfil`; views `vw_funcionarios_completo` e `v_financeiro_realizado` recriadas expondo `perfil`.
- Implementado e **publicado em produção** nos 6 sistemas: CRM (`0.0.290`/`f1f98f0`), RH (`0.0.218`/`c742130`), Orçamentos (`0.0.301`/`d55c64a`), Necessidade de Compra (`0.0.52`/`e616728`), Administração Bancária (`0.0.55`/`87e9a2c`), Dashboard Financeiro (`0.0.23`/`6cb8462`).
- QA (build+testes) do Skip passou em todas as 6 publicações antes de ir ao ar.

## Pendências

- [ ] Submodules locais de CRM, Orçamentos, Necessidade de Compra, Administração Bancária e Dashboard Financeiro **não foram sincronizados** com o que foi publicado no Skip nesta SPEC (só RH foi, na sessão anterior) — implementação ficou 100% no Skip, que é a fonte real de produção. Sincronizar quando for mexer de novo em algum desses sistemas.
- [ ] Testar em produção: criar/editar um registro de cada tipo com perfil preenchido e confirmar que salva; classificar algumas transações em `/transacoes` (Dashboard Financeiro) e confirmar que o filtro Ribeirão/São Paulo funciona nas telas de Contas a Pagar/Receber.
- [ ] Classificação de `transacoes` históricas é trabalho manual contínuo do usuário — não há import nem inferência automática.
