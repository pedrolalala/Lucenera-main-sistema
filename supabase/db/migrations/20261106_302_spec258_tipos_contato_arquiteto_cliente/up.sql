-- SPEC-258 (correção 1): um arquiteto pode ser cliente sem perder a identidade de arquiteto.
-- O tipo principal (`contatos.tipo` / `tipo_principal_id`) diz QUEM a pessoa é; o papel num negócio vem de onde ela está
-- ligada (projetos.cliente_id, orcamentos.cliente_id, nota fiscal...). Os tipos extras ficam em `contato_tipos`
-- (catálogo `tipos_contato`, Fases 0-1 já aplicadas em 06/11: 1 = cliente, 5 = fornecedor).
--   1. `sync_contact_type_on_budget` (gatilho de `orcamentos`) deixa de TROCAR `contatos.tipo` para 'cliente'; só acrescenta
--      'cliente' em `contato_tipos` (era ele que apagava o "arquiteto" de quem virava cliente de um orçamento).
--   2. Onde o banco exigia "tipo principal = cliente" passa a aceitar também "tem o tipo cliente em contato_tipos":
--      `vw_financeiro_projetos`, `vw_projetos_pipeline`, `showroom_emp_buscar_cliente`, `showroom_emp_criar` e a permuta de
--      `aprovar_orcamento_financeiro`. Só AMPLIA: tudo que passava antes continua passando (hoje, com 1 tipo por contato,
--      o resultado é idêntico).
-- Não muda: RLS spec069_* (continua pelo tipo principal), telas dos apps (Fase 4).

-- 1. Gatilho do orçamento: só acrescenta o tipo cliente
CREATE OR REPLACE FUNCTION public.sync_contact_type_on_budget()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- SPEC-258: não troca mais contatos.tipo (o tipo principal não muda); o contato ganha 'cliente' como tipo extra.
  IF NEW.cliente_id IS NOT NULL THEN
    INSERT INTO public.contato_tipos (contato_id, tipo)
    VALUES (NEW.cliente_id, 'cliente')
    ON CONFLICT (contato_id, tipo) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;

-- 2a. Views: o cliente do projeto aparece também quando o tipo principal dele é outro (ex.: arquiteto)
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
     LEFT JOIN contatos c ON c.id = p.cliente_id AND (c.tipo = 'cliente'::contato_tipo
          OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1))
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
     LEFT JOIN contatos c ON c.id = p.cliente_id AND (c.tipo = 'cliente'::contato_tipo
          OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE vendas.projeto_id = p.id AND vendas.historico_legado = false) v ON true
  WHERE p.arquivado = false OR p.arquivado IS NULL;

-- 2b. Funções: troca só o trecho do filtro de tipo (o resto do corpo fica exatamente como está no banco).
--     Cada troca precisa achar o trecho exatamente 1 vez, senão aborta tudo.
DO $mig$
DECLARE
  r record;
  v_def text;
  v_novo text;
  v_n int;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('public.showroom_emp_buscar_cliente(text,text,text)'::regprocedure,
       $a$WHERE c.tipo = 'cliente'$a$,
       $b$WHERE (c.tipo = 'cliente' OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1))$b$),
      ('public.showroom_emp_criar(text,text,uuid,uuid,date,text,jsonb)'::regprocedure,
       $a$AND c.tipo = 'cliente' AND c.ativo$a$,
       $b$AND (c.tipo = 'cliente' OR EXISTS (SELECT 1 FROM contato_tipos ct WHERE ct.contato_id = c.id AND ct.tipo_id = 1)) AND c.ativo$b$),
      ('public.aprovar_orcamento_financeiro(uuid)'::regprocedure,
       $a$WHERE id = v_permuta_ids[v_i] AND tipo IN ('fornecedor', 'cliente'))$a$,
       $b$WHERE id = v_permuta_ids[v_i] AND (tipo IN ('fornecedor', 'cliente') OR EXISTS (SELECT 1 FROM public.contato_tipos ct WHERE ct.contato_id = contatos.id AND ct.tipo_id IN (1, 5))))$b$)
    ) AS t(fn, antigo, novo)
  LOOP
    v_def := pg_get_functiondef(r.fn);
    v_n := (length(v_def) - length(replace(v_def, r.antigo, ''))) / length(r.antigo);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'SPEC-258: trecho esperado aparece % vez(es) em % (esperado 1). Nada foi alterado.', v_n, r.fn;
    END IF;
    v_novo := replace(v_def, r.antigo, r.novo);
    EXECUTE v_novo;
  END LOOP;
END
$mig$;
