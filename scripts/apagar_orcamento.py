"""
Exclui UM orçamento (pelo número, ex.: ORC-0001) e tudo que ele gerou: itens, histórico, arquitetos,
projeto_itens (some da Necessidade de Compra, que é view), saldos/movimentos de estoque por item
(reservas), transferências, devoluções, separações do orçamento (+ itens, entregas, baixas, arquivos),
parcelas, boletos, NF e vínculo com pedido de compra. Depois devolve as reservas: estoque_itens (local
Estoque) volta a espelhar produtos (dado da Connect) — só nos produtos do orçamento.

Cadastros (cliente, projeto, produtos) NÃO são tocados.

Cada linha apagada/alterada é copiada antes para public._bkp_del_<numero>_<data>_<tabela> (RLS ligada).

Uso:
  python scripts/apagar_orcamento.py ORC-0001            # DRY-RUN (desfaz no fim)
  python scripts/apagar_orcamento.py ORC-0001 --aplicar  # grava
"""

import argparse
import sys
from datetime import date
from pathlib import Path

import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _supabase_client import SUPABASE_DB_URL, SUPABASE_URL  # noqa: E402


# conjuntos de referência (tabelas temporárias, montadas antes de apagar)
CONJUNTOS = """
create temp table x_orc on commit drop as select id from public.orcamentos where numero = %(numero)s;
create temp table x_pi on commit drop as
  select id from public.projeto_itens where orcamento_id in (select id from x_orc);
create temp table x_sep on commit drop as
  select id from public.separacoes
  -- número pode repetir com o histórico antigo de Separação: só as criadas depois do orçamento
  where (numero_venda in (select numero from public.orcamentos where id in (select id from x_orc))
         or numero_venda in (select numero_venda from public.orcamentos where id in (select id from x_orc)))
        and created_at >= (select min(created_at) from public.orcamentos where id in (select id from x_orc))
     or id in (select separacao_id from public.separacao_itens
               where projeto_item_id in (select id from x_pi));
create temp table x_prod on commit drop as
  select distinct produto_id from public.projeto_itens where id in (select id from x_pi) and produto_id is not null;
create temp table x_parc on commit drop as
  select id from public.projeto_parcelas where orcamento_id in (select id from x_orc);
"""

# (tabela, filtro) na ordem em que é apagada (filhos antes dos pais)
APAGAR = [
    ("entregas_pendentes", "separacao_id in (select id from x_sep)"),
    ("entregas_finalizadas", "separacao_id in (select id from x_sep)"),
    ("entregas", "separacao_id in (select id from x_sep)"),
    ("separacao_itens", "separacao_id in (select id from x_sep) or projeto_item_id in (select id from x_pi)"),
    ("separacao_arquivos", "separacao_id in (select id from x_sep)"),
    ("separacao_baixas", "separacao_id in (select id from x_sep)"),
    ("separacoes", "id in (select id from x_sep)"),
    ("transferencias_estoque", "origem_projeto_item_id in (select id from x_pi) or destino_projeto_item_id in (select id from x_pi)"),
    ("devolucoes_estoque", "projeto_item_id in (select id from x_pi)"),
    ("estoque_movimentos_projeto_item", "projeto_item_id in (select id from x_pi) or projeto_item_destino_id in (select id from x_pi)"),
    ("estoque_saldos_projeto_item", "projeto_item_id in (select id from x_pi)"),
    ("pedido_compra_item_origem", "projeto_item_id in (select id from x_pi)"),
    ("notas_fiscais", """orcamento_id in (select id from x_orc) or boleto_id in (select id from public.boletos
                         where orcamento_id in (select id from x_orc) or parcela_id in (select id from x_parc))"""),
    ("garantia_itens", "orcamento_id in (select id from x_orc)"),
    ("boletos", "orcamento_id in (select id from x_orc) or parcela_id in (select id from x_parc)"),
    ("projeto_parcelas", "id in (select id from x_parc)"),
    ("historico_status_orcamentos", "orcamento_id in (select id from x_orc)"),
    ("orcamento_arquitetos", "orcamento_id in (select id from x_orc)"),
    ("projeto_itens", "id in (select id from x_pi)"),
    ("orcamento_itens", "orcamento_id in (select id from x_orc)"),
    ("orcamentos", "id in (select id from x_orc)"),
]

ESTOQUE_DIVERGENTE = """
  e.produto_id in (select produto_id from x_prod) and e.local = 'Estoque' and (
        e.quantidade <> coalesce(p.estoque_total, 0)
     or e.quantidade_reservada <> coalesce(p.estoque_total, 0) - coalesce(p.estoque_disponivel, 0)
     or e.quantidade_disponivel is distinct from coalesce(p.estoque_disponivel, 0))
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("numero", help="número do orçamento, ex.: ORC-0001")
    ap.add_argument("--aplicar", action="store_true", help="grava (sem isso é dry-run)")
    args = ap.parse_args()
    aplicar, numero = args.aplicar, args.numero
    bkp = "_bkp_del_" + numero.lower().replace("-", "") + "_" + date.today().strftime("%Y%m%d") + "_"
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (nada gravado)'}\n")

    c = psycopg2.connect(SUPABASE_DB_URL, connect_timeout=30)  # já vem trocado para o pooler
    k = c.cursor()
    k.execute("set local statement_timeout = '5min'")
    k.execute(CONJUNTOS, {"numero": numero})
    k.execute("select numero, numero_venda, status, valor_total from public.orcamentos where id in (select id from x_orc)")
    orc = k.fetchone()
    if not orc:
        sys.exit(f"orçamento {numero} não encontrado")
    print("orçamento:", orc)
    for t in ("x_orc", "x_pi", "x_sep", "x_parc", "x_prod"):
        k.execute(f"select count(*) from {t}")
        print(f"{t:8} {k.fetchone()[0]}")
    print()

    # os 2 triggers de orcamento_itens reabrem/bloqueiam orçamento ao mexer nos itens —
    # aqui o orçamento inteiro está saindo (ALTER TABLE ... DISABLE é transacional)
    k.execute("alter table public.orcamento_itens disable trigger trg_0_proteger_vinculo_connect")
    k.execute("alter table public.orcamento_itens disable trigger trg_orcamento_item_change_reset")
    # referências cruzadas orcamento_itens <-> projeto_itens (as duas saem)
    k.execute("""update public.orcamento_itens set projeto_item_origem_id = null
                 where projeto_item_origem_id in (select id from x_pi)""")
    k.execute("""update public.orcamento_itens set item_pai_id = null
                 where orcamento_id in (select id from x_orc) and item_pai_id is not null""")

    total = 0
    for tab, filtro in APAGAR:
        b = bkp + tab
        k.execute(f"drop table if exists public.{b}")
        k.execute(f"create table public.{b} as select * from public.{tab} where {filtro}")
        k.execute(f"alter table public.{b} enable row level security")
        k.execute(f"delete from public.{tab} where {filtro}")
        n = k.rowcount
        total += n
        print(f"apagado  {tab:34} {n:5}")
    k.execute("alter table public.orcamento_itens enable trigger trg_0_proteger_vinculo_connect")
    k.execute("alter table public.orcamento_itens enable trigger trg_orcamento_item_change_reset")

    # devolve as reservas: estoque_itens volta a espelhar produtos (dado da Connect)
    b = bkp + "estoque_itens"
    k.execute(f"drop table if exists public.{b}")
    k.execute(f"""create table public.{b} as select e.* from public.estoque_itens e
                  join public.produtos p on p.id = e.produto_id where {ESTOQUE_DIVERGENTE}""")
    k.execute(f"alter table public.{b} enable row level security")
    k.execute(f"""update public.estoque_itens e
                  set quantidade = coalesce(p.estoque_total, 0),
                      quantidade_disponivel = coalesce(p.estoque_disponivel, 0),
                      quantidade_reservada = coalesce(p.estoque_total, 0) - coalesce(p.estoque_disponivel, 0),
                      atualizado_em = now()
                  from public.produtos p where p.id = e.produto_id and {ESTOQUE_DIVERGENTE}""")
    print(f"\nestoque_itens corrigidos (reserva devolvida): {k.rowcount}")
    print(f"linhas apagadas no total: {total}")

    # conferência dentro da transação
    k.execute(f"""select count(*) from public.estoque_itens e join public.produtos p on p.id = e.produto_id
                  where {ESTOQUE_DIVERGENTE}""")
    print("estoque_itens ainda diferente de produtos:", k.fetchone()[0])
    for t in ("orcamentos", "projeto_itens", "estoque_saldos_projeto_item", "estoque_movimentos_projeto_item"):
        k.execute(f"select count(*) from public.{t}")
        print(f"restante {t:34} {k.fetchone()[0]}")
    k.execute("select count(*) from public.separacoes")
    print(f"restante {'separacoes':34} {k.fetchone()[0]}")

    if aplicar:
        c.commit()
        print("\nGRAVADO.")
    else:
        c.rollback()
        print("\nDRY-RUN: desfeito, nada gravado.")
    c.close()


if __name__ == "__main__":
    main()
