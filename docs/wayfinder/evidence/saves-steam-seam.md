# Evidence: save and Steam seam (slice S11, partial — crew-save lane)

Ticket: [Saves, Steam achievements and Steam Cloud](../../implementation/tickets/saves-steam-cloud.md) (slice S11)
Lane: crew-save — the save / Steam-interface seam only
Date: 2026-09-16 · Host: Linux, pinned engine `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`
Engine under test: `4.7.2.stable.official.ed1daf0bf` (all runs print this)
Repo: `/root/projects/steam-circuit-padel-pro` (Godot port); frozen browser reference `js/**` at commit `2979588`, **not modified**

## 1. What exists, in one paragraph

A versioned, corruption-safe offline save for the Godot port
(`godot/src/save/**`) written under `user://save/`, one file per save group,
covering exactly what the frozen browser reference persists in `localStorage`
(`js/ui.js:7-11`: `padel.prefs`, `padel.career`, `padel.history`, `padel.drill`,
`padel.feedback`) with atomic writes, merge-against-defaults on read,
corrupt-file quarantine and a version step that migrates the browser's
unversioned shape and refuses anything it does not know. Plus a narrow Steam
seam (`godot/src/steam/**`) for the two in-scope release features — achievements
and cloud saves — implemented over a mock backend that states on itself that it
is a mock, with the real GodotSteam GDExtension backend written but never
executed and every one of its API names marked unverified, swappable at exactly
one line. **No live Steam behaviour is proven anywhere in this file.**

## 2. Commands, exit codes and key output lines

All engine invocations use the shared lock (`flock -w 900 /tmp/padel-godot.lock`)
with `timeout` inside, one engine process at a time.

### 2.1 The new headless test — the deliverable's proof

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://tests/save_steam_test.gd
```

**exit 0.** Key lines:

```
# Godot 4.7.2-stable (official) · slice S11 save + Steam seam
ok save root is user://save (js/ui.js:7-11 has five localStorage keys)
ok every group is a real non-empty file on disk
ok career round-trips field for field
ok whole numbers reload as ints, not floats
ok the target file is byte-identical after the interrupted write
ok no .tmp file is left behind
ok the corrupt group falls back to the reference defaults, not an empty profile
ok the quarantined bytes are the ones that were there
ok v0 -> v1 preserves a stored field verbatim
ok a save from an unknown future schema version is refused
ok the refused file is byte-identical after the read
ok the backend saw one call per distinct achievement
ok unlock_source refuses while the mapping is empty
ok an unlock with no Steam backend fails honestly
ok the mock does not claim live Steam
ok the cloud copy downloads
ok the local file still exists after the upload (cloud is not the only copy)
ok with the addon absent the real bridge reports a non-zero (soft) status
ok the factory's default backend is the mock
ok every test section ran to completion
PASS 137/137
```

Counts from the same run: `ok ` lines **137**, `FAIL` lines **0**,
`SCRIPT ERROR` lines **0**, `PASS 137/137`, exit 0.

The test carries a self-guard: each of the nine sections records itself complete
as its last statement, and the run asserts all nine markers are present
(`ok every test section ran to completion`). A runtime error aborts only the
function it happens in — the caller continues — so without that guard a broken
section finished the run *without* failing it. That failure mode was observed
during development (see §6) and is now red by construction.

### 2.2 The engine harness must stay green (8/8)

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```

**exit 0**, final line `PASS 8/8` — unchanged with the save module present and
no Steam client. `godot/project.godot` and `run/main_scene` were not touched.

### 2.3 The addon probe — a report, not a claim

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://src/steam/probe_steam_addon.gd
```

**exit 0** (deliberately always 0: a non-zero `steamInitEx` status is a soft
failure by design). Output, verbatim:

```
# Steam addon probe (pinned Godot 4.7.2-stable (official))
# res://addons/godotsteam/ present = false
# Engine.has_singleton("Steam") = false
# init status = 2
# init message = GodotSteam singleton absent (addon not installed, or stripped from the build)
# is_steam_enabled = false
# is_mock = false (false means this is the real bridge class)
# live_steam_proven = false (always false: the live proof is a manual Steam-client run)
# RESULT: the addon is not installed in this tree; no Steam behaviour is proven.
```

The addon is **not** fetched, installed or vendored, per the lane's boundary.
This probe is the closing probe the route ticket asks for, ready to run the day
the plug-in zip is dropped in.

### 2.4 The no-Steam boundary rule, checked mechanically

```sh
cd /root/projects/steam-circuit-padel-pro && \
  grep -rn 'Steam\.\|steamInit\|GodotSteam' godot/ --include=*.gd | grep -v '^godot/src/steam/'
```

**exit 1 (grep: no matches), 0 lines.** Every Steam-touching identifier in the
tree lives under `godot/src/steam/**`; nothing in `godot/src/save/**`, the test
or anywhere else calls the Steam API.

### 2.5 A real save file, inspected outside the engine

A one-off script (written, run, deleted) wrote a profile through the real store
to `user://s11_sample/` and printed the bytes. Real artefacts, still on disk at
`/root/.local/share/godot/app_userdata/Steam Circuit Padel Pro (harness)/s11_sample/`:

| File | Bytes | sha256 |
|---|---|---|
| `career.json` | 401 | `cb30fa4eac188d57178516c4989e44789c4d5668dce4fc7c5c824dbfb4dddf04` |
| `prefs.json` | 599 | `2d8d74d6346fc296da83c3da237c174610b3b1a00cc2ab8d5d1db71ebc89fc7f` |
| `history.json` | 232 | `582cbe08b553257132868bb2da03d704770ee5fcea172443136a3ece4f4e52b8` |
| `drill.json` | 155 | `aa04ace58ff87b78b94655f007977f2c0db87fc23d877936767f793954d08f21` |
| `feedback.json` | 127 | `ee15c1c8e8e6910b5aa8778c56e87de0627edc76e788d37bb8d8d2dd9d8c2425` |

`career.json`, verbatim (401 bytes, tab-indented, keys sorted for determinism):

```json
{
	"balance": "b7",
	"build": "alpha-0.2",
	"format": "padel-save",
	"group": "career",
	"payload": {
		"losses": 3,
		"outfitsWon": { "maestro-challenge-1": true },
		"season": 4,
		"seasonProgress": {
			"doubleFaults": 1, "errors": 3, "longestRally": 9,
			"pointsWon": 41, "smashWinners": 5, "winners": 12
		},
		"stars": 7,
		"trophies": 1,
		"wins": 11
	},
	"schemaVersion": 1
}
```

(The nested objects are printed one-per-line in the real file; abbreviated here
for readability. The bytes and sha256 above are the real ones.)

## 3. File inventory

New files only. No file outside this lane's boundary was created or modified
(`js/**` untouched, `godot/project.godot` untouched, `run/main_scene` untouched).

| Path | Bytes | sha256 |
|---|---|---|
| `godot/src/save/save_schema.gd` | 9895 | `f8847b9794ab1e43b9af4a8ca837c0a4db7b38a78dfd4f69ebc004df142043ec` |
| `godot/src/save/save_store.gd` | 11018 | `7efc3ebae443aaa6fb8ffbe7ad98da965d17aba9ecacf44f9c5f268e4615ceac` |
| `godot/src/save/save_migration.gd` | 4994 | `a3cb3062d6c61c8c1e001a4274b750337d9cd9232a045b5b478b0fb2f78e24ab` |
| `godot/src/save/README.md` | 5343 | `3c1d01981b5632995cf83bb9d67711d21ced0ff75c5cdb2504694c98b0a9488c` |
| `godot/src/steam/steam_backend.gd` | 3623 | `84051ec19ff8e8d3a0d3a6005f22cce6e50305105223811396fe3779700471fa` |
| `godot/src/steam/mock_steam_backend.gd` | 6780 | `5bd2d2413d53e9eac6ff144ccb8b114dc80b13e9058f2f379d4a19313d449bf0` |
| `godot/src/steam/godotsteam_backend.gd` | 7318 | `d776930527cdecb917360696c9480d81e7244e0a05e3f3493d4aac2ce91a8517` |
| `godot/src/steam/steam_backend_factory.gd` | 2875 | `f2f409cf7ca5f9ab5fc8e720bab03b39b91f33fe6bb8a705eb77012dcd735053` |
| `godot/src/steam/achievements.gd` | 4301 | `330532aa994a63b0ae239a104bc9ea698305f6c1a0bc3d40afca119a075966b1` |
| `godot/src/steam/cloud_saves.gd` | 4770 | `9d0b05b976195a31f634d7a0a0fb9b10c36e351d29c4b5b893b078d4d958ab3e` |
| `godot/src/steam/probe_steam_addon.gd` | 2236 | `9420b4e54afa561c62284286fc500c49b061a3979a3d2944c824b25c7def76f2` |
| `godot/tests/save_steam_test.gd` | 35499 | `1eb09f97112bd96948184c248760f1c232568cb61d8150057ce44631dd9a158b` |

One file this lane's ticket allowlist names does **not** exist here:
`godot/src/save/steam/probe_addon.gd`. This lane was given the narrower seam
path `godot/src/steam/**`, so the probe is `godot/src/steam/probe_steam_addon.gd`.
The `godot/src/save/Achievements.gd`, `godot/src/save/CloudSync.gd` and
`godot/src/save/SaveMigration.gd` names in the implementation ticket are
delivered here as `godot/src/steam/achievements.gd`,
`godot/src/steam/cloud_saves.gd` and `godot/src/save/save_migration.gd`; the
ticket's `godot/tests/*_audit.gd` split (round-trip / bridge / achievements) is
delivered as the single `godot/tests/save_steam_test.gd` this lane was asked for.

## 4. The save format

### 4.1 Location and files

`user://save/<group>.json`, one file per save group. `user://` is Godot's
per-user writable root; the browser's equivalent was the origin's
`localStorage`. A test may point `SaveStore` at another root (`user://save_test`
is used by the test so a real profile is never touched).

### 4.2 Envelope

```json
{ "format": "padel-save", "schemaVersion": 1, "build": "alpha-0.2",
  "balance": "b7", "group": "career", "payload": <the payload> }
```

`build`/`balance` come from `js/data.js:20` (`VERSION`) — the save records which
build wrote it, the same way the feedback diagnostics already do.

### 4.3 Groups — mapped to the reference, field for field

| Group | File | Reference key | JSON type | Cap | Defaults merged on read |
|---|---|---|---|---|---|
| `prefs` | `prefs.json` | `padel.prefs` (`js/ui.js:7`, `:405-442`) | object | — | yes — the `ui` object's start values (`js/ui.js:460-481`) + audio defaults (`js/audio.js:3-6`), 17 fields |
| `career` | `career.json` | `padel.career` (`js/ui.js:11`, `:12-54`) | object | — | yes — `DEFAULT_CAREER`, 16 fields (`js/ui.js:12-36`) |
| `history` | `history.json` | `padel.history` (`js/ui.js:8`, `:1540-1561`) | array | 20 entries (`slice(0,20)`) | no (the reference merges none) |
| `drill` | `drill.json` | `padel.drill` (`js/ui.js:9`, `:206-230`) | object, exercise → best score | — | no |
| `feedback` | `feedback.json` | `padel.feedback` (`js/ui.js:10`, `:244-260`) | array of queue entries | `FEEDBACK.maxQueued` = 40 (`js/data.js:73`) | no |

No field beyond these was invented. `SEASON_METRIC_AGG`'s six metrics
(`pointsWon`, `winners`, `smashWinners`, `errors`, `doubleFaults`,
`longestRally` — `js/data.js:775-782`) are used for the `career.seasonProgress`
default, exactly as `emptySeasonProgress()` is (`js/data.js:785-787`).

### 4.4 Rules, each proven by a test line

| Rule | Reference | Test line |
|---|---|---|
| Shallow merge over defaults; stored keys (including unknown ones) kept | `js/ui.js:41` | `ok the stored field survives the merge` / `ok a field the schema does not know is preserved, not dropped` |
| Atomic write: temp file, flush, close, rename | — (new) | `ok a second write replaces the first in place`, `ok the target file is byte-identical after the interrupted write`, `ok no .tmp file is left behind` |
| Corruption → quarantine `<file>.corrupt.<unix>`, fall back to defaults, report it | browser `try/catch` lost the bytes (`js/ui.js:38-46`) | `ok the corrupt file was quarantined, not deleted`, `ok the quarantined bytes are the ones that were there` |
| Unknown `schemaVersion` → refuse, leave the file untouched | — (new) | `ok a save from an unknown future schema version is refused`, `ok the refused file is byte-identical after the read` |
| v0 (unversioned) → v1 envelope, fields verbatim | — (new) | `ok v0 -> v1 preserves a stored field verbatim`, `ok v0 -> v1 preserves an unknown field too` |
| Drill records written only on improvement | `js/ui.js:219-230` | `godot/src/save/save_store.gd::write_drill_record()` (policy ported; exercised by the store's own path) |
| Whole numbers reload as ints, fractional stay floats | — (new; see §6.2) | `ok whole numbers reload as ints, not floats`, `ok fractional numbers stay floats` |

### 4.5 What the format deliberately does NOT decide

The save-format ticket (`docs/wayfinder/tickets/save-and-cloud-format.md`) is
open and owns the cloud mapping, the conflict rule, and any *behavioural*
migration (e.g. whether a browser `localStorage` profile is ever imported).
Implemented here: only the mechanical envelope migration. Not implemented:
anything that would reinterpret game data. `SaveMigration` refuses rather than
guesses, and `CloudSaves.resolve_conflict()` states its placeholder rule (local
always wins, cloud never) in the code with the reason.

## 5. The Steam seam and the exact swap point

### 5.1 Shape

```
godot/src/steam/steam_backend.gd            the interface (no Steam call)
godot/src/steam/mock_steam_backend.gd       the test double; says it is a mock
godot/src/steam/godotsteam_backend.gd       the real bridge — WRITTEN, NEVER RUN
godot/src/steam/steam_backend_factory.gd    THE SWAP POINT (one line)
godot/src/steam/achievements.gd             narrow achievement interface
godot/src/steam/cloud_saves.gd              narrow cloud interface over the local save
godot/src/steam/probe_steam_addon.gd        the addon report (--script)
```

`Factory.create()` today returns `MockSteamBackend` in `UNAVAILABLE` mode — the
honest no-Steam path, init status 2, gate closed. Nothing anywhere else decides
which backend is used.

### 5.2 The swap (one file, two lines)

In `godot/src/steam/steam_backend_factory.gd`, replace the body of `create()`:

```gdscript
var b: SteamBackend = GodotSteamBackendScript.new()
b.init_backend()   # a non-zero status leaves the gate closed: the soft path
return b
```

Then fetch `godotsteam-4.22.1-gdextension-plugin-4.4.zip` into
`godot/addons/godotsteam/` and run the probe. Nothing else moves: achievements
and cloud only know the `SteamBackend` interface, and `is_steam_enabled()` stays
false on a non-zero `steamInitEx` status, so a Steam-less machine still runs on
local saves alone.

### 5.3 Unverified assumptions (every Steam API name used)

The addon was never fetched or loaded, so **none** of the following has ever
been executed. Each is marked `UNVERIFIED ASSUMED API` in
`godotsteam_backend.gd`:

1. The singleton is named `"Steam"`, fetched with `Engine.get_singleton("Steam")`,
   and `Engine.has_singleton("Steam")` is the correct presence test.
2. `steamInitEx(app_id = 0)` returns a `Dictionary` with an integer `status`
   (0 success, 1 other, 2 client not running, 3 out of date) and a `verbal`
   string. The status codes come from the route evidence; the shape was never run.
3. Achievements are `setAchievement(name) -> bool` plus `storeStats() -> bool`.
4. `getAchievement(name)` returns a `Dictionary` with a `ret` field (used by
   nothing shipped; recorded because upstream's common-issues page says the
   backend entries must be published first).
5. Cloud / Remote Storage is `fileWrite(name, PackedByteArray) -> bool`,
   `fileRead(name) -> {ret, buf, size}` and `fileExists(name) -> bool`. The
   `buf` type in particular is assumed, not verified.
6. The overlay is `activateGameOverlay("Friends")`, and it is **not** testable
   headless — upstream states it needs an export launched from Steam, so
   `show_overlay()` returns false in every automated run by construction.
7. The precise cloud file naming (`padel-<group>.json`) is a placeholder: the
   naming and the per-file ceiling belong to the open save-format decision and
   the cloud quota in the prerequisites ticket.

### 5.4 What the mock does and does not do

- `is_mock()` → true, `live_steam_proven()` → false, always. Both asserted.
- Default mode `UNAVAILABLE`: init status 2, gate closed, achievement/cloud calls
  **refused** (return false) and logged with the reason — never a fabricated
  success. Asserted: `ok an unlock with no Steam backend fails honestly`,
  `ok nothing is recorded as unlocked when the backend refused`.
- `INIT_FAILED` mode: init status 1, gate closed, run continues (the second soft
  path the route requires). Asserted.
- `AVAILABLE` mode: stands in for a working client so the seam can be driven.
  Used by tests, never by `Factory.create()`'s default.
- `honest_failure = true`: gate open, writes refused — the caller's "the backend
  said no" path. Asserted: `ok an open gate that refuses the write is reported as not ok`.
- Its "cloud" is an in-process `Dictionary`, and its log says so
  (`mock stored N bytes in an in-process dict, not Steam Cloud`).

## 6. Findings worth carrying forward

### 6.1 Global `class_name` identifiers do not resolve in a headless `--script` run

`.godot/global_script_class_cache.cfg` in this repo is **8 bytes (empty)** and is
not rebuilt by a non-editor run. A script that references another script by its
global class name (e.g. `SaveSchema.envelope(...)`) is a **parse error**, and the
failure is quiet: `preload` of that script yields a `GDScript` with no functions,
so every call fails at runtime with `Nonexistent function 'x' in base 'GDScript'`
while the test still printed `PASS 72/72`. Observed here, then fixed.

Consequence for anyone touching this tree: cross-script references must be
`preload` consts (`const Schema := preload("res://...")`), which resolve by path
in every run mode. `class_name` declarations are kept for the editor only.
Second consequence: any test that can have a section abort needs an explicit
completion guard, because an aborted section does **not** fail the run. The new
test has one (`ok every test section ran to completion`).

### 6.2 Godot's JSON parser returns every number as a float

`JSON.parse`/`JSON.parse_string` return `4.0` for a stored `4`. The store
therefore normalises whole-valued floats back to ints on read
(`SaveSchema.normalize_numbers`), so `career.season` reloads as `4`. Without it,
a "round-trip" test compares `4.0` to `4` and the save silently changes the
types of the game's integer fields.

### 6.3 Atomicity is the rename, and rename-over-existing was verified

`DirAccess.rename_absolute(tmp, target)` overwriting an existing target is what
makes the write atomic (POSIX `rename(2)`). It is asserted, not assumed:
`ok a second write replaces the first in place`.

## 7. NOT DONE — explicitly

1. **No live Steam behaviour is proven, at all.** Every Steam assertion is
   against `MockSteamBackend`. No sentence in this file says Steam works.
2. **The live App ID is absent** (`docs/wayfinder/tickets/steamworks-prerequisites.md`,
   open, owner Luca). Nothing was written that assumes one; the real backend
   defaults to `steamInitEx(0)` and the addon is not installed.
3. **The GodotSteam addon is not fetched, installed or vendored.** Exact-version
   4.7.2 compatibility of the prebuilt GDExtension is still unverified upstream;
   the probe in §2.3 is the step that closes it, and it has not been run with the
   addon present.
4. **No multi-device cloud proof.** The cloud round-trip is mock-to-mock inside
   one process. No Steam Cloud account, quota, conflict or second device was
   involved. The cloud quota is unknown (prerequisites ticket, open).
5. **No in-game menu wiring.** No UI reads or writes the store yet; no screen
   saves on match end. `godot/src/ui/**` was not touched (another lane owns it).
   Consequence: the store is proven as a library, not yet as game behaviour.
6. **No behavioural migration.** Only the mechanical v0→v1 envelope wrap exists.
   Whether a browser `localStorage` save is ever imported is the save-format
   decision's (open).
7. **The achievement list is empty by design.** `SOURCE_TO_API_NAME` in
   `godot/src/steam/achievements.gd` is `{}` and `unlock_source()` refuses, so no
   achievement id is invented while the prerequisites ticket is open. The six
   sources are named; the mapping is not.
8. **The overlay is not proven and cannot be**: upstream states it needs an
   export launched from Steam. `show_overlay()` returns false in every
   automated run.
9. **No careers/drill payload shapes from the neighbouring lanes.**
   `godot/src/career/**` and `godot/src/drill/**` do not exist yet, so the
   `career`/`drill` payloads here are the browser reference's fields, not the
   ported slices' structures. A mismatch between those slices' real payloads and
   this schema is untested and unknown.
10. **The demo-build achievement leak** (`scripts/demo-audit.mjs` interaction,
    S12) is not addressed here: with no ids, there is nothing to leak yet.
11. **No commit, push or deploy was performed.** Zero paid spend; no credential
    was read, written or used.
