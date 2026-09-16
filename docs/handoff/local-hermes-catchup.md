# Local Hermes-Dev — setup & catch-up prompt

Copy everything below the line into a fresh session on the local machine.

---

You are picking up **Steam Circuit Padel Pro — the Godot 3D port**.

One repository, one remote, one destination — everything you need is inside it:

**`https://github.com/Jockeys97/steam-circuit-padel-godot`** (public)

Clone it, work inside it, commit to it. Nothing else is involved.

## What the project in front of you is

A steampunk padel arcade game rebuilt in **Godot 4.7.2** from the browser game that ships
in the same repository. The browser game lives in `js/` (with `index.html` and
`styles.css`) and is the **frozen reference**: the port has to play the *same match* — same
seed, same scripted input, tick for tick, same result. Read it, compare against it, never
edit it. The Godot project sits in `godot/`.

## Get it running (macOS)

```bash
git clone https://github.com/Jockeys97/steam-circuit-padel-godot
cd steam-circuit-padel-godot
```

Install **Godot 4.7.2** (version matters — the project declares features `4.7`,
GL Compatibility renderer):
https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip

Open the editor, import `godot/project.godot`, press **F5**. First open re-imports the
athlete assets (~1 min).

**Controls:** WASD/arrows move · **Space** charge & release a drive · **Meta** slice ·
**Alt** special · **Tab/Z** switch player · **Esc** pause · **Q** quit. Gamepad works too.

## The gates (run these before claiming anything is broken or fixed)

The whole test story is `godot/game/run.sh`, which wraps the engine with the right flags
and a strict log gate (a `PASS` line next to a `SCRIPT ERROR` is a failure, not a pass):

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
./godot/game/run.sh harness        # project smoke harness — must print PASS 8/8
./godot/game/run.sh test           # headless scripted playthrough of the real match scene
./godot/game/run.sh play           # open the playable window
```

Individual suites, headless:

```bash
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd      # the playable slice
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo
$GODOT --headless --path godot/ --script res://tests/save_steam_test.gd
$GODOT --headless --path godot/ --script res://tests/input/run_all.gd
$GODOT --headless --path godot/ --script res://tests/audits/run_all.gd
```

Green at hand-off: harness `PASS 8/8`, slice `PASS 304/304` (full) and `229/229` (demo),
saves `137/137`, input `4/4` (308 checks), audits `10/10` (221 checks), music `32/32`
with 15 injected-drift cases.

## Where the truth lives

- `docs/mission/STATE.md` — current phase and the outcome of every tick of work.
- `docs/mission/LOG.md` — the long-form record; every claim carries the command that
  produced it.
- `docs/mission/BOARD.md` — what is done, in flight, blocked.
- `docs/wayfinder/evidence/*.md` — one evidence file per slice: what was measured, how,
  and what refused to be measured.
- `docs/implementation/tickets/*.md` — the slice tickets (S3–S13).

Read `STATE.md` and `LOG.md` before touching anything; they are more current than any
summary you will be handed.

## How work is done here (non-negotiable)

1. **Evidence over assertion.** Every claim needs the command and its exit code. A suite
   that prints `PASS` while its own log carries `SCRIPT ERROR` is not green.
2. **Never fabricate output.** If a tool fails, say so and route around it.
3. **The browser game in `js/` is the frozen reference.** The port reads it; nothing edits it.
4. **One heavy process at a time.** Serialise engine runs so suites never race each other
   over the same checkout — two Godot processes on one project produce failures that look
   like bugs and are not.
5. **The demo build must stay locked.** The demo is the same executable with a `demo`
   feature tag; the full game must never be reachable from it by argument or config.
6. **Report plainly.** No raw IDs in prose, no jargon, no partial summaries — one message
   when the work is done, with the handles (commit, file path, exit code).

## What is already proven (do not redo)

- Cross-engine **parity**: three whole matches, same seed and scripted input, identical
  tick-by-tick (digests on record), with mutation tests proving the gate can fail.
- Nine arenas, three modes (drill, tournament, career) playable end to end, save file
  persisted, demo-vs-full proven by pixel diff (30.5% of the menu frame).
- A packaged Linux build and demo self-check exist; a universal macOS build exists.
- Two independent reviews have run; their findings are being repaired.

## What is open (start here)

1. **Play it and take notes.** Feel is the owner's call, never a self-report. Camera
   framing currently has four studied options and a pending verdict; watch for anything
   that reads as a bug — stuck states, dead inputs, wrong score, athletes clipping.
2. **Music is ported and tested but not wired into the match** — you will hear effects
   only. Wiring it into the live match is unclaimed work.
3. **Pause/rematch flow** was just under repair (ESC then rematch could freeze the sim
   with a stale HUD).
4. **Steam**: the GodotSteam GDExtension loads and the seam is verified, but the addon is
   not vendored into the project and nothing has been proven against a real client.
5. **Anything you fix, fix at the seam and test at the seam** — then push to the repo above
   with `git -c user.name="Luca Fantini" -c user.email="lucadefantini@gmail.com"`.

## Handing back

Write findings where they survive: a short evidence file under `docs/wayfinder/evidence/`
(what you did, what you measured, what you saw), a line in `docs/mission/LOG.md`, and push.
The Linux side picks up from there — it owns the deep harnesses, the parity matrix and the
heavy asset tooling.
