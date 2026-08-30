/* Ordem de aprendizado — CLAUDE.md, seção "Ordem de aprendizado".
   Os invariantes desta seção são os que mais custaram a acertar (vários
   bugs reais em agosto/2026), e são os que este arquivo tranca. */
module.exports = function (APP, t) {

  /* ---- ferramentas ---- */

  /* "Dominar" um recorte = pôr todo cartão do NÍVEL MAIS BAIXO dele em
     caixa >= 2, que é o que grauLiberado() exige para avançar o degrau. */
  function dominar(m, tt, s) {
    const alvo = APP.BANCO.filter(q => q.m === m && q.t === tt && (!s || q.s === s));
    if (!alvo.length) throw new Error(`nada no banco para ${m}/${tt}${s ? '/' + s : ''}`);
    const menor = Math.min(...alvo.map(q => APP.grauDe(q)));
    alvo.filter(q => APP.grauDe(q) === menor)
      .forEach(q => { APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: '2099-01-01' }; });
    APP.limparCacheGrau();
  }
  function esquecerTudo() { APP.E.cartoes = {}; APP.limparCacheGrau(); }
  function subsDe(m, tt) {
    return [...new Set(APP.BANCO.filter(q => q.m === m && q.t === tt && q.s).map(q => q.s))];
  }

  t.grupo('pré-requisito de tópico');

  t.teste('toda matéria tem pelo menos um tópico aberto de saída', async () => {
    /* "A trava não pode deixar a pessoa sem nada para estudar." Carrega
       TODAS as matérias, não só as de um concurso: matéria avulsa e matéria
       parada precisam da mesma garantia. */
    await APP.montar({ materias: APP.ORDEM_MATERIAS });
    for (const mid of APP.ORDEM_MATERIAS) {
      const topicos = [...new Set(APP.BANCO.filter(q => q.m === mid).map(q => q.t))];
      if (!topicos.length) continue;
      const abertos = topicos.filter(tt => APP.topicoAberto(mid, tt));
      t.ok(abertos.length > 0, `${mid} não tem NENHUM tópico aberto — ninguém consegue começar`);
    }
  });

  t.teste('tópico com requisito começa fechado', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(APP.topicoAberto('matematica', 'Aritmética'), 'Aritmética é raiz, devia abrir');
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra exige Aritmética, devia estar fechada');
    t.ok(!APP.topicoAberto('matematica', 'Funções'), 'Funções exige Álgebra');
  });

  t.teste('dominar a base do exigido abre o tópico', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'));
    dominar('matematica', 'Aritmética');
    t.ok(APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra devia ter aberto');
  });

  t.teste('a abertura é transitiva — não pula elo da cadeia', async () => {
    /* Aritmética -> Álgebra -> Funções. Dominar só Aritmética não pode
       abrir Funções: histórico espalhado não destrava o que vem depois. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    dominar('matematica', 'Aritmética');
    t.ok(APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra abre');
    t.ok(!APP.topicoAberto('matematica', 'Funções'), 'Funções NÃO pode abrir ainda');
    dominar('matematica', 'Álgebra');
    t.ok(APP.topicoAberto('matematica', 'Funções'), 'agora Funções abre');
  });

  t.teste('histórico espalhado no meio da cadeia não destrava o que vem depois', async () => {
    /* Cadeia: Aritmética -> Álgebra -> Funções. Alguém pode ter a caixa de
       Álgebra em dia por acaso — histórico de antes da escada existir, ou
       de quando cabia estudar em qualquer ordem. Isso NÃO pode abrir
       Funções: baseDominada() exige que o exigido esteja ABERTO, não só com
       a caixa em dia. É o mesmo motivo transitivo que vale para subtópico. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra começa fechada');

    dominar('matematica', 'Álgebra');            // domina o MEIO, pulando a base
    t.ok(!APP.topicoAberto('matematica', 'Aritmética') === false,
      'Aritmética é raiz e segue aberta');
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'),
      'Álgebra tem cartão dominado, mas a base dela não — segue fechada');
    t.ok(!APP.topicoAberto('matematica', 'Funções'),
      'Funções NÃO pode abrir por causa de um domínio que pulou a base');

    dominar('matematica', 'Aritmética');          // agora sim, pela base
    t.ok(APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra abre');
    t.ok(APP.topicoAberto('matematica', 'Funções'), 'e Funções, que já estava dominada, também');
  });

  t.teste('errar a base fecha de volta o que dependia dela', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    dominar('matematica', 'Aritmética');
    t.ok(APP.topicoAberto('matematica', 'Álgebra'));
    /* um único cartão da base caindo para a caixa 1 desfaz o domínio */
    const base = APP.BANCO.filter(q => q.m === 'matematica' && q.t === 'Aritmética'
      && APP.grauDe(q) === 1 && APP.E.cartoes[q.id])[0];
    t.ok(base, 'precisava de um cartão de base dominado');
    APP.E.cartoes[base.id].caixa = 1;
    APP.limparCacheGrau();
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra devia ter fechado de novo');
  });

  t.grupo('pré-requisito de subtópico');

  t.teste('subtópico com requisito começa fechado, mesmo com o tópico aberto', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(APP.topicoAberto('matematica', 'Aritmética'), 'o tópico está aberto');
    const abertos = subsDe('matematica', 'Aritmética')
      .filter(s => APP.subtopicoAberto('matematica', 'Aritmética', s));
    t.igual(abertos, ['Multiplicação'], 'só a raiz da escada interna devia estar aberta');
  });

  t.teste('todo tópico que declara escada interna deixa um subtópico livre', () => {
    /* "senão o tópico abre e nenhum subtópico dele nunca abriria" */
    const porTopico = {};
    for (const chave of Object.keys(APP.REQUISITOS_SUB)) {
      const [m, tt] = chave.split('|');
      (porTopico[m + '|' + tt] = porTopico[m + '|' + tt] || []).push(chave);
    }
    for (const chave of Object.keys(porTopico)) {
      const [m, tt] = chave.split('|');
      const todos = subsDe(m, tt);
      if (!todos.length) continue;
      const livres = todos.filter(s => !(APP.REQUISITOS_SUB[m + '|' + tt + '|' + s] || []).length);
      t.ok(livres.length > 0, `${chave} travou TODOS os subtópicos — nenhum abriria nunca`);
    }
  });

  t.teste('subtópico não abre enquanto o tópico dele estiver fechado', async () => {
    /* "a trava de subtópico é uma camada A MAIS, nunca um atalho" */
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(!APP.topicoAberto('matematica', 'Álgebra'), 'Álgebra fechada');
    for (const s of subsDe('matematica', 'Álgebra')) {
      t.ok(!APP.subtopicoAberto('matematica', 'Álgebra', s),
        `${s} não podia abrir com o tópico fechado`);
    }
  });

  t.teste('subtópico dominado mas FECHADO não destrava quem depende dele', async () => {
    /* Mesma regra transitiva de tópico, um nível mais fundo: baseDominada()
       chama subtopicoAberto(), não só "a caixa está em dia". Sem isso,
       histórico de antes da escada abriria o próximo da fila de graça.
       Cadeia: Multiplicação -> Operações e expressões numéricas ->
       Divisibilidade. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const meio = 'Operações e expressões numéricas';
    const fim = 'Divisibilidade';
    t.ok(!APP.subtopicoAberto('matematica', 'Aritmética', meio), meio + ' começa fechado');

    dominar('matematica', 'Aritmética', meio);   // domina o meio, pulando Multiplicação
    t.ok(!APP.subtopicoAberto('matematica', 'Aritmética', meio),
      meio + ' tem cartão dominado, mas a base dele não — segue fechado');
    t.ok(!APP.subtopicoAberto('matematica', 'Aritmética', fim),
      fim + ' NÃO pode abrir por um domínio que pulou a base');

    dominar('matematica', 'Aritmética', 'Multiplicação');
    t.ok(APP.subtopicoAberto('matematica', 'Aritmética', meio), meio + ' abre');
    t.ok(APP.subtopicoAberto('matematica', 'Aritmética', fim), 'e o seguinte da fila também');
  });

  t.teste('a escada interna avança UM subtópico por vez', async () => {
    /* requisitos_subtopicos é uma FILA, não ondas: cada subtópico exige
       exatamente o anterior. Ver '_requisitos_subtopicos' no requisitos.json. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const abertos = () => subsDe('matematica', 'Aritmética')
      .filter(s => APP.subtopicoAberto('matematica', 'Aritmética', s)).sort();
    t.igual(abertos(), ['Multiplicação']);
    dominar('matematica', 'Aritmética', 'Multiplicação');
    t.igual(abertos(), ['Multiplicação', 'Operações e expressões numéricas'],
      'só o próximo da fila podia ter aberto');
    dominar('matematica', 'Aritmética', 'Operações e expressões numéricas');
    t.ok(abertos().includes('Divisibilidade'), 'agora o terceiro da fila abre');
    t.ok(!abertos().includes('Fatoração em números primos'), 'e o quarto ainda não');
  });

  t.teste('em toda matéria abre no máximo UM tópico por vez', async () => {
    /* O invariante que a fila existe para garantir. Antes dela, requisitos
       era um grafo e um tópico destravava vários de uma vez — Anatomia e
       Fisiologia abria 7 tópicos de Enfermagem com 11 cartões estudados.
       Ver '_a_fila' no banco/requisitos.json. */
    await APP.montar({ materias: APP.ORDEM_MATERIAS });
    for (const mid of APP.ORDEM_MATERIAS) {
      const topicos = [...new Set(APP.BANCO.filter(q => q.m === mid).map(q => q.t))];
      const temFila = topicos.some(tt => (APP.REQUISITOS[mid + '|' + tt] || []).length);
      if (!temFila) continue;                    // matéria sem fila declarada: fora do escopo
      esquecerTudo();
      const vistos = new Set();
      for (let passo = 0; passo <= topicos.length; passo++) {
        const novos = topicos.filter(tt => APP.topicoAberto(mid, tt) && !vistos.has(tt));
        t.ok(novos.length <= 1,
          `${mid}: ${novos.length} tópicos abriram de uma vez (${novos.join(', ')})`);
        if (!novos.length) break;
        vistos.add(novos[0]);
        dominar(mid, novos[0]);
      }
      t.igual(vistos.size, topicos.length, `${mid}: a fila não alcança todos os tópicos`);
    }
    esquecerTudo();
  });

  t.grupo('a trava só vale para cartão NOVO');

  t.teste('revisão vencida entra na fila mesmo com o tópico fechado', async () => {
    /* O invariante mais importante da seção: "Travar revisão viraria um
       jeito de esconder justamente o que a pessoa já errou." */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const hoje = APP.hoje();
    const deFechado = APP.BANCO.filter(q => q.m === 'matematica' && q.t === 'Funções');
    t.ok(deFechado.length >= 3, 'preciso de cartões de um tópico fechado');
    t.ok(!APP.topicoAberto('matematica', 'Funções'), 'Funções tem que estar fechada');

    const tres = deFechado.slice(0, 3);
    tres.forEach(q => { APP.E.cartoes[q.id] = { caixa: 2, acertos: 1, erros: 0, prox: hoje }; });
    APP.limparCacheGrau();

    const f = APP.fila();
    for (const q of tres) {
      t.ok(f.revisar.includes(q.id), 'revisão vencida de tópico fechado tem que entrar na fila');
    }
  });

  t.teste('cartão nunca visto de tópico fechado NÃO entra na fila', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    t.ok(!APP.topicoAberto('matematica', 'Funções'));
    const f = APP.fila();
    const vazaram = f.novas.filter(id => APP.porId[id].t === 'Funções');
    t.igual(vazaram, [], 'cartão novo de tópico fechado vazou para a fila');
  });

  t.teste('cartão novo de subtópico fechado NÃO entra na fila', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const f = APP.fila();
    const fechados = subsDe('matematica', 'Aritmética')
      .filter(s => !APP.subtopicoAberto('matematica', 'Aritmética', s));
    t.ok(fechados.length > 0, 'precisava de subtópico fechado para testar');
    const vazaram = f.novas.filter(id => {
      const q = APP.porId[id];
      return q.t === 'Aritmética' && fechados.includes(q.s);
    });
    t.igual(vazaram, [], 'cartão novo de subtópico fechado vazou');
  });

  t.grupo('escada de nível (n)');

  t.teste('cartão sem n vale 1', () => {
    t.igual(APP.grauDe({ id: 'x' }), 1);
    t.igual(APP.grauDe({ id: 'x', n: 3 }), 3);
  });

  t.teste('o nível é avaliado DENTRO do subtópico, não do tópico inteiro', async () => {
    /* O bug de agosto/2026: medir o nível 1 pelo TÓPICO somava cartão de
       subtópico ainda FECHADO — inacessível, logo impossível de dominar —
       e o nível 2 de subtópico nenhum jamais abria. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const alvo = 'Multiplicação';
    const doSub = APP.BANCO.filter(q => q.m === 'matematica' && q.t === 'Aritmética' && q.s === alvo);
    const niveis = [...new Set(doSub.map(q => APP.grauDe(q)))].sort((a, b) => a - b);
    if (niveis.length < 2) return;   // subtópico de um nível só não exercita a escada

    dominar('matematica', 'Aritmética', alvo);
    const liberadoNoSub = APP.grauLiberado('matematica', 'Aritmética', alvo);
    t.ok(liberadoNoSub > niveis[0],
      `dominado o nível ${niveis[0]} do subtópico, o degrau devia ter subido (veio ${liberadoNoSub})`);
  });

  t.teste('grauAberto usa o recorte do subtópico — o caso que travava a escada', async () => {
    /* REGRESSÃO de agosto/2026, relatada em uso: com grauLiberado(m,t) sem
       o `s`, o nível 1 do TÓPICO somava cartão de todo subtópico, inclusive
       os ainda FECHADOS pela escada — inacessíveis, logo impossíveis de
       dominar. O degrau nunca subia e o nível 2 de subtópico NENHUM abria.

       Aritmética é o caso real: 17 subtópicos, e vários dos fechados têm
       cartão de nível 1 que a pessoa não tem como alcançar ainda. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    dominar('matematica', 'Aritmética', 'Multiplicação');       // abre o 2º da fila
    const alvo = 'Operações e expressões numéricas';
    t.ok(APP.subtopicoAberto('matematica', 'Aritmética', alvo), alvo + ' devia ter aberto');

    dominar('matematica', 'Aritmética', alvo);                  // domina o nível 1 DELE

    const nivel2 = APP.BANCO.find(q => q.m === 'matematica' && q.t === 'Aritmética'
      && q.s === alvo && APP.grauDe(q) === 2);
    t.ok(nivel2, 'preciso de um cartão de nível 2 nesse subtópico');

    /* a prova de que o pooling por tópico não voltou: medido pelo tópico
       inteiro, o degrau continua em 1 e este cartão ficaria fechado */
    t.igual(APP.grauLiberado('matematica', 'Aritmética'), 1,
      'o tópico inteiro segue no degrau 1 — é justamente o que não pode decidir');
    t.ok(APP.grauAberto(nivel2),
      'nível 2 do subtópico dominado tem que abrir, mesmo com o tópico inteiro parado no degrau 1');
  });

  t.teste('o degrau mais baixo nunca trava', async () => {
    /* "Cartão sem n vale 1, e o degrau 1 nunca trava" — sem isso, ligar o
       recurso trancaria tudo que ninguém classificou ainda. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    for (const mid of APP.materiasInscritas()) {
      const topicos = [...new Set(APP.BANCO.filter(q => q.m === mid).map(q => q.t))];
      for (const tt of topicos) {
        if (!APP.topicoAberto(mid, tt)) continue;
        const cartoes = APP.BANCO.filter(q => q.m === mid && q.t === tt);
        const subsAbertos = new Set(cartoes.filter(q => !q.s || APP.subtopicoAberto(mid, tt, q.s))
          .map(q => q.s || ''));
        for (const s of subsAbertos) {
          const doRecorte = cartoes.filter(q => (q.s || '') === s);
          const menor = Math.min(...doRecorte.map(q => APP.grauDe(q)));
          const algum = doRecorte.find(q => APP.grauDe(q) === menor);
          t.ok(APP.grauAberto(algum),
            `${mid}/${tt}${s ? '/' + s : ''}: o degrau mais baixo (${menor}) está travado`);
        }
      }
    }
  });

  t.grupo('integridade do grafo');

  t.teste('nenhuma dependência aponta para tópico ou subtópico inexistente', () => {
    const existe = new Set();
    const existeSub = new Set();
    for (const q of APP.BANCO) {
      existe.add(q.m + '|' + q.t);
      if (q.s) existeSub.add(q.m + '|' + q.t + '|' + q.s);
    }
    const conferir = (m, deps, origem) => {
      for (const d of deps) {
        if (typeof d === 'string') {
          t.ok(existe.has(m + '|' + d), `${origem} exige tópico inexistente "${d}"`);
        } else {
          t.ok(existeSub.has(m + '|' + d.t + '|' + d.s),
            `${origem} exige subtópico inexistente "${d.t}|${d.s}"`);
        }
      }
    };
    for (const chave of Object.keys(APP.REQUISITOS)) {
      const [m] = chave.split('|');
      if (!APP.materiasInscritas().includes(m) && !APP.BANCO.some(q => q.m === m)) continue;
      conferir(m, APP.REQUISITOS[chave], chave);
    }
    for (const chave of Object.keys(APP.REQUISITOS_SUB)) {
      const [m] = chave.split('|');
      if (!APP.BANCO.some(q => q.m === m)) continue;
      conferir(m, APP.REQUISITOS_SUB[chave], chave);
    }
  });

  t.teste('nenhum tópico exige a si mesmo', () => {
    for (const chave of Object.keys(APP.REQUISITOS)) {
      const [m, tt] = chave.split('|');
      for (const d of APP.REQUISITOS[chave]) {
        const alvo = typeof d === 'string' ? d : d.t;
        if (typeof d === 'string') t.ok(alvo !== tt, `${chave} exige a si mesmo`);
      }
    }
  });

  t.teste('a escada de subtópico não tem ciclo', () => {
    for (const chave of Object.keys(APP.REQUISITOS_SUB)) {
      const [m, tt, s] = chave.split('|');
      const visto = new Set();
      const pilha = [[tt, s]];
      let passos = 0;
      while (pilha.length && passos++ < 500) {
        const [ct, cs] = pilha.pop();
        const k = ct + '|' + cs;
        if (visto.has(k)) continue;
        visto.add(k);
        for (const d of (APP.REQUISITOS_SUB[m + '|' + ct + '|' + cs] || [])) {
          t.ok(!(d.t === tt && d.s === s), `ciclo na escada de ${chave}`);
          pilha.push([d.t, d.s]);
        }
      }
    }
  });
};
