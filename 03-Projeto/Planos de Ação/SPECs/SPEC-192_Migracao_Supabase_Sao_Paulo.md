---
titulo: "SPEC-192 — Migrar o Supabase de Ohio (us-east-2) para São Paulo (sa-east-1), em plano pago"
status: aguardando aprovação
data_ultima_modificacao: 2026-10-08
sistemas_envolvidos:
  - Supabase "LUCENERA DATACENTER" (ref vcvcwzmbiftcawncibke, us-east-2, compute Nano) -> projeto novo em sa-east-1
  - Todos os sistemas do Skip (16) + Memória Lucenera (app estático com supabase-adapter.js)
  - scripts/ (.env central, sync Connect, SharePoint), dashboard Streamlit
  - Integrações externas: Focus NFe (webhook), SharePoint, Gemini, SMTP
---

# SPEC-192 — Migração do Supabase para São Paulo

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
- [ ] 0.3 Inventário completo de Ohio (com o banco de pé), salvo em `03-Projeto/Migracao_SP/`:
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
    dashboard Streamlit, Power BI se conectado).
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
