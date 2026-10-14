---
titulo: "SPEC-198 — Sair do Skip: hospedagem na Cloudflare Pages + virada do banco para São Paulo"
status: pendente
data_ultima_modificacao: 2026-10-13
sistemas_envolvidos:
  - Os 16 sistemas de 04-Sistemas (todos Vite + React, skip-react-template)
  - Supabase (Ohio vcvcwzmbiftcawncibke → São Paulo bgtfrcbipuxnsexbppsh, SPEC-192)
  - Scripts Python (sync Connect, imports, SharePoint)
relacionadas: [SPEC-192, SPEC-120, SPEC-183]
---

# SPEC-198 — Sair do Skip: hospedagem na Cloudflare Pages + virada do banco para São Paulo

## Checklist de Ação

### Etapa 1 — Piloto: Showroom na Cloudflare (ainda no banco de Ohio)
- [x] Conferir que o Showroom local = versão no ar no Skip (54698 v0.0.20 `3d59cf6`).
- [x] Conferir que compila fora do Skip (`vite build` ok) e que não usa login, `goskip` nem nada exclusivo do Skip.
- [x] `public/_redirects` (`/* /index.html 200`) para as rotas `/peca/:codigo`, `/showroom` e `/admin` abrirem direto.
- [x] Projeto `showroom-lucenera` na Cloudflare Pages (conta Pedrollaghi@gmail.com, a da Ficha Técnica) ligado ao GitHub
  `pedrolalala/showroom-qtq8er2dk`, branch `main` → https://showroom-lucenera.pages.dev
- [x] Testado no `pages.dev`: vitrine (185 peças, fotos), `/peca/11233` aberto direto (igual ao goskip: R$ 10.527,66),
  `/showroom` e `/admin` abertos direto (sem 404).
- [ ] Usuário: entrar no `/admin` (senha da curadoria) e tirar/voltar uma peça; abrir no celular.
- [ ] Selo "Criado com o Skip" aparece (vem do `skip.js` no `index.html`) — tirar quando o Showroom sair do Skip de vez.
- [ ] Com o teste ok, decidir o endereço final (domínio próprio, ex. `showroom.lucenera.com.br`) e trocar o link divulgado.

### Etapa 2 — Preparar os outros 15 sistemas (sem trocar nada no ar)
- [ ] Para cada sistema: conferir local = Skip (`skip_project_status` + último commit), `vite build` local, `_redirects`.
- [ ] Trocar os endereços fixos `*.goskip.app` pelos novos: `HUB_URL`, `SystemSwitcher` (SPEC-120) e a tabela `systems`
  (`url`). Melhor ler de uma variável (`VITE_HUB_URL`) para não ter endereço fixo de novo.
- [ ] Auth do Supabase: incluir os endereços novos nas Redirect URLs (SSO entre sistemas, recuperação de senha).
- [ ] Tirar o `<script src="https://goskip.dev/skip.js">` do `index.html` depois que o sistema sair do Skip
  (conferir antes: o skip.js mexe em `scrollTo` — ver memória `feedback_skip_js_scrollto_promise_useeffect`).
- [ ] Projeto na Cloudflare para cada sistema (pode ser feito antes, apontando para Ohio, e testado no `*.pages.dev`).
- [ ] Edge Functions e migrations passam a ser publicadas pela CLI do Supabase (`supabase functions deploy`,
  migrations aplicadas como hoje pelo `supabase/db/migrations` central) — o Skip deixa de fazer isso.
- [ ] Scripts Python agendados: decidir GitHub Actions (recomendado) ou continuar no computador.

### Etapa 3 — Janela da virada (Cloudflare + banco São Paulo juntos)
- [ ] Avisar a equipe e parar o uso; parar sync Connect e SharePoint.
- [ ] Recarregar os dados de Ohio em São Paulo (passo a passo da SPEC-192, `Migracao_SP/PASSO_A_PASSO_MIGRACAO_SP.md`)
  e conferir contagem tabela a tabela.
- [ ] Rodar `Migracao_SP/scripts/pos_virada_links.py --real` (485+ links de arquivo).
- [ ] Ligar os 2 jobs do pg_cron em São Paulo; webhook da Focus NFe e SharePoint para o endereço novo.
- [ ] Nas 16 Cloudflare: `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` de São Paulo e publicar de novo.
- [ ] `.env` central, scripts Python, Memória Lucenera e dashboard Streamlit para São Paulo.
- [ ] Teste ponta a ponta (SPEC-192 Fase 2) e Ohio parado 1–2 semanas como garantia.
- [ ] Cancelar o Skip.

### Passos manuais do usuário
- [x] Conta na Cloudflare: o usuário já tem (13/10) — é a mesma usada pelo sistema de Ficha Técnica.
- [ ] Piloto: Cloudflare → **Workers & Pages → Create → Pages → Connect to Git** → autorizar o GitHub
  (`pedrolalala`) → escolher `showroom-qtq8er2dk` → preencher:
  - Framework preset: **Vite** (ou "None")
  - Build command: `npx pnpm@10 install --frozen-lockfile && npx vite build`
  - Build output directory: `dist`
  - Variáveis (Environment variables): `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` (os valores de **Ohio**,
    os mesmos do `.env` do Showroom — a chave publishable é pública, vai no site de qualquer jeito) e
    `NODE_VERSION` = `22` e `SKIP_DEPENDENCY_INSTALL` = `1` (o repositório tem `bun.lockb` velho e `pnpm-lock.yaml`;
    sem isso a Cloudflare pode instalar com a ferramenta errada — instalação limpa com pnpm 10 testada 13/10)
  - Save and Deploy, e mandar o endereço `*.pages.dev` para testar.
- [ ] Antes da janela: plano pago em São Paulo; segredos do SharePoint (Vault) e `GMAIL_*`/`RESEND_API_KEY` no painel de SP;
  religar/desligar a integração Supabase dos projetos no Skip (para o Skip não publicar mais em Ohio).
- [ ] Escolher dia/horário da janela (sugestão: sábado à noite) e quem testa cada sistema.

## Objetivo

O chefe não quer usar o Skip. Os 16 sistemas passam a ser publicados na Cloudflare Pages a partir do GitHub, e na mesma
janela o banco muda de Ohio para São Paulo (SPEC-192). O Supabase continua sendo o banco; nada muda nas telas para quem usa.

## Decisões aprovadas

- Hospedagem: **Cloudflare Pages** (comparativo enviado ao Filippo, doc "Hospedagem dos sistemas Lucenera").
- Piloto com o **Showroom** (13/10).
- Telas só mudam para São Paulo **na janela da virada**, junto com os dados recarregados — São Paulo é cópia parada
  de 08/10; ligar antes faria a equipe ver dados velhos e gravar em dois lugares.
- O código já lê banco/chave de `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` nos 16 sistemas (conferido 13/10:
  nenhum endereço de Ohio fixo em `src/`); a troca é só nas variáveis da Cloudflare.

## Definição da SPEC

### Estado atual (13/10)
| Item | Hoje (Skip) | Depois (Cloudflare) |
|---|---|---|
| Código | GitHub + cópia no Skip | só GitHub (cada push publica) |
| Banco/chave | env do Skip ou integração Supabase (CRM, Orçamentos, Ubiqua, RH) | Environment variables da Cloudflare |
| Edge Functions/migrations | Skip publica sozinho (já causou reversões) | CLI do Supabase, só quando a gente manda |
| Endereço | `*.goskip.app` | `*.pages.dev` ou domínio próprio |
| Rotas internas (F5) | Skip resolve | `public/_redirects` |

### Critérios de aceite do piloto
- Todas as rotas abrem direto pelo endereço (sem 404 ao atualizar).
- Fotos e preços iguais ao `tela-showroom-522b1.goskip.app`.
- `/admin` grava (tirar/voltar peça) e a mudança aparece no Skip também (mesmo banco).

## Realizado

### 2026-10-13
- SPEC criada. Showroom conferido (local = Skip v0.0.20), build local ok, `public/_redirects` criado e enviado ao GitHub
  (`1c6e46f`). Ensaio do build da Cloudflare: clone limpo do GitHub, sem `.env`, `pnpm@10 install --frozen-lockfile` +
  `vite build` ok, `dist/_redirects` presente.
- Projeto Cloudflare `showroom-lucenera` criado e publicado (1º build ~35 s, pnpm 10.11.1, Node 22). Testes acima ok.

### 2026-10-13/14 — os 15 sistemas na Cloudflare
- Conferência GitHub × Skip (build limpo): todos com as mesmas telas. Vendas tinha `pnpm-lock.yaml` velho (corrigido).
- `public/_redirects` nos 13 restantes + 13 projetos criados (Ohio): cadastro-lucenera, catalogo-ubiqua,
  central-lucenera, compras-lucenera, producao-lucenera, financeiro-lucenera (= Orçamentos), vendas-lucenera,
  separacao-lucenera, adm-bancaria-lucenera, logistica-lucenera, crm-lucenera, rh-lucenera, dashboard-lucenera
  (todos `*.pages.dev`). 13 bundles idênticos ao Skip; Produção e Dashboard diferem só em hash.
- 14/10: links fixos no código (Central, Orçamentos, Adm. Bancária) trocados para `*.pages.dev` nos 13 repositórios.
  Migration 207 (`systems.link` do Hub → `*.pages.dev`; logistica/ubiqua/memoria/solicitacoes ficam como estão)
  escrita, dry-run ok (13 linhas); APLICADA em 14/10 pelo usuário (Management API, 201).
- 14/10: Memória (`memoria-lucenera.pages.dev`; GitHub estava sem 5 arquivos e sem supabase-js, completado do Skip
  57204 — `896cc9e`) e Central de Solicitações (sem GitHub: repositório novo `central-de-solicitacoes` montado do Skip
  53113 v0.0.5, submodule; `solicitacoes-lucenera.pages.dev`, CSS idêntico ao Skip). Migration 209 (links do Hub
  dos dois) escrita, dry-run ok.

## Pendências

- [ ] SPEC-198 piloto — usuário testar o `/admin` em https://showroom-lucenera.pages.dev (entrar e tirar/voltar uma peça) e no celular.
- [ ] SPEC-198 — `public/_redirects` existe só no GitHub do Showroom; o Skip 54698 não recebeu (não precisa, ele é abandonado depois da virada).
- [ ] SPEC-198 — definir dia da janela da virada (Cloudflare + banco São Paulo) e concluir pendências da SPEC-192 (plano pago, segredos SharePoint/e-mail).
- [ ] SPEC-198 — migration 207 aplicada; falta testar login + troca entre sistemas pela Cloudflare.
- [ ] SPEC-198 — avisar usuários dos endereços novos; links de aprovação já enviados a clientes (`gestaofinanceiralucenera.goskip.app/aprovacao`) só funcionam enquanto o Skip estiver no ar.
- [ ] SPEC-198 — aplicar migration 209 (Memória e Solicitações no Hub). "Sistema de Entregas" do Hub aponta para `lucenera.lovable.app`.
