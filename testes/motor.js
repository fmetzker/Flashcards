/* Carga do app e as duas telas que derivam do motor: ordem de exibição
   (CLAUDE.md, "Ordem de aprendizado") e baldes de revisão pendente
   (CLAUDE.md, "Motor de repetição espaçada"). */
module.exports = function (APP, t) {

  t.grupo('carga');

  t.teste('o app inteiro roda fora do navegador, com o banco real', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(APP.CONCURSOS.length >= 4, 'concursos.json devia ter carregado');
    t.ok(APP.BANCO.length > 1000, 'o banco real devia ter carregado');
    t.ok(APP.BLOCOS_META.length > 0, 'a meta devia ter sido montada');
  });

  t.teste('materiasInscritas é a união dos concursos mais as avulsas', async () => {
    await APP.montar({ concursos: ['caaq-cdm'], avulsas: ['biologia-celular'] });
    const m = APP.materiasInscritas();
    t.ok(m.includes('portugues') && m.includes('matematica'), 'faltou matéria do concurso');
    t.ok(m.includes('biologia-celular'), 'faltou a avulsa');
    t.igual(m.length, new Set(m).size, 'matéria repetida na união');
  });

  t.grupo('ordem de exibição');

  t.teste('tópico é listado na ordem em que a escada o libera', async () => {
    /* "A tela sempre lista tópico e subtópico na ordem em que a escada os
       libera, de cima pra baixo — nunca por tamanho, alfabeto ou ordem do
       banco." A profundidade nunca pode decrescer descendo a lista. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const resumo = APP.resumoDoBanco();
    for (const mid of Object.keys(resumo)) {
      const memo = {};
      const nomes = APP.porDesbloqueio(mid, resumo[mid].topicos);
      const prof = nomes.map(tt => APP.profundidadeTopico(mid, tt, memo));
      for (let i = 1; i < prof.length; i++) {
        t.ok(prof[i] >= prof[i - 1],
          `${mid}: "${nomes[i]}" (nível ${prof[i]}) veio depois de "${nomes[i - 1]}" (nível ${prof[i - 1]})`);
      }
    }
  });

  t.teste('tópico raiz aparece antes de quem depende dele', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const resumo = APP.resumoDoBanco();
    const ordem = APP.porDesbloqueio('matematica', resumo['matematica'].topicos);
    t.ok(ordem.indexOf('Aritmética') < ordem.indexOf('Álgebra'), 'Aritmética antes de Álgebra');
    t.ok(ordem.indexOf('Álgebra') < ordem.indexOf('Funções'), 'Álgebra antes de Funções');
  });

  t.teste('subtópico também sai em ordem de desbloqueio', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const resumo = APP.resumoDoBanco();
    const dt = resumo['matematica'].topicos['Aritmética'];
    t.ok(dt && dt.subs, 'Aritmética devia ter subtópicos no resumo');
    const memo = {};
    const nomes = APP.porDesbloqueioSub('matematica', 'Aritmética', dt.subs);
    const prof = nomes.map(s => APP.profundidadeSubtopico('matematica', 'Aritmética', s, memo));
    for (let i = 1; i < prof.length; i++) {
      t.ok(prof[i] >= prof[i - 1],
        `"${nomes[i]}" (nível ${prof[i]}) veio depois de "${nomes[i - 1]}" (nível ${prof[i - 1]})`);
    }
    t.igual(nomes[0], 'Multiplicação', 'a raiz da escada tem que vir primeiro');
  });

  t.teste('matéria sem grafo declarado não quebra a ordenação', async () => {
    /* "Matéria/tópico sem grafo cai toda na profundidade 0" */
    await APP.montar({ materias: ['biologia-celular'] });
    const resumo = APP.resumoDoBanco();
    const d = resumo['biologia-celular'];
    if (!d) return;
    const nomes = APP.porDesbloqueio('biologia-celular', d.topicos);
    t.igual(nomes.length, Object.keys(d.topicos).length, 'a ordenação perdeu tópico');
  });

  t.grupo('revisões pendentes');

  t.teste('os baldes são exclusivos e somam o total', async () => {
    /* Atrasadas, Hoje, Amanhã, 2-7, 8-30, 31-120: as fronteiras são os
       próprios INTERVALOS do Leitner, e cada cartão entra em um só balde. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const amostra = APP.BANCO.slice(0, 60);
    const distancias = [-9, -1, 0, 1, 3, 6, 12, 29, 45, 119];
    amostra.forEach((q, i) => {
      APP.E.cartoes[q.id] = {
        caixa: 3, acertos: 1, erros: 0,
        prox: APP.somarDias(hoje, distancias[i % distancias.length]),
      };
    });
    const baldes = APP.revisoesPorDia();
    const soma = baldes.reduce((s, b) => s + b.n, 0);
    t.igual(soma, amostra.length, 'os baldes não somam o total de cartões vistos');
    t.igual(baldes.map(b => b.rotulo),
      ['Atrasadas', 'Hoje', 'Amanhã', 'Em 2 a 7 dias', 'Em 8 a 30 dias', 'Em 31 a 120 dias'],
      'as fronteiras dos baldes são os INTERVALOS do Leitner e não devem mudar');
  });

  t.teste('conta a data real de vencimento, não a caixa nominal', async () => {
    /* "perto da prova o teto dinâmico comprime intervalos que seriam
       maiores, e os baldes devem refletir essa pressão de verdade" */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const q = APP.BANCO[0];
    /* caixa 8 (nominalmente 120 dias) mas vencendo amanhã */
    APP.E.cartoes = { [q.id]: { caixa: 8, acertos: 9, erros: 0, prox: APP.somarDias(hoje, 1) } };
    const baldes = APP.revisoesPorDia();
    const soma = baldes.reduce((s, b) => s + b.n, 0);
    t.igual(soma, 1, 'o cartão tem que estar em exatamente um balde');
    const achado = baldes.find(b => b.n === 1);
    t.igual(achado.rotulo, 'Amanhã', 'a caixa 8 comprimida tem que cair em "Amanhã"');
  });
};
