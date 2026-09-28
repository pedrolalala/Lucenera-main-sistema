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

## Correção pós-teste (2026-09-28)

Primeiro teste do usuário deu "Contas da equipe Lucenera não podem ser excluídas por aqui." com uma conta de
teste. Causa: o gatilho `on_auth_user_created` → `handle_new_user()` insere **toda** conta nova em
`public.usuarios` (role `viewer`) e cria uma linha vazia em `funcionarios` (status Ativo). A regra "está em
`usuarios` = equipe" recusava todo mundo.

Regra nova de equipe: `usuarios.role <> 'viewer'` **ou** linha em `usuario_papeis` (Hub) **ou**
`funcionarios` com cargo/departamento/admissão/contratação/empresa/código legado preenchido. Simulada nas 13
contas reais: 11 recusadas como equipe (inclui o representante real de 19/07, que tem papel no Hub e 1 cliente),
só as 2 contas de teste de hoje ficam excluíveis. Ao excluir, apaga também o funcionário vazio do gatilho
(`funcionarios.usuario_id` é ON DELETE SET NULL e sobraria um "funcionário Ativo" fantasma no RH).

Skip 33302 v0.0.93 (`0139093`): o apply deployou `excluir-conta-ubiqua` v2 (só ela). O publish foi bloqueado
pelo classificador do auto mode, mas o frontend não mudou nesta correção; publicar só alinha a versão no Skip.

Achado fora do escopo: o gatilho cria um `funcionarios` "Ativo" para cada representante do Ubiqua, e eles
aparecem no RH como funcionários. Não foi alterado.

## Rollback

Reverter o commit do submódulo e republicar; apagar a função `excluir-conta-ubiqua` no painel do Supabase.
