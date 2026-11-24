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
    const [avulsa] = APP.avulsasDeTeste();
    if (!avulsa) return;
    await APP.montar({ concursos: ['caaq-cdm'], avulsas: [avulsa] });
    const m = APP.materiasInscritas();
    t.ok(m.includes('portugues') && m.includes('matematica'), 'faltou matéria do concurso');
    t.ok(m.includes(avulsa), 'faltou a avulsa');
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
    const [mat] = APP.avulsasDeTeste({ semGrafo: true });
    if (!mat) return;
    await APP.montar({ materias: [mat] });
    const resumo = APP.resumoDoBanco();
    const d = resumo[mat];
    if (!d) return;
    const nomes = APP.porDesbloqueio(mat, d.topicos);
    t.igual(nomes.length, Object.keys(d.topicos).length, 'a ordenação perdeu tópico');
  });

  t.grupo('recorte na tela Matérias');

  /* Um bloco de concurso real que recorta uma matéria só, tirado de
     concursos.json na hora: escrever o id no teste travaria a saída do
     concurso (regra 12). Sem nenhum, os testes pulam. */
  const blocoRecortado = (filtro = () => true) => {
    for (const c of APP.CONCURSOS)
      for (const bl of c.blocos || [])
        if (bl.topicos && bl.topicos.length && (bl.materias || []).length === 1 && filtro(bl))
          return { c, bl, m: bl.materias[0] };
    return null;
  };

  t.teste('matéria recortada mostra só o recorte, e o edital não traz de volta o que saiu', async () => {
    if (!APP.CONCURSOS.length) await APP.carregarConfig();
    const alvo = blocoRecortado();
    if (!alvo) return;
    await APP.montar({ concursos: [alvo.c.id] });
    const d = APP.resumoDoBanco()[alvo.m];
    t.ok(d, 'a matéria recortada sumiu da tela');
    const dentro = APP.BANCO.filter(q => q.m === alvo.m && APP.noEscopo(alvo.bl.topicos, q));
    const fora = APP.BANCO.filter(q => q.m === alvo.m && !APP.noEscopo(alvo.bl.topicos, q));
    t.ok(fora.length > 0, 'o teste precisa de cartão fora do recorte para provar alguma coisa');
    t.igual(d.total, dentro.length, 'o total da matéria devia contar só o recorte');
    for (const tt of Object.keys(d.topicos)) {
      t.ok(alvo.bl.topicos.some(x => x === tt || x.indexOf(tt + '|') === 0
                                   || (x[0] === '#' && APP.porId[x.slice(1)] && APP.porId[x.slice(1)].t === tt)),
        `"${tt}" está fora do recorte e apareceu na tela`);
    }
  });

  t.teste('estudar a matéria inteira pela tela não sai do recorte', async () => {
    if (!APP.CONCURSOS.length) await APP.carregarConfig();
    const alvo = blocoRecortado();
    if (!alvo) return;
    await APP.montar({ concursos: [alvo.c.id] });
    /* cartão fora do recorte com revisão vencida: é o que escaparia, porque o
       cartão novo fora do recorte a escada já segura sozinha */
    const fora = APP.BANCO.filter(q => q.m === alvo.m && !APP.noEscopo(alvo.bl.topicos, q)).slice(0, 20);
    t.ok(fora.length > 0, 'o teste precisa de cartão fora do recorte');
    const ontem = APP.somarDias(APP.hoje(), -1);
    fora.forEach(q => { APP.E.cartoes[q.id] = { caixa: 3, prox: ontem, acertos: 2, erros: 0 }; });
    APP.abrirEscada();
    APP.E.meta = 100000;
    const lote = APP.montarLoteSessao('filtro', { m: alvo.m }, new Set());
    t.ok(lote.length > 0, 'a sessão da matéria veio vazia');
    lote.forEach(id => t.ok(APP.noEscopo(alvo.bl.topicos, APP.porId[id]),
      `"${APP.porId[id].t}|${APP.porId[id].s}" está fora do recorte e entrou na sessão`));
  });

  t.teste('recortada por um bloco só, a matéria leva o nome do bloco', async () => {
    if (!APP.CONCURSOS.length) await APP.carregarConfig();
    const alvo = blocoRecortado(bl => bl.nome !== (APP.MATERIAS[bl.materias[0]] || {}).nome);
    if (!alvo) return;
    await APP.montar({ concursos: [alvo.c.id] });
    t.igual(APP.nomeNaTela(alvo.m), alvo.bl.nome, 'devia aparecer com o nome do bloco do edital');
    /* outro concurso que cobre a matéria inteira desfaz o recorte, e o nome
       volta a ser o da matéria */
    const inteira = APP.CONCURSOS.find(c => c.id !== alvo.c.id &&
      (c.blocos || []).some(b => (b.materias || []).includes(alvo.m) && !(b.topicos && b.topicos.length)));
    if (!inteira) return;
    await APP.montar({ concursos: [alvo.c.id, inteira.id] });
    t.igual(APP.nomeNaTela(alvo.m), APP.MATERIAS[alvo.m].nome, 'sem recorte, o nome é o da matéria');
    const fora = APP.BANCO.filter(q => q.m === alvo.m && !APP.noEscopo(alvo.bl.topicos, q));
    t.igual(APP.resumoDoBanco()[alvo.m].total, APP.BANCO.filter(q => q.m === alvo.m).length,
      `sem recorte, a matéria inteira volta (${fora.length} cartões fora do recorte do primeiro)`);
  });

  t.grupo('revisões pendentes');

  t.teste('os baldes são exclusivos e somam o total', async () => {
    /* Atrasadas, Hoje, Amanhã, 2-7, 8-30, 31-120: as fronteiras são os
       próprios INTERVALOS do Leitner, e cada cartão entra em um só balde. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.abrirEscada();
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
    /* O balde é a data em `prox`, nunca a caixa. Vale para o progresso
       gravado antes de o teto dinâmico ser removido, que tem cartão de
       caixa alta com data curta — e é `prox` que fila() lê. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.abrirEscada();
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
