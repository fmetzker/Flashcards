/* Meta do dia — CLAUDE.md, seção "Meta e progresso do dia". */
module.exports = function (APP, t) {

  const bloco = (m) => APP.BLOCOS_META.find(b => b.materias.includes(m));

  t.grupo('meta — matéria repetida');

  t.teste('matéria em dois concursos não soma: vale o MAIOR peso', async () => {
    /* Português cai nos quatro concursos; somar o PESO daria um número maior
       que qualquer um dos dois sozinho. `peso` é a cota do edital ANTES do
       rateio — é ele quem carrega essa regra (ver comentário em
       blocosDaMeta()); `questoes`, depois do rateio, não prova mais isto
       sozinho porque dois pesos diferentes podem cair na mesma cota final
       por arredondamento. */
    await APP.montar({ concursos: ['vr-enf-2026'] });
    const soA = bloco('portugues').peso;

    await APP.montar({ concursos: ['caaq-cdm'] });
    const soB = bloco('portugues').peso;

    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    const juntos = bloco('portugues').peso;

    t.igual(juntos, Math.max(soA, soB), `${soA} e ${soB} deviam virar ${Math.max(soA, soB)}, veio ${juntos}`);
    t.ok(juntos < soA + soB || soA === 0 || soB === 0, 'não pode somar os dois pesos');
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
        const [tt0, ss] = tt.split('|');
        const existe = APP.BANCO.some(q => b.materias.includes(q.m) && q.t === tt0
                                         && (ss === undefined || q.s === ss));
        t.ok(existe, `escopo de "${b.nome}" cita tópico/subtópico inexistente: "${tt}"`);
      }
    }
  });

  t.teste('escopo por subtópico: "Tópico|Subtópico" abre só aquele subtópico', () => {
    /* o tópico do banco mistura o que o edital pede com o que ele nem cita —
       Álgebra tem equação do 2º grau e logaritmo; o 9º ano pede só a 1ª */
    const esc = ['Pontuação', 'Álgebra|Equações do 2º grau'];
    t.ok(APP.noEscopo(esc, { t: 'Pontuação' }), 'tópico inteiro tinha que entrar');
    t.ok(APP.noEscopo(esc, { t: 'Pontuação', s: 'Vírgula' }), 'subtópico de tópico inteiro tinha que entrar');
    t.ok(APP.noEscopo(esc, { t: 'Álgebra', s: 'Equações do 2º grau' }), 'subtópico listado tinha que entrar');
    t.ok(!APP.noEscopo(esc, { t: 'Álgebra', s: 'Equações logarítmicas' }), 'subtópico irmão não listado entrou');
    t.ok(!APP.noEscopo(esc, { t: 'Álgebra' }), 'cartão sem subtópico entrou por um escopo só de subtópico');
    t.ok(APP.noEscopo(null, { t: 'Qualquer' }), 'sem escopo, a matéria inteira entra');
  });

  t.teste('a sessão respeita o escopo por subtópico (revisão vencida fora dele não entra)', async () => {
    /* trecho já aberto na escada: é o único jeito de o cartão fora do escopo
       chegar até o filtro da sessão */
    await APP.montar({ concursos: ['cfaq-moc-mom'] });
    const mat = bloco('matematica');
    t.ok(mat && mat.topicos && mat.topicos.some(x => x.includes('|')),
      'cfaq-moc-mom devia recortar Matemática por subtópico');
    const fora = APP.BANCO.find(q => q.t === 'Álgebra' && q.s === 'Equações logarítmicas');
    const dentro = APP.BANCO.find(q => q.t === 'Álgebra' && q.s === 'Equações do 2º grau');
    t.ok(fora && dentro, 'preciso de um cartão de logaritmo e um de equação do 2º grau');
    const hoje = APP.hoje();
    APP.E.cartoes[fora.id] = { caixa: 1, acertos: 0, erros: 1, prox: hoje };
    APP.E.cartoes[dentro.id] = { caixa: 1, acertos: 0, erros: 1, prox: hoje };
    APP.E.escada[APP.chaveEscada(fora)] = APP.grauDe(fora);
    APP.E.escada[APP.chaveEscada(dentro)] = APP.grauDe(dentro);
    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.ok(lote.includes(dentro.id), 'a revisão dentro do escopo tinha que entrar');
    t.ok(!lote.includes(fora.id), 'revisão de logaritmo entrou numa sessão do CFAQ (fora do escopo)');
  });

  t.teste('o simulado sorteia só dentro do escopo do bloco', async () => {
    /* o simulado imita a prova: um simulado de 9º ano não pode trazer
       logaritmo nem tabela-verdade só porque estão na mesma matéria */
    await APP.montar({ concursos: ['cfaq-moc-mom'] });
    const mat = APP.BLOCOS.find(b => b.materias.includes('matematica'));
    t.ok(mat && mat.topicos, 'o bloco de Matemática do CFAQ devia ter escopo');
    const fora = APP.BANCO.filter(q => q.m === 'matematica' && !APP.noEscopo(mat.topicos, q)).length;
    t.ok(fora > 0, 'o teste precisa de cartão fora do escopo no banco carregado');
    t.igual(APP.disponivel(mat), APP.BANCO.filter(q => q.m === 'matematica').length - fora,
      'disponivel() contou cartão fora do escopo');
    for (let i = 0; i < 30; i++) {
      for (const id of APP.sorteia(mat)) {
        const q = APP.porId[id];
        t.ok(APP.noEscopo(mat.topicos, q), `simulado sorteou fora do escopo: ${q.t}|${q.s}`);
      }
    }
  });

  t.grupo('meta — matéria avulsa');

  t.teste('matéria avulsa vira bloco com peso próprio', async () => {
    const [avulsa] = APP.avulsasDeTeste();
    if (!avulsa) return;
    await APP.montar({ concursos: [], avulsas: [avulsa] });
    const b = bloco(avulsa);
    t.ok(b, 'avulsa devia ter virado bloco da meta');
    t.igual(b.peso, APP.META_MATERIA_AVULSA);
  });

  t.teste('avulsa não depende de concurso nenhum', async () => {
    const [avulsa] = APP.avulsasDeTeste();
    if (!avulsa) return;
    await APP.montar({ concursos: [], avulsas: [avulsa] });
    t.igual(APP.CONCURSO, null, 'sem concurso seguido, CONCURSO é null');
    t.igual(APP.BLOCOS, [], 'sem concurso, BLOCOS (da prova) fica vazio');
    t.ok(APP.BLOCOS_META.length > 0, 'mas BLOCOS_META tem o bloco sintético da avulsa');
  });

  t.teste('avulsa que também é matéria de concurso vale o maior peso', async () => {
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: [] });
    const doConcurso = bloco('portugues').peso;
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: ['portugues'] });
    const comAvulsa = bloco('portugues').peso;
    const menorBloco = Math.min(...APP.CONCURSOS.find(c => c.id === 'vr-enf-2026').blocos.map(b => b.questoes));
    t.igual(comAvulsa, Math.max(doConcurso, menorBloco), 'devia ser o maior, nunca a soma');
  });

  t.teste('com prova seguida, a avulsa pesa o menor bloco — nunca mais que matéria da prova', async () => {
    /* peso fixo de 20 num edital de blocos de 10 fazia cada avulsa valer o
       dobro de Português e tirava espaço da matéria principal */
    const duas = APP.avulsasDeTeste().slice(0, 2);
    if (duas.length < 2) return;
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: duas });
    const daProva = APP.BLOCOS_META.filter(b => !b.id.startsWith('avulsa@'));
    const avulsas = APP.BLOCOS_META.filter(b => b.id.startsWith('avulsa@'));
    t.igual(avulsas.length, 2, 'as duas avulsas deviam virar bloco');
    const menor = Math.min(...daProva.map(b => b.peso));
    for (const a of avulsas) {
      t.igual(a.peso, menor, `${a.nome} pesa ${a.peso}, devia pesar o menor bloco da prova (${menor})`);
      for (const b of daProva) t.ok(a.questoes <= b.questoes,
        `${a.nome} (${a.questoes}/dia) passou na frente de ${b.nome} (${b.questoes}/dia), que cai na prova`);
    }
  });

  t.grupo('meta — rateio proporcional (apportion)');

  t.teste('sempre soma exatamente o total pedido', () => {
    /* Casos que tendem a sobrar/faltar unidade por arredondamento puro —
       é exatamente o que o método do maior resto existe pra evitar. */
    const casos = [[1, 1, 1], [10, 20, 5], [3, 3, 3, 3, 3, 3, 3], [1], [7, 1], [100, 1, 1, 1]];
    for (const pesos of casos) {
      const r = APP.apportion(pesos, APP.META_DIARIA);
      const soma = r.reduce((a, b) => a + b, 0);
      t.igual(soma, APP.META_DIARIA, `pesos ${pesos.join(',')} deviam somar ${APP.META_DIARIA}, veio ${soma}`);
    }
  });

  t.teste('peso maior nunca recebe cota menor que peso menor', () => {
    const r = APP.apportion([30, 10, 5], 50);
    t.ok(r[0] >= r[1] && r[1] >= r[2], `rateio não respeitou a ordem dos pesos: ${r.join(',')}`);
  });

  t.teste('peso zero fica com cota zero, e não disputa a sobra do arredondamento', () => {
    const r = APP.apportion([10, 0, 10], 50);
    t.igual(r[1], 0);
    t.igual(r[0] + r[2], 50);
  });

  t.teste('pesos iguais somando exatamente o total: cada um recebe sua fatia exata', () => {
    t.igual(APP.apportion([1, 1, 1, 1, 1], 50), [10, 10, 10, 10, 10]);
  });

  t.teste('determinístico — mesma entrada, mesma saída sempre', () => {
    const a = APP.apportion([7, 7, 7, 7], 50), b = APP.apportion([7, 7, 7, 7], 50);
    t.igual(a, b);
  });

  t.teste('lista de pesos vazia devolve total zero, sem quebrar', () => {
    t.igual(APP.apportion([], 50), []);
  });

  t.grupo('meta — cota é a fatia rateada de META_DIARIA');

  t.teste('a meta do dia é sempre META_DIARIA, com um concurso ou com vários', async () => {
    /* Antes a meta crescia a cada concurso novo seguido (soma das cotas do
       edital); agora é sempre a mesma constante — só a DIVISÃO entre
       matérias muda. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    APP.aplicarFoco(null);
    t.igual(APP.E.meta, APP.META_DIARIA);

    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm', 'transpetro-mec'] });
    APP.aplicarFoco(null);
    t.igual(APP.E.meta, APP.META_DIARIA, 'seguir mais concursos não pode inflar a meta');
  });

  t.teste('a soma das cotas de BLOCOS_META bate com META_DIARIA', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    const soma = APP.BLOCOS_META.reduce((s, b) => s + b.questoes, 0);
    t.igual(soma, APP.META_DIARIA);
  });

  t.teste('escopo restrito a um concurso também soma META_DIARIA', async () => {
    /* "só este concurso" muda a DIVISÃO, não o total — ver pintarFocoConcurso() */
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    const soma = APP.blocosDaMeta([APP.CONCURSOS.find(c => c.id === 'vr-enf-2026')])
      .reduce((s, b) => s + b.questoes, 0);
    t.igual(soma, APP.META_DIARIA);
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

  t.grupo('meta — evento de matéria não carregada não pode inflar o total do dia');

  t.teste('aplicarEventoRemoto: dia fica com diasMateria (mesmo vazio) mesmo sem achar a matéria', async () => {
    /* Sem isso, progressoDoDia() não consegue distinguir "hoje, sem nada
       de matéria carregada" de "dia legado, anterior a diasMateria
       existir" — e cai no fallback errado. Ver o comentário da própria
       aplicarEventoRemoto(). */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    t.igual(APP.E.diasMateria[h], undefined, 'pré-condição: dia começa sem diasMateria');

    APP.aplicarEventoRemoto({
      id: 'ev-1', questao_id: 'id-de-questao-que-nao-existe-no-banco-carregado',
      ts: new Date().toISOString(), resultado: 'sabia', caixa_depois: 2, prox: h,
    }, new Set());

    t.ok(APP.E.diasMateria[h], 'diasMateria[hoje] tinha que existir depois do evento, mesmo vazio');
  });

  t.teste('evento remoto de matéria não carregada soma no gráfico bruto mas NÃO na meta do dia', async () => {
    /* Reproduz o sintoma relatado: painel mostra "224/50" no topo (bruto)
       enquanto cada bloco individual mostra "0/25" — sintoma de conta que
       trocou/desseguiu um concurso e o pull ainda traz histórico antigo
       daquela matéria. E.dias precisa continuar contando (é o gráfico
       "quanto você estudou", de propósito bruto — CLAUDE.md), mas
       progressoDoDia() (a META) não pode usar esse número. */
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    for (let i = 0; i < 5; i++) {
      APP.aplicarEventoRemoto({
        id: 'ev-' + i, questao_id: 'id-inexistente-' + i,
        ts: new Date().toISOString(), resultado: 'sabia', caixa_depois: 2, prox: h,
      }, new Set());
    }
    t.igual(APP.E.dias[h], 5, 'o gráfico bruto "quanto você estudou" precisa continuar contando');
    t.igual(APP.progressoDoDia(h), 0, 'sem matéria carregada correspondente, a meta não pode usar o bruto');

    const porBloco = APP.progressoPorBloco(h).reduce((s, b) => s + Math.min(b.feitas, b.cota), 0);
    t.igual(APP.progressoDoDia(h), porBloco, 'topo da meta e soma dos blocos individuais têm que bater');
  });

  t.grupo('aviso de meta batida — uma vez por DIA, não por sessão');

  const avisos = () => { const a = []; APP.__ctx.mostrarToast = m => a.push(m); return a; };

  t.teste('bater uma matéria mostra o aviso individual uma única vez', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    const bMat = bloco('matematica');
    APP.E.diasMateria[h] = { matematica: bMat.questoes };   // só matemática bate
    const a = avisos();
    APP.checarMetasBatidas();
    t.igual(a.length, 1, 'devia mostrar exatamente um aviso: ' + JSON.stringify(a));
    t.ok(a[0].includes('Matemática') || a[0].includes(bMat.nome), 'aviso não citou a matéria certa: ' + a[0]);
    t.ok(!a[0].includes('todas'), 'não devia ser o aviso de "todas as metas" ainda');

    // chamar de novo, sem mudar nada e SEM sessão nenhuma (S null) — não repete
    APP.S = null;
    const a2 = avisos();
    APP.checarMetasBatidas();
    t.igual(a2.length, 0, 'não podia repetir o aviso só porque a sessão (S) mudou/sumiu');
  });

  t.teste('fechar a ÚLTIMA matéria pendente mostra só "todas as metas", não o aviso individual dela', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    APP.E.diasMateria[h] = {};
    APP.BLOCOS_META.forEach(bl => { APP.E.diasMateria[h][bl.materias[0]] = bl.questoes; });
    const a = avisos();
    APP.checarMetasBatidas();
    t.igual(a.length, 1, 'devia mostrar exatamente um aviso, não um por matéria + o de todas: ' + JSON.stringify(a));
    t.ok(a[0].includes('todas as metas'), 'o único aviso tinha que ser o de "todas as metas": ' + a[0]);
  });

  t.teste('depois de "todas as metas" já anunciado, nenhum aviso novo aparece', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    APP.E.diasMateria[h] = {};
    APP.BLOCOS_META.forEach(bl => { APP.E.diasMateria[h][bl.materias[0]] = bl.questoes; });
    APP.checarMetasBatidas();   // primeira vez: anuncia "todas"
    const a = avisos();
    APP.checarMetasBatidas();   // segunda vez: nada novo
    t.igual(a.length, 0, 'não podia mostrar nada de novo: ' + JSON.stringify(a));
  });

  t.teste('o controle fica em E.metasAnunciadas[dia], não em S — dia diferente não herda nada', async () => {
    await APP.montar({ concursos: ['transpetro-mec'] });
    const h = APP.hoje();
    const bMat = bloco('matematica');
    APP.E.diasMateria[h] = { matematica: bMat.questoes };
    APP.checarMetasBatidas();
    t.ok(APP.E.metasAnunciadas[h].blocos.includes(bloco('matematica').id), 'devia ter marcado o aviso de hoje');
    t.igual(APP.E.metasAnunciadas['2020-01-01'], undefined, 'um dia sem histórico não pode ter entrada nenhuma');
  });
  t.grupo('meta — prova em foco, o resto só em revisão');

  const vencer = (ids) => {
    const h = APP.hoje();
    ids.forEach(id => { APP.E.cartoes[id] = { caixa: 3, acertos: 2, erros: 0, prox: h }; });
  };
  const daMateria = (m, n) => APP.BANCO.filter(q => q.m === m).slice(0, n).map(q => q.id);
  const novosDa = (lote, m) => lote.filter(id => APP.porId[id].m === m && !APP.E.cartoes[id]);
  /* sem a fila, todo tópico abre: é o que faz o cartão novo chegar até o filtro
     do foco, em vez de parar antes na trava de pré-requisito */
  const semFila = async (fn) => {
    const salvo = { REQ: APP.REQUISITOS, SUB: APP.REQUISITOS_SUB };
    APP.REQUISITOS = {}; APP.REQUISITOS_SUB = {};
    try { await fn(); } finally { APP.REQUISITOS = salvo.REQ; APP.REQUISITOS_SUB = salvo.SUB; }
  };

  t.teste('revisão de outra prova seguida entra na sessão; cartão novo dela não', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    const [id] = daMateria('enfermagem', 1);
    vencer([id]);
    APP.aplicarFoco('caaq-cdm');
    t.ok(bloco('enfermagem') && bloco('enfermagem').soRevisao, 'Enfermagem devia virar bloco só de revisão');
    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.ok(lote.includes(id), 'a revisão de Enfermagem tinha que entrar');
    t.igual(novosDa(lote, 'enfermagem').length, 0, 'cartão novo de matéria fora do foco não pode entrar');
    t.ok(novosDa(lote, 'matematica').length > 0, 'a prova em foco continua recebendo cartão novo');
    const linha = APP.progressoPorBloco(APP.hoje()).find(b => b.nome === bloco('enfermagem').nome);
    t.ok(linha.soRevisao, 'a tela precisa saber que o bloco é só de revisão');
  });

  t.teste('a cota só de revisão para no que há para fazer, e a soma segue em META_DIARIA', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    vencer(daMateria('enfermagem', 3));
    APP.aplicarFoco('caaq-cdm');
    t.igual(bloco('enfermagem').questoes, 3, 'cota maior que o vencido deixaria a meta impossível de fechar');
    const soma = APP.BLOCOS_META.reduce((n, b) => n + b.questoes, 0);
    t.igual(soma, APP.META_DIARIA, 'a sobra tem que voltar para os blocos da prova');
  });

  t.teste('revisão já feita hoje conta no limite: a cota não encolhe no meio do dia', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    vencer(daMateria('enfermagem', 1));
    APP.E.diasMateria[APP.hoje()] = { enfermagem: 2 };
    APP.aplicarFoco('caaq-cdm');
    t.igual(bloco('enfermagem').questoes, 3, '2 feitas hoje + 1 vencida');
  });

  t.teste('matéria fora do foco sem nada vencido não ganha bloco nem cota', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.aplicarFoco('caaq-cdm');
    t.ok(!bloco('enfermagem'), 'bloco vazio deixaria a meta impossível de fechar');
    const soma = APP.BLOCOS_META.reduce((n, b) => n + b.questoes, 0);
    t.igual(soma, APP.META_DIARIA);
  });

  t.teste('atraso grande fora do foco não toma a sessão da prova', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    vencer(daMateria('enfermagem', 200));
    APP.aplicarFoco('caaq-cdm');
    const bl = bloco('enfermagem');
    t.igual(bl.peso, Math.min(bloco('portugues').peso, bloco('matematica').peso), 'peso do menor bloco da prova em foco');
    t.ok(bl.questoes < APP.META_DIARIA / 2, `cota de ${bl.questoes} pesa como matéria principal`);
    const lote = APP.montarLoteSessao('normal', null, new Set());
    const deEnf = lote.filter(id => APP.porId[id].m === 'enfermagem').length;
    t.ok(deEnf <= bl.questoes, `${deEnf} revisões passaram da cota ${bl.questoes}`);
    t.ok(novosDa(lote, 'matematica').length > 0, 'o atraso expulsou o cartão novo da prova em foco');
  });

  t.teste('recorte da prova em foco vale para o cartão novo, não para a revisão de outra seguida', async () => {
    /* CFAQ não cobra logaritmo; CDM cobra. Quem segue os dois não pode perder
       o que já aprendeu de logaritmo por estar focado no CFAQ. */
    await APP.montar({ concursos: ['cfaq-moc-mom', 'caaq-cdm'] });
    await semFila(async () => {
      APP.abrirEscada();
      const log = APP.BANCO.find(q => q.t === 'Álgebra' && q.s === 'Equações logarítmicas');
      t.ok(log, 'preciso de um cartão de logaritmo');
      vencer([log.id]);
      APP.aplicarFoco('cfaq-moc-mom');
      const mat = bloco('matematica');
      t.ok(!mat.soRevisao, 'Matemática está na prova em foco');
      const lote = APP.montarLoteSessao('normal', null, new Set());
      t.ok(lote.includes(log.id), 'a revisão de logaritmo tinha que entrar');
      const novos = novosDa(lote, 'matematica');
      t.ok(novos.length > 0, 'a prova em foco devia oferecer cartão novo de Matemática');
      novos.forEach(id => t.ok(APP.noEscopo(mat.topicos, APP.porId[id]),
        `cartão novo fora do recorte da prova em foco: ${APP.porId[id].t} / ${APP.porId[id].s}`));
    });
  });

  t.teste('depois de fechar a meta, a revisão continua e o cartão novo segue só da prova em foco', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    const ids = daMateria('enfermagem', 2);
    vencer(ids);
    APP.aplicarFoco('caaq-cdm');
    const h = APP.hoje();
    APP.E.diasMateria[h] = {};
    APP.BLOCOS_META.forEach(bl => { APP.E.diasMateria[h][bl.materias[0]] = bl.questoes; });
    const lote = APP.montarLoteSessao('normal', null, new Set());
    ids.forEach(id => t.ok(lote.includes(id), 'revisão vencida sumiu depois da meta'));
    t.igual(novosDa(lote, 'enfermagem').length, 0, 'cartão novo fora do foco entrou depois da meta');
    t.ok(novosDa(lote, 'matematica').length > 0, 'a prova em foco devia continuar oferecendo cartão novo');
  });

  t.teste('revisão já na sessão não abre vaga para cartão novo fora do foco', async () => {
    /* ao reabastecer, o que já está na lista vem em `excluir`: a cota do bloco
       continua aberta, e nada pode ocupar o lugar da revisão pendente */
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    const [id] = daMateria('enfermagem', 1);
    vencer([id]);
    APP.aplicarFoco('caaq-cdm');
    const lote = APP.montarLoteSessao('normal', null, new Set([id]));
    t.igual(novosDa(lote, 'enfermagem').length, 0, 'cartão novo entrou no lugar da revisão excluída');
  });

  t.teste('com um concurso só, depois da meta o resto da matéria continua liberado', async () => {
    await APP.montar({ concursos: ['cfaq-moc-mom'] });
    await semFila(async () => {
      APP.abrirEscada();
      APP.aplicarFoco('cfaq-moc-mom');
      const h = APP.hoje();
      APP.E.diasMateria[h] = {};
      APP.BLOCOS_META.forEach(bl => { APP.E.diasMateria[h][bl.materias[0]] = bl.questoes; });
      const lote = APP.montarLoteSessao('normal', null, new Set());
      t.ok(lote.some(id => APP.porId[id].s === 'Equações logarítmicas'),
        'o foco só restringe cartão novo quando há outra prova seguida');
    });
  });

  t.teste('sem foco nada é só de revisão, e com um concurso só o foco não muda nada', async () => {
    await APP.montar({ concursos: ['vr-enf-2026', 'caaq-cdm'] });
    APP.abrirEscada();
    vencer(daMateria('enfermagem', 1));
    APP.aplicarFoco(null);
    t.ok(APP.BLOCOS_META.every(b => !b.soRevisao), 'sem foco todas as matérias recebem cartão novo');

    await APP.montar({ concursos: ['cfaq-moc-mom'] });
    APP.abrirEscada();
    const fora = APP.BANCO.find(q => q.t === 'Álgebra' && q.s === 'Equações logarítmicas');
    vencer([fora.id]);
    APP.aplicarFoco('cfaq-moc-mom');
    const lote = APP.montarLoteSessao('normal', null, new Set());
    t.ok(!lote.includes(fora.id), 'sem outra prova seguida, o que está fora do recorte continua fora');
  });
  t.grupo('meta — matéria que espera a base de outra');

  /* a trava é dado, não nome de matéria: aqui Português espera a Aritmética */
  const comTrava = async (fn) => {
    const salvo = APP.REQ_MATERIA.portugues;
    APP.REQ_MATERIA.portugues = Object.assign({}, salvo, { trava_externa: { m: 'matematica', t: 'Aritmética', criterio: 'teste' } });
    try { await fn(); } finally { APP.REQ_MATERIA.portugues = salvo; APP.limparCacheGrau(); }
  };
  /* todo subtópico precisa estar dominado: a fila de subtópicos também trava */
  const dominar = (m, t) => {
    APP.BANCO.filter(q => q.m === m && q.t === t).forEach(q => {
      APP.E.cartoes[q.id] = { caixa: 3, acertos: 2, erros: 0, prox: '2099-01-01' };
    });
  };

  t.teste('enquanto a base não vem, a matéria não abre nem recebe cota', async () => {
    await APP.montar({ concursos: ['caaq-cdm'] });
    await comTrava(async () => {
      APP.limparCacheGrau();
      APP.aplicarFoco(null);
      t.ok(!bloco('portugues'), 'matéria travada com cota deixaria a meta impossível de fechar');
      t.igual(APP.BLOCOS_META.reduce((n, b) => n + b.questoes, 0), APP.META_DIARIA);
      t.ok(!APP.fila().novas.some(id => APP.porId[id].m === 'portugues'), 'cartão novo de matéria travada entrou na fila');
    });
  });

  t.teste('dominar a base abre a matéria', async () => {
    await APP.montar({ concursos: ['caaq-cdm'] });
    await comTrava(async () => {
      dominar('matematica', 'Aritmética');
      APP.limparCacheGrau();
      APP.aplicarFoco(null);
      t.ok(bloco('portugues'), 'com a base dominada, a matéria devia ganhar cota');
      t.ok(APP.fila().novas.some(id => APP.porId[id].m === 'portugues'), 'com a base dominada, devia haver cartão novo');
    });
  });

  t.teste('matéria já em andamento não volta a travar', async () => {
    await APP.montar({ concursos: ['caaq-cdm'] });
    await comTrava(async () => {
      const q = APP.BANCO.find(x => x.m === 'portugues');
      APP.E.cartoes[q.id] = { caixa: 1, acertos: 0, erros: 1, prox: APP.hoje() };
      APP.limparCacheGrau();
      APP.aplicarFoco(null);
      t.ok(bloco('portugues'), 'errar a base depois não pode esconder a matéria em andamento');
    });
  });

  t.teste('sem a matéria exigida no banco, a trava não se aplica', async () => {
    await APP.montar({ concursos: ['caaq-cdm'], materias: ['portugues'] });
    await comTrava(async () => {
      APP.limparCacheGrau();
      t.igual(APP.travaExternaPendente('portugues'), null, 'sem a base carregada não há como medir, e a matéria ficaria presa para sempre');
    });
  });
};
