"""
Limpeza dos dados de TESTE de Orçamento e Separação Parcial (14/10/2026), antes de o sistema
começar a rodar em paralelo com a Connect.

Decisões do usuário (14/10):
  - TODO orçamento existente no sistema é teste — inclusive ORC-0038/ORC-0039, importados do
    XML da Connect — e é EXCLUÍDO de vez (não só cancelado).
  - Separações de fev–jun/2026 (histórico real do sistema antigo de Separação) ficam.
    Só saem as criadas a partir de 01/07/2026 (Separação Parcial, todas de orçamentos de teste).
  - Cadastros (clientes, produtos, projetos, RH), financeiro importado da Connect e Compras
    NÃO são tocados.

O que apaga (numa transação só): orçamentos + itens + histórico + arquitetos, projeto_itens,
saldos/movimentos de estoque por item, transferências, devoluções, separações de teste
(+ itens, entregas, entregas pendentes/finalizadas), parcelas e boletos dos orçamentos,
vínculo com pedido de compra. Depois devolve as reservas: estoque_itens (local Estoque)
volta a ser exatamente o que está em produtos (quantidade = estoque_total,
reservada = total − disponível), como faz o trigger fn_sync_estoque_itens_from_produtos.

Cada linha apagada/alterada é copiada antes para backup._bkp_limpeza_20261014_<tabela>
(RLS ligada, sem policy = invisível pelo app) para auditoria e para desfazer.

Uso:
  python scripts/limpar_dados_teste_orcamento_separacao.py            # DRY-RUN (desfaz no fim)
  python scripts/limpar_dados_teste_orcamento_separacao.py --aplicar  # grava
"""

import argparse
import sys
from pathlib import Path

import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _supabase_client import SUPABASE_DB_URL, SUPABASE_URL  # noqa: E402

CORTE_SEPARACAO = "2026-07-01"
BKP = "_bkp_limpeza_20261014_"

# conjuntos de referência (tabelas temporárias, montadas antes de apagar)
CONJUNTOS = f"""
create temp table x_orc on commit drop as select id from public.orcamentos;
create temp table x_pi on commit drop as
  select id from public.projeto_itens where orcamento_id in (select id from x_orc);
create temp table x_sep on commit drop as
  select id from public.separacoes where created_at >= '{CORTE_SEPARACAO}';
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
    # 3 notas de homologação (nunca emitidas) penduradas nos boletos de teste
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
  e.local = 'Estoque' and (
        e.quantidade <> coalesce(p.estoque_total, 0)
     or e.quantidade_reservada <> coalesce(p.estoque_total, 0) - coalesce(p.estoque_disponivel, 0)
     or e.quantidade_disponivel is distinct from coalesce(p.estoque_disponivel, 0))
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true", help="grava (sem isso é dry-run)")
    aplicar = ap.parse_args().aplicar
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (nada gravado)'}\n")

    c = psycopg2.connect(SUPABASE_DB_URL, connect_timeout=30)  # já vem trocado para o pooler
    k = c.cursor()
    k.execute("set local statement_timeout = '5min'")
    k.execute("create schema if not exists backup")
    k.execute(CONJUNTOS)
    for t in ("x_orc", "x_pi", "x_sep", "x_parc"):
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
        b = BKP + tab
        k.execute(f"drop table if exists backup.{b}")
        k.execute(f"create table backup.{b} as select * from public.{tab} where {filtro}")
        k.execute(f"alter table backup.{b} enable row level security")
        k.execute(f"delete from public.{tab} where {filtro}")
        n = k.rowcount
        total += n
        print(f"apagado  {tab:34} {n:5}")
    k.execute("alter table public.orcamento_itens enable trigger trg_0_proteger_vinculo_connect")
    k.execute("alter table public.orcamento_itens enable trigger trg_orcamento_item_change_reset")

    # devolve as reservas: estoque_itens volta a espelhar produtos (dado da Connect)
    b = BKP + "estoque_itens"
    k.execute(f"drop table if exists backup.{b}")
    k.execute(f"""create table backup.{b} as select e.* from public.estoque_itens e
                  join public.produtos p on p.id = e.produto_id where {ESTOQUE_DIVERGENTE}""")
    k.execute(f"alter table backup.{b} enable row level security")
    k.execute(f"""update public.estoque_itens e
                  set quantidade = coalesce(p.estoque_total, 0),
                      quantidade_disponivel = coalesce(p.estoque_disponivel, 0),
                      quantidade_reservada = coalesce(p.estoque_total, 0) - coalesce(p.estoque_disponivel, 0),
                      atualizado_em = now()
                  from public.produtos p where p.id = e.produto_id and {ESTOQUE_DIVERGENTE}""")
    print(f"\nestoque_itens corrigidos (reserva de teste devolvida): {k.rowcount}")
    print(f"linhas apagadas no total: {total}")

    # conferência dentro da transação
    k.execute(f"""select count(*) from public.estoque_itens e join public.produtos p on p.id = e.produto_id
                  where {ESTOQUE_DIVERGENTE}""")
    print("estoque_itens ainda diferente de produtos:", k.fetchone()[0])
    for t in ("orcamentos", "projeto_itens", "estoque_saldos_projeto_item", "estoque_movimentos_projeto_item"):
        k.execute(f"select count(*) from public.{t}")
        print(f"restante {t:34} {k.fetchone()[0]}")
    k.execute("select count(*) from public.separacoes")
    print(f"restante {'separacoes (histórico fev–jun)':34} {k.fetchone()[0]}")

    if aplicar:
        c.commit()
        print("\nGRAVADO.")
    else:
        c.rollback()
        print("\nDRY-RUN: desfeito, nada gravado.")
    c.close()


if __name__ == "__main__":
    main()
