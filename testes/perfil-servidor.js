/* O que o app grava em `perfis` — os dois campos de que o Painel de
   desempenho depende.

   A armadilha, já paga duas vezes: num PATCH do PostgREST, mandar um valor
   VAZIO não é "não mexe nisso", é APAGA. Ver HISTORICO.md. */
const { carregarApp } = require('../testar.js');

module.exports = function (APP, t) {

  async function appLogado() {
    const a = carregarApp({ sessao: true });
    /* materiasInscritas() filtra por ORDEM_MATERIAS, que só existe depois do
       carregarConfig() — sem esperar, a lista sai vazia por acidente e o
       teste passa sem exercitar nada */
    await a.carregarConfig();
    a.SUPA = { url: 'https://exemplo.supabase.co', anonKey: 'anon' };
    a.__ctx.console = { warn() {}, log() {}, error() {} };
    return a;
  }

  /* Captura só o PATCH em `perfis`. Filtrar importa: a cadeia de boot segue
     rodando em segundo plano (situação, revisor, aprovador, sincronizar) e
     também passa por aqui — sem o filtro, o teste conta o tráfego errado. */
  function espiarPatch(a) {
    const enviados = [];
    a.__ctx.fetch = (url, op) => {
      const metodo = (op && op.method) || 'GET';
      if (metodo === 'PATCH' && String(url).includes('/perfis')) {
        enviados.push({ url: String(url), corpo: op.body ? JSON.parse(op.body) : null });
      }
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve([]) });
    };
    return enviados;
  }

  t.grupo('perfis: PATCH não pode apagar o que não sabe');

  t.teste('lista de matérias vazia NÃO é enviada', async () => {
    /* conta que acabou de entrar e ainda não escolheu concurso; basta a rede
       voltar nesse instante (listener de 'online') para o PATCH sair */
    const a = await appLogado();
    a.INSCRITOS = [];
    a.E.materiasAvulsas = [];
    a.E.progressoZeradoEm = null;
    const enviados = espiarPatch(a);
    await a.sincronizarMateriasAtivas();
    t.igual(enviados.length, 0, 'não podia ter mandado PATCH nenhum: apagaria a lista boa do servidor');
  });

  t.teste('lista com matérias É enviada', async () => {
    const a = await appLogado();
    a.INSCRITOS = [];
    a.E.materiasAvulsas = ['portugues'];
    a.E.progressoZeradoEm = null;
    const enviados = espiarPatch(a);
    await a.sincronizarMateriasAtivas();
    t.igual(enviados.length, 1, 'lista não-vazia tem que ser sincronizada');
    t.igual(enviados[0].corpo.materias_ativas, ['portugues']);
    t.ok(!('progresso_zerado_em' in enviados[0].corpo), 'sem marco local, o campo não vai junto');
  });

  t.teste('marco de reset vazio NÃO é enviado', async () => {
    const a = await appLogado();
    a.INSCRITOS = [];
    a.E.materiasAvulsas = ['portugues'];
    a.E.progressoZeradoEm = null;
    const enviados = espiarPatch(a);
    await a.sincronizarMateriasAtivas();
    t.ok(!('progresso_zerado_em' in enviados[0].corpo),
      'null num PATCH apaga o marco do servidor — nem quando é o único campo');
  });

  t.teste('marco de reset de verdade É enviado', async () => {
    const a = await appLogado();
    a.INSCRITOS = [];
    a.E.materiasAvulsas = ['portugues'];
    a.E.progressoZeradoEm = '2026-08-01T10:00:00.000Z';
    const enviados = espiarPatch(a);
    await a.sincronizarMateriasAtivas();
    t.igual(enviados[0].corpo.progresso_zerado_em, '2026-08-01T10:00:00.000Z');
  });
};
