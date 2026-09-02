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
        const existe = APP.BANCO.some(q => b.materias.includes(q.m) && q.t === tt);
        t.ok(existe, `escopo de "${b.nome}" cita tópico inexistente: "${tt}"`);
      }
    }
  });

  t.grupo('meta — matéria avulsa');

  t.teste('matéria avulsa vira bloco com peso próprio', async () => {
    await APP.montar({ concursos: [], avulsas: ['biologia-celular'] });
    const b = bloco('biologia-celular');
    t.ok(b, 'avulsa devia ter virado bloco da meta');
    t.igual(b.peso, APP.META_MATERIA_AVULSA);
  });

  t.teste('avulsa não depende de concurso nenhum', async () => {
    await APP.montar({ concursos: [], avulsas: ['biologia-celular'] });
    t.igual(APP.CONCURSO, null, 'sem concurso seguido, CONCURSO é null');
    t.igual(APP.BLOCOS, [], 'sem concurso, BLOCOS (da prova) fica vazio');
    t.ok(APP.BLOCOS_META.length > 0, 'mas BLOCOS_META tem o bloco sintético da avulsa');
  });

  t.teste('avulsa que também é matéria de concurso vale o maior peso', async () => {
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: [] });
    const doConcurso = bloco('portugues').peso;
    await APP.montar({ concursos: ['vr-enf-2026'], avulsas: ['portugues'] });
    const comAvulsa = bloco('portugues').peso;
    t.igual(comAvulsa, Math.max(doConcurso, APP.META_MATERIA_AVULSA), 'devia ser o maior, nunca a soma');
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
};
