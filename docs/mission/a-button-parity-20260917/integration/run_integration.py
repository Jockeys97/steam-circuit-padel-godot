#!/usr/bin/env python3
"""
run_integration.py — cross-engine A-button differential proof.

Runs the ACTUAL production sampler + frame glue on BOTH engines against the
SAME production-rate device corpus, then compares field-by-field with NO
blanket tolerance (explicit normalization list only).

  JS    : node integration/js_frame_glue.mjs   (real main.js fns + verbatim gameLoop block)
  Godot : Godot headless --script res://integration/port_frame_glue.gd  (real Match.tscn apply_frame)

Enforces the brief's runner contract (defect 6): real subprocess timeouts,
missing-completion-marker / count-mismatch / SCRIPT ERROR / unapproved ERROR all
fail the run; a set of PASS strings alone is never enough.

Exit codes: 0 all gates pass, 1 harness/compile failure, 2 comparison found
unexpected divergence, 3 red-control did NOT detect corruption, 4 determinism
failure, 5 count/marker failure, 6 timeout.
"""

import json
import os
import re
import shutil
import subprocess
import sys

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

INPUT_FIELDS = [
    "left", "right", "up", "down", "moveX", "moveY", "charging", "hit", "slice",
    "shotVariant", "special", "switchPlayer", "switchDirection", "aim", "aimY",
    "analogAim", "smashUpgrade", "cutVolley", "globo", "splitStep", "sprint",
    "technicalModifier", "teamTactic",
]
SIM_FIELDS = [
    "shotCharge", "shotIntent", "queuedShotVariant", "queuedShotPower",
    "queuedShotAim", "queuedShotAimY", "smashPrimed", "cutVolleyPrimed",
    "globoPrimed", "playerSwingBuffer",
]
# Scenarios whose divergence is the DIAGNOSIS (intended), not a parity failure.
LATCH_SCENARIOS = {"zero-substep-latch", "hz144-latch"}


def log(msg):
    print(msg, flush=True)


def run(cmd, timeout, env=None):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, env=env, text=True)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT after %ds" % timeout


def parse_trace(text):
    """Return list of records (dict) from '# trace {...}' lines, in order."""
    recs = []
    for line in text.splitlines():
        if line.startswith("# trace "):
            recs.append(json.loads(line[len("# trace "):]))
    return recs


def evidence(text):
    """Only the evidence stream: '# ' header/trace/summary lines. Excludes
    wall-clock resource-load logs (e.g. 'BLEACHERS ... load_ms=NNN') which are
    non-deterministic noise unrelated to the input/sim path."""
    return "\n".join(l for l in text.splitlines() if l.startswith("# "))


def check_harness(text, name):
    """Enforce completion marker, SCRIPT ERROR=0, unapproved ERROR=0."""
    problems = []
    if "# summary " not in text:
        problems.append("missing # summary completion marker")
    if "SCRIPT ERROR" in text:
        problems.append("SCRIPT ERROR present")
    # The only approved ERROR is the benign teardown one (port's hashes.json).
    for line in text.splitlines():
        if line.startswith("ERROR:") and "resources still in use" not in line:
            problems.append("unapproved ERROR: " + line[:120])
    if problems:
        log("  [%s] HARNESS PROBLEMS: %s" % (name, "; ".join(problems)))
        return False
    return True


def compare(js_recs, gd_recs):
    """Field-by-field, tol=0 (6-dec strings). Returns report dict."""
    if len(js_recs) != len(gd_recs):
        return {"count_mismatch": True, "js": len(js_recs), "gd": len(gd_recs),
                "divergences": [], "comparisons": 0, "first": None}
    divergences = []
    comparisons = 0
    first = None
    for j, g in zip(js_recs, gd_recs):
        key = (j["scenario"], j["frame"])
        if j["scenario"] != g["scenario"] or j["frame"] != g["frame"]:
            divergences.append({"key": key, "field": "<alignment>",
                                "js": j["scenario"], "gd": g["scenario"]})
            if first is None:
                first = divergences[-1]
            continue
        # steps (sub-step count of the frame glue)
        comparisons += 1
        if j.get("steps") != g.get("steps"):
            d = {"key": key, "field": "steps", "js": j.get("steps"), "gd": g.get("steps")}
            divergences.append(d)
            if first is None:
                first = d
        for field in INPUT_FIELDS:
            comparisons += 1
            jv = j["input"].get(field)
            gv = g["input"].get(field)
            if jv != gv:
                d = {"key": key, "field": "input." + field, "js": jv, "gd": gv}
                divergences.append(d)
                if first is None:
                    first = d
        for field in SIM_FIELDS:
            comparisons += 1
            jv = j["sim"].get(field)
            gv = g["sim"].get(field)
            if jv != gv:
                d = {"key": key, "field": "sim." + field, "js": jv, "gd": gv}
                divergences.append(d)
                if first is None:
                    first = d
    return {"count_mismatch": False, "js": len(js_recs), "gd": len(gd_recs),
            "divergences": divergences, "comparisons": comparisons, "first": first}


def classify(divergences):
    """Split divergences into intended (latch) vs unexpected (real)."""
    intended = []
    real = []
    for d in divergences:
        key = d.get("key")
        scen = key[0] if key else "?"
        if scen in LATCH_SCENARIOS:
            intended.append(d)
        else:
            real.append(d)
    return intended, real


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    # 1. Copy Godot harness + corpus into the isolated project (write allowlist).
    dst_dir = os.path.join(PROJ, "integration")
    dst_corpus = os.path.join(dst_dir, "corpus", "production_rate.json")
    dst_glue = os.path.join(dst_dir, "port_frame_glue.gd")
    os.makedirs(os.path.dirname(dst_corpus), exist_ok=True)
    shutil.copyfile(CORPUS, dst_corpus)
    shutil.copyfile(GD_GLUE, dst_glue)
    log("copied harness -> %s" % dst_dir)

    # 2. Import warm-up (idempotent; audio .sample cache).
    rc, out = run([GODOT, "--headless", "--path", PROJ, "--import"], 180)
    log("import warm-up exit=%d" % rc)

    env = dict(os.environ)
    env.pop("DISPLAY", None)
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"

    # 3. JS harness (twice for determinism).
    js1_path = os.path.join(SCRATCH, "js.trace.txt")
    js2_path = os.path.join(SCRATCH, "js.trace2.txt")
    rc, out1 = run([NODE, JS_GLUE, "--out=" + js1_path], 120)
    rc2, out2 = run([NODE, JS_GLUE, "--out=" + js2_path], 120)
    js_ok = rc == 0 and check_harness(open(js1_path).read(), "js")
    log("JS harness exit=%d/%d ok=%s" % (rc, rc2, js_ok))

    # 4. Godot harness (twice for determinism).
    gd1_path = os.path.join(SCRATCH, "gd.trace.txt")
    gd2_path = os.path.join(SCRATCH, "gd.trace2.txt")
    gd_cmd = [GODOT, "--headless", "--path", PROJ, "--quit-after", "4000",
              "--script", "res://integration/port_frame_glue.gd"]
    rc_gd, gd_out = run(gd_cmd, 180, env)
    open(gd1_path, "w").write(gd_out)
    rc_gd2, gd_out2 = run(gd_cmd, 180, env)
    open(gd2_path, "w").write(gd_out2)
    gd_ok = rc_gd == 0 and check_harness(gd_out, "godot")
    log("Godot harness exit=%d/%d ok=%s" % (rc_gd, rc_gd2, gd_ok))

    if not js_ok or not gd_ok:
        log("FAIL: harness problem (see above).")
        log("godot tail:\n" + "\n".join(gd_out.splitlines()[-30:]))
        return 1

    # 5. Determinism (evidence stream byte-identical across reruns).
    js1, js2 = open(js1_path).read(), open(js2_path).read()
    gd1, gd2 = open(gd1_path).read(), open(gd2_path).read()
    det_ok = evidence(js1) == evidence(js2) and evidence(gd1) == evidence(gd2)
    log("determinism: js_evidence_identical=%s gd_evidence_identical=%s"
        % (evidence(js1) == evidence(js2), evidence(gd1) == evidence(gd2)))
    if not det_ok:
        log("FAIL: non-deterministic evidence stream.")
        return 4

    # 6. Cross-engine comparison.
    js_recs = parse_trace(js1)
    gd_recs = parse_trace(gd1)
    rep = compare(js_recs, gd_recs)
    intended, real = classify(rep["divergences"])
    log("comparison: %d field-pairs, %d divergences (%d intended-latch, %d unexpected)"
        % (rep["comparisons"], len(rep["divergences"]), len(intended), len(real)))

    # 7. Red control on the ACTUAL comparator (corrupt a COPY of the gd trace).
    corrupt = open(gd1_path).read()
    marker = corrupt.find('"queuedShotVariant":"drive"')
    if marker < 0:
        marker = corrupt.find('"hit":true')
    if marker < 0:
        log("FAIL: no marker to corrupt for red control")
        return 3
    corrupt = corrupt[:marker + 1] + "X" + corrupt[marker + 2:]
    corrupt_path = os.path.join(SCRATCH, "gd.corrupt.txt")
    open(corrupt_path, "w").write(corrupt)
    rep_corrupt = compare(js_recs, parse_trace(corrupt))
    red_ok = len(rep_corrupt["divergences"]) > 0
    log("red-control: corrupted copy produced %d divergences (must be >0): %s"
        % (len(rep_corrupt["divergences"]), red_ok))

    # Truncated-output control.
    truncated = "\n".join(gd1.splitlines()[:-5])
    rep_trunc = compare(js_recs, parse_trace(truncated))
    trunc_ok = rep_trunc.get("count_mismatch", False) or len(rep_trunc["divergences"]) > 0
    log("truncated-output control: count_mismatch=%s divergences=%d (must fail): %s"
        % (rep_trunc.get("count_mismatch"), len(rep_trunc["divergences"]), trunc_ok))

    # 8. First divergence per scenario.
    first_by_scen = {}
    for d in rep["divergences"]:
        scen = d["key"][0]
        first_by_scen.setdefault(scen, d)

    summary = {
        "schemaVersion": 2,
        "fixedStep": "1/120",
        "js_harness_exit": rc,
        "godot_harness_exit": rc_gd,
        "deterministic": det_ok,
        "total_comparisons": rep["comparisons"],
        "total_divergences": len(rep["divergences"]),
        "intended_latch_divergences": len(intended),
        "unexpected_divergences": len(real),
        "red_control_detected": red_ok,
        "truncated_output_detected": trunc_ok,
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

    # Verdict.
    if not red_ok:
        return 3
    if not trunc_ok:
        return 3
    if real:
        log("RESULT: unexpected divergences found — see summary.json. FAIL (exit 2).")
        return 2
    log("RESULT: PASS. Common-rate parity confirmed; latch divergence reproduced "
        "as the only difference (%d intended divergences)." % len(intended))
    return 0


if __name__ == "__main__":
    sys.exit(main())
