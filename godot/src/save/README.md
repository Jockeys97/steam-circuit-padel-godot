# `godot/src/save/**` — the port's offline save

One profile, five files, under `user://save/`. The schema mirrors exactly what
the frozen browser reference persists in `localStorage` (`js/ui.js:7-11`); no
field was invented.

## Map

| File | What it is |
|---|---|
| `save_schema.gd` | Constants: columns, paths, defaults, caps, and the merge/normalise helpers. Every constant cites the reference line it came from. |
| `save_store.gd` | Read/write the files: atomic write, defaults merge, corruption quarantine, refusal reporting. |
| `save_migration.gd` | The version step: v0 (unversioned) → v1 (envelope), and explicit refusal for anything else. |

The Steam-facing side of the slice lives outside this directory, in
`godot/src/steam/**`: `cloud_saves.gd` layers Steam Cloud over these files and
never replaces them.

## On-disk format

```json
{
  "format": "padel-save",
  "schemaVersion": 1,
  "build": "alpha-0.2",
  "balance": "b7",
  "group": "career",
  "payload": { "...the browser's own payload, untouched..." }
}
```

- One file per save group: `prefs.json`, `career.json`, `history.json`,
  `drill.json`, `feedback.json`. A corrupt file costs one group, not the profile.
- `format` is a tag: a file without it that also has no `schemaVersion` is read
  as v0 and migrated; a file that claims `schemaVersion: 1` without the tag is
  refused rather than guessed at.
- `build`/`balance` record which build wrote the file (`js/data.js:20`), the same
  fields the feedback diagnostics carry.

Groups, their reference key, and their JSON type:

| Group | Reference | Type | Cap |
|---|---|---|---|
| `prefs` | `padel.prefs` (`js/ui.js:405-442`) | object | — |
| `career` | `padel.career` (`js/ui.js:12-54`) | object | — |
| `history` | `padel.history` (`js/ui.js:1540-1561`) | array | 20 entries |
| `drill` | `padel.drill` (`js/ui.js:206-230`) | object (exercise → best score) | — |
| `feedback` | `padel.feedback` (`js/ui.js:244-260`) | array | `FEEDBACK.maxQueued` = 40 |

## Rules the code enforces, and why

1. **Atomic write.** Text goes to `<file>.tmp`, is flushed and closed, then
   renamed over the target — that rename is the commit point. A failure in
   between leaves the previous file byte-identical and no `.tmp` behind.
2. **Merge against defaults on read.** `prefs` merges over the `ui` object's
   start values (`js/ui.js:460-481` + `js/audio.js:3-6`); `career` merges over
   `DEFAULT_CAREER` (`js/ui.js:12-36`). This is the reference's
   `{...defaults, ...stored}` (`js/ui.js:41`): a shallow merge, so a stored
   `lineup` replaces the default `lineup` whole. A stored payload missing fields
   loads with defaults — an older save never becomes an empty profile.
3. **Whole numbers reload as ints.** Godot's JSON parser returns every number as
   a float; `SaveSchema.normalize_numbers()` converts whole-valued floats back to
   ints on read so `career.season` reloads as `4`, not `4.0`. Fractional values
   (`gamepadDeadzone` 0.15, `volume` 0.35) are untouched.
4. **Corruption is quarantined, not deleted.** A file that does not parse is
   renamed to `<file>.corrupt.<unix>` and the group falls back to its defaults;
   the recovered group is listed in `read_all()["recovered"]`. The browser's
   `try/catch` returned an empty value and lost the bytes.
5. **An unknown version is refused, never emptied.** `SaveMigration` refuses a
   `schemaVersion` this build does not know, the file is left on disk untouched,
   and `read_all()["refused"]` names the group.
6. **Drill records still save only on improvement** (`js/ui.js:219-230`):
   `write_drill_record()` returns `skipped: true` for a lower or equal score.
7. **No Steam call lives here.** Cloud is a layer over these files.

## Deliberately not decided here

The save-format ticket (`docs/wayfinder/tickets/save-and-cloud-format.md`) is
open and owns: whether a browser `localStorage` profile is ever imported, the
cloud file mapping and quota, the conflict rule, and any *behavioural* migration.
This module implements only the mechanical envelope migration and states its
placeholder conflict rule (local always wins) in `godot/src/steam/cloud_saves.gd`.

## Proof

`godot/tests/save_steam_test.gd` (headless, `--script`) round-trips a realistic
profile, proves the defaults merge with a deliberately incomplete payload, proves
the interrupted-write case leaves no partial file, recovers a corrupted file,
migrates a v0 sample, and refuses a `schemaVersion: 99` save.

```sh
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
  GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path godot/ --script res://tests/save_steam_test.gd
# PASS 137/137, exit 0
```

## Engine gotcha this module had to work around

A headless `--script` run does **not** rebuild
`.godot/global_script_class_cache.cfg` (it is empty in this repo), so global
`class_name` identifiers are not resolvable at parse time. A script that
references `SaveSchema.x` fails to compile and is silently loaded as a
function-less `GDScript`, which then fails every call at runtime. Cross-script
references under `godot/src/save/**` and `godot/src/steam/**` are therefore
`preload` consts, which resolve by path in every run mode. The inherited
`class_name` declarations are kept for editor/discoverability only.
