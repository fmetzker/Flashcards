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
vista(M, "inversao-trocada", "inversao-trocada")


# ---- enrolamento (bobina de máquina): arcos ao longo de um segmento ---------------

def _enrol(d, p0, p1, n=4, lado=1):
    """Bobina de transformador ou de campo: n arcos ao longo de p0→p1,
    abaulados para o lado 'lado' (+1/-1) da normal."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy * lado, ux * lado
    r = L / (2 * n)
    pts = []
    for i in range(n):
        cx, cy = x0 + ux * r * (2 * i + 1), y0 + uy * r * (2 * i + 1)
        for k in range(0, 13):
            t = math.pi * k / 12
            pts.append((cx - ux * r * math.cos(t) + nx * r * math.sin(t),
                        cy - uy * r * math.cos(t) + ny * r * math.sin(t)))
    d.linha(pts)


def _term(d, x, y, rot, dx=0, dy=0, ancora="middle"):
    d._add(f'<circle cx="{x}" cy="{y}" r="3" fill="{{c}}"/>', [(x - 3, y - 3), (x + 3, y + 3)])
    d.texto(x + dx, y + dy, rot, tam=11, ancora=ancora, negrito=True)


# ---- triângulo das potências (Franchi, Figura 3.2) --------------------------------

@circuito("triangulo-potencias")
def triangulo_potencias():
    d = Desenho(300, 190, alt="Triângulo das potências: a potência ativa P (kW) é o cateto "
                "horizontal, a reativa Q (kvar) é o cateto vertical e a aparente S (kVA) é a "
                "hipotenusa; φ é o ângulo entre P e S.")
    A, B, C = (40, 160), (240, 160), (240, 45)
    with d.grupo("P"):
        d.linha([A, B], esp=3)
        d.texto(140, 180, "P (kW)", tam=13, ancora="middle", negrito=True)
    with d.grupo("Q"):
        d.linha([B, C], esp=3)
        d.texto(248, 106, "Q (kvar)", tam=13, negrito=True)
    with d.grupo("S"):
        d.linha([A, C], esp=3)
        d.texto(118, 92, "S (kVA)", tam=13, ancora="middle", negrito=True)
    with d.grupo("phi"):
        ang = math.atan2(C[1] - A[1], C[0] - A[0])
        d.linha([(A[0] + 44 * math.cos(ang * k / 10), A[1] + 44 * math.sin(ang * k / 10)) for k in range(11)])
        d.texto(92, 152, "φ", tam=15, ancora="middle", negrito=True)
    with d.grupo("reto"):
        d.linha([(228, 160), (228, 148), (240, 148)], esp=1.5)
    return d


vista(M, "triangulo-potencias", "triangulo-potencias")
for _g in ("P", "Q", "S"):
    vista(M, f"triangulo-potencias-{_g.lower()}", "triangulo-potencias", destaque=[_g])


@circuito("correcao-fp")
def correcao_fp():
    d = Desenho(300, 200, alt="Correção do fator de potência: a mesma potência ativa P (cateto "
                "horizontal) com duas potências reativas. Antes, Q1 (maior) e ângulo φ1; depois "
                "de instalar capacitores, Q2 (menor) e ângulo φ2, menor que φ1. O trecho entre Q1 "
                "e Q2 é a potência reativa Qc fornecida pelos capacitores.")
    A, B = (40, 170), (240, 170)
    C1, C2 = (240, 40), (240, 110)
    with d.grupo("P"):
        d.linha([A, B], esp=3)
        d.texto(140, 190, "P (kW)", tam=13, ancora="middle", negrito=True)
    with d.grupo("Q2"):
        d.linha([B, C2], esp=3)
        d.texto(248, 146, "Q2", tam=13, negrito=True)
    with d.grupo("Qc"):
        d.linha([C2, C1], esp=3, tracejado="6 4")
        d.texto(248, 80, "Qc", tam=13, negrito=True)
    with d.grupo("S1"):
        d.linha([A, C1], esp=2)
        d.texto(112, 90, "S1", tam=13, ancora="middle", negrito=True)
    with d.grupo("S2"):
        d.linha([A, C2], esp=2)
        d.texto(172, 142, "S2", tam=13, ancora="middle", negrito=True)
    with d.grupo("phi"):
        for C, r, rot, (tx, ty) in ((C1, 60, "φ1", (106, 144)), (C2, 36, "φ2", (86, 164))):
            ang = math.atan2(C[1] - A[1], C[0] - A[0])
            d.linha([(A[0] + r * math.cos(ang * k / 10), A[1] + r * math.sin(ang * k / 10)) for k in range(11)], esp=1.5)
            d.texto(tx, ty, rot, tam=12, ancora="middle", negrito=True)
    return d


vista(M, "correcao-fp-qc", "correcao-fp", destaque=["Qc"])


# ---- transformador monofásico com primário de 4 fios (SENAI 5.2.1, Figs. 79-80) --

def _trafo4(ligacao):
    desc = {"paralelo": "as duas bobinas primárias em paralelo: I1 ligado ao I2 e F1 ligado ao F2, "
                        "com a entrada entre I1 e F1",
            "serie": "as duas bobinas primárias em série: F1 ligado ao I2, com a entrada entre I1 e F2",
            "errada": "as duas bobinas primárias em série, mas com F1 ligado ao F2 e a entrada entre I1 e I2"}
    d = Desenho(300, 230, alt="Transformador monofásico com primário de quatro fios: duas bobinas "
                "de 110 V (início I1/fim F1 e início I2/fim F2) e um secundário. Ligação com "
                + desc[ligacao] + ".")
    xa, xb, xs = 100, 160, 250
    ytop, ybot = 70, 160
    for x, i in ((xa, "1"), (xb, "2")):
        with d.grupo(f"B{i}"):
            d.linha([(x, ytop), (x, ytop + 10)])
            _enrol(d, (x, ytop + 10), (x, ybot - 10), n=4, lado=-1)
            d.linha([(x, ybot - 10), (x, ybot)])
        with d.grupo(f"T{i}"):
            _term(d, x, ytop, f"I{i}", dx=14, dy=-4)
            _term(d, x, ybot, f"F{i}", dx=14, dy=12)
    with d.grupo("nucleo"):
        d.linha([(196, 60), (196, 170)], esp=2)
        d.linha([(204, 60), (204, 170)], esp=2)
    with d.grupo("sec"):
        d.linha([(xs, ytop), (xs, ytop + 10)])
        _enrol(d, (xs, ytop + 10), (xs, ybot - 10), n=4, lado=1)
        d.linha([(xs, ybot - 10), (xs, ybot)])
        d.linha([(xs, ytop), (280, ytop)])
        d.linha([(xs, ybot), (280, ybot)])
        d.texto(xs, 196, "saída", tam=12, ancora="middle")
    with d.grupo("entrada"):
        d.texto(30, 20, "entrada", tam=12)
    ea, eb = (xa, "topo"), None
    with d.grupo("ponte"):
        if ligacao == "paralelo":
            d.linha([(xa, ytop), (xa, 45), (xb, 45), (xb, ytop)], esp=2.5)
            d.linha([(xa, ybot), (xa, 185), (xb, 185), (xb, ybot)], esp=2.5)
        elif ligacao == "serie":
            d.linha([(xa, ybot), (xa, 185), (130, 185), (130, 45), (xb, 45), (xb, ytop)], esp=2.5)
        else:
            d.linha([(xa, ybot), (xa, 185), (xb, 185), (xb, ybot)], esp=2.5)
    with d.grupo("~rede"):
        d.linha([(30, 30), (xa, 30), (xa, 45 if ligacao == "paralelo" else ytop)])
        if ligacao == "paralelo":
            d.linha([(30, 210), (xa, 210), (xa, 185)])
            d.no(xa, 45)
            d.no(xa, 185)
        elif ligacao == "serie":
            d.linha([(30, 210), (xb, 210), (xb, ybot)])
        else:
            d.linha([(30, 210), (180, 210), (180, 56), (xb, 56), (xb, ytop)])
    return d


for _lig in ("paralelo", "serie", "errada"):
    circuito(f"trafo4-{_lig}")((lambda l: lambda: _trafo4(l))(_lig))
    vista(M, f"trafo4-{_lig}", f"trafo4-{_lig}")


# ---- transformador trifásico: fechamentos Δ/Y e Y/Δ (SENAI Quadro 12, Figs. 83-84) --

def _tri3(d, cx, cy, tipo, rot):
    """Três bobinas em triângulo ou estrela, centradas em (cx, cy)."""
    R = 46
    vert = [(cx + R * math.cos(math.radians(a)), cy - R * math.sin(math.radians(a))) for a in (90, 210, 330)]
    with d.grupo(rot):
        if tipo == "D":
            for a, b in zip(vert, vert[1:] + vert[:1]):
                mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                ux, uy = b[0] - a[0], b[1] - a[1]
                p0 = (mx - ux * 0.3, my - uy * 0.3)
                p1 = (mx + ux * 0.3, my + uy * 0.3)
                d.linha([a, p0]); _enrol(d, p0, p1, n=3, lado=-1); d.linha([p1, b])
            pontas = vert
        else:
            pontas = []
            for v in vert:
                ux, uy = v[0] - cx, v[1] - cy
                p0 = (cx + ux * 0.25, cy + uy * 0.25)
                p1 = (cx + ux * 0.85, cy + uy * 0.85)
                d.linha([(cx, cy), p0]); _enrol(d, p0, p1, n=3, lado=1); d.linha([p1, v])
                pontas.append(v)
            d._add(f'<circle cx="{cx}" cy="{cy}" r="3" fill="{{c}}"/>', [(cx - 3, cy - 3), (cx + 3, cy + 3)])
    return pontas


def _trafo3(prim, sec, vin, vout):
    nome = {"D": "triângulo", "Y": "estrela"}
    d = Desenho(320, 190, alt=f"Transformador trifásico com cada bobina de 220 V: primário (entrada) "
                f"ligado em {nome[prim]} e alimentado com {vin}; secundário (saída) ligado em "
                f"{nome[sec]}" + (f", fornecendo {vout}." if vout else ", com a tensão de saída a descobrir."))
    pe = _tri3(d, 80, 100, prim, "prim")
    ps = _tri3(d, 240, 100, sec, "sec")
    with d.grupo("nucleo"):
        d.linha([(156, 40), (156, 160)], esp=2)
        d.linha([(164, 40), (164, 160)], esp=2)
    with d.grupo("vin"):
        d.texto(80, 180, f"entrada {vin}", tam=12, ancora="middle", negrito=True)
    with d.grupo("vout"):
        d.texto(240, 180, f"saída {vout}" if vout else "saída ?", tam=12, ancora="middle", negrito=True)
    with d.grupo("bob"):
        d.texto(160, 20, "cada bobina: 220 V", tam=11, ancora="middle")
    return d


circuito("trafo3-dy")(lambda: _trafo3("D", "Y", "220 V", None))
circuito("trafo3-yd")(lambda: _trafo3("Y", "D", "380 V", None))
vista(M, "trafo3-dy", "trafo3-dy")
vista(M, "trafo3-yd", "trafo3-yd")


# ---- motor de corrente contínua: ligações do campo (SENAI 6.2.2, Figs. 106-110) ---

def _motor_cc(lig):
    desc = {"serie": "campo série S1-S2 em série com a armadura A1-A2, entre o + e o −",
            "paralelo": "campo paralelo F1-F2 ligado em paralelo com a armadura A1-A2, os dois entre o + e o −",
            "composto": "campo série S1-S2 em série com a armadura e campo paralelo F1-F2 em paralelo com o conjunto, entre o + e o −",
            "independente": "armadura A1-A2 entre o + e o − de uma fonte, e campo F1-F2 alimentado por outra fonte, separada",
            "ima": "motor de ímã permanente: só os terminais A1 e A2 da armadura, ligados ao + e ao −"}
    d = Desenho(300, 240, alt="Motor de corrente contínua: " + desc[lig] + ".")
    xa, yc, r = 200, 160, 22
    with d.grupo("fonte"):
        d.texto(26, 34, "+", tam=16, negrito=True)
        d.texto(26, 226, "−", tam=16, negrito=True)
        d.linha([(40, 30), (270, 30)])
        d.linha([(40, 220), (270, 220)])
    with d.grupo("arm"):
        d.circulo(xa, yc, r)
        d.texto(xa, yc + 5, "M", tam=14, ancora="middle", negrito=True)
        _term(d, xa, yc - r, "A1", dx=10, dy=-2, ancora="start")
        _term(d, xa, yc + r, "A2", dx=10, dy=12, ancora="start")
        d.linha([(xa, yc + r), (xa, 220)])
    if lig in ("serie", "composto"):
        with d.grupo("S"):
            _term(d, xa, 50, "S1", dx=10, dy=4, ancora="start")
            _enrol(d, (xa, 56), (xa, 104), n=4, lado=1)
            _term(d, xa, 110, "S2", dx=10, dy=4, ancora="start")
        d.linha([(xa, 30), (xa, 50)])
        d.linha([(xa, 110), (xa, yc - r)])
    else:
        d.linha([(xa, 30), (xa, yc - r)])
    if lig in ("paralelo", "composto"):
        xf = 110
        with d.grupo("F"):
            _term(d, xf, 90, "F1", dx=-10, dy=4, ancora="end")
            _enrol(d, (xf, 96), (xf, 164), n=5, lado=-1)
            _term(d, xf, 170, "F2", dx=-10, dy=4, ancora="end")
        d.linha([(xf, 30), (xf, 90)])
        d.linha([(xf, 170), (xf, 220)])
    if lig == "independente":
        xf = 110
        with d.grupo("F"):
            d.retangulo(50, 64, 110, 136, esp=1.5)
            d.texto(105, 80, "outra fonte", tam=10, ancora="middle")
            d.texto(62, 108, "+", tam=14, negrito=True)
            d.texto(62, 176, "−", tam=14, negrito=True)
            _term(d, xf, 104, "F1", dx=10, dy=4, ancora="start")
            _enrol(d, (xf, 110), (xf, 164), n=4, lado=-1)
            _term(d, xf, 170, "F2", dx=10, dy=4, ancora="start")
            d.linha([(76, 104), (xf, 104)])
            d.linha([(76, 170), (xf, 170)])
    return d


for _lig in ("serie", "paralelo", "composto", "independente", "ima"):
    circuito(f"motor-cc-{_lig}")((lambda l: lambda: _motor_cc(l))(_lig))
    vista(M, f"motor-cc-{_lig}", f"motor-cc-{_lig}")
