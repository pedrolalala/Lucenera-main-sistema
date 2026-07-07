# Analise de Lacunas de Implementacao - 07/07/2026

Este relatorio compara a implementacao atual da pasta `Lucenera - ADAPTA PASS` com:

- reunioes em `02-Reunioes/`;
- processos mapeados em `05-Mapeamento Markdown/`;
- escopos e SPECs em `03-Projeto/`;
- snapshot e migrations centrais em `supabase/`;
- codigo dos sistemas em `04-Sistemas/`.

A leitura foi feita com as lentes ECC pedidas: planejamento (`/ecc:plan`), TDD (`/tdd`), code review (`/ecc:code-review`), build-fix (`/build-fix`) e refactor-clean (`/refactor-clean`). O objetivo aqui nao e alterar codigo, mas separar o que esta implementado, o que esta parcial, o que esta bloqueado e o que ainda nao virou SPEC.

## Resumo executivo

O ecossistema avancou bastante em Orçamentos, Financeiro/retorno bancario e backend de estoque por item de projeto. Ainda assim, a operacao completa da Lucenera nao esta pronta para corte do Connect. Os maiores blocos restantes sao:

1. **Sistema de TI/permissoes/SSO**: `SPEC-006` e `SPEC-007` foram implementadas localmente e refletidas no Supabase remoto em 07/07/2026; ainda precisam ser homologadas ponta a ponta com usuários reais e adotadas gradualmente pelos sistemas.
2. **Estoque e Compras como sistema operacional**: o backend parcial existe via `SPEC-010`, `SPEC-011`, `SPEC-012` e `SPEC-015`, mas nao existe app/tela propria para necessidade de compra, cotacao, pedido, recebimento, transferencia, devolucao e painel da Debora/Vitoria.
3. **Historico Connect e importacao repetivel**: M01-M04 seguem pendentes/parciais. As 16.621 linhas `VENDAS`, 2.042 vendas, 330 projetos e 1.508 produtos ainda nao foram promovidos integralmente para `vendas`, `projeto_itens` e movimentos derivados.
4. **CRM configuravel e timeline**: o CRM ainda opera com fluxo/status fixos; nao existem `crm_fluxos`, `crm_etapas` ou `crm_substatus` no snapshot atual.
5. **Financeiro completo**: `SPEC-008` concluiu retorno bancario tecnicamente, mas CP/CR, previsoes financeiras, NF por API, rotinas Lana/Caroline e homologacao CNAB real seguem pendentes ou bloqueadas por decisao.
6. **Logistica integrada**: o app evoluiu, mas ainda falta origem estruturada no Estoque/Compras, evidencias via OneDrive/SharePoint, estados canonicos, eventos para CRM e plano de corte entre backup operacional e `lucenera-logistics-b7cd1`.
7. **Seguranca/RLS/testes**: ha senha exposta registrada nos documentos, RLS permissivas com `USING (true)` em fluxos novos, Edge Functions com service role e quase nenhum teste automatizado real.

## Implementado ou muito avancado

| Area | Estado atual | Proxima validacao |
|---|---|---|
| Orçamentos `SPEC-001` a `SPEC-005` | Aprovacao transacional, frete/prazo, historico, parcelas/boletos e remocao de triggers legados estao implementados. | Homologar fluxo real ponta a ponta e cobrir com testes. |
| Aprovacao cliente/financeira `SPEC-009`, `016`, `017` | Banco e UI em homologacao; status oficial ficou `enviado_cliente -> Aprovacao Financeira -> Orcamento Aprovado`. | Homologar visualmente e decidir expiracao do token de cliente. |
| Criacao de produto no orcamento `SPEC-018` | RPC `criar_produto_orcamento` e UI implementadas em homologacao. | Validar obrigatoriedade final de marca/categoria/fornecedor e duplicidade. |
| Retorno bancario `SPEC-008` | Backend + frontend implementados; build do app Financeiro passa. | Testar com arquivo `.RET` real e homologar CNAB com Bradesco. |
| Estoque por item `SPEC-010` | Snapshot 07/07 confirma `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e hardening `20260707_023`. | Corrigir textos desatualizados nas SPECs/checklist e liberar consumo frontend. |
| Transferencia, entrega futura e devolucao `SPEC-011/012/015` | Backend/views/RPCs existem no banco real segundo snapshot e migrations. | Criar telas, permissoes e fluxos operacionais. |
| CRM itens aprovados `SPEC-014` | Card de itens aprovados foi implementado no CRM com estado `Ativo`/`Cancelado`. | Consumir `vw_estoque_saldos_projeto_item` para badges ricos. |
| Hub/TI `SPEC-006/007` | Permissoes granulares e SSO foram implementados em migrations, Edge Functions e apps Hub/Orcamentos/Financeiro/CRM; snapshot e remoto confirmados em 07/07/2026. | Homologar SSO com usuário real, validar a matriz de papéis/módulos/ações e planejar adoção nos sistemas. |

## Lacunas por dominio

### 1. Governanca, Hub e Sistema de TI

Falta homologar/adotar de forma integrada:

- matriz de sistemas/modulos/acoes/papeis/excecoes/auditoria (`SPEC-006`) com dados reais de operação;
- SSO entre sistemas por codigo curto (`SPEC-007`) com usuário real e destinos publicados;
- historico de acesso e atividade (`HUB-06`/`TI-12`, ainda sem SPEC dedicada);
- saude dos sistemas e integracoes (`TI-05`/`TI-07`);
- remocao progressiva das checagens locais divergentes em RH, Logistica, Ubiqua e outros.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 69-103.
- `03-Projeto/Planos de Ação/SPECs/SPEC-006_Permissoes_Granulares_no_Hub.md`.
- `03-Projeto/Planos de Ação/SPECs/SPEC-007_Token_Acesso_Compartilhado_Entre_Sistemas.md`.
- `04-Sistemas/central-lucenera-dashboard-1c9ba/src/pages/Dashboard.tsx` agora prefere `hub_sistemas_permitidos`, com fallback legado.
- `supabase/db/current/01_schema_full.sql` agora contem `modulos`, `papeis`, `papel_permissoes`, `usuario_papeis`, `usuario_permissao_excecoes`, `hub_pode_executar`, `hub_sistemas_permitidos` e `cross_system_session_codes`.

Observacao: `20260708_029_spec006_permissoes_granulares_hub/` foi verificada como aplicada no banco remoto e `20260708_030_spec007_sso_cross_system/` foi aplicada nesta rodada. Ambas agora estão refletidas em `db/current/`.

### 2. Connect, importacao e dados historicos

Falta implementar:

- framework de importacao idempotente com hash, lote e fila de revisao;
- promocao das linhas `VENDAS` para `vendas`, itens da venda e `projeto_itens`;
- conciliacao dos 51 codigos de projeto, 706 linhas `VENDAS` sem correspondencia e 221 produtos sem match;
- promocao de `staging_conta_pagar`, `staging_conta_receber` e `staging_pedido_compra` para tabelas operacionais;
- decisao de corte do Connect (`M12`), que continua sem data.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 38-61 e 254-262.
- `03-Projeto/02_RELATORIO_BANCO_DE_DADOS.md`.
- `supabase/db/current/09_schema_inventory.md` mostra tabelas de staging ainda presentes.

### 3. Estoque e Compras

Backend parcial ja existe, mas falta o sistema operacional:

- app/pasta/repositorio proprio de Estoque e Compras;
- telas de estoque por produto com reservado/entrega futura/transferencias/necessidade de compra;
- painel de Vitoria/Debora para aprovar transferencia e re-reservar material que chegou;
- cotacoes, pedidos, recebimentos, divergencias e confirmacao de conta a pagar;
- integracao com Logistica via fila estruturada, substituindo PDF/Teams manual;
- importacao dos movimentos historicos nao-`VENDAS`;
- frontend para devolucao/garantia/troca.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 166-187.
- Reuniao 08 em `02-Reunioes/...06.07.2026.../04_decisoes_pendencias.md`.
- `05-Mapeamento Markdown/03_debora_compras_cadastro_producao.md`.
- `05-Mapeamento Markdown/04_fluxo_comercial_faturamento_estoque.md`.

### 4. CRM

Falta implementar:

- fluxo versionado (`crm_fluxos`, `crm_etapas`, `crm_substatus`);
- checklists/tarefas/SLA/responsaveis configuraveis;
- timeline unica com eventos vindos de Orçamentos, Estoque, Financeiro e Logistica;
- gate manual de aceite/documento e plano futuro DocuSign;
- homologacao do SSO recebido por `sso_code` no login proprio atual;
- badges ricos de estoque no Card "Itens Aprovados do Projeto".

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 116-130.
- `03-Projeto/Escopos/03_ESCOPO_CRM.md`.
- `05-Mapeamento Markdown/10_validacao_cruzada_transcricoes_banco_sistemas.md`.
- `04-Sistemas/lucenera-crm-3bd29 (1)/src/App.tsx` mostra rotas implementadas, mas sem motor configuravel de workflow.

### 5. Financeiro / Administracao Bancaria

Falta implementar ou homologar:

- nova identidade/navegacao do app como Financeiro;
- `previsoes_financeiras`;
- promocao de CP/CR historicos;
- integracao com pedidos de compra;
- rotina oficial de `nosso_numero`;
- homologacao CNAB real com agencia, conta, carteira, convenio e sequencial oficial;
- emissao real de NF por provedor/API;
- migracao de PDFs para OneDrive/SharePoint;
- visao financeira por projeto;
- rotinas administrativas Lana/Caroline: tarifas, impostos, transferencias, DDA, contabilidade, folha/comissoes.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 147-164.
- `03-Projeto/Escopos/06_ESCOPO_FINANCEIRO.md`.
- `05-Mapeamento Markdown/01_lana_financeiro_administrativo.md`.
- `05-Mapeamento Markdown/02_caroline_administrativo_suprimentos.md`.

### 6. Logistica

Falta implementar:

- origem no Estoque/Compras (`EST-14`);
- vinculacao completa de separacao a `projeto_itens`;
- estados canonicos entre banco/app/processo;
- rota real, nao so simulacao visual;
- OneDrive/SharePoint para evidencias;
- devolucao/garantia como tipos operacionais;
- eventos para timeline do CRM;
- configuracoes/acessos via Sistema de TI;
- plano de corte entre `lucenera-logistica-atual-backup` e `lucenera-logistics-b7cd1`.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 189-202.
- `03-Projeto/Escopos/07_ESCOPO_LOGISTICA.md`.
- `04-Sistemas/lucenera-logistics-b7cd1/src/hooks/useSeparacaoArquivos.ts` e hooks relacionados ainda usam Supabase Storage.

### 7. Cadastro, RH e Ubiqua

Cadastro:

- concluir qualidade/deduplicacao de contatos;
- fornecedores canônicos;
- origem/ultima importacao;
- remover mocks e codigo morto de `Clientes`/`Projetos`.

RH:

- concluir consolidacao funcionario/usuario;
- remover ou isolar seed ficticio de migration;
- conectar folha/comissao ao Financeiro;
- publicar eventos/saude no Hub.

Ubiqua:

- manter fronteira separada;
- documentar tabelas exclusivas;
- identidade/permissao/saude via TI quando houver matriz central.

Evidencias:

- `03-Projeto/Planos de Ação/00_TASKS_GERAIS_ECOSSISTEMA.md`, linhas 105-114, 204-224.
- `03-Projeto/Escopos/02_ESCOPO_CADASTRO.md`.
- `03-Projeto/Escopos/08_ESCOPO_RH.md`.
- `03-Projeto/Escopos/09_ESCOPO_UBIQUA.md`.

## Seguranca e producao

Pontos que bloqueiam producao segura:

1. Rotacionar a senha registrada como exposta em migrations, citada no Adendo 03/07.
2. Revisar RLS/policies/grants, especialmente `USING (true)` em objetos novos.
3. Revisar Edge Functions com `SUPABASE_SERVICE_ROLE_KEY` (`salvar-projeto`, `update-project`, `process-budget-pdf`, `process-remittance`, `sync-sharepoint`).
4. Corrigir possivel drift de schema em Edge Functions:
   - `sync-sharepoint` referencia `tabela_precos`, ausente no inventario central consultado.
   - `generate-report` referencia `controle_ponto`, enquanto o snapshot lista `controle_falta`.
5. Padronizar variavel do dashboard: o codigo le `SUPABASE_SERVICE_ROLE_KEY`, mas mensagens/docs citam `SUPABASE_SERVICE_KEY`.

## Verificacao tecnica executada

Builds executados com sucesso nos apps que ja tinham `node_modules`:

| App | Comando | Resultado |
|---|---|---|
| `04-Sistemas/gestao-financeira-clone-544cb (1)` | `npm run build` | PASS, com aviso de bundle > 500 kB. |
| `04-Sistemas/lucenera-crm-3bd29 (1)` | `npm run build` | PASS, com aviso de bundle > 500 kB. |
| `04-Sistemas/retorno-bancario-bradesco-5392a` | `npm run build` | PASS, com aviso de bundle > 500 kB e dynamic import inefetivo em `cnab-parser.ts`. |

Lints executados:

| App | Resultado |
|---|---|
| Orçamentos | PASS com 14 warnings (`no-unused-vars`, hooks deps e imports nao usados). |
| CRM | PASS com 15 warnings (`no-unused-vars`, hooks deps e `@ts-expect-error` sem descricao). |
| Financeiro/Retorno | PASS com 7 warnings (`no-unused-vars` e hooks deps). |

Nao foram buildados localmente sem instalar dependencias:

- `central-lucenera-dashboard-1c9ba`;
- `cadastro-lucenera-b86fe`;
- `dashboard-rh-lucenera-5fe9c`;
- `lucenera-logistics-b7cd1`;
- `catalogo-pecas-ubiqua-e6fa0`.

Motivo: essas pastas nao tinham `node_modules` no espelho atual. Isso nao prova falha de build; apenas limita a verificacao local desta rodada.

## TDD e cobertura

A maior lacuna tecnica transversal e teste. Quase todos os apps usam:

```json
"test": "echo \"there are no tests for this project\" && exit 0"
```

Isso cria falso positivo de CI/teste. Para cumprir o padrao ECC/TDD, cada proxima frente precisa nascer com testes reais:

- unitarios para validacao, parsers, normalizadores e servicos;
- integracao para RPCs Supabase e Edge Functions;
- E2E Playwright para fluxos criticos: aprovacao de orcamento, retorno bancario, transferencia/devolucao de estoque, abertura via SSO, logistica com evidencia.

## Refactor-clean documental necessario

Antes de novas implementacoes grandes, limpar as fontes de confusao:

1. Atualizar/revisar `03-Projeto/00_INDICE.md` e `00_TASKS_GERAIS_ECOSSISTEMA.md` sempre que migrations locais forem aplicadas no remoto.
2. Manter `supabase/db/current/` reextraído após novas alterações remotas, para evitar nova divergencia entre documentos e snapshot.
3. Arquivar ou marcar claramente como supersedidas:
   - `SPEC-010_Rastreabilidade_Reservas_por_Cliente.md`;
   - `SPEC-011_Transferencia_Reservas_Entre_Clientes.md`.
4. Atualizar `SPEC-010_Saldos_Estoque_por_Item_de_Projeto.md`, cujo header ainda fala em hardening pendente apesar do snapshot confirmar `20260707_023`.
5. Atualizar versoes dos sistemas no checklist geral, pois os `package.json` atuais divergem de varios textos.
6. Manter o manifesto coerente quando houver nova rodada de reextração (a terceira rodada de 07/07 já atualizou `09_schema_inventory.md`).

## Ordem recomendada de implementacao

### P0 - Seguranca e verdade documental

- Rotacionar credencial exposta e revisar historico Git.
- Rodar auditoria RLS/grants.
- Atualizar documentos contraditorios antes de iniciar novas SPECs.

### P1 - Base transversal

- Homologar `SPEC-006` com dados reais de papel/módulo/ação.
- Homologar SSO da `SPEC-007`: Hub -> sistemas, CRM -> Orcamentos e Orcamentos -> Financeiro.
- Criar SPEC `HUB-06/TI-12` para eventos de acesso e auditoria de atividade.

### P1 - Estoque/Compras MVP

- Criar o app de Estoque/Compras consumindo `SPEC-010/011/012/015`.
- Implementar telas de produto, necessidade de compra, transferencia, devolucao e painel operacional.
- Definir permissoes por papel sobre a matriz ativa da `SPEC-006`.

### P1 - Historico Connect

- Implementar M01/M04: importacao idempotente e promocao das linhas `VENDAS`.
- Reconciliar produtos/projetos pendentes antes de gerar movimentos e financeiro historico.

### P2 - CRM, Logistica e Financeiro completo

- CRM configuravel e timeline.
- Logistica com origem no Estoque, OneDrive e eventos CRM.
- Financeiro com CP/CR, NF real, CNAB homologado e visao por projeto.

### P3 - Expansoes de negocio

- Portal do cliente.
- SharePoint/Planner.
- Excecoes comerciais: venda em aberto, brinde, aquisicao+devolucao.
- Ubiqua e RH integrados ao Hub/TI.

## Conclusao

O que falta nao e "mais uma tela": falta homologar e adotar a espinha dorsal compartilhada ja publicada no ambiente remoto. A sequencia mais segura e homologar permissoes/SSO, criar Estoque+Compras sobre o backend ja desenhado e so entao ampliar CRM, Logistica, Financeiro historico e Portal do Cliente.
