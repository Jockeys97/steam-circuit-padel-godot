import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

/**
 * Verifica il contratto fra i moduli: che ogni nome importato esista davvero
 * nel modulo che lo dovrebbe esportare, e che la query di versione sia allineata
 * ovunque.
 *
 * E' il guasto che non degrada. Un import che non risolve interrompe la catena
 * dei moduli: la pagina si apre, il campo si disegna, e nessun bottone risponde
 * perche' nessun listener e' stato agganciato. Nella console c'e' una riga, ma
 * chi prova il gioco vede solo un menu morto — ed e' successo due volte, la
 * seconda ripristinando da HEAD dei blocchi che erano stati aggiunti di proposito.
 *
 * Nessun altro audit copre questo: gli altri importano i moduli che gli servono e
 * misurano il bilanciamento, quindi un export mancante altrove non li tocca.
 */

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const JS_DIR = path.join(ROOT, "js");

const read = (p) => readFileSync(path.join(ROOT, p), "utf8");
const jsFiles = readdirSync(JS_DIR).filter((f) => f.endsWith(".js"));

// ── Gli export di ogni modulo ──────────────────────────────────────────────
/** Nomi esportati da un modulo, per le forme usate in questo progetto. */
function exportsOf(source) {
  const names = new Set();
  // export function x / export const x / export class x / export let x
  for (const m of source.matchAll(/^export\s+(?:async\s+)?(?:function|class|const|let|var)\s+([A-Za-z0-9_$]+)/gm)) {
    names.add(m[1]);
  }
  // export { a, b as c }
  for (const m of source.matchAll(/^export\s*\{([^}]*)\}/gm)) {
    for (const part of m[1].split(",")) {
      const bit = part.trim();
      if (!bit) continue;
      const as = bit.split(/\s+as\s+/);
      names.add((as[1] ?? as[0]).trim());
    }
  }
  if (/^export\s+default/m.test(source)) names.add("default");
  return names;
}

const moduleExports = new Map();
for (const file of jsFiles) moduleExports.set(file, exportsOf(read(path.join("js", file))));

// ── Ogni import deve trovare il proprio export ────────────────────────────
const IMPORT_RE = /import\s*\{([^}]*)\}\s*from\s*["']\.\/([A-Za-z0-9_.-]+\.js)(\?v=[^"']*)?["']/g;
let checked = 0;
const missing = [];
const unversioned = [];
for (const file of jsFiles) {
  const source = read(path.join("js", file));
  for (const m of source.matchAll(IMPORT_RE)) {
    const [, bindings, target, query] = m;
    // Un import senza query di versione sfuggiva al controllo di allineamento
    // qui sotto, che conta solo le query presenti: `drill.js` importava
    // `./data.js` nudo e il browser ne teneva una seconda istanza separata,
    // proprio la trappola dell'identita' dei moduli descritta nel README.
    if (!query) unversioned.push(`${file} importa ${target} senza query di versione`);
    const available = moduleExports.get(target);
    assert(available, `${file} importa da ${target}, che non esiste`);
    for (const part of bindings.split(",")) {
      const bit = part.trim();
      if (!bit) continue;
      // `import { a as b }`: il nome che deve esistere e' quello di partenza.
      const wanted = bit.split(/\s+as\s+/)[0].trim();
      checked += 1;
      if (!available.has(wanted)) missing.push(`${file} importa "${wanted}" da ${target}, che non lo esporta`);
    }
  }
}
assert.deepEqual(missing, [], `Import senza export corrispondente:\n  ${missing.join("\n  ")}`);
assert.deepEqual(unversioned, [], `Import locali senza cache busting:\n  ${unversioned.join("\n  ")}`);

// ── La query di versione deve essere una sola ─────────────────────────────
const VERSION_RE = /\?v=([A-Za-z0-9_.-]+)/g;
const versions = new Map();
const scanned = ["index.html", "styles.css", ...jsFiles.map((f) => path.join("js", f))];
for (const rel of scanned) {
  let source;
  try {
    source = read(rel);
  } catch {
    continue; // styles.css potrebbe non contenere query di versione
  }
  for (const m of source.matchAll(VERSION_RE)) {
    versions.set(m[1], (versions.get(m[1]) ?? 0) + 1);
  }
}
assert.equal(
  versions.size,
  1,
  `La query di versione deve essere una sola, trovate ${versions.size}: ${[...versions.entries()].map(([v, n]) => `${v}×${n}`).join(", ")}`,
);

const [[version, occurrences]] = [...versions.entries()];

console.log(JSON.stringify({
  moduli: jsFiles.length,
  importVerificati: checked,
  versione: version,
  occorrenze: occurrences,
}, null, 2));
console.log("\nmodule-contract-audit: ogni import trova il suo export, versione allineata");
