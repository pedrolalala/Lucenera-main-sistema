---
titulo: "SPEC-059 — Central Lucenera: Cadastro Fácil de Usuário (Email + Senha)"
status: concluído
data_ultima_modificacao: 2026-08-05
sistemas_envolvidos:
  - Central Lucenera (central-lucenera-dashboard-1c9ba)
---

# SPEC-059 — Central Lucenera: Cadastro Fácil de Usuário (Email + Senha)

> `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — `src/pages/admin/components/UsersTab.tsx` (Skip, `projectId 37750`): adicionar botão "Novo Usuário" que abre um `Dialog` com campos Nome, Email, Senha e Papel de Acesso (mesmo conjunto de opções do select de edição: admin, gerente, operador, funcionario, viewer).
- [x] Item 2 — Submit do formulário chama `supabase.rpc('criar_usuario', { p_email, p_password, p_nome, p_role })` (RPC já existe e já publicada no Supabase real — sem migration necessária).
- [x] Item 3 — Em sucesso: toast de confirmação, fecha o dialog, limpa o formulário e chama `fetchUsers()` para atualizar a tabela.
- [x] Item 4 — Em erro (ex.: email já cadastrado, `RAISE EXCEPTION` do `criar_usuario`): toast destrutivo com a mensagem retornada pelo Supabase.
- [x] Item 5 — Publicar via `skip_project_apply_changes` + `skip_project_publish` (`projectId 37750`, versão `0.0.37`/`737e6c0`, publicado em `central-lucenera-dashboard-1c9ba.goskip.app`), depois espelhar o mesmo arquivo no submodule local `04-Sistemas/central-lucenera-dashboard-1c9ba/` e atualizar o ponteiro do submodule no repo central. Commit no repo do sistema: `2f2c389` (push feito para `origin/main` em `central-lucenera`).
- [x] Item 6 — Atualizar `CHANGELOG.md`.

### Passos manuais do usuário

- [ ] Testar em produção: criar um usuário de verdade (nome/email/senha/papel) na aba "Gestão de Usuários" em `https://central-lucenera-dashboard-1c9ba.goskip.app` e confirmar que ele consegue logar.

## Objetivo

Hoje a aba "Gestão de Usuários" da Central Lucenera (Hub) só lista usuários existentes e permite editar papel/status — não existe forma de criar um usuário novo pela interface. A única via é a função SQL `criar_usuario`, que já existe e funciona, mas só é chamável direto no banco. Esta SPEC expõe essa função numa tela simples (nome, email, senha, papel) dentro da própria Central Lucenera, sem exigir acesso ao Supabase.

## Decisões aprovadas

- Reusar a RPC `criar_usuario(p_email, p_password, p_nome, p_role)` já publicada — não criar nova função nem nova tabela.
- O formulário fica na mesma aba "Gestão de Usuários" (`UsersTab.tsx`) da Central Lucenera, não em sistema novo.
- Papel padrão do formulário: `viewer` (mesmo default da RPC), com todos os papéis disponíveis no select, igual ao select de edição já existente.

## Definição da SPEC

### Estado atual (confirmado por leitura direta)

- `public.criar_usuario(p_email text, p_password text, p_nome text, p_role usuario_role DEFAULT 'viewer')` já existe em `supabase/db/current/03_functions.sql` (linha ~1680), cria a linha em `auth.users` (senha com `crypt`/`gen_salt`) e em `public.usuarios`, e já valida que só `admin` pode chamar.
- `04-Sistemas/central-lucenera-dashboard-1c9ba/src/pages/admin/components/UsersTab.tsx` (Skip `projectId 37750`, confirmado idêntico entre working tree do Skip e o submodule local em 2026-08-05) só tem tabela de listagem + edição de `role`/`ativo`. Não tem criação.
- `AdminPage.tsx` já passa `users` e `fetchUsers` para `UsersTab`; não precisa mudar assinatura, só reaproveitar `fetchUsers` após criar.

### Mudança proposta

- Novo estado local no `UsersTab` (`open`, `form: {nome, email, password, role}`, `submitting`).
- Botão "Novo Usuário" acima da tabela, abre `Dialog` (componente já existe em `src/components/ui/dialog.tsx`) com `Input`/`Label`/`Select`/`Button` (já existem no projeto).
- `handleCreateUser`: chama `supabase.rpc('criar_usuario', { p_email: form.email, p_password: form.password, p_nome: form.nome, p_role: form.role })`.

## Impacto no banco

Nenhum. RPC já existe e já está publicada no Supabase real.

## Impacto em telas

Só a aba "Gestão de Usuários" da Central Lucenera ganha um botão + dialog novo. Nenhuma outra tela muda.

## Regras de permissão

Sem mudança: `AdminPage.tsx` já redireciona quem não é `role === 'admin'` para fora de `/admin`, e a RPC repete a checagem no banco (`v_caller_role != 'admin'` → exceção).

## Análise obrigatória de ecossistema

- Depende de `usuarios` (sim, via RPC `criar_usuario`) e de `auth.users` (indiretamente, dentro da RPC). Não toca `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `systems` nem `user_system_access`.
- Afeta apenas Hub/TI (Central Lucenera). Nenhum outro domínio.
- Não há dado duplicado sendo criado — só um formulário sobre uma função que já existe.
- Não há migration antiga conflitante — nenhuma migration nova é necessária.
- Não exige atualização de `AI_DB_CONTEXT.md` (nenhuma tabela/coluna/função nova).

## Critérios de aceite

- Admin logado na Central Lucenera consegue criar usuário novo informando nome, email, senha e papel, sem sair da tela.
- Usuário criado aparece na lista imediatamente (via `fetchUsers()`) com o papel escolhido.
- Tentar criar com email já existente mostra erro claro (mensagem da exceção do Postgres), sem travar a tela.
- Usuário criado consegue logar em qualquer sistema com o email/senha cadastrados (mesmo fluxo de auth já usado pelos demais usuários).

## Testes/verificações obrigatórias

- QA pipeline do Skip (`skip_project_apply_changes`) precisa passar (build + testes automatizados do projeto).
- Teste manual: criar um usuário de teste, confirmar login, depois desativar/remover conforme prática interna.

## Realizado

### 2026-08-05

- SPEC criada.
- `UsersTab.tsx` implementado (botão + dialog "Novo Usuário", chamando `criar_usuario` via RPC) e publicado em produção no Skip (`projectId 37750`, versão `0.0.37`/`737e6c0`).
- Espelhado no submodule local, commitado e enviado ao GitHub (`central-lucenera`, commit `2f2c389`), com ponteiro de submodule atualizado no repo central.

## Pendências

- [ ] Teste manual em produção (criar um usuário real e confirmar login) ainda não foi feito pelo usuário.
