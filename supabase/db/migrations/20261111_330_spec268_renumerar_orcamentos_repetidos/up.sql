-- SPEC-268 (continuação, 11/11/2026): numerar TODOS os orçamentos ORC-… pela ordem de criação (todas as equipes juntas) e travar com índice único.
-- Contexto: até 10/11 cada equipe (RLS) gerava a sua própria sequência; a migration 321 já tornou o gerador global.
-- Decisão do usuário: o número é um só para todas as equipes, na ordem de data e hora de criação (o mais antigo é ORC-0001).
-- O de/para (só dos que mudam) fica em backup.spec268_renumeracao_orcamentos (usado pelo rollback).
-- O que muda por id (nunca por texto): orcamentos.numero, boletos.numero_documento, financeiro_titulos/parcelas,
-- projeto_parcelas, negociacoes, separacoes (numero_venda/numero_entrega), entregas_finalizadas,
-- estoque_movimentos_projeto_item.observacao e devolucoes_estoque.motivo. Texto livre sem ligação por id
-- (estoque_kardex.historico) NÃO é alterado. O índice único é criado por último (durante a troca o número passa por repetições).
-- Sem BEGIN/COMMIT de propósito (o dry_run.sql abre a transação e termina em ROLLBACK).

CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec268_renumeracao_orcamentos (
  orcamento_id  uuid PRIMARY KEY,
  numero_antigo text NOT NULL,
  numero_novo   text NOT NULL UNIQUE,
  aplicado_em   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE backup.spec268_renumeracao_orcamentos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON backup.spec268_renumeracao_orcamentos FROM PUBLIC, anon, authenticated;

-- mesma trava do gerador (migration 321): ninguém cria orçamento com esses números enquanto isto roda
SELECT pg_advisory_xact_lock(hashtext('orcamentos_numero_orc'));

-- Ordem cronológica de TODAS as equipes juntas: o mais antigo (data e hora de criação) é ORC-0001, o seguinte ORC-0002...
-- Só entram no de/para os que mudam de número. (Ninguém muda de número por causa de empate: desempate por id.)
INSERT INTO backup.spec268_renumeracao_orcamentos (orcamento_id, numero_antigo, numero_novo)
SELECT x.id, x.numero, x.novo
FROM (
  SELECT o.id, o.numero,
         'ORC-' || lpad((row_number() OVER (ORDER BY o.created_at, o.id))::text, 4, '0') AS novo
  FROM public.orcamentos o
  WHERE o.numero ~ '^ORC-[0-9]+$'
) x
WHERE x.numero <> x.novo
ON CONFLICT (orcamento_id) DO NOTHING;

-- 1) o próprio orçamento
UPDATE public.orcamentos o
SET numero = r.numero_novo
FROM backup.spec268_renumeracao_orcamentos r
WHERE r.orcamento_id = o.id AND o.numero = r.numero_antigo;

-- 2) boletos (numero_documento = ORC-0001-P1 ...)
UPDATE public.boletos b
SET numero_documento = regexp_replace(b.numero_documento, '^' || r.numero_antigo, r.numero_novo)
FROM backup.spec268_renumeracao_orcamentos r
WHERE b.orcamento_id = r.orcamento_id
  AND b.numero_documento ~ ('^' || r.numero_antigo || '([^0-9]|$)');

-- 3) financeiro novo: título (documento/descrição) e parcelas do título
UPDATE public.financeiro_titulos t
SET documento = CASE WHEN t.documento ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)')
                     THEN regexp_replace(t.documento, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
                     ELSE t.documento END,
    descricao = CASE WHEN t.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)')
                     THEN regexp_replace(t.descricao, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
                     ELSE t.descricao END
FROM backup.spec268_renumeracao_orcamentos r
WHERE t.orcamento_id = r.orcamento_id
  AND (t.documento ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)')
    OR t.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)'));

UPDATE public.financeiro_parcelas p
SET descricao = regexp_replace(p.descricao, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
FROM public.financeiro_titulos t
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = t.orcamento_id
WHERE p.titulo_id = t.id
  AND p.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)');

-- 4) legado do projeto e negociações
UPDATE public.projeto_parcelas pp
SET descricao = regexp_replace(pp.descricao, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
FROM backup.spec268_renumeracao_orcamentos r
WHERE pp.orcamento_id = r.orcamento_id
  AND pp.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)');

UPDATE public.negociacoes n
SET observacao = regexp_replace(n.observacao, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
FROM backup.spec268_renumeracao_orcamentos r
WHERE n.orcamento_id = r.orcamento_id
  AND n.observacao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)');

-- 5) separações (Venda Parcial/Logística): só as cujos itens são DESTE orçamento (o texto sozinho é ambíguo)
UPDATE public.separacoes s
SET numero_venda = r.numero_novo,
    numero_entrega = CASE WHEN s.numero_entrega ~ ('^' || r.numero_antigo || '([^0-9]|$)')
                          THEN regexp_replace(s.numero_entrega, '^' || r.numero_antigo, r.numero_novo)
                          ELSE s.numero_entrega END
FROM backup.spec268_renumeracao_orcamentos r
WHERE s.numero_venda = r.numero_antigo
  AND EXISTS (
    SELECT 1 FROM public.separacao_itens si
    JOIN public.projeto_itens pi ON pi.id = si.projeto_item_id
    WHERE si.separacao_id = s.id AND pi.orcamento_id = r.orcamento_id);

UPDATE public.entregas_finalizadas e
SET numero_entrega = CASE WHEN e.numero_entrega ~ ('^' || r.numero_antigo || '([^0-9]|$)')
                          THEN regexp_replace(e.numero_entrega, '^' || r.numero_antigo, r.numero_novo)
                          ELSE e.numero_entrega END,
    numero_pedido = CASE WHEN e.numero_pedido ~ ('^' || r.numero_antigo || '([^0-9]|$)')
                         THEN regexp_replace(e.numero_pedido, '^' || r.numero_antigo, r.numero_novo)
                         ELSE e.numero_pedido END
FROM public.separacoes s
JOIN backup.spec268_renumeracao_orcamentos r ON r.numero_novo = s.numero_venda
WHERE e.separacao_id = s.id
  AND (e.numero_entrega ~ ('^' || r.numero_antigo || '([^0-9]|$)')
    OR e.numero_pedido  ~ ('^' || r.numero_antigo || '([^0-9]|$)'));

-- 6) histórico de estoque ligado ao item do orçamento
UPDATE public.estoque_movimentos_projeto_item m
SET observacao = regexp_replace(m.observacao, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
FROM public.projeto_itens pi
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = pi.orcamento_id
WHERE m.projeto_item_id = pi.id
  AND m.observacao ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)');

UPDATE public.devolucoes_estoque d
SET motivo = regexp_replace(d.motivo, '(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)', '\1' || r.numero_novo || '\2', 'g')
FROM public.projeto_itens pi
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = pi.orcamento_id
WHERE d.projeto_item_id = pi.id
  AND d.motivo ~ ('(^|[^0-9A-Za-z])' || r.numero_antigo || '([^0-9]|$)');

-- 7) nunca mais repetir (o gerador da migration 321 já é global; isto barra qualquer caminho que informe o número à mão)
CREATE UNIQUE INDEX IF NOT EXISTS orcamentos_numero_uidx ON public.orcamentos (numero) WHERE numero IS NOT NULL;
