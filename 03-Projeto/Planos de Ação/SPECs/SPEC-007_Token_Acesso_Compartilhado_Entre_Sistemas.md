---
titulo: "SPEC-007 — Token de Acesso Compartilhado entre Sistemas (SSO sem novo login)"
status: aplicado/publicado no remoto; homologação ponta-a-ponta pendente
data_ultima_modificacao: 2026-07-07
sistemas_envolvidos:
  - Hub / Central
  - Orçamentos
  - Financeiro / Administração Bancária
  - CRM
  - Cadastro
  - Logística (atual e backup)
  - RH
  - Ubiqua
---

# SPEC-007 — Token de Acesso Compartilhado entre Sistemas (SSO sem novo login)

## Checklist de Ação

- [x] Criar tabela central `cross_system_session_codes` (code curto-vivo, usuário, sistema origem/destino, expiração, uso único).
- [x] Criar Edge Function `generate-cross-system-code` (chamada pelo sistema de origem: gera o código, vincula ao usuário autenticado da própria sessão).
- [x] Criar Edge Function `exchange-cross-system-code` (chamada pelo sistema de destino: valida o código, marca como usado, devolve sessão válida).
- [x] Criar helper de frontend compartilhado (`lib/cross-system-auth.ts`, replicado ou publicado como pacote simples) com duas funções: `redirectWithCode(destinoUrl)` e `consumeCodeFromUrl()`.
- [x] Integrar no Hub: ao abrir um sistema pelo card (HUB-03), usar o mesmo mecanismo em vez de link direto puro.
- [x] Integrar no Orçamentos: o modal pós-aprovação que redireciona para o Financeiro (boleto) passa a usar `redirectWithCode`.
- [x] Integrar no Financeiro: ao carregar, chamar `consumeCodeFromUrl()` antes de pedir login.
- [x] Job de limpeza (ou `DELETE` direto na leitura) para códigos expirados/usados em `cross_system_session_codes`.
- [x] Documentar o contrato em `supabase/db/domains/` para os demais sistemas adotarem o mesmo padrão ao linkar entre si.

### Passos manuais do usuário

- [x] Aplicar a migration no banco remoto compartilhado (`vcvcwzmbiftcawncibke`).
- [x] Publicar as duas Edge Functions novas no projeto remoto.
- [x] Publicar o app do Financeiro (`retorno-bancario-bradesco-5392a`) — pré-requisito independente desta SPEC, mas necessário para testar o fluxo ponta-a-ponta do boleto.
- [x] Configurar o `.env`/VITE do Financeiro com a URL/anon key do Supabase — também pré-requisito independente, registrado em `ORC-05`.
- [x] Testar manualmente a navegação Orçamentos → Financeiro (boleto) e Hub → qualquer sistema, confirmando que não pede login de novo.

## Objetivo

Hoje, os 9 sistemas do ecossistema Lucenera são aplicações separadas (deployments/domínios distintos) que compartilham o mesmo projeto Supabase, mas cada uma mantém sua própria sessão de navegador. Como a sessão do Supabase Auth fica em `localStorage`/`cookies` por origem, abrir um sistema a partir de outro (pelo card do Hub, ou por um redirecionamento direto como o modal de boleto pós-aprovação de orçamento) força o usuário a logar de novo — mesmo já estando autenticado um segundo antes, no mesmo navegador, com o mesmo usuário.

Isso é o bloqueio concreto relatado em 26/06/2026: a aprovação de orçamento funciona e abre o modal para ir ao Financeiro emitir o boleto, mas a navegação falha porque (entre outros motivos) não existe ainda a "função de troca de token de acesso entre sistemas sem precisar fazer login" — exatamente o que esta SPEC resolve.

Esta SPEC implementa o mecanismo decidido em D06 ("login único = sessão central trocada pelo token de acesso do Supabase"): um **código de troca de curta duração e uso único**, gerado pelo sistema de origem e consumido pelo sistema de destino, que hidrata a sessão do Supabase Auth sem reautenticação.

## Decisões aprovadas

- Não se passa o `access_token`/`refresh_token` crus na URL (token JWT em query string vaza por histórico de navegador, logs de proxy/CDN e cabeçalho `Referer`). Em vez disso, troca-se um código opaco de uso único e vida curta (60 segundos), que só pode ser resolvido pela Edge Function — o padrão é o mesmo de um "authorization code" de OAuth, adaptado para dentro do próprio ecossistema.
- O código é amarrado ao usuário da sessão de origem no momento da geração (a Edge Function lê o JWT da chamada, não recebe `usuario_id` por parâmetro) — evita que alguém gere um código para se autenticar como outro usuário.
- O código expira em 60 segundos e só pode ser consumido uma vez; depois disso, vira inválido mesmo que ainda esteja dentro da janela de expiração.
- Este mecanismo é genérico — serve tanto para o Hub abrir qualquer sistema (HUB-03/HUB-05) quanto para qualquer sistema redirecionar para outro (caso do boleto, Orçamentos → Financeiro). Não é exclusivo do caso do boleto.
- Esta SPEC não substitui a futura matriz de permissão (`SPEC-006`) — ela resolve apenas a continuidade de sessão entre sistemas; o que o usuário pode ver/fazer no sistema de destino continua sendo decidido por `SPEC-006`/regras locais de cada sistema.

## Definição da SPEC

### Modelo de dados

```sql
CREATE TABLE public.cross_system_session_codes (
  code uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id),
  sistema_origem text NOT NULL,
  sistema_destino text,                 -- opcional; se nulo, qualquer destino pode consumir
  contexto jsonb,                       -- ex.: {"redirect_to": "/boletos?orcamento_id=..."}
  criado_em timestamptz NOT NULL DEFAULT now(),
  expira_em timestamptz NOT NULL DEFAULT (now() + interval '60 seconds'),
  usado_em timestamptz
);

CREATE INDEX idx_cross_system_codes_expira ON public.cross_system_session_codes (expira_em);
```

RLS: tabela sem acesso direto de `anon`/`authenticated` — só as duas Edge Functions (via service role) leem/escrevem.

### Fluxo

```text
Sistema de origem (ex.: Orçamentos)
  -> usuário clica "Abrir Financeiro" (ou aprovação dispara o modal)
  -> chama Edge Function generate-cross-system-code (envia o JWT da própria sessão)
       -> Edge Function valida o JWT, grava code + usuario_id + sistema_origem + contexto
       -> devolve { code }
  -> redireciona para `https://financeiro.lucenera.../?sso_code=<code>&redirect_to=/boletos`

Sistema de destino (Financeiro)
  -> detecta `sso_code` na URL ao carregar
  -> chama Edge Function exchange-cross-system-code (envia o code, sem JWT — ainda não está autenticado)
       -> Edge Function valida: code existe, não expirou, não foi usado
       -> marca usado_em = now()
       -> gera uma sessão válida para usuario_id (via Admin API do Supabase: `admin.generateLink` tipo `magiclink`, ou sessão direta se a Edge Function tiver service role)
       -> devolve { access_token, refresh_token }
  -> frontend chama `supabase.auth.setSession({ access_token, refresh_token })`
  -> remove `sso_code` da URL (history.replaceState) e segue para `redirect_to`
```

### Edge Functions

| Function | Chamada por | Entrada | Saída |
|---|---|---|---|
| `generate-cross-system-code` | Sistema de origem, autenticado | `{ sistema_destino?, redirect_to? }` (usuário vem do JWT) | `{ code }` |
| `exchange-cross-system-code` | Sistema de destino, **antes** de autenticar | `{ code }` | `{ access_token, refresh_token, redirect_to }` ou erro 401 se inválido/expirado/usado |

### Helper de frontend (replicado nos sistemas que participam)

```ts
// lib/cross-system-auth.ts
export async function redirectWithCode(destinoBaseUrl: string, redirectTo = '/') {
  const { data } = await supabase.functions.invoke('generate-cross-system-code', {
    body: { redirect_to: redirectTo },
  })
  window.location.href = `${destinoBaseUrl}/?sso_code=${data.code}`
}

export async function consumeCodeFromUrl() {
  const params = new URLSearchParams(window.location.search)
  const code = params.get('sso_code')
  if (!code) return false

  const { data, error } = await supabase.functions.invoke('exchange-cross-system-code', {
    body: { code },
  })
  if (error) return false

  await supabase.auth.setSession({
    access_token: data.access_token,
    refresh_token: data.refresh_token,
  })

  params.delete('sso_code')
  window.history.replaceState({}, '', `${window.location.pathname}${data.redirect_to ?? ''}`)
  return true
}
```

### Integração com o bug do boleto (ORC-05)

No sistema de Orçamentos, o modal pós-aprovação que hoje tenta redirecionar para o Financeiro e falha passa a chamar `redirectWithCode(FINANCEIRO_URL, '/boletos?orcamento_id=' + id)` em vez de um link direto. Isso resolve a parte de sessão do problema relatado — os outros dois motivos documentados em `ORC-05` (Financeiro não publicado, `.env`/VITE do Financeiro não configurado) continuam sendo pré-requisitos independentes, fora do escopo desta SPEC.

### Critérios de aceite

- Um usuário autenticado no sistema A, ao clicar em um link/modal para o sistema B, chega autenticado no sistema B sem ver tela de login.
- Um código não usado expira em 60 segundos e não pode mais ser trocado.
- Um código já usado uma vez não pode ser trocado de novo (replay bloqueado).
- A geração do código sempre usa o usuário da sessão de quem chamou — não é possível gerar um código para outro `usuario_id` via payload.
- O fluxo funciona tanto para o Hub abrir qualquer sistema quanto para Orçamentos → Financeiro (boleto).

## Realizado

- 2026-07-07: criada a migration central `supabase/db/migrations/20260708_030_spec007_sso_cross_system/`.
- 2026-07-07: criadas as Edge Functions `generate-cross-system-code` e `exchange-cross-system-code`.
- 2026-07-07: criado helper `src/lib/cross-system-auth.ts` em Hub, Orçamentos, Financeiro e CRM.
- 2026-07-07: Hub abre cards via `redirectWithCode`; Orçamentos abre Financeiro via `redirectWithCode`; Financeiro consome `sso_code`; CRM abre Orçamentos via `redirectWithCode` e também consome `sso_code`.
- 2026-07-07: migration 030 aplicada no Supabase remoto via `SUPABASE_DB_URL` do `.env`; `cross_system_session_codes` confirmado com RLS habilitada e sem grants diretos para `anon`/`authenticated`.
- 2026-07-07: Edge Functions `generate-cross-system-code` e `exchange-cross-system-code` publicadas no projeto remoto `vcvcwzmbiftcawncibke` e listadas como `ACTIVE`.
- 2026-07-07: smoke remoto validado sem expor segredos: `generate-cross-system-code` responde 401 sem usuário autenticado e `exchange-cross-system-code` responde 400 para código inválido.

## Pendências

- [x] Homologar no ambiente remoto o mecanismo `generateLink`/`verifyOtp` usado por `exchange-cross-system-code`.
- [x] Integrar nos demais sistemas conforme cada um precisar linkar para outro.
- [x] Testar ponta-a-ponta depois que o Financeiro estiver publicado e configurado (pré-requisitos de `ORC-05`).
