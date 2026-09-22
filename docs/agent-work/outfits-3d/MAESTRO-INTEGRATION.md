# MAESTRO — the three outfits in the real game

**Status: integrated and verified end to end, with one pre-existing defect reported
and deliberately NOT fixed, and one versioning decision flagged rather than taken.**

**Resumption note.** This lane was interrupted during its final verification pass.
On resumption the whole-court capture was re-read by a human and reported as *"four
athletes in two pairs, no two Maestro recognisable as wearing two different
outfits"*. That report was correct and is diagnosed and fixed in §4: the two
Maestro were dressed correctly and framed too far away to be judged. The proof is
now a labelled two-panel image in which each Maestro is 435 px tall instead of
80 px, and the two outfits are two printed, measured colours. **No `js/**`, no
progression logic, no balance and no colosso/oracolo file was touched.**

The three outfits (`circuit`, `legend`, `signature`) were already authored and
verified in the capture harness (`renders-maestro/`, 64 frames + lineup). This
document covers what was still missing for them to be part of the GAME: the
missing Godot import of the region mask, the wardrobe → save → court path, and a
capture taken from the real `Match.tscn` rather than from a harness-only scene.

Nothing was committed. No progression logic, balance or `js/**` was touched.
Colosso and oracolo were not touched (see §6 for the two unavoidable side effects
of running Godot's project-wide importer).

---

## 1. The missing `.import` — FIXED

### What was wrong

`OutfitCatalogue.profile_mask()` (`godot/src/character/outfit_catalogue.gd:573`)
deliberately falls back to reading the PNG straight off disk
(`FileAccess` + `Image.load_png_from_buffer`) when the importer has not run. Its
own comment says why: *"a mask that only loads after someone opens the editor is a
mask that silently does nothing"*. That fallback is a good safety net, but it also
means a mask with no `.import` **works in an editor session where the local cache
happened to generate one, and is fragile on a clean checkout or in an export** —
in an export `ResourceLoader.exists()` answers for packed imported resources, not
for source PNGs.

Fiamma had both sidecars on disk; Maestro had neither:

```
godot/assets/athletes/outfits/fiamma/fiamma_region_mask.png + .png.import
godot/assets/athletes/outfits/maestro/maestro_region_mask.png              (no .import)
```

### What was run

Godot's own importer, not hand-written `.import` files:

```
GODOT_SILENCE_ROOT_WARNING=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path godot --import
```

Exit code `0`. Exactly two files appeared, nothing else changed:

```
assets/athletes/outfits/maestro/maestro_region_mask.png.import
assets/athletes/outfits/maestro/maestro_region_mask_preview.png.import
```

### Proof it is aligned with Fiamma

The `[params]` block and the whole non-uid/non-path structure are **byte-identical**
to Fiamma's:

```
diff <(sed -n '/^\[params\]/,$p' .../fiamma/fiamma_region_mask.png.import) \
     <(sed -n '/^\[params\]/,$p' .../maestro/maestro_region_mask.png.import)   -> no output
```

and the mask now resolves as a **first-class imported resource**, in a headless
run as well as a windowed one
(`docs/agent-work/outfits-3d/evidence/maestro-mask-import-probe.log`):

```
MASK athlete=fiamma  exists=true has_import=true class=CompressedTexture2D size=2048x2048 handed_to_shader=true sha_prefix_declared=f176618b03f92216
MASK athlete=maestro exists=true has_import=true class=CompressedTexture2D size=2048x2048 handed_to_shader=true sha_prefix_declared=dc39e62c92bc5b8e
MASKS_OK
```

Maestro now answers exactly like Fiamma. `sha256` of the mask is
`dc39e62c92bc5b8e…`, matching the `mask_sha256_prefix` the profile declares.

`outfit_maestro_match_capture.gd` keeps this as a standing assertion
(`ResourceLoader.exists` + `load()` returning a `CompressedTexture2D` +
`.import` present on disk), so a future clean checkout that loses the sidecar
fails loudly instead of silently using the disk fallback.

### Correction to the task's premise

The task stated that for Fiamma *"entrambi tracciati in git"* (both the PNG and
its `.import`). **That is not what git says.** Fiamma's two `.import` files are
present on disk but **untracked**:

```
$ git ls-files godot/assets/athletes/outfits/
godot/assets/athletes/outfits/fiamma/fiamma_region_mask.png
godot/assets/athletes/outfits/fiamma/fiamma_region_mask_preview.png
godot/assets/athletes/outfits/strong-outfit-a.png.import      <- these ARE tracked
godot/assets/athletes/outfits/strong-outfit-b.png.import
godot/assets/athletes/outfits/weak-outfit-a.png.import
godot/assets/athletes/outfits/weak-outfit-b.png.import

$ git status --short godot/assets/athletes/outfits/
?? godot/assets/athletes/outfits/fiamma/fiamma_region_mask.png.import
?? godot/assets/athletes/outfits/fiamma/fiamma_region_mask_preview.png.import
?? godot/assets/athletes/outfits/maestro/
```

So `.import` tracking in this repo is already inconsistent:
**78 `.import` files tracked, 317 on disk.** `.import` files are *not* gitignored
(`git check-ignore` returns nothing for them), so this is an unforced
inconsistency, not a rule. Maestro's new sidecars are now in the same state as
Fiamma's: present on disk, structurally identical, untracked. **Making them
tracked is a repo-hygiene decision that spans both athletes and is left to the
owner** — I am not allowed to commit, and silently `git add`-ing would be a
decision taken on someone else's behalf.

### The 5 MiB diagnostic preview — FLAGGED, NOT DECIDED

The importer imports every PNG it finds under `res://`, so
`maestro_region_mask_preview.png.import` was generated along with the mask's. The
honest position on it:

* **nothing loads the preview at runtime.** Its only producer is
  `tools/character/build_maestro_outfit_mask.py:51`, which documents it as
  *"the same mask tinted, for eyeballing"* — a human-facing diagnostic.
* because it has a `.import`, Godot now imports it and an export will pack it:
  **5,195,732 bytes (5.0 MiB) of diagnostic PNG in the shipped build.**
* for Fiamma the *PNG* is tracked in git (its `.import` is not), so "coherence
  with Fiamma" points at tracking the PNG — which is exactly the 5 MiB in history.
* I did **not** delete the preview `.import`: deleting it only removes it until
  the next import run, which regenerates it. Keeping it out of the project
  requires an exclusion rule or moving the preview outside `res://` — a repo
  change beyond this lane's scope.

**Recommendation (owner's call):** version `maestro_region_mask.png` and its
`.import` only; drop the preview PNG and its `.import` for both athletes, or keep
the preview outside `res://`. I have taken no git decision either way.

---

## 2. The wardrobe — VERIFIED

Maestro is roster index 0, so `Config.athlete()` already defaults to him and the
existing `tests/ui/screen_characters_audit.gd` mounts HIS wardrobe.

Verified on an **isolated store** (`user://maestro-wardrobe-probe`); the real
profile under `user://save` was snapshotted before and after and is untouched:

```
MEASURED real profile before = {"career.json":588,"prefs.json":613}
MEASURED real profile after  = {"career.json":588,"prefs.json":613}
ok   the real profile under user://save is untouched
```

`godot/tests/_maestro_wardrobe_probe.gd` — temporary, run once, deleted; its
source is kept at `evidence/maestro-wardrobe-probe.gd.txt` and its raw output at
`evidence/maestro-wardrobe-probe.log`. **`MAESTRO_WARDROBE_PASS checks=51`, exit 0.**

What it establishes:

* the wardrobe opens on Maestro and lists `["base","circuit","legend","signature","mythic"]`;
* on a fresh career all three variants **start locked**, each with a card, each
  carrying a challenge, each **refusing** `equip_outfit`, each showing its
  challenge sentence (the `_outfit_unlocked` → `CareerRules.is_unlocked` path);
* once unlocked, each of the three shows its pick action and
  `equip_outfit("maestro", id)` **returns true**;
* each equip is **written to `career.equippedOutfits`** in the save and re-read
  from the store (`equippedOutfits.maestro == id`);
* the choice **survives a fresh screen mount**: `equipped_outfit_id("maestro")`
  still answers the last equipped id, and its card wears the selected frame.

**Re-run on resumption** — `MAESTRO_WARDROBE_PASS checks=51`, exit 0. The probe was
copied in from `evidence/maestro-wardrobe-probe.gd.txt`, run headless, and deleted
again together with its `.uid` (nothing left under `godot/tests/_maestro_*`). It
re-measured the real profile before and after as
`{"career.json":588,"prefs.json":615}` both times — same sizes, and the store it
works in is `user://maestro-wardrobe-probe`, so the wardrobe path is exercised
without the user's profile being written. Raw output: `evidence/maestro-wardrobe-probe.log`.

`tests/ui/screen_characters_audit.gd` mounts the same wardrobe screen on its own
isolated store (`user://uir11-characters-audit`, `Config.save_dir` set and restored
in that file) and passes 182/182 — see §7.

### 2b. One real UX quirk found (behaviour, not a bug I fixed)

`equip_outfit()` hands the screen back to the team panel, so the wardrobe must be
re-opened before another variant can be picked. That is the port's faithful
reading of `js/ui.js:903-911` and is identical for Fiamma — reported, not changed.

---

## 3. Unlocks — VERIFIED, and NOT changed

`ModesSave.award_match_outfits()` is the single shared award for quick, tournament
and career end-of-match (`match_controller.gd::_finish_quick_outfits`,
`mode_session.gd:330`). Maestro goes through it exactly like Fiamma:

```
MEASURED award_match_outfits(maestro) unlocked = ["maestro:circuit","maestro:legend","maestro:signature","maestro:mythic"]
MEASURED the same match won for fiamma = ["fiamma:circuit","fiamma:legend","fiamma:signature"]
ok   the same award unlocks fiamma:circuit (parity)      [x3 variants]
ok   the match counts one maestro win
```

The identical fixture was run against two separate isolated stores (one per
athlete), so the parity claim is not contaminated by shared state.

**No progression logic was modified.** `award_match_outfits`,
`CareerProgress.award_outfit_challenges`, `CareerRules` and the challenge tables
are untouched; this section only observes them.

---

## 4. The court — THE PROOF

`godot/tests/outfit_maestro_match_capture.gd` (new), modelled on
`outfit_fiamma_match_capture.gd`: it instantiates the real `res://game/Match.tscn`,
replaces the athlete view with the real `athletes_view.gd`, spawns through
`AthleteSpawn.make()`, drives the match's own `_sync_views()` and saves the
framebuffer.

```
GODOT_SILENCE_ROOT_WARNING=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --path godot --script res://tests/outfit_maestro_match_capture.gd
```

**Exit 0, 64/64 checks, zero failures.**
`OUTFIT_MAESTRO_MATCH_PASS rigs=4 profiled=3 base=1 panels=2`
Raw output: `evidence/maestro-match-capture.log`.

All four slots are Maestro so the three authored variants and the untouched `base`
are visible in one frame: `player=circuit`, `playerMate=legend`,
`opponent=signature`, `opponentMate=base`.

Three images are written, all of them the real scene (`res://game/Match.tscn`, the
real `athletes_view.gd`, the real `AthleteSpawn.make()`, the real `_sync_views()`):

| file | what it is |
|---|---|
| `evidence/maestro-match.png` | **THE PROOF** — two panels, each a whole frame of the same real scene through a camera framed on ONE Maestro, labelled with the outfit read back off that rig's live material |
| `evidence/maestro-match-wide.png` | the whole court on the match's own camera, untouched: four rigs, four states, at the size the game draws them |
| `evidence/maestro-match-all-base.png` | the control frame behind the pixel test (every rig on its own material) |

### 4a. Why the first version of this capture was not readable — DIAGNOSED, THEN FIXED

The first version saved only the whole-court frame, and it was read as *"four
athletes, two pairs, no two Maestro recognisable as wearing two different
outfits"*. That report is what this rewrite exists to answer. The answer is **(c):
the two Maestro are dressed correctly and were framed too far away to be judged** —
not (a), not (b). The three possibilities, each settled by measurement:

* **(a) "the capture is showing athletes who are not the Maestro" — EXCLUDED.**
  The lineup was replaced with `{"id": "maestro"}` for all four slots, and every
  rig answers `get_athlete_asset() == "maestro"`, is on the `maestro` profile, and
  reads back the outfit id it was spawned with.
* **(b) "they are Maestro but the outfits are not applied in the match" —
  EXCLUDED, by pixels rather than by eye.** With the same frame rendered again
  with every rig on `base`, the outfit repaints **819 px** of the player's box
  against **103 px** of animation noise (7.9×), **613 px** vs **88 px** for
  `playerMate` (7.0×), **525 px** vs **34 px** for `opponent` (15×) — and the rig
  that never changed outfit moved **59 px** against **36 px** of noise. Zooming
  each athlete's box in the wide frame reads a royal-blue torso and royal-blue
  shorts for `player` and a cream torso with olive shorts for `playerMate`, which
  is what `renders-maestro/maestro_circuit_idle_front_close.png` and
  `maestro_legend_idle_front_close.png` show for the same two outfits.
* **(c) "dressed correctly but framed too far away / too small to recognise" —
  THIS IS THE DEFECT, and it is two numbers.** In the wide frame an athlete's box
  is **80×73 px** in 1280×720, and the panel that carries the outfit is a fraction
  of that, because the variants share their sleeves, their white chest stripe and
  their shorts cut. The two Maestro of a pair also stand **5.63 m apart**
  (measured), so pulling the match camera in far enough to frame both of them at
  once only reaches ~250 px per athlete. At that size two outfits that genuinely
  differ read as one — which is exactly what was reported.

### 4b. The fix: one panel per Maestro, each a whole frame of the real scene

The proof frame renders each of the two Maestro through a **second camera on the
match's own `World3D`** (`SubViewport.world_3d = root.world_3d`, asserted), framed
on that one athlete, at 640×720. The two panels are composed **in-engine** at
exactly the capture size and shown 1:1, so nothing is cropped, resampled or
composited outside Godot. Measured on the frame that was saved:

| role | outfit | athlete in panel | repainted px | mean repainted colour |
|---|---|---|---|---|
| `player` | `circuit` | **435 / 720 px = 60%** | 18985 | `#5e78be` (royal blue) |
| `playerMate` | `legend` | **435 / 720 px = 60%** | 17377 | `#9f9380` (cream/olive) |

The two mean colours are **93/441 apart** (floor 60), measured over exactly the
pixels each outfit repaints — so "two different outfits" is a number, not an
adjective. Each athlete is **5.4× the size** he is in the wide frame, the label on
each panel names the outfit read back off that rig's live material (not off a
dictionary this harness kept), and the swatch beside each label is that same
measured colour. The repainted-pixel counts and the colour distance vary by a few
percent between runs because the rigs are animated; the floors they are asserted
against do not.

### What the checks read off the LIVE rig, not from a cached variable

For each profiled role: the rig is the `maestro` asset; it is on the maestro
profile; the outfit id reads back correct; the masked material is `applied`; the
region mask is `set`; **`value_gate_enabled` is `true`** and both bands equal the
profile's `[0.0, 0.74]` / `[0.76, 1.0]` with feather `0.01`. The three variants
are three **independent** `ShaderMaterial` objects. `base` is the rig's own
material, untouched.

The gate assertion is the one that matters for Maestro specifically: his two atlas
families are 20.0° apart in hue under a 42° tolerance, so the hue test alone
collapses the six slots onto one colour per region. A capture that did not read
the gate back off the GPU material would not prove the outfits read as three.

### The pixels, not just the material

Binding the right uniforms does not prove they reach the screen, so the same frame
is rendered again with every rig on `base` and each athlete's **own screen-space
box** (projected through the match camera, so it follows the athlete) is compared
pixel by pixel — calibrated against the scene's own animation noise, measured as
the difference between two consecutive frames of an *unchanged* scene:

| role | outfit | box (px) | effect vs base | animation noise | verdict |
|---|---|---|---|---|---|
| player | circuit | 5840 | **819** | 103 | 7.9× noise |
| playerMate | legend | 5244 | **613** | 88 | 7.0× noise |
| opponent | signature | 3900 | **525** | 34 | 15× noise |
| opponentMate | base | 3900 | 59 | 36 | within band |

The control is what makes this meaningful: the athlete who never changed outfit
moved only inside the noise band, so the difference on the other three is the
outfit and not the scene. The all-base control frame is saved next to the proof as
`maestro-match-all-base.png`.

At this framing the outfits are provably on screen and **not** provably
distinguishable to a reader — that gap is §4a and §4b. The labelled two-panel
`maestro-match.png` is the frame the outfits can be judged from.

### The harness no longer writes the real profile

The Match scene reads and writes prefs through `Config.save_store()`, which points
at the real `user://save` unless moved. This harness points it at
`user://maestro-match-capture` and removes it at the end.

**Re-verified on resumption, because the real profile had in fact changed during
the session.** A watcher ran the harness while polling the real
`save/career.json` and `save/prefs.json` every 2 s (sha256 **and** mtime): both
were byte-for-byte and mtime-for-mtime identical before and after the run, with no
in-run change, exit 0. The scratch directory is gone afterwards.

The changes that *were* seen in the real profile are **another lane's, not this
one's**, and that is checkable rather than asserted: the real `prefs.json` payload
now carries `"lineup": {"opponent": "colosso", "opponentMate": "steamer",
"playerMate": "fiamma"}` — the colosso lane's lineup, and nothing this harness ever
stages (it stages all four slots on `maestro`, arena `officina`, tier `rivale`, and
only into the scratch store). Three further Godot processes from other lanes were
live on this machine at the time, including a windowed
`tests/ui/screen_characters_audit.gd` and a running `res://game/Main.tscn`. **This
harness did not write the real profile; another lane did.** — see §6.

**The Fiamma harness predates the isolation and does write the real profile on
every run** — see §6.

---

## 5. DEFECTS FOUND AND **NOT** FIXED (reported, per the brief)

### 5.1 The wardrobe's choice never reaches the match

`CharactersScreen.equip_outfit()` writes `career.equippedOutfits[athlete]`
(`CharactersScreen.gd:1210-1226`). The match builds its rigs from
`Lineup.outfits(_lineup, Config.outfit_id())` (`match_controller.gd:1072`), where
`Config.outfit_id()` is `Config.outfit_index` — a **session-level menu cycle**
(`match_config.gd:99-101, 282-286`). Nothing reads `equippedOutfits` back into
`Config.outfit_index`:

```
$ grep -rn "equippedOutfits" --include=*.gd godot/
CharactersScreen.gd:508, 1217, 1219     (reader + writer, inside the screen)
modes_save.gd:71                        (the field list)
career_progress.gd:78                   (the default)
save_schema.gd:111                      (the schema)
```

So equipping `signature` in the wardrobe, then starting a quick match, does **not**
put `signature` on court: the match wears whatever `Config.outfit_index` last
cycled to in the main menu. `Lineup.outfits()` also gives `base` to the three
non-player slots by design.

**This is pre-existing and athlete-independent — it is not a Maestro defect.**
`lineup.gd:29-33` documents it as a known port difference from
`athleteWithOutfits`/`js/ui.js:587-589`. It applies to Fiamma identically.
Closing it is a design change to the menu↔match seam that would affect every
athlete, so per the brief ("*se trovi un difetto riportalo senza correggerlo di
tua iniziativa*") it is reported, not touched.

**Consequence for the proof above, stated plainly:** `maestro-match.png` proves
the three outfits render correctly on Maestro in the real Match scene through the
real spawn factory and the real view sync — it does **not** prove that the
wardrobe selection is what put them there, because that link does not exist yet
for any athlete. It is the same bar the accepted Fiamma precedent was held to.

### 5.2 `mythic` is a wardrobe entry with no visual profile

`maestro:mythic` is an unlockable outfit in the reference table and appears in the
wardrobe, but `OUTFIT_PROFILES.maestro.outfits` lists only `circuit`, `legend`,
`signature`. By the profile's documented rule (*"An outfit absent from this table
is `base`"*) `mythic` falls through to `restore_base_surface()`: a player who wins
and equips `mythic` sees **no change at all**. It is in scope to report because
the award really does hand it out:

```
MEASURED award_match_outfits(maestro) unlocked = [...,"maestro:mythic"]
```

Fiamma has the same shape (her profile authors `circuit`/`legend`/`signature`
while `mythic` exists). Not fixed: authoring `mythic`'s six targets is new art
direction, not an integration fix.

---

## 6. Side effects on files this lane did not own (disclosed)

1. **`docs/agent-work/outfits-3d/evidence/fiamma-match.png`** — running the
   Fiamma harness once to confirm the capture path worked in this environment
   rewrote this **tracked** file (301,799 → 301,793 bytes; same scene, same
   fixtures, PNG-encoder difference). It has been **restored to its committed
   bytes** (`git show HEAD:<path>` redirect — no checkout/stash/reset was used)
   and `git status` is clean for it again.
2. **The real profile `user://save/prefs.json`** was rewritten (mtime only; size
   unchanged at 613 bytes, payload a valid prefs document) by that Fiamma harness
   run, because that harness does not isolate `Config.save_dir`. This is
   pre-existing harness behaviour, not something this lane introduced — and it is
   exactly why the new Maestro harness isolates its store. I could not restore the
   file: it is user data outside the repo and no copy of its prior bytes exists.
3. **Godot's project-wide importer** generated sidecars for files other lanes had
   just created, as an unavoidable consequence of importing the project:
   `assets/athletes/outfits/colosso/colosso_region_mask.png.import` (+ preview),
   five `game/out/ui-modes-*.png.import`, and `tests/ui/clean_mode_audit.gd.uid`.
   No colosso/oracolo *content* was read, edited or moved; only Godot's own
   metadata sidecars were produced for files that already existed.

---

## 7. Test suite — exit codes

Re-run on resumption, after every change in this document. Every exit code below
is the process exit code, and every tally is the test's own last line:

| test | exit | tally |
|---|---|---|
| `tests/outfit_maestro_profile_test.gd` | 0 | `OUTFIT_MAESTRO_PROFILE_PASS checks=118 failures=0` |
| `tests/outfit_fiamma_profile_test.gd` | 0 | `OUTFIT_FIAMMA_PROFILE_PASS checks=108 failures=0` |
| `tests/modes/outfit_challenges_audit.gd` | 0 | `PASS 89/89` |
| `tests/ui/screen_characters_audit.gd` | 0 | `PASS 182/182` |
| `tests/modes/save_progression_audit.gd` | 0 | `PASS 46/46` |
| `tests/outfit_maestro_match_capture.gd` | 0 | `OUTFIT_MAESTRO_MATCH_PASS`, 64/64 checks |
| `git diff --check` | 0 | clean |
| `git diff --cached --check` | 0 | clean |

`screen_characters_audit.gd` reports **182/182** where this document previously
recorded 170/170. That is the same test file at a later revision — it is one of the
files other lanes have modified in this tree (`git diff --name-only` lists it) —
and it passes. It is also the test that mounts Maestro's wardrobe, since Maestro is
roster index 0.

**Already failing before this lane, and failing identically after — not gates:**

| test | exit | tally |
|---|---|---|
| `tests/athlete_roster_test.gd` | 1 | `FAIL 56/60` (as before) |
| `tests/maestro_asset_test.gd` | 1 | `FAIL 31/34` (as before) |

Both failures are rig/asset expectations that predate this lane and have nothing to
do with outfits — the same checks fail, in the same direction:

* `athlete_roster_test.gd`: `the spawned rig has the expected joint count: expected
  24, got 28`; `all three locomotion clips are registered: expected ["idle","walk",
  "run"], got [... nine clips]`; `all four padel strokes are registered: expected 4,
  got 10`; `the pose readout covers every joint: expected 24, got 28`.
* `maestro_asset_test.gd`: `Maestro carries the remeshed 30,980-triangle mesh:
  expected 30980, got 12253`; `the walk clip moves the skeleton (bones changed 0)`;
  `the walk movement is measurable (max angle 0.0000 deg)`.

---

## 8. Reproducing

```bash
cd /Users/alessiofantini/Documents/steam-circuit-padel-11m
G=/Applications/Godot.app/Contents/MacOS/Godot

# the imports (idempotent)
GODOT_SILENCE_ROOT_WARNING=1 $G --headless --path godot --import

# the proof: the real Match scene. NOT headless - a headless Godot has no framebuffer.
GODOT_SILENCE_ROOT_WARNING=1 $G --path godot --script res://tests/outfit_maestro_match_capture.gd

# the mask import check (headless)
cp docs/agent-work/outfits-3d/evidence/maestro-mask-import-probe.gd.txt \
   godot/tests/_maestro_mask_import_probe.gd
GODOT_SILENCE_ROOT_WARNING=1 $G --headless --path godot --script res://tests/_maestro_mask_import_probe.gd

# the wardrobe probe (headless, isolated store)
cp docs/agent-work/outfits-3d/evidence/maestro-wardrobe-probe.gd.txt \
   godot/tests/_maestro_wardrobe_probe.gd
GODOT_SILENCE_ROOT_WARNING=1 $G --headless --path godot --script res://tests/_maestro_wardrobe_probe.gd
rm godot/tests/_maestro_*_probe.gd godot/tests/_maestro_*_probe.gd.uid
```

The two probes are shipped as `.gd.txt` because this lane's file scope allows only
`tests/outfit_maestro_match_capture.gd` to be added under `godot/tests/`; copy them
in to re-run, delete them after.

The capture step writes three images next to each other, derived from the one
`--out=` path: `<out>`, `<out>-wide.png` and `<out>-all-base.png`.

---

## 9. Files touched — and files NOT touched

**Touched by this lane** (all of it on resumption; `git status` shows all three as
untracked because nothing here was ever committed):

| file | state |
|---|---|
| `godot/tests/outfit_maestro_match_capture.gd` | new file (this lane), rewritten on resumption: whole-court frame + framed proof panels + labels + measured colour assertions |
| `godot/tests/outfit_maestro_match_capture.gd.uid` | new file (Godot's own sidecar) |
| `docs/agent-work/outfits-3d/MAESTRO-INTEGRATION.md` | this document |
| `docs/agent-work/outfits-3d/evidence/maestro-match.png` | rewritten: the labelled two-panel proof |
| `docs/agent-work/outfits-3d/evidence/maestro-match-wide.png` | new |
| `docs/agent-work/outfits-3d/evidence/maestro-match-all-base.png` | rewritten |
| `docs/agent-work/outfits-3d/evidence/maestro-match-capture.log` | rewritten (64/64, exit 0) |
| `docs/agent-work/outfits-3d/evidence/maestro-wardrobe-probe.log` | rewritten (51/51, exit 0) |

**NOT touched by this lane, and not claimed by it.** The tree is dirty with other
sessions' work. These are modified and none of them is mine:

```
godot/game/arenas/arena_kit.gd              godot/src/modes/data/modes.json
godot/game/match_config.gd                  godot/src/modes/modes_save.gd
godot/game/match_controller.gd              godot/src/save/save_schema.gd
godot/game/mode_session.gd                  godot/src/ui/**  (several)
js/data.js                                  godot/tests/**  (several)
```

Two files deserve a specific note because they belong to the **Maestro** feature and
are nonetheless **not** changes made by this resumption:

* `godot/src/character/outfit_catalogue.gd` — the `&"maestro"` entry in
  `OUTFIT_PROFILES`. mtime **16:46**, before this session started; modified by the
  earlier Maestro lane, not by this one.
* `godot/src/character/outfit_region_recolour.gdshader` — the optional
  `value_gate_enabled` gate. mtime **16:46**, same.

Both are read, asserted and rendered against by the capture harness; neither was
edited on resumption. No `js/**`, no progression logic and no balance was changed by
this lane at any point. Colosso and oracolo were not read, edited or moved.
