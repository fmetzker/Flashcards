# -*- coding: utf-8 -*-
"""Figuras da matéria Manutenção Mecânica.

Instrumentos são PARAMÉTRICOS: _paquimetro(leitura, resolução) e
_micrometro(leitura) desenham qualquer leitura com escalas coerentes — o
traço do nônio que coincide com a escala fixa é calculado, não posicionado à
mão, e vem marcado (no papel ou na tela, uma diferença de 0,05 mm entre dois
traços não se enxerga; a habilidade cobrada é somar as duas escalas).

Os demais desenhos são esquemas da técnica, redesenhados: símbolos de
válvula e atuador da ISO 1219-1, disposição de vistas e símbolo do diedro da
NBR 10067, linhas da NBR 8403, quadro de tolerância geométrica da NBR 6409,
campos de tolerância da NBR 6158 e diagramas σ-ε e S-N do Hibbeler.
"""
import math
from desenho import Desenho, simbolo, _n, DESTAQUE, FUNDO_DESTAQUE, TINTA

M = "manutencao-mecanica"
CINZA = "#C9D3DC"


def _poligono(d, pts, preench=None, esp=2):
    caminho = " ".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    d._add(f'<polygon points="{caminho}" fill="{preench or "{c}"}" stroke="{{c}}" '
           f'stroke-width="{_n(esp)}" stroke-linejoin="round"/>', pts)


def _seta(d, x1, y1, x2, y2, esp=1.8, ponta=7):
    """Linha de (x1,y1) a (x2,y2) com ponta cheia na chegada."""
    a = math.atan2(y2 - y1, x2 - x1)
    bx, by = x2 - ponta * math.cos(a), y2 - ponta * math.sin(a)
    d.linha([(x1, y1), (bx, by)], esp=esp)
    p = [(x2, y2), (bx + ponta * 0.45 * math.sin(a), by - ponta * 0.45 * math.cos(a)),
         (bx - ponta * 0.45 * math.sin(a), by + ponta * 0.45 * math.cos(a))]
    _poligono(d, p, esp=1)


def _caminho(d, dd, pts, esp=2, preench="none", tracejado=None):
    extra = f' stroke-dasharray="{tracejado}"' if tracejado else ""
    d._add(f'<path d="{dd}" fill="{preench}" stroke="{{c}}" stroke-width="{_n(esp)}" '
           f'stroke-linecap="round" stroke-linejoin="round"{extra}/>', pts)


# ---- paquímetro --------------------------------------------------------------

def _paquimetro(leitura, resolucao):
    """Escala fixa em mm e nônio de n divisões. Nônio "ampliado" de 39 mm para
    0,05 mm (traço a cada 1,95 mm), de 49 mm para 0,02 mm e de 9 mm para 0,1 mm
    — o traço j do nônio cai em I + j·passo + leitura, e coincide com a escala
    fixa exatamente quando j = (fração da leitura)/resolução."""
    n = round(1 / resolucao)
    k = 2 if resolucao == 0.05 else 1
    passo = k - resolucao
    inteiro = math.floor(leitura + 1e-9)
    j0 = round((leitura - inteiro) / resolucao)
    s = 7.0                                          # px por mm
    ini = inteiro - 5
    fim = leitura + n * passo + 5
    x = lambda mm: 20 + (mm - ini) * s
    w = x(fim) + 20
    y0 = 62                                          # face de contato das escalas
    d = Desenho(w, 130, alt=(
        f"Escalas de um paquímetro de resolução {str(resolucao).replace('.', ',')} mm: escala fixa "
        f"em milímetros, numerada de 10 em 10, e nônio de {n} divisões abaixo dela. O zero do nônio "
        f"está entre os traços de {inteiro} e {inteiro + 1} mm da escala fixa; o traço do nônio que "
        f"coincide com um traço da escala fixa está marcado com um triângulo azul."))
    with d.grupo("corpo"):
        d.retangulo(x(ini) - 8, 18, x(fim) - x(ini) + 16, y0 - 18, cor=TINTA, preench="#F4F7FA")
    for mm in range(math.ceil(ini), math.floor(fim) + 1):
        alto = 14 if mm % 10 == 0 else 10 if mm % 5 == 0 else 6
        d.linha([(x(mm), y0), (x(mm), y0 - alto)], esp=1.2)
        if mm % 10 == 0:
            d.texto(x(mm), y0 - 18, str(mm), tam=11, ancora="middle")
    x_nonio = x(leitura)
    with d.grupo("nonio"):
        d.retangulo(x_nonio - 10, y0, n * passo * s + 20, 42, cor=TINTA, preench="#fff")
    rotulo_cada = {10: 5, 20: 2, 50: 5}[n]
    for j in range(n + 1):
        xj = x_nonio + j * passo * s
        rot = j % rotulo_cada == 0
        d.linha([(xj, y0), (xj, y0 + (11 if rot else 6))], esp=1.2,
                cor=DESTAQUE if j == j0 else None)
        if rot:
            d.texto(xj, y0 + 24, str(j // rotulo_cada if n != 10 else j), tam=10, ancora="middle")
    xc = x_nonio + j0 * passo * s
    _poligono(d, [(xc, y0 + 30), (xc - 5, y0 + 39), (xc + 5, y0 + 39)], preench=DESTAQUE, esp=1)
    return d


def paquimetro(nome, leitura, resolucao):
    simbolo(M, nome, lambda dd: _copia(dd, _paquimetro(leitura, resolucao)),
            alt=_paquimetro(leitura, resolucao).alt)


def _copia(dd, origem):
    """simbolo() entrega um Desenho vazio; copia para ele o desenho pronto."""
    dd.w, dd.h, dd.itens = origem.w, origem.h, origem.itens


# ---- micrômetro --------------------------------------------------------------

def _micrometro(leitura):
    """Bainha com traços de milímetro acima da linha de referência e de meio
    milímetro abaixo; tambor de 50 divisões (0,01 mm) com a borda no último
    traço exposto. A divisão do tambor alinhada com a linha de referência é a
    centésima da leitura."""
    meio = math.floor(leitura * 2 + 1e-9) / 2        # parte lida na bainha
    cent = round((leitura - meio) * 100)
    s = 12.0
    x = lambda mm: 30 + mm * s
    yr = 70                                           # linha de referência
    borda = x(meio)
    d = Desenho(borda + 120, 140, alt=(
        f"Bainha e tambor de um micrômetro de resolução 0,01 mm. Na bainha, traços de milímetro "
        f"acima da linha de referência, numerados de 5 em 5, e traços de meio milímetro abaixo "
        f"dela. A borda do tambor deixa expostos os traços da bainha até {str(meio).replace('.', ',')} mm. "
        f"No tambor, graduado de 0 a 49, aparecem as divisões de {(cent - 4) % 50} a {(cent + 4) % 50}, "
        f"e uma delas está alinhada com a linha de referência."))
    with d.grupo("bainha"):
        d.retangulo(x(0) - 14, yr - 24, borda - x(0) + 20, 48, cor=TINTA, preench="#F4F7FA")
    d.linha([(x(0) - 14, yr), (borda, yr)], esp=1.4)
    for mm in range(0, int(meio) + 1):
        d.linha([(x(mm), yr), (x(mm), yr - (11 if mm % 5 == 0 else 7))], esp=1.2)
        if mm % 5 == 0:
            d.texto(x(mm), yr - 14, str(mm), tam=11, ancora="middle")
    h = 0.5
    while h <= meio + 1e-9:
        d.linha([(x(h), yr), (x(h), yr + 7)], esp=1.2)
        h += 1
    # tambor: chanfro + corpo; divisões crescem para cima, 9 px cada
    with d.grupo("tambor"):
        _poligono(d, [(borda, yr - 52), (borda + 18, yr - 60), (borda + 100, yr - 60),
                      (borda + 100, yr + 60), (borda + 18, yr + 60), (borda, yr + 52)],
                  preench="#fff", esp=2)
        d.linha([(borda + 18, yr - 60), (borda + 18, yr + 60)], esp=1)
    for k in range(-5, 6):
        div = (cent + k) % 50
        y = yr - k * 9
        rot = div % 5 == 0
        d.linha([(borda, y), (borda + (14 if rot else 8), y)], esp=1.2)
        if rot:
            d.texto(borda + 22, y + 4, str(div), tam=10)
    return d


def micrometro(nome, leitura):
    simbolo(M, nome, lambda dd: _copia(dd, _micrometro(leitura)), alt=_micrometro(leitura).alt)


paquimetro("paquimetro-005-eixo", 23.45, 0.05)
paquimetro("paquimetro-005-chapa", 8.85, 0.05)
paquimetro("paquimetro-002-pino", 31.36, 0.02)
micrometro("micrometro-sem-meio", 12.36)
micrometro("micrometro-com-meio", 17.78)
micrometro("micrometro-fim-tambor", 6.97)


# ---- válvulas e atuadores (ISO 1219-1) -----------------------------------------

Q = 40   # lado do quadrado de cada posição


def _mola(d, x, y, para_direita=True):
    sx = 1 if para_direita else -1
    pts = [(x, y)] + [(x + sx * (4 + 4 * i), y + (-7 if i % 2 == 0 else 7)) for i in range(5)] + \
          [(x + sx * 26, y)]
    d.linha(pts, esp=1.6)


def _solenoide(d, x, y, para_esquerda=True):
    sx = -1 if para_esquerda else 1
    x0 = x if para_esquerda else x
    xa, xb = (x - 16, x) if para_esquerda else (x, x + 16)
    d.retangulo(xa, y - 9, 16, 18, esp=1.6)
    d.linha([(xa, y + 9), (xb, y - 9)], esp=1.4)
    return xa if para_esquerda else xb


def _botao(d, x, y):
    """Acionamento por botão: haste até um semicírculo (ISO 1219)."""
    d.linha([(x, y), (x - 12, y)], esp=1.6)
    d._add(f'<path d="M {_n(x - 12)},{_n(y - 8)} A 8 8 0 0 0 {_n(x - 12)},{_n(y + 8)}" '
           f'fill="none" stroke="{{c}}" stroke-width="1.6"/>', [(x - 20, y - 8), (x - 12, y + 8)])


def _bloqueio(d, x, y, para_baixo):
    """Via bloqueada dentro da posição: haste curta + barra (o "T")."""
    s = 1 if para_baixo else -1
    d.linha([(x, y), (x, y + s * 8)], esp=1.6)
    d.linha([(x - 5, y + s * 8), (x + 5, y + s * 8)], esp=1.6)


def _escape(d, x, y):
    """Escape para a atmosfera (pneumática): triângulo vazio na ponta da via."""
    _poligono(d, [(x, y), (x - 6, y + 9), (x + 6, y + 9)], preench="#fff", esp=1.4)


def _valvula(posicoes, vias_cima, vias_baixo, rotulos, esquerda, direita, alt,
             escapes=()):
    """posicoes: lista (da esquerda para a direita) de listas de ligações; cada
    ligação é ('seta', via_origem, via_destino) ou ('t', via). As vias são
    nomes em vias_cima/vias_baixo: {nome: deslocamento x dentro do quadrado}.
    As vias externas saem da posição que fica junto da mola (a da direita),
    que é a de repouso."""
    n = len(posicoes)
    x0, yt = 60, 30
    d = Desenho(x0 * 2 + n * Q + 40, 120, alt=alt)
    rep = n - 1 if n < 3 else 1
    for i, lig in enumerate(posicoes):
        xq = x0 + i * Q
        d.retangulo(xq, yt, Q, Q, esp=2)
        pos = lambda via: (xq + vias_cima[via], yt) if via in vias_cima else (xq + vias_baixo[via], yt + Q)
        for l in lig:
            if l[0] == "seta":
                (xa, ya), (xb, yb) = pos(l[1]), pos(l[2])
                _seta(d, xa, ya + (3 if ya == yt else -3), xb, yb + (3 if yb == yt else -3), ponta=6)
            else:
                xa, ya = pos(l[1])
                _bloqueio(d, xa, ya, para_baixo=(ya == yt))
    xr = x0 + rep * Q
    for via, dx in vias_cima.items():
        d.linha([(xr + dx, yt), (xr + dx, yt - 12)], esp=1.6)
        d.texto(xr + dx, yt - 15, rotulos.get(via, via), tam=11, ancora="middle", negrito=True)
    for via, dx in vias_baixo.items():
        d.linha([(xr + dx, yt + Q), (xr + dx, yt + Q + 12)], esp=1.6)
        if via in escapes:
            _escape(d, xr + dx, yt + Q + 12)
        d.texto(xr + dx, yt + Q + (36 if via in escapes else 26), rotulos.get(via, via), tam=11,
                ancora="middle", negrito=True)
    ym = yt + Q / 2
    if esquerda == "botao":
        _botao(d, x0, ym)
    elif esquerda == "solenoide":
        _solenoide(d, x0, ym)
    elif esquerda == "solenoide+mola":
        xa = _solenoide(d, x0, ym)
        _mola(d, xa, ym + 0, para_direita=False)
    xd = x0 + n * Q
    if direita == "mola":
        _mola(d, xd, ym)
    elif direita == "solenoide+mola":
        xb = _solenoide(d, xd, ym, para_esquerda=False)
        _mola(d, xb, ym)
    return d


def _fig(nome, fn, alt):
    simbolo(M, nome, lambda dd: _copia(dd, fn()), alt=alt)


ALT_32 = ("Símbolo de válvula direcional pneumática com dois quadrados lado a lado. Vias "
          "numeradas: 2 em cima; 1 e 3 embaixo, com triângulo de escape na 3. Acionamento por "
          "botão à esquerda e mola à direita. No quadrado da direita, seta de 2 para 3 e via 1 "
          "bloqueada; no da esquerda, seta de 1 para 2 e via 3 bloqueada.")
_fig("valvula-3-2-botao-mola", lambda: _valvula(
    [[("seta", "1", "2"), ("t", "3")], [("seta", "2", "3"), ("t", "1")]],
    {"2": 12}, {"1": 12, "3": 28}, {}, "botao", "mola", ALT_32, escapes=("3",)), ALT_32)

ALT_52 = ("Símbolo de válvula direcional com dois quadrados lado a lado. Vias numeradas: "
          "4 e 2 em cima; 5, 1 e 3 embaixo, com triângulos de escape na 5 e na 3. Solenoide à "
          "esquerda e mola à direita. No quadrado da direita, setas de 1 para 2 e de 4 para 5; "
          "no da esquerda, setas de 1 para 4 e de 2 para 3.")
_fig("valvula-5-2-solenoide-mola", lambda: _valvula(
    [[("seta", "1", "4"), ("seta", "2", "3")], [("seta", "1", "2"), ("seta", "4", "5")]],
    {"4": 11, "2": 29}, {"5": 6, "1": 20, "3": 34}, {}, "solenoide", "mola", ALT_52,
    escapes=("5", "3")), ALT_52)

ALT_43 = ("Símbolo de válvula direcional hidráulica com três quadrados lado a lado, "
          "solenoide e mola de centragem em cada extremidade. Vias A e B em cima, P e T embaixo, "
          "saindo do quadrado central. Quadrado da esquerda: setas de P para A e de B para T. "
          "Quadrado da direita: setas de P para B e de A para T, cruzadas. Quadrado central: as "
          "quatro vias terminam num traço transversal (T).")
_fig("valvula-4-3-centro-fechado", lambda: _valvula(
    [[("seta", "P", "A"), ("seta", "B", "T")],
     [("t", "A"), ("t", "B"), ("t", "P"), ("t", "T")],
     [("seta", "P", "B"), ("seta", "A", "T")]],
    {"A": 12, "B": 28}, {"P": 12, "T": 28}, {}, "solenoide+mola", "solenoide+mola", ALT_43), ALT_43)


def _retencao():
    d = Desenho(200, 80, alt="")
    d.linha([(20, 40), (80, 40)])
    d.linha([(110, 40), (180, 40)])
    d.linha([(98, 26), (112, 40), (98, 54)])        # sede em V
    d.circulo(90, 40, 9)                            # esfera
    d.texto(24, 30, "A", tam=12, negrito=True)
    d.texto(176, 30, "B", tam=12, negrito=True, ancora="end")
    return d


ALT_RET = ("Símbolo hidráulico numa linha entre duas vias, A à esquerda e B à direita: um "
           "pequeno círculo encostado num assento em forma de V, aberto para a esquerda.")
_fig("simbolo-retencao", _retencao, ALT_RET)


def _alivio():
    d = Desenho(180, 130, alt="")
    xq, yq = 60, 35
    d.retangulo(xq, yq, 40, 40)
    d.linha([(80, yq + 40), (80, yq + 62)])          # entrada (P), embaixo
    d.linha([(80, yq), (80, yq - 16)])               # saída (T), em cima
    _seta(d, 90, yq + 34, 90, yq + 6, ponta=6)       # seta deslocada: fechada em repouso
    d.linha([(80, yq + 52), (48, yq + 52), (48, yq + 20), (xq, yq + 20)], esp=1.4, tracejado="4,3")
    _mola(d, xq + 40, yq + 20)
    d.linha([(104, yq + 32), (124, yq + 8)], esp=1.4)   # mola regulável
    d.texto(88, yq + 70, "P", tam=11, negrito=True)
    d.texto(88, yq - 6, "T", tam=11, negrito=True)
    return d


ALT_ALIV = ("Símbolo hidráulico: um quadrado com uma seta deslocada para o lado, fora do "
            "alinhamento entre a via P (embaixo) e a via T (em cima). Uma linha tracejada sai da "
            "via P e chega à lateral esquerda do quadrado; na lateral direita há uma mola com uma "
            "seta inclinada sobre ela.")
_fig("simbolo-alivio", _alivio, ALT_ALIV)


def _cilindro_simples():
    d = Desenho(220, 100, alt="")
    d.retangulo(30, 30, 120, 36)
    d.linha([(70, 30), (70, 66)], esp=3)              # êmbolo
    d.linha([(70, 48), (190, 48)], esp=3)             # haste
    _mola(d, 74, 48)
    d.linha([(42, 66), (42, 84)])                     # única via, do lado do êmbolo
    return d


ALT_CIL = ("Símbolo pneumático: retângulo alongado com um êmbolo, a haste saindo pela direita "
           "e uma mola na câmara do lado da haste. Há uma única via de alimentação, na câmara "
           "do lado esquerdo.")
_fig("simbolo-cilindro-simples-acao", _cilindro_simples, ALT_CIL)


# ---- desenho técnico -----------------------------------------------------------

def _disposicao():
    d = Desenho(300, 250, alt="")
    cx, cy, w, h = 120, 90, 70, 46
    d.retangulo(cx, cy, w, h, esp=2.5)
    d.texto(cx + w / 2, cy + h / 2 + 4, "frontal", tam=11, ancora="middle")
    for rot, (x, y) in {"X": (cx, cy + h + 22), "W": (cx, cy - h - 22),
                        "Y": (cx + w + 22, cy), "Z": (cx - w - 22, cy)}.items():
        d._add(f'<rect x="{_n(x)}" y="{_n(y)}" width="{w}" height="{h}" fill="none" '
               f'stroke="{{c}}" stroke-width="1.5" stroke-dasharray="5,4"/>', [(x, y), (x + w, y + h)])
        d.texto(x + w / 2, y + h / 2 + 5, rot, tam=15, ancora="middle", negrito=True)
    d.texto(155, 244, "1º diedro", tam=11, ancora="middle", italico=True)
    return d


ALT_DISP = ("Disposição de vistas no 1º diedro: um retângulo central com a vista frontal e "
            "quatro retângulos tracejados em volta, marcados X (abaixo da frontal), W (acima), "
            "Y (à direita) e Z (à esquerda).")
_fig("vistas-disposicao-1-diedro", _disposicao, ALT_DISP)


def _diedro(primeiro):
    """Tronco de cone visto de frente (trapézio, ponta estreita à esquerda) e
    visto pela esquerda (dois círculos). No 1º diedro, a vista lateral
    esquerda vai à DIREITA da frontal; no 3º, à esquerda."""
    d = Desenho(220, 100, alt="")
    xt = 30 if primeiro else 120
    xc = 175 if primeiro else 55
    d.linha([(xt, 38), (xt + 70, 22), (xt + 70, 78), (xt, 62), (xt, 38)])
    d.linha([(xt - 8, 50), (xt + 78, 50)], esp=1, tracejado="10,3,2,3")
    d.circulo(xc, 50, 28)
    d.circulo(xc, 50, 12)
    d.linha([(xc - 34, 50), (xc + 34, 50)], esp=1, tracejado="10,3,2,3")
    d.linha([(xc, 16), (xc, 84)], esp=1, tracejado="10,3,2,3")
    return d


ALT_D1 = ("Símbolo de projeção: à esquerda, um trapézio (tronco de cone visto de frente) com o "
          "lado estreito voltado para a esquerda; à direita dele, dois círculos concêntricos.")
ALT_D3 = ("Símbolo de projeção: à esquerda, dois círculos concêntricos; à direita deles, um "
          "trapézio (tronco de cone visto de frente) com o lado estreito voltado para os círculos.")
_fig("simbolo-1-diedro", lambda: _diedro(True), ALT_D1)
_fig("simbolo-3-diedro", lambda: _diedro(False), ALT_D3)


def _alavanca():
    """Suporte com alavanca articulada: contorno visível (contínua grossa),
    furo oculto (tracejada), eixo (traço-ponto) e a posição extrema da
    alavanca (traço-dois-pontos)."""
    d = Desenho(300, 200, alt="")
    d.linha([(30, 170), (200, 170), (200, 140), (130, 140), (130, 60), (90, 60), (90, 140),
             (30, 140), (30, 170)], esp=2.5)
    d.linha([(103, 140), (103, 170)], esp=1.4, tracejado="6,4")     # furo oculto
    d.linha([(117, 140), (117, 170)], esp=1.4, tracejado="6,4")
    d.linha([(110, 130), (110, 180)], esp=1, tracejado="12,3,2,3")   # linha de centro
    d.circulo(110, 75, 6, esp=2)
    d.linha([(110, 75), (230, 30)], esp=3)                            # alavanca
    d.linha([(110, 75), (250, 95)], esp=1.4, tracejado="14,3,2,3,2,3")  # posição extrema
    d.texto(236, 28, "A", tam=13, negrito=True)
    d.texto(256, 100, "D", tam=13, negrito=True)
    d.texto(122, 190, "C", tam=13, negrito=True)
    d.texto(84, 160, "B", tam=13, negrito=True)
    return d


ALT_ALAV = ("Vista de um suporte com uma alavanca articulada no alto. A: a alavanca, em linha "
            "contínua grossa. B: duas linhas tracejadas verticais na base do suporte. C: linha "
            "fina de traço longo e ponto, vertical, entre as tracejadas. D: uma segunda alavanca, "
            "inclinada para baixo, desenhada em linha fina de traço longo e dois pontos.")
_fig("linhas-suporte-alavanca", _alavanca, ALT_ALAV)


def _corte():
    d = Desenho(300, 150, alt="")
    d.retangulo(60, 40, 180, 70, esp=2.5)
    d.circulo(150, 75, 18, esp=2.5)
    d.linha([(150, 18), (150, 132)], esp=1, tracejado="12,3,2,3")
    d.linha([(150, 22), (150, 36)], esp=3.5)
    d.linha([(150, 114), (150, 128)], esp=3.5)
    _seta(d, 150, 26, 128, 26, esp=2, ponta=8)
    _seta(d, 150, 124, 128, 124, esp=2, ponta=8)
    d.texto(118, 31, "A", tam=13, negrito=True)
    d.texto(118, 129, "A", tam=13, negrito=True)
    return d


ALT_CORTE = ("Vista de uma placa retangular com um furo central. Uma linha de traço e ponto "
             "atravessa a placa verticalmente pelo centro do furo, com trechos grossos nas "
             "pontas; em cada ponta, uma seta horizontal apontando para a esquerda e a letra A.")
_fig("plano-de-corte-aa", _corte, ALT_CORTE)


def _quadro_tolerancia(simb):
    d = Desenho(260, 110, alt="")
    d.retangulo(20, 30, 180 if simb == "perp" else 130, 32, esp=1.6)
    d.linha([(56, 30), (56, 62)], esp=1.6)
    if simb == "perp":
        d.linha([(150, 30), (150, 62)], esp=1.6)
        d.linha([(28, 54), (48, 54)], esp=2)
        d.linha([(38, 54), (38, 36)], esp=2)
        d.texto(103, 51, "0,02", tam=14, ancora="middle")
        d.texto(175, 51, "A", tam=14, ancora="middle")
    else:
        d.linha([(28, 54), (34, 38), (50, 38), (44, 54), (28, 54)], esp=2)
        d.texto(103, 51, "0,05", tam=14, ancora="middle")
    d.linha([(20, 46), (6, 46), (6, 92)], esp=1.4)
    _seta(d, 6, 80, 6, 96, ponta=7)
    return d


ALT_PERP = ("Quadro de tolerância geométrica com três casas: na primeira, um símbolo formado "
            "por um traço vertical que se apoia no meio de um traço horizontal; na segunda, "
            "0,02; na terceira, a letra A. Uma linha de chamada sai do quadro com uma seta.")
ALT_PLAN = ("Quadro de tolerância geométrica com duas casas: na primeira, um símbolo em forma "
            "de paralelogramo inclinado; na segunda, 0,05. Uma linha de chamada sai do quadro "
            "com uma seta.")
_fig("tolerancia-perpendicularidade", lambda: _quadro_tolerancia("perp"), ALT_PERP)
_fig("tolerancia-planeza", lambda: _quadro_tolerancia("plan"), ALT_PLAN)


# ---- ajustes: campos de tolerância ----------------------------------------------

def _campos(eixo):
    """Furo H (afastamento inferior zero) e eixo acima, abaixo ou cruzando."""
    d = Desenho(280, 170, alt="")
    y0 = 95
    d.linha([(20, y0), (260, y0)], esp=1.4)
    d.texto(22, y0 - 6, "linha zero", tam=10, italico=True)
    d.retangulo(80, y0 - 34, 50, 34, preench=CINZA, esp=1.6)
    d.texto(105, y0 - 13, "furo", tam=11, ancora="middle")
    ys = {"folga": (y0 + 14, 30), "interferencia": (y0 - 74, 30), "incerto": (y0 - 50, 40)}[eixo]
    d.retangulo(160, ys[0], 50, ys[1], preench="#fff", esp=1.6)
    for k in range(6):
        x = 160 + k * 10
        d.linha([(x, ys[0] + ys[1]), (min(x + 10, 210), ys[0] + ys[1] - min(10, 210 - x))], esp=0.8)
    d.texto(185, ys[0] + ys[1] / 2 + 4, "eixo", tam=11, ancora="middle")
    return d


_ALT_CAMPOS = ("Diagrama de campos de tolerância: uma linha horizontal (linha zero); à "
               "esquerda, o campo do furo, retângulo cinza apoiado sobre a linha zero; à direita, "
               "o campo do eixo, retângulo hachurado")
_fig("ajuste-campos-folga", lambda: _campos("folga"),
     _ALT_CAMPOS + ", inteiramente abaixo da linha zero.")
_fig("ajuste-campos-interferencia", lambda: _campos("interferencia"),
     _ALT_CAMPOS + ", inteiramente acima do topo do campo do furo.")
_fig("ajuste-campos-incerto", lambda: _campos("incerto"),
     _ALT_CAMPOS + ", com a base abaixo do topo do campo do furo e o topo acima dele.")


# ---- resistência dos materiais ----------------------------------------------------

def _eixos(d, x0, y0, x1, y1, rx, ry):
    _seta(d, x0, y0, x1, y0, esp=1.6)
    _seta(d, x0, y0, x0, y1, esp=1.6)
    d.texto(x1 - 2, y0 + 16, rx, tam=13, ancora="end", italico=True)
    d.texto(x0 - 8, y1 + 10, ry, tam=13, ancora="end", italico=True)


def _tensao_deformacao():
    d = Desenho(300, 210, alt="")
    x0, y0 = 40, 180
    _eixos(d, x0, y0, 285, 15, "ε", "σ")
    pts = [(x0, y0), (64, 94), (70, 82), (76, 90), (86, 86), (96, 90), (106, 86), (118, 88)]
    for i in range(1, 21):            # encruamento até o máximo
        t = i / 20
        pts.append((118 + 82 * t, 88 - 58 * math.sin(t * math.pi / 2)))
    for i in range(1, 11):            # estricção até a ruptura
        t = i / 10
        pts.append((200 + 50 * t, 30 + 40 * t * t))
    d.linha(pts, esp=2.4)
    for rot, (x, y), dx, dy in (("A", (64, 94), -16, 4), ("B", (70, 82), -4, -9),
                                ("C", (200, 30), -4, -8), ("D", (250, 70), 8, 4)):
        d._add(f'<circle cx="{_n(x)}" cy="{_n(y)}" r="3.5" fill="{{c}}"/>', [(x - 4, y - 4), (x + 4, y + 4)])
        d.texto(x + dx, y + dy, rot, tam=13, negrito=True)
    d.texto(x0 - 6, y0 + 14, "O", tam=12, ancora="end", negrito=True)
    return d


ALT_SE = ("Diagrama tensão (σ, vertical) por deformação (ε, horizontal) de um aço dúctil. A "
          "curva sobe em linha reta desde a origem O até o ponto A, tem logo depois um pequeno "
          "patamar irregular que começa no ponto B, volta a subir em curva até o ponto mais alto, "
          "C, e então desce até terminar no ponto D.")
_fig("diagrama-tensao-deformacao", _tensao_deformacao, ALT_SE)


def _sn():
    d = Desenho(300, 200, alt="")
    x0, y0 = 46, 170
    _eixos(d, x0, y0, 285, 15, "N (ciclos)", "S")
    pts = [(x0 + 10 + i * 10, 60 + 70 * (1 - math.exp(-i / 6))) for i in range(22)]
    pts += [(x0 + 230, pts[-1][1])]
    d.linha(pts, esp=2.4)
    ya = pts[-1][1]
    d.linha([(x0, ya), (x0 + 236, ya)], esp=1.2, tracejado="6,4")
    d.texto(x0 - 6, ya + 4, "?", tam=14, ancora="end", negrito=True)
    return d


ALT_SN = ("Gráfico S-N de um aço: tensão alternada (S) na vertical e número de ciclos até a "
          "falha (N) na horizontal. A curva desce à medida que N aumenta e, a partir de certo "
          "número de ciclos, fica horizontal. Uma linha tracejada horizontal marca o nível desse "
          "trecho horizontal, indicado por um ponto de interrogação no eixo S.")
_fig("curva-sn-aco", _sn, ALT_SN)


# ---- engrenagens e manômetro -------------------------------------------------------

def _engrenagem(d, cx, cy, r, dentes, fase=0.0):
    pts = []
    for i in range(dentes * 4):
        a = fase + 2 * math.pi * i / (dentes * 4)
        rr = r + 5 if i % 4 in (1, 2) else r - 3
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    _poligono(d, pts, preench="#F4F7FA", esp=1.6)
    d.circulo(cx, cy, 5, esp=1.6)


def _trem():
    d = Desenho(320, 150, alt="")
    _engrenagem(d, 60, 75, 36, 14)
    _engrenagem(d, 140, 75, 36, 14, fase=math.pi / 14)
    _engrenagem(d, 236, 75, 52, 20)
    for rot, x in (("A", 60), ("B", 140), ("C", 236)):
        d.texto(x, 140 if rot != "C" else 146, rot, tam=13, ancora="middle", negrito=True)
    # seta curva sobre A: sentido horário
    d._add(f'<path d="M 34,30 A 34 34 0 0 1 86,30" fill="none" stroke="{DESTAQUE}" stroke-width="2.4"/>',
           [(34, 20), (86, 30)])
    _poligono(d, [(90, 36), (80, 31), (88, 24)], preench=DESTAQUE, esp=1)
    return d


ALT_TREM = ("Três engrenagens em linha, cada uma engrenada na vizinha: A à esquerda, B no meio "
            "e C, maior, à direita. Sobre A, uma seta curva indica rotação no sentido horário.")
_fig("trem-tres-engrenagens", _trem, ALT_TREM)


def _manometro_u():
    d = Desenho(260, 210, alt="")
    d.retangulo(10, 30, 60, 70, preench="#F4F7FA")
    d.texto(40, 70, "tanque", tam=11, ancora="middle")
    d.linha([(70, 60), (110, 60), (110, 180)], esp=2)
    d.linha([(126, 60), (126, 180)], esp=2)
    d._add('<path d="M 110,180 A 25 25 0 0 0 160,180" fill="none" stroke="{c}" stroke-width="2"/>',
           [(110, 180), (160, 205)])
    d._add('<path d="M 126,180 A 9 9 0 0 0 144,180" fill="none" stroke="{c}" stroke-width="2"/>',
           [(126, 180), (144, 189)])
    d.linha([(144, 180), (144, 20)], esp=2)
    d.linha([(160, 180), (160, 20)], esp=2)
    d.texto(152, 14, "aberto", tam=10, ancora="middle", italico=True)
    # líquido manométrico: mais baixo no ramo do tanque
    nivel_t, nivel_a = 140, 80
    d._add(f'<rect x="111" y="{nivel_t}" width="14" height="{180 - nivel_t}" fill="{CINZA}"/>',
           [(111, nivel_t), (125, 180)])
    d._add(f'<rect x="145" y="{nivel_a}" width="14" height="{180 - nivel_a}" fill="{CINZA}"/>',
           [(145, nivel_a), (159, 180)])
    d._add(f'<path d="M 110,180 A 25 25 0 0 0 160,180 L 144,180 A 9 9 0 0 1 126,180 Z" fill="{CINZA}"/>',
           [(110, 180), (160, 205)])
    d.linha([(170, nivel_a), (200, nivel_a)], esp=1, tracejado="4,3")
    d.linha([(170, nivel_t), (200, nivel_t)], esp=1, tracejado="4,3")
    _seta(d, 192, nivel_t, 192, nivel_a + 2, esp=1.2, ponta=6)
    _seta(d, 192, nivel_a, 192, nivel_t - 2, esp=1.2, ponta=6)
    d.texto(200, (nivel_a + nivel_t) / 2 + 5, "h", tam=13, italico=True)
    return d


ALT_MAN = ("Manômetro de tubo em U: o ramo esquerdo está ligado a um tanque fechado e o ramo "
           "direito é aberto para a atmosfera. O líquido manométrico está mais baixo no ramo "
           "ligado ao tanque e mais alto no ramo aberto; a diferença de altura entre os dois "
           "níveis está indicada por h.")
_fig("manometro-u-tanque", _manometro_u, ALT_MAN)
