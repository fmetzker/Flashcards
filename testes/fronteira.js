/* A fronteira do motor.js, imposta em vez de só documentada.

   Antes desta separação, nada impedia uma função do motor de chamar
   document.getElementById — e a única coisa que segurava era disciplina.
   Aqui a regra vira teste: motor decide o que estudar, index.html pinta tela
   e fala com o servidor. */
const fs = require('fs');
const path = require('path');

module.exports = function (APP, t) {
  const RAIZ = path.join(__dirname, '..');
  const motor = fs.readFileSync(path.join(RAIZ, 'motor.js'), 'utf8');

  /* tira comentários antes de procurar: o cabeçalho do arquivo CITA
     "document" e "localStorage" ao explicar a regra, e isso não é violação */
  const codigo = motor
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');

  t.grupo('fronteira do motor');

  const proibidos = [
    ['document', /\bdocument\s*\./],
    ['localStorage', /\blocalStorage\s*\./],
    ['window', /\bwindow\s*\./],
    ['fetch', /\bfetch\s*\(/],
    ['alert/confirm/prompt', /\b(alert|confirm|prompt)\s*\(/],
    ['chamarRest', /\bchamarRest\s*\(/],
    ['caches', /\bcaches\s*\./],
  ];

  for (const [nome, re] of proibidos) {
    t.teste(`motor.js não toca ${nome}`, () => {
      const m = codigo.match(re);
      t.ok(!m, `motor.js usa ${nome} — isso é camada de tela/rede, não de motor`);
    });
  }

  t.teste('motor.js é carregado antes do bloco inline do index.html', () => {
    /* a ordem importa: motor.js só DEFINE (as funções não rodam na carga),
       e o bloco inline declara os globais e dispara o boot */
    const html = fs.readFileSync(path.join(RAIZ, 'index.html'), 'utf8');
    const tag = html.indexOf('<script src="motor.js"></script>');
    t.ok(tag > 0, 'não achei a tag do motor.js no index.html');
    t.ok(tag < html.lastIndexOf('<script>'), 'motor.js tem que vir ANTES do bloco inline');
  });

  t.teste('motor.js está no cache do service worker', () => {
    /* sem isto o app abre online e quebra offline — e a falha só aparece no
       aparelho de quem já instalou */
    const sw = fs.readFileSync(path.join(RAIZ, 'sw.js'), 'utf8');
    t.ok(/["']\.\/motor\.js["']/.test(sw), 'motor.js não está em ARQUIVOS no sw.js');
  });

  t.teste('motor.js é embutido no offline.html', () => {
    const ps = fs.readFileSync(path.join(RAIZ, 'gerar-offline.ps1'), 'utf8');
    t.ok(/motor\.js/.test(ps), 'gerar-offline.ps1 não embute o motor.js');
  });
};
