/* Resumo de estudo antes do primeiro cartão novo — CLAUDE.md, seção
   "Resumos de estudo". Os resumos do teste são fabricados aqui e apagados no
   fim: o teste cobra a conduta do motor, não o conteúdo de nenhuma matéria. */
module.exports = function (APP, t) {

  t.grupo('resumos — quando o texto aparece');

  t.teste('aparece antes do 1º cartão novo, o do tópico antes do subtópico, e só uma vez', async () => {
    const c = APP.CONCURSOS.find(x => x.blocos.length);
    await APP.montar({ concursos: [c.id] });
    const q = APP.BANCO.find(x => x.s);
    t.ok(q, 'precisava de um cartão com subtópico no banco');
    if (!q) return;
    const kT = APP.chaveResumo(q.m, q.t), kS = APP.chaveResumo(q.m, q.t, q.s);
    const antes = { t: APP.RESUMOS[kT], s: APP.RESUMOS[kS] };
    const lidosAntes = APP.E.resumosLidos;
    try {
      APP.RESUMOS[kT] = { m: q.m, t: q.t, texto: ['x'], fontes: ['y'] };
      APP.RESUMOS[kS] = { m: q.m, t: q.t, s: q.s, texto: ['x'], fontes: ['y'] };
      APP.E.resumosLidos = {};
      APP.E.cartoes = {};
      t.igual(APP.resumoPendente(q), kT, 'primeiro vem o resumo do tópico (o mapa)');
      APP.E.resumosLidos[kT] = '2026-01-01';
      t.igual(APP.resumoPendente(q), kS, 'depois o do subtópico (o detalhe)');
      APP.E.resumosLidos[kS] = '2026-01-01';
      t.igual(APP.resumoPendente(q), null, 'lido uma vez, não aparece de novo');

      APP.E.resumosLidos = {};
      APP.E.cartoes = { [q.id]: { caixa: 1, prox: '2026-01-01', acertos: 0, erros: 1 } };
      t.igual(APP.resumoPendente(q), null, 'revisão nunca abre resumo: o assunto já foi visto');

      APP.E.cartoes = {};
      delete APP.RESUMOS[kT]; delete APP.RESUMOS[kS];
      t.igual(APP.resumoPendente(q), null, 'trecho sem resumo segue direto para o cartão');
    } finally {
      if (antes.t) APP.RESUMOS[kT] = antes.t; else delete APP.RESUMOS[kT];
      if (antes.s) APP.RESUMOS[kS] = antes.s; else delete APP.RESUMOS[kS];
      APP.E.resumosLidos = lidosAntes;
    }
  });
};
