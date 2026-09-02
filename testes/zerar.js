/* Redefinir progresso por matéria — Trilha C do plano (variante simples,
   só local, sem marco no servidor). Ver o comentário de zerarMateria() em
   index.html. */
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
};
