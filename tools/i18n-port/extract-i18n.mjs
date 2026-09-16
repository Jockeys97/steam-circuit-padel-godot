#!/usr/bin/env node
/**
 * extract-i18n.mjs — engine-free extraction of the reference string table.
 *
 * `js/i18n.js` (frozen browser reference, git HEAD 2979588) holds the only
 * authoritative copy of the game's human strings. This script reads it and
 * generates the port's locale data:
 *
 *   godot/src/locale/locale_data.gd   the two tables (it, en) as GDScript consts
 *
 * The extraction is *JavaScript's own semantics*, not a regex approximation:
 *
 *   - the `const DICT = { … }` literal is brace-matched out of the file and
 *     evaluated with `new Function("return (…);")()`, so escapes, unicode and
 *     duplicate keys behave exactly as they do in the browser (a key written
 *     twice keeps the LAST value and the FIRST position — this file does contain
 *     such keys, see DUPLICATE_KEYS in the generated output);
 *   - the result is then cross-checked against the module's own runtime: for
 *     every key, `setLang(lang); t(key)` must return the table value, and an
 *     unknown key must return the key itself.
 *
 * Deterministic: no timestamps, no hostnames. Re-running produces byte-identical
 * output (proved in docs/wayfinder/evidence/i18n-port-contract.md).
 *
 * Usage:
 *   node tools/i18n-port/extract-i18n.mjs            # report only, writes nothing
 *   node tools/i18n-port/extract-i18n.mjs --write    # write godot/src/locale/locale_data.gd
 *   node tools/i18n-port/extract-i18n.mjs --json     # dump the extraction as JSON
 *
 * Exported for the drift test (tools/i18n-port/verify-i18n-port.mjs), which
 * imports these functions and feeds them mutated source *text* — never a
 * mutated file on disk.
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO = resolve(HERE, "..", "..");
export const SOURCE_REL = "js/i18n.js";
export const OUT_REL = "godot/src/locale/locale_data.gd";

export function sha256(text) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

// ---------------------------------------------------------------------------
// the object literal, pulled out by brace matching
// ---------------------------------------------------------------------------

/** Returns the exact text of the `{ … }` that follows `const DICT =`. */
export function extractDictLiteral(source) {
  const at = source.indexOf("const DICT");
  if (at < 0) throw new Error("extractDictLiteral: `const DICT` not found");
  const open = source.indexOf("{", at);
  if (open < 0) throw new Error("extractDictLiteral: no `{` after `const DICT`");
  let depth = 0;
  let inString = null;
  let escaped = false;
  let inLineComment = false;
  for (let i = open; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1];
    if (inLineComment) {
      if (ch === "\n") inLineComment = false;
      continue;
    }
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === inString) inString = null;
      continue;
    }
    if (ch === "/" && next === "/") { inLineComment = true; i += 1; continue; }
    if (ch === '"' || ch === "'" || ch === "`") { inString = ch; continue; }
    if (ch === "{") depth += 1;
    else if (ch === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(open, i + 1);
    }
  }
  throw new Error("extractDictLiteral: unbalanced braces");
}

/** Evaluates the literal the way a JavaScript object literal is evaluated. */
export function evaluateDict(literal) {
  // eslint-disable-next-line no-new-func
  return new Function(`"use strict"; return (${literal});`)();
}

/**
 * Static key scan: the keys written in each language block, in file order, with
 * repeats preserved. `evaluateDict` cannot see a key written twice, so the
 * duplicates are reported separately and compared against the evaluated table
 * to prove the last-wins rule was applied.
 */
export function scanWrittenKeys(source) {
  const blocks = {};
  const blockRe = /\n {2}([A-Za-z_][A-Za-z0-9_]*): *\{(.*?)\n {2}\},?\n/s;
  const langs = [...source.matchAll(/\n {2}([A-Za-z_][A-Za-z0-9_]*): *\{/g)].map((m) => m[1]);
  for (const lang of langs) {
    const m = source.match(
      new RegExp(`\\n {2}${lang}: *\\{(.*?)\\n {2}\\},?\\n`, "s"),
    );
    if (!m) throw new Error(`scanWrittenKeys: block for '${lang}' not found`);
    blocks[lang] = [...m[1].matchAll(/\n {4}([A-Za-z_][A-Za-z0-9_]*):\s*"/g)].map((x) => x[1]);
  }
  return { langs, blocks };
}

/** Literal values written for one key in one block (last one wins in JS). */
export function scanWrittenValues(source, lang, key) {
  const m = source.match(new RegExp(`\\n {2}${lang}: *\\{(.*?)\\n {2}\\},?\\n`, "s"));
  if (!m) return [];
  const re = new RegExp(`\\n {4}${key}: "([^"]*)"`, "g");
  return [...m[1].matchAll(re)].map((x) => x[1]);
}

// ---------------------------------------------------------------------------
// the extraction
// ---------------------------------------------------------------------------

/**
 * @param {string} source text of js/i18n.js (a clone may be passed in)
 * @returns {{tables: Record<string, Record<string,string>>, locales: string[],
 *            defaultLang: string, fallbackLang: string, duplicateKeys: Record<string,string[]>,
 *            missingIn: Record<string,string[]>, keyOrder: Record<string,string[]>,
 *            placeholders: Record<string,string[]>, stats: object}}
 */
export function extractTables(source) {
  const literal = extractDictLiteral(source);
  const dict = evaluateDict(literal);
  const locales = Object.keys(dict);
  if (locales.length === 0) throw new Error("extractTables: no locale blocks");

  const { blocks } = scanWrittenKeys(source);

  const tables = {};
  const duplicateKeys = {};
  const missingIn = {};
  const keyOrder = {};
  for (const lang of locales) {
    const table = dict[lang];
    if (table === null || typeof table !== "object") {
      throw new Error(`extractTables: locale '${lang}' is not a table`);
    }
    for (const [key, value] of Object.entries(table)) {
      if (typeof value !== "string") {
        throw new Error(`extractTables: ${lang}.${key} is not a string`);
      }
    }
    tables[lang] = { ...table };
    keyOrder[lang] = Object.keys(table);
    const written = blocks[lang] ?? [];
    const seen = new Set();
    const dupes = [];
    for (const key of written) {
      if (seen.has(key)) dupes.push(key);
      seen.add(key);
    }
    duplicateKeys[lang] = [...new Set(dupes)];
    // last-wins must be what the evaluation produced
    for (const key of duplicateKeys[lang]) {
      const values = scanWrittenValues(source, lang, key);
      const evaluated = table[key];
      if (values.length === 0 || values[values.length - 1] !== evaluated) {
        throw new Error(
          `extractTables: ${lang}.${key} written ${values.length}× but evaluated to ` +
            `${JSON.stringify(evaluated)} (expected last-wins ${JSON.stringify(values[values.length - 1])})`,
        );
      }
    }
    const writtenSet = new Set(written);
    const evaluatedSet = new Set(keyOrder[lang]);
    for (const key of writtenSet) {
      if (!evaluatedSet.has(key)) throw new Error(`extractTables: ${lang}.${key} in the scan but not in the table`);
    }
  }

  // the default language and the fallback, read from the module's own code
  const defaultLang = /let currentLang = "([a-z]{2})"/.exec(source)?.[1];
  if (!defaultLang) throw new Error("extractTables: `let currentLang = \"xx\"` not found");
  const fallbackLang = /currentLang = DICT\[lang\] \? lang : "([a-z]{2})"/.exec(source)?.[1];
  if (!fallbackLang) throw new Error("extractTables: setLang fallback not found");
  if (!locales.includes(defaultLang)) throw new Error(`extractTables: default '${defaultLang}' is not a locale`);
  if (!locales.includes(fallbackLang)) throw new Error(`extractTables: fallback '${fallbackLang}' is not a locale`);

  for (const lang of locales) {
    missingIn[lang] = keyOrder[fallbackLang].filter((k) => !(k in tables[lang]));
  }

  const placeholders = {};
  for (const key of keyOrder[fallbackLang]) {
    const found = new Set();
    for (const lang of locales) {
      const text = tables[lang][key];
      if (text === undefined) continue;
      for (const m of text.matchAll(/\{(\w+)\}/g)) found.add(m[1]);
    }
    placeholders[key] = [...found];
  }

  return {
    tables,
    locales,
    defaultLang,
    fallbackLang,
    duplicateKeys,
    missingIn,
    keyOrder,
    placeholders,
    stats: {
      keys: keyOrder[fallbackLang].length,
      keysPerLocale: Object.fromEntries(locales.map((l) => [l, keyOrder[l].length])),
      duplicateKeys: duplicateKeys,
      missingIn: missingIn,
    },
  };
}

/**
 * Runs the reference module itself and asserts the extracted table is what
 * `t()` actually returns. This is the authority check: it does not trust the
 * regexes above, it asks the frozen reference what it prints.
 */
export async function crossCheckAgainstRuntime(extraction, sourcePath = join(REPO, SOURCE_REL)) {
  const mod = await import(pathToFileURL(sourcePath).href);
  const findings = [];
  let checked = 0;
  for (const lang of extraction.locales) {
    mod.setLang(lang);
    if (mod.getLang() !== lang) findings.push(`setLang("${lang}") did not stick (getLang() -> ${mod.getLang()})`);
    for (const key of extraction.keyOrder[lang]) {
      const want = extraction.tables[lang][key];
      const got = mod.t(key);
      checked += 1;
      if (got !== want) findings.push(`t(${JSON.stringify(key)}) under "${lang}" -> ${JSON.stringify(got)}, table says ${JSON.stringify(want)}`);
    }
  }
  // the fallback chain: a key missing from a locale must come out as the
  // fallback language's string, never as the id
  for (const lang of extraction.locales) {
    mod.setLang(lang);
    for (const key of extraction.missingIn[lang]) {
      const got = mod.t(key);
      const want = extraction.tables[extraction.fallbackLang][key];
      checked += 1;
      if (got !== want) findings.push(`t(${JSON.stringify(key)}) under "${lang}" -> ${JSON.stringify(got)}, fallback says ${JSON.stringify(want)}`);
    }
  }
  // an unknown key is returned as-is: this is the bug class (AI_LEGGENDA_NAME)
  for (const lang of extraction.locales) {
    mod.setLang(lang);
    const probe = "__no_such_message_id__";
    checked += 1;
    if (mod.t(probe) !== probe) findings.push(`t(${JSON.stringify(probe)}) under "${lang}" did not return the id itself`);
  }
  // a locale the reference does not have: setLang falls back, silently
  const unknownLocales = [];
  for (const lang of ["de", "fr", "es", "zz"]) {
    if (extraction.locales.includes(lang)) continue;
    mod.setLang(lang);
    const got = mod.getLang();
    const text = mod.t("brand");
    unknownLocales.push({ locale: lang, getLang: got, brandResolvesTo: text });
    checked += 1;
    if (got !== extraction.fallbackLang) {
      findings.push(`setLang(${JSON.stringify(lang)}) -> getLang() ${JSON.stringify(got)}, expected the fallback ${JSON.stringify(extraction.fallbackLang)}`);
    }
  }
  mod.setLang(extraction.defaultLang);
  return { checked, findings, unknownLocales };
}

// ---------------------------------------------------------------------------
// GDScript emission
// ---------------------------------------------------------------------------

export function gdEscape(text) {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t");
}

export function gdUnescape(text) {
  let out = "";
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (ch !== "\\") { out += ch; continue; }
    const next = text[i + 1];
    i += 1;
    if (next === "n") out += "\n";
    else if (next === "r") out += "\r";
    else if (next === "t") out += "\t";
    else if (next === "\\") out += "\\";
    else if (next === '"') out += '"';
    else throw new Error(`gdUnescape: unknown escape \\${next}`);
  }
  return out;
}

export function emitGdScript(extraction, sourceText) {
  const lines = [];
  const { locales, defaultLang, fallbackLang, tables, keyOrder, duplicateKeys, missingIn } = extraction;
  const bytes = Buffer.byteLength(sourceText, "utf8");
  const lineCount = sourceText.split("\n").length - (sourceText.endsWith("\n") ? 1 : 0);

  lines.push("## locale_data.gd — GENERATED FILE, DO NOT EDIT BY HAND.");
  lines.push("##");
  lines.push("## The port's locale data: the string tables of the frozen browser reference");
  lines.push(`## \`${SOURCE_REL}\`, extracted with JavaScript's own object-literal semantics so that a`);
  lines.push("## key written twice resolves exactly as it does in the browser (last value wins,");
  lines.push("## first position kept) — see DUPLICATE_KEYS below.");
  lines.push("##");
  lines.push("## Ids are MESSAGE IDS, not display text: the ported simulation stores ids");
  lines.push("## (`godot/src/sim/state.gd`, `events` / `pointMessage`) and the locale layer");
  lines.push("## resolves them (`godot/src/locale/locale.gd`). A key missing from every table");
  lines.push("## comes back as the id itself — the `AI_LEGGENDA_NAME` bug class. The drift test");
  lines.push("## `tools/i18n-port/verify-i18n-port.mjs` fails when this file stops matching the");
  lines.push("## live reference, or when an id the port emits has no resolvable string.");
  lines.push("##");
  lines.push("## Regenerate:  node tools/i18n-port/extract-i18n.mjs --write");
  lines.push("## Verify:      node tools/i18n-port/verify-i18n-port.mjs");
  lines.push("extends RefCounted");
  lines.push("");
  lines.push(`const SOURCE := "${SOURCE_REL}"`);
  lines.push(`const SOURCE_SHA256 := "${sha256(sourceText)}"`);
  lines.push(`const SOURCE_BYTES := ${bytes}`);
  lines.push(`const SOURCE_LINES := ${lineCount}`);
  lines.push(`const GENERATED_BY := "tools/i18n-port/extract-i18n.mjs"`);
  lines.push(`const DEFAULT_LANG := "${defaultLang}"`);
  lines.push(`const FALLBACK_LANG := "${fallbackLang}"`);
  lines.push(`const LOCALES := [${locales.map((l) => `"${l}"`).join(", ")}]`);
  lines.push("");
  lines.push("## Keys written more than once inside a table literal. JavaScript keeps the last");
  lines.push("## one, and so does this file: the value in TABLES is the last written value.");
  lines.push("const DUPLICATE_KEYS := {");
  for (const lang of locales) {
    lines.push(`\t"${lang}": [${duplicateKeys[lang].map((k) => `"${k}"`).join(", ")}],`);
  }
  lines.push("}");
  lines.push("");
  lines.push(`## Keys this locale does not define. They resolve through FALLBACK_LANG`);
  lines.push(`## ("${fallbackLang}") — never to the id itself. Empty means full coverage.`);
  lines.push("const MISSING_IN := {");
  for (const lang of locales) {
    lines.push(`\t"${lang}": [${missingIn[lang].map((k) => `"${k}"`).join(", ")}],`);
  }
  lines.push("}");
  lines.push("");
  lines.push("## Key order is the reference file's own insertion order, so a diff of this file");
  lines.push("## against a regenerated one reads like a diff of the reference.");
  lines.push("const TABLES := {");
  for (const lang of locales) {
    lines.push(`\t"${lang}": {`);
    for (const key of keyOrder[lang]) {
      lines.push(`\t\t"${key}": "${gdEscape(tables[lang][key])}",`);
    }
    lines.push("\t},");
  }
  lines.push("}");
  lines.push("");
  return lines.join("\n");
}

/**
 * Parses the emitted file back into tables. Strict on purpose: it is the check
 * that the file on disk really says what the extractor said it would.
 */
export function parseGdScript(text) {
  const meta = {};
  for (const key of ["SOURCE", "SOURCE_SHA256", "SOURCE_BYTES", "SOURCE_LINES", "GENERATED_BY", "DEFAULT_LANG", "FALLBACK_LANG"]) {
    const m = text.match(new RegExp(`^const ${key} := (".*"|\\d+)$`, "m"));
    if (!m) throw new Error(`parseGdScript: const ${key} not found`);
    meta[key] = m[1].startsWith('"') ? gdUnescape(m[1].slice(1, -1)) : Number(m[1]);
  }
  const loc = text.match(/^const LOCALES := \[(.*)\]$/m);
  if (!loc) throw new Error("parseGdScript: const LOCALES not found");
  const locales = [...loc[1].matchAll(/"([^"]*)"/g)].map((m) => m[1]);

  const block = (name) => {
    const at = text.indexOf(`const ${name} := {`);
    if (at < 0) throw new Error(`parseGdScript: const ${name} not found`);
    const open = text.indexOf("{", at);
    let depth = 0;
    let inString = false;
    let escaped = false;
    for (let i = open; i < text.length; i += 1) {
      const ch = text[i];
      if (inString) {
        if (escaped) escaped = false;
        else if (ch === "\\") escaped = true;
        else if (ch === '"') inString = false;
        continue;
      }
      if (ch === '"') { inString = true; continue; }
      if (ch === "{") depth += 1;
      else if (ch === "}") { depth -= 1; if (depth === 0) return text.slice(open, i + 1); }
    }
    throw new Error(`parseGdScript: unbalanced braces in ${name}`);
  };

  const parseMapOfString = (name) => {
    const body = block(name);
    const out = {};
    for (const m of body.matchAll(/\t"([^"]*)": \[(.*?)\],\n/g)) {
      out[m[1]] = [...m[2].matchAll(/"([^"]*)"/g)].map((x) => x[1]);
    }
    return out;
  };

  const tablesBody = block("TABLES");
  const tables = {};
  const keyOrder = {};
  const langRe = /\t"([^"]*)": \{\n([\s\S]*?)\n\t\},/g;
  for (const m of tablesBody.matchAll(langRe)) {
    const lang = m[1];
    if (tables[lang]) throw new Error(`parseGdScript: locale '${lang}' twice`);
    tables[lang] = {};
    keyOrder[lang] = [];
    for (const line of m[2].split("\n")) {
      const km = line.match(/^\t\t"((?:[^"\\]|\\.)*)": "((?:[^"\\]|\\.)*)",$/);
      if (!km) throw new Error(`parseGdScript: unparsable line in ${lang}: ${JSON.stringify(line)}`);
      const key = gdUnescape(km[1]);
      if (key in tables[lang]) throw new Error(`parseGdScript: duplicate key ${lang}.${key}`);
      tables[lang][key] = gdUnescape(km[2]);
      keyOrder[lang].push(key);
    }
  }

  return {
    meta,
    locales,
    tables,
    keyOrder,
    duplicateKeys: parseMapOfString("DUPLICATE_KEYS"),
    missingIn: parseMapOfString("MISSING_IN"),
  };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function report(extraction, runtime) {
  const s = extraction.stats;
  console.log(JSON.stringify({
    source: SOURCE_REL,
    sourceSha256: sha256(readFileSync(join(REPO, SOURCE_REL), "utf8")),
    locales: extraction.locales,
    defaultLang: extraction.defaultLang,
    fallbackLang: extraction.fallbackLang,
    keys: s.keys,
    keysPerLocale: s.keysPerLocale,
    duplicateKeys: s.duplicateKeys,
    missingIn: s.missingIn,
    runtimeCrossCheck: { checked: runtime.checked, findings: runtime.findings },
    requestedLocalesNotInReference: runtime.unknownLocales,
  }, null, 2));
}

async function main() {
  const args = process.argv.slice(2);
  const sourceText = readFileSync(join(REPO, SOURCE_REL), "utf8");
  const extraction = extractTables(sourceText);
  const written = emitGdScript(extraction, sourceText);
  const runtime = await crossCheckAgainstRuntime(extraction);
  const roundTrip = parseGdScript(written);
  const roundTripOk =
    JSON.stringify(roundTrip.tables) === JSON.stringify(extraction.tables) &&
    JSON.stringify(roundTrip.duplicateKeys) === JSON.stringify(extraction.duplicateKeys) &&
    JSON.stringify(roundTrip.missingIn) === JSON.stringify(extraction.missingIn);
  if (!roundTripOk) throw new Error("emit/parse round-trip mismatch — the emitter is broken");
  if (runtime.findings.length > 0) throw new Error(`runtime cross-check failed: ${runtime.findings.join("; ")}`);

  if (args.includes("--write")) {
    mkdirSync(join(REPO, "godot/src/locale"), { recursive: true });
    writeFileSync(join(REPO, OUT_REL), written, "utf8");
  }
  if (args.includes("--json")) {
    console.log(JSON.stringify(extraction, null, 2));
  } else {
    report(extraction, runtime);
  }
  console.log(`# emit/parse round-trip ok; ${OUT_REL} ${args.includes("--write") ? "written" : "NOT written (pass --write)"} (${Buffer.byteLength(written, "utf8")} bytes)`);
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  main().catch((err) => {
    console.error(`FAIL: ${err.message}`);
    process.exit(1);
  });
}
