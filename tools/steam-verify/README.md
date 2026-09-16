# tools/steam-verify — GodotSteam addon verification scratch

This directory exists so the GodotSteam GDExtension could be fetched, hashed and
**loaded in the pinned engine** without touching the game project. It is a scratch
area, not shipped code.

Result and full write-up: `docs/wayfinder/evidence/steam-addon-verification.md`.

| Path | What it is |
|---|---|
| `dl/godotsteam-4.22.1-gdextension-plugin-4.4.zip` | the release asset, verbatim (27,290,405 B, `sha256 2b12b349…bfa8f`) |
| `unpacked/` | the zip, extracted, untouched |
| `src/` | upstream C++/XML at release commit `5853a774…` (register_types, godotsteam.cpp/.h, project settings, doc_classes/Steam.xml) |
| `probe/` | an **isolated Godot project** (its own `project.godot` + `.godot/extension_list.cfg` + `addons/godotsteam/`) used to load the plug-in |
| `probe/probe_api.gd` | dumps the registered surface from `ClassDB` and calls `steamInitEx(0)`; writes `probe_report.txt` and `api_surface.json` |
| `probe/probe_call.gd` | ONE native Steam call per engine run (`-- <method>`), to record what a gate-closed call does |
| `releases.json`, `rel_gde.json`, `tags.json`, `tree.json` | Codeberg API metadata used for provenance |

## Rules this directory follows

- **No credential is used or requested.** Everything here is public data.
- Every engine invocation is one process at a time:
  `flock -w 900 /tmp/padel-godot.lock timeout <n> env -u DISPLAY … --headless`.
- The engine is the pinned `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`.
- The game project `godot/` is not modified by anything in here.

## Re-running

```sh
cd /root/projects/steam-circuit-padel-pro
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path $PWD/tools/steam-verify/probe/ --script res://probe_api.gd

for M in fileExists getFileSize fileWrite fileRead setAchievement storeStats \
         getAchievement activateGameOverlay; do
  flock -w 900 /tmp/padel-godot.lock timeout 60 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
    --path $PWD/tools/steam-verify/probe/ --script res://probe_call.gd -- "$M"
done
```

## Two traps, learned the hard way

1. **A bare copy of the addon does not register.** Measured: with
   `addons/godotsteam/` present but no `.godot/extension_list.cfg` entry,
   `Engine.has_singleton("Steam")` is `false`. The editor writes that file; to
   reproduce the negative control, copy `probe/` and delete its `.godot/` first.
2. **A GDScript runtime error aborts only the function it happens in**, and the
   caller then continues — so an error before `quit()` leaves an empty `SceneTree`
   spinning forever (this cost one 180 s timeout). Keep each risky step in its own
   function, write evidence to disk *before* a risky native call, and force a quit
   from `_process`.
