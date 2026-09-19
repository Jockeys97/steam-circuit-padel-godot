# The second player stands still in co-op (one controller on the desk)

Date: 2026-09-19 · Repo `steam-circuit-padel-godot`, worktree `luca-game-mechanics`, HEAD `e2be431`.
Ad-hoc diagnosis, no code changed.

## The report

Owner, playing the built worktree: *"Second player stops moving now, something broke."*

**Verdict: nothing in the code changed, and nothing in the code is wrong.** The stored profile is
in **co-op**, and co-op is a *two-controller* mode by the reference's own design: the partner slot
is a human input fed by the second player's sampler, which is **pad-only**. With one controller on
the machine, the partner is repositioned for each serve and then takes no part in the match.

## The rules that govern it

| Rule | Where |
|---|---|
| Co-op/versus mean humans on both slots: `_second_human()` is `state.pvp or state.coop` | `godot/game/match_controller.gd:1253` |
| The partner's movement comes from the second input struct only in co-op: `control_paddle_charge` / `queue_paddle_hit` / `move_human_paddle` / `attempt_human_swing` for `state.playerMate` | `godot/src/sim/sim.gd:2778-2786`, `:3030` |
| The AI moves the partner **only when the mode is not co-op**: `if not state.coop:` in `update_doubles_ai` | `godot/src/sim/sim.gd:2457` |
| The second sampler is pad-only — no keyboard, no InputMap action | `godot/game/input_map.gd:31-33`, `:262-265` |
| With no second pad, `assign_devices` leaves the second sampler at `NO_DEVICE` | `godot/game/input_map.gd:357-364` |
| Same in the frozen reference: `getInput2()` reads `gamepad2` and nothing else | `js/main.js:1096-1122` |
| The reference says it out loud, beside the player-mode panel: *"Co-op: two controllers on the same team, each drives one player."* | `js/i18n.js:1268` (`pmHint`), shown at `index.html:176` |
| The reference's default is `solo` | `js/ui.js:476` |

## The profile it was reported from

`user://save/prefs.json`, modified 00:12 local while the game was running:
`playerMode: "coop"`, `pacePreset: "standard"`, `mode: "quick"`, `controlMode: "semi"`.
The same write carries the pace rung the owner pressed on the new play-flow row — that feature
works. `playerMode` is the value the arena screen's players panel persists.

## The measurement

`godot/_probe_second_player.gd` (ad-hoc, project root, outside the sweep's hashed trees): one match
per human mode, 1200 frames (20 s) each, the first player driven by the repo's own
`game/scripted_player.gd` through the real `apply_frame` path, no second controller attached.

`moved` is the number of frames a paddle moved *continuously* (a driven paddle covers a few px a
frame); `jumps` counts serve repositioning, which teleports a paddle; `travel` is the furthest
distance from its start — the metric that lies, because a repositioned paddle travels without ever
playing.

| mode | paddle | moved (frames) | jumps | travel (px) | longest rally | points |
|---|---|---|---|---|---|---|
| solo | player | 1030 | 1 | 430.5 | **9** | 2 |
| solo | **playerMate (partner)** | **859** | 1 | 510.5 | | |
| solo | opponent / opponentMate | 791 / 688 | 1 / 1 | 503.4 / 503.0 | | |
| coop | player | 772 | 3 | 430.5 | **1** | 4 |
| coop | **playerMate (partner)** | **0** | 3 | 304.0 | | |
| coop | opponent / opponentMate | 435 / 418 | 3 / 3 | 505.9 / 444.2 | | |
| pvp | player / playerMate | 343 / 352 | 4 / 4 | 430.6 / 348.6 | **0** | 4 |
| pvp | opponent / opponentMate (the second human's side) | 0 / 0 | 1 / 1 | 88.1 / 120.4 | | |

The partner in co-op **never plays** — zero continuously-moving frames — while being moved by three
serve repositionings, which is exactly why a travel-only reading ("it moved 304 px") is not evidence
of play. The rally statistic collapses with it, 9 to 1, and in pvp the *second human's* side is the
one that stands still. Sampler-level checks confirm the reason: a non-primary sampler holds
`NO_DEVICE` with no controller attached and its sample reads `moveX 0.0` with no left/right.

## Not a regression from this session's work

The same probe, unchanged, on the pre-pace tree (`/private/tmp/pace-baseline`, `deab8cf` =
`9ea56e5^`): **identical numbers to the float** — solo partner `moved 859`, `travel 510.539245605469`;
co-op partner `moved 0`, `jumps 3`, `travel 304.0`; pvp opponents `moved 0`. `PASS 17/17` on both
trees. The pace feature scales the simulation clock in `advance_frame` and the play-flow change adds
a row to the modes screen; neither touches the second player's input or the co-op branch. The
baseline run's six `SCRIPT ERROR` lines are the documented empty-import-cache signature
(`padel_theme.tres` failing to preload, `Nonexistent function 'bind_seam'`) in that scratch worktree
— they do not touch the simulation, and the two runs agree to the float.

## What to do

Immediate, no code: pick **Solo** on the arena screen's players panel (`Giocatori`) before starting a
quick match, or attach a **second** controller for co-op/versus. Solo is the mode where the partner is
the simulation's AI and plays (859 continuously-moving frames, measured).

Open for the owner's verdict, each a real fork:

1. **Parity only** — keep the reference's behaviour and its existing hint text (this is what the
   current build does).
2. **Parity plus a live signal** — keep the behaviour, and show beside the panel whether a second
   controller is detected right now.
3. **Gate the buttons** — disable or annotate co-op/versus while only one controller is connected.
4. **AI fallback** — drive the partner with the simulation's AI when co-op is selected with no second
   controller. A deliberate divergence from the frozen reference: the browser does not do this.

## Limitations

- One seed and one 20-second run per mode; the motion numbers are deterministic (the two trees agree
  to the float) but the *points* and *rally* columns are one sample each. The partner's non-participation
  is measured as motion and corroborated by the rally collapse, not by a per-paddle hit counter (the
  simulation keeps `longestRally` / `totalRallyHits` only, `sim.gd:450-451`).
- The machine's controller inventory is from `hidutil list`: one physical pad, an `XboxSeriesXGamepad`
  (vendor `0x45e`, product `0xb12`), listed twice as its two HID interfaces. Whether Godot enumerates
  that as one joypad or two was **not** measured — if it appears as two, a co-op match could hand the
  second sampler the same physical pad, which would look different from the frozen partner measured here.
- Whether the stored `coop` was chosen in this session or predates it could not be determined: the
  save has no history, and a single prefs write rewrites the whole group, so the file's mtime dates
  *a* write (the pace rung press) rather than the `playerMode` value.
