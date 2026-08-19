---
titulo: "SPEC-117 — Página Contas em Aberto (Pagar/Receber) na Administração Bancária"
status: implementado localmente, aguardando publicação no Skip e homologação
data_ultima_modificacao: 2026-08-19
sistemas_envolvidos:
  - Administração Bancária (retorno-bancario-bradesco-5392a) — Skip projectId 36395 (confirmado via SPEC-114, v0.0.64)
---

# SPEC-117 — Página Contas em Aberto (Pagar/Receber) na Administração Bancária

## Checklist de Ação

- [x] Criar página nova em `retorno-bancario-bradesco-5392a` (`ContasEmAberto.tsx`, rota `/contas-em-aberto`) mostrando contas a pagar e a receber genuinamente em aberto (`status_pago = 0`)
- [x] Implementar a busca de dados via query nova (Opção B — ver "Fonte de dados"): `transacoes JOIN negociacoes JOIN empresas LEFT JOIN contatos LEFT JOIN plano_de_contas`, filtrando `status_pago = 0`
- [x] Implementar KPIs no topo: Total a Pagar em aberto, Total a Receber em aberto, Vencido, A Vencer
- [x] Implementar aging por faixa de atraso (0-30 / 31-90 / 91-365 / +365 dias), replicando a lógica de `scripts/panorama_financeiro/exportar_nao_quitadas.py` (nulificar `dt_vencimento` implausível — anos fora de 2000-2100 — em vez de calcular atraso sem sentido)
- [x] Implementar filtros: tipo (Pagar/Receber), empresa, perfil (Ribeirão/São Paulo/Todos), situação (Todos/Aberto/Vencido), período (data), busca por pessoa/fornecedor (multi-termo, sem acento — mesmo padrão SPEC-116 já usado em `ConsultarDuplicatas.tsx`)
- [x] Implementar tabela detalhada (uma linha por transação em aberto) com paginação — usar `.range()` em lotes se ultrapassar 1000 linhas (cap silencioso do PostgREST, achado da SPEC-081)
- [x] Adicionar link da nova página no menu (`Layout.tsx` → `navLinks`) e rota (`App.tsx`)
- [x] Atualizar `04-Sistemas/retorno-bancario-bradesco-5392a/supabase/AI_DB_CONTEXT.md` incluindo `transacoes`, `negociacoes`, `plano_de_contas`, `contatos` — hoje esse arquivo só documenta o universo `boletos`/`orcamentos`/`projetos`

### Passos manuais do usuário

- [ ] Confirmar o nome exato do item de menu/rota da nova página (sugestão: "Contas em Aberto")
- [ ] Antes de publicar, confirmar no Skip Cloud que o projectId 36395 ainda é o correto para `retorno-bancario-bradesco-5392a` e que o checkout local não está desatualizado em relação ao Skip
- [ ] Homologar a tela nova comparando os totais exibidos contra a planilha já exportada em 18-19/08/2026 (2.382 linhas: 1.506 a pagar + 876 a receber, R$ 7.597.768,83 + R$ 5.032.310,09) antes de considerar a SPEC concluída

## Objetivo

O usuário pediu um relatório de "Contas Não Quitadas" (contas a pagar/receber genuinamente em aberto, `status_pago = 0`), gerado fora do sistema (planilha + PDF) a partir de `transacoes`/`negociacoes`/`empresas`. Ao perguntar se essa informação já existia dentro do sistema "Administração Bancária", foi confirmado que **não existe**: esse sistema lê exclusivamente de `boletos` (43 linhas hoje, quase tudo `CR`, zero `CP`), sem nenhuma FK para `transacoes`/`negociacoes`. O universo real de contas em aberto (2.382 linhas, ~R$ 12,6 milhões) é hoje invisível dentro do sistema que o usuário usa no dia a dia.

O usuário confirmou explicitamente que quer uma página dentro do sistema com essa informação. Esta SPEC define uma página nova, dentro de Administração Bancária, que expõe contas a pagar e a receber em aberto — sem alterar a estrutura de dados existente.

## Decisões aprovadas (usuário, 2026-08-19)

- A página nova fica dentro do sistema Administração Bancária (`retorno-bancario-bradesco-5392a`) — foi o sistema onde o usuário pediu a informação.
- Mostra contas a pagar **e** a receber genuinamente em aberto: `status_pago = 0` apenas (`0=ABERTO, 1=PAGO, 2=CANCELADO`; cancelado nunca conta como aberto — regra da migration `20260819_121`).
- **Fonte de dados: Opção B — query nova**, equivalente à de `scripts/panorama_financeiro/exportar_nao_quitadas.py` (join direto `transacoes → negociacoes`, com nome de pessoa/fornecedor via `contatos`). Rejeitada a Opção A (view `v_financeiro_realizado`) por não ter nome de pessoa e por depender de `stg_duplicatas_vigentes`, tabela de staging sem migration rastreada — risco de subcontagem silenciosa.
- **Aging por faixa entra nesta primeira versão** (0-30 / 31-90 / 91-365 / +365 dias vencidos), mesma quebra usada no relatório visual já entregue.
- A página segue o mesmo padrão estrutural já usado hoje no sistema (`ConsultarDuplicatas.tsx`): acesso direto ao Supabase via `@/lib/supabase/client` dentro do componente (sem camada `services/`), filtros no topo, totais no rodapé, tabela paginada abaixo.
- **Não** conecta `boletos` a `transacoes`/`negociacoes` estruturalmente — os dois universos continuam desconectados como estão hoje; unificação estrutural é escopo maior, não pedido agora.
- **Não** altera a tela `ConsultarDuplicatas.tsx` nem a tabela `boletos`.

## Definição da SPEC

### Estado atual (achados)

- `retorno-bancario-bradesco-5392a` (Administração Bancária) lê boletos exclusivamente de `public.boletos`. `ConsultarDuplicatas.tsx` faz `supabase.from('boletos').select('*, empresas(nome)')`, filtrando `tipo_operacao = 'CP'|'CR'` no cliente. `boletos` tem ~43 linhas reais, quase todas `CR`; zero `CP` — por isso a aba "Contas a Pagar" desse sistema sempre mostra R$ 0.
- `boletos` não tem FK para `transacoes` nem `negociacoes`. O universo de contas a pagar/receber "genuínas" vive só em `transacoes` + `negociacoes` + `empresas` (+ `contatos`, `plano_de_contas`): 2.382 linhas com `status_pago = 0` (1.506 a pagar / R$ 7.597.768,83 + 876 a receber / R$ 5.032.310,09).
- Existe uma tela de KPI agregado sobre esse mesmo universo em **outro** sistema (`dashboard-lucenera-b02z85wa3`, "Dashboard Financeiro", `ContasPagarFoco.tsx`/`ContasReceberFoco.tsx`, via `v_financeiro_realizado`), mas é só um número agregado dentro de um dashboard analítico — não uma lista operacional linha a linha com nome de pessoa. Não resolve o pedido atual e está fora do escopo desta SPEC.
- `v_financeiro_realizado` passa por `INNER JOIN stg_duplicatas_vigentes`, tabela de staging sem migration de criação rastreada no repositório central — risco de exclusão silenciosa de linhas. Por isso a query nova (Opção B) foi escolhida em vez de reaproveitar a view.
- `04-Sistemas/retorno-bancario-bradesco-5392a/supabase/AI_DB_CONTEXT.md` não documenta `transacoes`, `negociacoes`, `contatos` nem `plano_de_contas` — só `boletos`/`orcamentos`/`projetos`. Precisa ser atualizado.
- `supabase/db/current/` (snapshot central) está desatualizado em relação a migrations já aplicadas (`v_financeiro_realizado` ausente de `05_views.sql`, `transacoes.perfil` ausente de `01_schema_full.sql`) — achado colateral, não bloqueia esta SPEC.

### Padrão de acesso a dados já usado pelo sistema (replicar, não reinventar)

`retorno-bancario-bradesco-5392a` não tem camada de `services/`, `hooks/` de dados nem store central — cada página chama `supabase.from(...).select(...)` diretamente no componente, com filtro/agregação no cliente via `useMemo`. A página nova segue o mesmo padrão.

### Query de dados (Opção B, aprovada)

Base: mesma lógica de `scripts/panorama_financeiro/exportar_nao_quitadas.py`, adaptada para `supabase-js` client-side:

```
transacoes t
  join negociacoes n on n.id = t.negociacao_id
  join empresas e on e.id = n.empresa_id
  left join contatos c on c.id = n.contato_id
  left join plano_de_contas pc on pc.id = n.plano_contas_id
where t.status_pago = 0
```

Campos: empresa, tipo (despesa→Pagar / receita→Receber), categoria, pessoa/fornecedor, descrição, valor, dt_emissao, dt_vencimento, dias em atraso (nulo se ano de `dt_vencimento` fora de 2000-2100 — dado corrompido conhecido, 4 linhas), nº duplicata, parcela/total parcelas, perfil (Ribeirão/SP).

### Estrutura de UI proposta

Seguindo o padrão visual de `ConsultarDuplicatas.tsx`:

- **Cabeçalho**: título "Contas em Aberto" + alternância Pagar/Receber.
- **KPIs no topo**: Total a Pagar em aberto, Total a Receber em aberto, Vencido, A Vencer — sobre o conjunto filtrado.
- **Aging**: cards ou mini-tabela por faixa (0-30 / 31-90 / 91-365 / +365 dias), separado por Pagar/Receber.
- **Filtros**: tipo, empresa, perfil, situação (Todos/Aberto/Vencido), período (`dt_vencimento`), busca por pessoa (multi-termo, sem acento — padrão SPEC-116).
- **Tabela detalhada**: Empresa, Tipo, Categoria, Pessoa, Descrição, Emissão, Vencimento, Dias em Atraso, Valor, Nº Duplicata, Parcela/Total — paginada.
- **Rodapé**: totais (mesmo padrão de `totais.vencido/aVencer/aberto/pago` já existente em `ConsultarDuplicatas.tsx`).

### Não escopo

- Não conecta `boletos` a `transacoes`/`negociacoes` estruturalmente.
- Não altera `ConsultarDuplicatas.tsx` nem comportamento existente de `boletos`.
- Não decide classificação de custo/categoria nova — só exibe o que já está classificado.
- Não implementa baixa, edição ou qualquer escrita sobre `transacoes`/`negociacoes` — tela somente leitura.
- Não mexe em `ContasPagarFoco.tsx`/`ContasReceberFoco.tsx` do outro sistema.

### Análise obrigatória de ecossistema

- **Depende de**: `contatos` (nome de pessoa/fornecedor) e RLS/`ProtectedRoute` padrão já existente no sistema. Não depende de `boletos`, `projeto_itens`, `projeto_parcelas`, `produtos` nem `orcamentos`.
- **Afeta**: apenas Administração Bancária (nova tela, sem mudança de schema/banco).
- **Dado duplicado?**: não — só leitura de dados existentes.
- **Migration de sistema contradizendo snapshot central?**: não; o achado é o inverso (snapshot central atrasado em relação às migrations aplicadas).
- **Exige atualizar `AI_DB_CONTEXT.md`?**: sim, `retorno-bancario-bradesco-5392a` precisa passar a documentar `transacoes`, `negociacoes`, `contatos`, `plano_de_contas`.
- **Padrão de acesso a dados do sistema**: acesso direto ao Supabase client dentro do componente — replicado, não reinventado.

### Critério de aceite

- Página carrega sem erro, autenticado, mostrando linhas reais de `transacoes` com `status_pago = 0`.
- Totais de "A Pagar" e "A Receber" batem com a planilha já gerada (`ContaPagar_2026-08-17_NAO_QUITADAS_v3.xlsx` / `ContaReceber_2026-08-17_NAO_QUITADAS.xlsx`).
- Aging por faixa bate com o relatório visual já entregue.
- Filtro por pessoa, empresa, perfil e período reduz a lista corretamente (verificação manual).
- Nenhuma linha com `status_pago = 1` ou `status_pago = 2` aparece na tela.
- Build do sistema passa sem erro de lint/tipo.
- `AI_DB_CONTEXT.md` do sistema atualizado.

## Realizado

**2026-08-19** — Implementado localmente no submodule `04-Sistemas/retorno-bancario-bradesco-5392a` (NÃO publicado no Skip Cloud, NÃO aplicado no Supabase real — esta SPEC não exigia migration nenhuma).

Arquivos criados/editados:
- `src/pages/ContasEmAberto.tsx` (novo) — página completa: header com toggle Pagar/Receber, 4 KPIs (Total a Pagar aberto, Total a Receber aberto, Vencido, A Vencer), mini-tabela de aging (0-30/31-90/91-365/+365 dias, colunas Pagar e Receber lado a lado), painel de filtros (empresa, perfil, situação, período por `dt_vencimento`, busca de pessoa multi-termo sem acento), tabela detalhada paginada (client-side, 50 linhas/página) e rodapé de totais.
- `src/App.tsx` — import de `ContasEmAberto` + rota `/contas-em-aberto` dentro do `ProtectedRoute` existente (mesmo padrão das demais rotas).
- `src/components/Layout.tsx` — item "Contas em Aberto" adicionado em `navLinks`, logo após "Consultar Duplicatas".
- `supabase/AI_DB_CONTEXT.md` — documentadas as colunas reais de `transacoes`/`negociacoes`/`plano_de_contas` usadas pela tela nova, mais uma seção "Contas em Aberto (SPEC-117)" explicando que é um universo desconectado de `boletos`, e o achado colateral de que `transacoes.perfil` existe no banco real (migration `20260805_077`) mas não aparece no snapshot central `supabase/db/current/01_schema_full.sql` nem em `src/lib/supabase/types.ts` deste sistema.

Fonte de dados implementada exatamente como a Opção B aprovada: `supabase.from('transacoes').select(...)` com embed `negociacoes(cod_duplicata, total_parc, empresas(nome), contatos(nome), plano_de_contas(nome))`, filtro `.eq('status_pago', 0)`, paginado em lotes de 1000 via `.range()` (padrão já usado em `dashboard-lucenera-b02z85wa3/src/services/*.ts` e `compras-lucenera-3o23t98ee/src/services/necessidade-compra.ts` — copiado, não inventado). Confirmado via `supabase/db/current/01_schema_full.sql` que os FKs são: `negociacoes.empresa_id → empresas`, `negociacoes.contato_id → contatos`, `negociacoes.plano_contas_id → plano_de_contas`, todos FKs únicos (sem ambiguidade de embed).

Decisões de nome/coluna tomadas por conta própria (a SPEC não especificava 100%):
- Dias em atraso "0" (não vencido) não entra em nenhuma faixa de aging — só `diasAtraso > 0` conta como vencido, mesma regra do script de referência.
- Faixas de aging: 1-30, 31-90, 91-365, 366+ (label da primeira faixa mantido como "0-30 dias" pedido na SPEC, mas o cálculo começa em 1 dia de atraso — dia 0 é "a vencer", não vencido).
- Filtro "Situação = Aberto" foi interpretado como "aberto e ainda não vencido" (equivalente a "a vencer"), já que TODAS as linhas da tela já são `status_pago = 0` por definição da query — não haveria sentido em um filtro "Aberto" que não filtrasse nada.
- Filtro de empresa compara por `nome` (não por `id`), replicando exatamente o padrão já usado em `ConsultarDuplicatas.tsx`.
- Período (`dataInicio`/`dataFinal`) default vazio (sem filtro), diferente do default fixo de junho/2026 em `ConsultarDuplicatas.tsx` — decisão para não esconder dados por padrão numa tela nova que precisa ser homologada contra a planilha de referência (2.382 linhas totais).
- KPIs "Total a Pagar"/"Total a Receber" são calculados sobre todos os filtros MENOS o toggle Pagar/Receber (mostram os dois lados sempre, já que são o par de cada um); "Vencido"/"A Vencer" refletem o tipo selecionado no toggle, para ficarem coerentes com a tabela detalhada abaixo. Isso não estava 100% explícito na SPEC.

Verificação executada:
- `pnpm install` (submodule não tinha `node_modules`) + `oxlint` nos arquivos alterados: só o warning pré-existente de `react-hooks/exhaustive-deps` (mesmo padrão de `ConsultarDuplicatas.tsx`/`Boletos.tsx`, não é regressão) e um warning pré-existente em `Layout.tsx` (variável `user` não usada, já existia antes desta SPEC).
- `oxfmt --check` limpo após rodar `oxfmt` para formatar os 3 arquivos alterados.
- `npx tsc --noEmit` sem erros nos arquivos novos/alterados.
- `pnpm run build` (`vite build`) concluído com sucesso — únicos avisos são pré-existentes (chunk size, dynamic import de `cnab-parser.ts`), não relacionados a esta SPEC.
- Não foi possível testar a tela ao vivo no navegador (sem esse acesso) nem confirmar totais contra a planilha `ContaPagar_2026-08-17_NAO_QUITADAS_v3.xlsx`/`ContaReceber_2026-08-17_NAO_QUITADAS.xlsx` — fica para homologação manual do usuário, ver "Passos manuais do usuário" no topo da SPEC (nenhum item concluído ainda).

Achado adicional durante a implementação: o checkout local de `retorno-bancario-bradesco-5392a` já tinha páginas que esta SPEC não mencionava (`Boletos.tsx`, `NotasFiscais.tsx`, `RetornoBoletos.tsx`, `CadastrarDuplicata.tsx`, `BaixarDuplicata.tsx`) — sinal de que o Skip pode estar mais avançado do que a SPEC presumia quando foi escrita. Reforça o passo manual já listado: comparar com o Skip Cloud antes de publicar por cima.

Antes de qualquer commit, rodar o agente `revisor`.

## Pendências

- [ ] Investigar (fora desta SPEC, achado colateral) o que é `stg_duplicatas_vigentes` e regularizar sua documentação/migration.
- [ ] Regerar o snapshot `supabase/db/current/` para refletir `v_financeiro_realizado` e `transacoes.perfil` (achado colateral).
