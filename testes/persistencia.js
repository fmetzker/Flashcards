/* Gravação do progresso — CLAUDE.md, regra 1 (o estado é chaveado pelo id
   real da conta) e o aviso de falha de gravação. */
const { carregarApp } = require('../testar.js');

module.exports = function (APP, t) {

  t.grupo('poda da lista de eventos próprios');

  t.teste('acima do teto, corta e mantém os MAIS RECENTES', () => {
    /* o id serve numa janela curta (empurra -> puxa de volta); o que é
       antigo já passou pelo cursor e virou peso morto no localStorage */
    APP.E.eventosProprios = Array.from({ length: 6000 }, (_, i) => 'id' + i);
    APP.podarEventosProprios();
    t.igual(APP.E.eventosProprios.length, APP.MAX_EVENTOS_PROPRIOS);
    t.igual(APP.E.eventosProprios[0], 'id1000', 'cortou pelo lado errado');
    t.igual(APP.E.eventosProprios[APP.MAX_EVENTOS_PROPRIOS - 1], 'id5999', 'perdeu o mais recente');
  });

  t.teste('abaixo do teto, não mexe', () => {
    APP.E.eventosProprios = ['a', 'b', 'c'];
    APP.podarEventosProprios();
    t.igual(APP.E.eventosProprios, ['a', 'b', 'c']);
  });

  t.teste('exatamente no teto, não mexe', () => {
    APP.E.eventosProprios = Array.from({ length: APP.MAX_EVENTOS_PROPRIOS }, (_, i) => 'x' + i);
    APP.podarEventosProprios();
    t.igual(APP.E.eventosProprios.length, APP.MAX_EVENTOS_PROPRIOS);
    t.igual(APP.E.eventosProprios[0], 'x0', 'não podia ter cortado nada');
  });

  t.grupo('falha ao gravar não pode ser silenciosa');

  t.teste('logado, o app avisa quando o localStorage recusa — uma vez só', () => {
    /* Precisa de uma sessão: deslogado, salvar() volta cedo de propósito
       ("nada a persistir ainda") e não há gravação para falhar. */
    const comConta = carregarApp({ sessao: true });
    t.ok(comConta.CHAVE, 'a sessão fingida devia ter produzido uma CHAVE');

    const avisos = [];
    /* o stub entra no CONTEXTO (o objeto global do script), que é de onde o
       app resolve a chamada — pôr em `comConta` não substituiria nada */
    comConta.__ctx.mostrarToast = m => avisos.push(m);
    comConta.__ctx.console = { warn() {}, log() {}, error() {} };
    comConta.__localStorage.setItem = () => { throw new Error('QuotaExceededError'); };

    comConta.salvar(); comConta.salvar(); comConta.salvar();

    t.ok(avisos.length >= 1, 'nenhum aviso foi emitido em 3 falhas seguidas');
    t.igual(avisos.length, 1, 'avisou mais de uma vez — vira ruído que se aprende a ignorar');
    t.ok(/espaço/i.test(avisos[0]), 'o aviso devia falar de espaço: ' + avisos[0]);

    /* voltando a gravar, o app pode avisar de novo numa falha futura */
    comConta.__localStorage.setItem = (k, v) => { comConta.__armazem[k] = String(v); };
    comConta.salvar();
    comConta.__localStorage.setItem = () => { throw new Error('QuotaExceededError'); };
    comConta.salvar();
    t.igual(avisos.length, 2, 'depois de voltar a gravar, uma falha nova tem que avisar de novo');
  });
};
