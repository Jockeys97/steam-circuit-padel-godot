import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

/**
 * Ogni modulo deve potersi valutare senza esplodere.
 *
 * Complementare a `module-contract-audit`, che verifica staticamente che ogni
 * nome importato esista e che la query di versione sia allineata. Quello legge
 * il testo; questo esegue. Sono guasti diversi: un modulo puo' avere tutti gli
 * import a posto e lanciare comunque al caricamento — una costante letta prima
 * della propria dichiarazione, una chiamata al DOM fuori da una funzione, un
 * `JSON.parse` su un valore assente. Il sintomo e' lo stesso e non degrada: la
 * pagina si apre, il campo si disegna, e nessun bottone risponde perche' la
 * catena dei moduli si e' interrotta prima che i listener venissero agganciati.
 *
 * Nessun altro audit ci arriva: `ui.js` e `main.js` chiedono il DOM, quindi
 * nessuno li importa e nessuno scopre se si rompono. Qui il DOM viene finto
 * quanto basta a far valutare i moduli — non si prova a far girare il gioco.
 */

const root = new URL("../", import.meta.url);

function stubDom() {
  const el = () => new Proxy({
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false } },
    dataset: {}, style: {}, hidden: false, innerHTML: "", textContent: "", value: "",
    appendChild() {}, addEventListener() {}, setAttribute() {}, replaceChildren() {},
    querySelector() { return null }, querySelectorAll() { return [] },
    getContext() {
      return new Proxy({
        canvas: { width: 960, height: 620 },
        measureText: () => ({ width: 10 }),
        createLinearGradient: () => ({ addColorStop() {} }),
        createRadialGradient: () => ({ addColorStop() {} }),
        getImageData: () => ({ data: [] }),
      }, { get: (target, key) => (key in target ? target[key] : () => {}) });
    },
    getBoundingClientRect() { return { left: 0, top: 0, width: 960, height: 620 } },
  }, { get: (target, key) => (key in target ? target[key] : el()) });

  globalThis.document = {
    getElementById: () => el(), createElement: () => el(),
    querySelector: () => el(), querySelectorAll: () => [],
    documentElement: el(), body: el(), addEventListener() {},
  };
  globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };
  globalThis.window = globalThis;
  globalThis.location = { search: "", hostname: "localhost" };
  globalThis.requestAnimationFrame = () => 0;
  globalThis.addEventListener = () => {};
  globalThis.removeEventListener = () => {};
  globalThis.matchMedia = () => ({ matches: false, addEventListener() {}, addListener() {} });
  globalThis.Image = class { set src(value) {} addEventListener() {} };
  globalThis.AudioContext = class {
    constructor() { this.destination = {}; this.currentTime = 0; }
    createGain() { return { connect() {}, gain: { value: 0, setValueAtTime() {}, linearRampToValueAtTime() {} } } }
    createOscillator() { return { connect() {}, start() {}, stop() {}, frequency: { value: 0, setValueAtTime() {} }, type: "" } }
    createBuffer() { return { getChannelData: () => [] } }
    createBufferSource() { return { connect() {}, start() {} } }
  };
  Object.defineProperty(globalThis, "navigator", {
    value: { getGamepads: () => [], language: "it", vibrate() {} },
    configurable: true,
  });
}

stubDom();

// La stringa di versione va letta dal codice, non scritta qui: `data.js` e
// `data.js?v=20260910-sprite-gate-v41` sono due moduli distinti per Node, ed e' una trappola in cui
// questo progetto e' gia' caduto tre volte.
const mainSource = await readFile(new URL("js/main.js", root), "utf8");
const versione = mainSource.match(/from "\.\/data\.js(\?v=[^"]*)"/)?.[1] ?? "";
assert.ok(versione, "Impossibile leggere la stringa di versione da main.js");

const files = (await readdir(new URL("js/", root))).filter((name) => name.endsWith(".js"));
assert.ok(files.length >= 8, `Attesi almeno otto moduli, trovati ${files.length}`);

const errori = [];
for (const file of files) {
  try {
    await import(new URL(`js/${file}${versione}`, root));
  } catch (error) {
    errori.push(`${file}: ${error.message}`);
  }
}
assert.deepEqual(errori, [], `Moduli che non si valutano:\n  ${errori.join("\n  ")}`);

console.log(JSON.stringify({ moduli: files.length, versione: versione.replace("?v=", "") }, null, 2));
