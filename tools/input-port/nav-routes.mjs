#!/usr/bin/env node
/**
 * nav-routes.mjs — derive the reference's screen/route inventory from the frozen
 * browser build, and verify the port's shipped copy against a fresh extraction.
 *
 * The reference's own reachability audit (`scripts/reachability-audit.mjs`) reads
 * `index.html`, `js/main.js` and `js/ui.js` as *sources* rather than importing
 * them, and so does this tool: the ported audit (`godot/tests/input/
 * reachability_audit.gd`) must be able to fail when the reference's route table
 * changes, which it can only do if the table is derived from the reference and
 * pinned by hash.
 *
 * What it extracts:
 *   1. the screens, in document order, from `<section class="screen" id="screen-X">`;
 *   2. the back action each screen *declares* (`data-back` on a button, the audit's
 *      rule 3 — declared, never inferred from position);
 *   3. the `to-*` actions the screen's markup carries (the markup edges);
 *   4. the `screens` registry keys of `js/ui.js` (the audit's cross-check);
 *   5. every `showScreen("X")` call site with file, line and enclosing function
 *      (the audit's rule 3: every screen is opened by some `showScreen`).
 *
 * Usage:
 *   node tools/input-port/nav-routes.mjs            # print the GDScript block
 *   node tools/input-port/nav-routes.mjs --report   # print the JSON report
 *   node tools/input-port/nav-routes.mjs --verify   # exit 1 if the shipped copy drifted
 *
 * Read-only: the browser build under `js/` and `index.html` are never written.
 */

import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

export const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

export const SOURCES = ["index.html", "js/ui.js", "js/main.js"];
export const SHIPPED = "godot/src/input/nav_routes.gd";
export const BEGIN = "# --- BEGIN GENERATED (tools/input-port/nav-routes.mjs)";
export const END = "# --- END GENERATED";

/** The root of the navigation: the audit's `screen-menu` has no `data-back`. */
export const ROOT_SCREEN = "screen-menu";
/** Screens that are the root or the field: no `data-back` is expected on them
 *  (`scripts/gamepad-nav-audit.mjs:56`). */
export const BACKLESS_SCREENS = ["screen-menu", "screen-game", "screen-result"];

export function readSource(rel) {
  return readFileSync(join(REPO, rel), "utf8");
}

export function hashSource(rel) {
  const text = readFileSync(join(REPO, rel));
  return { sha256: createHash("sha256").update(text).digest("hex"), bytes: text.length };
}

/** The screens in document order, each with the markup of its own block. */
export function screens(html = readSource("index.html")) {
  const re = /<section\s+class="screen[^"]*"\s+id="(screen-[a-z-]+)"/g;
  const starts = [...html.matchAll(re)].map((m) => ({ id: m[1], at: m.index }));
  return starts.map((s, i) => ({
    id: s.id,
    block: html.slice(s.at, i + 1 < starts.length ? starts[i + 1].at : html.length),
  }));
}

export function extract(html = readSource("index.html"), ui = readSource("js/ui.js"), main = readSource("js/main.js")) {
  const rows = screens(html).map(({ id, block }) => {
    // `data-back` is a bare attribute on the button that declares the return
    // (`index.html:88`), and the action on the same tag is the action it fires.
    const back = block.match(/data-action="([A-Za-z0-9-]+)"[^>]*\sdata-back\b/)?.[1]
      ?? block.match(/\sdata-back\b[^>]*data-action="([A-Za-z0-9-]+)"/)?.[1]
      ?? null;
    const to = [...new Set([...block.matchAll(/data-action="(to-[a-z-]+)"/g)].map((m) => m[1]))].sort();
    return { id, back, to };
  });

  const registryBlock = ui.match(/const screens = \{(.*?)\n\};/s)?.[1] ?? "";
  const registry = [...registryBlock.matchAll(/\n {2}([A-Za-z][A-Za-z0-9]*)\s*:/g)].map((m) => m[1]).sort();

  const openers = [];
  for (const [file, text] of [["js/main.js", main], ["js/ui.js", ui]]) {
    lines(text).forEach((line, index) => {
      for (const m of line.matchAll(/showScreen\("([a-z-]+)"\)/g)) {
        openers.push({ screen: `screen-${m[1]}`, file, line: index + 1, fn: enclosing(text, index) });
      }
    });
  }

  return {
    screens: rows,
    registry,
    openers,
    provenance: Object.fromEntries(SOURCES.map((rel) => [rel, hashSource(rel)])),
  };
}

function lines(text) {
  return text.split("\n");
}

/** The nearest preceding `function name(` or `const name = (`: enough to name the
 *  call site in the evidence without pretending to be a parser. */
function enclosing(text, index) {
  const before = lines(text).slice(0, index + 1).reverse();
  for (const line of before) {
    const fn = line.match(/^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/);
    if (fn) return fn[1];
    const arrow = line.match(/^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?\(/);
    if (arrow) return arrow[1];
    if (/^\s*(?:window\.)?addEventListener\(/.test(line) || /=>\s*\{\s*$/.test(line)) return "(callback)";
  }
  return "(top level)";
}

function gd(value) {
  if (value === null) return "null";
  if (typeof value === "number") return String(value);
  if (typeof value === "string") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(gd).join(", ")}]`;
  return `{${Object.entries(value).map(([k, v]) => `${JSON.stringify(k)}: ${gd(v)}`).join(", ")}}`;
}

/** The generated block, byte for byte. `--verify` compares this against the
 *  shipped file, so any whitespace difference is a drift failure. */
export function block(data = extract()) {
  const out = [];
  out.push(`${BEGIN}`);
  out.push(`## Derived from the frozen reference (commit 2979588). Regenerate:`);
  out.push(`##   node tools/input-port/nav-routes.mjs`);
  out.push(`const ROUTE_PROVENANCE := ${gd(data.provenance)}`);
  out.push("");
  out.push(`## <section ... id="screen-X">, document order. \`back\` is the action on`);
  out.push(`## the button that declares \`data-back\`; null means the screen declares no`);
  out.push(`## return (the root and the field). \`to\` are the \`to-*\` actions in the`);
  out.push(`## screen's own markup.`);
  out.push(`const ROUTE_SCREENS := [`);
  for (const row of data.screens) {
    out.push(`\t{"id": ${gd(row.id)}, "back": ${gd(row.back)}, "to": ${gd(row.to)}},`);
  }
  out.push(`]`);
  out.push("");
  out.push(`## The \`screens\` registry of \`js/ui.js:444-458\`, sorted: the audit's`);
  out.push(`## cross-check between the markup and the router's own table.`);
  out.push(`const ROUTE_REGISTRY := ${gd(data.registry)}`);
  out.push("");
  out.push(`## Every \`showScreen("X")\` call site: screen, file, line, enclosing function.`);
  out.push(`const ROUTE_OPENERS := [`);
  for (const o of data.openers) {
    out.push(`\t{"screen": ${gd(o.screen)}, "file": ${gd(o.file)}, "line": ${gd(o.line)}, "fn": ${gd(o.fn)}},`);
  }
  out.push(`]`);
  out.push(`${END}`);
  return out.join("\n");
}

export function verify(shippedText = readFileSync(join(REPO, SHIPPED), "utf8"), data = extract()) {
  const begin = shippedText.indexOf(BEGIN);
  const end = shippedText.indexOf(END, begin + 1);
  if (begin < 0 || end < 0) {
    return { ok: false, reason: `markers not found in ${SHIPPED}` };
  }
  const found = shippedText.slice(begin, end + END.length);
  const fresh = block(data);
  if (found !== fresh) {
    const a = found.split("\n");
    const b = fresh.split("\n");
    const at = a.findIndex((line, i) => line !== b[i]);
    return { ok: false, reason: `drift at line ${at + 1}: shipped ${JSON.stringify(a[at])} vs fresh ${JSON.stringify(b[at])}` };
  }
  return { ok: true, screens: data.screens.length, openers: data.openers.length };
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--verify")) {
    const result = verify();
    if (!result.ok) {
      console.error(`nav-routes: FAIL ${result.reason}`);
      process.exit(1);
    }
    console.log(`nav-routes: ok ${SHIPPED} matches the reference (${result.screens} screens, ${result.openers} showScreen call sites)`);
    return;
  }
  if (args.includes("--report")) {
    const data = extract();
    const reachable = reachableFromRoot(data);
    console.log(JSON.stringify({
      screens: data.screens.length,
      registry: data.registry.length,
      openers: data.openers.length,
      backless: data.screens.filter((s) => s.back === null).map((s) => s.id),
      markupReachableFromRoot: reachable,
      provenance: data.provenance,
    }, null, 2));
    return;
  }
  console.log(block());
}

/** Markup-edge reachability from the root: `to-<x>` inside a reachable screen
 *  opens `screen-<x>`. Code-origin edges (`showScreen` inside a callback) carry no
 *  static origin, so they are *not* added here — the ported audit asserts the
 *  reference's own rule (every screen has an opener) and prints this number. */
export function reachableFromRoot(data = extract()) {
  const edges = new Map(data.screens.map((s) => [s.id, s.to.map((t) => `screen-${t.slice(3)}`)]));
  const seen = new Set([ROOT_SCREEN]);
  const queue = [ROOT_SCREEN];
  while (queue.length) {
    const at = queue.shift();
    for (const next of edges.get(at) ?? []) {
      if (!edges.has(next) || seen.has(next)) continue;
      seen.add(next);
      queue.push(next);
    }
  }
  return [...seen].sort();
}

if (process.argv[1] && process.argv[1].endsWith("nav-routes.mjs")) main();
