---
titulo: "SPEC-192 — Migrar o Supabase de Ohio (us-east-2) para São Paulo (sa-east-1), em plano pago"
status: adiada (excepcional — fazer com tempo, fora da rotina)
data_ultima_modificacao: 2026-10-09
sistemas_envolvidos:
  - Supabase "LUCENERA DATACENTER" (ref vcvcwzmbiftcawncibke, us-east-2, compute Nano) -> projeto novo em sa-east-1
  - Todos os sistemas do Skip (16) + Memória Lucenera (app estático com supabase-adapter.js)
  - scripts/ (.env central, sync Connect, SharePoint), dashboard Streamlit
  - Integrações externas: Focus NFe (webhook), SharePoint, Gemini, SMTP
---

# SPEC-192 — Migração do Supabase para São Paulo

> **ADIADA em 09/10/2026.** Fica para ser feita de forma excepcional, com tempo e janela própria. Não interfere no trabalho do dia a dia: todos os sistemas seguem em Ohio. O projeto de São Paulo é só cópia parada (na virada, recarregar os dados do zero).

## Por quê (08/10/2026)

- 08/10 ~19h: banco, API e login fora do ar — **Disk IO Budget esgotado**. O projeto está em **Nano** (sem add-on de
  compute: 0,5 GB RAM, disco baseline 5 MB/s). Micro = 1 GB RAM, baseline 87 MB/s.
- Ohio fica a ~120–150 ms (ida e volta) do Brasil; São Paulo ~10–30 ms. Telas que fazem várias consultas em sequência
  ganham bastante. Dados no Brasil (LGPD).
- Decisão do usuário: migrar tudo para São Paulo e pagar o plano lá.
- Região não muda no projeto existente: é **projeto novo + cópia de tudo + troca de URL/chaves** em todos os sistemas.

## Ponto crítico: muda URL e chaves

Projeto novo = novo `ref`, nova URL `https://<novo-ref>.supabase.co`, nova anon key, nova service role key, nova senha
do banco, novo host do pooler. Tudo que aponta para `vcvcwzmbiftcawncibke` precisa ser trocado.

## Checklist

### Fase 0 — Preparar (antes da janela)

- [ ] 0.1 Assinar o **Pro** na organização (US$ 25/mês; o plano é da organização e cobre os dois projetos durante a
  migração). Subir Ohio para **Micro** já — tira o banco do sufoco e permite fazer o dump sem esgotar o disco de novo
  (cobrança por hora; para quando Ohio for apagado).
- [ ] 0.2 Criar o projeto novo em **South America (São Paulo) — sa-east-1**, compute **Micro** (ou Small se o
  desempenho pedir), Postgres 17 (mesma versão de Ohio: 17.6).
- [ ] 0.3 Inventário completo de Ohio (com o banco de pé), salvo em `03-Projeto/Planos de Ação/Excepcional - fazer com tempo/Migracao_SP/`:
  - extensões (`pg_extension`), schemas, contagem de linhas por tabela (para conferir depois);
  - jobs do `pg_cron` (ex.: `ferias-gerar-periodos`) e chamadas `pg_net`/`net.http_post` em funções e triggers
    (procurar `vcvcwzmbiftcawncibke`, `supabase.co`, chaves dentro de funções — ex. sync SharePoint);
  - Database Webhooks; publicações do Realtime;
  - buckets do Storage (nome, público/privado, políticas) e volume de arquivos;
  - Edge Functions **deployadas** (lista pela Management API — há funções que só existem nos projetos do Skip:
    emitir-nota-fiscal, focus-nfe-webhook, verificar-notas-pendentes, cadastro-ubiqua, excluir-conta-ubiqua,
    gerar-pdf-orcamento-ubiqua, interpretar-reuniao, classificar_solicitacao, generate/exchange-cross-system-code,
    process-billing-automation, sharepoint-projetos-push/pull…) e seus **secrets** (Focus NFe, SharePoint, Gemini…);
  - Auth: provedores, URLs de redirecionamento (todos os `*.goskip.app`), SMTP, modelos de e-mail, configurações
    (expiração de JWT, confirmação de e-mail);
  - onde cada sistema do Skip guarda URL/anon key (env do Skip `skip_env_list` e/ou integração Supabase do projeto
    Skip — **o Skip executa migrations e deploya functions no Supabase ligado**: tem que ser religado ao projeto novo,
    senão continua publicando em Ohio);
  - URLs fixas no código (`grep vcvcwzmbiftcawncibke` em 04-Sistemas, scripts, Memória `supabase-adapter.js`,
    dashboard Streamlit, Power BI se conectado). Achados no código-fonte local (08/10, conferir também no Skip):
    `catalogo-pecas-ubiqua-e6fa0/src/components/PartDetailSheet.tsx`, `catalogo-pecas-ubiqua-e6fa0/src/hooks/use-parts.ts`,
    `lucenera-crm-3bd29 (1)/src/components/Layout.tsx`, `separacao-parcial/src/pages/LoginPage.tsx`,
    `separacao-parcial/src/pages/SeparacaoParcialPage.tsx`, `supabase/.temp/linked-project.json` (CLI linkada);
    os demais sistemas têm o ref só no build (`dist/`), vindo do env do Skip.
- [ ] 0.4 Ensaio: restaurar um dump de Ohio no projeto novo, conferir erros e contagens, apagar e repetir na janela.

### Fase 1 — Janela de migração (fim de semana/noite, sistemas parados)

- [ ] 1.1 Avisar a equipe; congelar uso (nenhum sistema gravando). Parar o sync Connect e o SharePoint.
- [ ] 1.2 Dump de Ohio: `roles`, `schema` e `data` (inclui `auth` — usuários com as mesmas senhas e IDs), com a CLI do
  Supabase (`supabase db dump`) ou `pg_dump` pelo pooler.
- [ ] 1.3 Restaurar em São Paulo; recriar extensões; conferir **contagem de linhas tabela a tabela** igual a Ohio.
- [ ] 1.4 Copiar os arquivos do Storage (bucket por bucket, mesmos caminhos) e conferir quantidade/tamanho.
- [ ] 1.5 Recriar jobs do `pg_cron`, Database Webhooks e trocar URLs/chaves dentro de funções/triggers.
- [ ] 1.6 Deployar todas as Edge Functions no projeto novo + recriar os secrets.
- [ ] 1.7 Auth: redirect URLs, SMTP, modelos de e-mail, provedores.
- [ ] 1.8 Trocar URL + anon key nos 16 sistemas do Skip (e religar a integração Supabase de cada um), republicar
  todos; Memória Lucenera; `.env` central (SUPABASE_URL, chaves, SUPABASE_DB_URL, SUPABASE_ACCESS_TOKEN se mudar);
  dashboard Streamlit.
- [ ] 1.9 Integrações externas: webhook da Focus NFe para a URL nova; SharePoint (functions push/pull).

### Fase 2 — Validar e desligar Ohio

- [ ] 2.1 Teste ponta a ponta com usuário real em cada sistema: login (senha antiga funciona), Central → troca de
  sistema (SSO), orçamento → aprovação → venda, NF-e em homologação, RH férias/faltas, Consulta de Produtos (preço da
  SPEC-190 igual), Showroom com fotos, upload de arquivo.
- [ ] 2.2 Rodar o sync Connect no projeto novo (dry-run tem que dar zero alteração além do esperado).
- [ ] 2.3 Ohio fica pausado/só leitura por 1–2 semanas como garantia; depois baixar um backup final e **apagar**
  (a cobrança dele para).
- [ ] 2.4 Atualizar documentação e memórias (`reference_supabase_*`, pooler `aws-0-sa-east-1`…, ref novo).

## Realizado

### 2026-10-08 — projeto novo + inventário + ensaio do banco

- Projeto novo: ref `bgtfrcbipuxnsexbppsh`, **sa-east-1**, Postgres 17.11 (Ohio 17.6). Pooler que funciona nesta rede:
  `aws-1-sa-east-1.pooler.supabase.com:5432`, usuário `postgres.bgtfrcbipuxnsexbppsh` (host direto `db.…` não resolve
  aqui). `.env`: bloco "NOVO SUPABASE SÃO PAULO" (mesmos nomes do bloco de Ohio — scripts ainda leem Ohio, o último).
  **Compute aparece sem add-on (Nano) — colocar Pro/Micro antes da virada.**
- Inventário de Ohio (`scratchpad migsp/inventario_ohio.txt`): 116 MB; extensões pg_cron, pg_net (schema public),
  pg_trgm, unaccent (public), uuid-ossp, pgcrypto, vault; 2 cron (`sharepoint-projetos-pull` */5 min,
  `ferias-gerar-periodos` diário); 2 funções com URL (`disparar_pull_sharepoint`, `trg_projetos_sharepoint_push_fn`,
  usam vault: `sharepoint_pull_url`, `sharepoint_push_url`, `sharepoint_sync_secret`, `supabase_anon_key`);
  9 buckets (~140 MB, quase tudo `showroom-lucenera`); 27 Edge Functions; 16 secrets de functions (GEMINI, GMAIL_*,
  RESEND, SHAREPOINT_*…); Auth: 38 redirect URLs `*.goskip.app`, site_url localhost, sem SMTP próprio.
- **Ensaio do banco OK**: estrutura + dados de `public`/`memoria` + `auth.users`/`auth.identities` + `storage.buckets` +
  `supabase_migrations` copiados. Conferido: 156 tabelas, 128.623 linhas, 189 funções, 438 policies, 89 triggers,
  61 views — idênticos; acentos ok.
- Cuidados descobertos no ensaio (repetir na virada):
  1. `PGCLIENTENCODING=UTF8` no psql (Windows lia como WIN1252 → "OrÃ§amento").
  2. Tirar `ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin"` do dump (já existe no projeto novo; dá permissão negada).
  3. Criar antes as extensões nos mesmos schemas (pg_net e unaccent em `public`).
  4. Criar o schema `supabase_migrations` antes dos dados.
  5. CHECK `orcamentos_data_inicio_pagamento_check` é NOT VALID (usa a data de hoje): dropar antes dos dados e
     recriar NOT VALID depois.
  6. Dados com `SET session_replication_role = replica` (não dispara `handle_new_user` nem triggers de SharePoint).
- Na virada: Ohio continua mudando até lá → repetir só os dados (esvaziar e recarregar) na janela.

### 2026-10-09 — etapa 2 (preparar São Paulo), sem afetar quem usa

- [x] Storage: 402 arquivos copiados (`03-Projeto/Planos de Ação/Excepcional - fazer com tempo/Migracao_SP/scripts/copiar_storage.py`, idempotente); conferido por
  bucket (quantidade e bytes iguais) e foto aberta pelo endereço público de SP.
- [x] **485 links de arquivos gravados nos dados** apontavam para Ohio (`produtos.imagem_showroom_url` 219,
  `showroom_import_pecas.imagem_url` 167, `revenda_ubiqua.imagem_catalogo_url` 83, `producao_pedidos` PDFs,
  `configuracao_empresa_ubiqua.logo_url`, `quotes.items`, logs da produção). Script `pos_virada_links.py` (triggers
  desligados) troca para SP — testado na cópia de ensaio: 485 trocados; 335/338 links abrem. Os 3 que não abrem
  (`revenda-ubiqua-images/catalogos/339104, 189201, 339101_catalogo.jpg`) **já não abriam em Ohio** (arquivo nunca enviado).
  **Rodar de novo na virada, depois de recarregar os dados.**
- [x] pg_cron em SP: `sharepoint-projetos-pull` e `ferias-gerar-periodos` criados **desligados** (ligar na virada).
- [x] Auth: 37 redirect URLs, site_url e jwt_exp iguais a Ohio. Modelos de e-mail de Ohio eram os padrões antigos — não copiados.
- [x] 27 Edge Functions baixadas do que está publicado em Ohio (`supabase functions download --use-api`, cada uma
  com o próprio `_shared`), sem endereço fixo, e publicadas em SP com o mesmo verify_jwt; todas respondem.
  Lista: `03-Projeto/Planos de Ação/Excepcional - fazer com tempo/Migracao_SP/edge_functions_ohio.json`.
- [x] Secrets em SP: `GEMINI_API_KEY`, `SHAREPOINT_CLIENT_ID/TENANT_ID/CLIENT_SECRET` (do `.env`; hash igual a Ohio).
- [x] Endereço fixo no código trocado por `import.meta.env.VITE_SUPABASE_URL` (continua Ohio até a virada):
  Catálogo Ubiqua 33302 v0.0.101, CRM 24580 v0.0.318, Separação Parcial 48801 v0.0.52 — publicados, conferido no ar;
  migrations dos 3 já registradas (nada executado no banco); commits nos submodules.
- [x] Configuração dos sistemas no Skip: 12 têm `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` nas variáveis
  (Cadastro, Vendas, Separação, Adm. Bancária, Logística, Dashboard, Garantia, Compras, Central, Showroom, Produção,
  Memória); 4 recebem pela **integração Supabase do Skip** (CRM 24580, Orçamentos 32554, Ubiqua 33302, RH 23919) —
  sem variável visível. Separação 48801 também tem um `.env` no projeto Skip.

### Falta

- [ ] Secrets que dependem do usuário: `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `RESEND_API_KEY`, `lucenera Gestão Financeira`.
- [ ] Vault em SP (`sharepoint_pull_url`, `sharepoint_push_url`, `sharepoint_sync_secret`, `supabase_anon_key`) e
  secret `SHAREPOINT_SYNC_SECRET`: ler o cofre de Ohio e as chaves de SP foi **bloqueado pelo classificador**
  (credenciais) — precisa de autorização do usuário ou ele cadastra pelo painel.
- [ ] **Integração Supabase de cada projeto no Skip**: religar ao projeto novo na virada (tela do Skip — é ela que
  publica migrations/functions e injeta as variáveis nos 4 sistemas acima). Tarefa do usuário no Skip.
- [ ] Ensaio geral (etapa 3) e virada (etapa 4).
- [ ] Plano pago + Micro em SP antes da virada (usuário: amanhã).

## Custos (conferir no painel no momento da assinatura)

- Pro: US$ 25/mês por organização (inclui crédito de compute que cobre um Micro).
- Durante a migração, os dois projetos coexistem alguns dias (cobrança por hora).
- Preço de compute em sa-east-1 pode ser um pouco maior que em us-east-2.

## Riscos

- Esquecer uma URL/chave fixa → sistema continua falando com Ohio sem ninguém perceber. Mitigação: grep do ref antigo
  em tudo + Ohio pausado depois do corte (qualquer coisa esquecida quebra na hora e aparece).
- Skip republicando migrations/functions no projeto errado (ver memória "Publicar no Skip EXECUTA migrations legadas"):
  religar a integração antes de publicar qualquer sistema.
- Usuários/sessões: tokens de login antigos deixam de valer (JWT secret novo) — todo mundo faz login de novo.

## Perguntas abertas

1. Data/horário da janela (sugestão: sábado à noite)?
2. Compute em São Paulo: Micro ou Small?
3. Quem avisa a equipe e quem testa cada sistema no domingo?
