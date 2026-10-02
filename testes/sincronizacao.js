/* O que o pull traz do servidor para o progresso LOCAL — CLAUDE.md, "Painel
   de desempenho". A RLS diz o que a conta pode LER; para um aprovador isso é
   o log de todo mundo. O pull precisa trazer só o que é DELA. */
const { carregarApp } = require('../testar.js');

module.exports = function (APP, t) {

  async function appLogado() {
    const a = carregarApp({ sessao: true });
    await a.carregarConfig();
    a.SUPA = { url: 'https://exemplo.supabase.co', anonKey: 'anon' };
    a.__ctx.console = { warn() {}, log() {}, error() {} };
    /* o boot segue em segundo plano (verificarAprovador zera SOU_APROVADOR
       antes de perguntar ao servidor): sem esperar ele assentar, o que o
       teste liga aqui é desligado logo depois */
    await new Promise(r => setTimeout(r, 30));
    return a;
  }

  /* Servidor que se comporta como o de verdade para um APROVADOR: sem filtro
     de conta na URL, a policy "aprovador lê tudo" devolve as linhas de todo
     mundo; com `usuario_id=eq.X`, só as de X. */
  function servidorDeAprovador(a, linhas) {
    const urls = [];
    a.__ctx.fetch = (url, op) => {
      url = String(url);
      const metodo = (op && op.method) || 'GET';
      let corpo = [];
      const tabela = (url.match(/\/rest\/v1\/([a-z_]+)/) || [])[1];
      if (metodo === 'GET' && linhas[tabela]) {
        urls.push(url);
        const m = url.match(/usuario_id=eq\.([^&]+)/);
        corpo = linhas[tabela].filter(l => !m || l.usuario_id === decodeURIComponent(m[1]));
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(corpo) });
    };
    return urls;
  }

  const agora = new Date().toISOString();
  const evento = (id, usuario_id, questao_id) => ({
    id, usuario_id, questao_id, ts: agora, resultado: 'sabia', caixa_depois: 2,
    prox: '2099-01-01', criado_em: agora,
  });

  t.grupo('pull: só o que é da conta');

  t.teste('resposta de OUTRA conta não entra no progresso do aprovador', async () => {
    const a = await appLogado();
    a.E.cartoes = {}; a.E.dias = {}; a.E.diasTotal = {}; a.E.diasCertas = {}; a.E.diasMateria = {};
    const urls = servidorDeAprovador(a, {
      eventos_resposta: [
        evento('e-meu', 'conta-de-teste', 'q-minha'),
        evento('e-alheio', 'outra-conta', 'q-alheia'),
      ],
    });
    await a.puxarEventos();
    t.ok(urls.length > 0 && urls.every(u => u.includes('usuario_id=eq.conta-de-teste')),
      'o pull de eventos saiu sem filtro de conta');
    t.ok('q-minha' in a.E.cartoes, 'a resposta da própria conta devia entrar');
    t.ok(!('q-alheia' in a.E.cartoes), 'resposta de outra conta virou progresso desta');
    t.igual(a.E.dias[a.hoje()], 1, 'o dia contou resposta de outra conta');
  });

  t.teste('simulado de OUTRA conta não entra na lista do aprovador', async () => {
    const a = await appLogado();
    a.E.simulados = [];
    const urls = servidorDeAprovador(a, {
      simulados: [
        { id: 's-meu', usuario_id: 'conta-de-teste', data: '2026-10-01', acertos: 5, total: 10, concurso: 'x', criado_em: agora },
        { id: 's-alheio', usuario_id: 'outra-conta', data: '2026-10-01', acertos: 9, total: 10, concurso: 'x', criado_em: agora },
      ],
    });
    await a.puxarSimulados();
    t.ok(urls.length > 0 && urls.every(u => u.includes('usuario_id=eq.conta-de-teste')),
      'o pull de simulados saiu sem filtro de conta');
    t.igual(a.E.simulados.map(s => s.id), ['s-meu']);
  });

  t.grupo('reparo do aprovador: refaz o progresso pelo próprio log');

  /* Estado local "contaminado" de partida. corte = 1ª resposta do log
     (20/08), antes do início da importação alheia (29/08). */
  function estadoContaminado(a) {
    a.E.progressoZeradoEm = null;
    a.E.materiasZeradas = {};
    a.E.cartoes = {
      alheio: { caixa: 3, acertos: 1, erros: 0, prox: '2026-10-05', ts: '2026-09-15T12:00:00Z' },
      legado: { caixa: 4, acertos: 3, erros: 0, prox: '2026-09-01', ts: null },
      legadoTs: { caixa: 2, acertos: 1, erros: 0, prox: '2026-08-13', ts: '2026-08-10T12:00:00Z' },
      meu: { caixa: 5, acertos: 9, erros: 0, prox: '2026-12-01', ts: '2026-09-20T12:00:00Z' },
    };
    a.E.dias = { '2026-08-10': 7, '2026-09-15': 11 };
    a.E.diasTotal = { '2026-08-10': 7, '2026-09-15': 11 };
    a.E.diasCertas = { '2026-08-10': 5, '2026-09-15': 11 };
    a.E.diasMateria = { '2026-08-10': { portugues: 7 }, '2026-09-15': { portugues: 11 } };
    a.E.simulados = [];
    a.E.reparoPullConta = null;
    a.FILA = []; a.FILA_SIM = [];
  }
  const meusEventos = () => [
    { id: 'e1', questao_id: 'meu', ts: '2026-08-20T12:00:00+00:00', resultado: 'sabia', caixa_depois: 2, prox: '2026-08-23', criado_em: '2026-08-20T12:00:01+00:00' },
    { id: 'e2', questao_id: 'meu', ts: '2026-09-01T12:00:00+00:00', resultado: 'errei', caixa_depois: 1, prox: '2026-09-01', criado_em: '2026-09-01T12:00:01+00:00' },
  ];
  const materia = id => ({ meu: 'portugues', novo: 'portugues' })[id] || null;

  t.teste('tira o que veio de outra conta, guarda o pré-conta, refaz o próprio', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    const n = a.montarEstadoReconstruido(meusEventos(), [], {}, materia);
    t.igual(Object.keys(n.cartoes).sort(), ['legado', 'legadoTs', 'meu'], 'cartão alheio ficou, ou o pré-conta sumiu');
    t.igual([n.cartoes.meu.caixa, n.cartoes.meu.acertos, n.cartoes.meu.erros], [1, 1, 1],
      'o cartão próprio devia sair só do log (último evento: errei → caixa 1)');
    t.igual(n.dias, { '2026-08-10': 7, '2026-08-20': 1, '2026-09-01': 1 }, 'dias');
    t.igual(n.diasMateria['2026-09-01'], { portugues: 1 });
    t.ok(!('2026-09-15' in n.diasMateria), 'o dia das 11 respostas alheias continuou contando');
  });

  t.teste('zerar() vale: evento anterior ao marco não conta em nada', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    a.E.progressoZeradoEm = '2026-08-25T00:00:00.000Z';
    const n = a.montarEstadoReconstruido(meusEventos(), [], {}, materia);
    t.igual([n.cartoes.meu.acertos, n.cartoes.meu.erros], [0, 1], 'o acerto de antes do zerar voltou');
    t.ok(!('2026-08-20' in n.dias), 'o dia de antes do zerar voltou a contar');
  });

  t.teste('zerarMateria() vale: conta no dia, não volta o cartão', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    a.E.materiasZeradas = { portugues: '2026-09-10T00:00:00.000Z' };
    const n = a.montarEstadoReconstruido(meusEventos(), [], {}, materia);
    t.ok(!('meu' in n.cartoes), 'cartão de matéria zerada ressuscitou');
    t.igual(n.dias['2026-09-01'], 1, 'zerarMateria não apaga o dia estudado');
  });

  t.teste('enunciado reescrito: o evento antigo vai para o id novo', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    const evs = meusEventos().map(e => Object.assign({}, e, { questao_id: 'velho' }));
    const n = a.montarEstadoReconstruido(evs, [], { velho: 'novo' }, materia);
    t.ok('novo' in n.cartoes && !('velho' in n.cartoes), 'id antigo virou cartão órfão');
  });

  t.teste('simulados: os do log, os pré-conta e os ainda na fila', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    a.E.simulados = [
      { id: 's-alheio', data: '2026-09-10', acertos: 9, total: 10 },
      { id: 's-legado', data: '2026-08-01', acertos: 4, total: 10 },
      { id: 's-fila', data: '2026-10-01', acertos: 6, total: 10 },
    ];
    a.FILA_SIM = [{ id: 's-fila' }];
    const doLog = [{ id: 's-meu', data: '2026-09-05', acertos: 7, total: 10, concurso: 'x', criado_em: '2026-09-05T12:00:00+00:00' }];
    const n = a.montarEstadoReconstruido(meusEventos(), doLog, {}, materia);
    t.igual(n.simulados.map(x => x.id).sort(), ['s-fila', 's-legado', 's-meu']);
  });

  /* Servidor completo para sincronizar(): POST aceita, GET devolve o log da
     conta. `falharPush` simula a rede caindo no envio. */
  function servidorCompleto(a, { falharPush = false } = {}) {
    const gets = [];
    a.__ctx.fetch = (url, op) => {
      url = String(url);
      const metodo = (op && op.method) || 'GET';
      if (metodo === 'POST') {
        return Promise.resolve({ ok: !falharPush, status: falharPush ? 500 : 201, json: () => Promise.resolve([]) });
      }
      let corpo = [];
      if (metodo === 'GET') {
        gets.push(url);
        if (url.includes('/eventos_resposta') && !url.includes('criado_em=gt.')) corpo = meusEventos();
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(corpo) });
    };
    return gets;
  }

  t.teste('sincronizar() do aprovador repara uma vez, e só uma', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    a.FILA = [{ id: 'pendente', questao_id: 'meu', ts: '2026-09-01T13:00:00+00:00', resultado: 'sabia', caixa_depois: 2, prox: '2026-09-04' }];
    a.SOU_APROVADOR = true;
    const gets = servidorCompleto(a);
    await a.sincronizar();
    t.ok(a.E.reparoPullConta, 'o reparo não rodou');
    t.ok(!('alheio' in a.E.cartoes), 'cartão alheio sobreviveu ao reparo');
    t.ok(gets.some(u => u.includes('/eventos_resposta') && u.includes('usuario_id=eq.conta-de-teste')),
      'o reparo leu o log sem filtro de conta');
    const antes = gets.length;
    await a.sincronizar();
    t.ok(gets.slice(antes).every(u => !u.includes('offset=')), 'o reparo rodou de novo');
  });

  t.teste('quem não é aprovador não repara', async () => {
    const a = await appLogado();
    estadoContaminado(a);
    a.SOU_APROVADOR = false;
    servidorCompleto(a);
    await a.sincronizar();
    t.igual(a.E.reparoPullConta, null);
    t.ok('alheio' in a.E.cartoes, 'mexeu no estado de quem nunca importou nada alheio');
  });

  t.teste('envio falhou: não repara, não toca no estado', async () => {
    /* o log do servidor ainda não tem a fila desta conta — refazer agora
       apagaria a resposta que não subiu */
    const a = await appLogado();
    estadoContaminado(a);
    a.FILA = [{ id: 'pendente', questao_id: 'meu', ts: '2026-10-01T13:00:00+00:00', resultado: 'sabia', caixa_depois: 6, prox: '2026-11-30' }];
    a.SOU_APROVADOR = true;
    servidorCompleto(a, { falharPush: true });
    await a.sincronizar();
    t.igual(a.E.reparoPullConta, null, 'reparou sem ter enviado a fila');
    t.igual(a.E.cartoes.meu.caixa, 5, 'mexeu no estado mesmo com o envio falhando');
  });
};
