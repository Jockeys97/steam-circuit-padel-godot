import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

// Le arene possono essere spettacolari fuori dalla gabbia, ma la superficie
// di gioco deve restare sempre leggibile. L'audit protegge la zona sicura
// condivisa da effetti animati e oggetti scenografici.
const render = await readFile(new URL("../js/render.js", import.meta.url), "utf8");

assert.match(render, /function clipArenaScenery\(ctx\)/,
  "Manca la zona sicura comune per la scenografia delle arene");
assert.match(render, /ctx\.rect\(0, 0, 960, 96\)/,
  "La scenografia deve restare nel proscenio sopra il vetro di fondo");
assert.match(render, /ctx\.lineTo\(48, 700\)/,
  "Manca il limite esterno sinistro della gabbia");
assert.match(render, /ctx\.lineTo\(912, 700\)/,
  "Manca il limite esterno destro della gabbia");

const safeZoneUses = render.match(/clipArenaScenery\(ctx\);/g) ?? [];
assert.equal(safeZoneUses.length, 2,
  "La zona sicura va applicata sia agli effetti del fondale sia agli oggetti in primo piano");
assert.doesNotMatch(render, /clip\(["']evenodd["']\)/,
  "Il ritaglio inverso even-odd puo' lasciare elementi nel campo: usare solo zone positive");

console.log("arena scenery audit ok");
