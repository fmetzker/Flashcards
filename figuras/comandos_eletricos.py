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
