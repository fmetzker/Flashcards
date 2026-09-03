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

  t.teste('dentro de cada bloco, revisão pendente vem antes de cartão novo', async () => {
    /* Trilha B do plano de revisão da meta: revisão primeiro, cartão novo só
       entra se sobrar espaço na cota — troca de propósito do intercalar()
       (que espalhava as duas) por concatenação simples (ver o comentário em
       montarLoteSessao()). Caso mais fraco do teste global logo abaixo. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const b = APP.BLOCOS_META.find(x => x.materias.includes('matematica'));
    t.ok(b.questoes >= 4, 'preciso de cota >= 4 para caber revisão e novo no mesmo bloco');
    const daMateria = APP.BANCO.filter(q => q.m === 'matematica'
      && (!b.topicos || b.topicos.includes(q.t)) && APP.grauAberto(q));
    t.ok(daMateria.length >= 4, 'preciso de pelo menos 4 cartões abertos de matemática');
    // marca 2 como revisão vencida hoje; o resto continua "nunca visto"
    daMateria.slice(0, 2).forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 1, prox: hoje };
    });
    const revIds = new Set(daMateria.slice(0, 2).map(q => q.id));
    const lote = APP.montarLoteSessao('normal', null, new Set());
    const daArea = lote.filter(id => APP.porId[id].m === 'matematica');
    const posRev = daArea.map((id, i) => revIds.has(id) ? i : -1).filter(i => i >= 0);
    const posNov = daArea.map((id, i) => !revIds.has(id) ? i : -1).filter(i => i >= 0);
    t.ok(posRev.length > 0, 'a revisão marcada devia aparecer no lote');
    if (posNov.length > 0) {
      t.ok(Math.max(...posRev) < Math.min(...posNov),
        'revisão precisa vir toda antes do primeiro cartão novo dentro do bloco: ' + daArea.join(','));
    }
  });

  t.teste('revisão de QUALQUER matéria vem antes de cartão novo de QUALQUER outra', async () => {
    /* A ordem de BLOCOS_META não pode passar na frente da revisão: antes, a
       sessão saía [LP: rev,novo][Mat: rev,novo]..., e cartão NOVO da primeira
       matéria aparecia antes de revisão PENDENTE da segunda. O pedido é
       "conteúdo novo só se não tiver revisão pendente" — global, não por
       matéria. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    /* vence 1 cartão SÓ na última matéria de BLOCOS_META, e deixa as
       anteriores inteiras de cartão novo — é a situação em que o bug
       aparecia: os novos das primeiras matérias vinham antes dessa revisão */
    const ultimo = APP.BLOCOS_META[APP.BLOCOS_META.length - 1];
    const m = ultimo.materias[0];
    const alvo = APP.BANCO.find(q => q.m === m
      && (!ultimo.topicos || ultimo.topicos.includes(q.t)) && APP.grauAberto(q));
    t.ok(alvo, `preciso de um cartão aberto de ${m}`);
    APP.E.cartoes[alvo.id] = { caixa: 1, acertos: 0, erros: 1, prox: hoje };

    const lote = APP.montarLoteSessao('normal', null, new Set());
    const iRev = lote.indexOf(alvo.id);
    t.ok(iRev >= 0, 'a revisão vencida tinha que entrar no lote');
    t.igual(iRev, 0, 'a única revisão pendente tinha que ser o PRIMEIRO cartão da sessão, '
      + `mas veio na posição ${iRev} (matérias antes dela: `
      + lote.slice(0, iRev).map(id => APP.porId[id].m).join(',') + ')');
  });

  t.teste('com revisão em várias matérias, nenhum cartão novo aparece antes da última revisão', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const revIds = new Set();
    APP.BLOCOS_META.forEach(bl => {
      const m = bl.materias[0];
      const q = APP.BANCO.find(x => x.m === m
        && (!bl.topicos || bl.topicos.includes(x.t)) && APP.grauAberto(x) && !revIds.has(x.id));
      if (!q) return;
      APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 1, prox: hoje };
      revIds.add(q.id);
    });
    t.ok(revIds.size >= 2, 'preciso de revisão pendente em pelo menos 2 matérias');

    const lote = APP.montarLoteSessao('normal', null, new Set());
    const posRev = [], posNov = [];
    lote.forEach((id, i) => (revIds.has(id) ? posRev : posNov).push(i));
    t.igual(posRev.length, revIds.size, 'todas as revisões pendentes tinham que entrar');
    if (posNov.length > 0) {
      t.ok(Math.max(...posRev) < Math.min(...posNov),
        'cartão novo apareceu antes de uma revisão pendente de outra matéria: '
        + lote.map(id => (revIds.has(id) ? 'REV' : 'novo') + ':' + APP.porId[id].m).join(' '));
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

  t.grupo('ordem embaralhada — a ordem do arquivo não decide nada');

  /* A tabuada é o caso real que motivou isto (relatado em uso): no arquivo
     ela está em sequência — 3x2, 3x3, 3x4... — e estudar nessa ordem deixa
     responder somando o anterior em vez de lembrar, que é o oposto de
     recordação ativa. Ver cmpId() no motor.js. */
  const tabuada = () => APP.BANCO.filter(q => q.s === 'Multiplicação');
  const limpar = () => { APP.E.cartoes = {}; APP.limparCacheGrau(); };

  t.teste('cartão novo sai ordenado por id, não pela ordem do arquivo', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const noArquivo = tabuada().map(q => q.id);
    const naFila = APP.fila().novas.filter(id => APP.porId[id].s === 'Multiplicação');
    t.ok(naFila.length >= 10, 'preciso da tabuada aberta para testar');
    t.igual(naFila, [...naFila].sort(APP.cmpId), 'cartão novo devia sair ordenado por id');
    t.naoIgual(naFila, noArquivo.slice(0, naFila.length), 'saiu na ordem do arquivo');
  });

  t.teste('a tabuada não sai em sequência numérica', async () => {
    /* O teste que fala a língua do problema: não importa por qual regra,
       importa que 3x2, 3x3, 3x4 não venham em fila. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const chave = q => { const m = q.q.match(/(\d+) × (\d+)/); return m ? +m[1] * 10 + +m[2] : 0; };
    const nums = APP.fila().novas.map(id => APP.porId[id])
      .filter(q => q.s === 'Multiplicação').map(chave);
    t.ok(nums.length >= 10, 'preciso da tabuada');
    t.ok(!nums.every((v, i) => i === 0 || v > nums[i - 1]),
      'a tabuada saiu em sequência crescente — dá para responder somando o anterior');
  });

  t.teste('revisão com prioridade empatada desempata por id', async () => {
    /* Empate é o caso COMUM, não a exceção: todo cartão de mesma caixa, sem
       histórico de erro, do mesmo bloco, dá exatamente o mesmo número — e
       sort estável devolvia a ordem do arquivo. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const dez = tabuada().slice(0, 10);
    dez.forEach(q => { APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 1, prox: APP.hoje() }; });
    APP.limparCacheGrau();
    const rev = APP.fila().revisar;
    t.igual(new Set(rev.map(id => APP.prioridade(id))).size, 1,
      'o caso só testa o que quero se as prioridades empatarem');
    t.igual(rev, [...rev].sort(APP.cmpId), 'empate devia sair ordenado por id');
    t.naoIgual(rev, dez.map(q => q.id), 'saiu na ordem do arquivo');
    limpar();
  });

  t.teste('o desempate por id NÃO atropela prioridade()', async () => {
    /* O id é o ÚLTIMO critério, nunca o primeiro: caixa 1 quer dizer "errei
       na revisão mais recente", e nada pode passar na frente disso. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const ids = tabuada().map(q => q.id).sort(APP.cmpId);
    const menor = ids[0], maior = ids[ids.length - 1];
    APP.E.cartoes[menor] = { caixa: 3, acertos: 3, erros: 0, prox: APP.hoje() };
    APP.E.cartoes[maior] = { caixa: 1, acertos: 0, erros: 1, prox: APP.hoje() };
    APP.limparCacheGrau();
    t.igual(APP.fila().revisar, [maior, menor],
      'caixa 1 tem que vir antes da caixa 3, mesmo tendo o id maior');
    limpar();
  });

  t.teste('a ordem é a mesma em toda chamada — sem sorteio', async () => {
    /* fila() roda de novo a cada reabastecimento da sessão: com Math.random()
       a ordem mudaria no meio dela, e nenhum teste conseguiria travá-la. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.igual(APP.fila().novas, APP.fila().novas, 'duas chamadas deram ordens diferentes');
  });

  t.teste('o modo filtro embaralha igual', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const lote = APP.montarLoteSessao('filtro',
      { m: 'matematica', t: 'Aritmética', s: 'Multiplicação' }, new Set());
    t.ok(lote.length >= 10, 'preciso de cartões');
    t.igual(lote, [...lote].sort(APP.cmpId), 'o modo filtro saiu fora da ordem por id');
    t.naoIgual(lote, tabuada().slice(0, lote.length).map(q => q.id), 'saiu na ordem do arquivo');
  });

  t.teste('o modo erros embaralha igual', async () => {
    /* Ali a ordem acidental é outra: a de inserção em E.cartoes. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const oito = tabuada().slice(0, 8);
    oito.forEach(q => { APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 2, prox: APP.hoje() }; });
    APP.limparCacheGrau();
    const lote = APP.montarLoteSessao('erros', null, new Set());
    t.igual(lote, [...lote].sort(APP.cmpId), 'o modo erros saiu na ordem de inserção no E');
    t.naoIgual(lote, oito.map(q => q.id), 'saiu na ordem do arquivo');
    limpar();
  });

  t.grupo('repetição do cartão errado');

  function sessaoFalsa(modo) {
    return { lista: [], pos: 0, respondida: false, modo, filtro: null, pendentes: [] };
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
