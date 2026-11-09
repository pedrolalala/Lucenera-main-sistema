-- SPEC-267: liberação MANUAL de item da Connect para a Equipe de projetos pedir a separação (vendas 4907 e 4908, 09/11/2026).
-- A regra da SPEC-244 só libera item da Connect "sem data de entrega" ou que já recebeu peça (NF/transferência). Esta migration
-- acrescenta uma 3ª via, registrada e reversível: o Matheus/administração marca o item como liberado, com motivo.
-- NÃO mexe em estoque, saldos, reserva, financeiro nem na herança: só decide se o item pode ser separado (Reserva -> Ag. separar).
-- Sem BEGIN/COMMIT de propósito (o dry_run.sql abre a transação e termina em ROLLBACK; para aplicar, usar a transação do script de aplicação).

CREATE TABLE IF NOT EXISTS public.connect_item_liberacao_manual (
    projeto_item_id uuid PRIMARY KEY REFERENCES public.projeto_itens(id) ON DELETE CASCADE,
    cod_venda_connect integer,
    produto_codigo integer,
    motivo text NOT NULL CHECK (length(btrim(motivo)) > 0),
    liberado_por uuid NOT NULL DEFAULT auth.uid(),
    liberado_em timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.connect_item_liberacao_manual ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connect_item_liberacao_manual FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.connect_item_liberacao_manual TO authenticated;
-- leitura: quem usa a Venda Parcial; gravação só pela função abaixo
DROP POLICY IF EXISTS cilm_leitura ON public.connect_item_liberacao_manual;
CREATE POLICY cilm_leitura ON public.connect_item_liberacao_manual FOR SELECT TO authenticated
    USING ((SELECT public.pode_acessar_sistema('separacao-parcial')));

-- a regra de "liberado" ganha a 3ª via (as outras duas ficam IGUAIS à migration 300)
CREATE OR REPLACE FUNCTION public.connect_item_liberado(p_projeto_item_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id AND o.origem = 'connect'
     WHERE pi.id = p_projeto_item_id
       AND (EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r
                     WHERE r.projeto_item_id = pi.id AND r.tipo = 'reserva' AND r.aviso_data)
            OR EXISTS (SELECT 1 FROM public.estoque_movimentos_projeto_item m
                        WHERE m.projeto_item_id = pi.id AND m.tipo IN ('recebimento_para_reserva', 'transferencia_entrada'))
            OR EXISTS (SELECT 1 FROM public.connect_item_liberacao_manual l WHERE l.projeto_item_id = pi.id)));
$function$;

-- libera TODOS os itens de Reserva das vendas Connect informadas. p_aplicar=false só mostra o que faria.
CREATE OR REPLACE FUNCTION public.liberar_vendas_connect(p_vendas integer[], p_motivo text, p_aplicar boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_itens jsonb;
    v_n integer;
BEGIN
    IF NOT coalesce(public.pode_tratar_heranca_connect(), false) THEN
        RAISE EXCEPTION 'Só o Matheus ou um administrador pode liberar item da Connect.' USING ERRCODE = '42501';
    END IF;
    IF p_vendas IS NULL OR cardinality(p_vendas) = 0 THEN
        RAISE EXCEPTION 'Informe ao menos uma venda.' USING ERRCODE = 'P0001';
    END IF;
    IF p_aplicar AND nullif(btrim(coalesce(p_motivo, '')), '') IS NULL THEN
        RAISE EXCEPTION 'Informe o motivo da liberação.' USING ERRCODE = 'P0001';
    END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object('venda', x.cod_venda_connect, 'codigo', x.produto_codigo,
                 'quantidade', x.qtd, 'ja_liberado', x.lib)), '[]'::jsonb), count(*)
      INTO v_itens, v_n
      FROM (SELECT r.cod_venda_connect, r.produto_codigo, sum(r.quantidade) AS qtd, r.projeto_item_id,
                   public.connect_item_liberado(r.projeto_item_id) AS lib
              FROM public.connect_reserva_ambiente r
             WHERE r.tipo = 'reserva' AND r.cod_venda_connect = ANY (p_vendas) AND r.projeto_item_id IS NOT NULL
             GROUP BY r.cod_venda_connect, r.produto_codigo, r.projeto_item_id) x;

    IF v_n = 0 THEN
        RAISE EXCEPTION 'Nenhum item de Reserva ligado a item de projeto nas vendas informadas.' USING ERRCODE = 'P0001';
    END IF;

    IF p_aplicar THEN
        INSERT INTO public.connect_item_liberacao_manual (projeto_item_id, cod_venda_connect, produto_codigo, motivo, liberado_por)
        SELECT DISTINCT ON (r.projeto_item_id) r.projeto_item_id, r.cod_venda_connect, r.produto_codigo, btrim(p_motivo), auth.uid()
          FROM public.connect_reserva_ambiente r
         WHERE r.tipo = 'reserva' AND r.cod_venda_connect = ANY (p_vendas) AND r.projeto_item_id IS NOT NULL
        ON CONFLICT (projeto_item_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object('aplicado', p_aplicar, 'itens', v_itens);
END;
$$;
REVOKE ALL ON FUNCTION public.liberar_vendas_connect(integer[], text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.liberar_vendas_connect(integer[], text, boolean) TO authenticated;
