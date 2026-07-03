# Domínio: Hub/TI

## Papel no ecossistema

O Hub/TI é a camada de controle do ecossistema.

Ele deve permitir:

- ver sistemas ativos;
- cadastrar novos sistemas;
- acompanhar saúde de sistemas;
- controlar regras de acesso e permissões pela UI;
- liberar ou ocultar funcionalidades conforme perfil.

## Decisão atual

Permissões devem ser configuradas pela interface.

Exemplo: no fluxo de aprovação de orçamento, o modal/atalho para Administração Bancária só aparece se a pessoa responsável pelo orçamento tiver permissão de acessar o financeiro.

## Automações atuais

Automatizações identificadas no Supabase real relacionadas a Hub/TI, usuários e acesso:

- `public.admin_update_user_password(p_user_id uuid, p_new_password text)`: atualização administrativa de senha.
- `public.admin_update_user_role(p_user_id uuid, p_role text)`: atualização administrativa de papel.
- `public.admin_update_user_status(p_user_id uuid, p_ativo boolean)`: ativação/desativação administrativa de usuário.
- `public.criar_usuario(p_email text, p_password text, p_nome text, p_role usuario_role)`: criação de usuário.
- `public.get_user_role()`: consulta papel do usuário.
- `public.is_admin()` e `public.is_ubiqua_admin()`: checagens de perfil/admin.
- `public.stats_datacenter()`: estatísticas/saúde de data center/sistema.
- `public.handle_new_auth_user()` e `public.handle_new_user()`: vínculo inicial de usuário.

Triggers relacionadas:

- `auth.users.on_auth_user_created`
- `public.usuarios.trg_propagate_usuario_nome`
- `public.usuarios.usuarios_updated_at`

Edge Functions relacionadas:

- `chat-agent` e `chat-consulta`: automações de chat/consulta.
- `welcome-email`: e-mail de boas-vindas.
- `sync-teams`: integração/simulação Teams.
- `sync-sharepoint`: integração SharePoint/OneDrive/Microsoft.

Observação: o Hub/TI deve evoluir permissões pela UI. As funções atuais ajudam, mas não substituem um modelo configurável de permissões por sistema/módulo/ação.

## Ação a ser realizada

Modelar tabelas centrais para sistemas, papéis, permissões, vínculos usuário-sistema e regras de acesso. Sistemas devem consultar essas regras em vez de manter permissões hardcoded.
