---
titulo: "SPEC-194 — Criar login dos auxiliares de estoque e ligar ao cadastro de funcionário"
status: aguardando aprovação
data_ultima_modificacao: 2026-10-11
origem: "pedido do usuário 11/10 (lista de e-mails dos funcionários)"
sistemas_envolvidos:
  - Supabase (auth.users, usuarios, funcionarios, user_system_access, usuario_papeis)
  - Central / Hub (Acesso a Sistemas)
---

# SPEC-194 — Logins dos auxiliares de estoque

Criar as contas de quem ainda não tem login, com a senha padrão informada pelo usuário, e deixar cada conta **ligada
ao funcionário que já existe** no banco. Nada de criar funcionário novo.

## Situação conferida no banco (11/10)

| Funcionário (cadastro) | Cargo | E-mail da lista | Login hoje | Ação |
|---|---|---|---|---|
| Alexandre Guilherme da Costa | Auxiliar de Estoque | alexandrecosta490@gmail.com | **já existe** (criado 08/10, já entrou) e ligado | nada |
| Antonio Ernesto Rodrigues Filho | Auxiliar de Estoque | antonioaercdp123@gmail.com | não tem | criar |
| Claudio Otavio de Oliveira | Auxiliar de Estoque | oliveiraclaudio798@gmail.com | não tem | criar |
| João Gabriel Oliveira de Almeida | Auxiliar de Estoque | joaog1320@gmail.com | não tem | criar |
| Leandro César Rabello Tavares | Auxiliar de Estoque | leandro_tavares.18@hotmail.com | não tem | criar |
| Manuel Rodrigues de Paula Neto | Auxiliar de Estoque | manuelrodriguespaula77@gmail.com | não tem | criar |
| Matheus Fernando Luzente | Líder de Logística | matheus@lucenera.com (sem ".br") | **já existe** como `matheus@lucenera.com.br`, ligado | nada (a lista está sem o ".br") |
| Vitoria Lidia da Silva | Assistente Administrativo | vitoria@lucenera.com (sem ".br") | **já existe** como `vitoria@lucenera.com.br`, ligado | nada |

Os 5 a criar existem em `funcionarios` (Ativo), com `email` vazio e sem `usuario_id`.

Achado: o Alexandre tem login mas **nenhum sistema liberado** (`user_system_access` vazio) e nenhum papel. Os 5 novos
ficariam iguais se só criarmos a conta: eles entram, mas não veem sistema nenhum.

## Plano

- [ ] **1. Gravar o e-mail no cadastro de cada um dos 5 funcionários** antes de criar a conta. O gatilho
  `handle_new_user` só reaproveita o funcionário se `funcionarios.email` bater; sem isso ele cria um funcionário
  duplicado "Ativo" (aconteceu em 08/10 com 14 contas).
- [ ] **2. Criar as 5 contas** com a mesma lógica da RPC `criar_usuario` (e-mail já confirmado, senha padrão,
  `usuarios.role = 'funcionario'` igual ao Alexandre, nome do cadastro). Script único, em transação, com dry-run
  (rollback) antes do real. A senha não fica gravada em arquivo do repositório.
- [ ] **3. Liberar os sistemas** de cada um em Acesso a Sistemas / papéis (lista a definir, pergunta 1). Aplicar
  também ao Alexandre.
- [ ] **4. Conferir:**
  - cada funcionário com `usuario_id` e `email` certos;
  - nenhum funcionário novo criado (`funcionarios.created_at` na última hora = 0);
  - login de verdade com e-mail + senha padrão (API de login do Supabase), uma vez por conta.
- [ ] **5. Entregar a lista** (nome, e-mail, sistemas liberados) para o usuário repassar aos funcionários.

## Perguntas abertas

1. **Quais sistemas** os auxiliares de estoque devem ver? (ex.: Separação, Logística, Controle de Produção, Controle
   de Garantia, Cadastro/Consulta de Produtos). Todos iguais ao mesmo perfil?
2. **João Gabriel** é o mesmo João que ficou de entrar como editor do Controle de Produção (SPEC-191)? Se for, entra
   em `producao_editores` com este e-mail.
3. **Senha padrão:** todos vão usar a mesma senha padrão (informada no chat, não registrada aqui) até trocarem. Hoje não existe "trocar senha no primeiro
   acesso" — ok assim, ou pedimos para cada um trocar pela tela de Alterar Senha?

## Relacionado

- SPEC-193 C2: os e-mails da Lana e da Carol foram encontrados no mesmo levantamento — Lana = `financeiro@lucenera.com.br`,
  Carol = `caroline@lucenera.com.br` (as duas já têm login ligado ao funcionário).
