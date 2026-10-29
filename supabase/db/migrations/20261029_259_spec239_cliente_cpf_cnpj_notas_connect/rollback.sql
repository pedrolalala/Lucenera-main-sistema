-- Rollback da 259 (SPEC-239): devolve cpf, cnpj, tipo_pessoa e IE dos clientes preenchidos pela carga.
BEGIN;
UPDATE public.contatos c
   SET cpf = b.cpf, cnpj = b.cnpj, tipo_pessoa = b.tipo_pessoa, inscricao_estadual = b.inscricao_estadual
  FROM backup._bkp_259_contatos_documento b
 WHERE b.id = c.id;
DROP TABLE backup._bkp_259_contatos_documento;
COMMIT;
