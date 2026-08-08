/* Service worker do app de estudo.
   IMPORTANTE: ao publicar uma versão nova do index.html (por exemplo, com
   mais questões), troque o número da VERSAO abaixo. É isso que faz o
   aparelho baixar o arquivo novo em vez de continuar servindo o antigo. */

const VERSAO = "v170-eo-sesmt-completo-5-de-5";
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
  "./banco/topicos.json"
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
   continua servindo a versão antiga, e parece que a v25 nunca chegou. */
self.addEventListener("fetch", evento => {
  if (evento.request.method !== "GET") return;

  evento.respondWith(
    fetch(evento.request, { cache: "no-store" })
      .then(resposta => {
        if (resposta && resposta.status === 200 && resposta.type === "basic") {
          const copia = resposta.clone();
          caches.open(CACHE).then(cache => cache.put(evento.request, copia));
        }
        return resposta;
      })
      .catch(() => caches.match(evento.request))
  );
});
