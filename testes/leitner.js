/* Motor de repetição espaçada — CLAUDE.md, "Motor de repetição espaçada". */
module.exports = function (APP, t) {
  t.grupo('leitner');

  /* Fixa a prova a N dias de hoje. O intervalo do Leitner NÃO depende
     disto (ver os testes abaixo) — o que depende é diasAteMaisProxima(),
     que hoje serve só à tela. */
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

  t.teste('sem prova nenhuma, cada caixa vale o intervalo dela', () => {
    APP.INSCRITOS = [];
    const esperado = [0, 1, 3, 7, 14, 30, 60, 120];
    for (let caixa = 1; caixa <= APP.CAIXA_MAX; caixa++) {
      t.igual(APP.proximaData(caixa), APP.somarDias(APP.hoje(), esperado[caixa - 1]),
        `caixa ${caixa}`);
    }
  });

  t.teste('a proximidade da prova NÃO encurta intervalo nenhum', () => {
    /* O invariante central desta tela do motor: não existe teto dinâmico.
       Comprimir revisão na reta final só ajudaria quem tem capacidade
       sobrando, e aqui o gargalo é a capacidade (meta de 50/dia contra
       milhares de cartões) — cada slot gasto no que a pessoa já acertou
       4 ou 5 vezes sai de cartão nunca visto. Ver INTERVALOS e
       HISTORICO.md. */
    const esperado = [0, 1, 3, 7, 14, 30, 60, 120];
    for (const d of [0, 1, 2, 3, 5, 9, 10, 30, 90, 100, 900]) {
      provaEm(d);
      for (let caixa = 1; caixa <= APP.CAIXA_MAX; caixa++) {
        t.igual(APP.proximaData(caixa), APP.somarDias(APP.hoje(), esperado[caixa - 1]),
          `prova em ${d} dias, caixa ${caixa} deveria valer ${esperado[caixa - 1]} dias`);
      }
    }
  });

  t.teste('nenhuma caixa acima da 1 vence no mesmo dia', () => {
    /* Só a caixa 1 devolve HOJE. Se qualquer outra caísse em 0, o cartão
       voltaria para sempre no mesmo dia e a sessão nunca andaria. */
    for (const d of [0, 1, 2, 3, 10, 30, 100, 900]) {
      provaEm(d);
      for (let caixa = 2; caixa <= APP.CAIXA_MAX; caixa++) {
        t.ok(APP.proximaData(caixa) > APP.hoje(),
          `prova em ${d} dias, caixa ${caixa} caiu em hoje`);
      }
    }
  });

  t.teste('diasAteMaisProxima é a prova mais próxima, não a mais distante', () => {
    /* Quem pergunta é a tela: contagem regressiva e o aviso de backlog vs.
       tempo restante. Vale a mais próxima porque é a que aperta primeiro. */
    APP.INSCRITOS = [
      { id: 'longe', data: APP.somarDias(APP.hoje(), 900), blocos: [] },
      { id: 'perto', data: APP.somarDias(APP.hoje(), 9), blocos: [] },
    ];
    t.igual(APP.diasAteMaisProxima(), 9);
    t.igual(APP.proximaData(8), APP.somarDias(APP.hoje(), 120),
      'a prova perto não pode mexer no intervalo');
  });

  t.teste('prova já passada não gera número negativo', () => {
    provaEm(-30);
    t.igual(APP.diasAteMaisProxima(), 0);
    t.igual(APP.proximaData(8), APP.somarDias(APP.hoje(), 120));
  });

  t.grupo('previsão de revisão');

  /* O botão de resposta mostra quando o cartão volta ANTES de a pessoa
     escolher. Se a previsão e a gravação divergirem, o app mente no próprio
     botão que ela aperta. */

  t.teste('sabia sobe um degrau; chutei e errei voltam para a caixa 1', () => {
    t.igual(APP.caixaDepois(1, 'sabia'), 2);
    t.igual(APP.caixaDepois(5, 'sabia'), 6);
    t.igual(APP.caixaDepois(4, 'chutei'), 1, 'chutei não é acerto');
    t.igual(APP.caixaDepois(4, 'errei'), 1);
    t.igual(APP.caixaDepois(APP.CAIXA_MAX, 'sabia'), APP.CAIXA_MAX, 'não passa da caixa mais alta');
  });

  t.teste('a previsão bate com a data que registrar() grava', () => {
    APP.INSCRITOS = [];
    APP.E.cartoes = { x: { caixa: 3, acertos: 2, erros: 0, prox: '2020-01-01' } };
    t.igual(APP.previsaoRevisao('x', 'sabia').data, APP.proximaData(4), 'caixa 3 + sabia = caixa 4');
    t.igual(APP.previsaoRevisao('x', 'sabia').dias, 7);
    t.igual(APP.previsaoRevisao('x', 'errei').data, APP.hoje(), 'caixa 1 vence hoje');
    t.igual(APP.previsaoRevisao('x', 'errei').dias, 0);
    t.igual(APP.previsaoRevisao('x', 'chutei').dias, 0);
  });

  t.teste('cartão nunca respondido parte da caixa 1, igual a registrar()', () => {
    APP.INSCRITOS = [];
    APP.E.cartoes = {};
    t.igual(APP.previsaoRevisao('inedito', 'sabia').caixa, 2);
    t.igual(APP.previsaoRevisao('inedito', 'sabia').dias, 1, 'primeira vez que acerta: volta amanhã');
  });

  t.teste('a previsão não muda com a prova chegando perto', () => {
    /* mesma regra de proximaData(), pelo caminho que a tela usa: o botão
       promete 120 dias e são 120 dias, com a prova em 5 ou em 900. */
    APP.E.cartoes = { x: { caixa: 7, acertos: 9, erros: 0, prox: '2020-01-01' } };
    provaEm(5);
    t.igual(APP.previsaoRevisao('x', 'sabia').dias, 120, 'D-5: intervalo cheio mesmo assim');
    provaEm(900);
    t.igual(APP.previsaoRevisao('x', 'sabia').dias, 120, 'prova longe: intervalo cheio');
  });

  t.grupo('prioridade');

  t.teste('os descontos de erro e peso somam menos que uma caixa', () => {
    /* prioridade() hoje só desempata DENTRO da mesma caixa (critério 6 de
       ordenarRevisoes) — mas o número continua tendo de fazer sentido
       sozinho: 0.6 + 0.3 < 1, nunca atravessa a distância entre caixas. */
    APP.BLOCOS = [];
    APP.E.cartoes = {
      baixa: { caixa: 1, acertos: 9, erros: 0, prox: '2020-01-01' },
      alta: { caixa: 2, acertos: 0, erros: 9, prox: '2020-01-01' },
    };
    APP.porId.baixa = { id: 'baixa', m: 'x', t: 'y' };
    APP.porId.alta = { id: 'alta', m: 'x', t: 'y' };
    t.ok(APP.prioridade('baixa') < APP.prioridade('alta'),
      'desconto de caixa 2 só de erro passou da caixa 1 sem erro');
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


  t.grupo('ordem da revisão');

  /* Cenário sintético, do zero: matéria x com fila A → B → C e, dentro de A,
     fila de subtópicos s1 → s2; matéria y com fila P → Q (mais curta, para
     provar que a posição é FRAÇÃO da fila). Cada cartão é
     [id, m, t, s, n, caixa, erros]. Restaura banco e requisitos no fim,
     porque os outros testes não reindexam REQUISITOS ao montar. */
  function ordem(cartoes) {
    const salvo = { BANCO: APP.BANCO, REQ: APP.REQUISITOS, SUB: APP.REQUISITOS_SUB, BLOCOS: APP.BLOCOS };
    try {
      APP.BLOCOS = [];
      APP.REQUISITOS = { 'x|B': ['A'], 'x|C': ['B'], 'y|Q': ['P'] };
      APP.REQUISITOS_SUB = { 'x|A|s2': [{ t: 'A', s: 's1' }] };
      APP.BANCO = cartoes.map(([id, m, tt, s, n]) => {
        const q = { id, m, t: tt };
        if (s) q.s = s;
        if (n) q.n = n;
        return q;
      });
      APP.E.cartoes = {};
      cartoes.forEach(([id, , , , , caixa, erros]) => {
        APP.porId[id] = APP.BANCO.find(q => q.id === id);
        APP.E.cartoes[id] = { caixa, acertos: 3, erros: erros || 0, prox: '2020-01-01' };
      });
      return APP.ordenarRevisoes(cartoes.map(c => c[0]));
    } finally {
      cartoes.forEach(([id]) => delete APP.porId[id]);
      APP.BANCO = salvo.BANCO; APP.REQUISITOS = salvo.REQ;
      APP.REQUISITOS_SUB = salvo.SUB; APP.BLOCOS = salvo.BLOCOS;
      APP.E.cartoes = {};
    }
  }

  t.teste('caixa 1 (reaprendizado) vem antes de qualquer caixa de retenção', () => {
    /* mesmo sendo degrau 3 contra a base: errou ou chutou, revisa primeiro */
    t.igual(ordem([
      ['a', 'x', 'A', 's1', 1, 2],
      ['z', 'x', 'A', 's1', 3, 1],
    ]), ['z', 'a']);
  });

  t.teste('na retenção, caixa mais alta primeiro', () => {
    /* ids em ordem contrária à esperada: se a caixa não decidir, o id
       inverte tudo e o teste acusa */
    t.igual(ordem([
      ['a', 'x', 'A', 's1', 1, 2],
      ['b', 'x', 'A', 's1', 1, 3],
      ['c', 'x', 'A', 's1', 1, 6],
      ['d', 'x', 'A', 's1', 1, 1],
    ]), ['d', 'c', 'b', 'a']);
  });

  t.teste('mesma caixa: o degrau base vem antes, mesmo errando menos', () => {
    t.igual(ordem([
      ['a', 'x', 'A', 's1', 2, 4, 3],
      ['b', 'x', 'A', 's1', 1, 4, 0],
    ]), ['b', 'a']);
  });

  t.teste('degrau é RELATIVO ao recorte: sem nível 1, o 2 é a base', () => {
    /* s3 só tem nível 2 — é a base dele. Em s1 o nível 2 é o segundo
       degrau. Com o `n` puro os dois empatariam e o id poria 'a' na frente. */
    t.igual(ordem([
      ['a', 'x', 'A', 's1', 2, 4],
      ['a0', 'x', 'A', 's1', 1, 5],
      ['b', 'x', 'A', 's3', 2, 4],
    ]), ['a0', 'b', 'a']);
  });

  t.teste('mesma caixa e degrau: tópico do começo da fila vem antes', () => {
    t.igual(ordem([
      ['a', 'x', 'C', null, 1, 4],
      ['b', 'x', 'A', null, 1, 4],
      ['c', 'x', 'B', null, 1, 4],
    ]), ['b', 'c', 'a']);
  });

  t.teste('posição na fila é FRAÇÃO da fila da matéria', () => {
    /* x|B está no meio de uma fila de 3 (0.5); y|Q no fim de uma de 2 (1).
       Pela profundidade bruta os dois valem 1 e o id poria 'a' na frente. */
    t.igual(ordem([
      ['a', 'y', 'Q', null, 1, 4],
      ['b', 'x', 'B', null, 1, 4],
      ['c', 'x', 'C', null, 1, 4],
      ['d', 'y', 'P', null, 1, 4],
    ]), ['d', 'b', 'a', 'c']);
  });

  t.teste('mesmo tópico: subtópico anterior na fila vem antes', () => {
    t.igual(ordem([
      ['a', 'x', 'A', 's2', 1, 4],
      ['b', 'x', 'A', 's1', 1, 4],
    ]), ['b', 'a']);
  });

  t.teste('tudo empatado acima: quem erra mais vem primeiro', () => {
    t.igual(ordem([
      ['a', 'x', 'A', 's1', 1, 4, 0],
      ['b', 'x', 'A', 's1', 1, 4, 3],
    ]), ['b', 'a']);
  });

};
