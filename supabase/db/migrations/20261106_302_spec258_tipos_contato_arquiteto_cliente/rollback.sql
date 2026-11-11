-- SPEC-258 (correção 1): desfaz a migration 302 — volta o gatilho, as views e as 3 funções ao que eram.
-- Não remove linhas de contato_tipos criadas enquanto a 302 esteve no ar (são só tipos extras; não atrapalham o comportamento antigo).

CREATE OR REPLACE FUNCTION public.sync_contact_type_on_budget()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.cliente_id IS NOT NULL THEN
    -- Update the tipo column on contatos to 'cliente'
    UPDATE public.contatos
    SET tipo = 'cliente'
    WHERE id = NEW.cliente_id
      AND tipo IS DISTINCT FROM 'cliente'::public.contato_tipo;

    -- Also ensure the contato_tipos junction table has the 'cliente' entry
    INSERT INTO public.contato_tipos (contato_id, tipo)
    VALUES (NEW.cliente_id, 'cliente')
    ON CONFLICT (contato_id, tipo) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE VIEW public.vw_financeiro_projetos AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.cliente_id,
    c.nome AS cliente_nome,
    v.valor_total,
    v.valor_recebido,
    v.valor_pendente,
    v.total_parcelas,
    v.parcelas_pagas,
    v.parcelas_pendentes
   FROM projetos p
     LEFT JOIN contatos c ON c.id = p.cliente_id AND c.tipo = 'cliente'::contato_tipo
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total,
            sum(
                CASE
                    WHEN vendas.status_pagamento = 'Pago'::status_pagamento THEN vendas.valor_total
                    ELSE 0::numeric
                END) AS valor_recebido,
            sum(
                CASE
                    WHEN vendas.status_pagamento <> 'Pago'::status_pagamento THEN vendas.valor_total
                    ELSE 0::numeric
                END) AS valor_pendente,
            count(*) AS total_parcelas,
            count(*) FILTER (WHERE vendas.status_pagamento = 'Pago'::status_pagamento) AS parcelas_pagas,
            count(*) FILTER (WHERE vendas.status_pagamento <> 'Pago'::status_pagamento) AS parcelas_pendentes
           FROM vendas
          WHERE vendas.projeto_id = p.id AND vendas.historico_legado = false) v ON true;

CREATE OR REPLACE VIEW public.vw_projetos_pipeline AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.data_entrada,
    p.area_do_projeto ->> 'tipo'::text AS tipo_projeto,
    p.cliente_id,
    c.nome AS cliente_nome,
    COALESCE(v.valor_total, 0::numeric) AS valor_total
   FROM projetos p
     LEFT JOIN contatos c ON c.id = p.cliente_id AND c.tipo = 'cliente'::contato_tipo
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE vendas.projeto_id = p.id AND vendas.historico_legado = false) v ON true
  WHERE p.arquivado = false OR p.arquivado IS NULL;

DO $rb$
DECLARE
  r record;
  v_def text;
  v_n int;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('public.showroom_emp_buscar_cliente(text,text,text)'::regprocedure,
       $b$WHERE (c.tipo = 'cliente' OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1))$b$,
       $a$WHERE c.tipo = 'cliente'$a$),
      ('public.showroom_emp_criar(text,text,uuid,uuid,date,text,jsonb)'::regprocedure,
       $b$AND (c.tipo = 'cliente' OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1)) AND c.ativo$b$,
       $a$AND c.tipo = 'cliente' AND c.ativo$a$),
      ('public.aprovar_orcamento_financeiro(uuid)'::regprocedure,
       $b$WHERE id = v_permuta_ids[v_i] AND (tipo IN ('fornecedor', 'cliente') OR EXISTS (SELECT 1 FROM public.contato_tipos ct WHERE ct.contato_id = contatos.id AND ct.tipo_id IN (1, 5))))$b$,
       $a$WHERE id = v_permuta_ids[v_i] AND tipo IN ('fornecedor', 'cliente'))$a$)
    ) AS t(fn, atual, original)
  LOOP
    v_def := pg_get_functiondef(r.fn);
    v_n := (length(v_def) - length(replace(v_def, r.atual, ''))) / length(r.atual);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'rollback SPEC-258: trecho aparece % vez(es) em %', v_n, r.fn;
    END IF;
    EXECUTE replace(v_def, r.atual, r.original);
  END LOOP;
END
$rb$;
