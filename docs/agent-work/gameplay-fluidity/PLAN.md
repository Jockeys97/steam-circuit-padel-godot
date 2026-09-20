# Gameplay fluidity and tactical interception

Approved user intent: improve natural animation and AI volley/bounce decisions.
Only working repository: /Users/alessiofantini/Documents/steam-circuit-padel-11m,
branch codex/integrate-arena-11m. Preserve all dirty and concurrent changes.

## Contract

One coherent implementation bundle, then Astra acceptance. Simulation owns
contact validity and timing; presentation must never delay input or alter ball
physics. Keep public interfaces backward-compatible. No paid asset generation,
credentials, dependencies, commits, pushes, or edits to other checkouts.

1. Add a deterministic tactical contact decision to the opponent AI: intercept
when height, reach, position and available time make a comfortable volley;
otherwise allow a reachable bounce or glass recovery. Never impose a universal
bounce rule, wait past a second bounce, or volley a serve illegally. Retain
reaction delays, receiver ownership, difficulty distinctions and seeded behavior.
Inspect existing forecast/contact helpers before introducing new state. Mirror
intentional simulation behavior in js/game.js and Godot, with parity tests.
2. Improve presentation with directional lateral/backward footwork, a small
preparation split-step, anticipatory shot preparation and recovery, and a distinct
compact volley. Use existing rigs and bounded procedural/in-place animation;
no root motion affecting simulation coordinates. Preserve Fiamma ready idle,
Maestro asset, Fornaio stand-in, wrist attachments and material corrections.
Smooth transitions without blending away the authoritative contact pose.
Dedicated full smash/bandeja and separate forehand/backhand asset production are
follow-on work, not grounds to spend Meshy credits.
3. Add tests and evidence: net volley, deep uncomfortable interception deferred
to bounce, late emergency return, service reception, glass recovery, deterministic
JS/Godot cases; compare volley/bounced-contact counts on the same representative
seeded scenarios before/after without requiring an arbitrary global quota.
Validate animation onset/recovery, contact timing, skeleton compatibility and
visual evidence of movement and volley. Run relevant existing AI, animation,
Colosso and Fornaio gates. Do not rewrite expected trace digests without explaining
the intentional behavior changes and retaining meaningful assertions.

## Ownership and handoff

One astra_flash_builder owns in-scope discovery, implementation and verification:
godot/src/sim/sim.gd, js/game.js, godot/game/athletes_view.gd,
godot/src/character/athlete_rig.gd, tightly related simulation state/helpers only
if necessary, dedicated tests and evidence under this feature directory.
No menus, theme, compact timing labels, asset replacements or unrelated files.
Before editing capture the actual dirty-file baseline and stop on overlapping
active writes. Worker report must list changed paths, commands, exit statuses,
behavior measurements, visual evidence and limitations. Root reviews actual
baseline-relative changes, specification and quality in one pass.

## Execution status

Completed directly by Astra under explicit user authorization after two incomplete
Flash executions. Active root session metadata confirmed gpt-6-astra; the static
doctor default did not describe the UI override. See REPORT.md for implementation,
tests, measurements and limits. No further delegation used.
