# -*- coding: utf-8 -*-
"""Figuras da matéria Biologia Celular: esquemas didáticos (fora de escala) de
célula vegetal e animal, membrana em mosaico fluido, cortes transversais de
centríolo e axonema, hemácias e transporte pela membrana."""
import math
from desenho import Desenho, simbolo, _n

M = "biologia-celular"
VERDE = "#8BC48A"
VERDE_ESC = "#3F7D3E"
AZUL_V = "#CFE3F3"
NUCLEO = "#D9C7E8"
MITO = "#F2B8A0"
GOLGI = "#F4D58D"
CABECA = "#7FA8D6"
PROT = "#E8A87C"


def _fig(nome, fn, alt):
    def desenhar(dd):
        o = fn()
        dd.w, dd.h, dd.itens = o.w, o.h, o.itens
    simbolo(M, nome, desenhar, alt=alt)


def _elipse(d, cx, cy, rx, ry, preench="none", esp=1.6, rot=0):
    d._add(f'<ellipse cx="{_n(cx)}" cy="{_n(cy)}" rx="{_n(rx)}" ry="{_n(ry)}" fill="{preench}" '
           f'stroke="{{c}}" stroke-width="{_n(esp)}" transform="rotate({rot} {_n(cx)} {_n(cy)})"/>',
           [(cx - max(rx, ry), cy - max(rx, ry)), (cx + max(rx, ry), cy + max(rx, ry))])


def _chamada(d, alvo, texto_pos, rotulo):
    d.linha([texto_pos, alvo], esp=1.2)
    d._add(f'<circle cx="{_n(alvo[0])}" cy="{_n(alvo[1])}" r="2.5" fill="{{c}}"/>',
           [(alvo[0] - 3, alvo[1] - 3), (alvo[0] + 3, alvo[1] + 3)])
    d.texto(texto_pos[0] + (6 if texto_pos[0] >= alvo[0] else -6), texto_pos[1] + 5, rotulo, tam=15,
            negrito=True, ancora="start" if texto_pos[0] >= alvo[0] else "end")


def _mitocondria(d, cx, cy, rx=20, ry=10, rot=0):
    _elipse(d, cx, cy, rx, ry, preench=MITO, rot=rot)
    a = math.radians(rot)
    pts = []
    for i in range(9):
        t = -rx * 0.75 + i * rx * 1.5 / 8
        y = (ry * 0.55) * (1 if i % 2 else -1)
        pts.append((cx + t * math.cos(a) - y * math.sin(a), cy + t * math.sin(a) + y * math.cos(a)))
    d.linha(pts, esp=1.1)


def _celula_vegetal():
    d = Desenho(320, 240)
    d.retangulo(30, 20, 240, 200, preench="#E6F2DC", esp=4)          # parede
    d.retangulo(38, 28, 224, 184, preench="#fff", esp=1.2)          # membrana
    d._add(f'<rect x="110" y="60" width="140" height="120" rx="30" fill="{AZUL_V}" stroke="{{c}}" '
           f'stroke-width="1.4"/>', [(110, 60), (250, 180)])        # vacúolo central
    d.circulo(72, 70, 24, preench=NUCLEO, esp=1.6)
    d.circulo(76, 66, 7, preench="#A58CC4", esp=1)
    for cx, cy, r in ((70, 140, 0), (80, 190, 20), (150, 196, -10), (230, 44, 0), (150, 42, 10)):
        _elipse(d, cx, cy, 18, 9, preench=VERDE, rot=r)
        for k in (-1, 0, 1):
            dx, dy = 9 * math.cos(math.radians(r)), 9 * math.sin(math.radians(r))
            d.linha([(cx - dx + k * 3 * math.sin(math.radians(r)), cy - dy + k * 3),
                     (cx + dx + k * 3 * math.sin(math.radians(r)), cy + dy + k * 3)], esp=0.8, cor=VERDE_ESC)
    _mitocondria(d, 100, 110, 12, 6, 30)
    _chamada(d, (70, 140), (14, 165), "X")
    _chamada(d, (200, 120), (295, 120), "Y")
    return d


_fig("celula-vegetal-x-y", _celula_vegetal, "Esquema de uma célula vegetal, retangular, com uma "
     "camada externa espessa e, por dentro dela, uma linha fina. No centro, uma grande bolsa azul "
     "clara ocupa a maior parte da célula (marcada Y). No canto, um corpo redondo com outro menor "
     "dentro. Espalhadas, várias estruturas verdes e ovais com linhas internas paralelas (uma delas "
     "marcada X).")


def _golgi(d, x, y):
    for i in range(4):
        yy = y + i * 7
        d._add(f'<path d="M {x - 26 + i * 2},{yy} Q {x},{yy - 10} {x + 26 - i * 2},{yy}" fill="none" '
               f'stroke="#B8902D" stroke-width="4" stroke-linecap="round"/>', [(x - 26, yy - 10), (x + 26, yy)])
    for dx in (-30, 32):
        d.circulo(x + dx, y + 26, 3.5, preench=GOLGI, esp=1)


def _celula_animal():
    d = Desenho(320, 240)
    pts = [(160 + 120 * math.cos(t) * (1 + 0.06 * math.sin(3 * t)), 120 + 95 * math.sin(t) * (1 + 0.05 * math.cos(2 * t)))
           for t in [i * 2 * math.pi / 60 for i in range(60)]]
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="#FBF1EA" stroke="{{c}}" stroke-width="2"/>', pts)
    d.circulo(150, 118, 34, preench=NUCLEO, esp=1.8)
    d.circulo(156, 112, 10, preench="#A58CC4", esp=1)
    _golgi(d, 230, 92)
    _mitocondria(d, 96, 168, 22, 11, -15)
    _mitocondria(d, 220, 170, 18, 9, 20)
    for cx, cy in ((90, 90), (200, 200), (120, 200)):
        d.circulo(cx, cy, 6, preench="#C9D3DC", esp=1)
    _chamada(d, (230, 96), (300, 60), "X")
    _chamada(d, (96, 168), (30, 200), "Y")
    return d


_fig("celula-animal-x-y", _celula_animal, "Esquema de uma célula animal de contorno arredondado e "
     "irregular, com núcleo e nucléolo no centro. À direita, uma pilha de sacos achatados e curvos, "
     "com pequenas vesículas nas pontas (marcada X). Embaixo, à esquerda, uma estrutura oval com uma "
     "linha interna dobrada em zigue-zague (marcada Y); há outra igual à direita e pequenas vesículas "
     "redondas espalhadas.")


def _fosfolipidio(d, x, y, cima=True):
    s = 1 if cima else -1
    d.circulo(x, y, 4.5, preench=CABECA, esp=1)
    d.linha([(x - 2, y + s * 4), (x - 2, y + s * 22)], esp=1.2)
    d.linha([(x + 2, y + s * 4), (x + 2, y + s * 22)], esp=1.2)


def _membrana():
    d = Desenho(340, 220)
    yt, yb = 80, 140
    for i in range(32):
        x = 20 + i * 10
        if 120 <= x <= 160:
            continue
        _fosfolipidio(d, x, yt, True)
        _fosfolipidio(d, x, yb, False)
    d._add(f'<rect x="118" y="62" width="44" height="96" rx="18" fill="{PROT}" stroke="{{c}}" '
           f'stroke-width="1.6"/>', [(118, 62), (162, 158)])          # transmembrana
    _elipse(d, 250, 152, 22, 11, preench=PROT)                        # periférica, face interna
    for x0 in (140, 230):                                             # cadeias de carboidrato
        y = 62 if x0 == 140 else 75
        for k in range(4):
            xh, yh = x0 + (k % 2) * 7 - 3, y - 4 - k * 7.5
            pts = [(xh + 4 * math.cos(math.radians(60 * j)), yh + 4 * math.sin(math.radians(60 * j))) for j in range(6)]
            caminho = " ".join(f"{_n(px)},{_n(py)}" for px, py in pts)
            d._add(f'<polygon points="{caminho}" fill="#9BCB8E" stroke="{{c}}" stroke-width="1"/>', pts)
    _chamada(d, (140, 110), (200, 196), "X")
    return d


_fig("membrana-mosaico-fluido", _membrana, "Esquema de membrana em mosaico fluido: duas fileiras de "
     "moléculas com uma cabeça redonda e duas caudas, as caudas voltadas umas para as outras no meio. "
     "Uma proteína grande atravessa as duas fileiras de lado a lado (marcada X). Na face de cima, "
     "cadeias de pequenos hexágonos presas à proteína e a uma das moléculas; na face de baixo, uma "
     "proteína oval apenas encostada.")


def _anel_tubulos(d, cx, cy, R, n_por_grupo, centrais):
    for i in range(9):
        a = math.radians(90 - i * 40)
        gx, gy = cx + R * math.cos(a), cy - R * math.sin(a)
        dirg = a - math.radians(55)          # grupos inclinados, em cata-vento
        for k in range(n_por_grupo):
            t = (k - (n_por_grupo - 1) / 2) * 9
            d.circulo(gx + t * math.cos(dirg), gy - t * math.sin(dirg), 5, preench="#C8D9EA", esp=1.3)
    if centrais:
        d.circulo(cx - 7, cy, 5, preench="#C8D9EA", esp=1.3)
        d.circulo(cx + 7, cy, 5, preench="#C8D9EA", esp=1.3)


def _centriolo():
    d = Desenho(200, 200)
    _anel_tubulos(d, 100, 100, 66, 3, False)
    return d


def _axonema():
    d = Desenho(200, 200)
    d.circulo(100, 100, 88, esp=1.6)
    _anel_tubulos(d, 100, 100, 60, 2, True)
    return d


_fig("corte-microtubulos-9x3", _centriolo, "Corte transversal de uma estrutura cilíndrica: nove "
     "grupos de três pequenos círculos (microtúbulos) dispostos em anel, sem nada no centro.")
_fig("corte-microtubulos-9x2-2", _axonema, "Corte transversal de uma estrutura cilíndrica envolta "
     "por membrana: nove pares de pequenos círculos (microtúbulos) em anel e mais dois círculos "
     "isolados no centro.")


def _hemacias():
    d = Desenho(330, 130)
    cx, cy = 60, 60
    pts = []
    for i in range(48):
        a = 2 * math.pi * i / 48
        r = 26 + (6 if i % 4 == 0 else 0)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="#D9534F" stroke="{{c}}" stroke-width="1.4"/>', pts)
    d.circulo(165, 60, 32, preench="#D9534F", esp=1.4)
    d.circulo(165, 60, 13, preench="#EE9B98", esp=0)
    d.circulo(275, 60, 42, preench="#E8746F", esp=1.4)
    for x, t in ((60, "A"), (165, "B"), (275, "C")):
        d.texto(x, 122, t, tam=14, ancora="middle", negrito=True)
    return d


_fig("hemacias-abc", _hemacias, "Três hemácias vistas de frente. A: menor, murcha, com a borda "
     "cheia de pontas. B: disco com o centro mais claro, de aspecto normal. C: maior e arredondada, "
     "sem o centro claro, inchada.")


def _transportes():
    d = Desenho(360, 230)
    yt, yb = 90, 140
    d._add(f'<rect x="10" y="{yt}" width="340" height="{yb - yt}" fill="#E8EEF4" stroke="none"/>', [(10, yt), (350, yb)])
    d.linha([(10, yt), (350, yt)], esp=2)
    d.linha([(10, yb), (350, yb)], esp=2)
    d.texto(14, 22, "meio extracelular", tam=10, italico=True)
    d.texto(14, 222, "citoplasma", tam=10, italico=True)
    # A: difusão simples (muitas partículas fora, poucas dentro)
    for x, y in ((40, 45), (60, 60), (75, 40), (50, 75), (85, 70)):
        d.circulo(x, y, 3.5, preench="#5B7A99", esp=0)
    d.circulo(70, 180, 3.5, preench="#5B7A99", esp=0)
    d.linha([(65, 60), (65, 170)], esp=1.8)
    d._add('<polygon points="65,178 60,168 70,168" fill="{c}"/>', [(60, 168), (70, 178)])
    # B: canal
    d._add(f'<rect x="150" y="{yt - 6}" width="14" height="{yb - yt + 12}" fill="{PROT}" stroke="{{c}}" stroke-width="1.4"/>',
           [(150, yt - 6), (164, yb + 6)])
    d._add(f'<rect x="176" y="{yt - 6}" width="14" height="{yb - yt + 12}" fill="{PROT}" stroke="{{c}}" stroke-width="1.4"/>',
           [(176, yt - 6), (190, yb + 6)])
    for x, y in ((158, 40), (180, 55), (170, 30), (190, 72)):
        d._add(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6" fill="#2E7D4F"/>', [(x - 3, y - 3), (x + 3, y + 3)])
    d._add('<rect x="167" y="185" width="6" height="6" fill="#2E7D4F"/>', [(167, 185), (173, 191)])
    d.linha([(170, 70), (170, 172)], esp=1.8)
    d._add('<polygon points="170,180 165,170 175,170" fill="{c}"/>', [(165, 170), (175, 180)])
    # C: bomba (poucas partículas dentro → muitas fora), com ATP
    d._add(f'<rect x="262" y="{yt - 10}" width="46" height="{yb - yt + 20}" rx="12" fill="{PROT}" stroke="{{c}}" '
           f'stroke-width="1.4"/>', [(262, yt - 10), (308, yb + 10)])
    for x, y in ((262, 40), (285, 30), (300, 55), (316, 38), (276, 62)):
        d._add(f'<polygon points="{x},{y - 4} {x + 4},{y + 3} {x - 4},{y + 3}" fill="#B5524A"/>', [(x - 4, y - 4), (x + 4, y + 3)])
    d._add('<polygon points="285,176 289,183 281,183" fill="#B5524A"/>', [(281, 176), (289, 183)])
    d.linha([(285, 170), (285, 64)], esp=1.8)
    d._add('<polygon points="285,56 280,66 290,66" fill="{c}"/>', [(280, 56), (290, 66)])
    d.texto(318, 192, "ATP → ADP + P", tam=10)
    for x, t in ((65, "A"), (170, "B"), (285, "C")):
        d.texto(x - 22, 120, t, tam=15, ancora="middle", negrito=True)
    return d


_fig("transporte-membrana-abc", _transportes, "Esquema de uma membrana horizontal, com o meio "
     "extracelular em cima e o citoplasma embaixo, e três mecanismos lado a lado. A: partículas, "
     "numerosas em cima e poucas embaixo, atravessando a própria bicamada de cima para baixo. B: "
     "partículas, numerosas em cima, passando de cima para baixo por um canal formado por "
     "proteínas. C: partículas, poucas embaixo e numerosas em cima, levadas de baixo para cima por "
     "uma proteína, com a indicação ATP → ADP + P.")
