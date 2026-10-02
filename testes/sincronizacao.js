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
};
