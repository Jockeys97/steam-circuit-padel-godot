# Gameplay + map hand-off — 2026-09-17

Read this before touching `godot/game/**` or `docs/wayfinder/**`.

Work sits on branch **`codex/input-bridge-and-slice-s14`** — 3 commits on top of
`a877d19`, **nothing pushed yet**. `main` is untouched and `origin/main` is 7 commits
ahead of the local `main` (see *Two histories* below before merging anything).

## The three commits (safe to build on)

| commit | what changed |
|---|---|
| `33ebd82` | **Input bridge.** The device is chosen per frame (`selectPrimaryGamepad`), Godot's button numbering replaces the browser's (LB is 9, not 4 — LB used to pause the match), the LEFT stick aims while a shot button is held and the athlete STOPS there, the right stick is the directional switch with a 0.72/0.30 latch, and taking over a pad holds its first press — armed on a swap, not on the match's first selection, which used to eat the serve on a pad. `godot/project.godot` carries the corrected bindings. |
| `0d8260a` | **Map charting for slice S14** + two corrections: the reference has **28** audit scripts, not 27 (`run-audits.mjs:21-23` globs the directory, so all 28 are wired — the *expected value* in `validate.py` was stale, the check is unchanged); and the reference audit suite cannot run on this Mac at all while `node_modules/` is absent (`sharp` does not resolve). |
| `7637fa3` | **Two instruments** — `godot/game/tools/pad_probe.gd` (prints, live, which button you press and which `padel_*` action it fires) and `godot/game/tools/yellow_map.py` (ASCII map of one colour class in a PNG; screen capture is refused on this host, so this is how a rendered frame gets measured). Plus `docs/wayfinder/evidence/active-player-marker.md`. |

## What is NOT in those commits, and why

- **The active-athlete marker.** It lives in `godot/game/match_controller.gd` and
  `godot/tests/game_slice_test.gd`, which a lane is writing **right now** (the timing
  presentation). Freezing half-finished work in history is worse than a dirty tree; the
  marker's evidence and its two tools are committed, the code lands next.
- **`godot/game/hud.gd`** carries another hand's work (pad hint strings, the feedback
  panel moved to the bottom right) — not this session's, left alone.
- **Three lanes in flight**: shot-logic parity, timing-logic parity, timing
  presentation (charging ring, advice word, precision bar, energy bar, and the timing
  verdict over the striker). Their files are the ones appearing as new under
  `godot/tests/`, `tools/sim-port/` and `godot/game/out/`.
- **Generated and heavy, deliberately uncommitted**: `art/generated/` (265 MB with the
  Pantera GLBs), `tools/meshy/**`, the capture PNGs that are re-rendered on every run.

## Getting the work

Nothing has been pushed. Two ways, pick one with Alessio:

```bash
# 1. from the bundle (no remote involved)
git fetch /tmp/gameplay-and-map-2026-09-17.bundle codex/input-bridge-and-slice-s14:luca/gameplay

# 2. push the branch itself (ask first: main must stay untouched)
git push -u origin codex/input-bridge-and-slice-s14
```

If you commit, use your own identity as the earlier hand-off says:
`git -c user.name="Luca Fantini" -c user.email="lucadefantini@gmail.com"`.

**Two histories.** The local `main` and `origin/main` have diverged: `8037c6b`≡`8fed1da`
and `0458c23`≡`2f7b538` are the *same work* committed twice (patch-for-patch identical —
297 and 1082 lines), and `a877d19` (athlete strokes ↔ gameplay contact) exists only
locally. Do not merge `main` into `origin/main` blindly: rebase the local-only work onto
`origin/main` and drop the two duplicates.

## Verified on this checkout (commands, not adjectives)

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --script res://tests/input/run_all.gd       # PASS 5/5, 392 checks, 7 not-ported (DOM)
$GODOT --headless --path godot/ --script res://tests/input/switch_mode_audit.gd   # PASS 84/84
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd     # 288/289
$GODOT --headless --path godot/ --script res://tests/audits/run_all.gd      # PASS 10/10 (221 checks)
$GODOT --headless --path godot/                                             # PASS 8/8 (harness = the main scene)
python3 docs/wayfinder/validate.py                                          # PASS, 0 errors, 0 warnings
```

The slice's single red is `the shipping pack exists … padel.pck` — a gitignored clone
artifact, by design. `flock` and `timeout` do not exist on macOS: every wrapper that
uses them exits 127 with an empty stream, so run the binaries directly.

## What to work on, and what "done" means

The contract is the three tickets (all eight sections each):

- `docs/wayfinder/tickets/shot-logic-parity.md` — every shot intent, anchor to anchor.
- `docs/wayfinder/tickets/timing-logic-parity.md` — the numbers behind PERFETTO.
- `docs/wayfinder/tickets/timing-presentation-3d.md` — the charging guide **and** the
  verdict over the striker. The owner confirmed on 2026-09-17 that he meant **both**.

A gate is done when its evidence file exists, its commands were re-run by someone other
than the implementer, and the counts are quoted. A marker that exists in code and cannot
be found in a rendered frame is **not** delivered — measure it (see
`docs/wayfinder/evidence/active-player-marker.md` for how).

## House rules that bind this work

1. `js/**` is the frozen reference: read it, never edit it.
2. Evidence over assertion: every claim carries its command and output.
3. One heavy engine process at a time (`pgrep -f Godot` before starting one); the game
   window alive is the owner's play-test — do not kill it.
4. Commit by explicit path, never `git add -A`: it would try to add 265 MB of `art/`.
5. Leave a running lane's files alone until it returns — three are in flight now.
