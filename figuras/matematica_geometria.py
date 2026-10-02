# -*- coding: utf-8 -*-
"""Figuras de Matemática: geometria, gráficos de função, Venn e estatística.

Tudo desenhado EM ESCALA a partir dos dados do enunciado (PADRAO §1.8,
"coerente com os números"): o triângulo de 65° tem 65°, a escada de 5 m
apoiada a 4 m tem 3 m de base. As figuras dos cartões antigos só mostram o
que o enunciado já diz — o que se pede fica marcado com "?" ou letra.
"""
import math
from desenho import Desenho, simbolo, _n, DESTAQUE, TINTA

M = "matematica"
AZUL = "#7fa8d6"
CLARO = "#E3ECF5"
CINZA = "#C9D3DC"


# ---- primitivas ---------------------------------------------------------------

def _pol(d, pts, preench="none", esp=2, tracejado=None):
    extra = f' stroke-dasharray="{tracejado}"' if tracejado else ""
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="{preench}" stroke="{{c}}" stroke-width="{_n(esp)}" '
           f'stroke-linejoin="round"{extra}/>', pts)


def _seg(d, a, b, esp=2, tracejado=None, cor=None):
    d.linha([a, b], esp=esp, tracejado=tracejado, cor=cor)


def _ponta(d, a, b, tam=7, cor=None):
    """Ponta de seta cheia em b, vinda de a."""
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    bx, by = b[0] - tam * math.cos(ang), b[1] - tam * math.sin(ang)
    s, c = math.sin(ang) * tam * 0.45, math.cos(ang) * tam * 0.45
    pts = [b, (bx + s, by - c), (bx - s, by + c)]
    cc = cor or "{c}"
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="{cc}" stroke="{cc}" stroke-width="1"/>', pts)


def _seta(d, a, b, esp=1.6, tam=7, cor=None):
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    _seg(d, a, (b[0] - tam * 0.8 * math.cos(ang), b[1] - tam * 0.8 * math.sin(ang)), esp=esp, cor=cor)
    _ponta(d, a, b, tam, cor=cor)


def _rot(d, a, b, texto, lado=1, dist=12, tam=12, italico=False):
    """Rótulo no meio do segmento ab, afastado perpendicularmente."""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    L = math.hypot(b[0] - a[0], b[1] - a[1]) or 1
    nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
    d.texto(mx + lado * nx * dist, my + lado * ny * dist + tam * 0.35, texto, tam=tam,
            ancora="middle", italico=italico)


def _cota(d, a, b, texto, off=16, tam=12):
    """Linha de cota paralela a ab, deslocada 'off', com setas nas duas pontas."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
    pa = (a[0] + nx * off, a[1] + ny * off)
    pb = (b[0] + nx * off, b[1] + ny * off)
    _seg(d, a, (pa[0] + nx * 4, pa[1] + ny * 4), esp=0.8)
    _seg(d, b, (pb[0] + nx * 4, pb[1] + ny * 4), esp=0.8)
    _seta(d, ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2), pa, esp=1, tam=6)
    _seta(d, ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2), pb, esp=1, tam=6)
    sx = 1 if off > 0 else -1
    _rot(d, pa, pb, texto, lado=sx, dist=9, tam=tam)


def _arco(d, v, p1, p2, r=22, texto=None, dist=14, tam=12, cor=None):
    """Arco do ângulo p1-v-p2 (o menor) com rótulo na bissetriz."""
    a1 = math.atan2(p1[1] - v[1], p1[0] - v[0])
    a2 = math.atan2(p2[1] - v[1], p2[0] - v[0])
    x1, y1 = v[0] + r * math.cos(a1), v[1] + r * math.sin(a1)
    x2, y2 = v[0] + r * math.cos(a2), v[1] + r * math.sin(a2)
    cruz = (p1[0] - v[0]) * (p2[1] - v[1]) - (p1[1] - v[1]) * (p2[0] - v[0])
    varre = 1 if cruz > 0 else 0
    cc = cor or "{c}"
    d._add(f'<path d="M {_n(x1)},{_n(y1)} A {r} {r} 0 0 {varre} {_n(x2)},{_n(y2)}" fill="none" '
           f'stroke="{cc}" stroke-width="1.6"/>', [(v[0] - r, v[1] - r), (v[0] + r, v[1] + r)])
    if texto:
        d1 = (math.cos(a1) + math.cos(a2), math.sin(a1) + math.sin(a2))
        L = math.hypot(*d1) or 1
        bx, by = d1[0] / L, d1[1] / L
        d.texto(v[0] + bx * (r + dist), v[1] + by * (r + dist) + tam * 0.35, texto, tam=tam,
                ancora="middle", cor=cor)


def _reto(d, v, p1, p2, s=10):
    u = [(p - q) / math.hypot(p1[0] - v[0], p1[1] - v[1]) for p, q in zip(p1, v)]
    w = [(p - q) / math.hypot(p2[0] - v[0], p2[1] - v[1]) for p, q in zip(p2, v)]
    a = (v[0] + u[0] * s, v[1] + u[1] * s)
    b = (v[0] + (u[0] + w[0]) * s, v[1] + (u[1] + w[1]) * s)
    c = (v[0] + w[0] * s, v[1] + w[1] * s)
    d.linha([a, b, c], esp=1.4)


def _ponto(d, p, nome=None, dx=0, dy=-8, r=3, tam=13):
    d._add(f'<circle cx="{_n(p[0])}" cy="{_n(p[1])}" r="{r}" fill="{{c}}"/>',
           [(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)])
    if nome:
        d.texto(p[0] + dx, p[1] + dy, nome, tam=tam, ancora="middle", negrito=True)


def _polar(c, r, graus):
    """Ponto a 'graus' (sentido anti-horário, 0° à direita) do centro c."""
    a = math.radians(graus)
    return (c[0] + r * math.cos(a), c[1] - r * math.sin(a))


def _fig(nome, fn, alt):
    def desenhar(dd):
        o = fn()
        dd.w, dd.h, dd.itens = o.w, o.h, o.itens
    simbolo(M, nome, desenhar, alt=alt)


# ===== figuras para cartões que já existem =======================================

def _peca_l():
    d = Desenho(260, 240)
    k = 9
    x0, y0 = 50, 30
    pts = [(x0, y0), (x0 + 4 * k, y0), (x0 + 4 * k, y0 + 14 * k), (x0 + 18 * k, y0 + 14 * k),
           (x0 + 18 * k, y0 + 18 * k), (x0, y0 + 18 * k)]
    _pol(d, pts, preench=CLARO, esp=2.2)
    _cota(d, (x0, y0 + 18 * k), (x0, y0), "18 cm", off=-20)
    _cota(d, (x0, y0 + 18 * k), (x0 + 18 * k, y0 + 18 * k), "18 cm", off=20)
    _cota(d, (x0, y0), (x0 + 4 * k, y0), "4 cm", off=-14)
    _cota(d, (x0 + 18 * k, y0 + 14 * k), (x0 + 18 * k, y0 + 18 * k), "4 cm", off=-14)
    return d


_fig("peca-em-l", _peca_l, "Peça em forma de L: altura total 18 cm e largura total 18 cm; o braço "
     "vertical e o braço horizontal têm, cada um, 4 cm de espessura.")


def _octogono():
    d = Desenho(220, 220)
    c = (110, 110)
    for i, nome in enumerate("ABCDEFGH"):
        p = _polar(c, 80, 112.5 - 45 * i)
        q = _polar(c, 80, 112.5 - 45 * (i + 1))
        _seg(d, p, q, esp=2.2)
        t = _polar(c, 96, 112.5 - 45 * i)
        d.texto(t[0], t[1] + 5, nome, tam=13, ancora="middle", negrito=True)
    return d


_fig("octogono-abcdefgh", _octogono, "Octógono regular com os vértices nomeados de A a H, em "
     "sequência no sentido horário, começando no alto à esquerda.")


def _cordas():
    d = Desenho(240, 240)
    c, R, k = (120, 120), 90, 15.0
    e = math.sqrt(36 - 24)
    X = (c[0] + e * k, c[1])
    d.circulo(c[0], c[1], R, esp=2)
    for a, b, ang, ra, rb in ((6, 4, math.acos((4 - 6) / (2 * e)), "6", "4"),
                              (8, 3, -math.acos((3 - 8) / (2 * e)), "8", "y")):
        u = (math.cos(ang), -math.sin(ang))
        pa = (X[0] + a * k * u[0], X[1] + a * k * u[1])
        pb = (X[0] - b * k * u[0], X[1] - b * k * u[1])
        _seg(d, pa, pb, esp=2)
        _rot(d, X, pa, ra, lado=1, dist=11, tam=13)
        _rot(d, X, pb, rb, lado=1, dist=11, tam=13, italico=(rb == "y"))
    _ponto(d, X)
    return d


_fig("cordas-6-4-8-y", _cordas, "Circunferência com duas cordas que se cruzam num ponto interno. "
     "Uma fica dividida em segmentos de 6 e 4; a outra, em segmentos de 8 e y.")


def _circulo_quadrado():
    d = Desenho(220, 220)
    _pol(d, [(30, 30), (190, 30), (190, 190), (30, 190)], esp=2.2)
    d.circulo(110, 110, 80, esp=2)
    _ponto(d, (110, 110))
    _seg(d, (110, 110), _polar((110, 110), 80, 30), esp=1.6)
    _rot(d, (110, 110), _polar((110, 110), 80, 30), "8 cm", lado=1, dist=11)
    return d


_fig("circulo-no-quadrado", _circulo_quadrado, "Círculo de raio 8 cm dentro de um quadrado, "
     "tocando os quatro lados.")


def _triangulo_externo():
    d = Desenho(300, 200)
    A, B = (30, 160), (190, 160)
    t = 160 / (math.sin(math.radians(45)))  # lei dos senos: AC/sen70 = AB/sen45
    AC = 160 * math.sin(math.radians(70)) / math.sin(math.radians(45))
    C = _polar(A, AC, 65)
    _pol(d, [A, B, C], esp=2.2)
    _seg(d, B, (270, 160), esp=1.4, tracejado="6,4")
    _arco(d, A, B, C, r=26, texto="65°", dist=14)
    _arco(d, B, (270, 160), C, r=22, texto="110°", dist=16)
    _arco(d, C, A, B, r=20, texto="?", dist=12, tam=13)
    _ponto(d, A, "A", dx=-10, dy=4, r=0)
    _ponto(d, B, "B", dx=0, dy=18, r=0)
    _ponto(d, C, "C", dx=0, dy=-8, r=0)
    return d


_fig("triangulo-angulo-externo", _triangulo_externo, "Triângulo ABC com o lado AB prolongado "
     "além de B. Ângulo interno em A: 65°. Ângulo externo em B, entre o prolongamento e o lado BC: "
     "110°. O ângulo interno em C está marcado com um ponto de interrogação.")


def _altura_bissetriz():
    d = Desenho(320, 200)
    B, C = (20, 170), (300, 170)
    BC = 280
    A = _polar(B, BC * math.cos(math.radians(65)), 65)
    H = (A[0], 170)
    # bissetriz do ângulo reto: corta BC no ponto que divide na razão AB:AC
    AB, AC = math.dist(A, B), math.dist(A, C)
    S = (B[0] + BC * AB / (AB + AC), 170)
    _pol(d, [A, B, C], esp=2.2)
    _seg(d, A, H, esp=1.6)
    _seg(d, A, S, esp=1.6, tracejado="6,4")
    _reto(d, A, B, C, s=11)
    _reto(d, H, A, C, s=8)
    _arco(d, A, H, S, r=58, texto="20°", dist=12, tam=12)
    _ponto(d, A, "A", dy=-8, r=0)
    _ponto(d, B, "B", dx=-8, dy=6, r=0)
    _ponto(d, C, "C", dx=8, dy=6, r=0)
    d.texto(H[0] - 6, 186, "altura", tam=10, ancora="end", italico=True)
    d.texto(S[0] + 6, 186, "bissetriz", tam=10, italico=True)
    return d


_fig("triangulo-altura-bissetriz", _altura_bissetriz, "Triângulo retângulo com o ângulo reto "
     "no vértice A, no alto. De A descem a altura (linha contínua, perpendicular à hipotenusa BC) e "
     "a bissetriz do ângulo reto (linha tracejada); o ângulo entre as duas mede 20°.")


def _paralelas(rotulos, angulo, posicoes, alt_nome):
    """Retas r e s horizontais, transversal t. posicoes: [(reta, quadrante, rótulo)];
    quadrante: 'ne','no','se','so' em torno do cruzamento."""
    d = Desenho(300, 200)
    yr, ys = 60, 140
    _seg(d, (20, yr), (280, yr), esp=2)
    _seg(d, (20, ys), (280, ys), esp=2)
    d.texto(284, yr + 4, "r", tam=13, italico=True)
    d.texto(284, ys + 4, "s", tam=13, italico=True)
    dx = 80 / math.tan(math.radians(angulo))
    Pr = (150 + dx / 2, yr)
    Ps = (150 - dx / 2, ys)
    ext = 30 / math.tan(math.radians(angulo))
    _seg(d, (Ps[0] - ext - 4, ys + 30), (Pr[0] + ext + 4, yr - 30), esp=2)
    d.texto(Pr[0] + ext + 8, yr - 30, "t", tam=13, italico=True)
    alvo = {"ne": lambda P: (P, (P[0] + 60, P[1]), (P[0] + 40 / math.tan(math.radians(angulo)), P[1] - 40)),
            "no": lambda P: (P, (P[0] + 40 / math.tan(math.radians(angulo)), P[1] - 40), (P[0] - 60, P[1])),
            "so": lambda P: (P, (P[0] - 60, P[1]), (P[0] - 40 / math.tan(math.radians(angulo)), P[1] + 40)),
            "se": lambda P: (P, (P[0] - 40 / math.tan(math.radians(angulo)), P[1] + 40), (P[0] + 60, P[1]))}
    for reta, quad, rot in posicoes:
        P = Pr if reta == "r" else Ps
        v, p1, p2 = alvo[quad](P)
        _arco(d, v, p1, p2, r=18, texto=rot, dist=20 if len(rot) > 3 else 16, tam=12)
    return d


_fig("paralelas-alternos-expressoes",
     lambda: _paralelas(None, 59, [("r", "so", "2x²+9"), ("s", "ne", "3x²−16")], ""),
     "Duas retas paralelas horizontais, r em cima e s embaixo, cortadas por uma transversal t. "
     "Entre as paralelas, em lados opostos da transversal, estão marcados os ângulos 2x²+9 (junto "
     "de r, à esquerda de t) e 3x²−16 (junto de s, à direita de t).")


def _opostos():
    d = Desenho(260, 200)
    O = (130, 100)
    a, b = 35, 35 + 70
    _seg(d, _polar(O, 110, a), _polar(O, 110, a + 180), esp=2)
    _seg(d, _polar(O, 110, b), _polar(O, 110, b + 180), esp=2)
    _arco(d, O, _polar(O, 50, a), _polar(O, 50, b), r=24, texto="5x+20°", dist=24)
    _arco(d, O, _polar(O, 50, a + 180), _polar(O, 50, b + 180), r=24, texto="2x+50°", dist=24)
    return d


_fig("opostos-pelo-vertice-expressoes", _opostos, "Duas retas concorrentes. Num par de ângulos "
     "opostos pelo vértice estão escritas as medidas 5x+20° (em cima) e 2x+50° (embaixo).")


def _relogio(h, m):
    d = Desenho(220, 220)
    c = (110, 110)
    d.circulo(c[0], c[1], 92, esp=2.4)
    for i in range(60):
        p1 = _polar(c, 92, 90 - 6 * i)
        p2 = _polar(c, 86 if i % 5 else 80, 90 - 6 * i)
        _seg(d, p1, p2, esp=2 if i % 5 == 0 else 0.8)
    for n in range(1, 13):
        t = _polar(c, 68, 90 - 30 * n)
        d.texto(t[0], t[1] + 5, str(n), tam=13, ancora="middle")
    _seg(d, c, _polar(c, 46, 90 - ((h % 12) * 30 + m * 0.5)), esp=5)
    _seg(d, c, _polar(c, 74, 90 - m * 6), esp=2.6)
    _ponto(d, c, r=5)
    return d


_fig("relogio-2h30", lambda: _relogio(2, 30), "Relógio analógico marcando 2h30min: ponteiro dos "
     "minutos no 6 e ponteiro das horas entre o 2 e o 3.")
_fig("relogio-10h15", lambda: _relogio(10, 15), "Relógio analógico marcando 10h15min: ponteiro dos "
     "minutos no 3 e ponteiro das horas pouco depois do 10.")


def _escada_conves():
    d = Desenho(240, 220)
    k = 38
    W, F = (180, 190), (180 - 3 * k, 190)
    T = (180, 190 - 4 * k)
    _seg(d, (20, 190), (220, 190), esp=2.4)
    _seg(d, (180, 190), (180, 20), esp=2.4)
    d.texto(186, 30, "antepara", tam=10, italico=True)
    d.texto(30, 206, "convés", tam=10, italico=True)
    _seg(d, F, T, esp=4, cor=DESTAQUE)
    _reto(d, W, T, F, s=12)
    _rot(d, F, T, "5 m", lado=-1, dist=14)
    _rot(d, W, T, "4 m", lado=1, dist=14)
    _rot(d, F, W, "d", lado=1, dist=12, italico=True)
    return d


_fig("escada-conves-antepara", _escada_conves, "Escada de 5 m apoiada na antepara, tocando-a a 4 m "
     "de altura do convés; a distância d entre a base da escada e a antepara está indicada no convés.")


def _ancora():
    d = Desenho(280, 230)
    k = 3.2
    N = (40, 40)
    Afd = (40 + 36 * k, 40 + 48 * k)
    _seg(d, (10, 40), (270, 40), esp=1.6, cor=DESTAQUE)
    d.texto(266, 34, "superfície", tam=10, ancora="end", italico=True)
    _seg(d, (10, Afd[1]), (270, Afd[1]), esp=2)
    d.texto(266, Afd[1] + 14, "fundo", tam=10, ancora="end", italico=True)
    _pol(d, [(22, 30), (58, 30), (52, 40), (28, 40)], preench=CLARO)
    _seg(d, N, Afd, esp=2.4)
    _seg(d, N, (40, Afd[1]), esp=1.2, tracejado="5,4")
    _reto(d, (40, Afd[1]), N, Afd, s=10)
    _rot(d, N, Afd, "60 m", lado=-1, dist=14)
    _rot(d, N, (40, Afd[1]), "48 m", lado=1, dist=14)
    _rot(d, (40, Afd[1]), Afd, "?", lado=-1, dist=12, tam=14)
    _ponto(d, Afd)
    return d


_fig("cabo-ancora-60-48", _ancora, "Navio na superfície e âncora no fundo, 48 m abaixo. O cabo "
     "esticado de 60 m vai do navio à âncora; a distância horizontal entre os dois está marcada com "
     "ponto de interrogação.")


def _mastro():
    d = Desenho(240, 230)
    k = 9
    B, C, A = (60, 200), (60, 200 - 20 * k), (60 + 15 * k, 200)
    _seg(d, (20, 200), (220, 200), esp=2)
    _seg(d, B, C, esp=4)
    _seg(d, A, C, esp=2, cor=DESTAQUE)
    _reto(d, B, C, A, s=11)
    _rot(d, B, C, "20 m", lado=1, dist=16)
    _rot(d, B, A, "15 m", lado=1, dist=12)
    _ponto(d, A, "A", dx=8, dy=16)
    _ponto(d, B, "B", dx=-6, dy=16)
    _ponto(d, C, "C", dx=-10, dy=-4)
    return d


_fig("mastro-estai-abc", _mastro, "Mastro vertical BC de 20 m, com a base B no convés. O ponto A "
     "está no convés, a 15 m de B, e um cabo liga A ao topo C do mastro.")


def _predios():
    d = Desenho(260, 220)
    k = 7
    y0 = 200
    x1, x2 = 40, 40 + 20 * k
    _seg(d, (10, y0), (250, y0), esp=2)
    _pol(d, [(x1 - 28, y0), (x1, y0), (x1, y0 - 25 * k), (x1 - 28, y0 - 25 * k)], preench=CLARO)
    _pol(d, [(x2, y0), (x2 + 28, y0), (x2 + 28, y0 - 10 * k), (x2, y0 - 10 * k)], preench=CLARO)
    _seg(d, (x1, y0 - 25 * k), (x2, y0 - 10 * k), esp=2.4, cor=DESTAQUE)
    _rot(d, (x1 - 28, y0), (x1 - 28, y0 - 25 * k), "25 m", lado=-1, dist=14)
    _rot(d, (x2 + 28, y0), (x2 + 28, y0 - 10 * k), "10 m", lado=-1, dist=14)
    _cota(d, (x1, y0), (x2, y0), "20 m", off=14)
    return d


_fig("cabo-entre-predios", _predios, "Dois prédios, de 25 m e 10 m de altura, separados por 20 m na "
     "horizontal; um cabo liga o topo de um ao topo do outro.")


def _sombras():
    d = Desenho(320, 200)
    k = 8
    y0 = 180
    _seg(d, (10, y0), (310, y0), esp=2)
    for x, h, s, rh in ((40, 4, 6, "4 m"), (130, 10, 15, "?")):
        _seg(d, (x, y0), (x, y0 - h * k), esp=4)
        _seg(d, (x, y0 - h * k), (x + s * k, y0), esp=1.2, tracejado="5,4")
        _rot(d, (x, y0), (x, y0 - h * k), rh, lado=-1, dist=16, tam=12 if rh != "?" else 14)
        _cota(d, (x, y0), (x + s * k, y0), f"{s} m", off=12)
    d.texto(48, y0 - 4 * k - 6, "poste", tam=10, italico=True)
    d.texto(138, y0 - 10 * k - 6, "mastro", tam=10, italico=True)
    return d


_fig("sombras-poste-mastro", _sombras, "Num terreno plano, um poste de 4 m projeta sombra de 6 m e, "
     "ao lado, um mastro de altura desconhecida projeta sombra de 15 m; os raios de sol são paralelos.")


def _duas_escadas():
    d = Desenho(260, 240)
    k = 60
    W = 220
    y0 = 180
    _seg(d, (10, y0), (250, y0), esp=2)
    _seg(d, (W, y0), (W, 20), esp=2.4)
    for L, cor, rot in ((3, None, "3 m"), (2, DESTAQUE, "2 m")):
        F = (W - L * k * 0.5, y0)
        T = (W, y0 - L * k * math.sin(math.radians(60)))
        _seg(d, F, T, esp=3, cor=cor)
        _arco(d, F, (W, y0), T, r=14, texto="α", dist=8, tam=11)
        _rot(d, F, T, rot, lado=-1, dist=12)
    _cota(d, (W - 2 * k * 0.5, y0), (W, y0), "1 m", off=14)
    _cota(d, (W - 3 * k * 0.5, y0), (W, y0), "?", off=38, tam=14)
    return d


_fig("duas-escadas-mesmo-angulo", _duas_escadas, "Duas escadas apoiadas na mesma antepara, ambas "
     "formando o ângulo α com o chão: a de 2 m tem a base a 1 m da antepara; a distância da base "
     "da escada de 3 m até a antepara está marcada com ponto de interrogação.")


def _pedestres():
    d = Desenho(300, 220)
    k = 18
    A, B = (40, 180), (40 + 12 * k, 180)
    P = (40 + 7.2 * k, 180 - 14.4 * k * 0.55)
    _seg(d, (10, 180), (290, 180), esp=2)
    _seg(d, (10, P[1]), (290, P[1]), esp=2)
    _seg(d, A, P, esp=1.6)
    _seg(d, B, P, esp=1.6)
    _seg(d, P, (P[0], 180), esp=1.2, tracejado="5,4")
    _arco(d, A, B, P, r=22, texto="α", dist=10)
    _arco(d, B, P, A, r=22, texto="β", dist=10)
    _ponto(d, A, "A", dy=18)
    _ponto(d, B, "B", dy=18)
    _ponto(d, P, "P", dy=-8)
    _cota(d, A, B, "12 m", off=34)
    d.texto(P[0] + 6, (P[1] + 180) / 2, "largura", tam=10, italico=True)
    return d


_fig("pedestres-poste-rua", _pedestres, "Rua de calçadas paralelas. Os pedestres A e B estão numa "
     "calçada, a 12 m um do outro; o poste P está na calçada oposta. Ângulo α em A, entre AB e AP; "
     "ângulo β em B, entre BA e BP. A largura da rua está tracejada, de P até a calçada de A e B.")


def _lancha():
    d = Desenho(300, 220)
    k = 1.0
    A, C = (20, 190), (20 + 260 * k, 190)
    B = (20 + 60 * k, 190 - 150 * k)
    _seg(d, (10, 190), (290, 190), esp=2)
    d.texto(250, 204, "praia", tam=10, ancora="end", italico=True)
    _seg(d, A, B, esp=1.6)
    _seg(d, C, B, esp=1.6)
    _seg(d, B, (B[0], 190), esp=1.2, tracejado="5,4")
    _reto(d, (B[0], 190), B, C, s=9)
    _arco(d, A, C, B, r=22)
    _arco(d, C, B, A, r=22)
    _rot(d, B, (B[0], 190), "d", lado=-1, dist=10, italico=True)
    _ponto(d, A, "A", dy=18)
    _ponto(d, C, "C", dy=18)
    _ponto(d, B, "B", dy=-8)
    _cota(d, A, C, "260 m", off=26)
    return d


_fig("lancha-observador-praia", _lancha, "Praia em linha reta com os pontos A e C, a 260 m um do "
     "outro; a lancha B está fora da praia. As visadas AB e CB formam ângulos marcados em A e em C; "
     "a distância d da lancha até a praia está tracejada, perpendicular à reta AC.")


def _inscrito():
    d = Desenho(260, 160)
    c, R = (130, 140), 110
    g = math.degrees(2 * math.asin(1 / 3))
    A, D = _polar(c, R, 180), _polar(c, R, 0)
    Bp, Cp = _polar(c, R, 180 - g), _polar(c, R, 180 - 2 * g)
    d._add(f'<path d="M {_n(A[0])},{_n(A[1])} A {R} {R} 0 0 1 {_n(D[0])},{_n(D[1])}" fill="none" '
           f'stroke="{{c}}" stroke-width="2"/>', [(c[0] - R, c[1] - R), (c[0] + R, c[1])])
    _pol(d, [A, Bp, Cp, D], esp=2)
    _rot(d, A, Bp, "1", lado=1, dist=10)
    _rot(d, Bp, Cp, "1", lado=1, dist=10)
    _rot(d, Cp, D, "?", lado=1, dist=11, tam=14)
    _rot(d, A, D, "3", lado=1, dist=-12)
    for p, n, dx, dy in ((A, "A", -10, 4), (Bp, "B", -8, -6), (Cp, "C", 0, -9), (D, "D", 10, 4)):
        _ponto(d, p, n, dx=dx, dy=dy, r=2.5)
    return d


_fig("quadrilatero-inscrito-diametro", _inscrito, "Semicircunferência de diâmetro AD = 3. O "
     "quadrilátero ABCD tem os vértices B e C sobre o arco, com AB = 1 e BC = 1; a corda CD está "
     "marcada com ponto de interrogação.")


def _setor_cone():
    d = Desenho(320, 200)
    c, R = (90, 100), 80
    a0, a1 = 90 - 60, 90 + 60
    p0, p1 = _polar(c, R, a0), _polar(c, R, a1)
    d._add(f'<path d="M {_n(c[0])},{_n(c[1])} L {_n(p0[0])},{_n(p0[1])} A {R} {R} 0 0 0 '
           f'{_n(p1[0])},{_n(p1[1])} Z" fill="{CLARO}" stroke="{{c}}" stroke-width="2"/>',
           [(c[0] - R, c[1] - R), (c[0] + R, c[1])])
    _arco(d, c, p0, p1, r=18, texto="120°", dist=14)
    _rot(d, c, p0, "12 cm", lado=1, dist=14)
    _seta(d, (180, 70), (215, 70), esp=1.8)
    V, r, base = (265, 30), 26, 150
    d._add(f'<ellipse cx="{V[0]}" cy="{base}" rx="{r}" ry="8" fill="none" stroke="{{c}}" '
           f'stroke-width="2"/>', [(V[0] - r, base - 8), (V[0] + r, base + 8)])
    _seg(d, (V[0] - r, base), V, esp=2)
    _seg(d, (V[0] + r, base), V, esp=2)
    _seg(d, V, (V[0], base), esp=1.2, tracejado="5,4")
    d.texto(V[0] + r - 2, (V[1] + base) / 2, "h = ?", tam=12)
    return d


_fig("setor-120-vira-cone", _setor_cone, "À esquerda, setor circular de raio 12 cm e ângulo central "
     "de 120°; uma seta indica que ele é enrolado para formar o cone da direita, cuja altura h está "
     "marcada com ponto de interrogação.")


def _tales_postes():
    d = Desenho(330, 220)
    u = 11
    ys = [30, 30 + 4 * u * math.sin(math.radians(80)), 30 + 10 * u * math.sin(math.radians(80))]
    for y in ys:
        _seg(d, (10, y), (320, y), esp=1.6)
    pL = [(40 + (y - 30) / math.tan(math.radians(80)), y) for y in ys]
    th = math.degrees(math.asin(math.sin(math.radians(80)) / 2))
    pR = [(110 + (y - 30) / math.tan(math.radians(th)), y) for y in ys]
    _seg(d, (pL[0][0] - 3, 18), (pL[2][0] + 3, ys[2] + 14), esp=3)
    _seg(d, (pR[0][0] - 8, 18), (pR[2][0] + 10, ys[2] + 14), esp=3)
    _rot(d, pL[0], pL[1], "4 m", lado=1, dist=14)
    _rot(d, pL[1], pL[2], "6 m", lado=1, dist=14)
    _rot(d, pR[0], pR[1], "8 m", lado=-1, dist=14)
    _rot(d, pR[1], pR[2], "x", lado=-1, dist=12, italico=True, tam=13)
    d.texto(320, ys[0] - 5, "fios", tam=10, ancora="end", italico=True)
    return d


_fig("tales-fios-postes", _tales_postes, "Três fios paralelos horizontais cortados por dois postes "
     "inclinados. No poste da esquerda, os trechos entre os fios medem 4 m e 6 m; no da direita, o "
     "trecho correspondente ao de 4 m mede 8 m e o correspondente ao de 6 m é x.")


def _patio_faixa():
    d = Desenho(300, 220)
    k = 6
    x0, y0 = 30, 30
    _pol(d, [(x0, y0), (x0 + 40 * k, y0), (x0 + 40 * k, y0 + 25 * k), (x0, y0 + 25 * k)],
         preench=CINZA, esp=2)
    _pol(d, [(x0 + 5 * k, y0 + 5 * k), (x0 + 35 * k, y0 + 5 * k), (x0 + 35 * k, y0 + 20 * k),
             (x0 + 5 * k, y0 + 20 * k)], preench="#fff", esp=1.6)
    d.texto(x0 + 20 * k, y0 + 12.5 * k + 5, "jardim: 450 m²", tam=12, ancora="middle")
    _cota(d, (x0, y0 + 25 * k), (x0 + 40 * k, y0 + 25 * k), "40 m", off=16)
    _cota(d, (x0 + 40 * k, y0 + 25 * k), (x0 + 40 * k, y0), "25 m", off=16)
    _cota(d, (x0, y0 + 12.5 * k), (x0 + 5 * k, y0 + 12.5 * k), "x", off=0.01)
    return d


_fig("patio-faixa-x", _patio_faixa, "Pátio retangular de 40 m por 25 m. Uma faixa de largura "
     "uniforme x contorna o jardim central, de 450 m².")


def _altura_hipotenusa(nome, m, n, rot_h, rot_m, rot_n, rot_hip, alt):
    def fn():
        d = Desenho(320, 200)
        k = 280 / (m + n)
        B, C = (20, 170), (20 + (m + n) * k, 170)
        H = (20 + n * k, 170)
        A = (H[0], 170 - math.sqrt(m * n) * k)
        _pol(d, [A, B, C], esp=2.2)
        _seg(d, A, H, esp=1.6)
        _reto(d, A, B, C, s=11)
        _reto(d, H, A, C, s=8)
        if rot_h:
            _rot(d, A, H, rot_h, lado=1, dist=-22)
        if rot_n:
            _rot(d, B, H, rot_n, lado=1, dist=-14, italico=len(rot_n) == 1)
            _rot(d, H, C, rot_m, lado=1, dist=-14, italico=len(rot_m) == 1)
        if rot_hip:
            _cota(d, B, C, rot_hip, off=18)
        _ponto(d, A, "A", dy=-8, r=0)
        _ponto(d, B, "B", dx=-8, dy=6, r=0)
        _ponto(d, C, "C", dx=8, dy=6, r=0)
        return d
    _fig(nome, fn, alt)


_altura_hipotenusa("altura-hipotenusa-12", 16, 9, "12 cm", "m", "n", None,
                   "Triângulo retângulo ABC, com o ângulo reto em A. A altura relativa à hipotenusa "
                   "BC mede 12 cm e divide a hipotenusa nas projeções n (junto de B) e m (junto de C).")
_altura_hipotenusa("altura-hipotenusa-40", 32, 8, None, "", "", "40 m",
                   "Triângulo retângulo ABC, com o ângulo reto em A, e a altura relativa à "
                   "hipotenusa BC, que mede 40 m. O pé da altura divide a hipotenusa em dois "
                   "segmentos, o menor junto de B.")


# ===== figuras para cartões novos ==================================================

_fig("paralelas-correspondentes-70",
     lambda: _paralelas(None, 70, [("r", "ne", "70°"), ("s", "ne", "x")], ""),
     "Duas retas paralelas horizontais, r em cima e s embaixo, cortadas por uma transversal t. "
     "Junto de r, acima dela e à direita de t, um ângulo de 70°; junto de s, na mesma posição "
     "(acima de s e à direita de t), o ângulo x.")


def _grafico(curva, xs=(-3, 7), ys=(-3, 6), pontos=(), sombrear=None):
    """Plano cartesiano com grade de 1 em 1 e a curva f (função de x)."""
    k = 26
    W = (xs[1] - xs[0]) * k + 40
    H = (ys[1] - ys[0]) * k + 40
    d = Desenho(W, H)
    X = lambda x: 20 + (x - xs[0]) * k
    Y = lambda y: 20 + (ys[1] - y) * k
    for x in range(xs[0], xs[1] + 1):
        _seg(d, (X(x), Y(ys[0])), (X(x), Y(ys[1])), esp=0.6, cor="#DDE4EA")
    for y in range(ys[0], ys[1] + 1):
        _seg(d, (X(xs[0]), Y(y)), (X(xs[1]), Y(y)), esp=0.6, cor="#DDE4EA")
    _seta(d, (X(xs[0]), Y(0)), (X(xs[1]) + 10, Y(0)), esp=1.4)
    _seta(d, (X(0), Y(ys[0])), (X(0), Y(ys[1]) - 10), esp=1.4)
    d.texto(X(xs[1]) + 8, Y(0) + 16, "x", tam=12, italico=True)
    d.texto(X(0) - 10, Y(ys[1]) - 4, "y", tam=12, italico=True)
    for x in range(xs[0], xs[1] + 1):
        if x:
            d.texto(X(x), Y(0) + 14, str(x), tam=9, ancora="middle", cor="#5A6B7A")
    for y in range(ys[0], ys[1] + 1):
        if y:
            d.texto(X(0) - 5, Y(y) + 3, str(y), tam=9, ancora="end", cor="#5A6B7A")
    pts = []
    passo = 0.05
    x = xs[0]
    while x <= xs[1] + 1e-9:
        y = curva(x)
        if ys[0] - 0.5 <= y <= ys[1] + 0.5:
            pts.append((X(x), Y(max(ys[0] - 0.5, min(ys[1] + 0.5, y)))))
        x += passo
    if pts:
        d.linha(pts, esp=2.6, cor=DESTAQUE)
    for (px, py) in pontos:
        _ponto(d, (X(px), Y(py)), r=3.5)
    return d


_fig("grafico-reta-crescente", lambda: _grafico(lambda x: 2 * x + 2, xs=(-3, 4), ys=(-3, 6),
                                                 pontos=[(-1, 0), (0, 2)]),
     "Plano cartesiano com grade de 1 em 1. Uma reta crescente corta o eixo x no ponto (−1, 0) e o "
     "eixo y no ponto (0, 2); os dois pontos estão marcados.")
_fig("grafico-reta-decrescente", lambda: _grafico(lambda x: 3 - x / 2, xs=(-2, 7), ys=(-2, 5),
                                                   pontos=[(0, 3), (6, 0)]),
     "Plano cartesiano com grade de 1 em 1. Uma reta decrescente passa pelos pontos marcados "
     "(0, 3), no eixo y, e (6, 0), no eixo x.")
_fig("grafico-parabola-raizes-1-5", lambda: _grafico(lambda x: -(x - 1) * (x - 5) / 1.0,
                                                      xs=(-1, 7), ys=(-3, 5), pontos=[(1, 0), (5, 0)]),
     "Plano cartesiano com grade de 1 em 1. Uma parábola com a concavidade voltada para baixo "
     "corta o eixo x nos pontos marcados (1, 0) e (5, 0); entre eles, a curva fica acima do eixo x.")
_fig("grafico-parabola-vertice-2-menos1", lambda: _grafico(lambda x: (x - 2) ** 2 - 1, xs=(-2, 6),
                                                            ys=(-2, 6), pontos=[(2, -1)]),
     "Plano cartesiano com grade de 1 em 1. Uma parábola com a concavidade voltada para cima tem o "
     "vértice marcado no ponto (2, −1) e corta o eixo x em (1, 0) e (3, 0).")
_fig("grafico-parabola-sem-raiz", lambda: _grafico(lambda x: 0.5 * (x - 2) ** 2 + 1, xs=(-2, 6),
                                                    ys=(-2, 6)),
     "Plano cartesiano com grade de 1 em 1. Uma parábola com a concavidade voltada para cima fica "
     "inteiramente acima do eixo x, sem tocá-lo; o ponto mais baixo está em (2, 1).")


def _ciclo(graus):
    d = Desenho(240, 240)
    c, R = (120, 120), 85
    _seta(d, (15, 120), (228, 120), esp=1.2)
    _seta(d, (120, 225), (120, 12), esp=1.2)
    d.texto(226, 136, "cos", tam=10, ancora="end", italico=True)
    d.texto(126, 18, "sen", tam=10, italico=True)
    d.circulo(c[0], c[1], R, esp=2)
    for n, g in (("I", 45), ("II", 135), ("III", 225), ("IV", 315)):
        t = _polar(c, 50, g)
        d.texto(t[0], t[1] + 5, n, tam=12, ancora="middle", cor="#5A6B7A")
    P = _polar(c, R, graus)
    _seg(d, c, P, esp=2, cor=DESTAQUE)
    # arco de 0° até o ângulo, no sentido anti-horário (na tela, sweep 0)
    r = 22
    p0, p1 = _polar(c, r, 0), _polar(c, r, graus)
    d._add(f'<path d="M {_n(p0[0])},{_n(p0[1])} A {r} {r} 0 {1 if graus > 180 else 0} 0 '
           f'{_n(p1[0])},{_n(p1[1])}" fill="none" stroke="{DESTAQUE}" stroke-width="1.8"/>',
           [(c[0] - r, c[1] - r), (c[0] + r, c[1] + r)])
    _ponto(d, P, "P", dx=-10, dy=14)
    return d


_fig("ciclo-trigonometrico-210", lambda: _ciclo(210), "Círculo trigonométrico com os eixos dos "
     "cossenos (horizontal) e dos senos (vertical) e os quadrantes numerados de I a IV. O ponto P, "
     "marcado na circunferência, corresponde a um ângulo de 210°, medido a partir do eixo horizontal "
     "positivo no sentido anti-horário.")


def _venn2():
    d = Desenho(300, 200)
    _pol(d, [(10, 10), (290, 10), (290, 190), (10, 190)], esp=1.4)
    d._add(f'<circle cx="115" cy="100" r="68" fill="{AZUL}" fill-opacity="0.25" stroke="{{c}}" '
           f'stroke-width="2"/>', [(47, 32), (183, 168)])
    d._add(f'<circle cx="185" cy="100" r="68" fill="{AZUL}" fill-opacity="0.25" stroke="{{c}}" '
           f'stroke-width="2"/>', [(117, 32), (253, 168)])
    d.texto(70, 42, "A", tam=14, negrito=True)
    d.texto(226, 42, "B", tam=14, negrito=True)
    for x, y, t in ((85, 105, "12"), (150, 105, "5"), (215, 105, "8"), (270, 180, "3")):
        d.texto(x, y, t, tam=15, ancora="middle")
    return d


_fig("venn-2-conjuntos", _venn2, "Diagrama de Venn com os conjuntos A e B dentro de um retângulo. "
     "Só em A: 12 elementos. Na interseção de A e B: 5. Só em B: 8. Fora dos dois conjuntos: 3.")


def _venn3():
    d = Desenho(300, 260)
    _pol(d, [(10, 10), (290, 10), (290, 250), (10, 250)], esp=1.4)
    for cx, cy in ((115, 100), (185, 100), (150, 160)):
        d._add(f'<circle cx="{cx}" cy="{cy}" r="66" fill="{AZUL}" fill-opacity="0.2" stroke="{{c}}" '
               f'stroke-width="2"/>', [(cx - 66, cy - 66), (cx + 66, cy + 66)])
    d.texto(56, 46, "M", tam=14, negrito=True)
    d.texto(236, 46, "S", tam=14, negrito=True)
    d.texto(150, 244, "E", tam=14, ancora="middle", negrito=True)
    for x, y, t in ((90, 85, "10"), (210, 85, "7"), (150, 205, "9"),
                    (150, 78, "4"), (112, 150, "6"), (188, 150, "3"), (150, 124, "2"),
                    (272, 240, "5")):
        d.texto(x, y, t, tam=14, ancora="middle")
    return d


_fig("venn-3-conjuntos", _venn3, "Diagrama de Venn com três conjuntos de tripulantes, M, S e E, "
     "dentro de um retângulo. Só M: 10. Só S: 7. Só E: 9. M e S, sem E: 4. M e E, sem S: 6. S e E, "
     "sem M: 3. Nos três: 2. Fora dos três: 5.")


def _setores():
    d = Desenho(320, 200)
    c, R = (100, 100), 80
    fatias = [("Manutenção", 45, "#7fa8d6"), ("Operação", 30, "#a9c7a1"),
              ("Administrativo", 15, "#e8c48a"), ("Segurança", 10, "#d9a3a3")]
    a = 90.0
    for i, (nome, p, cor) in enumerate(fatias):
        a2 = a - p * 3.6
        p0, p1 = _polar(c, R, a), _polar(c, R, a2)
        grande = 1 if p > 50 else 0
        d._add(f'<path d="M {c[0]},{c[1]} L {_n(p0[0])},{_n(p0[1])} A {R} {R} 0 {grande} 1 '
               f'{_n(p1[0])},{_n(p1[1])} Z" fill="{cor}" stroke="{{c}}" stroke-width="1.6"/>',
               [(c[0] - R, c[1] - R), (c[0] + R, c[1] + R)])
        t = _polar(c, R * 0.62, (a + a2) / 2)
        d.texto(t[0], t[1] + 4, f"{p}%", tam=11, ancora="middle", negrito=True)
        yl = 50 + i * 30
        d._add(f'<rect x="200" y="{yl - 10}" width="12" height="12" fill="{cor}" stroke="{{c}}" '
               f'stroke-width="1"/>', [(200, yl - 10), (212, yl + 2)])
        d.texto(218, yl, nome, tam=11)
        a = a2
    return d


_fig("setores-funcionarios", _setores, "Gráfico de setores da distribuição dos funcionários de um "
     "terminal por área: Manutenção 45%, Operação 30%, Administrativo 15% e Segurança 10%.")


PRODUCAO = [("jan", 30), ("fev", 34), ("mar", 26), ("abr", 31), ("mai", 33), ("jun", 22)]


def _linha():
    d = Desenho(320, 230)
    X0, Y0, H = 50, 190, 150
    fy = lambda v: Y0 - (v - 15) / 25 * H
    _seg(d, (X0, Y0 - H - 8), (X0, Y0), esp=1.6)
    _seg(d, (X0, Y0), (X0 + 260, Y0), esp=1.6)
    for v in range(15, 41, 5):
        _seg(d, (X0 - 4, fy(v)), (X0 + 260, fy(v)), esp=0.6, cor="#DDE4EA")
        d.texto(X0 - 8, fy(v) + 4, str(v), tam=10, ancora="end")
    d.texto(X0 - 10, Y0 - H - 14, "mil barris", tam=11)
    pts = []
    for i, (mes, v) in enumerate(PRODUCAO):
        x = X0 + 25 + i * 44
        pts.append((x, fy(v)))
        d.texto(x, Y0 + 16, mes, tam=11, ancora="middle")
    d.linha(pts, esp=2.4, cor=DESTAQUE)
    for p in pts:
        _ponto(d, p, r=3.5)
    return d


_fig("linha-producao-semestre", _linha, "Gráfico de linha da produção mensal de um poço, em mil "
     "barris, de janeiro a junho: janeiro 30, fevereiro 34, março 26, abril 31, maio 33 e junho 22. "
     "Eixo vertical de 15 a 40, de 5 em 5.")


def _plan_piramide():
    d = Desenho(240, 240)
    s, c = 60, (120, 120)
    q = [(c[0] - s / 2, c[1] - s / 2), (c[0] + s / 2, c[1] - s / 2),
         (c[0] + s / 2, c[1] + s / 2), (c[0] - s / 2, c[1] + s / 2)]
    _pol(d, q, preench=CLARO)
    h = 62
    for i in range(4):
        a, b = q[i], q[(i + 1) % 4]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        nx, ny = (mx - c[0]) / (s / 2), (my - c[1]) / (s / 2)
        _pol(d, [a, b, (mx + nx * h, my + ny * h)], preench="#fff")
    return d


def _plan_prisma_tri():
    d = Desenho(300, 200)
    w, h = 60, 90
    x0, y0 = 30, 55
    for i in range(3):
        _pol(d, [(x0 + i * w, y0), (x0 + (i + 1) * w, y0), (x0 + (i + 1) * w, y0 + h), (x0 + i * w, y0 + h)],
             preench=CLARO if i == 1 else "#fff")
    tri = w * math.sqrt(3) / 2
    _pol(d, [(x0 + w, y0), (x0 + 2 * w, y0), (x0 + 1.5 * w, y0 - tri)])
    _pol(d, [(x0 + w, y0 + h), (x0 + 2 * w, y0 + h), (x0 + 1.5 * w, y0 + h + tri)])
    return d


def _plan_cone():
    d = Desenho(260, 220)
    c, R = (110, 40), 120
    p0, p1 = _polar(c, R, -90 + 55), _polar(c, R, -90 - 55)
    d._add(f'<path d="M {c[0]},{c[1]} L {_n(p0[0])},{_n(p0[1])} A {R} {R} 0 0 1 {_n(p1[0])},{_n(p1[1])} Z" '
           f'fill="{CLARO}" stroke="{{c}}" stroke-width="2"/>', [(c[0] - R, c[1]), (c[0] + R, c[1] + R)])
    d.circulo(110, c[1] + R + 34, 34, esp=2)
    return d


_fig("planificacao-piramide-quadrada", _plan_piramide, "Planificação: um quadrado no centro e um "
     "triângulo isósceles apoiado em cada um dos quatro lados do quadrado.")
_fig("planificacao-prisma-triangular", _plan_prisma_tri, "Planificação: três retângulos iguais "
     "lado a lado e dois triângulos equiláteros, um apoiado no alto e outro embaixo do retângulo do "
     "meio.")
_fig("planificacao-cone", _plan_cone, "Planificação: um setor circular e, encostado no arco do "
     "setor, um círculo.")


def _distancia_pontos():
    return _grafico(lambda x: float("nan"), xs=(-1, 6), ys=(-1, 6), pontos=[(1, 1), (4, 5)])


def _dist_rotulada():
    d = _distancia_pontos()
    k = 26
    X = lambda x: 20 + (x + 1) * k
    Y = lambda y: 20 + (6 - y) * k
    _seg(d, (X(1), Y(1)), (X(4), Y(5)), esp=2.2, cor=DESTAQUE)
    d.texto(X(1) + 6, Y(1) + 14, "A(1, 1)", tam=11, negrito=True)
    d.texto(X(4) + 6, Y(5) - 6, "B(4, 5)", tam=11, negrito=True)
    return d


_fig("distancia-a-b-grade", _dist_rotulada, "Plano cartesiano com grade de 1 em 1, com os pontos "
     "A(1, 1) e B(4, 5) marcados e ligados por um segmento.")


def _area_semicirculo():
    d = Desenho(300, 160)
    k = 25
    x0, y0 = 30, 30
    _pol(d, [(x0, y0), (x0 + 8 * k, y0), (x0 + 8 * k, y0 + 4 * k), (x0, y0 + 4 * k)], preench=CLARO, esp=0)
    d._add(f'<path d="M {x0 + 8 * k},{y0} A {2 * k} {2 * k} 0 0 1 {x0 + 8 * k},{y0 + 4 * k} Z" '
           f'fill="{CLARO}" stroke="none"/>', [(x0 + 8 * k, y0), (x0 + 10 * k, y0 + 4 * k)])
    d.linha([(x0 + 8 * k, y0), (x0, y0), (x0, y0 + 4 * k), (x0 + 8 * k, y0 + 4 * k)], esp=2.2)
    d._add(f'<path d="M {x0 + 8 * k},{y0} A {2 * k} {2 * k} 0 0 1 {x0 + 8 * k},{y0 + 4 * k}" '
           f'fill="none" stroke="{{c}}" stroke-width="2.2"/>', [(x0 + 8 * k, y0), (x0 + 10 * k, y0 + 4 * k)])
    _seg(d, (x0 + 8 * k, y0), (x0 + 8 * k, y0 + 4 * k), esp=1, tracejado="4,4")
    _cota(d, (x0, y0 + 4 * k), (x0 + 8 * k, y0 + 4 * k), "8 m", off=14)
    _cota(d, (x0, y0 + 4 * k), (x0, y0), "4 m", off=-14)
    return d


_fig("area-retangulo-semicirculo", _area_semicirculo, "Figura formada por um retângulo de 8 m por "
     "4 m e um semicírculo encostado no lado direito do retângulo, com diâmetro igual a esse lado "
     "de 4 m.")


def _tales_triangulo():
    d = Desenho(260, 220)
    A, B, C = (130, 20), (30, 200), (230, 200)
    t = 0.4
    D = (A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t)
    E = (A[0] + (C[0] - A[0]) * t, A[1] + (C[1] - A[1]) * t)
    _pol(d, [A, B, C], esp=2.2)
    _seg(d, D, E, esp=2, cor=DESTAQUE)
    _rot(d, A, D, "4", lado=1, dist=12)
    _rot(d, D, B, "6", lado=1, dist=12)
    _rot(d, A, E, "6", lado=-1, dist=12)
    _rot(d, E, C, "x", lado=-1, dist=12, italico=True, tam=13)
    for p, n, dx, dy in ((A, "A", 0, -8), (B, "B", -10, 6), (C, "C", 10, 6), (D, "D", -12, 2), (E, "E", 12, 2)):
        _ponto(d, p, n, dx=dx, dy=dy, r=2.5)
    return d


_fig("tales-triangulo-de-paralelo-bc", _tales_triangulo, "Triângulo ABC com o segmento DE "
     "paralelo a BC, D sobre AB e E sobre AC. AD = 4, DB = 6, AE = 6 e EC = x.")


def _central_inscrito():
    d = Desenho(240, 240)
    c, R = (120, 120), 90
    P1, P2 = _polar(c, R, 220), _polar(c, R, 320)
    V = _polar(c, R, 100)
    d.circulo(c[0], c[1], R, esp=2)
    _seg(d, c, P1, esp=1.8)
    _seg(d, c, P2, esp=1.8)
    _seg(d, V, P1, esp=1.8, cor=DESTAQUE)
    _seg(d, V, P2, esp=1.8, cor=DESTAQUE)
    _arco(d, c, P1, P2, r=20, texto="100°", dist=14)
    _arco(d, V, P1, P2, r=26, texto="x", dist=12, cor=DESTAQUE)
    _ponto(d, c, "O", dx=10, dy=-6, r=2.5)
    _ponto(d, V, "V", dy=-8, r=2.5)
    _ponto(d, P1, "P", dx=-10, dy=10, r=2.5)
    _ponto(d, P2, "Q", dx=10, dy=10, r=2.5)
    return d


_fig("angulo-central-inscrito-100", _central_inscrito, "Circunferência de centro O. Os pontos P e Q "
     "estão na parte de baixo da circunferência e V, no alto. O ângulo central POQ mede 100°; o "
     "ângulo PVQ, com vértice V na circunferência e apoiado no mesmo arco PQ, é x.")


def _prisma_hex():
    d = Desenho(240, 220)
    c1, c2 = (110, 60), (130, 170)
    rx, ry = 70, 24
    top = [(c1[0] + rx * math.cos(math.radians(60 * i)), c1[1] + ry * math.sin(math.radians(60 * i)))
           for i in range(6)]
    bot = [(x + (c2[0] - c1[0]), y + (c2[1] - c1[1])) for x, y in top]
    visivel_bot = [0, 1, 2, 3]       # arestas da base de baixo voltadas para frente
    _pol(d, top, preench=CLARO, esp=2)
    for i in range(6):
        a, b = bot[i], bot[(i + 1) % 6]
        tracejada = i not in (0, 1, 2)
        _seg(d, a, b, esp=2 if not tracejada else 1.2, tracejado="5,4" if tracejada else None)
        lat_oculta = i in (4, 5)
        _seg(d, top[i], bot[i], esp=2 if not lat_oculta else 1.2, tracejado="5,4" if lat_oculta else None)
    return d


_fig("prisma-hexagonal", _prisma_hex, "Prisma de base hexagonal em perspectiva, com as arestas "
     "escondidas desenhadas tracejadas.")
