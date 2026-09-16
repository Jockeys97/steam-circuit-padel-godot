/**
 * parity-stream.mjs — the shared, format-aware reader/writer for parity-digest
 * streams.
 *
 * It knows ONE thing: the frozen digest stream shape defined by
 * `scripts/parity-digest.mjs` (READ-ONLY, sha256
 * 2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd) and cited in
 * `docs/wayfinder/tickets/simulation-port-boundary.md` §6.
 *
 * It does NOT contain any simulation logic and does NOT know Godot. Both engines
 * are reduced to the same canonical text shape before anything is compared, so a
 * GDScript producer only has to print the documented lines to be comparable.
 *
 * Two accepted input formats:
 *
 *   1. digest text (what `scripts/parity-digest.mjs` prints to stdout):
 *        3 header comment lines starting with '# '
 *        N digest lines, each starting with 'tick=NNNNNN'
 *        an optional '# json=<path>' comment line
 *        a final 'PARITY-DIGEST JS PASS seed=... ... digestSha256=...' summary
 *
 *   2. the JSON artifact written by `--json=<path>`: `{samples: [...]}` plus
 *      seed/ticks/every/digestSha256/finalRngState.
 *
 * Both are normalized to `{samples:[{tick, values:{...key->text...}}]}` and the
 * JSON side is rendered through the SAME formatter as the text side, which makes
 * the two formats comparable and lets this module recompute the digest sha256 of
 * either one as an integrity check (verified: the frozen JSON artifact and the
 * live stdout of the harness both hash to a7136682...).
 */

import { createHash } from "node:crypto";

/**
 * The frozen field order. `kind` decides how a field is compared:
 *   - "identity": the tick itself, never compared as a value
 *   - "discrete": must match exactly, bit-for-bit — §6's real gate
 *   - "float":    engine-dependent (float64 in JS vs Godot's float32 nodes);
 *                 exact by default, numeric within `--tol` when asked
 *
 * `parts` names the components of vector/point fields so a divergence can be
 * reported as `ball.z` instead of the whole tuple.
 */
export const FIELDS = [
  { key: "tick", kind: "identity", note: "sample index; field order is the contract" },
  { key: "rngState", kind: "discrete", note: "int32, bit-comparable across engines (§4)" },
  { key: "rngCalls", kind: "discrete", note: "reconstructed on the JS side, counted in GDScript" },
  { key: "ball", kind: "float", parts: ["x", "y", "z"] },
  { key: "v", kind: "float", parts: ["x", "y", "z"], note: "px/s" },
  { key: "spin", kind: "float" },
  { key: "bounces", kind: "discrete", note: "player/ai" },
  { key: "shotType", kind: "discrete", note: "printed but not asserted by the JS harness; §6 wants it identical" },
  { key: "smashStage", kind: "discrete", note: "printed but not asserted by the JS harness; §6 wants it identical" },
  { key: "player", kind: "float", parts: ["x", "y"] },
  { key: "playerMate", kind: "float", parts: ["x", "y"] },
  { key: "opponent", kind: "float", parts: ["x", "y"] },
  { key: "opponentMate", kind: "float", parts: ["x", "y"] },
  { key: "points", kind: "discrete", note: "printed but not asserted by the JS harness" },
  { key: "games", kind: "discrete" },
  { key: "sets", kind: "discrete" },
  { key: "playerScore", kind: "discrete" },
  { key: "aiScore", kind: "discrete" },
  { key: "pointsWon", kind: "discrete" },
  { key: "rallyHits", kind: "discrete" },
  { key: "serveAttempts", kind: "discrete" },
  { key: "longestRally", kind: "discrete" },
];

export const FIELD_KEYS = FIELDS.map((field) => field.key);
export const COMPARED_KEYS = FIELD_KEYS.filter((key) => key !== "tick");
export const FIELD_BY_KEY = new Map(FIELDS.map((field) => [field.key, field]));

const DISCRETE_KEYS = new Set(FIELDS.filter((f) => f.kind === "discrete").map((f) => f.key));
const INTEGER_KEYS = new Set([
  "rngState",
  "rngCalls",
  "smashStage",
  "rallyHits",
  "serveAttempts",
  "longestRally",
]);

export function isDiscrete(key) {
  return DISCRETE_KEYS.has(key);
}

/** fixed(6), byte-identical to the JS harness's `fixed`. */
export function fixed(value) {
  return Number.isFinite(value) ? value.toFixed(6) : String(value);
}

/** Render one JSON sample (the harness's `sampleState` shape) into field text. */
export function valuesFromJsonSample(sample) {
  const { ball, paddles, score } = sample;
  const vec = (x, y, z) => `(${fixed(x)},${fixed(y)},${fixed(z)})`;
  const pt = (p) => `(${fixed(p.x)},${fixed(p.y)})`;
  return {
    tick: String(sample.tick).padStart(6, "0"),
    rngState: String(sample.rngState),
    rngCalls: String(sample.rngCalls),
    ball: vec(ball.x, ball.y, ball.z),
    v: vec(ball.vx, ball.vy, ball.vz),
    spin: fixed(ball.spin),
    bounces: `${ball.bounces.player}/${ball.bounces.ai}`,
    shotType: String(ball.shotType),
    smashStage: String(ball.smashStage),
    player: pt(paddles.player),
    playerMate: pt(paddles.playerMate),
    opponent: pt(paddles.opponent),
    opponentMate: pt(paddles.opponentMate),
    points: String(score.points),
    games: String(score.games),
    sets: String(score.sets),
    playerScore: String(score.playerScore),
    aiScore: String(score.aiScore),
    pointsWon: String(score.pointsWon),
    rallyHits: String(score.rallyHits),
    serveAttempts: String(score.serveAttempts),
    longestRally: String(score.longestRally),
  };
}

/** Join a values map back into a digest line, in the frozen field order. */
export function lineFromValues(values) {
  return FIELD_KEYS.map((key) => `${key}=${values[key]}`).join(" ");
}

/**
 * sha256 of a digest body, exactly as the harness computes it: the digest lines
 * joined with "\n" plus a trailing newline.
 */
export function digestSha256OfLines(lines) {
  return createHash("sha256").update(`${lines.join("\n")}\n`).digest("hex");
}

/**
 * Parse a digest line into `{values, order, problems}`.
 *
 * Tolerant about values that contain spaces (it slices between `key=` anchors
 * instead of splitting on whitespace), strict about the contract: the key set
 * and the key ORDER must both match `FIELDS`. A producer that prints the fields
 * in a different order would otherwise compare clean while being unreadable, so
 * that is reported as a structural problem, not as a mere divergence.
 */
export function parseDigestLine(line, lineNo) {
  const problems = [];
  const anchors = [];
  const re = /(?:^|\s)([A-Za-z][A-Za-z0-9_]*)=/g;
  let match;
  while ((match = re.exec(line)) !== null) {
    anchors.push({ key: match[1], valueStart: re.lastIndex, anchorStart: match.index });
  }
  if (anchors.length === 0) {
    return { values: null, problems: [`line ${lineNo}: non riconosciuta come riga di digest`] };
  }
  const order = anchors.map((a) => a.key);
  const values = {};
  anchors.forEach((anchor, index) => {
    const end = index + 1 < anchors.length ? anchors[index + 1].anchorStart : line.length;
    const value = line.slice(anchor.valueStart, end).trim();
    if (value === "") problems.push(`line ${lineNo}: campo "${anchor.key}" senza valore`);
    if (anchor.key in values) problems.push(`line ${lineNo}: campo "${anchor.key}" duplicato`);
    values[anchor.key] = value;
  });

  if (order.length !== FIELD_KEYS.length || order.join(",") !== FIELD_KEYS.join(",")) {
    const firstWrong = order.findIndex((key, index) => key !== FIELD_KEYS[index]);
    const position = firstWrong === -1 ? order.length : firstWrong;
    problems.push(
      `line ${lineNo}: ordine dei campi non conforme in posizione ${position}: ` +
        `atteso "${FIELD_KEYS[position] ?? "-"}", ricevuto "${order[position] ?? "-"}" ` +
        `(${order.length} campi, attesi ${FIELD_KEYS.length})`,
    );
  }
  return { values, problems };
}

function readHeaderAndSummary(lines) {
  const header = {};
  const summary = {};
  const problems = [];
  const warnings = [];
  for (const raw of lines) {
    const line = raw.trim();
    if (line === "") continue;
    if (line.startsWith("#")) {
      const body = line.slice(1).trim();
      for (const token of body.split(/\s+/)) {
        const eq = /^([A-Za-z][A-Za-z0-9-]*)=(\S*)$/.exec(token);
        if (eq) header[eq[1]] = eq[2];
      }
      continue;
    }
    if (line.startsWith("PARITY-DIGEST") || line.includes(" digestSha256=")) {
      for (const token of line.split(/\s+/)) {
        const eq = /^([A-Za-z][A-Za-z0-9-]*)=(\S*)$/.exec(token);
        if (eq) summary[eq[1]] = eq[2];
      }
      // A producer that declared FAIL is reporting its OWN self-check, not
      // necessarily a defect in the lines it printed. Refusing to compare would
      // hide the field-level evidence, so the verdict is surfaced as a warning
      // and the comparison still runs; the integrity checks below are what
      // actually guard against a corrupt or truncated stream.
      if (/\bFAIL\b/.test(line)) warnings.push(`il producer ha auto-dichiarato un fallimento: ${line}`);
    }
  }
  return { header, summary, problems, warnings };
}

/**
 * Parse a digest TEXT stream (harness stdout, or any producer printing the same
 * shape). Returns a normalized stream record; `problems` is non-empty when the
 * contract is violated and comparison must not proceed silently.
 */
export function parseDigestText(text, { label = "stream", sourcePath = null } = {}) {
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  const { header, summary, problems, warnings } = readHeaderAndSummary(lines);
  const samples = [];
  const structural = [...problems];
  const seenTicks = new Set();

  lines.forEach((raw, index) => {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) return;
    if (!line.startsWith("tick=")) return; // the summary line lands here
    const lineNo = index + 1;
    const { values, problems: lineProblems } = parseDigestLine(line, lineNo);
    structural.push(...lineProblems);
    if (!values) return;
    const tick = values.tick;
    if (seenTicks.has(tick)) structural.push(`line ${lineNo}: tick duplicato ${tick}`);
    seenTicks.add(tick);
    samples.push({ tick, values, lineNo, raw: line });
  });

  if (samples.length === 0) structural.push("nessuna riga di digest trovata");
  for (let i = 1; i < samples.length; i += 1) {
    if (samples[i].tick <= samples[i - 1].tick) {
      structural.push(
        `line ${samples[i].lineNo}: tick non crescente (${samples[i - 1].tick} -> ${samples[i].tick})`,
      );
    }
  }

  const digestLines = samples.map((sample) => sample.raw);
  const recomputedSha256 = samples.length ? digestSha256OfLines(digestLines) : null;
  const declaredSha256 = summary.digestSha256 ?? header.digestSha256 ?? null;
  if (declaredSha256 && recomputedSha256 && declaredSha256 !== recomputedSha256) {
    structural.push(
      `integrita': il digestSha256 dichiarato (${declaredSha256}) non coincide con quello ` +
        `ricalcolato dalle righe presenti (${recomputedSha256}) - stream alterato o troncato`,
    );
  }
  if (summary.sampledTicks !== undefined && Number(summary.sampledTicks) !== samples.length) {
    structural.push(
      `integrita': la summary dichiara sampledTicks=${summary.sampledTicks} ma le righe di digest sono ${samples.length}`,
    );
  }

  return {
    label,
    sourcePath,
    format: "digest-text",
    header,
    summary,
    samples,
    meta: {
      seed: summary.seed ?? header.seed ?? null,
      ticks: summary.ticks ?? header.ticks ?? null,
      every: summary.every ?? header.every ?? null,
      sampledTicks: summary.sampledTicks ?? null,
      finalRngState: summary.finalRngState ?? null,
      digestSha256: declaredSha256,
    },
    integrity: {
      recomputedSha256,
      declaredSha256,
      ok: declaredSha256 ? declaredSha256 === recomputedSha256 : null,
    },
    warnings,
    problems: structural,
  };
}

/** Parse the harness's `--json=<path>` artifact. */
export function parseDigestJson(text, { label = "json", sourcePath = null } = {}) {
  let payload;
  try {
    payload = JSON.parse(text);
  } catch (error) {
    return {
      label,
      sourcePath,
      format: "json",
      samples: [],
      meta: {},
      integrity: { ok: null },
      warnings: [],
      problems: [`JSON non valido: ${error.message}`],
    };
  }
  const problems = [];
  const rawSamples = Array.isArray(payload.samples) ? payload.samples : [];
  if (rawSamples.length === 0) problems.push("il JSON non contiene un array `samples` popolato");
  const samples = rawSamples.map((sample, index) => {
    const values = valuesFromJsonSample(sample);
    return {
      tick: values.tick,
      values,
      lineNo: index + 1,
      raw: lineFromValues(values),
    };
  });
  const digestLines = samples.map((sample) => sample.raw);
  const recomputedSha256 = samples.length ? digestSha256OfLines(digestLines) : null;
  const declaredSha256 = payload.digestSha256 ?? null;
  if (declaredSha256 && recomputedSha256 && declaredSha256 !== recomputedSha256) {
    problems.push(
      `integrita': digestSha256 dichiarato (${declaredSha256}) != ricalcolato dai samples (${recomputedSha256})`,
    );
  }
  if (payload.digestLineCount !== undefined && payload.digestLineCount !== samples.length) {
    problems.push(
      `integrita': digestLineCount=${payload.digestLineCount} ma i samples sono ${samples.length}`,
    );
  }
  return {
    label,
    sourcePath,
    format: "json",
    header: { tool: payload.tool ?? null, side: payload.side ?? null },
    summary: {},
    samples,
    meta: {
      seed: payload.seed ?? null,
      ticks: payload.ticks ?? null,
      every: payload.every ?? null,
      sampledTicks: payload.sampledTicks ? String(payload.sampledTicks.length) : null,
      finalRngState: payload.finalRngState ?? null,
      digestSha256: declaredSha256,
    },
    integrity: {
      recomputedSha256,
      declaredSha256,
      ok: declaredSha256 ? declaredSha256 === recomputedSha256 : null,
    },
    warnings: [],
    problems,
  };
}

/** Auto-detect the format and parse. */
export function parseStream(text, { label = "stream", sourcePath = null } = {}) {
  const trimmed = text.replace(/^\uFEFF/, "").trimStart();
  if (trimmed.startsWith("{")) return parseDigestJson(text, { label, sourcePath });
  return parseDigestText(text, { label, sourcePath });
}

export function integritySummary(stream) {
  if (stream.problems.length) return "PROBLEMS";
  if (stream.integrity.ok === true) return "OK";
  if (stream.integrity.ok === false) return "MISMATCH";
  return "not-declared";
}

/** A human-readable location of a sample, unambiguous across the two formats. */
export function locationOf(stream, sample) {
  if (!sample) return "-";
  return stream.format === "json" ? `json-sample#${sample.lineNo}` : `line ${sample.lineNo}`;
}

/** The subset of a stream's provenance that is worth persisting in a report. */
export function streamMetadata(stream) {
  return {
    format: stream.format,
    seed: stream.meta.seed ?? null,
    ticks: stream.meta.ticks ?? null,
    every: stream.meta.every ?? null,
    sampledTicks: stream.samples.length,
    finalRngState: stream.meta.finalRngState ?? null,
    digestSha256: stream.meta.digestSha256 ?? null,
    recomputedSha256: stream.integrity.recomputedSha256 ?? null,
    integrity: integritySummary(stream),
    warnings: stream.warnings ?? [],
    problems: stream.problems,
  };
}

export function summarizeStream(stream, name) {
  const { meta, summary, header } = stream;
  const bits = [
    `${name}`,
    `format=${stream.format}`,
    `source=${stream.sourcePath ?? "(stdin)"}`,
    `seed=${meta.seed ?? "-"}`,
    `ticks=${meta.ticks ?? "-"}`,
    `every=${meta.every ?? "-"}`,
    `sampledTicks=${stream.samples.length}`,
    `declaredSampledTicks=${meta.sampledTicks ?? "-"}`,
    `finalRngState=${meta.finalRngState ?? "-"}`,
    `digestSha256=${meta.digestSha256 ?? "-"}`,
    `integrity=${integritySummary(stream)}`,
  ];
  if (header.step) bits.push(`step=${header.step}`);
  if (header.side) bits.push(`side=${header.side}`);
  return bits.join(" ");
}
