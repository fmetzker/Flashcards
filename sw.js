/* Service worker do app de estudo.
   IMPORTANTE: ao publicar uma versão nova do index.html (por exemplo, com
   mais questões), troque o número da VERSAO abaixo. É isso que faz o
   aparelho baixar o arquivo novo em vez de continuar servindo o antigo. */

const VERSAO = "v291-painel-descarta-id-fantasma";
const CACHE = "prova-enf-" + VERSAO;

/* Cache do BANCO (tudo debaixo de ./banco/) é separado do cache do APP, e
   com nome ESTÁVEL — não leva VERSAO, não é apagado a cada deploy.

   Antes, os dois viviam juntos em `CACHE` (nome com VERSAO): activate()
   apagava o cache da versão anterior por completo a cada bump, e como
   VERSAO muda a cada mudança de index.html (regra 2 do CLAUDE.md, ~3x/dia
   neste repositório), o banco inteiro — hoje 3,6 MB em 10 matérias — era
   rebaixado do zero a cada deploy de CÓDIGO, mesmo quando nenhuma questão
   tinha mudado. Com o cache separado, só o app shell (pequeno) se refaz a
   cada deploy; o banco só é rebaixado arquivo por arquivo quando aquela
   matéria específica muda de verdade (o handler de fetch abaixo já
   reescreve o cache certo a cada resposta de rede, então isso já acontece
   sozinho em uso normal — nenhuma lógica nova precisou entrar ali). */
const CACHE_BANCO = "prova-enf-banco";

const ARQUIVOS = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icone-192.png",
  "./icone-512.png",
  "./apple-touch-icon.png",
  /* o banco (banco/*.json) saiu daqui — cacheado à parte, em CACHE_BANCO,
     abaixo */
  "./concursos.json",
  "./supabase.json"
];

/* Instalação: baixa e guarda os dois caches em paralelo.
   Os arquivos de matéria não são listados à mão: são lidos de materias.json,
   para que acrescentar uma matéria nova não exija lembrar de editar aqui.
   materias.json, indice-legado.json, reescritas.json, topicos.json e
   requisitos.json vão todos para CACHE_BANCO — são dado do banco, não
   código do app, e sem eles o app offline perde peça (matérias, migração de
   progresso, histórico de questão reescrita, árvore do edital, travas de
   pré-requisito, respectivamente). */
self.addEventListener("install", evento => {
  evento.waitUntil(
    Promise.all([
      caches.open(CACHE).then(cache => cache.addAll(ARQUIVOS)),
      caches.open(CACHE_BANCO).then(cache => cache.addAll([
        "./banco/materias.json",
        "./banco/indice-legado.json",
        "./banco/reescritas.json",
        "./banco/topicos.json",
        "./banco/requisitos.json"
      ]).then(() => fetch("./banco/materias.json"))
        .then(r => r.json())
        .then(materias => cache.addAll(materias.map(m => "./banco/" + m.id + ".json"))))
    ]).then(() => self.skipWaiting())
  );
});

/* Ativação: apaga caches de versões anteriores do APP — nunca CACHE_BANCO,
   que não tem versão e não deve ser apagado por deploy de código nenhum. */
self.addEventListener("activate", evento => {
  evento.waitUntil(
    caches.keys()
      .then(nomes => Promise.all(
        nomes.filter(n => n.startsWith("prova-enf-") && n !== CACHE && n !== CACHE_BANCO)
             .map(n => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

/* Busca: tenta a rede primeiro e usa o cache como reserva.
   Era o contrário até a v14 — cache primeiro. Isso fazia o aparelho continuar
   servindo a versão antiga do index.html mesmo depois de publicar uma nova, e
   trocar a VERSAO aqui não bastava para resolver: o service worker velho
   respondia antes. Como o app passou a assumir que há rede, rede-primeiro
   custa pouco e acaba com esse problema. Sem internet, o cache assume e o app
   continua abrindo.

   {cache:"no-store"} é essencial aqui: o GitHub Pages manda
   Cache-Control: max-age=600 em tudo, e sem isso o fetch() abaixo pode ser
   respondido pela própria memória de cache HTTP do navegador — uma camada
   ABAIXO deste service worker — sem sequer sair pro ar. "Rede primeiro"
   só é rede primeiro de verdade se a chamada ignorar esse cache; do
   contrário, fechar e reabrir o app dentro da mesma janela de 10 minutos
   continua servindo a versão antiga, e parece que a v25 nunca chegou.

   PRAZO_FETCH_MS existe porque "rede primeiro" tem um furo: fetch() só cai
   pro catch() quando a rede FALHA (caiu, DNS, CORS), nunca quando ela só está
   LENTA. Numa internet limitada — que não caiu, só demora — a promessa fica
   pendurada e o app trava na tela de "carregando" pra sempre, sem cair pro
   cache nunca. Por isso a rede corre contra um prazo: se ela não responder a
   tempo, o cache assume na hora (se tiver algo pra servir) e a rede continua
   em segundo plano só pra atualizar o cache pro próximo carregamento. No
   PRIMEIRO acesso — sem nada em cache ainda — não tem pra onde cair: o prazo
   estourar aí só faz esperar a mesma promessa de rede que já estava a
   caminho, em vez de abrir mão dela (desistir teria só trocado uma espera
   por um erro, sem ganhar nada). */
const PRAZO_FETCH_MS = 4000;
function comPrazo(promessa, ms){
  return new Promise((resolve, reject) => {
    const alarme = setTimeout(() => reject(new Error("timeout")), ms);
    promessa.then(
      v => { clearTimeout(alarme); resolve(v); },
      e => { clearTimeout(alarme); reject(e); }
    );
  });
}

self.addEventListener("fetch", evento => {
  if (evento.request.method !== "GET") return;

  // grava no cache do BANCO ou do APP conforme a URL — é isso que mantém
  // CACHE_BANCO sempre fresco sozinho, sem precisar de lógica de "matéria
  // mudou" nenhuma: toda resposta de rede boa já atualiza o cache certo.
  const alvo = evento.request.url.indexOf("/banco/") !== -1 ? CACHE_BANCO : CACHE;
  const buscaNaRede = fetch(evento.request, { cache: "no-store" }).then(resposta => {
    if (resposta && resposta.status === 200 && resposta.type === "basic") {
      const copia = resposta.clone();
      caches.open(alvo).then(cache => cache.put(evento.request, copia));
    }
    return resposta;
  });

  evento.respondWith(
    comPrazo(buscaNaRede, PRAZO_FETCH_MS).catch(() =>
      // sem cache específico: caches.match() varre todos os caches abertos,
      // então funciona igual estivesse em CACHE ou em CACHE_BANCO
      caches.match(evento.request).then(cacheado => cacheado || buscaNaRede)
    )
  );
});
