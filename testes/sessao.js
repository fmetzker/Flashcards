/* Sessão de estudo — CLAUDE.md, "Motor de repetição espaçada" e
   "Meta e progresso do dia". Inclui a sessão contínua (agosto/2026). */
module.exports = function (APP, t) {

  const materiaDe = id => APP.porId[id].m;

  t.grupo('montagem da sessão');

  t.teste('a sessão respeita a cota de cada bloco', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const lote = APP.montarLoteSessao('normal', null, new Set());
    for (const b of APP.BLOCOS_META) {
      const daArea = lote.filter(id => b.materias.includes(materiaDe(id)));
      t.ok(daArea.length <= b.questoes,
        `${b.nome}: ${daArea.length} cartões para uma cota de ${b.questoes}`);
    }
  });

  t.teste('a sessão cobre TODOS os blocos, não só o do foco', async () => {
    /* "quem seguia dois concursos nunca recebia a matéria exclusiva do
       outro; agora a sessão cobre tudo que a meta cobra" */
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    const lote = APP.montarLoteSessao('normal', null, new Set());
    const materias = new Set(lote.map(materiaDe));
    t.ok(materias.has('matematica'), 'Matemática (só do CAAQ) devia aparecer');
    t.ok(materias.has('enfermagem'), 'Enfermagem (só do VR) devia aparecer');
  });

  t.teste('a sessão nunca repete cartão', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.igual(lote.length, new Set(lote).size, 'cartão repetido no mesmo lote');
  });

  t.teste('o excluir é respeitado — reabastecer não repete o que já saiu', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const primeiro = APP.montarLoteSessao('normal', null, new Set());
    t.ok(primeiro.length > 0, 'o primeiro lote não podia vir vazio');
    const segundo = APP.montarLoteSessao('normal', null, new Set(primeiro));
    const repetidos = segundo.filter(id => primeiro.includes(id));
    t.igual(repetidos, [], 'o reabastecimento devolveu cartão que já tinha saído');
  });

  t.teste('só entra cartão do escopo de tópicos do bloco', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const lote = APP.montarLoteSessao('normal', null, new Set());
    for (const id of lote) {
      const q = APP.porId[id];
      const b = APP.BLOCOS_META.find(x => x.materias.includes(q.m));
      if (b && b.topicos) {
        t.ok(b.topicos.includes(q.t), `"${q.t}" está fora do escopo de ${b.nome}`);
      }
    }
  });

  t.grupo('sessão contínua — sem adiantamento');

  t.teste('nada vencido e nada novo: o lote vem VAZIO, não adiantado', async () => {
    /* Decisão de agosto/2026: o adiantamento de revisão foi removido. Com a
       sessão contínua, faltar cartão numa matéria deixou de ser problema —
       e estudar antes da hora só enfraquece o espaçamento. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.BANCO.forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 5, acertos: 3, erros: 0, prox: '2099-01-01' };
    });
    APP.limparCacheGrau();
    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.igual(lote, [], 'não pode puxar cartão que ainda não venceu');
  });

  t.teste('o mesmo vale no modo filtro (estudar um tópico isolado)', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.BANCO.forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 5, acertos: 3, erros: 0, prox: '2099-01-01' };
    });
    APP.limparCacheGrau();
    const lote = APP.montarLoteSessao('filtro', { m: 'matematica', t: 'Aritmética' }, new Set());
    t.igual(lote, [], 'o modo filtro também não pode adiantar');
  });

  t.teste('revisão vencida de tópico fechado sustenta a sessão sozinha', async () => {
    /* O cenário que motivou a sessão contínua: errou um cartão antigo, o
       tópico avançado fechou, e não há cartão novo disponível. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    /* tudo visto e longe de vencer... */
    APP.BANCO.forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 5, acertos: 3, erros: 0, prox: '2099-01-01' };
    });
    /* ...menos a base de Aritmética, que a pessoa acabou de errar */
    const base = APP.BANCO.filter(q => q.m === 'matematica' && q.t === 'Aritmética'
      && APP.grauDe(q) === 1);
    base.forEach(q => { APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 2, prox: hoje }; });
    APP.limparCacheGrau();
    APP.aplicarFoco(null);

    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.ok(lote.length > 0, 'a sessão não podia ficar vazia — há revisão vencida de sobra');
    for (const id of lote) {
      t.ok(APP.E.cartoes[id].prox <= hoje, 'entrou cartão que ainda não venceu');
    }
  });

  t.grupo('modo filtro');

  t.teste('estudar um tópico não é atalho para pular a escada', async () => {
    /* "estudar um tópico pela tela Matérias não pode ser um atalho para
       pular o degrau de baixo" */
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(!APP.topicoAberto('matematica', 'Funções'));
    const lote = APP.montarLoteSessao('filtro', { m: 'matematica', t: 'Funções' }, new Set());
    const novos = lote.filter(id => !APP.E.cartoes[id]);
    t.igual(novos, [], 'o modo filtro deixou passar cartão novo de tópico fechado');
  });

  t.teste('o filtro respeita matéria, tópico e subtópico', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const lote = APP.montarLoteSessao('filtro',
      { m: 'matematica', t: 'Aritmética', s: 'Multiplicação' }, new Set());
    t.ok(lote.length > 0, 'Multiplicação está aberta, devia render cartões');
    for (const id of lote) {
      const q = APP.porId[id];
      t.igual([q.m, q.t, q.s], ['matematica', 'Aritmética', 'Multiplicação']);
    }
  });

  t.grupo('repetição do cartão errado');

  function sessaoFalsa(modo) {
    return { lista: [], pos: 0, respondida: false, modo, filtro: null,
      metasAnunciadas: new Set(), todasAnunciada: false, pendentes: [] };
  }

  t.teste('acertar não agenda repetição', () => {
    APP.S = sessaoFalsa('normal');
    APP.agendarRepeticao('abc', 'sabia');
    t.igual(APP.S.pendentes, []);
  });

  t.teste('errar e chutar agendam repetição', () => {
    for (const r of ['errei', 'chutei']) {
      APP.S = sessaoFalsa('normal');
      APP.agendarRepeticao('abc', r);
      t.igual(APP.S.pendentes.length, 1, `"${r}" devia agendar`);
      t.igual(APP.S.pendentes[0].id, 'abc');
    }
  });

  t.teste('a repetição cai entre 5 e 10 cartões à frente', () => {
    for (let i = 0; i < 200; i++) {
      APP.S = sessaoFalsa('normal');
      APP.S.pos = 12;
      APP.agendarRepeticao('abc', 'errei');
      const d = APP.S.pendentes[0].apareceEm - 12;
      t.ok(d >= 5 && d <= 10, `distância fora da faixa: ${d}`);
    }
  });

  t.teste('o modo erros não duplica a repetição', () => {
    /* esse modo JÁ é a revisão do que foi errado */
    APP.S = sessaoFalsa('erros');
    APP.agendarRepeticao('abc', 'errei');
    t.igual(APP.S.pendentes, []);
  });

  t.teste('sem sessão aberta, agendar não quebra', () => {
    APP.S = null;
    APP.agendarRepeticao('abc', 'errei');   // não pode lançar
    t.ok(true);
  });
};
