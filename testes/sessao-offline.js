/* Ficar sem internet NÃO pode deslogar ninguém.

   O app é um PWA feito para funcionar offline. renovarSessao() já apagou a
   sessão em qualquer erro — inclusive falha de rede — e isso derrubou o login
   de uma conta de verdade, com o papel de aprovador junto, só por abrir o app
   sem internet perto do token vencer. Ver HISTORICO.md. */
const { carregarApp } = require('../testar.js');

module.exports = function (APP, t) {

  /* sessão prestes a vencer: é o que faz verificarSessao() chamar
     renovarSessao() em vez de não fazer nada */
  function appQuaseVencido() {
    const a = carregarApp({ sessao: true });
    /* pelos acessores, NAO por a.__ctx.X: `let` de topo vive no escopo
       lexico, e atribuir no sandbox criaria uma propriedade que o script
       nao enxerga (mesma razao da regra 13) */
    a.SESSAO = { access_token: 'x.e30.y', refresh_token: 'r1',
                 expires_at: Date.now() + 1000 };
    a.SUPA = { url: 'https://exemplo.supabase.co', anonKey: 'anon' };
    a.__ctx.console = { warn() {}, log() {}, error() {} };
    return a;
  }

  t.grupo('sessão não cai por falta de rede');

  t.teste('falha de rede mantém a sessão', async () => {
    const a = appQuaseVencido();
    a.__ctx.fetch = () => Promise.reject(new TypeError('Failed to fetch'));
    await a.renovarSessao();
    t.ok(a.SESSAO !== null, 'sem internet não pode apagar a sessão');
    t.ok(a.__armazem['vr:sessao'], 'a sessão salva também tem que continuar lá');
  });

  t.teste('timeout da rede mantém a sessão', async () => {
    /* fetchComPrazo rejeita por prazo numa internet lenta que não caiu */
    const a = appQuaseVencido();
    a.__ctx.fetch = () => new Promise(() => {});   // nunca resolve
    const p = a.renovarSessao();
    await new Promise(r => setTimeout(r, 100));
        t.ok(a.SESSAO !== null, 'timeout não pode apagar a sessão');
  });

  t.teste('servidor 5xx mantém a sessão', async () => {
    /* problema do lado deles não é credencial ruim */
    const a = appQuaseVencido();
    a.__ctx.fetch = () => Promise.resolve({
      ok: false, status: 503, json: () => Promise.resolve({ msg: 'indisponível' }),
    });
    await a.renovarSessao();
    t.ok(a.SESSAO !== null, '503 não é credencial inválida');
  });

  t.teste('servidor recusando o refresh token (4xx) DESLOGA', async () => {
    /* o outro lado da regra: token revogado ou conta apagada tem que sair */
    const a = appQuaseVencido();
    a.__ctx.fetch = () => Promise.resolve({
      ok: false, status: 400,
      json: () => Promise.resolve({ error: 'invalid_grant' }),
    });
    await a.renovarSessao();
    t.igual(a.SESSAO, null, '4xx do GoTrue tem que deslogar');
    t.ok(!a.__armazem['vr:sessao'], 'e apagar a sessão salva');
  });
};
