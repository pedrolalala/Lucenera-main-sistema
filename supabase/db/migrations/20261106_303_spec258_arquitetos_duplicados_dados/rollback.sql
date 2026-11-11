-- SPEC-258: desfaz a migration 303 a partir dos backups backup._bkp_spec258_*.
-- Não reabre o erro da sincronização: a função sharepoint-projetos-pull continua corrigida (ver SPEC-258).
ALTER TABLE projetos DISABLE TRIGGER trg_projetos_sharepoint_push;
SELECT set_config('app.sync_em_andamento', 'on', true);

UPDATE projetos p SET arquiteto_id = b.arquiteto_id FROM backup._bkp_spec258_projetos b WHERE p.id = b.id;

DELETE FROM projeto_arquitetos pa USING backup._bkp_spec258_projeto_arquitetos_inseridos b
 WHERE pa.projeto_id = b.projeto_id AND pa.arquiteto_id = b.arquiteto_id;

ALTER TABLE projetos ENABLE TRIGGER trg_projetos_sharepoint_push;

DELETE FROM contato_tipos ct USING backup._bkp_spec258_contato_tipos_inseridos b
 WHERE ct.contato_id = b.contato_id AND ct.tipo = b.tipo;

-- primeiro quem volta a ser duplicata (o de arquiteto), depois quem volta a ser principal (índice único de CPF/CNPJ)
UPDATE contatos c SET canonical_id = b.canonical_id FROM backup._bkp_spec258_contatos b WHERE c.id = b.id AND b.canonical_id IS NOT NULL;
UPDATE contatos c SET canonical_id = NULL FROM backup._bkp_spec258_contatos b WHERE c.id = b.id AND b.canonical_id IS NULL;

-- as tabelas de backup ficam (apagar à mão depois de conferir):
-- DROP TABLE backup._bkp_spec258_contatos, backup._bkp_spec258_projetos,
--   backup._bkp_spec258_projeto_arquitetos_inseridos, backup._bkp_spec258_contato_tipos_inseridos;
