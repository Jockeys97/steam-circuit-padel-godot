#!/usr/bin/env node
/**
 * emit-analysis.mjs — where the ported simulation emits message ids, and whether
 * each emitted id has a resolvable string.
 *
 * The port stores message ids where the reference stored rendered text
 * (`godot/src/sim/state.gd`: `events` / `pointMessage` hold ids, `t()` is a
 * presentation coupling). Nothing in the port writes those ids down, so this
 * module derives them from the source:
 *
 *   - every `add_event(state, <expr>)` call site in `godot/src/sim/*.gd`;
 *   - every `state.pointMessage = <expr>` / `+= <expr>` assignment;
 *   - literal ids inside a site are taken directly (a ternary of literals is two
 *     ids, not one); comparison operands (`== "player"`) are not ids and are
 *     dropped;
 *   - a *dynamic* site (a `%` format, or a bare variable) must be declared in
 *     `tools/i18n-port/emit-sites.json`. The declaration carries the values that
 *     get substituted, and those values are re-derived from the source and must
 *     match: the literals at the call sites of the function that supplies them,
 *     the literals inside the function itself, or the suffix set of the
 *     reference table's own keys.
 *
 * A dynamic site that is not declared, or a declared substitution that no longer
 * matches its source, is a hard failure. That is the door the `AI_LEGGENDA_NAME`
 * bug walked through: an id nobody had written down anywhere.
 *
 * No engine, no dependencies, no writes. Usage:
 *   node tools/i18n-port/emit-analysis.mjs          # human-readable report
 *   node tools/i18n-port/emit-analysis.mjs --json   # machine-readable
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { REPO } from "./extract-i18n.mjs";

export const SIM_FILES = ["godot/src/sim/sim.gd", "godot/src/sim/state.gd", "godot/src/sim/entities.gd"];
export const EMIT_SITES_REL = "tools/i18n-port/emit-sites.json";

// ---------------------------------------------------------------------------
// source-level helpers
// ---------------------------------------------------------------------------

/** Normalises whitespace so an anchor survives reformatting. */
export function normalize(text) {
  return text.replace(/\s+/g, " ").trim();
}

/** Drops a GDScript `#` comment, honouring string literals. Comments are not code. */
export function stripLineComment(line) {
  let inString = false;
  let escaped = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') { inString = true; continue; }
    if (ch === "#") return line.slice(0, i);
  }
  return line;
}

/**
 * Balanced-paren slice of a call's argument list, given the ABSOLUTE offset of
 * the callee name in `source`. Throws when the call spans lines: that shape has
 * never occurred in this port and must be looked at by a human, not guessed at.
 */
export function callArgText(source, calleeAt, calleeName) {
  const open = source.indexOf("(", calleeAt + calleeName.length);
  if (open < 0) throw new Error(`callArgText: no '(' after ${calleeName} at ${calleeAt}`);
  let depth = 0;
  let inString = null;
  let escaped = false;
  for (let i = open; i < source.length; i += 1) {
    const ch = source[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === inString) inString = null;
      continue;
    }
    if (ch === '"' || ch === "'") { inString = ch; continue; }
    if (ch === "\n") throw new Error(`callArgText: ${calleeName} call spans lines (unsupported shape: ${source.slice(calleeAt, calleeAt + 80)})`);
    if (ch === "(") depth += 1;
    else if (ch === ")") {
      depth -= 1;
      if (depth === 0) return source.slice(open + 1, i);
    }
  }
  throw new Error(`callArgText: unbalanced parens for ${calleeName}`);
}

/**
 * Every double-quoted literal in an expression, unescaped, with the operands of
 * `==` / `!=` comparisons removed first — `winner == "player"` is not an id.
 */
export function literalsIn(expr, { raw = false } = {}) {
  const cleaned = raw
    ? expr
    : expr
      // `assessment["quality"]` is a table index, not a message id
      .replace(/\[\s*"(?:[^"\\]|\\.)*"\s*\]/g, "")
      // `winner == "player"` / `kind != "long"` are comparisons, not ids
      .replace(/(==|!=)\s*"(?:[^"\\]|\\.)*"/g, "");
  const out = [];
  let inString = false;
  let escaped = false;
  let current = "";
  for (let i = 0; i < cleaned.length; i += 1) {
    const ch = cleaned[i];
    if (inString) {
      if (escaped) {
        current += ch === "n" ? "\n" : ch === "t" ? "\t" : ch;
        escaped = false;
      } else if (ch === "\\") escaped = true;
      else if (ch === '"') { out.push(current); current = ""; inString = false; }
      else current += ch;
      continue;
    }
    if (ch === '"') inString = true;
  }
  return out;
}

export function splitTopLevel(text) {
  const parts = [];
  let depth = 0;
  let inString = null;
  let escaped = false;
  let current = "";
  for (const ch of text) {
    if (inString) {
      current += ch;
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === inString) inString = null;
      continue;
    }
    if (ch === '"' || ch === "'") { inString = ch; current += ch; continue; }
    if (ch === "(" || ch === "[" || ch === "{") depth += 1;
    if (ch === ")" || ch === "]" || ch === "}") depth -= 1;
    if (ch === "," && depth === 0) { parts.push(current.trim()); current = ""; continue; }
    current += ch;
  }
  parts.push(current.trim());
  return parts;
}

function functionOf(lines, lineIndex) {
  for (let i = lineIndex; i >= 0; i -= 1) {
    const m = lines[i].match(/^\s*(?:static )?func (\w+)/);
    if (m) return m[1];
  }
  return null;
}

/** The lines of one function body (comments removed), exclusive of the next func. */
export function functionBody(source, name) {
  const lines = source.split("\n").map(stripLineComment);
  let start = -1;
  for (let i = 0; i < lines.length; i += 1) {
    if (new RegExp(`^\\s*(?:static )?func ${name}\\b`).test(lines[i])) { start = i; break; }
  }
  if (start < 0) return null;
  const body = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^\s*(?:static )?func \w+/.test(lines[i])) break;
    body.push(lines[i]);
  }
  return body;
}

/** String literals of the Nth (0-based) argument at every call site of `callee`. */
export function literalsAtCallSites(source, callee, argIndex, { raw = false } = {}) {
  const out = [];
  const re = new RegExp(`\\b${callee}\\(`, "g");
  let m;
  while ((m = re.exec(source)) !== null) {
    const lineStart = source.lastIndexOf("\n", m.index) + 1;
    const lineEnd = source.indexOf("\n", m.index);
    const line = source.slice(lineStart, lineEnd < 0 ? source.length : lineEnd);
    if (new RegExp(`^\\s*(?:static )?func ${callee}\\b`).test(line)) continue; // the definition
    if (stripLineComment(line).trim() === "") continue;
    let args;
    try { args = callArgText(source, m.index, callee); } catch { continue; }
    const parts = splitTopLevel(args);
    if (parts.length <= argIndex) continue;
    out.push(...literalsIn(parts[argIndex], { raw }));
  }
  return [...new Set(out)];
}

// ---------------------------------------------------------------------------
// sites
// ---------------------------------------------------------------------------

/**
 * @returns {Array<{file, line, fn, kind, expr, raw, literals, dynamic, appends}>}
 */
export function collectEmitSites(files = SIM_FILES, readText = (rel) => readFileSync(join(REPO, rel), "utf8")) {
  const sites = [];
  for (const rel of files) {
    const rawSource = readText(rel);
    const rawLines = rawSource.split("\n");
    const source = rawSource.split("\n").map(stripLineComment).join("\n");
    const lines = source.split("\n");
    let offset = 0;
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i];
      const fn = functionOf(lines, i);
      const re = /add_event\(/g;
      let m;
      while ((m = re.exec(line)) !== null) {
        if (/^\s*(?:static )?func add_event\b/.test(line)) continue;
        const abs = offset + m.index;
        const rawArgs = callArgText(source, abs, "add_event");
        const expr = splitTopLevel(rawArgs)[1] ?? "";
        sites.push({
          file: rel, line: i + 1, fn, kind: "add_event", expr: expr.trim(),
          raw: normalize(line), literals: literalsIn(expr), dynamic: isDynamic(expr),
        });
      }
      const assign = line.match(/^(\s*)state\.pointMessage\s*(\+?=)\s*(.+?)\s*$/);
      if (assign) {
        const expr = assign[3];
        sites.push({
          file: rel, line: i + 1, fn, kind: "pointMessage", expr,
          raw: normalize(line), literals: literalsIn(expr), dynamic: isDynamic(expr),
          appends: assign[2] === "+=",
        });
      }
      offset += line.length + 1;
    }
  }
  return sites;
}

function isDynamic(expr) {
  if (expr.trim() === '""') return false; // `pointMessage = ""` clears the field: not an id
  if (/%/.test(expr)) return true;
  return literalsIn(expr).filter((x) => x !== "").length === 0;
}

export const siteKey = (site) => `${site.file}|${site.kind}|${normalize(site.expr)}`;

export function dynamicSiteMap(sites) {
  const map = new Map();
  for (const site of sites) {
    if (!site.dynamic) continue;
    const key = siteKey(site);
    if (!map.has(key)) map.set(key, { key, sites: [] });
    map.get(key).sites.push(site);
  }
  return map;
}

// ---------------------------------------------------------------------------
// expansion of the declared dynamic sites
// ---------------------------------------------------------------------------

/**
 * Resolves one declared substitution set against the source it claims to come
 * from. Returns {values, failures}.
 */
export function resolveSubstitutionSet(name, decl, ctx) {
  const failures = [];
  const { texts, tables } = ctx;
  const verify = decl.verify;
  let derived = null;
  const needsFile = verify.kind === "literalsAtCallSitesOf" || verify.kind === "idLiteralsInFunction";
  const text = needsFile ? texts[verify.file] : null;
  if (needsFile && text === undefined) return { values: decl.values, failures: [`substitution set '${name}': file '${verify.file}' not read`] };
  if (verify.kind === "literalsAtCallSitesOf") {
    derived = literalsAtCallSites(text, verify.target, verify.argIndex, { raw: true });
  } else if (verify.kind === "idLiteralsInFunction") {
    const body = functionBody(text, verify.target);
    if (body === null) {
      failures.push(`substitution set '${name}': function '${verify.target}' not found in ${verify.file}`);
    } else {
      // only id-shaped literals: the substitutions of an id template are ids
      derived = [...new Set(body.flatMap((l) => literalsIn(l)))]
        .filter((x) => typeof tables.it[x] === "string" || typeof tables.en[x] === "string");
    }
  } else if (verify.kind === "suffixesOfTableKeys") {
    const re = new RegExp(verify.pattern);
    derived = [...new Set(Object.keys(tables.it).filter((k) => re.test(k)).map((k) => re.exec(k)[1]))];
  } else {
    failures.push(`substitution set '${name}': unknown verify.kind '${verify.kind}'`);
  }
  if (derived !== null) {
    const a = [...new Set(derived)].sort();
    const b = [...new Set(decl.values)].sort();
    if (JSON.stringify(a) !== JSON.stringify(b)) {
      failures.push(
        `substitution set '${name}': declared ${JSON.stringify(b)} but ${JSON.stringify(verify)} yields ${JSON.stringify(a)}`,
      );
    }
  }
  if (decl.values.length === 0) failures.push(`substitution set '${name}': no values declared`);
  return { values: decl.values, failures };
}

/** Expands one declared dynamic site into the ids it can emit. */
export function expandSite(decl, sites, ctx) {
  const failures = [];
  const exp = decl.expansion;
  const ids = [];
  const push = (id) => { if (id !== "") ids.push(id); };

  if (exp.kind === "ids") {
    const set = ctx.substitutions[exp.from];
    if (!set) failures.push(`${decl.id ?? siteKey(decl)}: unknown substitution set '${exp.from}'`);
    else for (const v of set) push(exp.lower ? v.toLowerCase() : v);
  } else if (exp.kind === "template-substitution") {
    const set = ctx.substitutions[exp.from];
    if (!set) failures.push(`${decl.id ?? siteKey(decl)}: unknown substitution set '${exp.from}'`);
    else for (const v of set) push(exp.template.replace(/%s/g, exp.lower ? v.toLowerCase() : v));
  } else if (exp.kind === "enum") {
    if (exp.verify) {
      const body = functionBody(ctx.texts[decl.file], exp.verify.target);
      if (body === null) {
        failures.push(`${decl.id ?? siteKey(decl)}: function '${exp.verify.target}' not found in ${decl.file}`);
      } else {
        const derived = [...new Set(body.flatMap((l) => literalsIn(l)))]
          .filter((x) => typeof ctx.tables.it[x] === "string" || typeof ctx.tables.en[x] === "string");
        const a = [...derived].sort();
        const b = [...new Set(exp.values)].sort();
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          failures.push(`${decl.id ?? siteKey(decl)}: declared ${JSON.stringify(b)} but ${exp.verify.target} contains ${JSON.stringify(a)}`);
        }
      }
    }
    for (const v of exp.values) push(v);
  } else if (exp.kind === "template-range") {
    const list = ctx.frozen[exp.countFromFrozen];
    if (!Array.isArray(list) || list.length === 0) {
      failures.push(`${decl.id ?? siteKey(decl)}: frozen '${exp.countFromFrozen}' is not a non-empty list`);
    } else {
      for (let i = 0; i < list.length; i += 1) push(exp.template.replace(/%d/g, String(i)));
    }
  } else if (exp.kind === "suffix-append") {
    const set = ctx.substitutions[exp.suffixesFrom];
    if (!set) failures.push(`${decl.id ?? siteKey(decl)}: unknown substitution set '${exp.suffixesFrom}'`);
    else for (const prefix of exp.prefixes) for (const suffix of set) push(`${prefix}${exp.separator}${suffix}`);
  } else {
    failures.push(`${decl.id ?? siteKey(decl)}: unknown expansion kind '${exp.kind}'`);
  }
  return { ids: [...new Set(ids)], failures };
}

/**
 * The whole derivation: literal ids, declared dynamic ids, reason sets.
 * @returns {{ids: Map<string,string[]>, sites: Array, failures: string[], dynamicDeclared: Set<string>, dynamicObserved: Set<string>}}
 */
export function deriveEmittedIds({ sites, declarations, texts, tables, frozen }) {
  const failures = [];
  const ids = new Map();
  const add = (id, where) => {
    if (!ids.has(id)) ids.set(id, []);
    if (!ids.get(id).includes(where)) ids.get(id).push(where);
  };

  const substitutions = {};
  for (const [name, decl] of Object.entries(declarations.substitutionSets ?? {})) {
    const { values, failures: f } = resolveSubstitutionSet(name, decl, { texts, tables });
    failures.push(...f);
    const expandedByTemplate = new Set((decl.expand ?? []).map((spec) => spec.value));
    const out = values.filter((v) => !expandedByTemplate.has(v));
    for (const spec of decl.expand ?? []) {
      const from = substitutions[spec.from];
      if (!from) { failures.push(`substitution set '${name}': expand.from '${spec.from}' is not a set`); continue; }
      for (const v of from) out.push(spec.value.replace(/%s/g, spec.lower ? v.toLowerCase() : v));
    }
    substitutions[name] = [...new Set(out)];
  }

  // literal sites
  for (const site of sites) {
    if (site.dynamic) continue;
    for (const id of site.literals) {
      if (id === "") continue; // `pointMessage = ""` clears the field, it is not an id
      add(id, `${site.file}:${site.line}`);
    }
  }

  // declared dynamic sites
  const observed = dynamicSiteMap(sites);
  const declaredKeys = new Set();
  for (const decl of declarations.dynamicSites ?? []) {
    if (decl.literalSite) continue; // documentation of a literal site, not a dynamic one
    const key = `${decl.file}|${decl.kind ?? "add_event"}|${normalize(decl.expr)}`;
    declaredKeys.add(key);
    const found = observed.get(key);
    if (!found) {
      failures.push(`declared dynamic site not found in the source: ${key}`);
      continue;
    }
    if (decl.fn) {
      for (const site of found.sites) {
        if (site.fn !== decl.fn) failures.push(`${key} is declared in '${decl.fn}' but line ${site.line} sits in '${site.fn}'`);
      }
    }
    for (const anchor of decl.anchors ?? []) {
      if (!texts[decl.file].includes(anchor)) failures.push(`${key}: anchor not found in ${decl.file}: ${JSON.stringify(anchor)}`);
    }
    const { ids: expanded, failures: f } = expandSite(
      { ...decl, id: decl.id ?? key },
      found.sites,
      { substitutions, texts, frozen, tables },
    );
    failures.push(...f);
    for (const id of expanded) add(id, `${decl.file}:${found.sites[0].line}`);
  }
  for (const key of observed.keys()) {
    if (!declaredKeys.has(key)) {
      failures.push(
        `UNDECLARED dynamic emit site: ${key} — add it to ${EMIT_SITES_REL} with its substitutions and the source they come from, ` +
          `so an id nobody has written down cannot reach the screen`,
      );
    }
  }

  return { ids, sites, failures, dynamicDeclared: declaredKeys, dynamicObserved: new Set(observed.keys()) };
}

// ---------------------------------------------------------------------------
// resolution (the executable form of godot/src/locale/locale_rules.json)
// ---------------------------------------------------------------------------

export function mirrorResolver(tables, rules, fallbackLang = "it") {
  const lookup = (key, lang) => {
    const table = tables[lang] ?? {};
    if (Object.prototype.hasOwnProperty.call(table, key)) return table[key];
    const fallback = tables[fallbackLang] ?? {};
    if (Object.prototype.hasOwnProperty.call(fallback, key)) return fallback[key];
    return key;
  };
  const substitute = (text, params) => {
    let out = text;
    for (const [name, value] of Object.entries(params)) out = out.split(`{${name}}`).join(String(value));
    return out;
  };
  const t = (id, params = {}, lang = rules.defaultLocale) => {
    const sep = rules.compositeSeparator ?? ":";
    const cut = id.indexOf(sep);
    if (cut > 0) {
      const parent = id.slice(0, cut);
      const arg = id.slice(cut + sep.length);
      const rule = rules.compositeRules?.[parent];
      if (rule) {
        if (rule.binding === "placeholder") return substitute(lookup(parent, lang), { [rule.placeholder]: t(arg, {}, lang) });
        if (rule.binding === "suffix") return `${lookup(parent, lang)}${arg ? rule.separator + t(arg, {}, lang) : ""}`;
      }
    }
    return substitute(lookup(id, lang), params);
  };
  return { t, lookup, substitute };
}

/**
 * Classifies one emitted id.
 *   ok        — a table key with no unfillable placeholder, or a composite with a rule
 *   no-params — a table key whose placeholders the port's id cannot carry
 *   no-key    — not a table key, and no composite rule
 */
export function classifyId(id, tables, rules, fallbackLang = "it", depth = 0) {
  const placeholders = (key) => {
    const texts = [tables.default, tables.it, tables.en].map((tb) => tb?.[key]).filter((x) => typeof x === "string");
    const set = new Set();
    for (const text of texts) for (const m of text.matchAll(/\{(\w+)\}/g)) set.add(m[1]);
    return [...set];
  };
  if (depth > 4) return { category: "no-key", detail: "composite nesting deeper than 4" };
  const sep = rules.compositeSeparator ?? ":";
  const cut = id.indexOf(sep);
  if (cut > 0) {
    const parent = id.slice(0, cut);
    const arg = id.slice(cut + sep.length);
    const rule = rules.compositeRules?.[parent];
    if (rule) {
      const argClass = classifyId(arg, tables, rules, fallbackLang, depth + 1);
      if (argClass.category !== "ok") {
        return {
          category: argClass.category, rule: parent, inherits: arg,
          detail: `composite '${parent}' has a rule but its argument '${arg}' does not resolve (${argClass.detail})`,
        };
      }
      if (rule.binding === "placeholder" && !placeholders(parent).includes(rule.placeholder)) {
        return { category: "no-params", detail: `template '${parent}' has no {${rule.placeholder}} placeholder`, rule: parent };
      }
      return { category: "ok", detail: `composite rule '${parent}' (${rule.binding})`, rule: parent };
    }
  }
  if (typeof tables.it[id] === "string") {
    const ph = placeholders(id);
    if (ph.length > 0) return { category: "no-params", detail: `template needs {${ph.join("} {")}} and the event id carries no parameters` };
    return { category: "ok", detail: "plain key" };
  }
  if (typeof tables.en[id] === "string") return { category: "ok", detail: "key present in en only" };
  return { category: "no-key", detail: "no table key and no composite rule" };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

export function loadPortContext() {
  const rules = JSON.parse(readFileSync(join(REPO, "tools/i18n-port/resolve-rules.json"), "utf8"));
  const declarations = JSON.parse(readFileSync(join(REPO, EMIT_SITES_REL), "utf8"));
  const files = [...new Set(SIM_FILES.concat((declarations.dynamicSites ?? []).map((d) => d.file)))];
  const texts = Object.fromEntries(files.map((rel) => [rel, readFileSync(join(REPO, rel), "utf8")]));
  const frozen = JSON.parse(readFileSync(join(REPO, "godot/src/sim/frozen/data.json"), "utf8"));
  return { rules, declarations, texts, frozen, files };
}

async function main() {
  const { extractTables } = await import("./extract-i18n.mjs");
  const extraction = extractTables(readFileSync(join(REPO, "js/i18n.js"), "utf8"));
  const { rules, declarations, texts, frozen, files } = loadPortContext();
  const sites = collectEmitSites(files, (rel) => texts[rel]);
  const tables = { it: extraction.tables.it, en: extraction.tables.en, default: extraction.tables[rules.defaultLocale] };
  const derived = deriveEmittedIds({ sites, declarations, texts, tables, frozen });

  const rows = [...derived.ids.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([id, where]) => ({ id, sites: where, ...classifyId(id, tables, rules, extraction.fallbackLang) }));

  if (process.argv.includes("--json")) {
    console.log(JSON.stringify({ sites: sites.length, failures: derived.failures, ids: rows }, null, 2));
  } else {
    const byCat = {};
    for (const row of rows) byCat[row.category] = (byCat[row.category] ?? 0) + 1;
    console.log(`# emit sites: ${sites.length} (${derived.dynamicObserved.size} distinct dynamic site shapes, all declared)`);
    console.log(`# ids the port can emit: ${rows.length} — ${JSON.stringify(byCat)}`);
    for (const row of rows.filter((r) => r.category !== "ok")) {
      console.log(`  ${row.category.padEnd(10)} ${row.id}  [${row.sites.join(", ")}] — ${row.detail}`);
    }
  }
  for (const f of derived.failures) console.log(`  FAIL ${f}`);
  if (derived.failures.length > 0) process.exitCode = 1;
}

if (process.argv[1] && process.argv[1].endsWith("emit-analysis.mjs")) {
  main().catch((err) => { console.error(`FAIL: ${err.stack}`); process.exit(1); });
}
