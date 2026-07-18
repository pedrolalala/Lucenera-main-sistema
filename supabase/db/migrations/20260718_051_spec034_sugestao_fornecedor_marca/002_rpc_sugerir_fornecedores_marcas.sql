-- Migration 20260718_051 — Parte 2 (SPEC-034)
-- RPC de sugestão (não aplicação) de fornecedor por marca, para acelerar o
-- backfill manual de marcas.fornecedor_id (109 marcas sem fornecedor em
-- 2026-07-18). Não grava nada — só leitura. A aplicação continua sendo um
-- clique explícito do usuário via atualizarFornecedorMarca() já existente
-- (services/marcas.ts, SPEC-033), individual ou em lote com revisão visível
-- (ver Marcas.tsx / ModalRevisarSugestoesFornecedor.tsx desta SPEC).
--
-- Escopo: só marcas com fornecedor_id ainda NULL. Não filtra marcas.ativo,
-- para manter paridade com getMarcasComFornecedor() (SPEC-033), que também
-- não filtra por esse campo hoje.
--
-- Candidato: top-1 por marca (LATERAL + LIMIT 1) via
-- word_similarity(unaccent(lower(marca.nome)), unaccent(lower(fornecedor.nome)))
-- — mesma função e mesma ordem de argumentos validada empiricamente na
-- análise da SPEC-034 (marca.nome, geralmente curto, como termo;
-- fornecedor.nome, geralmente mais longo/formal, como texto onde a melhor
-- substring é procurada).
--
-- Piso de score 0.3 só para reduzir ruído/payload (mesmo piso técnico usado
-- em buscar_fornecedores_fuzzy) — NÃO é o limiar de confiança para exibir ou
-- aplicar a sugestão. Essa decisão fica no frontend (Marcas.tsx), como
-- constantes fáceis de ajustar sem nova migration.
--
-- Calculada sob demanda (chamada quando a tela /marcas carrega), sem
-- pré-computação/cache: volume pequeno (109 marcas x fornecedores ativos
-- cadastrados como contato_tipos.tipo = 'fornecedor'), sem sinal de
-- lentidão nesse tipo de cruzamento no restante do sistema, e evita servir
-- sugestão desatualizada se um fornecedor novo for cadastrado entre chamadas.
--
-- SECURITY INVOKER: só leitura, respeita as mesmas policies de SELECT já
-- abertas (authenticated) em marcas/contatos/contato_tipos.

CREATE OR REPLACE FUNCTION public.sugerir_fornecedores_marcas()
RETURNS TABLE (
    marca_id        uuid,
    marca_nome      text,
    fornecedor_id   uuid,
    fornecedor_nome text,
    score           real
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT
        m.id       AS marca_id,
        m.nome     AS marca_nome,
        best.id    AS fornecedor_id,
        best.nome  AS fornecedor_nome,
        best.sim   AS score
    FROM public.marcas m
    CROSS JOIN LATERAL (
        SELECT
            c.id,
            c.nome,
            word_similarity(
                public.immutable_unaccent(lower(m.nome)),
                public.immutable_unaccent(lower(c.nome))
            ) AS sim
        FROM public.contatos c
        JOIN public.contato_tipos ct
            ON ct.contato_id = c.id
           AND ct.tipo = 'fornecedor'
        WHERE c.ativo = true
        ORDER BY sim DESC
        LIMIT 1
    ) best
    WHERE m.fornecedor_id IS NULL
      AND best.sim >= 0.3
    ORDER BY best.sim DESC, m.nome;
$$;

COMMENT ON FUNCTION public.sugerir_fornecedores_marcas() IS
'SPEC-034. Sugestão (não aplicação) de fornecedor por marca, top-1 por
word_similarity(unaccent(lower(marca.nome)), unaccent(lower(fornecedor.nome)))
>= 0.3, restrita a marcas.fornecedor_id IS NULL e
contato_tipos.tipo = fornecedor / contatos.ativo = true. Usada por
getSugestoesFornecedorMarca() (services/marcas.ts) para popular a tela
/marcas com sugestões clicáveis. Nunca grava nada — só leitura. SECURITY
INVOKER.';

GRANT EXECUTE ON FUNCTION public.sugerir_fornecedores_marcas() TO authenticated;
