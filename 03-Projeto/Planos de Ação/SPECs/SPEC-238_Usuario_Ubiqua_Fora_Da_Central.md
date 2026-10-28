---
titulo: "SPEC-238 — Usuário do Catálogo Ubiqua não aparece na Central da Lucenera"
status: no ar
data_ultima_modificacao: 2026-10-28
sistemas_envolvidos:
  - Banco (Supabase SP) — usuarios, funcionarios, gatilho handle_new_user
  - Central (central-lucenera-dashboard-1c9ba) — Administração (Gestão de Usuários, Matriz, Acesso a Sistemas, Exceções)
---

# SPEC-238 — Usuário do Catálogo Ubiqua não aparece na Central da Lucenera

> Origem: pedido do usuário em 28/10/2026, depois de achar `andresafl@yahoo.com.br` na Central: "quem for usuario da
> ubiqua não deve aparecer na central da lucenera!! pois são coisas diferentes!!". Disse também: "não precisa apagar".

## Checklist de Ação

- [x] Levantar de onde vem a conta e como ela entra na Central.
- [x] Migration 258: coluna `usuarios.somente_ubiqua` + preencher as contas já existentes + gatilho marca as novas e não
      cria funcionário para elas.
- [x] Central: lista de usuários da Administração sem as contas `somente_ubiqua`.
- [x] Aplicar a 258 (28/10: 4 contas marcadas, 32 da Lucenera) e publicar a Central (`22eed2e`).

## Estado encontrado (28/10)

- O Catálogo Ubiqua cria a conta pela Edge Function `cadastro-ubiqua`, que grava `user_metadata.origem =
  'catalogo-ubiqua'`. O gatilho `on_auth_user_created` → `handle_new_user` cria, para **toda** conta nova, uma linha em
  `usuarios` (role `viewer`) e, se o e-mail não bate com um funcionário, um **funcionário novo "Ativo"**.
- A Central (Administração) lista `usuarios` inteira → a revendedora aparece junto com a equipe.
- O Catálogo lê `usuarios` (role, perfil) → a linha em `usuarios` precisa continuar existindo.
- Contas com cadastro na Ubiqua hoje: 4. Duas são da Lucenera (Filippo, pedrollaghi — têm papéis e acessos) e **não**
  podem sumir. Duas nasceram no catálogo (`origem = catalogo-ubiqua`): Andresa - Jardinópolis e marianemribeiro.
  Portanto o critério é **como a conta nasceu**, não "ter cadastro na Ubiqua".
- Contas nascidas no catálogo (`origem = catalogo-ubiqua`): **4** — andresafl@yahoo.com.br, marianemribeiro@gmail.com,
  erp.lucenera@gmail.com, vinicius_bortolin@hotmail.com. Nenhuma tem papel nem acesso a sistema; o Vinicius usa
  vinicius@lucenera.com.br na Lucenera. As 4 ficam `somente_ubiqua` (dry-run 28/10: 33 Lucenera, 4 Ubiqua; conta nova
  do catálogo sai marcada e sem funcionário, conta comum continua criando funcionário).

## Decisões

1. `usuarios.somente_ubiqua boolean not null default false` — `true` para conta criada pelo cadastro do catálogo.
2. Nada é apagado (pedido do usuário). As 2 contas atuais só são marcadas.
3. Conta nova do catálogo: o gatilho grava `somente_ubiqua = true` e **não cria funcionário**.
4. Central: a lista de usuários da Administração filtra `somente_ubiqua = false` (alimenta Gestão de Usuários, Matriz de
   Acesso, Acesso a Sistemas e Exceções).
5. Se alguém da Lucenera se cadastrar pelo catálogo, basta pôr `somente_ubiqua = false` nele.

## Fora do escopo

- Os 2 funcionários criados pelo gatilho para as contas atuais (nome = prefixo do e-mail) continuam no RH — o usuário
  pediu para não apagar.
- Aba Movimentação (auditoria) continua mostrando o que acontece no Catálogo Ubiqua.
