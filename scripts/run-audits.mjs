import { readdir } from "node:fs/promises";
import { spawn } from "node:child_process";
import path from "node:path";

/**
 * Esegue tutti gli audit e dice quali sono rossi.
 *
 * Lo script che c'era prima era un `for` di shell che usciva al primo
 * fallimento con l'output buttato in `/dev/null`. In una sessione di lavoro
 * lunga e' il comportamento sbagliato due volte: nasconde il messaggio
 * dell'asserzione, che e' l'unica cosa che serve, e si ferma al primo rosso
 * quindi non si sa se ne sono caduti altri. Con venti audit e due sessioni che
 * lavorano sullo stesso repository, sapere *quanti* e *quali* cambia la
 * diagnosi: uno rosso e' un bug, cinque rossi sono un file a meta'.
 *
 * Esce con codice 1 se anche uno solo fallisce, cosi' la CI se ne accorge.
 */

const root = new URL("../", import.meta.url);
const dir = new URL("scripts/", root);
const files = (await readdir(dir))
  .filter((name) => name.endsWith("-audit.mjs"))
  .sort();

if (!files.length) {
  console.error("Nessun audit trovato in scripts/");
  process.exit(1);
}

function esegui(file) {
  return new Promise((resolve) => {
    const avvio = Date.now();
    const figlio = spawn(process.execPath, [path.join("scripts", file)], {
      cwd: new URL(".", root).pathname,
      stdio: ["ignore", "ignore", "pipe"],
    });
    let errore = "";
    figlio.stderr.on("data", (pezzo) => { errore += pezzo; });
    figlio.on("close", (codice) => {
      resolve({ file, ok: codice === 0, ms: Date.now() - avvio, errore });
    });
  });
}

// In sequenza e non in parallelo: alcuni audit simulano partite intere e su una
// macchina modesta farli correre tutti insieme falsa i tempi senza guadagnare.
const esiti = [];
for (const file of files) esiti.push(await esegui(file));

const larghezza = Math.max(...esiti.map((e) => e.file.length));
for (const esito of esiti) {
  const nome = esito.file.replace(/-audit\.mjs$/, "").padEnd(larghezza - 10);
  const tempo = `${String(esito.ms).padStart(5)} ms`;
  console.log(`${esito.ok ? "✅" : "❌"} ${nome} ${tempo}`);
}

const rossi = esiti.filter((e) => !e.ok);
console.log(`\n${esiti.length - rossi.length}/${esiti.length} audit passano`);

if (rossi.length) {
  for (const esito of rossi) {
    // Solo la riga dell'asserzione: lo stack di Node qui non aggiunge niente,
    // perche' il file e' gia' nel nome e la riga e' nel messaggio.
    const riga = esito.errore.split("\n").find((l) => l.includes("Error")) ?? esito.errore.split("\n")[0];
    console.log(`\n❌ ${esito.file}\n   ${riga.trim()}`);
  }
  process.exit(1);
}
