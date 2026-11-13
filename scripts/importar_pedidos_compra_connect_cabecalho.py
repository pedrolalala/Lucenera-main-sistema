"""
Importa a planilha PedidoCompra_AAAA-MM-DD.xlsx (export Connect) como pedidos de
compra do sistema novo (`pedidos_compra`), SO CABECALHO — a planilha nao traz itens.

Pedido do Compras (pedidos_compra, plural) e diferente de `pedido_compra`
(financeiro, singular — ver importar_pedido_compra.py). Aqui o objetivo e o
usuario achar o pedido na Entrada de Nota Fiscal (pedido da Connect em aberto).

Regras:
  - numero = "<codigo_pedido> CONNECT" (mesmo formato do 1993 CONNECT criado na tela);
  - fornecedor = contatos tipo='fornecedor' casado pelo NOME normalizado (contatos nao tem
    o codigo da Connect; `codigo_legado` e de CLIENTE — nao usar). Cadastro duplicado:
    vale o que ja tem mais pedidos, depois o de menor id (e avisa). Fornecedor sem
    cadastro: o pedido e PULADO e listado (cadastrar o fornecedor e rodar de novo);
  - status 'aprovado', data_emissao e valor_total (vl_nota) da planilha;
  - empresa/perfil/condicoes ficam vazios (a planilha nao informa; a Entrada de NF
    deixa escolher a empresa);
  - NAO cria itens, parcelas nem Contas a Pagar (pedidos_compra so tem gatilho de
    auditoria e de numeracao);
  - rerun-safe: pula pedido cujo numero ja existe ("N", "N CONNECT", "PC-LEGADO-N" ou numero antigo de pedido renomeado - SPEC-293);
  - tudo numa transacao; sem --aplicar faz ROLLBACK (dry-run).

Uso:
  python scripts/importar_pedidos_compra_connect_cabecalho.py <planilha.xlsx>            # dry-run
  python scripts/importar_pedidos_compra_connect_cabecalho.py <planilha.xlsx> --aplicar
"""

import argparse
import os
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent


def db_url() -> str:
    m = re.search(r"^\s*SUPABASE_DB_URL\s*=\s*(.*)$", (ROOT / ".env").read_text(encoding="utf-8"), re.M)
    if not m:
        sys.exit("SUPABASE_DB_URL ausente no .env")
    return m.group(1).strip().strip("\"'")


def psql(url: str, sql: str, tuples: bool = True) -> str:
    args = ["psql", url, "-X", "-v", "ON_ERROR_STOP=1"] + (["-A", "-F", "|", "-t"] if tuples else [])
    r = subprocess.run(args, input=sql, capture_output=True, text=True, encoding="utf-8",
                       env={**os.environ, "PGCLIENTENCODING": "UTF8"})
    if r.returncode != 0:
        sys.exit("psql falhou:\n" + r.stderr)
    return r.stdout.strip()


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode().upper()
    return re.sub(r"\s+", " ", re.sub(r"[^A-Z0-9 ]", " ", s)).strip()


def lit(v: str) -> str:
    return "'" + v.replace("'", "''") + "'"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("planilha")
    ap.add_argument("--aplicar", action="store_true")
    a = ap.parse_args()
    url = db_url()

    df = pd.read_excel(a.planilha)
    ped = df.drop_duplicates("codigo_pedido")
    if ped.codigo_pedido.duplicated().any():
        sys.exit("codigo_pedido duplicado")

    existentes = set()
    for l in psql(url, "select numero from pedidos_compra").splitlines():
        m = re.search(r"(\d{3,5})", l)
        if m:
            existentes.add(int(m.group(1)))
    # SPEC-293: pedido renomeado na tela (ex.: "1930 CONNECT" -> outro numero) continua existente pelo numero ANTIGO,
    # registrado em backup.spec293_renumeracao_pedidos_compra. Tolera a tabela ainda nao existir (migration 347 nao aplicada).
    if psql(url, "select to_regclass('backup.spec293_renumeracao_pedidos_compra') is not null") == "t":
        for l in psql(url, "select numero_antigo from backup.spec293_renumeracao_pedidos_compra "
                           "where pedido_id <> '00000000-0000-0000-0000-000000000000'").splitlines():
            m = re.search(r"(\d{3,5})", l)
            if m:
                existentes.add(int(m.group(1)))

    forn: dict[str, list[tuple[str, str, int]]] = {}
    for l in psql(url, "select c.id,c.nome,(select count(*) from pedidos_compra p where p.fornecedor_id=c.id) "
                       "from contatos c where c.tipo='fornecedor' order by c.id").splitlines():
        i, n, q = l.split("|", 2)[0], l.split("|")[1], int(l.split("|")[-1])
        forn.setdefault(norm(n), []).append((i, n, q))

    novos, pulados, erros, sem_forn, duplos = [], [], [], [], []
    for _, r in ped.iterrows():
        n = int(r.codigo_pedido)
        if n in existentes:
            pulados.append(n)
            continue
        h = forn.get(norm(r.nm_fornecedor), [])
        if not h:
            sem_forn.append(f"{n} ({r.nm_fornecedor}, R$ {float(r.vl_nota):.2f})")
            continue
        if len(h) > 1:
            h = sorted(h, key=lambda x: (-x[2], x[0]))
            duplos.append(f"{n}: {len(h)} cadastros de '{h[0][1]}' -> usado {h[0][0]}")
        d, mth, y = str(r.emissao_pedido).strip().split("/")
        novos.append((n, h[0][0], h[0][1], f"{y}-{mth}-{d}", round(float(r.vl_nota), 2), r.nm_fornecedor))

    if erros:
        sys.exit("ABORTADO, nada gravado:\n  " + "\n  ".join(erros))

    print(f"planilha: {len(ped)} pedidos | novos: {len(novos)} | ja existiam: {len(pulados)} {pulados}")
    for n, _, nome, dt, v, nm in novos:
        print(f"  {n} CONNECT  {dt}  R$ {v:>10.2f}  {nome}" + ("" if nome.strip().upper() == str(nm).strip().upper() else f"   [planilha: {nm}]"))
    print(f"total R$ {sum(x[4] for x in novos):,.2f}")
    for t, lst in (("SEM CADASTRO DE FORNECEDOR (pulados)", sem_forn), ("CADASTRO DUPLICADO (conferir)", duplos)):
        if lst:
            print(t + ":\n  " + "\n  ".join(lst))
    if not novos:
        return

    obs = "Pedido da Connect (planilha PedidoCompra 05/11/2026) - importado so com cabecalho, sem itens."
    vals = ",\n".join(
        f"({lit(f'{n} CONNECT')}, '{fid}'::uuid, 'aprovado', '{dt}'::date, {v}, {lit(obs)})"
        for n, fid, _, dt, v, _ in novos
    )
    sql = f"""BEGIN;
INSERT INTO pedidos_compra (numero, fornecedor_id, status, data_emissao, valor_total, observacao)
VALUES {vals};
SELECT count(*) AS inseridos FROM pedidos_compra WHERE numero LIKE '% CONNECT' AND observacao LIKE 'Pedido da Connect (planilha PedidoCompra 05/11/2026)%';
{'COMMIT' if a.aplicar else 'ROLLBACK'};
"""
    print(psql(url, sql))
    print("APLICADO." if a.aplicar else "DRY-RUN: nada foi gravado (ROLLBACK). Use --aplicar para gravar.")


if __name__ == "__main__":
    main()
