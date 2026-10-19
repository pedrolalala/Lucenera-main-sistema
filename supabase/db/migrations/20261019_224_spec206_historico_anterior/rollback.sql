-- Desfaz a 224: apaga só os eventos importados (os gravados pelos gatilhos ficam).
BEGIN;
DELETE FROM auditoria.eventos WHERE navegador LIKE 'Histórico importado%';
COMMIT;
