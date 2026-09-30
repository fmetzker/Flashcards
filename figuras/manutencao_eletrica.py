# -*- coding: utf-8 -*-
"""Figuras da matéria Manutenção Elétrica.

Instrumentos ligados ao circuito (TC com amperímetro, TP com voltímetro,
megômetro num motor) e o gráfico de tendência de corrente do caso do motor
M1 (SENAI-DN, 2013, cap. 14). Os números seguem o texto da apostila; o
desenho é nosso, não recorte dela.
"""
import math
from desenho import Desenho, circuito, vista

M = "manutencao-eletrica"


def _enrol(d, p0, p1, n=4, lado=1):
    """Bobina: n arcos ao longo de p0→p1 (mesmo desenho de Máquinas)."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy * lado, ux * lado
    r = L / (2 * n)
    pts = []
    for i in range(n):
        cx, cy = x0 + ux * r * (2 * i + 1), y0 + uy * r * (2 * i + 1)
        for k in range(13):
            t = math.pi * k / 12
            pts.append((cx - ux * r * math.cos(t) + nx * r * math.sin(t),
                        cy - uy * r * math.cos(t) + ny * r * math.sin(t)))
    d.linha(pts)


def _ponto(d, x, y):
    d._add(f'<circle cx="{x}" cy="{y}" r="3" fill="{{c}}"/>', [(x - 3, y - 3), (x + 3, y + 3)])


# ---- TC com amperímetro (SENAI 11.2, Figura 203) ----------------------------------

@circuito("tc-amperimetro")
def tc_amperimetro():
    d = Desenho(300, 210, alt="Transformador de corrente (TC) de relação 50/5 A: o condutor da "
                "fase L1, que vai ao motor, atravessa o núcleo do TC (primário, K-L); o secundário "
                "(k-l) é ligado por dois fios a um amperímetro de painel com entrada de 5 A e escala "
                "de 0 a 50 A.")
    with d.grupo("~L1"):
        d.linha([(20, 60), (280, 60)], esp=3)
        d.texto(20, 50, "L1", tam=12, negrito=True)
        d.texto(280, 50, "ao motor", tam=11, ancora="end")
    with d.grupo("TC"):
        d.circulo(130, 60, 20, esp=3)
        d.texto(96, 38, "K", tam=11, negrito=True)
        d.texto(158, 38, "L", tam=11, negrito=True)
        d.texto(160, 94, "TC 50/5 A", tam=12, negrito=True)
    with d.grupo("sec"):
        d.linha([(122, 79), (122, 151)])
        d.linha([(138, 79), (138, 151)])
        d.texto(110, 100, "k", tam=11, negrito=True)
        d.texto(144, 100, "l", tam=11, negrito=True)
    with d.grupo("A"):
        d.circulo(130, 172, 22)
        d.texto(130, 177, "A", tam=15, ancora="middle", negrito=True)
        d.texto(160, 190, "escala 0–50 A", tam=11)
    return d


vista(M, "tc-amperimetro", "tc-amperimetro")
vista(M, "tc-amperimetro-sec", "tc-amperimetro", destaque=["sec"])


# ---- TP com voltímetro (SENAI 11.2, Figura 204) -----------------------------------

@circuito("tp-voltimetro")
def tp_voltimetro():
    d = Desenho(300, 170, alt="Transformador de potencial (TP) de relação 6000/115 V: o primário "
                "está ligado em paralelo entre L1 e N de uma rede de 6000 V; o secundário alimenta "
                "um voltímetro de painel com entrada de 115 V e escala até 6000 V.")
    with d.grupo("rede"):
        d.linha([(20, 30), (140, 30)], esp=3)
        d.linha([(20, 140), (140, 140)], esp=3)
        d.texto(20, 22, "L1", tam=12, negrito=True)
        d.texto(20, 158, "N", tam=12, negrito=True)
        d.texto(24, 90, "6000 V", tam=11)
    with d.grupo("prim"):
        d.linha([(110, 30), (110, 55)])
        _enrol(d, (110, 55), (110, 115), n=4, lado=1)
        d.linha([(110, 115), (110, 140)])
        _ponto(d, 110, 30)
        _ponto(d, 110, 140)
    with d.grupo("nucleo"):
        d.linha([(132, 50), (132, 120)])
        d.linha([(138, 50), (138, 120)])
    with d.grupo("sec"):
        _enrol(d, (160, 55), (160, 115), n=4, lado=-1)
        d.linha([(160, 55), (240, 55), (240, 66)])
        d.linha([(160, 115), (240, 115), (240, 104)])
    with d.grupo("V"):
        d.circulo(240, 85, 19)
        d.texto(240, 90, "V", tam=15, ancora="middle", negrito=True)
        d.texto(200, 158, "TP 6000/115 V", tam=12, ancora="middle", negrito=True)
    return d


vista(M, "tp-voltimetro", "tp-voltimetro")


# ---- megômetro no motor (SENAI 14.2, Quadros 37-38) -------------------------------

def _megometro(modo):
    desc = {"terra": "o terminal L (linha) no enrolamento A e o terminal E (terra) na carcaça",
            "entre": "o terminal L (linha) no enrolamento A e o terminal E (terra) no enrolamento B"}
    d = Desenho(320, 230, alt="Motor desligado da rede, com três enrolamentos (A, B e C) soltos "
                "dentro da carcaça, e um megômetro ligado com " + desc[modo] + ".")
    with d.grupo("carcaca"):
        d.retangulo(30, 50, 170, 130, esp=2)
        d.texto(115, 196, "carcaça do motor", tam=11, ancora="middle")
        _ponto(d, 200, 150)
    for x, n in ((70, "A"), (115, "B"), (160, "C")):
        with d.grupo(n):
            d.linha([(x, 64), (x, 80)])
            _enrol(d, (x, 80), (x, 150), n=4, lado=1)
            d.linha([(x, 150), (x, 164)])
            _ponto(d, x, 64)
            d.texto(x - 8, 76, n, tam=12, ancora="end", negrito=True)
    with d.grupo("meg"):
        d.retangulo(232, 150, 76, 60, esp=2)
        d.texto(270, 176, "MΩ", tam=14, ancora="middle", negrito=True)
        d.texto(252, 204, "E", tam=12, ancora="middle", negrito=True)
        d.texto(288, 204, "L", tam=12, ancora="middle", negrito=True)
        _ponto(d, 252, 150)
        _ponto(d, 288, 150)
    with d.grupo("pontas"):
        # L (à direita) sobe por fora e chega ao A por cima; E fica por dentro:
        # assim os dois fios nunca se cruzam, o que pareceria ligação.
        d.linha([(288, 150), (288, 24), (70, 24), (70, 64)], esp=2)
        if modo == "terra":
            d.linha([(252, 150), (200, 150)], esp=2)
        else:
            d.linha([(252, 150), (252, 36), (115, 36), (115, 64)], esp=2)
    return d


for _m in ("terra", "entre"):
    circuito(f"megometro-{_m}")((lambda m: lambda: _megometro(m))(_m))
    vista(M, f"megometro-{_m}", f"megometro-{_m}")


# ---- gráfico de tendência de corrente (SENAI 14.3, Figura 235) ---------------------

@circuito("tendencia-corrente")
def tendencia_corrente():
    d = Desenho(320, 230, alt="Gráfico de tendência da corrente de um motor ao longo de 14 "
                "minutos, com a corrente nominal (cerca de 12 A) marcada por uma linha tracejada. "
                "A corrente fica em 12 A, salta de repente para 18 A no 4º minuto, fica alguns "
                "minutos em 18 A, sobe de novo perto do 11º minuto e cai a zero.")
    X0, Y0, W, H = 50, 190, 250, 160
    fx = lambda t: X0 + t / 14 * W
    fy = lambda a: Y0 - a / 20 * H
    with d.grupo("eixos"):
        d.linha([(X0, Y0 - H - 6), (X0, Y0), (X0 + W + 6, Y0)])
        for a in (0, 5, 10, 15, 20):
            d.linha([(X0 - 4, fy(a)), (X0, fy(a))], esp=1)
            d.texto(X0 - 8, fy(a) + 4, str(a), tam=10, ancora="end")
        for t in (0, 2, 4, 6, 8, 10, 12, 14):
            d.linha([(fx(t), Y0), (fx(t), Y0 + 4)], esp=1)
            d.texto(fx(t), Y0 + 16, str(t), tam=10, ancora="middle")
        d.texto(X0 + W / 2, Y0 + 34, "tempo (min)", tam=11, ancora="middle")
        d.texto(X0 - 10, Y0 - H - 12, "corrente (A)", tam=11)
    with d.grupo("nominal"):
        d.linha([(X0, fy(12)), (X0 + W, fy(12))], esp=1.5, tracejado="6 4")
        d.texto(X0 + W, fy(12) + 14, "nominal", tam=10, ancora="end")
    with d.grupo("degrau"):
        d.linha([(fx(0), fy(12)), (fx(4), fy(12)), (fx(4.1), fy(18)), (fx(10), fy(18))], esp=3)
    with d.grupo("desarme"):
        d.linha([(fx(10), fy(18)), (fx(10.8), fy(19.5)), (fx(11), fy(19.5)), (fx(11.1), fy(0)),
                 (fx(14), fy(0))], esp=3)
    return d


vista(M, "tendencia-corrente", "tendencia-corrente")
vista(M, "tendencia-corrente-degrau", "tendencia-corrente", destaque=["degrau"])
