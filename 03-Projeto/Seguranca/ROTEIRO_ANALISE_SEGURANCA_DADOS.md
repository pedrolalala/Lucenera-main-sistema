---
titulo: "Roteiro fixo — análise de segurança de dados dos sistemas Lucenera"
criado: 2026-11-03
relacionadas: [SPEC-069, SPEC-196, SPEC-198]
scripts: scripts/seguranca/
relatorios: 03-Projeto/Seguranca/rodadas/
---

# Roteiro de análise de segurança de dados

Documento fixo. Não é uma SPEC: é o **passo a passo que se repete** sempre que formos conferir se algum dado está
exposto. Cada vez que o roteiro for executado, gerar um relatório novo em `rodadas/AAAA-MM-DD_rodada_NN.md` e abrir
SPEC só para o que precisar de correção.

## Princípio

Tudo que está no site (HTML, JavaScript, chave `anon`) é público: qualquer um vê no **F12 → DevTools** (abas
*Sources* e *Network*). Quem protege os dados é o **banco** (RLS + grants) e as **Edge Functions** — nunca a tela.
Por isso a análise olha de fora para dentro, com três "personagens":

| Personagem | Como simular | O que deveria conseguir |
|---|---|---|
| **Visitante** (sem login) | chave `anon` tirada do próprio site | só o Showroom público (`vw_showroom_publico`, `showroom_import_pecas`) |
| **Conta nova** (alguém que se cadastrou sozinho — o signup está aberto) | `authenticated` com `sub` que não existe em `usuarios`, em ROLLBACK | nada de financeiro, RH, cliente, custo |
| **Funcionário sem o sistema** (ex.: auxiliar de estoque) | `authenticated` com o `sub` real, em ROLLBACK | só o que os papéis dele liberam |

## Regras da execução

- **Só leitura.** Nenhum teste grava, apaga ou chama função que mexe em dado. Edge Function só com `OPTIONS`
  (preflight); RPC nunca é chamada pela API — é avaliada pelo catálogo do banco.
- Teste de banco sempre em transação `READ ONLY` que termina em `ROLLBACK`.
- Nunca imprimir chave/senha inteira (mascarar `eyJhb…xxxx`). Nunca colar relatório com segredo no GitHub.
- Conexão direta ao banco (`SUPABASE_DB_URL`) e Management API precisam de **autorização do usuário na hora**
  (o modo automático bloqueia leitura em produção).
- Sempre testar **os dois bancos** enquanto Ohio existir (`vcvcwzmbiftcawncibke`) — os sites antigos do Skip
  continuam no ar apontando para ele.

## Etapas

### 1. Inventário do que está no ar
- Sites Cloudflare `*-lucenera.pages.dev` + `catalogo-ubiqua.pages.dev` e os endereços antigos `*.goskip.app`
  (lista em `scripts/seguranca/01_varrer_sites.py`). Atualizar quando nascer sistema novo.
- Edge Functions publicadas em cada projeto (`supabase/functions/` + preflight `OPTIONS`).
- Buckets de storage e se são públicos.

### 2. O que o navegador entrega (equivale ao DevTools) — `01_varrer_sites.py`
Para cada site, baixar `index.html` e todos os `.js`/`.css` e procurar:
- [ ] JWT com `role` diferente de `anon` (principalmente `service_role`) ou `sb_secret_…`
- [ ] chaves de terceiros: Google/Gemini (`AIza…`), Resend (`re_…`), OpenAI/Anthropic, GitHub, AWS, Focus NFe
- [ ] webhooks (Teams/Power Automate/Slack) e URLs internas
- [ ] senha/token escrito no código (`password: "…"`, `token = "…"`)
- [ ] source maps acessíveis (`.js.map` → expõe o código-fonte inteiro)
- [ ] cabeçalhos de segurança: CSP, `X-Frame-Options`, HSTS, `X-Content-Type-Options`, `Referrer-Policy`
- [ ] qual banco cada site usa (SP × Ohio)

### 3. Visitante na API — `02_testar_visitante_api.py`
- [ ] `GET /rest/v1/` (lista de tabelas) deve dar 401
- [ ] `GET` com `limit=1` em **toda** tabela/view (schemas `public` e `memoria`): só o Showroom pode responder 200
- [ ] tabela que responde 200 com 0 linhas = grant para `anon` sobrando (regra 1 da SPEC-196) — anotar
- [ ] `GET /storage/v1/bucket` não lista nada; bucket público só se for de propósito (fotos do Showroom)
- [ ] para cada bucket usado no código (`grep storage.from(`): `GET /storage/v1/object/public/<bucket>/__nao_existe__`
      → "Bucket not found" = privado; "Object not found" = **público**
- [ ] `POST /storage/v1/object/list/<bucket>` com a chave `anon` não pode devolver arquivo (contar, nunca baixar)
- [ ] nome de arquivo sequencial/adivinhável (`ORC-2026-000001.pdf`) em bucket público = exposto mesmo sem listagem
- [ ] `GET /auth/v1/settings`: anotar `disable_signup` e provedores ligados

### 4. Edge Functions (a porta dos fundos)
A chave `anon` é um JWT válido: `verify_jwt = true` **não basta**. Para cada função, no código:
- [ ] usa `SUPABASE_SERVICE_ROLE_KEY`? Então tem que conferir quem chamou (`auth.getUser()` + papel/
      `pode_acessar_sistema`) **ou** um segredo próprio (`x-…-secret`, cron) antes de ler/gravar
- [ ] aceita campos livres do corpo e grava direto (`.update(body)`)? → crítico
- [ ] manda e-mail/WhatsApp/Teams para endereço vindo do corpo? → abuso (spam/phishing com o nome da empresa)
- [ ] chama IA paga sem login? → custo
- [ ] `Access-Control-Allow-Origin: *` em função que grava
- [ ] está publicada (preflight 200) mesmo sem uso? → despublicar

### 5. Banco por dentro — `03_testar_banco_papeis.py` (precisa de autorização)
Catálogo + contagem real como **visitante** e como **conta nova**, em `READ ONLY`/`ROLLBACK`:
- [ ] tabela sem RLS em schema exposto
- [ ] grant `INSERT/UPDATE/DELETE` para `anon`
- [ ] política `USING (true)`/`WITH CHECK (true)` para `authenticated` em dado sensível
- [ ] mais de uma política permissiva no mesmo comando (vale a mais aberta)
- [ ] view de dono `postgres` sem portão no `WHERE` (pula o RLS de baixo) e sem `security_invoker`
- [ ] função `SECURITY DEFINER` executável por `anon`/conta nova sem conferir papel; `search_path` fixo
- [ ] o que uma **conta nova** consegue ler (lista com contagem) — com signup aberto, isso é quase público
- [ ] repetir como 1 funcionário real sem o sistema (auxiliar de estoque)
- [ ] `produtos`: custo só pela `vw_produtos_custo` (SPEC-193)

### 6. Autenticação e contas
- [ ] signup aberto é necessário? (Ubiqua cria conta? se não, desligar no painel Auth)
- [ ] confirmação de e-mail ligada; política de senha; proteção contra senha vazada
- [ ] Redirect URLs só dos domínios atuais
- [ ] usuários sem uso / sem papel / da Ubiqua (`somente_ubiqua`) — revisar lista
- [ ] chaves: quando foi a última troca da `service_role`; quem tem o `.env`

### 7. Resto do ambiente
- [ ] Ohio: está só leitura? quando apagar? (SPEC-198) — enquanto existir, é uma cópia inteira dos dados
- [ ] sites do Skip ainda no ar → derrubar ou trocar por redirecionamento
- [ ] repositórios GitHub: públicos ou privados? histórico com `.env`/chave? (`git log -p | grep`)
- [ ] backups (`schema backup`) não expostos à API
- [ ] logs: Edge Functions não imprimem dado pessoal/segredo

## Classificação dos achados

| Nível | Quando | Prazo |
|---|---|---|
| **Crítico** | alguém de fora lê ou altera financeiro/RH/cliente, ou age com a chave mestra | parar e corrigir no mesmo dia |
| **Alto** | conta nova (signup) lê dado sensível; abuso de e-mail/IA; cópia de dados esquecida | SPEC na semana |
| **Médio** | grant/política sobrando sem dado vazando hoje; cabeçalho ausente | junto da próxima mudança |
| **Baixo** | boa prática, informação pública | backlog |

## Saída de cada rodada

1. `rodadas/AAAA-MM-DD_rodada_NN.md`: o que foi testado, o que **não** foi (e por quê), achados por nível,
   evidência (sem segredo), comparação com a rodada anterior.
2. Uma SPEC por grupo de correção (ex.: "Edge Functions sem checagem de quem chama").
3. Linha no `CHANGELOG.md`.
4. Depois de corrigir: rodar de novo só as etapas afetadas e marcar no relatório.

## Frequência

- Rodada completa: **mensal** e depois de qualquer sistema novo ou mudança de permissão grande.
- Etapas 2 e 3 (rápidas, sem autorização especial): depois de cada publicação.
