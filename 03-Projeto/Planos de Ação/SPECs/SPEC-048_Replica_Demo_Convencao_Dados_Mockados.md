---
titulo: "SPEC-048 — Réplica de Demonstração do Ecossistema Lucenera para Convenção (dados mockados + Supabase dedicado)"
status: pendente
data_ultima_modificacao: 2026-07-25
sistemas_envolvidos:
  - Ecossistema completo (Hub/Central, Gestão Financeira/Orçamentos, Compras, Administração Bancária, CRM, RH, Logística, Cadastro, Dashboard de Métricas, Ubiqua, Dashboard Admin Python)
  - Supabase (novo projeto dedicado)
---

# SPEC-048 — Réplica de Demonstração do Ecossistema Lucenera para Convenção

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre segurança (ler antes de tudo)

O usuário colou nesta conversa 4 credenciais de um projeto Supabase (`sb_publishable_...`, `sb_secret_...`, JWT `anon`, JWT `service_role`). Por decisão confirmada nesta SPEC, esse é um **projeto novo, dedicado à demo** — não é o Supabase de produção. Mesmo assim:

- Nenhuma dessas chaves foi (ou deve ser) gravada neste arquivo, em código commitado, ou em qualquer lugar do repositório central. Elas só devem existir em arquivos `.env` locais (já ignorados pelo `.gitignore`) e, quando necessário, como *secrets* do próprio Supabase (Edge Functions).
- Este mesmo ecossistema já teve um incidente registrado (`03-Projeto/00_INDICE.md`, adendo de 03/07/2026) de **credencial em texto plano commitada em 3 repositórios**. `AGENTS.md` proíbe explicitamente commitar `.env` ou qualquer segredo do Supabase, ou imprimir valor real em resposta/commit/PR.
- A chave `sb_secret_...` e o JWT `service_role` têm acesso total de leitura/escrita ignorando RLS. Mesmo em projeto de demo, não devem ser usadas no frontend (React) — só em `dashboard/.env` (Python, já é o padrão atual) ou em Edge Functions. O frontend usa a `anon`/`sb_publishable_...`.
- **Ação recomendada:** já que essas chaves passaram por um chat, considerar regenerá-las no painel do Supabase antes de usar em produção da demo (rotação é gratuita e rápida). Ver "Passos manuais do usuário".

## Checklist de Ação

- [x] Item 1 — Confirmar quais dos 10 sistemas em `04-Sistemas/` entram na demo: todos os 10 (decisão do usuário em 2026-07-25).
- [x] Item 2 — Criar a estrutura de pastas do novo local (`C:\script python\Replica SISTEMA LUCENERA`).
- [x] Item 3 — Provisionar o schema completo no Supabase novo. Abordagem corrigida em relação ao previsto: `supabase/db/migrations/` sozinho **não é suficiente** (primeira migration é placeholder vazio — tabelas base nunca foram capturadas em migration nenhuma). Usado em vez disso: base = `supabase/db/current/*.sql` (dump real de 07/07) + delta = migrations `031`-`061`. Aplicado com sucesso: 95 tabelas, 54 views, 101 funções, 53 triggers, 356 policies. Detalhes e gaps conhecidos em `supabase/schema/README.md` da réplica.
- [x] Item 4 — Buckets de Storage criados (`orcamentos`, `revenda-ubiqua-images` públicos; `notas_fiscais`, `materiais-separacao` privados), localizados por grep em `.storage.from(...)` no código. Arquivos dentro dos buckets não foram migrados (buckets vazios).
- [x] Item 5 — Script de seed de dados mockados escrito e rodado (`supabase/seed/seed_data.py`, idempotente — pode rodar de novo com segurança). Volume gerado documentado em `supabase/seed/README.md`.
- [x] Item 6 — Código dos 10 sistemas React copiado para o novo local, `.env` configurado com as credenciais do Supabase de demo. Build validado com sucesso em 1 sistema (`central-lucenera`, via `npm install --legacy-peer-deps && npm run build`) — confirma que não há dependência de runtime do Skip. Os outros 9 ainda não tiveram build validado (ver Pendências).
- [x] Item 7 — `dashboard/` Python copiado para `dashboard-python/`, `.env` configurado. Build/execução ainda não validados (ver Pendências).
- [ ] Item 8 — Redesenhar/republicar as Edge Functions essenciais à demo; desativar/mockar as que dependem de integração externa não replicável (SharePoint, Bradesco, Teams, e-mail real — ver "Edge Functions"). Não iniciado.
- [x] Item 9 — 5 usuários demo criados **de verdade** via Supabase Auth Admin API (login funcional, não só linha decorativa no banco), cobrindo os 5 papéis do Hub/TI. Credenciais em `supabase/seed/README.md`.
- [ ] Item 10 — Ensaiar o roteiro de apresentação ponta a ponta e validar o reset entre execuções (o reset do banco já existe e foi testado — `reset_seed_tables()` — falta ensaiar o roteiro nos sistemas de fato).
- [ ] Item 11 — Decidir e, se aprovado, implementar a estratégia multi-tenant (ver "Multi-tenant").

### Passos manuais do usuário

- [ ] Criar o projeto Supabase novo dedicado (se as chaves já coladas não forem desse projeto ainda) e confirmar a URL do projeto.
- [ ] Avaliar regenerar (`Roll`) a `sb_secret_...`/`service_role` já que trafegaram em texto no chat, mesmo sendo projeto de demo.
- [ ] Aprovar qual das pastas ambíguas em `04-Sistemas/` é a versão correta a replicar quando houver mais de uma candidata (ver tabela em "Estado atual").
- [ ] Confirmar se a apresentação vai depender de internet no local da convenção (Supabase é sempre remoto) ou se precisa de um plano B offline — isso muda o Item 8 e pode adicionar escopo grande (Supabase local via Docker).
- [ ] Decidir sobre multi-tenant (ver seção própria) — impacta o desenho do schema mockado.
- [ ] Rodar localmente os passos de instalação (`bun install` / `pnpm install`, `npm run dev`/`build`) em cada sistema copiado, já que não tenho como validar build/execução de app React fora deste ambiente sem rodar comandos no seu terminal.
- [ ] Aprovar a lista de dados mockados (nomes de clientes fictícios, projetos fictícios, valores) antes da geração, para garantir que nada pareça dado real de cliente na convenção.

## Objetivo

Ter, até a convenção, uma cópia funcional e estável do ecossistema Lucenera — todos os sistemas React relevantes + o dashboard Python + um banco Supabase próprio, populado só com dados fictícios e consistentes — rodando em `C:\script python\Replica SISTEMA LUCENERA`, sem qualquer vínculo com o Supabase de produção ou dados reais de clientes.

## Decisões aprovadas

- O local `C:\script python\Replica SISTEMA LUCENERA` (hoje vazio) é o **destino** da réplica, não a origem — confirmado pelo usuário. A origem é o próprio repositório atual (`04-Sistemas/*` + `dashboard/` + `supabase/`).
- O projeto Supabase cujas chaves foram fornecidas é **novo, dedicado à demo**, separado do projeto de produção — confirmado pelo usuário. Isso é o que torna seguro popular com dados mockados e usar numa apresentação pública.
- O usuário sinalizou interesse em uma opção **multi-tenant** para esse projeto Supabase de demo — decisão de desenho ainda aberta, tratada como pendência com opções na seção "Multi-tenant" abaixo, não como algo já fechado.

## Definição da SPEC

### 1. Estado atual — inventário do que existe hoje (fonte real)

**Sistemas React/TypeScript** (`04-Sistemas/`, scaffold "Skip" — Vite + React + TS + Shadcn, sem dependência de runtime do Skip encontrada no código-fonte verificado):

| Pasta | Sistema | Repo GitHub (`.gitmodules`) | Observação |
|---|---|---|---|
| `central-lucenera-dashboard-1c9ba` | Hub/Central | `central-lucenera` | Painel admin principal |
| `retorno-bancario-bradesco-5392a` | Administração Bancária | `administra--o-bancaria` | Processa retorno CNAB Bradesco |
| `gestao-financeira-clone-544cb (1)` | Gestão Financeira / Orçamentos | `Lucenera---Gest-o-Financeira` | Criação/aprovação de orçamentos |
| `compras-lucenera-3o23t98ee` | Compras / Necessidade de Compra | `compras-lucenera-3o23t98ee` | `package.json` confirma escopo próprio, distinto de Gestão Financeira |
| `dashboard-lucenera-b02z85wa3` | Dashboard de Métricas (web) | `dashboard-lucenera-b02z85wa3` | Relatórios/KPIs — distinto do `dashboard/` Python |
| `lucenera-crm-3bd29 (1)` | CRM | `lucenera-crm` | **Submodule local desatualizado** — versão publicada real está no projeto Skip (`projectId 24580`), não no código local (ver `[[systems_inventory]]`) |
| `dashboard-rh-lucenera-5fe9c` | RH | `dashboard-rh-lucenera-6g2endmv7` | Folha, frequência |
| `lucenera-logistics-b7cd1` | Logística | `lucenera-logistics-bz5s7xehm` | Fulfillment, rastreamento |
| `cadastro-lucenera-b86fe` | Cadastro | `cadastro-lucenera` | **`git status` mostra como não-rastreado (`??`)** — verificar se o clone/link do submodule está íntegro antes de copiar |
| `catalogo-pecas-ubiqua-e6fa0` | Catálogo Ubiqua | `cat-logo-pe-as-ubiqua-` | Baixa prioridade — confirmar se entra na demo |

**Dashboard Admin Python** (`dashboard/`): Streamlit + Plotly + Pandas, páginas Home/Projetos/Financeiro/Estoque/Logística/CRM-Arquitetos/RH-Comissões, conecta via `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (`dashboard/config.py`).

**Banco Supabase** (fonte de verdade em `supabase/`): PostgreSQL, ~86 tabelas base + ~45 views no schema `public` (número do último snapshot completo, 07/07/2026 — desatualizado, ver seção 2), 8 domínios documentados em `supabase/db/domains/` (`cadastros`, `crm`, `estoque_compras`, `financeiro`, `hub_ti`, `logistica`, `orcamentos`, `rh`). 15 Edge Functions em `supabase/functions/`.

**Padrão de credenciais por app** (confirmado lendo `.env`/código de cada sistema):
- Apps React: `VITE_SUPABASE_URL` + `VITE_SUPABASE_PUBLISHABLE_KEY` (chave `anon`/publicável, RLS ativo).
- `dashboard/` Python: `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` (bypassa RLS — uso interno/administrativo apenas).

### 2. Banco: qual fonte usar para recriar o schema

`supabase/db/current/` (dump `pg_dump` schema-only) é o snapshot mais legível, mas está **desatualizado**: manifesto datado de 07/07/2026, cobrindo até a migration `030`. Hoje existem **62 pastas de migration**, a última em `20260724_061_link_sharepoint_projeto` — ou seja, faltam ~31 migrations no dump atual (SPECs 010–041 aplicadas depois).

Duas opções, ambas válidas — decidir antes do Item 3:

| Opção | Como | Prós | Contras |
|---|---|---|---|
| A. Replay de `supabase/db/migrations/*` em ordem | Rodar as 62 pastas, em ordem cronológica pelo prefixo `YYYYMMDD_NNN`, contra o projeto novo vazio | Reflete o estado real mais recente; é a fonte que `AGENTS.md` já trata como corrente | Migrations não foram desenhadas pra rodar 100% independentes/idempotentes fora de ordem; pode haver dependência cruzada a validar na hora |
| B. Reextrair um `pg_dump` novo do Supabase de produção real, aplicar esse dump no projeto novo | `pg_dump --schema=public --schema-only` contra a produção, restaurar no projeto demo | Garantia de fidelidade 1:1 com o estado atual real | Exige acesso `SUPABASE_DB_URL` de produção — mais uma superfície de risco a manusear com cuidado |

Recomendação: **Opção A** (replay das migrations), por já ser o fluxo padrão do repositório e não exigir tocar em credenciais de produção. `03_functions.sql`/`04_triggers.sql`/`05_views.sql`/`06_storage.sql`/`07_rls_policies.sql` do snapshot atual servem como checklist de conferência pós-replay, não como fonte a aplicar diretamente.

`08_seed_minimo.sql` está vazio ("pendente de consolidação") — **não existe seed reaproveitável hoje**. Todo dado mockado desta SPEC é novo.

### 3. Dados mockados necessários (por domínio)

Consistência entre domínios é obrigatória — os IDs precisam casar entre tabelas (ex.: um `projeto` mockado precisa ter `orcamento`, `itens`, `parcelas` e `contatos` coerentes entre si, não gerados isoladamente).

| Domínio | Tabelas-chave | Volume sugerido p/ demo |
|---|---|---|
| Cadastros | `empresas`, `contatos`, `produtos`, `fornecedores`, `marcas`, `categorias_produto`, `categorias_financeiras` | 15–20 empresas, 30–40 contatos, 50–80 produtos, 10 fornecedores |
| CRM / Projetos | `projetos`, `historico_status_orcamentos` | 20–30 projetos em estágios variados do funil (spread proposital pra demo visual) |
| Orçamentos | `orcamentos`, `orcamento_itens`, `projeto_itens` | 1–3 orçamentos por projeto, com itens de produtos reais do cadastro mockado |
| Financeiro | `projeto_parcelas`, `boletos` | Parcelas cobrindo todos os status possíveis (pendente, pago, vencido) pra mostrar os relatórios |
| Estoque/Compras | `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item`, pedidos de compra | Saldos que alimentem `vw_necessidade_compra` com exemplos reais de necessidade |
| RH | `funcionarios`, `funcionarios_detalhes`, comissões | 10–15 funcionários fictícios |
| Logística | tabelas de fulfillment/rastreamento do domínio `logistica` | Poucos exemplos, cobrindo os status principais |
| Hub/TI | `usuarios`, `papeis`, `papel_permissoes`, `usuario_papeis` | 1 usuário demo por papel a ser mostrado (admin, financeiro, vendas, etc.) |

Todos os nomes (pessoas, empresas, projetos) devem ser **claramente fictícios** — não usar variações de nomes reais de clientes/arquitetos vistos em `01-Documento/` ou nas reuniões.

### 4. Multi-tenant (decisão em aberto)

O usuário mencionou interesse numa "opção de multi tenant id" pro Supabase de demo. Duas leituras possíveis — precisa confirmação antes de desenhar o schema mockado:

- **A. Sem multi-tenant** — um único conjunto de dados mockados, projeto Supabase 100% dedicado à demo. Mais simples, menor risco, suficiente se só uma pessoa/estação apresenta por vez.
- **B. Com `tenant_id`/`organizacao_id`** — adicionar uma coluna de isolamento nas tabelas centrais (`projetos`, `orcamentos`, `contatos`, etc.) e RLS por tenant, permitindo várias "instâncias" de dados mockados isoladas no mesmo projeto Supabase (ex.: um dataset por estação de demo, ou resetável independentemente). Exige mudança de schema em cima do que já existe (o schema de produção **não tem** esse conceito hoje — seria uma extensão só do ambiente de demo, não replicada de volta pra produção).

Recomendação: começar pela **Opção A** para a convenção (prazo curto, menor superfície de erro) e tratar B como evolução se houver necessidade real de múltiplas instâncias simultâneas — mas a decisão final é do usuário.

### 5. Edge Functions — o que entra na demo

| Function | Entra na demo? | Motivo |
|---|---|---|
| `aprovar-orcamento-financeiro`, `salvar-projeto`, `update-project`, `generate-report` | Sim | Fluxo core, sem dependência externa |
| `generate-cross-system-code`, `exchange-cross-system-code` | Sim | SSO entre sistemas (SPEC-007), útil pra mostrar navegação integrada |
| `parse-budget-pdf`, `process-budget-pdf` | A confirmar | Podem depender de API externa de IA/OCR paga — checar se há chave própria antes de incluir |
| `process-remittance`, `sync-sharepoint`, `sync-teams` | Não | Dependem de integrações externas reais (banco, SharePoint, Teams) que não fazem sentido/não devem rodar contra um ambiente de demo |
| `enviar-confirmacao-email`, `welcome-email` | Não (ou mockar) | Evitar disparo real de e-mail durante a demo |
| `chat-agent`, `chat-consulta` | A confirmar | Podem depender de chave de LLM própria — decidir se entra no roteiro de apresentação |

### 6. Arquitetura da réplica (estrutura de pastas proposta em `Replica SISTEMA LUCENERA/`)

```text
Replica SISTEMA LUCENERA/
  sistemas/
    central-lucenera/
    gestao-financeira/
    compras/
    administracao-bancaria/
    crm/
    rh/
    logistica/
    cadastro/
    dashboard-metricas/
    (ubiqua/ — se confirmado)
  dashboard-python/
  supabase/
    schema/        (migrations copiadas, na ordem, pra reaplicar)
    seed/          (scripts novos de dados mockados desta SPEC)
  README_DEMO.md   (roteiro de apresentação + como resetar os dados)
```

Não é necessário replicar a estrutura de submodules Git nem as pastas `00-Contexto/`, `01-Documento/`, `02-Reunioes/` do repositório central — a demo só precisa do código executável e do banco, não do histórico de gestão do projeto.

### 7. Modo apresentação — estabilidade e risco de conectividade

- Todos os sistemas React falam com o Supabase por HTTPS direto do navegador — **exigem internet** no local da convenção, independente de como o app é hospedado (local `vite dev`/`preview` ou build estático). Confirmar com o usuário se a conectividade do local é confiável (ver "Passos manuais do usuário"); se não for, um Supabase local (self-hosted, Docker) é a única forma de rodar 100% offline, e é escopo adicional grande, fora desta SPEC até ser aprovado.
- Recomenda-se rodar os apps como build estático (`vite build` + `preview`/servidor estático local) em vez de `dev server`, por estabilidade.
- Ter um script de **reset de dados** (voltar o banco de demo ao estado inicial mockado) para poder repetir a demonstração várias vezes ao longo da convenção sem acumular sujeira dos testes anteriores.

## Impacto no banco

Cria um projeto Supabase novo e independente — nenhum impacto no banco de produção. Dentro do projeto novo: schema completo replicado (via migrations) + seed de dados mockados novo (a escrever) + eventual coluna `tenant_id` se a Opção B do multi-tenant for aprovada (não afeta produção em nenhum cenário).

## Impacto em telas

Nenhuma mudança de tela nos sistemas originais. A réplica roda o mesmo código-fonte, só apontando para outro `.env`/projeto Supabase.

## Regras de permissão

Reaproveitar o modelo de papéis do Hub/TI (SPEC-006: `papeis`, `papel_permissoes`, `usuario_papeis`) já existente no schema. Criar usuários demo com login simples e senha conhecida pelo apresentador, cobrindo os papéis que o roteiro da convenção for mostrar (ex.: admin vê tudo; usuário financeiro vê só Financeiro/Orçamentos).

## Critérios de aceite

- Todos os sistemas aprovados (Item 1) rodam localmente a partir do novo local, sem apontar para o Supabase de produção.
- O schema do Supabase de demo bate com o inventário de `supabase/db/domains/` (mesmas tabelas/relacionamentos usados pelos sistemas).
- Um fluxo completo (ex.: criar projeto → orçamento → aprovação → parcela) funciona ponta a ponta com dados mockados, sem erro.
- Nenhum dado real de cliente aparece em nenhum sistema da réplica.
- Existe um jeito de resetar os dados mockados entre apresentações.

## Testes/verificações obrigatórias

- Rodar `build`/`dev` de cada sistema copiado e confirmar que conecta no Supabase novo (sem erro de RLS/permissão para o usuário demo usado).
- Validar que o dashboard Python (`dashboard/config.py`) lê do projeto novo e renderiza os gráficos sem erro.
- Conferir, tabela por tabela, que os dados mockados batem com as constraints reais (FKs, enums de status — ver `supabase/docs/status_enums.md`) antes de considerar o seed pronto.
- Ensaiar a apresentação completa pelo menos uma vez de ponta a ponta antes da convenção.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` ou `user_system_access`?** Sim — todas essas tabelas precisam existir e estar populadas de forma coerente no projeto de demo, replicando o mesmo modelo de dados da produção.
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI?** Afeta todos, mas só no ambiente de demo — zero impacto em produção.
- **Existe dado duplicado que deve ser derivado por relacionamento?** O dado mockado deve seguir as mesmas regras de derivação já documentadas (`[[design_decisions]]`: `boletos.orcamento_id` como link primário, `projetos.valor_total` denormalizado via `sync_projeto_valor_total()`, vencimento via `_lucenera_parse_prazo_pagamento()`) — não hardcodar valores que deveriam ser calculados.
- **Existe migration antiga que contradiz o snapshot central?** O próprio snapshot central (`supabase/db/current/`) está desatualizado em relação às migrations mais recentes — ver seção 2. Resolver isso é pré-requisito desta SPEC, não só um risco a anotar.
- **Exige atualização de `AI_DB_CONTEXT.md`?** Não nos sistemas de produção — o ambiente de demo é isolado. Pode valer a pena um `AI_DB_CONTEXT.md` próprio dentro da pasta de réplica, para quem for mexer nela depois.

## Realizado

### 2026-07-25

- Confirmadas com o usuário as duas decisões que destravaram a execução: pasta destino vazia (`C:\script python\Replica SISTEMA LUCENERA`) e projeto Supabase dedicado à demo (não produção); escopo = todos os 10 sistemas; schema aplicado via SUPABASE_DB_URL/senha fornecida pelo usuário.
- Estrutura de pastas criada e código dos 10 sistemas React + `dashboard/` Python copiado para o novo local (excluindo `node_modules`/`.git`/`dist`).
- **Achado de segurança durante a cópia:** `robocopy` trouxe o `dashboard/.env` original, que continha a `service_role` **real de produção** (projeto `vcvcwzmbiftcawncibke`) — não aparecia em `ls` por ser dotfile. Sobrescrito na hora com as credenciais do projeto de demo antes de qualquer uso.
- Conexão direta `db.<ref>.supabase.co` falhou (só tem endereço IPv6, sem rota nesta rede) — resolvido usando o **Session Pooler** (`aws-0-us-east-2.pooler.supabase.com:5432`, IPv4), localizado via navegação assistida no painel Supabase (conta `erp.lucenera@gmail.com`).
- Schema aplicado com sucesso: 95 tabelas, 54 views, 101 funções, 53 triggers, 356 policies, extensões `unaccent`/`pg_trgm`/`uuid-ossp`/`pgcrypto`. Abordagem original da SPEC (replay de `supabase/db/migrations/*`) revelou-se **insuficiente** — a migration `001` é placeholder vazio, as tabelas base nunca foram capturadas em migration nenhuma. Corrigido usando `supabase/db/current/*.sql` (dump real de 07/07) como base + migrations `031`-`061` como delta. Detalhes completos, incluindo um bug de `search_path` esvaziado pelo dump e dois gaps de drift de produção encontrados (`estoque_itens.quantidade_disponivel` sem migration de origem; backfill da migration `045` dependente de tabela de staging inexistente), documentados em `supabase/schema/README.md` da réplica.
- 4 buckets de Storage criados (`orcamentos`, `revenda-ubiqua-images` públicos; `notas_fiscais`, `materiais-separacao` privados) com as policies reais copiadas do snapshot.
- Seed de dados mockados escrito e aplicado (`supabase/seed/seed_data.py`, idempotente): 9 systems, 5 papéis, 4 empresas, 45 contatos, 8 fornecedores, 10 marcas, 8+8 categorias, 60 produtos, 5 usuários de login real (via Auth Admin API) + 12 funcionários adicionais, 25 projetos, 22 orçamentos, 91 itens de orçamento, 25 itens de projeto, 45 parcelas, 35 boletos, 60 linhas de estoque. Credenciais de login em `supabase/seed/README.md`.
- Build validado com sucesso em 1 dos 10 sistemas (`central-lucenera`, via `npm install --legacy-peer-deps && npm run build`) — confirma que os apps rodam fora do Skip Cloud.

## Pendências

- [ ] Validar `build`/`dev` dos outros 9 sistemas (só `central-lucenera` foi validado até agora).
- [ ] Validar que o `dashboard/` Python (Streamlit) roda e renderiza contra o Supabase de demo.
- [ ] Ensaiar o roteiro de apresentação ponta a ponta nos sistemas de fato (o banco já está pronto e populado).
- [ ] Edge Functions ainda não republicadas no projeto de demo (Item 8) — nenhuma function roda hoje contra esse projeto.
- [ ] Resolver a pasta `cadastro-lucenera-b86fe` — aparece como não-rastreada (`??`) no `git status` do repo central; verificar se o clone está íntegro (foi copiada para a réplica assim mesmo).
- [ ] Confirmar se o código local do CRM (`lucenera-crm-3bd29 (1)`) deveria ter sido sincronizado com a versão publicada no Skip (`projectId 24580`) antes de replicar — a réplica usou o submodule local, que pode estar desatualizado (`[[systems_inventory]]`).
- [ ] Decidir sobre multi-tenant (segue em aberto — não implementado; demo rodando em modo single-tenant simples).
- [ ] Confirmar se a demo precisa funcionar offline (Supabase local via Docker) ou se a conectividade no local da convenção é garantida.
- [ ] Avaliar regenerar as chaves/senha do Supabase de demo coladas nesta conversa, por precaução.
- [ ] Registrar formalmente no repo de produção os 2 gaps de drift encontrados (`estoque_itens.quantidade_disponivel` e a tabela de staging `stg_duplicatas_vigentes` da migration 045) — achados reais sobre o banco de produção, não específicos da demo.
- [ ] Buckets de Storage estão vazios — subir arquivos de exemplo (PDF de orçamento, imagens de catálogo) se o roteiro precisar mostrar anexos.
