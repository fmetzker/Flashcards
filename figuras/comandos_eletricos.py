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
vista(M, "reversao-forca", "rev-forca")
vista(M, "reversao-forca-k20", "rev-forca", destaque=["K20"])
