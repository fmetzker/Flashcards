/* Testes de comportamento do motor do app.
 *
 *   node testar.js            roda tudo
 *   node testar.js requisito  roda só os testes cujo nome casa com "requisito"
 *
 * POR QUE ISTO EXISTE. Até esta versão, nada conferia a CONDUTA do app: o
 * `validar.py` cuida do banco de questões e da configuração, e o `node
 * --check` dentro dele só olha sintaxe. Leitner, grafo de pré-requisito,
 * escada de nível, meta do dia, fuso de Brasília — tudo isso era verificado
 * à mão, no navegador, uma vez, e nunca mais. Regra escrita em prosa
 * envelhece calada; teste que falha, não. Cada caso aqui é uma regra do
 * CLAUDE.md em forma executável, e o nome do teste diz qual.
 *
 * COMO CARREGA O APP. Não há cópia do motor aqui, nem `motor.js` separado, e
 * isso é deliberado: o teste lê o PRÓPRIO `index.html`, extrai o bloco
 * <script> e roda dentro de um `vm` do node com o mínimo de browser fingido
 * (window, document, localStorage, navigator). Não existe versão de teste
 * que possa divergir da versão publicada — é o mesmo arquivo que vai pro ar.
 *
 * O banco de verdade entra por `window.DADOS`, o mesmo gancho que o
 * `offline.html` já usa (ver pega() no index.html): os testes rodam contra
 * banco/*.json reais, não contra dado inventado.
 *
 * SEM DEPENDÊNCIA (regra 4 do CLAUDE.md): só `node`, que o validar.py já
 * exige para o --check da sintaxe.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const RAIZ = __dirname;

/* ------------------------------------------------------------------ *
 * 1. Carregar o app dentro do node                                     *
 * ------------------------------------------------------------------ */

/* Os globais que os testes precisam ler e escrever. `let` no index.html
   precisa de get+set (o teste troca o valor inteiro); `const` só de get
   (são objetos mutados no lugar, nunca reatribuídos). */
const GLOBAIS_LET = [
  'BANCO', 'CONCURSO', 'BLOCOS', 'BLOCOS_META', 'ORDEM_MATERIAS', 'TOPICOS_EDITAL',
  'REQ_MATERIA', 'REQUISITOS', 'REQUISITOS_SUB', 'CONCURSOS', 'INSCRITOS', 'E', 'S',
  'SESSAO', 'SUPA',
];
const GLOBAIS_CONST = [
  'porId', 'MATERIAS', 'blocoDaMateria', 'INTERVALOS', 'CAIXA_MAX',
  'META_MATERIA_AVULSA', 'SESSAO_SEM_CONCURSO', 'FUSO_BRASILIA',
  'CHAVE', 'MAX_EVENTOS_PROPRIOS',
];
/* As funções puras do motor — nenhuma toca DOM nem localStorage. */
const FUNCOES = [
  'hoje', 'diaUTC', 'somarDias', 'proximaData', 'diasAteMaisProxima',
  'prioridade', 'fila', 'intercalar', 'cmpId',
  'indexarRequisitos', 'topicoAberto', 'subtopicoAberto',
  'requisitosPendentes', 'requisitosPendentesSub', 'baseDominada',
  'grauDe', 'grauLiberado', 'grauAberto', 'menorGrauExistente', 'limparCacheGrau',
  'profundidadeTopico', 'profundidadeSubtopico', 'porDesbloqueio', 'porDesbloqueioSub',
  'blocosDaMeta', 'revisaoPendenteDaMateria', 'progressoDoDia', 'progressoPorBloco',
  'feitasHoje', 'montarLoteSessao', 'agendarRepeticao', 'resumoDoBanco',
  'materiasInscritas', 'provaMaisProxima', 'blocoDe', 'embaralhaOrdem',
  'revisoesPorDia', 'aplicarFoco', 'carregarConfig', 'carregarBancoParcial',
  /* não são motor puro (tocam localStorage), mas o teste precisa alcançá-las */
  'salvar', 'podarEventosProprios', 'renovarSessao', 'chamarAuth',
  'sincronizarMateriasAtivas',
];

function lerDados() {
  const dados = {};
  const arquivos = [
    'concursos.json', 'supabase.json',
    'banco/materias.json', 'banco/indice-legado.json', 'banco/reescritas.json',
    'banco/topicos.json', 'banco/requisitos.json',
  ];
  const materias = JSON.parse(fs.readFileSync(path.join(RAIZ, 'banco/materias.json'), 'utf8'));
  for (const m of materias) arquivos.push('banco/' + m.id + '.json');
  for (const a of arquivos) {
    const p = path.join(RAIZ, a);
    if (!fs.existsSync(p)) throw new Error('arquivo ausente: ' + a);
    dados[a] = JSON.parse(fs.readFileSync(p, 'utf8'));
  }
  return dados;
}

/* elemento de DOM que aceita qualquer coisa sem fazer nada — o app monta
   tela em vários pontos do boot, e nenhum teste daqui olha pixel */
function elementoFalso() {
  const el = {
    style: {}, classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    dataset: {}, children: [], textContent: '', innerHTML: '', value: '',
    appendChild() {}, prepend() {}, remove() {}, setAttribute() {}, removeAttribute() {},
    addEventListener() {}, querySelector() { return elementoFalso(); },
    querySelectorAll() { return []; }, getBoundingClientRect() { return { height: 0, width: 0 }; },
    focus() {}, blur() {}, insertBefore() {}, replaceChildren() {},
  };
  return el;
}

/* `sessao: true` pré-carrega uma sessão fingida no localStorage ANTES do
   app subir. Muda o boot inteiro: CONTA_ID e CHAVE deixam de ser nulos, e
   com isso o caminho de gravação de progresso passa a existir — sem isso
   salvar() retorna cedo ("deslogado: nada a persistir") e não dá para
   testar o que ele faz quando o localStorage recusa. */
function carregarApp(opcoes = {}) {
  const html = fs.readFileSync(path.join(RAIZ, 'index.html'), 'utf8');
  const ini = html.lastIndexOf('<script>');
  const fim = html.lastIndexOf('</script>');
  if (ini < 0 || fim < 0) throw new Error('não achei o bloco <script> do index.html');
  /* Na MESMA ordem das tags do HTML: motor.js primeiro (só define), depois o
     bloco inline (que declara os globais e roda o boot). Ler os dois daqui,
     em vez de manter uma lista, é o que garante que o teste veja exatamente
     o que o navegador vê. */
  const motor = fs.readFileSync(path.join(RAIZ, 'motor.js'), 'utf8');
  const script = motor + String.fromCharCode(10) + html.slice(ini + '<script>'.length, fim);

  const armazem = {};
  if (opcoes.sessao) {
    const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64')
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const token = 'x.' + b64({ sub: 'conta-de-teste', email: 'teste@exemplo.com' }) + '.y';
    armazem['vr:sessao'] = JSON.stringify({ access_token: token, user_id: 'conta-de-teste' });
  }
  const localStorageFalso = {
    getItem: k => (k in armazem ? armazem[k] : null),
    setItem: (k, v) => { armazem[k] = String(v); },
    removeItem: k => { delete armazem[k]; },
    clear: () => { for (const k of Object.keys(armazem)) delete armazem[k]; },
  };
  const documentoFalso = {
    getElementById: () => elementoFalso(),
    querySelector: () => elementoFalso(),
    querySelectorAll: () => [],
    createElement: () => elementoFalso(),
    createDocumentFragment: () => elementoFalso(),
    addEventListener() {}, removeEventListener() {},
    body: elementoFalso(),
    documentElement: elementoFalso(),
    head: elementoFalso(),
  };

  const sandbox = {
    console,
    /* fetch nunca deveria ser chamado: window.DADOS cobre tudo que pega()
       precisa. Se for, é sinal de que o app passou a buscar algo novo — e
       aí o teste tem que saber, não engolir em silêncio. */
    fetch: () => Promise.reject(new Error('fetch inesperado no teste')),
    setTimeout, clearTimeout, setInterval, clearInterval,
    /* fetchComPrazo() usa AbortController; sem ele no sandbox a chamada
       estoura antes de chegar na rede e o teste passa por engano */
    AbortController, TypeError, Error,
    requestAnimationFrame: fn => setTimeout(fn, 0),
    localStorage: localStorageFalso,
    document: documentoFalso,
    navigator: { onLine: true },
    location: { protocol: 'http:', href: 'http://localhost/', hash: '' },
    history: { replaceState() {} },
    alert() {}, confirm: () => false, prompt: () => null,
    addEventListener() {}, removeEventListener() {},
    scrollTo() {}, scrollY: 0, matchMedia: () => ({ matches: false, addEventListener() {} }),
  };
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  sandbox.self = sandbox;
  sandbox.window.DADOS = lerDados();

  /* A linha de exportação é anexada DENTRO do mesmo escopo do script, que é
     a única forma de enxergar as ligações `let`/`const` de topo — elas não
     ficam no objeto global nem em vm.runInContext. */
  const exporta = `
;globalThis.__APP = {
  ${GLOBAIS_LET.map(g => `get ${g}(){return ${g}}, set ${g}(v){${g}=v}`).join(',\n  ')},
  ${GLOBAIS_CONST.map(g => `get ${g}(){return ${g}}`).join(',\n  ')},
  ${FUNCOES.join(', ')}
};`;

  const ctx = vm.createContext(sandbox);
  vm.runInContext(script + exporta, ctx, { filename: 'index.html', timeout: 20000 });
  const APP = ctx.__APP;
  /* o contexto do vm É o objeto global do script: declaração de função de
     topo (mostrarToast, salvar...) vira propriedade dele, então trocar
     ctx.mostrarToast substitui o que o app chama de verdade lá dentro —
     coisa que atribuir em APP não faz, porque APP é só a vitrine. */
  APP.__ctx = ctx;
  APP.__armazem = armazem;
  APP.__localStorage = localStorageFalso;

  /* Estado de partida para um teste: joga fora o progresso e o banco
     carregado, declara o que a conta segue e carrega as matérias pelo MESMO
     caminho que o app usa em produção (carregarBancoParcial). Devolve uma
     promessa porque esse caminho é assíncrono — com window.DADOS montado, o
     `await` resolve na primeira microtarefa, sem rede nenhuma. */
  APP.montar = async ({ concursos = [], avulsas = [], materias = [], cartoes = {} } = {}) => {
    /* concursos.json e requisitos.json chegam por carregarConfig(), que o
       boot dispara sozinho e sem await — esperar aqui é o que garante que
       CONCURSOS já esteja de pé antes do primeiro teste. Chamar de novo é
       inofensivo: a função relê window.DADOS e reatribui. */
    if (!APP.CONCURSOS.length) await APP.carregarConfig();
    APP.BANCO = [];
    for (const k of Object.keys(APP.porId)) delete APP.porId[k];
    APP.E.cartoes = cartoes;
    APP.E.dias = {}; APP.E.diasTotal = {}; APP.E.diasCertas = {}; APP.E.diasMateria = {};
    APP.E.concursos = concursos;
    APP.E.materiasAvulsas = avulsas;
    APP.E.escopoEstudo = null;
    APP.INSCRITOS = APP.CONCURSOS.filter(c => concursos.includes(c.id));
    const aCarregar = materias.length ? materias : APP.materiasInscritas();
    await APP.carregarBancoParcial(aCarregar);
    APP.aplicarFoco(null);
    APP.limparCacheGrau();
    return APP;
  };
  return APP;
}

/* ------------------------------------------------------------------ *
 * 2. Mini-framework                                                    *
 * ------------------------------------------------------------------ */

let passou = 0;
const falhas = [];
const filtro = process.argv[2];
let grupoAtual = '';

function grupo(nome) { grupoAtual = nome; }

/* Os testes correm em fila, um de cada vez, e não em paralelo: todos
   compartilham o mesmo `E`/`BANCO` (é um app de estado global), então dois
   rodando juntos pisariam no estado um do outro. `fn` pode ser assíncrona —
   montar() é. */
const fila = [];
function teste(nome, fn) {
  const cheio = grupoAtual + ' › ' + nome;
  if (filtro && !cheio.toLowerCase().includes(filtro.toLowerCase())) return;
  fila.push({ nome: cheio, fn });
}

async function correrFila() {
  for (const { nome, fn } of fila) {
    try {
      await fn();
      passou++;
    } catch (e) {
      falhas.push({ nome, erro: e.message, pilha: e.stack });
    }
  }
}

function ok(cond, msg) {
  if (!cond) throw new Error(msg || 'esperava verdadeiro');
}
function igual(obtido, esperado, msg) {
  const a = JSON.stringify(obtido), b = JSON.stringify(esperado);
  if (a !== b) throw new Error((msg ? msg + ': ' : '') + `esperava ${b}, veio ${a}`);
}
function naoIgual(obtido, indesejado, msg) {
  if (JSON.stringify(obtido) === JSON.stringify(indesejado)) {
    throw new Error((msg ? msg + ': ' : '') + `não podia ser ${JSON.stringify(indesejado)}`);
  }
}

module.exports = { carregarApp, grupo, teste, ok, igual, naoIgual };

/* ------------------------------------------------------------------ *
 * 3. Os testes                                                         *
 * ------------------------------------------------------------------ */

if (require.main === module) {
  (async () => {
    let APP;
    try {
      APP = carregarApp();
    } catch (e) {
      console.error('\nnão consegui carregar o index.html dentro do node:\n  ' + e.message);
      console.error(e.stack);
      process.exit(1);
    }

    const ferramentas = { grupo, teste, ok, igual, naoIgual };
    for (const arq of fs.readdirSync(path.join(RAIZ, 'testes')).filter(a => a.endsWith('.js')).sort()) {
      require(path.join(RAIZ, 'testes', arq))(APP, ferramentas);
    }
    await correrFila();

    console.log('');
    for (const f of falhas) {
      console.log('  FALHOU  ' + f.nome);
      console.log('          ' + f.erro);
    }
    const total = passou + falhas.length;
    console.log(`\n${passou}/${total} testes passaram`);
    if (falhas.length) {
      console.log(`${falhas.length} falha(s).`);
      process.exit(1);
    }
    console.log('Motor conferido.');
  })();
}
