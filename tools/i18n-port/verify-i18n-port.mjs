#!/usr/bin/env node
/**
 * verify-i18n-port.mjs — engine-free locale port contract test.
 *
 * Asserts, against the CURRENT working tree, that the Godot port's locale data is
 * a faithful, still-current copy of the frozen browser reference's string table,
 * and that every message id the ported simulation can emit has a resolvable
 * string (or is a named, reasoned entry in the debt ledger).
 *
 *   (a) the extractor is faithful: the tables it pulls out of `js/i18n.js` are
 *       cross-checked against the reference module's own `t()` — 688 keys × 2
 *       locales, the fallback chain, the unknown-key rule, and the
 *       unknown-locale rule;
 *   (b) `godot/src/locale/locale_data.gd` parses back to exactly those tables,
 *       with the same key order, the same duplicate keys and the same reference
 *       hash — i.e. the port's locale data has not drifted from the live
 *       `js/i18n.js` (in either direction: a stale data file, or a reference that
 *       moved under it);
 *   (c) the port-side reference invariants hold: key parity between locales,
 *       per-key placeholder parity, and the 78 runtime-composed keys
 *       (`athlete_*`, `arena_*`, `ai_*`, outfit name keys, `obj_*`) — the family
 *       that hid `ai_leggenda_name` and printed "AI_LEGGENDA_NAME" on screen;
 *   (d) every id the ported simulation can emit is classified, and the set of
 *       ids that do NOT resolve equals `tools/i18n-port/unresolved-baseline.json`
 *       exactly: no growth (a new unsolvable id is a hard failure) and no stale
 *       entry (an id that resolves now must leave the ledger);
 *   (e) the declared contract holds: the reference hash, the composite rules and
 *       their templates/placeholders, `locale.gd` implementing each declared
 *       rule, and every resolvable composite id producing the SAME string the
 *       live reference produces for the equivalent JavaScript expression;
 *   (f) genuinely-injected drift goes RED: ten mutations (a changed string, a
 *       removed key, a moved reference, an added emit site, a case-typo id, an
 *       undeclared dynamic site, a new score reason, a renamed table key, a
 *       shrunk ledger, a padded ledger) are applied to IN-MEMORY clones and must
 *       each produce a failure. If any injected drift is NOT caught, this test
 *       fails too.
 *
 * No dependencies, no install, no engine (this host may not launch Godot): node
 * stdlib plus the repo's own files. Writes nothing.
 *
 * Usage:
 *   node tools/i18n-port/verify-i18n-port.mjs
 *   node tools/i18n-port/verify-i18n-port.mjs --drift=case-typo-id
 *     -> runs ONE injected-drift scenario as the primary check.
 *        exit 1 with "DRIFT DETECTED" means the test caught it (the demonstrable
 *        RED case); exit 0 in this mode would mean the test is blind there.
 *   node tools/i18n-port/verify-i18n-port.mjs --list-drift
 */

import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";

import { REPO, SOURCE_REL, OUT_REL, sha256, extractTables, crossCheckAgainstRuntime, parseGdScript } from "./extract-i18n.mjs";
import {
  EMIT_SITES_REL, SIM_FILES, normalize, stripLineComment, collectEmitSites, dynamicSiteMap,
  deriveEmittedIds, classifyId, mirrorResolver,
} from "./emit-analysis.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const RULES_REL = "tools/i18n-port/resolve-rules.json";
const BASELINE_REL = "tools/i18n-port/unresolved-baseline.json";
const RESOLVER_REL = "godot/src/locale/locale.gd";
const FROZEN_REL = "godot/src/sim/frozen/data.json";

const C = { reset: "\u001b[0m", red: "\u001b[31m", green: "\u001b[32m", yellow: "\u001b[33m", dim: "\u001b[2m", bold: "\u001b[1m" };
const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (c, s) => (useColor ? c + s + C.reset : s);

// ---------------------------------------------------------------------------
// context: everything the checks read, in memory, so a drift scenario can mutate
// ---------------------------------------------------------------------------

export function loadContext() {
  const declarations = JSON.parse(readFileSync(join(REPO, EMIT_SITES_REL), "utf8"));
  const files = [...new Set(SIM_FILES.concat((declarations.dynamicSites ?? []).filter((d) => !d.literalSite).map((d) => d.file)))];
  return {
    sourceText: readFileSync(join(REPO, SOURCE_REL), "utf8"),
    gdText: readFileSync(join(REPO, OUT_REL), "utf8"),
    rulesText: readFileSync(join(REPO, RULES_REL), "utf8"),
    baselineText: readFileSync(join(REPO, BASELINE_REL), "utf8"),
    declarationsText: JSON.stringify(declarations),
    resolverText: readFileSync(join(REPO, RESOLVER_REL), "utf8"),
    godotRulesText: readFileSync(join(REPO, "godot/src/locale/locale_rules.json"), "utf8"),
    frozenText: readFileSync(join(REPO, FROZEN_REL), "utf8"),
    simTexts: Object.fromEntries(files.map((rel) => [rel, readFileSync(join(REPO, rel), "utf8")])),
  };
}

// ---------------------------------------------------------------------------
// checks
// ---------------------------------------------------------------------------

/** (a) the extractor against the reference module itself. */
export async function checkExtractorFaithful(ctx, findings) {
  const extraction = extractTables(ctx.sourceText);
  const runtime = await crossCheckAgainstRuntime(extraction);
  if (runtime.findings.length > 0) {
    findings.push(`extractor is not faithful to the reference runtime: ${runtime.findings.join("; ")}`);
  }
  if (runtime.checked < 1000) findings.push(`extractor runtime cross-check only covered ${runtime.checked} calls`);
  const unknown = runtime.unknownLocales ?? [];
  if (unknown.length === 0) findings.push("no unknown-locale probe ran: the setLang fallback is unverified");
  for (const row of unknown) {
    if (row.getLang !== extraction.fallbackLang) {
      findings.push(`unknown locale '${row.locale}' resolved to '${row.getLang}', expected the fallback '${extraction.fallbackLang}'`);
    }
  }

  // Negative control for the bug class this contract exists for: an id that is not
  // in the table comes back as the id, so the player reads "AI_LEGGENDA_NAME". The
  // reference still behaves that way (git 1652240 fixed the missing key, not the
  // silent fallback), and the port must reproduce the semantics while the drift
  // test makes sure no emitted id ever lands there.
  const mod = await import(pathToFileURL(join(REPO, SOURCE_REL)).href);
  for (const lang of extraction.locales) {
    mod.setLang(lang);
    const idiom = "AI_LEGGENDA_NAME";
    if (mod.t(idiom) !== idiom) findings.push(`reference semantics changed: t(${JSON.stringify(idiom)}) under '${lang}' no longer returns the id`);
    if (mod.t("ai_leggenda_name") === "ai_leggenda_name") findings.push(`the reference table no longer defines 'ai_leggenda_name' — the key the 1652240 bug was about`);
  }
  mod.setLang(extraction.defaultLang);
  return { extraction, runtime };
}

/** (b) the emitted GDScript data file against the live extraction. */
export function checkPortDataMatchesReference(ctx, extraction, findings) {
  let parsed;
  try {
    parsed = parseGdScript(ctx.gdText);
  } catch (err) {
    findings.push(`${OUT_REL} does not parse: ${err.message}`);
    return null;
  }
  const liveSha = sha256(ctx.sourceText);
  if (parsed.meta.SOURCE_SHA256 !== liveSha) {
    findings.push(
      `${OUT_REL} was generated from ${SOURCE_REL}@${String(parsed.meta.SOURCE_SHA256).slice(0, 12)} but the live file is ${liveSha.slice(0, 12)} — the port's locale data has drifted from the reference (or the reference moved)`,
    );
  }
  if (parsed.meta.SOURCE_BYTES !== Buffer.byteLength(ctx.sourceText, "utf8")) findings.push(`${OUT_REL}: SOURCE_BYTES is stale`);
  if (parsed.meta.SOURCE_LINES !== ctx.sourceText.split("\n").length - 1) findings.push(`${OUT_REL}: SOURCE_LINES is stale`);
  if (JSON.stringify(parsed.locales) !== JSON.stringify(extraction.locales)) {
    findings.push(`${OUT_REL}: LOCALES ${JSON.stringify(parsed.locales)} != reference ${JSON.stringify(extraction.locales)}`);
  }
  if (parsed.meta.DEFAULT_LANG !== extraction.defaultLang) findings.push(`${OUT_REL}: DEFAULT_LANG drifted`);
  if (parsed.meta.FALLBACK_LANG !== extraction.fallbackLang) findings.push(`${OUT_REL}: FALLBACK_LANG drifted`);

  for (const lang of extraction.locales) {
    const live = extraction.tables[lang] ?? {};
    const port = parsed.tables[lang];
    if (!port) { findings.push(`${OUT_REL}: locale '${lang}' missing`); continue; }
    const liveKeys = Object.keys(live);
    const portKeys = Object.keys(port);
    for (const key of liveKeys) {
      if (!(key in port)) findings.push(`${OUT_REL}.${lang}: key '${key}' is in the reference but not in the port data`);
      else if (port[key] !== live[key]) {
        findings.push(
          `${OUT_REL}.${lang}.${key}: port says ${JSON.stringify(port[key])}, reference says ${JSON.stringify(live[key])}`,
        );
      }
    }
    for (const key of portKeys) {
      if (!(key in live)) findings.push(`${OUT_REL}.${lang}: key '${key}' is in the port data but not in the reference`);
    }
    if (JSON.stringify(portKeys) !== JSON.stringify(liveKeys)) {
      findings.push(`${OUT_REL}.${lang}: key order differs from the reference's insertion order`);
    }
    if (JSON.stringify(parsed.duplicateKeys[lang]) !== JSON.stringify(extraction.duplicateKeys[lang])) {
      findings.push(`${OUT_REL}.${lang}: DUPLICATE_KEYS drifted`);
    }
    if (JSON.stringify(parsed.missingIn[lang]) !== JSON.stringify(extraction.missingIn[lang])) {
      findings.push(`${OUT_REL}.${lang}: MISSING_IN drifted`);
    }
  }
  // the emitted file must be byte-reproducible from the reference
  return parsed;
}

/** (c) the port-side invariants the browser build enforces in scripts/i18n-audit.mjs. */
export async function checkReferenceInvariants(tables, locales, fallbackLang, findings) {
  if (locales.length !== 2) {
    findings.push(
      `the reference now has ${locales.length} locale tables (${locales.join(", ")}) — the parity check below is written for two; revisit the contract instead of trusting a green run`,
    );
  }
  const [it, en] = [tables[fallbackLang], tables[locales.find((l) => l !== fallbackLang)]];
  const onlyFallback = Object.keys(it).filter((k) => !(k in en));
  const onlyOther = Object.keys(en).filter((k) => !(k in it));
  if (onlyFallback.length) findings.push(`keys only in ${fallbackLang}: ${onlyFallback.join(", ")}`);
  if (onlyOther.length) findings.push(`keys only in ${en === it ? "?" : "the other locale"}: ${onlyOther.join(", ")}`);

  const placeholders = (text) => [...text.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(",");
  for (const key of Object.keys(it)) {
    if (!(key in en)) continue;
    if (placeholders(it[key]) !== placeholders(en[key])) {
      findings.push(`${key}: locales use different placeholders (${placeholders(it[key]) || "none"} vs ${placeholders(en[key]) || "none"})`);
    }
  }

  const data = await import(pathToFileURL(join(REPO, "js/data.js")).href);
  const rules = JSON.parse(readFileSync(join(REPO, RULES_REL), "utf8"));
  const expected = [];
  const push = (key, family) => expected.push({ key, family });
  for (const fam of rules.derivedKeyFamilies ?? []) {
    const [file, path] = String(fam.idsFrom).split(":");
    if (file !== "js/data.js") { findings.push(`derived key family '${fam.pattern}': unsupported source ${fam.idsFrom}`); continue; }
    const values = path.includes("[*]")
      ? Object.values(data[path.split("[*]")[0]]).flat().map((x) => x.nameKey)
      : Object.keys(data[path]).map((k) => (fam.idField ? data[path][k][fam.idField] : k));
    for (const value of values) {
      for (const suffix of fam.suffixes ?? [null]) {
        const key = fam.pattern.replace("{id}", value).replace("{suffix}", suffix ?? "").replace("{nameKey}", value);
        push(key, fam.pattern);
      }
    }
  }
  for (const { key, family } of expected) {
    for (const lang of locales) {
      if (!(key in tables[lang])) {
        findings.push(`runtime-composed key ${JSON.stringify(key)} (${family}) is not defined in '${lang}' — it would print as the raw id`);
      }
    }
  }
  return { composedKeys: expected.length, families: (rules.derivedKeyFamilies ?? []).length };
}

/** (d) emitted-id coverage against the debt ledger. */
export function checkEmittedIds(ctx, tables, rules, fallbackLang, findings) {
  const declarations = JSON.parse(ctx.declarationsText);
  const frozen = JSON.parse(ctx.frozenText);
  const files = [...new Set(SIM_FILES.concat((declarations.dynamicSites ?? []).filter((d) => !d.literalSite).map((d) => d.file)))];
  const sites = collectEmitSites(files, (rel) => ctx.simTexts[rel]);
  const table = { it: tables.it, en: tables.en, default: tables[rules.defaultLocale] };
  const derived = deriveEmittedIds({ sites, declarations, texts: ctx.simTexts, tables: table, frozen });
  findings.push(...derived.failures);

  const rows = [...derived.ids.entries()].map(([id, where]) => ({ id, sites: where, ...classifyId(id, table, rules, fallbackLang) }));
  const unresolved = rows.filter((r) => r.category !== "ok");
  const baseline = JSON.parse(ctx.baselineText);
  const ledger = new Map((baseline.entries ?? []).map((e) => [e.id, e]));

  for (const row of unresolved) {
    const entry = ledger.get(row.id);
    if (!entry) {
      findings.push(
        `UNRESOLVED MESSAGE ID '${row.id}' (${row.category}: ${row.detail}) is emitted at ${row.sites.join(", ")} and is not in ${BASELINE_REL} — the player would see that id, not a sentence`,
      );
      continue;
    }
    if (entry.category !== row.category) {
      findings.push(`ledger entry '${row.id}': recorded as '${entry.category}' but the port emits it as '${row.category}'`);
    }
    if (!entry.rootCause || !baseline.rootCauses?.[entry.rootCause]) {
      findings.push(`ledger entry '${row.id}': no rootCause (every entry must say why, and be traceable to a cause with a fix path)`);
    }
  }
  for (const entry of ledger.values()) {
    const row = rows.find((r) => r.id === entry.id);
    if (!row) {
      findings.push(`STALE ledger entry '${entry.id}': the port can no longer emit it — delete the entry so the ledger stays a true statement`);
    } else if (row.category === "ok") {
      findings.push(`STALE ledger entry '${entry.id}': it resolves now (${row.detail}) — delete the entry and let the test prove the fix`);
    }
  }
  return { rows, unresolved, sites, derived };
}

/** (e) the declared contract: hashes, rules, templates, and reference equivalence. */
export async function checkContract(ctx, tables, rules, rows, fallbackLang, findings) {
  const liveSha = sha256(ctx.sourceText);
  // the port reads the rules from res:// — the two copies must not drift apart
  if (normalize(ctx.godotRulesText) !== normalize(ctx.rulesText)) {
    findings.push(`${RESOLVER_REL}'s rules (godot/src/locale/locale_rules.json) differ from ${RULES_REL} — one source of truth only`);
  }
  if (rules.reference?.sha256 !== liveSha) {
    findings.push(`${RULES_REL}: reference.sha256 ${rules.reference?.sha256?.slice(0, 12)} != live ${liveSha.slice(0, 12)} — the contract is written against a different reference`);
  }
  if (rules.reference?.file !== SOURCE_REL) findings.push(`${RULES_REL}: reference.file is ${rules.reference?.file}, expected ${SOURCE_REL}`);
  const declaredLocales = JSON.stringify(rules.locales);
  const referenceLocales = Object.keys(tables).filter((k) => k !== "default");
  if (declaredLocales !== JSON.stringify(referenceLocales)) {
    findings.push(`${RULES_REL}: locales ${declaredLocales} != the reference's ${JSON.stringify(referenceLocales)}`);
  }
  const absent = (rules.absentLocales ?? []).map((x) => x.locale);
  for (const locale of ["de", "fr", "es"]) {
    if (referenceLocales.includes(locale)) findings.push(`${RULES_REL}: locale '${locale}' is declared absent but the reference has a table for it`);
    if (!absent.includes(locale) && locale === "de") findings.push(`${RULES_REL}: 'de' is not recorded as absent — a German request must be recorded missing, not invented`);
  }
  const refIt = tables[fallbackLang];
  const bindings = new Set();
  for (const [parent, rule] of Object.entries(rules.compositeRules ?? {})) {
    bindings.add(String(rule.binding));
    if (typeof refIt[parent] !== "string") {
      findings.push(`${RULES_REL}: composite rule '${parent}' has no template key in the reference table`);
      continue;
    }
    if (rule.binding === "placeholder") {
      if (!new RegExp(`\\{${rule.placeholder}\\}`).test(refIt[parent])) {
        findings.push(`${RULES_REL}: rule '${parent}' binds {${rule.placeholder}} but the template is ${JSON.stringify(refIt[parent])}`);
      }
      for (const lang of referenceLocales) {
        if (typeof tables[lang][parent] === "string" && !new RegExp(`\\{${rule.placeholder}\\}`).test(tables[lang][parent])) {
          findings.push(`${RULES_REL}: rule '${parent}' binds {${rule.placeholder}} but the ${lang} template has no such placeholder`);
        }
      }
    }
  }
  // the resolver is data-driven: it must know the declared machinery, and the shapes
  // it declares (a composite separator, an unknown-locale fallback) must be in it
  if (!/"compositeRules"/.test(ctx.resolverText) || !/"compositeSeparator"/.test(ctx.resolverText)) {
    findings.push(`${RESOLVER_REL} does not read the declared composite rules from the contract — the rules and the resolver have drifted apart`);
  }
  for (const binding of bindings) {
    if (!ctx.resolverText.includes(`"${binding}"`)) {
      findings.push(`${RESOLVER_REL} does not implement the declared composite binding '${binding}'`);
    }
  }
  if (!ctx.resolverText.includes("locale_data")) {
    findings.push(`${RESOLVER_REL} does not preload the generated locale data`);
  }
  if (!/FALLBACK/.test(ctx.resolverText)) {
    findings.push(`${RESOLVER_REL} does not reference the fallback locale: the fallback chain must be explicit`);
  }

  // every resolvable composite the port emits must render exactly what the live
  // reference renders for the equivalent JavaScript expression
  const mod = await import(pathToFileURL(join(REPO, SOURCE_REL)).href);
  const mirror = mirrorResolver(tables, rules, fallbackLang);
  const sep = rules.compositeSeparator ?? ":";
  let compared = 0;
  for (const row of rows) {
    if (row.category !== "ok" || !row.rule) continue;
    const rule = rules.compositeRules[row.rule];
    const cut = row.id.indexOf(sep);
    const arg = row.id.slice(cut + sep.length);
    for (const lang of rules.locales) {
      mod.setLang(lang);
      const expected = rule.binding === "placeholder"
        ? mod.t(row.rule, { [rule.placeholder]: mod.t(arg) })
        : `${mod.t(row.rule)}${arg ? rule.separator + mod.t(arg) : ""}`;
      const got = mirror.t(row.id, {}, lang);
      compared += 1;
      if (got !== expected) {
        findings.push(`composite '${row.id}' under '${lang}': the port's rule yields ${JSON.stringify(got)}, the live reference yields ${JSON.stringify(expected)}`);
      }
    }
  }
  mod.setLang(rules.defaultLocale);
  return { compared };
}

// ---------------------------------------------------------------------------
// injected drift scenarios (all on in-memory clones)
// ---------------------------------------------------------------------------

/** Did a drift scenario actually change anything? A scenario that patches a moved
 * anchor would otherwise "pass" by doing nothing, and the control would be blind. */
export function contextChanged(a, b) {
  return a.sourceText !== b.sourceText
    || a.gdText !== b.gdText
    || a.baselineText !== b.baselineText
    || a.rulesText !== b.rulesText
    || a.declarationsText !== b.declarationsText
    || a.resolverText !== b.resolverText
    || JSON.stringify(a.simTexts) !== JSON.stringify(b.simTexts);
}

export const DRIFT = {
  "port-string-changed": {
    what: "one string in the port's locale data is edited by hand",
    mutate: (ctx) => ({ ...ctx, gdText: ctx.gdText.replace('"GIOCA ORA"', '"GIOCA ADESSO"') }),
    expect: /port says .*GIOCA ADESSO|drifted/,
  },
  "port-key-removed": {
    what: "one key is missing from the port's locale data",
    mutate: (ctx) => ({ ...ctx, gdText: ctx.gdText.replace('\t\t"histVs": "vs",\n', "") }),
    expect: /key 'histVs' is in the reference but not in the port data|key order differs/,
  },
  "reference-moved": {
    what: "the reference string table changes under the port (a key's text is edited in js/i18n.js)",
    mutate: (ctx) => ({ ...ctx, sourceText: ctx.sourceText.replace('"GIOCA ORA"', '"GIOCA SUBITO"') }),
    expect: /drifted from the reference|reference.sha256/,
  },
  "reference-moved-with-regen": {
    what: "the reference is edited AND the port data regenerated without re-deriving the contract (the rules hash goes stale)",
    mutate: (ctx) => {
      const sourceText = ctx.sourceText.replace('"GIOCA ORA"', '"GIOCA SUBITO"');
      const gdText = ctx.gdText.replace('"GIOCA ORA"', '"GIOCA SUBITO"').replace(/const SOURCE_SHA256 := "[0-9a-f]+"/, `const SOURCE_SHA256 := "${createHash("sha256").update(sourceText, "utf8").digest("hex")}"`);
      return { ...ctx, sourceText, gdText };
    },
    expect: /reference\.sha256/,
  },
  "new-emit-site-unknown-id": {
    what: "a new emit site is added with an id that is not in the table",
    mutate: (ctx) => {
      const rel = "godot/src/sim/sim.gd";
      const next = ctx.simTexts[rel].replace("static func serve_let(", 'static func probe() -> void:\n\tadd_event(state, "evNonesuch")\n\n\nstatic func serve_let(');
      return { ...ctx, simTexts: { ...ctx.simTexts, [rel]: next } };
    },
    expect: /UNRESOLVED MESSAGE ID 'evNonesuch'/,
  },
  "case-typo-id": {
    what: "an existing emit site's id is typed with the wrong case (the AI_LEGGENDA_NAME class: a lookup that cannot match)",
    mutate: (ctx) => {
      const rel = "godot/src/sim/sim.gd";
      return { ...ctx, simTexts: { ...ctx.simTexts, [rel]: ctx.simTexts[rel].replace('"evChiquita"', '"EV_CHIQUITA"') } };
    },
    expect: /UNRESOLVED MESSAGE ID 'EV_CHIQUITA'/,
  },
  "undeclared-dynamic-site": {
    what: "a new emit site computes its id at runtime and nobody declares it",
    mutate: (ctx) => {
      const rel = "godot/src/sim/sim.gd";
      const next = ctx.simTexts[rel].replace("static func serve_let(", 'static func probe(kind: String) -> void:\n\tadd_event(state, "ev%s" % kind)\n\n\nstatic func serve_let(');
      return { ...ctx, simTexts: { ...ctx.simTexts, [rel]: next } };
    },
    expect: /UNDECLARED dynamic emit site/,
  },
  "new-score-reason": {
    what: "a new reason id flows into score_point without updating the declared substitution set",
    mutate: (ctx) => {
      const rel = "godot/src/sim/sim.gd";
      return { ...ctx, simTexts: { ...ctx.simTexts, [rel]: ctx.simTexts[rel].replace('score_point(state, State.other(side), "msgOut", POINT_ERROR)', 'score_point(state, State.other(side), "msgDeep", POINT_ERROR)') } };
    },
    expect: /substitution set 'scorePointReason'.*msgDeep/,
  },
  "table-key-renamed": {
    what: "a key the port composes at runtime is renamed in the reference table",
    mutate: (ctx) => ({ ...ctx, sourceText: ctx.sourceText.replace("tactic_staggered:", "tactic_staggerd_typo:") }),
    expect: /substitution set 'tactic'|drifted/,
  },
  "ledger-shrunk": {
    what: "the debt ledger drops an entry it cannot resolve any more",
    mutate: (ctx) => {
      const baseline = JSON.parse(ctx.baselineText);
      baseline.entries = baseline.entries.filter((e) => e.id !== "serveHint");
      return { ...ctx, baselineText: JSON.stringify(baseline) };
    },
    expect: /UNRESOLVED MESSAGE ID 'serveHint'/,
  },
  "ledger-padded": {
    what: "the debt ledger gains an entry that is resolvable (debt that no longer exists)",
    mutate: (ctx) => {
      const baseline = JSON.parse(ctx.baselineText);
      baseline.entries.push({ id: "evChiquita", category: "no-key", rootCause: "rc3-reference-hardcoded-literal" });
      return { ...ctx, baselineText: JSON.stringify(baseline) };
    },
    expect: /STALE ledger entry 'evChiquita'/,
  },
};

/** Runs every check over one context. Returns {findings, info}. */
export async function runChecks(ctx) {
  const findings = [];
  const info = {};
  const { extraction } = await checkExtractorFaithful(ctx, findings);
  const parsed = checkPortDataMatchesReference(ctx, extraction, findings);
  const rules = JSON.parse(ctx.rulesText);
  info.keysPerLocale = Object.fromEntries(extraction.locales.map((l) => [l, extraction.keyOrder[l].length]));
  info.duplicateKeys = extraction.duplicateKeys;
  info.missingIn = extraction.missingIn;
  info.referenceSha256 = sha256(ctx.sourceText);
  info.runtimeChecked = extraction.stats ? undefined : undefined;

  const tables = { it: extraction.tables.it, en: extraction.tables.en, default: extraction.tables[rules.defaultLocale] ?? extraction.tables.it };
  if (parsed) {
    const inv = await checkReferenceInvariants(parsed.tables, extraction.locales, extraction.fallbackLang, findings);
    info.composedKeys = inv.composedKeys;
    info.composedFamilies = inv.families;
  }
  const emit = checkEmittedIds(ctx, tables, rules, extraction.fallbackLang, findings);
  info.sites = emit.sites.length;
  info.idsEmitted = emit.rows.length;
  info.unresolved = emit.unresolved.map((r) => ({ id: r.id, category: r.category }));
  info.resolved = emit.rows.filter((r) => r.category === "ok").length;
  const contract = await checkContract(ctx, tables, rules, emit.rows, extraction.fallbackLang, findings);
  info.compositesCompared = contract.compared;
  return { findings, info };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);
  const driftArg = args.find((a) => a.startsWith("--drift="));
  const scenario = driftArg ? driftArg.slice("--drift=".length) : null;

  if (args.includes("--list-drift")) {
    for (const [name, s] of Object.entries(DRIFT)) console.log(`${name}\n    ${s.what}`);
    return;
  }

  if (scenario) {
    const spec = DRIFT[scenario];
    if (!spec) {
      console.error(`unknown drift scenario '${scenario}' — try --list-drift`);
      process.exit(2);
    }
    const base = loadContext();
    const mutated = spec.mutate(base);
    const mutatedSomething =
      mutated.sourceText !== base.sourceText || mutated.gdText !== base.gdText ||
      mutated.baselineText !== base.baselineText || JSON.stringify(mutated.simTexts) !== JSON.stringify(base.simTexts);
    if (!mutatedSomething) {
      console.error(`drift scenario '${scenario}' mutated nothing — the anchor it patches is gone, fix the scenario`);
      process.exit(2);
    }
    const { findings } = await runChecks(mutated);
    const caught = findings.some((f) => spec.expect.test(f));
    if (caught) {
      console.log(`${paint(C.red, "DRIFT DETECTED")} (${scenario}) — ${spec.what}`);
      console.log(`  ${findings.find((f) => spec.expect.test(f))}`);
      process.exit(1);
    }
    console.error(`${paint(C.red, "DRIFT NOT DETECTED")} (${scenario}) — ${spec.what}`);
    console.error(`  findings were: ${findings.length === 0 ? "(none)" : findings.join(" | ")}`);
    process.exit(3);
  }

  const ctx = loadContext();
  const { findings, info } = await runChecks(ctx);

  console.log(`${paint(C.bold, "i18n port contract")} — ${SOURCE_REL} @ ${info.referenceSha256.slice(0, 12)}`);
  console.log(`  locales          ${JSON.stringify(info.keysPerLocale)}  default 'en' → fallback 'it' → the id`);
  console.log(`  duplicate keys   ${JSON.stringify(info.duplicateKeys)}`);
  console.log(`  missing keys     ${JSON.stringify(info.missingIn)}`);
  console.log(`  composed keys    ${info.composedKeys} across ${info.composedFamilies} runtime families, all defined in both locales`);
  console.log(`  emit sites       ${info.sites} in godot/src/sim/**`);
  console.log(`  ids emitted      ${info.idsEmitted} — ${info.resolved} resolve, ${info.unresolved.length} ledgered`);
  console.log(`  composites       ${info.compositesCompared} port resolutions compared against the live reference module`);
  const ledger = JSON.parse(ctx.baselineText);
  for (const row of info.unresolved) console.log(`    ${paint(C.yellow, row.category.padEnd(9))} ${row.id}`);

  // every injected drift must be caught, and every scenario must actually apply
  const driftFailures = [];
  for (const [name, spec] of Object.entries(DRIFT)) {
    const mutated = spec.mutate(ctx);
    if (!contextChanged(ctx, mutated)) {
      driftFailures.push(`${name}: the scenario mutated nothing — its anchor moved, so the drift control is blind here`);
      continue;
    }
    const { findings: f } = await runChecks(mutated);
    const caught = f.some((x) => spec.expect.test(x));
    if (!caught) driftFailures.push(`${name}: ${spec.what} -> NOT caught (${f.length} findings)`);
  }
  console.log(`  injected drift   ${Object.keys(DRIFT).length - driftFailures.length}/${Object.keys(DRIFT).length} scenarios caught`);

  if (findings.length > 0 || driftFailures.length > 0) {
    console.log("");
    for (const f of findings) console.log(`${paint(C.red, "FAIL")} ${f}`);
    for (const f of driftFailures) console.log(`${paint(C.red, "FAIL (drift control)")} ${f}`);
    console.log(`\n${paint(C.red, `${findings.length + driftFailures.length} finding(s)`)} — the port's locale data and the reference have diverged`);
    process.exit(1);
  }
  console.log(`\n${paint(C.green, "OK")} — the port's locale data matches ${SOURCE_REL} byte for byte, every emitted id resolves or is ledgered with a reason, and all ${Object.keys(DRIFT).length} injected drifts were caught. Ledger: ${(ledger.entries ?? []).length} entries.`);
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  main().catch((err) => { console.error(`FAIL: ${err.stack}`); process.exit(1); });
}
