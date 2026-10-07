"""
Biblioteca compartilhada pelo ciclo de sincronizacao Connect
(importar_contas_pagar_receber.py, importar_pedido_compra.py,
importar_produtos_estoque.py, importar_produtos_novos.py).

Centraliza o que a SPEC-157 (03-Projeto/Planos de Ação/SPECs/SPEC-157_...)
exige em todo modulo:
  - descoberta automatica do arquivo mais recente (sem editar constante de
    caminho a cada exportacao nova);
  - pre-validacoes obrigatorias (cabecalho, minimo de linhas, unicidade da
    chave natural DENTRO da planilha) que abortam a importacao SEM tocar no
    banco quando falham;
  - relatorio estruturado por modulo (inseridos/atualizados/removidos ou
    inativados/ignorados/erros) com timestamp, e log em arquivo.

Cada script mantem sua propria logica de negocio (resolucao de negociacao,
triggers de preco, header+staging de pedido_compra etc.) — este modulo so
padroniza as etapas em volta dela.
"""

from __future__ import annotations

import glob
import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = ROOT / "scripts" / "logs" / "sync_connect"


class ImportacaoAbortada(Exception):
    """Levantada por uma pre-validacao que falhou. O caller NAO deve tocar no banco."""


def descobrir_planilha_mais_recente(pasta: Path, prefixo: str, sufixo: str = ".xlsx") -> Path:
    """Encontra o arquivo `<prefixo>*<sufixo>` mais recente em `pasta`.

    "Mais recente" = maior nome de arquivo (as exportacoes usam
    `Prefixo_AAAA-MM-DD.xlsx`, entao ordenar por string == ordenar por data).
    Evita ter que bumpar constante de caminho manualmente a cada exportacao
    nova (exigido no ciclo documentado em scripts/AGENTS.md).
    """

    candidatos = sorted(glob.glob(str(pasta / f"{prefixo}*{sufixo}")))
    if not candidatos:
        raise ImportacaoAbortada(
            f"Nenhum arquivo '{prefixo}*{sufixo}' encontrado em {pasta}. "
            "Confirme se a planilha foi exportada para essa pasta."
        )
    return Path(candidatos[-1])


def validar_cabecalho(colunas_planilha: list[str], colunas_esperadas: list[str], origem: str) -> None:
    """Verifica que as colunas esperadas existem na planilha.

    So checa PRESENCA, nao posicao/ordem -- todo carregar_planilha() deste
    ciclo seleciona coluna por NOME (`df["nome_da_coluna"]`), nunca por
    posicao, entao o Connect e' livre pra reordenar colunas no export sem
    quebrar nada (confirmado 2026-09-22: ContaPagar mudou a ordem entre
    cod_duplicata/cod_itens_duplicata numa exportacao real durante o
    desenvolvimento desta validacao). O que aborta e' coluna esperada
    FALTANDO ou a planilha vindo com layout/aba errada.
    """

    presentes = set(colunas_planilha)
    faltando = [c for c in colunas_esperadas if c not in presentes]
    if faltando:
        raise ImportacaoAbortada(
            f"[{origem}] Cabecalho incompativel — colunas esperadas ausentes: {faltando}. "
            "A planilha pode ter mudado de layout ou vir truncada. Importacao abortada, banco NAO foi tocado."
        )


def validar_minimo_linhas(n_linhas: int, minimo: int, origem: str) -> None:
    """Piso de seguranca contra exportacao vazia/truncada — NUNCA usado como
    expectativa de volume (volume real varia mes a mes com o estado das obras).
    """

    if n_linhas < minimo:
        raise ImportacaoAbortada(
            f"[{origem}] Planilha tem {n_linhas} linha(s), abaixo do minimo de seguranca "
            f"({minimo}). Isso indica exportacao vazia ou truncada — NUNCA usar essa planilha "
            "para sincronizar (apagaria/inativaria dados validos). Importacao abortada, banco NAO foi tocado."
        )


def validar_chave_unica(df: pd.DataFrame, colunas_chave: list[str], origem: str) -> None:
    """count(*) == count(distinct chave) na PROPRIA planilha. Se a planilha
    violar isso, a chave esta errada ou a exportacao tem problema — abortar.
    """

    total = len(df)
    distintos = df.drop_duplicates(subset=colunas_chave).shape[0]
    if distintos != total:
        chave_dup = (
            df[df.duplicated(subset=colunas_chave, keep=False)]
            .sort_values(colunas_chave)[colunas_chave]
            .drop_duplicates()
            .head(10)
            .to_dict("records")
        )
        raise ImportacaoAbortada(
            f"[{origem}] Chave natural {colunas_chave} NAO e unica na planilha "
            f"({total} linhas, {distintos} chaves distintas). Exemplos duplicados: {chave_dup}. "
            "A chave esta errada ou a exportacao esta com problema. Importacao abortada, banco NAO foi tocado."
        )


@dataclass
class RelatorioModulo:
    """Contadores de uma execucao de um modulo, para o resumo final legivel
    pelo gestor e para o log em arquivo."""

    nome: str
    arquivo_origem: str = ""
    iniciado_em: datetime = field(default_factory=datetime.now)
    finalizado_em: datetime | None = None
    inseridos: int = 0
    atualizados: int = 0
    removidos: int = 0
    inativados: int = 0
    cancelados: int = 0
    reativados: int = 0
    ignorados: int = 0
    erros: list[str] = field(default_factory=list)
    abortado: str | None = None  # motivo, se a pre-validacao abortou

    def finalizar(self) -> None:
        self.finalizado_em = datetime.now()

    def registrar_erro(self, mensagem: str) -> None:
        self.erros.append(mensagem)

    def to_dict(self) -> dict:
        return {
            "nome": self.nome,
            "arquivo_origem": self.arquivo_origem,
            "iniciado_em": self.iniciado_em.isoformat(timespec="seconds"),
            "finalizado_em": self.finalizado_em.isoformat(timespec="seconds") if self.finalizado_em else None,
            "inseridos": self.inseridos,
            "atualizados": self.atualizados,
            "removidos": self.removidos,
            "inativados": self.inativados,
            "cancelados": self.cancelados,
            "reativados": self.reativados,
            "ignorados": self.ignorados,
            "erros": self.erros,
            "abortado": self.abortado,
        }

    def imprimir(self) -> None:
        print(f"\n=== RESUMO [{self.nome}] — {self.arquivo_origem} ===")
        if self.abortado:
            print(f"  ABORTADO: {self.abortado}")
            return
        print(f"  Inseridos:   {self.inseridos}")
        print(f"  Atualizados: {self.atualizados}")
        if self.removidos:
            print(f"  Removidos (delete fisico): {self.removidos}")
        if self.inativados:
            print(f"  Inativados (soft delete):  {self.inativados}")
        if self.reativados:
            print(f"  Reativados:                {self.reativados}")
        if self.cancelados:
            print(f"  Cancelados (status_pago=2): {self.cancelados}")
        print(f"  Ignorados:   {self.ignorados}")
        print(f"  Erros:       {len(self.erros)}")
        for e in self.erros[:10]:
            print(f"    - {e}")
        dur = (self.finalizado_em - self.iniciado_em).total_seconds() if self.finalizado_em else None
        if dur is not None:
            print(f"  Duracao: {dur:.1f}s")


def salvar_log(relatorios: list[RelatorioModulo], dry_run: bool) -> Path:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = LOG_DIR / f"sync_connect_{ts}{'_dryrun' if dry_run else ''}.json"
    payload = {
        "executado_em": datetime.now().isoformat(timespec="seconds"),
        "dry_run": dry_run,
        "modulos": [r.to_dict() for r in relatorios],
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def imprimir_resumo_final(relatorios: list[RelatorioModulo], dry_run: bool, log_path: Path | None = None) -> None:
    print("\n" + "=" * 60)
    print("RESUMO FINAL DO CICLO DE SINCRONIZACAO CONNECT")
    print("=" * 60)
    print(f"Modo: {'DRY-RUN (nada foi gravado)' if dry_run else 'GRAVACAO REAL'}")
    for r in relatorios:
        status = "ABORTADO" if r.abortado else ("COM ERROS" if r.erros else "OK")
        print(f"  [{status:9s}] {r.nome}")
    if log_path:
        print(f"\nLog detalhado salvo em: {log_path}")
