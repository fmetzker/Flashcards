# -*- coding: utf-8 -*-
"""Figuras da matéria Matemática.

Frações representadas por figura (Anexo III do PS CFAQ-MOC/MOM, item VI:
"escrever frações representadas por gráficos de onde possam ser deduzidos o
numerador e o denominador") e um gráfico de barras para leitura de dados.

Dois moldes servem a qualquer fração: grade (linhas × colunas de partes
iguais) e círculo em setores iguais. Uma fração nova é uma linha:
    circuito("fr-...")(lambda: _grade(...)); vista(M, "fr-...", "fr-...")
"""
import math
from desenho import Desenho, circuito, vista

M = "matematica"
PINTA = "#7fa8d6"      # parte pintada: azul médio, legível em fundo branco


def _celula(d, x, y, w, h, pintada):
    d._add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{PINTA if pintada else "#fff"}" '
           f'stroke="{{c}}" stroke-width="2"/>', [(x, y), (x + w, y + h)])


def _grade(linhas, colunas, pintadas, inteiros=1, alt_extra=""):
    """`inteiros` grades iguais lado a lado; `pintadas` conta da esquerda para
    a direita, linha a linha, atravessando as grades em ordem."""
    cel = 34 if colunas * inteiros <= 8 else 26
    gw, gh = colunas * cel, linhas * cel
    vao = 24
    d = Desenho(40 + inteiros * gw + (inteiros - 1) * vao, 40 + gh,
                alt=(f"{inteiros} figuras iguais, cada uma" if inteiros > 1 else "Uma figura")
                + f" dividida em {linhas * colunas} partes iguais ({linhas} × {colunas}); "
                f"{pintadas} parte(s) pintada(s) no total." + alt_extra)
    k = 0
    for g in range(inteiros):
        x0 = 20 + g * (gw + vao)
        with d.grupo(f"g{g}"):
            for i in range(linhas):
                for j in range(colunas):
                    _celula(d, x0 + j * cel, 20 + i * cel, cel, cel, k < pintadas)
                    k += 1
    return d


def _setores(n, pintadas, alt_extra=""):
    r, cx, cy = 70, 90, 90
    d = Desenho(180, 180, alt=f"Um círculo dividido em {n} setores iguais; {pintadas} setor(es) "
                f"pintado(s)." + alt_extra)
    for i in range(n):
        a0, a1 = -math.pi / 2 + 2 * math.pi * i / n, -math.pi / 2 + 2 * math.pi * (i + 1) / n
        pts = [(cx, cy)] + [(cx + r * math.cos(a0 + (a1 - a0) * k / 12),
                             cy + r * math.sin(a0 + (a1 - a0) * k / 12)) for k in range(13)]
        caminho = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        d._add(f'<polygon points="{caminho}" fill="{PINTA if i < pintadas else "#fff"}" '
               f'stroke="{{c}}" stroke-width="2" stroke-linejoin="round"/>', pts)
    return d


# ---- frações por figura ---------------------------------------------------------

circuito("fr-grade-3-8")(lambda: _grade(1, 8, 3))
vista(M, "fr-grade-3-8", "fr-grade-3-8")

circuito("fr-setor-5-6")(lambda: _setores(6, 5))
vista(M, "fr-setor-5-6", "fr-setor-5-6")

circuito("fr-grade-6-12")(lambda: _grade(3, 4, 6))
vista(M, "fr-grade-6-12", "fr-grade-6-12")

circuito("fr-impropria-7-4")(lambda: _grade(1, 4, 7, inteiros=2,
                                            alt_extra=" Cada figura é um inteiro."))
vista(M, "fr-impropria-7-4", "fr-impropria-7-4")


@circuito("fr-equivalentes")
def fr_equivalentes():
    d = Desenho(320, 150, alt="Duas figuras do mesmo tamanho, cada uma é um inteiro. A de cima "
                "está dividida em 2 partes iguais, com 1 pintada; a de baixo está dividida em 8 "
                "partes iguais, com 4 pintadas.")
    for j in range(2):
        _celula(d, 20 + j * 140, 20, 140, 40, j < 1)
    for j in range(8):
        _celula(d, 20 + j * 35, 90, 35, 40, j < 4)
    return d


vista(M, "fr-equivalentes", "fr-equivalentes")


# ---- gráfico de barras (leitura de dados) ---------------------------------------

PESCADO = [("jan", 40), ("fev", 25), ("mar", 35), ("abr", 50), ("mai", 30)]


@circuito("barras-pescado")
def barras_pescado():
    d = Desenho(320, 240, alt="Gráfico de barras: toneladas de pescado desembarcadas num porto "
                "por mês. Janeiro 40, fevereiro 25, março 35, abril 50 e maio 30 toneladas. "
                "Eixo vertical de 0 a 50, de 10 em 10.")
    X0, Y0, H = 50, 200, 160
    fy = lambda v: Y0 - v / 50 * H
    with d.grupo("eixos"):
        d.linha([(X0, Y0 - H - 8), (X0, Y0), (X0 + 250, Y0)])
        for v in range(0, 51, 10):
            d.linha([(X0 - 4, fy(v)), (X0 + 250, fy(v))], esp=0.6, cor="#c8d0d8")
            d.texto(X0 - 8, fy(v) + 4, str(v), tam=10, ancora="end")
        d.texto(X0 - 10, Y0 - H - 14, "toneladas", tam=11)
    for i, (mes, v) in enumerate(PESCADO):
        x = X0 + 18 + i * 46
        with d.grupo(mes):
            d._add(f'<rect x="{x}" y="{fy(v):.1f}" width="30" height="{Y0 - fy(v):.1f}" '
                   f'fill="{PINTA}" stroke="{{c}}" stroke-width="1.5"/>', [(x, fy(v)), (x + 30, Y0)])
            d.texto(x + 15, Y0 + 16, mes, tam=11, ancora="middle")
    return d


vista(M, "barras-pescado", "barras-pescado")
