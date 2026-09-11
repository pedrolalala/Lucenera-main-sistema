# Auditoria - SPEC-130/131 Sincronizacao em Duas Vias Projetos x SharePoint

**Data:** 2026-09-11
**Revisor:** agente revisor (independente, sem aplicar/editar nada)
**Escopo:** supabase/db/migrations/20260911_132_sharepoint_projetos_sync_2via/ (001 a 011),
supabase/functions/sharepoint-projetos-push/index.ts,
supabase/functions/sharepoint-projetos-pull/index.ts,
SPEC-130 e SPEC-131.

**Contexto critico:** a migration 001-011 ja rodou no Supabase real (vcvcwzmbiftcawncibke)
e as 2 Edge Functions ja estao deployadas. Qualquer correcao abaixo relativa aos arquivos
001-011 nao pode ser feita editando esses arquivos - exige uma migration nova (012 em
diante). O achado de escala do pull (timeout de 5s do pg_net em lista com 3781 itens,
cron pausado) ja e pendencia conhecida e nao e repetido aqui.

---

## Critico

### 1. Push sem protecao contra duplicidade em falha parcial ou corrida concorrente

supabase/functions/sharepoint-projetos-push/index.ts decide "criar vs. atualizar" olhando
so projeto.sharepoint_item_id (lido do banco no inicio da execucao). Nao existe nenhuma etapa
equivalente a do CNAB (hash + RPC transacional) que impeca reprocessamento inseguro:

- Falha parcial real: se o POST no Graph tiver sucesso (item criado) e a chamada seguinte a
  RPC confirmar_push_sharepoint falhar por qualquer motivo (rede, timeout, erro do Postgres),
  o catch do index.ts (linhas ~205-219) grava um log de erro SEM sharepoint_item_id (a
  variavel e local ao bloco try, nunca e referenciada no catch) e retorna 500 - mas o banco
  nunca fica sabendo do item ja criado. Na proxima edicao desse projeto, a trigger dispara de
  novo, sharepoint_item_id continua NULL, e o push cria um SEGUNDO item na lista para o mesmo
  projeto. O indice unico uq_projetos_sharepoint_item_id (001) impede que os dois IDs fiquem
  amarrados ao mesmo projeto - um dos dois itens fica orfao pra sempre, e como o POST de
  criacao e o gatilho da automacao de pasta/Teams/Planner (SPEC-131), isso duplica tambem a
  automacao externa.
- Corrida concorrente: duas edicoes quase simultaneas de um projeto recem-criado (ainda com
  sharepoint_item_id = NULL) podem originar duas execucoes da function em paralelo; ambas leem
  sharepoint_item_id = NULL, ambas fazem POST de criacao, e so uma vence a escrita final em
  confirmar_push_sharepoint - a mesma duplicidade acima, sem nenhuma falha de rede envolvida.
- Nao ha lock/advisory lock, nem verificacao "ja existe item com este codigo na lista antes de
  criar" (o fallback por codigo existe no PULL, em aplicar_pull_sharepoint, mas nao no PUSH).

**Como corrigir** (em migration/deploy novos, nao editando 001-011): antes do POST de criacao,
buscar na lista por field_0 eq '<codigo>' (ou usar uma chave de idempotencia do Graph, se
disponivel) e cair para PATCH se ja existir; e/ou serializar por projeto (ex.:
pg_advisory_xact_lock(hashtext(projeto_id)) na RPC de confirmacao, ou uma coluna/timestamp de
lock de "push em andamento").

### 2. .or() da pull montado com string interpolada - risco de "filter injection" no PostgREST

supabase/functions/sharepoint-projetos-pull/index.ts, linha 195:

    .or(`sharepoint_item_id.eq.${sharepointItemId}${codigo ? `,and(codigo.eq.${codigo},sharepoint_item_id.is.null)` : ''}`)

codigo vem de texto livre da lista SharePoint (field_0), sem qualquer escape. A sintaxe de
filtro do PostgREST usa virgula como separador de condicoes e parenteses para agrupamento - um
valor com virgula, parentese ou ponto inesperado quebra ou altera a arvore de condicoes (ex.:
alguem digitar "26,267" na coluna Codigo por engano ja produz uma clausula malformada). Na
melhor hipotese isso derruba o processamento DAQUELE item (erro capturado e logado); na pior,
uma virgula seguida de algo que o PostgREST interprete como coluna.operador.valor pode
adicionar uma condicao extra a consulta e casar o item errado, levando aplicar_pull_sharepoint
a atualizar um projeto que nao e o pretendido. Classifico como Critico porque o efeito
potencial e sobrescrever dados do projeto errado sem aviso - mas o vetor exige alguem com
permissao de edicao na lista "Organizacao Projetos" (nao e exposto a internet).

**Correcao sugerida** (Edge Function, redeploy - nao mexe em migration): trocar por duas
consultas separadas (.eq('sharepoint_item_id', sharepointItemId).maybeSingle(), e so se vazio
.eq('codigo', codigo).is('sharepoint_item_id', null).maybeSingle()), evitando montar filtro
combinado por concatenacao de string.

---

## Aviso

### 3. disparar_pull_sharepoint() sem REVOKE/GRANT explicitos (inconsistente com as irmas na mesma migration)

010_cron_pull_sharepoint.sql e 011_ajuste_authorization_header.sql recriam
public.disparar_pull_sharepoint() como SECURITY DEFINER mas, diferente de
gerar_codigo_projeto (004), confirmar_push_sharepoint (008) e aplicar_pull_sharepoint (009)
- que todas fazem REVOKE ALL ... FROM PUBLIC + GRANT EXECUTE ... TO service_role (ou
authenticated, service_role) - esta funcao nao tem nenhum REVOKE/GRANT. Como nao ha
ALTER DEFAULT PRIVILEGES revogando EXECUTE de PUBLIC em public neste projeto (confirmado por
grep: so existe 1 ocorrencia do comando, referente a tabelas/views do showroom, nao a
funcoes), o padrao do Postgres e que PUBLIC - logo authenticated e possivelmente anon - ganha
EXECUTE por padrao em funcao nova. Diferente das duas funcoes de trigger (que nao podem ser
chamadas diretamente por serem do tipo trigger), disparar_pull_sharepoint() retorna void e e
chamavel via rpc/disparar_pull_sharepoint por qualquer usuario autenticado (e possivelmente
anonimo), disparando um ciclo de pull fora do cron. O dano pratico e baixo (a Edge Function
ainda exige x-sync-secret internamente), mas e uma inconsistencia real de padrao dentro da
propria migration e permite abuso de custo/rate-limit do Graph por qualquer usuario logado no
ecossistema.

### 4. Deteccao de conflito no pull nao usa o timestamp do SharePoint como a SPEC descreve - falsos positivos provaveis

A SPEC-130 (secao "Fluxo pull", passo 3) descreve: "se item.lastModifiedDateTime >
projetos.updated_at -> aplica (...) caso contrario e houver divergencia real -> conflito". O
codigo implementado em processarItem (pull index.ts) NAO usa item.lastModifiedDateTime em
nenhum momento - ele decide conflito comparando so existente.updated_at com
existente.last_synced_at:

    const editadoDepoisDoUltimoSync =
      !existente.last_synced_at || new Date(existente.updated_at) > new Date(existente.last_synced_at)

projetos.updated_at e mantido pelo trigger pre-existente update_projetos_updated_at, que -
pelo padrao universal desse tipo de trigger neste projeto - dispara em QUALQUER UPDATE da
linha, nao so nos 10 campos do mapa de sincronizacao. Ou seja: se QUALQUER OUTRO SISTEMA
(Orcamentos, Financeiro, RH via equipe_id, etc.) tocar em qualquer coluna do projeto depois do
ultimo sync, updated_at avanca e passa a ficar sempre maior que last_synced_at - e a partir dai
TODA edicao legitima feita so no SharePoint para aquele projeto sera classificada como
"conflito" e descartada (mantendo o valor do sistema, sem sobrescrever), mesmo quando nao ha
edicao concorrente real nos campos sincronizados. Isso nao perde dado (cai no caminho seguro de
log), mas derruba na pratica o criterio de aceite "editar na lista volta pro CRM em ate 1 ciclo
do cron, sem duplicar" - o pull tende a virar bidirecional so de nome para projetos ativamente
tocados por outros modulos.

### 5. RLS de sharepoint_sync_log/sharepoint_status_map sem nenhuma policy diverge do padrao ja usado pelo proprio projeto para tabela de auditoria equivalente

003_rls_tabelas_sync.sql habilita RLS nas 4 tabelas novas sem nenhum CREATE POLICY - correto
para sharepoint_sync_state e projeto_codigo_sequencia (estado interno puro, sem motivo de
leitura por humano). Mas para sharepoint_sync_log, a propria SPEC-130 declara que "todo
conflito vai para sharepoint_sync_log (...) para conferencia humana" - e, como esta, NENHUM
papel (nem admin) consegue ler essa tabela pela API/PostgREST, so via acesso direto ao
Supabase (service role/dashboard). Isso diverge do padrao que este mesmo projeto ja usa para
uma tabela de auditoria equivalente: public.auditoria_permissoes (SPEC-006,
20260708_029_.../001_tabelas.sql) tem RLS COM uma policy explicita
(admin_select_auditoria_permissoes ... USING (is_admin())) mais GRANT SELECT ... TO
authenticated, permitindo que um admin veja o log pela aplicacao. Sugiro, numa migration nova,
espelhar esse padrao em sharepoint_sync_log (e possivelmente sharepoint_status_map, que o
Vinicius tambem precisara poder ler/manter).

### 6. gerar_codigo_projeto() pode quebrar para o ano inteiro se existir um codigo legado fora do formato AA.NNN

    select coalesce(max(nullif(split_part(codigo, '.', 2), '')::integer), 0)
      into v_max_existente
    from public.projetos
    where codigo like v_ano || '.%';

Nao ha CHECK de formato em projetos.codigo (e so varchar(50) NOT NULL), e o historico deste
projeto ja teve mais de uma vez dado legado fora do padrao esperado (ver notas de import de
planilhas). Se qualquer linha do ano corrente tiver um sufixo nao puramente numerico (ex.:
"26.267B"), o ::integer explode e TODA chamada futura de gerar_codigo_projeto() para aquele ano
passa a falhar - trava a criacao de projeto pelo sistema (e o fallback de gerar codigo no pull
tambem) ate alguem corrigir o dado manualmente. Vale endurecer o filtro (ex. usar uma
comparacao por regex tipo '^AA\.[0-9]+$' em vez de like) numa migration futura.

### 7. Retry/backoff descrito na SPEC nao existe no codigo

A SPEC-130 (secao "Fluxo push", passo 7) diz: "Erro do Graph -> log action='error' +
reenfileira (retry com backoff); o projeto nunca fica sem tentativa de ir para a lista." No
codigo shipado (trigger 006/011, RPCs, Edge Function), nao ha nenhum reenfileiramento ou retry
- uma falha do Graph so grava o log e devolve 500; nao existe worker ou tabela de fila. Nao e
um bug (o comportamento atual e seguro, so nao e automatico), mas a SPEC descreve algo que
ainda nao foi implementado - vale corrigir o texto da SPEC ou tratar como item pendente
explicito, para nao passar a impressao de que a garantia ja existe.

---

## Info

### 8. supabase/docs/relationships.md ainda documenta a FK errada (pre-existente, nao introduzida hoje)

Linhas 90 e 148 de supabase/docs/relationships.md dizem "projetos.responsavel_obra_id ->
contatos.id". O schema real (supabase/db/current/01_schema_full.sql, linha ~11454) confirma
que a FK de verdade e projetos_responsavel_obra_id_fkey -> public.usuarios(id) - exatamente
como a SPEC-130 corrigiu e como o codigo novo (migration 009, as duas Edge Functions) ja usa
CONSISTENTEMENTE em todos os lugares (chequei push, pull e a RPC - nao encontrei nenhuma
referencia residual a contatos para esse campo). So falta atualizar esse arquivo de doc junto
com o Item 10 ja previsto na SPEC (AI_DB_CONTEXT.md/domains/crm.md).

### 9. projetos.historico (jsonb) ja previa sistema_origem: "sharepoint" e nao e usado por esta SPEC

A coluna projetos.historico tem um comentario de schema pre-existente descrevendo um
convenio {"campo":..., "sistema_origem":"crm|sharepoint|rh"}, mas nao encontrei nenhum trigger
atual que efetivamente grave nela (parece morta/nunca ativada). SPEC-130 criou seu proprio
mecanismo paralelo (last_sync_source + sharepoint_sync_log), o que e razoavel dado que a coluna
parece nao estar em uso - so deixando registrado para nao confundir quem encontrar os dois
mecanismos no futuro.

### 10. sharepoint_status_map.sharepoint_valor sem UNIQUE

Nada impede que o Vinicius, ao preencher o de-para, mapeie dois projeto_status diferentes para
o mesmo texto de status da lista - o mapa reverso usado no pull (Map construido em JS) ficaria
ambiguo (o ultimo carregado vence, sem aviso). Sugiro um indice unico em sharepoint_valor antes
do seed definitivo.

---

## O que foi verificado e esta correto

- search_path fixado em todas as 4 funcoes SECURITY DEFINER relevantes
  (gerar_codigo_projeto, confirmar_push_sharepoint, aplicar_pull_sharepoint,
  disparar_pull_sharepoint) - todas usam "set search_path = public" (as duas que chamam
  net.http_post/vault usam "public, extensions", coerente com onde essas extensoes vivem).
- trg_projetos_stamp_sync_meta_fn NAO e SECURITY DEFINER (roda como quem fez o UPDATE) - nao
  precisa de search_path fixado por nao ter risco de escalonamento de privilegio; a ausencia
  aqui nao e uma falha, ao contrario da funcao de push (que e definer e tem o search_path
  corretamente pinado).
- Anti-eco (last_sync_source + trigger BEFORE + flag de sessao app.sync_em_andamento) esta bem
  desenhado para o caminho feliz: a trigger BEFORE garante que toda escrita "normal" (CRM, ou
  qualquer outro processo que nao seja a RPC de pull) carimba 'sistema', e so a RPC de pull liga
  a flag que faz a trigger BEFORE nao sobrescrever o que ela mesma gravou. Nao achei sequencia
  de eventos que deixe last_sync_source com valor errado - o problema real encontrado nao e o
  carimbo ficar errado, e a DUPLICIDADE DE ITEM no SharePoint (achado Critico #1). pg_net
  enfileira dentro da mesma transacao, entao rollback da escrita original tambem cancela o POST
  enfileirado - nao ha risco de HTTP disparado para uma escrita que nao vingou.
- gerar_codigo_projeto() sob concorrencia normal (sem dado legado fora do padrao, achado #6):
  o INSERT ... ON CONFLICT DO UPDATE em projeto_codigo_sequencia serializa corretamente duas
  chamadas simultaneas via lock de linha - a segunda transacao so le o valor ja incrementado
  pela primeira depois de destravar, evitando colisao de codigo. Sem problema aqui.
- responsavel_obra_id -> usuarios esta consistente em TODOS os arquivos revisados (migration
  009, push index.ts, pull index.ts) - a correcao citada no enunciado desta revisao foi
  propagada corretamente (a unica inconsistencia residual e de documentacao, achado Info #8,
  nao de codigo).
- Nenhuma credencial nova foi commitada nos arquivos revisados; segredos ficam no Vault
  (sharepoint_sync_secret, sharepoint_push_url, sharepoint_pull_url, supabase_anon_key), como a
  propria migration documenta.
- codigo/venda_id/boletos.projeto_id/aprovar_orcamento_financeiro/sync_projeto_valor_total()/
  _lucenera_parse_prazo_pagamento() - nenhum desses invariantes do dominio e tocado por esta
  SPEC; fora de escopo, sem violacao encontrada.

## Observacao de processo (nao e achado de codigo)

Toda a migration 001-011 ja rodou em producao. Os achados Critico #1 e #2 e os Aviso #3-#7
acima, se o Pedro/Vinicius decidirem corrigi-los, exigem uma migration NOVA (012 em diante)
e/ou redeploy das Edge Functions - nunca editar os arquivos 001-011 existentes. Nao apliquei,
nao editei e nao publiquei nada nesta revisao.
