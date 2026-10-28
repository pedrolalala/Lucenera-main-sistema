-- Rollback da 256 (SPEC-236).
BEGIN;
UPDATE public.contatos
   SET endereco_entrega = NULL, numero_entrega = NULL, complemento_entrega = NULL, bairro_entrega = NULL,
       cidade_entrega = NULL, estado_entrega = NULL, cep_entrega = NULL
 WHERE tipo = 'fornecedor'
   AND nome IN ('MANOELLA ZAUITH LEITE LOPES', 'ISLIGHT COMERCIO E SERVICOS DE ILUMINACAO LTDA')
   AND endereco_entrega = 'Rua Ayrton Roxo' AND numero_entrega = '867';
DROP TABLE IF EXISTS public.compras_config;
UPDATE public.empresas SET razao_social = 'FOCO ILUMINACAO EIRELI – ME' WHERE nome = 'FOCO ILUMINACAO';
COMMIT;
