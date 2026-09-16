# Evidence: the quick-match slice — playable, localised, wired for sound

- Date: 2026-09-16 (built and measured this session; every number here was measured, none recalled)
- Ticket: `docs/implementation/tickets/quick-match-slice.md` (slice S2 of `docs/implementation/PLAN.md`)
- Artifacts: `godot/game/**`, `godot/tests/game_slice_test.gd`, this file
- Engine: `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`, `4.7.2.stable.official.ed1daf0bf`
- Host: 3,910 MB RAM, 0 swap, no GPU, **no sound device**. Every Godot process in this file ran
  under `flock -w 900 /tmp/padel-godot.lock`, one at a time, with `timeout` inside.
- Lanes this file integrates (both verified by their own owners, both read-only here):
  `godot/src/locale/**` (i18n lane, `tools/i18n-port/verify-i18n-port.mjs`) and
  `godot/src/audio/audio_port.gd` + `godot/assets/audio/**` (audio lane,
  `--script res://tests/audio_port_test.gd`, `PASS 15/15`).

## 0. Status in one line

**Playable, and now legible, localised and audible-by-construction.** A human can start the
menu, pick a tier and an athlete, play a quick match in 3D against the S1 deterministic core,
and see the tennis score, the energy bar, shot feedback, the point log and the result — with
every label resolved through the ported locale layer (0 raw message ids on screen, down from the
22 leaks the owner measured), with the ten contract sounds bound to the simulation's own events,
and with the six visual defects the owner listed repaired. `PASS 106/106` (was 62/62), engine
harness still `PASS 8/8`, `node tools/i18n-port/hud-coverage.mjs --fail-on-leak` exit 0.
**Not "done"**: no human verdict, no listening test (this host has no sound device), and the
frame's near-half framing stays a composition question for the owner (§7).

## 1. What exists

| Artifact | What it is |
|---|---|
| `godot/game/Main.tscn` + `main_menu.gd` | Main menu: play quick match, the four AI tiers from `AI_OPPONENTS`, the six athletes from `ATHLETES`, the arena and court-scale line, quit. Keyboard + pad + mouse. |
| `godot/game/Match.tscn` + `match_controller.gd` | The match scene. Owns one `SimState` from `Sim.create_match_state("quick", athlete, arena, tier, 0, {})`, steps it with `Sim.update_match(state, 1/120, input, input2)`, drives the 3D view, feeds the HUD, and drives sound. |
| `godot/game/court.gd` | Sim px → world mapping, court/net/glass/lines geometry, camera presets, the athlete rig, the racket object. |
| `godot/game/match_audio.gd` | **New this lane.** The only place message ids become sounds: the id → contract-sound table, the state-edge triggers for the sounds the sim stores no id for, and the request log/diagnostics the test reads back. |
| `godot/game/hud.gd` | The in-match HUD (Control nodes only). All text through the locale layer; the `EVENT_LABELS` block is generated. |
| `godot/game/tools/gen_hud_labels.py` | **New this lane.** Generates the `EVENT_LABELS` block of `hud.gd` from the locale projection + the debt ledger, with `--check`. |
| `godot/game/input_map.gd` | The 22-field input struct from the InputMap actions. |
| `godot/game/scripted_player.gd` | The deterministic stand-in for a human (test + capture only; the game's AI is in `src/sim`). |
| `godot/game/match_config.gd` | The menu's selection, static, survives the scene change. |
| `godot/game/run.sh` | Documented runner: `harness`, `test`, `play`, `play-xvfb`, `shots`, `all`. Honours the flock rule. |
| `godot/game/out/*.png` | Five 1280x720 captures (section 4). |
| `godot/tests/game_slice_test.gd` | The headless scripted playthrough, 106 checks in 11 groups (section 2.2). |
| `godot/game/tools/*` | `dump_input_events.gd`, `dump_ui_defaults.gd` (project.godot is written with strings the engine serialised, not hand-typed), `ready_probe.gd` (a measurement, §8), `inspect_png.py` (the blank-frame guard, reused as the frame sampler). |

The court, the net, the glass and the camera presets are the `godot/prototypes/arena_spike/`
ones, copied — not rebuilt. **Court scale: one uniform `PX_TO_M = 0.025` m/px**, which makes
`COURT` 800x508 px render as 20.000 x 12.700 m. The aspect question is *recorded, not
resolved*: 20:10 would need a different scale and stays Luca's call.

## 2. Exact commands, exit codes, key output lines

All run from `/root/projects/steam-circuit-padel-pro`.

**2.1 The harness must keep working — it does** (re-run after every edit made below):

```sh
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```
exit 0, last lines `ok float accumulator overshoots 120 steps (count integer ticks)` / `PASS 8/8`.
`run/main_scene` is still `res://tests/SmokeTest.tscn`; the game scenes are launched by explicit
scene argument.

**2.2 The headless scripted playthrough** (the 4.x `--script` form; verified, not assumed — an
`extends SceneTree` script is the main loop, so no `.tscn` wrapper is needed):

```sh
flock -w 900 /tmp/padel-godot.lock timeout 400 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/game_slice_test.gd
```
exit 0, `PASS 106/106`. Key lines, verbatim:

```text
# Godot 4.7.2-stable (official) · physics 120 Hz · slice S2 headless playthrough
# PLAYTHROUGH ticks=25962 crossings=174 points=24 max_rally=16 result={ "winner": "ai" } score=0-0 games={ "player": 0, "ai": 0 } sets={ "player": 0, "ai": 1 }
# AUDIO driver=Dummy requests=260 counts={ "serve": 24, "bounce": 33, "hit": 142, "wall": 33, "point-loss": 23, "net": 4, "defeat": 1 } by_source={ "ball.serveInFlight": 24, "evServeValid": 24, "ball.hitFlash": 142, "evWallValid": 33, "state.pointMessage:pointOpp:msgDoubleBounce": 19, "evSmashValid": 9, "state.pointMessage:pointOpp:msgSmashX3Wall": 1, "evNetRebound": 4, "state.pointMessage:pointOpp:msgNetFault": 3, "state.result:ai": 1 }
PASS 106/106
```

The 106 checks, grouped (each prints `ok <name>` or `FAIL <name>: expected <x>, got <y>`):

- **frozen inputs**: default athlete/arena are roster order 0, `COURT.left=80`, `COURT.bottom=564`,
  `SERVICE_LINE_OFFSET=126`, the scale is one uniform constant;
- **resources**: every resource the new scenes name resolves (both scenes, the scripts, the rigged GLB);
- **input**: every match control is a named InputMap action, every action has ≥1 event, every
  match control also carries a pad event, `ui_accept` carries a pad button, `menu_quit` exists,
  `padel_left` carries a key AND a stick axis;
- **the menu**: loads, instantiates fully, has the play button, offers 4 tiers + 6 athletes, the
  play button is wired to `start_match`, every choice is focus-navigable in all four directions,
  the match exposes `to_menu()` and `tick_fixed()`;
- **the match**: instantiates, owns a real state, `mode=quick`, `running=true`, the seed is injected,
  one `tick_fixed` call is exactly one sim tick, and it needs no engine clock;
- **no second physics path**: the controller's state is compared tick by tick (1,500 ticks)
  against an independently created state driven by a direct `Sim.update_match` loop — same
  input sequence, and `rng_state`, `rng_calls`, ball position and points must all match;
- **the locale layer** (§2.6, new): the resolver has the reference's two tables and 688 keys each;
  no id reaches the screen for any of the HUD's 94 labels; every resolvable label is *byte-equal*
  to what `Locale.t()` produces (the table is a projection of the locale layer, not a second copy);
  the composite ids resolve the way the reference resolves them; the dead
  `controlMsg:deep|mid|net` labels are gone; the ten ledgered ids get a readable line and the
  ledger is not shrunk; the shot grade/mode ids resolve to the reference's own words;
- **the audio mapping** (new): the contract's own anchors (`tools/audio-port/event-map.json`) hold
  for wall/net/bounce/special/point-win/point-loss, an id with no sound is silent rather than
  guessed, every target is a real contract event id, and the contract still offers exactly ten;
- **the rendered build's contract** (new, headless): the net is a lattice (≥40 children); all four
  glass panes exist, are tinted (alpha ≥ 0.2), unshaded and railed; every racket is racket-sized
  (0.26 m face, not the sim's 2.80 m contact box) and held within 0.9 m of its athlete at hand
  height; the debug panel cannot reach the scoreboard at 1152 px or 1280 px; no HUD panel leaves
  the frame;
- **the four tiers**: each constructs a match AND plays real points (tier 0/1/2/3, ≥6 net crossings each);
- **the full playthrough**: points scored, a real result inside the tick budget (25,962 of 400,000),
  the result names a real side, rallies occur (174 net crossings, longest rally 16 hits), the
  score display advances in the tennis sequence (one point per step, a game only at 4+ points
  with a 2-point margin, points reset on a game, a set counted on top, every displayed value in
  {0,15,30,40,AD}), a game never exceeds 5 raw points;
- **the event list** contains a serve, a bounce and a point; **the HUD** shows the sim's player
  score, ai score and game count, renders the sim's events, shows the result panel, its debug line
  names the seed and the tier, **no log line contains any message id**, and **the log never repeats
  a line twice in a row** (the echo the owner saw was an unresolved id, now impossible twice over);
- **the audio wiring at runtime** (§2.7, new): requests were accepted with no errors, a serve/hit/
  bounce/wall-or-net sound each occurred, the end of the match is exactly one match sound, every
  point but the last is a point sound (23 of 24), a voice was observed *playing* in the engine, and
  nothing was requested that the contract does not declare.

**2.3 The captures** (`run.sh shots` is these two commands plus `ls`):

```sh
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/Main.tscn -- --capture=menu
```
exit 0, `CAPTURE_SAVE err=0 path=res://game/out/menu.png size=1280x720`, `menu capture exit=0`.

```sh
flock -w 900 /tmp/padel-godot.lock timeout 420 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/Match.tscn -- \
  --capture=match --camera=default --tier=3 --seed=20260916
```
exit 0, `match capture exit=0`:

```text
MODELS rigged_glb=res://prototypes/arena_spike/assets/volpe-rigged.glb mesh_instances=1 copies=4
CAPTURE_SHOT name=quickmatch-serve.png tick=143 points=0 crossings=1 rally=0
CAPTURE_SHOT name=rally.png tick=420 points=0 crossings=3 rally=3
CAPTURE_SHOT name=hud.png tick=421 points=0 crossings=3 rally=3
CAPTURE_SHOT name=result.png tick=25962 points=24 crossings=174 rally=16
CAPTURE_DONE shots=4 ticks=25962 result={ "winner": "ai" } score=0-0 points=24
```

`xvfb-run` + `--rendering-driver opengl3` is the recipe proven in
`docs/wayfinder/evidence/character-material-render.md`; `--headless` writes a blank capture.
**Note the tick counts: 25,962 ticks / 24 points / 174 crossings / rally 16 — identical to the
headless run in 2.2, and identical to the run before this lane's changes.** The rendered path and
the headless path play the same match, which is what "one simulation, two clocks" means here. (The
`ERROR: Condition "status < 0" is true … init_output_device (drivers/alsa/audio_driver_alsa.cpp:97)`
line in the capture log is the host's missing sound device; Godot logs `All audio drivers failed,
falling back to the dummy driver` and renders anyway. Expected here, not a defect.)

**2.4 Blank-frame guard** (pure standard library; no numpy/PIL on this host):

```sh
python3 godot/game/tools/inspect_png.py godot/game/out/*.png
```
exit 0, one line per frame, `blank=no` on all five (values in §4). The same module is imported for
the pixel sampling in §2.8.

**2.5 The frozen web build was not touched.** `js/**` and `scripts/**` were read only, never
written; no audit script was run against them by this lane. `git status --porcelain` shows `??
godot/` — the Godot port is untracked in this repo — so nothing here can be mistaken for a change
to the frozen reference.

**2.6 The i18n gate: 22 leaks → 0, and the gate itself is proven non-vacuous**

```sh
node tools/i18n-port/hud-coverage.mjs --fail-on-leak
```
Before (the owner's measurement of the pre-existing HUD): **22 raw-id leaks, exit 1**. After:

```text
# godot/game/hud.gd — 94 hand-written event labels, sha256 862622e12c5c
# ids the sim can emit: 108 — 108 get a readable line, 0 print the id (or contain it)
```
exit 0. (The "before" number is quoted, not re-measured: `godot/game/hud.gd` is untracked, so the
old table is not recoverable from git, and this lane overwrote it.) So that the gate is not taken on
faith, a **negative control** was run — the value of one emitted id was temporarily set to the id
itself in `hud.gd` and the gate re-run:

```text
# ids the sim can emit: 108 — 107 get a readable line, 1 print the id (or contain it)
  RAW ID   evWallValid                        -> "evWallValid"
```
exit 1 — then the file was restored from a byte copy, `node tools/i18n-port/hud-coverage.mjs
--fail-on-leak` returned exit 0 again and `python3 godot/game/tools/gen_hud_labels.py --check`
returned exit 0, with `hud.gd`'s sha256 back at `862622e12c5c7261…`, unchanged from before the
control. The gate detects exactly the class of defect the owner reported, and nothing else changed.

**2.7 How the audio wiring is proven without a sound device**

`AudioServer.get_driver_name()` returns `Dummy` on this host (printed by the test:
`# AUDIO driver=Dummy`). No claim of a listening test is made anywhere. What is asserted:

- **the mapping, as data**, against the contract's own anchors — every `port.eventIdAnchors` entry
  in `tools/audio-port/event-map.json` resolves to the sound the contract names for it
  (`evWallValid`→wall; `evTape`/`evNetRebound`→net; `evServeValid`/`evSmashValid`→bounce; the six
  athlete ids→special; `pointYou…`→point-win; `pointOpp…`→point-loss), an id with no sound maps to
  `""` rather than a guess, and every target is checked to be one of the contract's own ids;
- **the module accepted every request**: `errors` is empty and `requests=260` for the playthrough —
  260 one-shots asked for, 0 rejected, none that the contract does not declare;
- **the events the match actually produced**, each attributed to the message id or state edge that
  caused it: 24 serves, 142 contacts, 33 floor bounces, 33 wall contacts, 4 net contacts, 23 point
  sounds, 1 match sound (`by_source` in §2.2);
- **engine state, not the call's return value**: after a request the module's own
  `AudioStreamPlayer.playing` is read back and observed true (the test asserts a non-empty
  `playing_probe`), and every count above is taken from the port's diagnostics *after*
  `play_event()` returned true. The module's `_ready()` builds the ten players and the buses — an
  unparented instance reports an **empty** contract, which this lane found the hard way and the test
  now parents around.

**2.8 Reading the frames as numbers** (how the "missing rear wall" was actually found). The pane
was there but opaque: `court.gd`'s `material()` took an `alpha` argument and only used it to switch
`TRANSPARENCY_ALPHA` on, never to set the albedo's alpha, so every "glass" surface was a solid lit
slab. Sampling a column of `rally.png` (via `inspect_png.read_png`) before the fix showed the pure
tint `(158,214,242)` — a fully opaque pane. After the fix:

```text
left-wall col x=200:  y=60 (28,38,51) bg   y=90 (33,42,54) bg   y=120 (98,126,150) glass   y=150 (98,126,150) glass
right/far  col x=1150: y=115 (255,255,255) frame rail            y=160 (103,130,153) glass over the surround
```
a ~+65 RGB step where the pane is, against the surround — visibly translucent, with the white frame
rail at full white. This is the one defect in the owner's list that reading the code would *not*
have found: the wall was drawn, in the wrong material.

## 3. Input model, stated exactly

- `_process(delta)` samples the input struct **once per rendered frame** and stores it.
- `_physics_process(delta)` runs **one tick** with that sample, at the project's fixed 120 Hz,
  and the one-shot fields (`hit`, `special`, `switchPlayer`, `switchDirection`, `smashUpgrade`,
  `cutVolley`, `globo`, `teamTactic`) are consumed by the first tick of the frame and absent
  from the next — the double-shot bug guarded by the comment at `js/main.js:1204-1206` cannot
  happen here.
- The browser accumulates in its render callback and runs up to `MAX_SIM_STEPS = 8`; the slice
  is driven by the engine's own fixed physics step, with the same `1/120` substep. The substep
  size — the property determinism depends on — is identical; the substep *count per frame* is the
  engine's, not a second accumulator. `MAX_SIM_STEPS` is declared and reported.
- One-shot semantics copied from the browser: the hit is queued on the **release** of the
  charge key (`js/main.js:2573-2580`), alt is the special, tab/z switch, the pad reads A drive,
  X slice (+RB vibora), Y lob (+RB defensive lob), B special, LB switch, LT split-step, RT
  sprint, RB technical, D-pad tactics `attack/defend/staggered/balanced`.
- The browser wires **no keyboard lob**; neither does this slice, deliberately.
- The harness path does not use the engine clock at all: `harness_mode()` switches the
  controller off and the test calls the same public `tick_fixed()` that `_physics_process`
  calls. One code path, two clocks.

## 4. Screenshots (1280x720 RGBA, software GL — correctness only)

`python3 godot/game/tools/inspect_png.py godot/game/out/*.png` → exit 0, `blank=no` on all five.

| File | Bytes | sha256 | distinct RGB | std | px ≠ modal | Shows |
|---|---|---|---|---|---|---|
| `godot/game/out/menu.png` | 139,782 | `faa85a420c1a489a30a5be3be60ce8512b8d4e80ded276a1ec9b4e7e7ae7154d` | 1,746 | 39.96 | 0.2790 | The main menu: title, the four tiers with their real skill/speed/power, the six athletes with their real stats, the arena + court-scale line, `GIOCA PARTITA RAPIDA` / `ESCI`, the seed, both control legends. **Byte-identical to the previous lane's capture** — this lane did not touch the menu. |
| `godot/game/out/quickmatch-serve.png` | 184,012 | `c58e2a8071cf1b27d89a54b6142cf31699e003e1a62a77c6187342fcc1f4da80` | 7,011 | 64.07 | 0.8299 | Tick 143, the scripted serve in flight: the court, the mesh net with its white tape, the four glass walls, four athletes each holding a racket, the ball past the net, the scoreboard, the log. |
| `godot/game/out/rally.png` | 208,444 | `ea810e7c5af2d4c3821483310a0e0a4f0caf6267579028bdf34e922a42316397` | 8,008 | 64.12 | 0.8278 | Tick 420, a 3-hit rally: `RALLY 3 colpi`, `PERFETTO`/`BILANCIATO`, the energy bar, and resolved log lines (`Controlli il giocatore di fondo.`, `Angolo cercato: il vetro laterale entra in gioco!`). |
| `godot/game/out/hud.png` | 208,245 | `321617b81bb878a84eda45562731b9e23ab80f32c2b23dcd5d988501cfdfc880` | 8,022 | 64.13 | 0.8277 | The HUD frame: feedback label, energy bar, five-line `CRONACA` event log, the seed/tier/tick line wrapped inside its bounded panel, the control hint. |
| `godot/game/out/result.png` | 209,529 | `dba93a3d5e4ea41665d0533ae310431d97e91b9128f9c56e035d1a5f8611e3a8` | 7,845 | 64.72 | 0.7754 | The end of the match (tick 25,962): the result panel, `Set 0-1`, `punti vinti 0-24`, longest rally, the log, all four athletes on court. |

Frame contents were checked by looking at the images and by sampling pixels, not inferred from
success codes. Compared with the frames the owner inspected, the changes are exactly the six
repairs in §5: the pink bars are gone (a racket is now a racket), no bar lies detached on the
court, the net has a mesh, the rear and side glass read as glass with white rails and frames, and
the top-left debug line no longer touches the scoreboard. The scene is otherwise the same scene:
same camera, same palette, same composition, same panel positions apart from defect 5.

## 5. The six defects: root cause and repair

| # | Owner's observation | Root cause (found, not guessed) | Repair |
|---|---|---|---|
| 1 | "Players' rackets render as huge pink rectangular bars that clip through the scene" | The view drew the sim's paddle **contact box** — `paddle.w` × `paddle.h` = 2.80 m × 0.50 m, the collision volume, not a racket — placed at the athlete's ground point. | `Court.make_racket_view()` builds a racket: a 0.26 m unshaded face + a rim + a grip, held at the hand. Asserted headless: face radius 0.13 m, within 0.9 m of its athlete, 0.6–1.6 m up. |
| 2 | "Two stray cyan bars lie on the court surface, unattached to any player" | The same contact box, for the two **near-side** athletes, whose bodies sit behind the bottom HUD panels: the box was wider than the hidden figure and read as a bar lying on the court. (Cyan is the colour the old code used for that pair.) | Same repair — a hand-sized object at the hand, attached to a visible arm/shoulder above the panel edge. Read back on the frame: *"the dark shape at the end of the figure's arm reads as a paddle/racket held in the hand. It is not lying separately on the court surface."* |
| 3 | "Rear/far glass walls are missing — only the side walls render" | `material()`'s `alpha` argument switched transparency mode on but never reached `albedo_color.a`, so **every** pane was an opaque lit slab; the rear pane was drawn the whole time, reading as a dark band. | `material()` now applies `alpha` to the albedo; `GlassFar`/`GlassNear`/`GlassLeft`/`GlassRight` are built by one `glass_wall()` helper (pane + top rail + posts, unshaded at alpha 0.22). Verified by pixel sampling (§2.8) and by eye. |
| 4 | "The net renders as a solid dark bar with no mesh" | The net was one `box()` of the net height, no mesh geometry. | A lattice: 25 strands + 3 horizontal cords at 0.046 m spacing + the white tape on top, between the two padded posts; asserted ≥40 children. The frame now shows *"a mesh with a white tape along the top"*. |
| 5 | "Top-left HUD text overlaps: the debug line collides with the athlete name" | The debug panel was bounded to 264 px, ending at x = 276 while the scoreboard starts at `W/2 - 360` = 280 at 1280 px — a 4 px margin that vanished at any narrower window (Godot's default is 1152 px, where it overlapped by 64 px). | The panel is bounded to 196 px (ends at 208) and the line wraps inside it; the test asserts no overlap at **both** 1152 px and 1280 px and that no panel leaves the frame. Read back on the frame: no overlap. |
| 6 | "The event log repeats the same entry" | The HUD's own table returned the raw id when it could not resolve one, so consecutive events printed the same string; the sim also stores the same id repeatedly (this seed's rally has `msgDoubleBounce` 19 times). | Every line is resolved through `locale.gd`; the test asserts no log line contains any of the HUD's 94 ids and no line repeats its predecessor. |

Kept and verified as the owner required: score (games/sets/rally), the energy bar, shot feedback
(`PERFETTO`/`BUONO`/`IN ANTICIPO`/`IN RITARDO` + `CONTROLLO`/`BILANCIATO`/`POTENZA`), the result
panel and the point log — all still on the frames, all asserted headless. No visual redesign was
done: same composition, same camera, same palette.

## 6. Camera, and what "provisional" means here

`--camera=default` (the arena_spike preset that solves the web build's opening composition:
position `(0, 14.4552, 6.4000)`, pitch `-65.2°`, fov `50.866°`) is the default, because
`PLAN.md` records the camera *start* as confirmed ("first build reproduces the current web
composition"). `--camera=playable` (behind the baseline) and `--camera=wide` are one argument
away. **Neither is Luca's framing verdict, and this file does not claim it.** Under this camera the
near baseline sits at ~98 % of frame height, so the two near-side athletes are cut at the waist by
the bottom HUD band (measured on `rally.png`: the panel edge crosses the near-left figure at waist
height; head, shoulders, arm and racket are above it). That is the browser's own composition and
therefore **left alone** — see §7.

## 7. What is NOT done (open list)

- **No human verdict.** Nothing here is Luca's look-and-feel or UI approval; the slice stays
  `built, evidenced, pending human verdicts`.
- **No listening test, and none claimed.** This host has no sound device (`driver=Dummy`). The
  audio evidence is mapping + request + engine-state assertions (§2.7); a human has to hear it.
- **No frame-rate claim of any kind.** All rendering here is Mesa llvmpipe software GL on a
  GPU-less host, valid for correctness screenshots and invalid for performance.
- **The near-half framing is open for the owner (art direction, not repaired here).** With the
  shipped camera the two near athletes are cut at the waist by the bottom HUD band. Fixing it means
  moving the camera or restructuring the bottom band — composition the owner froze — so the
  measurement is recorded instead of the change made.
- **The bottom HUD band's panels are not mutually disjoint.** At 1280 px the centred feedback panel
  spans x 340–940 while the log panel ends at 452 and the hint panel starts at 908: 112 px and 32 px
  of shared x, in the same y band and the same translucent style, so they read as one bar. Making
  them disjoint needs ≤376 px for the feedback panel (its energy row alone is ~560 px) or a
  different bottom layout — a layout decision, so it is listed, not taken. The overlap the owner
  actually flagged (debug line vs athlete name) is fixed and guarded by the test.
- **Not the HUD of S4.** This is the tracer-bullet HUD the ticket asks for (score, energy,
  feedback, log, result). It has not been through a human design/legibility review, only
  clipping/overflow/overlap/blankness checks.
- **Two shot-feedback words differ from the owner's expected list — and the frozen reference
  contradicts itself here.** The brief lists `IN ANTICIPO` / `IN RITARDO`; the shipped HUD shows
  `ANTICIPATO` / `RITARDATO`. The ported locale module is *right*: in `js/i18n.js` the `it` table
  (lines 2–698) defines `shotEarly` twice — `IN ANTICIPO` at line 171 and `ANTICIPATO` at line 552
  — and `shotLate` twice (`IN RITARDO` at 172, `RITARDATO` at 553); JavaScript keeps the **last**
  definition, so the browser's live string is `ANTICIPATO`/`RITARDATO`. Seven `shot*` keys are
  duplicated in that table and five agree; only those two differ. This lane routed the HUD through
  the verified locale layer and **did not hand-patch the two words** — a curated override belongs
  to the locale lane or to the owner's call, not to a presentation file (recorded, not taken).
- **The one open audio routing decision is a derivation, not an invention.** The contract records
  that "which port event id, if any, should carry each sfx sound is a presentation-layer decision
  that does not exist yet". This lane derived it from the reference: where the contract anchors an
  id, that id carries the sound (wall, net, bounce, special, point-win, point-loss); where the port
  stores no id at the trigger (serve, hit, victory, defeat), the edge is taken from the state field
  the reference's `sfx.*` call sits beside — `ball.serveInFlight` rising (`js/game.js:750`,
  `performServe`), `ball.hitFlash` rising (`hitBall`/`sfx.hit()`), and `state.result` being set (the
  contract itself calls `state.result` "the authoritative port signal"; `setToYou`/`setToCircuit`
  are deliberately **not** also routed, because routing both double-plays the end-of-match sound —
  asserted: exactly one match sound). Points are read from `state.pointMessage`, the id the sim
  stores at `sim.gd:2026` — the same statement whose JS twin plays the point sound at
  `js/game.js:2110-2111` — with the "a point happened" edge from `stats.pointsWon`, because that id
  never enters the events ring. Both are documented next to the code in `godot/game/match_audio.gd`.
- **No special shot is heard in this seed**, because the scripted player never presses the special
  key; the routing is unit-asserted and the runtime count is asserted to equal the emitted count
  (0 = 0) rather than assumed non-zero.
- **One arena, one format.** Quick match only, arena 0 by default (`--athlete=`/`--tier=` are
  arguments), `MATCH_FORMATS` untouched: the slice plays the sim's own default set. Career,
  tournament, drill, saves, Steam, touch/OSK and the other eight arenas are S3-S13.
- **No export/packaging.** Scenes are launched by explicit scene argument because
  `run/main_scene` must stay `res://tests/SmokeTest.tscn`.
- **The rigged athlete is one model, four copies, tinted by a floor ring.** The GLB has one baked
  texture and no proven garment zones (`character-material-render.md` §4), so the four athletes are
  not visually distinct beyond the ring and the racket colour. A known hole, not a hidden one.
- **Keyboard has no lob**, because the browser has none. `--capture=` and the scripted player
  produce the screenshots; a human has to play it for the feel verdict.
- **Gamepad input is mapped and asserted, not physically tested**: no pad is attached to this host.
- **`to_menu()`/`change_scene_to_file` is not exercised headlessly** (a scene change needs live
  frames); the test asserts the method exists and that the menu's play button is wired to
  `start_match`.
- **Other lanes' files were not edited**: `godot/src/locale/**`, `godot/src/audio/**`,
  `godot/assets/**`, `js/**`, `scripts/**`, `docs/mission/**` are read-only to this lane.

## 8. Findings worth keeping

- **The frozen reference has duplicate keys, and the later one wins.** `js/i18n.js`'s `it` table
  defines seven `shot*` keys twice (`shotEarly` is `IN ANTICIPO` at line 171 and `ANTICIPATO` at
  552; five of the seven duplicate pairs agree, `shotEarly`/`shotLate` do not). JS keeps the last,
  so the ported locale module's `ANTICIPATO`/`RITARDATO` is faithful — which is exactly why a
  "faithful" port can look wrong against a hand-written expectation. When a reference contradicts
  itself, the resolved runtime value is the only defensible target, and the contradiction is
  evidence for the owner rather than something to silently normalise.
- **A material's alpha can be a lie in two places.** `material()` switched `TRANSPARENCY_ALPHA` on
  but left `albedo_color.a` at 1.0, so four "glass" walls were solid slabs and the missing-wall
  verdict was really a wrong-material verdict. Read the rendered pixel, not only the code.
- **A simulation's `w`/`h` is not a drawing.** `paddle.w/h` is the contact box (2.80 × 0.50 m);
  rendered 1:1 it produced metre-wide bars. Presentation geometry must be derived, not reused.
- **The gate must be shown to fail.** The i18n coverage gate was run against a deliberately
  re-broken `hud.gd` (one value set to its own id): it printed `RAW ID evWallValid` with exit 1.
  Restoring the byte copy returned it to exit 0 with the same sha256. A green gate that cannot go
  red proves nothing.
- **Node `_ready()` does not run for nodes added during `SceneTree._initialize()`** in a `--script`
  run; it runs on the first frame. `godot/game/tools/ready_probe.gd` measured it (`a.ready=false`
  in `_initialize`, `true` at frame 1), and the slice test runs its checks inside `_process`
  because of it. A test written in `_initialize` silently tests an empty tree. The same trap bit the
  audio contract check: an `AudioPort.new()` that is never added to the tree has no players and
  reports an **empty** contract — the test parents it before asking.
- **Godot's default `ui_accept` and `ui_cancel` carry no joypad event** (its `ui_up/down/left/
  right` do carry the D-pad and the left stick). A pad-only player could move the menu focus and had
  nothing to press. `godot/project.godot` re-declares both as exact **supersets** of the engine's
  own events (A and Start for accept, B for cancel); every keycode event was taken out of
  `InputMap.action_get_events()` with `var_to_str`, none typed by hand and none removed.
- **A parse error in a scene script hangs rather than reddens** — the aborted scene never quits,
  and the run is only stopped by `timeout`. The ticket's "hang is a red" rule is real. (A typed
  parse error surfaced by the test runner is the cheaper failure: this lane's one parse error —
  `for width in [1152.0, 1280.0]` making the arithmetic Variant — was found and fixed in one run.)
- **Capture batch size matters on software GL.** Ticking 40 steps per drawn frame made the
  end-of-match capture take minutes; the finished plan ticks 4,000 per frame for the last shot. The
  batch changes how many ticks pass between two drawn frames, never the tick size — and the final
  tick count is identical to the headless run.
- **`godot/project.godot` is additive**: the `[application]`, `[physics]` and `[rendering]`
  sections are unchanged (same `run/main_scene`, same 120 Hz, same `gl_compatibility`) and a single
  `[input]` block was appended. Re-verified by running the harness, not by reading the diff:
  `PASS 8/8`, exit 0. Godot wrote `.uid` files next to the new scripts; they are engine-generated.
- **One heavy process across the mission.** Every Godot invocation here (harness, slice test, both
  captures) ran under `flock -w 900 /tmp/padel-godot.lock` with `timeout` inside, never two at once,
  on a 3,910 MB / 0-swap host shared with other lanes.

## 9. Files, sizes, hashes

`godot/game/**` (excluding the captures), `godot/tests/game_slice_test.gd` and the project file:

```
  17443  godot/game/court.gd              4827b14f4e7c0f9e3bf61386d91f04eaeb0d3471303bbbca2271b62296464b0a
  26251  godot/game/hud.gd                862622e12c5c7261e61789a04723f8d3e13ffbbdada5cebe5bae0a0e9c4ffd1c
   8094  godot/game/input_map.gd          cea098cc4387f90544ecad049fa4ad63caa1bb7c0408d0c9e62afba8af299b6e
   8655  godot/game/main_menu.gd          06d2cfe6cb13164545776414db0c985e7bc92a6916731043d9d467413c93f79d
  11966  godot/game/match_audio.gd        b713ab6f26cc9f3757e1431de80969471e33d46538b6d86bc702a07e9f008fe9
   1794  godot/game/match_config.gd       a52b3c46e3e6634aefafb00dff353ded07ecade94ff16dd367c04c75b1f6bf2b
  18413  godot/game/match_controller.gd   35738f7718b5ff6818f5f598ce74c48fd833b46f12c82f9b92b7bd9495c3ab1e
   2970  godot/game/scripted_player.gd    4077d2914de61ede0746f48c44693e12b688e3d8352f9d87f1a136e6cba308ce
    249  godot/game/Main.tscn             43c5dd2dad000186aecc2c8d3d9b24e9d146cbccbf383242ac6efaaa6487dc2f
    181  godot/game/Match.tscn            da485243c197db7d85d3e1b6c9e5ebe0cd71d3065f6235b397b098e8ece7b568
   4253  godot/game/run.sh                a81c6d6eb61125b13d5d8fd7e381afe4b1f311b47e14a89c0d3cab24768195db
  11124  godot/game/tools/gen_hud_labels.py    e73f56c3e6a1539c0f0f77c608696761b289967ddda5e2fdec8bf40d7cb72865
   3632  godot/game/tools/dump_input_events.gd 29415ae4a656cf4b434f2efdf30ffb58c811f84a8f010dcce9f42d6345aef9f4
   1256  godot/game/tools/dump_ui_defaults.gd  eb46db097216c4b60a093d65e424b94a9ae2ca01032eeff9aad219045a71bc54
    612  godot/game/tools/ready_probe.gd      ff549891ea8058e106dca78a4b8ab0af7af6e31f2b18542561933aecc028b13e
   4652  godot/game/tools/inspect_png.py     c6d3eb3790d55724e7c88ed1a9aec00a8b213b1422c34032e48ea34478862330
  36787  godot/tests/game_slice_test.gd     3a001d3cf42b6d3c71ffac1f5f8d6ea986cd3e7188a3b6332858a68fda2b58f4
  11783  godot/project.godot              0aa9ed50958c8931b9172e778f0d379504e061dd9e4b8a59c086e3f62b06f35a
```

Captures, 5 files, all 1280x720 RGBA (hashes also in §4):

```
 139782  godot/game/out/menu.png             faa85a420c1a489a30a5be3be60ce8512b8d4e80ded276a1ec9b4e7e7ae7154d
 184012  godot/game/out/quickmatch-serve.png c58e2a8071cf1b27d89a54b6142cf31699e003e1a62a77c6187342fcc1f4da80
 208444  godot/game/out/rally.png            ea810e7c5af2d4c3821483310a0e0a4f0caf6267579028bdf34e922a42316397
 208245  godot/game/out/hud.png              321617b81bb878a84eda45562731b9e23ab80f32c2b23dcd5d988501cfdfc880
 209529  godot/game/out/result.png           dba93a3d5e4ea41665d0533ae310431d97e91b9128f9c56e035d1a5f8611e3a8
```

Re-derive with
`sha256sum godot/game/*.gd godot/game/*.tscn godot/game/run.sh godot/game/tools/*.gd godot/game/tools/*.py godot/game/out/*.png godot/tests/game_slice_test.gd godot/project.godot`.

Changed by this lane (all inside `godot/game/**`, `godot/tests/game_slice_test.gd` and this file):
`court.gd` (racket object, net lattice, glass walls, material alpha), `hud.gd` (locale-routed
labels, bounded and named panels), `match_controller.gd` (racket views and placement, the audio
node, audio in `summary()`), `match_audio.gd` (new), `tools/gen_hud_labels.py` (new),
`tests/game_slice_test.gd` (+44 checks), this file. `main_menu.gd`, `input_map.gd`,
`scripted_player.gd`, `match_config.gd`, `run.sh`, `project.godot`, both `.tscn`s and `menu.png`
are untouched — their hashes above match the previous lane's evidence where that file recorded
them.

## 10. Blockers

None. Nothing in this slice is waiting on a failing gate; every gate named here is green and
reproducible from §2. The open items in §7 are human verdicts (Luca's framing/UI call), a sound
device to listen on, and two composition decisions the owner has reserved — all recorded, none
blocking.

---

## 11. Slice S6 — the nine arenas, and the two visual defects

Lane: `crew-arena` (integration owner for `godot/game/**`). Reference: the frozen browser build
(`js/` at `2979588`) — `js/data.js`'s `ARENAS` table (nine rows: `id`, `name`, `desc`, `image`,
`wallBounce`, `floorGrip`, `palette`) is the specification, `js/render.js` is the presentation
reference (`drawArena` at 694, `drawFantasyArenaBackdrop`, `drawLocomotiveDepotBackdrop`,
`drawClockworkFactoryBackdrop`, `clipArenaScenery` at 481). Nothing was invented: every colour,
every arena's scenery vocabulary and every distinguishing number is read from those two files, and
each arena's court floor is painted from its own `palette.floor`.

### 11.1 What was built

A data-driven arena library, `godot/game/arenas/**`, with one documented public API that the rest of
the game calls and nothing else in that directory needs to be imported:

```
ids() -> PackedStringArray          the nine frozen ids, in roster order
info(id) -> Dictionary              the frozen row, plus the presentation keys the library adds
build(id, preset) -> Node3D         a complete 3D environment; null for an unknown id
build_into(parent, id, preset)      the same, parented
```

| layer | file | role |
|---|---|---|
| data | `godot/game/arenas/arena_style.gd` | the nine arenas' presentation data only (family, sky stops, glow, apron, palette, scenery table, artwork name) |
| shared look | `godot/game/arenas/court_builder.gd` | world environment + lights, court surface and lines, net, the glass cage, and the small mesh/material primitives |
| per-arena | `godot/game/arenas/arena_scenery.gd` | each arena's backdrop and scenery objects, clipped to the band `clipArenaScenery` defines |
| API | `godot/game/arenas/arena_library.gd` | the four functions above; the only module `match_controller.gd` imports |

The nine arenas in 3D: `officina` (open: the reference's own `#51c6f4 -> #c8f1ff -> #f5a277 ->
#e57958` gradient with the clouds and trees it draws at 716-740), `locomotive` and `cattedrale`
(depot family), `clockwork` and `forgia` (factory family), and `tempesta`, `abissale`, `caldera`,
`orrery` (the four fantasy arenas, which composite their own painted artwork — the same four
`drawFantasyArenaBackdrop` returns true for — while the other five are drawn procedurally by the
reference and are drawn procedurally here). The four artwork files are copied verbatim from
`assets/arenas/` into `godot/game/arenas/art/` and the sha256 of each copy equals the source's.

`godot/game/court.gd` is now only what its name says: the pixel-space-to-3D mapping, the camera
builder and the athlete/racket rigs (the old `build_world`/`build_court` are thin forwarders to the
library, kept because the slice test and the tools call them). `match_controller.gd` gained
`add_arena(id)`, `set_arena(id)` (rebuilds the environment in place and re-syncs every view),
`arena_mesh_count()` and a `--capture=arenas` path that renders all nine in one engine process.

Arena selection is a row of nine buttons in `Main.tscn`'s menu, under the two existing columns,
each labelled with the frozen id, carrying the reference's own name key (`arena_<id>_name`, the key
`js/render.js:906` draws), the description and both frozen numbers in its tooltip. The row is
wired into the same explicit focus graph as the other rows (left/right walk the nine with wrap,
up returns to the tier column, down reaches the play button) and drives `match_config.gd`'s
`arena_index`, which the match scene reads. The five non-fantasy arenas also have their
`palette.floor` — the frozen table is the only source of arena data, field for field.

### 11.2 The two visual defects

**(a) the rear wall did not read as glass.** Root cause: one flat-alpha sheet, no pane edges, no
frame, and — behind it — nothing (the only thing above the court was the dark ground plane, which
is why the back of the court read as an open void). Repair: the rear wall is now six glass panes
with the reference's five dividers between them, a frame rail with a lighter "catching the light"
line along its top edge, a foot band, and *behind the glass* the arena's own backdrop — the sky
gradient plus the arena's scenery. The glass alpha is wired to the arena's frozen `wallBounce`
(`forgia` 0.83 -> 0.300 … `tempesta` 0.95 -> 0.460), so the more reactive an arena's wall is, the
more glass you read. The slice test asserts the object contract for all nine arenas (six panes,
split transparency, unshaded, dividers, rail, rail highlight, foot band, backdrop present and
covering the frame).

Measured, same columns (x 540..740, the centre of the back wall), mean RGB per screen row:

```
row   quickmatch-serve.png (before)        arena-officina.png (after)
 20   ( 20, 26, 38)  uniform, void          ( 44, 61, 73)  arena sky
 24   ( 20, 26, 38)                         ( 46, 61, 74)
 28   ( 20, 26, 38)                         ( 48, 62, 74)
 32   ( 62, 66, 74)  top edge               ( 25, 42, 63)  glass top rail
 36   (129,136,144)  max (237,242,250)      (103,114,129)  max (237,242,250)
 40   ( 77, 86, 98)                         ( 95, 95,101)  min ( 13, 29, 49)
 44   ( 85, 93,105)                         (102,102,108)  min ( 13, 29, 49)
 48   ( 78, 87, 99)                         ( 95, 95,101)  min ( 13, 30, 49)
 52   ( 28, 38, 51)  flat: no pane detail    ( 50, 48, 53)  min ( 13, 30, 49)
 56   ( 28, 38, 51)  (max 58,66,74)         ( 50, 47, 52)
 60   ( 28, 38, 51)                         ( 50, 47, 52)
 64   ( 28, 38, 51)                         ( 49, 46, 51)
 68   ( 72, 81, 93)  bright line            ( 87, 86, 92)  bright line
 80   ( 64, 73, 85)  bright line            ( 79, 79, 85)  bright line
```

Region means (rect x,y,w,h), before -> after:

```
above_rear_wall@400,6,480,26    ( 29.7, 34.4, 48.5) -> ( 62.2, 85.1, 99.3)   arena sky, not ground
rear_wall@400,60,480,50         ( 36.5, 45.4, 55.9) -> ( 43.6, 47.2, 53.5)
rear_glass_center@560,90,160,40 ( 45.6, 51.2, 54.7) -> ( 41.6, 48.4, 52.3)
```

The fantasy arenas are darker on purpose — their sky is the reference's own night gradient
(`#07142f` at the top) — and they show the same structure: `arena-tempesta.png`, rows 28/32 are
(10,14,26)/(25,42,63) and rows 52..64 run (28,39,52) … (20,32,45) with max (50,62,73), i.e. pane
and divider variation where the before frame was flat (28,38,51) with max (58,66,74).

**(b) a yellow/black arc clipped by the left screen edge.** Root cause: the object is not a HUD
widget at all — it is the Officina arena's gear ring, drawn as 3D scenery at a world x the old court
code did not bound, so it projected past the left edge and read as a clipped gauge. Repair: the
scenery is banded to the frame from the camera preset itself, and the slice test asserts that every
scenery object of every arena lands inside the frame (`|ndc| <= 1.0`) — not sampled by eye but
projected through the camera's own matrix.

Measured, region `left_edge_arc@0,300,36,80` (the strip the defect was visible in):

```
                            mean RGB              max RGB            yellow-gold pixels
quickmatch-serve.png (before) (106.1, 99.8, 72.1) (255,255,255)      747 / 2880  (25.9%)
arena-officina.png (after)    ( 61.2, 71.1, 93.8) ( 83,144,206)        0 / 2880
arena-tempesta.png  (after)   ( 56.5, 73.1,100.7) ( 83,144,206)        0 / 2880
```

and the gear is still drawn: 7,513 yellow-gold pixels in the whole `arena-officina.png` frame
against 2,855 before, with none of them at the edge.

**(c) the HUD, bounded.** Every panel is in `hud.gd`'s `_panels` list and `apply_safe_area()` shifts
(never resizes) each one back inside an 8 px safe margin, re-running on `size_changed`; a frame too
small to hold a panel is skipped rather than mis-clamped (in the harness the viewport is 64x64, and
clamping into it pushed the whole layout off the real frame — that is what the first run of the new
check caught). The bottom band was also re-composed: `FeedbackPanel` is 268 px wide with the energy
label above its bar, and `HintPanel` moved to the free strip on the right, because the log, the
feedback panel and the hint panel overlapped at 1152 px.

Panel rectangles at both sizes (from `godot/game/tools/hud_probe.gd`), frame 1280x720 / 1152x648:

```
ScorePanel     280..1000  10..135     LogPanel       12.. 432  538..710 / 466..638
FeedbackPanel  506.. 774 530..690     DebugPanel     12.. 208   10.. 49
HintPanel     1008..1268 148..261     ResultPanel   360.. 920  250..470
```

### 11.3 Commands, exit codes, key output lines

```bash
# 1. the project's own harness — unchanged, and still the main scene
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
#   exit 0 · "PASS 8/8" (8 ok lines: engine version, 120 Hz, float accumulator)

# 2. the slice test — 106 checks before this slice, 136 after
flock -w 900 /tmp/padel-godot.lock timeout 500 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/game_slice_test.gd
#   exit 0 · "PASS 136/136"
#   # MENU_FIT 1280x720 needs 1078x613   /  # MENU_FIT 1152x648 needs 1078x636
#   # REAR_GLASS_ALPHA forgia:0.83->0.300 abissale:0.84->0.313 clockwork:0.86->0.340
#     caldera:0.88->0.367 officina:0.89->0.380 locomotive:0.92->0.420 orrery:0.93->0.433
#     cattedrale:0.94->0.447 tempesta:0.95->0.460

# 3. build all nine headless and project every scenery object through the camera
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://game/tools/arena_probe.gd
#   exit 0 · "PROBE OK built=9 failed=0"

# 4. the HUD's panel rectangles at both frame sizes
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://game/tools/hud_probe.gd
#   exit 0 · one line per panel per frame (the table above)

# 5. the renders: the menu, and one frame per arena in ONE engine process
bash godot/game/run.sh shots-arenas
#   menu capture exit=0 · arena capture exit=0
#   ARENA_CAPTURE id=officina family=open wallBounce=0.89 rear_alpha=0.380 meshes=156 scenery=11 artwork=false
#   ARENA_CAPTURE id=locomotive family=locomotive wallBounce=0.92 rear_alpha=0.420 meshes=136 scenery=11 artwork=false
#   ARENA_CAPTURE id=clockwork family=clockwork wallBounce=0.86 rear_alpha=0.340 meshes=172 scenery=10 artwork=false
#   ARENA_CAPTURE id=cattedrale family=locomotive wallBounce=0.94 rear_alpha=0.447 meshes=144 scenery=10 artwork=false
#   ARENA_CAPTURE id=forgia family=clockwork wallBounce=0.83 rear_alpha=0.300 meshes=174 scenery=12 artwork=false
#   ARENA_CAPTURE id=tempesta family=fantasy wallBounce=0.95 rear_alpha=0.460 meshes=166 scenery=13 artwork=true
#   ARENA_CAPTURE id=abissale family=fantasy wallBounce=0.84 rear_alpha=0.313 meshes=138 scenery=13 artwork=true
#   ARENA_CAPTURE id=caldera family=fantasy wallBounce=0.88 rear_alpha=0.367 meshes=160 scenery=17 artwork=true
#   ARENA_CAPTURE id=orrery family=fantasy wallBounce=0.93 rear_alpha=0.433 meshes=156 scenery=15 artwork=true
#   ARENA_CAPTURE_DONE arenas=9 expected=9

# 6. blank-frame guard, and the pixel measurements quoted above
python3 godot/game/tools/inspect_png.py godot/game/out/arena-*.png godot/game/out/menu.png
#   exit 0 · every frame 1280x720, blank=no
python3 godot/game/tools/inspect_png.py --region=... --rows=rear_wall_band@540,740,20,110 \
  godot/game/out/quickmatch-serve.png godot/game/out/arena-officina.png godot/game/out/arena-tempesta.png
#   exit 0 · the region means and row profiles in 11.2
```

### 11.4 Renders: one per arena

All 1280x720 RGBA, software GL (correctness only), one engine process, same camera preset, same
tick — the only difference between two of these frames is the arena.

```
   189492  arena-abissale.png   877591fb7615af6b18a57c9bd41c052541aa828bbb46bde85835f460b3cb50d5  blank=no
   186052  arena-caldera.png    6ccd554cad5747aaa5edb7aa09227b0827238d99abc9311130cbae84bd40d4d7  blank=no
   187234  arena-cattedrale.png c127692a37e2738daf9e5953fc2a8188bc33e9992396508dadb3415d0bf8a9f5  blank=no
   187727  arena-clockwork.png  54a40ff1b7ec30ce8b0f3dd5b3f3f8f82b085f2a3d1fa880a63fda7893b6e309  blank=no
   186522  arena-forgia.png     e902b73280dabdbf5b87b0e400a21c690de56afba5fc971dd099993c3d7fc652  blank=no
   186609  arena-locomotive.png 6b881b7869c2228b599b7e8dec43fcd9a05250d121b3facba403d6c98056ac94  blank=no
   187269  arena-officina.png   5a2c1d996bdb4813d3a639d89edfb90205047bf49f7c4c844658872bbf1a4905  blank=no
   189636  arena-orrery.png     50ba703720a521dd4c490cd0ab76270ef1c573f1734fa84c869b7fc2b263879b  blank=no
   185282  arena-tempesta.png   c2de9ba07f856cad0418eec8b1b5585edc71274fab9a786e44088402c988fc4f  blank=no
   139765  menu.png             919a143d56b5fd57bc080db93731f7d2099c6dc4eb624f125057cc980382c461  blank=no
```

(In `godot/game/out/`.) Nine distinct sha256s, nine distinct colour counts (7,572–8,406 distinct
RGB values) and the same 82.19% of pixels away from the modal colour: the arenas differ while the
court, the cage and the HUD are common, which is the design. Read back visually as well: the back
of the court reads as a glass wall with white frame posts and the arena's own sky and scenery behind
it, no HUD panel overlaps another, and no element is cut by any edge — including the nine arena
labels, which are legible (`OFFICINA … ORRERY`). The first render of the arena row showed nine
unlabelled stubs (the buttons collapsed to their 8 px clip width); fixed in `main_menu.gd` and
re-rendered, see `menu.png` above.

### 11.5 New assertions (30, all green)

`tests/game_slice_test.gd`, 106 -> 136 checks:

* `_arena_library()` — the frozen table offers nine arenas; the library's ids are the table's, in
  order; the default is roster order 0; all nine build a non-empty environment (>= 60 meshes);
  each builds its own scenery behind the rear glass (one node per prop of its own table); arena
  data equals the frozen row field for field (`name`, `desc`, `image`, `wallBounce`, `floorGrip`);
  every arena's ground is painted from its own palette; the nine signatures are distinct; the
  scenery vocabulary differs between arenas (>= 12 kinds); the glass alpha is monotone in
  `wallBounce`; an unknown id does not build; the reference's own gradient stops and glow colour are
  in the tables; the four arenas with their own reference artwork are the four that load it, the
  files are on disk, and the artwork decodes at runtime and reaches the backdrop.
* `_arena_scenery_in_frame()` — every scenery object of every arena is fully inside the 1280x720
  frame (projected through the camera's own matrix); every arena's backdrop covers the frame above
  and behind the rear glass; the rear wall is six panes with dividers, a lit rail and a foot band in
  every arena.
* `_hud_safe_area()` — no HUD panel leaves the frame and no two overlap at 1280x720 or 1152x648;
  the runtime safe-area pass really does bound panels (measured on a deliberately cramped 640x360
  frame).
* `_arena_library()` also closes the loop end to end: an arena picked in the config is the arena
  the real match scene builds *and* the arena the simulation runs on (`state.arena`), checked for
  two different ids so a silent fallback to the default arena cannot pass.
* `_menu_reaches_match()` — extended: the menu's choice count now includes the nine arena buttons
  (exact count), one button per arena id found by name, distinct labels, every button selects its
  own arena through `match_config`, and the menu's measured height fits both frame sizes.

The existing checks are untouched except where the menu legitimately grew a row (the toggle-count
expectation) and the arena/glass node lookups, which now walk the tree by name because the
environment is a child of the match rather than a flat scene.

### 11.6 Files, sizes, hashes

```
 13979  454a6465a8b52e3a…  godot/game/arenas/arena_style.gd      (new)
 16922  2ab08843092b671f…  godot/game/arenas/court_builder.gd    (new)
 22022  0cbdba0f32e89fb5…  godot/game/arenas/arena_scenery.gd    (new)
  6382  f50f4fa5eeef7097…  godot/game/arenas/arena_library.gd    (new)
 12121  598938cc97d66d6b…  godot/game/court.gd                   (rewritten)
  2700  9669d04938019a86…  godot/game/match_config.gd            (arena_ids, set_arena_id)
 22298  1035e510a2de5f72…  godot/game/match_controller.gd        (arena library, set_arena, --capture=arenas)
 30006  25669f88a55598e4…  godot/game/hud.gd                     (safe area, bottom band)
 12789  67a76423457ad535…  godot/game/main_menu.gd               (arena row)
  5674  61d054585051f342…  godot/game/run.sh                     (shots-arenas)
  5062  1cfbc331ce0aa4aa…  godot/game/tools/arena_probe.gd       (new)
  3842  12fcc51c650a8651…  godot/game/tools/hud_probe.gd         (new)
  8313  9b69080974185641…  godot/game/tools/inspect_png.py       (--region, --rows)
 58412  22ac70d68952ad3e…  godot/tests/game_slice_test.gd        (+30 checks)
```

Artwork copies (`godot/game/arenas/art/`), each sha256 equal to its source in `assets/arenas/`:

```
bastione-tempesta.webp    0c6b652677d708b9dc5abd1597cae656324aab1a7ae80a363331be04feb9f131
caldera-titano.webp       b03dfd17c6644346dbc137e1840f87e67e83eb2e72f283277561e35ec8b34edf
orrery-celeste.webp       421af9a27f57771b81626e31e74a080d74d5955f31f9cf371f7e361d58c24caa
santuario-abissale.webp   71e57162d8f941a7970bb7b33deaab4ab5e3072747ea39a15586e0074ae80271
```

(The sizes and hashes for `main_menu.gd` and `tests/game_slice_test.gd` in §9 are the previous
lane's — the table above is what is on disk now.)

Re-derive with
`sha256sum godot/game/*.gd godot/game/arenas/*.gd godot/game/arenas/art/* godot/game/tools/*.gd
godot/game/tools/*.py godot/game/run.sh godot/tests/game_slice_test.gd godot/game/out/*.png`.

Nothing outside `godot/game/**`, `godot/tests/game_slice_test.gd` and this file was written;
`godot/project.godot`, `js/**`, `godot/src/**`, `godot/assets/**` and the other lanes' files are
untouched, `run/main_scene` is still `res://tests/SmokeTest.tscn`, and nothing was committed.

### 11.7 What is NOT done (added to §7's list)

* **Arena scenery and the scoreboard overlap by composition, not by bug.** The arena's upper scenery
  (the Officina's gear rings sit at 0.80–0.92 of the frame's height) is drawn behind the translucent
  scoreboard banner (rows 10–135, 0.78 alpha). The frame-edge contract holds — nothing is *cut*, it
  is covered — but whether the band's props should be biased towards the lower half of the band is
  an owner composition call, not mine to make.
* **The five non-fantasy arenas do not composite their `.webp`.** Not a missing asset: the reference
  itself draws those five procedurally (`drawLocomotiveDepotBackdrop`, `drawClockworkFactoryBackdrop`
  and the open scene's gradient) and composites `arena.image` only for the four fantasy arenas, which
  is exactly what this port does. If the intent was ever to use all nine images, that is a reference
  decision.
* **No per-arena audio or per-arena wall-bounce audio cue.** The audio contract is unchanged and
  still wired to the sim's own events; `wallBounce` is presentation-only in this slice, which is what
  the frozen data says it is.
* **Frame-rate is not measured anywhere here.** These are software-GL correctness renders.
* **The near-half framing (athletes cut at the waist by the bottom HUD band) is untouched**, as
  instructed. The band's top edge did not move: it is still the bottom-left log panel's top
  (`H-182`). The feedback panel's own top moved 22 px up as a side effect of stacking its energy
  label above its bar, and it now ends 35 px above the frame's bottom instead of 32.

### 11.8 Scope, and how it was verified

`git status --porcelain` cannot show this lane's footprint file by file: `godot/` is untracked in
this repository (`?? godot/`), so nothing under it has a tracked baseline. Scope was verified by
construction and by the engine's own state instead — only `godot/game/**`,
`godot/tests/game_slice_test.gd` and this file were written here, and `godot/project.godot:10` still
reads `run/main_scene="res://tests/SmokeTest.tscn"`, which the harness run in 11.3 loaded (its 8
checks are the proof that it did).

One side effect worth recording, because several lanes share this working tree: the engine's project
scan writes `.uid` sidecars next to other lanes' new scripts whenever the mandated harness command
runs, so recent `.uid` files under `godot/src/**` are that, not edits from this lane. Nothing was
committed, pushed or deployed, and no paid service was called.

---

# 12. The interrupted integration lane, finished and greened — crew-integrate-2

This section is appended by the continuation lane that finished the integration work the harness killed
mid-flight. Nothing above is rewritten. The lane inherited an approximately 95 %-done working tree,
verified every claim on disk before trusting it, and then closed the four things that were still open:
the one red check, the three HIGH review fixes (proved by test, not by reading), the two audit-runner
false-green generators, and the remaining slice items. §12.1 states what was inherited; §12.11 states
what is NOT done.

## 12.1 What was inherited, and what was verified before it was trusted

| Claim | Verified how | Result |
|---|---|---|
| `game_slice_test.gd` is red on exactly one check | ran it, locked | `FAIL 130/131`, the red being `tier and athlete choices are focus-navigable (keyboard + pad)` at `game_slice_test.gd:269` |
| engine harness green | ran it | `PASS 8/8`, exit 0 |
| 782-line evidence file with no section for this lane | `wc -l` | 782 lines, §11 was the last section |
| the three HIGH fixes are IN the tree | read, then TESTED | all three were present; one of them (H-2) was only half-done — see §12.4 |

Everything below is the state of the working tree as it stands now, not of the dead lane's intentions.

## 12.2 The gate itself was a false-green generator, and it was fixed first

The first full run of the inherited suite printed `PASS 209/209, exit 0` **while the log contained**

```
SCRIPT ERROR: Invalid type in function 'step' in base 'RefCounted (drill_session.gd)'.
              Cannot convert argument 2 from Nil to Dictionary.
```

A GDScript runtime error aborts only the function it happens in, Godot keeps running, and the suite
prints its green line anyway — the same class of defect the independent review raised as M-4 about the
audit runner. Two things were done about it, both required:

1. **The cause.** The drill screen (`godot/game/mode_screen.gd`) drove the real `DrillSession` with
   `step(1.0 / 120.0, null)`. `DrillSession.step(dt, input: Dictionary)` is another lane's API
   (`godot/src/modes/drill_session.gd:257`) and is not this lane's to change, so the CALL SITE was
   fixed: the first frame carries the player's press (`{"hit": true}`, leaving the `ready` phase), the
   rest carry `{}`. The screen now reports a live session:
   `# MODE_SCREEN drill locked=false rows=4 reachable=4 focus=drill:precision detail=SESSIONE fase live · round 0 · tentativi 0 · punti 0 · target {"active":true,…}`.

2. **The gate.** `godot/game/check_log.sh` (new) fails a suite on any `SCRIPT ERROR` line, on any
   engine `ERROR:` line that is not a named+counted allowance, on a non-zero exit code, on a missing
   `PASS` line, and on `FAIL` lines beyond the expected count. `SCRIPT ERROR` is never allowed.
   Two `ERROR:` allowances are named and counted, each with its reason in the script's own header:
   `arena_library`'s deliberate caller-bug guard (provoked on purpose by the test) and the engine's
   `ERROR: n resources still in use at exit` line (§12.2.1).
   `godot/tests/game_slice_test.gd` also gained the two guards the review asked for in M-1: nineteen
   named sections that each report completion (`# sections ran 19/19`, and a missing entry is a FAIL),
   and an object-count check (`# OBJECTS start=1550 end=1945 delta=395 nodes=1 orphans=0 resources=56`)
   so a run that leaves objects behind is a red check rather than a line in the log.

### 12.2.1 The engine's exit-time line, measured rather than waved through

`ERROR: 7 resources still in use at exit` appears in some slice-test runs and not others (absent in 4
of 7 runs, including both `--verbose` runs). The measurement that locates it:

* at the end of a run the test's own footprint is **1 node, 0 orphan nodes** (printed every run), so
  the test does not accumulate Nodes;
* a `static var` holding a `Resource` outlives the scene tree, and the port has exactly one such
  cache: `godot/src/character/outfit_catalogue.gd:95` (`static var _shader: Shader = null`). That file
  belongs to the character slice and is **outside this lane's write scope**, so it is reported here
  rather than edited.

The gate therefore allows that one line, once, by name. It is the only allowance besides the arena
guard, and both are in the gate's own source with their rationale.

### 12.2.2 The two audit-runner false-green generators (review M-4)

| Where | Before | After |
|---|---|---|
| `godot/src/audits/audit_base.gd` `finish()` | `checks == 0` was a pass: an audit that aborted before its first assertion printed green | `checks == 0` is a FAILURE that names the audit (`FAIL <audit>: 0 checks ran — the audit aborted before its first assertion`), `failures == 0` is the pass, `not_ported` stays a recorded gap |
| `godot/tests/audits/run_all.gd` | the summary line was `PASS %d/%d % [AUDITS.size(), AUDITS.size()]` — a constant | the summary is the accumulated result (`passed` over the ten), each audit's check count is pinned per name, and a count that moves in either direction fails that audit |

The second one is shown working, not asserted: the inherited `EXPECTED_CHECKS` table carried the right
total (221) with eight of its ten per-name counts permuted (it is the same list as the review's M-4
row, which is where it came from). With the table as inherited the aggregate was **RED**: `FAIL
controller_tactics: ran 14 checks, expected 22 (a skipped or dead section)`, `FAIL 2/10`, exit 1. Each
audit was then re-measured from its own `ok <name> (<n> checks)` line and the table corrected
(`controller_tactics` 14, `match_format` 26, `wall_rules` 22, `court_speed` 25, `shot_quality` 13,
`smash_input` 24, `lineup` 23, `ai_attack` 16, `difficulty` 35, `shot_balance` 23 — sum 221, unchanged
`EXPECTED_TOTAL`). The change is itself the demonstration: a table that does not match the audits now
fails the run instead of printing `PASS 10/10`.

`godot/tests/build/audit_base_abort_probe.gd` (new) is the smallest thing that can go red for the
first generator, and it is a run of its own:

```
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/build/audit_base_abort_probe.gd
```

The probe drives `AuditBase` through four states — 0 checks, a failed check, a healthy check, a
`not_ported` gap — and requires `finish()` to return 1, 1, 0, 0 respectively. Observed:
`PASS 6/6`, exit 0, with the two `FAIL …` lines the failure cases write to stderr by design.

## 12.3 The red check, greened — and the defect it was hiding

The failing check asked whether the nine arena rows, six athlete rows and four tier rows of the menu
can be reached by keyboard and pad. The dead lane's version asked the verified focus model
(`godot/game/menu_focus.gd` -> `godot/src/input/**`) for its reachable ids and got a list that left
rows out. Wiring was not the problem. The model was reasoning about **the pre-layout rectangles**:

```
# MENU_FRAME root=(64, 64) host=(1280.0, 720.0) menu=[P: (0.0, 0.0), S: (1280.0, 720.0)]
# MENU_FOCUS_ROW tier:0 rect=0,0 430x31        <- every row at the origin
# MENU_FOCUS_ROW arena:officina rect=0,0 449x31
```

`main_menu.gd` refreshes the model in `_ready()`, and a `Container` places its children only at the
END of the frame that builds them, so every target was measured at `(0,0)`. With all centres equal,
the model's "is there anything to my right/down" test was answering from font widths: with every centre
at the same point, whether a row counted as reachable depended on whether its minimum width differed
from its neighbour's by more than the model's tolerance, so rows fell out of the navigation order for a
reason that has nothing to do with navigation. The failing check's own message listed the rows the model
could not reach.

**The fix is in the screen, not in the assertion:** `main_menu.gd` now re-measures the focus model when
its column's laid-out size changes (`_process`, one refresh per layout change — which also covers a
window resize) instead of only once in `_ready()`. `godot/game/menu_focus.gd` gained `focus_node()`,
`focus_id()` and `reset_focus()` (`ensureMenuFocus` after a rebuild), so a caller — and the test — can
ask the model where the focus is and put it back on its first target.

Before and after, same log line:

```
before:  # MENU_FOCUS_ROW tier:0 rect=0,0 430x31 / arena:officina rect=0,0 449x31  (every row at the origin)
after:   # MENU_FOCUS targets=25 reachable=25 rows=19 granted=19 locked=0 focus=arena:orrery
         # MENU_FRAME root=(64, 64) host=(1280.0, 720.0) menu=[P: (0.0, 0.0), S: (1280.0, 720.0)]
```

The check that now holds is not "the labels are wired" but, in the four halves the model itself can
answer: every granted row is **registered**, **focusable**, **reachable** by BFS over the model's own
up/down/left/right, and every row the build **locks** is focusable by neither route. The test also
asserts that the screen — not the test — handed the model its geometry: the model's own cached
rectangles cover `N` distinct places for `N` targets, and the origin is not among them. A keyboard
`KEY_DOWN` through `MenuFocus.handle_key()` and a pad direction frame through `MenuFocus.step_pad()`
each move the focus, and what the model focuses is a real, visible `Control` on the menu.

## 12.4 The three HIGH fixes, each proved by a test

### H-2 — the fixed 120 Hz timestep, driven by rendered frames

The review's finding: `_physics_process` ticked only when `_process` had set a fresh frame flag, so the
simulation advanced **one tick per rendered frame** (60 ticks/s at 60 fps), and the browser's
accumulator (`simAccumulator = Math.min(accum + dt, FIXED_STEP * MAX_SIM_STEPS)`, `js/main.js:1196-1205`)
was not implemented. Half of the fix was inherited (an accumulator existed); the other half was not —
`_physics_process` was still the only clock. It is gone. `_process` samples input and calls
`apply_frame(delta)`, which drives the accumulator; `MAX_SIM_STEPS` clamps a long frame, and the
largest frame step is reported.

The test feeds the real controller three artificial frame patterns for the SAME wall second — 30 fps
(30 frames of 1/30), 60 fps, 240 fps — and requires the reference's fixed-step count from each:

```
# FRAME_CLOCK 30fps=120 60fps=120 240fps=120 (one wall second each)
ok the controller defines no `_physics_process` — the frame loop is the only clock
ok the frame entry point is public, so this test drives the real loop
ok one tick_fixed call is one sim tick
ok 60 fps: one wall second is the reference's 120 fixed ticks (not 60 frames)
ok 30 fps: the same wall second is the same 120 fixed ticks (not 30 frames)
ok 240 fps: the same wall second is the same 120 fixed ticks (not 240 frames)
```

The failure mode the review described (one tick per rendered frame) would give 30, 60 and 240; the
reference's answer is 120 for all three.

### H-3 — input edges that survive a fast render frame

The review's finding: `_process` overwrote the frame input on every rendered frame, so a one-shot that
exists on exactly one frame was lost whenever the render rate exceeded the tick rate. The fix keeps
the browser's shape: a press is **latched** and stays latched until a sub-step spends it
(`hitQueued`/`specialQueued`, `js/main.js:2573-2580`). The test delivers a press and a release inside
ONE rendered frame — the frame no sub-step runs — and then a full-step frame, and asserts the tick the
press reaches still sees it:

```
ok a half-step frame runs no sub-step
ok the press is latched while no sub-step has spent it
ok the frame that spends it runs exactly one sub-step
ok the shot still fires: the tick sees the PRESS, not the release (H-3)
ok ... and the special with it
ok a full-step frame spends the press in that same frame
ok ... and it is not left armed for the next frame
```

### H-1 — the packed athlete path

The review's finding: the only athlete-model loader pointed at `res://prototypes/arena_spike/assets/volpe-rigged.glb`,
and every export preset excludes `res://prototypes/*`, so the shipped build drew four capsule fallbacks
and no test noticed (`ResourceLoader.exists()` is true in the editor). The path was moved to
`res://assets/athletes/volpe-rigged.glb` (`godot/game/court.gd:105`) and the work is now guarded three
ways, none of which is `exists()`:

* a scan of every `res://` literal in `godot/game/**` and `godot/src/**` against the presets' **own**
  `exclude_filter`, read out of `godot/export_presets.cfg` at run time (a preset that starts excluding a
  new tree fails this suite rather than a copy of the list being updated);
* the athlete scene and both rig GLBs checked against the exclusion patterns;
* the real artifacts: the shipping pack and the demo pack are opened and searched byte by byte for the
  athlete scene path ("resolves inside a real pack" is a claim about the artifact).

```
ok no `res://` path in game/** or src/** lives in a tree the exporters exclude
ok the athlete scene the match loads is inside a packed tree
ok the rig factory's GLB_BASE is the same path the court falls back to
ok every GLB the rig loads is inside a packed tree
ok the athlete scene is INSIDE res://build/linux-x86_64/padel.pck (the packaged build can draw the rigs)
ok no excluded tree is inside res://build/linux-x86_64/padel.pck
ok the demo pack carries the athlete scene too
```

## 12.5 Athletes on court, through the roster the menu chose

The match builds its four athletes through `godot/src/character/athlete_spawn.gd`, with the lineup
(`godot/game/lineup.gd`) resolved from the menu's athlete selection and the outfits from the catalogue.
The measured report, one line per run, names the athlete, the outfit, the material anchors and the
joints — this is the roster-and-outfit path the brief asked for, end to end:

```
ATHLETES rigs=4 source=res://assets/athletes/volpe-rigged.glb glb_loads=12 spawn_ms=3503
  lineup={"opponent":"steamer","opponentMate":"fiamma","player":"maestro","playerMate":"pantera"}
ATHLETES rigs=4 load_errors=0 glb_loads=12 report={... "Rig_player" athlete_id=maestro outfit_id=base
  joints=24 triangles=31325 material_class=ShaderMaterial shader_path=res://src/character/outfit_recolour.gdshader ...}
```

Each rig is checked to be at its court position, upright, and holding its racket within a metre of the
athlete at hand height (`global_position` deltas, because the racket is a child of the rig and its
`position` is local).

## 12.6 The demo rule, ON SCREEN — the two captures, compared

The previous pair of captures was byte-identical, which is how the defect was found. Both captures
below are rendered by the same code, on the same host, at the same resolution, differing only in the
build flag; the command is the one in `godot/game/run.sh` (windowed, `xvfb-run` + software GL, because
plain `--headless` produces blank frames):

```
flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/Main.tscn -- --capture=menu --out=menu-full
# ... and the same command with `--demo` appended and --out=menu-demo
```

| | full build | demo build (`--demo`) |
|---|---|---|
| file | `godot/game/out/menu-full.png` | `godot/game/out/menu-demo.png` |
| bytes | 137,938 | 119,601 |
| sha256 | `5d5dd6c256e1cb6bb93478adfdbc03457512fedf5ff325163d2d817502cc8619` | `a855d99589c489878239dd26fd2d41343511b0c920b72868f5d452b41f5bab38` |
| on-screen arenas | all nine | `["CLOCKWORK"]` |
| on-screen athletes | six | two (`athlete:0`, `athlete:2` — maestro and steamer) |
| tiers shown / enabled | 4 / 4 | 4 / 1 (index 1, the demo's pinned `medium`) |
| modes | TRAINING, CHAMPIONSHIP TOURNAMENT, CAREER — all enabled | all three `disabled`, text `"… — In the full game"` |
| focusable ids | 25 | 7 |

The two files are not identical, and the difference is measured rather than eyeballed:

```
identical files: False
frames: (1280, 720) (1280, 720)
differing pixels: 281168 of 921600 (30.51%), bbox=(46, 85, 1232, 588)
```

The on-screen counts above come from the `MENU_ON_SCREEN` line the screen prints from its own built
widget tree in each run, so "the demo rule is enforced on screen" is asserted on the screen's state,
not on the gate's answer:

```
full: MENU_ON_SCREEN {"arenas":["OFFICINA",…,"ORRERY"],"athletes":["IL","LA","LO","LA","L'ORACOLO","IL"],
        "build":"full","focus":"tier:0","tiers_enabled":[0,1,2,3],"tiers_shown":4, …}
demo: MENU_ON_SCREEN {"arenas":["CLOCKWORK"],"athletes":["IL","LO"],"build":"demo","focus":"tier:1",
        "tiers_enabled":[1],"tiers_shown":4,"modes":[{"disabled":true,…},…], …}
```

The same rule is asserted inside the suite as well (two athletes, one arena, one enabled tier, exactly
three tiers shown locked, no locked mode focusable), in both build variants.

The exported binaries are not re-exported by this lane, and the reason is a fact rather than a budget
choice: `--capture` writes to `res://game/out/<name>.png`, and inside an exported build `res://` is the
pack file, so a capture cannot be written from the exported binary at all. The demo rule's
inside-the-export proof already exists and is cited, not repeated: the S12 slice ran
`padel-demo-selfcheck.x86_64 --headless` → `PASS 18/18`, the built thing asserting its own content rule
(`docs/wayfinder/evidence/demo-and-export.md` §4).

## 12.7 The three mode screens

`godot/game/mode_screen.gd` + `godot/game/ModeScreen.tscn` (both new) are the first real screens on top
of `godot/src/modes/**`: every row is read from that directory's public API — the four drill exercises
from `ModeTables.drill_exercises()`, the three tournament rounds from `TournamentRules.path()`, the
career fixture, season objectives and progression constants from `CareerRules`/`CareerProgress`. The
drill screen runs a **real** `DrillSession` (created with the menu's athlete, arena and lineup) and
shows its live phase, round, attempts, points and target. Navigation is the same verified focus model
the menu uses, and the screen declares the reference's own return: `NavRoutes.back_action("screen-modes")`
→ `to-menu`, so ESC and the pad's back go through `MenuFocus.back()`.

```
# MODE_SCREEN drill      locked=false rows=4 reachable=4 focus=drill:precision     (SESSIONE fase live …)
# MODE_SCREEN tournament locked=false rows=3 reachable=3 focus=tournament:round0
# MODE_SCREEN career     locked=false rows=5 reachable=5 focus=career:fixture
```

In a demo build the gate answers `modes() -> ["quick"]`, so tournament and career render the
reference's own locked line instead of rows (`locked=true`, `rows=0`), and `drill` is deliberately NOT
locked — the reference's demo rule enumerates modes and says nothing about drill, which the menu
reaches (`to-drill`) in either build. That asymmetry is asserted per mode, with the reason in the code.

## 12.8 The per-arena check against the reference's own spec

Each arena's painted treatment is compared against `js/render.js` **read at run time** (the four fantasy
gradient stops and glow colours are parsed out of `drawFantasyArenaBackdrop`'s `themes` block,
`js/render.js:500-506`), and the port's own `family` classification is cross-checked against the
reference's table:

| arena | family | port sky | port glow | reference | deviation |
|---|---|---|---|---|---|
| officina | open | `#51c6f4` → `#e57958` | `#7fd4ff` | none | n/a (family backdrop reads no arena data, `js/render.js:697-701`) |
| locomotive | locomotive | `#071526` → `#37444d` | `#78c9da` | none | n/a |
| clockwork | clockwork | `#160f31` → `#33214b` | `#ecaa43` | none | n/a |
| cattedrale | locomotive | `#071526` → `#37444d` | `#c98bff` | none | n/a (the port's own tint; `arena_style.gd` says which) |
| forgia | clockwork | `#160f31` → `#33214b` | `#ffd54a` | none | n/a (the port's own tint) |
| tempesta | fantasy | `#07142f` → `#287eb0` | `#79eeff` | `#07142f` → `#287eb0`, `#79eeff` | **none** |
| abissale | fantasy | `#020b1d` → `#086474` | `#42fff2` | `#020b1d` → `#086474`, `#42fff2` | **none** |
| caldera | fantasy | `#160b10` → `#7b2817` | `#ff7138` | `#160b10` → `#7b2817`, `#ff7138` | **none** |
| orrery | fantasy | `#080722` → `#30246a` | `#b595ff` | `#080722` → `#30246a`, `#b595ff` | **none** |

The check fails if any of those nine rows departs from the reference, and it also fails if the four ids
the reference lists are not exactly the four the port calls fantasy — so the classification cannot
drift away from the reference's table silently. Nothing here overrides the physical data: `wallBounce`
and `floorGrip` are still read from the frozen roster through `src/sim/frozen.gd`, never restated.

## 12.9 The gate, as run

The lane's whole gate is one script (`/tmp/crew2-gates4.sh`, one engine at a time, every invocation
wrapped in `flock -w 900 /tmp/padel-godot.lock` + `timeout`), and `godot/game/check_log.sh` decides each
suite. The command prefix for every row below is

```
flock -w 900 /tmp/padel-godot.lock timeout <t> env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```

| suite | arguments | exit | verdict line |
|---|---|---|---|
| engine harness | *(none: `run/main_scene` = `res://tests/SmokeTest.tscn`)* | 0 | `ok harness: PASS 8/8 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)` |
| slice test, full build | `--script res://tests/game_slice_test.gd` | 0 | `ok slice-full: PASS 211/211 exit=0 script-errors=0 errors=2(allowed=1+1) fails=0(allowed=0)` |
| slice test, demo build | `--script res://tests/game_slice_test.gd -- --demo` | 0 | `ok slice-demo: PASS 211/211 exit=0 script-errors=0 errors=1(allowed=1+0) fails=0(allowed=0)` |
| `audit_base` failure-path probe | `--script res://tests/build/audit_base_abort_probe.gd` | 0 | `ok audit-probe: PASS 6/6 exit=0 script-errors=0 errors=0(allowed=0+0) fails=3(allowed=3)` |
| ten ported rules audits | `--script res://tests/audits/run_all.gd` | 0 | `ok audits: PASS 10/10 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)` |
| ported input audits | `--script res://tests/input/run_all.gd` | 0 | `ok input-runner: PASS 4/4 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)` |

`OVERALL=0`. The slice count moved **131 -> 211** (the inherited run was `FAIL 130/131` with one red;
the red is green and eighteen checks were added by this lane's work, all of them asserted in both build
variants — the two variants print the same count, deliberately, so a build-dependent check cannot hide).
Both slice runs report the same footprint line, `# sections ran 19/19` and
`# OBJECTS start=1550 end=1945 delta=395 nodes=1 orphans=0 resources=56`.

The ten audits, individually green inside the aggregate (`# totals checks=221 failures=0 not-ported=0
expected-checks=221 mismatched=[] audits_failed=0`, `# verdict audits passed=10/10 harness checks=20/20`):

| audit | checks | audit | checks |
|---|---|---|---|
| `controller_tactics` | 14 | `lineup` | 23 |
| `match_format` | 26 | `ai_attack` | 16 |
| `wall_rules` | 22 | `difficulty` | 35 |
| `court_speed` | 25 | `shot_balance` | 23 |
| `shot_quality` | 13 | `smash_input` | 24 |

221 checks in total, matching the recorded total the review cited — with each per-audit count now
pinned to the audit it belongs to (§12.2.2).

## 12.10 Artifact inventory (bytes and sha256, this lane's write scope)

Every file this lane created or changed, with the size and hash of the file as it stands after the gate
run above. `godot/game/out/**` is the capture output directory that the export presets exclude; it is
not committed.

| path | bytes | sha256 |
|---|---|---|
| `godot/game/mode_screen.gd` (new) | 14,415 | `901753c64f5b235a996edd944e78f32014f9cbfacf99da0ba1d821f953f47900` |
| `godot/game/ModeScreen.tscn` (new) | 322 | `ac4f7f7b024d387cca09b4ddb58c4866a341b342631438b87a6bf61ff01d7931` |
| `godot/game/check_log.sh` (new) | 4,317 | `f9045a36f7dcb0438c3ca1c9c63263d489cd0e1ddf012a5e811b0929c75c31b7` |
| `godot/tests/build/audit_base_abort_probe.gd` (new) | 3,398 | `643c24e7b592f811c940dde1ef1e93f65edbdd8a26777f5d194da79b92776118` |
| `godot/tests/game_slice_test.gd` | 99,620 | `7ae710583551a7f8f2265c54d198ad733bc7549b5e529db8bcf2d5668ed57557` |
| `godot/game/menu_focus.gd` | 12,220 | `7d45de3e265b5260854f1063d0b5925e7260777339c1cb6d0bec10951b43569a` |
| `godot/game/main_menu.gd` | 23,563 | `f168d578ef00c41a4dfabb68b30ee60a1368d4ddc0b565ae07f7e5e9c724078d` |
| `godot/game/match_controller.gd` | 34,556 | `5a2159a8e3cda933a43acb23d76398906fd66c50139052593f8010a198d20536` |
| `godot/src/audits/audit_base.gd` | 6,466 | `a8732ab803e9ad4e383a12e6098dbb29ac1fd3dff95391bd40659076972c1ab6` |
| `godot/tests/audits/run_all.gd` | 8,329 | `16b89a0a585c02c88d3033c27f6d7870fd333559903f9b6ac99aefaa190849e9` |
| `godot/game/out/menu-full.png` (capture) | 137,938 | `5d5dd6c256e1cb6bb93478adfdbc03457512fedf5ff325163d2d817502cc8619` |
| `godot/game/out/menu-demo.png` (capture) | 119,601 | `a855d99589c489878239dd26fd2d41343511b0c920b72868f5d452b41f5bab38` |

`godot/src/audits/audit_base.gd` and `godot/tests/audits/run_all.gd` are the two files the item-3 fix
was explicitly allowed to touch; no audit's assertions were changed (the only edit in the aggregate is
the check-count table and the verdict's source). `godot/project.godot` is untouched and
`run/main_scene` is still `res://tests/SmokeTest.tscn`, which the harness row above loaded.
Nothing was committed, pushed or deployed; no paid service was called.

## 12.11 What is NOT done

* **No fresh export of the two presets by this lane.** The demo/full captures of §12.6 come from the
  project run, where the only difference is the build flag; the packs on disk are the previous slice's.
  The reason is in §12.6: `--capture` cannot write inside a packaged build.
* **The engine's exit-time `resources still in use at exit` line** is allowed with a named pattern
  (§12.2.1), not fixed: its cause is a `static var Shader` in
  `godot/src/character/outfit_catalogue.gd:95`, which is outside this lane's write scope.
* **The mode screens do not start a mode match, do not save progress and do not carry the drill's own
  HUD.** They display the mode's own data and return to the menu. Starting a career or tournament match
  from them, `ModesSave` wiring and the drill HUD are the next slice.
* **The demo export's content rule is proven at the project level and was already proven inside the
  exported binary by the S12 slice** (`DemoSelfReport`, `PASS 18/18`); this lane did not repeat the
  export.
* **Athlete rigs are not animated per-run beyond the sim's own gait state** — `locomotion_states` are
  reported and wired to the sim, but no new animation work was done here.
* **The two `ERROR:` allowances in `check_log.sh` are a deliberate, named deviation** from "a suite log
  must contain no engine error line at all". Both are justified in the script's header and counted
  (max one each); any other `ERROR:` line, and any `SCRIPT ERROR` at all, fails the suite.

# 13. The three modes are PLAYABLE, and the Italian text defects are fixed — crew-modes-play

Lane: **crew-modes-play**, integration owner for `godot/game/**`. Write scope: `godot/game/**`,
`godot/tests/game_slice_test.gd`, `godot/build/**` (never committed), this file (append) and the new
`docs/wayfinder/evidence/modes-playable.md`. `godot/src/**`, `js/**`, `scripts/**`,
`godot/export_presets.cfg` and `godot/project.godot` were read and not edited; nothing was committed
or pushed; no paid service was called.

§12 ended with "the mode screens do not start a mode match, do not save progress and do not carry the
drill's own HUD". That is the gap this section closes, and it closes it by PLAYING: a real session
against `godot/src/modes/**`, a mode HUD, the bracket and the season written through
`godot/src/modes/modes_save.gd` → `godot/src/save/**`, and all three modes refused in the demo build.

## 13.1 The counts, before and after

| Suite | Before this lane | After this lane |
|---|---|---|
| `slice-full` (`tests/game_slice_test.gd`) | `PASS 211/211` | **`PASS 280/280`** |
| `slice-demo` (same file, `-- --demo`) | `PASS 211/211` | **`PASS 229/229`** |
| engine harness (`--path godot/`, `SmokeTest.tscn`) | `PASS 8/8` | `PASS 8/8` |
| ten rules audits (`tests/audits/run_all.gd`) | `PASS 10/10` | `PASS 10/10` |
| input suite (`tests/input/run_all.gd`) | `PASS 4/4` audits | `82/83` — see §13.6, NOT this lane |

```
ok slice-full: PASS 280/280 exit=0 script-errors=0 errors=1(allowed=1+0) fails=0(allowed=0)
ok slice-demo: PASS 229/229 exit=0 script-errors=0 errors=2(allowed=1+1) fails=0(allowed=0)
```

Both gate lines come from `godot/game/check_log.sh` (the strict gate §12.2 added: a `SCRIPT ERROR`,
or any `ERROR:` line other than the two named allowances, fails the suite whatever the counts say).
The demo variant is a separate engine run with `-- --demo`, so "the demo build is green" is a fact
about a run, not about a branch.

## 13.2 What was missing, and what was added

`godot/src/modes/**` had the rules and 3 603 green checks (`modes-port.md`), and
`godot/game/mode_screen.gd` could display their tables — but nothing could **play** one. Three
things were missing and all three now exist:

| Path | What it is |
|---|---|
| `godot/game/mode_session.gd` (new) | the playable session: one drill / tournament round / career match. Owns the mode's live state, resolves the fixture, steps the REAL engine, and on a single end-of-session path awards and persists exactly what the reference awards and persists. Every number comes from `src/modes/**`; the only physics line is `Sim.update_match` (through `DrillSession.step` for the drill) |
| `godot/game/mode_hud.gd` (new) | the mode HUD panel: title, phase, and the mode's own lines and metrics. Visible only when a session exists — a quick match still has no mode panel |
| `godot/game/match_controller.gd` (edited) | takes a mode route: builds the session BEFORE the arena (the fixture's court is the one physics runs on), adopts the session's state, ticks it through `session.step`, draws the drill's target ring, ends the drill from ESC, and returns to the mode screen |
| `godot/game/match_config.gd` (edited) | `pending_mode` / `pending_exercise` / `pending_round` / `save_dir` / `save_store()` / `mode_options()`: the one place a screen and a test hand `ModeSession.start` the same dictionary |
| `godot/game/mode_screen.gd` (edited) | each mode screen now STARTS its mode (a `start_mode()` that refuses when the build does not grant it), shows the save's own state (`tournament_round`, the career's season/objectives/stars), and carries a render path (`--capture`, `--mode`, `--save-dir`) |
| `godot/game/lineup.gd` (edited) | `resolve()` accepts the dictated rival pair (`CareerRules.dictated_rivals`), so a mode's rivals are the reference's, not the menu's |

## 13.3 Item 1 — the drill, played

Command (both variants run; the numbers below are the full one):

```
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/game_slice_test.gd            # exit 0
```

Named checks, all `ok` in `/tmp/final-full.log (godot/build/logs/2026-09-16-slice-full-final.log)` → `godot/build/logs/2026-09-16-slice-full.log`:

```
ok the drill starts from the menu's own options as a real DrillSession
ok the drill runs the exercise the screen selected
ok the drill matches the quick match's own court and rival tables
ok the drill HUD carries the phase, the target and the live score the tick loop will move
ok the drill HUD draws the reference's four metrics
ok the tick loop advances the drill out of `ready` and places a target
ok the HUD's target is the drill's own target, not a copy
ok an untouched feed closes the attempt as the reference's own miss
ok a miss pays the reference's zero: attemptPoints(0, grade)
ok a hit: the rally exercise grades a held exchange with the reference's own points
ok ending the drill persists the record through ModesSave
ok the drill save round-trips: a second store reads the same best
ok a drill ends once: ending it again writes nothing new
ok a drill that scored nothing does not overwrite the record (improvement only)
```

The session is started from the menu's own options (`Config.mode_options()`) through the SHIPPED
route (`res://game/Match.tscn` with `Config.pending_mode = "drill"`), played with the scripted player
through `tick_fixed` — the same entry point a rendered frame uses — and graded by `DrillScoring`:
`# DRILL session=rally score=7 best=7 attempts=1 hits=1 streak=1 grade=late line=shot:late · 7`.
The miss pays `attemptPoints(0, grade) == 0`; the hit pays `attemptPoints(min(1.5, 0.25 + rally_hits *
0.18), grade)`, both recomputed from the reference's own `drill_scoring.gd` in the assertion, so the
test cannot pass by agreeing with itself. Persistence is read back through a SECOND store
(`Config.save_store()`), and the improvement-only rule is exercised by a session that scored nothing:
the record does not move and the save reports `skipped`.

## 13.4 Item 2 — the tournament, played, advanced and next-fixture

```
ok a tournament round starts on the bracket's own fixture
ok the round played is the one the save holds (tournament_round)
ok the round's court is the fixture's own
ok the round's AI is the reference's tier for that round
ok the round's rivals are the dictated pair (dictatedRivals)
ok a tournament round keeps the reference's own scoring (a full tennis match, not points)
ok the tournament HUD shows the round, the court and the rival
ok the tournament round reaches a real result inside the tick budget
ok the round is scored by `tournament_rules.gd::advance`
ok the advanced round is persisted through ModesSave.save_tournament_round
ok the trophy flag is the reference's own (final round won)
ok the match reaches the history albo through ModesSave.record_match
ok the tournament screen shows the round the save holds
ok the tournament screen shows the next fixture's court and marks the round in corso
ok a WON round advances the bracket and persists round+1 through save_tournament_round
ok the advanced round's next fixture is the reference's fixture for that round
ok winning a round is recorded in the history albo too
```

The played round is a real one: 52 288 ticks, the scripted player, the real engine, ending
`winner=ai` — so `advance(0, false)` returned `{"round": 0, "reset": true, "continuing": false}` and
the save holds round 0. The WIN branch is exercised separately and this file says so plainly: the
result is FORCED (`state.result = {"winner": "player"}`, the field `Sim.update_match` itself writes),
because the branch under test is `advance(round, true)` plus the `save_tournament_round` call that had
no caller before this lane (`# TOURNAMENT_WIN round=0 -> next=1 fixture=abissale`). Both branches read
the round back through `ModesSave.tournament_round` on a fresh store.

## 13.5 Item 3 — the career, played, awarded and on screen

```
ok a career match starts from the calendar the save holds
ok the career match plays the saved season and calendar position
ok the career court is the season's own fixture
ok the rival is the season's AI profile (careerAiProfile)
ok the career match scores in points at the reference's own target
ok the season's bonus objective is `matchObjective(season, matchIndex)`
ok the career HUD carries the match objective as one line
ok the mode HUD panel draws the objective line it modelled
ok the mode HUD is visible in a mode match (and was not in a quick one)
ok the career match reaches a real result inside the tick budget
ok the career match advances the calendar through `apply_career_match`
ok the outcome is one of the reference's own four (or "" mid-season)
ok the objectives are awarded by `CareerProgress.awardObjectives`
ok the bonus objective is measured on THIS match (`matchObjective`)
ok the career payload is persisted through ModesSave.save_career
ok the career history entry reaches the albo with the season it was played in
ok the objective line on the HUD is read back from the same state the match ended in
ok the career screen shows the season and calendar the save holds
ok the career screen lists the season's objectives as the save holds them
ok the career screen reports the stars the match earned
```

Played to a real result in 10 262 ticks (points to 11). The persisted payload, read back from the
save: `matchIndex 1`, `stars 2`, `seasonStars 2`, `losses 1`, `seasonObjectives` with
`winRally … done`, and a history entry carrying its season. The objective is a HUD line IN-MATCH
(`OBIETTIVO  noDoubleFault 0/0  ·  FATTO`) and the season state is on the screen the player returns
to (`# CAREER_SCREEN season=1 match=1 wins=0 stars=2`).

## 13.6 Item 4 — the demo rule, on every route

```
ok a DEMO build grants exactly one mode (js/build.js DEMO_CONTENT.modes)
ok a locked drill screen refuses to start and says why
ok a locked tournament screen refuses to start and says why
ok a locked career screen refuses to start and says why
ok a DEMO build refuses all three modes at the seal (ModeSession.can_start)
ok a DEMO build's mode screens refuse all three (ModeScreen.start_mode)
ok a DEMO build's match scene refuses a mode route and falls back to quick match
```

Four routes, all refused before anything is built: the gate (`ModeSession.can_start`), the session
(`ModeSession.start` returns null — `MODE_REFUSED mode=drill reason=drill is not in this DEMO build's
granted modes ["quick"]`), the screen (`ModeScreen.start_mode` reports `started=false` with a reason)
and the MATCH SCENE, which is the route no screen can bypass (`Config.pending_mode = "drill"` by hand,
then `res://game/Match.tscn`: `session == null`, `pending_mode` back to `quick`, and the state is a
quick match).

One divergence is deliberate and named: in the browser, training is a header button
(`index.html`, `data-action="to-drill"`) and not a mode card, so `DEMO_CONTENT.modes` cannot answer
"is the drill playable" — `allModes` has no training entry at all. This port renders all three modes
from ONE row and one gate, so it applies the build's granted list uniformly: in the demo, no mode can
be started by any route. `ModeSession.can_start` asks the build flag AND the granted list, which is
exactly the rule the menu's own mode row already used, so the menu and the session cannot disagree.

## 13.7 Item 5 — the three text defects

**(a) the accented letters.** `MODALITA'` and `gia'` were SOURCE STRINGS in `godot/game/**`, not a
font gap, and both halves are now checked:

```
ok the UI font carries the Italian accented glyphs (font coverage, not a fallback)
ok the locale table's own title is the reference's, accents included          # MODALITÀ DI GIOCO
ok the reference's Italian title has no ASCII apostrophe standing in for a vowel
ok no string literal in godot/game/** spells an accented Italian word with an apostrophe
ok the menu's mode-row title is the reference's own `modesTitle` string
ok the mode-row title is laid out above the mode row, not below it
```

The title on the mode row now reads the reference's own key (`modesTitle`: `MODALITÀ DI GIOCO` in
Italian, `GAME MODES` in English) instead of a literal, and the port's own Italian strings were fixed
where they were typed with an apostrophe (`gia'` → `già`, `difficolta'` → `difficoltà`, `piu'` →
`più` in `hud.gd` and the gate's comment). The source scan is a structural check on every string
literal in `godot/game/**`, so the defect cannot come back in a file this lane owns without failing
the suite. The font check separates the two questions the owner asked: the shipped Godot font DOES
carry `à/è/é/ì/ò/ù/À/È/Ì/Ò/Ù/·/»` — the glyph was never the problem — while `▸` (U+25B8) and `◂`
(U+25C2) are NOT in it and were on screen as missing-glyph boxes in the outfit button and on the mode
screens' back button. Both were replaced with Latin-1 characters and the coverage check now names
what the screens actually use.

**(b) the clipped `In the full game`.** Measured, not guessed, at both frame sizes, in the locale the
defect was reported in (Italian):

```
# MODE_ROW_FIT 1280x720:  "TORNEO CAMPIONATO — Nella versione completa" needs 340 + 8 pad, has 391
# MODE_ROW_FIT 1152x648:  "TORNEO CAMPIONATO — Nella versione completa" needs 316 + 8 pad, has 348
```

Before the fix the same measurement read `needs 365 + 8 but the row is 349 (1280x720)` and
`needs 373 but the row is 307 (1152x648)` — the panel was 24 px too narrow in one frame and 66 px in
the other, which is why the label was trimmed to `Nella versione complet` (`In the full ga`). Two
causes, both fixed in `godot/game/main_menu.gd`: the section title sat INSIDE the row and reserved
118 px of the width the three buttons had to share (it now has its own line above the row), and the
buttons carried `clip_text = true`, which is what made the overflow silent. Clip is gone, the font is
13 px, and the fit check measures the label with the engine's own font metrics against the width the
layout actually gives the button — so the row must fit, it cannot trim. `menu-demo.png` shows all
three labels complete: `TRAINING — In the full game`, `CHAMPIONSHIP TOURNAMENT — In the full game`,
`CAREER — In the full game`.

**(c) the mixed-language stat labels.** The reference prints exactly three stat ids
(`statSpeed`/`statControl`/`statPower` = `VEL`/`CTR`/`POT` in Italian, `SPD`/`CTL`/`PWR` in English),
and an AI tier's accuracy has no stat id at all (`js/ui.js:636` feeds it as `state.ai.skill`), so the
tier row printed English while the athlete row printed Italian. Both rows and both mode screens now
read the ids from the locale table (`statSpeed`, `statControl`, `statPower`, and `ability` for the
accuracy figure):

```
ok the reference's Italian stat labels are the ones this UI prints
ok the English table carries the reference's other spelling, not a third one
ok no stat label on the menu speaks English while its neighbour speaks Italian
ok every stat label on the menu is one of the reference's own ids
ok no mode screen row and no mode HUD line speaks a stat language of its own
```

Nothing was invented: every label on screen is a reference message id, and the check that would
catch an invented one is a word-boundary scan for `skill|speed|power|control` over every Button on the
menu, every open mode screen's rows and every mode HUD line.

## 13.8 Renders

```
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --resolution 1280x720 \
  --path godot/ res://game/Match.tscn -- --capture=modes          # three mode HUDs, one engine run
```

`godot/game/out/mode-drill.png` shows the drill HUD with `FASE RESULT`, `PRECISION · fase result ·
round 1`, `PUNTEGGIO 2 · record 2 · shot:perfect · 2`, `BERSAGLIO short (550, 153) r46`,
`COLPI 0/1 · serie 0 · rally 1`, `ESITO drillWhyWide` and the four reference metrics — a real attempt,
graded, on screen. `mode-tournament.png` and `mode-career.png` carry their own lines
(`TURNO 1/3 · officina · Rivale del Circuito (Abilità 0.46)`, `STAGIONE 1 · PARTITA 1/3 · cattedrale`,
`OBIETTIVO noDoubleFault 0/0 · FATTO`). `mode-career-screen.png` is the career SCREEN reading the
PLAYED save (`--save-dir=user://slice-modes-test`): `STAGIONE 1 · partita 2/3 · forgia`,
`BILANCIO 0 vinte · 1 perse · 2 stelle`, `OBIETTIVO · winRally · target 10 · FATTO`,
`PARTITA 2 · forgia`. `menu-demo.png` is the demo menu. Software GL: correctness frames only, no
frame-rate claim.

## 13.9 Two findings worth carrying forward

* **The menu renders in the default locale (`en`, `locale_rules.json`) while the in-match HUD pins
  Italian** (`godot/game/hud.gd` calls `Locale.set_lang("it")`). That is why the same run shows
  `Ability 0.50` on a mode screen and `Abilità 0.46` in a mode HUD's lines, and why the demo menu
  capture prints `In the full game` where the suite (which builds a match HUD first) prints
  `Nella versione completa`. Both are asserted in the language they are rendered in; the split itself
  is another lane's seam (`src/locale/**`) and is reported here, not changed.
* **The input suite is 82/83 and the failing check is NOT this lane's.**
  `a11y/every_motion_mention_in_audio_is_a_false_diagnostic` reports
  `["res://src/audio/music.gd:328"]`; that line is the English prose word "reduces" in a comment, and
  the audit's `MOTION_WORDS` scan is a substring match for `reduce`. `godot/src/audio/music.gd` was
  modified at 16:31:14 by a concurrent lane and is outside this lane's write scope
  (`godot/src/**`). Reported with the evidence and left alone.

## 13.10 Artifact inventory (bytes and sha256)

| Path | Bytes | sha256 |
|---|---|---|
| `godot/game/mode_session.gd` | 23772 | `9ffb4e605ad15706594932e432e0ce29ba6a92e00f3321db68daf9f329a8eb56` |
| `godot/game/mode_hud.gd` | 6050 | `4703b04bc16fda0ee21f06ae40a99d4112cb65a9b5af74089717d71268eaaccf` |
| `godot/game/mode_screen.gd` | 24810 | `c4feaedde9dec42813349dadb354a58cda56fc8906e04262c8b66a623bfe4e1b` |
| `godot/game/match_controller.gd` | 47956 | `c8ad6081e0b6a39a09efccae80c439c7da8cf704419298ba62ea2bb429737bdf` |
| `godot/game/match_config.gd` | 7819 | `f56c9ee917c08bbeee1e496b44348107fdd3bcc041439e44a1c50e8ecbba9adc` |
| `godot/game/lineup.gd` | 6063 | `3132662d6594c310f49b71fcb1bd734eadc480c679874835e7dc3e9542bda50b` |
| `godot/game/main_menu.gd` | 25884 | `4851a8bfe347dbd40574c5b3f75c02822f28cefe8d84ae8d032ba1467ff4b437` |
| `godot/game/hud.gd` | 30006 | `07940213f5472a784adcc41516a6094a00f5e761c89a0d3cda26235d1b95cf16` |
| `godot/game/content_gate.gd` | 5247 | `3709bf2bef355e0538d1fcf9b90ed175dc5599b92722bf3a55c3ed3b847dcf8a` |
| `godot/tests/game_slice_test.gd` | 137071 | `ebf0e3dbd020d6d2018757561d9de6ac8883a87d6817bc548f6e47bc977b06aa` |
| `godot/game/out/mode-drill.png` | 225193 | `d63451473923cb729e9efe4094735d75e13a802428a0a4d77f0c15c08e6ec9f2` |
| `godot/game/out/mode-tournament.png` | 202375 | `72b0e866f127cd97420792df4086c82ffa6917aed601d1cdce24c1e435383740` |
| `godot/game/out/mode-career.png` | 207862 | `d901f4c50ed7a62adebafc1d8289f700e47e37b84eb6033eec8202c06a3279da` |
| `godot/game/out/mode-career-screen.png` | 72785 | `8d410f8c65d083b8237c5a34f653879a0ddbccf27b86c1844d4f19311a504b04` |
| `godot/game/out/menu-demo.png` | 120951 | `d9a93c0075109e6d22e5a341adf7486dc68403fa100dda85ebe61fb369d1619f` |
| `docs/wayfinder/evidence/modes-playable.md` (new) | 23204 | `efa12f4b7a3420f62bc38040ca8d8c534ffecaabbe780d31ab72512c07f3a270` |
| `docs/wayfinder/evidence/quick-match-playable.md` (this file, §13 appended) | 107660 | `1fd3fa2d5f56bd45370b668df943ecf27583f8d39399510df34ebac17e550338` |

The two document hashes are the versions measured at hand-off — measured BEFORE this table's
own last edit, because a document cannot contain its own final hash. The code and render hashes
above are unaffected by that edit.

Run logs, copied out of `/tmp` into the build tree (never committed):
`godot/build/logs/2026-09-16-slice-full.log`, `…-slice-demo.log`, `…-baseline-full.log`,
`…-engine-harness.log`, `…-rules-audits.log`, `…-input-suite.log`, `…-capture-mode-huds.log`,
`…-capture-career-screen.log`, `…-capture-demo-menu.log`.

## 13.11 What is NOT done

* **The drill is not driven by a human in a rendered window.** It is played by the scripted player
  through `tick_fixed`, the same entry point a rendered frame uses, and rendered in three frames
  (§13.8). No `xvfb` session was played interactively.
* **The tournament round the slice PLAYS ends in a loss** at the pinned seed, so the bracket RESET
  branch is the one a real match exercised; the WIN branch (`advance(round, true)` →
  `save_tournament_round`) is exercised with a FORCED result, stated as such in §13.4. The scripted
  player was not re-tuned to win, and the win was not faked as a played match.
* **Career season 1 only.** The slice plays the first match of season 1. The later seasons, the
  finale and the promotion path are covered by the modes lane's own audits (3 603 checks), not by a
  played match here.
* **No fresh export of the two presets.** The demo build is proven by `-- --demo` in the project
  (which is what `BuildFlag` reads) and by the refusal assertions in §13.6; the packaged demo binary
  was not re-exported or re-run by this lane.
* **`godot/src/**` was not edited at all.** Where a mode's rule needed a different input (the dictated
  rival pair, `modes_save` writers) the caller was changed, not the module: `modes_save.gd`'s
  `save_tournament_round` had no caller before and now has one.
* **The input-suite check named in §13.9 is left failing.** Its cause is in another lane's file
  (`godot/src/audio/music.gd`, modified 16:31:14) and outside this lane's write scope.
