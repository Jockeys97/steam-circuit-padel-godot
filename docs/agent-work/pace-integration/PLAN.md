# Pace integration

Approved scope: port Luca's 9ea56e5 and e2be431 pace feature into the existing
codex/integrate-arena-11m working tree at 7b4dc56, preserving all dirty work.
No arena assets, coop changes, commits, branch changes, or live save changes.

One implementation phase: capture exact baseline of affected files, port the
pace module, saved preference validation, match-start factor, and Settings/Modes
controls. Use Luca's patch as the source, not wholesale replacement of diverged
files. Preserve current 1.0 pace as default (brisk); invalid/missing saved values
fall back to it. Scale simulation time once, never balance constants. Retain
fixed-step input semantics and bounded catch-up. Ensure new rally stamina and
animation bridge remain compatible with the simulation rate.

Owned scope: files touched by the two source commits under godot/game,
godot/src/save, godot/src/sim/pace.gd, godot/src/ui/data/UiData.gd,
godot/src/ui/screens/{ModesScreen,SettingsScreen}.gd, their relevant tests and
generated UID sidecars, plus evidence and REPORT.md in this directory.
Other files require a concrete integration dependency, reported explicitly.

Acceptance: all five presets selectable in Settings and match setup, persisted
through isolated test saves and applied on next match; measured fixed ticks per
real frame correspond to 1.5/1.0/0.75/0.6/0.5; missing/invalid preference preserves
old behavior. Run relevant pace, save, modes layout, court speed and stamina
checks; inspect UI layout at a narrow supported size. Tests must not overwrite
the user's profile. Report commands, exits, artifacts, changed paths, and limits.

Astra reviews actual delta against captured baseline and verification evidence.
