/* Redefinir progresso por matéria — apaga o progresso local E carimba um
   marco por matéria (E.materiasZeradas -> perfis.materias_zeradas), que é o
   que mantém o Painel de desempenho de acordo com a tela Estatísticas. Ver
   o comentário de zerarMateria() em index.html e o §2.4 do schema.sql. */
module.exports = function (APP, t) {

  t.grupo('zerar progresso de uma matéria');

  t.teste('remove só os cartões da matéria escolhida', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const dePortugues = APP.BANCO.filter(q => q.m === 'portugues').slice(0, 3);
    const deMatematica = APP.BANCO.filter(q => q.m === 'matematica').slice(0, 3);
    t.ok(dePortugues.length === 3 && deMatematica.length === 3, 'preciso de cartões das duas matérias');
    [...dePortugues, ...deMatematica].forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: APP.hoje() };
    });
    APP.__ctx.confirm = () => true;
    APP.zerarMateria('portugues');
    dePortugues.forEach(q => t.ok(!(q.id in APP.E.cartoes), `${q.id} (português) devia ter sumido`));
    deMatematica.forEach(q => t.ok(q.id in APP.E.cartoes, `${q.id} (matemática) não devia ter mexido`));
  });

  t.teste('sem confirmação, não apaga nada', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const q = APP.BANCO.find(x => x.m === 'portugues');
    APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: APP.hoje() };
    APP.__ctx.confirm = () => false;
    APP.zerarMateria('portugues');
    t.ok(q.id in APP.E.cartoes, 'sem confirmar, o cartão não podia ter sumido');
  });

  t.teste('sem matéria escolhida (vazio ou nulo), não faz nada', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const q = APP.BANCO.find(x => x.m === 'portugues');
    APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: APP.hoje() };
    APP.__ctx.confirm = () => true;
    APP.zerarMateria('');
    APP.zerarMateria(null);
    t.ok(q.id in APP.E.cartoes, 'sem matéria escolhida, nada devia ter mexido');
  });

  t.teste('não mexe em E.dias/E.diasTotal/E.diasCertas nem em diasMateria de dias passados', async () => {
    /* Sequência de estudo e "quanto você estudou" precisam sobreviver ao
       reset de uma matéria — só o que a pessoa SABE reinicia. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const ontem = APP.somarDias(APP.hoje(), -1);
    APP.E.dias[ontem] = 12;
    APP.E.diasTotal[ontem] = 12;
    APP.E.diasCertas[ontem] = 9;
    APP.E.diasMateria[ontem] = { portugues: 5, matematica: 7 };
    const q = APP.BANCO.find(x => x.m === 'portugues');
    APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: APP.hoje() };
    APP.__ctx.confirm = () => true;
    APP.zerarMateria('portugues');
    t.igual(APP.E.dias[ontem], 12);
    t.igual(APP.E.diasTotal[ontem], 12);
    t.igual(APP.E.diasCertas[ontem], 9);
    t.igual(APP.E.diasMateria[ontem], { portugues: 5, matematica: 7 });
  });

  t.grupo('marco por matéria — o que mantém o Painel de acordo com Estatísticas');

  t.teste('carimba E.materiasZeradas SÓ da matéria zerada', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.E.materiasZeradas = {};
    const q = APP.BANCO.find(x => x.m === 'portugues');
    APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: APP.hoje() };
    const antes = Date.now();
    APP.__ctx.confirm = () => true;
    APP.zerarMateria('portugues');
    const marco = APP.E.materiasZeradas.portugues;
    t.ok(marco, 'devia ter carimbado a matéria zerada');
    const t0 = Date.parse(marco);
    t.ok(!isNaN(t0) && t0 >= antes, 'o marco tinha que ser um instante válido e de agora: ' + marco);
    t.igual(APP.E.materiasZeradas.matematica, undefined, 'não podia carimbar matéria que não foi zerada');
  });

  t.teste('sem confirmação, não carimba nada', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.E.materiasZeradas = {};
    APP.__ctx.confirm = () => false;
    APP.zerarMateria('portugues');
    t.igual(APP.E.materiasZeradas, {}, 'cancelar não podia deixar marco pra trás');
  });

  t.teste('zerar a mesma matéria de novo avança o marco', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.__ctx.confirm = () => true;
    APP.E.materiasZeradas = { portugues: '2020-01-01T00:00:00.000Z' };
    APP.zerarMateria('portugues');
    t.ok(Date.parse(APP.E.materiasZeradas.portugues) > Date.parse('2020-01-01T00:00:00.000Z'),
      'o marco tinha que avançar para o instante novo');
  });

  t.teste('zerar duas matérias guarda os dois marcos', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.__ctx.confirm = () => true;
    APP.E.materiasZeradas = {};
    APP.zerarMateria('portugues');
    APP.zerarMateria('matematica');
    t.ok(APP.E.materiasZeradas.portugues, 'perdeu o marco da primeira matéria zerada');
    t.ok(APP.E.materiasZeradas.matematica, 'perdeu o marco da segunda matéria zerada');
  });
};
