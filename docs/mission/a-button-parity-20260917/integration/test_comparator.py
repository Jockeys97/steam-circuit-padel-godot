#!/usr/bin/env python3
"""
test_comparator.py — no-engine self-tests for the comparator false-green paths.

Runs WITHOUT node/Godot: exercises the exact functions the CLI uses
(comparator.compare / classify / red_detected / runs_ok / verdict) on synthetic
records. Each test targets one false-green path the review/FINAL.md called out.

Rerun (no engine, no installs, no network):

    python3 docs/mission/a-button-parity-20260917/integration/test_comparator.py

Exit 0 == all tests pass.
"""

import copy
import sys

import comparator

CONTRACT = comparator.LATCH_CONTRACT
# The one historical latch occurrence: zero-substep-latch, frame 2, two fields.
LATCH_FRAME = 2
LATCH_POWER = CONTRACT[("zero-substep-latch", LATCH_FRAME, "sim.queuedShotPower")]
LATCH_SWING = CONTRACT[("zero-substep-latch", LATCH_FRAME, "sim.playerSwingBuffer")]


def rec(scen, frame, steps=1, input_vals=None, sim_vals=None):
    inp = {f: None for f in comparator.INPUT_FIELDS}
    inp.update(input_vals or {})
    sim = {f: None for f in comparator.SIM_FIELDS}
    sim.update(sim_vals or {})
    return {"scenario": scen, "frame": frame, "steps": steps,
            "input": inp, "sim": sim}


def latch_pair_at(frame, js_power=None, gd_power=None, js_swing=None, gd_swing=None):
    """One (js, gd) record pair at `frame`. Defaults to the EXACT historical
    contract values only when frame == LATCH_FRAME; otherwise defaults to
    identical (non-diverging) records, since the real corpus only diverges
    once (frame 2)."""
    if frame == LATCH_FRAME:
        js_power = LATCH_POWER[0] if js_power is None else js_power
        gd_power = LATCH_POWER[1] if gd_power is None else gd_power
        js_swing = LATCH_SWING[0] if js_swing is None else js_swing
        gd_swing = LATCH_SWING[1] if gd_swing is None else gd_swing
    else:
        js_power = "1.000000" if js_power is None else js_power
        gd_power = js_power if gd_power is None else gd_power
        js_swing = "0.000000" if js_swing is None else js_swing
        gd_swing = js_swing if gd_swing is None else gd_swing
    j = rec("zero-substep-latch", frame,
            sim_vals={"queuedShotPower": js_power, "playerSwingBuffer": js_swing})
    g = rec("zero-substep-latch", frame,
            sim_vals={"queuedShotPower": gd_power, "playerSwingBuffer": gd_swing})
    return j, g


def neutral(frame):
    r = rec("no-input", frame)
    return r, copy.deepcopy(r)


EXP_FRAMES = 4
EXP_SCEN = ["no-input", "no-input", "zero-substep-latch", "zero-substep-latch"]


def build_traces():
    """Baseline corpus: 2 no-input + 2 latch-scenario frames. Only frame 2
    (LATCH_FRAME) diverges, matching the exact historical contract; frame 3
    is steady-state (no divergence) — mirrors the real one-occurrence corpus."""
    js, gd = [], []
    for f in range(2):
        j, g = neutral(f)
        js.append(j), gd.append(g)
    for f in range(2, 4):
        j, g = latch_pair_at(f)
        js.append(j), gd.append(g)
    return js, gd


TESTS = []


def test(name):
    def deco(fn):
        TESTS.append((name, fn))
        return fn
    return deco


@test("exact contract: latch frame/field/value match is intended, other field is real")
def t_field_scoped():
    js, gd = build_traces()
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    intended, real = comparator.classify(rep["divergences"])
    assert comparator.latch_reproduced(intended), "latch must reproduce exactly"
    assert real == [], "no unexpected divergences expected, got %r" % real
    assert comparator.verdict(rep, True, True)[0] == 0

    # Divergence on a DIFFERENT field at the SAME contracted frame -> real.
    js2, gd2 = build_traces()
    js2[2]["sim"]["queuedShotAim"] = "1.0"
    gd2[2]["sim"]["queuedShotAim"] = "0.5"
    rep2 = comparator.compare(js2, gd2, EXP_FRAMES, EXP_SCEN)
    intended2, real2 = comparator.classify(rep2["divergences"])
    assert ("zero-substep-latch", LATCH_FRAME, "sim.queuedShotAim") not in CONTRACT
    assert any(d["field"] == "sim.queuedShotAim" for d in real2), "must be real"
    assert comparator.verdict(rep2, True, True)[0] == 2


@test("wrong frame: contract field diverging on the WRONG frame is real, not intended")
def t_wrong_frame():
    js, gd = build_traces()
    # Move the divergence to frame 3 instead of the contracted frame 2.
    js[2]["sim"]["queuedShotPower"] = "1.000000"
    gd[2]["sim"]["queuedShotPower"] = "1.000000"
    gd[3]["sim"]["queuedShotPower"] = "0.400000"  # differs from js[3] now
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    intended, real = comparator.classify(rep["divergences"])
    assert any(d["key"][1] == 3 and d["field"] == "sim.queuedShotPower" for d in real), \
        "wrong-frame occurrence must be classified real"
    assert comparator.latch_reproduced(intended) is False, \
        "contract's frame-2 occurrence is missing -> not reproduced"
    assert comparator.verdict(rep, True, True)[0] == 2


@test("wrong value: right frame/field but value != contract is real")
def t_wrong_value():
    js, gd = build_traces()
    gd[2]["sim"]["queuedShotPower"] = "0.999999"  # not the contracted 0.400000
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    intended, real = comparator.classify(rep["divergences"])
    assert any(d["field"] == "sim.queuedShotPower" for d in real), \
        "wrong value at contracted frame/field must be real"
    assert comparator.latch_reproduced(intended) is False
    assert comparator.verdict(rep, True, True)[0] == 2


@test("extra occurrence: contract satisfied but an ADDITIONAL divergence exists -> real, verdict fails")
def t_extra_occurrence():
    js, gd = build_traces()
    # Contract at frame 2 is intact; add an unrelated extra divergence at frame 3.
    gd[3]["sim"]["queuedShotAim"] = "0.123456"
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    intended, real = comparator.classify(rep["divergences"])
    assert comparator.latch_reproduced(intended) is True
    assert len(real) == 1 and real[0]["field"] == "sim.queuedShotAim"
    assert comparator.verdict(rep, True, True)[0] == 2


@test("known latch difference must be present exactly (no-repro is a failure)")
def t_latch_must_reproduce():
    js, gd = build_traces()
    # Neutralize the latch difference: make gd identical to js at frame 2.
    gd[2]["sim"]["queuedShotPower"] = "1.000000"
    gd[2]["sim"]["playerSwingBuffer"] = "0.000000"
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    assert rep["divergences"] == [], "expected zero divergences"
    code, _ = comparator.verdict(rep, True, True)
    assert code == 2, "no reproduction must fail, got exit %d" % code


@test("empty and missing-required-field inputs raise ComparatorError")
def t_empty_missing():
    try:
        comparator.compare([], [], EXP_FRAMES, EXP_SCEN)
        raise AssertionError("compare([],[]) must raise")
    except comparator.ComparatorError:
        pass

    js, gd = build_traces()
    bad = [dict(r) for r in js]
    del bad[0]["sim"]
    try:
        comparator.compare(bad, gd, EXP_FRAMES, EXP_SCEN)
        raise AssertionError("missing 'sim' must raise")
    except comparator.ComparatorError:
        pass

    bad2 = [dict(r) for r in js]
    bad2[0]["input"] = "nope"
    try:
        comparator.compare(bad2, gd, EXP_FRAMES, EXP_SCEN)
        raise AssertionError("non-dict input must raise")
    except comparator.ComparatorError:
        pass


@test("contract field silently ABSENT on both sides raises, not a silent None==None pass")
def t_missing_field_both_sides():
    js, gd = build_traces()
    # Remove a contract field key entirely (not null) from BOTH sides, at the
    # SAME record: this is a structural capture gap, distinct from an
    # explicit null, and must fail loudly rather than compare equal.
    bad_js = [dict(r, input=dict(r["input"])) for r in js]
    bad_gd = [dict(r, input=dict(r["input"])) for r in gd]
    del bad_js[1]["input"]["sprint"]
    del bad_gd[1]["input"]["sprint"]
    try:
        comparator.compare(bad_js, bad_gd, EXP_FRAMES, EXP_SCEN)
        raise AssertionError("field absent from BOTH js and gd input must raise")
    except comparator.ComparatorError as e:
        assert "sprint" in str(e)

    # Same for a sim-contract field.
    bad_js2 = [dict(r, sim=dict(r["sim"])) for r in js]
    bad_gd2 = [dict(r, sim=dict(r["sim"])) for r in gd]
    del bad_js2[2]["sim"]["shotCharge"]
    del bad_gd2[2]["sim"]["shotCharge"]
    try:
        comparator.compare(bad_js2, bad_gd2, EXP_FRAMES, EXP_SCEN)
        raise AssertionError("field absent from BOTH js and gd sim must raise")
    except comparator.ComparatorError as e:
        assert "shotCharge" in str(e)

    # Control: an EXPLICIT null on both sides is legitimate and must NOT raise.
    ok_js = [dict(r, input=dict(r["input"])) for r in js]
    ok_gd = [dict(r, input=dict(r["input"])) for r in gd]
    ok_js[1]["input"]["sprint"] = None
    ok_gd[1]["input"]["sprint"] = None
    comparator.compare(ok_js, ok_gd, EXP_FRAMES, EXP_SCEN)  # must not raise


@test("equally truncated traces fail against expected corpus frame count")
def t_equal_truncation():
    js, gd = build_traces()
    rep = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    assert rep["frame_count_ok"] is True
    # Both truncated to 3 frames, still equal -> no count mismatch, no divergence.
    rep_t = comparator.compare(js[:3], gd[:3], EXP_FRAMES, EXP_SCEN)
    assert rep_t["count_mismatch"] is False
    assert rep_t["frame_count_ok"] is False, "equal truncation must fail coverage"
    assert comparator.verdict(rep_t, True, True)[0] == 2


@test("unequal traces fail via count mismatch and propagate to verdict")
def t_unequal():
    js, gd = build_traces()
    rep = comparator.compare(js, gd[:3], EXP_FRAMES, EXP_SCEN)
    assert rep["count_mismatch"] is True
    assert comparator.verdict(rep, True, True)[0] == 2


@test("scenario sequence mismatch fails verdict")
def t_scenario_seq():
    js, gd = build_traces()
    reorder = [js[2], js[3], js[0], js[1]]
    rep = comparator.compare(reorder, gd, EXP_FRAMES, EXP_SCEN)
    assert rep["scenario_ok"] is False
    assert comparator.verdict(rep, True, True)[0] == 2


@test("red-control is baseline-relative; no-op mutation is NOT detected")
def t_red_control():
    js, gd = build_traces()
    baseline = comparator.compare(js, gd, EXP_FRAMES, EXP_SCEN)
    assert len(baseline["divergences"]) > 0, "baseline already divergent (latch)"

    # Real corruption: latch scenario, UNRELATED field (queuedShotAim) -> real.
    gd_c = copy.deepcopy(gd)
    gd_c[2]["sim"]["queuedShotAim"] = "0.999000"
    rep_c = comparator.compare(js, gd_c, EXP_FRAMES, EXP_SCEN)
    _, real_c = comparator.classify(rep_c["divergences"])
    assert any(d["field"] == "sim.queuedShotAim" for d in real_c), "must classify real"
    assert comparator.red_detected(baseline, rep_c) is True
    assert comparator.verdict(rep_c, comparator.red_detected(baseline, rep_c), True)[0] == 2

    # No-op corruption: rename the NON-compared 'delta' key -> identical result.
    gd_noop = copy.deepcopy(gd)
    # rename a field outside INPUT/SIM/steps on one record only
    gd_noop[0]["delta"] = "x"
    del gd_noop[0]["delta"]
    gd_noop[0]["extra"] = "unused"
    rep_noop = comparator.compare(js, gd_noop, EXP_FRAMES, EXP_SCEN)
    assert comparator.red_detected(baseline, rep_noop) is False, \
        "no-op mutation must NOT be accepted as detected corruption"


@test("runs_ok rejects nonzero exit codes and missing markers (no stale reuse)")
def t_runs_ok():
    good = "# trace {}\n# summary ok\n"
    ok, _ = comparator.runs_ok([(0, good), (0, good)], "x")
    assert ok is True

    ok, probs = comparator.runs_ok([(1, good)], "x")
    assert ok is False and any("exit=1" in p for p in probs)

    # A stale-good file cannot mask a failed second run: rc2 != 0 fails the pair.
    ok, probs = comparator.runs_ok([(0, good), (1, good)], "x")
    assert ok is False and any("run2" in p for p in probs)

    # Missing summary marker fails.
    ok, probs = comparator.runs_ok([(0, "# trace {}")], "x")
    assert ok is False and any("summary" in p for p in probs)


def main():
    passed = failed = 0
    for name, fn in TESTS:
        try:
            fn()
            print("PASS  %s" % name)
            passed += 1
        except Exception as e:  # noqa: BLE001
            print("FAIL  %s\n      %s: %s" % (name, type(e).__name__, e))
            failed += 1
    print("\n%d passed, %d failed" % (passed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
