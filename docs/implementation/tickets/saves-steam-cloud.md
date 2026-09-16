# Saves, Steam achievements and Steam Cloud (slice S11)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Tournament and career presentation](tournament-career.md) for the career payload's shape, and [Drill as a 3D session](drill-3d.md) for the drill record's. Acceptance is blocked by [Save and cloud format](../../wayfinder/tickets/save-and-cloud-format.md) (open, HITL, owner Luca), which decides the schema, the file location and the migration answer, and by [Steamworks prerequisites](../../wayfinder/tickets/steamworks-prerequisites.md) (open, HITL, owner Luca) for the achievement list, the cloud quota and the App ID. The bridge work is unblocked and can start now: the integration route is resolved and only the **live release proof** needs the real App ID. The slice may not be called done while those stay open, and no mock is ever presented as production Steam success.

This ticket implements row S11 of `docs/implementation/PLAN.md` ("Saves, Steam achievements, Steam Cloud"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S12 or S13.

## Objective

Make progress survive: a local save that round-trips everything the current game persists, achievements that fire from what the game already tracks, and cloud synchronisation layered on top of the local file rather than replacing it. The route is already chosen and written down — a drop-in GDExtension addon under `addons/godotsteam/`, stock Godot export templates, `Engine.has_singleton("Steam")` guarded, with a single `is_steam_enabled()` gate through which every achievement, cloud and overlay call passes, so a headless run, a Steam-less machine and a non-Steam build all take the same local-only path.

Two rules shape the whole slice and are stated before any code:

- **The local save is never the second copy.** Cloud is layered on top of it, per the resolved route. A build with no Steam client must lose nothing.
- **A mock proves a seam, never a release.** Everything below can be tested against a development/test app and against a fake bridge; the live release proof is explicitly separate and requires the App ID and a Steam client, and nothing in this slice's evidence may blur the two.

## Existing source anchors

Persistence in the reference — five keys, all `localStorage`:

| Anchor | What it is |
|---|---|
| `js/ui.js:7-11` | The five keys: `padel.prefs` (`:7`), `padel.history` (`:8`), `padel.drill` (`:9`), `padel.feedback` (`:10`), `padel.career` (`:11`). The save schema is the union of what these five hold |
| `js/ui.js:38, 48` | `loadCareer()` / `saveCareer(career)` |
| `js/ui.js:206-226` | `loadDrillRecords`, `drillRecord`, `saveDrillRecord` — records are saved **only on improvement**, which is a policy the port must keep or change deliberately |
| `js/ui.js:244-256` | `loadFeedbackQueue` / the queue write, capped by `FEEDBACK.maxQueued` |
| `js/ui.js:405-414` | `loadPrefs()` / `savePrefs(prefs)`. **This is the merge-against-defaults behaviour the save-format decision names**: the loader merges a stored payload over defaults, so a save written by an older build does not become an empty profile |
| `js/ui.js:422` | `collectPrefs()` — the full preference set, including `tournamentRound` at `:427` and the defaults object at `:464` |
| `js/ui.js:1540-1551` | `loadHistory()` / `saveHistory(list)` — the history is capped at 20 entries (`slice(0, 20)`) |
| `js/ui.js:1563` | `renderHistory()` — what the history screen reads |
| `js/data.js:515-555` | `ATHLETE_OUTFITS`, 26 entries with 20 unlockable challenges — the `outfitsWon` source the achievements read |
| `js/data.js:765-767, 853` | `CAREER_MATCHES`, `CAREER_POINTS_TO_WIN`, `CAREER_PROMOTION_WINS`, `CAREER_FINAL_SEASON` — the career progression achievements read |
| `js/data.js:20` | `VERSION` — the save must record which build wrote it, the way the balance tag is recorded today |

Steam:

| Anchor | What it is |
|---|---|
| `docs/wayfinder/tickets/steamworks-integration-route.md` | The resolved route: GodotSteam GDExtension 4.22.1 Stable (Steamworks SDK 1.65), a drop-in under `addons/godotsteam/`, with the module build as the stated fallback if the prebuilt plug-in does not load in the pinned binary |
| the same, "Headless CI impact" | The three cases the port must handle without failing: `steamInitEx()` returning a non-zero status when no client is running (a **soft** failure: continue), a missing `libsteam_api.so` (a hard loader error), and a missing plug-in leaving `Engine.has_singleton("Steam")` false |
| the same, "No-Steam fallback" | The required v1 fallback: one `is_steam_enabled()` gate; cloud layered on the local save, never the only copy |
| the same, "Open item carried forward" | The closing probe when the plug-in zip is first fetched: load it in the pinned binary and assert `Engine.has_singleton("Steam")` is true and `steamInitEx()` returns a status code rather than failing to load. If it fails, switch to the module builds and record it |
| the same, on the overlay | The overlay can never be asserted headless — upstream states it does not work in the editor and only works in an export launched from Steam — so it needs one manual Steam-client run |
| `docs/wayfinder/tickets/steamworks-prerequisites.md` | The achievement list with API names, the cloud quota, and the App ID. Sources named there: career stars and the career progression model, trophies and history, and the 20 unlockable outfit challenges. Specials are shot abilities, not characters |
| `docs/wayfinder/evidence/steamworks-integration-route.md` | The route's full evidence, including the compared candidates and why the module route was not chosen |
| `godot/tests/smoke_test.gd` | The headless contract every test in this port uses, and the run that must stay green with no Steam present |

The seams this slice sits next to, each with one owner: the career and drill payload shapes come from [Tournament and career presentation](tournament-career.md) and [Drill as a 3D session](drill-3d.md); `godot/src/ui/**` owns the screens that show progress, and this slice owns the store they read; `godot/src/locale/**` owns strings; `godot/src/audio/**` owns sound.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/save/SaveSchema.gd` — the schema: prefs, history, drill records, feedback queue, career, plus a `schemaVersion` and the writing build's version. Generated field names from `js/ui.js`, not re-typed
- `godot/src/save/SaveStore.gd` — read, write, and **merge against defaults** the way `js/ui.js:405-414` does; one file per key group under `user://`, with the paths named in `s11-save-notes.md`
- `godot/src/save/SaveMigration.gd` — the version step. Its behaviour is stated by the save-format decision; until that lands it exists as an interface and refuses to guess
- `godot/src/save/steam/SteamBridge.gd` — the only thing that calls the addon: `is_steam_enabled()`, `steam_init()`, `unlock_achievement(id)`, `cloud_write(file, bytes)`, `cloud_read(file)`, `show_overlay()`. Every call is behind the one gate
- `godot/src/save/steam/FakeSteamBridge.gd` — the test double with the same surface, used by headless tests. It is a double, and its own file header says so
- `godot/src/save/Achievements.gd` — the achievement mapping, from the game's own tracked values to the API names the prerequisites ticket defines. Until those names land it holds the source values and refuses to invent ids
- `godot/src/save/CloudSync.gd` — the cloud layer over the local save: write-after-save, read-on-start with a conflict rule that is the save-format decision's, never "cloud wins"
- `godot/src/save/steam/probe_addon.gd` — the closing probe: a script run by `--script` that reports whether the singleton exists and what `steamInitEx()` returns
- `godot/tests/save_roundtrip_audit.gd` and `.tscn` — every payload round-trips byte-for-byte through the store, and a payload missing fields loads with defaults merged
- `godot/tests/steam_bridge_audit.gd` and `.tscn` — the no-Steam path, the missing-singleton path and the non-zero `steamInitEx` path are all soft and all continue
- `godot/tests/achievements_audit.gd` and `.tscn` — every achievement source value in the game maps to exactly one API name, and no achievement fires from a value the game does not track
- `godot/src/save/README.md` — the store's map, the gate's rule and the mock-versus-release statement
- `docs/implementation/evidence/s11-*` — the evidence files listed below

The addon itself: `godot/addons/godotsteam/` is a **drop-in**, fetched as a toolchain acquisition, not authored here. It is not in the allowlist for editing; if the pinned binary cannot load it, the fallback route in the integration ticket is taken and recorded, not patched.

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/`, `godot/src/career/**`, `godot/src/drill/**`, `godot/src/ui/**` beyond the store's registration, `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/view/**`, `godot/prototypes/`, and `godot/project.godot` beyond the addon's own registration and nothing else — the 120 Hz tick and the `gl_compatibility` renderer stay as the harness left them.

No Steam call may appear anywhere outside `godot/src/save/steam/**`. That is the whole point of the gate.

## Inputs and outputs

Inputs:

- The career payload shape from [Tournament and career presentation](tournament-career.md) and the drill record shape from [Drill as a 3D session](drill-3d.md).
- The preference set from `js/ui.js:422-464`, including `tournamentRound` and its defaults — the defaults are what "merge against defaults" means, so they are carried, not re-invented.
- The achievement sources named in the prerequisites ticket: career stars and the progression model, trophies and history, the 20 unlockable outfit challenges. Specials are **not** an achievement source; they are shot abilities.
- The save-format decision, when it lands: schema, location, cloud mapping, migration answer.
- The Steam addon, when it is fetched; a development/test app is enough for everything except the live proof.

Outputs:

- A local save under `user://` that round-trips every payload the reference persists, with merge-against-defaults proven by a test that loads a deliberately incomplete payload.
- One `is_steam_enabled()` gate; a build with no Steam client runs every test and loses nothing.
- Achievement unlocking driven by the game's own tracked values, mapped to API names once those land. Until then the mapping is present as sources-without-ids and the audit asserts that no invented id exists.
- A cloud layer that writes after the local save and reads at start, with the conflict rule left to the decision and the local file never deleted.
- The closing probe for the addon: the plug-in loaded in the pinned binary with `Engine.has_singleton("Steam")` asserted true and `steamInitEx()` returning a status code.

Explicitly not output: publishing, store configuration, the live App ID, the overlay assertion (impossible headless), a second cloud copy, migration behaviour before the decision lands, and any statement that the port is Steam-ready.

## Tests

The web work that bears on this slice, by real file name:

- `scripts/feedback-audit.mjs` — the queue's behaviour: an entry is unsent when queued (`:71`), a missing endpoint fails with its own reason (`:78-79`), the offline case is distinguished from a missing endpoint (`:94-95`), and a rejection does not consume the queue (`:107`). The Godot equivalent is that the feedback payload round-trips through the store with `sent` preserved and the queue capped at `FEEDBACK.maxQueued`.
- `scripts/outfit-challenges-audit.mjs` — the 20 unlockable challenges the achievement mapping reads. The counts are asserted in the career audit; this slice asserts the mapping covers them all.
- `scripts/demo-audit.mjs` — the demo exposes two athletes and one arena; a demo build must not leak achievements for content it does not contain. That interaction is named here and enforced in [Demo and export presets](demo-export-presets.md).
- `scripts/assets-audit.mjs`, `scripts/modules-audit.mjs`, `scripts/module-contract-audit.mjs` — the Godot equivalent is the headless load with zero script errors, which must stay green **with no Steam present**, and that is itself the most important test in this slice.

Godot-side equivalents:

- `godot/tests/save_roundtrip_audit.gd` — every payload round-trips; an incomplete payload loads with defaults merged and no field lost; a payload from an older `schemaVersion` is either migrated or refused explicitly, never silently emptied; drill records keep the save-only-on-improvement policy.
- `godot/tests/steam_bridge_audit.gd` — with no singleton, with the fake bridge, and with a fake bridge that returns a non-zero `steamInitEx` status, every path continues and the local save is written and read identically. A missing `libsteam_api.so` is reported as a hard loader error by the harness, not swallowed.
- `godot/tests/achievements_audit.gd` — every achievement source is a value the game actually tracks; no achievement id is invented before the list lands; the source-to-id mapping is one-to-one.
- The ported smoke run, unchanged: `env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 <godot> --headless --path godot/` still prints `PASS 8/8` with the save module present and no Steam.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. `timeout` is the CI bound, not `--quit-after`.

The three headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in save_roundtrip_audit steam_bridge_audit achievements_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s11-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s11-${a//_/-}.log; \
done
```

The no-Steam harness smoke, which is the release-critical one:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/; echo "exit=$?"
```

The addon's one line of truth, once it is fetched:

```sh
cd /root/projects/steam-circuit-padel-pro && ls godot/addons/godotsteam/ 2>/dev/null | head; \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ --script res://src/save/steam/probe_addon.gd; \
  echo "probe exit=$?"
```

The local save file, inspected outside the engine, so the schema is checkable without running the game:

```sh
ls -l ~/.local/share/godot/app_userdata/*/ 2>/dev/null | head -20
```

The no-Steam rule, checked mechanically:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  grep -rn 'Steam\.\|steamInit\|GodotSteam' godot/ --include=*.gd | grep -v '^godot/src/save/steam/'; \
  echo "the line above must be empty (all Steam calls live behind the gate)"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s11-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s11-save-roundtrip-audit.log`, `s11-steam-bridge-audit.log`, `s11-achievements-audit.log` — each with an exit code and a `PASS n/n` line.
- `docs/implementation/evidence/s11-no-steam-smoke.log` — the harness run with no Steam client, `PASS n/n`, exit 0. This is the proof that a Steam-less build is not broken, and it is deliberately separate from any Steam-positive claim.
- `docs/implementation/evidence/s11-boundary-check.log` — the mechanical check that no Steam call exists outside `godot/src/save/steam/**`.
- `docs/implementation/evidence/s11-addon-probe.log` — the closing probe's result: the addon directory listing, `Engine.has_singleton("Steam")`, and the `steamInitEx()` status code, or the recorded switch to the module route if the prebuilt plug-in does not load in the pinned binary.
- `docs/implementation/evidence/s11-save-schema.md` — the schema field by field, mapped to the five reference keys, with the merge-against-defaults rule and the drill save-on-improvement policy stated, and the migration behaviour marked as the save-format decision's.
- `docs/implementation/evidence/s11-steam-status.md` — the plain statement of what is proven and what is not: mock-backed interfaces green; the addon's loadability probed; the overlay **not** proven and impossible headless; the live App ID absent; the cloud quota unknown. No sentence in this file may say "Steam works".
- `docs/implementation/evidence/s11-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a mock-backed test presented as Steam success; an overlay screenshot claimed from a headless run; a schema asserted in prose without the round-trip test; a cloud write asserted without the local file still being written; and any claim that a save written by the current game migrates, before the decision lands.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- A payload does not round-trip, or an incomplete payload loads as an empty profile instead of merging with defaults.
- A save path or a cloud write deletes, truncates or replaces the local file.
- A Steam call appears outside `godot/src/save/steam/**`, or a call is made without passing the one gate.
- A non-zero `steamInitEx()` status, a missing singleton or a missing plug-in is treated as a hard failure instead of a soft one — **except** a genuinely missing `libsteam_api.so` beside the binary, which is a hard loader error and must stay visible.
- An achievement id is invented before the prerequisites list lands, or an achievement fires from a value the game does not track.
- Migration behaviour is implemented before the save-format decision lands.
- A mock is presented as production Steam success, or the evidence claims Steam works.
- A file outside the allowlist changes, `js/` or `scripts/` changes at all, or the addon is edited rather than used as a drop-in.

What stops the slice: a red audit after the retry rule below; the prebuilt addon failing to load in the pinned binary, which switches the route to the module builds and is recorded rather than patched; or the save-format decision not landing, in which case the store is delivered with a refused-migration interface and the migration half is recorded as blocked.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the defaults object used by the merge test is the one from `js/ui.js:464` and not a smaller hand-made set; confirm the round-trip test writes and reads through the real store rather than an in-memory copy; confirm the fake bridge returns a non-zero status in one of its modes so the soft path is actually exercised; confirm the boundary check's grep covers `.gd` and not only `.gdscript`.

## Human gates that block this slice (open, owner Luca)

- **Save and cloud format** — the schema, the `user://` location, the cloud mapping, and whether browser `localStorage` saves need migrating (conditional on the web build ever shipping). This slice proposes the shape and refuses to implement the migration; it decides nothing.
- **Steamworks prerequisites** — the achievement list with API names, the cloud quota, and the App ID recorded. Achievements stay source-mapped-without-ids until the list lands; the live release proof waits on the App ID and is explicitly separate from everything above.
- **Product scope and platforms** — the OS set (it decides export presets and therefore what "the cloud file" is on each platform) and the save scope decision that the format ticket takes as input.
