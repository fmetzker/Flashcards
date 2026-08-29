/* Datas e fuso — CLAUDE.md, "Motor de repetição espaçada":
   "O dia sempre vira no fuso de Brasília, nunca no fuso do aparelho."   */
module.exports = function (APP, t) {
  t.grupo('datas');

  t.teste('hoje() devolve AAAA-MM-DD', () => {
    t.ok(/^\d{4}-\d{2}-\d{2}$/.test(APP.hoje()), 'formato inesperado: ' + APP.hoje());
  });

  t.teste('hoje() usa o fuso de Brasília, não o do aparelho', () => {
    /* Regra que já foi quebrada uma vez (hoje() usava toISOString, que é
       UTC). Às 02:00 UTC ainda é o dia anterior em Brasília (UTC-3): se o
       app cortasse por UTC, os dois bateriam — e é isso que não pode. */
    const fmtUTC = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'UTC', year: 'numeric', month: '2-digit', day: '2-digit',
    });
    const fmtBr = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
    });
    const madrugada = new Date(Date.UTC(2026, 0, 2, 2, 0, 0));  // 02:00 UTC = 23:00 do dia 1 em SP
    t.igual(fmtUTC.format(madrugada), '2026-01-02', 'âncora do teste');
    t.igual(fmtBr.format(madrugada), '2026-01-01', 'âncora do teste');
    t.igual(APP.FUSO_BRASILIA, 'America/Sao_Paulo', 'o fuso do app mudou');
  });

  t.teste('somarDias atravessa mês e ano sem escorregar', () => {
    t.igual(APP.somarDias('2026-01-31', 1), '2026-02-01');
    t.igual(APP.somarDias('2026-12-31', 1), '2027-01-01');
    t.igual(APP.somarDias('2026-03-01', -1), '2026-02-28');
    t.igual(APP.somarDias('2026-08-29', 0), '2026-08-29');
  });

  t.teste('somarDias atravessa o horário de verão sem perder um dia', () => {
    /* O motivo de diaUTC existir: somar em horário LOCAL faria o dia sumir
       ou repetir na virada do horário de verão. Ancorado em UTC, não. */
    t.igual(APP.somarDias('2026-02-14', 1), '2026-02-15');
    t.igual(APP.somarDias('2026-10-17', 1), '2026-10-18');
  });

  t.teste('somarDias soma 365 dias sem desvio', () => {
    let d = '2026-01-01';
    for (let i = 0; i < 365; i++) d = APP.somarDias(d, 1);
    t.igual(d, '2027-01-01');
  });

  t.teste('diaUTC ancora à meia-noite UTC', () => {
    t.igual(APP.diaUTC('2026-08-29').toISOString(), '2026-08-29T00:00:00.000Z');
  });
};
