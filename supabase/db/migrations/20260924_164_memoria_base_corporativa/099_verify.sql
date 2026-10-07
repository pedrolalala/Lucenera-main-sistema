-- SPEC-164 — verificação pós-aplicação (somente leitura).

-- 1. Contagem por tipo/categoria. Esperado: 54 itens
--    (31 knowledge_items + 17 marcas + 4 cadastros institucionais + 2 fontes).
SELECT categoria, tipo, status, count(*) FROM memoria.kb_itens GROUP BY 1, 2, 3 ORDER BY 1, 2;

-- 2. Nenhuma linha antiga sem cópia (deve retornar 0 linhas).
SELECT 'knowledge_items' t, k.id FROM memoria.knowledge_items k
 WHERE k.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.legado_id = k.id)
UNION ALL
SELECT 'entities', e.id FROM memoria.entities e
 WHERE e.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.legado_id = e.id)
UNION ALL
SELECT 'sources', s.id FROM memoria.sources s
 WHERE NOT EXISTS (SELECT 1 FROM memoria.kb_itens i WHERE i.legado_id = s.id);

-- 3. Tabelas antigas intactas.
SELECT (SELECT count(*) FROM memoria.knowledge_items) ki, (SELECT count(*) FROM memoria.entities) ent,
       (SELECT count(*) FROM memoria.sources) src;

-- 4. Busca com sinônimo (rodar como authenticated, ver 03-Projeto SPEC-164 §Testes).
SELECT titulo, relevancia FROM memoria.kb_buscar('downlight') LIMIT 5;
SELECT titulo, relevancia FROM memoria.kb_buscar('fidelidade cromatica') LIMIT 5;
SELECT * FROM memoria.kb_sugerir('fit');
