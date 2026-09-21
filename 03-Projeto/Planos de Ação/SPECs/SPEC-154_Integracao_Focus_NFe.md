---
titulo: "SPEC-154 — Integração Focus NFe (emissão real de Nota Fiscal a partir do sistema Vendas)"
status: especificação fechada, pronta para implementar
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

- [ ] `notas_fiscais.ambiente text NOT NULL DEFAULT 'homologacao' CHECK (ambiente IN ('homologacao','producao'))`.
- [ ] `notas_fiscais.ref text` — referência única e **imutável** da tentativa atual na Focus NFe (formato `VENDA-{numero_venda}-N{tentativa}`, ex. `VENDA-0032-N1`). `UNIQUE` quando não nulo. Reemissão após erro = nova `ref` (nunca reenviar a mesma ref com payload diferente — regra 5.2/5 do briefing).
- [ ] `notas_fiscais.status_emissao text NOT NULL DEFAULT 'nao_emitida' CHECK (status_emissao IN ('nao_emitida','processando_autorizacao','autorizado','erro_autorizacao','cancelado'))`.
- [ ] `notas_fiscais.status_sefaz text` — código cStat cru da SEFAZ (ex. `'100'`, `'532'`), armazenado sempre, mesmo quando o código não estiver na lista conhecida (regra 5.1 do briefing: nunca inventar, sempre guardar o que veio).
- [ ] `notas_fiscais.mensagem_sefaz text` — texto oficial da Focus/SEFAZ, fonte da verdade para exibição.
- [ ] `notas_fiscais.chave_nfe text` — chave de acesso real de 44 dígitos, só quando `status_emissao='autorizado'`.
- [ ] `notas_fiscais.caminho_xml text` — URL do XML retornado pela Focus (`arquivo_url`, já existente, passa a guardar o caminho do DANFE/PDF autorizado — sem duplicar coluna).
- [ ] `notas_fiscais.payload_enviado jsonb` — snapshot do JSON de fato enviado no `POST /nfe`, para auditoria/reemissão.
- [ ] `notas_fiscais.tentativa_atual integer NOT NULL DEFAULT 1`.
- [ ] `notas_fiscais.ultima_consulta_em timestamptz` — usado pelo job de fallback (R3) pra saber quais notas em `processando_autorizacao` já estão "velhas" o suficiente pra consultar de novo.
- [ ] Nova tabela `public.notas_fiscais_erros` (histórico completo, uma linha por tentativa que voltou com problema — nunca sobrescrita, regra 4/8 do briefing):
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
- [ ] RPC ou lógica na Edge Function pra criar a próxima tentativa: ao reemitir, `tentativa_atual += 1`, nova `ref`, mantém o histórico anterior em `notas_fiscais_erros` intocado (nunca apagar/sobrescrever, regra 8).

### Edge Functions novas (`04-Sistemas/vendas-lucenera/supabase/functions/`)

- [ ] **`emitir-nota-fiscal`** (chamada autenticada pelo frontend de Vendas): recebe `nota_fiscal_id` (já criado como rascunho pela RPC `registrar_nota_fiscal_parcial` da SPEC-153, com itens e pagador já definidos). Monta o payload NF-e 4.00 a partir dos MESMOS dados já usados no espelho DANFE (`DanfePreview.tsx`/`danfe.ts` da SPEC-153) — **fonte única de montagem do payload** (regra R1 do briefing: o espelho e o payload real nunca podem divergir):
  - Emitente: `orcamentos.empresa_id → empresas` (CNPJ, IE, endereço, regime tributário).
  - Destinatário: `notas_fiscais.cliente_id → contatos` ou `nome_destinatario` (texto livre).
  - Itens: `notas_fiscais_itens → orcamento_itens → produtos` (NCM/CST reais; CFOP pela heurística provisória já existente — ver "Gap de CFOP" abaixo, não resolvido nesta SPEC).
  - `ref = 'VENDA-' + numero_venda + '-N' + tentativa_atual`.
  - `POST {ambiente}/nfe?ref={ref}` via HTTP Basic (token do secret, senha vazia).
  - **Trata os 5 casos da política (seção 2.2 do briefing)**:
    - `201` (síncrono, autorizado ou erro já resolvido): grava direto — se autorizado, `chave_nfe`/`numero_nf`/`serie`/`caminho_xml`/`arquivo_url`; se erro, insere linha em `notas_fiscais_erros` e marca `status_emissao='erro_autorizacao'`.
    - `202` (`processando_autorizacao`): grava o status pendente, `ultima_consulta_em = now()`; resultado final só chega por webhook ou pelo job de fallback (R3).
    - `400`/`422` (pré-validação, nota nunca chega na SEFAZ): insere em `notas_fiscais_erros` com `erro_campo`/`erro_codigo`/`mensagem` de cada item de `erros[]`; **não incrementa tentativa** (não houve envio real à SEFAZ, o usuário só precisa corrigir e reenviar com a mesma tentativa — decisão de implementação, documentar no código).
    - `401`/`403`: erro de configuração (token/CNPJ não habilitado) — não é erro da venda, avisar o usuário de forma diferente (mensagem de configuração, não de rejeição fiscal).
    - `429`: backoff exponencial (regra 7 do briefing) — reagenda a chamada, não falha direto pro usuário.
    - `5xx`/timeout: retry limitado com log estruturado (regra 5.2/5), sem duplicar a `ref`.
  - Sempre grava `payload_enviado` (o JSON de fato mandado) antes de enviar.
- [ ] **`focus-nfe-webhook`** (endpoint público, sem sessão Supabase — identifica a nota pelo `ref` no corpo): recebe o POST da Focus a cada mudança de status. **Idempotente** (regra 3/5.3 do briefing: a Focus reenvia em 1min/30min/1h/3h/24h se não receber 2xx) — faz `UPDATE ... WHERE ref = $1` (upsert por ref, nunca duplica), sempre responde `2xx` mesmo em reprocessamento do mesmo evento. Se o status recebido for `erro_autorizacao`, insere (não substitui) uma linha em `notas_fiscais_erros`. Valida o cabeçalho de autenticação do hook (`authorization`/`authorization_header`, configurados na criação do hook — secret próprio, nunca hardcoded).
- [ ] **`verificar-notas-pendentes`** (job de fallback — chamado por `pg_cron`, extensão **já habilitada** no projeto, confirmado via `pg_extension`, junto com `pg_net`): roda periodicamente (proposta: a cada 15 min), busca `notas_fiscais WHERE status_emissao = 'processando_autorizacao' AND (ultima_consulta_em IS NULL OR ultima_consulta_em < now() - interval '10 minutes')`, chama `GET /nfe/{ref}` pra cada uma, atualiza como o webhook faria. É rede de segurança pro caso do webhook falhar/atrasar além do último retry da Focus (24h).
- [ ] Registrar o gatilho de webhook na Focus NFe na primeira vez (`POST /hooks`, `{cnpj, event: 'nfe', url: <url da Edge Function>, authorization, authorization_header}`) — **passo manual do usuário** depois que a Edge Function estiver deployada (a URL só existe depois do deploy), ver Passos manuais.

### Frontend (`04-Sistemas/vendas-lucenera`)

- [ ] Modal "Emitir Nota Fiscal" (`Vendas.tsx`): depois de `registrar_nota_fiscal_parcial` criar o rascunho da nota (fluxo já existente da SPEC-153, itens + pagador), adicionar um passo/botão **"Confirmar e Emitir via Focus NFe"** que chama a Edge Function `emitir-nota-fiscal`. O espelho (`DanfePreview.tsx`) já mostrado antes desse passo passa a ser explicitamente a tela de confirmação (R1) — nenhuma duplicação de lógica de montagem de payload entre o espelho e a Edge Function (o espelho lê os mesmos dados; a Edge Function é quem de fato serializa pro formato Focus).
- [ ] Depois de emitir, mostrar o status em tempo real: "Processando autorização..." (202), "Autorizado" com link pro XML/DANFE (201/webhook confirmando), ou "Erro" com a `mensagem_sefaz` completa e um botão "Corrigir e reemitir" (abre o formulário de novo, nova tentativa).
- [ ] Tela/aba nova **"Pendências de Nota Fiscal"**: lista `notas_fiscais_erros WHERE resolvido = false`, agrupado por nota, com histórico de tentativas anteriores visível (nunca escondido). Ação "Marcar como resolvido" fica implícita quando uma nova tentativa da mesma nota é autorizada (a Edge Function marca as pendências anteriores daquela `nota_fiscal_id` como `resolvido=true, data_resolucao=now()` ao gravar sucesso).
- [ ] Exibir o status mínimo da nota (pendente/processando/autorizado/erro/cancelado) na listagem principal de Vendas (`statusNota`, já existe — estender pra refletir `status_emissao` real em vez de só "tem nota"/"não tem nota").

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
- [ ] **Configurar secrets no Supabase** (`FOCUS_NFE_TOKEN_...`) — nunca em código/`.env` versionado.
- [ ] Aplicar as migrations desta SPEC.
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

_(nada implementado ainda — SPEC fechada, pronta pra implementar)_

## Pendências

- [ ] Tabela completa de CFOP (intra/interestadual, ST, finalidade) — validação com contador/Vinícius antes de emissão real.
- [ ] Política de pagador sem CPF/CNPJ em nota parcial.
- [ ] Estrutura final de múltiplos tokens Focus NFe por empresa emissora (depende de quantas contas o usuário criar).
- [ ] Confirmar `empresas.codigo_municipio_ibge` preenchido antes da primeira emissão real.
- [ ] Confirmar cobertura real de `produtos.ncm` (percentual de produtos com valor preenchido) — verificação manual, não posso rodar como planner/implementador sem acesso amplo de leitura.
