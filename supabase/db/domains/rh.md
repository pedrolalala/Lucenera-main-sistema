# Domínio: RH

## Papel no ecossistema

RH concentra dados de funcionários, equipes, cargos e responsáveis.

## Relação com outros domínios

- CRM pode atribuir responsáveis por tarefa.
- Projetos já possuem responsável.
- Hub/TI pode usar usuários/funcionários para permissões e acesso.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a RH:

- `public.get_faltas_injustificadas(p_funcionario_id uuid, p_inicio date, p_fim date)`: consulta faltas injustificadas por funcionário/período.
- `public.handle_new_auth_user()` e `public.handle_new_user()`: criação/vínculo inicial de usuário, com impacto em pessoas/acesso.
- `public.get_vendedores()`: consulta vendedores, útil para atribuições comerciais.
- Funções genéricas de `updated_at` também afetam tabelas de funcionários.

Triggers relacionadas:

- `auth.users.on_auth_user_created`
- `public.funcionarios.funcionarios_updated_at`
- `public.usuarios.usuarios_updated_at`

Edge Functions relacionadas:

- `welcome-email`: e-mail de boas-vindas.
- `sync-teams`: integração/simulação Microsoft Teams.

Observação: functions locais encontradas apenas no projeto de RH não são fonte de verdade e não devem ser promovidas sem revisão específica.

## Ação a ser realizada

Consolidar vínculo entre funcionário, usuário de sistema, permissões e responsabilidade operacional. Evitar duplicação entre cadastro de funcionário e perfil de login.
