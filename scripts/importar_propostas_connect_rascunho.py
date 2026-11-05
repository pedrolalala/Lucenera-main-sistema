"""
SPEC-243 — Importa como RASCUNHO as propostas da Connect que NÃO viraram venda (XML fora da herança).

Critério (tudo no espelho `connect_xml_orcamento` / `connect_xml_item`, carregado por importar_xml_orcamentos_connect.py):
  * o orçamento NÃO está na herança (não tem linha em connect_reserva_ambiente) e ainda não existe no sistema;
  * TODOS os itens têm saida = 0 e quantidade positiva, sem marca de devolução/troca/haver/defeito (uma venda tem saida = -1; documento de
    devolução tem total negativo);
  * total do XML > 0, empresa achada pelo CNPJ do XML e cliente achado pelo código da Connect (codigo_legado).
Fica de fora, por regra: vendas já entregues (saida = -1), devoluções (total negativo) e orçamentos mistos (parte vendida, parte não).

O que cria: um orçamento `status = 'rascunho'`, número `CNX-<orçamento da Connect>`, origem_connect_cod_orcamento, cliente, empresa, data e total do XML
(desconto geral = soma dos itens − total), equipe Administração, SEM projeto e SEM digitador (o XML não traz), e os itens (orcamento_itens, L em custom_id).
NÃO cria projeto_itens, saldos, reserva, estoque, venda, parcelas nem boletos: a função confere antes×depois e se desfaz se qualquer um mudar.

Uso:
  python scripts/importar_propostas_connect_rascunho.py            # DRY-RUN: roda tudo numa transação e DESFAZ
  python scripts/importar_propostas_connect_rascunho.py --aplicar  # grava
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402

TRIGGERS = ("trg_orcamento_workflow", "trg_sync_contact_type_on_budget", "trg_1_orcamento_equipe_digitador")

FOTO = """
SELECT concat_ws('|',
  (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
  (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.projeto_parcelas), (SELECT count(*) FROM public.boletos),
  (SELECT count(*) FROM public.vendas), (SELECT count(*) FROM public.projetos WHERE valor_total IS NOT NULL AND valor_total <> 0),
  (SELECT count(*) || '/' || coalesce(sum(quantidade),0) FROM public.projeto_itens),
  (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_entregue),0) || '/' || coalesce(sum(q_devolvida),0) FROM public.estoque_saldos_projeto_item),
  (SELECT count(*) FROM public.orcamentos WHERE status <> 'rascunho'),
  (SELECT count(*) FROM public.connect_reserva_tratamento))
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()

    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute(FOTO)
        antes = cur.fetchone()[0]

        cur.execute("SELECT id FROM public.equipes_projetos WHERE equipes ILIKE 'Administra%' ORDER BY equipes LIMIT 1")
        row = cur.fetchone()
        equipe_id = row[0] if row else None

        cur.execute(
            r"""
            CREATE TEMP TABLE _p_cand AS
            SELECT x.cod_orcamento AS cod, x.vl_total_orcamento AS total, x.dt_orcamento AS dt, x.cod_cliente, x.cnpj_empresa,
                   (SELECT e.id FROM public.empresas e WHERE regexp_replace(coalesce(e.cnpj,''),'\D','','g') = regexp_replace(coalesce(x.cnpj_empresa,''),'\D','','g') LIMIT 1) AS empresa_id,
                   (SELECT c.id FROM public.contatos c WHERE c.codigo_legado::text = x.cod_cliente::text ORDER BY c.created_at LIMIT 1) AS cliente_id
              FROM public.connect_xml_orcamento x
             WHERE x.vl_total_orcamento > 0
               AND NOT EXISTS (SELECT 1 FROM public.orcamentos o WHERE o.origem_connect_cod_orcamento = x.cod_orcamento OR o.numero = 'CNX-' || x.cod_orcamento)
               AND NOT EXISTS (SELECT 1 FROM public.connect_reserva_ambiente r WHERE r.cod_orcamento_connect = x.cod_orcamento)
               AND EXISTS (SELECT 1 FROM public.connect_xml_item i WHERE i.cod_orcamento = x.cod_orcamento)
               AND NOT EXISTS (SELECT 1 FROM public.connect_xml_item i WHERE i.cod_orcamento = x.cod_orcamento
                                  AND (coalesce(i.saida,0) <> 0 OR i.qtd_produto <= 0 OR coalesce(i.dev_troca,0) <> 0
                                       OR coalesce(i.dev_haver,0) <> 0 OR coalesce(i.dev_defeito,0) <> 0))
            """
        )
        cur.execute("SELECT count(*), count(*) FILTER (WHERE empresa_id IS NULL), count(*) FILTER (WHERE cliente_id IS NULL) FROM _p_cand")
        n, sem_emp, sem_cli = cur.fetchone()
        print(f"Propostas candidatas (saida=0, total>0, fora da herança): {n} | sem empresa: {sem_emp} | sem cliente: {sem_cli}")
        cur.execute("CREATE TEMP TABLE _p_ok AS SELECT * FROM _p_cand WHERE empresa_id IS NOT NULL AND cliente_id IS NOT NULL")

        for t in TRIGGERS:
            cur.execute(f"ALTER TABLE public.orcamentos DISABLE TRIGGER {t}")
        cur.execute("SELECT set_config('app.skip_approval_reset', 'true', true)")

        cur.execute(
            """
            INSERT INTO public.orcamentos (id, empresa_id, cliente_id, status, numero, valor_total, observacoes,
                                           origem_connect_cod_orcamento, data_emissao, equipe_id, desconto_tipo, desconto_global)
            SELECT gen_random_uuid(), empresa_id, cliente_id, 'rascunho', 'CNX-' || cod, total,
                   'Proposta da Connect (SPEC-243): não virou venda na Connect. Rascunho sem projeto; o XML não traz projeto nem digitador.',
                   cod, dt::timestamptz, %s, 'valor', 0
              FROM _p_ok
            """,
            (equipe_id,),
        )
        inseridos = cur.rowcount

        cur.execute(
            """
            INSERT INTO public.orcamento_itens (orcamento_id, produto_id, quantidade, preco_unitario, desconto, descricao, ordem, custom_id)
            SELECT o.id, p.id, g.q, round(g.t / g.q, 3), 0, coalesce(nullif(btrim(g.d), ''), 'Item sem descrição'),
                   (row_number() OVER (PARTITION BY g.cod ORDER BY g.l NULLS LAST, g.cod_produto))::integer, g.l
              FROM (SELECT cod_orcamento AS cod, nullif(btrim(coalesce(desc_classificacao,'')),'') AS l, cod_produto,
                           sum(qtd_produto) AS q, sum(vl_total_produto) AS t, (array_agg(desc_produto ORDER BY linha))[1] AS d
                      FROM public.connect_xml_item WHERE cod_orcamento IN (SELECT cod FROM _p_ok) GROUP BY 1, 2, 3) g
              JOIN public.orcamentos o ON o.numero = 'CNX-' || g.cod
              LEFT JOIN public.produtos p ON p.codigo_produto = g.cod_produto
            """
        )
        itens = cur.rowcount
        cur.execute(
            """
            UPDATE public.orcamentos o
               SET desconto_global = greatest(0, round((SELECT coalesce(sum(oi.quantidade * oi.preco_unitario), 0)
                                                          FROM public.orcamento_itens oi WHERE oi.orcamento_id = o.id) - o.valor_total, 2))
             WHERE o.numero IN (SELECT 'CNX-' || cod FROM _p_ok)
            """
        )

        for t in TRIGGERS:
            cur.execute(f"ALTER TABLE public.orcamentos ENABLE TRIGGER {t}")
        cur.execute("SELECT set_config('app.skip_approval_reset', 'false', true)")

        cur.execute(FOTO)
        depois = cur.fetchone()[0]
        partes_a, partes_d = antes.split("|"), depois.split("|")
        # só o nº de orçamentos fora de rascunho, e tudo o resto, não podem mudar
        igual = partes_a == partes_d
        print(f"Orçamentos rascunho inseridos: {inseridos} | itens: {itens}")
        print("Fotografia antes :", antes)
        print("Fotografia depois:", depois)
        print("Operacional (estoque, saldos, financeiro, vendas, projeto_itens, tratamentos) IGUAL:", "SIM" if igual else "NÃO")

        cur.execute(
            """
            SELECT o.numero, o.status, o.origem, o.equipe_id IS NOT NULL, o.data_emissao::date, o.valor_total, o.desconto_global,
                   (SELECT count(*) FROM public.orcamento_itens i WHERE i.orcamento_id = o.id),
                   (SELECT count(*) FROM public.orcamento_itens i WHERE i.orcamento_id = o.id AND i.produto_id IS NULL),
                   (SELECT round(sum(i.quantidade * i.preco_unitario), 2) FROM public.orcamento_itens i WHERE i.orcamento_id = o.id)
              FROM public.orcamentos o WHERE o.numero IN (SELECT 'CNX-' || cod FROM _p_ok) ORDER BY o.numero
            """
        )
        linhas = cur.fetchall()
        for r in linhas:
            print("  ", r)
        cur.execute(
            "SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'public.orcamentos'::regclass AND tgname = ANY(%s)", (list(TRIGGERS),)
        )
        habil = cur.fetchall()
        print("Triggers religados:", habil)

        ok = igual and inseridos == n - sem_emp - sem_cli and all(h[1] == "O" for h in habil) and all(r[1] == "rascunho" and r[2] == "sistema" for r in linhas)
        if not ok:
            print("ABORTADO: uma conferência falhou; nada foi gravado.")
            con.rollback()
            sys.exit(1)
        if args.aplicar:
            con.commit()
            print("GRAVADO.")
        else:
            con.rollback()
            print("DRY-RUN: tudo desfeito, nada foi gravado.")
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
