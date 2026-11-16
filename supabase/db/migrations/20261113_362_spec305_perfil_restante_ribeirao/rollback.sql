BEGIN;
UPDATE public.financeiro_titulos t SET perfil = NULL FROM backup._bkp_spec305_perfil_restante b WHERE b.tabela = 'titulo' AND b.id = t.id::text;
UPDATE public.boletos t SET perfil = NULL FROM backup._bkp_spec305_perfil_restante b WHERE b.tabela = 'boleto' AND b.id = t.id::text;
COMMIT;
-- depois de conferir: DROP TABLE backup._bkp_spec305_perfil_restante;
