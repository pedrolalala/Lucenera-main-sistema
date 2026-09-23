---
titulo: "SPEC-160 — Esqueci minha senha (recuperação por e-mail) no Catálogo Ubiqua"
status: pendente
data_ultima_modificacao: 2026-09-23
sistemas_envolvidos:
  - Catálogo Peças Ubiqua (04-Sistemas/catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-160 — Esqueci minha senha (recuperação por e-mail) no Catálogo Ubiqua

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Origem

Achado durante o teste ao vivo da SPEC-159 (2026-09-23): o Catálogo Ubiqua não tem nenhum jeito de recuperar a senha para quem está **deslogado** e esqueceu a senha — a tela de login (`AuthWrapper.tsx`) só tem login e criar conta, sem link de recuperação. Outros sistemas do ecossistema (Logística, CRM) já têm esse fluxo (`ForgotPasswordPage.tsx`/`ResetPasswordPage.tsx` na Logística). Usuário pediu para adicionar aqui também.

## Checklist de Ação

- [x] Criar `src/pages/ForgotPasswordPage.tsx`: formulário com campo e-mail, chama `supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/redefinir-senha` })`, mostra tela de confirmação genérica ("se o e-mail existir, enviamos um link") — mesmo padrão de UX já usado em `lucenera-logistics-b7cd1/src/pages/ForgotPasswordPage.tsx`, adaptado ao visual do Ubiqua (usa `Input`/`Label`/`Button`/`Card` já existentes no projeto, não os componentes da Logística)
- [x] Criar `src/pages/ResetPasswordPage.tsx`: formulário com Nova Senha + Confirmar Nova Senha, valida sessão de recuperação (`supabase.auth.getSession()` — se não houver sessão nem hash de recovery na URL, redireciona para `/esqueci-senha` com aviso de link inválido/expirado), chama `supabase.auth.updateUser({ password })`, depois `supabase.auth.signOut()` e redireciona para a tela de login (`/`)
- [x] Adicionar link "Esqueci minha senha?" no formulário de login em `src/components/AuthWrapper.tsx` (só no modo login, não no modo cadastro), apontando para `/esqueci-senha`
- [x] Registrar as duas rotas novas em `src/App.tsx` **fora** do `<AuthWrapper>` (como rotas públicas de topo, mesmo padrão do `/onboarding`): `/esqueci-senha` → `ForgotPasswordPage`, `/redefinir-senha` → `ResetPasswordPage`. Importante: não podem ficar dentro do `<AuthWrapper>`, porque o link de recuperação do Supabase cria uma sessão válida ao ser aberto — se a rota estivesse dentro do `AuthWrapper`, ele trataria o usuário como logado e mostraria o catálogo em vez da tela de redefinir senha
- [x] Validação de senha nova no `ResetPasswordPage.tsx`: mínimo 6 caracteres (mesmo padrão do resto do app, ver SPEC-159), confirmação igual

### Passos manuais do usuário

- [x] Conferir redirect URL allowlist do Supabase — verificado via Management API (`GET /v1/projects/{ref}/config/auth`, campo `uri_allow_list`): `https://catalogo-pecas-ubiqua-e6fa0.goskip.app/**` já está cadastrado (wildcard cobre `/redefinir-senha`). Nada a fazer aqui.
- [x] Publicado no Skip — `0.0.90` (`b7f3400`), produção: https://catalogo-pecas-ubiqua-e6fa0.goskip.app
- [x] Testado em produção (2026-09-23), parcialmente ao vivo: guard de `/redefinir-senha` sem sessão → redireciona corretamente para `/esqueci-senha` com toast "Link inválido ou expirado"; formulário de `/esqueci-senha` → `resetPasswordForEmail` chamado com sucesso (sem erro), tela de confirmação genérica exibida, e-mail de recuperação real disparado para a conta do usuário (pedrollaghi@gmail.com) — pendente só a etapa final de abrir o link recebido e confirmar a troca (o agente não tem acesso à caixa de entrada do usuário)
- [ ] Usuário: abrir o e-mail de recuperação recebido, confirmar que o link leva para `/redefinir-senha` (não para o catálogo) e concluir a troca de senha, para fechar o teste ponta a ponta

## Objetivo

Permitir que um representante que esqueceu a senha e está deslogado do Catálogo Ubiqua consiga recuperar o acesso sozinho, via e-mail — sem depender de um admin resetar a senha manualmente (que hoje nem existe nesse sistema).

## Decisões aprovadas

- Fica restrito ao sistema Catálogo Peças Ubiqua, mesmo escopo da SPEC-159.
- Reaproveita a infraestrutura padrão do Supabase Auth (`resetPasswordForEmail` + `updateUser`), sem RPC nova nem mudança de banco — mesmo mecanismo já usado pela Logística e pelo CRM (`UpdatePassword.tsx`).
- Mensagem de confirmação do "esqueci senha" é genérica (não confirma nem nega se o e-mail existe), por segurança — mesmo padrão da Logística.

## Definição da SPEC

### Estado atual

- `AuthWrapper.tsx`: só login/criar conta, sem link de recuperação.
- `App.tsx`: todas as rotas (exceto `/onboarding`) ficam dentro de `<AuthWrapper>`, que barra quem não está logado mostrando o formulário de login/cadastro.
- Não existe `ForgotPasswordPage`/`ResetPasswordPage` neste sistema (existem só na Logística, que serve de referência de padrão).

### Mudança proposta

Duas páginas novas + 1 link + 2 rotas públicas, replicando o padrão do Supabase Auth já validado na Logística:

1. `/esqueci-senha` (pública, fora do `AuthWrapper`) → pede e-mail → `resetPasswordForEmail`.
2. Usuário recebe e-mail do Supabase com link para `/redefinir-senha`.
3. `/redefinir-senha` (pública, fora do `AuthWrapper`) → Supabase já autentica a sessão de recovery ao abrir o link → formulário de nova senha → `updateUser({password})` → signOut → volta pro login normal.

## Impacto no banco

Nenhum. Usa `auth.users` via Supabase Auth padrão, sem tabela/coluna/RLS nova.

## Impacto em telas, relatórios ou automações

- Só o Catálogo Ubiqua: 2 páginas novas, 1 link novo em `AuthWrapper.tsx`, 2 rotas novas em `App.tsx`.
- Depende de configuração externa do Supabase (redirect URL allowlist) — não é código, é config do projeto Supabase.

## Regras de permissão

Nenhuma — é ação sobre a própria conta, sem depender de role/nível de acesso, disponível para qualquer pessoa com um e-mail cadastrado.

## Critérios de aceite

- Usuário deslogado consegue solicitar recuperação de senha informando o e-mail.
- E-mail com link chega e, ao abrir, leva para a tela de nova senha (não para o catálogo).
- Nova senha definida com sucesso permite login imediato.
- Link expirado/inválido mostra aviso claro e manda para `/esqueci-senha` de novo.
- Mensagem de confirmação do pedido não revela se o e-mail existe ou não na base.

## Testes/verificações obrigatórios

- Fluxo completo com e-mail real (passo manual do usuário, listado acima).
- Tentar abrir `/redefinir-senha` diretamente sem link válido → deve barrar/redirecionar, não deixar trocar senha sem sessão de recovery.
- Conferir que `/esqueci-senha` e `/redefinir-senha` funcionam mesmo sem estar logado (não caem na tela de login do `AuthWrapper`).

## Pendências

- [ ] Nenhuma no momento — SPEC pronta para implementação, exceto a configuração externa do Supabase (redirect URL), que é passo manual do usuário.

## Realizado

**2026-09-23** — Implementado pelo agente `implementador`:
- `src/pages/ForgotPasswordPage.tsx` (novo): formulário com campo e-mail, chama `supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/redefinir-senha` })`; após o envio (sucesso ou erro silencioso do Supabase) mostra tela de confirmação genérica ("Se esse e-mail existir na nossa base, você vai receber um link para redefinir a senha"), sem diferenciar e-mail existente/inexistente; toast de erro genérico só se a própria chamada lançar exceção; link "Voltar para o login" para `/`. Visual espelha `AuthWrapper.tsx` (`bg-muted/30`, card `bg-card border rounded-xl shadow-lg`, inputs `h-12`).
- `src/pages/ResetPasswordPage.tsx` (novo): no `useEffect` inicial chama `supabase.auth.getSession()`; se não houver sessão E a URL não tiver `type=recovery` no hash, mostra toast de link inválido/expirado e redireciona para `/esqueci-senha` via `useNavigate`. Formulário Nova Senha + Confirmar Nova Senha (`type="password"`, mínimo 6 caracteres, mesmo padrão de `ProfilePage.tsx`); ao submeter com sucesso chama `supabase.auth.updateUser({ password })`, toast de sucesso, `signOut()` e `navigate('/', { replace: true })`; erro mostra toast. Mesmo padrão visual do `ForgotPasswordPage.tsx`.
- `src/components/AuthWrapper.tsx`: adicionado `import { Link } from 'react-router-dom'` e link "Esqueci minha senha" abaixo do botão "Entrar", visível só quando `!isSignUp` (modo login); nenhuma mudança em `handleLogin`/`handleSignUp`/modo cadastro.
- `src/App.tsx`: importado `ForgotPasswordPage` e `ResetPasswordPage`; adicionadas as rotas `/esqueci-senha` e `/redefinir-senha` como filhas diretas de `<Routes>`, antes da rota `/onboarding`, sem `<AuthWrapper>` em volta — funcionam para usuário deslogado e não são tratadas como "logado" pela sessão de recovery do Supabase.
- Rodado `npm run lint` (oxlint) — sem erros novos, só warnings pré-existentes em outros arquivos (nenhum introduzido pelas mudanças desta SPEC). Rodado `npm run build` (vite build) — compilou sem erros.
- Nenhuma mudança em `supabase/`, nenhuma migration criada (sem impacto no banco, conforme SPEC).

### Passos manuais pendentes do usuário
- Conferir no painel do Supabase (Authentication → URL Configuration → Redirect URLs) se `https://catalogo-pecas-ubiqua-e6fa0.goskip.app/redefinir-senha` está na allowlist — sem isso o link do e-mail pode ser rejeitado ou cair na URL padrão.
- Testar golden path no navegador: em `/`, clicar "Esqueci minha senha" → `/esqueci-senha` → informar e-mail real cadastrado → conferir tela de confirmação genérica → abrir o link recebido por e-mail → conferir que cai em `/redefinir-senha` (não no catálogo) → definir nova senha → conferir logout automático e redirecionamento para `/` → logar com a nova senha. Também testar abrir `/redefinir-senha` direto sem link válido (deve barrar e redirecionar para `/esqueci-senha`).
- Rodar o agente `revisor` antes de qualquer commit.
- Publicar no Skip separadamente, se aprovado.
