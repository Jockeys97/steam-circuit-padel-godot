# OST integration audit — 2026-09-23

Scope: canonical Godot 3D checkout, source call graph and resource references.
No music routing was changed by this audit.

## Result

47 OGG catalogue tracks are available for manual audition in the jukebox.
None currently has an automatic runtime trigger in the game/menu flows inspected.
Catalogue mappings are not evidence of automatic playback.

- `godot/src/ui/jukebox/jukebox_screen.gd` constructs SoundtrackManager and calls
  `play_track` for the selected catalogue entry.
- Searches of production `.gd`, `.tscn`, `.tres` and `project.godot` find no other
  consumer of SoundtrackManager or the OST folder. Calls to `play_for_arena` and
  `play_context` outside their definitions are limited to tests.
- `godot/game/match_controller.gd` creates MatchAudio and resets it for the match.
- `godot/game/match_audio.gd` creates `res://src/audio/music.gd`, not
  SoundtrackManager. `_drive_music` adjusts its procedural sequencer intensity
  from rallyHits, games and sets; it stops it on match result.
- `godot/game/main_menu.gd` uses AudioPort for mixer preferences, not OST playback.

## Catalogue versus actual use

| Group | Count | Automatic triggers |
| --- | ---: | --- |
| Arena-labelled tracks | 16 | None |
| Menu, roster, career, training, climax, victory | 6 | None |
| Epic suite | 8 | None |
| Sawano/Titan suite | 12 | None |
| DBGT suite | 5 | None |

Existing soundtrack tests validate lookup tables, file availability and isolated
manager playback. They do not validate menu/match integration.

## Separate implementation needed

Introduce a single owner for OST context transitions; replace or explicitly mute
the existing procedural score to avoid two music layers. Wire menu/roster/career,
arena start, training and results; define epic/special trigger policy and minimum
dwell time so short rallies do not constantly switch tracks. Preserve mixer,
pause, replay and exit lifecycle. Validate real menu-to-match-to-results transitions.
Review arena IDs before wiring: legacy arena labels and runtime IDs differ.

No claims here of listening through every game mode or profiling audio performance.
