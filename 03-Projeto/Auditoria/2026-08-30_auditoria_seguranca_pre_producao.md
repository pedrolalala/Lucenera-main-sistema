# Auditoria de Segurança Pré-Produção — Lucenera ADAPTA PASS

**Data**: 2026-08-30
**Tipo**: Diagnóstico apenas — nenhuma correção, alteração ou refatoração foi feita. Nenhum dado real foi exposto, alterado ou exfiltrado durante esta auditoria.
**Escopo**: 10+ sistemas React/TypeScript (`04-Sistemas/`), Edge Functions Deno (`supabase/functions/`), banco PostgreSQL/Supabase (RLS, RPCs, grants), dependências (npm/Python/Deno) e segredos/configuração/fluxo de dados.
**Metodologia**: leitura de código-fonte completa, consultas somente-leitura (`SELECT`) contra catálogos do sistema do banco real (`pg_policies`, `pg_proc`, `information_schema`), e análise estática de dependências (sem acesso à internet — sem `npm audit` real).

---

## Sumário executivo

**O sistema NÃO está pronto para produção no estado atual.** Foram encontradas vulnerabilidades que permitem, sem nenhuma autenticação:

1. Tomar controle administrativo total do sistema (reset de senha de qualquer usuário, promoção a admin, criação de conta admin nova).
2. Ler e alterar dados de funcionários (RH) e dados financeiros de staging sem login.
3. Ler em massa todos os orçamentos pendentes de aprovação de cliente (dados financeiros + PII) sem precisar do token individual de cada um.
4. Ler e alterar CPF/CNPJ e dados pessoais de clientes do catálogo Ubiqua sem login.
5. Criar/alterar orçamentos e itens diretamente no banco sem login.
6. Chamar 4 Edge Functions (alterar qualquer projeto, criar projetos falsos, enviar e-mail em nome da empresa pra qualquer destinatário, baixar PDF com PII de qualquer orçamento Ubiqua) sem nenhuma autenticação.

Nenhum desses pontos depende de erro de configuração futura — são falhas já presentes no schema/código atual, verificadas diretamente contra o banco de produção e o código das Edge Functions.

Além dos bloqueadores críticos, há uma camada mais ampla de RBAC "só de UI" — o controle de papéis (SPEC-069) filtra o que aparece na tela, mas boa parte das tabelas de negócio não replica esse controle como RLS no banco, então qualquer usuário autenticado (mesmo o papel mais restrito) pode, em teoria, acessar dado além do que a interface mostra fazendo a chamada direto na API REST do Supabase.

**Recomendação**: tratar os achados Críticos como bloqueadores de go-live. Os Altos devem ser resolvidos antes ou logo após o lançamento, com plano definido. Esta auditoria não implementou nenhuma correção — cada item precisa de uma decisão e implementação própria.

---

## 🔴 CRÍTICOS (bloqueadores de go-live)

### C1 — Bypass de autorização por NULL em 4 RPCs administrativas → takeover total sem autenticação
- **Onde**: RPCs `admin_update_user_password`, `admin_update_user_role`, `admin_update_user_status`, `criar_usuario` (banco).
- **Evidência**: cada função faz `SELECT role INTO v_caller_role FROM usuarios WHERE id = auth.uid(); IF v_caller_role != 'admin' THEN RAISE EXCEPTION...`. Quando não há sessão (`auth.uid()` é `NULL`, como acontece com a chave `anon` pura), `v_caller_role` fica `NULL`, `NULL != 'admin'` avalia `NULL`, e `IF NULL THEN` em PL/pgSQL equivale a falso — a exceção nunca dispara. Confirmado que `anon` tem `GRANT EXECUTE` nas 4 funções.
- **Exploração**: com só a chave `anon` pública (embutida em todo bundle JS, sem precisar de nenhuma conta), um atacante chama `rpc/admin_update_user_password` ou `rpc/admin_update_user_role` com qualquer `user_id` e reseta a senha de qualquer conta (inclusive admin) ou promove qualquer conta a admin; ou chama `rpc/criar_usuario` com `p_role: 'admin'` e cria uma conta admin do zero.
- **Contraste**: `aprovar_orcamento_financeiro` (mesma categoria de sensibilidade) já usa o padrão correto (`hub_pode_executar`) — o padrão seguro existe no projeto, só não foi replicado nessas 4 funções, que ficaram no modelo legado de `usuarios.role`.

### C2 — RLS totalmente desabilitada em `funcionarios` e 6 tabelas de staging financeiro, com GRANT completo para `anon`
- **Onde**: tabela `funcionarios` (36 linhas: nome, e-mail, cargo, empresa, datas de admissão/demissão) e `staging_conta_pagar`, `staging_conta_receber`, `staging_pedido_compra`, `staging_produtos`, `staging_import_bruto`, `stg_duplicatas_vigentes`.
- **Evidência**: `relrowsecurity = false` nessas tabelas; grant pra `anon` inclui `INSERT, SELECT, UPDATE, DELETE, TRUNCATE`.
- **Exploração**: `GET/PATCH/DELETE /rest/v1/funcionarios` sem login lê, altera ou apaga a tabela inteira. As tabelas de staging ficam expostas do mesmo jeito durante qualquer janela de sincronização (import de planilha) em que estiverem populadas.

### C3 — Políticas RLS `USING (true)` liberadas para `anon` em tabelas de negócio centrais
- **Onde**: `logs_auditoria` (SELECT), `fornecedores` (SELECT e **DELETE**), `orcamentos` (INSERT via `anon_insert_orcamentos`), `orcamento_itens` (INSERT), `orcamentos_revenda_ubiqua` (INSERT/SELECT/UPDATE), `empresas` (SELECT), `quotes`/`quote_history` (ALL).
- **Evidência**: policies nomeadas explicitamente pra `anon`/`public` com `USING (true)`/`WITH CHECK (true)`, sem checar `auth.uid()` nem `hub_pode_executar`. Em `orcamentos`, essa policy **coexiste** com a policy correta (`spec069_orcamentos_insert`, que usa `hub_pode_executar`) — mas como RLS combina policies do mesmo comando com OR, basta a policy permissiva existir pra liberar geral, mesmo com a policy certa também presente.
- **Exploração**: sem login, ler todo o log de auditoria (reconhecimento fácil de IDs/ações/timestamps pra um atacante), apagar fornecedores, criar orçamentos e itens de orçamento fantasmas na tabela principal do ecossistema, ler o cadastro de empresas.

### C4 — CPF/CNPJ e dados pessoais de clientes Ubiqua legíveis e alteráveis por qualquer pessoa, sem login
- **Onde**: tabela `informacoes_cliente_ubiqua` (coluna `cpf_cnpj text NOT NULL`).
- **Evidência**: duas policies duplicadas de SELECT (`"Permitir leitura anon e auth"`, `all_select_informacoes_cliente`), ambas `TO authenticated, anon USING (true)`; e `anon_update_informacoes_cliente ... FOR UPDATE TO anon USING (true) WITH CHECK (true)` — sem nenhuma condição de dono/ID.
- **Exploração**: `GET /rest/v1/informacoes_cliente_ubiqua?select=nome,email,telefone,cpf_cnpj` sem login retorna a base completa de clientes, incluindo CPF/CNPJ; `PATCH` reescreve qualquer registro. Risco de LGPD direto (vazamento e adulteração de dado pessoal/documento fiscal em massa, sem exigir sessão).

### C5 — Política de leitura de orçamento por token não valida o token específico
- **Onde**: tabela `orcamentos`, policy `anon_can_read_orcamento_by_token`.
- **Evidência**: `FOR SELECT TO authenticated, anon USING (token_aprovacao_cliente IS NOT NULL)` — a condição só checa que a linha *tem algum token preenchido*, não que ele bate com o token que o requisitante deveria conhecer. A RPC de aprovação (`aprovar_orcamento_cliente_publico`) valida o token corretamente, mas essa policy na tabela é uma porta paralela que não passa por essa RPC.
- **Exploração**: `GET /rest/v1/orcamentos?select=*` com a chave `anon` pública retorna **todos** os orçamentos com status "enviado para o cliente" — nome, razão social, endereço, CEP, telefone, valores e itens — sem precisar saber o token de nenhum deles individualmente.

### C6 — 4 Edge Functions sem nenhuma autenticação, usando `SUPABASE_SERVICE_ROLE_KEY` (bypassa RLS)
- **`update-project`**: zero checagem de `Authorization`; espalha o corpo inteiro da requisição (`{ id, ...updates }`) direto num `.update()` — qualquer campo de qualquer projeto pode ser reescrito por qualquer requisição anônima (incluindo campos financeiros).
- **`salvar-projeto`**: zero checagem de `Authorization`; cria projetos direto no banco a partir do corpo da requisição, sem login.
- **`welcome-email`**: zero checagem de `Authorization`; dispara e-mail real via Resend pro endereço informado no corpo — relay de e-mail aberto ao público, usável pra spam/phishing em nome do domínio da empresa, ou pra esgotar a cota paga da conta Resend.
- **`process-budget-pdf`** (fluxo Ubiqua): zero checagem de `Authorization`; busca nome/e-mail/telefone/CPF-CNPJ do cliente vinculado a um `quote_id`, gera um PDF e devolve uma **URL pública permanente** de Storage — qualquer pessoa que descubra ou receba esse `quote_id` (ex.: via e-mail, log, link compartilhado) acessa o documento com PII para sempre, sem re-autenticar.

---

## 🟠 ALTOS

### A1 — Geração de PDF de orçamento sem checagem de autorização por registro (IDOR)
- **Onde**: `generate-report/index.ts` (todos os sistemas que a usam, principal em Orçamentos).
- **Evidência**: a checagem de papel (`role IN ('admin','gerente')`) é explicitamente pulada quando `reportType === 'orcamento'`; a busca do orçamento usa `supabaseAdmin` (service role, ignora RLS) filtrando só por `id`, sem checar se o usuário logado tem vínculo com aquele orçamento/projeto/equipe.
- **Exploração**: qualquer usuário autenticado no ecossistema — inclusive o papel mais restrito (`viewer`), de **qualquer um dos 10 sistemas** (sessão compartilhada via SSO) — gera o PDF completo (cliente, endereço, telefone, valores, itens) de qualquer orçamento só sabendo o UUID. Não é acesso anônimo, mas quebra o princípio de menor privilégio que o resto da matriz RBAC (SPEC-069) segue.

### A2 — RBAC calculado mas nunca aplicado na rota em 3 sistemas
- **Onde**: Compras (`compras-lucenera-3o23t98ee`), Logística (`lucenera-logistics-b7cd1`), Separação Parcial (`separacao-parcial`).
- **Evidência**: `hasAccess` é calculado via RPC `hub_pode_executar` no hook de auth de Compras e Logística, mas o componente `ProtectedRoute` de nenhum dos dois lê esse valor — só checa `user`/`loading`. Separação Parcial nem chega a computar `hasAccess`. Em contraste, Cadastro, Admin Bancária, Orçamentos, RH, Dashboard Financeiro e CRM checam `hasAccess === false` corretamente.
- **Exploração**: qualquer usuário autenticado no ecossistema (mesmo sem permissão nenhuma nesses 3 sistemas) navega direto pra URL de produção e o app renderiza normalmente, sem tela de "Acesso Negado". A severidade real depende do RLS de cada tabela usada por essas telas — que, pelos achados C2/C3/A3 abaixo, em vários casos também não protege.

### A3 — RLS reduzida a "portão de login" (sem granularidade de papel/dono) em ~55% das políticas do banco
- **Onde**: 202 de 370 políticas totais são `USING(true)`/`WITH CHECK(true)` restritas só a `authenticated`, sem `hub_pode_executar` nem filtro por dono/empresa/projeto — inclui `transacoes`, `projeto_parcelas`, `estoque_itens`, `separacao_arquivos`, `entregas_finalizadas`, `funcionarios_financeiro`, `funcionarios_detalhes`, `funcionarios_beneficios_empresas`, `historico_status_orcamentos`, `notas_fiscais_compra`.
- **Evidência/Exploração**: o RBAC (SPEC-069) filtra o que a UI de cada sistema mostra, mas essas tabelas não replicam esse controle como RLS. Um usuário autenticado com papel `viewer` (sem acesso a Financeiro/RH na UI) pode, com o mesmo token JWT, chamar a API REST do Supabase direto (`fetch` no console do navegador) e ler/escrever em `transacoes`, `funcionarios_financeiro`, `estoque_itens` — nada na camada de banco impede isso, só a interface esconde o botão.
- **Nota de consistência**: a cobertura RBAC é inconsistente — tabelas centrais a fluxos recentes (produtos, projetos, contatos, boletos, contas_bancarias, notas_fiscais, remessas, separacoes) têm policy `spec069_*` correta; tabelas mais antigas/periféricas (financeiro de RH, estoque, quotes/Ubiqua, logs, fornecedores, transações) ficaram de fora da migração.

### A4 — Inserção anônima irrestrita em `orcamentos`/`orcamento_itens` (sistema principal)
- Já coberto em C3, listado aqui também por ser INSERT (não SELECT), categoria de impacto diferente: poluição de dados financeiros reais por qualquer script anônimo.

### A5 — Automação financeira (Edge Functions) sem autenticação
- **Onde**: `process-billing-automation`, `process-remittance`.
- **Evidência**: nenhuma checagem de `Authorization`; usam service role; processam todos os boletos pendentes, geram "nota fiscal" (hoje mock) e atualizam status de cobrança.
- **Exploração**: hoje a severidade é Alta (não Crítica) porque os dados gerados são mocks — mas a ausência de auth numa função que muda status de cobrança em produção vira Crítica no dia em que essa automação passar a gerar NF real.

---

## 🟡 MÉDIOS

### M1 — CORS wildcard (`*`) em todas as Edge Functions
Mitigado parcialmente por a autenticação ser via Bearer token (não cookie), mas ainda é uma camada de defesa a menos caso surja XSS em algum dos 10 frontends. Presente em `_shared/cors.ts` e replicado em quase toda função.

### M2 — Mensagens de erro internas vazando pro cliente
Padrão `catch (error) { return new Response(JSON.stringify({error: error.message})) }` em várias Edge Functions (`chat-agent`, `salvar-projeto`, `update-project`, `process-billing-automation`, `process-remittance`, `enviar-confirmacao-email`); `sync-sharepoint` chega a incluir resposta de erro bruta do Microsoft Graph na resposta ao cliente. Pode revelar nomes de tabela/coluna/constraint do schema real. O padrão bom (mensagem genérica ao cliente + log detalhado só no servidor) já existe em `parse-budget-pdf`/`generate-report` — só não foi aplicado em todo lugar.

### M3 — Dado de usuário pode vazar pro Gemini (Google) sem filtro
`classificar_solicitacao` concatena título+descrição (texto livre digitado por qualquer funcionário) e envia pra API do Gemini sem sanitização — se alguém colar um CPF ou valor de negociação real ao relatar um bug, esse texto sai da infraestrutura Lucenera. Risco de governança de dado, não falha de código.

### M4 — Exfiltração de mensagens de chat pra webhook de terceiro hardcoded
`chat-agent/index.ts` encaminha `{ message, user_id }` pra `https://workflow.usecurling.com/webhook/...` (n8n de terceiro) sem validação de conteúdo — vale confirmar se é integração autorizada pelo negócio.

### M5 — `sync-teams` aceita qualquer valor não-vazio como token válido
Só checa `if (!authHeader)`, nunca valida contra o Supabase Auth. Impacto real baixo hoje (função é mock), mas o padrão merece correção antes de qualquer implementação real.

### M6 — Código de SSO entre sistemas trafega via query string
`cross-system-auth.ts` (replicado nos 10 sistemas) manda o `sso_code` via `URLSearchParams`, não `location.hash` — fica no histórico do navegador e pode vazar via `Referer` até o `replaceState` rodar. Severidade real depende de quão curto/único-uso é o código no backend (Edge Functions `generate-cross-system-code`/`exchange-cross-system-code`, não auditadas em detalhe de expiração/reuso nesta rodada).

### M7 — Múltiplas policies redundantes/conflitantes por tabela
Ex.: `contatos` tem 4 policies de SELECT diferentes, todas `USING(true)`. RLS combina com OR — terreno fértil pra alguém adicionar uma policy nova mais restrita achando que substitui as antigas, e a permissiva continuar valendo (exatamente o que já aconteceu em `orcamentos`, achado C3).

---

## 🟢 BAIXOS / INFORMATIVOS

- **Dependência `Pillow==10.0.1`** em `04-Sistemas/lucenera-power-point/` (e duplicata em `script python power point/`) — possível RCE via `ImageMath.eval()` em versões pré-10.2.0, segundo conhecimento de treinamento (confiança média, precisa `pip-audit` real pra confirmar). `Werkzeug==3.0.1` no mesmo sistema — possível debugger RCE se `debug=True` estiver ativo (confirmar config do Flask).
- **`.env` corretamente ignorado pelo git** (`.gitignore` cobre `.env`/`.env.*`) — nenhum segredo real (`SERVICE_ROLE_KEY`, senha, token) encontrado hardcoded em código `.ts`/`.tsx`/`.py` de nenhum sistema. `.env` de cada sistema só tem a chave `anon` pública (esperada no bundle do cliente).
- **Planilhas financeiras reais commitadas no git** (`01-Documento/01 - Planilhas/*.xlsx`, `01-Documento/03 - Relatorios/*`) — dado real de contas a pagar/receber fica no histórico do repositório indefinidamente, mesmo que o arquivo seja removido depois. Risco depende da visibilidade do repositório GitHub (confirmar se é privado).
- **Nenhum header de segurança configurado no código** (CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) — os sistemas são SPAs estáticas na plataforma Skip, sem servidor próprio neste repo; depende da plataforma de hospedagem aplicar algo por padrão (não verificável a partir do código).
- **XSS clássico**: não encontrado. Único `dangerouslySetInnerHTML` em todos os 10 sistemas é o boilerplate `chart.tsx` do shadcn/ui (injeta CSS de config fixo, não HTML de usuário). Nenhum `eval`, `new Function`, `.innerHTML =` fora disso.
- **CSRF**: risco estruturalmente baixo, confirmado (não só assumido) — único cookie em uso em todos os 10 sistemas é `sidebar:state` (UI, shadcn/ui), não sessão. Auth 100% via Bearer token, imune ao vetor clássico de CSRF.
- **Injeção (SQL/NoSQL/command/path)**: nenhum achado nas Edge Functions (todas usam supabase-js parametrizado) nem no PL/pgSQL (único `EXECUTE format(...)` é código interno do Supabase Storage, com allowlist e parâmetros posicionados). Não é injeção.
- **Rate limiting**: nenhuma das Edge Functions tem proteção própria contra abuso (Supabase não tem rate limit nativo) — mais relevante nas que chamam API paga externa (Gemini) e nas que já são publicamente abusáveis por falta de auth (`welcome-email` → Resend).
- **Tokens de aprovação de cliente**: gerados com `gen_random_uuid()` (entropia forte); comparação de token nas RPCs de aprovação/recusa é null-safe e correta — o problema é só a policy paralela C5 que ignora essa RPC.
- **Hashing de senha**: `admin_update_user_password`/`criar_usuario` usam bcrypt (`crypt(..., gen_salt('bf'))`) corretamente — o problema não é o hashing, é o gate de quem pode chamar (C1).
- **Dependências frontend**: nenhum sinal de typosquatting/slopsquatting; `xlsx`/`sheetjs` e `lodash` antigo (famílias conhecidas de CVE) não aparecem em nenhum `package.json`; todos os 11 sistemas têm lockfile. `vite@8.x`/rolldown-vite (Central Lucenera) é versão muito recente — sem histórico de CVE confiável no meu conhecimento, recomenda-se `npm audit` real.
- **Grant amplo por padrão**: papel `anon` tem `GRANT` (não RLS) em 153 de ~160 tabelas/views do schema public. O grant sozinho não é a falha (RLS decide na prática), mas é uma configuração de base arriscada — facilita que uma tabela nova esqueça de restringir e fique exposta por padrão, como já aconteceu nos achados críticos acima.

---

## O que foi verificado e está OK (negativo, documentado por completude)

- Nenhum segredo real hardcoded em código de nenhum sistema (frontend, Edge Functions, scripts Python).
- Nenhum dump de banco (`.sql`/`.dump`/`.backup`) commitado no repositório.
- Nenhuma credencial de conexão hardcoded fora do `.env`.
- Nenhuma URL de importação Deno de origem não-oficial nas Edge Functions.
- `hub_pode_executar(NULL, ...)` é null-safe — retorna `false` para chamador sem sessão (diferente do bug de C1, que está na lógica *dentro* das 4 RPCs afetadas, não na RPC central de RBAC).
- ~15 tabelas centrais a fluxos recentes (produtos, projetos, contatos, boletos, contas_bancarias, notas_fiscais, remessas, separações) têm RLS corretamente vinculada a `hub_pode_executar`.

---

## Limitações desta auditoria

- **Dependências**: avaliação de CVE é heurística, baseada em conhecimento de treinamento sem acesso à internet — recomenda-se `npm audit`/`pip-audit`/Snyk real antes do go-live, especialmente em `lucenera-power-point`.
- **Exploração ao vivo**: os achados críticos de RLS foram confirmados pela definição literal das policies no banco real (prova suficiente por si só), não por um teste de leitura/escrita ao vivo contra a API pública — uma tentativa de teste controlado foi bloqueada pelo classificador de permissões desta sessão. Recomenda-se ao time validar com uma chamada controlada (ambiente de teste, nunca produção) antes de corrigir, para confirmar que o comportamento em produção bate exatamente com o que foi encontrado no schema (sincronizado em 27/08/2026).
- **Edge Functions/RPCs de SSO**: `generate-cross-system-code`/`exchange-cross-system-code` não foram lidas em detalhe nesta rodada (tempo de vida do código, uso único) — recomenda-se cobrir numa rodada seguinte se o achado M6 for levado adiante.
- Esta auditoria é um levantamento pontual, não substitui um processo contínuo de revisão de segurança (SAST/DAST/pentest formal) antes ou depois do lançamento.
