-- SPEC-249 chamado 1: a vendedora Moara (nm_connect = MOARA, equipe Thairine, saiu da empresa) estava SEM equipe no cadastro e a carga da Connect
-- jogou as 26 vendas dela em "Administração"; as projetistas da equipe Thairine não as enxergam (RLS por equipe, SPEC-200).
-- Ajuste de DADO (não mexe em estoque, financeiro, itens nem saldos): define a equipe da Moara = Thairine e move os orçamentos dela da
-- Connect que estão em Administração para a Thairine (e as linhas de Reserva × Ambiente desses orçamentos, para a recarga não desfazer).
-- Backup do "antes" no schema backup (rollback.sql restaura).
DO $$
DECLARE
    v_thairine uuid := 'e4294fd5-0c68-4686-af8a-f2e76d2db2cd';
    v_admin    uuid := '269e8071-92f0-461f-a3c7-d949cacdd7a9';
    v_moara    uuid;
    n_orc int; n_res int; n_func int;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.equipes_projetos WHERE id = v_thairine AND equipes = 'Thairine') THEN
        RAISE EXCEPTION 'Equipe Thairine não encontrada com o id esperado.';
    END IF;
    SELECT id INTO v_moara FROM public.funcionarios WHERE nm_connect = 'MOARA';
    IF v_moara IS NULL THEN RAISE EXCEPTION 'Funcionária MOARA não encontrada.'; END IF;

    CREATE SCHEMA IF NOT EXISTS backup;
    CREATE TABLE backup.spec249_moara_funcionario AS
        SELECT id, equipe_id FROM public.funcionarios WHERE id = v_moara;
    CREATE TABLE backup.spec249_moara_orcamentos AS
        SELECT id, equipe_id FROM public.orcamentos
        WHERE origem = 'connect' AND vendedor_id = v_moara AND equipe_id = v_admin;
    CREATE TABLE backup.spec249_moara_reserva AS
        SELECT id, equipe_id FROM public.connect_reserva_ambiente
        WHERE equipe_id = v_admin AND orcamento_id IN (SELECT id FROM backup.spec249_moara_orcamentos);
    REVOKE ALL ON backup.spec249_moara_funcionario, backup.spec249_moara_orcamentos, backup.spec249_moara_reserva FROM PUBLIC, anon, authenticated;

    UPDATE public.funcionarios SET equipe_id = v_thairine WHERE id = v_moara AND equipe_id IS NULL;
    GET DIAGNOSTICS n_func = ROW_COUNT;

    UPDATE public.orcamentos SET equipe_id = v_thairine WHERE id IN (SELECT id FROM backup.spec249_moara_orcamentos);
    GET DIAGNOSTICS n_orc = ROW_COUNT;

    UPDATE public.connect_reserva_ambiente SET equipe_id = v_thairine WHERE id IN (SELECT id FROM backup.spec249_moara_reserva);
    GET DIAGNOSTICS n_res = ROW_COUNT;

    IF n_func <> 1 OR n_orc <> (SELECT count(*) FROM backup.spec249_moara_orcamentos) OR n_res <> (SELECT count(*) FROM backup.spec249_moara_reserva) THEN
        RAISE EXCEPTION 'Contagem inesperada (funcionario %, orcamentos %, reserva %): ajuste desfeito.', n_func, n_orc, n_res;
    END IF;
    RAISE NOTICE 'Moara: funcionario %, orcamentos %, linhas de reserva %', n_func, n_orc, n_res;
END $$;
