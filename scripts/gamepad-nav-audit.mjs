import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

/**
 * Audit della navigazione con controller.
 *
 * Un gioco che si vende su Steam si gioca col pad, e la tastiera e' l'eccezione.
 * I difetti di questa parte non si vedono provando col mouse: si vedono quando
 * qualcuno prende il controller e scopre che una schermata e' un vicolo cieco.
 *
 * Qui si verifica il contratto fra markup e navigazione: che ogni elemento
 * interattivo dichiarato nel markup sia raggiungibile dal fuoco, che ogni
 * schermata abbia un ritorno dichiarato, e che nessun campo di testo resti senza
 * un modo di scriverci col solo pad.
 */

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const main = readFileSync(new URL("../js/main.js", import.meta.url), "utf8");
const i18n = readFileSync(new URL("../js/i18n.js", import.meta.url), "utf8");

const report = {};

/** Il selettore usato da `collectMenuTargets`, letto dal codice e non riscritto. */
const selettore = main.match(/root\.querySelectorAll\(\s*"([^"]+)"/s)?.[1]
  ?? main.match(/root\.querySelectorAll\(\s*\n?\s*"([^"]+)",?\s*\n?\s*\)/s)?.[1];
assert(selettore, "Non trovo il selettore dei bersagli del fuoco in main.js");
const tagRaggiungibili = new Set(
  selettore.split(",").map((s) => s.trim()).filter((s) => /^[a-z]+$/.test(s)),
);
report.selettore = [...tagRaggiungibili].join(",");

// ── 1. Ogni tipo di elemento interattivo presente nel markup e' raggiungibile ─
{
  const presenti = new Set();
  for (const tag of ["button", "input", "textarea", "select", "summary"]) {
    if (new RegExp(`<${tag}\\b`).test(html)) presenti.add(tag);
  }
  const irraggiungibili = [...presenti].filter((t) => !tagRaggiungibili.has(t));
  assert.deepEqual(
    irraggiungibili,
    [],
    `Elementi presenti nel markup che il fuoco non raggiunge: ${irraggiungibili.join(", ")}. `
    + "Col pad diventano invisibili e la schermata e' un vicolo cieco.",
  );
  report.tagUsati = [...presenti].join(",");
}

// ── 2. Ogni schermata navigabile ha un ritorno dichiarato ──────────────────
{
  const sezioni = [...html.matchAll(/<section class="screen[^"]*" id="(screen-[a-z-]+)"[\s\S]*?<\/section>/g)];
  assert(sezioni.length >= 8, `Trovate solo ${sezioni.length} schermate: il markup e' cambiato`);
  const senzaRitorno = [];
  for (const [blocco, id] of sezioni.map((m) => [m[0], m[1]])) {
    // Il menu e le schermate di gioco non hanno un "indietro": sono la radice e
    // il campo. Tutte le altre devono poter essere lasciate col pad.
    if (["screen-menu", "screen-game", "screen-result"].includes(id)) continue;
    if (!/data-back/.test(blocco)) senzaRitorno.push(id);
  }
  assert.deepEqual(
    senzaRitorno,
    [],
    `Schermate senza un ritorno dichiarato (data-back): ${senzaRitorno.join(", ")}`,
  );
  report.schermate = sezioni.length;
}

// ── 3. Il menu principale non deve avere un data-back ─────────────────────
// E' la radice: "indietro" da qui non deve portare da nessuna parte. Prima
// prendeva il primo `[data-action^="to-"]` della schermata — la barra in alto —
// e apriva il Profilo, cioe' andava avanti.
{
  const menu = html.match(/<section class="screen screen--active" id="screen-menu"[\s\S]*?<\/section>/)?.[0];
  assert(menu, "Schermata del menu non trovata");
  assert(
    !/data-back/.test(menu),
    "Il menu principale non deve dichiarare un ritorno: e' la radice della navigazione",
  );
  assert(
    /\[data-back\]/.test(main),
    "menuBack deve cercare il ritorno dichiarato, non il primo data-action della schermata",
  );
}

// ── 4. Indietro deve stare anche su B/Cerchio ─────────────────────────────
{
  const blocco = main.match(/function pollGamepadMenu[\s\S]*?\n}/)?.[0];
  assert(blocco, "pollGamepadMenu non trovata");
  assert(
    /b\(1\)/.test(blocco),
    "B/Cerchio non e' mappato nei menu: e' il tasto che tutti provano per tornare indietro",
  );
  assert(/b\(0\)/.test(blocco), "A/Croce deve confermare");
  // L'aiuto non deve promettere un comando che non esiste.
  const promesse = [...i18n.matchAll(/pad(?:Hints3|MenuHint): "([^"]+)"/g)].map((m) => m[1]);
  assert(promesse.length >= 2, "Stringhe di aiuto del pad non trovate");
  promesse.forEach((testo) => {
    assert(
      /B\/(Cerchio|Circle)/.test(testo),
      `L'aiuto promette un comando diverso da quello mappato: "${testo}"`,
    );
  });
  report.aiuto = promesse.length;
}

// ── 5. Nessun campo di testo senza un modo di scriverci col pad ───────────
{
  const campi = [
    ...[...html.matchAll(/<textarea\b[^>]*id="([^"]+)"/g)].map((m) => m[1]),
    ...[...html.matchAll(/<input\b[^>]*type="text"[^>]*id="([^"]+)"/g)].map((m) => m[1]),
    ...[...html.matchAll(/<input\b[^>]*id="([^"]+)"[^>]*type="text"/g)].map((m) => m[1]),
  ];
  assert(campi.length > 0, "Nessun campo di testo trovato: il markup e' cambiato");
  // La tastiera su schermo deve esistere e aprirsi dalla conferma.
  assert(/id="osk"/.test(html), "Manca la tastiera su schermo: col pad questi campi non si compilano");
  assert(/id="oskGrid"/.test(html), "Manca la griglia dei tasti");
  const attiva = main.match(/function activateMenuFocus[\s\S]*?\n}/)?.[0];
  assert(
    /openOsk\(/.test(attiva),
    "Confermare su un campo di testo non apre la tastiera: il campo riceverebbe il fuoco "
    + "e resterebbe impossibile da compilare",
  );
  assert(
    /isTextField\(/.test(attiva),
    "activateMenuFocus deve distinguere un campo di testo da un pulsante",
  );
  // La tastiera deve essere il contesto di fuoco quando e' aperta, altrimenti il
  // pad muoverebbe il fuoco sulla schermata sotto invece che fra i tasti.
  const contesto = main.match(/function menuContext[\s\S]*?\n}/)?.[0];
  assert(/oskOpen\(\)/.test(contesto), "La tastiera aperta deve diventare il contesto di fuoco");
  // E si deve poter chiudere con indietro, o si resta intrappolati.
  const back = main.match(/function menuBack[\s\S]*?\n}/)?.[0];
  assert(/closeOsk\(\)/.test(back), "Indietro deve chiudere la tastiera: senza, si resta intrappolati");
  report.campiDiTesto = campi.length;
}

// ── 6. Le etichette dei tasti d'azione esistono in entrambe le lingue ─────
{
  const chiavi = ["oskShift", "oskSpace", "oskBackspace", "oskDone", "oskHint", "ariaOsk"];
  for (const chiave of chiavi) {
    const n = (i18n.match(new RegExp(`\\b${chiave}:`, "g")) ?? []).length;
    assert.equal(n, 2, `${chiave} deve esistere in italiano e in inglese, trovata ${n} volta/e`);
  }
  report.etichetteTastiera = chiavi.length;
}

// ── 7. Il fuoco non deve poter finire su cio' che e' nascosto o bloccato ──
{
  const raccolta = main.match(/function collectMenuTargets[\s\S]*?\n}/)?.[0];
  assert(/\[hidden\]/.test(raccolta), "Il fuoco deve saltare cio' che e' nascosto");
  assert(/disabled/.test(raccolta), "Il fuoco deve saltare cio' che e' disabilitato");
  assert(/offsetParent/.test(raccolta), "Il fuoco deve saltare cio' che non e' disegnato");
}


// ── 8. Il fuoco non deve saltare gli elementi larghi ─────────────────────
// `moveMenuFocus` confrontava i soli centri penalizzando lo scostamento per tre.
// Un elemento largo ha il centro in mezzo alla riga: partendo da una colonna
// laterale perdeva contro un elemento piccolo e piu' allineato molto piu' lontano,
// e veniva saltato. La textarea del feedback era nella lista dei bersagli e
// restava comunque irraggiungibile — il difetto peggiore, perche' il codice
// sembrava giusto.
{
  // La geometria vive in `findMenuTarget`: `moveMenuFocus` la applica.
  const blocco = main.match(/function findMenuTarget[\s\S]*?\n}/)?.[0];
  assert(blocco, "findMenuTarget non trovata");
  assert(
    /sovrapposizione|overlap/.test(blocco),
    "La scelta del prossimo elemento deve considerare la sovrapposizione sull'asse "
    + "trasversale, non solo la distanza fra i centri: altrimenti gli elementi larghi "
    + "vengono saltati",
  );
  assert(
    /Math\.min\(curRect\.right, r\.right\)/.test(blocco),
    "La sovrapposizione orizzontale va calcolata dai bordi dei due rettangoli",
  );
}


// ── 9. Le schermate di sola lettura devono scorrere col pad ───────────────
// `challenges`, `history` e `profile` hanno un solo bersaglio — il pulsante
// Indietro — e contenuto molto piu' alto della finestra. Lo scorrimento era solo
// un effetto collaterale di `scrollIntoView` quando il fuoco si spostava: senza
// un secondo bersaglio non si spostava niente, e il resto della pagina era
// irraggiungibile col solo pad.
{
  assert(/function scrollMenu\(/.test(main), "Manca lo scorrimento della vista");
  assert(
    /function scrollContainer\(/.test(main),
    "Lo scorrimento deve trovare il contenitore giusto: alcuni riquadri scorrono per conto proprio",
  );
  // `moveMenuFocus` deve dire se il fuoco si e' mosso, o chi chiama non puo'
  // sapere quando ripiegare sullo scorrimento.
  const muovi = main.match(/function moveMenuFocus[\s\S]*?\n}/)?.[0];
  assert(/return (Boolean\(best\)|true|false)/.test(muovi), "moveMenuFocus deve riferire se ha spostato il fuoco");

  // Il pad: levetta destra sempre, levetta sinistra quando non c'e' bersaglio.
  const menu = main.match(/function pollGamepadMenu[\s\S]*?\n}/)?.[0];
  assert(/gamepadAxis\(pad, 3\)/.test(menu), "La levetta destra deve scorrere: e' il gesto che si prova per primo");
  assert(/scrollMenu\(/.test(menu), "Il pad deve poter scorrere la pagina");
  assert(/findMenuTarget\(/.test(menu), "Serve sapere se c'e' un bersaglio prima di decidere se scorrere");

  // La tastiera deve comportarsi allo stesso modo, o le due vie divergono.
  const tasti = main.match(/if \(key === "arrowup"[\s\S]*?\n    }/)?.[0];
  assert(tasti, "Ramo delle frecce non trovato");
  assert(/scrollMenu\(/.test(tasti), "Anche le frecce devono scorrere dove il fuoco non puo' andare");
}

// ── 10. Nessuna schermata di sola lettura senza modo di leggerla ──────────
{
  const soloLettura = ["screen-challenges", "screen-history", "screen-profile", "screen-help"];
  for (const id of soloLettura) {
    const blocco = html.match(new RegExp(`<section class="screen[^"]*" id="${id}"[\\s\\S]*?</section>`))?.[0];
    assert(blocco, `Schermata ${id} non trovata`);
    // Poche o nessuna voce interattiva: e' esattamente il caso in cui lo
    // scorrimento non puo' dipendere dallo spostamento del fuoco.
    const bersagli = (blocco.match(/<button|<input|<textarea|<summary/g) ?? []).length;
    if (bersagli <= 3) {
      assert(
        /scrollMenu\(/.test(main),
        `${id} ha ${bersagli} bersagli e contenuto lungo: senza scorrimento e' illeggibile col pad`,
      );
    }
  }
}

console.log(JSON.stringify(report, null, 2));
console.log("\ngamepad-nav-audit: tutto raggiungibile col pad, e i campi di testo si compilano");
