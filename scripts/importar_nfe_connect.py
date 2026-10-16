"""
SPEC-204: importa os XMLs das notas fiscais emitidas pela Connect (NF-e 4.00 e eventos) para
notas_fiscais_connect (+ itens, duplicatas, eventos). A tela "Notas Fiscais Connect" do Vendas lê
essas tabelas.

- *-nfe.xml (nfeProc): uma nota. Reimportar a mesma chave atualiza a nota e refaz itens/duplicatas.
- *-procEventoNFe.xml: carta de correção (110110), cancelamento (110111)... Cancelamento homologado
  (cStat 135/155) marca a nota como cancelada.
- Só entra nota emitida por empresa do grupo (empresas.cnpj); as outras são listadas e puladas.
- Lê a pasta e as subpastas (ex.: uma pasta por mês).
- Só grava nas 4 tabelas notas_fiscais_connect*: não mexe em financeiro (parcelas, boletos, contas,
  transações), estoque, orçamentos nem notas_fiscais. Essas tabelas não têm trigger nem view ligada.
- Vínculos: empresa pelo CNPJ do emitente; cliente (contatos) pelo CPF/CNPJ do destinatário quando
  só existe um contato com ele; peça (produtos) pelo cProd = codigo_produto.

Uso:
  python scripts/importar_nfe_connect.py "01-Documento/04 - XML/XML NOTA FISCAL"            # DRY-RUN
  python scripts/importar_nfe_connect.py "01-Documento/04 - XML/XML NOTA FISCAL" --aplicar  # grava
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _supabase_client import SUPABASE_DB_URL  # noqa: E402

NS = {"n": "http://www.portalfiscal.inf.br/nfe"}
CANCELAMENTO = "110111"
EVENTO_HOMOLOGADO = {"135", "136", "155"}
# Soma no valor: nota de venda (5101–5123, 5401–5405 e 6xxx); abate: devolução de cliente (entrada).
CFOP_VENDA = r"^[56](10[1-9]|11\d|12[0-3]|40[1-5])$"
CFOP_DEVOLUCAO = r"^[12](20[1-4]|41[01])$"


def txt(el, caminho):
    if el is None:
        return None
    achado = el.find(caminho, NS)
    if achado is None or achado.text is None:
        return None
    return achado.text.strip() or None


def num(el, caminho):
    valor = txt(el, caminho)
    return float(valor) if valor is not None else None


def ler_nota(arquivo: Path, conteudo: str):
    raiz = ET.fromstring(conteudo)
    inf = raiz.find(".//n:infNFe", NS)
    if inf is None:
        return None
    ide, emit, dest = inf.find("n:ide", NS), inf.find("n:emit", NS), inf.find("n:dest", NS)
    tot = inf.find("n:total/n:ICMSTot", NS)
    prot = raiz.find(".//n:protNFe/n:infProt", NS)

    if txt(dest, "n:CNPJ"):
        dest_tipo, dest_doc = "CNPJ", txt(dest, "n:CNPJ")
    elif txt(dest, "n:CPF"):
        dest_tipo, dest_doc = "CPF", txt(dest, "n:CPF")
    elif dest is not None:
        dest_tipo, dest_doc = "ESTRANGEIRO", txt(dest, "n:idEstrangeiro")
    else:
        dest_tipo, dest_doc = None, None

    itens = []
    for det in inf.findall("n:det", NS):
        prod, imp = det.find("n:prod", NS), det.find("n:imposto", NS)
        icms = imp.find("n:ICMS/*", NS) if imp is not None else None
        itens.append(
            {
                "numero_item": int(det.get("nItem")),
                "codigo_produto": txt(prod, "n:cProd"),
                "descricao": txt(prod, "n:xProd"),
                "ncm": txt(prod, "n:NCM"),
                "cest": txt(prod, "n:CEST"),
                "cfop": txt(prod, "n:CFOP"),
                "unidade": txt(prod, "n:uCom"),
                "quantidade": num(prod, "n:qCom"),
                "valor_unitario": num(prod, "n:vUnCom"),
                "valor_total": num(prod, "n:vProd"),
                "valor_desconto": num(prod, "n:vDesc"),
                "valor_frete": num(prod, "n:vFrete"),
                "valor_outros": num(prod, "n:vOutro"),
                "valor_icms": num(icms, "n:vICMS"),
                "valor_st": num(icms, "n:vICMSST"),
                "valor_ipi": num(imp, "n:IPI/n:IPITrib/n:vIPI"),
            }
        )

    duplicatas = [
        {"numero": txt(d, "n:nDup"), "vencimento": txt(d, "n:dVenc"), "valor": num(d, "n:vDup")}
        for d in inf.findall("n:cobr/n:dup", NS)
    ]

    return {
        "chave_nfe": inf.get("Id", "")[3:],
        "numero": int(txt(ide, "n:nNF")),
        "serie": int(txt(ide, "n:serie") or 0),
        "modelo": txt(ide, "n:mod"),
        "data_emissao": txt(ide, "n:dhEmi"),
        "data_saida": txt(ide, "n:dhSaiEnt"),
        "natureza_operacao": txt(ide, "n:natOp"),
        "tipo_nf": int(txt(ide, "n:tpNF") or 1),
        "finalidade": int(txt(ide, "n:finNFe") or 1),
        "cfop_principal": itens[0]["cfop"] if itens else None,
        "emitente_cnpj": txt(emit, "n:CNPJ"),
        "emitente_nome": txt(emit, "n:xNome"),
        "destinatario_tipo": dest_tipo,
        "destinatario_documento": dest_doc,
        "destinatario_nome": txt(dest, "n:xNome"),
        "destinatario_ie": txt(dest, "n:IE"),
        "destinatario_email": txt(dest, "n:email"),
        "destinatario_municipio": txt(dest, "n:enderDest/n:xMun"),
        "destinatario_uf": txt(dest, "n:enderDest/n:UF"),
        "valor_produtos": num(tot, "n:vProd"),
        "valor_desconto": num(tot, "n:vDesc"),
        "valor_frete": num(tot, "n:vFrete"),
        "valor_seguro": num(tot, "n:vSeg"),
        "valor_outros": num(tot, "n:vOutro"),
        "valor_ipi": num(tot, "n:vIPI"),
        "valor_icms": num(tot, "n:vICMS"),
        "valor_st": num(tot, "n:vST"),
        "valor_total": num(tot, "n:vNF"),
        "forma_pagamento": txt(inf, "n:pag/n:detPag/n:tPag"),
        "modalidade_frete": int(txt(inf, "n:transp/n:modFrete") or 9),
        "informacoes_complementares": txt(inf, "n:infAdic/n:infCpl"),
        "protocolo": txt(prot, "n:nProt"),
        "data_autorizacao": txt(prot, "n:dhRecbto"),
        "status_sefaz": txt(prot, "n:cStat"),
        "arquivo_nome": arquivo.name,
        "xml": conteudo,
        "itens": itens,
        "duplicatas": duplicatas,
    }


def ler_evento(arquivo: Path, conteudo: str):
    raiz = ET.fromstring(conteudo)
    inf = raiz.find(".//n:evento/n:infEvento", NS)
    if inf is None:
        return None
    ret = raiz.find(".//n:retEvento/n:infEvento", NS)
    det = inf.find("n:detEvento", NS)
    return {
        "chave_nfe": txt(inf, "n:chNFe"),
        "tipo_evento": txt(inf, "n:tpEvento"),
        "descricao": txt(det, "n:descEvento"),
        "sequencia": int(txt(inf, "n:nSeqEvento") or 1),
        "data_evento": txt(inf, "n:dhEvento"),
        "correcao": txt(det, "n:xCorrecao"),
        "justificativa": txt(det, "n:xJust"),
        "protocolo": txt(ret, "n:nProt") or txt(det, "n:nProt"),
        "status_sefaz": txt(ret, "n:cStat"),
        "arquivo_nome": arquivo.name,
        "xml": conteudo,
    }


COLUNAS_NOTA = [
    "chave_nfe", "empresa_id", "numero", "serie", "modelo", "data_emissao", "data_saida",
    "natureza_operacao", "tipo_nf", "finalidade", "cfop_principal", "emitente_cnpj", "emitente_nome",
    "destinatario_tipo", "destinatario_documento", "destinatario_nome", "destinatario_ie",
    "destinatario_email", "destinatario_municipio", "destinatario_uf", "cliente_id", "valor_produtos",
    "valor_desconto", "valor_frete", "valor_seguro", "valor_outros", "valor_ipi", "valor_icms",
    "valor_st", "valor_total", "forma_pagamento", "modalidade_frete", "informacoes_complementares",
    "protocolo", "data_autorizacao", "status_sefaz", "arquivo_nome", "xml",
]
COLUNAS_ITEM = [
    "numero_item", "codigo_produto", "produto_id", "descricao", "ncm", "cest", "cfop", "unidade",
    "quantidade", "valor_unitario", "valor_total", "valor_desconto", "valor_frete", "valor_outros",
    "valor_icms", "valor_st", "valor_ipi",
]
COLUNAS_EVENTO = [
    "chave_nfe", "tipo_evento", "descricao", "sequencia", "data_evento", "correcao", "justificativa",
    "protocolo", "status_sefaz", "arquivo_nome", "xml",
]


def gravar_nota(cur, nota):
    cols = ", ".join(COLUNAS_NOTA)
    vals = ", ".join(f"%({c})s" for c in COLUNAS_NOTA)
    atualiza = ", ".join(f"{c} = excluded.{c}" for c in COLUNAS_NOTA if c != "chave_nfe")
    cur.execute(
        f"""insert into public.notas_fiscais_connect ({cols}) values ({vals})
            on conflict (chave_nfe) do update set {atualiza}, atualizado_em = now()
            returning id, (xmax = 0) as nova""",
        nota,
    )
    nota_id, nova = cur.fetchone()
    cur.execute("delete from public.notas_fiscais_connect_itens where nota_id = %s", (nota_id,))
    cur.execute("delete from public.notas_fiscais_connect_duplicatas where nota_id = %s", (nota_id,))
    for item in nota["itens"]:
        cur.execute(
            f"""insert into public.notas_fiscais_connect_itens (nota_id, {", ".join(COLUNAS_ITEM)})
                values (%(nota_id)s, {", ".join(f"%({c})s" for c in COLUNAS_ITEM)})""",
            {**item, "nota_id": nota_id},
        )
    for dup in nota["duplicatas"]:
        cur.execute(
            """insert into public.notas_fiscais_connect_duplicatas (nota_id, numero, vencimento, valor)
               values (%s, %s, %s, %s)""",
            (nota_id, dup["numero"], dup["vencimento"], dup["valor"]),
        )
    return nova


def gravar_evento(cur, evento):
    cols = ", ".join(COLUNAS_EVENTO)
    vals = ", ".join(f"%({c})s" for c in COLUNAS_EVENTO)
    atualiza = ", ".join(
        f"{c} = excluded.{c}" for c in COLUNAS_EVENTO if c not in ("chave_nfe", "tipo_evento", "sequencia")
    )
    cur.execute(
        f"""insert into public.notas_fiscais_connect_eventos ({cols}) values ({vals})
            on conflict (chave_nfe, tipo_evento, sequencia) do update set {atualiza}""",
        evento,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pasta", help="pasta com os XMLs (*.xml), inclusive subpastas")
    parser.add_argument("--aplicar", action="store_true", help="grava (sem isso, desfaz no fim)")
    args = parser.parse_args()

    arquivos = sorted(Path(args.pasta).rglob("*.xml"))
    if not arquivos:
        sys.exit(f"Nenhum XML em {args.pasta}")

    notas, eventos, ignorados = [], [], []
    chaves_vistas = {}
    for arq in arquivos:
        conteudo = arq.read_text(encoding="utf-8")
        try:
            raiz_tag = ET.fromstring(conteudo).tag.split("}")[-1]
        except ET.ParseError as e:
            ignorados.append((arq.name, f"XML inválido: {e}"))
            continue
        if raiz_tag in ("nfeProc", "NFe"):
            nota = ler_nota(arq, conteudo)
            if nota and nota["status_sefaz"] not in (None, "100", "150"):
                ignorados.append((arq.name, f"nota não autorizada (cStat {nota['status_sefaz']})"))
            elif nota and nota["chave_nfe"] in chaves_vistas:
                ignorados.append((arq.name, f"mesma nota de {chaves_vistas[nota['chave_nfe']]}"))
            elif nota:
                chaves_vistas[nota["chave_nfe"]] = arq.name
                notas.append(nota)
        elif raiz_tag == "procEventoNFe":
            evento = ler_evento(arq, conteudo)
            if evento:
                eventos.append(evento)
        else:
            ignorados.append((arq.name, f"tipo não reconhecido ({raiz_tag})"))

    conn = psycopg2.connect(SUPABASE_DB_URL)
    try:
        cur = conn.cursor()
        cur.execute("select regexp_replace(cnpj, '\\D', '', 'g'), id, nome from public.empresas where cnpj is not null")
        empresas = {cnpj: (eid, nome) for cnpj, eid, nome in cur.fetchall()}

        novas = atualizadas = 0
        sem_cliente = 0
        pecas_sem_cadastro = set()
        for nota in notas:
            empresa = empresas.get(nota["emitente_cnpj"])
            if not empresa:
                ignorados.append((nota["arquivo_nome"], "emitente não é empresa do grupo"))
                continue
            nota["empresa_id"] = empresa[0]

            nota["cliente_id"] = None
            if nota["destinatario_documento"]:
                cur.execute(
                    """select id from public.contatos
                       where regexp_replace(coalesce(nullif(cpf_cnpj, ''), nullif(cpf, ''), cnpj, ''), '\\D', '', 'g') = %s
                         and canonical_id is null
                       limit 2""",
                    (nota["destinatario_documento"],),
                )
                achados = cur.fetchall()
                if len(achados) == 1:
                    nota["cliente_id"] = achados[0][0]
            if not nota["cliente_id"]:
                sem_cliente += 1

            for item in nota["itens"]:
                item["produto_id"] = None
                if item["codigo_produto"] and item["codigo_produto"].isdigit():
                    cur.execute(
                        "select id from public.produtos where codigo_produto = %s limit 2",
                        (int(item["codigo_produto"]),),
                    )
                    achados = cur.fetchall()
                    if len(achados) == 1:
                        item["produto_id"] = achados[0][0]
                if not item["produto_id"]:
                    pecas_sem_cadastro.add(item["codigo_produto"])

            if gravar_nota(cur, nota):
                novas += 1
            else:
                atualizadas += 1

        for evento in eventos:
            # posições 7-20 da chave = CNPJ do emitente; evento de nota de terceiro (ex.: manifestação de
            # nota recebida) não entra
            if evento["chave_nfe"][6:20] not in empresas:
                ignorados.append((evento["arquivo_nome"], f"evento ({evento['descricao']}) de nota de outro emitente"))
                continue
            gravar_evento(cur, evento)

        # liga eventos às notas e marca as canceladas
        cur.execute(
            """update public.notas_fiscais_connect_eventos e set nota_id = n.id
               from public.notas_fiscais_connect n
               where n.chave_nfe = e.chave_nfe and e.nota_id is distinct from n.id"""
        )
        cur.execute(
            """update public.notas_fiscais_connect n
               set situacao = 'cancelada', cancelada_em = e.data_evento, atualizado_em = now()
               from public.notas_fiscais_connect_eventos e
               where e.nota_id = n.id and e.tipo_evento = %s and e.status_sefaz = any(%s)
                 and n.situacao <> 'cancelada'""",
            (CANCELAMENTO, list(EVENTO_HOMOLOGADO)),
        )
        canceladas = cur.rowcount

        # Mesma regra da tela do Vendas: soma só a nota de VENDA autorizada (CFOP de venda) e abate a
        # devolução de cliente autorizada (entrada 1201–1204/1410–1411 e 2xxx). O resto não soma.
        cur.execute(
            f"""select e.nome, to_char(n.data_emissao at time zone 'America/Sao_Paulo', 'YYYY-MM') mes,
                      count(*), count(*) filter (where n.situacao = 'cancelada'),
                      coalesce(sum(n.valor_total) filter (where n.situacao = 'autorizada' and n.cfop_principal ~ '{CFOP_VENDA}'), 0),
                      coalesce(sum(n.valor_total) filter (where n.situacao = 'autorizada' and n.cfop_principal ~ '{CFOP_DEVOLUCAO}'), 0)
               from public.notas_fiscais_connect n left join public.empresas e on e.id = n.empresa_id
               group by 1, 2 order by 1, 2"""
        )
        por_mes = cur.fetchall()
        cur.execute(
            """select count(*) from public.notas_fiscais_connect_eventos where nota_id is null"""
        )
        eventos_soltos = cur.fetchone()[0]
        cur.execute(
            f"""select count(*), count(*) filter (where situacao = 'cancelada'),
                      coalesce(sum(valor_total) filter (where situacao = 'autorizada' and cfop_principal ~ '{CFOP_VENDA}'), 0)
                      - coalesce(sum(valor_total) filter (where situacao = 'autorizada' and cfop_principal ~ '{CFOP_DEVOLUCAO}'), 0)
               from public.notas_fiscais_connect"""
        )
        total, total_canc, valor = cur.fetchone()

        print(f"XMLs lidos: {len(arquivos)}  (notas: {len(notas)}, eventos: {len(eventos)})")
        print(f"Notas novas: {novas}  atualizadas: {atualizadas}  canceladas agora: {canceladas}")
        print(f"Notas sem cliente vinculado (CPF/CNPJ não cadastrado ou repetido): {sem_cliente}")
        print(f"Códigos de peça sem cadastro em produtos: {len(pecas_sem_cadastro)}"
              + (f" -> {', '.join(sorted(p or '?' for p in pecas_sem_cadastro))}" if pecas_sem_cadastro else ""))
        for nome, motivo in ignorados:
            print(f"  IGNORADO {nome}: {motivo}")
        print("Por empresa e mês (emissão): notas / canceladas / vendas − devoluções = líquido")
        for emp, mes, qtd, canc, vend, dev in por_mes:
            print(f"  {emp} {mes}: {qtd:3d} / {canc} / R$ {vend:,.2f} − R$ {dev:,.2f} = R$ {vend - dev:,.2f}")
        if eventos_soltos:
            print(f"Eventos sem a nota correspondente importada: {eventos_soltos}")
        print(f"Na tabela agora: {total} notas ({total_canc} canceladas), vendas líquidas (vendas − devoluções) R$ {valor:,.2f}")

        if args.aplicar:
            conn.commit()
            print("GRAVADO.")
        else:
            conn.rollback()
            print("DRY-RUN: nada gravado (use --aplicar).")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
