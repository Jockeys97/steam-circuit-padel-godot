#!/usr/bin/env node
/**
 * hud-coverage.mjs — read-only coverage of the port's emitted message ids by the
 * one owner of the match's feedback vocabulary.
 *
 * `godot/game/feedback_vocabulary.gd` (architecture-deepening gate 1) carries the
 * event log's `EVENT_LABELS` map — GENERATED there by
 * `godot/game/tools/gen_hud_labels.py` — beside the `describe_event()` that
 * resolves a message id through the verified locale layer first and this table
 * second. The legacy HUD used to hold the table; it now paints the log and asks
 * the module for the line, and this probe reads the table from that owner.
 *
 * This tool measures the gap and changes nothing. It exits 0 unless `--fail-on-leak`
 * is passed, in which case it exits 1 when an id the sim can emit would be printed
 * as (or inside) the id itself.
 *
 * Usage:
 *   node tools/i18n-port/hud-coverage.mjs
 *   node tools/i18n-port/hud-coverage.mjs --fail-on-leak
 */

import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { REPO } from "./extract-i18n.mjs";
import { SIM_FILES, loadPortContext, collectEmitSites, deriveEmittedIds, classifyId } from "./emit-analysis.mjs";
import { extractTables } from "./extract-i18n.mjs";

const LABELS_REL = "godot/game/feedback_vocabulary.gd";

/** The constant block of a GDScript `const NAME := { … }` map, as key -> value strings. */
export function constMap(text, name) {
  const at = text.indexOf(`const ${name} := {`);
  if (at < 0) return null;
  const open = text.indexOf("{", at);
  let depth = 0;
  let end = -1;
  for (let i = open; i < text.length; i += 1) {
    if (text[i] === "{") depth += 1;
    else if (text[i] === "}") { depth -= 1; if (depth === 0) { end = i; break; } }
  }
  const body = text.slice(open, end + 1);
  const out = {};
  for (const m of body.matchAll(/\t"([^"]*)":\s*"([^"]*)",\n/g)) out[m[1]] = m[2];
  return out;
}

/** Mirrors the table lookup of `describe_event()` in godot/game/feedback_vocabulary.gd. */
export function hudDescribe(id, eventLabels, reasonMap) {
  if (Object.prototype.hasOwnProperty.call(eventLabels, id)) return eventLabels[id];
  const reason = (r) => (Object.prototype.hasOwnProperty.call(reasonMap, r) ? reasonMap[r] : r);
  if (id.startsWith("pointYou:")) return `Punto tuo — ${reason(id.slice(9))}`;
  if (id.startsWith("pointOpp:")) return `Punto del circuito — ${reason(id.slice(9))}`;
  if (id.startsWith("doubleFault:")) return `DOPPIO FALLO (${reason(id.slice(12))})`;
  if (id.endsWith(" secondServe")) return `${reason(id.slice(0, id.length - 12))} — seconda di servizio`;
  if (id.startsWith("eventLine")) return `Circuito: ${id}`;
  return id;
}

function main() {
  const failOnLeak = process.argv.includes("--fail-on-leak");
  const labelsPath = join(REPO, LABELS_REL);
  if (!existsSync(labelsPath)) {
    console.log(`${LABELS_REL} is not in this working tree — nothing to measure (the vocabulary module has not landed).`);
    return;
  }
  const labelsText = readFileSync(labelsPath, "utf8");
  const eventLabels = constMap(labelsText, "EVENT_LABELS") ?? {};
  const reasonMap = {
    msgOut: "palla fuori",
    msgDoubleBounce: "secondo rimbalzo",
    msgNetFault: "palla in rete",
    msgNetShort: "non ha superato la rete",
    msgSmashReturned: "smash respinto",
    serveOutBox: "servizio fuori dal box",
    serveIntoNet: "servizio in rete",
    evServeValid: "servizio valido",
  };

  const { rules, declarations, texts, frozen } = loadPortContext();
  const files = [...new Set(SIM_FILES.concat((declarations.dynamicSites ?? []).filter((d) => !d.literalSite).map((d) => d.file)))];
  const sites = collectEmitSites(files, (rel) => texts[rel]);
  const sourceText = readFileSync(join(REPO, "js/i18n.js"), "utf8");
  const extraction = extractTables(sourceText);
  const tables = { it: extraction.tables.it, en: extraction.tables.en, default: extraction.tables[rules.defaultLocale] };
  const derived = deriveEmittedIds({ sites, declarations, texts, tables, frozen });
  const ids = [...derived.ids.keys()];

  const leaks = [];
  const covered = [];
  for (const id of ids) {
    const out = hudDescribe(id, eventLabels, reasonMap);
    if (out.includes(id)) leaks.push({ id, out, category: classifyId(id, tables, rules, extraction.fallbackLang).category });
    else covered.push({ id, out });
  }
  const reachable = new Set(ids);
  const unreachableLabels = Object.keys(eventLabels).filter((k) => !reachable.has(k) && k.includes(":"));

  console.log(`# ${LABELS_REL} — ${Object.keys(eventLabels).length} generated event labels, sha256 ${createHash("sha256").update(labelsText, "utf8").digest("hex").slice(0, 12)}`);
  console.log(`# ids the sim can emit: ${ids.length} — ${covered.length} get a readable line, ${leaks.length} print the id (or contain it)`);
  for (const row of leaks) console.log(`  RAW ID   ${row.id.padEnd(34)} -> ${JSON.stringify(row.out)}${row.category !== "ok" ? `  (contract category: ${row.category})` : ""}`);
  if (unreachableLabels.length) {
    console.log(`# composite labels in the HUD table that no emitted id can match: ${unreachableLabels.map((k) => JSON.stringify(k)).join(", ")}`);
  }
  if (failOnLeak && leaks.length) process.exit(1);
}

main();
