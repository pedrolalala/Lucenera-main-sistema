"""
SPEC-245 (G11) — Corrige a PESSOA (cliente/fornecedor) das negociações do Contas a Receber / Contas a Pagar.

PROBLEMA (reunião 42 / tela Consultar Duplicatas): 9.714 das 14.027 negociações estão sem contato (a tela mostra "Pessoa 464") e, nas de despesa que têm
contato, 1.609 de 2.330 apontam para a PESSOA ERRADA. Causa: o importador ligava o contato só quando criava a negociação e pelo `cod_pessoa` SEM olhar o tipo
(o mesmo número existe como cliente e como arquiteto, e os 357 fornecedores nem têm `codigo_legado`); as negociações antigas nunca foram preenchidas.

REGRA (a planilha do dia manda; `nome_pessoa`/`razao_pessoa` vêm em cada linha):
  1. acha o contato pelo NOME (nome, razão social ou empresa, sem acento/pontuação) igual ao da planilha. Receber prefere cliente > arquiteto; Pagar prefere
     fornecedor > arquiteto > cliente (despesa também é paga a arquiteto/cliente: RT, devolução). Se houver mais de um do mesmo tipo, usa o que tem
     `codigo_legado` = cod_pessoa; se ainda assim ficar ambíguo (duplicidade de cadastro com o mesmo nome), usa o MAIS ANTIGO e lista na aba ambiguas_resolvidas;
  2. se não existe, cria um PRÉ-CADASTRO (Receber -> cliente; Pagar -> fornecedor) com o nome e a razão social da planilha, uma vez por nome, com
     `codigo_legado` = cod_pessoa só quando esse (código, tipo) está livre e o código não tem outro nome na planilha;
  3. só troca o contato da negociação quando ele está vazio ou não bate com o nome da planilha. Nada além de `negociacoes.contato_id` e dos pré-cadastros muda.
Backups no schema `backup`; Excel em scripts/logs/conferencia_financeiro/. Idempotente.

Uso:  python scripts/corrigir_pessoas_financeiro.py            # DRY-RUN (transação desfeita)
      python scripts/corrigir_pessoas_financeiro.py --aplicar  # grava
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
CASOS = [("ContaReceber_", "receita", "cliente", ["cliente", "arquiteto"]), ("ContaPagar_", "despesa", "fornecedor", ["fornecedor", "arquiteto", "cliente"])]


def norm(x) -> str:
    s = unicodedata.normalize("NFD", str(x or "")).encode("ascii", "ignore").decode().upper()
    for ch in ".,;:-/()&":
        s = s.replace(ch, " ")
    return " ".join(s.split())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()
    hoje = f"{datetime.now():%Y%m%d_%H%M%S}"  # com hora: rodar de novo NUNCA apaga o backup da rodada anterior

    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute("SELECT id::text, codigo_legado, tipo::text, nome, razao_social, nome_empresa, created_at FROM public.contatos WHERE coalesce(ativo, true)")
        ct = pd.DataFrame(cur.fetchall(), columns=["id", "cod", "tipo", "nome", "razao", "empresa", "criado"])
        for k in ("nome", "razao", "empresa"):
            ct["n_" + k] = ct[k].map(norm)
        por_nome: dict[str, list] = {}
        for r in ct.itertuples():
            for n in {r.n_nome, r.n_razao, r.n_empresa}:
                if n:
                    por_nome.setdefault(n, []).append(r)
        nome_do_contato = {r.id: {r.n_nome, r.n_razao, r.n_empresa} - {""} for r in ct.itertuples()}
        usados = {(int(r.cod), r.tipo) for r in ct.itertuples() if pd.notna(r.cod)}

        mudar, criar, ambiguas, sem_nome = [], {}, [], 0
        for prefixo, tipo, tipo_novo, preferencia in CASOS:
            d = pd.read_excel(descobrir_planilha_mais_recente(PASTA, prefixo))
            d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce")
            d = d.dropna(subset=["cod"])
            d["cod"] = d["cod"].astype(int)
            d["status"] = pd.to_numeric(d["pago"], errors="coerce")
            d["cod_pessoa"] = pd.to_numeric(d["cod_pessoa"], errors="coerce")
            d["n1"], d["n2"] = d["nome_pessoa"].map(norm), d["razao_pessoa"].map(norm)
            # códigos de pessoa com um só nome na planilha (para decidir se o código serve de codigo_legado)
            nomes_por_cod = d.dropna(subset=["cod_pessoa"]).groupby("cod_pessoa")["n2"].nunique()

            cur.execute(
                "SELECT t.cod_itens_duplicata, t.negociacao_id::text, t.status_pago, n.contato_id::text FROM public.transacoes t "
                "JOIN public.negociacoes n ON n.id = t.negociacao_id WHERE t.tipo::text = %s AND t.cod_itens_duplicata IS NOT NULL",
                (tipo,),
            )
            db = pd.DataFrame(cur.fetchall(), columns=["cod", "neg", "status_pago", "contato_atual"])
            m = d.merge(db, left_on=["cod", "status"], right_on=["cod", "status_pago"], how="inner")
            # uma pessoa por negociação (a mais frequente)
            g = (m.groupby("neg").agg(contato_atual=("contato_atual", "first"), cod_pessoa=("cod_pessoa", "first"), nome=("nome_pessoa", "first"),
                                      razao=("razao_pessoa", "first"), n1=("n1", "first"), n2=("n2", "first"), linhas=("cod", "size")).reset_index())
            g["contato_atual"] = g["contato_atual"].map(lambda v: v if isinstance(v, str) else None)
            for r in g.itertuples():
                nomes = {x for x in (r.n1, r.n2) if x and x != "NAN"}
                if not nomes:
                    sem_nome += 1
                    continue
                if r.contato_atual and nome_do_contato.get(r.contato_atual, set()) & nomes:
                    continue  # já está certo
                cands = {}
                for n in nomes:
                    for c in por_nome.get(n, []):
                        cands[c.id] = c
                escolhido = None
                if cands:
                    for t in preferencia:
                        doTipo = [c for c in cands.values() if c.tipo == t]
                        if len(doTipo) == 1:
                            escolhido = doTipo[0].id
                            break
                        if len(doTipo) > 1:
                            com_cod = [c for c in doTipo if pd.notna(c.cod) and pd.notna(r.cod_pessoa) and int(c.cod) == int(r.cod_pessoa)]
                            if len(com_cod) == 1:
                                escolhido = com_cod[0].id
                                break
                            # mesmo nome em mais de um cadastro do mesmo tipo (duplicidade de cadastro): fica o MAIS ANTIGO. Deixar a ligação antiga
                            # (que costuma ser outra pessoa) seria pior do que escolher um dos cadastros do mesmo nome.
                            escolha = sorted(doTipo, key=lambda c: (c.criado, c.id))[0]
                            ambiguas.append({"tipo": tipo, "negociacao": r.neg, "cod_pessoa": r.cod_pessoa, "nome": r.nome, "candidatos": len(doTipo),
                                             "escolhido_mais_antigo": escolha.id})
                            escolhido = escolha.id
                            break
                if escolhido == "AMBIGUO":
                    continue
                if escolhido is None:
                    chave = (tipo_novo, norm(r.razao) or norm(r.nome))
                    if chave not in criar:
                        cod = int(r.cod_pessoa) if pd.notna(r.cod_pessoa) else None
                        usar_cod = cod if (cod is not None and (cod, tipo_novo) not in usados and nomes_por_cod.get(cod, 0) == 1) else None
                        if usar_cod is not None:
                            usados.add((usar_cod, tipo_novo))
                        criar[chave] = {"tipo": tipo_novo, "nome": str(r.nome).strip() if str(r.nome) != "nan" else str(r.razao).strip(),
                                        "razao": str(r.razao).strip() if str(r.razao) != "nan" else str(r.nome).strip(), "cod_pessoa": cod, "codigo_legado": usar_cod, "negociacoes": 0}
                    criar[chave]["negociacoes"] += 1
                    escolhido = ("NOVO", chave)
                mudar.append({"tipo": tipo, "negociacao": r.neg, "contato_antes": r.contato_atual, "destino": escolhido, "cod_pessoa": r.cod_pessoa, "nome": r.nome, "linhas": int(r.linhas)})

        dm = pd.DataFrame(mudar)
        antes_nulo = int(dm["contato_antes"].isna().sum()) if len(dm) else 0
        print(f"Negociações a corrigir: {len(dm)} (sem contato: {antes_nulo} | com contato ERRADO: {len(dm) - antes_nulo}) | pré-cadastros a criar: {len(criar)} | ambíguas resolvidas pelo cadastro mais antigo: {len(ambiguas)} | sem nome na planilha: {sem_nome}")
        if len(dm):
            print(dm.groupby("tipo").size().to_dict(), "| destino existente:", int(dm["destino"].map(lambda x: not isinstance(x, tuple)).sum()), "| destino novo:", int(dm["destino"].map(lambda x: isinstance(x, tuple)).sum()))
        print("pré-cadastros por tipo:", pd.Series([v["tipo"] for v in criar.values()]).value_counts().to_dict() if criar else {})

        saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
        saida.mkdir(parents=True, exist_ok=True)
        xlsx = saida / f"correcao_pessoas_{datetime.now():%Y%m%d_%H%M%S}{'' if args.aplicar else '_dryrun'}.xlsx"
        with pd.ExcelWriter(xlsx) as w:
            dm.assign(destino=dm["destino"].map(lambda x: "PRE-CADASTRO NOVO" if isinstance(x, tuple) else x)).to_excel(w, sheet_name="negociacoes", index=False) if len(dm) else None
            pd.DataFrame(list(criar.values())).to_excel(w, sheet_name="pre_cadastros", index=False)
            pd.DataFrame(ambiguas).to_excel(w, sheet_name="ambiguas_resolvidas", index=False)
        print("Excel:", xlsx)

        if len(dm):
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes), (SELECT count(*) FROM public.contatos)")
            antes = cur.fetchone()
            cur.execute("CREATE SCHEMA IF NOT EXISTS backup")
            bk_neg, bk_ct = f"_bkp_negociacoes_contato_{hoje}", f"_bkp_contatos_precadastro_financeiro_{hoje}"
            cur.execute(f"CREATE TABLE backup.{bk_neg} (negociacao_id uuid PRIMARY KEY, tipo text, contato_antes uuid, contato_depois uuid, criado_em timestamptz DEFAULT now())")
            cur.execute(f"CREATE TABLE backup.{bk_ct} (contato_id uuid PRIMARY KEY, tipo text, nome text, criado_em timestamptz DEFAULT now())")
            novos: dict = {}
            for chave, v in criar.items():
                obs = (f"PRÉ-CADASTRO criado ao corrigir o Contas a {'Receber' if v['tipo'] == 'cliente' else 'Pagar'} da Connect (cód. pessoa {v['cod_pessoa']}, {datetime.now():%d/%m/%Y}). "
                       "Só nome e razão social vieram da planilha: completar CPF/CNPJ, telefone, e-mail e endereço.")
                cur.execute(
                    "INSERT INTO public.contatos (tipo, nome, razao_social, codigo_legado, observacoes) VALUES (%s::contato_tipo, %s, %s, %s, %s) RETURNING id::text",
                    (v["tipo"], v["nome"], v["razao"], v["codigo_legado"], obs),
                )
                novos[chave] = cur.fetchone()[0]
                cur.execute(f"INSERT INTO backup.{bk_ct} (contato_id, tipo, nome) VALUES (%s::uuid, %s, %s)", (novos[chave], v["tipo"], v["nome"]))
            linhas = []
            for r in dm.itertuples():
                destino = novos[r.destino[1]] if isinstance(r.destino, tuple) else r.destino
                linhas.append((r.negociacao, r.tipo, r.contato_antes if isinstance(r.contato_antes, str) else None, destino))
            psycopg2.extras.execute_values(cur, f"INSERT INTO backup.{bk_neg} (negociacao_id, tipo, contato_antes, contato_depois) VALUES %s", linhas,
                                           template="(%s::uuid, %s, %s::uuid, %s::uuid)", page_size=500)
            psycopg2.extras.execute_values(cur, "UPDATE public.negociacoes n SET contato_id = v.novo::uuid FROM (VALUES %s) AS v(id, novo) WHERE n.id = v.id::uuid",
                                           [(a, d_) for a, _, _, d_ in linhas], page_size=500)
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes), (SELECT count(*) FROM public.contatos)")
            depois = cur.fetchone()
            esperado = (antes[0], antes[1], antes[2], antes[3] + len(criar))
            print("transações / negociações / soma das parcelas / contatos antes:", antes, "| depois:", depois, "->", "OK" if depois == esperado else "DIFERENTE DO ESPERADO")
            if depois != esperado:
                raise SystemExit("ABORTADO: contagens ou valores mudaram além do esperado; nada foi gravado.")
            print(f"Backups: backup.{bk_neg} ({len(linhas)}) e backup.{bk_ct} ({len(novos)})")

        if args.aplicar:
            con.commit()
            print("GRAVADO.")
        else:
            con.rollback()
            print("DRY-RUN: tudo desfeito, nada foi gravado.")
    except BaseException:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
