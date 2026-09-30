# -*- coding: utf-8 -*-
"""Figuras da matéria Comandos Elétricos.

Nomenclatura da apostila do curso (SENAI-DN, Comandos Elétricos, 2013):
Q11/Q12 disjuntores do comando, F10 fusíveis de força, F7 relé térmico,
K1 contator, S0 desliga, S1 liga, E1 sinalizador, M1 motor. Os circuitos
são os circuitos-padrão da técnica, redesenhados: nenhuma figura dos livros
é copiada.

Cada circuito é desenhado UMA vez (@circuito); cada figura de cartão é UMA
linha de vista() no fim do arquivo. Figura nova = linha nova lá embaixo.

Ids deste arquivo:
  pd-comando  Q11 F7.95 S0 S1 K1.13 K1.23 K1.A1 E1 Q12; nets ~L1 ~a ~b ~N1
              ~N2 ~c ~d ~col ~L2 (a: Q11→F7; b: F7→S0; c: K1 23-24→E1;
              d: S1/selo → bobina; col: coletor → Q12)
  pd-forca    F10.L1..L3  K1.L1..L3  F7.L1..L3  M1; nets ~L1 ~L2 ~L3 ~PE
"""
from desenho import Desenho, circuito, vista, simbolo, ALTURA, VERDE

M = "comandos-eletricos"


# ---- circuitos -----------------------------------------------------------

@circuito("pd-comando")
def pd_comando():
    """Comando da partida direta, escada vertical, em repouso. Coluna
    principal x=110; selo em paralelo com S1 em x=170; sinalização em x=230."""
    d = Desenho(290, 372, alt="Diagrama de comando da partida direta entre L1 e L2: "
                "Q11, contato 95-96 de F7, S0, depois S1 com o contato K1 13-14 em paralelo, "
                "a bobina de K1 e Q12. À direita, K1 23-24 em série com a lâmpada E1.")
    x, xs, xl = 110, 170, 230
    d.borne(x, 28, "L1", net="L1")
    d.texto(x + 12, 32, "220 V / 60 Hz", tam=11)
    d.fio((x, 31.5), (x, 34), net="L1")
    d.contato(x, 34, id="Q11", tag="Q11", atuador="disjuntor", nome="disjuntor Q11")
    d.fio((x, 74), (x, 82), net="a")
    d.contato(x, 82, "nf", id="F7.95", tag="F7", bornes=("95", "96"), atuador="termico",
              nome="contato 95-96 do relé térmico F7")
    d.fio((x, 122), (x, 130), net="b")
    d.contato(x, 130, "nf", id="S0", tag="S0", bornes=("11", "12"), atuador="botao",
              nome="botão desliga S0")
    n1, n2, col = 180, 238, 298
    d.fio((x, 170), (x, n1), (xl, n1), net="N1")
    d.fio((x, n1), (x, 188), net="N1")
    d.fio((xs, n1), (xs, 188), net="N1")
    d.fio((xl, n1), (xl, 188), net="N1")
    d.no(x, n1, net="N1")
    d.no(xs, n1, net="N1")
    d.contato(x, 188, id="S1", tag="S1", bornes=("13", "14"), atuador="botao",
              nome="botão liga S1")
    d.contato(xs, 188, id="K1.13", tag="K1", bornes=("13", "14"),
              nome="contato de selo K1 13-14")
    d.contato(xl, 188, id="K1.23", tag="K1", bornes=("23", "24"),
              nome="contato K1 23-24")
    d.fio((x, 228), (x, n2), net="N2")
    d.fio((xs, 228), (xs, n2), (x, n2), net="N2")
    d.no(x, n2, net="N2")
    d.fio((x, n2), (x, 246), net="N2")
    d.bobina(x, 246, id="K1.A1", tag="K1", nome="bobina de K1")
    d.fio((xl, 228), (xl, 246), net="c")
    d.lampada(xl, 246, id="E1", tag="E1", nome="lâmpada E1")
    d.fio((x, 286), (x, col), net="col")
    d.fio((xl, 286), (xl, col), (x, col), net="col")
    d.no(x, col, net="col")
    d.fio((x, col), (x, 306), net="col")
    d.contato(x, 306, id="Q12", tag="Q12", atuador="disjuntor", nome="disjuntor Q12")
    d.fio((x, 346), (x, 352), net="L2")
    d.borne(x, 355.5, "L2", net="L2")
    return d


@circuito("pd-forca")
def pd_forca():
    """Força da partida direta: L1 L2 L3 → F10 → K1 → F7 → M1, com PE."""
    d = Desenho(300, 372, alt="Diagrama de força da partida direta: L1, L2 e L3 passam "
                "pelos fusíveis F10, pelos contatos 1-2, 3-4 e 5-6 de K1 e pelo relé térmico "
                "F7 até o motor M1; o PE vai à carcaça do motor.")
    xs, trilhos = (130, 170, 210), (38, 54, 70)
    d.texto(236, 24, "3~ 220 V / 60 Hz", tam=11, ancora="middle")
    for y, fase in zip(trilhos, ("L1", "L2", "L3")):
        d.barramento(y, 60, 280, fase)
    d.barramento(86, 60, 280, "PE", cor=VERDE, tracejado="8,3,2,3")
    for x, y, fase in zip(xs, trilhos, ("L1", "L2", "L3")):
        d.fio((x, y), (x, 104), net=fase)
        d.no(x, y, net=fase)
    y_f = 104
    d.tripolar(xs, y_f, "fusivel", "F10", tag="F10", bornes=None, nome="fusível F10")
    y_k = y_f + ALTURA + 12
    y_t = y_k + ALTURA + 12
    y_m = y_t + ALTURA + 10
    for x, fase in zip(xs, ("L1", "L2", "L3")):
        d.fio((x, y_f + ALTURA), (x, y_k), net=f"{fase}f")
        d.fio((x, y_k + ALTURA), (x, y_t), net=f"{fase}k")
        d.fio((x, y_t + ALTURA), (x, y_m), net=f"{fase}t")
    d.tripolar(xs, y_k, "contato", "K1", tag="K1", nome="contato de potência de K1")
    d.tripolar(xs, y_t, "termico", "F7", tag="F7", nome="elemento térmico de F7")
    yc, r = d.motor3(xs, y_m)
    with d.grupo("~PE"):
        d.linha([(262, 86), (262, yc), (xs[1] + r, yc)], cor=VERDE, esp=1.5,
                tracejado="8,3,2,3")
        d.texto(266, yc - 4, "PE", tam=10, cor=VERDE)
    return d


# ---- símbolos avulsos ------------------------------------------------------

simbolo(M, "simbolo-contato-95-96",
        lambda d: d.contato(84, 20, "nf", bornes=("95", "96"), atuador="termico"),
        alt="Símbolo de um contato normalmente fechado, com os terminais 95 em cima e 96 "
            "embaixo, ligado por linha tracejada a um atuador em forma de degrau à esquerda.")


# ---- vistas: uma linha por figura de cartão ----------------------------------

vista(M, "partida-direta-comando", "pd-comando")
vista(M, "partida-direta-comando-selo", "pd-comando", destaque=["K1.13"])
vista(M, "partida-direta-forca-fusivel-l2", "pd-forca",
      pontos=[("A", "F10.L2", "topo"), ("B", "F10.L2", "base")])


# ---- galeria de símbolos: um circuito, um cartão por destaque ----------------
# Ids G1..G12, sem letra nem número visíveis além dos bornes que o próprio
# símbolo traz — o cartão pergunta "o símbolo destacado representa..."

@circuito("galeria")
def galeria():
    d = Desenho(300, 250, alt="Quadro com doze símbolos elétricos em três linhas.")
    col = (50, 125, 200, 270)
    y1, y2, y3 = 20, 105, 190
    d.contato(col[0], y1, "na", id="G1", nome="contato NA")
    d.contato(col[1], y1, "nf", id="G2", nome="contato NF")
    d.contato(col[2], y1, "na", id="G3", atuador="botao", nome="botão NA")
    d.contato(col[3], y1, "nf", id="G4", atuador="botao", nome="botão NF")
    d.contato(col[0], y2, "na", id="G5", atuador="fimdecurso", nome="fim de curso NA")
    d.contato(col[1], y2, "na", id="G6", atuador="temp_on", nome="contato NA temporizado na energização")
    d.contato(col[2], y2, "na", id="G7", atuador="temp_off", nome="contato NA temporizado na desenergização")
    d.contato(col[3], y2, "nf", id="G8", atuador="termico", nome="contato NF térmico")
    d.bobina(col[0], y3, id="G9", nome="bobina")
    d.bobina(col[1] + 6, y3, id="G10", tempo="on", nome="bobina de temporizador na energização")
    d.fusivel(col[2], y3, id="G11", nome="fusível")
    d.lampada(col[3], y3, id="G12", nome="sinalizador luminoso")
    return d


# ---- temporizador com contato comutador ------------------------------------

@circuito("temporizador")
def temporizador():
    """KT1 (retardo na energização) comandado pela chave S1; o contato
    comutador 15-16-18 alterna entre H1 (16, NF) e H2 (18, NA)."""
    d = Desenho(270, 230, alt="Diagrama entre L1 e N: a chave S1 alimenta a bobina do "
                "temporizador KT1, com retardo na energização. Ao lado, o contato comutador "
                "de KT1: do comum 15 saem o 16, que acende H1, e o 18, que acende H2.")
    x, xc = 80, 190
    d.borne(x, 24, "L1", net="L1")
    d.fio((x, 27.5), (x, 40), (xc, 40), (xc, 56), net="L1")
    d.no(x, 40, net="L1")
    d.fio((x, 40), (x, 56), net="L1")
    d.contato(x, 56, id="S1", tag="S1", bornes=("13", "14"), nome="chave S1")
    d.fio((x, 96), (x, 116), net="a")
    d.bobina(x, 116, id="KT1.A1", tag="KT1", tempo="on", nome="bobina do temporizador KT1")
    d.contato(xc, 56, "comutador", id="KT1.15", tag="KT1", bornes=("15", "16", "18"),
              nome="contato comutador 15-16-18 de KT1")
    xh1, xh2 = xc + 11, xc - 11
    d.fio((xh1, 96), (xh1, 106), (xh1 + 30, 106), (xh1 + 30, 116), net="h1")
    d.fio((xh2, 96), (xh2, 106), (xh2 - 30, 106), (xh2 - 30, 116), net="h2")
    d.lampada(xh1 + 30, 116, id="H1", tag="H1", nome="lâmpada H1")
    d.lampada(xh2 - 30, 116, id="H2", tag="H2", nome="lâmpada H2")
    d.fio((x, 156), (x, 190), (xh1 + 30, 190), (xh1 + 30, 156), net="N")
    d.fio((xh2 - 30, 156), (xh2 - 30, 190), net="N")
    d.no(x, 190, net="N")
    d.no(xh2 - 30, 190, net="N")
    d.fio((x, 190), (x, 200), net="N")
    d.borne(x, 203.5, "N", net="N")
    return d


# ---- vistas da Fase 3: simbologia, proteção e comando ------------------------

for _g, _nome in [("G1", "contato-na"), ("G2", "contato-nf"), ("G3", "botao-na"),
                  ("G4", "botao-nf"), ("G5", "fim-de-curso"), ("G6", "temporizado-energizacao"),
                  ("G7", "temporizado-desenergizacao"),
                  ("G9", "bobina"), ("G10", "bobina-temporizador"), ("G11", "fusivel"),
                  ("G12", "sinalizador")]:
    vista(M, f"galeria-{_nome}", "galeria", destaque=[_g])

vista(M, "partida-direta-forca", "pd-forca")
vista(M, "partida-direta-forca-k1-recorte", "pd-forca", recorte=["K1"])
vista(M, "partida-direta-forca-f10-f7", "pd-forca", destaque=["F10", "F7"])
vista(M, "partida-direta-comando-q11", "pd-comando", destaque=["Q11"])
vista(M, "partida-direta-comando-f7", "pd-comando", destaque=["F7.95"])
vista(M, "partida-direta-comando-e1", "pd-comando", destaque=["K1.23", "E1"])
vista(M, "temporizador-comutador", "temporizador")
vista(M, "temporizador-comutador-recorte", "temporizador", recorte=["KT1.15"], destaque=["KT1.15"])


# ---- Partida direta: comando de vários pontos (Franchi, Figura A.8) ----------

@circuito("varios-pontos")
def varios_pontos():
    """Dois postos de comando: desliga S0a e S0b em série (NF); liga S1a e
    S1b em paralelo entre si e com o selo K1 13-14."""
    d = Desenho(290, 350, alt="Comando de um motor por dois postos, entre L1 e L2: Q11, F7 95-96, "
                "os botões de desligar S0a e S0b em série; depois os botões de ligar S1a e S1b "
                "em paralelo entre si e com o contato de selo K1 13-14; por fim a bobina de K1.")
    x, x2, x3 = 100, 160, 220
    d.borne(x, 24, "L1", net="L1")
    d.texto(x + 12, 28, "220 V / 60 Hz", tam=11)
    d.fio((x, 27.5), (x, 32), net="L1")
    d.contato(x, 32, id="Q11", tag="Q11", atuador="disjuntor", nome="disjuntor Q11")
    d.fio((x, 72), (x, 76), net="a")
    d.contato(x, 76, "nf", id="F7.95", tag="F7", bornes=("95", "96"), atuador="termico",
              nome="contato 95-96 de F7")
    d.fio((x, 116), (x, 120), net="b")
    d.contato(x, 120, "nf", id="S0a", tag="S0a", bornes=("11", "12"), atuador="botao",
              nome="botão desliga S0a")
    d.fio((x, 160), (x, 164), net="c")
    d.contato(x, 164, "nf", id="S0b", tag="S0b", bornes=("11", "12"), atuador="botao",
              nome="botão desliga S0b")
    n1, n2 = 214, 272
    d.fio((x, 204), (x, n1), (x3, n1), net="N1")
    for xx in (x, x2, x3):
        d.fio((xx, n1), (xx, 222), net="N1")
    d.no(x, n1, net="N1")
    d.no(x2, n1, net="N1")
    d.contato(x, 222, id="S1a", tag="S1a", bornes=("13", "14"), atuador="botao", nome="botão liga S1a")
    d.contato(x2, 222, id="S1b", tag="S1b", bornes=("13", "14"), atuador="botao", nome="botão liga S1b")
    d.contato(x3, 222, id="K1.13", tag="K1", bornes=("13", "14"), nome="contato de selo K1 13-14")
    d.fio((x3, 262), (x3, n2), (x, n2), net="N2")
    d.fio((x2, 262), (x2, n2), net="N2")
    d.fio((x, 262), (x, n2), (x, 280), net="N2")
    d.no(x, n2, net="N2")
    d.no(x2, n2, net="N2")
    d.bobina(x, 280, id="K1.A1", tag="K1", nome="bobina de K1")
    d.fio((x, 320), (x, 326), net="L2")
    d.borne(x, 329.5, "L2", net="L2")
    return d


# ---- Partida com reversão (apostila SENAI, cap. 9, nomenclatura da Figura 175) --

@circuito("rev-comando")
def rev_comando():
    """Comando da reversão em 24 VCC. Coluna de K10 (x=100): S1 13-14 com o
    selo K10 13-14 em paralelo; S2 21-22 e K20 21-22 (intertravamentos); bobina
    K10. Coluna de K20 (x=220): o espelho. Sinalização: K10 33-34 -> E1 e
    K20 33-34 -> E2."""
    d = Desenho(410, 470, alt="Comando de partida com reversão em 24 VCC: F1, contato 95-96 do "
                "disjuntor-motor Q1 e S0. Coluna de K10: S1 13-14 com o selo K10 13-14 em paralelo, "
                "depois o NF 21-22 de S2, o NF 21-22 de K20 e a bobina de K10. Coluna de K20: S2 "
                "13-14 com o selo K20 13-14, o NF 21-22 de S1, o NF 21-22 de K10 e a bobina de K20. "
                "À direita, K10 33-34 acende E1 e K20 33-34 acende E2. Embaixo, F2 e 0 V.")
    x, xa, xb, xs2, xl1, xl2 = 100, 150, 220, 270, 330, 380
    d.borne(x, 22, "+24 VCC", net="P")
    d.fio((x, 25.5), (x, 30), net="P")
    d.fusivel(x, 30, id="F1", tag="F1", nome="fusível F1")
    d.fio((x, 70), (x, 76), net="a")
    d.contato(x, 76, "nf", id="Q1.95", tag="Q1", bornes=("95", "96"), atuador="termico",
              nome="contato 95-96 do disjuntor-motor Q1")
    d.fio((x, 116), (x, 122), net="b")
    d.contato(x, 122, "nf", id="S0", tag="S0", bornes=("11", "12"), atuador="botao", nome="botão desliga S0")
    n1 = 172
    d.fio((x, 162), (x, n1), (xl2, n1), net="N1")
    for xx in (x, xa, xb, xs2, xl1, xl2):
        d.fio((xx, n1), (xx, 180), net="N1")
    for xx in (x, xa, xb, xs2, xl1):
        d.no(xx, n1, net="N1")
    # coluna K10
    d.contato(x, 180, id="S1", tag="S1", bornes=("13", "14"), atuador="botao", nome="botão S1 (13-14)")
    d.contato(xa, 180, id="K10.13", tag="K10", bornes=("13", "14"), nome="selo K10 13-14")
    d.fio((xa, 220), (xa, 230), (x, 230), net="A2")
    d.fio((x, 220), (x, 236), net="A2")
    d.no(x, 230, net="A2")
    d.contato(x, 236, "nf", id="S2.21", tag="S2", bornes=("21", "22"), atuador="botao",
              nome="contato NF 21-22 do botão S2")
    d.fio((x, 276), (x, 282), net="A3")
    d.contato(x, 282, "nf", id="K20.21", tag="K20", bornes=("21", "22"), nome="contato NF 21-22 de K20")
    d.fio((x, 322), (x, 328), net="A4")
    d.bobina(x, 328, id="K10.A1", tag="K10", nome="bobina de K10")
    # coluna K20
    d.contato(xb, 180, id="S2", tag="S2", bornes=("13", "14"), atuador="botao", nome="botão S2 (13-14)")
    d.contato(xs2, 180, id="K20.13", tag="K20", bornes=("13", "14"), nome="selo K20 13-14")
    d.fio((xs2, 220), (xs2, 230), (xb, 230), net="B2")
    d.fio((xb, 220), (xb, 236), net="B2")
    d.no(xb, 230, net="B2")
    d.contato(xb, 236, "nf", id="S1.21", tag="S1", bornes=("21", "22"), atuador="botao",
              nome="contato NF 21-22 do botão S1")
    d.fio((xb, 276), (xb, 282), net="B3")
    d.contato(xb, 282, "nf", id="K10.21", tag="K10", bornes=("21", "22"), nome="contato NF 21-22 de K10")
    d.fio((xb, 322), (xb, 328), net="B4")
    d.bobina(xb, 328, id="K20.A1", tag="K20", nome="bobina de K20")
    # sinalização
    d.contato(xl1, 180, id="K10.33", tag="K10", bornes=("33", "34"), nome="contato K10 33-34")
    d.contato(xl2, 180, id="K20.33", tag="K20", bornes=("33", "34"), nome="contato K20 33-34")
    d.fio((xl1, 220), (xl1, 328), net="e1")
    d.fio((xl2, 220), (xl2, 328), net="e2")
    d.lampada(xl1, 328, id="E1", tag="E1", nome="lâmpada E1")
    d.lampada(xl2, 328, id="E2", tag="E2", nome="lâmpada E2")
    col = 384
    for xx in (x, xb, xl1, xl2):
        d.fio((xx, 368), (xx, col), net="Z")
    d.fio((x, col), (xl2, col), net="Z")
    for xx in (x, xb, xl1):
        d.no(xx, col, net="Z")
    d.fio((x, col), (x, 392), net="Z")
    d.fusivel(x, 392, id="F2", tag="F2", nome="fusível F2")
    d.fio((x, 432), (x, 438), net="0V")
    d.borne(x, 441.5, "0 V", net="0V")
    return d


@circuito("rev-forca")
def rev_forca():
    """Força da reversão: Q1 -> K10 (L1-U1, L2-V1, L3-W1) em paralelo com K20,
    que troca L1 e L3 (L1-W1, L3-U1)."""
    d = Desenho(310, 350, alt="Força da partida com reversão: L1, L2 e L3 passam pelo disjuntor-motor "
                "Q1 e se dividem entre os contatores K10 e K20. K10 liga L1 ao U1, L2 ao V1 e L3 ao W1. "
                "K20 liga L2 ao V1 e troca as outras duas: L1 vai ao W1 e L3 ao U1.")
    xs = (100, 130, 160)
    xr = (210, 240, 270)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 50, 290, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 80), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 80, "contato", "Q1", tag="Q1", nome="polo do disjuntor-motor Q1", atuador="disjuntor")
    for x, xx, y, f in zip(xs, xr, (132, 140, 148), ("L1", "L2", "L3")):
        d.fio((x, 120), (x, 162), net=f + "q")
        d.fio((x, y), (xx, y), (xx, 162), net=f + "q")
        d.no(x, y, net=f + "q")
    d.tripolar(xs, 162, "contato", "K10", tag="K10", nome="polo de K10")
    d.tripolar(xr, 162, "contato", "K20", tag=None, nome="polo de K20")
    with d.grupo("K20.tag"):
        d.texto(xr[-1] + 18, 186, "K20", negrito=True)
    ym = 268
    for x, f in zip(xs, ("U", "V", "W")):
        d.fio((x, 202), (x, ym), net=f)
    # K20: L1 (210) -> W1 (160); L2 (240) -> V1 (130); L3 (270) -> U1 (100)
    for xx, xd, y, f in zip(xr, (160, 130, 100), (230, 238, 246), ("W", "V", "U")):
        d.fio((xx, 202), (xx, y), (xd, y), net=f)
        d.no(xd, y, net=f)
    d.motor3(xs, ym, tag="M1")
    return d


vista(M, "varios-pontos", "varios-pontos")
vista(M, "partida-direta-comando-pontos-s1", "pd-comando", pontos=[("A", "S1", "topo"), ("B", "K1.A1", "topo", "esq")])
vista(M, "partida-direta-comando-pontos-bobina", "pd-comando", pontos=[("A", "K1.A1", "topo", "esq"), ("B", "K1.A1", "base", "esq")])
vista(M, "partida-direta-forca-contato-l2", "pd-forca", pontos=[("A", "K1.L2", "topo"), ("B", "K1.L2", "base")])
vista(M, "partida-direta-forca-k1", "pd-forca", destaque=["K1.L1", "K1.L2", "K1.L3"])
vista(M, "reversao-comando", "rev-comando")
vista(M, "reversao-comando-k20-21", "rev-comando", destaque=["K20.21"])
vista(M, "reversao-comando-s2-21", "rev-comando", destaque=["S2.21"])
vista(M, "reversao-comando-pontos-k20", "rev-comando", pontos=[("A", "K20.A1", "topo", "esq"), ("B", "K20.A1", "base", "esq")])
vista(M, "reversao-forca-k20", "rev-forca", destaque=["K20"])


# ---- Partida estrela-triângulo (apostila cap. 10: K1 linha, K2 estrela, K3 triângulo) --

def _motor6(d, xs, y, cx=None):
    """Motor com seis terminais: 1, 2 e 3 chegam por cima (como no motor3);
    6, 4 e 5 saem pela direita, na altura devolvida em 'direita'."""
    import math
    cx = cx or xs[1]
    r = 28
    cy = y + 30 + r
    direita = {}
    with d.grupo("M1"):
        for x, rot, ang in zip(xs, ("1", "2", "3"), (-40, 0, 40)):
            a = math.radians(ang)
            d.linha([(x, y), (x, y + 14), (cx + r * math.sin(a), cy - r * math.cos(a))])
            d.texto(x + 4, y + 11, rot, tam=10)
        d.circulo(cx, cy, r)
        d.texto(cx, cy - 2, "M", tam=15, ancora="middle", negrito=True)
        d.texto(cx, cy + 14, "3~", ancora="middle")
        d.texto(xs[0] - 16, cy + 4, "M1", ancora="end", negrito=True)
        for rot, dy in (("6", -16), ("4", 0), ("5", 16)):
            xe = cx + math.sqrt(r * r - dy * dy)
            direita[rot] = (xe, cy + dy)
            d.texto(xe + 3, cy + dy - 3, rot, tam=10)
    return direita


@circuito("yd-forca")
def yd_forca():
    d = Desenho(400, 400, alt="Força da partida estrela-triângulo: L1, L2 e L3 passam pelos fusíveis F10. "
                "K1 e o relé térmico F7 levam as fases aos terminais 1, 2 e 3 do motor. K3 liga L1 ao "
                "terminal 6, L2 ao 4 e L3 ao 5 (triângulo). K2 tem as entradas unidas entre si e as saídas "
                "nos terminais 6, 4 e 5 (fecha a estrela).")
    xs, x3, x2 = (90, 116, 142), (200, 226, 252), (300, 326, 352)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 50, 380, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 80), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 80, "fusivel", "F10", tag="F10", bornes=None, nome="fusível F10")
    for x, xx, y, f in zip(xs, x3, (132, 140, 148), ("L1", "L2", "L3")):
        d.fio((x, 120), (x, 164), net=f + "f")
        d.fio((x, y), (xx, y), (xx, 164), net=f + "f")
        d.no(x, y, net=f + "f")
    d.tripolar(xs, 164, "contato", "K1", tag="K1", nome="polo de K1")
    d.tripolar(x3, 164, "contato", "K3", tag="K3", nome="polo de K3")
    with d.grupo("K2.ponte"):
        d.linha([(x2[0], 156), (x2[-1], 156)])
        for x in x2:
            d.linha([(x, 156), (x, 164)])
        d.no(x2[1], 156)
    d.tripolar(x2, 164, "contato", "K2", tag="K2", nome="polo de K2")
    for x in xs:
        d.fio((x, 204), (x, 214))
    d.tripolar(xs, 214, "termico", "F7", tag="F7", nome="elemento térmico de F7")
    dire = _motor6(d, xs, 262)
    # terminais 6, 4, 5 levados para a direita até as saídas de K3 e K2
    for rot, xk3, xk2 in (("6", x3[0], x2[0]), ("4", x3[1], x2[1]), ("5", x3[2], x2[2])):
        xe, ye = dire[rot]
        with d.grupo("~T" + rot):
            d.linha([(xe, ye), (x2[-1] + 14, ye)])
            d.linha([(xk2, 204), (xk2, ye)])
        with d.grupo("~K3T" + rot):          # perna de K3: sem corrente na estrela
            d.linha([(xk3, 204), (xk3, ye)])
        d.no(xk3, ye, net="T" + rot)
        d.no(xk2, ye, net="T" + rot)
    return d


@circuito("yd-comando")
def yd_comando():
    """Comando da estrela-triângulo com temporizador de contato comutador:
    S1 energiza K1 (selo) e KT; o comum 15 de KT alimenta K2 (estrela) pelo 16
    e, passado o tempo, K3 (triângulo) pelo 18. K3 21-22 e K2 21-22 fazem o
    intertravamento entre estrela e triângulo."""
    d = Desenho(360, 480, alt="Comando da partida estrela-triângulo entre L1 e L2: Q11, F7 95-96, S0, "
                "e S1 com o selo K1 13-14 em paralelo. Depois do selo: a bobina de K1; o contato comutador "
                "15-16-18 do temporizador KT, cujo 16 alimenta a bobina de K2 através do NF 21-22 de K3 e "
                "cujo 18 alimenta a bobina de K3 através do NF 21-22 de K2; e a bobina do temporizador KT, "
                "com retardo na energização.")
    x, xs_, xt, xk3, xk2, xkt = 100, 150, 205, 170, 250, 320
    d.borne(x, 24, "L1", net="L1")
    d.texto(x + 12, 28, "220 V / 60 Hz", tam=11)
    d.fio((x, 27.5), (x, 32), net="L1")
    d.contato(x, 32, id="Q11", tag="Q11", atuador="disjuntor", nome="disjuntor Q11")
    d.fio((x, 72), (x, 78), net="a")
    d.contato(x, 78, "nf", id="F7.95", tag="F7", bornes=("95", "96"), atuador="termico", nome="contato 95-96 de F7")
    d.fio((x, 118), (x, 124), net="b")
    d.contato(x, 124, "nf", id="S0", tag="S0", bornes=("11", "12"), atuador="botao", nome="botão desliga S0")
    n1, n2 = 174, 234
    d.fio((x, 164), (x, n1), (xs_, n1), (xs_, 182), net="N1")
    d.fio((x, n1), (x, 182), net="N1")
    d.no(x, n1, net="N1")
    d.contato(x, 182, id="S1", tag="S1", bornes=("13", "14"), atuador="botao", nome="botão liga S1")
    d.contato(xs_, 182, id="K1.13", tag="K1", bornes=("13", "14"), nome="selo K1 13-14")
    d.fio((xs_, 222), (xs_, n2), net="N2")
    d.fio((x, 222), (x, n2), (xkt, n2), net="N2")
    for xx in (x, xs_, xt):
        d.no(xx, n2, net="N2")
    d.fio((x, n2), (x, 348), net="N2")
    d.bobina(x, 348, id="K1.A1", tag="K1", nome="bobina de K1")
    d.fio((xt, n2), (xt, 244), net="N2")
    d.contato(xt, 244, "comutador", id="KT.15", tag="KT", bornes=("15", "16", "18"),
              nome="contato comutador 15-16-18 de KT")
    # 16 (NF, direita) → K3 21-22 → bobina K2 (estrela)
    d.fio((xt + 11, 284), (xt + 11, 292), (xk2, 292), (xk2, 300), net="e16")
    d.contato(xk2, 300, "nf", id="K3.21", tag="K3", bornes=("21", "22"), nome="NF 21-22 de K3")
    d.fio((xk2, 340), (xk2, 348), net="e16b")
    d.bobina(xk2, 348, id="K2.A1", tag="K2", nome="bobina de K2 (estrela)")
    # 18 (NA, esquerda) → K2 21-22 → bobina K3 (triângulo)
    d.fio((xt - 11, 284), (xt - 11, 292), (xk3, 292), (xk3, 300), net="e18")
    d.contato(xk3, 300, "nf", id="K2.21", tag="K2", bornes=("21", "22"), nome="NF 21-22 de K2")
    d.fio((xk3, 340), (xk3, 348), net="e18b")
    d.bobina(xk3, 348, id="K3.A1", tag="K3", nome="bobina de K3 (triângulo)")
    d.fio((xkt, n2), (xkt, 348), net="N2")
    d.bobina(xkt, 348, id="KT.A1", tag="KT", tempo="on", nome="bobina do temporizador KT")
    col = 402
    for xx in (x, xk3, xk2, xkt):
        d.fio((xx, 388), (xx, col), net="Z")
    d.fio((x, col), (xkt, col), net="Z")
    for xx in (x, xk3, xk2):
        d.no(xx, col, net="Z")
    d.fio((x, col), (x, 410), net="Z")
    d.contato(x, 410, id="Q12", tag="Q12", atuador="disjuntor", nome="disjuntor Q12")
    d.fio((x, 450), (x, 456), net="L2")
    d.borne(x, 459.5, "L2", net="L2")
    return d


# ---- Partida compensadora (K1 tensão plena, K2 liga o autotransformador à rede,
#      K3 fecha a estrela do autotransformador — apostila 11.2 e Franchi 5.3.2) --

@circuito("comp-forca")
def comp_forca():
    d = Desenho(360, 440, alt="Força da partida compensadora: L1, L2 e L3 passam pelos fusíveis F10. "
                "K1, seguido do relé térmico F7, liga o motor direto à rede. K2 liga a rede às três bobinas "
                "do autotransformador T1; as pontas de baixo das bobinas são unidas por K3 (estrela). Do tap "
                "de 80% de cada bobina sai um fio para o terminal correspondente do motor.")
    xs, x2, x3 = (90, 116, 142), (220, 250, 280), (220, 250, 280)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 50, 330, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 80), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 80, "fusivel", "F10", tag="F10", bornes=None, nome="fusível F10")
    for x, xx, y, f in zip(xs, x2, (132, 140, 148), ("L1", "L2", "L3")):
        d.fio((x, 120), (x, 164), net=f + "f")
        d.fio((x, y), (xx, y), (xx, 164), net=f + "f")
        d.no(x, y, net=f + "f")
    d.tripolar(xs, 164, "contato", "K1", tag="K1", nome="polo de K1")
    d.tripolar(x2, 164, "contato", "K2", tag=None, nome="polo de K2")
    with d.grupo("K2.tag"):
        d.texto(x2[-1] + 18, 188, "K2", negrito=True)
    for x in xs:
        d.fio((x, 204), (x, 214))
    d.tripolar(xs, 214, "termico", "F7", tag="F7", nome="elemento térmico de F7")
    # autotransformador: três bobinas, tap de 80% a 1/5 da altura a partir de cima... (80% da tensão
    # fica entre o tap e o ponto de estrela, embaixo)
    yb0, yb1 = 214, 294
    with d.grupo("T1"):
        for x in x2:
            d.linha([(x, 204), (x, yb0)])
            d.retangulo(x - 6, yb0, 12, yb1 - yb0, preench="#fff")
            d.linha([(x, yb1), (x, 310)])
        d.texto(x2[-1] + 16, yb0 + 34, "T1", negrito=True)
        d.texto(x2[-1] + 16, yb0 + 50, "80%", tam=10)
    ytap = yb0 + (yb1 - yb0) * 0.2
    d.tripolar(x3, 318, "contato", "K3", tag=None, nome="polo de K3")
    with d.grupo("K3.tag"):
        d.texto(x3[-1] + 18, 342, "K3", negrito=True)
    with d.grupo("K3.estrela"):
        d.linha([(x3[0], 358), (x3[0], 368), (x3[-1], 368), (x3[-1], 358)])
        d.linha([(x3[1], 358), (x3[1], 368)])
        d.no(x3[1], 368)
    for x in x2:
        d.fio((x, 310), (x, 318))
    ym = 320
    for x in xs:
        d.fio((x, 254), (x, ym))
    # taps de 80%: descem pelo vão à esquerda de cada bobina e seguem por baixo
    # delas até o motor; a bobina mais à esquerda usa a linha mais alta, para
    # nenhum tap cruzar a descida de outro
    for xx, xd, y in zip(x2, xs, (298, 302, 306)):
        with d.grupo("~tap"):
            d.linha([(xx - 6, ytap), (xx - 12, ytap), (xx - 12, y), (xd, y)])
        d.no(xd, y, net="tap")
    d.motor3(xs, ym, tag="M1")
    return d


vista(M, "estrela-triangulo-forca-k2", "yd-forca", destaque=["K2"])
vista(M, "estrela-triangulo-forca-k3", "yd-forca", destaque=["K3"])
vista(M, "estrela-triangulo-forca-estrela", "yd-forca", acionados=["K1", "K2"],
      energizado=["~L1", "~L2", "~L3", "F10", "~L1f", "~L2f", "~L3f", "K1", "F7", "M1", "K2", "~T6", "~T4", "~T5"])
vista(M, "estrela-triangulo-comando", "yd-comando")
vista(M, "estrela-triangulo-comando-intertravamento", "yd-comando", destaque=["K3.21", "K2.21"])
vista(M, "compensadora-forca-k3", "comp-forca", destaque=["K3"])


# ---- Comutação de velocidades: motor Dahlander (apostila cap. 12: K2 baixa;
#      K1 e K3 alta, com K3 unindo 1U, 1V e 1W) --------------------------------

@circuito("dahl-forca")
def dahl_forca():
    import math
    d = Desenho(400, 420, alt="Força de um motor Dahlander: L1, L2 e L3 passam pelos fusíveis F10. "
                "K2, com o relé térmico F7, liga as fases aos terminais 1U, 1V e 1W (velocidade baixa). "
                "K1, com o relé térmico F8, liga as fases aos terminais 2U, 2V e 2W (velocidade alta); K3 "
                "tem as entradas unidas e as saídas em 1U, 1V e 1W, unindo esses três terminais.")
    xs, x1, x3 = (90, 116, 142), (200, 226, 252), (300, 326, 352)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 50, 380, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 80), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 80, "fusivel", "F10", tag="F10", bornes=None, nome="fusível F10")
    for x, xx, y, f in zip(xs, x1, (132, 140, 148), ("L1", "L2", "L3")):
        d.fio((x, 120), (x, 164), net=f + "f")
        d.fio((x, y), (xx, y), (xx, 164), net=f + "f")
        d.no(x, y, net=f + "f")
    d.tripolar(xs, 164, "contato", "K2", tag="K2", nome="polo de K2")
    d.tripolar(x1, 164, "contato", "K1", tag="K1", nome="polo de K1")
    with d.grupo("K3.ponte"):
        d.linha([(x3[0], 156), (x3[-1], 156)])
        for x in x3:
            d.linha([(x, 156), (x, 164)])
        d.no(x3[1], 156)
    d.tripolar(x3, 164, "contato", "K3", tag="K3", nome="polo de K3")
    for x in xs + x1:
        d.fio((x, 204), (x, 214))
    d.tripolar(xs, 214, "termico", "F7", tag="F7", nome="elemento térmico de F7")
    d.tripolar(x1, 214, "termico", "F8", tag=None, nome="elemento térmico de F8")
    with d.grupo("F8.tag"):
        d.texto(x1[-1] + 16, 238, "F8", negrito=True)
    # motor: 1U 1V 1W por cima (vindos de F7); 2U 2V 2W pela direita
    cx, r = xs[1], 28
    cy = 262 + 56 + r
    with d.grupo("M1"):
        for x, rot, ang in zip(xs, ("1U", "1V", "1W"), (-40, 0, 40)):
            a = math.radians(ang)
            d.linha([(x, 254), (x, 300), (cx + r * math.sin(a), cy - r * math.cos(a))])
            d.texto(x + 4, 296, rot, tam=10)
        d.circulo(cx, cy, r)
        d.texto(cx, cy - 2, "M", tam=15, ancora="middle", negrito=True)
        d.texto(cx, cy + 14, "3~", ancora="middle")
        d.texto(xs[0] - 16, cy + 4, "M1", ancora="end", negrito=True)
    for rot, dy, xk1 in (("2U", -16, x1[0]), ("2V", 0, x1[1]), ("2W", 16, x1[2])):
        xe = cx + math.sqrt(r * r - dy * dy)
        with d.grupo("~" + rot):
            d.linha([(xe, cy + dy), (xk1, cy + dy), (xk1, 254)])
            d.texto(xe + 3, cy + dy - 3, rot, tam=10)
    # K3: saídas em 1U, 1V, 1W (as linhas que descem de F7)
    for xk3, xm, y in zip(x3, xs, (262, 268, 274)):
        with d.grupo("~K3" + str(xm)):
            d.linha([(xk3, 204), (xk3, y), (xm, y)])
        d.no(xm, y, net="K3" + str(xm))
    return d


# ---- Aceleração rotórica: rotor bobinado com três estágios de resistências ---------

@circuito("rotorica-forca")
def rotorica_forca():
    d = Desenho(330, 540, alt="Força da partida rotórica: L1, L2 e L3 passam pelos fusíveis F10, por K1 "
                "e pelo relé térmico F7 até o estator do motor de anéis M1. Os terminais do rotor K, L e M "
                "descem cada um por uma coluna de três resistores. K11 une as três colunas depois do "
                "primeiro resistor, K12 depois do segundo, e K13 no fim, curto-circuitando tudo.")
    xs = (110, 140, 170)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 60, 300, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 76), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 76, "fusivel", "F10", tag="F10", bornes=None, nome="fusível F10")
    d.tripolar(xs, 124, "contato", "K1", tag="K1", nome="polo de K1")
    d.tripolar(xs, 172, "termico", "F7", tag="F7", nome="elemento térmico de F7")
    for x in xs:
        d.fio((x, 116), (x, 124))
        d.fio((x, 164), (x, 172))
    yc, r = d.motor3(xs, 212, tag="M1")
    with d.grupo("M1"):
        d.circulo(xs[1], yc, r - 7)            # círculo interno: rotor bobinado
    # rotor: K, L, M saem por baixo e descem por três colunas de resistores;
    # em cada estágio, um contator tripolar une as três colunas (estrela),
    # tirando do circuito os resistores de baixo
    y0 = yc + r
    for x, rot in zip(xs, ("K", "L", "M")):
        with d.grupo("~" + rot):
            d.linha([(x, y0 - 6), (x, y0 + 8)])
            d.texto(x + 4, y0 + 6, rot, tam=10)
    passo = 78
    xk = (230, 252, 274)
    for i, tag in enumerate(("K11", "K12", "K13")):
        yr = y0 + 8 + i * passo
        for x, rot in zip(xs, ("K", "L", "M")):
            d.resistor(x, yr, id=f"R{rot}{i + 1}", nome=f"resistor {i + 1} do terminal {rot}")
        yl = yr + ALTURA
        ultimo = i == 2
        for j, (x, xx) in enumerate(zip(xs, xk)):
            yj = yl + 4 + j * 6
            fim = yj if ultimo else yr + passo
            d.fio((x, yl), (x, fim))
            d.fio((x, yj), (xx, yj), (xx, yl + 22))
            d.no(x, yj)
        d.tripolar(xk, yl + 22, "contato", tag, tag=tag, nome=f"polo de {tag}")
        with d.grupo(tag + ".estrela"):
            d.linha([(xk[0], yl + 62), (xk[0], yl + 68), (xk[-1], yl + 68), (xk[-1], yl + 62)])
            d.linha([(xk[1], yl + 62), (xk[1], yl + 68)])
            d.no(xk[1], yl + 68)
    return d


# ---- Sensores de proximidade de 3 fios: NPN e PNP (apostila 7.1.2) ----------------

def _sensor3(tipo):
    d = Desenho(300, 230, alt=(f"Sensor de proximidade de três fios, saída {tipo}, alimentado entre +24 VCC e 0 V: "
                "fio marrom no +, azul no 0 V e preto na saída. " +
                ("A carga (bobina de K1) fica entre o + e o fio preto." if tipo == "NPN"
                 else "A carga (bobina de K1) fica entre o fio preto e o 0 V.")))
    d.barramento(30, 60, 270, "+24 V", cor=None)
    d.barramento(200, 60, 270, "0 V", cor=None)
    xs, xk = 110, 220
    with d.grupo("B1"):
        d.retangulo(xs - 34, 88, 68, 50, preench="#fff")
        d.texto(xs, 110, "B1", tam=12, ancora="middle", negrito=True)
        d.texto(xs, 126, tipo, tam=11, ancora="middle")
    with d.grupo("~BN"):
        d.linha([(xs - 20, 30), (xs - 20, 88)])
        d.texto(xs - 24, 70, "BN", tam=10, ancora="end")
    with d.grupo("~BU"):
        d.linha([(xs - 20, 138), (xs - 20, 200)])
        d.texto(xs - 24, 170, "BU", tam=10, ancora="end")
    d.no(xs - 20, 30); d.no(xs - 20, 200)
    if tipo == "NPN":
        with d.grupo("~BK"):
            d.linha([(xs + 20, 138), (xs + 20, 160), (xk, 160), (xk, 108)])
            d.texto(xs + 24, 154, "BK", tam=10)
        d.fio((xk, 30), (xk, 68), net="pk")
        d.no(xk, 30)
        d.bobina(xk, 68, id="K1.A1", tag="K1", nome="bobina de K1 (carga)")
    else:
        with d.grupo("~BK"):
            d.linha([(xs + 20, 138), (xs + 20, 146), (xk, 146), (xk, 152)])
            d.texto(xs + 24, 144, "BK", tam=10)
        d.bobina(xk, 152, id="K1.A1", tag="K1", nome="bobina de K1 (carga)")
        d.fio((xk, 192), (xk, 200), net="nk")
        d.no(xk, 200)
    return d


circuito("sensor-npn")(lambda: _sensor3("NPN"))
circuito("sensor-pnp")(lambda: _sensor3("PNP"))


# ---- Inversor de frequência: blocos (Franchi 6.3-6.4) -------------------------------

@circuito("inversor-blocos")
def inversor_blocos():
    d = Desenho(320, 250, alt="Diagrama de blocos de um inversor de frequência: a rede trifásica de 60 Hz "
                "entra no retificador; dele sai tensão contínua para o barramento CC (com capacitor de filtro); "
                "o bloco inversor com IGBTs, comandado pela CPU, gera tensão alternada de frequência variável "
                "para o motor.")
    d.texto(20, 40, "Rede 3~", tam=11)
    d.texto(20, 54, "60 Hz", tam=11)
    d.fio((28, 64), (28, 80), (40, 80))
    d.bloco(40, 60, 70, 40, ["Retificador"], id="RET", nome="retificador")
    d.fio((110, 80), (130, 80))
    d.bloco(130, 60, 70, 40, ["Barramento", "CC"], id="CC", nome="barramento CC")
    d.fio((200, 80), (220, 80))
    d.bloco(220, 60, 70, 40, ["Inversor", "(IGBTs)"], id="INV", nome="bloco inversor com IGBTs")
    d.fio((255, 100), (255, 140))
    yc, r = d.motor3((240, 255, 270), 140, id="M", tag=None, nome="motor")
    d.bloco(130, 170, 70, 40, ["CPU"], id="CPU", nome="CPU (controle)")
    with d.grupo("~pulsos"):
        d.linha([(200, 190), (225, 190), (225, 100)], tracejado="4,3")
    d.texto(165, 232, "IHM / entradas", tam=10, ancora="middle")
    return d


# ---- Soft-starter com contator de bypass (Franchi 6.2.3) ----------------------------

@circuito("softstarter-bypass")
def softstarter_bypass():
    d = Desenho(300, 360, alt="Soft-starter ligada com contator de bypass: L1, L2 e L3 passam pelos fusíveis F1 "
                "e pelo contator K1 até a soft-starter (bloco de SCRs) e daí ao motor. O contator K2 fica em "
                "paralelo com a soft-starter, ligando a entrada direto à saída.")
    xs = (100, 130, 160)
    for y, f in zip((30, 46, 62), ("L1", "L2", "L3")):
        d.barramento(y, 60, 280, f)
    for x, y, f in zip(xs, (30, 46, 62), ("L1", "L2", "L3")):
        d.fio((x, y), (x, 76), net=f)
        d.no(x, y, net=f)
    d.tripolar(xs, 76, "fusivel", "F1", tag="F1", bornes=None, nome="fusível F1")
    d.tripolar(xs, 124, "contato", "K1", tag="K1", nome="polo de K1")
    for x in xs:
        d.fio((x, 116), (x, 124))
    # derivação para o bypass
    xb = (200, 220, 240)
    for x, xx, y in zip(xs, xb, (172, 178, 184)):
        d.fio((x, 164), (x, 196))
        d.fio((x, y), (xx, y), (xx, 196))
        d.no(x, y)
    d.bloco(80, 196, 100, 44, ["Soft-starter", "(SCRs)"], id="SS", nome="soft-starter")
    d.tripolar(xb, 196, "contato", "K2", tag=None, nome="polo de K2")
    with d.grupo("K2.tag"):
        d.texto(xb[-1] + 16, 220, "K2", negrito=True)
    for x, xx, y in zip(xs, xb, (256, 262, 268)):
        d.fio((x, 240), (x, 280))
        d.fio((xx, 236), (xx, y), (x, y))
        d.no(x, y)
    d.motor3(xs, 280, tag="M1")
    return d


vista(M, "dahlander-forca", "dahl-forca")
vista(M, "dahlander-forca-k3", "dahl-forca", destaque=["K3"])
vista(M, "rotorica-forca", "rotorica-forca")
vista(M, "rotorica-forca-k13", "rotorica-forca", destaque=["K13"])
vista(M, "sensor-npn", "sensor-npn")
vista(M, "sensor-pnp", "sensor-pnp")
vista(M, "inversor-blocos-ret", "inversor-blocos", destaque=["RET"])
vista(M, "inversor-blocos-cc", "inversor-blocos", destaque=["CC"])
vista(M, "inversor-blocos-inv", "inversor-blocos", destaque=["INV"])
vista(M, "softstarter-bypass-k2", "softstarter-bypass", destaque=["K2"])
