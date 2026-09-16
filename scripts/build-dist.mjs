import { cp, mkdir, rm, readdir, stat } from "node:fs/promises";
import path from "node:path";

/**
 * Prepara `dist/`, cioe' quello che va davvero dentro il pacchetto.
 *
 * Il gioco non ha un passo di build — si apre `index.html` e funziona — quindi
 * questa cartella non compila niente: sceglie. La radice del repository pesa
 * 157 MB, di cui 131 sono `assets/_archivio`, i master PNG da cui gli sprite
 * vengono generati. Servono a rigenerare gli asset, non a giocarci: puntare
 * Tauri sulla radice significherebbe far scaricare a ogni giocatore sei volte il
 * necessario.
 *
 * Cio' che resta e' quello che il gioco chiede davvero a runtime: 25 MB su
 * disco, di cui 9,6 al primo caricamento.
 */

const root = new URL("../", import.meta.url);
const dist = new URL("dist/", root);

// Elenco esplicito, non esclusioni: una lista di cosa entra si legge e si
// verifica, una lista di cosa resta fuori dimentica in silenzio il file nuovo.
const INCLUSI = ["index.html", "styles.css", "js", "assets"];
const ESCLUSI_DENTRO_ASSETS = ["_archivio"];

async function pesa(dir) {
  let totale = 0;
  for (const voce of await readdir(dir, { withFileTypes: true })) {
    const figlio = path.join(dir, voce.name);
    totale += voce.isDirectory() ? await pesa(figlio) : (await stat(figlio)).size;
  }
  return totale;
}

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });

for (const voce of INCLUSI) {
  await cp(new URL(voce, root), new URL(voce, dist), {
    recursive: true,
    filter: (origine) => {
      const relativo = path.relative(new URL(".", root).pathname, origine);
      return !ESCLUSI_DENTRO_ASSETS.some((e) => relativo.split(path.sep).includes(e));
    },
  });
}

const megabyte = (b) => (b / (1024 * 1024)).toFixed(1);
const dentro = await pesa(new URL(".", dist).pathname);
const radice = await pesa(new URL("assets/", root).pathname);

console.log(JSON.stringify({
  pacchetto: `${megabyte(dentro)} MB`,
  assetNelRepository: `${megabyte(radice)} MB`,
  risparmiato: `${megabyte(radice - dentro)} MB di master che non servono a giocare`,
  incluso: INCLUSI,
}, null, 2));
