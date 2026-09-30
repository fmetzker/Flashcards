# -*- coding: utf-8 -*-
"""Biblioteca de desenho dos diagramas elétricos dos cartões.

Símbolos IEC 60617 (os mesmos da NBR 12523 que a apostila do SENAI usa) e a
identificação de terminais da NBR IEC 60947 (13-14 NA, 11-12 NF, 95-96 e
97-98 do relé térmico, A1-A2 da bobina, 1/2 3/4 5/6 de potência).

Só biblioteca padrão do Python (regra 4 do CLAUDE.md). Esta biblioteca não
grava arquivo: quem grava em banco/img/ é o desenhar-figuras.py.

O modelo é CIRCUITO + VISTA, para que cada circuito seja desenhado uma vez
só e cada figura de cartão custe uma linha:

  - @circuito("pd-comando") desenha o circuito INTEIRO, uma vez. Cada
    símbolo recebe um id ("S1", "K1.13", "K1.A1", "F7.95") e cada fio um
    net ("~N1"). O id é hierárquico: "K1" casa com "K1.13", "K1.A1"... —
    o contator inteiro.
  - vista(materia, nome, "pd-comando", destaque=[...], recorte=[...],
    energizado=[...], pontos=[...], falha=[...]) registra UMA figura:
    destaque  fundo azul atrás dos ids ("o contato destacado");
    acionados contatos desenhados ACIONADOS (NA fechado, NF aberto) — o
              circuito "funcionando", como a apostila mostra passo a passo;
    recorte   corta a figura na região desses ids (explicar um pedaço);
    energizado pinta de vermelho ids/nets (o caminho da corrente);
    pontos    (letra, id, "topo"|"base") — ponto de medição A, B...;
    falha     X vermelho sobre o id (figura de explicação, nunca de
              pergunta de diagnóstico — ali a falha é o que se pergunta).

Convenções de desenho: todo símbolo é VERTICAL e ocupa ALTURA (40)
unidades, do terminal de cima (x, y) ao de baixo (x, y + ALTURA).
"""
import math
from contextlib import contextmanager

ALTURA = 40

TINTA = "#16232E"      # mesmo --tinta do app
DESTAQUE = "#1D5A8C"   # --azul: o elemento de que a pergunta fala
FUNDO_DESTAQUE = "#DCE7F0"
ENERGIA = "#BC3B34"    # --coral: caminho energizado / falha
VERDE = "#0E7C66"      # --verde: terra (PE) e pontos de medição

FONTE = "Arial, Helvetica, sans-serif"
LARGURA_ALVO = 300     # tamanho natural de uma figura na tela do celular

CIRCUITOS = {}         # nome -> função que devolve um Desenho
FIGURAS = {}           # "img/<m>/<nome>.svg" -> função que devolve o SVG
ALTS = {}              # "img/<m>/<nome>.svg" -> alt sugerido


def _n(v):
    """Número curto e determinístico — o SVG gerado precisa ser idêntico a
    cada execução, senão o diff do git vira ruído."""
    v = round(float(v), 1)
    return str(int(v)) if v == int(v) else str(v)


def _esc(t):
    return (str(t).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def _casa(grupo, ids):
    """'K1' casa com 'K1', 'K1.13', 'K1.A1'; '~N1' casa só com o net N1."""
    if not grupo:
        return False
    return any(grupo == i or grupo.startswith(i + ".") for i in ids)


class Desenho:
    def __init__(self, largura, altura, alt=""):
        self.w, self.h = largura, altura
        self.alt = alt
        self.itens = []        # {'g', 'tpl', 'bb', 'est'}; tpl tem {c} onde vai a cor
        self._est = None       # 'rep'/'aci': item só aparece em repouso/acionado
        self.ancoras = {}      # id -> {'topo': (x,y), 'base': (x,y)}
        self.nomes = {}        # id -> descrição curta, para o alt da vista
        self._g = None

    # ---- grupos ----------------------------------------------------------
    @contextmanager
    def grupo(self, nome):
        anterior = self._g
        self._g = nome if nome else anterior
        try:
            yield
        finally:
            self._g = anterior

    def _add(self, tpl, pts):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        self.itens.append({"g": self._g, "tpl": tpl, "est": self._est,
                           "texto": tpl.startswith("<text"),
                           "bb": (min(xs), min(ys), max(xs), max(ys))})

    def caixa(self, ids):
        bbs = [it["bb"] for it in self.itens if _casa(it["g"], ids)]
        if not bbs:
            raise KeyError(f"nenhum elemento com id {ids}")
        return (min(b[0] for b in bbs), min(b[1] for b in bbs),
                max(b[2] for b in bbs), max(b[3] for b in bbs))

    # ---- primitivas (cor=None: segue destaque/energizado da vista) --------
    def linha(self, pontos, cor=None, esp=2, tracejado=None):
        d = " ".join(f"{_n(x)},{_n(y)}" for x, y in pontos)
        extra = f' stroke-dasharray="{tracejado}"' if tracejado else ""
        self._add(f'<polyline points="{d}" fill="none" stroke="{cor or "{c}"}" '
                  f'stroke-width="{_n(esp)}" stroke-linecap="round" '
                  f'stroke-linejoin="round"{extra}/>', pontos)

    def fio(self, *pontos, net=None):
        with self.grupo("~" + net if net else None):
            self.linha(pontos)

    def no(self, x, y, net=None):
        """Ponto de junção: três ou mais fios no mesmo lugar."""
        with self.grupo("~" + net if net else None):
            self._add(f'<circle cx="{_n(x)}" cy="{_n(y)}" r="3" fill="{{c}}"/>',
                      [(x - 3, y - 3), (x + 3, y + 3)])

    def texto(self, x, y, t, tam=12, cor=None, ancora="start", negrito=False,
              italico=False):
        estilo = (' font-weight="bold"' if negrito else "") + \
                 (' font-style="italic"' if italico else "")
        larg = len(str(t)) * tam * 0.6
        x0 = x - larg if ancora == "end" else x - larg / 2 if ancora == "middle" else x
        self._add(f'<text x="{_n(x)}" y="{_n(y)}" font-size="{_n(tam)}" fill="{cor or "{c}"}" '
                  f'text-anchor="{ancora}"{estilo}>{_esc(t)}</text>',
                  [(x0, y - tam * 0.8), (x0 + larg, y + tam * 0.2)])

    def retangulo(self, x, y, w, h, cor=None, esp=2, preench="none"):
        self._add(f'<rect x="{_n(x)}" y="{_n(y)}" width="{_n(w)}" height="{_n(h)}" '
                  f'fill="{preench}" stroke="{cor or "{c}"}" stroke-width="{_n(esp)}"/>',
                  [(x, y), (x + w, y + h)])

    def circulo(self, x, y, r, cor=None, esp=2, preench="none"):
        self._add(f'<circle cx="{_n(x)}" cy="{_n(y)}" r="{_n(r)}" fill="{preench}" '
                  f'stroke="{cor or "{c}"}" stroke-width="{_n(esp)}"/>',
                  [(x - r, y - r), (x + r, y + r)])

    def _registra(self, id, x, y, nome):
        if id:
            self.ancoras[id] = {"topo": (x, y), "base": (x, y + ALTURA)}
            if nome:
                self.nomes[id] = nome

    # ---- símbolos de comando (verticais, altura ALTURA) -------------------
    def contato(self, x, y, tipo="na", id=None, tag=None, bornes=None,
                atuador=None, nome=None):
        """Contato NA (fechador) ou NF (abridor), desenhado em REPOUSO.
        tipo: 'na' | 'nf' | 'comutador' (comum em cima; embaixo NF à direita
        e NA à esquerda — bornes = (comum, NF, NA), ex. ('15', '16', '18')).
        atuador: None | 'botao' | 'termico' | 'fimdecurso' | 'disjuntor' |
        'temp_on' (retardo na energização) | 'temp_off' (na desenergização)
        — os dois temporizados como no Quadro 10 da apostila SENAI: arco "("
        para energização, ")" para desenergização."""
        if tipo == "comutador":
            return self._comutador(x, y, id, tag, bornes, nome)
        with self.grupo(id):
            self.linha([(x, y), (x, y + 13)])
            self.linha([(x, y + ALTURA), (x, y + 27)])
            if tipo == "na":
                lamina, meio = (x - 10, y + 11), (x - 5, y + 19)
                lamina_aci = (x - 3, y + 12)          # fechado: encosta no fixo
            else:
                self.linha([(x, y + 13), (x + 8, y + 13)])
                lamina, meio = (x + 10, y + 10), (x + 5, y + 18.5)
                lamina_aci = (x + 13, y + 20)         # aberto: afasta do fixo
            # a lâmina é o único traço que muda com o estado: a vista escolhe
            # qual desenhar (acionados=[...]); o resto do símbolo é comum
            self._est = "rep"
            self.linha([(x, y + 27), lamina])
            self._est = "aci"
            self.linha([(x, y + 27), lamina_aci])
            self._est = None
            esq = x - 12
            if atuador == "disjuntor":
                self.linha([(x - 3, y + 10), (x + 3, y + 16)])
                self.linha([(x - 3, y + 16), (x + 3, y + 10)])
            elif atuador:
                ponta, ym = x - 22, meio[1]
                if atuador not in ("temp_on", "temp_off"):
                    self.linha([meio, (ponta, ym)], esp=1.5, tracejado="3,3")
                if atuador == "botao":
                    self.linha([(ponta + 4, ym - 6), (ponta, ym - 6), (ponta, ym + 6),
                                (ponta + 4, ym + 6)])
                    esq = ponta - 5
                elif atuador == "termico":
                    self.linha([(ponta, ym), (ponta, ym - 5), (ponta - 6, ym - 5),
                                (ponta - 6, ym + 5), (ponta - 12, ym + 5), (ponta - 12, ym)])
                    esq = ponta - 16
                elif atuador == "fimdecurso":
                    # cunha acionada pelo came da máquina (Quadro 7 da apostila)
                    self.linha([(ponta, ym), (ponta - 9, ym - 6), (ponta - 9, ym + 6), (ponta, ym)])
                    esq = ponta - 13
                elif atuador in ("temp_on", "temp_off"):
                    # duas linhas paralelas até o arco; o lado para onde o arco
                    # abre é o que distingue energização de desenergização
                    self.linha([meio, (ponta, ym)], esp=1.5)
                    self.linha([(meio[0], ym + 4), (ponta, ym + 4)], esp=1.5)
                    cx = ponta + (0 if atuador == "temp_on" else -6)
                    if atuador == "temp_on":      # "(" : abre para o contato
                        d_arco = f"M {_n(cx + 6)},{_n(ym - 5)} A 7 7 0 0 0 {_n(cx + 6)},{_n(ym + 9)}"
                    else:                         # ")" : abre para fora
                        d_arco = f"M {_n(cx)},{_n(ym - 5)} A 7 7 0 0 1 {_n(cx)},{_n(ym + 9)}"
                    self._add(f'<path d="{d_arco}" fill="none" stroke="{{c}}" stroke-width="2"/>',
                              [(cx - 2, ym - 5), (cx + 8, ym + 9)])
                    esq = ponta - 6
            if bornes:
                bx = x + (14 if tipo == "nf" else 6)
                self.texto(bx, y + 9, bornes[0], tam=10)
                self.texto(bx, y + 38, bornes[1], tam=10)
            if tag:
                self.texto(esq, y + 24, tag, ancora="end", negrito=True)
        self._registra(id, x, y, nome)

    def _comutador(self, x, y, id, tag, bornes, nome):
        """Contato comutador (reversível), comum EM CIMA — o diagrama desce de
        L1, então a alimentação chega pelo comum. Embaixo, NF à direita e NA à
        esquerda. Em repouso a lâmina encosta no NF; acionado, no NA.
        bornes = (comum, NF, NA), ex. ('15', '16', '18')."""
        with self.grupo(id):
            xa, xf = x - 11, x + 11
            self.linha([(x, y), (x, y + 13)])
            self.linha([(xf - 7, y + 27), (xf, y + 27), (xf, y + ALTURA)])
            self.linha([(xa, y + 28), (xa, y + ALTURA)])
            self._est = "rep"
            self.linha([(x, y + 13), (xf + 2, y + 30)])
            self._est = "aci"
            self.linha([(x, y + 13), (xa, y + 28)])
            self._est = None
            if bornes:
                self.texto(x + 5, y + 9, bornes[0], tam=10)
                self.texto(xf + 4, y + 39, bornes[1], tam=10)
                self.texto(xa - 4, y + 39, bornes[2], tam=10, ancora="end")
            if tag:
                self.texto(x - 8, y + 12, tag, ancora="end", negrito=True)
        self.ancoras[id] = {"topo": (x, y), "base": (x, y + ALTURA),
                            "nf": (xf, y + ALTURA), "na": (xa, y + ALTURA)}
        if nome:
            self.nomes[id] = nome

    def bobina(self, x, y, id=None, tag=None, nome=None, tempo=None):
        """tempo: None | 'on' (retardo na energização: quadrado com X) |
        'off' (na desenergização: quadrado preto) — Quadro 10 da apostila."""
        with self.grupo(id):
            self.linha([(x, y), (x, y + 12)])
            self.retangulo(x - 13, y + 12, 26, 16)
            if tempo:
                self.retangulo(x - 25, y + 12, 12, 16,
                               preench="{c}" if tempo == "off" else "none")
                if tempo == "on":
                    self.linha([(x - 25, y + 12), (x - 13, y + 28)])
                    self.linha([(x - 25, y + 28), (x - 13, y + 12)])
            self.linha([(x, y + 28), (x, y + ALTURA)])
            self.texto(x + 6, y + 9, "A1", tam=10)
            self.texto(x + 6, y + 39, "A2", tam=10)
            if tag:
                self.texto(x - (29 if tempo else 17), y + 24, tag, ancora="end", negrito=True)
        self._registra(id, x, y, nome)

    def lampada(self, x, y, id=None, tag=None, nome=None):
        with self.grupo(id):
            self.linha([(x, y), (x, y + 10)])
            self.circulo(x, y + 20, 10)
            d = 7.1
            self.linha([(x - d, y + 20 - d), (x + d, y + 20 + d)])
            self.linha([(x - d, y + 20 + d), (x + d, y + 20 - d)])
            self.linha([(x, y + 30), (x, y + ALTURA)])
            if tag:
                self.texto(x - 15, y + 24, tag, ancora="end", negrito=True)
        self._registra(id, x, y, nome)

    def fusivel(self, x, y, id=None, tag=None, nome=None):
        with self.grupo(id):
            self.linha([(x, y), (x, y + ALTURA)])
            self.retangulo(x - 5, y + 9, 10, 22, preench="#fff")
            self.linha([(x, y + 9), (x, y + 31)])
            if tag:
                self.texto(x - 10, y + 24, tag, ancora="end", negrito=True)
        self._registra(id, x, y, nome)

    def resistor(self, x, y, id=None, tag=None, nome=None):
        """Resistor (IEC 60617): retângulo SEM a linha atravessando — é essa
        linha que distingue o fusível."""
        with self.grupo(id):
            self.linha([(x, y), (x, y + 9)])
            self.retangulo(x - 5, y + 9, 10, 22, preench="#fff")
            self.linha([(x, y + 31), (x, y + ALTURA)])
            if tag:
                self.texto(x - 10, y + 24, tag, ancora="end", negrito=True)
        self._registra(id, x, y, nome)

    def bloco(self, x, y, w, h, linhas, id=None, nome=None):
        """Bloco funcional (diagrama de blocos): retângulo com texto centrado."""
        with self.grupo(id):
            self.retangulo(x, y, w, h, preench="#fff")
            y0 = y + h / 2 - (len(linhas) - 1) * 7 + 4
            for i, t in enumerate(linhas):
                self.texto(x + w / 2, y0 + i * 14, t, tam=11, ancora="middle")
        if id:
            self.ancoras[id] = {"topo": (x + w / 2, y), "base": (x + w / 2, y + h)}
            if nome:
                self.nomes[id] = nome

    def elemento_termico(self, x, y, id=None, bornes=None, nome=None):
        """Elemento bimetálico do relé térmico, em série com a fase."""
        with self.grupo(id):
            self.linha([(x, y), (x, y + 10)])
            self.retangulo(x - 8, y + 10, 16, 20)
            self.linha([(x, y + 10), (x, y + 14), (x - 4, y + 14), (x - 4, y + 26),
                        (x, y + 26), (x, y + 30)])
            self.linha([(x, y + 30), (x, y + ALTURA)])
            if bornes:
                self.texto(x + 11, y + 9, bornes[0], tam=10)
                self.texto(x + 11, y + 38, bornes[1], tam=10)
        self._registra(id, x, y, nome)

    # ---- grupos de potência ------------------------------------------------
    def tripolar(self, xs, y, simbolo, dispositivo, tag=None, bornes=("1", "2", "3", "4", "5", "6"),
                 fases=("L1", "L2", "L3"), nome=None, atuador=None):
        """O mesmo símbolo nas três fases. Ids: '<dispositivo>.<fase>' —
        'K1.L2' é o polo de K1 na fase L2; 'K1' é o contator inteiro."""
        for i, (x, fase) in enumerate(zip(xs, fases)):
            b = (bornes[2 * i], bornes[2 * i + 1]) if bornes else None
            pid = f"{dispositivo}.{fase}"
            pn = f"{nome}, fase {fase}" if nome else None
            if simbolo == "contato":
                self.contato(x, y, id=pid, bornes=b, nome=pn, atuador=atuador)
            elif simbolo == "termico":
                self.elemento_termico(x, y, id=pid, bornes=b, nome=pn)
            elif simbolo == "fusivel":
                self.fusivel(x, y, id=pid, nome=pn)
        with self.grupo(dispositivo + ".tag"):
            if simbolo == "contato":
                self.linha([(xs[0] - 5, y + 19), (xs[-1] - 5, y + 19)], esp=1.5, tracejado="3,3")
            if tag:
                self.texto(xs[0] - 16, y + 24, tag, ancora="end", negrito=True)

    def motor3(self, xs, y, id="M1", tag="M1", nome="motor trifásico"):
        """As três fases descem e convergem para a borda do círculo, a ±40°
        do topo — fases mais afastadas que o raio nunca o tocariam retas."""
        xc, r = xs[1], 26
        yc = y + 30 + r
        with self.grupo(id):
            for x, rotulo, ang in zip(xs, ("U1", "V1", "W1"), (-40, 0, 40)):
                a = math.radians(ang)
                self.linha([(x, y), (x, y + 14), (xc + r * math.sin(a), yc - r * math.cos(a))])
                self.texto(x + 4, y + 11, rotulo, tam=10)
            self.circulo(xc, yc, r)
            self.texto(xc, yc - 2, "M", tam=15, ancora="middle", negrito=True)
            self.texto(xc, yc + 14, "3~", ancora="middle")
            if tag:
                self.texto(xs[0] - 16, yc + 4, tag, ancora="end", negrito=True)
        self._registra(id, xc, y, nome)
        return yc, r

    def barramento(self, y, x0, x1, net, rotulo=None, cor=None, tracejado=None):
        with self.grupo("~" + net):
            self.linha([(x0, y), (x1, y)], cor=cor, tracejado=tracejado)
            self.texto(x0 - 5, y + 4, rotulo or net, ancora="end", negrito=True, cor=cor)

    def borne(self, x, y, rotulo, net=None):
        """Terminal de alimentação do comando (L1, L2, N...)."""
        with self.grupo("~" + net if net else None):
            self.circulo(x, y, 3.5, preench="#fff")
            self.texto(x - 10, y + 4, rotulo, ancora="end", negrito=True)

    # ---- vista: o que vira SVG ----------------------------------------------
    def svg(self, destaque=(), recorte=None, energizado=(), pontos=(), falha=(),
            acionados=(), margem=16, origem=""):
        pretos, extras, fundos = [], [], []
        # caixa de corte
        if recorte == "tudo":      # ajusta ao próprio desenho (símbolo avulso)
            bbs = [it["bb"] for it in self.itens]
            x0, y0 = min(b[0] for b in bbs), min(b[1] for b in bbs)
            x1, y1 = max(b[2] for b in bbs), max(b[3] for b in bbs)
            vb = (x0 - margem, y0 - margem, x1 + margem, y1 + margem)
        elif recorte:
            x0, y0, x1, y1 = self.caixa(recorte)
            vb = (max(0, x0 - margem), max(0, y0 - margem),
                  min(self.w, x1 + margem), min(self.h, y1 + margem))
        else:
            vb = (0, 0, self.w, self.h)
        dentro = lambda bb: not (bb[2] < vb[0] or bb[0] > vb[2] or bb[3] < vb[1] or bb[1] > vb[3])

        for i in destaque:
            bx0, by0, bx1, by1 = self.caixa([i])
            fundos.append(f'<rect x="{_n(bx0 - 6)}" y="{_n(by0 - 4)}" width="{_n(bx1 - bx0 + 12)}" '
                          f'height="{_n(by1 - by0 + 8)}" rx="6" fill="{FUNDO_DESTAQUE}"/>')
        inteiro = lambda bb: bb[0] >= vb[0] and bb[2] <= vb[2] and bb[1] >= vb[1] and bb[3] <= vb[3]
        for it in self.itens:
            if not dentro(it["bb"]) or (recorte and it["texto"] and not inteiro(it["bb"])):
                continue   # texto cortado pela borda do recorte some inteiro
            if it["est"]:
                aci = _casa(it["g"], acionados)
                if (it["est"] == "aci") != aci:
                    continue
            cor = ENERGIA if _casa(it["g"], energizado) else \
                DESTAQUE if _casa(it["g"], destaque) else TINTA
            pretos.append(it["tpl"].replace("{c}", cor))
        for i in falha:
            bx0, by0, bx1, by1 = self.caixa([i])
            cx, cy, d = (bx0 + bx1) / 2, (by0 + by1) / 2, 9
            extras.append(f'<polyline points="{_n(cx - d)},{_n(cy - d)} {_n(cx + d)},{_n(cy + d)}" '
                          f'stroke="{ENERGIA}" stroke-width="3" stroke-linecap="round"/>')
            extras.append(f'<polyline points="{_n(cx - d)},{_n(cy + d)} {_n(cx + d)},{_n(cy - d)}" '
                          f'stroke="{ENERGIA}" stroke-width="3" stroke-linecap="round"/>')
        for p in pontos:
            letra, i, onde = p[:3]
            lado = p[3] if len(p) > 3 else "dir"
            x, y = self.ancoras[i][onde]
            y += -5 if onde == "topo" else 5
            dx = 17 if lado == "dir" else -17
            extras.append(f'<circle cx="{_n(x)}" cy="{_n(y)}" r="3.5" fill="{VERDE}"/>')
            extras.append(f'<polyline points="{_n(x)},{_n(y)} {_n(x + dx * 0.55)},{_n(y)}" '
                          f'stroke="{VERDE}" stroke-width="1.5"/>')
            extras.append(f'<circle cx="{_n(x + dx)}" cy="{_n(y)}" r="8" fill="#fff" '
                          f'stroke="{VERDE}" stroke-width="1.5"/>')
            extras.append(f'<text x="{_n(x + dx)}" y="{_n(y + 4)}" font-size="11" fill="{VERDE}" '
                          f'text-anchor="middle" font-weight="bold">{_esc(letra)}</text>')

        w, h = vb[2] - vb[0], vb[3] - vb[1]
        escala = min(2.0, LARGURA_ALVO / w) if w < LARGURA_ALVO else 1.0
        cab = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{_n(vb[0])} {_n(vb[1])} {_n(w)} {_n(h)}" '
               f'width="{_n(w * escala)}" height="{_n(h * escala)}" font-family="{FONTE}">\n')
        marca = f"<!-- gerado por desenhar-figuras.py a partir de {origem}; não editar à mão -->\n" if origem else ""
        fundo = f'<rect x="{_n(vb[0])}" y="{_n(vb[1])}" width="{_n(w)}" height="{_n(h)}" fill="#fff"/>'
        return marca + cab + "\n".join([fundo] + fundos + pretos + extras) + "\n</svg>\n"


# ---- registro ---------------------------------------------------------------

def circuito(nome):
    """Registra a função que desenha o circuito inteiro (chamada uma vez)."""
    def registra(fn):
        if nome in CIRCUITOS:
            raise ValueError(f"circuito registrado duas vezes: {nome}")
        cache = {}

        def construir():
            if "d" not in cache:
                cache["d"] = fn()
            return cache["d"]
        construir.__name__ = fn.__name__
        CIRCUITOS[nome] = construir
        return fn
    return registra


def vista(materia, nome, circ, **opcoes):
    """UMA figura de cartão: um circuito já registrado + opções de vista."""
    chave = f"img/{materia}/{nome}.svg"
    if chave in FIGURAS:
        raise ValueError(f"figura registrada duas vezes: {chave}")

    def gerar():
        return CIRCUITOS[circ]().svg(origem=f"circuito '{circ}'", **opcoes)
    FIGURAS[chave] = gerar

    def alt():
        d = CIRCUITOS[circ]()
        nomeia = lambda i: d.nomes.get(i, i.lstrip("~"))
        partes = [d.alt]
        if opcoes.get("recorte") and opcoes["recorte"] != "tudo":
            partes.append("Recorte mostrando só: " + ", ".join(map(nomeia, opcoes["recorte"])) + ".")
        if opcoes.get("destaque"):
            partes.append("Destacado: " + ", ".join(map(nomeia, opcoes["destaque"])) + ".")
        if opcoes.get("acionados"):
            partes.append("Acionados: " + ", ".join(map(nomeia, opcoes["acionados"])) + ".")
        if opcoes.get("energizado"):
            partes.append("Em vermelho, o caminho energizado.")
        for p in opcoes.get("pontos", ()):
            partes.append(f"Ponto {p[0]}: {'antes' if p[2] == 'topo' else 'depois'} de {nomeia(p[1])}.")
        if opcoes.get("falha"):
            partes.append("Marcado com X: " + ", ".join(map(nomeia, opcoes["falha"])) + ".")
        return " ".join(partes)
    ALTS[chave] = alt


def simbolo(materia, nome, desenhar, largura=140, altura=80, **opcoes):
    """Figura de símbolo avulso: 'desenhar' recebe um Desenho vazio."""
    circ = f"simbolo:{materia}/{nome}"
    alt = opcoes.pop("alt", "")

    def fn():
        d = Desenho(largura, altura, alt=alt)
        desenhar(d)
        return d
    circuito(circ)(fn)
    opcoes.setdefault("recorte", "tudo")
    vista(materia, nome, circ, **opcoes)
