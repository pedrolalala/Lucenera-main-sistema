-- SPEC-324: desfaz as tabelas e funcoes da importacao da folha. So rode se NENHUMA importacao foi gerada
-- (os titulos do Contas a Pagar ja criados nao sao apagados; ficariam sem a ligacao com a folha).
BEGIN;
DROP FUNCTION IF EXISTS public.folha_importar_detalhe(uuid);
DROP FUNCTION IF EXISTS public.folha_importar_listar(int);
DROP FUNCTION IF EXISTS public.folha_importar_cancelar(uuid, text);
DROP FUNCTION IF EXISTS public.folha_importar_gerar_titulos(uuid, jsonb, date);
DROP FUNCTION IF EXISTS public.folha_importar_excluir_holerite(uuid, text);
DROP FUNCTION IF EXISTS public.folha_importar_vincular(uuid, uuid);
DROP FUNCTION IF EXISTS public.folha_importar_conferir(jsonb);
DROP FUNCTION IF EXISTS public.folha_guias_dos_totais(jsonb);
DROP FUNCTION IF EXISTS public.folha_digitos(text);
DROP FUNCTION IF EXISTS public.folha_exige_rh();
DROP TABLE IF EXISTS public.folha_guias;
DROP TABLE IF EXISTS public.folha_holerites;
DROP TABLE IF EXISTS public.folha_importacoes;
COMMIT;
