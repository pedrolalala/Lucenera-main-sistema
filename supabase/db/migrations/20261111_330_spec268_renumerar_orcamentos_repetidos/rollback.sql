-- SPEC-268: desfaz a renumeração (usa o de/para guardado em backup.spec268_renumeracao_orcamentos).
-- O de/para é mantido (histórico); só os números e os textos voltam. Sem BEGIN/COMMIT de propósito.
DROP INDEX IF EXISTS public.orcamentos_numero_uidx;

UPDATE public.estoque_movimentos_projeto_item m
SET observacao = regexp_replace(m.observacao, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
FROM public.projeto_itens pi
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = pi.orcamento_id
WHERE m.projeto_item_id = pi.id AND m.observacao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)');

UPDATE public.devolucoes_estoque d
SET motivo = regexp_replace(d.motivo, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
FROM public.projeto_itens pi
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = pi.orcamento_id
WHERE d.projeto_item_id = pi.id AND d.motivo ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)');

UPDATE public.entregas_finalizadas e
SET numero_entrega = CASE WHEN e.numero_entrega ~ ('^' || r.numero_novo || '([^0-9]|$)')
                          THEN regexp_replace(e.numero_entrega, '^' || r.numero_novo, r.numero_antigo) ELSE e.numero_entrega END,
    numero_pedido = CASE WHEN e.numero_pedido ~ ('^' || r.numero_novo || '([^0-9]|$)')
                         THEN regexp_replace(e.numero_pedido, '^' || r.numero_novo, r.numero_antigo) ELSE e.numero_pedido END
FROM public.separacoes s
JOIN backup.spec268_renumeracao_orcamentos r ON r.numero_novo = s.numero_venda
WHERE e.separacao_id = s.id
  AND (e.numero_entrega ~ ('^' || r.numero_novo || '([^0-9]|$)') OR e.numero_pedido ~ ('^' || r.numero_novo || '([^0-9]|$)'));

UPDATE public.separacoes s
SET numero_venda = r.numero_antigo,
    numero_entrega = CASE WHEN s.numero_entrega ~ ('^' || r.numero_novo || '([^0-9]|$)')
                          THEN regexp_replace(s.numero_entrega, '^' || r.numero_novo, r.numero_antigo) ELSE s.numero_entrega END
FROM backup.spec268_renumeracao_orcamentos r
WHERE s.numero_venda = r.numero_novo
  AND EXISTS (SELECT 1 FROM public.separacao_itens si JOIN public.projeto_itens pi ON pi.id = si.projeto_item_id
              WHERE si.separacao_id = s.id AND pi.orcamento_id = r.orcamento_id);

UPDATE public.negociacoes n
SET observacao = regexp_replace(n.observacao, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
FROM backup.spec268_renumeracao_orcamentos r
WHERE n.orcamento_id = r.orcamento_id AND n.observacao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)');

UPDATE public.projeto_parcelas pp
SET descricao = regexp_replace(pp.descricao, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
FROM backup.spec268_renumeracao_orcamentos r
WHERE pp.orcamento_id = r.orcamento_id AND pp.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)');

UPDATE public.financeiro_parcelas p
SET descricao = regexp_replace(p.descricao, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
FROM public.financeiro_titulos t
JOIN backup.spec268_renumeracao_orcamentos r ON r.orcamento_id = t.orcamento_id
WHERE p.titulo_id = t.id AND p.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)');

UPDATE public.financeiro_titulos t
SET documento = CASE WHEN t.documento ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)')
                     THEN regexp_replace(t.documento, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
                     ELSE t.documento END,
    descricao = CASE WHEN t.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)')
                     THEN regexp_replace(t.descricao, '(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)', '\1' || r.numero_antigo || '\2', 'g')
                     ELSE t.descricao END
FROM backup.spec268_renumeracao_orcamentos r
WHERE t.orcamento_id = r.orcamento_id
  AND (t.documento ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)')
    OR t.descricao ~ ('(^|[^0-9A-Za-z])' || r.numero_novo || '([^0-9]|$)'));

UPDATE public.boletos b
SET numero_documento = regexp_replace(b.numero_documento, '^' || r.numero_novo, r.numero_antigo)
FROM backup.spec268_renumeracao_orcamentos r
WHERE b.orcamento_id = r.orcamento_id AND b.numero_documento ~ ('^' || r.numero_novo || '([^0-9]|$)');

UPDATE public.orcamentos o
SET numero = r.numero_antigo
FROM backup.spec268_renumeracao_orcamentos r
WHERE r.orcamento_id = o.id AND o.numero = r.numero_novo;
