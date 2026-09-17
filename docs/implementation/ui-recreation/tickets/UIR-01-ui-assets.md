---
id: UIR-01
title: UI asset acquisition and import (fonts + images)
slug: ui-assets
state: done
readiness: potential
owner_role: asset worker
blocked_by: []
blocks: [UIR-02]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-01-assets.md
---

# UIR-01: UI asset acquisition and import (fonts + images)

## Worker brief (copy-paste)

> Bring the reference's display fonts and UI images into the Godot project. Download Lilita One (400) and Nunito (400/600/700/800) as static TTFs into `godot/assets/ui/fonts/`, copy the UI webp images from `assets/ui/**` into `godot/assets/ui/**` keeping their relative paths, run a Godot `--import`, and record every file's size and sha256 with its license note into `evidence/uir-01-assets.md`. You own `godot/assets/ui/**` and the generated `.import` sidecars for those files. Do not touch any other directory.

## Why this exists

The port has no font file anywhere (verified: zero `.ttf`/`.otf`/`.woff*` in the repo) and no theme resource (the only `.tres` is `godot/assets/audio/padel_audio_bus.tres`). The reference loads Lilita One + Nunito 400/600/700/800 from Google Fonts (`index.html:11-16`) and keys art from `assets/ui/**`. Godot cannot reference files outside `godot/`, so the images must be copied in and the fonts fetched once.

## Prerequisites (Definition of Ready)

- Plan approved; pack read.
- Network access for the font download (or a local font file Luca supplies).

## Read allowlist

- `index.html:11-16` (font families and weights), `index.html:31-710` (which images each screen uses)
- `assets/ui/**` (source images: `steam-circuit-key-art.webp`, `xbox-controller-steam.webp`, `playstation-controller-steam.webp`, `generic-controller-steam.webp`, `modes/quick-match.webp`, `modes/tournament.webp`, `modes/career.webp`)
- `assets/athletes/*.webp`, `assets/arenas/*.webp` (preview images the card grids use; copy the set the reference references)
- `styles.css` `url(...)` occurrences for the exact image list per selector

## Write allowlist (you own these)

- `godot/assets/ui/**` (new; fonts under `godot/assets/ui/fonts/`, images mirroring `assets/ui/**` relative paths)
- `godot/tests/ui/fonts_assets_probe.gd` and its `.uid` sidecar (optional load-check probe; delete both before hand-back if you prefer, the evidence table is the durable artifact)
- Generated sidecars for files you add: `godot/assets/ui/**/*.import`
- `docs/implementation/ui-recreation/evidence/uir-01-assets.md`

No other writes. No commits.

## Do not touch

`godot/src/**`, `godot/game/**`, `godot/tests/**`, `godot/project.godot`, `js/**`, `assets/**` (read-only source), `index.html`, `styles.css`.

## Microsteps (do in order)

1. Confirm nothing exists yet: `ls godot/assets/ui` must fail; `find godot -name '*.ttf'` must print nothing.
2. Create `godot/assets/ui/fonts/`. Download the font files. Proposed sources (PROPOSED, unverified in this session; verify each URL returns a TTF before use, both families are SIL OFL so embedding is licensed):
   - `LilitaOne-Regular.ttf` from `https://github.com/google/fonts/raw/main/ofl/lilitaone/LilitaOne-Regular.ttf`
   - `Nunito-Regular.ttf`, `Nunito-SemiBold.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf` from statics in the google/fonts repo (`ofl/nunito/static/…`) or from the fonts.google.com "Download family" zip. Prefer static TTFs over the variable font: Godot's variable-font variation coordinates would make the theme's weight assignment a second mechanism, and the reference only uses 400/600/700/800.
   - If a URL 404s: record it in the evidence file and fetch the zip from `https://fonts.google.com/download?family=Nunito` instead. Never substitute a different family.
3. Copy images: mirror the reference paths under `godot/assets/ui/`:
   ```bash
   cd "$REPO"
   mkdir -p godot/assets/ui/modes
   cp assets/ui/steam-circuit-key-art.webp assets/ui/xbox-controller-steam.webp \
      assets/ui/playstation-controller-steam.webp assets/ui/generic-controller-steam.webp \
      godot/assets/ui/
   cp assets/ui/modes/*.webp godot/assets/ui/modes/
   ```
   Then the athlete and arena previews the card grids use: copy `assets/athletes/<id>.webp` and `assets/arenas/<id>.webp` into a parallel structure under `godot/assets/ui/` (for example `godot/assets/ui/athletes/`, `godot/assets/ui/arenas/`). Record the exact mapping table in the evidence file; the screens will reference these paths.
4. Run the import so `.import` sidecars and UIDs are generated:
   ```bash
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
   "$GODOT" --headless --path godot/ --import
   ```
   Expect exit 0; first import takes about a minute on this Mac.
5. Load-check: a five-line probe script prints each imported resource's path and class (`load(path)`), run headless. If Godot 4.7.2 cannot import a `.webp` (expected: it can, WebP import is native), record the failure and stop rather than converting formats silently.
6. Record in `evidence/uir-01-assets.md`: every file's path, bytes, sha256, its source, the font licenses (OFL text pointer), the image mapping table from `assets/**` to `godot/assets/ui/**`, and the import command with its exit code.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --import ; echo "exit=$?"
# load-check probe: Godot runs scripts only from inside the project, so the probe is a tracked file at res://tests/ui/fonts_assets_probe.gd (owned by this ticket; optional; you may delete it and its .uid after the log is written)
"$GODOT" --headless --path godot/ --script res://tests/ui/fonts_assets_probe.gd ; echo "exit=$?"
```

If you create `godot/tests/ui/fonts_assets_probe.gd`, it is yours alone: no other ticket edits it. Delete it before hand-back if you prefer; the evidence file's load-check table is the durable artifact.

## Acceptance commands (Linux CI form, existing, host agents only)

Not applicable; this ticket is asset staging and runs wherever the repo lives. The import command is the same with the Linux binary.

## Evidence to hand back

- `evidence/uir-01-assets.md` with the file register, hashes, licenses, mapping table, import exit code.
- Hand-back message: font files imported (count), images copied (count), any URL that failed.

## Definition of Done

- [ ] Five font TTFs present under `godot/assets/ui/fonts/`, each with sha256 recorded.
- [ ] All UI mode images + key art + controller images + athlete/arena previews copied under `godot/assets/ui/**`, mapping table complete.
- [ ] `--import` exit 0; every asset loads (load-check table green).
- [ ] Evidence file complete; only allowlisted paths changed.
- [ ] No `.import` sidecar committed outside `godot/assets/ui/**`.

## Failure and recovery

- Download unavailable: stop and report; do not fabricate font files and do not fall back to a different family.
- A webp fails to import: record path + engine error; do not convert to PNG silently (a format change is a design decision, not a workaround).
- Import generates sidecars in unrelated directories: those were pre-existing generated noise; leave them uncommitted and note them.

## Traces

`index.html:11-16` (fonts), `index.html:31-710` (image usage), `styles.css` `url()` rules; handoff step 3; pack README "Assets" section.
