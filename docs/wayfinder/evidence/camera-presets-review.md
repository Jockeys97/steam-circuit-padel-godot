# Camera presets review — the artifact, not the verdict

Godot 4.7.2 port of Steam Circuit Padel Pro. Companion to
`docs/wayfinder/tickets/camera-and-feel-spike.md`, which is **open** and stays open.

> **NO VERDICT HAS BEEN MADE.** This document renders and measures camera/HUD
> options so the choice is cheap to make and cheap to reverse. The recommendation in
> section 8 is a **proposal for the owner**, nothing more. The gate closes when Luca
> plays it, not when a number in this file looks good.

Nothing was committed, pushed or deployed. Zero paid spend, zero new assets: every
pixel here comes from assets and code the repository already had.

---

## 1. The question on the table

The port reproduces the browser build's opening composition (the `default` preset in
`godot/game/court.gd`, solved by `godot/prototypes/arena_spike/`). Nobody has
approved it, and the shipped framing has one measured problem: **the near-side
athletes are cut off by the bottom HUD band, so the player cannot see their own
team's footwork.**

That claim is now a number rather than an impression. At 1280×720, on the game's own
rally frame:

- the near player's whole body occupies screen rows **554 → 571** — a **17 px tall**
  athlete — and the bottom HUD band starts at row **530**;
- **100 %** of the near player's drawn body pixels fall inside a HUD panel rectangle
  (the log panel, x 12…432, y 538…710). Not "mostly hidden": every pixel;
- the near partner, at x 1097…1152, survives only because they happen to stand in
  the gap between two panels on this tick;
- the near **baseline** — where a receiving player actually stands — projects to row
  **707**, which is 177 px inside the band and 13 px from the bottom of the frame.

So the defect is not "the HUD is a bit big". A player standing on their own baseline
is, by construction, invisible.

---

## 2. What was built

`godot/prototypes/camera_study/` — see its `README.md` for the reproduction recipe.

The study scene instantiates the **real** `res://game/match_controller.gd` (real
arena, court, glass, net, HUD, simulation, scripted player), switches its engine
clock off, and steps it to the game's own `rally.png` predicate
(`rallyHits >= 3 and ball.z < 140`, from `match_controller.gd:_capture_plan`). Every
option then renders that **same frozen tick**, so the only difference between two
images is the option under test.

This matters for option 1: `current-composition` is not this study's approximation of
the game's framing, it is the game's framing, produced by the game's own camera
builder and the game's own HUD. The game's own `godot/game/out/rally.png` is copied
into the study folder next to it as an independent cross-check, untouched.

Two images per option, plus the engine's own numbers:

| artifact | what it is |
|---|---|
| `<option>__<W>x<H>.png` | the frame as a player would see it, HUD on |
| `<option>__<W>x<H>__mask.png` | ID pass: one exact unshaded RGB per athlete, per ball, per court bed; glass, net, scenery, lines, rackets and HUD hidden |
| `<option>__<W>x<H>.json` | camera, HUD panel rectangles, projected feet/head/ball/court points, frozen tick |

The measurement (`measure.py`, no engine) counts the ID pass and intersects those
pixels with the HUD rectangles **the engine reported for that exact frame**. A beauty
frame cannot answer "how much of this body is hidden" — the athlete's baked texture
shares colours with the court — so the ID pass exists to make the counting
arithmetic instead of judgement.

---

## 3. The options

| # | id | camera | HUD | why (one line) |
|---|---|---|---|---|
| 1 | `current-composition` | `court.gd` preset `default`, untouched | as shipped | The baseline everything else is measured against. |
| 2 | `raised-backed-off` | `default`, dollied straight back along its own view axis, distance solved | as shipped | Same pitch, same FOV, same look — only further away. Solved so the near pair's feet, **where they stand on this frame**, clear the band. The smallest camera move that fixes today's frame. |
| 3 | `slim-bottom-band` | `default`, untouched | slim | The band shrinks instead of the world: log panel cut to two smaller lines, feedback panel kept where the reference puts it but reduced to the score word and the energy bar. |
| 4 | `raised-and-slim-band` | `default`, dollied back, solved against the **near baseline** | slim | Both fixes, with the strict criterion: a player standing **anywhere** on their own half is readable, not just where they happen to be on this tick. Shows what that strictness costs. |
| 5 | `tactical-wide` | existing `wide` preset (16.62 m, −68°, 60° FOV) | as shipped | A higher tactical view that already exists in the codebase — no art-direction invention — so the cost of "more court" in ball size is visible. |
| 6 | `behind-the-baseline` | existing `playable` preset (3.2 m, level, looking at the net) | as shipped | The closest behind-the-server view the port has ever rendered, and the one that reads footwork best. Also already in the codebase. |

Options 5 and 6 are deliberately **not new art direction**: they are the two camera
presets `godot/game/court.gd` already ships, rendered here with the real HUD, real
athletes and the real rally state for the first time.

The two "solve" criteria are bisections on a monotone quantity (backing straight off
along the view axis can only move a near object up the frame), 30 iterations, and the
solved distance is written into the JSON — so the framing is checkable arithmetic,
not taste.

---

## 4. Commands, exit codes, key output

Every engine invocation goes through the shared lock with `timeout` inside, per the
host rule (3,910 MB RAM, other lanes working in this repository concurrently). At no
point were two Godot processes alive.

**(a) Script compiles against the live game code**
```
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ --check-only \
  --script res://prototypes/camera_study/camera_study.gd
```
exit `0`, no `Compilation failed`.

**(b) Render, 1280x720** — `godot/prototypes/camera_study/out/render_1280x720.log`
```
./godot/prototypes/camera_study/render.sh 1280x720 game
```
exit `0` — `RESULT: STUDY_PASS`. Key lines:
```
STUDY_START bodies=game driver=llvmpipe (LLVM 21.1.8, 256 bits) display=X11
BODIES game rigs=4/4 source=match_controller.build_athletes()
FROZEN tick=420 rally=3 ball_px=(798.0,203.8,54.5) score=0-0
FRAME size=1280x720
SOLVE_DOLLY criterion=near-feet     t=4.4867 band_top=530.0 target=520.0 probe_y_at_0=570.9 probe_y_at_t=520.0
SOLVE_DOLLY criterion=near-baseline t=5.6822 band_top=612.0 target=602.0 probe_y_at_0=706.6 probe_y_at_t=602.0
STUDY_PASS options=6 frame=1280x720 bodies=game mem_mb=52.0
```

**(c) Render, 1152x648** — `godot/prototypes/camera_study/out/render_1152x648.log`
```
./godot/prototypes/camera_study/render.sh 1152x648 game
```
exit `0` — `RESULT: STUDY_PASS`. Key lines:
```
BODIES game rigs=4/4 source=match_controller.build_athletes()
FROZEN tick=420 rally=3 ball_px=(798.0,203.8,54.5) score=0-0
FRAME size=1152x648
SOLVE_DOLLY criterion=near-feet     t=7.4859 band_top=458.0 target=448.0 probe_y_at_0=513.8 probe_y_at_t=448.0
SOLVE_DOLLY criterion=near-baseline t=6.7606 band_top=540.0 target=530.0 probe_y_at_0=636.0 probe_y_at_t=530.0
STUDY_PASS options=6 frame=1152x648 bodies=game mem_mb=52.0
```
The frozen tick, the rally count and the ball's simulation coordinates are **identical
at both resolutions** — the same match state, drawn into two different frames.

**(d) Measure (offline, no engine)**
```
python3 godot/prototypes/camera_study/measure.py 1280x720
python3 godot/prototypes/camera_study/measure.py 1152x648
```
exit `0` each — `MEASURE_PASS res=1280x720 options=6 …` / `MEASURE_PASS res=1152x648 options=6 …`

**(e) The project's own harness still passes, after everything above**
```
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```
exit `0` — `PASS 8/8`.

**One blocker, recorded rather than worked around.** Between 13:50 and ~14:05 the
game scripts did not compile: another lane was mid-integration in
`godot/game/match_controller.gd` (`build_athletes()`, `_player_color`, then
`AthleteSpawn.GLB_BASE`, which did not exist in `athlete_spawn.gd` yet). The study
depends on `res://game/match_controller.gd`, so it could not run. Nothing of theirs
was touched or fixed; the render was simply retried until their edit landed, and it
then passed first time. A useful consequence: `bodies=game` now means the shipping
rig, because that integration made `build_athletes()` spawn
`src/character/athlete_spawn.gd` rigs itself — `rigs=4/4` in both logs, read back off
the nodes rather than assumed.

---

## 5. File inventory

Everything below is under `godot/prototypes/camera_study/out/`.

| file | bytes | dimensions | sha256 |
|---|---:|---|---|
| `behind-the-baseline__1152x648.json` | 4440 |  | `895dbb6ce7b3330c448b0244ff80de256d6c0daebcbc7517dec927af15fd35be` |
| `behind-the-baseline__1152x648.png` | 187261 | 1152x648 | `2436767d7f3a1e175a311e6497eadbcc56ca03f7e4a0e9501f20dce204d6bc64` |
| `behind-the-baseline__1152x648__mask.png` | 5908 | 1152x648 | `af1dd59309ef88abd60068b0c323c26739741279a035daf8e1e94368db77c3dc` |
| `behind-the-baseline__1280x720.json` | 4432 |  | `20f2d45d9a4d3ade46ec1cef982e70d36b91cd3c217f14880f0d9b1a11058774` |
| `behind-the-baseline__1280x720.png` | 207855 | 1280x720 | `c82306b4f7a87a5f13a8fc5a4bc1c4402f379c627d78bdef4948ce32543d677e` |
| `behind-the-baseline__1280x720__mask.png` | 6919 | 1280x720 | `706344df4e9f96615b63b8e7e40065c2a7bba6845306d2ecd0e27284594e7f94` |
| `contact-sheet-mask__1152x648.png` | 45789 | 1800x610 | `8efc6868eb25d3d1b4a3729f12c1385152aa6dd04dbdf31f266efdffbca18278` |
| `contact-sheet-mask__1280x720.png` | 46164 | 1800x610 | `47c286722e3cdfc229fc831da44387067a63a0f0c92c6fc3fbf8a575186ae60f` |
| `contact-sheet__1152x648.png` | 481247 | 1800x610 | `ae7060d54136892e1d16dd1b0444bf07e08e0a33b2557e753704e5601737b6c5` |
| `contact-sheet__1280x720.png` | 444748 | 1800x610 | `8248492a3b8eb4705d95890bfa1bd7aae1a5b8728eef788320ae4dfb5d7c75d6` |
| `current-composition__1152x648.json` | 4381 |  | `0ff869ca6d00c1670af3c285b69a0dd3d2d48378ff6f506fa0d7dfe16023dac7` |
| `current-composition__1152x648.png` | 189708 | 1152x648 | `ccd1122181a65f461fb5c60f024f56ca81bb8ee417742e434f9f222946d7a137` |
| `current-composition__1152x648__mask.png` | 6671 | 1152x648 | `b8d5427edb7d95372cbcc13cd76d4cc3ec4a336c83f07711f5874c8f2331ffd0` |
| `current-composition__1280x720.json` | 4381 |  | `92ce5cffdbd82cc3cd055cbe648cd9b4505e51660c6935aa4faa89963d725a4f` |
| `current-composition__1280x720.png` | 217128 | 1280x720 | `18c6f410197653b7eca781c4d84b90074612649b6afd0d26c5a3695026a30e70` |
| `current-composition__1280x720__mask.png` | 7729 | 1280x720 | `98968998e75de4f48812cc796fbd98cb9a81aed5b089b650b74c9d428f4e874c` |
| `index__1152x648.json` | 35754 |  | `50b6595a3fd2bfb36f65b0cca6f32f1b2b2702f9b73ee36890b29764a40cdaf5` |
| `index__1280x720.json` | 35765 |  | `bc6dbd75eb6668432958b08066d1ec004a10990033b48b4e7cd7d4af202e88ee` |
| `measure__1152x648.json` | 37982 |  | `a1b91d4cc8973e5aba00f985bfa633de0756017e9d857a1425aa9e0e41a0ef49` |
| `measure__1152x648.md` | 7058 |  | `f6a5faa317d999257b42ea30b7e3ed8956698062df147b28875fe11eba939520` |
| `measure__1280x720.json` | 37918 |  | `c5d9babfe6cd6c9f6de2899d7f7b4b2121a5e9c66f2edebdf1123a8a77a57702` |
| `measure__1280x720.md` | 7064 |  | `3eacf4dc6d2bb94458cac4ce39ce43123c43c705986b80eb0d4c06f4418eb045` |
| `raised-and-slim-band__1152x648.json` | 4497 |  | `4b7a02288dceb901441dbe66dbeb7661342447d69ff8f40deeeb1fe10585f033` |
| `raised-and-slim-band__1152x648.png` | 148348 | 1152x648 | `f47d50c8796d5d4da9b454aa5b78f26676fab1d3e9763017ea071a140239c814` |
| `raised-and-slim-band__1152x648__mask.png` | 5747 | 1152x648 | `c6a49c2dd595cc87439a8b290d2f28bac4182fac2f51f1901854bc9dcf2c0710` |
| `raised-and-slim-band__1280x720.json` | 4498 |  | `55b6bdc0be02b20fc9fe77ab28957f5677f2a849b623b575efa10972e1fab77c` |
| `raised-and-slim-band__1280x720.png` | 169025 | 1280x720 | `ff011ebab6aa970708aed17bcf64a6e6eb0ea0c0c918629a14562404bc94a7f8` |
| `raised-and-slim-band__1280x720__mask.png` | 6829 | 1280x720 | `f3ff91537c276e9ac774a63d1d8cc50cd21ac36424087ba2635eb6de63eb0301` |
| `raised-backed-off__1152x648.json` | 4471 |  | `7542ee2f08961a8ed8d4bf818ae323ab6a0fc1740f23e3c397ba987533abebae` |
| `raised-backed-off__1152x648.png` | 161420 | 1152x648 | `a10f70d83ed8941ecb52b77fcf1a5ad6aa2491889e5606613ae8723e0285ef33` |
| `raised-backed-off__1152x648__mask.png` | 5730 | 1152x648 | `7bbacce9a1e1402785cca52801d4768965f2d165d8643fecc7538348c0846160` |
| `raised-backed-off__1280x720.json` | 4483 |  | `c20b7676484f3e757648d09a389a598ee9ee50862f3e5ea13324b76e2c1ed3c1` |
| `raised-backed-off__1280x720.png` | 201835 | 1280x720 | `3e24387f0e6ab17da1ad2390d47a97cefb1ff70aee1ac88907f29a2883b3b995` |
| `raised-backed-off__1280x720__mask.png` | 7059 | 1280x720 | `12b34b844f0208635f615b54cba378646ae65117d0a2bc155d11865d9eab6cfc` |
| `reference-in-game-rally__1280x720.png` | 208444 | 1280x720 | `ea810e7c5af2d4c3821483310a0e0a4f0caf6267579028bdf34e922a42316397` |
| `render_1152x648.log` | 4660 |  | `b0a0a2d5362458b80a62a616d88c2cc7b02d64c556a7bb3cf9a81426043a6a3a` |
| `render_1280x720.log` | 4660 |  | `f00df15ed6044a0a103c5f4e3818c5f43445cede54e9619b4399cd865c660ad1` |
| `slim-bottom-band__1152x648.json` | 4415 |  | `90fffd4b1468a043ee83b7534127fd4a9000d27145bb9dd8f0602d4e20030979` |
| `slim-bottom-band__1152x648.png` | 169848 | 1152x648 | `74f857534c4cb0b043902a80769ed9ebf7395507646a9d445a84993a70e7ab20` |
| `slim-bottom-band__1152x648__mask.png` | 6658 | 1152x648 | `7989a45fa50f44f87153ab53cbfd36b69867256e3b330e09fbdb99ea9c2e87df` |
| `slim-bottom-band__1280x720.json` | 4415 |  | `dd07d2f89cce9ec9abb69752caa0e65fe30ac2e6f406b39f27b5732a2101cacb` |
| `slim-bottom-band__1280x720.png` | 197645 | 1280x720 | `cc5c87aef8acffc5d603eb6451d350e7bfc409b330e3bdb2d154f20ba442fb2a` |
| `slim-bottom-band__1280x720__mask.png` | 7758 | 1280x720 | `33fa0e1ff9f892444e37bd6483cefdf07a188d7018db1e3403dd5b941ebd5342` |
| `tactical-wide__1152x648.json` | 4387 |  | `95a5cadf60882ffd1fe16c79bdf148881f50f213a0b9cf0b56f17354013e732b` |
| `tactical-wide__1152x648.png` | 161796 | 1152x648 | `b3d94816868b88155ba2c09f1bd6ac830d9a6e85a276182d94821fe541a07df8` |
| `tactical-wide__1152x648__mask.png` | 5827 | 1152x648 | `3ba4c1e3c24dae783836d664031f072165dc986634ce65ac554b52504f48f407` |
| `tactical-wide__1280x720.json` | 4393 |  | `496334af7eaafed917a3185651ac37d4fd0e74d1fa750003f13afdcc47581c73` |
| `tactical-wide__1280x720.png` | 185067 | 1280x720 | `64e499acfb5724d17ccba4692bb1625b39cd97a3b05347ac0fd45a51722e2b24` |
| `tactical-wide__1280x720__mask.png` | 6856 | 1280x720 | `337fe115124dcbbeaccbc02130863350ecaa3400bd960e0389207a6847df6f90` |

`out/attempt1-reposition/` additionally holds the first slim-band attempt (22 files),
kept as the record described in section 7.

---

## 6. Measurements

Read `court surface in frame %` rather than `court quad in frame %` when comparing
across all six options; the quad column is correct for the five top-down options and
structurally wrong for `behind-the-baseline`, and both are printed so the failure is
visible rather than silent.

Two notes on the ball columns. `diameter px (projected)` is the honest size number:
the ball's radius projected through the camera. `diameter px (area)` is derived from
the ball's pixel count in the ID pass, and on this frozen tick the ball happens to sit
**on top of the far player's body** on screen (ball centre 1023.7, 228.4; that
athlete's head projects to 1020.5, 202.2), so part of it is occluded and the area
figure under-reads by roughly 1-2 px. Where the two columns disagree, the projected
one is the one to trust.

The four athletes are animated rigs playing `idle`, so body pixel counts carry about
1 % of jitter between options from the animation phase (far player 1017 px vs 1008 px
at 720p, same camera). Every conclusion below is one to three orders of magnitude
larger than that jitter.

### Measurements at 1280x720 (bodies=game, frozen tick 420)

#### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band

| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |
|---|---|---:|---:|---:|---:|---:|---:|---|
| current-composition | near player | 1232 | 1232 | 0 | 0.0 | 100.0 | 0.0 | YES |
| current-composition | near partner | 1600 | 0 | 1600 | 100.0 | 100.0 | 0.0 | YES |
| current-composition | far player | 1017 | 502 | 515 | 50.6 | 100.0 | 100.0 | no |
| current-composition | far partner | 896 | 0 | 896 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near player | 698 | 0 | 698 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near partner | 812 | 0 | 812 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far player | 816 | 0 | 816 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far partner | 539 | 0 | 539 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near player | 1232 | 0 | 1232 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near partner | 1600 | 0 | 1600 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | far player | 1008 | 421 | 587 | 58.2 | 100.0 | 100.0 | no |
| slim-bottom-band | far partner | 898 | 0 | 898 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near player | 621 | 0 | 621 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near partner | 693 | 0 | 693 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far player | 533 | 0 | 533 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far partner | 469 | 0 | 469 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near player | 590 | 0 | 590 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near partner | 712 | 0 | 712 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far player | 491 | 0 | 491 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far partner | 460 | 0 | 460 | 100.0 | 100.0 | 100.0 | no |
| behind-the-baseline | near player | 0 | 0 | 0 | 0.0 | 32.7 | 0.0 | YES |
| behind-the-baseline | near partner | 0 | 0 | 0 | 0.0 | 39.4 | 0.0 | YES |
| behind-the-baseline | far player | 3649 | 7 | 3642 | 99.8 | 100.0 | 100.0 | no |
| behind-the-baseline | far partner | 2893 | 0 | 2893 | 100.0 | 100.0 | 100.0 | no |

#### Court, ball and the bottom band

| option | court surface in frame % | near half in frame % | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| current-composition | 100.0 | 100.0 | 100.0 | 560142 | 106917 | 8.2 | 9.7 | 190 | 26.4 | 252336 |
| raised-backed-off | 100.0 | 100.0 | 100.0 | 331056 | 40565 | 7.7 | 7.5 | 190 | 26.4 | 252336 |
| slim-bottom-band | 100.0 | 100.0 | 100.0 | 560120 | 66377 | 10.2 | 9.7 | 108 | 15.0 | 204336 |
| raised-and-slim-band | 100.0 | 100.0 | 100.0 | 294584 | 0 | 7.1 | 7.1 | 108 | 15.0 | 204336 |
| tactical-wide | 100.0 | 100.0 | 100.0 | 280223 | 15227 | 7.3 | 7.0 | 190 | 26.4 | 252336 |
| behind-the-baseline | 57.6 | 22.5 | 1.0 | 506602 | 115120 | 16.8 | 14.5 | 190 | 26.4 | 252336 |

`court surface in frame %` is a 41x27 grid of points on the court floor: the share of the playing surface the camera can see. `court quad in frame %` is the projected corner quad clipped to the frame - correct for the top-down options and meaningless for a low camera, where the near corners project thousands of pixels off-screen and blow the denominator up. Both are printed so the failure is visible instead of silent.

#### Cameras

| option | mode | solve | dolly back m | position | pitch deg | fov |
|---|---|---|---:|---|---:|---:|
| current-composition | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-backed-off | dolly-solved | near-feet | 4.487 | (0.00, 18.53, 8.28) | -65.20 | 50.87 |
| slim-bottom-band | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-and-slim-band | dolly-solved | near-baseline | 5.682 | (0.00, 19.61, 8.78) | -65.20 | 50.87 |
| tactical-wide | preset-wide | - | 0.000 | (0.00, 16.62, 7.40) | -68.00 | 60.00 |
| behind-the-baseline | preset-playable | - | 0.000 | (0.00, 3.20, 5.80) | -18.69 | 60.00 |

#### Deltas against `current-composition` (positive = more of it)

| option | near-pair readable px | ball diameter px | court surface in frame pp | court bed px under HUD | HUD area px |
|---|---:|---:|---:|---:|---:|
| current-composition | +0 | +0.0 | +0.0 | +0 | +0 |
| raised-backed-off | -90 | -0.5 | +0.0 | -66352 | +0 |
| slim-bottom-band | +1232 | +2.0 | +0.0 | -40540 | -48000 |
| raised-and-slim-band | -286 | -1.1 | +0.0 | -106917 | -48000 |
| tactical-wide | -298 | -0.9 | +0.0 | -91690 | +0 |
| behind-the-baseline | -1600 | +8.6 | -42.4 | +8203 | +0 |

#### HUD panels, per option (engine rectangles, x y w h)

| option | panel | rect | court bed px it covers |
|---|---|---|---:|
| current-composition | ScorePanel | 280 10 720 125 | 720 |
| current-composition | FeedbackPanel | 506 530 268 160 | 42880 |
| current-composition | LogPanel | 12 538 420 172 | 56833 |
| current-composition | DebugPanel | 12 10 196 91 | 0 |
| current-composition | HintPanel | 1008 148 260 113 | 6484 |
| raised-backed-off | ScorePanel | 280 10 720 125 | 0 |
| raised-backed-off | FeedbackPanel | 506 530 268 160 | 23584 |
| raised-backed-off | LogPanel | 12 538 420 172 | 16981 |
| raised-backed-off | DebugPanel | 12 10 196 91 | 0 |
| raised-backed-off | HintPanel | 1008 148 260 113 | 0 |
| slim-bottom-band | ScorePanel | 280 10 720 125 | 720 |
| slim-bottom-band | FeedbackPanel | 506 612 268 100 | 25460 |
| slim-bottom-band | LogPanel | 12 612 420 96 | 33661 |
| slim-bottom-band | DebugPanel | 12 10 196 91 | 0 |
| slim-bottom-band | HintPanel | 1008 148 260 113 | 6536 |
| raised-and-slim-band | ScorePanel | 280 10 720 125 | 0 |
| raised-and-slim-band | FeedbackPanel | 506 612 268 100 | 0 |
| raised-and-slim-band | LogPanel | 12 612 420 96 | 0 |
| raised-and-slim-band | DebugPanel | 12 10 196 91 | 0 |
| raised-and-slim-band | HintPanel | 1008 148 260 113 | 0 |
| tactical-wide | ScorePanel | 280 10 720 125 | 0 |
| tactical-wide | FeedbackPanel | 506 530 268 160 | 9916 |
| tactical-wide | LogPanel | 12 538 420 172 | 5311 |
| tactical-wide | DebugPanel | 12 10 196 91 | 0 |
| tactical-wide | HintPanel | 1008 148 260 113 | 0 |
| behind-the-baseline | ScorePanel | 280 10 720 125 | 0 |
| behind-the-baseline | FeedbackPanel | 506 530 268 160 | 42880 |
| behind-the-baseline | LogPanel | 12 538 420 172 | 72240 |
| behind-the-baseline | DebugPanel | 12 10 196 91 | 0 |
| behind-the-baseline | HintPanel | 1008 148 260 113 | 0 |

Unclassified mask pixels (neither a subject nor the black background, i.e. the classifier's own error bar): current-composition 0.0000% (0 px), raised-backed-off 0.0000% (0 px), slim-bottom-band 0.0000% (0 px), raised-and-slim-band 0.0000% (0 px), tactical-wide 0.0000% (0 px), behind-the-baseline 0.0000% (0 px)

### Measurements at 1152x648 (bodies=game, frozen tick 420)

#### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band

| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |
|---|---|---:|---:|---:|---:|---:|---:|---|
| current-composition | near player | 1006 | 1006 | 0 | 0.0 | 100.0 | 0.0 | YES |
| current-composition | near partner | 1305 | 0 | 1305 | 100.0 | 100.0 | 0.0 | YES |
| current-composition | far player | 815 | 782 | 33 | 4.0 | 100.0 | 100.0 | no |
| current-composition | far partner | 730 | 0 | 730 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near player | 422 | 0 | 422 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | near partner | 468 | 0 | 468 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far player | 480 | 0 | 480 | 100.0 | 100.0 | 100.0 | no |
| raised-backed-off | far partner | 320 | 0 | 320 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near player | 1006 | 0 | 1006 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | near partner | 1305 | 0 | 1305 | 100.0 | 100.0 | 100.0 | no |
| slim-bottom-band | far player | 817 | 811 | 6 | 0.7 | 100.0 | 100.0 | no |
| slim-bottom-band | far partner | 729 | 0 | 729 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near player | 446 | 0 | 446 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | near partner | 503 | 0 | 503 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far player | 387 | 0 | 387 | 100.0 | 100.0 | 100.0 | no |
| raised-and-slim-band | far partner | 345 | 0 | 345 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near player | 475 | 0 | 475 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | near partner | 582 | 0 | 582 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far player | 401 | 0 | 401 | 100.0 | 100.0 | 100.0 | no |
| tactical-wide | far partner | 368 | 0 | 368 | 100.0 | 100.0 | 100.0 | no |
| behind-the-baseline | near player | 0 | 0 | 0 | 0.0 | 32.7 | 0.0 | YES |
| behind-the-baseline | near partner | 0 | 0 | 0 | 0.0 | 39.4 | 0.0 | YES |
| behind-the-baseline | far player | 2965 | 723 | 2242 | 75.6 | 100.0 | 100.0 | no |
| behind-the-baseline | far partner | 2341 | 0 | 2341 | 100.0 | 100.0 | 100.0 | no |

#### Court, ball and the bottom band

| option | court surface in frame % | near half in frame % | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| current-composition | 100.0 | 100.0 | 100.0 | 453094 | 120663 | 7.5 | 8.7 | 190 | 29.3 | 252336 |
| raised-backed-off | 100.0 | 100.0 | 100.0 | 202190 | 27720 | 6.2 | 5.9 | 190 | 29.3 | 252336 |
| slim-bottom-band | 100.0 | 100.0 | 100.0 | 453070 | 79614 | 9.2 | 8.7 | 108 | 16.7 | 204336 |
| raised-and-slim-band | 100.0 | 100.0 | 100.0 | 215662 | 0 | 6.3 | 6.1 | 108 | 16.7 | 204336 |
| tactical-wide | 100.0 | 100.0 | 100.0 | 227372 | 23477 | 6.4 | 6.3 | 190 | 29.3 | 252336 |
| behind-the-baseline | 57.6 | 22.5 | 1.0 | 410605 | 115120 | 15.3 | 13.1 | 190 | 29.3 | 252336 |

`court surface in frame %` is a 41x27 grid of points on the court floor: the share of the playing surface the camera can see. `court quad in frame %` is the projected corner quad clipped to the frame - correct for the top-down options and meaningless for a low camera, where the near corners project thousands of pixels off-screen and blow the denominator up. Both are printed so the failure is visible instead of silent.

#### Cameras

| option | mode | solve | dolly back m | position | pitch deg | fov |
|---|---|---|---:|---|---:|---:|
| current-composition | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-backed-off | dolly-solved | near-feet | 7.486 | (0.00, 21.25, 9.54) | -65.20 | 50.87 |
| slim-bottom-band | game-default | - | 0.000 | (0.00, 14.46, 6.40) | -65.20 | 50.87 |
| raised-and-slim-band | dolly-solved | near-baseline | 6.761 | (0.00, 20.59, 9.24) | -65.20 | 50.87 |
| tactical-wide | preset-wide | - | 0.000 | (0.00, 16.62, 7.40) | -68.00 | 60.00 |
| behind-the-baseline | preset-playable | - | 0.000 | (0.00, 3.20, 5.80) | -18.69 | 60.00 |

#### Deltas against `current-composition` (positive = more of it)

| option | near-pair readable px | ball diameter px | court surface in frame pp | court bed px under HUD | HUD area px |
|---|---:|---:|---:|---:|---:|
| current-composition | +0 | +0.0 | +0.0 | +0 | +0 |
| raised-backed-off | -415 | -1.3 | +0.0 | -92943 | +0 |
| slim-bottom-band | +1006 | +1.8 | +0.0 | -41049 | -48000 |
| raised-and-slim-band | -356 | -1.2 | +0.0 | -120663 | -48000 |
| tactical-wide | -248 | -1.1 | +0.0 | -97186 | +0 |
| behind-the-baseline | -1305 | +7.8 | -42.4 | -5543 | +0 |

#### HUD panels, per option (engine rectangles, x y w h)

| option | panel | rect | court bed px it covers |
|---|---|---|---:|
| current-composition | ScorePanel | 216 10 720 125 | 10080 |
| current-composition | FeedbackPanel | 442 458 268 160 | 42880 |
| current-composition | LogPanel | 12 466 420 172 | 58450 |
| current-composition | DebugPanel | 12 10 196 91 | 0 |
| current-composition | HintPanel | 880 148 260 113 | 9253 |
| raised-backed-off | ScorePanel | 216 10 720 125 | 0 |
| raised-backed-off | FeedbackPanel | 442 458 268 160 | 17420 |
| raised-backed-off | LogPanel | 12 466 420 172 | 10300 |
| raised-backed-off | DebugPanel | 12 10 196 91 | 0 |
| raised-backed-off | HintPanel | 880 148 260 113 | 0 |
| slim-bottom-band | ScorePanel | 216 10 720 125 | 10080 |
| slim-bottom-band | FeedbackPanel | 442 540 268 100 | 25728 |
| slim-bottom-band | LogPanel | 12 540 420 96 | 34605 |
| slim-bottom-band | DebugPanel | 12 10 196 91 | 0 |
| slim-bottom-band | HintPanel | 880 148 260 113 | 9201 |
| raised-and-slim-band | ScorePanel | 216 10 720 125 | 0 |
| raised-and-slim-band | FeedbackPanel | 442 540 268 100 | 0 |
| raised-and-slim-band | LogPanel | 12 540 420 96 | 0 |
| raised-and-slim-band | DebugPanel | 12 10 196 91 | 0 |
| raised-and-slim-band | HintPanel | 880 148 260 113 | 0 |
| tactical-wide | ScorePanel | 216 10 720 125 | 0 |
| tactical-wide | FeedbackPanel | 442 458 268 160 | 14204 |
| tactical-wide | LogPanel | 12 466 420 172 | 9273 |
| tactical-wide | DebugPanel | 12 10 196 91 | 0 |
| tactical-wide | HintPanel | 880 148 260 113 | 0 |
| behind-the-baseline | ScorePanel | 216 10 720 125 | 0 |
| behind-the-baseline | FeedbackPanel | 442 458 268 160 | 42880 |
| behind-the-baseline | LogPanel | 12 466 420 172 | 72240 |
| behind-the-baseline | DebugPanel | 12 10 196 91 | 0 |
| behind-the-baseline | HintPanel | 880 148 260 113 | 0 |

Unclassified mask pixels (neither a subject nor the black background, i.e. the classifier's own error bar): current-composition 0.0000% (0 px), raised-backed-off 0.0000% (0 px), slim-bottom-band 0.0000% (0 px), raised-and-slim-band 0.0000% (0 px), tactical-wide 0.0000% (0 px), behind-the-baseline 0.0000% (0 px)

---

## 7. What got worse — plainly

- **`slim-bottom-band` costs information, not pixels.** It drops the feedback panel's
  mode line ("BILANCIATO"), cuts the chronicle from five lines to two, and shrinks
  that text from 17 px to 13 px (title 18 -> 14, score word 40 -> 26, energy caption
  18 -> 14). Nothing else about it is worse: the camera, the court, the ball and all
  four bodies are untouched. Whether losing the mode line and three chronicle lines is
  acceptable is a design call, and it is the owner's, not this study's.
- **`raised-backed-off` shrinks everything.** At 1280x720 the near pair's bodies go
  from 1232/1600 px to 698/812 px (-43 %/-49 %) and the ball from 9.7 px to 7.5 px
  across. At 1152x648 it is worse, because the band's 190 px is a bigger share of a
  shorter frame: the solve needs 7.49 m of dolly, the bodies fall to 422/468 px
  (-58 %/-64 %) and the ball to **5.9 px**. A 6-pixel ball at the resolution a player
  might actually pick is a playability problem in its own right.
- **`raised-and-slim-band` is the strictest and also the smallest.** It is the only
  option with **zero** court-bed pixels under any HUD panel, and it holds for a player
  standing anywhere on their own baseline rather than just where they stand on this
  tick — but it pays 5.68 m of dolly for it, bodies at 621/693 px and a 7.1 px ball.
- **`tactical-wide` buys nothing that the band fix does not.** Every body is readable,
  but they are the second-smallest in the set (590/712 px) and the ball is 7.0 px.
- **`behind-the-baseline` deletes the player's own team.** The near pair is not
  partially hidden, it is **not in the frame at all** (0 drawn pixels; 32.7 % and
  39.4 % of their head-to-feet span falls inside the frame, all of it below the visible
  area). It also sees only **57.6 %** of the court surface and **22.5 %** of the near
  half. What it gives back is real and large: a 14.5 px ball and far-side bodies of
  3649/2893 px, roughly 3x the current framing. It is the most readable view of an
  athlete in the set and the least playable view of a doubles court.
- **A defect none of these options fixes.** At 1280x720 the top-right hint panel
  (`HintPanel`, 1008 148 260 113) hides **49 %** of the far player's body in the
  current composition. Every option that leaves the hint panel alone inherits it. It
  is the same class of bug as the bottom band and it is not in scope here; it is
  flagged so it is not discovered twice.
- **The first slim attempt made one player worse to make another better.** Recorded in
  `out/attempt1-reposition/`: shrinking the panel boxes and moving the feedback panel
  to the bottom-right corner bought the near player back and buried the near
  **partner**, who stands on that side (-987 readable px on them). The cause is that
  `hud.gd:panel_rect` takes the larger of the offset span and the panel's own minimum
  size, so moving a tall panel only moves the collision. The shipped variant shrinks
  the content, which is what actually sets the height.
- **The reference tile is older than the rest.** `out/reference-in-game-rally__1280x720.png`
  is a byte-identical copy of `godot/game/out/rally.png`
  (sha256 `ea810e7c…`, written 12:33), which predates the athletes-view integration, so
  its bodies are the older GLB base-pose duplicates. It is included as an independent
  cross-check of the framing, not of the athletes. Nothing in `godot/game/out/` was
  overwritten.

---

## 8. Proposal for the owner — **not a decision**

**What I would pick: `slim-bottom-band`.** The measured problem is the band, not the
camera, and the band is the cheaper thing to change and the cheaper thing to undo.

At 1280x720 it takes the near player from **0 readable pixels to 1232** (100 %), the
near partner stays at 1600, both bodies move entirely above the band, the bottom band
drops from 190 px to 108 px (26.4 % -> 15.0 % of the frame), and the court under the
HUD drops from 106,917 px to 66,377 px. At 1152x648 the same change does the same
thing (band 29.3 % -> 16.7 % of the frame, near pair 0 -> 1006 and 1305 readable px).
**The camera, the court and the ball are bit-for-bit untouched** — the ball stays at
9.7 px projected at 720p and 8.7 px at 648, where every camera option costs between
23 % and 39 % of that.

The three trade-offs that actually decide this:

1. **Information vs. bodies.** The slim band buys the near pair back by deleting the
   mode line and three chronicle lines. If that text has to stay, the only remaining
   lever is the camera, and the camera charges for it in ball size — 7.5 px at 720p,
   5.9 px at 648.
2. **This tick vs. any tick.** `slim-bottom-band` clears the near pair *where they
   stand on this frame* with 41 px to spare (feet at 571, band top at 612), but the
   near **baseline** still projects to row 707, inside the band. A player who retreats
   to their own baseline is still cut. Only `raised-and-slim-band` is safe everywhere,
   and it costs 5.68 m of dolly, ~50 % of body size and 2.6 px of ball. If the owner
   wants one decision that never has to be revisited, it is that one; if the owner
   wants the cheapest correct thing to play this week, it is the slim band.
3. **How small is too small.** Nothing here can tell you whether a 7 px ball or a
   17 px athlete is playable. That is the entire content of the play session, and it
   is why `behind-the-baseline` is in the set at all: it is the far end of the axis,
   with a 14.5 px ball, 3x bodies, and no view of your own team.

If the answer after playing is "the athletes are simply too small at any band size",
then none of these six is the answer and the real question is the court scale
(`PX_TO_M = 0.025`, and `COURT`'s 1.575 aspect that is not 20:10) — still open, still
owned by Luca, and deliberately untouched here.

**No verdict has been made. The owner's play session is what closes this gate.**


---

## 9. What is NOT done

- **No owner verdict.** The camera-and-feel gate is open. Nothing here closes it, and
  the ticket's `Status: open` is unchanged.
- **No frame-rate claim, and none is possible from this evidence.** Every frame was
  rendered on Mesa llvmpipe software GL under Xvfb, on a GPU-less host. These images
  are correctness and composition evidence only.
- **No art direction is locked.** No new palette, no new asset, no new prop, no
  change to any arena.
- **Nothing in the game was changed.** `godot/game/**`, `godot/src/**`, `js/**`,
  `scripts/**` and `godot/project.godot` are untouched; `run/main_scene` is
  unchanged. The HUD variants are applied at runtime, from the study scene, through
  the HUD's own anchors, offsets and theme overrides.
- **One tick, one seed, one arena, one tier.** Everything is measured at tick 420 of
  seed 20260916, tier 3, on the default arena. A second tick would move the players;
  that is exactly why option 4's criterion is the near baseline rather than the
  players' positions.
- **Glass readability is not measured.** The ID pass hides the glass cage, so a body
  behind a translucent pane counts as fully visible. In the beauty frame it is
  dimmed. Whether that dimming is acceptable is an eye question, not a pixel one.
- **Motion, input latency and "feel" are not measured.** Static frames cannot answer
  the half of the ticket that says *feel*. Only the play session can.
