# SPEC-205 — Central: "Esqueceu a senha?" envia e-mail de recuperação

- **Data:** 2026-10-15
- **Status:** em andamento
- **Origem:** relato do usuário em 15/10: o link "Esqueceu a senha?" no login da Central não fazia nada.
- **Sistema:** Central (`04-Sistemas/central-lucenera-dashboard-1c9ba`), Auth do Supabase SP.

## Causa
O link era `<a href="#">` e não havia nenhuma tela de recuperação na Central.

## Solução (tela)
- `/esqueci-senha` (`EsqueciSenha.tsx`): a pessoa informa o e-mail e a tela chama `supabase.auth.resetPasswordForEmail(email, { redirectTo: <origem>/redefinir-senha })`. A resposta é a mesma para qualquer e-mail, para não revelar quem tem conta.
- `/redefinir-senha` (`RedefinirSenha.tsx`): o link do e-mail abre uma sessão de recuperação. A pessoa grava a nova senha (mínimo de 8 caracteres, como na SPEC-187) com `updateUser`, a sessão é encerrada e ela volta ao login. Link vencido ou já usado mostra "Pedir novo link".
- `Index.tsx`: "Esqueceu a senha?" leva para `/esqueci-senha`.
- `central-lucenera.pages.dev/**` já está na lista de redirecionamentos permitidos do Auth.

## Pendência — envio do e-mail (configuração do Supabase)
O Auth do projeto SP **não tem SMTP próprio**. O SMTP padrão do Supabase só entrega para e-mails de membros da equipe do projeto no painel do Supabase e manda no máximo 2 e-mails por hora. Os funcionários não recebem. Falta:
1. Configurar um SMTP próprio no Auth (Microsoft 365 da Lucenera, Resend ou similar). Isso precisa de um remetente e das credenciais.
2. Traduzir o assunto e o texto do e-mail de recuperação (hoje "Reset your password", em inglês). Isso vale para todos os sistemas.
3. Opcional: trocar o `site_url` do Auth (`http://localhost:3000`) para `https://central-lucenera.pages.dev`.

## Critérios de aceite
1. Clicar em "Esqueceu a senha?" abre a tela de recuperação.
2. Com o SMTP configurado, o e-mail chega e o link leva à tela de nova senha.
3. A nova senha funciona no login de todos os sistemas.

## Checklist
- [x] Telas (build ok; tsc sem erro novo)
- [x] Publicado a8b4c2f (central-lucenera.pages.dev)
- [ ] SMTP próprio configurado
- [ ] Teste ponta a ponta
