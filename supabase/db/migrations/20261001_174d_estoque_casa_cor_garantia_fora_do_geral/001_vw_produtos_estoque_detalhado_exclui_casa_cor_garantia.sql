-- Migration 20261001_174d (SPEC-174, item N8) -- RASCUNHO, NÃO APLICADA.
--
-- Decisão da reunião de 01/10/2026 ("Setor separado"): os setores
-- 'Estoque Garantia' e 'Estoque Casa Cor' (enum public.estoque_local, já
-- existente) ficam visíveis na consulta de produto, mas NÃO somam no
-- estoque geral nem no disponível do produto.
--
-- ONDE O CÁLCULO VIVE HOJE (consulta só leitura ao Supabase real em
-- 01/10/2026, via pg_get_functiondef/pg_get_viewdef):
--
--   1. produtos.estoque_total e produtos.estoque_disponivel são COLUNAS
--      diretas da tabela produtos -- não existe nenhuma função/trigger que
--      as recalcule a partir de estoque_itens (conferido: nenhuma function
--      em pg_proc faz "UPDATE produtos ... SET estoque_total/
--      estoque_disponivel"). O único trigger relacionado,
--      fn_sync_estoque_itens_from_produtos (AFTER INSERT/UPDATE ON
--      produtos), vai no sentido CONTRÁRIO -- copia produtos.estoque_total/
--      estoque_disponivel PARA uma linha de estoque_itens(local='Estoque'),
--      nunca o inverso. Essas colunas são escritas só pelos scripts de
--      import (scripts/importar_produtos_estoque.py e
--      importar_produtos_novos.py) -- fora do escopo desta migration.
--
--   2. O cálculo que de fato SOMA estoque_itens por produto, incluindo
--      TODOS os locais (sem distinguir Casa Cor/Garantia dos demais),
--      acontece em dois lugares:
--
--      a) Frontend (Cadastro, cadastro-lucenera-b86fe), client-side, sem
--         nenhuma função de banco: `getProdutosEstoqueFiltradoBatched`
--         (src/services/produtos.ts) e `buildEstoquePorSetor` +
--         totais de `PecaDetailsPanel.tsx` somavam
--         TODOS os estoque_itens do produto. CORRIGIDO no mesmo commit
--         desta migration (fora do banco): os dois agora excluem
--         'Estoque Garantia'/'Estoque Casa Cor' da soma geral/disponível,
--         usando a nova lista `ESTOQUE_SETORES_FORA_DO_GERAL` em
--         src/lib/estoque-sectors.ts -- continuam aparecendo na lista
--         vertical/tabela por setor, só com um rótulo "fora do disponível".
--
--      b) Banco: a VIEW public.vw_produtos_estoque_detalhado (criada em
--         20260629140000_create_vw_produtos_estoque_detalhado.sql,
--         redefinida em 20260629151700_fix_estoque_view_and_rls.sql,
--         ambas dentro de 04-Sistemas/cadastro-lucenera-b86fe/supabase/
--         migrations -- não em supabase/db/current/, que está sem
--         reextração desta view) calcula `estoque_geral` somando
--         estoque_itens.quantidade de todo `local ILIKE 'estoque%'`.
--         'Estoque Garantia' e 'Estoque Casa Cor' COMEÇAM com "Estoque " e
--         BATEM nesse padrão -- ou seja, HOJE, se alguém carregar estoque
--         nesses dois setores, a view somaria errado (geral e disponível
--         inflados). Esta migration corrige essa view. Esta é a view
--         "vw_produtos_estoque_detalhado" citada na SPEC-174.
--
-- USO ATUAL de vw_produtos_estoque_detalhado: só uma função exportada no
-- Cadastro a consulta (`getProdutoEstoqueDetalhado`,
-- src/services/produtos.ts), e essa função NÃO é chamada em nenhum lugar
-- do app hoje (grep em 04-Sistemas/cadastro-lucenera-b86fe/src: nenhuma
-- outra ocorrência de `.from('vw_produtos_estoque_detalhado')` ou
-- `getProdutoEstoqueDetalhado` fora da própria definição). Nenhum outro
-- sistema usa esta view em código (as outras ocorrências do nome, em
-- src/lib/supabase/types.ts de outros sistemas, são só metadados de FK
-- gerados, não SELECTs reais). Corrigir agora é preventivo, antes da
-- planilha de Casa Cor (passo manual pendente da SPEC-174) ser carregada.
--
-- DRY-RUN (leitura, sem transação de escrita -- o agente implementador não
-- executa DDL/DML contra o banco real, nem dentro de BEGIN/ROLLBACK):
-- `SELECT local, count(*), sum(quantidade), sum(quantidade_reservada)
--  FROM estoque_itens GROUP BY local` em 01/10/2026 retornou só os locais
-- 'Estoque' (4886 linhas) e 'Showroom' (337 linhas) -- NENHUMA linha hoje
-- com local = 'Estoque Garantia' ou 'Estoque Casa Cor'. Logo, HOJE, 0
-- produtos mudam de estoque_geral/disponível com esta correção (a view
-- também está sem nenhum uso ativo). O ganho é não inflar os totais no dia
-- em que a planilha do Matheus (Casa Cor) e qualquer movimentação de
-- Garantia forem carregadas em estoque_itens.
--
-- Triggers em estoque_itens: NENHUM (conferido via
-- information_schema.triggers). Triggers em produtos: produtos_updated_at,
-- trg_atualizar_preco_venda, trg_calculo_preco_venda,
-- trg_sync_estoque_itens_from_produtos, update_produtos_updated_at --
-- nenhum de integração externa (SharePoint) e, de qualquer forma, esta
-- migration só redefine uma VIEW (nenhum UPDATE/INSERT em produtos ou
-- estoque_itens), então nenhum trigger dispara ao aplicá-la.
--
-- CREATE OR REPLACE VIEW preserva as 9 colunas e a ORDEM atuais (id,
-- codigo_produto, nome, sku, preco_venda, estoque_geral, reserva,
-- separacao, disponivel) -- acrescenta 2 colunas NOVAS no final
-- (estoque_garantia, estoque_casa_cor), visíveis mas fora de
-- estoque_geral/disponivel, para quem quiser consumir a view já com o
-- detalhe dos dois setores.
--
-- Rollback: reaplicar a definição anterior (sem o filtro NOT IN e sem as
-- 2 colunas novas) -- arquivo
-- 04-Sistemas/cadastro-lucenera-b86fe/supabase/migrations/20260629151700_fix_estoque_view_and_rls.sql.

CREATE OR REPLACE VIEW public.vw_produtos_estoque_detalhado AS
WITH estoque_calculado AS (
    SELECT ei.produto_id,
        sum(
            CASE
                WHEN ei.local::text ILIKE 'estoque%'
                 AND ei.local NOT IN ('Estoque Garantia'::public.estoque_local, 'Estoque Casa Cor'::public.estoque_local)
                THEN ei.quantidade
                ELSE 0
            END
        ) AS qtd_geral,
        sum(
            CASE WHEN ei.local::text ILIKE 'showroom%' THEN ei.quantidade ELSE 0 END
        ) AS qtd_showroom,
        sum(
            CASE WHEN ei.local = 'Estoque'::public.estoque_local THEN COALESCE(ei.quantidade_reservada, 0) ELSE 0 END
        ) + sum(
            CASE WHEN ei.local::text ILIKE 'reserva%' THEN ei.quantidade ELSE 0 END
        ) AS qtd_reserva,
        sum(
            CASE
                WHEN ei.local::text ILIKE 'separacao%' OR ei.local::text ILIKE 'separação%'
                THEN ei.quantidade
                ELSE 0
            END
        ) AS qtd_separacao,
        -- SPEC-174 N8: expostos à parte, fora de qtd_geral/disponivel.
        sum(
            CASE WHEN ei.local = 'Estoque Garantia'::public.estoque_local THEN ei.quantidade ELSE 0 END
        ) AS qtd_garantia,
        sum(
            CASE WHEN ei.local = 'Estoque Casa Cor'::public.estoque_local THEN ei.quantidade ELSE 0 END
        ) AS qtd_casa_cor,
        sum(ei.quantidade) AS total_fisico
    FROM public.estoque_itens ei
    GROUP BY ei.produto_id
)
SELECT p.id,
    p.codigo_produto,
    p.nome,
    p.sku,
    p.preco_venda,
    COALESCE(ec.qtd_geral, 0) AS estoque_geral,
    COALESCE(ec.qtd_reserva, 0) AS reserva,
    COALESCE(ec.qtd_separacao, 0) AS separacao,
    COALESCE(ec.qtd_geral, 0) - COALESCE(ec.qtd_reserva, 0) - COALESCE(ec.qtd_separacao, 0) AS disponivel,
    -- SPEC-174 N8 (novas, no final -- não alteram a ordem das 9 colunas
    -- existentes): visíveis, mas já fora de estoque_geral/disponivel acima.
    COALESCE(ec.qtd_garantia, 0) AS estoque_garantia,
    COALESCE(ec.qtd_casa_cor, 0) AS estoque_casa_cor
FROM public.produtos p
LEFT JOIN estoque_calculado ec ON p.id = ec.produto_id;

COMMENT ON VIEW public.vw_produtos_estoque_detalhado IS
'SPEC-174 N8 (2026-10-01): estoque_geral/disponivel não somam mais
''Estoque Garantia''/''Estoque Casa Cor'' (decisão "Setor separado", reunião
de 01/10) -- antes, o filtro local ILIKE ''estoque%'' incluía os dois por
engano, já que ambos começam com "Estoque ". Colunas novas
estoque_garantia/estoque_casa_cor expõem esses setores à parte, no final,
sem mudar a ordem das colunas anteriores.';

-- GRANT preservado (CREATE OR REPLACE VIEW mantém ACL existente; repetido
-- aqui só por clareza/idempotência, igual ao padrão de outras migrations).
GRANT SELECT ON public.vw_produtos_estoque_detalhado TO authenticated;

NOTIFY pgrst, 'reload schema';
