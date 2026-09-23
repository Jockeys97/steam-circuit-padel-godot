# Jukebox player card — design, evidence, limits

## What the request was

The right-hand side of the Jukebox screen was an inspector with a player bolted
under it, and a full-screen-height generative prompt dominated it. The user asked
for a more beautiful right side, especially the player.

## Design contract delivered

The right column is now one dominant console card on the game's own navy/cyan
palette:

- hero row: a procedural record motif beside the track title, its arena, the
  category lamp and the honest state line;
- real transport readout: elapsed and duration read from the live stream, with the
  progress bar driven by that same fraction;
- transport row: previous / play / stop / next plus the music volume, in one band;
- everything long (BPM, key, style, generative prompt and its copy button) moved
  into a collapsed "Metadati & Prompt" section that the reader opens on purpose.

Selection and playback are two separate facts and the screen shows both: the hero
describes the **selected** track, the "▶" row marker and the "In Riproduzione" line
name the track that is **actually streaming**.

## Files

- `godot/src/ui/jukebox/jukebox_screen.gd` — the console card, the readout, the
  selection/playback split and the collapsed metadata section.
- `godot/src/ui/jukebox/jukebox_record.gd` — the procedural navy/cyan disc: drawn
  once, spun by a tween on the node's rotation, no shader and no per-frame redraw.
- `godot/src/audio/soundtrack_manager.gd` — additive readout only
  (`active_player`, `is_playing`, `playback_position`, `playback_duration`,
  `playback_progress`). No existing function or field was changed.
- `godot/tests/jukebox_player_test.gd` — this screen's own suite (checks, plus the
  native captures when it is given a display).

Nothing in the catalogue, the assets, the prompts, the left list order or its
selection semantics was changed.

## Verification

All commands from the repository root, Godot 4.7.2 (`/opt/homebrew/bin/godot`).

| command | result |
| --- | --- |
| `--headless --path godot --script res://tests/soundtrack_manager_test.gd` | 62 checks, 0 failures, exit 0 |
| `--headless --path godot --script res://tests/test_jukebox_screen36.gd` | exit 0, 47 track buttons, badges and playback unchanged |
| `--headless --path godot --script res://tests/jukebox_player_test.gd` | 89 checks, 0 failures |
| `--rendering-driver opengl3 --path godot --resolution 1280x720 --script res://tests/jukebox_player_test.gd` | 100 checks, 0 failures, exit 0, three captures |

Covered by the dedicated suite: the title/arena pair that `_select_track` used to
leave empty; both badge text contracts; the idle 0:00 / --:-- / empty bar state;
elapsed, duration and progress equal to the stream's own readers; selection versus
playback separation (including the eyebrow and the single "▶" row); the file-less
branch (Play disabled, no checkmark, honest "in attesa" line, zero readout, disc
still); the volume slider opening on the Music bus level and still writing dB to
that bus; visible focus rings and Play taking keyboard focus; no overflow at
1280x720 and 1920x1080 with the longest catalogue title, collapsed and expanded;
the disc never enabling `_process`, one tween handle across rapid stop/play; and the
back / ESC lifecycle emitting `closed`, stopping playback and freeing the screen.

## Captures

`captures/jukebox-player-1280x720.png`,
`captures/jukebox-player-1280x720-prompt.png` (expanded metadata) and
`captures/jukebox-player-1920x1080.png`. Rendered from the real viewport with
`RenderingServer.force_draw(false)` and checked non-blank by colour sampling.

One window resize per native run, as the ported capture harness does: a second
resize-and-draw inside one process aborted silently on macOS, so the two 1280x720
states are captured first and the 1920x1080 state last.

## Limits and residual notes

- Headless playback is real here (the dummy driver advances the stream), so the
  moving readout is asserted in both phases rather than only in the native one.
- The disc's cost is described as shape, not measured: it repaints only when its
  accent, playback state or size changes. No benchmark was run.
- Seek was left out on purpose (the brief allowed skipping it): the readout is
  honest and there is no fake position control.
- The engine still prints its shutdown warnings (leaked instances, resources still
  in use) at exit. Both suites exit 0; the dedicated suite frees its screens
  explicitly first. These warnings are recorded, not attributed.
- Running natively generated the 47 `godot/assets/audio/music/*.ogg.import` files
  (the repository tracks 413 other `.import` files). They were left in place.

## Git

Baseline for this work: `e01b098`. HEAD advanced externally during the task
(`4c871f6`, then `e445a58`/`3c53335`); those commits are not mine and nothing was
reverted. The work above is the uncommitted diff on top plus the new files.
