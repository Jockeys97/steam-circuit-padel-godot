#!/usr/bin/env python3
"""comparator.py — single source of truth for the cross-engine differential verdict.

Shared by the CLI runner (run_integration.py) and the no-engine self-tests
(test_comparator.py). There is no separate generic diff proxy: the CLI's final
verdict is `verdict()` below, and the tests exercise the same functions.

Exit-code contract (returned by verdict / main):
  0 all gates pass
  1 harness / compile / import failure (or invalid comparator input)
  2 unexpected divergence, count mismatch, corpus-count/coverage mismatch,
    or the known latch difference NOT reproduced exactly
  3 red-control / negative-control / truncation-control self-check failure
  4 determinism failure
  6 subprocess timeout
"""

import json

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

# Exact historical latch contract: (scenario, frame, field) -> (expected js
# value, expected gd value). A divergence is the diagnosed, intended one ONLY
# if it occurs on the EXACT frame, EXACT field, AND matches these EXACT
# values. Wrong frame, wrong field, wrong value, a missing occurrence, or an
# extra occurrence are all REAL (unexpected) divergences — the contract is a
# fixed point, not a name-only allowlist. Values per review/FINAL.md frame 2.
LATCH_CONTRACT = {
    ("zero-substep-latch", 2, "sim.queuedShotPower"): ("1.000000", "0.400000"),
    ("zero-substep-latch", 2, "sim.playerSwingBuffer"): ("0.000000", "0.271667"),
}

# Derived (scenario, field) view, kept for callers/messages that only need
# the field-scope shape; classification itself uses LATCH_CONTRACT exactly.
LATCH_ALLOWLIST = {(scen, field) for (scen, _frame, field) in LATCH_CONTRACT}


class ComparatorError(Exception):
    """Structurally invalid comparator input (empty, missing required fields)."""


def parse_trace(text):
    """Return list of record dicts from '# trace {...}' lines, in order."""
    recs = []
    for line in text.splitlines():
        if line.startswith("# trace "):
            recs.append(json.loads(line[len("# trace "):]))
    return recs


def evidence(text):
    """Only the '# ' evidence stream (header/trace/summary), excluding
    non-deterministic wall-clock resource logs."""
    return "\n".join(l for l in text.splitlines() if l.startswith("# "))


def check_harness(text, name):
    """Return a list of problems (empty == clean)."""
    problems = []
    if "# summary " not in text:
        problems.append("%s: missing # summary completion marker" % name)
    if "SCRIPT ERROR" in text:
        problems.append("%s: SCRIPT ERROR present" % name)
    for line in text.splitlines():
        if line.startswith("ERROR:") and "resources still in use" not in line:
            problems.append("%s: unapproved ERROR: %s" % (name, line[:120]))
    return problems


def runs_ok(runs, label):
    """runs = list of (exit_code, stdout_text). OK only if EVERY run exits 0 AND
    its own stdout passes check_harness. A failed run cannot be masked by stale
    output: the run's own text is checked, never a reused file."""
    problems = []
    for i, (rc, text) in enumerate(runs):
        if rc != 0:
            problems.append("%s run%d exit=%d" % (label, i + 1, rc))
        problems.extend(check_harness(text, "%s%d" % (label, i + 1)))
    return not problems, problems


def _validate(recs, name):
    if not recs:
        raise ComparatorError("%s trace has zero records (empty)" % name)
    for i, r in enumerate(recs):
        if not isinstance(r, dict):
            raise ComparatorError("%s record %d is not an object" % (name, i))
        for k in ("scenario", "frame", "steps", "input", "sim"):
            if k not in r:
                raise ComparatorError("%s record %d missing required field %r"
                                     % (name, i, k))
        if not isinstance(r["input"], dict) or not isinstance(r["sim"], dict):
            raise ComparatorError("%s record %d input/sim not objects" % (name, i))
        # A contract field silently ABSENT (no key at all) must not pass —
        # even when it is missing from BOTH js and gd. An explicit null is a
        # legitimate observed value; a missing key is a structural gap in the
        # capture and must fail loudly instead of comparing as None == None.
        for field in INPUT_FIELDS:
            if field not in r["input"]:
                raise ComparatorError(
                    "%s record %d missing input contract field %r (absent, not null)"
                    % (name, i, field))
        for field in SIM_FIELDS:
            if field not in r["sim"]:
                raise ComparatorError(
                    "%s record %d missing sim contract field %r (absent, not null)"
                    % (name, i, field))


def _scenario_seq(recs):
    return [r.get("scenario") for r in recs]


def compare(js_recs, gd_recs, expected_frames=None, expected_scenarios=None):
    """Field-by-field tol=0 comparison. Raises ComparatorError on structurally
    invalid input (empty / missing required fields). expected_frames /
    expected_scenarios, when provided, gate corpus coverage: an equally
    truncated pair (equal counts, zero field divergences) still fails."""
    _validate(js_recs, "js")
    _validate(gd_recs, "gd")

    rep = {
        "count_mismatch": len(js_recs) != len(gd_recs),
        "js": len(js_recs),
        "gd": len(gd_recs),
        "frame_count_ok": True,
        "scenario_ok": True,
        "divergences": [],
        "comparisons": 0,
        "first": None,
    }
    if expected_frames is not None:
        rep["frame_count_ok"] = (len(js_recs) == expected_frames
                                 and len(gd_recs) == expected_frames)
    if expected_scenarios is not None:
        rep["scenario_ok"] = (_scenario_seq(js_recs) == expected_scenarios
                              and _scenario_seq(gd_recs) == expected_scenarios)
    if rep["count_mismatch"]:
        return rep

    for j, g in zip(js_recs, gd_recs):
        key = (j["scenario"], j["frame"])
        if j["scenario"] != g["scenario"] or j["frame"] != g["frame"]:
            d = {"key": key, "field": "<alignment>",
                 "js": j["scenario"], "gd": g["scenario"]}
            rep["divergences"].append(d)
            if rep["first"] is None:
                rep["first"] = d
            continue
        rep["comparisons"] += 1
        if j.get("steps") != g.get("steps"):
            d = {"key": key, "field": "steps", "js": j.get("steps"), "gd": g.get("steps")}
            rep["divergences"].append(d)
            if rep["first"] is None:
                rep["first"] = d
        for field in INPUT_FIELDS:
            rep["comparisons"] += 1
            jv = j["input"].get(field)
            gv = g["input"].get(field)
            if jv != gv:
                d = {"key": key, "field": "input." + field, "js": jv, "gd": gv}
                rep["divergences"].append(d)
                if rep["first"] is None:
                    rep["first"] = d
        for field in SIM_FIELDS:
            rep["comparisons"] += 1
            jv = j["sim"].get(field)
            gv = g["sim"].get(field)
            if jv != gv:
                d = {"key": key, "field": "sim." + field, "js": jv, "gd": gv}
                rep["divergences"].append(d)
                if rep["first"] is None:
                    rep["first"] = d
    return rep


def classify(divergences):
    """Split into intended (exact historical latch contract match) vs real.

    A divergence is intended ONLY if (scenario, frame, field) is a key in
    LATCH_CONTRACT AND the observed (js, gd) values equal the contract's
    exact expected values. Same field/scenario but wrong frame, or same
    frame/field but wrong value(s), is REAL — the contract pins frame AND
    value, not just the field name.
    """
    intended = []
    real = []
    for d in divergences:
        key = d.get("key")
        scen, frame = (key[0], key[1]) if key else ("?", None)
        field = d.get("field", "?")
        expected = LATCH_CONTRACT.get((scen, frame, field))
        if expected is not None and (d.get("js"), d.get("gd")) == expected:
            intended.append(d)
        else:
            real.append(d)
    return intended, real


def latch_reproduced(intended):
    """True only when the intended set's (scenario, frame, field) keys equal
    LATCH_CONTRACT's keys exactly — every contracted occurrence present,
    none missing, none extra. No reproduction is NOT acceptable."""
    seen = {(d["key"][0], d["key"][1], d["field"]) for d in intended if d.get("key")}
    return seen == set(LATCH_CONTRACT.keys())


def red_detected(rep_baseline, rep_corrupt):
    """Baseline-relative red-control: the corruption must ADD divergences over
    the already-divergent baseline, cause a count mismatch, or produce a
    divergence classified real. A no-op mutation (identical result) is NOT
    accepted as a detected corruption."""
    _, real_c = classify(rep_corrupt["divergences"])
    return (len(rep_corrupt["divergences"]) > len(rep_baseline["divergences"])
            or rep_corrupt.get("count_mismatch")
            or len(real_c) > 0)


def verdict(rep, red_ok, trunc_ok):
    """Shared verdict helper. Returns (exit_code, message)."""
    intended, real = classify(rep["divergences"])
    if rep.get("count_mismatch"):
        return 2, "count mismatch: JS=%d Godot=%d records" % (rep["js"], rep["gd"])
    if not rep.get("frame_count_ok", True):
        return 2, "frame count does not match expected corpus (%d/%d)" % (rep["js"], rep["gd"])
    if not rep.get("scenario_ok", True):
        return 2, "scenario sequence does not match expected corpus"
    if not red_ok:
        return 3, "red-control did NOT detect corruption"
    if not trunc_ok:
        return 3, "truncated-output control did NOT fail"
    if not latch_reproduced(intended):
        seen = sorted({(d["key"][0], d["key"][1], d["field"]) for d in intended if d.get("key")})
        return 2, "known latch difference NOT reproduced exactly (intended=%r)" % seen
    if real:
        return 2, "%d unexpected divergence(s); first=%r" % (len(real), real[0])
    return 0, "PASS: input/queue parity + latch divergence reproduced exactly"
