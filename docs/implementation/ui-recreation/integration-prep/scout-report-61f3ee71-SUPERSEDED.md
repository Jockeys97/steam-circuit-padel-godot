# Brother-branch scout — `codex/gameplay-and-map` (2026-09-17, read-only)

Scouted by a dev-work subagent. **No write, fetch, checkout, pull, stash, reset, merge,
rebase or config change was made in the active checkout**
(`/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot`). All work was
done with read-only git/gh commands plus an isolated partial clone at
`/tmp/padel-brother-prep/remote/clone`. One Godot process was NOT started; budget $0.

## Bottom line

- The branch exists, is pushed, and is **4 commits ahead / 0 behind** the current
  `main` — a pure linear stack (merge base == main tip), so a future integration is a
  conflict-free fast-forward at git level **as of these SHAs**.
- **There is no PR.** `gh pr list --state all` returns `[]`; the user-supplied
  `/pull/new/codex/gameplay-and-map` URL is the GitHub *compare page for creating* a
  PR, not an existing PR.
- **The "map" in the branch name is not a game-arena map.** It is
  `docs/wayfinder/map.md`, the project WORK map (slice S14: shot-logic parity,
  timing-logic parity, timing presentation). No arena/layout asset, no `.tscn`, no
  `godot/game/arenas/**` change is in this branch.
- **The branch tip is deliberately partial** (see R1): it rewrites the pad input
  bridge but does NOT commit the caller (`godot/game/match_controller.gd`) that drives
  it — that "follows in a second push" per its own handoff doc. **Merging the tip
  as-is would leave the pad silently dead** (keyboard unaffected). Wait for the
  second push before integrating.
- No file overlap with the dirty UI work in the active checkout today: branch touches
  `godot/game/input_map.gd`, `godot/game/match_config.gd`, `godot/project.godot`,
  `godot/tests/input/*`, `docs/**`, tools; the dirty files are
  `godot/game/main_menu.gd` + `godot/game/match_controller.gd`. The *next* push from
  the brother will touch `match_controller.gd` — exactly our dirty file (R2).

## Verified refs (fresh re-check 2026-09-17 01:21:59 +0200)

| ref | sha |
|---|---|
| `origin/codex/gameplay-and-map` | `61f3ee718dda7aaf304447384480695a29e0efac` |
| `origin/main` = local `main` HEAD | `252ff6074039372ebbf8ec682f9adda0e9c80d03` |
| merge base | `252ff6074039372ebbf8ec682f9adda0e9c80d03` (== main tip) |
| branch tree | `60fe07819fd3b34a405718902caee5914da12dec` |

Local checkout state (read-only observation): `main` @ `252ff60`, upstream `origin/main`,
`+0 -0`; modified: `godot/game/main_menu.gd`, `godot/game/match_controller.gd`; untracked
incl. `godot/assets/ui/`, `docs/implementation/ui-recreation/`, `art/concepts/`,
`godot/game/out/*.png` (UI captures), `.hermes/`.

## The 4 commits (all by Alessio Fantini, 2026-09-17 01:12–01:16 +0200)

1. `d5bb0f8` — **input bridge fix**: `godot/game/input_map.gd` rewritten (+368/-110):
   per-frame device selection (`select_device`/`assign_devices`), left-stick absolute
   aim (`shot_aim_axis`), movement zeroed while charging, switch-flick latch (0.72 arm /
   0.30 re-arm), possession arming on pad change only, curved stick response (1.28 /
   aim 0.72), second-player pad sampler; `godot/project.godot` bindings corrected from
   browser numbering to Godot's (LB=9, Start=6, RB=10, D-pad 11–14, split-step=LT
   axis, sprint=RT axis); `match_config.gd::control_mode()` (saved preference now
   reaches the match).
2. `a52bbb2` — **docs: slice S14 charting**: `docs/wayfinder/map.md`, three new
   tickets (shot-logic-parity, timing-logic-parity, timing-presentation-3d),
   `validate.py` expectation 27→28 audit scripts (expected VALUE fixed, check
   unchanged), regenerated `validation.md`.
3. `cc88a14` — **two instruments**: `godot/game/tools/pad_probe.gd` (live button→action
   probe), `godot/game/tools/yellow_map.py` (ASCII colour-class map of a captured PNG;
   used where screenshots are refused), `docs/wayfinder/evidence/player-switch-parity.md`
   + `active-player-marker.md`.
4. `61f3ee7` — **handoff doc** `docs/handoff/gameplay-and-map-2026-09-17.md` +
   `docs/mission/LOG.md`/`STATE.md` updates.

Totals: 21 files, +1607/−195. Full list: `changed-files.txt` / `branch-inventory.json`.

## What is intentionally NOT in the branch (per its own handoff)

- `godot/game/match_controller.gd` and `godot/tests/game_slice_test.gd` — the
  active-athlete marker + the input-bridge *caller*; "code follows in a second push".
- Three lanes still in flight on the brother's machine: shot-logic parity, timing-logic
  parity, timing presentation (S14a/b/c) — new files under `godot/tests/`,
  `tools/sim-port/`, `godot/game/out/`; "do not build on those files yet".
- `godot/game/hud.gd` — another hand's work, left alone.
- Frozen parity reference `js/`, `index.html`, `styles.css`: **verified untouched**
  (diff for those paths is empty). `GAMEPLAY_RULES.md`, `godot/src/sim/**` untouched.

## Risks / blockers (condensed; full text in the JSON)

- **R1 (high) — partial input bridge.** The new `input_map.gd` reads a per-instance
  `device` that defaults to `NO_DEVICE` (all pad reads neutral) and is only set via
  `set_device`/`select_device`, whose only intended caller (`match_controller.gd`)
  is not committed. Pad = dead at the tip; keyboard = fine. Do not merge until the
  second push (or merge with eyes open and accept a keyboard-only pad-less build).
- **R2 (medium) — seam with our UI work.** The coming second push edits
  `match_controller.gd` (and one section of `game_slice_test.gd`); our active checkout
  has `match_controller.gd` dirty. Sequence: UI lane commits first, then integrate.
- **R3 (medium) — gate claims are on an integrated working tree, not the pushed tip.**
  Handoff numbers: input 5/5 (393 checks; new `switch_mode_audit` 79/79), audits 10/10,
  harness 8/8, slice 292/292 (only red: gitignored `padel.pck` "absent — not scored").
  Mission rule: re-run by someone other than the implementer.
- **R4 (low) — `project.godot` [input] block rewritten**: later editors of
  `project.godot` (e.g. UI autoloads) must rebase on it; conflicts are semantic.
- **R5 (low) — the JS reference audit suite cannot run on this Mac** (`node_modules/`
  absent, `sharp` unresolved). Recorded by the branch itself; not a merge blocker.
- **R6 (info) — commit author is `alessiofantini@Host-002.lan`** (machine-local, not a
  GitHub-linked email): PR/commit attribution may show unlinked.
- **R7 (info) — divergent local histories on the brother's machine**: duplicates
  `8037c6b`≡`8fed1da` and `0458c23`≡`2f7b538` "must not be merged"; local-only
  `a877d19` (athlete strokes ↔ gameplay contact) is not in this branch and is unknown
  to the active repo (`git cat-file` → not a valid object). Ask him whether it is
  wanted upstream — do not fetch his local main.

## Proposed safe integration order (for the parent to execute later, not now)

Preconditions: (a) UI lane's `main_menu.gd`/`match_controller.gd` work committed or
handed off; (b) brother's second push landed or explicit "tip is final" go-ahead;
(c) SHAs re-verified.

```bash
# in the active checkout, once its owner allows network state changes
git fetch origin
git rev-parse origin/main origin/codex/gameplay-and-map   # expect 252ff60.. / 61f3ee7.. or newer
git merge-base --is-ancestor origin/main origin/codex/gameplay-and-map   # true ⇒ ff-able
git merge --ff-only origin/codex/gameplay-and-map          # conflict-free at current SHAs
```

Then gates on the merged tree, **one Godot process at a time** (macOS, engine 4.7.2
`ed1daf0bf`):

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --import
$GODOT --headless --path godot/ --script res://tests/input/run_all.gd
$GODOT --headless --path godot/ --script res://tests/audits/run_all.gd
$GODOT --headless --path godot/
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd
python3 docs/wayfinder/validate.py
```

Then independent re-run by someone other than the implementer, then push `main` (owner
account). PR traceability, if wanted: the branch owner can open the PR via the given
`/pull/new/` URL (the repo currently has zero PRs).

Do-not list: no pull/checkout/stash/reset/merge/rebase/fetch in the active checkout
while UI work is uncommitted; never `git add -A` (repo carries ~265 MB
`art/generated/`, `tools/meshy/**`, captures); do not merge the duplicate commits or
the brother's local `main`; do not treat the PR-creation URL as an existing PR.

## Artifacts

- `branch-inventory.json` — machine-readable: refs, commits, per-file inventory
  (status/insertions/deletions/category), risks with evidence, ownership,
  integration plan.
- `changed-files.txt` — flat `status<TAB>path` list (21 entries).
- `/tmp/padel-brother-prep/remote/clone` — isolated partial clone used for inspection
  (safe to delete; owned by nobody else).

Re-verify freshness at any time with read-only commands:

```bash
git ls-remote https://github.com/Jockeys97/steam-circuit-padel-godot.git 'refs/heads/*'
gh pr list --repo Jockeys97/steam-circuit-padel-godot --state all
```
