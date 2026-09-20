/**
 * verify.mjs — reproducibility + red-control check for the reference oracle.
 *
 * 1. Reproducibility: run the oracle twice with a pinned seed; the two traces
 *    must be byte-identical (tol=0).
 * 2. Red control: corrupt a COPY of one trace (flip one byte) and prove a
 *    byte comparison against the pristine trace exits NONZERO. Production
 *    source is never mutated — only a scratch copy is.
 *
 * Exit codes: 0 both checks pass, 1 reproducibility failure, 2 red-control
 * failure (the comparison did NOT detect the corruption), 3 usage/IO.
 *
 * Usage:
 *   node reference/verify.mjs
 */

import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
import os from "node:os";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ORACLE = path.join(__dirname, "oracle", "a-button-oracle.mjs");
const NODE = process.execPath;
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "padel-ref-verify-"));

function run(out) {
  execFileSync(NODE, [ORACLE, `--out=${out}`], { stdio: "pipe" });
  return fs.readFileSync(out, "utf8");
}

const a = path.join(dir, "a.txt");
const b = path.join(dir, "b.txt");
const c = path.join(dir, "corrupt.txt");

const t1 = run(a);
const t2 = run(b);

if (t1 !== t2) {
  console.log("FAIL reproducibility: two pinned-seed runs differ");
  process.exit(1);
}
console.log(`PASS reproducibility: two runs byte-identical (${t1.length} bytes)`);

// Corrupt a COPY (flip one digit inside a "# trace " line, not the header).
const copy = Buffer.from(t1, "utf8");
const idx = t1.indexOf('"drive"');
if (idx < 0) throw new Error("no marker to corrupt");
copy[idx + 2] = "x".charCodeAt(0); // "drive" -> "drixe"
fs.writeFileSync(c, copy);
const corrupt = fs.readFileSync(c, "utf8");

if (corrupt === t1) {
  console.log("FAIL red-control: corruption did not change the trace");
  process.exit(3);
}
if (t1 === corrupt) {
  console.log("FAIL red-control: comparison reports identical despite corruption");
  process.exit(2);
}
// A byte-level diff of the two must be nonzero. `diff -q` exits 1 when the files
// differ — that nonzero exit IS the red-control proof.
let diffExit = 0;
let diffOut = "";
try {
  diffOut = execFileSync("diff", ["-q", a, c], { encoding: "utf8" }).trim();
} catch (e) {
  diffExit = e.status;
  diffOut = String(e.stdout || "").trim();
}
if (diffExit === 0) {
  console.log("FAIL red-control: diff -q exited 0 (did not detect corruption)");
  process.exit(2);
}
if (diffExit === 2) {
  console.log("FAIL red-control: diff -q errored");
  process.exit(2);
}
console.log(`PASS red-control: corrupted copy detected, diff exited ${diffExit} (${diffOut})`);
console.log("VERIFY OK: oracle is deterministic and comparison is red-capable");
