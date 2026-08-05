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
- `generate-cross-system-code`: SPEC-007, gera código opaco de curta duração para abrir outro sistema sem reenviar token cru pela URL.
- `exchange-cross-system-code`: SPEC-007, consome o código uma única vez e hidrata sessão Supabase no sistema de destino.

Observação: o Hub/TI deve evoluir permissões pela UI. As funções atuais ajudam, mas não substituem um modelo configurável de permissões por sistema/módulo/ação.

## SPEC-006 — permissões granulares V1 no Hub

Migration central: `supabase/db/migrations/20260708_029_spec006_permissoes_granulares_hub/`.

Estado remoto em 2026-07-07: aplicado/verificado no projeto Supabase `vcvcwzmbiftcawncibke` e refletido em `supabase/db/current/`.

Objetos publicados:

- `systems.slug` e `systems.visivel_no_hub`;
- `modulos`, `modulo_acoes`;
- `papeis`, `papel_permissoes`;
- `usuario_papeis`, `usuario_permissao_excecoes`;
- `auditoria_permissoes`;
- `hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text)`;
- `hub_sistemas_permitidos(p_usuario_id uuid)`.

Regras:

- Exceção individual prevalece sobre papel.
- `papel_permissoes.modulo_id IS NULL` significa sistema inteiro.
- `papel_permissoes.acao IS NULL` significa todas as ações.
- A UI administrativa do Hub lê/escreve diretamente nas tabelas novas, protegidas por RLS `is_admin()`.
- Outros sistemas devem consumir o contrato via RPC, não por leitura direta das tabelas.

## SPEC-007 — SSO entre sistemas

Migration central: `supabase/db/migrations/20260708_030_spec007_sso_cross_system/`.

Estado remoto em 2026-07-07: migration aplicada e Edge Functions `generate-cross-system-code`/`exchange-cross-system-code` publicadas como `ACTIVE`.

Objeto publicado:

- `cross_system_session_codes`.

Regras:

- A tabela fica sem acesso direto para `anon`/`authenticated`.
- Origem chama `generate-cross-system-code` autenticada.
- Destino chama `exchange-cross-system-code` antes de exibir login.
- URL recebe somente `sso_code`; nunca `access_token` nem `refresh_token`.
- Códigos expiram em 60 segundos e são de uso único.

## SPEC-063 — primeiro sistema-satélite a checar `hub_pode_executar` de verdade

Achado em 2026-08-05: até esta SPEC, **nenhum** sistema-satélite consultava permissão granular nenhuma — todo `Layout.tsx`/`ProtectedRoute.tsx` dos 8 sistemas fora do Hub só verificava se existia uma sessão Supabase válida (`session`/`user`). Como todos compartilham o mesmo `auth.users`, qualquer login válido em qualquer sistema Lucenera bastava para abrir qualquer outro sistema pela URL direta, **mesmo que o papel/exceção da pessoa não desse acesso a ele** — a checagem granular só decidia quais cards apareciam no Hub, nunca bloqueava o sistema de destino.

Caso concreto: usuário configurou o papel "gerente" (atribuído à Lana, `financeiro@lucenera.com.br`) sem acesso a "Dashboard Financeiro" (`papel_permissoes` confirmava isso corretamente), mas ela conseguia abrir `dashboard-empresa-40d7d.goskip.app` (Skip `projectId 41135`, pasta local `dashboard-lucenera-b02z85wa3`) e ver tudo, porque esse app nunca checava nada além do login.

Corrigido só neste sistema (`dashboard-empresa-40d7d`/`dashboard-financeiro`), a pedido explícito do usuário — os outros 7 continuam com a mesma lacuna: `use-auth.tsx` ganhou `hasAccess` (chama `hub_pode_executar(auth.uid(), 'dashboard-financeiro', null, null)` assim que a sessão é conhecida) e `Layout.tsx` passou a bloquear com tela "Acesso negado" quando `hasAccess === false`. Publicado em produção (Skip `projectId 41135`, versão `0.0.22`/`7f37a25`). Ver `03-Projeto/Planos de Ação/SPECs/SPEC-063_Dashboard_Financeiro_Checagem_Permissao_Hub.md`.

**Padrão a reaplicar nos outros 7 sistemas quando for a vez de cada um**: mesmo par de mudanças (`hasAccess` no `AuthProvider` + bloqueio no wrapper de rota), trocando só o `p_system_slug` pelo slug real do sistema em `systems.slug`.

## Ação a ser realizada

Homologar SSO ponta a ponta com usuário real, validar a matriz inicial de papéis/módulos/ações com a operação e então migrar sistema por sistema para consultar `hub_pode_executar` em vez de permissões hardcoded — **"Dashboard Financeiro" é o primeiro migrado (SPEC-063, 2026-08-05); faltam CRM, RH, Cadastro, Orçamentos, Necessidade de Compra, Administração Bancária e Sistema de Entregas**.
