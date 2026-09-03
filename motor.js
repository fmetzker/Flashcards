/* Motor de estudo — a lógica pura do app.
 *
 * O que mora aqui: Leitner, grafo de pré-requisito, escada de nível, meta do
 * dia, montagem da sessão e datas no fuso de Brasília. Nada mais.
 *
 * A REGRA DESTE ARQUIVO, e o testar.js reprova quem quebrar: **nenhuma
 * função daqui pode tocar DOM, localStorage, rede ou `window`**. Motor
 * decide o que estudar; quem pinta tela e quem fala com o servidor é o
 * index.html. Foi o que permitiu testar tudo isto fora do navegador.
 *
 * ESTADO. As variáveis que o motor lê (E, BANCO, porId, BLOCOS_META,
 * REQUISITOS...) continuam declaradas no index.html, de propósito: `let` e
 * `const` de topo vivem no ambiente léxico GLOBAL, compartilhado entre
 * <script> clássicos, então as funções daqui as enxergam normalmente. A
 * resolução acontece na CHAMADA, não na definição — por isso a ordem das
 * tags no HTML (motor.js antes) não cria problema de inicialização.
 *
 * Carregado por <script src> no index.html e embutido no offline.html pelo
 * gerar-offline.ps1. Sem export, sem módulo, sem build (regra 4).
 */

/* cota diária de cada matéria avulsa, tratada como bloco próprio dentro de
   blocosDaMeta() — ver o bloco de mesclagem logo abaixo */
const META_MATERIA_AVULSA = 20;

/* Blocos que valem para a META DIÁRIA — a união de TODOS os concursos
   inscritos, não só o que está em foco. Quem segue dois concursos precisa
   estudar os dois todo dia; antes a meta só enxergava o foco, e a matéria
   exclusiva do outro concurso não contava nada.

   Matéria repetida NÃO soma: Português cai nos cinco concursos cadastrados,
   e somar daria 50 questões/dia de Português. Fica valendo a MAIOR cota
   entre eles — estudar 10 de Português serve para as cinco provas ao mesmo
   tempo, não é trabalho multiplicado.

   O escopo de tópicos é UNIÃO, não "o do bloco que venceu". Os editais
   divergem de verdade: Português do Moço de Máquinas tem 8 itens e inclui
   gêneros textuais; o de nível superior tem 12 e inclui regência, colocação
   pronominal e coordenação/subordinação — mas NÃO cita gêneros. Nenhum é
   subconjunto do outro, então escolher "o maior" perderia conteúdo que cai
   numa das provas. Bloco sem `topicos` declarado significa matéria inteira,
   e nesse caso a união também é a matéria inteira. */
/* A meta diária é fixa — sempre META_DIARIA questões, não importa quantos
   concursos ou matérias avulsas a conta segue. Antes a meta era a SOMA das
   cotas do edital (podia ser 20, podia ser 90, crescia a cada concurso
   novo seguido); agora esse número vira só um PESO relativo, e
   blocosDaMeta() rateia META_DIARIA entre as matérias proporcionalmente a
   ele — ver apportion() logo abaixo. Substitui SESSAO_SEM_CONCURSO (não
   existe mais "tamanho de sessão menor por não ter prova nenhuma atrás":
   a meta é sempre esta, com ou sem concurso seguido). */
const META_DIARIA = 50;

/* Rateio proporcional de `total` (inteiro) entre `pesos`, sem perder nem
   sobrar unidade — método do maior resto (Hamilton): cada peso recebe o
   piso da parte exata que lhe cabe, e as unidades que sobraram (por causa
   do arredondamento) vão, uma a uma, para quem tem a MAIOR parte
   fracionária perdida. Empate desempata pela posição em `pesos` — nunca
   Math.random() (a mesma regra de determinismo de cmpId/embaralhaOrdem):
   apportion() roda de novo a cada boot/troca de foco, e um empate que
   sorteasse mudaria a cota de um dia pro outro sem a pessoa ter feito
   nada diferente. Peso 0 sempre fica com cota 0 — não participa da
   sobra. */
function apportion(pesos, total){
  const soma = pesos.reduce((a,b)=>a+b, 0);
  if(soma <= 0) return pesos.map(()=>0);
  const exato = pesos.map(p => total * p / soma);
  const piso = exato.map(Math.floor);
  const falta = total - piso.reduce((a,b)=>a+b, 0);
  const restos = exato
    .map((v,i)=> ({i, frac: v - piso[i]}))
    .filter(r=> pesos[r.i] > 0)
    .sort((a,b)=> b.frac - a.frac || a.i - b.i);
  const resultado = piso.slice();
  for(let k=0; k<falta; k++) resultado[restos[k].i]++;
  return resultado;
}

function blocosDaMeta(lista){
  const porMateria = {};                       // matéria -> bloco vencedor (peso = cota do edital/avulsa)
  const escopo = {};                           // matéria -> Set de tópicos, ou null = tudo
  const fonte = (lista && lista.length) ? lista
              : (INSCRITOS.length ? INSCRITOS : (CONCURSO ? [CONCURSO] : []));
  fonte.forEach(c=>{
    (c.blocos||[]).forEach(bl=>{
      (bl.materias||[]).forEach(m=>{
        const cota = bl.questoes || 0;
        if(!porMateria[m] || cota > porMateria[m].questoes){
          porMateria[m] = {id: bl.id, nome: bl.nome, questoes: cota, materias: [m]};
        }
        // união do escopo: um bloco sem 'topicos' abre a matéria inteira
        if(escopo[m] === null) return;
        if(!bl.topicos || !bl.topicos.length){ escopo[m] = null; return; }
        escopo[m] = escopo[m] || new Set();
        bl.topicos.forEach(t=> escopo[m].add(t));
      });
    });
  });
  /* Matéria avulsa entra como se fosse o próprio bloco de um concurso: peso
     fixo de META_MATERIA_AVULSA por matéria — antes avulsa só aparecia como
     contagem bruta, sem cota nenhuma ("sem contar pra meta"); virou bloco de
     verdade porque a pessoa marcou aquilo para estudar TODO dia, não só como
     sobra depois de fechar a cota do concurso.
     Se a matéria já tem bloco de algum concurso seguido, fica valendo o
     MAIOR peso entre o bloco do concurso e o peso fixo da avulsa — mesma
     regra de "matéria repetida não soma" que já vale entre concursos, agora
     estendida à avulsa. Escopo de tópicos sempre abre a matéria inteira:
     avulsa não tem edital nenhum limitando o que cai, então não faz sentido
     herdar o recorte de tópicos de um concurso que por acaso cobre a mesma
     matéria. */
  (E.materiasAvulsas||[]).forEach(m=>{
    if(!porMateria[m] || META_MATERIA_AVULSA > porMateria[m].questoes){
      porMateria[m] = {id: "avulsa", nome: (MATERIAS[m] && MATERIAS[m].nome) || m,
                        questoes: META_MATERIA_AVULSA, materias: [m]};
    }
    escopo[m] = null;
  });
  if(!Object.keys(porMateria).length) return [];   // nada seguido: nenhum peso pra ratear
  /* ORDEM_MATERIAS só decide a ORDEM de exibição — nunca quais matérias
     entram. Antes esta linha era `ORDEM_MATERIAS.filter(...)`, e quando a
     função rodava com a lista ainda vazia (o boot chamava aplicarFoco antes
     de carregar materias.json) o resultado era [] e a meta caía no fallback
     do concurso em foco, sem erro nenhum na tela. Matéria fora de
     ORDEM_MATERIAS agora vai para o fim em vez de sumir. A MESMA ordem
     também é o desempate de apportion() — deterministo dos dois lados. */
  const ordenadas = Object.keys(porMateria).sort((a,b)=>{
    const ia = ORDEM_MATERIAS.indexOf(a), ib = ORDEM_MATERIAS.indexOf(b);
    return (ia < 0 ? Infinity : ia) - (ib < 0 ? Infinity : ib);
  });
  const cotas = apportion(ordenadas.map(m=> porMateria[m].questoes), META_DIARIA);
  return ordenadas.map((m,i)=>{
    const bl = porMateria[m];
    const topicos = escopo[m] ? Array.from(escopo[m]) : null;
    /* `questoes` é a fatia renormalizada de META_DIARIA — não soma mais
       revisão pendente (isso virou ordem de apresentação dentro da cota,
       não quantidade a mais; ver montarLoteSessao). `peso` é o valor de
       ANTES do rateio (a cota do edital/avulsa, já com a regra de "matéria
       repetida não soma, vale a maior" aplicada) — exposto à parte porque é
       ele quem carrega essa regra; `questoes` sozinho não permite mais
       provar isso, já que dois pesos diferentes na mesma chamada podem virar
       a mesma cota final por causa do arredondamento. nome da MATÉRIA, não
       do bloco: "Conhecimentos específicos" é o nome de três blocos
       diferentes (um por concurso), cada um cobrindo uma matéria diferente —
       usar bl.nome fazia a meta do dia mostrar três linhas idênticas e
       impossíveis de distinguir. MATERIAS[m].nome é sempre único. */
    return {id: bl.id+"@"+m, nome: (MATERIAS[m] && MATERIAS[m].nome) || bl.nome,
            questoes: cotas[i], peso: bl.questoes, materias: [m], topicos};
  });
}

/* prova mais próxima entre os inscritos — é ela que representa o conjunto
   quando não há escopo escolhido (cabeçalho e contagem regressiva) */
function provaMaisProxima(){
  return INSCRITOS.reduce((a,c)=> (!a || diaUTC(c.data) < diaUTC(a.data)) ? c : a, null);
}

/* Escopo de estudo: null = estudar para TODOS os inscritos (meta somada);
   um id = estudar só para aquele concurso, e a meta encolhe para a dele.

   O banco carregado NÃO muda (isso é E.concursos, via materiasInscritas), só
   o que conta no dia — por isso trocar o escopo repinta em vez de recarregar.

   O teto do Leitner segue em diasAteMaisProxima(), sobre TODOS os inscritos,
   de propósito: estudar só para um concurso hoje não adia a prova do outro,
   e os cartões precisam continuar prontos para ela.

   Sem NENHUM concurso/processo seletivo seguido (só matéria avulsa, ou nada
   ainda) CONCURSO fica null — não existe prova nenhuma pra responder "qual
   prova?", e inventar uma (data, regra de aprovação) violaria a regra 11 do
   CLAUDE.md. Simulado e a pergunta "quantos dias faltam" ficam indisponíveis
   nesse estado (ver pintarInicio); "Estudar agora" continua funcionando,
   porque fila() só depende do banco carregado, não de CONCURSO. */
/* Achata REQ_MATERIA num mapa de consulta direta, uma vez no boot, porque
   topicoAberto() é chamado a cada montagem de fila e varrer o JSON aninhado
   a cada cartão seria desperdício.

   REQUISITOS["portugues|Crase"] = ["Classes de palavras", "Regência"]   */
/* REQUISITOS_SUB["matematica|Aritmética|Juros"] = [{"t":"Aritmética","s":"Porcentagem"}]
   — mesma ideia de REQUISITOS, um nível mais fundo: pré-requisito ENTRE
   SUBTÓPICOS do mesmo tópico (ou de outro), não mais só entre tópicos. Ver
   subtopicoAberto() logo abaixo e "Ordem de aprendizado" no CLAUDE.md. */
function indexarRequisitos(){
  REQUISITOS = {};
  REQUISITOS_SUB = {};
  Object.keys(REQ_MATERIA).forEach(mid=>{
    const req = REQ_MATERIA[mid].requisitos || {};
    Object.keys(req).forEach(t=>{ REQUISITOS[mid + "|" + t] = req[t] || []; });
    const reqSub = REQ_MATERIA[mid].requisitos_subtopicos || {};
    Object.keys(reqSub).forEach(chave=>{ REQUISITOS_SUB[mid + "|" + chave] = reqSub[chave] || []; });
  });
}

function grauDe(q){ return (q && q.n) || 1; }

/* Até que degrau deste tópico a pessoa já pode receber CARTÃO NOVO.

   Regra: o degrau k+1 abre quando TODO cartão de degrau k daquele tópico está
   na caixa 2 ou acima — ou seja, foi respondido e acertado sem chute na
   última vez ("Sabia" sobe de caixa; "Chutei" e "Errei" voltam para a 1).
   Reaproveita o estado do Leitner que já existe, em vez de inventar um
   segundo sistema de domínio que precisaria ser guardado e sincronizado.

   Cartão nunca visto não está dominado, então o degrau não avança — é o que
   faz a escada segurar de verdade. */
const _cacheGrau = {};

/* 's' é opcional: sem ele, mede o tópico inteiro (comportamento de sempre).
   Com 's', mede só os cartões daquele subtópico — usado por baseDominada()
   quando um pré-requisito aponta para {t, s} em vez de para o tópico
   inteiro (ver "Pré-requisito pode apontar para um subtópico" no CLAUDE.md).

   Anda pelos graus que EXISTEM de verdade nesse escopo (m/t/s), não pelos
   inteiros 1,2,3... Descoberto na auditoria de requisitos_subtopicos de
   agosto/2026: vários subtópicos (ex. Aritmética|Fatoração em números
   primos) só têm cartão de nível 2+, sem nenhum de nível 1 — a versão
   antiga travava g=1 pra sempre nesse caso (checava porGrau[1], achava
   undefined, e nunca chegava a olhar o nível 2 mesmo 100% dominado), o que
   deixava esses subtópicos (e, no caso pré-existente de
   Geometria|Geometria analítica, o TÓPICO Vetores inteiro, que exige esse
   subtópico) permanentemente travados. Andar pelos graus presentes em vez
   de incrementar 1 por 1 corrige isso e também sobrevive a um buraco no
   meio (nível 1 e 3 sem nível 2) — no caso comum, sem buraco nenhum, o
   resultado é idêntico ao de sempre. */
function grauLiberado(m, t, s){
  const chave = m + "|" + t + "|" + (s || "");
  if(chave in _cacheGrau) return _cacheGrau[chave];
  const porGrau = {};
  BANCO.forEach(q=>{
    if(q.m !== m || q.t !== t) return;
    if(s && q.s !== s) return;
    (porGrau[grauDe(q)] = porGrau[grauDe(q)] || []).push(q.id);
  });
  const graus = Object.keys(porGrau).map(Number).sort((a,b)=>a-b);
  let i = 0;
  while(i < graus.length && porGrau[graus[i]].every(id=>{
    const c = E.cartoes[id];
    return c && c.caixa >= 2;
  })) i++;
  // tudo dominado: sentinela "um grau além do último" (mesmo espírito do
  // g++ incondicional de sempre — nenhum cartão real tem esse nível)
  const g = i < graus.length ? graus[i] : (graus[graus.length-1] || 0) + 1;
  return _cacheGrau[chave] = g;
}

/* o cache vale por montagem de fila: responder um cartão muda o que está
   liberado, e a fila é remontada a cada sessão */
function limparCacheGrau(){
  for(const k in _cacheGrau) delete _cacheGrau[k];
  for(const k in _cacheMenorGrau) delete _cacheMenorGrau[k];
}

/* Menor grau que EXISTE de verdade no escopo m/t/s — quase sempre 1 (cartão
   sem 'n' vale 1), mas alguns subtópicos só têm cartão de nível 2+ (ver o
   comentário de grauLiberado() acima). "Base dominada" tem que comparar
   contra o piso REAL desse escopo, não contra o literal 1: senão, um
   subtópico sem nível 1 passaria a barra sem ninguém ter estudado nada
   (grauLiberado começa nesse piso mesmo com zero progresso), ou — se o
   comparador ficasse hardcoded alto demais — nunca passaria (o bug que
   motivou esta auditoria: Vetores, que exige Geometria|Geometria analítica,
   um subtópico só com nível 2 e 3, ficava travado para sempre). */
const _cacheMenorGrau = {};

function menorGrauExistente(m, t, s){
  const chave = m + "|" + t + "|" + (s || "");
  if(chave in _cacheMenorGrau) return _cacheMenorGrau[chave];
  let menor = null;
  BANCO.forEach(q=>{
    if(q.m !== m || q.t !== t) return;
    if(s && q.s !== s) return;
    const g = grauDe(q);
    if(menor === null || g < menor) menor = g;
  });
  return _cacheMenorGrau[chave] = (menor === null ? 1 : menor);
}

function baseDominada(m, dep){
  const t = typeof dep === "string" ? dep : dep.t;
  const s = typeof dep === "string" ? undefined : dep.s;
  /* {t,s}: a barra a vencer é a do SUBTÓPICO exigido (que já inclui, por
     baixo, o tópico dele estar aberto — ver subtopicoAberto()), não só o
     tópico inteiro. Mesma razão transitiva de sempre: sem isto, quem tem a
     caixa de um subtópico em dia por coincidência (histórico de antes da
     escada existir) abriria o que depende dele sem ter passado pela cadeia. */
  if(s){ if(!subtopicoAberto(m, t, s)) return false; }
  else{ if(!topicoAberto(m, t)) return false; }
  return grauLiberado(m, t, s) > menorGrauExistente(m, t, s);
}

/* Requisitos que ainda faltam para este tópico abrir; vazio = aberto. */
function requisitosPendentes(m, t){
  const req = REQUISITOS[m + "|" + t];
  if(!req || !req.length) return [];
  return req.filter(dep=> !baseDominada(m, dep));
}

function topicoAberto(m, t){ return requisitosPendentes(m, t).length === 0; }

function requisitosPendentesSub(m, t, s){
  const req = REQUISITOS_SUB[m + "|" + t + "|" + s];
  if(!req || !req.length) return [];
  return req.filter(dep=> !baseDominada(m, dep));
}

/* subtópico só abre se o TÓPICO dele já estiver aberto — a trava por
   subtópico é uma camada A MAIS, nunca um atalho que pule a de tópico. */
function subtopicoAberto(m, t, s){
  return topicoAberto(m, t) && requisitosPendentesSub(m, t, s).length === 0;
}

/* Rótulo de exibição de uma dependência pendente — string (tópico) sai como
   está; {t, s} vira "Subtópico (em Tópico)", senão a tela mostraria
   "[object Object]". */
function rotuloDep(d){ return typeof d === "string" ? d : d.s + " (em " + d.t + ")"; }

/* Cartão NOVO só entra com o tópico aberto, o subtópico aberto (quando tem
   `s` e há requisito para ele) E o degrau alcançado.

   O degrau é medido NO RECORTE MAIS FINO que o cartão tem: passar q.s aqui
   dá a cada subtópico a própria escada de nível, casada com a escada de
   desbloqueio. Medir pelo tópico inteiro empaca a escada e nunca destrava —
   é um bug real, ver HISTORICO.md. Cartão sem `s` cai no tópico inteiro
   automaticamente, que é o comportamento de sempre. */
function grauAberto(q){
  if(!topicoAberto(q.m, q.t)) return false;
  if(q.s && !subtopicoAberto(q.m, q.t, q.s)) return false;
  return grauDe(q) <= grauLiberado(q.m, q.t, q.s);
}

/* união das matérias de TODOS os concursos inscritos, MAIS as matérias
   avulsas — não só do que está em foco. Seguir dois concursos precisa trazer
   o conteúdo dos dois para a fila, senão "seguir" não significa nada além de
   trocar o cabeçalho; matéria avulsa entra do mesmo jeito, sem bloco nenhum
   por trás. */
function materiasInscritas(){
  const usadas = {};
  INSCRITOS.forEach(c=> c.blocos.forEach(b=> b.materias.forEach(m=>{ usadas[m] = true; })));
  E.materiasAvulsas.forEach(m=>{ usadas[m] = true; });
  return ORDEM_MATERIAS.filter(m=>usadas[m]);
}

const blocoDe = q => blocoDaMateria[q.m];

/* E.eventosProprios só cresce, e cada id é uma string de 36 caracteres.
   O comentário original estimava "poucos milhares em anos" — estimativa
   feita quando o banco era menor e a sessão terminava ao fim de um lote
   fixo. Com a sessão contínua e a meta somando revisão pendente, 40
   respostas por dia são ~570KB por ano só nesta lista; somada ao E.cartoes
   (uma entrada por cartão já visto) e aos quatro mapas de dias, o teto de
   ~5MB do localStorage deixa de ser teórico — e a falha de gravação é
   justamente a que salvar() passou a avisar, acima.

   Podar é seguro porque o id só serve numa janela curta: ele entra ao
   EMPURRAR e é consumido pelo PUXAR logo em seguida, dentro da mesma
   chamada de sincronizar(). Passado o cursor, o evento nunca mais volta e o
   id vira peso morto. O teto de 5.000 cobre milhares de ciclos de folga
   sobre essa janela de um; e só poda depois de um ciclo COMPLETO ter dado
   certo, que é o que garante que o cursor de fato avançou. */
const MAX_EVENTOS_PROPRIOS = 5000;

function podarEventosProprios(){
  const n = E.eventosProprios.length;
  if(n <= MAX_EVENTOS_PROPRIOS) return;
  E.eventosProprios = E.eventosProprios.slice(n - MAX_EVENTOS_PROPRIOS);
}

const FUSO_BRASILIA = "America/Sao_Paulo";

const fmtDiaBrasilia = new Intl.DateTimeFormat("en-CA", {timeZone: FUSO_BRASILIA, year:"numeric", month:"2-digit", day:"2-digit"});

const hoje = () => fmtDiaBrasilia.format(new Date());   // "AAAA-MM-DD", dia corrente em Brasília

/* "YYYY-MM-DD" -> Date ancorado em meia-noite UTC. Não é a mesma coisa que
   meia-noite de Brasília (são 3h de diferença), mas para SOMAR e COMPARAR
   datas isso não importa — o que importa é que todo o cálculo de calendário
   use sempre a mesma âncora, e nunca a hora local do aparelho. */
const diaUTC = txt => new Date(txt+"T00:00:00Z");

function somarDias(dataYMD, n){
  const d = diaUTC(dataYMD);
  d.setUTCDate(d.getUTCDate()+n);
  return d.toISOString().slice(0,10);
}

/* dias até a prova MAIS PRÓXIMA entre todos os inscritos. É este que manda no
   teto do Leitner: seguir um concurso distante não pode afrouxar a revisão
   por causa de outro que é semana que vem. */
function diasAteMaisProxima(){
  return INSCRITOS.reduce((menor,c)=>{
    const d = Math.max(0, Math.ceil((diaUTC(c.data) - diaUTC(hoje()))/86400000));
    return Math.min(menor, d);
  }, Infinity);
}

/* Leitner com teto: nenhum intervalo passa de 1/3 dos dias restantes.

   8 caixas — eram 5, com o intervalo travado em 14 dias pra sempre depois
   disso: quem acertava um cartão 10 vezes seguidas continuava revisando a
   cada 14 dias, sem o espaçamento crescer com o domínio. As 3 caixas novas
   (30/60/120 dias) dão o que fazer pro cartão bem sabido, e a distância
   praticamente dobra a cada caixa, igual a curva de esquecimento pede. O
   teto de 1/3 dos dias até a prova continua cortando essas caixas mais
   longas sozinho perto do exame — nada aqui precisou mudar pra isso valer:
   prova a 90 dias já limita a 30, então 60/120 só valem de verdade quando a
   prova está bem longe. */
const INTERVALOS = [0,1,3,7,14,30,60,120];

const CAIXA_MAX = INTERVALOS.length;   // caixa mais alta que existe

function proximaData(caixa){
  const d = diasAteMaisProxima();
  const teto = d<=10 ? 1 : Math.max(1, Math.floor(d/3));
  const inter = Math.min(INTERVALOS[Math.max(0,Math.min(CAIXA_MAX-1,caixa-1))], teto);
  return somarDias(hoje(), inter);
}

/* Prioridade dentro do que JÁ VENCEU (PADRAO-DOS-CARTOES.md, seção 4.2).

   Nada aqui adianta revisão: o espaçamento continua mandando em QUANDO o
   cartão volta. Isto decide só a ORDEM entre os que já venceram, para o caso
   comum de a fila ser maior que o tempo disponível — aí importa o que sai
   primeiro.

   Três critérios, nesta ordem de peso:

   1. CAIXA — quanto mais baixa, mais recente é a dificuldade. Continua sendo
      o sinal mais forte, como já era.
   2. TAXA DE ERRO da própria questão — duas questões na caixa 2 não são
      iguais: a que a pessoa já errou 4 vezes é mais urgente que a que ela
      errou uma. Só entra com histórico suficiente (3 respostas), senão uma
      única resposta azarada dominaria a ordem.
   3. PESO DO BLOCO na prova — desempate por onde vale mais ponto. É o critério
      mais fraco de propósito: peso de bloco não é sinal de dificuldade, só de
      retorno, e não deve passar na frente do que a pessoa não sabe.

   Os pesos (0.6 e 0.3) são calibrados para que a soma máxima do desconto
   fique ABAIXO de 1 — ou seja, abaixo da distância entre duas caixas. Sem
   isso, um cartão da caixa 2 que a pessoa erra muito passaria na frente de um
   da caixa 1, e caixa 1 quer dizer "errei na revisão mais recente", que é o
   sinal mais forte que existe. Erro histórico e peso do bloco ordenam DENTRO
   da caixa; nunca atravessam a fronteira dela. */
function prioridade(id){
  const c = E.cartoes[id];
  const respostas = c.acertos + c.erros;
  const erro = respostas >= 3 ? c.erros / respostas : 0;   // 0..1
  const bl = BLOCOS.find(b => b.id === blocoDe(porId[id]));
  const peso = bl ? bl.questoes / Math.max(1, E.meta) : 0; // 0..1
  return c.caixa - erro * 0.6 - peso * 0.3;
}

/* A ORDEM DO ARQUIVO NUNCA DECIDE NADA. Onde nenhum critério pedagógico
   distingue dois cartões, quem desempata é o id — e isso é um embaralhamento
   de graça: o id é o SHA-1 do enunciado truncado (regra 5), ou seja, um valor
   uniformemente aleatório sem relação nenhuma com o conteúdo do cartão nem
   com a posição dele no arquivo. Ordenar por id É embaralhar.

   Determinístico de propósito, em vez de Math.random(): fila() roda de novo a
   cada reabastecimento da sessão, então com sorteio a ordem mudaria no meio
   dela e nenhum teste conseguiria travar o comportamento. Sem semente, sem
   estado, igual para todo mundo.

   Isto NÃO é um segundo critério pedagógico por cima do que já existe — é o
   contrário: tira de cena um critério acidental (a ordem em que os cartões
   foram escritos no arquivo), que estava decidindo coisa que ninguém pediu.
   Sem ele, a tabuada saía 3x2, 3x3, 3x4... e dava pra responder somando o
   anterior em vez de lembrar. */
function cmpId(a, b){ return a < b ? -1 : a > b ? 1 : 0; }

function fila(){
  const h = hoje();
  limparCacheGrau();
  const revisar = [], novas = [];
  BANCO.forEach(q=>{
    const c = E.cartoes[q.id];
    /* cartão novo de degrau ainda fechado nem entra na fila: é o bloqueio da
       escada. Revisão vencida entra sempre, venha de que degrau vier. */
    if(!c){ if(grauAberto(q)) novas.push(q.id); }
    else if(c.prox <= h) revisar.push(q.id);
  });
  /* prioridade() continua mandando na revisão; o id só entra quando ela
     empata — e empata muito: todo cartão de mesma caixa, sem histórico de
     erro, do mesmo bloco, dá exatamente o mesmo número. */
  revisar.sort((a,b)=> prioridade(a) - prioridade(b) || cmpId(a,b));
  /* `novas` não tem critério nenhum acima do id: a ordem pedagógica já foi
     imposta pelo filtro acima — o cartão só chega aqui se o tópico dele
     estiver aberto E o degrau dele alcançado, e dentro de um mesmo recorte
     aberto todos os cartões novos são do mesmo degrau. Ordenar por um
     segundo critério de "nível" foi o que criou a incoerência que motivou a
     remoção das camadas entre tópicos; o id não é critério, é a ausência
     deliberada de um. */
  novas.sort(cmpId);
  return {revisar, novas};
}

/* Quanto do dia conta para a meta. Duas regras:

   1. Matéria fora de todos os blocos da meta não conta — senão quem segue
      dois concursos bateria a meta de um estudando só matéria do outro.
   2. Cada bloco tem teto próprio, a cota dele. Fazer 50 de Português numa
      cota de 10 conta 10, não 50: é o que faz a meta só fechar quando todas
      as áreas foram estudadas.

   Dois casos caem no `dias` bruto, sem detalhamento por matéria: dia
   anterior a diasMateria existir (retroagir seria inventar de qual matéria
   eram) e BLOCOS_META vazio (sem cota nenhuma para distribuir, contar tudo é
   melhor que travar em 0). O segundo hoje só acontece em estado transitório
   do boot ou para quem não segue nada — avulsa também vira bloco. */
function progressoDoDia(k){
  const porMat = E.diasMateria[k];
  if(!porMat || !BLOCOS_META.length) return E.dias[k] || 0;
  return BLOCOS_META.reduce((total, bl)=>{
    const feitas = bl.materias.reduce((n,m)=> n + (porMat[m]||0), 0);
    return total + Math.min(feitas, bl.questoes);
  }, 0);
}

function feitasHoje(){ return progressoDoDia(hoje()); }

/* detalhamento por bloco do dia de hoje, para a tela inicial mostrar onde
   ainda falta — devolve [{nome, feitas, cota, avulsa}] na ordem dos blocos
   da meta (união dos inscritos), não só do concurso em foco. `avulsa` marca
   os blocos sintéticos que blocosDaMeta() cria a partir de E.materiasAvulsas
   (id "avulsa"), só para o rótulo "· avulsa" na tela — a cota já é uma
   cota de verdade, tratada igual à de qualquer bloco de concurso. */
function progressoPorBloco(k){
  const porMat = E.diasMateria[k] || {};
  return BLOCOS_META.map(bl=>({
    nome: bl.nome,
    feitas: bl.materias.reduce((n,m)=> n + (porMat[m]||0), 0),
    cota: bl.questoes,
    avulsa: bl.id.indexOf("avulsa@") === 0
  }));
}

function resumoDoBanco(){
  const dados = {};
  BANCO.forEach(q=>{
    const d  = dados[q.m] = dados[q.m] || Object.assign(vazio(), {topicos:{}});
    const dt = d.topicos[q.t] = d.topicos[q.t] || Object.assign(vazio(), {subs:{}});
    const ds = q.s ? (dt.subs[q.s] = dt.subs[q.s] || vazio()) : null;
    const c = E.cartoes[q.id];
    [d, dt, ds].forEach(n=>{
      if(!n) return;
      n.total++;
      if(c){
        n.vistas++; n.ac += c.acertos; n.resp += c.acertos + c.erros;
        // "dominado" é o mesmo critério que grauLiberado usa pra destravar
        // degrau: caixa 2+ quer dizer "acertou sem chutar na última vez"
        if(c.caixa >= 2) n.dominados++;
      }
    });
    /* quanto do tópico (e, se houver subtópico, do PRÓPRIO subtópico) está
       atrás do degrau fechado, e quanto falta acertar pra abrir o próximo —
       a tela precisa dos dois pra explicar a trava. Grava nos dois níveis
       porque grauAberto() agora escala por subtópico quando o cartão tem um
       (ver comentário de grauAberto) — dt.graus fica pra tópico sem
       subtópico nenhum; ds.graus é o que trava de verdade quando existe. */
    const g = grauDe(q);
    dt.graus = dt.graus || {};
    const dg = dt.graus[g] = dt.graus[g] || {total:0, dominados:0};
    dg.total++;
    if(c && c.caixa >= 2) dg.dominados++;
    if(ds){
      ds.graus = ds.graus || {};
      const dgs = ds.graus[g] = ds.graus[g] || {total:0, dominados:0};
      dgs.total++;
      if(c && c.caixa >= 2) dgs.dominados++;
    }
  });

  /* Acrescenta o que o edital cobra e o banco ainda não cobre: tópico com
     total 0. Sem isto, item do conteúdo programático sem nenhum cartão fica
     invisível — que é justamente o pior caso descrito no Sinal 2 do
     PADRAO-DOS-CARTOES.md: estudar com sensação de cobertura completa e
     chegar na prova sem ter visto o assunto.

     Só entra matéria que a pessoa realmente segue (materiasInscritas), senão
     um concurso alheio encheria a tela de assunto que não vai cair. */
  materiasInscritas().forEach(mid=>{
    const oficial = TOPICOS_EDITAL[mid];
    if(!oficial || !oficial.topicos) return;
    const d = dados[mid] = dados[mid] || Object.assign(vazio(), {topicos:{}});
    oficial.topicos.forEach(t=>{
      d.topicos[t] = d.topicos[t] || Object.assign(vazio(), {subs:{}});
    });
  });
  return dados;
}

/* Profundidade de um tópico no grafo de requisitos.json: 0 para quem não
   exige nada, e 1 + a maior profundidade entre o que ele exige, senão.
   É a mesma leitura de "quantos elos da corrente até a raiz" — quanto
   maior, mais tarde a escada libera aquele tópico. memo evita recalcular
   o mesmo tópico váras vezes (grafo é uma árvore/DAG, não uma lista). */
function profundidadeTopico(mid, t, memo){
  const chave = mid+"|"+t;
  if(chave in memo) return memo[chave];
  memo[chave] = 0;   // guarda de recursão: requisitos.json circular já é barrado pelo validar
  const deps = REQUISITOS[chave] || [];
  const prof = deps.reduce((max, dep)=>{
    const tdep = typeof dep === "string" ? dep : dep.t;
    return Math.max(max, 1 + profundidadeTopico(mid, tdep, memo));
  }, 0);
  memo[chave] = prof;
  return prof;
}

/* ordena tópicos pela ordem em que a escada de pré-requisitos os libera —
   quem não depende de nada vem primeiro, cada um só depois de tudo que
   exige. Matéria sem requisitos.json cai toda na profundidade 0 e a ordem
   volta a ser só por tamanho, como já era antes desta função existir. */
function porDesbloqueio(mid, mapa){
  const memo = {};
  return Object.keys(mapa).sort((x,y)=>
    profundidadeTopico(mid, x, memo) - profundidadeTopico(mid, y, memo)
    || mapa[y].total - mapa[x].total
    || x.localeCompare(y,"pt")
  );
}

/* mesma ideia de profundidadeTopico(), um nível mais fundo: profundidade de
   um SUBTÓPICO no grafo de requisitos_subtopicos. Uma dependência de
   subtópico é sempre {t,s} (nunca string solta — ver _forma_do_item em
   requisitos.json), e pode apontar pra um subtópico de OUTRO tópico (ex.:
   Trigonometria usa {Geometria,Triângulos) — por isso recebe mid+t+s
   completos, não só s, e a recursão desce por dep.t/dep.s, não por `t`
   fixo. */
function profundidadeSubtopico(mid, t, s, memo){
  const chave = mid+"|"+t+"|"+s;
  if(chave in memo) return memo[chave];
  memo[chave] = 0;
  const deps = REQUISITOS_SUB[chave] || [];
  const prof = deps.reduce((max, dep)=>
    Math.max(max, 1 + profundidadeSubtopico(mid, dep.t, dep.s, memo)), 0);
  memo[chave] = prof;
  return prof;
}

/* ordena os subtópicos de UM tópico pela ordem em que a escada de
   requisitos_subtopicos os libera — mesma regra de porDesbloqueio(), um
   nível mais fundo. Tópico sem requisitos_subtopicos cai todo na
   profundidade 0 e a ordem volta a ser só por tamanho. */
function porDesbloqueioSub(mid, t, mapa){
  const memo = {};
  return Object.keys(mapa).sort((x,y)=>
    profundidadeSubtopico(mid, t, x, memo) - profundidadeSubtopico(mid, t, y, memo)
    || mapa[y].total - mapa[x].total
    || x.localeCompare(y,"pt")
  );
}

/* Monta um LOTE de ids para a sessão — usada tanto para abrir a sessão
   quanto para reabastecê-la sem fechar (ver responder()/registrar() mais
   abaixo). `excluir` é o Set de ids já usados NESTA sessão, pra nunca
   repetir cartão no mesmo dia por reabastecimento (a repetição proposital
   de cartão errado usa outro caminho — ver agendarRepeticao()).

   Sem adiantamento de revisão em lugar nenhum aqui (removido a pedido: com
   a sessão contínua, "faltou pra fechar a cota" deixou de ser problema —
   quem reabastece pega mais de outra matéria/tópico ainda aberto, e a
   sessão só termina quando isso também vier vazio; estudar cartão antes da
   hora só enfraquecia o espaçamento sem essa necessidade). */
function montarLoteSessao(modo, filtro, excluir){
  const q = fila();
  let lista = [];
  if(modo==="erros"){
    /* sem sort por id, isto sairia na ordem em que os cartões entraram no
       E.cartoes — outra ordem acidental, ver cmpId() */
    lista = Object.keys(E.cartoes).filter(id=>porId[id] && E.cartoes[id].caixa<=2 && E.cartoes[id].erros>0 && !excluir.has(id)).sort(cmpId);
  } else if(modo==="filtro"){
    /* uma matéria ou um tópico isolado: vale a mesma ordem do estudo normal —
       o que está vencido primeiro, depois o que nunca foi visto */
    const alvo = BANCO.filter(x =>
      x.m===filtro.m &&
      (!filtro.t || x.t===filtro.t) &&
      (!filtro.s || x.s===filtro.s));
    const h = hoje(), rev = [], nov = [];
    limparCacheGrau();
    alvo.forEach(x=>{
      if(excluir.has(x.id)) return;
      const c = E.cartoes[x.id];
      /* mesma escada do estudo normal: estudar um tópico pela tela Matérias
         não pode ser um atalho para pular o degrau de baixo */
      if(!c){ if(grauAberto(x)) nov.push(x.id); }
      else if(c.prox <= h) rev.push(x.id);
    });
    rev.sort((a,b)=> prioridade(a) - prioridade(b) || cmpId(a,b));   // mesma ordem do estudo normal
    nov.sort(cmpId);
    // revisão primeiro, cartão novo só se sobrar espaço — ver o comentário
    // no modo normal, mais abaixo, sobre a troca de intercalar() por isto
    lista = rev.concat(nov).slice(0, E.meta);
  } else {
    /* Monta a sessão RESPEITANDO A COTA DE CADA BLOCO DA META — a união dos
       concursos inscritos, não só o que está em foco. Antes isto seguia o
       foco, e quem seguia dois concursos nunca recebia a matéria exclusiva
       do outro; agora a sessão cobre tudo que a meta cobra, na mesma sessão.

       Sorteia dentro do escopo de tópicos do bloco, quando ele existe: um
       concurso pode cobrar só parte da matéria (Português do Moço de
       Máquinas não pede regência nem colocação pronominal). Sem `topicos`
       declarado, a matéria entra inteira.

       Cada bloco entra com o que ainda falta para fechar a cota dele. A
       cota (`bl.questoes`) é a fatia renormalizada da meta fixa — ver
       blocosDaMeta(). */
    const h = hoje();
    const porBloco = progressoPorBloco(h);
    /* Revisão vem antes de cartão novo em TODA a sessão, não só dentro de
       cada matéria. Por isso os dois lados são acumulados em listas
       separadas aqui e só concatenados no fim: antes, cada bloco entrava
       inteiro (`[revisões dele][novos dele]`) e a sessão saía
       `[LP: rev,novo][SUS: rev,novo][Enf: rev,novo]` — cartão NOVO de
       Português aparecia antes de revisão PENDENTE de Enfermagem, que é
       exatamente o que "conteúdo novo só se não tiver revisão pendente"
       não quer.

       QUEM ENTRA continua decidido pela cota de cada bloco (`falta`),
       igual a antes: isto muda só a ORDEM de apresentação. É o que mantém
       a meta honesta — tudo que entra na sessão conta em progressoDoDia(),
       que capa por bloco do mesmo jeito. Revisão que passa da cota da
       própria matéria continua esperando (e volta no fallback pós-meta,
       logo abaixo, que também serve revisão primeiro). */
    const revs = [], novs = [];
    BLOCOS_META.forEach((bl,i)=>{
      const falta = Math.max(0, bl.questoes - Math.min(porBloco[i].feitas, bl.questoes));
      if(!falta) return;
      const daArea = id => {
        const x = porId[id];
        if(!x || excluir.has(id) || bl.materias.indexOf(x.m) < 0) return false;
        return !bl.topicos || bl.topicos.indexOf(x.t) >= 0;
      };
      const rev = q.revisar.filter(daArea);
      const nov = q.novas.filter(daArea);
      /* `rev` já reflete só o que está pendente NESTA chamada (responder um
         cartão hoje tira ele daqui), então limitar por `falta` aqui já
         garante que a revisão sozinha nunca estoura a cota do bloco — não
         precisa do teto de 2x novos que blocosDaMeta() tinha antes.

         Se isso ainda ficar abaixo de `falta` (pouca revisão pendente E
         trava de degrau ou tópico recém-aberto com pouco cartão novo), o
         bloco simplesmente entra com menos que a cota — não completa com
         nada que ainda não venceu nem abriu. A sessão contínua reabastece
         de outra matéria/tópico depois; não precisa fingir que esta cota
         fechou hoje. */
      const parte = rev.slice(0, falta);
      revs.push.apply(revs, parte);
      novs.push.apply(novs, nov.slice(0, falta - parte.length));
    });
    /* As revisões saem reordenadas por prioridade() ENTRE as matérias, não
       agrupadas por matéria: uma vez que a fatia de cada bloco já foi
       escolhida, quem vem primeiro é quem prioridade() diz (caixa, taxa de
       erro, peso do bloco), como já valia dentro de cada matéria. Os novos
       continuam agrupados por matéria, na ordem de BLOCOS_META — ali não
       há urgência a comparar entre matérias, e agrupar mantém o estudo de
       conteúdo novo coeso. */
    revs.sort((a,b)=> prioridade(a) - prioridade(b) || cmpId(a,b));
    lista = revs.concat(novs);
    /* nenhuma cota aberta (meta do dia já fechada) ou nada nas matérias da
       prova: sobra tudo que a pessoa segue e ainda está vencido ou liberado,
       sem respeitar cota de bloco nenhuma — é o "continuar estudando depois
       de bater a meta", real, não adiantado. Termina de vez só quando isto
       também vier vazio. */
    if(lista.length===0){
      lista = q.revisar.filter(id=>!excluir.has(id)).concat(q.novas.filter(id=>!excluir.has(id)));
    }
  }
  return lista;
}

/* Errou ou chutou (não demonstrou saber de verdade): volta pra caixa 1 do
   Leitner como sempre (vale a partir de amanhã), E ganha uma repetição
   dentro da MESMA sessão, 5 a 10 cartões à frente — reforço de curto prazo,
   a pedido. Modo "erros" já É essa revisão, não duplica. Se errar de novo
   na repetição, agenda outra do mesmo jeito (auto-limitante na prática: a
   maioria acerta antes de virar um ciclo longo). */
function agendarRepeticao(id, resultado){
  if(resultado === "sabia" || !S || S.modo === "erros") return;
  const daqui = 5 + Math.floor(Math.random()*6);   // 5 a 10
  S.pendentes.push({id, apareceEm: S.pos + daqui});
}

function embaralhaOrdem(n){
  const p = Array.from({length:n}, (_,i)=>i);
  for(let i=p.length-1;i>0;i--){ const j=Math.floor(Math.random()*(i+1)); [p[i],p[j]]=[p[j],p[i]]; }
  return p;
}

/* Quantos cartões já respondidos vencem em cada balde de tempo, mais o que
   já está atrasado agora — só das matérias inscritas (mesmo escopo que o
   resto da tela usa). Não é a fila em si (que ainda respeita a trava de
   degrau para cartão NOVO): aqui a pergunta é só "quando isso vence", então
   nenhuma trava entra — revisão vencida nunca é travada (ver grauAberto),
   o forecast segue a mesma regra.

   As fronteiras (1, 7, 30, 120) não são números redondos escolhidos à toa:
   são os próprios intervalos do Leitner (INTERVALOS) — cada balde é onde
   uma caixa nova passa a vencer (caixa 3-4 → até 7 dias, caixa 5-6 → até
   30, caixa 7-8 → até 120). "Hoje"/"Amanhã" ficam isolados de propósito:
   são caixa 1 e caixa 2, a pressão mais imediata. Baldes são EXCLUSIVOS
   (cada cartão entra em um só), não cumulativos — um "em 8 a 30 dias"
   somado ao "hoje" daria a falsa impressão de que um inclui o outro.

   Perto da prova, o teto dinâmico (proximaData()) comprime intervalos que
   nominalmente seriam maiores — um cartão de caixa 7 (60 dias) pode vencer
   em 10 dias se a prova está logo ali. Isso é o comportamento CERTO: os
   baldes contam a data real (`prox`), não a caixa nominal, então mostram a
   pressão de verdade, não uma promessa que o teto vai quebrar depois. */
function revisoesPorDia(){
  const inscritas = materiasInscritas();
  const h = diaUTC(hoje());
  const b = {atrasadas:0, hoje:0, amanha:0, semana:0, mes:0, resto:0};
  Object.keys(E.cartoes).forEach(id=>{
    const x = porId[id];
    if(!x || inscritas.indexOf(x.m) < 0) return;
    const diff = Math.round((diaUTC(E.cartoes[id].prox) - h) / 86400000);
    if(diff < 0) b.atrasadas++;
    else if(diff === 0) b.hoje++;
    else if(diff === 1) b.amanha++;
    else if(diff <= 7) b.semana++;
    else if(diff <= 30) b.mes++;
    else b.resto++;   // 31 a 120 dias — INTERVALOS nunca passa de 120
  });
  const dias = [];
  if(b.atrasadas) dias.push({rotulo:"Atrasadas", n:b.atrasadas});
  dias.push({rotulo:"Hoje", n:b.hoje});
  dias.push({rotulo:"Amanhã", n:b.amanha});
  dias.push({rotulo:"Em 2 a 7 dias", n:b.semana});
  dias.push({rotulo:"Em 8 a 30 dias", n:b.mes});
  dias.push({rotulo:"Em 31 a 120 dias", n:b.resto});
  return dias;
}
