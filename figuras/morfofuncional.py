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


# ---- osso ------------------------------------------------------------------------

def _caminho(d, dd, pts, preench="none", esp=1.6, cor=None):
    d._add(f'<path d="{dd}" fill="{preench}" stroke="{cor or "{c}"}" stroke-width="{_n(esp)}" '
           f'stroke-linejoin="round" stroke-linecap="round"/>', pts)


def _poros(d, x0, y0, x1, y1, dentro):
    """Poros do osso esponjoso: pequenos espaços entre as trabéculas."""
    for j, y in enumerate(range(int(y0), int(y1), 8)):
        for x in range(int(x0) + (j % 2) * 5, int(x1), 10):
            if dentro(x, y):
                _elipse(d, x, y, 3.2, 2.2, preench="#fff", esp=0.7, rot=(x * 7 + y * 3) % 60 - 30)


def _chave_esq(d, x, y0, y1, t):
    d.linha([(x + 6, y0), (x, y0), (x, y1), (x + 6, y1)], esp=1.4)
    d.linha([(x, (y0 + y1) / 2), (x - 8, (y0 + y1) / 2)], esp=1.4)
    _rotulo(d, x - 20, (y0 + y1) / 2, t)


def _osso_longo():
    d = Desenho(320, 360)
    cx = 130
    contorno = (f"M {cx - 46},62 C {cx - 46},28 {cx + 46},28 {cx + 46},62 C {cx + 46},84 {cx + 26},96 {cx + 24},110 "
                f"L {cx + 24},250 C {cx + 26},264 {cx + 46},276 {cx + 46},298 C {cx + 46},332 {cx - 46},332 {cx - 46},298 "
                f"C {cx - 46},276 {cx - 26},264 {cx - 24},250 L {cx - 24},110 C {cx - 26},96 {cx - 46},84 {cx - 46},62 Z")
    _caminho(d, contorno, [(cx - 46, 28), (cx + 46, 332)], preench=OSSO, esp=2)
    for topo, sinal in ((36, 1), (324, -1)):
        y_placa = 104 if sinal == 1 else 256
        esp_ = (f"M {cx - 39},{topo + sinal * 26} C {cx - 39},{topo} {cx + 39},{topo} {cx + 39},{topo + sinal * 26} "
                f"C {cx + 39},{topo + sinal * 44} {cx + 20},{y_placa - sinal * 4} {cx + 18},{y_placa} "
                f"L {cx - 18},{y_placa} C {cx - 20},{y_placa - sinal * 4} {cx - 39},{topo + sinal * 44} "
                f"{cx - 39},{topo + sinal * 26} Z")
        _caminho(d, esp_, [(cx - 39, min(topo, y_placa)), (cx + 39, max(topo, y_placa))], preench=ESPONJOSO, esp=0.8)
        ya, yb = sorted((topo + sinal * 8, y_placa - sinal * 6))
        _poros(d, cx - 34, ya, cx + 34, yb,
               lambda x, y, t=topo: abs(x - cx) < (32 if abs(y - t) < 44 else 14))
        d._add(f'<rect x="{cx - 24}" y="{y_placa - 3}" width="48" height="6" fill="{CARTILAGEM}" stroke="{{c}}" '
               f'stroke-width="1"/>', [(cx - 24, y_placa - 3), (cx + 24, y_placa + 3)])
        arco = (f"M {cx - 40},{topo + sinal * 18} C {cx - 34},{topo - sinal * 4} {cx + 34},{topo - sinal * 4} "
                f"{cx + 40},{topo + sinal * 18}")
        _caminho(d, arco, [(cx - 40, topo - 4), (cx + 40, topo + 18)], cor="#7FA9CF", esp=5)
    d._add(f'<rect x="{cx - 13}" y="112" width="26" height="136" rx="6" fill="#F7E7A0" stroke="{{c}}" '
           f'stroke-width="1"/>', [(cx - 13, 112), (cx + 13, 248)])
    _chave_esq(d, 64, 30, 102, "A")
    _chave_esq(d, 64, 110, 250, "B")
    _chamada(d, (cx, 180), (220, 180), "C")
    _chamada(d, (cx + 20, 104), (220, 116), "D")
    _chamada(d, (cx + 10, 66), (220, 70), "E")
    _chamada(d, (cx + 19, 220), (220, 232), "F")
    _chamada(d, (cx + 26, 34), (220, 24), "G")
    return d


_fig("osso-longo-partes", _osso_longo, "Corte longitudinal de um osso longo na vertical. As duas "
     "extremidades são alargadas e arredondadas; a de cima está toda marcada A, e a parte longa do meio "
     "está marcada B. No centro da parte longa há uma cavidade amarela (C), cercada por uma parede maciça "
     "(F). Entre cada extremidade e a parte longa, uma faixa azul estreita (D). As extremidades são "
     "preenchidas por um tecido cheio de pequenos espaços (E) e cobertas, na superfície, por uma camada "
     "azul (G).")


def _bastao(d, a, b, larg, preench=OSSO):
    """Osso em forma de bastão: cápsula de a até b."""
    (x0, y0), (x1, y1) = a, b
    for cor, w in (("{c}", larg + 2.6), (preench, larg)):
        d._add(f'<line x1="{_n(x0)}" y1="{_n(y0)}" x2="{_n(x1)}" y2="{_n(y1)}" stroke="{cor}" '
               f'stroke-width="{_n(w)}" stroke-linecap="round"/>',
               [(min(x0, x1) - larg / 2, min(y0, y1) - larg / 2), (max(x0, x1) + larg / 2, max(y0, y1) + larg / 2)])


def _mao():
    d = Desenho(320, 340)
    _bastao(d, (128, 336), (130, 300), 22)
    _bastao(d, (186, 336), (182, 302), 16)
    for x, y in ((118, 282), (140, 280), (162, 280), (184, 282), (122, 262), (143, 260), (164, 260), (184, 262)):
        _elipse(d, x, y, 10, 8, preench=OSSO, esp=1.3)
    dedos = [((112, 250), (82, 202), (30, 24)),
             ((128, 246), (118, 168), (38, 24, 18)),
             ((148, 246), (150, 162), (42, 27, 19)),
             ((168, 246), (180, 166), (39, 25, 18)),
             ((186, 250), (210, 182), (31, 20, 16))]
    for i, (base, topo, fal) in enumerate(dedos):
        _bastao(d, base, topo, 11)
        ang = math.atan2(topo[1] - base[1], topo[0] - base[0])
        x, y = topo
        for L in fal:
            x0, y0 = x + 12 * math.cos(ang), y + 12 * math.sin(ang)
            x, y = x0 + L * math.cos(ang), y0 + L * math.sin(ang)
            _bastao(d, (x0, y0), (x, y), 9 if L > 20 else 8)
    for t, (x, y) in zip("12345", ((80, 232), (110, 200), (150, 206), (190, 206), (214, 222))):
        _rotulo(d, x, y, t, tam=11)
    _chamada(d, (184, 262), (250, 270), "A")
    _chamada(d, (208, 136), (262, 120), "B")
    return d


_fig("mao-metacarpais-numerados", _mao, "Esqueleto da mão direita vista pela palma, com os dedos para "
     "cima e o polegar à esquerda. Embaixo, as pontas de dois ossos do antebraço; acima deles, um "
     "agrupamento de oito ossinhos arredondados em duas fileiras (marcado A). Desse agrupamento partem cinco "
     "ossos longos, um para cada dedo, numerados de 1 (polegar) a 5 (dedo mínimo). Na continuação de cada "
     "um, os ossinhos dos dedos: dois no polegar e três nos demais (um deles marcado B).")


def _membro_superior():
    d = Desenho(300, 430)
    _bastao(d, (40, 40), (150, 52), 12)                     # clavícula
    d.circulo(160, 70, 18, preench=OSSO, esp=1.6)          # cabeça do úmero
    _bastao(d, (162, 82), (168, 228), 18)                   # úmero
    _elipse(d, 168, 236, 24, 9, preench=OSSO, esp=1.4)      # epicôndilos
    _bastao(d, (150, 250), (132, 360), 12)                  # rádio, do lado do polegar
    _bastao(d, (184, 244), (182, 362), 13)                  # ulna
    for x, y in ((136, 372), (156, 370), (176, 372), (140, 388), (160, 388), (180, 388)):
        _elipse(d, x, y, 9, 7, preench=OSSO, esp=1.1)
    _bastao(d, (128, 386), (108, 408), 8)                   # polegar, para indicar o lado
    for x in (144, 160, 176, 190):
        _bastao(d, (x, 398), (x + 1, 418), 7)
    _chamada(d, (90, 46), (70, 16), "A")
    _chamada(d, (166, 150), (240, 140), "B")
    _chamada(d, (141, 305), (84, 300), "C")
    _chamada(d, (183, 305), (240, 300), "D")
    d.texto(98, 424, "polegar", tam=10, ancora="end", italico=True)
    return d


_fig("membro-superior-ossos", _membro_superior, "Ossos do membro superior direito em vista anterior, com "
     "o polegar à esquerda. No alto, um osso horizontal em forma de bastão (marcado A) chega ao ombro. Do "
     "ombro desce um único osso longo até o cotovelo (marcado B). Do cotovelo ao punho descem dois ossos "
     "paralelos: o do lado do polegar (marcado C) e o do lado do dedo mínimo (marcado D). Embaixo, os "
     "ossinhos do punho e o início dos dedos.")


def _articulacoes():
    d = Desenho(400, 300)
    # A: sutura — duas placas do crânio encaixadas em zigue-zague
    zz = [(100 + (6 if i % 2 else -6), 40 + i * 5) for i in range(15)]
    _pol(d, [(20, 40)] + zz + [(20, 110)], preench=OSSO, esp=1.4)
    _pol(d, [(180, 40)] + zz + [(180, 110)], preench=OSSO, esp=1.4)
    # B: sindesmose — dois ossos longos unidos por membrana interóssea
    d._add('<rect x="250" y="40" width="84" height="76" fill="#E8DCC8" stroke="none"/>', [(250, 40), (334, 116)])
    for y in range(44, 112, 8):
        d.linha([(252, y), (334, y + 6)], esp=0.9)
    _bastao(d, (240, 30), (240, 118), 22)
    _bastao(d, (342, 30), (342, 118), 12)
    # C: sincondrose — osso, cartilagem hialina, osso
    _pol(d, [(30, 170), (170, 170), (170, 205), (30, 205)], preench=OSSO, esp=1.4)
    _pol(d, [(30, 205), (170, 205), (170, 220), (30, 220)], preench=CARTILAGEM, esp=1.4)
    _pol(d, [(30, 220), (170, 220), (170, 260), (30, 260)], preench=OSSO, esp=1.4)
    # D: sinovial — extremidades com cartilagem, cavidade com líquido e cápsula
    _caminho(d, "M 222,170 C 208,216 208,232 222,276 L 338,276 C 352,232 352,216 338,170 Z",
             [(208, 170), (352, 276)], preench="#E3F0FA", esp=1.8)
    _caminho(d, "M 232,156 L 328,156 L 328,192 C 328,216 232,216 232,192 Z", [(232, 156), (328, 216)], preench=OSSO)
    _caminho(d, "M 232,296 L 328,296 L 328,256 C 328,234 232,234 232,256 Z", [(232, 234), (328, 296)], preench=OSSO)
    _caminho(d, "M 232,192 C 232,216 328,216 328,192", [(232, 192), (328, 216)], cor="#7FA9CF", esp=5)
    _caminho(d, "M 232,256 C 232,234 328,234 328,256", [(232, 234), (328, 256)], cor="#7FA9CF", esp=5)
    for t, x, y in (("A", 100, 132), ("B", 290, 134), ("C", 100, 284), ("D", 374, 224)):
        _rotulo(d, x, y, t)
    return d


_fig("articulacoes-tipos-abcd", _articulacoes, "Quatro esquemas de união entre ossos. A: duas placas ósseas "
     "lado a lado, encaixadas por uma linha em zigue-zague, sem espaço entre elas. B: dois ossos longos "
     "paralelos, ligados ao longo do comprimento por uma membrana de fibras. C: duas peças ósseas separadas "
     "por uma faixa azul de cartilagem. D: duas extremidades ósseas cobertas por cartilagem azul, separadas "
     "por um espaço com líquido e envolvidas por uma cápsula.")
