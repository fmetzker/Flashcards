/* Service worker do app de estudo.
   IMPORTANTE: ao publicar uma versão nova do index.html (por exemplo, com
   mais questões), troque o número da VERSAO abaixo. É isso que faz o
   aparelho baixar o arquivo novo em vez de continuar servindo o antigo. */

const VERSAO = "v277-id-do-cartao-na-tela";
const CACHE = "prova-enf-" + VERSAO;

const ARQUIVOS = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icone-192.png",
  "./icone-512.png",
  "./apple-touch-icon.png",
  /* o banco saiu de dentro do index.html na Fase 0 — sem estes arquivos
     no cache, o app não abre offline */
  "./concursos.json",
  "./supabase.json",
  "./banco/materias.json",
  "./banco/indice-legado.json",
  /* mapa de questões reescritas — sem ele no cache, abrir offline depois de
     uma correção de enunciado perderia o histórico daqueles cartões */
  "./banco/reescritas.json",
  /* árvore oficial do conteúdo programático — sem ele, a tela Matérias offline
     deixa de mostrar os tópicos do edital que ainda não têm cartão */
  "./banco/topicos.json",
  /* pré-requisitos entre tópicos — sem ele, o app offline deixa de travar
     tópico por dependência; só a escada interna do cartão continua valendo */
  "./banco/requisitos.json"
];

/* Instalação: baixa tudo e guarda.
   Os arquivos de matéria não são listados à mão: são lidos de materias.json,
   para que acrescentar uma matéria nova não exija lembrar de editar aqui. */
self.addEventListener("install", evento => {
  evento.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(ARQUIVOS)
        .then(() => fetch("./banco/materias.json"))
        .then(r => r.json())
        .then(materias => cache.addAll(materias.map(m => "./banco/" + m.id + ".json"))))
      .then(() => self.skipWaiting())
  );
});

/* Ativação: apaga caches de versões anteriores */
self.addEventListener("activate", evento => {
  evento.waitUntil(
    caches.keys()
      .then(nomes => Promise.all(
        nomes.filter(n => n.startsWith("prova-enf-") && n !== CACHE)
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

  const buscaNaRede = fetch(evento.request, { cache: "no-store" }).then(resposta => {
    if (resposta && resposta.status === 200 && resposta.type === "basic") {
      const copia = resposta.clone();
      caches.open(CACHE).then(cache => cache.put(evento.request, copia));
    }
    return resposta;
  });

  evento.respondWith(
    comPrazo(buscaNaRede, PRAZO_FETCH_MS).catch(() =>
      caches.match(evento.request).then(cacheado => cacheado || buscaNaRede)
    )
  );
});
