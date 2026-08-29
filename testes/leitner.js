/* Motor de repetição espaçada — CLAUDE.md, "Motor de repetição espaçada". */
module.exports = function (APP, t) {
  t.grupo('leitner');

  /* Fixa a prova a N dias de hoje, que é o que manda no teto dinâmico
     (proximaData -> diasAteMaisProxima -> INSCRITOS). */
  function provaEm(dias) {
    APP.INSCRITOS = [{ id: 'teste', data: APP.somarDias(APP.hoje(), dias), blocos: [] }];
  }

  t.teste('8 caixas, nos intervalos 1/3/7/14/30/60/120', () => {
    t.igual(APP.INTERVALOS, [0, 1, 3, 7, 14, 30, 60, 120]);
    t.igual(APP.CAIXA_MAX, 8);
  });

  t.teste('CAIXA_MAX concorda com o check do Postgres', () => {
    /* supabase/schema.sql: check (caixa_depois between 1 and 8). Nada liga
       os dois automaticamente, e o Postgres RECUSA o evento se o cliente
       gravar caixa mais alta — a conta perderia a resposta em silêncio. */
    const fs = require('fs'), path = require('path');
    const sql = fs.readFileSync(path.join(__dirname, '..', 'supabase', 'schema.sql'), 'utf8');
    const m = sql.match(/caixa_depois\s+between\s+1\s+and\s+(\d+)/i);
    t.ok(m, 'não achei o check de caixa_depois no schema.sql');
    t.igual(Number(m[1]), APP.CAIXA_MAX, 'schema.sql e CAIXA_MAX divergiram');
  });

  t.teste('caixa 1 vence no MESMO dia — errou, revisa ainda hoje', () => {
    /* INTERVALOS[0] é 0, não 1: os sete intervalos que o CLAUDE.md cita
       (1/3/7/14/30/60/120) são das caixas 2 a 8. A caixa 1 é onde "chutei"
       e "errei" jogam o cartão, e ela devolve HOJE de propósito — o cartão
       continua vencido na fila do dia, em vez de sumir até amanhã. */
    APP.INSCRITOS = [];
    t.igual(APP.proximaData(1), APP.hoje());
  });

  t.teste('sem prova nenhuma, os intervalos valem sem teto', () => {
    APP.INSCRITOS = [];
    const esperado = [0, 1, 3, 7, 14, 30, 60, 120];
    for (let caixa = 1; caixa <= APP.CAIXA_MAX; caixa++) {
      t.igual(APP.proximaData(caixa), APP.somarDias(APP.hoje(), esperado[caixa - 1]),
        `caixa ${caixa}`);
    }
  });

  t.teste('teto dinâmico: nenhum intervalo passa de 1/3 dos dias restantes', () => {
    provaEm(90);   // teto = 30
    t.igual(APP.proximaData(8), APP.somarDias(APP.hoje(), 30), 'caixa 8 cortada em 30');
    t.igual(APP.proximaData(7), APP.somarDias(APP.hoje(), 30), 'caixa 7 cortada em 30');
    t.igual(APP.proximaData(6), APP.somarDias(APP.hoje(), 30), 'caixa 6 já vale 30');
    t.igual(APP.proximaData(4), APP.somarDias(APP.hoje(), 7), 'abaixo do teto, intacta');
  });

  t.teste('a partir de D-10 toda caixa acima da 1 vira revisão diária', () => {
    for (const d of [10, 5, 1, 0]) {
      provaEm(d);
      for (let caixa = 2; caixa <= APP.CAIXA_MAX; caixa++) {
        t.igual(APP.proximaData(caixa), APP.somarDias(APP.hoje(), 1),
          `prova em ${d} dias, caixa ${caixa} deveria ser diária`);
      }
      t.igual(APP.proximaData(1), APP.hoje(), `prova em ${d} dias, caixa 1 segue no mesmo dia`);
    }
  });

  t.teste('o teto nunca zera um intervalo que não era zero', () => {
    /* teto tem Math.max(1, ...): mesmo com a prova amanhã, caixa 2+ cai em
       1 dia, nunca em 0 — senão o cartão voltaria para sempre no mesmo dia. */
    for (const d of [0, 1, 2, 3, 10, 30, 100, 900]) {
      provaEm(d);
      for (let caixa = 2; caixa <= APP.CAIXA_MAX; caixa++) {
        t.ok(APP.proximaData(caixa) > APP.hoje(),
          `prova em ${d} dias, caixa ${caixa} caiu em hoje`);
      }
    }
  });

  t.teste('a prova mais próxima é que manda, não a mais distante', () => {
    /* "seguir um concurso distante não pode afrouxar a revisão por causa de
       outro que é semana que vem" */
    APP.INSCRITOS = [
      { id: 'longe', data: APP.somarDias(APP.hoje(), 900), blocos: [] },
      { id: 'perto', data: APP.somarDias(APP.hoje(), 9), blocos: [] },
    ];
    t.igual(APP.diasAteMaisProxima(), 9);
    t.igual(APP.proximaData(8), APP.somarDias(APP.hoje(), 1), 'D-9 deveria ser diária');
  });

  t.teste('prova já passada não gera intervalo negativo', () => {
    provaEm(-30);
    t.igual(APP.diasAteMaisProxima(), 0);
    t.igual(APP.proximaData(8), APP.somarDias(APP.hoje(), 1));
  });

  t.grupo('prioridade');

  t.teste('caixa baixa vem antes de caixa alta, sempre', () => {
    /* Os pesos de erro (0.6) e de bloco (0.3) somam menos de 1 de
       propósito: ordenam DENTRO da caixa e nunca atravessam a fronteira
       dela, porque caixa 1 é o sinal mais forte que o motor produz. */
    APP.BLOCOS = [];
    APP.E.cartoes = {
      baixa: { caixa: 1, acertos: 9, erros: 0, prox: '2020-01-01' },
      alta: { caixa: 2, acertos: 0, erros: 9, prox: '2020-01-01' },
    };
    APP.porId.baixa = { id: 'baixa', m: 'x', t: 'y' };
    APP.porId.alta = { id: 'alta', m: 'x', t: 'y' };
    t.ok(APP.prioridade('baixa') < APP.prioridade('alta'),
      'cartão de caixa 1 sem erro nenhum tem que vir antes de caixa 2 só de erro');
    delete APP.porId.baixa; delete APP.porId.alta;
  });

  t.teste('dentro da mesma caixa, quem erra mais vem primeiro', () => {
    APP.BLOCOS = [];
    APP.E.cartoes = {
      erra: { caixa: 3, acertos: 1, erros: 9, prox: '2020-01-01' },
      acerta: { caixa: 3, acertos: 9, erros: 1, prox: '2020-01-01' },
    };
    APP.porId.erra = { id: 'erra', m: 'x', t: 'y' };
    APP.porId.acerta = { id: 'acerta', m: 'x', t: 'y' };
    t.ok(APP.prioridade('erra') < APP.prioridade('acerta'));
    delete APP.porId.erra; delete APP.porId.acerta;
  });

  t.teste('taxa de erro só conta a partir de 3 respostas', () => {
    /* menos que isso é ruído: um erro em uma resposta não é "cartão difícil" */
    APP.BLOCOS = [];
    APP.E.cartoes = {
      novo: { caixa: 3, acertos: 0, erros: 2, prox: '2020-01-01' },
      velho: { caixa: 3, acertos: 0, erros: 3, prox: '2020-01-01' },
    };
    APP.porId.novo = { id: 'novo', m: 'x', t: 'y' };
    APP.porId.velho = { id: 'velho', m: 'x', t: 'y' };
    t.igual(APP.prioridade('novo'), 3, '2 respostas: erro ainda não pesa');
    t.ok(APP.prioridade('velho') < 3, '3 respostas: erro passa a pesar');
    delete APP.porId.novo; delete APP.porId.velho;
  });

  t.grupo('intercalar');

  t.teste('espalha as duas listas em vez de concatenar', () => {
    /* Sem isso, uma fila de revisão grande engolia a sessão inteira e
       cartão novo nunca aparecia. */
    const r = APP.intercalar(['r1', 'r2', 'r3', 'r4'], ['n1', 'n2']);
    t.igual(r.length, 6);
    t.ok(r.indexOf('n1') < 4, 'a primeira nova não pode ficar para o fim: ' + r.join(','));
  });

  t.teste('preserva a ordem interna de cada lista', () => {
    const r = APP.intercalar(['r1', 'r2', 'r3'], ['n1', 'n2']);
    t.ok(r.indexOf('r1') < r.indexOf('r2'), 'ordem da revisão trocou');
    t.ok(r.indexOf('r2') < r.indexOf('r3'), 'ordem da revisão trocou');
    t.ok(r.indexOf('n1') < r.indexOf('n2'), 'ordem das novas trocou');
  });

  t.teste('lista vazia de um lado devolve a outra intacta', () => {
    t.igual(APP.intercalar([], ['n1', 'n2']), ['n1', 'n2']);
    t.igual(APP.intercalar(['r1', 'r2'], []), ['r1', 'r2']);
    t.igual(APP.intercalar([], []), []);
  });

  t.teste('não perde nem duplica cartão', () => {
    const a = ['a1', 'a2', 'a3', 'a4', 'a5'], b = ['b1', 'b2'];
    const r = APP.intercalar(a, b);
    t.igual(r.length, a.length + b.length);
    t.igual(new Set(r).size, a.length + b.length, 'duplicou alguma coisa');
  });
};
