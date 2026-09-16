# Auditoria de Segurança Focada — Eixo 1 (Supabase/Banco) e Eixo 2 (Segredos no Front-end)

**Data**: 2026-08-30
**Tipo**: Diagnóstico apenas — nenhuma correção, alteração, rotação de chave ou escrita foi feita. Todas as consultas ao banco foram `SELECT` contra catálogos do sistema (`pg_class`, `pg_proc`, `information_schema`); a varredura de front-end incluiu os bundles JS já compilados (`dist/`) commitados no repositório, além do código-fonte.
**Relação com a auditoria anterior** (`2026-08-30_auditoria_seguranca_pre_producao.md`): este documento aprofunda e reverifica de forma independente os dois eixos pedidos. Os achados críticos já reportados (C1-C6) continuam válidos — aqui eles são detalhados com números exatos e novas checagens (mapeamento completo do que a chave `anon` alcança, `search_path` em funções `SECURITY DEFINER`, varredura da chave de serviço nos bundles compilados).
**Este relatório servirá de base para uma spec de correção futura — nenhuma correção foi implementada aqui.**

---

## EIXO 1 — Segurança do Supabase / Banco de Dados

### 1.1 Row Level Security — tabela por tabela

Total de tabelas no schema `public`: **103**.

**Sem RLS habilitada (7 tabelas)** — confirmado via `pg_class.relrowsecurity = false`:

| Tabela | Conteúdo | Grant `anon` |
|---|---|---|
| `funcionarios` | nome, e-mail, cargo, empresa, datas de admissão/demissão (36 linhas) | INSERT, SELECT, UPDATE, DELETE, TRUNCATE |
| `staging_conta_pagar` | staging de import financeiro (contas a pagar) | idem |
| `staging_conta_receber` | staging de import financeiro (contas a receber) | idem |
| `staging_pedido_compra` | staging de import de pedidos de compra | idem |
| `staging_produtos` | staging de import de catálogo/preço | idem |
| `staging_import_bruto` | staging genérico de import | idem |
| `stg_duplicatas_vigentes` | staging de duplicatas bancárias | idem |

Sem RLS + grant total para `anon` = qualquer requisição HTTP não autenticada (`GET/POST/PATCH/DELETE https://vcvcwzmbiftcawncibke.supabase.co/rest/v1/funcionarios`, por exemplo) lê, escreve ou apaga essas 7 tabelas por completo, incluindo `TRUNCATE`.

**Com RLS habilitada, mas com policy(ies) que liberam `anon`/`public` sem condição real** (já detalhado na auditoria anterior, achados C3/C4/C5): `logs_auditoria` (SELECT), `fornecedores` (SELECT + DELETE), `orcamentos` (INSERT + policy de leitura por token que não valida o token específico), `orcamento_itens` (INSERT), `orcamentos_revenda_ubiqua` (INSERT/SELECT/UPDATE), `informacoes_cliente_ubiqua` (SELECT + UPDATE, contém CPF/CNPJ), `empresas` (SELECT), `quotes`/`quote_history` (ALL).

**Com RLS habilitada e corretamente restrita** (positivo, confirmado): tabelas cobertas pelo padrão `spec069_*` (`hub_pode_executar(auth.uid(), ...)`) — produtos, projetos, contatos (para as policies que usam esse padrão — ver 1.6 sobre as policies concorrentes na mesma tabela), boletos, contas_bancarias, notas_fiscais, remessas, separações, cotações de compra, pedido_compra_itens, solicitações de compra, funcionários_novo.

**Zona cinzenta — RLS habilitada, mas só como "portão de login"** (sem papel/dono, achado A3 da auditoria anterior): ~55% das 370 policies totais do banco (202) são `USING(true)`/`WITH CHECK(true)` restritas só a `authenticated`, sem checar papel específico nem dono da linha — inclui `transacoes`, `projeto_parcelas`, `estoque_itens`, `funcionarios_financeiro`, `funcionarios_detalhes`, `funcionarios_beneficios_empresas`, `historico_status_orcamentos`, `notas_fiscais_compra`.

### 1.2 Vetor de ataque usando SOMENTE a chave `anon`

A chave `anon` está embutida em todo bundle JS público (confirmado no item 2.1). Ela sozinha, sem login algum, permite:

**Leitura/escrita direta de tabela** (via PostgREST, `/rest/v1/<tabela>`):
- Ler e apagar `funcionarios` por completo (sem RLS).
- Ler e escrever nas 6 tabelas de staging financeiro (sem RLS).
- Ler todo o `logs_auditoria` (reconhecimento: IDs de usuário, ações, timestamps — útil pra planejar um ataque maior).
- Ler e apagar `fornecedores`.
- Ler CPF/CNPJ e dados de contato de `informacoes_cliente_ubiqua`, e alterá-los.
- Ler todos os `orcamentos` com `token_aprovacao_cliente` preenchido (praticamente todo orçamento já enviado a cliente) — nome, endereço, telefone, valores, itens — sem precisar do token de nenhum.
- Inserir linhas em `orcamentos`, `orcamento_itens`, `orcamentos_revenda_ubiqua`.
- Ler `empresas` e `quotes`/`quote_history` por completo.

**Chamada de função RPC** (via PostgREST, `/rest/v1/rpc/<funcao>`): consultei `information_schema.routine_privileges` e confirmei **136 funções** com `EXECUTE` concedido a `anon` no schema `public` — a lista completa está no Anexo A. Isso inclui, além das já reportadas como críticas (`admin_update_user_password`, `admin_update_user_role`, `admin_update_user_status`, `criar_usuario`), um número grande de RPCs de negócio sensíveis também abertas a `anon`: `aprovar_orcamento_financeiro`, `aprovar_projeto_financeiro`, `desfazer_aprovacao_financeira`, `financeiro_editar_orcamento`, `cancelar_pedido_compra`, `cancelar_orcamento`, `aprovar_solicitacao_compra`, `aprovar_transferencia_estoque`, entre outras.

A maioria dessas RPCs provavelmente tem uma checagem interna (`hub_pode_executar`/`auth.uid()`) que bloqueia um chamador sem sessão — mas isso **não foi verificado função por função nesta rodada** (são ~130 funções; verificar cada uma individualmente é o próximo passo natural antes de uma correção). O que já está confirmado, e é o ponto central deste achado: **o padrão de concessão neste banco é "conceder EXECUTE a `anon` por padrão e confiar na lógica interna de cada função para barrar"**, em vez de "revogar de `anon` por padrão e conceder só onde um fluxo público é intencional" (ex.: `aprovar_orcamento_cliente_publico`, `recusar_orcamento_cliente_publico`, `buscar_orcamento_para_aprovacao`, que são desenhadas pra serem públicas). Isso amplia a superfície de ataque: **qualquer** bug de lógica de autorização futuro numa dessas ~130 funções vira uma falha crítica automaticamente, porque a barreira de "precisa estar logado" nunca existiu no nível de GRANT.

### 1.3 Funções RPC / PL-pgSQL — bugs de autorização e `search_path`

**Bug de comparação NULL (já reportado como C1, reconfirmado)**: `admin_update_user_password`, `admin_update_user_role`, `admin_update_user_status`, `criar_usuario` fazem `IF v_caller_role != 'admin' THEN RAISE EXCEPTION`, e `NULL != 'admin'` avalia `NULL` (tratado como falso pelo `IF`), então um chamador sem sessão (`auth.uid()` NULL) passa pela checagem. Confirmado que as 4 têm `GRANT EXECUTE` para `anon`.

**`SECURITY DEFINER` sem `search_path` fixo (achado novo desta rodada)**: das 94 funções `SECURITY DEFINER` no schema `public` (funções que rodam com o privilégio de quem as criou, não de quem chama — потencialmente bypassando RLS), **19 não têm `SET search_path` configurado** no `proconfig`:

`adicionar_item_cotacao`, `adicionar_item_pedido`, `atualizar_status_cotacao`, `atualizar_status_pedido`, `atualizar_status_solicitacao`, `criar_cotacao_compra`, `criar_pedido_compra`, `criar_solicitacao_compra`, `fn_log_auditoria`, `get_next_sku`, `get_vendedores`, `handle_contato_tipo`, `is_admin`, `is_ubiqua_admin`, `on_contato_created`, `re_reservar_projeto_item`, `registrar_recebimento_compra`, `set_updated_at`, `update_revenda_ubiqua_ordem`.

Todas as 19 têm `GRANT EXECUTE` para `anon` e `authenticated`. Sem `search_path` fixo, a função roda com o `search_path` de sessão do **chamador**, não um fixo e confiável definido pelo dono — a classe de vulnerabilidade clássica (equivalente ao CVE-2018-1058 do PostgreSQL) é: se existir algum papel com permissão de criar objetos num schema que apareça antes de `public` no `search_path` do chamador, e a função referenciar algum nome de tabela/função **sem qualificar o schema** (ex.: `SELECT * FROM produtos` em vez de `SELECT * FROM public.produtos`), um objeto forjado nesse schema poderia ser executado com o privilégio elevado da função `SECURITY DEFINER`.
**Não verifiquei, função por função, se o corpo de cada uma das 19 usa referências não-qualificadas** (isso exige ler o código-fonte de cada função, não só o catálogo) — reportando como achado de configuração (ausência de `search_path` fixo é, por si só, prática insegura recomendada contra pela documentação oficial do Postgres/Supabase, independente de exploração confirmada) e deixando a confirmação de exploração real para a fase de correção/verificação.

**Funções administrativas com padrão correto (contraste, positivo)**: `aprovar_orcamento_financeiro` usa `IF COALESCE(auth.role(), '') != 'service_role' AND NOT hub_pode_executar(auth.uid(), ...) THEN` — null-safe e correto. `hub_pode_executar(NULL, ...)` também é null-safe (retorna `false`). O padrão seguro já existe e é usado consistentemente nas funções mais recentes (SPEC-069) — o problema está localizado nas funções que ficaram no modelo legado.

### 1.4 Service Role Key — varredura dedicada

- Grep em todo o repositório (excluindo `node_modules`/`.git`) por `SUPABASE_SERVICE_ROLE_KEY=ey`, `service_role`, e qualquer JWT (`eyJ...`) fora de `.env`/`node_modules`: **nenhum valor real de service role key encontrado em código-fonte**.
- **Verificação adicional desta rodada**: os 7 sistemas com `dist/` (build já compilado) commitado no repositório — `cadastro-lucenera-b86fe`, `compras-lucenera-3o23t98ee`, `dashboard-lucenera-b02z85wa3`, `gestao-financeira-clone-544cb`, `lucenera-crm-3bd29`, `retorno-bancario-bradesco-5392a`, `separacao-parcial` — foram varridos diretamente nos arquivos `.js` minificados finais (o que realmente é servido ao navegador). **Nenhuma ocorrência de `service_role`/`SUPABASE_SERVICE_ROLE` em nenhum bundle compilado.**
- O único JWT encontrado no bundle da Cadastro foi decodificado: `{"iss":"supabase","ref":"vcvcwzmbiftcawncibke","role":"anon", ...}` — confirma que é a chave pública esperada, não a de serviço.
- **Onde a service role key É usada corretamente**: dentro das Edge Functions (`Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`), que rodam no servidor Supabase, nunca no navegador — uso apropriado. O risco real de uso da service role está em Edge Functions sem autenticação própria (já reportado: `update-project`, `salvar-projeto`, `process-budget-pdf` usam service role sem checar quem chama — o problema não é a chave estar exposta, é a Edge Function não ter porteiro).
- **Conclusão do item**: não encontrei a service role key exposta no cliente em nenhum lugar verificado (código-fonte nem bundle compilado). Este é o único item do Eixo 2 marcado como "não confirmado" — recomendo, mesmo assim, uma rotação preventiva da service role key ao corrigir os achados críticos do Eixo 1, como boa prática padrão sempre que um sistema com falhas de autorização críticas é corrigido.

### 1.5 Privilégios por papel (`anon` / `authenticated` / `service_role`)

- `anon`: `EXECUTE` em 136 funções (Anexo A) + `GRANT` (não RLS) em 153 de ~160 tabelas/views do schema `public` (achado da auditoria anterior, reconfirmado em espírito pelos números desta rodada). O `GRANT` de tabela não é, por si, a falha — é a RLS que decide na prática — mas é uma base de configuração arriscada: qualquer tabela nova criada sem RLS explícita nasce acessível por padrão.
- `authenticated`: mesmo padrão de `EXECUTE`/`GRANT` amplo, com a expectativa de que RLS (`hub_pode_executar`) filtre — válido nas ~15 tabelas cobertas pela SPEC-069, não confirmado nas demais (achado A3).
- `service_role`: usado corretamente só dentro de Edge Functions server-side; não usado do lado cliente em nenhum ponto verificado.

### 1.6 Dados sensíveis no banco

Tabelas com CPF/CNPJ/dado pessoal ou financeiro identificadas: `contatos` (cpf, cnpj, cpf_cnpj), `informacoes_cliente_ubiqua` (cpf_cnpj — **sem RLS efetiva**, ver 1.1), `funcionarios`/`funcionarios_financeiro`/`funcionarios_detalhes` (dado de RH — `funcionarios` sem RLS nenhuma; os outros dois com RLS "portão de login"), `orcamentos`/`transacoes`/`boletos`/`notas_fiscais` (dado financeiro).
- Criptografia em repouso: gerenciada pela infraestrutura do Supabase (nível disco) — fora do controle do código deste repositório, não avaliável por leitura de schema.
- CPF/CNPJ armazenado em texto puro nas colunas (`text`, sem função de hash/criptografia a nível de aplicação) — esperado para um sistema B2B operacional deste tipo, mas o risco sobe proporcionalmente à falta de RLS nas tabelas que os contêm (ver 1.1).
- Exposição via view: não foi encontrada nenhuma view pública que faça join de tabelas sensíveis além do que as tabelas-base já expõem via RLS/GRANT.

### 1.7 Edge Functions — autenticação e autorização (resumo; detalhe completo na auditoria anterior)

| Função | Exige JWT válido? | Checa papel/dono? | Usa service role? |
|---|---|---|---|
| `update-project` | **Não** | Não | Sim |
| `salvar-projeto` | **Não** | Não | Sim |
| `welcome-email` | **Não** | Não | — (Resend API) |
| `process-budget-pdf` | **Não** | Não | Sim |
| `process-billing-automation` | **Não** | Não | Sim |
| `process-remittance` | **Não** | Não | Sim |
| `sync-teams` | Só checa header presente, não valida | Não | — |
| `generate-report` (orçamento) | Sim | **Não** (bypass explícito no código pra `reportType='orcamento'`) | Sim |
| Demais funções administrativas (`role IN ('admin','gerente')`) | Sim | Sim | Sim |

---

## EIXO 2 — Exposição de Chaves e Dados no Front-end

### 2.1 Chaves e segredos no cliente

- **Chave `anon` do Supabase**: presente (esperada, por design) em `.env`/bundle de todos os 10+ sistemas — confirmado decodificando o JWT real do bundle compilado (role `anon`). Isso não é uma falha — é a chave pública que a arquitetura Supabase espera no cliente; a segurança real depende inteiramente de RLS (Eixo 1).
- **Chave de serviço (`service_role`)**: **não encontrada** no cliente, nem em código-fonte nem em bundle compilado (ver 1.4). Este é o item mais crítico possível de se encontrar exposto, e a varredura dedicada desta rodada (incluindo os `dist/` já compilados) não encontrou ocorrência.
- **Chaves de API de terceiros** (`GEMINI_API_KEY`, credenciais Resend/SharePoint/Microsoft Graph): usadas exclusivamente em Edge Functions via `Deno.env.get(...)`, nunca embutidas em código de frontend — confirmado por grep nos 10 sistemas.
- **Senhas/strings de conexão**: nenhuma encontrada hardcoded em nenhum arquivo `.ts`/`.tsx` de frontend.
- **`localStorage`/`sessionStorage`/cookies**: supabase-js guarda a sessão (access/refresh token) em `localStorage` por padrão — comportamento esperado da biblioteca, não uma falha de implementação do time. Nenhum sistema guarda CPF, senha ou dado financeiro adicional em storage local além dessa sessão padrão. Único cookie em uso em todos os 10 sistemas é `sidebar:state` (preferência de UI do shadcn/ui), não relacionado a autenticação.

### 2.2 O que o bundle JS revela

O vetor de reconhecimento real não é a leitura manual do JS minificado (nomes de tabela/coluna sobrevivem à minificação como strings literais, mas são triviais de achar por outro caminho muito mais direto): **a própria API REST do Supabase (PostgREST) é auto-documentada**. Qualquer um com a chave `anon` pública pode requisitar `GET https://vcvcwzmbiftcawncibke.supabase.co/rest/v1/` e receber de volta um documento OpenAPI completo listando **todo nome de tabela, coluna, tipo de dado e toda função RPC exposta** no schema `public` — isso não depende de examinar o JavaScript do cliente, é uma funcionalidade padrão do PostgREST.
Na prática, isso significa: o "segredo" da estrutura do banco (nomes de tabela como `funcionarios`, `informacoes_cliente_ubiqua`, `admin_update_user_password`) nunca foi realmente protegido por obscuridade — a única proteção possível é RLS/GRANT corretos (Eixo 1). Confirmar isso reforça por que os achados do Eixo 1 são o risco real, não a "descoberta" de nomes internos.

### 2.3 Dados sensíveis no cliente

- Nenhum `console.log`/`console.error` encontrado no frontend imprimindo objeto de sessão completo, token, ou PII em massa (o padrão de log encontrado nos 10 sistemas é de erro genérico, ex.: `console.error('Erro ao buscar...', error)`).
- O PDF de orçamento (via `generate-report`) e o PDF Ubiqua (via `process-budget-pdf`) **são o principal ponto de exposição de dado sensível no lado cliente/entrega** — não porque o front-end "vaza" algo, mas porque a falta de autorização por objeto no backend (achados A1/C6 do Eixo 1) permite que qualquer sessão válida (ou, no caso do Ubiqua, nenhuma sessão) baixe esse PDF com CPF/CNPJ e dados financeiros de terceiros.

### 2.4 Headers e CORS

- **CORS**: todas as Edge Functions usam `Access-Control-Allow-Origin: '*'` (`_shared/cors.ts`, replicado). Mitigado parcialmente pela autenticação ser via Bearer token (não cookie) — um site de terceiro não consegue forjar uma requisição autenticada só por conta do CORS aberto, mas ainda é uma camada de defesa a menos.
- **Headers de segurança ausentes**: nenhuma configuração de CSP, HSTS, X-Frame-Options, X-Content-Type-Options ou Referrer-Policy encontrada em nenhum `vite.config.ts`, `index.html` (via `<meta http-equiv>`) ou arquivo de configuração de nenhum dos 10 sistemas. Como são SPAs estáticas hospedadas na plataforma Skip (sem servidor próprio neste repositório), a aplicação desses headers depende inteiramente da plataforma de hospedagem — não há como confirmar ou negar a partir do código se a Skip aplica algo por padrão.
- **Configuração de JWT/refresh token no cliente**: uso padrão do `@supabase/supabase-js` (renovação automática de token via `onAuthStateChange`/refresh token) em todos os 10 sistemas — nenhuma configuração customizada insegura encontrada (ex.: nenhum sistema desabilita `autoRefreshToken`/`persistSession` de forma que enfraqueça a sessão, nem estende manualmente o tempo de vida do token).

---

## Anexo A — Lista completa das 136 funções com `EXECUTE` concedido a `anon`

```
_lucenera_parse_prazo_pagamento, adicionar_item_cotacao, adicionar_item_pedido, adm_aprovar_pelo_cliente,
admin_update_user_password, admin_update_user_role, admin_update_user_status, aprovar_orcamento_cliente,
aprovar_orcamento_cliente_manual, aprovar_orcamento_cliente_publico, aprovar_orcamento_financeiro,
aprovar_orcamento_financeiro_base_spec001, aprovar_projeto_financeiro, aprovar_solicitacao_compra,
aprovar_transferencia_estoque, atualizar_desconto_compra_produto, atualizar_parcela_pedido_compra,
atualizar_preco_custo_produto, atualizar_status_cotacao, atualizar_status_pedido, atualizar_status_solicitacao,
buscar_fornecedores_fuzzy, buscar_orcamento_para_aprovacao, buscar_produtos_fuzzy, can_user_approve_quotes,
cancelar_orcamento, cancelar_pedido_compra, cancelar_transferencia_estoque, cliente_aprovar_orcamento,
cliente_recusar_orcamento, criar_cotacao_compra, criar_pedido_compra, criar_pedido_compra_de_necessidade,
criar_pedido_compra_lote, criar_produto_orcamento, criar_solicitacao_compra, criar_usuario,
current_user_funcionario_id, current_user_is_funcionario, desfazer_aprovacao_financeira,
enviar_orcamento_para_cliente, equipe_aprovar_orcamento, equipe_devolver_orcamento_cliente,
estornar_item_separacao, estornar_separacao_parcial, finalizar_separacao_parcial_pronta,
finalizar_validacao_financeira, financeiro_devolver_orcamento_equipe, financeiro_editar_orcamento,
fn_add_dias_uteis, fn_atualiza_updated_at, fn_atualizar_preco_venda, fn_auditoria_permissoes,
fn_auditoria_usuario_papeis, fn_auto_numero_orcamento, fn_gerar_numero_orcamento, fn_log_auditoria,
fn_solicitacoes_set_atualizado_em, fn_sync_equipe_por_responsavel, fn_sync_estoque_itens_from_produtos,
fn_update_orcamento_timestamp, fn_validar_saldo_projeto_item, gen_token_hex, generate_product_slug,
gerar_parcelas_pedido_compra, get_dashboard_crm_by_closing, get_dashboard_kpi, get_dashboard_stats,
get_faltas_injustificadas, get_latest_transaction_id, get_my_funcionario_id, get_next_sku, get_user_role,
get_vendedores, handle_contato_tipo, handle_new_auth_user, handle_new_user, handle_orcamento_item_change_reset,
handle_orcamento_workflow, handle_updated_at, hub_pode_executar, hub_sistemas_permitidos, immutable_unaccent,
is_admin, is_ubiqua_admin, limpar_staging_processados, link_my_funcionario_record, log_can_approve_quotes_change,
normalize_orcamento_status, on_contato_created, pode_trocar_reserva, processar_retorno_bancario,
propagate_contato_nome, propagate_projeto_codigo, propagate_usuario_nome, re_reservar_projeto_item,
recusar_orcamento_cliente_publico, registrar_devolucao_projeto_item, registrar_devolucao_projeto_item_setor,
registrar_recebimento_compra, registrar_separacao_setor, rejeitar_solicitacao_compra,
replace_orcamento_arquitetos, replace_projeto_arquitetos, set_orcamento_numero, set_pedido_compra_numero,
set_projeto_itens_descricao, set_updated_at, solicitar_transferencia_estoque, stats_datacenter,
sugerir_fornecedores_marcas, sync_contact_type_on_budget, sync_entregue_ao_finalizar_entrega,
sync_entregue_ao_finalizar_separacao, sync_projeto_valor_total, sync_responsavel_nome,
sync_separacao_cliente, sync_separacao_codigo_obra, sync_separado_ao_ficar_pronto, track_reagendamento,
trg_estoque_saldos_projeto_item_atualizado_em, trigger_fechar_projeto, trigger_proteger_fechamento,
trigger_proteger_parcelas, trigger_separacao_pronta, trigger_update_revenda_ubiqua_slug,
trocar_reserva_projetista, unaccent, unaccent_init, unaccent_lexize, update_atualizado_em,
update_revenda_ubiqua_ordem, update_revenda_ubiqua_updated_at, update_updated_at_column,
vincular_origem_pedido_compra_item, voltar_orcamento_rascunho
```

**Nota**: muitas destas são funções de *trigger* (ex.: `sync_*`, `handle_*`, `trigger_*`, `propagate_*`) — o `GRANT EXECUTE` concedido a elas não significa necessariamente que fazem algo perigoso se chamadas diretamente via RPC (algumas podem falhar silenciosamente ou não fazer nada fora do contexto de um trigger real), mas o fato de PostgREST expor **qualquer** função do schema `public` com `EXECUTE` concedido, sem distinguir "função de negócio" de "função de trigger interna", significa que todas essas 136 são, tecnicamente, endpoints de API chamáveis por qualquer um com a chave `anon`. Recomenda-se, na fase de correção, revisar cada uma e decidir: revogar de `anon` (padrão recomendado para a maioria), manter só em `authenticated`, ou confirmar que a lógica interna já é segura o suficiente para permanecer pública.

---

## Limitações desta rodada

- Não foi verificado, função por função, se as 19 funções `SECURITY DEFINER` sem `search_path` fixo têm referências não-qualificadas de schema no corpo (exigiria leitura individual do código de cada uma).
- Não foi verificado, função por função, se as ~130 funções RPC expostas a `anon` (além das 4 já confirmadas como vulneráveis) têm lógica de autorização interna robusta — a lista do Anexo A é um mapa de superfície de ataque, não uma confirmação de exploração de cada uma.
- Rotação da service role key não foi executada (fora do escopo diagnóstico) — recomendada como precaução ao corrigir os achados do Eixo 1, mesmo sem evidência de exposição.
