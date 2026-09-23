---
titulo: "SPEC-159 — Alterar Senha (self-service) no Catálogo Ubiqua"
status: pendente
data_ultima_modificacao: 2026-09-23
sistemas_envolvidos:
  - Catálogo Peças Ubiqua (04-Sistemas/catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-159 — Alterar Senha (self-service) no Catálogo Ubiqua

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Adicionar `updatePassword(currentPassword, newPassword)` em `src/hooks/use-auth.tsx` — reautentica com `supabase.auth.signInWithPassword({ email, password: currentPassword })` para confirmar a senha atual e só então chama `supabase.auth.updateUser({ password: newPassword })`
- [x] Adicionar seção "Alterar Senha" em `src/pages/ProfilePage.tsx` (novo bloco, separado do form de Dados Pessoais/Empresa, com seu próprio submit): campos Senha Atual, Nova Senha, Confirmar Nova Senha
- [x] Validações no frontend: nova senha ≥ 6 caracteres (mesmo mínimo já usado no cadastro em `AuthWrapper.tsx`), nova senha = confirmação, nova senha ≠ senha atual
- [x] Mensagem de erro clara quando a senha atual informada estiver incorreta (Supabase retorna erro de credencial inválida no `signInWithPassword` de reautenticação)
- [x] Feedback de sucesso (toast) e limpar os campos após trocar

### Passos manuais do usuário

- [ ] Nenhum — não há mudança de banco/RLS/migration, é só frontend usando a API de auth já existente (`supabase.auth`)
- [ ] Testar manualmente no navegador (golden path): trocar senha com senha atual correta, tentar com senha atual errada, tentar nova senha < 6 caracteres, tentar confirmação diferente — depois logout/login com a nova senha
- [ ] Publicar no Skip (este agente não publica; feito separadamente após rodar o `revisor`)

## Objetivo

O Catálogo Ubiqua (portal do representante) hoje não tem como o usuário logado trocar a própria senha — só existe cadastro inicial (`AuthWrapper.tsx`) e login. Esta SPEC adiciona essa ação dentro da tela de Perfil (`/perfil`) já existente, que hoje só edita dados pessoais/empresa.

## Decisões aprovadas

- Fica restrito ao sistema **Catálogo Peças Ubiqua**, não se estende a outros sistemas do ecossistema (decisão do usuário).
- Exige confirmação da senha atual antes de trocar (reautenticação via `signInWithPassword`), já que é um portal usado por representantes externos — evita troca trivial de senha em sessão esquecida aberta.
- Reaproveita a infraestrutura de auth já existente (`supabase.auth`), sem criar RPC nova nem tocar em `usuarios_ubiqua`/`usuarios` (a senha vive em `auth.users`, fora dessas tabelas de perfil).

## Definição da SPEC

### Estado atual

- `src/hooks/use-auth.tsx`: expõe `signUp`, `signIn`, `signOut` — não tem `updatePassword`.
- `src/pages/ProfilePage.tsx`: um único form que edita `usuarios_ubiqua` (nome, telefone) e `empresa_ubiqua` (dados da empresa); e-mail é somente-leitura. Nenhum campo de senha.
- Sistema usa Supabase Auth padrão (`auth.users`), mesmo projeto Supabase do restante do ecossistema — trocar senha aqui não afeta nem depende de outro sistema.

### Mudança proposta

1. **Hook** (`use-auth.tsx`):
   ```ts
   const updatePassword = async (currentPassword: string, newPassword: string) => {
     if (!user?.email) return { error: new Error('Usuário não identificado.') }
     const { error: reauthError } = await supabase.auth.signInWithPassword({
       email: user.email,
       password: currentPassword,
     })
     if (reauthError) return { error: reauthError }
     const { error } = await supabase.auth.updateUser({ password: newPassword })
     return { error }
   }
   ```
   Adicionar ao `AuthContextType` e ao value do `AuthContext.Provider`.

2. **Tela** (`ProfilePage.tsx`): novo bloco "Alterar Senha" (com `<Separator />` antes, mesmo padrão visual dos blocos existentes), form próprio (não reaproveita `handleSave`), 3 campos (`type="password"`), botão "Alterar Senha" com loading state próprio.

### Regras de validação

| Campo | Regra |
|---|---|
| Senha atual | obrigatório, verificado via reautenticação |
| Nova senha | mínimo 6 caracteres (mesmo padrão do cadastro) |
| Confirmar nova senha | deve ser igual à nova senha |
| Nova senha vs atual | não pode ser igual (checagem simples no frontend) |

## Impacto no banco

Nenhum. Usa `auth.users` via `supabase.auth.updateUser`, sem tabela/coluna/RLS nova.

## Impacto em telas, relatórios ou automações

- Só `ProfilePage.tsx` do Catálogo Ubiqua. Nenhum outro sistema é afetado.

## Regras de permissão

Qualquer usuário autenticado do Catálogo Ubiqua pode alterar a própria senha (não depende de `nivel_acesso`/role) — é ação sobre a própria conta, não sobre a de terceiros.

## Critérios de aceite

- Usuário logado consegue trocar a própria senha informando a senha atual correta.
- Senha atual incorreta → erro claro, senha não é alterada.
- Nova senha e confirmação diferentes → bloqueado no frontend antes de chamar a API.
- Após troca bem-sucedida, login subsequente só funciona com a nova senha.

## Testes/verificações obrigatórios

- Trocar senha com senha atual correta → sucesso, logout/login com a nova senha funciona.
- Tentar trocar com senha atual errada → bloqueado, mensagem de erro.
- Tentar nova senha < 6 caracteres → bloqueado no frontend.

## Pendências

- [ ] Nenhuma no momento — SPEC pronta para implementação.

## Realizado

**2026-09-23** — Implementado pelo agente `implementador`:
- `src/hooks/use-auth.tsx`: adicionado `updatePassword(currentPassword, newPassword)` ao `AuthContextType` e ao `AuthProvider`, conforme código da SPEC (reautentica via `signInWithPassword` antes de `updateUser`); exposto no value do `AuthContext.Provider`.
- `src/pages/ProfilePage.tsx`: adicionado segundo `<form>` (card próprio, mesmo padrão visual dos blocos existentes — `Separator`, `Input`/`Label`/`Button`) com os campos Senha Atual, Nova Senha e Confirmar Nova Senha, estado `passwordForm` e `changingPassword` (loading próprio, não reaproveita `saving`), handler `handleChangePassword` com as validações (mínimo 6 caracteres, confirmação igual, nova ≠ atual), toast de erro/sucesso via `sonner`, e limpeza dos 3 campos após sucesso.
- Rodado `npm run lint` (oxlint) — sem erros novos, só warnings pré-existentes em outros arquivos (nenhum novo introduzido pelas mudanças). Rodado `npm run build` (vite build) — compilou sem erros.
- Nenhuma mudança em `supabase/`, nenhuma migration criada (não há impacto no banco, conforme SPEC).

### Passos manuais pendentes do usuário
- Testar golden path no navegador: login no Catálogo Ubiqua → `/perfil` → trocar senha com senha atual correta (esperar sucesso + logout/login com a nova senha); tentar com senha atual errada (esperar erro); tentar nova senha < 6 caracteres e confirmação diferente (esperar bloqueio no frontend, sem chamar a API).
- Rodar o agente `revisor` antes de qualquer commit.
- Publicar no Skip separadamente, se aprovado.
