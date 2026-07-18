# Migration 20260718_052 - SPEC-036 (Catálogo Ubiqua: isolamento de clientes por representante)

## Contexto

Ver `03-Projeto/Planos de Ação/SPECs/SPEC-036_Catalogo_Ubiqua_Marca_Isolamento_Clientes_e_Cores.md` (item 6 do Checklist de Ação).

O Catálogo de Peças Ubiqua (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`) usa o mesmo projeto Supabase central (`vcvcwzmbiftcawncibke`) do resto do ecossistema Lucenera. Hoje `public.informacoes_cliente_ubiqua` não tem nenhuma coluna que identifique quem cadastrou cada cliente, e a RLS existente é aberta demais (`USING (true)` para `anon`/`authenticated` em várias policies), permitindo que qualquer representante veja/edite os clientes de qualquer outro.

## Decisão de negócio (já tomada, não reabrir)

- Isolamento é por **representante individual** (`usuarios_ubiqua.id`), não por empresa/representação — decisão baseada na fala do Vinicius na reunião ("representante A cadastra... representante B não consegue visualizar").
- Clientes já existentes sem dono ficam com `cadastrado_por_usuario_id = NULL` (sem backfill automático) — continuam visíveis apenas para staff Lucenera central (`usuarios.role IN ('admin','gerente')`, via a policy pré-existente `"Permitir leitura admin_gerente"`, que esta migration não altera) e para `usuarios_ubiqua` com `nivel_acesso IN ('admin','interno')`. Backfill manual fica pendente de decisão futura.

## Arquivos

| Arquivo | Função |
|---|---|
| `001_informacoes_cliente_ubiqua_isolamento_representante.sql` | Adiciona a coluna `cadastrado_por_usuario_id` (FK para `usuarios_ubiqua.id`) + índice, remove as policies antigas totalmente abertas e cria policies de SELECT/INSERT/UPDATE/DELETE restritas ao dono do cadastro ou a `usuarios_ubiqua.nivel_acesso IN ('admin','interno')`. |

## Efeito colateral (de brinde)

Não existia nenhuma policy de DELETE em `informacoes_cliente_ubiqua` antes desta migration — ou seja, exclusão de cliente nunca funcionava via `anon`/`authenticated` (bug pré-existente). A nova policy `delete_informacoes_cliente_por_representante` corrige isso como consequência natural do desenho de isolamento, não é um objetivo separado.

## Segurança

- Mantém intacta a policy `"Permitir leitura admin_gerente"` (staff Lucenera central).
- Remove as policies `"Permitir leitura anon e auth"`, `all_select_informacoes_cliente`, `anon_insert_informacoes_cliente`, `anon_update_informacoes_cliente`, `auth_insert_informacoes_cliente`, `auth_update_informacoes_cliente` — todas com `USING`/`WITH CHECK` sem filtro por dono.
- INSERT exige que `cadastrado_por_usuario_id = auth.uid()`, ou seja, o frontend precisa preencher essa coluna no momento da criação (ver `CustomersPage.tsx`).

## Status

**Aplicada em 2026-07-18** no Supabase real (`vcvcwzmbiftcawncibke`), pelo orquestrador (nunca por subagente), com confirmação explícita do usuário. Verificado pós-aplicação: coluna `cadastrado_por_usuario_id` criada; as 5 policies (`select/insert/update/delete_informacoes_cliente_por_representante` + `Permitir leitura admin_gerente` preservada) são exatamente as existentes na tabela hoje; índice `idx_informacoes_cliente_ubiqua_dono` criado; os 4 clientes pré-existentes ficaram com `cadastrado_por_usuario_id = NULL`.

## Verificação esperada (pós-aplicação, manual)

- Um novo cliente criado por um representante autenticado tem `cadastrado_por_usuario_id` preenchido com o `auth.uid()` de quem criou.
- Um segundo representante, logado com outra conta `revendedor`, não vê (`SELECT`) o cliente cadastrado pelo primeiro.
- Uma conta com `usuarios_ubiqua.nivel_acesso IN ('admin','interno')` continua vendo todos os clientes.
- Staff Lucenera central (`usuarios.role IN ('admin','gerente')`) continua vendo todos os clientes via a policy pré-existente.
