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


# ---- músculo ---------------------------------------------------------------------

def _estrias(d, x0, x1, y0, y1, passo=5):
    for x in range(int(x0) + 3, int(x1) - 2, passo):
        d.linha([(x, y0 + 2), (x, y1 - 2)], cor="#B5615A", esp=0.9)


def _tecidos_musculares():
    d = Desenho(420, 300)
    # A: estriado esquelético — fibras longas, estriadas, muitos núcleos na periferia
    for y in (18, 50):
        d._add(f'<rect x="50" y="{y}" width="350" height="26" rx="10" fill="{MUSCULO_CLARO}" stroke="{{c}}" '
               f'stroke-width="1.3"/>', [(50, y), (400, y + 26)])
        _estrias(d, 52, 398, y, y + 26)
        for k, x in enumerate(range(80, 390, 46)):
            _elipse(d, x, y + (4 if k % 2 else 22), 8, 2.6, preench=NUCLEO, esp=0)
    # B: liso — células fusiformes, um núcleo central, sem estrias
    for linha, y in enumerate((112, 132, 152)):
        for x in range(60 + (linha % 2) * 34, 400, 68):
            fus = f"M {x - 34},{y} Q {x},{y - 11} {x + 34},{y} Q {x},{y + 11} {x - 34},{y} Z"
            _caminho(d, fus, [(x - 34, y - 11), (x + 34, y + 11)], preench=MUSCULO_CLARO, esp=1.1)
            _elipse(d, x, y, 7, 2.4, preench=NUCLEO, esp=0)
    # C: estriado cardíaco — fibras ramificadas, estriadas, núcleo central, discos intercalares
    fibra = ("M 50,206 L 190,206 L 236,186 L 400,186 L 400,208 L 250,208 L 214,226 L 400,226 L 400,248 "
             "L 210,248 L 190,236 L 50,236 Z")
    _caminho(d, fibra, [(50, 186), (400, 248)], preench=MUSCULO_CLARO, esp=1.3)
    _estrias(d, 52, 188, 206, 236)
    _estrias(d, 238, 398, 186, 208)
    _estrias(d, 216, 398, 226, 248)
    for x, y in ((100, 221), (300, 197), (320, 237)):
        _elipse(d, x, y, 7, 3.2, preench=NUCLEO, esp=0)
    for x, ya, yb in ((150, 206, 236), (350, 186, 208), (260, 226, 248)):
        d.linha([(x, ya), (x + 3, (ya + yb) / 2), (x, yb)], esp=3.2)
    for t, y in (("A", 46), ("B", 132), ("C", 217)):
        _rotulo(d, 24, y, t)
    return d


_fig("musculos-tres-tecidos-abc", _tecidos_musculares, "Três tecidos musculares vistos ao microscópio, em "
     "faixas. A: fibras longas e cilíndricas, com listras transversais e vários núcleos achatados encostados na "
     "borda. B: células em forma de fuso, sem listras, cada uma com um único núcleo no meio. C: fibras com "
     "listras transversais que se ramificam e se unem, com um núcleo no centro de cada célula e traços escuros "
     "atravessando a fibra onde uma célula encosta na outra.")


def _envoltorios():
    d = Desenho(360, 300)
    cx, cy = 160, 150
    d.circulo(cx, cy, 118, preench="#F6E3D6", esp=4.5)
    fasc = [(cx, cy - 58), (cx + 56, cy - 14), (cx + 34, cy + 56), (cx - 36, cy + 56), (cx - 56, cy - 14), (cx, cy + 4)]
    for fx, fy in fasc:
        d.circulo(fx, fy, 34, preench="#EFC9BE", esp=2.4)
        for j in range(-3, 4):
            for i in range(-3, 4):
                x, y = fx + i * 9.5 + (4.7 if j % 2 else 0), fy + j * 8.4
                if (x - fx) ** 2 + (y - fy) ** 2 < 28 ** 2:
                    d.circulo(x, y, 4.2, preench=MUSCULO_CLARO, esp=0.7)
    _chamada(d, (cx + 84, cy - 84), (300, 40), "A")
    _chamada(d, (cx + 56 + 34, cy - 14), (316, 150), "B")
    _chamada(d, (cx + 34 + 9.5, cy + 56 + 8.4), (300, 262), "C")
    return d


_fig("musculo-envoltorios-abc", _envoltorios, "Corte transversal de um músculo esquelético: um grande "
     "círculo envolvido por uma camada externa grossa (marcada A). Dentro dele, vários feixes redondos, cada "
     "um contornado por uma camada própria (o contorno de um feixe está marcado B). Dentro de cada feixe, "
     "muitos círculos pequenos, cada um envolvido por uma camada finíssima (a de um deles está marcada C).")


def _sarcomero(d, y, z0, z1, rotulos=False):
    meio = (z0 + z1) / 2
    for z in (z0, z1):
        d.linha([(z, y - 34), (z, y + 34)], esp=3)
    for k in range(-2, 3):                                  # filamentos finos, presos às linhas Z
        yy = y + k * 14
        d.linha([(z0, yy), (z0 + 120, yy)], cor="#4F6FA8", esp=1.6)
        d.linha([(z1, yy), (z1 - 120, yy)], cor="#4F6FA8", esp=1.6)
    for k in (-1.5, -0.5, 0.5, 1.5):                        # filamentos grossos, no centro
        yy = y + k * 14
        d.linha([(meio - 80, yy), (meio + 80, yy)], cor="#B5524A", esp=4)
        for x in range(int(meio - 74), int(meio + 75), 12):
            if abs(x - meio) > 8:
                s = 1 if x > meio else -1
                d.linha([(x, yy), (x + s * 4, yy - 4)], cor="#B5524A", esp=1.2)
                d.linha([(x, yy), (x + s * 4, yy + 4)], cor="#B5524A", esp=1.2)
    if rotulos:
        _chamada(d, (z0 + 30, y - 28), (z0 + 30, y - 58), "X")
        _chamada(d, (meio + 50, y + 7), (meio + 96, y + 58), "Y")


def _sarcomeros():
    d = Desenho(420, 300)
    _sarcomero(d, 90, 40, 380, rotulos=True)
    _sarcomero(d, 230, 90, 330)
    d.texto(210, 150, "relaxado", tam=12, ancora="middle", italico=True)
    d.texto(210, 290, "contraído", tam=12, ancora="middle", italico=True)
    return d


_fig("sarcomero-relaxado-contraido", _sarcomeros, "Dois esquemas do mesmo sarcômero, um embaixo do outro, "
     "delimitados por duas linhas verticais grossas. Presos a cada linha vertical, filamentos finos azuis "
     "apontam para o centro (um marcado X); no centro, filamentos grossos vermelhos com pequenas cabeças "
     "(um marcado Y). Em cima, legenda 'relaxado'; embaixo, legenda 'contraído', com as linhas verticais mais "
     "próximas e os filamentos finos avançando mais sobre os grossos.")


def _formas_musculo():
    d = Desenho(440, 200)
    # A: circular — anel de fibras em volta de uma abertura
    for r in (16, 22, 28, 34):
        _elipse(d, 60, 80, r + 10, r, esp=1.4, cor="#B5524A")
    _elipse(d, 60, 80, 20, 10, preench="#fff", esp=1.6)
    # B: triangular (convergente) — fibras em leque convergindo para um tendão
    for k in range(9):
        d.linha([(150 + k * 9, 30 + abs(k - 4) * 3), (186, 132)], cor="#B5524A", esp=1.6)
    d.linha([(186, 132), (186, 152)], esp=3)
    # C: fusiforme — fusiforme com fibras paralelas e tendões nas pontas
    _caminho(d, "M 280,30 Q 312,82 280,134 Q 248,82 280,30 Z", [(248, 30), (312, 134)], preench=MUSCULO_CLARO, esp=1.6)
    for dx in (-12, -6, 0, 6, 12):
        d._add(f'<path d="M 280,36 Q {280 + dx * 2.2},82 280,128" fill="none" stroke="#B5524A" stroke-width="1.2"/>',
               [(280 + dx * 2.2, 36), (280, 128)])
    d.linha([(280, 12), (280, 30)], esp=3)
    d.linha([(280, 134), (280, 152)], esp=3)
    # D: peniforme — tendão central com fibras oblíquas dos dois lados
    d.linha([(380, 14), (380, 152)], esp=3)
    for y in range(34, 132, 10):
        d.linha([(380, y), (356, y - 16)], cor="#B5524A", esp=1.6)
        d.linha([(380, y), (404, y - 16)], cor="#B5524A", esp=1.6)
    for t, x in (("A", 60), ("B", 186), ("C", 280), ("D", 380)):
        _rotulo(d, x, 180, t)
    return d


_fig("musculos-formas-abcd", _formas_musculo, "Quatro esquemas da disposição das fibras de um músculo. A: "
     "fibras em anéis concêntricos ao redor de uma abertura. B: fibras em leque, largas de um lado e "
     "convergindo para um único tendão do outro. C: músculo alongado, mais grosso no meio e afinando nas duas "
     "pontas, com fibras paralelas e um tendão em cada ponta. D: um tendão central percorrendo todo o "
     "comprimento, com fibras curtas e oblíquas saindo dos dois lados, como uma pena.")


# ---- sistema reprodutor ------------------------------------------------------------

ROSA = "#F4C7C3"
ROSA_ESC = "#E39A94"
OVARIO = "#F6DCB4"
GLANDULA = "#E8D3A4"


def _feminino():
    d = Desenho(400, 300)
    utero = ("M 140,92 C 140,58 260,58 260,92 C 260,140 226,170 216,196 L 216,206 L 184,206 L 184,196 "
             "C 174,170 140,140 140,92 Z")
    _caminho(d, utero, [(140, 58), (260, 206)], preench=ROSA_ESC, esp=1.8)
    _caminho(d, "M 160,90 C 176,86 224,86 240,90 L 204,160 L 196,160 Z", [(160, 86), (240, 160)],
             preench=ROSA, esp=1)                                   # cavidade com endométrio
    _caminho(d, "M 186,206 L 182,286 L 218,286 L 214,206 Z", [(182, 206), (218, 286)], preench=ROSA, esp=1.6)
    for s in (-1, 1):                                               # tubas, ovários e fímbrias
        x0 = 200 + s * 60
        tuba = (f"M {x0},86 C {200 + s * 110},62 {200 + s * 150},54 {200 + s * 160},88 "
                f"C {200 + s * 166},108 {200 + s * 158},124 {200 + s * 146},132")
        xs = sorted((x0, 200 + s * 166))
        _caminho(d, tuba, [(xs[0], 54), (xs[1], 132)], cor="{c}", esp=10)
        _caminho(d, tuba, [(xs[0], 54), (xs[1], 132)], cor=ROSA, esp=7)
        for a in (-40, -15, 10, 35, 60):
            ang = math.radians(a + (90 if s > 0 else 90))
            fx, fy = 200 + s * 146, 132
            d.linha([(fx, fy), (fx + s * 14 * math.cos(math.radians(a)), fy + 14 * math.sin(math.radians(a)) + 6)],
                    esp=2.2)
        _elipse(d, 200 + s * 112, 150, 24, 14, preench=OVARIO, esp=1.6)
        d.linha([(200 + s * 88, 150), (200 + s * 62, 118)], esp=1.4, tracejado="3 3")
    _chamada(d, (88, 150), (30, 196), "A")
    _chamada(d, (100, 64), (64, 22), "B")
    _chamada(d, (46, 146), (22, 112), "C")
    _chamada(d, (240, 120), (330, 210), "D")
    _chamada(d, (200, 250), (270, 262), "E")
    return d


_fig("reprodutor-feminino-abcde", _feminino, "Esquema frontal dos órgãos internos femininos. No centro, um "
     "órgão oco em forma de pera invertida, com a cavidade interna triangular (marcado D), que se estreita "
     "embaixo e continua num canal até a abertura externa (marcado E). Do alto do órgão central sai, para "
     "cada lado, um tubo fino e curvo (marcado B do lado esquerdo) que termina em franjas abertas (marcadas "
     "C). Logo abaixo de cada franja, um órgão oval preso ao órgão central por um cordão (o da esquerda "
     "marcado A).")


def _masculino():
    d = Desenho(380, 330)
    d.circulo(170, 80, 42, preench="#FBF1C8", esp=1.8)              # bexiga
    d.texto(170, 84, "bexiga", tam=11, ancora="middle", italico=True)
    _elipse(d, 232, 104, 11, 30, preench=GLANDULA, esp=1.5, rot=18)  # vesícula seminal
    _elipse(d, 170, 142, 26, 19, preench=GLANDULA, esp=1.6)         # próstata
    d.circulo(186, 178, 6, preench=GLANDULA, esp=1.3)               # bulbouretral
    uretra = "M 170,122 L 170,184 C 170,206 150,214 128,222 L 62,252"
    _caminho(d, uretra, [(62, 122), (170, 252)], cor="#B5524A", esp=2.2)
    _caminho(d, "M 166,192 C 150,204 120,212 92,226 L 56,244 L 66,264 L 104,248 C 132,236 160,228 176,210 Z",
             [(56, 192), (176, 264)], preench=ROSA, esp=1.6)        # pênis
    _caminho(d, uretra, [(62, 122), (170, 252)], cor="#B5524A", esp=2.2)
    d.circulo(52, 256, 13, preench=ROSA_ESC, esp=1.4)               # glande
    _caminho(d, "M 126,250 C 112,286 136,322 168,318 C 200,314 206,276 186,250 Z", [(112, 250), (206, 322)],
             preench="#F7E3DA", esp=1.2)                            # escroto
    _elipse(d, 156, 286, 20, 26, preench=OVARIO, esp=1.6)           # testículo
    _caminho(d, "M 172,262 C 186,270 188,296 172,310", [(172, 262), (188, 310)], cor="#9C6B3E", esp=7)
    deferente = "M 172,310 C 196,300 202,262 214,220 C 226,180 252,140 256,100 C 260,52 214,40 204,60 C 196,76 200,110 186,130"
    _caminho(d, deferente, [(172, 40), (260, 310)], cor="#4F6FA8", esp=2.4)
    _chamada(d, (150, 290), (88, 300), "A")
    _chamada(d, (184, 286), (240, 300), "B")
    _chamada(d, (226, 196), (296, 214), "C")
    _chamada(d, (236, 92), (300, 70), "D")
    _chamada(d, (188, 146), (300, 150), "E")
    _chamada(d, (190, 180), (260, 250), "F")
    return d


_fig("reprodutor-masculino-abcdef", _masculino, "Esquema lateral dos órgãos masculinos. No alto, a bexiga. "
     "Logo abaixo dela, envolvendo o início do canal que sai da bexiga, uma glândula arredondada (marcada E); "
     "atrás da bexiga, uma glândula alongada (marcada D); abaixo da glândula E, uma glândula pequena e redonda "
     "(marcada F). O canal segue pelo pênis até a ponta. Embaixo, dentro do escroto, um órgão oval (marcado A), "
     "com uma estrutura em forma de vírgula encostada atrás dele (marcada B). Dessa estrutura sai um tubo "
     "azul (marcado C) que sobe, contorna a bexiga por cima e desce por trás dela até a glândula E.")


def _ciclo():
    d = Desenho(440, 290)
    x0, x1, base, alto = 60, 400, 240, 50
    X = lambda dia: x0 + (dia - 1) * (x1 - x0) / 27
    d._add(f'<rect x="{_n(X(1))}" y="{alto}" width="{_n(X(5) - X(1))}" height="{base - alto}" fill="#F8DCDC"/>',
           [(X(1), alto), (X(5), base)])
    d.texto(X(1), alto - 8, "menstruação", tam=10, italico=True)
    d.linha([(x0, alto - 6), (x0, base), (x1 + 6, base)], esp=1.6)
    for dia in (1, 7, 14, 21, 28):
        d.linha([(X(dia), base), (X(dia), base + 5)], esp=1.2)
        d.texto(X(dia), base + 18, str(dia), tam=11, ancora="middle")
    d.texto((x0 + x1) / 2, base + 36, "dia do ciclo", tam=11, ancora="middle", italico=True)
    d.linha([(X(14), alto - 4), (X(14), base)], esp=1, tracejado="4 3")
    d.texto(X(14), alto - 8, "ovulação", tam=10, ancora="middle", italico=True)
    g = lambda t, c, w: math.exp(-((t - c) / w) ** 2)
    curvas = [  # (rótulo, cor, função do dia -> 0..1, dia do rótulo)
        ("1", "#2E7D4F", lambda t: 0.22 + 0.1 * g(t, 4, 3) + 0.25 * g(t, 14, 0.9), 4),
        ("2", "#B5524A", lambda t: 0.08 + 0.85 * g(t, 14, 0.9), 14),
        ("3", "#4F6FA8", lambda t: 0.1 + 0.62 * g(t, 12.8, 2.2) + 0.3 * g(t, 21, 3), 11),
        ("4", "#9C6B3E", lambda t: 0.04 + 0.62 * g(t, 21.5, 3.2), 22),
    ]
    for rot, cor, f, dia_r in curvas:
        pts = [(X(t / 4), base - f(t / 4) * (base - alto - 20)) for t in range(4, 113)]
        d.linha(pts, cor=cor, esp=2.4)
        xr, yr = X(dia_r), base - f(dia_r) * (base - alto - 20) - 16
        _rotulo(d, xr + (14 if rot == "1" else 0), yr, rot, tam=12)
    return d


_fig("ciclo-hormonios-1234", _ciclo, "Gráfico dos níveis de quatro hormônios ao longo de um ciclo de 28 dias, "
     "com a menstruação marcada nos dias 1 a 5 e a ovulação no dia 14. Curva 1: baixa, com uma elevação leve no "
     "início do ciclo e um pico pequeno no dia 14. Curva 2: baixa o ciclo todo, com um pico alto e estreito no "
     "dia 14. Curva 3: sobe na primeira metade até um pico pouco antes do dia 14, cai e tem uma segunda "
     "elevação menor por volta do dia 21. Curva 4: baixa até a ovulação e alta na segunda metade, com pico por "
     "volta do dia 21.")
