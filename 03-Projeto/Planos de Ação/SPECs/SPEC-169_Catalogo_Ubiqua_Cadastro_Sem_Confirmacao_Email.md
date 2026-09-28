---
titulo: "SPEC-169 — Catálogo Ubiqua: cadastro entra direto, sem confirmação de e-mail"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - catalogo-pecas-ubiqua-e6fa0
---

# SPEC-169 — Catálogo Ubiqua: cadastro entra direto, sem confirmação de e-mail

## Checklist de Ação

- [x] Edge Function `cadastro-ubiqua`: cria a conta já confirmada (Admin API, `email_confirm: true`).
- [x] `use-auth.tsx`: `signUp` chama a função e faz `signInWithPassword` em seguida.
- [x] `AuthWrapper.tsx`: mostra a mensagem de erro da função (ex.: e-mail já cadastrado).
- [x] Publicado no Skip 33302 v0.0.91 (`61e0030`); a etapa "integrations" deployou só `cadastro-ubiqua` v1 (as outras 23 funções intactas, conferido por versão).
- [x] Função no ar: e-mail inválido → 400, senha curta → 400, OPTIONS → 200.
- [ ] Testar cadastro real com e-mail novo (usuário).

### Passos manuais do usuário

Nenhum. Não tem migration.

## Objetivo

A equipe da Ubiqua pediu para tirar a confirmação de e-mail: ao se cadastrar com e-mail e senha, o site
abre direto. **Só no Catálogo Ubiqua**: os outros sistemas continuam exigindo confirmação.

## Decisões aprovadas

- 2026-09-28 (usuário): fazer só no Ubiqua, não desligar `mailer_autoconfirm` no projeto Supabase.
- O usuário foi avisado de que o risco é equivalente ao de desligar tudo: a conta do Supabase Auth é
  compartilhada entre todos os sistemas, então uma conta criada pelo Ubiqua também entra nos sistemas que só
  exigem login (sem checar permissão do Hub), e a função precisa ficar aberta, porque quem se cadastra ainda
  não tem sessão. Manteve a escolha para que os outros sistemas continuem pedindo confirmação no cadastro.

## Definição

- Estado do Supabase (lido em 2026-09-28): `mailer_autoconfirm = false`, `disable_signup = false`, sem SMTP
  próprio (o envio padrão tem limite baixo por hora). Não foi alterado.
- `supabase/functions/cadastro-ubiqua/index.ts`: POST `{email, password}` → valida formato do e-mail e senha
  com 6+ caracteres → `auth.admin.createUser({ email_confirm: true, user_metadata: { origem: 'catalogo-ubiqua' } })`.
  E-mail já existente → 409. Não cria papel nem linha em `usuarios_ubiqua` (o onboarding continua igual).
- O site chama a função com a chave pública (JWT legado, passa no `verify_jwt` padrão).

## Rollback

Reverter o commit do submódulo e republicar; apagar a função `cadastro-ubiqua` no painel do Supabase.
