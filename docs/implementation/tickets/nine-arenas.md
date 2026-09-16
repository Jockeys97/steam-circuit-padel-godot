# Nine arenas in 3D (slice S6)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [3D camera and feel integration into the slice](camera-feel-integration.md) technically — an arena is drawn for a camera, and the camera composition is not decided until that slice lands. Acceptance is additionally blocked by [Arena art direction](../../wayfinder/tickets/arena-art-direction.md) (open, HITL, owner Luca), which decides per arena whether it is rebuilt as geometry, reused as painted artwork, or sent down the Meshy lane, and by the open court-aspect question, which fixes the court's real-world proportions and therefore the size everything around it is built to. One arena may be built as proof now; the slice may not be called done.

This ticket implements row S6 of `docs/implementation/PLAN.md` ("Nine arenas in 3D"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S7 through S13.

## Objective

Give the port its nine arenas — `officina`, `locomotive`, `clockwork`, `cattedrale`, `forgia`, `tempesta`, `abissale`, `caldera`, `orrery` — each recognisable as a distinct place in real 3D, each carrying its own frozen `wallBounce` and its own palette, and none of them bought with credits. The work is built one arena at a time: the first arena is the proof that the route works and stops for a look, then the remaining eight follow the proven route. Nothing here is approved as the final art direction, because that decision is open; what this slice delivers is one working arena, a per-arena route that the decision can then confirm or replace, and the audit that keeps the nine distinct and correctly parameterised.

Two facts shape the work, both read from the source rather than assumed:

- The web build draws arenas as painted backdrops in a fabricated perspective, with a screen-space scenery clip. There is no 3D art to convert. The port either reuses those painted images as textures and skyboxes, or builds geometry — and that is exactly the open decision.
- Two of the nine arenas reuse another arena's image file. `cattedrale` points at `assets/arenas/deposito-locomotive.webp` and `forgia` points at `assets/arenas/clockwork-factory.webp`, so there are seven image files for nine arenas. A 3D rebuild that gives each arena its own look must not read the shared path as "these two are the same place".

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/data.js:560-661` | `ARENAS`, the nine entries, in order: `officina` (`:562`), `locomotive` (`:571`), `clockwork` (`:580`), `cattedrale` (`:589`), `forgia` (`:599`), `tempesta` (`:609`), `abissale` (`:619`), `caldera` (`:629`), `orrery` (`:639`) |
| `js/data.js:566, 575, 584, 593, 603, 613, 623, 633, 643` | The nine `wallBounce` values: 0.89, 0.92, 0.86, 0.94, 0.83, 0.95, 0.84, 0.88, 0.93. **Simulation data**: they enter the simulation at `js/game.js:2272` and `:2284`. Not this slice's to change |
| `js/data.js:568` | The per-arena `palette` object (`floor`, `accent`, `gear`) — the colours a 3D arena must carry, and the data the HUD already uses at `js/render.js:1613` |
| `js/data.js:565, 574, 583, 592, 602, 612, 622, 632, 642` | The `image` field per arena. `cattedrale` and `forgia` share another arena's file; the remaining seven are distinct |
| `assets/arenas/officina-vapore.webp`, `deposito-locomotive.webp`, `clockwork-factory.webp`, `bastione-tempesta.webp`, `santuario-abissale.webp`, `caldera-titano.webp`, `orrery-celeste.webp` | The seven painted backdrops on disk. These are the reuse-as-texture candidates, and no new art may be generated to replace them |
| `js/render.js:694` | `export function drawArena(ctx, canvas, arena, time)` — the single entry point that draws an arena in the web build |
| `js/render.js:696` | `const scene = arena.id ?? "officina"` — the arena id selects the fantasy backdrop variant, so the nine are drawn by id and not by palette |
| `js/render.js:702` | `drawFantasyArenaBackdrop(ctx, canvas, scene, time, arena.image)` — the painted-image path |
| `js/render.js:451` | `drawArenaArtwork(ctx, canvas, imagePath, time)` — how the image is drawn and animated |
| `js/render.js:481` | `clipArenaScenery(ctx)` — the screen-space scenery clip the scenery audit inspects |
| `scripts/arena-scenery-audit.mjs:9-21` | What that clip guarantees today: the renderer must contain `function clipArenaScenery(ctx)` (`:9`), the rect `ctx.rect(0, 0, 960, 96)` (`:11`), the two safe-zone edges `ctx.lineTo(48, 700)` and `ctx.lineTo(912, 700)` (`:13`, `:15`), exactly two safe-zone uses (`:19`), and no `evenodd` clip (`:21`) |
| `js/data.js:1-8` | `COURT` — the 800 x 508 px logical field every arena is built around |
| `GAMEPLAY_RULES.md:9-15` | The scale section: the logical field is a 20 x 10 metre rectangle, the net splits two halves, the ball uses `x/y` horizontally and `z` for height, and the glass rules. The 20 x 10 figure conflicts with `COURT`'s 1.575 aspect and is **open** |
| `godot/src/sim/frozen.gd` (`arenas()`) and `godot/src/sim/frozen/data.json` (`arenas`, nine entries) | The ported arena table — the same nine rows, verbatim, including `floorGrip`, which nothing in `js/` reads and which is carried as data without inventing behaviour for it |
| `godot/src/view/CourtMesh.gd` and `CourtMesh.tscn` | The court mesh built by [Quick-match vertical slice in 3D](quick-match-slice.md) from `COURT` under one uniform scale. This slice reuses it and does not rebuild the court |
| `godot/prototypes/arena_spike/arena_playable_1280x720.png` and `render.sh` | The working capture route and the composition the arena proof is rendered in |
| `docs/wayfinder/evidence/camera-spike-render.md` | The measured court dimensions under the 0.025 m/px scale (20.00 x 12.70 m, net 0.95 m), the proof that the aspect question is real, and the note that the spike contains no arena work |

The seam this slice sits next to: `godot/src/view/` is shared with [3D camera and feel integration into the slice](camera-feel-integration.md) and [Quick-match vertical slice in 3D](quick-match-slice.md). This ticket owns the arena files and nothing else in `godot/src/view/`; `CourtMesh.gd` keeps its owner. The locale seam (`godot/src/locale/**`) owns arena names and descriptions, which are keys today (`nameKey`-style ids in the data), and this slice does not add strings.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/arena/ArenaData.gd` — the reader that turns `frozen.gd`'s nine rows into the shape the view needs (`id`, palette, `wallBounce`, image path), with no re-typing of any value
- `godot/src/arena/ArenaScene.gd` and `godot/src/arena/ArenaScene.tscn` — the arena container: backdrop, floor, glass, net posts, lighting and palette, parameterised by arena id
- `godot/src/arena/routes/texture_route.gd` — the reuse-the-painted-artwork route: the seven images as skybox/backdrop textures with palette-driven tinting, and the per-arena variation that keeps the two image-sharing arenas visibly distinct
- `godot/src/arena/routes/geometry_route.gd` — the geometry route, written only if the art-direction decision names it for a given arena. Until that decision lands, this file exists as an interface with no arena bound to it
- `godot/src/arena/palettes.gd` — the nine palettes exported from `js/data.js:568` and its siblings, generated, not hand-typed
- `godot/tests/arena_matrix_audit.gd` and `godot/tests/arena_matrix_audit.tscn` — the ported replacement for the screen-space scenery audit: nine arenas load, each carries its own `wallBounce` and palette, no two are pixel-identical, and each renders without a script error
- `godot/tests/arena_wallbounce_audit.gd` and `godot/tests/arena_wallbounce_audit.tscn` — proves the frozen `wallBounce` values are live by driving one rally per arena through the simulation and asserting the ball's post-wall speed scales with the arena's own value
- `godot/tests/capture_arenas.gd` — the capture harness, one 1280x720 frame per arena
- `godot/shots/arena-<id>.png` for the nine ids, plus `godot/shots/arena-proof.png`, and an append to `godot/shots/README.md`
- `docs/implementation/evidence/s6-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `assets/` (read-only: the seven painted images are reused, never regenerated or repainted — spend is zero), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md); `wallBounce` is read from `frozen.gd` and never re-declared), `godot/src/view/CourtMesh.gd`, `godot/src/view/CameraRig.gd` and `godot/src/view/camera/**` (owned by [3D camera and feel integration into the slice](camera-feel-integration.md)), `godot/src/ui/**`, `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/input/**`, `godot/prototypes/` (read-only), and every Meshy path — no arena goes through the Meshy lane without Luca naming the arena and the spend.

## Inputs and outputs

Inputs:

- The nine arena rows from `frozen.gd`, verbatim, each with `wallBounce`, `floorGrip`, `palette`, `image` and its unlock metadata. `floorGrip` is carried and not interpreted: nothing in `js/` reads it, and inventing a physics role for it is new behaviour.
- The court mesh and the uniform root scale recorded by the quick-match slice. This slice does not change the scale and does not resolve the aspect conflict; it states the scale it built under.
- One camera preset from the camera slice, applied identically to all nine captures so the arenas are compared under one composition.
- The seven painted images on disk, reused as textures. No generation, no repainting, no Meshy call.

Outputs:

- One arena built as proof — the recommended default in `PLAN.md` starts from the painted artwork route with the arena's own palette driving the tint, which is a proposal and not a decision — rendered, captured and written up before the remaining eight start.
- The remaining eight following whichever route the art-direction decision names, one at a time, each captured under the same camera preset.
- Nine arenas whose simulation-visible parameter (`wallBounce`) is provably the frozen one, and whose visual identity is provably distinct from the other eight.
- A per-arena route table: arena id, route taken, artwork or geometry source, palette source line, `wallBounce`, and the one-line reason. This table is the artifact the art-direction verdict is taken on.

Explicitly not output: any new arena, any repainted artwork, any Meshy credits spent, any change to `wallBounce` or `floorGrip`, any change to the court mesh or its scale, and any claim that the art direction is settled. The ninth arena is not "the last one squeezed in" — it is the same route applied once more, and if it does not fit the route it is reported as a route finding.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/arena-scenery-audit.mjs` — the audit that guards the screen-space scenery clip today (`:9-21`). It is screen-space and cannot port to 3D, so it is the one audit in this port that is genuinely **replaced** rather than translated: its promise — the scenery never covers the safe play area, and the clip is applied exactly twice, not by an `evenodd` fill rule — becomes a 3D assertion that the backdrop geometry stays outside a declared safe volume around the court, and that the safe volume is defined once and consumed by everything that draws around the court. The JavaScript audit stays green and untouched; the port does not delete it.
- `scripts/assets-audit.mjs` — the Godot equivalent is load-time: the arena matrix audit fails if any arena's backdrop texture path does not resolve.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors, which the matrix audit also covers for the nine new scenes.
- `scripts/court-speed-audit.mjs` — a control, not a gate: `wallBounce` enters the simulation, so a red `court-speed` would mean the arena work touched simulation data. It must stay green.

Godot-side equivalents:

- `godot/tests/arena_matrix_audit.gd` — loads all nine arena scenes; asserts each carries its own palette read from `frozen.gd` and its own `wallBounce`; asserts the two image-sharing arenas are not visually identical (a rendered hash of the frame differs); asserts the backdrop never intersects the declared safe volume around the court; prints `ok`/`FAIL` per arena and `PASS n/n`.
- `godot/tests/arena_wallbounce_audit.gd` — for each of the nine, drives one scripted rally into the arena's own wall and asserts the post-wall horizontal speed ratio matches the arena's `wallBounce` within the tolerance the parity gate definition allows. Until that gate lands, the audit asserts the ordering (a higher `wallBounce` yields a faster post-wall ball) and records the exactness question as open.
- `godot/tests/capture_arenas.gd` — one 1280x720 frame per arena, under one camera preset, with the arena id, the palette source lines, the route and the software-GL caveat in the log.
- `godot/tests/arena_proof_audit.gd` — the proof-arena subset, run first and fast, so the route is proven before eight more arenas are built on it.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. A capture needs a real rendering context — `--headless` installs the dummy driver and the frame is blank — so the render route is `xvfb-run` plus an explicit rendering driver, as the prototype render scripts use it.

The arena matrix, headless:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/arena_matrix_audit.tscn > docs/implementation/evidence/s6-arena-matrix.log 2>&1; \
  echo "exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s6-arena-matrix.log
```

The `wallBounce` liveness audit:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/arena_wallbounce_audit.tscn > docs/implementation/evidence/s6-wallbounce.log 2>&1; \
  echo "exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s6-wallbounce.log
```

One capture per arena, under one camera preset:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  for id in officina locomotive clockwork cattedrale forgia tempesta abissale caldera orrery; do \
    flock -w 900 /tmp/padel-godot.lock \
    env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
      /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
      res://tests/capture_arenas.tscn -- --arena=${id} --preset=playable \
      >> docs/implementation/evidence/s6-capture.log 2>&1 || echo "CAPTURE FAILED: $id"; \
  done; echo "done"
```

The frozen data this slice must not change, printed for the record:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  sed -n '560,661p' js/data.js | grep -E 'id:|wallBounce:' && \
  python3 -c "import json;d=json.load(open('godot/src/sim/frozen/data.json'));print(len(d['arenas']),[a.get('wallBounce') for a in d['arenas']])"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && node scripts/arena-scenery-audit.mjs; echo "scenery exit=$?"
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s6-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s6-arena-matrix.log` — nine arenas loaded, each with its own palette and `wallBounce`, the distinctness check and the safe-volume check, one `ok`/`FAIL` line per arena and `PASS n/n` with the exit code.
- `docs/implementation/evidence/s6-wallbounce.log` — the per-arena wall scaling check, with the ordering asserted and the exactness question marked open.
- `docs/implementation/evidence/s6-capture.log` — one line per arena: id, route, palette source line, `wallBounce`, camera preset, tick, rendering driver and output path.
- `godot/shots/arena-officina.png` and the other eight `godot/shots/arena-<id>.png`, plus `godot/shots/arena-proof.png` — 1280x720, all under the same camera preset, so the nine are comparable.
- `godot/shots/README.md` — appended: which preset and which uniform court scale each arena capture used, and the software-GL caveat.
- `docs/implementation/evidence/s6-arena-route-table.md` — arena id, route taken, artwork or geometry source, palette source line, `wallBounce`, and the one-line reason. For the two arenas that share an image file, the note that the shared path is not the same place, with the variation that makes them distinct.
- `docs/implementation/evidence/s6-proof-arena.md` — the proof arena: what was built, under which route, how long it took, what it proves, and what the remaining eight will reuse. This is the artifact the art-direction verdict is taken on.
- `docs/implementation/evidence/s6-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a capture list without the per-arena log line; a distinctness claim supported by a palette diff alone when the two arenas share an image file; any statement that the art direction is decided; and any frame-rate claim, because this host has no GPU.

## Failure and recovery criteria

Red means any of these:

- The matrix audit or the `wallBounce` audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- An arena's `wallBounce` differs from `js/data.js`, or any arena re-declares its own copy of a frozen number instead of reading `frozen.gd`.
- Any arena changes `COURT`, the court mesh or its scale, or resolves the court-aspect conflict inside an arena file.
- `floorGrip` gains behaviour. It is unread in `js/` and is ported as data.
- Two arenas render identically, or an arena is missing from the matrix.
- A capture run exits non-zero or writes a blank frame because it went through the dummy driver.
- The slice generates, repaints or purchases artwork, or calls the Meshy lane, without Luca naming the arena and the spend.
- A file outside the allowlist changes, or `js/`, `scripts/` or `assets/` changes at all.
- A frame-rate or target-hardware claim appears in the evidence.

What stops the slice: a red audit after the retry rule below; the art-direction decision rejecting the painted-artwork route after the proof arena is built, in which case the proof is re-done on the named route rather than patched; or the court-aspect decision landing in a form that resizes the court, in which case the arena work waits rather than being rebuilt twice.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the matrix audit reads the palette through `ArenaData.gd` and not from a duplicated table; confirm the two image-sharing arenas differ by a rendered hash and not only by tint; confirm the capture loop's `--rendering-driver opengl3` sits under `xvfb-run` and not under `--headless`; confirm the wall audit compares post-wall speed within the same arena across two runs before comparing across arenas, so a nondeterministic scenario is not read as a data error.

Replacing an audit is a red flag that must be stated, not glossed: `arena-scenery-audit.mjs` is the only audit in this port that is replaced rather than translated, and the replacement is justified by the medium (screen-space clip versus 3D safe volume) and recorded in the evidence, not by the audit being inconvenient.

## Human gates that block this slice (open, owner Luca)

- **Arena art direction** — per arena, whether it is rebuilt as geometry, reused as painted artwork, or sent through the Meshy lane, and what makes nine distinct places once the fake perspective is gone. This slice builds one proof arena on the recommended default (reuse the existing painted artwork as textures or skybox, no Meshy spend) and presents the route table; it does not decide, and no slice is declared complete on the proof alone.
- **Court aspect** — `COURT` is 800 x 508 px = 1.575, not 20:10, and the px-to-metre scale is undecided. Every arena's real-world size follows from it. This slice states the scale it built under and does not resolve the conflict.
