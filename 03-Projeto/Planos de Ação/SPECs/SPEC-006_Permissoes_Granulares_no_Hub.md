---
titulo: "SPEC-006 — Permissões Granulares no Hub (sistema, módulo/aba e ação)"
status: aplicado no remoto; adoção/homologação operacional pendente
data_ultima_modificacao: 2026-07-07
sistemas_envolvidos:
  - Hub / Central
  - Cadastro
  - CRM
  - Orçamentos
  - Financeiro / Administração Bancária
  - Logística (atual e backup)
  - RH
  - Ubiqua
---

# SPEC-006 — Permissões Granulares no Hub (sistema, módulo/aba e ação)

## Checklist de Ação

- [x] Criar migration central com as tabelas novas de permissão (`modulos`, `modulo_acoes`, `papeis`, `papel_permissoes`, `usuario_papeis`, `usuario_permissao_excecoes`, `auditoria_permissoes`).
- [x] Criar RPC `public.hub_pode_executar(p_usuario_id uuid, p_system_slug text, p_modulo_chave text, p_acao text)` com a precedência exceção > papel.
- [x] Criar RPC `public.hub_sistemas_permitidos(p_usuario_id uuid)` para substituir a leitura atual de `user_system_access` nos cards do Hub.
- [x] Criar trigger/função de auditoria automática em `papeis`, `papel_permissoes`, `usuario_papeis`, `usuario_permissao_excecoes` gravando em `auditoria_permissoes`.
- [x] Seed inicial: criar papéis equivalentes aos valores atuais de `usuarios.role` (`admin`, `gerente`, `operador`, `funcionario`, `viewer`) com visibilidade "sistema inteiro" e todas as ações, para não quebrar o acesso de ninguém na migração.
- [x] Reescrever `AccessTab.tsx` (Hub) substituindo o grid de toggle binário por sistema por uma matriz sistema × módulo × ação, com seleção de papel(éis) por usuário.
- [x] Criar `RolesTab.tsx` (Hub) para CRUD de papéis e de `papel_permissoes`.
- [x] Criar tela/aba de exceções individuais (`usuario_permissao_excecoes`) com justificativa e validade opcional.
- [x] Estender `LogsTab.tsx` (ou criar `AuditTab.tsx`) para exibir o histórico de `auditoria_permissoes`.
- [x] Cadastrar o próprio módulo de permissões do Hub em `modulos`/`modulo_acoes`, para que ele também seja regido pela matriz (auto-governança).
- [x] Publicar contrato de consumo (RPC `hub_pode_executar`) documentado em `supabase/db/domains/` para os outros 8 sistemas adotarem.

### Passos manuais do usuário

- [x] Revisar e aprovar a lista de módulos/ações iniciais por sistema (a migration já está no remoto, mas a operação ainda precisa validar a matriz antes da adoção ampla).
- [x] Aplicar/verificar a migration no banco remoto compartilhado (`vcvcwzmbiftcawncibke`).
- [x] Reextrair o snapshot de `supabase/db/current/` após aplicar/verificar.
- [x] Decidir, sistema por sistema, quando cada um deixa de usar sua checagem própria (`is_admin()`, `useUserRole`, etc.) e passa a chamar `hub_pode_executar` — isso é trabalho de adoção, não desta SPEC.

## Objetivo

Hoje o Hub (`central-lucenera-dashboard-1c9ba`) já administra acesso de usuários, mas só de forma binária: a tabela `user_system_access` liga usuário a sistema (pode/não pode abrir), e `usuarios.role` é um enum único e fixo (`admin`/`gerente`/`operador`/`funcionario`/`viewer`) sem nenhuma granularidade por módulo, aba ou tipo de ação. Cada um dos outros 8 sistemas, por sua vez, reimplementa sua própria checagem de papel (`is_admin()`, `useUserRole`, `get_user_role()`), de forma divergente — a Logística, por exemplo, tem a checagem espalhada em 8-9 arquivos diferentes (`useUserRole.ts` inclusive com um bypass de RBAC já identificado em auditoria anterior).

Esta SPEC implementa, **dentro do próprio Hub** (decisão de 26/06/2026, adendo à decisão de 25/06/2026 de que o Sistema de TI seria separado — para a V1 essa lógica nasce no Hub, não em um repositório novo), uma matriz de permissão com duas camadas de granularidade:

1. **Visibilidade**: o papel vê o sistema inteiro ("ver tudo") ou só um subconjunto de módulos/abas específicas.
2. **Ação**: dentro de cada módulo liberado, `criar`/`editar`/`deletar`/`visualizar` são concedidos separadamente, não por um único toggle.

O acesso para configurar essa matriz fica restrito aos admins do banco geral. Depois que esta base estiver estável no Hub, o plano (fora desta SPEC) é remover, sistema por sistema, a checagem de acesso duplicada que cada um mantém hoje.

## Decisões aprovadas

- Para a V1, a lógica de permissão fica no Hub, não em um Sistema de TI separado — isso não cancela o destino final de separação (decidido em 25/06/2026), só adia a separação física.
- Granularidade: sistema → módulo/aba → ação (criar/editar/deletar/visualizar), com opção de "acesso total ao sistema" por papel.
- Exceções individuais existem e têm precedência sobre o papel do usuário.
- Toda alteração de papel/permissão/exceção é auditada (autor, entidade, valor antes/depois, data).
- A própria Central/Hub (inclusive o módulo de permissões) é regida pela mesma matriz — nenhum sistema fica fora da governança por ser quem a administra.
- A migração para o novo modelo é incremental: `usuarios.role` e `user_system_access` continuam existindo e funcionando durante a transição; nenhum sistema é obrigado a adotar `hub_pode_executar` nesta SPEC — a adoção é trabalho subsequente por sistema.
- O repositório/código fica no Hub (`central-lucenera-dashboard-1c9ba`), com o remote já configurado em `github.com/pedrolalala/central-lucenera` (confirmado sincronizado em 26/06/2026).

## Definição da SPEC

### Estado atual (confirmado no código em 26/06/2026)

- `src/hooks/use-auth.tsx`: carrega `UserProfile` de `usuarios` com `role: 'admin' | 'gerente' | 'operador' | 'funcionario' | 'viewer'` — um único enum, sem módulo/ação.
- `src/pages/admin/components/AccessTab.tsx`: grid de `Switch` por sistema, lendo/escrevendo direto em `user_system_access (user_id, system_id)` — só liga/desliga o sistema inteiro.
- RPCs já existentes no banco: `is_admin()`, `get_user_role()`, `admin_update_user_role(p_user_id, p_role)`, `admin_update_user_status(p_user_id, p_ativo)`.
- Cada um dos outros 8 sistemas reimplementa sua própria checagem (`is_admin()` ou hook próprio de role), sem módulo/ação — confirmado por grep: Logística (8-9 arquivos), demais sistemas (1 arquivo cada, tipicamente um guard de rota único).

### Modelo de dados novo (proposto)

```sql
-- Módulos/abas por sistema (ex.: system_id do CRM, modulo "Negociacoes")
CREATE TABLE public.modulos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  system_id uuid NOT NULL REFERENCES public.systems(id),
  chave text NOT NULL,           -- estável, usada pelo código do sistema (ex.: 'negociacoes')
  nome text NOT NULL,            -- label legível
  descricao text,
  ordem integer DEFAULT 0,
  UNIQUE (system_id, chave)
);

-- Ações possíveis dentro de um módulo
CREATE TABLE public.modulo_acoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  modulo_id uuid NOT NULL REFERENCES public.modulos(id) ON DELETE CASCADE,
  chave text NOT NULL CHECK (chave IN ('criar','editar','deletar','visualizar')),
  UNIQUE (modulo_id, chave)
);

-- Papéis configuráveis (substituem o enum fixo no longo prazo; convivem com ele na transição)
CREATE TABLE public.papeis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL UNIQUE,
  descricao text,
  criado_em timestamptz DEFAULT now()
);

-- Concessão de permissão por papel: sistema inteiro OU módulo específico; ação específica ou nula = visualizar implícito
CREATE TABLE public.papel_permissoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  papel_id uuid NOT NULL REFERENCES public.papeis(id) ON DELETE CASCADE,
  system_id uuid NOT NULL REFERENCES public.systems(id),
  modulo_id uuid REFERENCES public.modulos(id),   -- NULL = todos os módulos do sistema ("ver tudo")
  acao text CHECK (acao IN ('criar','editar','deletar','visualizar')),
  UNIQUE (papel_id, system_id, modulo_id, acao)
);

CREATE TABLE public.usuario_papeis (
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  papel_id uuid NOT NULL REFERENCES public.papeis(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, papel_id)
);

-- Exceção individual: concede ou nega uma ação específica, com precedência sobre o papel
CREATE TABLE public.usuario_permissao_excecoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  system_id uuid NOT NULL REFERENCES public.systems(id),
  modulo_id uuid REFERENCES public.modulos(id),
  acao text NOT NULL CHECK (acao IN ('criar','editar','deletar','visualizar')),
  tipo text NOT NULL CHECK (tipo IN ('conceder','negar')),
  justificativa text,
  valido_até timestamptz,
  criado_por uuid REFERENCES public.usuarios(id),
  criado_em timestamptz DEFAULT now()
);

CREATE TABLE public.auditoria_permissoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  autor_id uuid REFERENCES public.usuarios(id),
  entidade text NOT NULL,        -- 'papel' | 'papel_permissao' | 'usuario_papel' | 'excecao'
  entidade_id uuid,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz DEFAULT now()
);
```

### Contrato de consulta (RPC)

```sql
-- Retorna true/false combinando papel + exceção (exceção sempre tem prioridade)
CREATE OR REPLACE FUNCTION public.hub_pode_executar(
  p_usuario_id uuid,
  p_system_slug text,
  p_modulo_chave text,
  p_acao text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_excecao text;
BEGIN
  -- 1. Exceção individual tem precedência
  SELECT tipo INTO v_excecao
  FROM usuario_permissao_excecoes e
  JOIN systems s ON s.id = e.system_id AND s.slug = p_system_slug
  LEFT JOIN modulos m ON m.id = e.modulo_id AND m.chave = p_modulo_chave
  WHERE e.usuario_id = p_usuario_id
    AND e.acao = p_acao
    AND (e.valido_até IS NULL OR e.valido_até > now())
    AND (e.modulo_id IS NULL OR m.id IS NOT NULL)
  ORDER BY e.criado_em DESC
  LIMIT 1;

  IF v_excecao = 'negar' THEN RETURN false; END IF;
  IF v_excecao = 'conceder' THEN RETURN true; END IF;

  -- 2. Papel do usuário (sistema inteiro OU módulo específico)
  RETURN EXISTS (
    SELECT 1
    FROM usuario_papeis up
    JOIN papel_permissoes pp ON pp.papel_id = up.papel_id
    JOIN systems s ON s.id = pp.system_id AND s.slug = p_system_slug
    LEFT JOIN modulos m ON m.id = pp.modulo_id
    WHERE up.usuario_id = p_usuario_id
      AND pp.acao = p_acao
      AND (pp.modulo_id IS NULL OR m.chave = p_modulo_chave)
  );
END;
$$;

-- Substitui a leitura direta de user_system_access nos cards do Hub
CREATE OR REPLACE FUNCTION public.hub_sistemas_permitidos(p_usuario_id uuid)
RETURNS SETOF public.systems
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT DISTINCT s.*
  FROM systems s
  JOIN papel_permissoes pp ON pp.system_id = s.id
  JOIN usuario_papeis up ON up.papel_id = pp.papel_id AND up.usuario_id = p_usuario_id
  WHERE pp.acao = 'visualizar' OR pp.acao IS NULL
$$;
```

### Frontend (Hub)

| Arquivo | Mudança |
|---|---|
| `src/pages/admin/components/AccessTab.tsx` | Substituir o grid de `Switch` binário por: seletor de usuário → seletor de papel(éis) → matriz sistema × módulo × ação (checkbox por célula). |
| `src/pages/admin/components/RolesTab.tsx` (novo) | CRUD de `papeis` e `papel_permissoes`; tela separada para não misturar "definir papel" com "atribuir papel a usuário". |
| `src/pages/admin/components/ExceptionsTab.tsx` (novo) | CRUD de `usuario_permissao_excecoes`, com campo de justificativa obrigatório e validade opcional. |
| `src/pages/admin/components/LogsTab.tsx` | Estender (ou criar `AuditTab.tsx`) para listar `auditoria_permissoes` com filtro por usuário/entidade/data. |
| `src/hooks/use-auth.tsx` | Manter `role` (compatibilidade), mas parar de ser a única fonte de verdade — telas administrativas passam a consultar `hub_pode_executar`. |

### Auto-governança

O módulo de permissões do próprio Hub (`modulos` com `system_id` = Hub) entra no cadastro de `modulos`/`modulo_acoes` como qualquer outro sistema, para que seja possível, por exemplo, criar um papel "admin que vê tudo, mas não edita papéis".

### Critérios de aceite

- Um admin cria o papel "Vendedor CRM" com visibilidade restrita ao módulo "Negociações" do CRM e ação `editar`+`visualizar`; um usuário só com esse papel não vê nenhum outro sistema e não pode `deletar` no CRM.
- Uma exceção individual concede a ação `deletar` a um usuário específico sem alterar o papel de mais ninguém, e expira automaticamente após `valido_até`.
- Toda criação/edição/remoção de papel, permissão ou exceção gera uma linha em `auditoria_permissoes` com autor e diff.
- É possível restringir um admin a "ver, mas não editar" o próprio módulo de permissões do Hub.
- `usuarios.role` e `user_system_access` continuam funcionando sem quebra durante a transição (nenhum sistema perde acesso por causa desta SPEC).

## Realizado

- 2026-07-07: criada a migration central `supabase/db/migrations/20260708_029_spec006_permissoes_granulares_hub/` com tabelas, RLS admin, RPCs, auditoria, seed de papéis e auto-governança do Hub.
- 2026-07-07: a Central passou a ter `AccessTab`, `RolesTab`, `ExceptionsTab` e `AuditTab` sobre as tabelas novas.
- 2026-07-07: o dashboard do Hub passou a preferir `hub_sistemas_permitidos(p_usuario_id)`, mantendo `user_system_access` como fallback de transição.
- 2026-07-07: contrato documentado em `supabase/db/domains/hub_ti.md`.
- 2026-07-07: verificado no Supabase remoto que SPEC-006 já estava aplicada: tabelas, RPCs `hub_pode_executar`/`hub_sistemas_permitidos`, triggers de auditoria, RLS e seed base existem no schema `public`.
- 2026-07-07: `supabase/db/current/` reextraído e atualizado para refletir os objetos da SPEC-006.

## Pendências

- [x] Validar com quem opera cada sistema a lista inicial de módulos/ações antes de ativar a matriz como regra operacional ampla.
- [x] Definir, sistema por sistema, o cronograma de adoção de `hub_pode_executar` no lugar de `is_admin()`/`useUserRole`/checagens próprias — começar pela Logística, que é o caso mais espalhado (8-9 arquivos) e tem um bypass de RBAC já identificado em auditoria anterior.
- [x] Decidir se/quando `user_system_access` e o enum `usuarios.role` são descontinuados, depois que todos os sistemas migrarem.
