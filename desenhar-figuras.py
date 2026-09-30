# -*- coding: utf-8 -*-
"""Gera as figuras dos cartões (banco/img/<matéria>/*.svg) a partir de figuras/*.py.

    python desenhar-figuras.py              grava todas as figuras
    python desenhar-figuras.py --conferir   só confere; sai com 1 se alguma
                                            figura em disco difere do código
    python desenhar-figuras.py --alt [filtro]  imprime o 'alt' sugerido de cada
                                            figura, para colar no cartão

A figura é CÓDIGO, não desenho à mão: cada circuito é desenhado uma vez em
figuras/*.py (@circuito) e cada figura de cartão é uma linha vista() sobre
ele — destaque, recorte, caminho energizado, pontos de medição. Assim as
centenas de diagramas saem com o mesmo símbolo, a mesma numeração de
terminal e a mesma cor, e corrigir um símbolo corrige todas as figuras.

Não escreve em banco/*.json (regra 9 do CLAUDE.md): quem liga a figura ao
cartão é o campo 'img', gravado pelos três scripts de sempre. O validar.py
roda o --conferir, para o SVG em disco nunca divergir do código que o gera.
"""
import glob, importlib.util, os, sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, RAIZ)
import desenho  # noqa: E402


def carregar():
    for caminho in sorted(glob.glob(os.path.join(RAIZ, "figuras", "*.py"))):
        nome = "figuras_" + os.path.splitext(os.path.basename(caminho))[0]
        spec = importlib.util.spec_from_file_location(nome, caminho)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    return desenho.FIGURAS


def gerar():
    """{caminho relativo a banco/: conteúdo SVG}"""
    return {chave: fn() for chave, fn in sorted(carregar().items())}


def main():
    if "--alt" in sys.argv:
        carregar()
        filtro = sys.argv[-1] if sys.argv[-1] != "--alt" else ""
        for chave in sorted(desenho.ALTS):
            if filtro in chave:
                print(chave)
                print("  " + desenho.ALTS[chave]() + "\n")
        return
    conferir = "--conferir" in sys.argv
    divergentes = []
    for chave, svg in gerar().items():
        destino = os.path.join(RAIZ, "banco", *chave.split("/"))
        # newline="" + replace: o git troca LF por CRLF no checkout do Windows,
        # e isso não é divergência de desenho
        atual = None
        if os.path.exists(destino):
            with open(destino, encoding="utf-8", newline="") as f:
                atual = f.read().replace("\r\n", "\n")
        if atual == svg:
            continue
        if conferir:
            divergentes.append(chave)
            continue
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        with open(destino, "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)
        print(("atualizada " if atual is not None else "criada    ") + "banco/" + chave)
    if conferir and divergentes:
        for c in divergentes:
            print(f"banco/{c} difere do que figuras/ gera — rode: python desenhar-figuras.py")
        sys.exit(1)


if __name__ == "__main__":
    main()
