"""
SPEC-125 — Importacao das fotos do showroom a partir do arquivo ODP/PPTX.

Fluxo (3 subcomandos, nesta ordem):

  1) extrair  — le o .odp/.pptx, salva 1 imagem "principal" por slide + todas as
                imagens do slide numa subpasta, e um slides.json com o texto de
                cada slide (nome da peca, quantidade, observacoes).

  2) match    — para cada slide, procura o produto correspondente em `produtos`
                (RPC buscar_produtos_fuzzy + fallback ILIKE). Gera um CSV de
                revisao humana: revisao_showroom.csv. NAO grava nada no banco.

  3) aplicar  — le o CSV ja revisado (coluna produto_id_confirmado preenchida),
                sobe a imagem principal de cada slide para o bucket de Storage
                `showroom-lucenera` e roda
                UPDATE produtos SET imagem_showroom_url = ... WHERE id = ...
                (usa --dry-run para simular). Requer a migration da SPEC-125 ja
                aplicada (coluna imagem_showroom_url + bucket).

Uso:
  python scripts/importar_fotos_showroom.py extrair \
      --arquivo "01-Documento/01 - Planilhas/LISTA DECORATIVOS DISPONIVEIS - SHOWROOM.odp" \
      --out scripts/_saida_showroom
  python scripts/importar_fotos_showroom.py match  --dir scripts/_saida_showroom
  python scripts/importar_fotos_showroom.py aplicar --dir scripts/_saida_showroom --dry-run

Depende de: stdlib (zipfile/xml), e para match/aplicar tambem de
scripts/_supabase_client.py (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY no .env da raiz).
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import zipfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Namespaces ODF (.odp) e OOXML (.pptx)
# ---------------------------------------------------------------------------
ODF_NS = {
    "office": "urn:oasis:names:tc:opendocument:xmlns:office:1.0",
    "draw": "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
    "xlink": "http://www.w3.org/1999/xlink",
    "presentation": "urn:oasis:names:tc:opendocument:xmlns:presentation:1.0",
    "svg": "urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0",
}

# A quantidade na lista do showroom quase sempre e o inteiro no INICIO do nome
# da peca: "1 PACO - OLE", "2 FROGO PENDENTE - CHUMBO". Anos de design ("©2000",
# "1962") e codigos ("CÓD 1370/4") NAO devem ser lidos como quantidade.
QTD_PREFIXO_RE = re.compile(r"^\s*(\d{1,3})\s+(?=[A-Za-zÀ-ÿ])")
QTY_ROTULADA_RE = re.compile(
    r"(?:qtd|quant|quantidade|estoque)\.?\s*[:\-]?\s*(\d{1,3})"
    r"|(\d{1,3})\s*(?:un|und|unid)\b",
    re.IGNORECASE,
)


# ---------------------------------------------------------------------------
# EXTRAIR
# ---------------------------------------------------------------------------
def _localname(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _text_of(el) -> str:
    return "".join(el.itertext())


def extrair_odp(zf: zipfile.ZipFile):
    import xml.etree.ElementTree as ET

    content = zf.read("content.xml")
    root = ET.fromstring(content)
    pages = root.findall(".//draw:page", ODF_NS)
    slides = []
    for idx, page in enumerate(pages, start=1):
        name_attr = page.get(f"{{{ODF_NS['draw']}}}name") or ""
        textos: list[str] = []
        imagens: list[str] = []
        for frame in page.iter():
            ln = _localname(frame.tag)
            if ln in ("text-box", "p", "span"):
                continue
            if ln == "frame":
                # texto do frame
                for tb in frame.iter():
                    if _localname(tb.tag) == "p":
                        t = _text_of(tb).strip()
                        if t:
                            textos.append(t)
                # imagens do frame
                for im in frame.iter():
                    if _localname(im.tag) == "image":
                        href = im.get(f"{{{ODF_NS['xlink']}}}href") or ""
                        if href:
                            imagens.append(href.lstrip("./"))
        # fallback: qualquer texto solto na pagina
        if not textos:
            for tb in page.iter():
                if _localname(tb.tag) == "p":
                    t = _text_of(tb).strip()
                    if t:
                        textos.append(t)
        slides.append(
            {
                "slide": idx,
                "nome_slide": name_attr,
                "textos": textos,
                "imagens": _dedupe(imagens),
            }
        )
    return slides


def extrair_pptx(zf: zipfile.ZipFile):
    import xml.etree.ElementTree as ET

    A = "http://schemas.openxmlformats.org/drawingml/2006/main"
    R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    slide_files = sorted(
        (n for n in zf.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n)),
        key=lambda n: int(re.search(r"(\d+)", n).group(1)),
    )
    slides = []
    for idx, sf in enumerate(slide_files, start=1):
        root = ET.fromstring(zf.read(sf))
        textos = []
        for p in root.iter(f"{{{A}}}p"):
            runs = "".join(t.text or "" for t in p.iter(f"{{{A}}}t"))
            if runs.strip():
                textos.append(runs.strip())
        rels_name = f"ppt/slides/_rels/{Path(sf).name}.rels"
        imagens = []
        if rels_name in zf.namelist():
            rroot = ET.fromstring(zf.read(rels_name))
            for rel in rroot:
                tgt = rel.get("Target", "")
                if "media/" in tgt:
                    imagens.append("ppt/" + tgt.replace("../", ""))
        slides.append(
            {"slide": idx, "nome_slide": "", "textos": textos, "imagens": _dedupe(imagens)}
        )
    return slides


def _dedupe(seq):
    seen, out = set(), []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def _pick_nome_qtd(textos: list[str]) -> tuple[str, str, int | None, str]:
    """Retorna (nome_bruto, nome_limpo, quantidade, observacoes).

    nome_bruto = 1a linha textual util (com o prefixo de quantidade, se houver).
    nome_limpo = sem o "N " do inicio (melhor pra casar com o catalogo).
    quantidade = inteiro do inicio do nome, senao qtd rotulada nas demais linhas.
    """
    nome_bruto = ""
    obs_partes: list[str] = []
    for t in textos:
        if not nome_bruto and len(t) >= 3 and not t.strip().isdigit():
            nome_bruto = t.strip()
            continue
        obs_partes.append(t.strip())

    qtd: int | None = None
    m = QTD_PREFIXO_RE.match(nome_bruto)
    if m:
        qtd = int(m.group(1))
    if qtd is None:
        for t in [nome_bruto, *obs_partes]:
            mm = QTY_ROTULADA_RE.search(t)
            if mm:
                qtd = int(next(g for g in mm.groups() if g))
                break

    nome_limpo = QTD_PREFIXO_RE.sub("", nome_bruto).strip()
    return nome_bruto, nome_limpo, qtd, " | ".join(p for p in obs_partes if p).strip()


def cmd_extrair(args):
    arq = Path(args.arquivo)
    if not arq.exists():
        sys.exit(f"Arquivo nao encontrado: {arq}")
    out = Path(args.out)
    (out / "imagens").mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(arq) as zf:
        names = set(zf.namelist())
        if "content.xml" in names:
            slides = extrair_odp(zf)
            fmt = "odp"
        elif any(n.startswith("ppt/slides/") for n in names):
            slides = extrair_pptx(zf)
            fmt = "pptx"
        else:
            sys.exit("Formato nao reconhecido (nem ODP nem PPTX).")

        registros = []
        for s in slides:
            nome_bruto, nome_limpo, qtd, obs = _pick_nome_qtd(s["textos"])
            slide_dir = out / "imagens" / f"slide_{s['slide']:03d}"
            principal_rel = ""
            if s["imagens"]:
                slide_dir.mkdir(parents=True, exist_ok=True)
                maior, maior_sz = None, -1
                for i, href in enumerate(s["imagens"]):
                    if href not in names:
                        continue
                    data = zf.read(href)
                    ext = Path(href).suffix or ".png"
                    dest = slide_dir / f"img_{i:02d}{ext}"
                    dest.write_bytes(data)
                    if len(data) > maior_sz:
                        maior, maior_sz = dest, len(data)
                if maior is not None:
                    principal = out / "imagens" / f"slide_{s['slide']:03d}{maior.suffix}"
                    principal.write_bytes(maior.read_bytes())
                    principal_rel = principal.relative_to(out).as_posix()
            registros.append(
                {
                    **s,
                    "nome_bruto": nome_bruto,
                    "nome_peca": nome_limpo,
                    "quantidade_ppt": qtd,
                    "observacoes": obs,
                    "imagem_principal": principal_rel,
                }
            )

    (out / "slides.json").write_text(
        json.dumps({"formato": fmt, "total_slides": len(registros), "slides": registros}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    com_img = sum(1 for r in registros if r["imagem_principal"])
    com_nome = sum(1 for r in registros if r["nome_peca"])
    print(f"[extrair] formato={fmt} slides={len(registros)} com_imagem={com_img} com_nome={com_nome}")
    print(f"[extrair] saida: {out/'slides.json'}  e  {out/'imagens'}/")


# ---------------------------------------------------------------------------
# MATCH
# ---------------------------------------------------------------------------
def _norm(s: str) -> str:
    import unicodedata

    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9 ]", " ", s.lower()).strip()


_STOP = {"de", "da", "do", "com", "para", "led", "e", "-", "1x", "2x", "3x"}


def _marca_do_nome(nome_bruto: str) -> str:
    partes = re.split(r"\s[-–]\s", nome_bruto)
    return partes[-1].strip() if len(partes) > 1 else ""


def _candidatos(termo: str, produtos: list[dict], k: int = 3) -> list[tuple[dict, float]]:
    toks = [t for t in _norm(termo).split() if t and t not in _STOP]
    if not toks:
        return []
    primeiro = toks[0]  # token mais distintivo (modelo da peca)
    pontuados = []
    for p in produtos:
        pt = set(p["_n"].split())
        if not pt:
            continue
        inter = len(set(toks) & pt)
        if inter == 0:
            continue
        sc = inter / len(set(toks) | pt)
        if primeiro in pt:
            sc += 0.5  # bonus forte se o modelo aparece no nome do produto
        pontuados.append((p, round(sc, 3)))
    pontuados.sort(key=lambda x: x[1], reverse=True)
    return pontuados[:k]


def cmd_match(args):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from _supabase_client import get_client  # type: ignore

    d = Path(args.dir)
    dados = json.loads((d / "slides.json").read_text(encoding="utf-8"))
    sb = get_client()

    produtos: list[dict] = []
    page = 0
    while True:
        resp = (
            sb.table("produtos")
            .select("id,nome,sku,referencia,codigo_produto,estoque_showroom,valor_venda,ativo")
            .eq("ativo", True)
            .range(page * 1000, page * 1000 + 999)
            .execute()
        )
        produtos.extend(resp.data or [])
        if not resp.data or len(resp.data) < 1000:
            break
        page += 1
    for p in produtos:
        p["_n"] = _norm(p["nome"])
    print(f"[match] {len(produtos)} produtos ativos carregados")

    linhas = []
    for s in dados["slides"]:
        nome_limpo = s.get("nome_peca") or ""
        nome_bruto = s.get("nome_bruto") or nome_limpo
        if not s.get("imagem_principal"):
            continue  # slides de divisoria de secao nao entram na vitrine

        cands = _candidatos(nome_limpo, produtos)
        # RPC fuzzy do proprio sistema como 4a opiniao
        rpc_cod = rpc_nome = ""
        try:
            r = sb.rpc(
                "buscar_produtos_fuzzy", {"p_termo": nome_limpo, "p_offset": 0, "p_limit": 1}
            ).execute()
            if r.data:
                rpc_cod = r.data[0].get("codigo_produto") or ""
                rpc_nome = r.data[0].get("nome") or ""
        except Exception as e:  # noqa: BLE001
            print(f"  rpc falhou slide {s['slide']}: {e}", file=sys.stderr)

        linha = {
            "slide": s["slide"],
            "ppt_nome": nome_bruto,
            "ppt_qtd": s.get("quantidade_ppt") or "",
            "marca_ppt": _marca_do_nome(nome_bruto),
            "observacoes": s.get("observacoes") or "",
            "imagem_principal": s.get("imagem_principal") or "",
        }
        for i in range(3):
            if i < len(cands):
                p, sc = cands[i]
                linha[f"cand{i + 1}_cod"] = p["codigo_produto"]
                linha[f"cand{i + 1}_nome"] = p["nome"]
                linha[f"cand{i + 1}_sh"] = p["estoque_showroom"]
                linha[f"cand{i + 1}_score"] = sc
            else:
                linha[f"cand{i + 1}_cod"] = linha[f"cand{i + 1}_nome"] = ""
                linha[f"cand{i + 1}_sh"] = linha[f"cand{i + 1}_score"] = ""
        linha["fuzzy_rpc_cod"] = rpc_cod
        linha["fuzzy_rpc_nome"] = rpc_nome
        # >>> coluna que o revisor humano preenche: codigo_produto (inteiro) <<<
        linha["codigo_confirmado"] = cands[0][0]["codigo_produto"] if cands and cands[0][1] >= 1.3 else ""
        linhas.append(linha)

    csv_path = d / "revisao_showroom.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(linhas[0].keys()))
        w.writeheader()
        w.writerows(linhas)
    pre = sum(1 for x in linhas if x["codigo_confirmado"])
    algum = sum(1 for x in linhas if x["cand1_cod"])
    print(f"[match] {len(linhas)} pecas c/ foto | {algum} com >=1 candidato | {pre} pre-preenchidas -> {csv_path}")
    print("[match] revise a coluna 'codigo_confirmado' (codigo_produto). Vazio = nao vai pra vitrine.")


# ---------------------------------------------------------------------------
# APLICAR
# ---------------------------------------------------------------------------
BUCKET = "showroom-lucenera"


def cmd_aplicar(args):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from _supabase_client import get_client, SUPABASE_URL  # type: ignore

    d = Path(args.dir)
    sb = get_client()
    rows = list(csv.DictReader((d / "revisao_showroom.csv").open(encoding="utf-8-sig")))
    aplicados = semeados = 0
    for row in rows:
        cod = (row.get("codigo_confirmado") or "").strip()
        img_rel = (row.get("imagem_principal") or "").strip()
        if not cod or not img_rel:
            continue
        try:
            cod_int = int(float(cod))
        except ValueError:
            print(f"  slide {row['slide']}: codigo_confirmado invalido ({cod!r})", file=sys.stderr)
            continue
        img_path = d / img_rel
        if not img_path.exists():
            print(f"  slide {row['slide']}: imagem sumiu ({img_rel})", file=sys.stderr)
            continue

        prod = (
            sb.table("produtos")
            .select("id,estoque_showroom")
            .eq("codigo_produto", cod_int)
            .limit(1)
            .execute()
            .data
        )
        if not prod:
            print(f"  slide {row['slide']}: nenhum produto com codigo_produto={cod_int}", file=sys.stderr)
            continue
        pid = prod[0]["id"]
        sh_atual = prod[0]["estoque_showroom"] or 0

        key = f"showroom/{cod_int}{img_path.suffix.lower()}"
        url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{key}"

        patch: dict = {"imagem_showroom_url": url}
        qtd_ppt = row.get("ppt_qtd") or ""
        if args.semear_estoque and sh_atual == 0 and str(qtd_ppt).strip().isdigit() and int(qtd_ppt) > 0:
            patch["estoque_showroom"] = int(qtd_ppt)

        if args.dry_run:
            extra = f" + estoque_showroom={patch['estoque_showroom']}" if "estoque_showroom" in patch else ""
            print(f"  [dry-run] slide {row['slide']}: {img_path.name} -> {key}{extra}")
            aplicados += 1
            semeados += "estoque_showroom" in patch
            continue

        with img_path.open("rb") as fh:
            sb.storage.from_(BUCKET).upload(
                key, fh.read(), {"content-type": _mime(img_path.suffix), "upsert": "true"}
            )
        sb.table("produtos").update(patch).eq("id", pid).execute()
        aplicados += 1
        semeados += "estoque_showroom" in patch
        print(f"  slide {row['slide']}: OK cod={cod_int}{' (estoque semeado)' if 'estoque_showroom' in patch else ''}")
    print(
        f"[aplicar] {aplicados} produto(s) {'simulados' if args.dry_run else 'atualizados'}"
        f" | {semeados} com estoque_showroom semeado"
    )


def _mime(suf: str) -> str:
    return {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(
        suf.lower(), "application/octet-stream"
    )


# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="SPEC-125 importacao de fotos do showroom")
    sub = ap.add_subparsers(dest="cmd", required=True)

    pe = sub.add_parser("extrair")
    pe.add_argument("--arquivo", required=True)
    pe.add_argument("--out", default="scripts/_saida_showroom")
    pe.set_defaults(func=cmd_extrair)

    pm = sub.add_parser("match")
    pm.add_argument("--dir", default="scripts/_saida_showroom")
    pm.set_defaults(func=cmd_match)

    pa = sub.add_parser("aplicar")
    pa.add_argument("--dir", default="scripts/_saida_showroom")
    pa.add_argument("--dry-run", action="store_true")
    pa.add_argument(
        "--semear-estoque",
        action="store_true",
        dest="semear_estoque",
        help="onde estoque_showroom=0, usa a quantidade da lista (ppt_qtd) como valor inicial",
    )
    pa.set_defaults(func=cmd_aplicar)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
