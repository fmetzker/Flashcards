#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Mede o banco contra o padrão de METODOLOGIA.md.

Uso:  python3 auditar-banco.py            # relatório resumido
      python3 auditar-banco.py --listar    # + os ids de cada problema
      python3 auditar-banco.py --csv saida.csv

Diferente do validar.py, este script NÃO reprova nada e não sai com código de
erro: ele mede qualidade, que é gradiente, não regra. A saída serve para
decidir o que reescrever primeiro — não para barrar publicação.

O que dá para medir automaticamente é um subconjunto do padrão. Julgamento
sobre plausibilidade de distrator e sobre a explicação ensinar de verdade
continua sendo humano; o que este script faz é achar os casos onde a suspeita
é objetiva o bastante para valer revisão.
"""
import json, os, re, sys, csv, collections

RAIZ = os.path.dirname(os.path.abspath(__file__))
BANCO_DIR = os.path.join(RAIZ, 'banco')
CONCURSOS = os.path.join(RAIZ, 'concursos.json')

# ---------------------------------------------------------------- carregar

def carrega():
    materias = json.load(open(os.path.join(BANCO_DIR, 'materias.json'), encoding='utf-8'))
    nomes = {m['id']: m['nome'] for m in materias}
    B = []
    for m in materias:
        caminho = os.path.join(BANCO_DIR, m['id'] + '.json')
        if os.path.exists(caminho):
            B.extend(json.load(open(caminho, encoding='utf-8')))
    return B, nomes


# ------------------------------------------------------------- verificações
# Cada função devolve uma string com o motivo, ou None se a questão passa.

def sem_pergunta_real(q):
    """1.1 — recordação ativa: o enunciado precisa ser respondível sozinho.

    Enunciado que só diz "assinale a correta sobre X" transfere a pergunta
    inteira para as alternativas, e aí o que se mede é reconhecimento."""
    e = q['q'].strip().lower()
    vagos = [
        r'assinale a (alternativa )?(correta|incorreta|verdadeira|falsa)\s*[.:]?$',
        r'^sobre .{0,60},? (assinale|marque|indique)',
        r'(é|está) correto afirmar( que)?\s*[.:]?$',
        r'^(considere|analise) as (afirmativas|assertivas|proposições)',
    ]
    for p in vagos:
        if re.search(p, e):
            return 'enunciado não é pergunta respondível sem as alternativas'
    return None


def alternativa_lixo(q):
    """2 — "todas as anteriores" e combinatórias tipo "apenas I e III"."""
    ruins = []
    for a in q['o']:
        al = a.strip().lower()
        if re.search(r'(todas|nenhuma) (as|das) (anteriores|alternativas|afirmativas)', al):
            ruins.append(a)
        elif re.match(r'^(apenas|somente)\s+([ivx]+|\d)(\s*(,|e)\s*([ivx]+|\d))*\.?$', al):
            ruins.append(a)
    if ruins:
        return 'alternativa de formato proibido: ' + ' | '.join(ruins[:2])
    return None


def enunciado_longo(q):
    """1.2 — um fato por cartão.

    Comprimento não prova que há vários fatos, mas é o melhor indício
    automático: enunciado muito longo quase sempre empilha contexto que
    poderia virar cartões separados. Limiar alto de propósito, para sinalizar
    só os casos gritantes."""
    n = len(q['q'])
    if n > 400:
        return f'enunciado com {n} caracteres (provável mais de um fato)'
    return None


def negativa(q):
    """2 — "assinale a INCORRETA". Não é erro, é custo: só vale quando a
    própria banca cobra assim. Listado para revisão, não como defeito."""
    if re.search(r'\b(incorret|excet|não\s+(é|são|deve|corresponde|faz)|falsa)\w*\b', q['q'], re.I):
        return 'enunciado por negativa'
    return None


def explicacao_fraca(q):
    """1.4 — a explicação precisa dizer POR QUE."""
    e = q['e'].strip()
    if len(e) < 40:
        return f'explicação com {len(e)} caracteres (curta demais para ensinar)'
    if re.search(r'^(a )?(alternativa|opção|letra)\s+[a-e]\b', e, re.I):
        return 'explicação só aponta a letra, não explica'
    return None


def distrator_curto(q):
    """1.3 — distrator plausível.

    Distrator drasticamente mais curto que a correta costuma ser preenchimento
    ("Nunca", "Apenas X"), que ninguém marcaria por engano de verdade."""
    correta = len(q['o'][q['c']])
    curtos = [a for i, a in enumerate(q['o']) if i != q['c'] and len(a) * 3 < correta and len(a) < 25]
    if curtos:
        return 'distrator curto demais para ser plausível: ' + ' | '.join(curtos[:2])
    return None


VERIFICACOES = [
    ('sem-pergunta',      sem_pergunta_real,  'ALTO'),
    ('alternativa-lixo',  alternativa_lixo,   'ALTO'),
    ('explicacao-fraca',  explicacao_fraca,   'ALTO'),
    ('distrator-curto',   distrator_curto,    'MÉDIO'),
    ('enunciado-longo',   enunciado_longo,    'MÉDIO'),
    ('negativa',          negativa,           'BAIXO'),
]


# ------------------------------------------------------------------ relatório

def cobertura(B, nomes):
    """3.3 — quantos cartões por tópico, do menor para o maior."""
    por = collections.Counter((q['m'], q['t']) for q in B)
    return sorted(por.items(), key=lambda x: x[1])


def main():
    listar = '--listar' in sys.argv
    csv_saida = None
    if '--csv' in sys.argv:
        csv_saida = sys.argv[sys.argv.index('--csv') + 1]

    B, nomes = carrega()
    achados = []   # (id, materia, topico, chave, gravidade, motivo)
    for q in B:
        for chave, fn, grav in VERIFICACOES:
            motivo = fn(q)
            if motivo:
                achados.append((q['id'], q['m'], q.get('t', ''), chave, grav, motivo))

    print(f"Banco: {len(B)} questões\n")
    print("=" * 66)
    print("ADERÊNCIA AO PADRÃO (METODOLOGIA.md)")
    print("=" * 66)

    por_chave = collections.Counter(a[3] for a in achados)
    for chave, _, grav in VERIFICACOES:
        n = por_chave.get(chave, 0)
        pct = n / len(B) * 100
        print(f"  [{grav:5}] {chave:18} {n:4} questões ({pct:.1f}%)")

    afetadas = len({a[0] for a in achados})
    print(f"\n  questões com ao menos um apontamento: {afetadas} de {len(B)} "
          f"({afetadas/len(B)*100:.1f}%)")
    limpas = len(B) - afetadas
    print(f"  questões sem nenhum apontamento:      {limpas} ({limpas/len(B)*100:.1f}%)")

    print("\n  por matéria:")
    por_mat = collections.Counter(a[1] for a in achados if a[4] == 'ALTO')
    total_mat = collections.Counter(q['m'] for q in B)
    for m in total_mat:
        n = por_mat.get(m, 0)
        print(f"    {nomes.get(m, m):42} {n:4} de gravidade ALTA de {total_mat[m]}")

    print("\n" + "=" * 66)
    print("COBERTURA — os 12 tópicos com menos cartões")
    print("=" * 66)
    for (m, t), n in cobertura(B, nomes)[:12]:
        print(f"  {n:4}  {nomes.get(m, m)[:28]:28}  {t}")

    if listar:
        print("\n" + "=" * 66)
        print("APONTAMENTOS (gravidade ALTA)")
        print("=" * 66)
        for a in sorted(achados, key=lambda x: (x[1], x[2])):
            if a[4] == 'ALTO':
                print(f"  [{a[0]}] {a[1]}/{a[2]}\n        {a[3]}: {a[5][:110]}")

    if csv_saida:
        with open(csv_saida, 'w', newline='', encoding='utf-8-sig') as f:
            w = csv.writer(f)
            w.writerow(['id', 'materia', 'topico', 'verificacao', 'gravidade', 'motivo'])
            w.writerows(achados)
        print(f"\nCSV gravado em {csv_saida} ({len(achados)} linhas)")

    print("\nEste script mede, não reprova. Ver METODOLOGIA.md para o padrão.")


if __name__ == '__main__':
    main()
