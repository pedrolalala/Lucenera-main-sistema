---
titulo: "SPEC-170 — Catálogo Ubiqua: botões Sair e Excluir conta"
status: concluído
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - catalogo-pecas-ubiqua-e6fa0
---

# SPEC-170 — Catálogo Ubiqua: botões Sair e Excluir conta

## Checklist de Ação

- [x] Botão "Sair" (ícone) no topo do site.
- [x] Seção "Conta" no Perfil com "Sair" e "Excluir conta".
- [x] "Sair" e "Excluir conta" também no onboarding (conta nova fica presa ali até concluir o cadastro).
- [x] Edge Function `excluir-conta-ubiqua` (exclui só a conta de quem chama).
- [x] Publicado no Skip 33302 v0.0.92 (`acf7869`); só `excluir-conta-ubiqua` v1 foi deployada (outras 24 intactas). Sem sessão → 401.
- [ ] Teste do usuário: criar conta → Sair → entrar de novo → Excluir conta.

### Passos manuais do usuário

Nenhum. Não tem migration.

## Objetivo

O usuário não tinha mais e-mails livres para testar o cadastro sem confirmação (SPEC-169) e pediu botões
de sair e de excluir a conta no site do Ubiqua.

## Definição

- Confirmação: modal pedindo para digitar `EXCLUIR`.
- `excluir-conta-ubiqua`: identifica o usuário pelo token da sessão (`auth.getUser`) e **recusa**:
  - conta em `public.usuarios` (equipe Lucenera): `usuarios` e todo o schema `memoria` têm FK `on delete
    cascade` para `auth.users`, então apagar levaria o acesso a todos os sistemas e o conteúdo da Memória;
  - `usuarios_ubiqua.nivel_acesso = 'admin'`;
  - representante com linhas em `informacoes_cliente_ubiqua` (FK sem cascata; o banco bloquearia de
    qualquer jeito).
  - Toda checagem falha fechada: erro na consulta = não exclui.
- Exclusão: `auth.admin.deleteUser` (apaga `usuarios_ubiqua` por cascata) e depois apaga a `empresa_ubiqua`
  do onboarding se nenhum outro representante estiver ligado a ela.
- Orçamentos (`orcamentos_revenda_ubiqua`) não têm FK para o usuário e ficam guardados.

## Rollback

Reverter o commit do submódulo e republicar; apagar a função `excluir-conta-ubiqua` no painel do Supabase.
