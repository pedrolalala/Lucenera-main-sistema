-- Migration 20260727_064 - SPEC-049 (achado durante validação)
--
-- equipes_projetos tem RLS habilitado desde a migration
-- 20260630_012_equipe_projetos_comissao, mas NUNCA ganhou nenhuma policy de
-- leitura -- confirmado via pg_policies (0 linhas para essa tabela) e via
-- teste real "SET ROLE authenticated; SELECT * FROM equipes_projetos" (0
-- linhas, sem erro). RLS habilitado sem nenhuma policy = deny-all silencioso
-- para qualquer role que nao seja o dono da tabela/superuser.
--
-- Isso nunca foi percebido porque nenhum sistema tinha, ate a SPEC-049,
-- nenhuma consulta autenticada (via anon/authenticated key) que lesse essa
-- tabela -- so leitura via service_role/postgres, que ignora RLS. A view
-- vw_cadastro_produto_reserva_detalhe (migration 20260727_063) e o primeiro
-- consumidor autenticado real, e por isso "equipe_nome" sempre voltava NULL
-- no card lateral do Cadastro, mesmo com o resto do dado correto.
--
-- Tabela sem dado sensivel (id, equipes text, created_at -- ver
-- information_schema.columns), entao segue o mesmo padrao ja usado em todas
-- as outras tabelas do dominio (projetos, contatos, produtos, projeto_itens,
-- estoque_saldos_projeto_item): SELECT liberado para qualquer usuario
-- autenticado, sem restricao por linha.

CREATE POLICY authenticated_select_equipes_projetos
    ON public.equipes_projetos
    FOR SELECT
    TO authenticated
    USING (true);
