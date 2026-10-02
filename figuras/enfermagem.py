# -*- coding: utf-8 -*-
"""Figuras da matéria Enfermagem.

Traçados de ECG são SINTÉTICOS, gerados por soma de funções sobre a grade
padrão (25 mm/s; quadrado grande = 0,2 s): servem para reconhecer o padrão
de cada ritmo de parada (FV caótica, TV larga e regular, assistolia plana,
AESP organizada), não para medir intervalos. Os demais desenhos são
esquemas: tórax com espaços intercostais, silhueta da regra dos nove,
camadas da pele, curva de peso por idade com escores z e posições no leito.
"""
import math
from desenho import Desenho, simbolo, _n, DESTAQUE

M = "enfermagem"
ROSA = "#F2C4C4"
ROSA_FINO = "#FAE3E3"
PELE = "#F6E0CC"
GORDURA = "#F7EDB4"
MUSCULO = "#D99A8C"
QUEIMA = "#E9967A"


def _fig(nome, fn, alt):
    def desenhar(dd):
        o = fn()
        dd.w, dd.h, dd.itens = o.w, o.h, o.itens
    simbolo(M, nome, desenhar, alt=alt)


def _pol(d, pts, preench="none", esp=2, cor=None):
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="{preench}" stroke="{cor or "{c}"}" '
           f'stroke-width="{_n(esp)}" stroke-linejoin="round"/>', pts)


# ---- ECG -------------------------------------------------------------------------

def _g(t, c, w):
    return math.exp(-((t - c) / w) ** 2)


def _batimento(t):
    """Um complexo P-QRS-T normal; t em segundos desde o início do ciclo."""
    return (0.15 * _g(t, 0.10, 0.025) - 0.12 * _g(t, 0.19, 0.010) + 1.0 * _g(t, 0.21, 0.011)
            - 0.28 * _g(t, 0.235, 0.012) + 0.30 * _g(t, 0.45, 0.050))


RITMOS = {
    "fv": lambda t: (0.45 + 0.25 * math.sin(2 * math.pi * 0.6 * t)) *
                    (0.6 * math.sin(2 * math.pi * 4.7 * t) + 0.35 * math.sin(2 * math.pi * 7.1 * t + 1.1)
                     + 0.25 * math.sin(2 * math.pi * 2.9 * t + 2.3)),
    # QRS largo (≈0,16 s) e onda T oposta, ciclo de 0,33 s (≈180/min)
    "tv": lambda t: (1.0 * _g(t % 0.33, 0.09, 0.045) - 0.55 * _g(t % 0.33, 0.22, 0.05)
                     - 0.25 * _g(t % 0.33, 0.03, 0.02)),
    "assistolia": lambda t: 0.03 * math.sin(2 * math.pi * 0.35 * t) + 0.01 * math.sin(2 * math.pi * 1.9 * t),
    "aesp": lambda t: _batimento(t % 0.8),
}


def _ecg(ritmo, segundos=3.0):
    pxs = 110                     # px por segundo (5 quadrados grandes)
    h = 140
    w = segundos * pxs
    d = Desenho(w + 20, h + 20)
    x0, y0 = 10, 10
    for i in range(int(segundos * 25) + 1):         # quadrado pequeno = 0,04 s
        x = x0 + i * pxs / 25
        d.linha([(x, y0), (x, y0 + h)], esp=1.2 if i % 5 == 0 else 0.5,
                cor=ROSA if i % 5 == 0 else ROSA_FINO)
    for j in range(int(h / (pxs / 25)) + 1):
        y = y0 + j * pxs / 25
        d.linha([(x0, y), (x0 + w, y)], esp=1.2 if j % 5 == 0 else 0.5,
                cor=ROSA if j % 5 == 0 else ROSA_FINO)
    base = y0 + h * 0.6
    amp = h * 0.42
    f = RITMOS[ritmo]
    pts = [(x0 + k / 4, base - amp * f(k / 4 / pxs)) for k in range(int(w * 4) + 1)]
    d.linha(pts, esp=1.8)
    return d


_ALT_ECG = "Faixa de eletrocardiograma sobre papel quadriculado, com cerca de 3 segundos de registro. "
_fig("ecg-fibrilacao-ventricular", lambda: _ecg("fv"), _ALT_ECG +
     "O traçado é uma ondulação irregular e desorganizada, de amplitude e frequência variáveis, "
     "sem complexos QRS, ondas P ou ondas T identificáveis.")
_fig("ecg-taquicardia-ventricular", lambda: _ecg("tv"), _ALT_ECG +
     "Complexos largos, grandes e iguais entre si, que se repetem de forma regular e muito rápida "
     "(cerca de 9 complexos em 3 segundos), sem ondas P visíveis.")
_fig("ecg-assistolia", lambda: _ecg("assistolia"), _ALT_ECG +
     "O traçado é praticamente uma linha reta, com uma ondulação mínima da linha de base e nenhum "
     "complexo.")
_fig("ecg-ritmo-organizado", lambda: _ecg("aesp"), _ALT_ECG +
     "Complexos regulares e organizados, cada um com onda P, QRS estreito e onda T, numa frequência "
     "de cerca de 75 por minuto.")


# ---- tórax: espaços intercostais ------------------------------------------------------

def _torax():
    d = Desenho(300, 300)
    cx = 150
    _pol(d, [(70, 40), (230, 40), (262, 90), (250, 280), (50, 280), (38, 90)], preench=PELE, esp=2)
    d.retangulo(cx - 12, 52, 24, 150, preench="#fff", esp=1.6)       # esterno
    d.texto(cx, 222, "esterno", tam=9, ancora="middle")
    for lado in (-1, 1):                                             # clavículas
        d.linha([(cx + lado * 14, 50), (cx + lado * 92, 40)], esp=3)
    for i in range(1, 8):                                            # costelas
        y = 46 + i * 24
        for lado in (-1, 1):
            d.linha([(cx + lado * 13, y), (cx + lado * 70, y + 6), (cx + lado * 98, y + 16)], esp=1.6)
    for i in range(1, 7):                                            # nº do espaço, à esquerda do paciente
        y = 46 + i * 24 + 14
        d.texto(cx + 108, y + 8, f"{i}º", tam=9)
    xl = cx + 62
    d.linha([(xl, 40), (xl, 270)], esp=1, tracejado="5,4")
    d.texto(xl + 3, 284, "LHC", tam=9)
    ye = 46 + 4 * 24 + 13
    d._add(f'<circle cx="{cx - 20}" cy="{ye}" r="7" fill="{DESTAQUE}"/>', [(cx - 27, ye - 7), (cx - 13, ye + 7)])
    d.texto(cx - 32, ye + 5, "X", tam=14, ancora="end", negrito=True)
    d.texto(40, 30, "D", tam=13, negrito=True)
    d.texto(260, 30, "E", tam=13, negrito=True, ancora="end")
    return d


_fig("torax-eletrodo-x", _torax, "Tórax visto de frente, com o lado direito do paciente (D) à "
     "esquerda da figura e o esquerdo (E) à direita. Esterno no centro, costelas desenhadas dos dois "
     "lados e os espaços intercostais numerados de 1º a 6º do lado esquerdo do paciente; linha "
     "hemiclavicular (LHC) esquerda tracejada. Um eletrodo, marcado X, está no lado direito do "
     "paciente, colado à borda do esterno, no mesmo nível do 4º espaço intercostal.")


# ---- regra dos nove ---------------------------------------------------------------------

def _silhueta():
    d = Desenho(220, 300)
    cx = 110
    pinta = lambda q: QUEIMA if q else "#fff"
    d.circulo(cx, 34, 22, preench=pinta(True), esp=2)
    d.retangulo(cx - 8, 56, 16, 10, preench="#fff", esp=1.6)
    d.retangulo(cx - 40, 66, 80, 104, preench="#fff", esp=2)
    for lado in (-1, 1):
        x = cx + lado * 40
        _pol(d, [(x, 70), (x + lado * 22, 76), (x + lado * 34, 168), (x + lado * 14, 170), (x, 100)],
             preench=pinta(True))
        _pol(d, [(cx + lado * 4, 170), (cx + lado * 38, 170), (cx + lado * 32, 288), (cx + lado * 10, 288)],
             preench="#fff")
    d.texto(cx, 120, "tronco", tam=10, ancora="middle", italico=True)
    return d


_fig("regra-dos-nove-cabeca-bracos", _silhueta, "Silhueta de um adulto de frente. Estão "
     "sombreadas, como queimadas, a cabeça inteira e os dois membros superiores inteiros; tronco e "
     "membros inferiores sem sombra.")


# ---- camadas da pele -----------------------------------------------------------------------

CAMADAS = [("epiderme", 10, PELE), ("derme", 34, "#EFC9B0"), ("tecido subcutâneo", 46, GORDURA),
           ("músculo", 50, MUSCULO)]


def _camadas(d, x0, x1, y0):
    y = y0
    limites = {}
    for nome, h, cor in CAMADAS:
        d._add(f'<rect x="{x0}" y="{_n(y)}" width="{x1 - x0}" height="{h}" fill="{cor}" stroke="{{c}}" '
               f'stroke-width="0.8"/>', [(x0, y), (x1, y + h)])
        d.texto(x1 + 6, y + h / 2 + 4, nome, tam=10)
        limites[nome] = (y, y + h)
        y += h
    return limites


def _agulha(d, xp, yp, graus, comp, rot):
    a = math.radians(graus)
    xt, yt = xp - comp * math.cos(a), yp - comp * math.sin(a)
    xb, yb = xt - 46 * math.cos(a), yt - 46 * math.sin(a)
    d.linha([(xb, yb), (xt, yt)], esp=7, cor="#9AA8B5")               # seringa
    d.linha([(xt, yt), (xp, yp)], esp=1.8)                            # agulha
    d.texto(xb - 4, yb - 4, rot, tam=14, ancora="end", negrito=True)


def _vias():
    d = Desenho(440, 230)
    topo = 90
    lim = _camadas(d, 20, 340, topo)
    for x, alvo, dy, graus, rot in ((70, "músculo", 22, 90, "A"), (200, "tecido subcutâneo", 20, 45, "B"),
                                    (320, "derme", 6, 15, "C")):
        yp = lim[alvo][0] + dy
        _agulha(d, x, yp, graus, (yp - topo) / math.sin(math.radians(graus)) + 16, rot)
    return d


_fig("agulhas-camadas-pele", _vias, "Corte esquemático das camadas, de cima para baixo: epiderme, "
     "derme, tecido subcutâneo e músculo. Três agulhas: A, perpendicular à pele (90°), com a ponta "
     "no músculo; B, inclinada a cerca de 45°, com a ponta no tecido subcutâneo; C, quase paralela à "
     "pele (cerca de 15°), com a ponta logo abaixo da epiderme, na derme.")


def _lesao_estagio3():
    d = Desenho(340, 200)
    lim = _camadas(d, 20, 240, 40)
    fundo = lim["tecido subcutâneo"][0] + 26
    pts = [(80, 40), (100, 52), (112, fundo - 6), (130, fundo), (160, fundo + 2), (178, fundo - 4),
           (190, 54), (205, 40)]
    _pol(d, pts, preench="#B5524A", esp=1.4)
    return d


_fig("lesao-pressao-corte-subcutaneo", _lesao_estagio3, "Corte esquemático das camadas da pele "
     "(epiderme, derme, tecido subcutâneo e músculo) com uma lesão em forma de cratera: ela "
     "atravessa toda a epiderme e toda a derme e chega ao tecido subcutâneo, sem alcançar o músculo.")


# ---- curva de peso por idade -----------------------------------------------------------

def _curva_peso():
    d = Desenho(320, 240)
    X0, Y0, W, H = 40, 200, 240, 170
    X = lambda m: X0 + m / 24 * W
    Y = lambda kg: Y0 - (kg - 2) / 14 * H
    d.linha([(X0, Y0 - H), (X0, Y0), (X0 + W, Y0)], esp=1.6)
    for m in range(0, 25, 6):
        d.texto(X(m), Y0 + 14, str(m), tam=9, ancora="middle")
    for kg in range(2, 17, 2):
        d.texto(X0 - 5, Y(kg) + 3, str(kg), tam=9, ancora="end")
        d.linha([(X0, Y(kg)), (X0 + W, Y(kg))], esp=0.5, cor="#DDE4EA")
    d.texto(X0 + W / 2, Y0 + 30, "idade (meses)", tam=10, ancora="middle", italico=True)
    d.texto(X0 - 4, Y0 - H - 8, "peso (kg)", tam=10, italico=True)
    # aproximação da mediana e dos escores z (curva OMS, meninos, forma)
    med = lambda m: 3.3 + 7.6 * (1 - math.exp(-m / 7.0)) + 0.11 * m
    z = {"+2": 1.24, "0": 1.0, "−2": 0.80, "−3": 0.71}
    for rot, fat in z.items():
        pts = [(X(m), Y(med(m) * fat)) for m in [i * 0.5 for i in range(49)]]
        d.linha(pts, esp=2 if rot == "0" else 1.4, cor="#2E7D4F" if rot == "0" else
                ("#C0392B" if rot in ("−3", "+2") else "#D68910"))
        d.texto(X(24) + 4, Y(med(24) * fat) + 4, rot, tam=10, negrito=True)
    p = (X(12), Y(med(12) * 0.755))
    d._add(f'<circle cx="{_n(p[0])}" cy="{_n(p[1])}" r="4.5" fill="{DESTAQUE}"/>',
           [(p[0] - 5, p[1] - 5), (p[0] + 5, p[1] + 5)])
    return d


_fig("curva-peso-idade-ponto", _curva_peso, "Gráfico de peso (kg) por idade (0 a 24 meses), com "
     "quatro curvas identificadas à direita, de cima para baixo: escore z +2, 0, −2 e −3. Um ponto "
     "azul, aos 12 meses, está abaixo da curva −2 e acima da curva −3.")


# ---- posições no leito --------------------------------------------------------------------

def _pessoa(d, pts):
    """pts: cabeça, ombro, quadril, joelho, pé."""
    cab, omb, qua, joe, pe = pts
    d.circulo(cab[0], cab[1], 11, preench=PELE, esp=1.8)
    d.linha([omb, qua, joe, pe], esp=6, cor="#5B7A99")
    d.linha([omb, (omb[0] + (qua[0] - omb[0]) * 0.5, omb[1] + (qua[1] - omb[1]) * 0.5 - 4)], esp=4, cor="#5B7A99")


def _fowler():
    d = Desenho(320, 200)
    d.linha([(60, 150), (280, 150)], esp=5)                       # estrado
    d.linha([(70, 150), (70, 185)], esp=3)
    d.linha([(270, 150), (270, 185)], esp=3)
    a = math.radians(50)
    dobra = (150, 150)
    topo = (dobra[0] - 100 * math.cos(a), dobra[1] - 100 * math.sin(a))
    d.linha([dobra, topo], esp=5)                                  # cabeceira elevada
    u = (-math.cos(a), -math.sin(a))              # ao longo da cabeceira, para cima
    n = (math.sin(a), -math.cos(a))               # perpendicular, para fora do leito
    em = lambda ao_longo, fora: (dobra[0] + u[0] * ao_longo + n[0] * fora,
                                 dobra[1] + u[1] * ao_longo + n[1] * fora)
    _pessoa(d, [em(98, 12), em(78, 8), (dobra[0] + 10, 141), (205, 134), (262, 141)])
    return d


def _trendelenburg():
    d = Desenho(320, 200)
    a = math.radians(-15)                                          # cabeça mais baixa
    p0, p1 = (60, 120), (280, 120 + 220 * math.sin(a))
    d.linha([p0, p1], esp=5)
    d.linha([(70, 122), (70, 185)], esp=3)
    d.linha([(270, p1[1] + 2), (270, 185)], esp=3)
    off = lambda x, dy: (x, p0[1] + (x - 60) * math.tan(a) - dy)
    _pessoa(d, [off(80, 14), off(100, 9), off(175, 9), off(225, 9), off(265, 9)])
    return d


_fig("posicao-fowler", _fowler, "Paciente deitado de costas num leito com a cabeceira elevada "
     "cerca de 50° em relação ao estrado; tronco recostado e pernas estendidas no plano do leito.")
_fig("posicao-trendelenburg", _trendelenburg, "Paciente deitado de costas sobre uma maca reta e "
     "inclinada, com a cabeça mais baixa que os pés.")
