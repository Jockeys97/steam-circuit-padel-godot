#!/usr/bin/env python3
"""
run_integration.py — cross-engine A-button differential proof (launch 6/6).

Runs the ACTUAL production sampler + frame glue on BOTH engines against the
SAME production-rate device corpus, then compares field-by-field with NO
blanket tolerance. Verdict logic lives in comparator.py (shared with the
no-engine self-tests) — there is no separate diff proxy.

Corrections applied this launch (per review/FINAL.md):
  * classify() is now field-scoped: only (scenario, field) pairs in
    comparator.LATCH_ALLOWLIST are "intended"; every other divergence on the
    latch scenario is real.
  * Red-control is baseline-relative (corruption must ADD divergences / cause a
    count mismatch / be classified real), and a no-op negative control must NOT
    be detected.
  * Verdict propagates count mismatch AND corpus frame/coverage mismatch, and
    requires the known latch difference to be reproduced exactly (no-repro is a
    failure, not a pass).
  * Import exit code and BOTH run exit codes + stdout harness markers are gated;
    a failed run cannot be masked by stale reused output.

Exit codes: 0 all gates pass, 1 harness/compile/import failure, 2 unexpected
divergence or count/coverage mismatch or latch not reproduced, 3 red/negative/
truncation control failure, 4 determinism failure, 6 timeout.
"""

import json
import os
import shutil
import subprocess
import sys

import comparator  # noqa: E402  (same directory; shared verdict helper)

REPO = "/Users/alessiofantini/Documents/steam-circuit-padel-godot"
MISSION = os.path.join(REPO, "docs/mission/a-button-parity-20260917")
INTEG = os.path.join(MISSION, "integration")
CORPUS = os.path.join(INTEG, "corpus", "production_rate.json")
JS_GLUE = os.path.join(INTEG, "js_frame_glue.mjs")
GD_GLUE = os.path.join(INTEG, "port_frame_glue.gd")

NODE = shutil.which("node") or "/Users/alessiofantini/.hermes/node/bin/node"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
PROJ = "/tmp/padel-a-button-20260917-port/godot"
SCRATCH = "/tmp/padel-a-button-20260917-port"


def log(msg):
    print(msg, flush=True)


def run(cmd, timeout, env=None):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, env=env, text=True)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT after %ds" % timeout


def corpus_expectations():
    with open(CORPUS) as f:
        corpus = json.load(f)
    expected_scenarios = []
    expected_frames = 0
    for sc in corpus["scenarios"]:
        n = sum(f.get("n", 1) for f in sc["frames"])
        expected_scenarios.extend([sc["id"]] * n)
        expected_frames += n
    return expected_frames, expected_scenarios


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    expected_frames, expected_scenarios = corpus_expectations()

    # 1. Copy Godot harness + corpus into the isolated project (write allowlist).
    dst_dir = os.path.join(PROJ, "integration")
    dst_corpus = os.path.join(dst_dir, "corpus", "production_rate.json")
    dst_glue = os.path.join(dst_dir, "port_frame_glue.gd")
    os.makedirs(os.path.dirname(dst_corpus), exist_ok=True)
    shutil.copyfile(CORPUS, dst_corpus)
    shutil.copyfile(GD_GLUE, dst_glue)
    log("copied harness -> %s" % dst_dir)

    # 2. Import warm-up. Import failures are fatal (defect 6: --import errors
    #    must not be ignored).
    rc_import, out_import = run([GODOT, "--headless", "--path", PROJ, "--import"], 180)
    log("import warm-up exit=%d" % rc_import)
    if rc_import != 0:
        log("FAIL: import warm-up failed (exit=%d)." % rc_import)
        if out_import:
            log("import tail:\n" + "\n".join(out_import.splitlines()[-30:]))
        return 1

    env = dict(os.environ)
    env.pop("DISPLAY", None)
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"

    # 3. JS harness (twice for determinism). stdout is the evidence; we never
    #    read a reused file, so a failed run cannot be masked by stale output.
    js1_path = os.path.join(SCRATCH, "js.trace.txt")
    js2_path = os.path.join(SCRATCH, "js.trace2.txt")
    rc, out1 = run([NODE, JS_GLUE], 120)
    rc2, out2 = run([NODE, JS_GLUE], 120)
    if rc == -1 or rc2 == -1:
        log("FAIL: JS harness timeout.")
        return 6
    open(js1_path, "w").write(out1)
    open(js2_path, "w").write(out2)
    js_ok, js_problems = comparator.runs_ok([(rc, out1), (rc2, out2)], "js")
    log("JS harness exit=%d/%d ok=%s" % (rc, rc2, js_ok))
    if not js_ok:
        log("  JS PROBLEMS: %s" % "; ".join(js_problems))

    # 4. Godot harness (twice for determinism).
    gd1_path = os.path.join(SCRATCH, "gd.trace.txt")
    gd2_path = os.path.join(SCRATCH, "gd.trace2.txt")
    gd_cmd = [GODOT, "--headless", "--path", PROJ, "--quit-after", "4000",
              "--script", "res://integration/port_frame_glue.gd"]
    rc_gd, gd_out = run(gd_cmd, 180, env)
    open(gd1_path, "w").write(gd_out)
    rc_gd2, gd_out2 = run(gd_cmd, 180, env)
    open(gd2_path, "w").write(gd_out2)
    if rc_gd == -1 or rc_gd2 == -1:
        log("FAIL: Godot harness timeout.")
        return 6
    gd_ok, gd_problems = comparator.runs_ok([(rc_gd, gd_out), (rc_gd2, gd_out2)], "gd")
    log("Godot harness exit=%d/%d ok=%s" % (rc_gd, rc_gd2, gd_ok))
    if not gd_ok:
        log("  GD PROBLEMS: %s" % "; ".join(gd_problems))

    if not js_ok or not gd_ok:
        log("FAIL: harness problem (see above).")
        log("godot tail:\n" + "\n".join(gd_out.splitlines()[-30:]))
        return 1

    # 5. Determinism (evidence stream byte-identical across reruns).
    det_ok = (comparator.evidence(out1) == comparator.evidence(out2)
              and comparator.evidence(gd_out) == comparator.evidence(gd_out2))
    log("determinism: js_evidence_identical=%s gd_evidence_identical=%s"
        % (comparator.evidence(out1) == comparator.evidence(out2),
           comparator.evidence(gd_out) == comparator.evidence(gd_out2)))
    if not det_ok:
        log("FAIL: non-deterministic evidence stream.")
        return 4

    # 6. Cross-engine comparison (with corpus coverage expectations).
    js_recs = comparator.parse_trace(out1)
    gd_recs = comparator.parse_trace(gd_out)
    rep = comparator.compare(js_recs, gd_recs,
                             expected_frames=expected_frames,
                             expected_scenarios=expected_scenarios)
    intended, real = comparator.classify(rep["divergences"])
    log("comparison: %d field-pairs, %d divergences (%d intended-latch, %d unexpected)"
        % (rep["comparisons"], len(rep["divergences"]), len(intended), len(real)))
    log("corpus coverage: frames=%d/%d (expected=%d) scenario_seq_ok=%s"
        % (rep["js"], rep["gd"], expected_frames, rep.get("scenario_ok")))

    # 7. Red control on the ACTUAL comparator: corrupt a NON-latch field in a
    #    COPY of the Godot trace. Baseline-relative: must ADD divergences or be
    #    classified real.
    corrupt = gd_out
    marker = corrupt.find('"queuedShotVariant":"drive"')   # a-tap (non-latch)
    if marker < 0:
        marker = corrupt.find('"queuedShotVariant"')
    if marker < 0:
        log("FAIL: no marker to corrupt for red control")
        return 3
    corrupt = corrupt[:marker + 1] + "X" + corrupt[marker + 2:]
    corrupt_path = os.path.join(SCRATCH, "gd.corrupt.txt")
    open(corrupt_path, "w").write(corrupt)
    rep_corrupt = comparator.compare(js_recs, comparator.parse_trace(corrupt),
                                     expected_frames, expected_scenarios)
    red_ok = comparator.red_detected(rep, rep_corrupt)
    log("red-control: baseline=%d divergences, corrupted=%d (count_mismatch=%s): %s"
        % (len(rep["divergences"]), len(rep_corrupt["divergences"]),
           rep_corrupt.get("count_mismatch"), red_ok))

    # 7b. Negative control: a mutation that changes nothing compared (rename the
    #     non-compared 'delta' key) must NOT be detected as corruption.
    noop = gd_out.replace('"delta"', '"Xdelta"', 1)
    rep_noop = comparator.compare(js_recs, comparator.parse_trace(noop),
                                  expected_frames, expected_scenarios)
    noop_ok = not comparator.red_detected(rep, rep_noop)
    log("negative-control: no-op corruption detected=%s (must be False): %s"
        % (not noop_ok, noop_ok))
    if not noop_ok:
        log("FAIL: negative control false-positived (no-op accepted as corruption).")
        return 3

    # 7c. Truncated-output control: drop the last 2 "# trace" lines from a COPY,
    #     so the comparator MUST report a count mismatch.
    lines = gd_out.splitlines()
    trace_idx = [i for i, l in enumerate(lines) if l.startswith("# trace ")]
    truncated = "\n".join(lines[:trace_idx[-3]]) if len(trace_idx) >= 3 else ""
    rep_trunc = comparator.compare(js_recs, comparator.parse_trace(truncated),
                                   expected_frames, expected_scenarios)
    trunc_ok = rep_trunc.get("count_mismatch", False) or len(rep_trunc["divergences"]) > 0
    log("truncated-output control: count_mismatch=%s divergences=%d (must fail): %s"
        % (rep_trunc.get("count_mismatch"), len(rep_trunc["divergences"]), trunc_ok))

    # 8. First divergence per scenario.
    first_by_scen = {}
    for d in rep["divergences"]:
        scen = d["key"][0]
        first_by_scen.setdefault(scen, d)

    exit_code, message = comparator.verdict(rep, red_ok, trunc_ok)
    summary = {
        "schemaVersion": 3,
        "fixedStep": "1/120",
        "import_exit": rc_import,
        "js_harness_exit": [rc, rc2],
        "godot_harness_exit": [rc_gd, rc_gd2],
        "deterministic": det_ok,
        "total_comparisons": rep["comparisons"],
        "expected_frames": expected_frames,
        "js_frames": rep["js"],
        "gd_frames": rep["gd"],
        "count_mismatch": rep.get("count_mismatch"),
        "frame_count_ok": rep.get("frame_count_ok"),
        "scenario_ok": rep.get("scenario_ok"),
        "total_divergences": len(rep["divergences"]),
        "intended_latch_divergences": len(intended),
        "unexpected_divergences": len(real),
        "latch_reproduced": comparator.latch_reproduced(intended),
        "red_control_detected": red_ok,
        "negative_control_not_detected": noop_ok,
        "truncated_output_detected": trunc_ok,
        "verdict_exit": exit_code,
        "verdict_message": message,
        "first_divergence": rep["first"],
        "first_divergence_by_scenario": first_by_scen,
        "latch_evidence": [d for d in intended],
        "artifacts": {
            "js_trace": js1_path, "godot_trace": gd1_path,
            "corrupt_copy": corrupt_path,
            "corpus": CORPUS,
        },
    }
    with open(os.path.join(INTEG, "summary.json"), "w") as f:
        json.dump(summary, f, indent=2, default=str)
    log("wrote summary.json")

    log("RESULT: exit=%d — %s" % (exit_code, message))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
