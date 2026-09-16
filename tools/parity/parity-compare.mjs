#!/usr/bin/env node
/**
 * parity-compare.mjs — the consumer half of the cross-engine parity comparison.
 *
 * Input: two parity-digest streams. One is the JavaScript one produced by
 * `scripts/parity-digest.mjs` (READ-ONLY seam, sha256 2b24dd26...), the other is
 * meant to become the GDScript one from the Godot port. Either side may be given
 * as the harness's stdout text, as its `--json=<path>` artifact, or as `-` for
 * stdin. Formats may differ between the two sides.
 *
 * Output: EQUAL, or the exact first divergence — tick, field, component, both
 * values, both line numbers — plus how much of the rest of the stream is a
 * consequence of that break rather than an independent finding.
 *
 * It ports nothing and knows no Godot. The gate it implements is the one
 * `docs/wayfinder/tickets/simulation-port-boundary.md` §6 defines:
 *   - discrete fields (`rngState`, `rngCalls`, the counters and score fields,
 *     `shotType`/`smashStage`) must match bit-for-bit;
 *   - positions/velocities/spin are float64 in JS and flow through float32 in
 *     Godot, so they are exact by DEFAULT here (the strict, honest reading) and
 *     only compared numerically when `--tol=<abs>` is passed. The `1e-3` in §6
 *     is a PROPOSAL, never measured, so it is never the default.
 *
 * Usage:
 *   node tools/parity/parity-compare.mjs <left> <right> [options]
 *     <left> <right>   path to a digest stream, or `-` for stdin
 *     --tol=<abs>      absolute tolerance for float fields (default 0 = strict)
 *     --json=<path>    write the machine-readable report
 *     --quiet          suppress the human report, keep the summary line
 *
 * Exit codes: 0 IDENTICAL, 1 DIVERGED, 2 NOT-COMPARABLE, 3 usage/IO error.
 */

import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  FIELDS,
  COMPARED_KEYS,
  isDiscrete,
  parseStream,
  locationOf,
  streamMetadata,
  summarizeStream,
} from "./parity-stream.mjs";

const EXIT = { IDENTICAL: 0, DIVERGED: 1, NOT_COMPARABLE: 2, USAGE: 3 };

let quiet = false;
const emit = (line) => {
  if (!quiet) console.log(line);
};
const always = (line) => console.log(line);

function usageError(message) {
  console.error(`PARITY-COMPARE USAGE: ${message}`);
  console.error("  node tools/parity/parity-compare.mjs <left> <right> [--tol=<abs>] [--json=<path>] [--quiet]");
  process.exit(EXIT.USAGE);
}

function parseArgs(argv) {
  const out = { tol: 0, json: null, quiet: false, positionals: [] };
  for (const raw of argv) {
    if (raw === "--help" || raw === "-h") usageError("help richiesto");
    const match = /^--([a-z-]+)(?:=(.*))?$/.exec(raw);
    if (!match) {
      out.positionals.push(raw);
      continue;
    }
    const [, name, value] = match;
    if (name === "tol") {
      if (value === undefined || !/^\d*\.?\d+(?:e-?\d+)?$/i.test(value)) {
        usageError(`--tol richiede un numero non negativo, ricevuto "${value}"`);
      }
      out.tol = Number.parseFloat(value);
      if (!(out.tol >= 0)) usageError(`--tol fuori intervallo: ${value}`);
    } else if (name === "json") {
      out.json = value ?? null;
      if (!out.json) usageError("--json richiede un percorso");
    } else if (name === "quiet") {
      out.quiet = true;
    } else {
      usageError(`opzione sconosciuta: --${name}`);
    }
  }
  if (out.positionals.length !== 2) {
    usageError(`servono esattamente due stream, ricevuti ${out.positionals.length}`);
  }
  return out;
}

function readStream(spec, label) {
  if (spec === "-") {
    const text = readFileSync(0, "utf8");
    return parseStream(text, { label, sourcePath: "(stdin)" });
  }
  let text;
  try {
    text = readFileSync(spec, "utf8");
  } catch (error) {
    console.error(`PARITY-COMPARE IO: impossibile leggere "${spec}": ${error.message}`);
    process.exit(EXIT.USAGE);
  }
  return parseStream(text, { label, sourcePath: path.resolve(spec) });
}

// ---------------------------------------------------------------------------
// Field comparison
// ---------------------------------------------------------------------------

function numbersIn(text) {
  const trimmed = text.trim();
  const tuple = /^\(([^)]*)\)$/.exec(trimmed);
  const pieces = tuple ? tuple[1].split(",") : [trimmed];
  const values = pieces.map((piece) => Number(piece.trim()));
  if (values.some((value) => !Number.isFinite(value))) return null;
  return values;
}

/**
 * Compare one field of one sampled tick.
 * Returns null when equal, or a divergence descriptor naming the first
 * differing component (`ball.x`, `v.y`, `spin`).
 */
function compareField(field, leftText, rightText, tol) {
  if (field.kind === "discrete") {
    if (leftText === rightText) return null;
    return {
      field: field.key,
      component: null,
      kind: "discrete",
      left: leftText,
      right: rightText,
      delta: null,
    };
  }

  if (leftText === rightText) return null;

  const leftNumbers = numbersIn(leftText);
  const rightNumbers = numbersIn(rightText);
  if (!leftNumbers || !rightNumbers || leftNumbers.length !== rightNumbers.length) {
    return {
      field: field.key,
      component: null,
      kind: field.kind,
      left: leftText,
      right: rightText,
      delta: null,
      note: "valore non interpretabile come numero o come vettore",
    };
  }

  const parts = field.parts ?? ["value"];
  const diffs = [];
  for (let i = 0; i < leftNumbers.length; i += 1) {
    const delta = Math.abs(leftNumbers[i] - rightNumbers[i]);
    if (delta > 0) diffs.push({ index: i, delta });
  }
  const componentOf = (index) => (field.parts ? `${field.key}.${parts[index] ?? index}` : field.key);

  if (diffs.length === 0) {
    // Same numbers, different text: a formatting divergence, not a value one.
    return {
      field: field.key,
      component: null,
      kind: field.kind,
      left: leftText,
      right: rightText,
      delta: 0,
      note: "stesso valore numerico, testo diverso (formattazione non conforme al contract)",
    };
  }

  if (tol === 0) {
    // Strict: the printed text is the contract. Report the first component that
    // actually moved, so the finding names `ball.z` rather than the whole tuple.
    const first = diffs[0];
    return {
      field: field.key,
      component: componentOf(first.index),
      kind: field.kind,
      left: leftNumbers[first.index],
      right: rightNumbers[first.index],
      delta: first.delta,
      note: "strict: confronto esatto, tolleranza 0",
    };
  }

  const beyondTolerance = diffs.filter((diff) => diff.delta > tol);
  if (beyondTolerance.length === 0) return null;
  const worst = beyondTolerance.reduce((a, b) => (b.delta > a.delta ? b : a));
  return {
    field: field.key,
    component: componentOf(worst.index),
    kind: field.kind,
    left: leftNumbers[worst.index],
    right: rightNumbers[worst.index],
    delta: worst.delta,
  };
}

// ---------------------------------------------------------------------------
// The comparison
// ---------------------------------------------------------------------------

function tickSetReport(left, right) {
  const leftTicks = new Set(left.samples.map((sample) => sample.tick));
  const rightTicks = new Set(right.samples.map((sample) => sample.tick));
  const missingFromRight = [...leftTicks].filter((tick) => !rightTicks.has(tick));
  const extraInRight = [...rightTicks].filter((tick) => !leftTicks.has(tick));
  return { missingFromRight, extraInRight };
}

function compare(left, right, tol) {
  const report = {
    result: null,
    reason: null,
    detail: null,
    tol,
    toleranceMode: tol === 0 ? "strict" : `abs<=${tol}`,
    comparedSamples: 0,
    comparedFields: COMPARED_KEYS.length,
    firstDivergence: null,
    dependentDivergentTicks: 0,
    cascadeTicks: 0,
    discreteBreak: false,
    problems: { left: left.problems, right: right.problems },
  };

  // (1) Stream integrity / contract conformance comes first: comparing a corrupt
  // or off-contract stream would produce confident nonsense.
  const structural = [
    ...left.problems.map((problem) => `[left] ${problem}`),
    ...right.problems.map((problem) => `[right] ${problem}`),
  ];
  if (structural.length) {
    report.result = "NOT-COMPARABLE";
    report.reason = "stream non conforme al contratto";
    report.detail = structural[0];
    report.structuralProblems = structural;
    return report;
  }

  // (2) Run parameters must agree, or the comparison is between two different
  // runs and every field would "differ" for the wrong reason.
  const mismatches = [];
  for (const key of ["seed", "ticks", "every"]) {
    const l = left.meta[key];
    const r = right.meta[key];
    if (l !== null && r !== null && String(l) !== String(r)) {
      mismatches.push(`${key}: left=${l} right=${r}`);
    }
  }
  if (mismatches.length) {
    report.result = "NOT-COMPARABLE";
    report.reason = "parametri di run diversi";
    report.detail = mismatches.join("; ");
    report.parameterMismatches = mismatches;
    return report;
  }

  // (3) Sample grid.
  const grid = tickSetReport(left, right);
  if (grid.missingFromRight.length || grid.extraInRight.length) {
    const firstMissing = grid.missingFromRight[0] ?? null;
    const firstExtra = grid.extraInRight[0] ?? null;
    const atTick = firstMissing ?? firstExtra;
    report.result = "DIVERGED";
    report.firstDivergence = {
      index: left.samples.findIndex((sample) => sample.tick === atTick),
      tick: atTick,
      field: "samples",
      component: null,
      kind: "grid",
      left: firstMissing ? `tick presente` : "tick assente",
      right: firstExtra ? `tick in piu'` : "tick assente",
      leftLineNo: left.samples.find((sample) => sample.tick === atTick)?.lineNo ?? null,
      rightLineNo: right.samples.find((sample) => sample.tick === atTick)?.lineNo ?? null,
      leftAt: locationOf(left, left.samples.find((sample) => sample.tick === atTick)),
      rightAt: locationOf(right, right.samples.find((sample) => sample.tick === atTick)),
      detail:
        `griglia di campionamento diversa: mancanti a destra=[${grid.missingFromRight.join(",") || "-"}] ` +
        `in piu' a destra=[${grid.extraInRight.join(",") || "-"}]`,
    };
    return report;
  }

  // (4) Field-by-field walk in the frozen order, sample by sample.
  const pairs = left.samples.map((sample, index) => ({ sample, rightSample: right.samples[index] }));
  let firstIndex = null;
  for (const { sample, rightSample } of pairs) {
    for (const field of FIELDS) {
      if (field.kind === "identity") continue;
      const divergence = compareField(
        field,
        sample.values[field.key],
        rightSample.values[field.key],
        tol,
      );
      if (divergence) {
        if (!report.firstDivergence) {
          firstIndex = pairs.findIndex((pair) => pair.sample === sample);
          report.firstDivergence = {
            index: firstIndex,
            tick: sample.tick,
            leftLineNo: sample.lineNo,
            rightLineNo: rightSample.lineNo,
            leftAt: locationOf(left, sample),
            rightAt: locationOf(right, rightSample),
            ...divergence,
          };
        }
      }
    }
    report.comparedSamples += 1;
  }

  // (5) Everything after the first divergence is a consequence, per §6: one
  // branch flip (`nextRandom(state) < chance`) diverges the engines for good, so
  // those ticks are counted, never presented as separate findings.
  if (report.firstDivergence) {
    for (let i = report.firstDivergence.index + 1; i < pairs.length; i += 1) {
      const { sample, rightSample } = pairs[i];
      const differs = FIELDS.some(
        (field) =>
          field.kind !== "identity" &&
          compareField(field, sample.values[field.key], rightSample.values[field.key], tol) !== null,
      );
      if (differs) report.dependentDivergentTicks += 1;
    }
    report.cascadeTicks = pairs.length - firstIndex - 1;
    report.discreteBreak = report.firstDivergence.kind === "discrete";
    report.result = "DIVERGED";
    return report;
  }

  report.result = "IDENTICAL";
  return report;
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

function toleranceLabel(tol) {
  return tol === 0
    ? "strict (exact text per field)"
    : `abs<=${tol} sui campi float (PROPOSTA §6, MAI MISURATA - non e' un gate validato)`;
}

function printReport(report, left, right, leftSpec, rightSpec) {
  emit(`# parity-compare.mjs left=${leftSpec} right=${rightSpec}`);
  emit(`# left  ${summarizeStream(left, "left")}`);
  emit(`# right ${summarizeStream(right, "right")}`);
  for (const warning of left.warnings ?? []) emit(`# WARNING [left] ${warning}`);
  for (const warning of right.warnings ?? []) emit(`# WARNING [right] ${warning}`);
  emit(`# tolerance=${toleranceLabel(report.tol)}`);
  emit(
    `# gate=discrete-exact(${COMPARED_KEYS.filter(isDiscrete).length} campi) ` +
      `float=${report.tol === 0 ? "exact" : `tollerati abs<=${report.tol}`}`,
  );

  if (report.result === "NOT-COMPARABLE") {
    emit(`PARITY-COMPARE RESULT=NOT-COMPARABLE reason="${report.reason}"`);
    emit(`DETAIL ${report.detail}`);
    if (report.structuralProblems) {
      for (const problem of report.structuralProblems.slice(0, 10)) emit(`PROBLEM ${problem}`);
      if (report.structuralProblems.length > 10) {
        emit(`PROBLEM ... e altri ${report.structuralProblems.length - 10} problemi strutturali`);
      }
    }
    if (report.parameterMismatches) {
      for (const mismatch of report.parameterMismatches) emit(`PARAM ${mismatch}`);
    }
    emit("NOTE nessun confronto di campo eseguito: i due stream non sono confrontabili cosi' come sono.");
    return;
  }

  if (report.result === "IDENTICAL") {
    const fastPath =
      left.meta.digestSha256 && left.meta.digestSha256 === right.meta.digestSha256
        ? " digestSha256-identical"
        : "";
    emit(
      `PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=${report.comparedSamples} ` +
        `comparedFields=${report.comparedFields}${fastPath}`,
    );
    const producerWarnings = [...(left.warnings ?? []), ...(right.warnings ?? [])];
    if (producerWarnings.length) {
      emit(
        "PRODUCER-SELF-CHECK un producer ha auto-dichiarato FAIL mentre TUTTE le righe di digest " +
          "coincidono campo per campo: la divergenza e' nel controllo interno di quel producer " +
          "(formattazione dei suoi valori di riferimento), non nei dati del digest.",
      );
    }
    emit(
      "NOTE i campi che il producer JS stampa ma non asserisce (shotType, smashStage, playerScore, aiScore, " +
        "points, games, sets, pointsWon) sono QUI confrontati: sono la parte discreta del gate §6.",
    );
    return;
  }

  const first = report.firstDivergence;
  emit(
    `PARITY-COMPARE RESULT=DIVERGED firstTick=${first.tick} field=${first.component ?? first.field} ` +
      `kind=${first.kind} leftAt="${first.leftAt ?? first.leftLineNo ?? "-"}" ` +
      `rightAt="${first.rightAt ?? first.rightLineNo ?? "-"}"`,
  );
  emit(
    `FIRST-DIVERGENCE tick=${first.tick} field=${first.field}` +
      (first.component ? ` component=${first.component}` : "") +
      ` kind=${first.kind}`,
  );
  emit(`  left : ${first.left}`);
  emit(`  right: ${first.right}`);
  if (first.delta !== null && first.delta !== undefined) emit(`  delta: ${first.delta}`);
  if (first.note) emit(`  note : ${first.note}`);
  if (first.detail) emit(`  detail: ${first.detail}`);

  if (report.discreteBreak) {
    emit(
      `BRANCH-MISMATCH divergenza discreta a tick ${first.tick} (${first.field}): per ` +
        "simulation-port-boundary.md §6 una singola differenza puo' far scattare un gate di probabilita' " +
        "(`nextRandom(state) < chance`) e da li' i due engine divergono per sempre; le posizioni " +
        "successive sono conseguenze, non findings indipendenti.",
    );
  } else if (first.kind === "grid") {
    emit(
      "GRID-MISMATCH i due stream campionano tick diversi: confrontare i campioni comuni " +
        "nasconderebbe la differenza di griglia, quindi e' riportata come prima divergenza.",
    );
  } else {
    emit(
      `FLOAT-DRIFT divergenza float a tick ${first.tick} (${first.component ?? first.field}), ` +
        `delta=${first.delta}; la tolleranza 1e-3 di §6 e' una proposta mai misurata.`,
    );
  }
  emit(
    `CASCADE divergentTicksAfter=${report.dependentDivergentTicks} of ${report.cascadeTicks} remaining ` +
      "samples (dipendenti dalla prima divergenza, elencati non come findings separati)",
  );
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  quiet = options.quiet;
  const [leftSpec, rightSpec] = options.positionals;
  const left = readStream(leftSpec, "left");
  const right = readStream(rightSpec, "right");
  const report = compare(left, right, options.tol);

  printReport(report, left, right, leftSpec, rightSpec);

  const payload = {
    tool: "tools/parity/parity-compare.mjs",
    left: { spec: leftSpec, ...streamMetadata(left) },
    right: { spec: rightSpec, ...streamMetadata(right) },
    ...report,
  };
  if (options.json) {
    const target = path.resolve(process.cwd(), options.json);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    emit(`# json=${target}`);
  }

  always(
    `PARITY-COMPARE ${report.result} ` +
      (report.result === "IDENTICAL"
        ? `sampledTicks=${report.comparedSamples} digestSha256=${left.meta.digestSha256 ?? "-"}`
        : `reason="${report.reason ?? `first divergence at tick ${report.firstDivergence?.tick} field ${report.firstDivergence?.component ?? report.firstDivergence?.field}`}"`),
  );
  const exitCode = EXIT[report.result.replace(/-/g, "_")];
  process.exit(exitCode ?? EXIT.USAGE);
}

main().catch((error) => {
  console.error(`PARITY-COMPARE ERROR: ${error?.stack ?? error}`);
  process.exit(EXIT.USAGE);
});
