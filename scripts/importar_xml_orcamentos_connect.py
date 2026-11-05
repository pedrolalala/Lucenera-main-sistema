"""
SPEC-243 — Importa os XML de orçamento da Connect (pasta 01-Documento/01 - Planilhas/XML, um arquivo por orçamento) e ENRIQUECE os
orçamentos Connect que já existem no sistema (criados por importar_reserva_entrega_futura_connect.py):

  * valor_total = vl_total_orcamento (total REAL do orçamento) e desconto geral = soma dos itens − total (tipo "valor");
  * itens completos DO DOCUMENTO (orcamento_itens): quantidade líquida por (L, peça) — as linhas de troca/devolução do XML (quantidade
    negativa) entram com sinal; peças só do XML entram só no documento. NADA operacional muda: projeto_itens, saldos de Reserva/Entrega
    Futura/Entregue e estoque ficam como as planilhas deixaram (regra do usuário: é tudo herança, não mexe na quantidade);
  * empresa pelo CNPJ do XML e data do orçamento.

Também BATE os dois conjuntos e gera a lista do que falta: orçamentos da herança sem XML (para exportar na Connect) e XML que não
estão na herança.

Ordem: 1) importar_reserva_entrega_futura_connect.py  2) ESTE script. (Reimportar as planilhas apaga o enriquecimento: rodar o XML de novo.)

Uso:
  python scripts/importar_xml_orcamentos_connect.py            # DRY-RUN (roda tudo dentro de uma transação e DESFAZ; usa a migration 273
                                                               #          em rascunho dentro da transação se ela ainda não estiver aplicada)
  python scripts/importar_xml_orcamentos_connect.py --aplicar  # grava (exige a migration 273 aplicada)
"""

from __future__ import annotations

import argparse
import glob
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import SUPABASE_DB_URL, SUPABASE_URL  # noqa: E402
from sync_connect_common import RelatorioModulo, imprimir_resumo_final, salvar_log, validar_minimo_linhas, ImportacaoAbortada  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas" / "XML"
LOG_DIR = ROOT / "scripts" / "logs" / "reserva_connect"
MIGRATION = ROOT / "supabase" / "db" / "migrations" / "20261104_273_spec243_xml_orcamentos_connect" / "up.sql"


def num(s):
    t = (s or "").strip()
    if t == "":
        return None
    if "," in t and "." in t:
        t = t.replace(".", "").replace(",", ".")
    else:
        t = t.replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


def data(s):
    t = (s or "").strip()
    try:
        return datetime.strptime(t[:10], "%d/%m/%Y").date()
    except ValueError:
        return None


def ler_xml(path: Path):
    raw = path.read_bytes()
    for enc in ("utf-8", "latin-1"):
        try:
            return ET.fromstring(raw.decode(enc))
        except Exception:  # noqa: BLE001
            continue
    return None


def carregar_xmls():
    orcs, itens, ignorados, erros = [], [], [], []
    for p in sorted(glob.glob(str(PASTA / "*"))):
        p = Path(p)
        if not p.is_file() or p.suffix.lower() != ".xml":
            continue
        if p.stat().st_size < 50:
            ignorados.append(p.name)
            continue
        r = ler_xml(p)
        o = r.find("orcamento") if r is not None else None
        if o is None:
            erros.append(p.name)
            continue
        g = lambda k: (o.findtext(k) or "").strip()  # noqa: E731
        try:
            cod = int(g("cod_orcamento"))
        except ValueError:
            erros.append(p.name)
            continue
        if p.stem.isdigit() and int(p.stem) != cod:
            erros.append(f"{p.name} (cod_orcamento {cod} diferente do nome do arquivo)")
            continue
        orcs.append((cod, p.name, int(g("cod_empresa") or 0) or None, g("cnpj_empresa") or None, int(g("cod_cliente") or 0) or None,
                     num(g("vl_total_orcamento")), data(g("dt_orcamento")), data(g("dt_devolucao"))))
        its = o.find("itens")
        for n, it in enumerate([] if its is None else its.findall("Item"), start=1):
            h = lambda k: (it.findtext(k) or "").strip()  # noqa: E731
            qtd = num(h("qtd_produto"))
            if qtd is None:
                continue
            itens.append((cod, n, int(h("indice") or 0) or None, h("desc_classificacao") or None, int(h("cod_produto") or 0) or None,
                          h("referencia") or None, h("desc_produto") or None, qtd, num(h("vl_unitario")), num(h("desconto_produto")),
                          num(h("vl_total_produto")), int(h("saida") or 0), int(h("dev_troca") or 0), int(h("dev_haver") or 0),
                          int(h("dev_defeito") or 0)))
    return orcs, itens, ignorados, erros


def main() -> None:
    ap = argparse.ArgumentParser(description="SPEC-243: XML dos orçamentos da Connect")
    ap.add_argument("--aplicar", action="store_true", help="grava (sem isso roda e DESFAZ no fim)")
    args = ap.parse_args()
    aplicar = args.aplicar
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (roda tudo e desfaz no fim)'}\n")
    rel = RelatorioModulo(nome="XML dos orçamentos da Connect (SPEC-243)", arquivo_origem=str(PASTA.name))

    orcs, itens, ignorados, erros = carregar_xmls()
    print(f"XML lidos: {len(orcs)} orçamentos, {len(itens)} itens | vazios ignorados: {ignorados} | com erro: {erros}")
    try:
        validar_minimo_linhas(len(orcs), 50, "XML")
    except ImportacaoAbortada as e:
        rel.abortado = str(e)
        rel.imprimir()
        sys.exit(1)

    conn = psycopg2.connect(SUPABASE_DB_URL, connect_timeout=30)
    cur = conn.cursor()
    try:
        cur.execute("set local statement_timeout = '10min'")
        cur.execute("select to_regprocedure('public.aplicar_xml_connect_orcamentos()')")
        if cur.fetchone()[0] is None:
            if aplicar:
                raise ImportacaoAbortada("A migration 273 não está aplicada. Aplique-a antes de usar --aplicar.")
            print("Migration 273 (rascunho) ainda não aplicada: rodando dentro desta transação, que será desfeita.")
            sql = "\n".join(l for l in MIGRATION.read_text(encoding="utf-8").splitlines() if l.strip() not in ("BEGIN;", "COMMIT;"))
            cur.execute(sql)

        # ---- espelho do XML (substitui tudo) ------------------------------------------------------------------
        cur.execute("delete from public.connect_xml_orcamento")
        psycopg2.extras.execute_values(cur, """insert into public.connect_xml_orcamento
            (cod_orcamento, arquivo, cod_empresa, cnpj_empresa, cod_cliente, vl_total_orcamento, dt_orcamento, dt_devolucao) values %s""", orcs)
        psycopg2.extras.execute_values(cur, """insert into public.connect_xml_item
            (cod_orcamento, linha, indice, desc_classificacao, cod_produto, referencia, desc_produto, qtd_produto, vl_unitario,
             desconto_produto, vl_total_produto, saida, dev_troca, dev_haver, dev_defeito) values %s""", itens, page_size=1000)

        # ---- bater os dois conjuntos ----------------------------------------------------------------------------
        cur.execute("""select r.cod_orcamento_connect, min(r.cod_venda_connect), min(r.nome_bruto), count(*), round(sum(r.quantidade)),
                              bool_or(r.orcamento_id is not null)
                         from public.connect_reserva_ambiente r where r.cod_orcamento_connect is not null group by 1 order by 1""")
        heranca = pd.DataFrame(cur.fetchall(), columns=["orcamento_connect", "venda_connect", "nome_na_planilha", "linhas", "pecas", "ja_virou_orcamento"])
        xml_cods = {o[0] for o in orcs}
        heranca["tem_xml"] = heranca.orcamento_connect.isin(xml_cods)
        sem_xml = heranca[~heranca.tem_xml].drop(columns="tem_xml")
        fora = pd.DataFrame([(o[0], o[1], o[4], o[5], o[6]) for o in orcs if o[0] not in set(heranca.orcamento_connect)],
                            columns=["orcamento_connect", "arquivo", "cliente_connect", "total_xml", "data"])
        print(f"\nOrçamentos da herança: {len(heranca)} | com XML: {int(heranca.tem_xml.sum())} | SEM XML (exportar na Connect): {len(sem_xml)}"
              f" (destes, {int(sem_xml.ja_virou_orcamento.sum())} já viraram orçamento no sistema)")
        print(f"XML fora da herança (não entram): {len(fora)}")

        # itens: onde o XML é menor que o pendente (inconsistente) e onde só o sistema tem
        cur.execute("""
            with x as (select cod_orcamento, nullif(btrim(coalesce(desc_classificacao,'')),'') l, cod_produto, sum(qtd_produto) net
                         from public.connect_xml_item group by 1,2,3),
                 n as (select o.origem_connect_cod_orcamento cod_orcamento, pi.l_fixo l, p.codigo_produto cod_produto,
                              coalesce(s.q_reserva,0)+coalesce(s.q_entrega_futura,0) pend
                         from public.projeto_itens pi join public.orcamentos o on o.id=pi.orcamento_id join public.produtos p on p.id=pi.produto_id
                         left join public.estoque_saldos_projeto_item s on s.projeto_item_id=pi.id where o.origem='connect')
            select 'xml_menor_que_pendente' tipo, n.cod_orcamento, n.l, n.cod_produto, x.net::numeric, n.pend::numeric
              from n join x on x.cod_orcamento=n.cod_orcamento and x.l is not distinct from n.l and x.cod_produto=n.cod_produto where x.net < n.pend
            union all
            select 'so_no_sistema', n.cod_orcamento, n.l, n.cod_produto, null, n.pend::numeric
              from n where n.cod_orcamento in (select cod_orcamento from x)
               and not exists (select 1 from x where x.cod_orcamento=n.cod_orcamento and x.l is not distinct from n.l and x.cod_produto=n.cod_produto)""")
        itens_div = pd.DataFrame(cur.fetchall(), columns=["tipo", "orcamento_connect", "L", "peca", "qtd_xml_liquida", "pendente_planilha"])

        cur.execute("""select o.origem_connect_cod_orcamento, e.nome from public.orcamentos o join public.empresas e on e.id=o.empresa_id where o.origem='connect'""")
        emp_atual = dict(cur.fetchall())
        cur.execute("select cnpj, nome from public.empresas")
        por_cnpj = {re.sub(r"\D", "", c or ""): n for c, n in cur.fetchall()}
        emp_div = [(o[0], emp_atual[o[0]], por_cnpj.get(re.sub(r"\D", "", o[3] or ""))) for o in orcs
                   if o[0] in emp_atual and por_cnpj.get(re.sub(r"\D", "", o[3] or "")) not in (None, emp_atual[o[0]])]
        print(f"Empresa do XML diferente da deduzida pelo Contas a Receber: {len(emp_div)} -> {emp_div[:6]}")

        # ---- aplica ---------------------------------------------------------------------------------------------
        cur.execute("select public.aplicar_xml_connect_orcamentos()")
        res = cur.fetchone()[0]
        print("\nRESULTADO:", res)

        cur.execute("""select count(*) filter (where abs(o.valor_total - (coalesce((select sum(i.quantidade*i.preco_unitario) from public.orcamento_itens i where i.orcamento_id=o.id),0) - o.desconto_global)) > 0.02),
                             count(*), round(sum(o.valor_total),2)
                        from public.orcamentos o join public.connect_xml_orcamento x on x.cod_orcamento=o.origem_connect_cod_orcamento where o.origem='connect'""")
        diverg, total_o, soma = cur.fetchone()
        print(f"Orçamentos com XML: {total_o} | valor líquido (itens − desconto) diferente do total: {diverg} (esperado 0) | soma dos totais: R$ {soma}")
        cur.execute("""select count(*), coalesce(sum(s.q_entregue),0) from public.estoque_saldos_projeto_item s join public.projeto_itens pi on pi.id=s.projeto_item_id
                         join public.orcamentos o on o.id=pi.orcamento_id where o.origem='connect' and s.q_entregue>0""")
        print("Itens com ENTREGUE > 0 / quantidade entregue:", cur.fetchone())
        # orçamentos cujo líquido não fecha com o total (total MAIOR que os itens: acréscimo/frete que o XML não detalha)
        cur.execute("""select o.origem_connect_cod_orcamento, o.valor_total, round(coalesce((select sum(i.quantidade*i.preco_unitario) from public.orcamento_itens i
                              where i.orcamento_id=o.id),0),2) soma_itens, o.desconto_global
                         from public.orcamentos o join public.connect_xml_orcamento x on x.cod_orcamento=o.origem_connect_cod_orcamento
                        where o.origem='connect' and abs(o.valor_total - (coalesce((select sum(i.quantidade*i.preco_unitario) from public.orcamento_itens i
                              where i.orcamento_id=o.id),0) - o.desconto_global)) > 0.02""")
        total_diferente = pd.DataFrame(cur.fetchall(), columns=["orcamento_connect", "total_xml", "soma_itens", "desconto_geral"])
        if len(total_diferente):
            print("Orçamentos em que o total do XML não fecha com os itens:", total_diferente.values.tolist())
        # peças do XML que não existem no cadastro de produtos (nos orçamentos Connect do sistema)
        cur.execute("""select xi.cod_produto, max(xi.referencia), max(xi.desc_produto), count(distinct xi.cod_orcamento), sum(xi.qtd_produto)
                         from public.connect_xml_item xi join public.orcamentos o on o.origem_connect_cod_orcamento=xi.cod_orcamento and o.origem='connect'
                        where not exists (select 1 from public.produtos p where p.codigo_produto=xi.cod_produto) group by 1 order by 4 desc""")
        pecas_sem_cadastro = pd.DataFrame(cur.fetchall(), columns=["cod_produto", "referencia", "descricao", "orcamentos", "qtd"])
        print(f"Peças do XML que NÃO estão no cadastro de produtos: {len(pecas_sem_cadastro)} -> {pecas_sem_cadastro.cod_produto.tolist()[:15]}")
        cur.execute("""select count(*) from public.historico_status_orcamentos h join public.orcamentos o on o.id=h.orcamento_id
                        where o.origem='connect' and h.status_novo='enviado_cliente'""")
        print("Reinício de aprovação nos orçamentos Connect (esperado 0):", cur.fetchone()[0])
        cur.execute("select status, count(*) from public.orcamentos where origem='connect' group by 1")
        print("Status dos orçamentos Connect:", cur.fetchall())

        LOG_DIR.mkdir(parents=True, exist_ok=True)
        xlsx = LOG_DIR / f"xml_connect_{datetime.now():%Y%m%d_%H%M%S}{'' if aplicar else '_dryrun'}.xlsx"
        with pd.ExcelWriter(xlsx) as xw:
            pd.DataFrame(list(res.items()), columns=["indicador", "valor"]).to_excel(xw, sheet_name="resumo", index=False)
            sem_xml.to_excel(xw, sheet_name="exportar_estes_xml", index=False)
            fora.to_excel(xw, sheet_name="xml_fora_da_heranca", index=False)
            pd.DataFrame(emp_div, columns=["orcamento_connect", "empresa_atual", "empresa_do_xml"]).to_excel(xw, sheet_name="empresa_divergente", index=False)
            itens_div.to_excel(xw, sheet_name="itens_divergentes", index=False)
            total_diferente.to_excel(xw, sheet_name="total_nao_fecha", index=False)
            pecas_sem_cadastro.to_excel(xw, sheet_name="pecas_sem_cadastro", index=False)
        print("Excel de conferência:", xlsx)

        rel.atualizados = int(res.get("orcamentos_com_xml", 0))
        rel.inseridos = int(res.get("itens_so_do_xml_no_documento", 0))
        if aplicar:
            conn.commit()
            print("\nGRAVADO.")
        else:
            conn.rollback()
            print("\nDRY-RUN: tudo desfeito, nada foi gravado.")
    except ImportacaoAbortada as e:
        conn.rollback()
        rel.abortado = str(e)
    except Exception as e:  # noqa: BLE001
        conn.rollback()
        rel.registrar_erro(f"{type(e).__name__}: {e}")
        print(f"\nERRO — tudo desfeito: {e}")
    finally:
        conn.close()

    rel.finalizar()
    rel.imprimir()
    imprimir_resumo_final([rel], not aplicar, salvar_log([rel], not aplicar))
    if rel.erros or rel.abortado:
        sys.exit(1)


if __name__ == "__main__":
    main()
