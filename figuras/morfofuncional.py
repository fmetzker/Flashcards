# -*- coding: utf-8 -*-
"""Figuras da matéria Ciências Morfofuncionais: esquemas didáticos (fora de
escala) de pele, osso, músculo e sistema reprodutor, redesenhados a partir do
que as questões da disciplina pedem para reconhecer — nunca recortados do
material (o repositório e o site são públicos).

Cada esquema é desenhado uma vez e marca as estruturas com letras ou números;
cada cartão pergunta por uma marca diferente sobre a mesma figura."""
import math
from desenho import Desenho, simbolo, _n

M = "morfofuncional"
EPIDERME = "#F3D2B8"
CORNEO = "#E9C9A0"
DERME = "#FBE9E3"
GORDURA = "#FFF3C4"
SEBACEA = "#F4D58D"
SUOR = "#BFD9EE"
ARTERIA = "#C0504D"
VEIA = "#4F6FA8"
PELO = "#5A3E2B"
OSSO = "#F1E6CF"
ESPONJOSO = "#E6D3AE"
MEDULA = "#F2B8A0"
CARTILAGEM = "#CFE3F3"
MUSCULO = "#D98880"
MUSCULO_CLARO = "#F2C6C2"
NUCLEO = "#7D5BA6"


def _fig(nome, fn, alt):
    def desenhar(dd):
        o = fn()
        dd.w, dd.h, dd.itens = o.w, o.h, o.itens
    simbolo(M, nome, desenhar, alt=alt)


def _pol(d, pts, preench="none", esp=1.6, cor=None):
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="{preench}" stroke="{cor or "{c}"}" '
           f'stroke-width="{_n(esp)}" stroke-linejoin="round"/>', pts)


def _elipse(d, cx, cy, rx, ry, preench="none", esp=1.4, rot=0, cor=None):
    d._add(f'<ellipse cx="{_n(cx)}" cy="{_n(cy)}" rx="{_n(rx)}" ry="{_n(ry)}" fill="{preench}" '
           f'stroke="{cor or "{c}"}" stroke-width="{_n(esp)}" transform="rotate({rot} {_n(cx)} {_n(cy)})"/>',
           [(cx - max(rx, ry), cy - max(rx, ry)), (cx + max(rx, ry), cy + max(rx, ry))])


def _rotulo(d, x, y, t, tam=15):
    """Letra ou número de marcação, num círculo branco para não sumir no fundo."""
    d._add(f'<circle cx="{_n(x)}" cy="{_n(y)}" r="{_n(tam * 0.72)}" fill="#fff" stroke="{{c}}" '
           f'stroke-width="1.4"/>', [(x - tam * 0.72, y - tam * 0.72), (x + tam * 0.72, y + tam * 0.72)])
    d.texto(x, y + tam * 0.36, t, tam=tam, ancora="middle", negrito=True)


def _chamada(d, alvo, pos, t):
    d.linha([pos, alvo], esp=1.2)
    d._add(f'<circle cx="{_n(alvo[0])}" cy="{_n(alvo[1])}" r="2.5" fill="{{c}}"/>',
           [(alvo[0] - 3, alvo[1] - 3), (alvo[0] + 3, alvo[1] + 3)])
    _rotulo(d, pos[0], pos[1], t)


def _chave(d, x, y0, y1, t):
    """Chave vertical à direita marcando uma faixa (camada)."""
    d.linha([(x - 6, y0), (x, y0), (x, y1), (x - 6, y1)], esp=1.4)
    d.linha([(x, (y0 + y1) / 2), (x + 8, (y0 + y1) / 2)], esp=1.4)
    _rotulo(d, x + 20, (y0 + y1) / 2, t)


# ---- pele ------------------------------------------------------------------------

def _pele():
    d = Desenho(400, 300)
    x0, x1 = 20, 330
    topo, y_ep, y_de, base = 40, 72, 190, 270
    onda = [(x, y_ep + 7 * math.sin((x - x0) / 14)) for x in range(x0, x1 + 1, 5)]
    _pol(d, [(x0, base), (x0, y_de), (x1, y_de), (x1, base)], preench=GORDURA, esp=0)
    _pol(d, [(x0, y_de)] + list(reversed(onda))[::-1] + [(x1, y_de)], preench=DERME, esp=0)
    _pol(d, [(x0, topo), (x1, topo)] + list(reversed(onda)), preench=EPIDERME, esp=0)
    d._add(f'<rect x="{x0}" y="{topo}" width="{x1 - x0}" height="5" fill="{CORNEO}"/>', [(x0, topo), (x1, topo + 5)])
    d.linha([(x0, topo), (x1, topo)], esp=1.6)
    d.linha(onda, esp=1.2)
    d.linha([(x0, y_de), (x1, y_de)], esp=1, tracejado="4 3")
    # adipócitos da hipoderme
    for i, x in enumerate(range(x0 + 12, x1 - 6, 22)):
        for j, y in enumerate((y_de + 16, y_de + 40, y_de + 64)):
            d.circulo(x + (11 if j % 2 else 0), y, 10, preench="#FFFBE6", esp=1)
    # vasos da derme
    d.linha([(x0, 178), (x1, 176)], cor=ARTERIA, esp=3)
    d.linha([(x0, 185), (x1, 183)], cor=VEIA, esp=3)
    for xp in (60, 200, 290):
        d.linha([(xp, 177), (xp - 4, 120), (xp, y_ep + 4), (xp + 4, 120), (xp + 6, 184)], cor=ARTERIA, esp=1.2)
    # pelo: folículo inclinado com bulbo na derme profunda e haste saindo da superfície
    fx0, fy0, fx1, fy1 = 108, 200, 128, topo
    for dx in (-7, 7):
        d.linha([(fx0 + dx, fy0), (fx1 + dx, fy1)], esp=1.4)
    d.circulo(fx0, fy0 + 4, 10, preench="#E8C6A8", esp=1.4)
    d.linha([(fx0, fy0 - 2), (fx1, fy1), (fx1 + 6, 6)], cor=PELO, esp=3.5)
    # glândula sebácea abrindo no folículo
    for cx, cy in ((142, 108), (150, 122), (138, 124)):
        _elipse(d, cx, cy, 10, 8, preench=SEBACEA, esp=1.2)
    d.linha([(132, 112), (124, 104)], esp=1.4)
    # glândula sudorípara: novelo na derme profunda, ducto em espiral até a superfície
    nov = [(250 + 15 * math.cos(t) + 6 * math.cos(4.3 * t), 152 + 9 * math.sin(t) + 5 * math.sin(3.7 * t))
           for t in [k * 0.12 for k in range(105)]]
    d.linha(nov, cor="#2E6E9E", esp=2.4)
    duto = [(250 + 5 * math.sin(y / 6), y) for y in range(142, topo - 1, -4)]
    d.linha(duto, cor="#2E6E9E", esp=1.8)
    # marcas
    _chave(d, 340, topo, y_ep + 4, "A")
    _chave(d, 340, y_ep + 6, y_de, "B")
    _chave(d, 340, y_de + 2, base, "C")
    _chamada(d, (146, 116), (186, 96), "D")
    _chamada(d, (266, 160), (300, 140), "E")
    _chamada(d, (126, 60), (70, 18), "F")
    return d


_fig("pele-corte-camadas-anexos", _pele, "Corte esquemático da pele, de cima para baixo: uma faixa "
     "superficial de células com o limite inferior ondulado (marcada A), uma faixa mais espessa com "
     "vasos sanguíneos vermelhos e azuis (marcada B) e uma faixa profunda cheia de células grandes e "
     "redondas (marcada C). Um tubo inclinado parte de um bulbo na faixa B e deixa sair um fio escuro "
     "pela superfície (marcado F); ao lado dele, um cacho de bolsas amarelas ligado ao tubo (marcado "
     "D). À direita, um tubo enovelado no fundo da faixa B, com um ducto em espiral que sobe até a "
     "superfície (marcado E).")


def _estratos():
    d = Desenho(360, 280)
    x0, x1 = 20, 300
    faixas = [  # (y0, y1, rótulo)
        (20, 56, "1"), (56, 72, "2"), (72, 102, "3"), (102, 196, "4"), (196, 232, "5")]
    # 1 córneo: lâminas achatadas sem núcleo
    for k, y in enumerate(range(24, 54, 6)):
        desl = (k % 2) * 18
        for x in range(x0 + desl, x1 - 30, 36):
            _elipse(d, x + 16, y, 17, 2.4, preench=CORNEO, esp=0.8)
    # 2 lúcido: faixa clara homogênea
    d._add(f'<rect x="{x0}" y="57" width="{x1 - x0}" height="14" fill="#FBF6EE" stroke="{{c}}" '
           f'stroke-width="0.8"/>', [(x0, 57), (x1, 71)])
    # 3 granuloso: células achatadas com grânulos escuros
    for k, y in enumerate((80, 94)):
        for x in range(x0 + 4 + (k % 2) * 16, x1 - 30, 32):
            _elipse(d, x + 14, y, 15, 6, preench="#EBC9AE", esp=0.9)
            for g in (-8, -2, 5, 10):
                d.circulo(x + 14 + g, y + (1 if g % 2 else -1), 1.3, preench="#5A3E2B", esp=0)
    # 4 espinhoso: várias fileiras de células poligonais com núcleo
    for k, y in enumerate(range(114, 192, 20)):
        for x in range(x0 + (k % 2) * 13, x1 - 20, 26):
            cx, cy = x + 13, y
            pts = [(cx + 12 * math.cos(math.radians(30 + 60 * i)), cy + 10 * math.sin(math.radians(30 + 60 * i)))
                   for i in range(6)]
            _pol(d, pts, preench=EPIDERME, esp=0.9)
            d.circulo(cx, cy, 3.2, preench=NUCLEO, esp=0)
    # 5 basal: uma fileira de células colunares sobre a membrana basal
    for x in range(x0 + 2, x1 - 10, 14):
        d._add(f'<rect x="{x}" y="200" width="12" height="30" rx="4" fill="#E2B392" stroke="{{c}}" '
               f'stroke-width="0.9"/>', [(x, 200), (x + 12, 230)])
        _elipse(d, x + 6, 218, 3.4, 5.5, preench=NUCLEO, esp=0)
    d.linha([(x0, 233), (x1, 233)], esp=2.2)
    d._add(f'<rect x="{x0}" y="234" width="{x1 - x0}" height="30" fill="{DERME}"/>', [(x0, 234), (x1, 264)])
    d.texto((x0 + x1) / 2, 254, "derme", tam=12, ancora="middle", italico=True)
    for y0, y1, t in faixas:
        _chave(d, x1 + 10, y0 + 1, y1 - 1, t)
    return d


_fig("epiderme-estratos-numerados", _estratos, "Corte esquemático da epiderme de pele espessa sobre a "
     "derme, dividida em cinco faixas numeradas de cima para baixo. 1: lâminas achatadas empilhadas, "
     "sem núcleo. 2: faixa fina, clara e homogênea. 3: duas fileiras de células achatadas com "
     "grânulos escuros. 4: várias fileiras de células poligonais com núcleo. 5: uma única fileira de "
     "células altas apoiadas numa linha grossa, logo acima da derme.")
