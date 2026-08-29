/* Meta do dia — CLAUDE.md, seção "Meta e progresso do dia". */
module.exports = function (APP, t) {

  const bloco = (m) => APP.BLOCOS_META.find(b => b.materias.includes(m));

  t.grupo('meta — matéria repetida');

  t.teste('matéria em dois concursos não soma: vale a MAIOR cota', async () => {
    /* Português cai nos quatro concursos; somar daria 40/dia da mesma
       matéria. Estudar 10 de Português serve para as quatro provas. */
    await APP.montar({ concursos: ['vr-enf-2026'] });
    const soA = bloco('portugues').novos;

    await APP.montar({ concursos: ['caaq-cdm'] });
    const soB = bloco('portugues').novos;

    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    const juntos = bloco('portugues').novos;

    t.igual(juntos, Math.max(soA, soB), `${soA} e ${soB} deviam virar ${Math.max(soA, soB)}, veio ${juntos}`);
    t.ok(juntos < soA + soB || soA === 0 || soB === 0, 'não pode somar as duas cotas');
  });

  t.teste('cada matéria aparece uma única vez em BLOCOS_META', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm', 'transpetro-mec'] });
    const vistas = [];
    for (const b of APP.BLOCOS_META) vistas.push(...b.materias);
    t.igual(vistas.length, new Set(vistas).size, 'matéria repetida em dois blocos da meta');
  });

  t.grupo('meta — escopo de tópicos');

  t.teste('escopo de tópicos é UNIÃO, não o do bloco vencedor', async () => {
    /* "se um concurso restringe e outro não, quem segue os dois estuda a
       matéria inteira" — união é o que garante não estudar de menos. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const restrito = bloco('portugues').topicos;
    t.ok(Array.isArray(restrito) && restrito.length > 0, 'transpetro-mec devia restringir Português');

    await APP.montar({ concursos: ['vr-enf-2026'] });
    const solto = bloco('portugues').topicos;

    await APP.montar({ concursos: ['transpetro-mec', 'vr-enf-2026'] });
    const uniao = bloco('portugues').topicos;

    if (solto === null) {
      t.igual(uniao, null, 'um bloco sem escopo abre a matéria inteira — a união tem que ser tudo');
    } else {
      for (const tt of restrito) t.ok(uniao.includes(tt), `união perdeu "${tt}"`);
      for (const tt of solto) t.ok(uniao.includes(tt), `união perdeu "${tt}"`);
    }
  });

  t.teste('todo tópico declarado no escopo existe no banco', async () => {
    /* "tópico com grafia errada some silenciosamente da sessão, que é pior
       que um erro" */
    await APP.montar({ concursos: APP.CONCURSOS.map(c => c.id) });
    for (const b of APP.BLOCOS_META) {
      if (!b.topicos) continue;
      for (const tt of b.topicos) {
        const existe = APP.BANCO.some(q => b.materias.includes(q.m) && q.t === tt);
        t.ok(existe, `escopo de "${b.nome}" cita tópico inexistente: "${tt}"`);
      }
    }
  });

  t.grupo('meta — matéria avulsa');

  t.teste('matéria avulsa vira bloco com cota própria', async () => {
    await APP.montar({ concursos: [], avulsas: ['biologia-celular'] });
    const b = bloco('biologia-celular');
    t.ok(b, 'avulsa devia ter virado bloco da meta');
    t.igual(b.novos, APP.META_MATERIA_AVULSA);
  });

  t.teste('avulsa não depende de concurso nenhum', async () => {
    await APP.montar({ concursos: [], avulsas: ['biologia-celular'] });
    t.igual(APP.CONCURSO, null, 'sem concurso seguido, CONCURSO é null');
    t.igual(APP.BLOCOS, [], 'sem concurso, BLOCOS (da prova) fica vazio');
    t.ok(APP.BLOCOS_META.length > 0, 'mas BLOCOS_META tem o bloco sintético da avulsa');
  });

  t.teste('avulsa que também é matéria de concurso vale a maior cota', async () => {
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: [] });
    const doConcurso = bloco('portugues').novos;
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: ['portugues'] });
    const comAvulsa = bloco('portugues').novos;
    t.igual(comAvulsa, Math.max(doConcurso, APP.META_MATERIA_AVULSA), 'devia ser a maior, nunca a soma');
  });

  t.grupo('meta — cota = novos + revisão');

  t.teste('sem nada vencido, a cota é só a do edital', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    for (const b of APP.BLOCOS_META) {
      t.igual(b.revisao, 0, `${b.nome} não devia ter revisão pendente num estado limpo`);
      t.igual(b.questoes, b.novos, `${b.nome}: questoes devia ser igual a novos`);
    }
  });

  t.teste('revisão pendente entra na cota, capada em 2x os novos', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const b0 = bloco('matematica');
    const novos = b0.novos;

    /* vence MUITO mais que o dobro, para o teto entrar em ação */
    const daMateria = APP.BANCO.filter(q => q.m === 'matematica'
      && (!b0.topicos || b0.topicos.includes(q.t)));
    t.ok(daMateria.length > novos * 2, 'preciso de banco maior que o teto para testá-lo');
    daMateria.slice(0, novos * 2 + 25).forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 2, acertos: 1, erros: 0, prox: hoje };
    });
    APP.aplicarFoco(null);

    const b = bloco('matematica');
    t.igual(b.revisao, novos * 2, 'a revisão devia estar capada em 2x os novos');
    t.igual(b.questoes, b.novos + b.revisao, 'questoes = novos + revisao');
  });

  t.teste('a revisão da cota conta cartão de tópico que fechou depois', async () => {
    /* revisaoPendenteDaMateria NÃO filtra por trava, de propósito: revisão
       vencida nunca é travada, então tem que contar na cota também. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    t.ok(!APP.topicoAberto('matematica', 'Funções'), 'Funções tem que estar fechada');
    const deFechado = APP.BANCO.filter(q => q.m === 'matematica' && q.t === 'Funções').slice(0, 4);
    t.ok(deFechado.length === 4, 'preciso de 4 cartões de tópico fechado');
    deFechado.forEach(q => { APP.E.cartoes[q.id] = { caixa: 2, acertos: 1, erros: 0, prox: hoje }; });
    APP.aplicarFoco(null);
    t.ok(bloco('matematica').revisao >= 4, 'cartão de tópico fechado tem que contar na revisão da cota');
  });

  t.grupo('progresso do dia');

  t.teste('excedente de um bloco não compensa outro', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const bMat = bloco('matematica');
    /* estudou o TRIPLO da cota de matemática e nada das outras */
    APP.E.diasMateria[hoje] = { matematica: bMat.questoes * 3 };
    const total = APP.progressoDoDia(hoje);
    const soma = APP.BLOCOS_META.reduce((s, b) => s + b.questoes, 0);
    t.ok(total < soma, 'estourar uma matéria não pode fechar a meta inteira');
    t.igual(total, bMat.questoes, 'cada bloco entra limitado à própria cota');
  });

  t.teste('matéria fora dos inscritos não conta para a meta', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    APP.E.diasMateria[hoje] = { enfermagem: 50 };   // não é matéria deste concurso
    t.igual(APP.progressoDoDia(hoje), 0);
  });

  t.teste('progressoPorBloco espelha os blocos da meta', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const p = APP.progressoPorBloco(APP.hoje());
    t.igual(p.length, APP.BLOCOS_META.length);
    p.forEach((linha, i) => {
      t.igual(linha.cota, APP.BLOCOS_META[i].questoes, `cota do bloco ${i}`);
      t.igual(linha.nome, APP.BLOCOS_META[i].nome, `nome do bloco ${i}`);
    });
  });
};
