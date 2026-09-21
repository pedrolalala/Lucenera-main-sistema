---
titulo: "SPEC-154 — Integração Focus NFe (emissão real de Nota Fiscal a partir do sistema Vendas)"
status: implementada em código (banco + Edge Functions + frontend); pendente de passos manuais (migrations, secrets, deploy, publicação Skip, teste ao vivo)
data_ultima_modificacao: 2026-09-21
sistemas_envolvidos:
  - Vendas (vendas-lucenera) — dono da emissão, do espelho e das pendências de rejeição
  - Financeiro / Administração Bancária (retorno-bancario-bradesco-5392a) — só consumidor de leitura do status da nota (sem mudança de código neste escopo)
dependencias:
  - SPEC-153 (sistema Vendas + `notas_fiscais.cliente_id`/`nome_destinatario` + tabela `notas_fiscais_itens` + espelho DANFE — já implementada, aplicada e publicada; esta SPEC estende o mesmo `notas_fiscais` em vez de recriar)
  - SPEC-132 (campos fiscais de produtos — `ncm`, `cst`, `cest`, `tipo_fiscal`, `porc_st` já existem, reaproveitados aqui)
---

# SPEC-154 — Integração Focus NFe (emissão real de Nota Fiscal a partir do sistema Vendas)

> Origem: reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas" (decisão de usar Focus NFe) + briefing técnico completo do usuário em 2026-09-21, que fecha a política de integração (fluxo assíncrono, webhook com retry, modelo de erros/pendências) — substitui as pendências em aberto da v1 desta SPEC (CFOP, IBGE, multi-empresa continuam pendências separadas, ver seção própria).

## Checklist de Ação

### Banco (`supabase/db/migrations/YYYYMMDD_154_focus_nfe_integracao/`)

Estende `public.notas_fiscais` (já existe, colunas reais confirmadas: `id, numero_nf, serie, data_emissao, valor, arquivo_url, fornecedor, arquiteto, boleto_id, orcamento_id, tipo_operacao, perfil, cliente_id, nome_destinatario` + `notas_fiscais_itens` da SPEC-153) — **não recria nada**, só adiciona:

- [x] `notas_fiscais.ambiente text NOT NULL DEFAULT 'homologacao' CHECK (ambiente IN ('homologacao','producao'))`.
- [x] `notas_fiscais.ref text` — referência única e **imutável** da tentativa atual na Focus NFe (formato `VENDA-{numero_venda}-N{tentativa}`, ex. `VENDA-0032-N1`). `UNIQUE` quando não nulo. Reemissão após erro = nova `ref` (nunca reenviar a mesma ref com payload diferente — regra 5.2/5 do briefing).
- [x] `notas_fiscais.status_emissao text NOT NULL DEFAULT 'nao_emitida' CHECK (status_emissao IN ('nao_emitida','processando_autorizacao','autorizado','erro_autorizacao','cancelado'))`.
- [x] `notas_fiscais.status_sefaz text` — código cStat cru da SEFAZ (ex. `'100'`, `'532'`), armazenado sempre, mesmo quando o código não estiver na lista conhecida (regra 5.1 do briefing: nunca inventar, sempre guardar o que veio).
- [x] `notas_fiscais.mensagem_sefaz text` — texto oficial da Focus/SEFAZ, fonte da verdade para exibição.
- [x] `notas_fiscais.chave_nfe text` — chave de acesso real de 44 dígitos, só quando `status_emissao='autorizado'`.
- [x] `notas_fiscais.caminho_xml text` — URL do XML retornado pela Focus. **Decisão de implementação (2026-09-21)**: não foi criada uma coluna `caminho_xml` separada — o próprio item já resolvia isso no parêntese ("`arquivo_url`, já existente ... sem duplicar coluna"). `arquivo_url` passou a também guardar o link do documento autorizado devolvido pela Focus. Ver comentário no topo de `20260921_154_focus_nfe_integracao/001_notas_fiscais_focus_campos.sql`.
- [x] `notas_fiscais.payload_enviado jsonb` — snapshot do JSON de fato enviado no `POST /nfe`, para auditoria/reemissão.
- [x] `notas_fiscais.tentativa_atual integer NOT NULL DEFAULT 1`.
- [x] `notas_fiscais.ultima_consulta_em timestamptz` — usado pelo job de fallback (R3) pra saber quais notas em `processando_autorizacao` já estão "velhas" o suficiente pra consultar de novo.
- [x] Nova tabela `public.notas_fiscais_erros` (histórico completo, uma linha por tentativa que voltou com problema — nunca sobrescrita, regra 4/8 do briefing):
  - `id uuid PK default gen_random_uuid()`
  - `nota_fiscal_id uuid NOT NULL REFERENCES notas_fiscais(id)`
  - `ref text NOT NULL`
  - `numero_tentativa integer NOT NULL`
  - `status_sefaz text`
  - `mensagem_sefaz text`
  - `erro_codigo text`
  - `erro_campo text` — nome do campo do JSON que causou o erro, quando a API informar (pré-validação 400/422)
  - `resposta_bruta jsonb NOT NULL` — payload cru completo da resposta de erro, sempre preservado
  - `data_hora timestamptz NOT NULL DEFAULT now()`
  - `resolvido boolean NOT NULL DEFAULT false`
  - `data_resolucao timestamptz`
  - RLS: mesmo padrão permissivo já usado em `notas_fiscais_itens` (SPEC-153) — controle de acesso real via `hub_pode_executar` dentro das Edge Functions/RPCs, não RLS granular por linha.
- [x] Lógica na Edge Function (não RPC — decisão de implementação) pra criar a próxima tentativa: ao reemitir, `tentativa_atual += 1` só quando a rejeição anterior tinha `status_sefaz` preenchido (rejeição real, chegou na SEFAZ); quando foi só pré-validação (`status_sefaz` nulo), reaproveita a mesma tentativa/ref. Nova `ref`, mantém o histórico anterior em `notas_fiscais_erros` intocado (nunca apagar/sobrescrever, regra 8). Ver `emitir-nota-fiscal/index.ts`.
- [x] Migration de agendamento do job de fallback via `pg_cron`/`pg_net` (`20260921_154_focus_nfe_integracao/004_agendar_verificar_notas_pendentes.sql`), com placeholders `<PROJECT_REF>`/`<VAULT_SECRET_NOME>` — nenhum token real commitado.
- [x] `empresas.codigo_municipio_ibge text` nullable (`003_empresas_codigo_municipio_ibge.sql`) — confirmado que a coluna não existia antes de adicionar.

### Edge Functions novas (`04-Sistemas/vendas-lucenera/supabase/functions/`)

- [x] **`emitir-nota-fiscal`** (chamada autenticada pelo frontend de Vendas): recebe `nota_fiscal_id` (já criado como rascunho pela RPC `registrar_nota_fiscal_parcial` da SPEC-153, com itens e pagador já definidos). Monta o payload NF-e 4.00 a partir dos MESMOS dados já usados no espelho DANFE (heurística de CFOP duplicada de `danfe.ts` em `_shared/cfop.ts`, mesmo padrão já usado por `generate-report` pra `calcularParcelasPdf`) — **fonte única de montagem do payload** em `_shared/montar-payload-nfe.ts`:
  - Emitente: `orcamentos.empresa_id → empresas` (CNPJ obrigatório no payload; IE/endereço/regime tributário só usados pra validar que o cadastro está completo — ver "Decisão: dados do emitente" abaixo).
  - Destinatário: `notas_fiscais.cliente_id → contatos` (ou cliente do orçamento como fallback) ou `nome_destinatario` (texto livre).
  - Itens: `notas_fiscais_itens → orcamento_itens → produtos` (NCM/CST reais; CFOP pela heurística provisória já existente — ver "Gap de CFOP" abaixo, não resolvido nesta SPEC).
  - `ref = 'VENDA-' + numero_venda + '-N' + tentativa_atual`.
  - `POST {ambiente}/v2/nfe?ref={ref}` via HTTP Basic (token do secret, senha vazia) — `_shared/focus-client.ts`.
  - **Trata os 5 casos da política (seção 2.2 do briefing)**:
    - `201`/`202`: um único aplicador (`_shared/aplicar-resultado-focus.ts`, `aplicarStatusFocusNaNota`) trata os dois — se autorizado, grava `chave_nfe`/`numero_nf`/`serie`/`arquivo_url`; se erro, insere linha em `notas_fiscais_erros` e marca `status_emissao='erro_autorizacao'`; se `processando_autorizacao`, grava o status pendente e `ultima_consulta_em`. **Mesmo aplicador é reusado pelo webhook e pelo polling** (fonte única de verdade do mapeamento de status).
    - `400`/`422` (pré-validação, nota nunca chega na SEFAZ): insere em `notas_fiscais_erros` com `erro_campo`/`erro_codigo`/`mensagem` de cada item (parser defensivo em `normalizarErrosPreValidacao`, cobre os formatos mais comuns sem inventar estrutura); **não incrementa tentativa**.
    - `401`/`403`: erro de configuração (token/CNPJ não habilitado) — `status_emissao` não muda, mensagem própria de configuração gravada em `notas_fiscais_erros` com `erro_codigo='focus_config_401'/'focus_config_403'`.
    - `429`: backoff exponencial local (até 3 tentativas, `_shared/focus-client.ts`) antes de desistir e devolver "tente novamente" pro chamador.
    - `5xx`/timeout: mesmo retry limitado (`chamarFocusComRetry`), sem duplicar a `ref`.
  - Também bloqueia ANTES de chamar a Focus (pré-validação interna, mesmo efeito de um 400/422) quando falta `empresas.codigo_municipio_ibge`, CNPJ do emitente, CPF/CNPJ do destinatário, ou NCM/CST de algum item — nunca inventa esses dados.
  - Sempre grava `payload_enviado` (o JSON de fato mandado) antes de enviar.
- [x] **`focus-nfe-webhook`** (endpoint público, `verify_jwt=false`, sem sessão Supabase — identifica a nota pelo `ref` no corpo): recebe o POST da Focus a cada mudança de status. **Idempotente** — usa o mesmo `aplicarStatusFocusNaNota` (`UPDATE ... WHERE ref = $1`), sempre responde `2xx` mesmo em reprocessamento do mesmo evento ou erro interno inesperado (documentado no código: evita a Focus reagendar reentregas por até 24h por um evento que o job de fallback já cobre via polling). Se o status recebido for `erro_autorizacao`, insere (não substitui) uma linha em `notas_fiscais_erros` — com uma checagem de duplicata exata pra não acumular ruído em reentregas do MESMO evento. Valida o header de autorização (`Authorization: Bearer <secret>` ou `X-Focus-Webhook-Secret`) contra o secret `FOCUS_NFE_WEBHOOK_SECRET`.
- [x] **`verificar-notas-pendentes`** (job de fallback — chamado por `pg_cron`/`pg_net`, `verify_jwt=false`, autenticado por secret próprio `FOCUS_NFE_CRON_SECRET` em vez da service role key, pra não expor esse segredo mais sensível dentro do SQL do cron job): busca `notas_fiscais WHERE status_emissao = 'processando_autorizacao' AND ref IS NOT NULL AND (ultima_consulta_em IS NULL OR ultima_consulta_em < now() - interval '10 minutes')`, chama `GET /nfe/{ref}` pra cada uma, atualiza pelo mesmo `aplicarStatusFocusNaNota` do webhook.
- [ ] Registrar o gatilho de webhook na Focus NFe na primeira vez (`POST /hooks`, `{cnpj, event: 'nfe', url: <url da Edge Function>, authorization, authorization_header}`) — **passo manual do usuário** depois que a Edge Function estiver deployada (a URL só existe depois do deploy), ver Passos manuais.

### Decisão: dados cadastrais do emitente não entram no payload (2026-09-21)

Na Focus NFe, razão social/endereço/IE/regime tributário do emitente ficam cadastrados uma vez na própria conta Focus (`POST /empresas`, fora do escopo desta SPEC — passo manual do usuário). O payload de emissão (`POST /v2/nfe`) só envia `cnpj_emitente` (pra desambiguar quando um token cobre mais de um CNPJ). Os demais campos de `empresas` continuam sendo lidos e usados só pra validar que o cadastro Lucenera está completo (bloqueando emissão se faltar `codigo_municipio_ibge`, por exemplo) — ver `_shared/montar-payload-nfe.ts`.

### Decisão: token único Focus NFe (simplificação registrada, 2026-09-21)

Implementado com UM secret único (`FOCUS_NFE_TOKEN` + `FOCUS_NFE_AMBIENTE`) em vez de um secret por empresa, como a própria SPEC já previa como ponto de partida. `resolverConfigFocus` (`_shared/focus-client.ts`) já recebe `empresa_id` como parâmetro, mesmo sem usar, pra não precisar redesenhar a assinatura quando a estrutura multi-empresa for implementada de verdade — só trocar o corpo da função.

### Decisão: defaults de integração para campos que `produtos`/`orcamentos` não modelam (2026-09-21)

Sem virar "dado fiscal inventado" (o `payload_enviado` gravado deixa isso auditável): `pis_situacao_tributaria`/`cofins_situacao_tributaria` default `'99'` (produto não tem CST de PIS/COFINS cadastrado), `icms_origem` default `'0'` (nacional), `presenca_comprador` default `'9'`, `indicador_inscricao_estadual_destinatario` derivado de ter/não ter IE cadastrada, `modalidade_frete` derivado de `orcamentos.frete_tipo`. Todos documentados em `_shared/montar-payload-nfe.ts` e devolvidos em `avisos` (não bloqueiam emissão, ao contrário dos `bloqueantes`).

### Frontend (`04-Sistemas/vendas-lucenera`)

- [x] Modal "Emitir Nota Fiscal" (`Vendas.tsx`): depois de `registrar_nota_fiscal_parcial` criar o rascunho da nota (fluxo já existente da SPEC-153, itens + pagador), adicionar um passo/botão **"Confirmar e Emitir via Focus NFe"** que chama a Edge Function `emitir-nota-fiscal`. O espelho (`DanfePreview.tsx`) já mostrado antes desse passo passa a ser explicitamente a tela de confirmação (R1) — nenhuma duplicação de lógica de montagem de payload entre o espelho e a Edge Function (o espelho lê os mesmos dados; a Edge Function é quem de fato serializa pro formato Focus). Implementado como um terceiro passo `nfStep === 'emissao'` (`src/lib/focus-nfe.ts` faz o `fetch` cru autenticado; `Vendas.tsx::handleConfirmarEmissao` decide o que mostrar pra cada um dos formatos de resposta documentados em `emitir-nota-fiscal/index.ts`).
- [x] Depois de emitir, mostrar o status em tempo real: "Processando autorização..." (202), "Autorizado" com link pro XML/DANFE (201/webhook confirmando), ou "Erro" com a `mensagem_sefaz` completa e um botão "Corrigir e reemitir" (abre o formulário de novo, nova tentativa). Implementado: `processando`/`sucesso` (com link `arquivo_url` + `chave_nfe`, relidos de `notas_fiscais` após a chamada, já que a Edge Function não repete esses campos na resposta) / `pre_validacao_interna` e `pre_validacao_focus` (lista de bloqueantes/erros, botão "Corrigir e tentar novamente" volta pro passo `form`) / `configuracao` e `retry_esgotado` (mensagem diferenciada + botão "Tentar novamente" que reemite a MESMA nota rascunho, sem criar duplicata).
- [x] Tela/aba nova **"Pendências de Nota Fiscal"** (`src/pages/PendenciasNotaFiscal.tsx`, rota `/pendencias-nota-fiscal`, link no header de `Layout.tsx`): lista `notas_fiscais_erros WHERE resolvido = false` com join até `notas_fiscais → orcamentos.numero_venda`, ordenado por `data_hora desc`. "Marcar como resolvido" continua implícito (feito pela Edge Function, não pelo frontend) — botão "Ver venda" navega para `/vendas?venda=<orcamento_id>`, que abre automaticamente o espelho daquela venda (`Vendas.tsx`, efeito novo lendo `useSearchParams`).
- [x] Exibir o status mínimo da nota (pendente/processando/autorizado/erro/cancelado) na listagem principal de Vendas (`statusNota`, já existe — estender pra refletir `status_emissao` real em vez de só "tem nota"/"não tem nota"). Implementado de forma aditiva: quando a nota mais recente da venda (`notaMaisRecente`, por `created_at`) está `processando_autorizacao` ou `erro_autorizacao`, o badge da listagem principal mostra isso (e desabilita o botão "Emitir Nota Fiscal" só no caso `processando`); caso contrário mantém a lógica original de completa/parcial/pendente.

### Integração com outros módulos (R5)

- [ ] **Sem mudança de código na Administração Bancária nesta SPEC** — só deixar `notas_fiscais.status_emissao` legível (já é, é uma coluna normal na tabela compartilhada) para quando fizer sentido ela consultar se a nota foi autorizada antes de liberar algo. Não decidido nem necessário agora.

### Gap de CFOP (não decido a regra completa sozinho — herdado da v1 desta SPEC)

- Mesma heurística provisória já em produção desde a SPEC-153 (`cfopHeuristico` em `danfe.ts`, `porc_st > 0 ? '5405' : '5102'`) — só intra-estado, sem tratar interestadual. **Continua sendo a pendência mais crítica antes de emitir em produção real**: precisa de validação com contador/Vinícius. Até lá, toda emissão desta SPEC roda em `ambiente = 'homologacao'`.

### Gap de endereço fiscal do emitente (IBGE) — herdado da v1

- `empresas` não tem `codigo_municipio_ibge`. Migration desta SPEC inclui `empresas.codigo_municipio_ibge text` nullable — preenchimento manual do usuário antes da primeira emissão real.

### Gap de múltiplas empresas emissoras — herdado da v1

- Cada empresa emissora real (Foco/Manoella/Islight) precisa de token próprio na Focus NFe. Proposta mantida: secret por empresa (`FOCUS_NFE_TOKEN_<slug_empresa>_<AMBIENTE>`), resolvido na Edge Function a partir de `empresas.codigo`/`cnpj`. Estrutura final depende de quantas contas o usuário efetivamente criar (ver Passos manuais).

### Passos manuais do usuário

- [ ] **Criar conta(s) Focus NFe** e obter token(s) de homologação (produção só depois de validar CFOP).
- [ ] **Configurar secrets nas Edge Functions** (`FOCUS_NFE_TOKEN`, `FOCUS_NFE_AMBIENTE`, `FOCUS_NFE_WEBHOOK_SECRET`, `FOCUS_NFE_CRON_SECRET`) — nunca em código/`.env` versionado. Implementado com token único por enquanto (ver "Decisão: token único Focus NFe" acima), não `FOCUS_NFE_TOKEN_<slug_empresa>_<AMBIENTE>` por empresa.
- [ ] Aplicar as 4 migrations desta SPEC (`supabase/db/migrations/20260921_154_focus_nfe_integracao/`), na ordem 001→004 (a 004 só depois do deploy das Edge Functions e do secret do Vault).
- [ ] **Deploy das 3 Edge Functions** (`emitir-nota-fiscal`, `focus-nfe-webhook`, `verificar-notas-pendentes`).
- [ ] **Registrar o webhook na Focus NFe** (`POST /hooks`) apontando pra URL real da Edge Function, só depois do deploy.
- [ ] **Agendar `verificar-notas-pendentes` via `pg_cron`** (migration própria, `cron.schedule(...)`, chama a Edge Function via `pg_net`).
- [ ] **Preencher `empresas.codigo_municipio_ibge`** pra cada empresa emissora.
- [ ] **Validar a tabela de CFOP com contador/Vinícius** antes de qualquer emissão em produção real.
- [ ] **Decidir a política de pagador sem CPF/CNPJ** em nota parcial (bloquear emissão real vs. manter como nota interna/espelho) — decisão de negócio, não decidida nesta SPEC.
- [ ] Testar emissão ponta a ponta em homologação com uma venda de teste antes de liberar uso real.

## Objetivo

Substituir a pendência crônica "decidir ferramenta/API de emissão de nota fiscal" por uma integração real e completa com Focus NFe: emissão assíncrona com tratamento de todos os status possíveis (síncrono, processando, pré-validação, rejeição), webhook idempotente com fallback por polling, e um registro de pendências/erros com histórico completo por tentativa — nunca perdendo rastreabilidade de uma rejeição.

## Decisões aprovadas

- Provedor: **Focus NFe**, API v2, NF-e modelo 4.00.
- Ambiente de homologação até confirmação explícita de virada para produção (bloqueado também pela validação de CFOP, que é regra fiscal sensível).
- Emissão sempre via Edge Function — token nunca exposto no frontend.
- `ref` é única e imutável por tentativa; reemissão = nova `ref`, histórico anterior nunca apagado.
- Webhook deve ser idempotente (a Focus reenvia em 1min/30min/1h/3h/24h se não receber 2xx).
- Nenhum código/mensagem de rejeição é inventado — tudo vem literalmente da resposta da API e é armazenado, mesmo quando o código não é reconhecido.
- Job de fallback (polling) usa `pg_cron`/`pg_net`, já habilitados no projeto — não precisa de infraestrutura externa nova.
- Administração Bancária não é alterada nesta SPEC (R5) — só fica com a leitura de status disponível pra uso futuro.

## Análise de ecossistema (obrigatória)

- **Depende de** `orcamentos` (empresa emitente), `contatos` (destinatário), `produtos` (NCM/CST/CFOP), `notas_fiscais`/`notas_fiscais_itens` (SPEC-153, estendidas aqui) e `empresas` (nova coluna IBGE).
- **Afeta**: Vendas (principal — nova tela de pendências, novo fluxo de emissão), Financeiro/Administração Bancária (nenhuma mudança de código, só leitura futura opcional).
- **Dado duplicado que deveria ser derivado?** `payload_enviado`/`resposta_bruta` são snapshots intencionais (auditoria/rastreabilidade fiscal), não duplicação indevida — o que foi de fato enviado/recebido numa tentativa específica não pode mudar retroativamente mesmo que a lógica de montagem do payload mude depois.
- **Migration antiga que contradiz o snapshot central?** Mesma observação já registrada nas SPECs 152/153 — `supabase/db/current/` está desatualizado; as colunas reais de `notas_fiscais` usadas aqui foram confirmadas direto no banco (não pelo snapshot desatualizado).
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim — do sistema Vendas (novas tabelas/colunas, novas Edge Functions, novo job `pg_cron`).
- **Padrão de acesso a dados**: Edge Functions seguem o padrão já estabelecido no ecossistema (`generate-report`, etc.) — lógica de integração externa isolada em Deno, nunca no frontend. Chamada de banco por `pg_cron`/`pg_net` é um padrão novo neste ecossistema (nenhum outro sistema usa job agendado no Postgres ainda) — documentar isso no `AI_DB_CONTEXT.md` como precedente.

## Realizado

**2026-09-21 — Frontend implementado (implementador, tarefa separada da anterior). Banco + Edge Functions já estavam prontos e revisados (etapa anterior do mesmo dia) — nenhum arquivo de banco/Edge Function foi tocado nesta etapa.**

- `04-Sistemas/vendas-lucenera/src/lib/focus-nfe.ts` (novo): helper `emitirNotaFiscal(notaFiscalId, accessToken)` — mesmo padrão de `fetch` autenticado já usado em `gestao-financeira-clone-544cb/src/lib/envio-inicial-cliente.ts::downloadBudgetPdf` (Authorization: Bearer `<access_token>` da sessão do usuário via `useAuth()`; token da Focus nunca passa pelo frontend). Sempre tenta parsear o corpo como JSON, mesmo em respostas de erro HTTP, porque a Edge Function sempre devolve JSON.
- `04-Sistemas/vendas-lucenera/src/pages/Vendas.tsx`:
  - `NotaFiscal` (interface) e a query de `fetchVendas` ganharam os campos novos de `notas_fiscais` (`status_emissao`, `status_sefaz`, `mensagem_sefaz`, `chave_nfe`, `arquivo_url`, `ref`, `created_at`).
  - Modal "Emitir Nota Fiscal" ganhou um terceiro passo (`nfStep: 'preview' | 'form' | 'emissao'`): `handleRegistrar` não fecha mais o modal depois de `registrar_nota_fiscal_parcial` — guarda o `nota_fiscal_id` retornado e avança pro passo `emissao`, onde `handleConfirmarEmissao` chama `emitir-nota-fiscal` e trata os 6 formatos de resultado (`sucesso`, `processando`, `pre_validacao_interna`, `pre_validacao_focus`, `configuracao`, `retry_esgotado`, `erro_generico`) num type `EmissaoResultado` discriminado por `tipo`.
  - `statusNota()` estendida (aditiva) com `notaMaisRecente()` — reflete `status_emissao` da nota mais recente da venda quando está `processando_autorizacao` ou `erro_autorizacao`, sem alterar a lógica original de completa/parcial/pendente.
  - Novo efeito sincroniza `vendaAtual` com a lista `vendas` sempre que ela é recarregada (necessário porque o modal agora fica aberto entre os 3 passos, atravessando refetches).
  - Novo efeito lê `?venda=<orcamento_id>` da URL (chegando da tela de Pendências) e abre automaticamente o espelho daquela venda.
  - Lista "Notas já emitidas" (passo `preview`) ganhou um badge de `status_emissao` por nota.
- `04-Sistemas/vendas-lucenera/src/pages/PendenciasNotaFiscal.tsx` (novo): lista `notas_fiscais_erros WHERE resolvido = false` com join até `notas_fiscais.orcamento_id → orcamentos.numero_venda`, ordenado por `data_hora desc`. Botão "Ver venda" navega para `/vendas?venda=<orcamento_id>`.
- `04-Sistemas/vendas-lucenera/src/App.tsx`: rota `/pendencias-nota-fiscal` registrada dentro do mesmo `ProtectedRoute` (mesma checagem de acesso ao sistema `vendas` via `hub_pode_executar`, sem RBAC fino separado — igual ao resto do sistema).
- `04-Sistemas/vendas-lucenera/src/components/Layout.tsx`: header ganhou um nav de 2 links (Vendas / Pendências de Nota Fiscal) — antes só tinha logo + botões de sair/central, porque o sistema nascia com uma única tela.
- `npm run lint` (`oxlint src`): sem erros — só os 2 warnings pré-existentes de `react-hooks/exhaustive-deps` no padrão `fetchX` dentro de `useEffect(() => { fetchX() }, [])` (mesmo padrão já usado no resto do arquivo antes desta SPEC, replicado na tela nova).
- `npm run build` (`vite build`): compilou sem erro (13.5s), só o aviso genérico de chunk >500kB (pré-existente, não é desta mudança).

### Decisões de implementação do frontend (2026-09-21)

- **"Corrigir e tentar novamente" tem 2 comportamentos diferentes por tipo de erro** (decisão técnica, não de negócio): para `pre_validacao_interna`/`pre_validacao_focus` (dados errados/incompletos), o botão volta pro passo `form` — a nota rascunho já criada permanece como está (histórico nunca é apagado, mesma filosofia da SPEC), o usuário pode registrar uma nova tentativa depois de corrigir o pagador/itens. Para `configuracao`/`retry_esgotado` (problema não relacionado aos dados da venda), o botão reemite a MESMA nota rascunho via `handleConfirmarEmissao` de novo, sem passar pelo formulário — evita criar uma nota fiscal duplicada por um problema que não tem nada a ver com os dados preenchidos.
- **Link do XML/DANFE e chave de acesso não vêm na resposta da Edge Function** (201/202) — só são gravados direto em `notas_fiscais` por `aplicarStatusFocusNaNota`. O frontend faz uma releitura pontual de `notas_fiscais` logo depois da chamada pra mostrar esses dados, em vez de esperar o usuário atualizar a página.
- **RBAC da tela "Pendências de Nota Fiscal"**: mesma checagem de sistema (`hub_pode_executar('vendas', null, null)`) de qualquer outra tela de Vendas — não foi criada uma ação (`p_acao`) separada pra ler pendências, já que a leitura de `notas_fiscais_erros` não é mais sensível que o resto do sistema (RLS da tabela é permissiva pra `authenticated`, mesmo padrão já documentado na migration 002).

**Achado do revisor corrigido (2026-09-21) — rascunho de nota rejeitado ficava preso pra sempre.** `registrar_nota_fiscal_parcial` (RPC da SPEC-153) sempre INSERE uma `notas_fiscais`+itens nova, nunca atualiza um rascunho existente; e `jaFaturado()` soma `quantidade_faturada` de TODAS as notas da venda, sem filtrar por `status_emissao`. Sem correção, clicar "Corrigir e tentar novamente" (ou simplesmente fechar o modal no meio da emissão) criava/deixava um rascunho órfão que continuava contando como "já faturado" pra sempre, reduzindo silenciosamente a quantidade disponível da venda mesmo sem nenhuma nota autorizada pela SEFAZ. Corrigido com `cancelarRascunhoSeNecessario()` em `Vendas.tsx`: deleta o rascunho atual (`notas_fiscais_itens` cai junto via `ON DELETE CASCADE`) sempre que o usuário sai do passo de emissão sem uma nota `autorizado`/`processando_autorizacao` de verdade — cobre os 3 pontos de saída (botão "Corrigir e tentar novamente", botão "Fechar", e fechar clicando fora/Esc via `onOpenChange` do Dialog). Build/lint confirmados sem erro novo depois do fix.
- **Achado do revisor corrigido (2026-09-21) — `error` do refetch pós-emissão não era checado.** Mesmo padrão já corrigido no backend (achado anterior desta SPEC) não tinha sido replicado no frontend: a releitura de `notas_fiscais` pra pegar `chave_nfe`/`arquivo_url`/`numero_nf` depois de um 201/202 não checava `error`. Corrigido: agora loga e avisa o usuário ("nota processada, mas os detalhes não carregaram — confira a listagem") em vez de mostrar um card de sucesso silenciosamente incompleto.

- Migration rascunho em `supabase/db/migrations/20260921_154_focus_nfe_integracao/` (4 arquivos: `001_notas_fiscais_focus_campos.sql`, `002_notas_fiscais_erros.sql`, `003_empresas_codigo_municipio_ibge.sql`, `004_agendar_verificar_notas_pendentes.sql`) — **NÃO aplicada no Supabase real** (regra do agente implementador: aplicação é sempre passo manual do usuário).
- 3 Edge Functions em `04-Sistemas/vendas-lucenera/supabase/functions/` (`emitir-nota-fiscal`, `focus-nfe-webhook`, `verificar-notas-pendentes`) + módulos compartilhados em `supabase/functions/_shared/` (`cors.ts`, `cfop.ts`, `focus-client.ts`, `aplicar-resultado-focus.ts`, `montar-payload-nfe.ts`) — **NÃO deployadas**.
- `04-Sistemas/vendas-lucenera/supabase/AI_DB_CONTEXT.md` atualizado com a seção "SPEC-154 — Integração Focus NFe".
- Build (`vite build`) e lint (`oxlint src`) do sistema Vendas rodados e OK — nenhum arquivo `.tsx`/frontend foi tocado nesta tarefa, então o resultado era esperado (só confirma que nada quebrou). **Correção (2026-09-21, revisor)**: `deno check` de fato roda neste ambiente via `npx -y deno` — rodado nos 3 entrypoints (que importam todo `_shared/*`), passou limpo, exit code 0, zero erro de tipo/sintaxe.
- **Achado do revisor corrigido (2026-09-21)**: `emitir-nota-fiscal/index.ts` não checava o retorno de `error` em nenhum `.update()`/`.insert()` do Supabase. Corrigido: os pontos que só registram histórico (`notas_fiscais_erros`) agora logam o erro (`console.error`) sem abortar, já que a resposta da Focus já foi obtida e o usuário deve saber o resultado mesmo se o nosso registro falhar; o ponto mais sensível — gravar `payload_enviado` **antes** de chamar a Focus (regra explícita da SPEC) — agora **aborta** a emissão se esse registro falhar, em vez de transmitir uma nota fiscal sem rastro auditável do que foi enviado. Mesmo achado, consequência mais branda, corrigido em `_shared/aplicar-resultado-focus.ts` (checagem de duplicata antes de inserir erro).
- Decisões de implementação registradas nesta SPEC (ver seções "Decisão: ..." acima no Checklist): não criar coluna `caminho_xml` separada (reusa `arquivo_url`); dados cadastrais do emitente não entram no payload de emissão (só `cnpj_emitente`, resto fica cadastrado na conta Focus); token único `FOCUS_NFE_TOKEN` em vez de um por empresa; defaults documentados para PIS/COFINS CST, ICMS origem, presença do comprador, modalidade de frete e indicador de IE do destinatário (campos que `produtos`/`orcamentos` ainda não modelam); `verificar-notas-pendentes` autenticado por secret próprio (`FOCUS_NFE_CRON_SECRET`) em vez da service role key, para não expor esse segredo mais sensível dentro do SQL do `pg_cron`.
- Pré-validação interna implementada em `emitir-nota-fiscal`/`_shared/montar-payload-nfe.ts`: bloqueia a emissão (sem chamar a Focus) quando falta `empresas.codigo_municipio_ibge`, CNPJ do emitente, CPF/CNPJ do destinatário, ou NCM/CST de algum item — nunca envia payload incompleto/inventado.

### Passos manuais pendentes (nenhum executado por mim, por regra)

- Aplicar as 4 migrations no Supabase real (nesta ordem: 001, 002, 003, 004 — a 004 só depois do deploy das Edge Functions e da criação do secret do Vault).
- Criar conta(s) Focus NFe e obter token(s) de homologação.
- Configurar os secrets nas Edge Functions: `FOCUS_NFE_TOKEN`, `FOCUS_NFE_AMBIENTE`, `FOCUS_NFE_WEBHOOK_SECRET`, `FOCUS_NFE_CRON_SECRET`.
- Deploy das 3 Edge Functions.
- Registrar o webhook na Focus NFe (`POST /hooks`) apontando pra URL real, só depois do deploy.
- Criar o secret no Vault do Postgres (mesmo valor de `FOCUS_NFE_CRON_SECRET`) e então aplicar a migration 004 com `<PROJECT_REF>`/`<VAULT_SECRET_NOME>` substituídos.
- Preencher `empresas.codigo_municipio_ibge` por empresa emissora.
- Validar a tabela de CFOP com contador/Vinícius antes de qualquer emissão em produção real.
- Publicar o frontend novo no Skip (sistema Vendas) — feito nesta etapa só em código, não publicado.
- Testar manualmente no navegador, depois de aplicar as migrations/secrets/deploy acima (golden path que eu não consigo confirmar sozinho):
  - Emitir uma nota fiscal completa: "Emitir Nota Fiscal" → preview → form → "Registrar Nota Fiscal (rascunho)" → "Confirmar e Emitir via Focus NFe" → conferir que aparece "Processando autorização..." ou "Autorizado" (depende do tempo de resposta real da Focus em homologação).
  - Forçar um caso de pré-validação interna (ex. produto sem NCM) e conferir que a lista de bloqueantes aparece certa, e que "Corrigir e tentar novamente" volta pro formulário.
  - Conferir que a tela "Pendências de Nota Fiscal" (`/pendencias-nota-fiscal`) lista o erro acima, e que "Ver venda" abre o espelho da venda certa.
  - Conferir que o badge de status na listagem principal de Vendas muda para "Processando emissão"/"Erro na emissão" conforme o caso.
- Testar emissão ponta a ponta em homologação com uma venda de teste (só depois de todos os passos acima).
- Rodar o agente `revisor` antes de qualquer commit.

## Pendências

- [ ] Tabela completa de CFOP (intra/interestadual, ST, finalidade) — validação com contador/Vinícius antes de emissão real.
- [ ] Política de pagador sem CPF/CNPJ em nota parcial — implementado como **bloqueio** de emissão real na pré-validação interna (decisão técnica, não decisão de negócio: a Focus rejeitaria mesmo assim). A decisão de negócio de fundo (permitir nota interna/espelho sem emitir de verdade, tratar de outra forma) continua em aberto.
- [ ] Estrutura final de múltiplos tokens Focus NFe por empresa emissora (depende de quantas contas o usuário criar) — implementado com token único por enquanto, `resolverConfigFocus` já preparado pra extensão sem redesenho.
- [ ] Confirmar `empresas.codigo_municipio_ibge` preenchido antes da primeira emissão real.
- [ ] Confirmar cobertura real de `produtos.ncm` (percentual de produtos com valor preenchido) — verificação manual, não posso rodar como planner/implementador sem acesso amplo de leitura.
- [x] Frontend desta SPEC (modal "Emitir Nota Fiscal" com o botão "Confirmar e Emitir via Focus NFe", status em tempo real, tela "Pendências de Nota Fiscal", `statusNota` refletindo `status_emissao`) — implementado 2026-09-21 (tarefa separada). Falta só o teste ao vivo (ponta a ponta em homologação, depois de todos os passos manuais de banco/secrets/deploy) e a publicação no Skip.
- [ ] Exatidão do schema exato de payload da Focus NFe (nomes de campo do `POST /v2/nfe`) não foi validada contra a documentação oficial nem contra um ambiente de homologação real — montada com base em conhecimento geral da API pública da Focus; testar ponta a ponta em homologação é obrigatório antes de qualquer uso real, e pode exigir ajustes pontuais em `_shared/montar-payload-nfe.ts`.
