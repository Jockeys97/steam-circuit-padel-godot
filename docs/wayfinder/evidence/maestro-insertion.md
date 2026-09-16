# Il Maestro inserted as the second real athlete — Mac-side record

Committed on the owner's Mac (macOS 27, Apple Silicon), engine
`/Applications/Godot.app/Contents/MacOS/Godot`, version `4.7.2.stable.official.ed1daf0bf`
(the version the mission pins). Every engine command ran headless, one engine process at a time
(`pgrep -fl Godot` checked before each run), fresh session per command, from the repository root.
This host has no `flock`, no `xvfb-run` and no `timeout` binary, so `godot/game/run.sh` was NOT
used: the engine was invoked directly, which is what the hand-off prescribes for the Mac.

Source pack: `maestro-asset-pack-20260916/maestro-asset-pack/` (assembled on the Linux side);
`INSERT-NOTES.md` read first as the operative spec, plus `RESULT.md` and `hashes.json`.
An independent byte-level verification of the same pack, produced by a separate task while this
insertion ran, is `docs/wayfinder/evidence/maestro-pack-verify.md` (copied unchanged; sha256
`06a61bc4c7d0671523332ae0b7f91293844fa226ad4c4fafa6a1316c0e7be153`). Its findings agree with the
engine wherever they overlap and are cited below where they disagree with the pack's prose.

## 1. The four GLBs, copied and hash-checked in the repo

| File (in `godot/assets/athletes/`) | Bytes | sha256 recomputed in the repo | matches `hashes.json` |
|---|---|---|---|
| `maestro-rigged.glb` | 9,974,896 | `f314518555bde367bd8971bb1933d5c1a0ae01e50ab4a9c61f52676402b6496e` | yes |
| `maestro-idle.glb` | 10,023,848 | `48430822f3621baf54ec5e780f390dbef46772903e771c5b05a3d6c2af9872b8` | yes |
| `maestro-walking.glb` | 9,987,672 | `d742f4597d6dada3bc4493735a162c816e7f42c988dfcdfe13f353ab0503dba8` | yes |
| `maestro-running.glb` | 9,983,076 | `f7f98512d5474a2c0d5e294355f22340444faec7b20a49060eeb97737a63a79b` | yes |

Recomputed with `shasum -a 256` after the copy; all four byte counts and digests match
`hashes.json` exactly. Godot's import pass then generated, for each GLB, the sidecar set the repo
already tracks for the Volpe files: `<name>.glb.import`, `<name>_texture_0.png` and its
`.import` (12 files; the embedded base-colour texture extracted). No `_normal` or
`_metallic_roughness` maps were produced for the Maestro files — the exports carry one texture.

Deliberately NOT copied from the pack: `maestro-texture.png` (7,411,125 B) and the two
thumbnails. The texture is embedded in all four GLBs (verified in engine: one material, one
2048x2048 albedo texture per file) and nothing in the port reads a standalone texture file; the
PNG would have been a 7.4 MB duplicate.

## 2. What the engine measured (structure, all four GLBs)

Probed with a throwaway `res://tests/` script (deleted with its `.gd.uid` before the commit),
loading each GLB through the same `GLTFDocument` path the rig uses:

| File | joints | triangles | surfaces | embedded clip | clip length | Armature scale |
|---|---|---|---|---|---|---|
| `maestro-rigged.glb` | 24 | 30,980 | 1 | `Armature\|clip0\|baselayer` | 0.300000 s | (0.01, 0.01, 0.01) |
| `maestro-idle.glb` | 24 | 30,980 | 1 | `Armature\|Idle\|baselayer` | 4.033333 s | (0.01, 0.01, 0.01) |
| `maestro-walking.glb` | 24 | 30,980 | 1 | `Armature\|walking_man\|baselayer` | 1.066667 s | (0.01, 0.01, 0.01) |
| `maestro-running.glb` | 24 | 30,980 | 1 | `Armature\|running\|baselayer` | 0.666667 s | (0.01, 0.01, 0.01) |

All four share one 24-joint humanoid skeleton in the same names and order as the Volpe rig
(Hips … `headfront`). Every claim in the pack's table reproduces in engine; the rigged file's one
clip is the 0.30 s single-key bind hold, NOT an idle — the wiring below makes sure it can never
be aliased into the idle slot.

## 3. Material override: per-athlete state BEFORE and AFTER (the ripple, shown not hidden)

The emission-off change lives in `set_outfit()`'s override block, which is shared by every
athlete, so each athlete's state was measured both before and after the edit (same throwaway
probe, same run shape). Values read off the material objects, not from cached variables:

| Athlete (rig path) | GLB base material | override BEFORE | override AFTER |
|---|---|---|---|
| Volpe fallback (`steamer`) | emission ON, `emission=(1,1,1)` with the base texture as emissive map; metallic 1.0000, roughness 1.0000 | emission **true**, metallic 0.0000, roughness 0.8500, albedo 2048x2048 | emission **false**, metallic 0.0000, roughness 0.8500, albedo 2048x2048 |
| Colosso | emission OFF, `emission=(0,0,0)`, no emissive map; metallic 1.0000, roughness 1.0000 | emission **false**, metallic 0.0000, roughness 0.8500, albedo 2048x2048 | emission **false** (unchanged), same otherwise |
| Maestro (unwired → wired) | emission ON, `emission=(1,1,1)` with the base texture as emissive map; metallic 1.0000, roughness 1.0000 | (id not wired: the same id fell back to Volpe, emission true) | emission **false**, metallic 0.0000, roughness 0.8500, albedo 2048x2048, digest `354aac585d12727b` |

- The ripple is real and visible: the Volpe-fallback override flips emission on → off, exactly as
  the Meshy-emissive defect requires; Colosso never had the defect (its GLB carries emission off)
  and is therefore unchanged; Maestro, the athlete the change was made for, ends with emission
  off, metallic 0, roughness 0.85 and its baked albedo texture kept.
- Revertibility measured: `use_glb_pbr(true)` on the wired Maestro rig reports emission **true**,
  metallic 1.0000, roughness 1.0000 — the block is the documented non-glTF default, so the
  "render exactly what the GLB asks for" escape hatch still works.
- Where the change applies: `AthleteRig.set_outfit()` sets `emission_enabled = false` on the
  duplicated override material, in the same `if not _use_glb_pbr:` block as the existing
  metallic/roughness overrides. `get_material_state()` gained an `"emission"` field so the new
  gate can assert it.
- Ripple boundary, stated plainly: for the catalogue-recolour athletes (all but Colosso/Maestro)
  `AthleteSpawn.make()` runs `OutfitCatalogue.apply()` AFTER `set_outfit()`, replacing the
  StandardMaterial3D override with the recolour `ShaderMaterial`. That shader was not touched by
  this change and keeps its own `pbr_metallic` / `pbr_roughness` uniforms. In-match, the
  emission-off override is what the Maestro player rig renders with.
- One pack-note nuance: the notes' "both rigged files carry" the emissive defect is true for
  Volpe and Maestro, but Colosso's export already carries emission off (engine-measured) —
  recorded so the "both" phrasing is not read as "all Meshy exports".

## 4. Root scale: kept at 0.01 — measured, no fix applied

Measured through `AthleteRig.get_world_extent()` (bone-pose walk, correct headless):

- World extent of the wired Maestro rig: min `(-0.3995, 0.0392, -0.0939)`, size
  `(0.7974, 1.7610, 0.1961)` → **height 1.760989 m**, **feet min Y 0.039219 m** — an athlete,
  not a scaled rig. The Armature root scale stays 0.01 as the notes require; nothing was changed.
- Facing verified in engine from the skeleton itself: the `headfront` marker bone sits
  +0.1145 m in Z from `Head`, and `LeftToeBase` sits +0.1172 m in Z from `LeftFoot` —
  **front is +Z**, same convention as Volpe. Both numbers are asserted by the new gate.
- Contradictions found, engine trusted (both recorded, neither acted on):
  1. The notes estimate "world height about 1.59 m"; the engine measures **1.761 m** (bone-pose
     extent, head_end at 1.800208). The independent pack report independently fails to
     reproduce 1.59 m as well (its candidates: 1.799999 m with the scale kept, 180.000 m
     predicted if the 0.01 were stripped) — see its section 6. The 158 m figure does not
     reproduce either (180 m predicted, and the engine never saw a stripped scale).
  2. The hand-off's expected window "1.45–1.75 m" is clipped by the measurement by 11 mm. The
     gate therefore asserts the measured reality: a band of 1.45–1.80 m, which still separates
     a human athlete from a ~158 m dropped-scale rig. The measured value is printed on every
     run, so no window is doing the reporting.

## 5. Wiring, and what the match line now says

- `athlete_rig.gd`: `ATHLETE_GLB` gained `maestro → res://assets/athletes/maestro-rigged.glb`;
  a new `COMPANION_CLIPS` table maps maestro's `idle/walk/run` to the three companion GLBs;
  `_glb_idle_path` is filled in `set_athlete_asset()`; `_build()` adopts `CLIP_IDLE` from that
  companion BEFORE the first-embedded-clip fallback, so the 0.30 s bind hold can never become
  the idle. Volpe behaviour is byte-for-byte unchanged (its base path still selects
  `GLB_WALK`/`GLB_RUN`; other athletes with no table entry keep their old empty paths).
  `GLB_BASE`, `GLB_WALK`, `GLB_RUN` and `court.gd`'s `GLB_PATH` are untouched — the slice's own
  assertion that `AthleteRig.GLB_BASE == Court.GLB_PATH` still passes.
  The rebase onto the moved `origin/main` kept upstream's freshly renamed Colosso entry
  (`res://assets/athletes/colosso.glb`) and added the Maestro line beside it; that one hunk was
  the whole merge conflict.
- After the change the wired rig reports idle 4.033333 s, walk 1.066667 s, run 0.666667 s,
  30,980 triangles, 24 joints, one surface.
- The quick-match log line, verbatim from the slice run (three runs agree except `spawn_ms`):

```
ATHLETES rigs=4 source=res://assets/athletes/volpe-rigged.glb glb_loads=12 spawn_ms=4777 lineup={"opponent":"steamer","opponentMate":"fiamma","player":"maestro","playerMate":"pantera"}
```

  The **player** slot is `maestro` and its rig now serves the Maestro GLB: the slice's own
  athlete dump for `player` reports `athlete_asset: "maestro"` and `triangles: 30980` (the other
  three roles — pantera, steamer, fiamma — still report the Volpe placeholder, 31,325 triangles,
  as designed: one real athlete at a time). Two caveats stated rather than glossed: the line's
  `source=` field prints the rig's compatibility constant (`GLB_BASE`, still Volpe), not the
  per-rig mesh — the `lineup=` field and the per-rig dump are what prove which body a role
  wears; and `glb_loads=12` is `spawned × 3`, a fixed accounting in `match_controller.gd`, not a
  live parse count — with Maestro wired the true count is 13 (three Volpe rigs × 3 files, plus
  Maestro's base + three companions). Neither field was reworded by this lane.

## 6. Gates (exact commands, exit codes, verbatim tally lines)

All from the repository root, `export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`,
`GODOT_SILENCE_ROOT_WARNING=1`, one engine process at a time:

| # | Command (tail) | Exit | Tally line | SCRIPT ERROR count |
|---|---|---|---|---|
| 1 | `"$GODOT" --headless --path godot/ --import` | 0 | (import pass; four Maestro GLBs) | 0 |
| 2 | `"$GODOT" --headless --path godot/ --script res://tests/maestro_asset_test.gd` | 0 | `PASS 34/34` | 0 |
| 3 | `"$GODOT" --headless --path godot/ --script res://tests/colosso_asset_test.gd` | 0 | `PASS 19/19` | 0 |
| 4 | `"$GODOT" --headless --path godot/` (the run.sh harness gate) | 0 | `PASS 8/8` | 0 |
| 5 | `"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd` | 0 | `PASS 292/292` (292 `ok` lines, 0 `FAIL`) | 0 |

These five runs are the ones measured on the FINAL tree — the insertion commit after the rebase
onto the moved `origin/main` (`8fed1da`). `origin/main` had gained two commits while this
insertion was being written, so the hand-off's rule was followed: the remote/local comparison was
done first, the insertion was rebased, the one conflict resolved (`ATHLETE_GLB`, above), and the
whole gate sequence was then re-run on the rebased tree. Tallies changed in exactly one place:
the Colosso gate is upstream's own grown version (19 checks, was 10) — gates 1, 2, 4 and 5 came
back identical, and the Maestro gate's printed `MEASURED` values are byte-identical before and
after the rebase, which is the reproducibility check for §2–§4. The slice was run twice and
returned `PASS 292/292` both times. No `PASS` line ever sat next to a `SCRIPT ERROR`.

New focused gate `godot/tests/maestro_asset_test.gd` (`PASS 34/34`) asserts, printing every
measured value: spawns through `AthleteSpawn.make(&"maestro", &"base")`; `athlete_asset` =
maestro; `load_error` OK; joints 24 with the exact measured bone names/order; triangles 30,980;
one surface; idle/walk/run registered with the measured lengths inside tolerant windows
(4.033 ± 0.10 / 1.067 ± 0.05 / 0.667 ± 0.05 — tight enough that the 0.30 s bind hold can never
pass as an idle); each locomotion clip plays; the walk clip actually moves the skeleton
(23 bones changed between t=0.05 s and t=0.55 s, max joint rotation delta 53.7631°); all four
authored strokes exist, `play_stroke(&"drive")` is true and the drive stroke moves the skeleton
(9 bones, max 58.0961°); world extent height 1.7610 m in the 1.45–1.80 band and feet 0.0392 m
within ±0.08 m of the floor; `headfront`/toe facing +Z; material state emission off, metallic 0,
roughness 0.8500, albedo texture 2048x2048 present.

NOTE on the hand-off's pack expectations: the brief expected two red/skipped pack checks and a
278/280 tally because `godot/build/linux-x86_64/padel.pck` is absent. At this commit that does
NOT reproduce, and the difference is not from this insertion: `42aafa5` (already on `main`)
reworked the pack check, and the slice now prints, verbatim:

```
# PACK_MODE full=res://build/linux-x86_64/padel.pck absent (source checkout) — pack-content checks not run, not scored
# PACK_MODE demo=res://build/linux-x86_64-demo/padel-demo.pck absent (source checkout) — pack-content check not run, not scored
```

so a source checkout scores 292/292 with the pack checks explicitly not run (and a present but
broken pack still fails them). `godot/build/` still does not exist on this host.

## 7. Cross-lane notes (origin/main moved while this insertion ran)

- Two upstream commits landed during this work: `2f7b538` (the frozen athlete standard:
  `docs/art/character-standard.md`, `docs/art/roster-3d.json`, the Colosso GLB renamed to
  `colosso.glb`, new prototypes and a standalone validator) and `8fed1da` (Colosso's racket
  mounted on the `RightHand` bone). This insertion was rebased onto both, as the hand-off
  requires, and re-gated (§6).
- Naming tension, recorded and not acted on: the fresh standard's rule is "file names are roster
  ids"; its validator checks `base.startswith(<id>)`, which `maestro-rigged.glb` satisfies, and
  its preferred game-asset spot is `godot/assets/athletes/<id>.glb` on the 28-joint
  `mixamorig:` skeleton. The Maestro pack is the older 24-joint export with plain bone names —
  the same class the roster calls "fuori standard" for `pantera` — and this lane's brief fixed
  the four file names, so the names stayed as briefed. `docs/art/roster-3d.json` still lists
  `maestro` as `assente` with a null GLB; it was NOT updated by this lane (outside its
  allowlist, and whether Maestro is re-rigged on the new standard is an owner/lane decision).
- Racket interplay: `8fed1da`'s `make_standard_bone_attachment()` deliberately rejects rigs
  whose bones do not carry the `mixamorig:` prefix, so the Maestro player rig keeps the legacy
  body-relative racket placement while Colosso rides the wrist. The final slice run passes both
  shapes.

## 8. Not copied, not measured, not claimed

- `maestro-texture.png` and the thumbnails: intentionally not copied (see §1).
- **No pixels and no frames were produced on this Mac.** The visual read — does Il Maestro look
  right, is the walk readable, do the hands/feet hold up at 30,980 triangles — is the owner's
  verdict and is NOT claimed here. The interactive game was not launched (the hand-off hands
  that to the owner).
- Not re-run this session: the demo-variant slice, the saves/input/audits/music suites (they were
  not touched by this change and were green at the last recorded sweep), any performance
  measurement, and any DCC inspection of the mesh.
- The import pass also generated three `.import` sidecars for untracked arena `.webp` art
  (`godot/game/arenas/art/*.webp.import`); those are left untracked exactly as found. The same
  pass generated Colosso sidecars under the GLB's then-current file name
  (`colosso-solar-titan-all-animations.glb.*`); those are NOT part of this commit — the rebase
  adopted upstream's rename to `colosso.glb` together with upstream's own sidecar set, and the
  obsolete local files were deleted before the commit.

## 9. Files changed in this insertion

- `godot/assets/athletes/maestro-rigged.glb`, `maestro-idle.glb`, `maestro-walking.glb`,
  `maestro-running.glb` + each one's `.glb.import`, `_texture_0.png`, `_texture_0.png.import`
  (12 generated files).
- `godot/src/character/athlete_rig.gd` (asset table, companion-clip table, idle adoption,
  emission off, `get_material_state()` emission field).
- `godot/tests/maestro_asset_test.gd` + its generated `.gd.uid`.
- `docs/wayfinder/evidence/maestro-insertion.md` (this file) and
  `docs/wayfinder/evidence/maestro-pack-verify.md` (independent report, copied unchanged).
- `docs/mission/LOG.md` (one appended entry).
- (No Colosso files: the remote's `2f7b538` renamed the GLB to `colosso.glb` and committed its
  own sidecar set, which the rebased tree carries.)

## 10. Hand-off handles

- Insertion commit: `91941e8cdeda463a0c4f413e4135aa25c06bde94` — "feat: integrate Il Maestro
  Meshy athlete" (rebased onto the moved `origin/main`; the single `ATHLETE_GLB` hunk was the
  only conflict).
- Push verification: `git ls-remote origin -h refs/heads/main` returned
  `91941e8cdeda463a0c4f413e4135aa25c06bde94` and `git rev-parse HEAD` returned the same value —
  remote head equal to local HEAD, checked after the push (pre-push the remote stood at
  `8fed1da36cc914be748d0b843746e2abea37392e`, so the push went out as the usual fast-forward
  after the rebase).
- This follow-up documentation commit corrects the final tallies and carries these handles; its
  own push was verified the same way (remote head equal to local HEAD at push time).
