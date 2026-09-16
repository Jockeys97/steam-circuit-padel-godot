/**
 * gen-demo-content.mjs — the port's demo content table, generated from the
 * reference instead of re-typed.
 *
 * `js/build.js:43-56` is the authority for what the demo contains. This script
 * imports that module (the same module `scripts/demo-audit.mjs` audits) and
 * writes the table, plus two facts the table alone does not carry:
 *
 *   - the sha256 of the `js/build.js` it was generated from, so a drift between
 *     the reference and the port's copy is detectable by re-running this script
 *     and diffing, not by eye;
 *   - the mode ids the reference's own menu offers (`index.html` `.mode-card`
 *     `data-mode`), because "quick match only" is only a rule if the full set is
 *     written down somewhere mechanical;
 *   - the number of challenge outfits on each demo athlete (`js/data.js`
 *     `ATHLETE_OUTFITS`), the demo's only long-term hook
 *     (`scripts/demo-audit.mjs:79-90`).
 *
 * Output: `godot/tests/build/demo_content.json` — read at runtime by
 * `godot/tests/build/DemoContent.gd`. Nothing in the port types these ids by hand.
 *
 * Usage: node tools/export/gen-demo-content.mjs
 */

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");

const buildSrc = path.join(root, "js", "build.js");
const dataSrc = path.join(root, "js", "data.js");
const htmlSrc = path.join(root, "index.html");
const outDir = path.join(root, "godot", "tests", "build");
const outFile = path.join(outDir, "demo_content.json");

const { DEMO_CONTENT } = await import(buildSrc);
const { ATHLETE_OUTFITS } = await import(dataSrc);

const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");

// The mode ids the reference's menu declares, in document order.
const html = await readFile(htmlSrc, "utf8");
const allModes = [...html.matchAll(/class="mode-card"\s+data-mode="([a-z]+)"/g)].map((m) => m[1]);

// The demo's only earned reward: outfit challenges on the athletes it grants.
const outfitChallenges = {};
for (const id of DEMO_CONTENT.athletes) {
  const outfits = ATHLETE_OUTFITS[id] ?? [];
  outfitChallenges[id] = outfits.filter((o) => o.challenge).length;
}

const payload = {
  generatedBy: "tools/export/gen-demo-content.mjs",
  source: "js/build.js",
  sources: {
    "js/build.js": sha256(await readFile(buildSrc)),
    "js/data.js": sha256(await readFile(dataSrc)),
    "index.html": sha256(await readFile(htmlSrc)),
  },
  content: DEMO_CONTENT,
  allModes,
  outfitChallenges,
};

await mkdir(outDir, { recursive: true });
await writeFile(outFile, JSON.stringify(payload, null, 2) + "\n");

console.log(JSON.stringify({
  wrote: path.relative(root, outFile),
  athletes: payload.content.athletes,
  arenas: payload.content.arenas,
  modes: payload.content.modes,
  difficulty: payload.content.difficulty,
  allModes,
  outfitChallenges,
  sources: payload.sources,
}, null, 2));
