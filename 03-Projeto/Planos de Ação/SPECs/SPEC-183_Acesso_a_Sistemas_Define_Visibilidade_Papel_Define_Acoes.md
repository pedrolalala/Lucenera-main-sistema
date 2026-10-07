---
titulo: "SPEC-183 — Acesso a Sistemas define o que a pessoa vê; Papel define o que ela faz"
status: pendente
data_ultima_modificacao: 2026-10-07
sistemas_envolvidos:
  - Central / Hub (central-lucenera-dashboard-1c9ba)
  - Todos os sistemas que usam hub_pode_executar nas RLS (Adm. Bancária, Orçamentos, Cadastro, Compras, CRM, Logística, Separação, RH, Central de Solicitações)
  - Todos os sistemas com SystemSwitcher (useSistemasPermitidos replicado)
---

# SPEC-183 — Acesso a Sistemas define o que a pessoa vê; Papel define o que ela faz

## Checklist de Ação

### Fase 1 — Regra nova de visibilidade (banco + Central)

- [x] Migration: `hub_sistemas_permitidos(u)` passa a devolver **só** os sistemas marcados em `user_system_access` (com `visivel_no_hub = true`), sem olhar papel.
- [x] Migration: `hub_pode_executar(u, slug, modulo, acao)` ganha um **portão** antes de tudo (antes das exceções): se o sistema é `visivel_no_hub = true` e não está em `user_system_access` do usuário → `false`. Bypass do portão para `usuarios.role = 'admin'`.
- [x] Migration: remover a policy `user_insert_usa` de `user_system_access` (hoje qualquer usuário logado pode inserir acesso para si mesmo — com a regra nova isso deixaria cada um se liberar sozinho). Fica só `user_select_usa` (ler o próprio) + `admin_all_usa`.
- [x] Migration (dados): para cada usuário **não admin com papel**, regravar `user_system_access` = o que ele vê hoje no Hub (resultado atual de `hub_sistemas_permitidos`). Usuários sem papel ficam como estão (já veem a lista antiga). Ninguém ganha nem perde nada no dia da troca.
- [x] Na mesma migration, ajuste da Mariane (`mariane@lucenera.com.br`): sem Administração Bancária, com Showroom Lucenera.
- [x] Central, aba **Acesso a Sistemas**: texto explicando que é aqui que se define o que a pessoa vê; aviso por sistema marcado quando nenhum papel da pessoa dá permissão nele ("vê o cartão, mas não consegue fazer nada lá dentro").
- [x] Central, aba **Papéis** (e Matriz de Acesso): texto deixando claro que papel não faz sistema aparecer, só define ações dentro dos sistemas liberados.
- [x] Central, aba **Exceções**: idem (exceção não fura o portão de Acesso a Sistemas).
- [x] Atualizar `supabase/db/domains/hub_ti.md`. (Comentário de `useSistemasPermitidos.ts` não alterado: está replicado em ~10 sistemas e o fallback legado continua inofensivo, lê a mesma tabela.)

### Fase 2 — Papéis por ação dentro do sistema (depende das regras da gerente de projetos)

- [x] ~~Aba Papéis por ação~~ — já existe no ar (Skip 37750): nível por sistema Sem acesso / Consultar / Editar (sem cadastrar) / Editar / Total. A cópia local da Central está atrasada em relação ao Skip.
- [ ] Permitir permissões por **módulo** dos sistemas que tiverem módulos (hoje só `orcamentos.aprovacao_equipe` e `hub.permissoes`).
- [ ] Criar papel `gerente_projetos` = `equipe_projetos` + o que a Mari pode a mais (lista a definir pelo usuário).
- [ ] Migrar as checagens que ainda leem `usuarios.role` direto (`equipe_aprovar_orcamento`, `equipe_devolver_orcamento_cliente`: `role IN ('admin','gerente')`) para `hub_pode_executar(..., 'orcamentos', 'aprovacao_equipe', 'aprovar')`.

### Passos manuais do usuário

- [x] Aprovar esta SPEC (Fase 1) — 07/10.
- [ ] Depois da Fase 1, revisar pessoa a pessoa na aba Acesso a Sistemas (tabela "Estado em 07/10" abaixo).
- [ ] Levantar o que a Mari pode fazer a mais que a equipe de projetos (libera a Fase 2).

## Objetivo

Hoje quem decide o que aparece no Hub são os **papéis**, e a aba "Acesso a Sistemas" só vale para quem não tem papel nenhum — por isso marcar o Showroom para a Mariane não teve efeito, e a Administração Bancária apareceu porque o papel `funcionario` dava acesso total a ela (com acesso real aos dados, não só ao cartão). Esta SPEC separa as duas coisas: **Acesso a Sistemas** = o que a pessoa vê e pode abrir (só o que o admin marcou); **Papel** = o que ela pode fazer dentro de cada sistema liberado.

## Decisões aprovadas

- (2026-10-07) A regra começa pela visualização: a pessoa só vê o que estiver marcado em **Acesso a Sistemas**.
- (2026-10-07) Sistema não marcado = **esconde e bloqueia** (cartão some e `hub_pode_executar` nega, inclusive por link direto), mesmo que o papel permita.
- (2026-10-07) No dia da troca, **copiar o que cada pessoa vê hoje** para Acesso a Sistemas; ajustes finos depois, pessoa a pessoa. Mariane ajustada já na migração (tira Adm. Bancária, põe Showroom).
- (2026-10-07) Mari é **gerente de projetos** e terá poderes a mais que a equipe de projetos — o que exatamente fica para depois ("por enquanto deixar como está").
- Admin (`usuarios.role = 'admin'`) continua vendo e podendo tudo (bypass já existente no Hub e no SystemSwitcher).

## Definição da SPEC

### Estado atual (conferido no banco em 2026-10-07)

| Peça | Hoje |
|---|---|
| Hub / SystemSwitcher | admin → tudo; senão `hub_sistemas_permitidos` (papéis com `visualizar` ou TOTAL); se vazio → `user_system_access` |
| `hub_pode_executar` (17 tabelas com RLS usam) | exceção individual → papel. Não olha `user_system_access` |
| `user_system_access` | PK `(user_id, system_id)`, sem trigger. Policies: `user_select_usa`, `admin_all_usa`, **`user_insert_usa` (usuário insere para si mesmo)** |
| Papel da Mariane | trocado hoje 10h00–10h02 (Pedro, pela Matriz de Acesso): saiu `equipe_projetos`, entrou `funcionario` (único usuário nesse papel; dá TOTAL em Adm. Bancária, CRM, Orçamentos, Fichas Técnicas, Separação, Entregas) |
| Showroom | nenhum papel libera → nenhum não-admin vê |
| Memória Lucenera | só `admin_geral` com ação `aprovar` (sem `visualizar`) → nenhum não-admin vê |

### Regra nova

```
Cartão no Hub / menu lateral  = sistema marcado em Acesso a Sistemas   (admin: todos)
Pode agir dentro do sistema   = marcado em Acesso a Sistemas  E  (exceção 'conceder' OU papel permite)
                                exceção 'negar' continua tirando a ação
```

`hub_pode_executar` — portão novo, antes da exceção:

```sql
IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND role = 'admin')
   AND EXISTS (SELECT 1 FROM systems WHERE slug = p_system_slug AND visivel_no_hub)
   AND NOT EXISTS (SELECT 1 FROM user_system_access a JOIN systems s ON s.id = a.system_id
                   WHERE a.user_id = p_usuario_id AND s.slug = p_system_slug)
THEN RETURN false; END IF;
```

Sistemas internos (`visivel_no_hub = false`, ex.: `hub`) ficam fora do portão — continuam só por papel. O lookup usa a PK `(user_id, system_id)`; as policies continuam no padrão `(SELECT hub_pode_executar((SELECT auth.uid()), …))` (uma chamada por consulta).

### Impacto nos frontends

Nenhum código obrigatório fora da Central: Hub e SystemSwitcher já chamam `hub_sistemas_permitidos` e o fallback legado lê a mesma tabela. Mudam só os textos/avisos das abas de Administração da Central.

**Limite conhecido:** sistemas-satélite que só exigem login e têm tabelas com RLS `USING (true)` (ex.: Showroom, Catálogo Ubiqua, Memória) não passam por `hub_pode_executar` — neles o "bloqueia por link direto" só vale depois de um guard de entrada no próprio sistema (ver Pendências).

### Estado em 07/10 (o que será copiado; não-admins)

| Pessoa | Vê hoje (vira o Acesso a Sistemas dela) |
|---|---|
| Caroline | cadastro, controle-garantia, controle-producao, necessidade-de-compra, orcamentos, solicitacoes |
| Débora | cadastro, controle-garantia, controle-producao, logistica, necessidade-de-compra, separacao-parcial, solicitacoes |
| Mariane | cadastro, controle-garantia, controle-producao, crm, logistica, orcamentos, separacao-parcial, solicitacoes, ubiqua **+ showroom − financeiro** |
| Marina | cadastro, controle-garantia, controle-producao, crm, logistica, orcamentos, separacao-parcial, solicitacoes |
| Thairine | cadastro, controle-garantia, controle-producao, crm, logistica, orcamentos, separacao-parcial, solicitacoes |
| pedrollaghi | cadastro, controle-garantia, controle-producao, logistica, orcamentos, separacao-parcial, solicitacoes, ubiqua |
| erp.lucenera, marianelighting, vinicius_bortolin | nada (sem papel e lista antiga vazia) |

Admins (Filippo, Kimberly, Pedro, Vinicius, Lana¹) seguem vendo tudo. ¹ Lana não aparece entre os não-admins — conferir o `role` dela antes de aplicar.

### Análise de ecossistema

- Depende de `usuarios`, `systems`, `user_system_access`, `papeis`, `papel_permissoes`, `usuario_papeis`, `usuario_permissao_excecoes`.
- Afeta Hub/TI diretamente e, via `hub_pode_executar`, as RLS de Adm. Bancária, Orçamentos, Cadastro/produtos, Compras, CRM/contatos/projetos, Separação, RH (`funcionarios_novo`) e Central de Solicitações.
- Nenhum dado duplicado novo.

### Critérios de aceite

- Mariane vê Showroom e não vê Administração Bancária; consulta a `boletos` como ela retorna 0 linhas.
- Para cada não-admin, o Hub mostra exatamente a mesma lista de antes da migração (exceto Mariane).
- Desmarcar um sistema em Acesso a Sistemas tira o cartão **e** faz `hub_pode_executar` daquele sistema retornar `false` para a pessoa.
- Marcar um sistema faz o cartão aparecer mesmo que nenhum papel libere (e a aba mostra o aviso).
- Usuário comum não consegue inserir linha em `user_system_access` (teste como `authenticated`, não service role).
- Admin continua vendo tudo.

### Testes obrigatórios

- Dry-run da migration com ROLLBACK (sem `BEGIN/COMMIT` no texto testado), comparando `hub_sistemas_permitidos` antes × depois para todos os usuários.
- Testar `hub_pode_executar` e uma consulta RLS real como `authenticated` para Mariane e para um admin.
- `CREATE OR REPLACE` mantendo exatamente a mesma assinatura das duas funções (não criar overload).

## Realizado

### 2026-10-07

- Migration `20261007_186_spec183_acesso_sistemas_visibilidade` (001 dados + 002 funções/policy + rollback) aplicada no Supabase real após dry-run com ROLLBACK.
- Mudança em relação à tabela acima: para a Mariane foi mantida **a lista que o usuário já tinha marcado** (cadastro, controle-producao, crm, logistica, memoria, orcamentos, separacao-parcial, showroom, solicitacoes, ubiqua) — ela ganhou Showroom e Memória e perdeu Adm. Bancária e Controle de Garantia (não estava marcado).
- Conferido: todos os outros usuários veem exatamente o mesmo que antes; admin segue com tudo; como Mariane (`authenticated`): `notas_fiscais` 3→0, `contas_bancarias` 4→0, `boletos` segue 26 (liberado por Separação Parcial, proposital); INSERT em `user_system_access` pelo próprio usuário agora é negado.

### 2026-10-07 (Central publicada)

- Skip 37750 v0.0.47 (`17e851f`) publicado: textos novos nas abas Acesso a Sistemas, Matriz de Acesso, Papéis e Exceções + aviso por sistema marcado sem nenhum papel/exceção que dê permissão, e aviso quando o usuário é admin. Editado sobre o arquivo do Skip (local está desatualizado; não sincronizado).
- Antes do apply: as 13 migrations legadas da Central já estavam registradas; depois do publish: nenhuma Edge Function republicada (comparado `GET /functions` antes × depois), regra SPEC-183 intacta no banco. Textos conferidos no bundle de produção.

## Pendências

- [ ] Definir o que a gerente de projetos (Mari) pode fazer a mais que a equipe de projetos — libera a Fase 2 (papel `gerente_projetos`).
- [ ] Guard de entrada nos sistemas-satélite que só exigem login (Showroom, Catálogo Ubiqua, Memória Lucenera, Controle de Produção/Garantia): checar `hub_pode_executar(uid, slug, NULL, NULL)` ao abrir, para o "bloqueia por link direto" valer também neles.
- [ ] Conta `marianelighting@outlook.com` (viewer, sem papel, sem acesso): confirmar se é da Mariane e se deve ser desativada.
- [x] Papel `gerente` (Lana) dá TOTAL em Administração Bancária e RH — **confirmado intencional pelo usuário em 07/10**.
