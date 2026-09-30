# -*- coding: utf-8 -*-
"""Figuras da matéria Máquinas Elétricas.

Placas de bornes: uma função desenha qualquer fechamento a partir de três
dados — a grade de terminais, as pontes (cadeias de terminais ligados) e em
quais terminais entra cada fase. Os fechamentos são os da apostila SENAI-DN
(2013, cap. 6 e Figuras 162-163), com L1-1, L2-2, L3-3.

Placa de identificação: um motor fictício, com números coerentes entre si
(P = √3·V·I·cosφ·η confere nas duas tensões), para os cartões de leitura de
placa. Não imita a placa de fabricante nenhum.
"""
import math
from desenho import Desenho, circuito, vista, VERDE

M = "maquinas-eletricas"


def _placa(titulo, grade, pontes, fases, alt):
    """grade: linhas de terminais; pontes: cadeias de terminais ligados entre
    si; fases: {'L1': terminal, ...} — onde a alimentação entra."""
    esp = 44
    x0, y0 = 90, 70
    larg = 2 * x0 + esp * (len(grade[0]) - 1) - 40
    alt_total = y0 + esp * (len(grade) - 1) + 70
    d = Desenho(max(larg, 220), alt_total, alt=alt)
    pos = {}
    for i, linha in enumerate(grade):
        for j, t in enumerate(linha):
            pos[t] = (x0 - 20 + j * esp, y0 + i * esp)
    xs = [p[0] for p in pos.values()]
    ys = [p[1] for p in pos.values()]
    with d.grupo("placa"):
        d.retangulo(min(xs) - 36, min(ys) - 22, max(xs) - min(xs) + 72, max(ys) - min(ys) + 58)
    for fase, t in fases.items():
        x, y = pos[t]
        with d.grupo("~" + fase):
            d.linha([(x, 18), (x, y - 11)])
            d.texto(x, 14, fase, tam=12, ancora="middle", negrito=True)
    col = lambda c: x0 - 20 + c * esp
    lin = lambda r: y0 + r * esp
    for cadeia in pontes:
        with d.grupo("ponte"):
            if cadeia[0] == "rota":
                # ponte longa com rota explícita, em unidades da grade (coluna,
                # linha): por fora da grade ou por um corredor livre. Reta ou
                # traçado automático cruzariam outra ponte, e cruzamento numa
                # placa de bornes é lido como ligação.
                _, a, b, pontos = cadeia
                pts = [(col(c), lin(r)) for c, r in pontos]
                (xa, ya), (xb, yb) = pos[a], pos[b]
                def borda(xc, yc, xo, yo):
                    dd = math.hypot(xo - xc, yo - yc)
                    return (xc + (xo - xc) / dd * 11, yc + (yo - yc) / dd * 11)
                d.linha([borda(xa, ya, *pts[0])] + pts + [borda(xb, yb, *pts[-1])], esp=2.5)
                continue
            for a, b in zip(cadeia, cadeia[1:]):
                (xa, ya), (xb, yb) = pos[a], pos[b]
                dist = math.hypot(xb - xa, yb - ya)
                assert dist <= esp * 1.5, f"ponte {a}-{b} longa demais: dê a rota explícita"
                ux, uy = (xb - xa) / dist, (yb - ya) / dist
                d.linha([(xa + ux * 11, ya + uy * 11), (xb - ux * 11, yb - uy * 11)], esp=2.5)
    for t, (x, y) in pos.items():
        with d.grupo(f"T{t}"):
            d.circulo(x, y, 11, preench="#fff")
            d.texto(x, y + 4, str(t), tam=11, ancora="middle", negrito=True)
    if titulo:
        d.texto(d.w / 2, alt_total - 8, titulo, tam=12, ancora="middle")
    return d


G6 = [[1, 2, 3], [4, 5, 6]]
G12 = [[1, 2, 3], [7, 8, 9], [4, 5, 6], [10, 11, 12]]
F123 = {"L1": 1, "L2": 2, "L3": 3}
FECH = {
    "6-triangulo": (G6, [("rota", 1, 6, [(-0.6, 0), (-0.6, 1.6), (2, 1.6)]), [2, 4], [3, 5]], "motor de 6 pontas: 1 ligado ao 6, 2 ao 4 e 3 ao 5"),
    "6-estrela": (G6, [[4, 5, 6]], "motor de 6 pontas: 4, 5 e 6 ligados entre si"),
    "12-duplo-triangulo": (G12, [[1, 7], ("rota", 7, 6, [(-0.6, 1), (-0.6, 3.6), (2.6, 3.6), (2.6, 2)]), [6, 12],
                                  [2, 8, 4, 10], [3, 9, 5, 11]],
                           "motor de 12 pontas: 1-7-6-12 juntos, 2-8-4-10 juntos e 3-9-5-11 juntos"),
    "12-duplo-estrela": (G12, [[1, 7], [2, 8], [3, 9], [4, 5, 6], [10, 11, 12]],
                         "motor de 12 pontas: 1-7, 2-8 e 3-9 juntos; 4-5-6 ligados entre si e 10-11-12 ligados entre si"),
    "12-triangulo": (G12, [("rota", 1, 12, [(-0.6, 0), (-0.6, 3.6), (2, 3.6)]),
                                            ("rota", 2, 10, [(0.5, 0), (0.5, 3)]),
                                            ("rota", 3, 11, [(1.5, 0), (1.5, 3)]),
                                            [4, 7], [5, 8], [6, 9]],
                     "motor de 12 pontas: 1-12, 2-10 e 3-11 juntos; pontes 4-7, 5-8 e 6-9"),
    "12-estrela": (G12, [[4, 7], [5, 8], [6, 9], [10, 11, 12]],
                   "motor de 12 pontas: pontes 4-7, 5-8 e 6-9; 10-11-12 ligados entre si"),
}
for _nome, (_g, _p, _desc) in FECH.items():
    circuito("placa-" + _nome)(
        (lambda g, p, desc: lambda: _placa(None, g, p, F123,
            f"Placa de bornes de um {desc}. L1 entra no 1, L2 no 2 e L3 no 3."))(_g, _p, _desc))
    vista(M, "placa-" + _nome, "placa-" + _nome)


# ---- placa de identificação (motor fictício, números coerentes) --------------

PLACA_ID = [
    ("tipo", "MOTOR DE INDUÇÃO TRIFÁSICO"),
    ("pot", "5 cv   3,7 kW"), ("freq", "60 Hz"),
    ("tensao", "220/380 V"), ("corrente", "13,8/8,0 A"),
    ("rpm", "1730 rpm"), ("fs", "FS 1,15"),
    ("ipin", "Ip/In 7,5"), ("cat", "Cat. N"),
    ("isol", "Isol. F"), ("ip", "IP55"),
    ("reg", "Reg. S1"), ("rend", "Rend. 85%"),
    ("cosfi", "cos φ 0,83"), ("lig", "Δ 220 V  /  Y 380 V"),
]


@circuito("placa-motor")
def placa_motor():
    d = Desenho(300, 222, alt="Placa de identificação de um motor de indução trifásico: 5 cv "
                "(3,7 kW), 60 Hz, 220/380 V, 13,8/8,0 A, 1730 rpm, FS 1,15, Ip/In 7,5, categoria N, "
                "isolamento classe F, IP55, regime S1, rendimento 85%, cos φ 0,83; ligação triângulo "
                "em 220 V e estrela em 380 V.")
    with d.grupo("moldura"):
        d.retangulo(10, 10, 280, 202)
    with d.grupo("tipo"):
        d.texto(150, 32, PLACA_ID[0][1], tam=12, ancora="middle", negrito=True)
    y = 58
    pares = PLACA_ID[1:-1]
    for i in range(0, len(pares), 2):
        for k, (cid, txt) in enumerate(pares[i:i + 2]):
            with d.grupo(cid):
                d.texto(24 + k * 140, y, txt, tam=13)
        y += 20
    with d.grupo("lig"):
        d.texto(150, y + 4, PLACA_ID[-1][1], tam=13, ancora="middle", negrito=True)
    return d


vista(M, "placa-motor", "placa-motor")
for _cid in ("rpm", "fs", "ipin", "ip", "isol", "reg", "cat"):
    vista(M, f"placa-motor-{_cid}", "placa-motor", destaque=[_cid])


# ---- inversão do sentido de rotação ----------------------------------------------

def _inversao(troca):
    d = Desenho(260, 200, alt="Rede L1, L2 e L3 ligada aos terminais U1, V1 e W1 de um motor "
                "trifásico" + (", com L1 e L3 trocadas entre si: L1 vai ao W1 e L3 ao U1."
                               if troca else ", na ordem: L1 no U1, L2 no V1 e L3 no W1."))
    xs = (90, 130, 170)
    ordem = (2, 1, 0) if troca else (0, 1, 2)
    for i, (y, f) in enumerate(zip((30, 46, 62), ("L1", "L2", "L3"))):
        d.barramento(y, 50, 220, f)
        xd = xs[ordem.index(i)]
        with d.grupo("~" + f):
            d.linha([(xs[i], y), (xs[i], 84), (xd, 108), (xd, 124)])
        d.no(xs[i], y, net=f)
    d.motor3(xs, 124, tag=None)
    return d


circuito("inversao-normal")(lambda: _inversao(False))
circuito("inversao-trocada")(lambda: _inversao(True))
vista(M, "inversao-normal", "inversao-normal")
vista(M, "inversao-trocada", "inversao-trocada")
