# Player switching, the two sticks, and which pad the game reads

- **Date:** 2026-09-16 (CEST) · **Host:** the owner's Mac (Apple Silicon M4), engine `4.7.2.stable.official.ed1daf0bf`
- **Question asked:** "does the 3D have the same switching system with the stick?" — then, after the owner's own review of the mapping: "complete the controller bridge".
- **Answer, first line:** **the switching *rules* were the same and the whole input bridge around them was not.** Four things were wrong, and one of them was not about the stick at all: the pad's buttons were numbered like the **browser's** Gamepad API, so on a real controller **LB paused the match**, `View` switched player, RB and Start did nothing and the D-pad set the wrong tactics.
- **`godot/src/sim/**` was not modified**: the rules were right. The three-match parity proof is re-run below to prove it still is.
- **Not committed.** Working tree only; the repository has other lanes in flight.

---

## 1. What was found, at the line

| # | finding | evidence |
|---|---|---|
| F-1 | **No latch on the flick.** The reference arms at 0.72 and re-arms only below 0.30 (`js/main.js:943-948`), and holding a shot button clears it (`:925`). The port re-sent `switchDirection` on **every tick** the stick stayed past 0.72 and never cleared it. | `input_map.gd` before: `elif right.length() >= SWITCH_FLICK:` — no release threshold, no latch state |
| F-2 | **The switching mode never reached the match.** `assisted`/`semi`/`manual` are a saved preference with a translated label, and the simulation has all three branches — but `state.controlMode` was only ever the literal `"semi"`. | `grep -rn "controlMode" godot/ --include=*.gd` → default, reset and reads only; no reader of the preference |
| F-3 | **The second pad had no sampler and no input.** `_frame_input2 = Sim.empty_input()` was its only write. | `match_controller.gd` before: `_frame_input2 = Sim.empty_input()` |
| **F-4** | **The pad's buttons were numbered like the browser's.** The Gamepad API numbers 0=A 1=B 2=X 3=Y **4=LB 5=RB 6=LT 7=RT 8=back 9=start 10=LS 11=RS 12-15=D-pad**; Godot numbers **4=back 5=guide 6=start 7=LS 8=RS 9=LB 10=RB 11-14=D-pad**. Every binding past Y had been pasted from the browser. | `godot/project.godot` before: `padel_switch`=4, `padel_technical`=5, `padel_split_step`=6, `padel_sprint`=7, `padel_pause`=9, the four tactics=12-15. The engine's own constants on this host: `A=0 B=1 X=2 Y=3 BACK=4 GUIDE=5 START=6 LS=7 RS=8 LB=9 RB=10 DPAD_UP=11 DOWN=12 LEFT=13 RIGHT=14`, axes `4=LT 5=RT`. |
| **F-5** | **The aim came from the right stick, and the athlete kept moving while charging.** The reference stops the athlete (`js/main.js:924`, `g.move = {x: 0, y: 0}`) and aims with the **left** stick absolutely (`:920-923`, `shotAimAxis` at `:301-304`); the right stick only ever asks for the switch. `analogAim` is true whenever the aim comes from the pad, even centred (`:1073`). | `input_map.gd` before: `if charge_action != null: if right.length() > 0.02: input["aim"] = right.x`, with `moveX` keeping the stick through the charge |
| **F-6** | **The stick response was linear.** The reference curves the radial result by **1.28** (`js/main.js:295`) and the aim by **0.72**, sign kept (`shotAimAxis`, `:301-304`). | `input_map.gd` before: `return v.normalized() * minf(1.0, scaled)` — no exponent anywhere |
| F-7 | **The device was fixed to 0.** The reference picks the pad somebody touches, keeps the current one during a local match, and gives the second seat the next connected pad (`js/main.js:258-276`, `:780-784`); a pad that takes over mid-match does not fire the shot it was holding (`awaitingGameplayRelease`, `:838-843`, read at `:838-843`). | `input_map.gd` before: `const DEVICE := 0`, used for every read |
| F-8 | **The remap audit shared F-4's assumption.** Its free-button list and its comment ("the map carries 0-7, 9 and 12-15") are the browser's numbering; button 10 is RB here. | `tests/input/input_remap_a11y_audit.gd:150-152`, before |

F-8 is why F-4 survived: the audit that owns the bindings was asserting the same wrong numbers.

## 2. What was changed

| file | change |
|---|---|
| `godot/project.godot` | Every past-Y binding moved to Godot's numbering: `padel_switch`→LB(9), `padel_technical`→RB(10), `padel_pause`→Start(6), the four tactics→11/12/13/14, `padel_split_step`→the LT axis (4), `padel_sprint`→the RT axis (5) with its bogus button dropped. A comment block at the head of `[input]` states both numberings and what went wrong. |
| `godot/game/input_map.gd` | Rewritten around `device` (chosen, not assumed), `select_device`/`assign_devices`/`device_has_activity` (the reference's policy), `set_device` (drops the previous pad's edges and arms possession), the latch with its release and its charge re-arm, the **left-stick absolute aim** through `shot_aim_axis`, the movement zeroed while the pad charges, the aim a released charge carries (`shotAimQueued`, `:933`/`:1056`), the curved sticks, and the second pad's one-shots read off its own buttons. |
| `godot/game/match_controller.gd` | `_input_source2` (pad-only sampler) and `queued_one_shots2` with its own latch; `apply_frame` builds the second sample only when `_second_human()`; `_refresh_pads()` once per frame; `start_match` / `_adopt_session` assign `state.controlMode = Config.control_mode()`; `MATCH_START` prints `switch=<mode>`. |
| `godot/game/match_config.gd` | `Config.control_mode()`: the saved `controlMode`, validated against the reference's three (`js/main.js:2273`), `semi` for anything absent or unknown. |
| `godot/tests/input/switch_mode_audit.gd` | new: 79 checks (below). |
| `godot/tests/input/input_remap_a11y_audit.gd` | the free-button list and its comment corrected to Godot's numbering (F-8). |
| `godot/tests/input/run_all.gd` | the new audit joins the runner. |

## 3. The new audit: `switch_mode_audit.gd`, `PASS 79/79`

Six questions, all headless, none re-implementing a rule:

1. **The latch as a sequence**: fires at the 0.72 threshold and carries the stick's own direction; five held
   ticks fire nothing more; 0.5 keeps it armed; under 0.30 releases it; the next flick fires; **holding a shot
   button re-arms it** (`js/main.js:925`).
2. **The two sticks**: the 1.28 curve makes the middle of the stick deader than a straight line while full
   deflection still reaches 1; `shotAimAxis` keeps its sign and its 0.72 and clamps before curving.
3. **The gate through the real core** (`Sim.update_active_player`): a flick away from the partner switches
   nobody (alignment under 0.2, `js/game.js:657`); one towards him switches, with the reference's 0.55 s flash;
   a locked service reception refuses **both** the flick and the button; the button works once the lock clears.
4. **The preference**: `manual`, `assisted`, an unknown value and an absent key — the last two in `semi`, via a
   temporary save directory, not the real profile.
5. **Every pad binding against the physical button its own label names**, plus LT/RT as analog axes, plus an
   explicit "none of these four is on Godot's `back` button" for the ones that were.
6. **The device policy**: no pad selected before a frame asks for one; a pad that takes over holds its first
   press (no hit, no charge, no flick during possession); with no controller attached both samplers produce
   `Sim.empty_input()` field for field; the policy with nothing connected is a no-op, not a guess.

On floating point, because it nearly made this audit lie: Godot's `Vector2` is single precision, so
`Vector2(0.3, 0).length()` is `0.30000001192` — on the wrong side of a `<= 0.3` test. Thresholds are asserted
as constants; the sequences use values inside the bands.

## 4. Verification — every suite, before and after

| suite | before | after | verdict |
|---|---|---|---|
| `tests/input/run_all.gd` | `PASS 4/4`, 308 checks | **`PASS 5/5`, 387 checks**, not-ported 7 | green, one audit added |
| `tests/input/switch_mode_audit.gd` | — | **`PASS 79/79`** | new |
| `tests/audits/run_all.gd` | `PASS 10/10`, 221 checks | `PASS 10/10`, 221 checks, `mismatched=[]` | unchanged |
| project harness (main scene) | `PASS 8/8` | `PASS 8/8` | unchanged |
| `tests/modes/run_all.gd` | `PASS 6/6`, 3,603 checks | `PASS 6/6`, 3,603 checks | unchanged |
| `tests/game_slice_test.gd` (full) | `FAIL 277/278` | `FAIL 277/278` | unchanged — the one red is the gitignored `padel.pck` |
| `tests/game_slice_test.gd -- --demo` | `FAIL 222/227` | `FAIL 222/227` | unchanged — the same five, none new |
| `tests/athlete_stroke_bridge_test.gd` | `PASS 70/70` | `PASS 70/70` | unchanged |
| boot, `res://game/Match.tscn --quit-after 120 --models=0` | — | `MATCH_START … switch=semi`, **0 `SCRIPT ERROR`** | green |

One intermediate red, kept on the record because it is informative: after the `project.godot` correction the
remap audit failed `remap/padel_drive_accepts_a_pad_rebinding` — it had been using button **10** as a "free"
button, which the browser calls RB's neighbour and Godot calls RB. That is F-8; the fix is a correction to the
test's assumption, not a retreat from the change.

**The parity proof re-runs unchanged** — the same three digests as `match-parity.md`, byte for byte, which is
the check that the frozen core was not touched:

| scenario | sampled ticks | digest (JS and Godot) | verdict |
|---|--:|---|---|
| M1 plain, seed 12345 | 22,210 | `69a10a20…05d7` | `IDENTICAL`, events 254/254, mismatched 0 |
| M2 double fault, seed 999 | 12,813 | `c2cd281d…1f11` | `IDENTICAL`, events 186/186, mismatched 0 |
| M3 wall/glass + net cord, seed 11 | 16,858 | `6917dfdf…8619` | `IDENTICAL`, events 219/219, mismatched 0 |

Runtime read of the wiring, with the scene started headless:

```
$GODOT --headless --path godot/ res://game/Match.tscn --quit-after 120 -- --models=0
MATCH_START tier=rivale athlete=maestro arena=officina seed=20260916 camera=default models=false headless=true switch=semi
```

`switch=semi` is `Config.control_mode()` reading the real profile — the same call `start_match` assigns to
`state.controlMode`. A non-default value is asserted in the audit against a temporary save, not against the
owner's profile.

## 5. What this does NOT prove

- **No pad was attached during any of it.** `Input.get_connected_joypads()` was empty for every run, so every
  pad read in every suite was neutral. The bindings, the device policy and the possession rule are asserted as
  wiring; **whether the owner's Ace Gamer arrives as device 0 or 1 on macOS, and whether the feel is right, is
  a play-test** — and it is the first thing to do with a controller in hand.
- **The aim/movement change is not play-tested.** Aiming with the left stick while the athlete stops is the
  reference's behaviour as coded, and it changes how the game feels more than anything else in this document.
- **PvP and co-op still have two seats and no second human.** The second sampler, its latch and the seat-locking
  policy are in the frame path; two people on one machine is a play-test.
- **The switching mode has no UI.** The port now honours the saved value; nothing offers to change it (the
  reference has buttons, `js/main.js:2313`, `:2474`).
- **An editor is open on this project.** Godot rewrites `project.godot` when its settings change, so the
  corrected bindings should be confirmed under Project → Project Settings → Input Map after the next save.
- The demo slice's five reds and the music suite's two are **pre-existing** and unrelated; they were red before
  this change and are red in exactly the same places after it.

## 6. Deviations, declared

- **`flock` and `timeout` do not exist on macOS.** `godot/game/run.sh` and `tools/parity-godot/run-match-gd.sh`
  both pipe through them, so the documented entry points exit 127 with an empty stream — which the comparator
  reports as `NOT-COMPARABLE`, i.e. it looks like a divergence but is a missing binary. Every command above was
  run **directly**, with the lock and the timeout removed. On the mission's shared Linux host those wrappers are
  the whole safety story and this shortcut is not available.
- **Other Godot processes were alive during these runs**: the owner's editor (`--editor --path …/godot`) and a
  playable window on `res://game/Main.tscn`. The one-heavy-process rule was written for the 3.9 GB Linux host;
  on this machine the runs above are 2 s each and were taken anyway. The playable window runs the code as it was
  when it started, not this change.
- `tools/*/out/` is gitignored, so the parity artifacts written here never enter the tree.
