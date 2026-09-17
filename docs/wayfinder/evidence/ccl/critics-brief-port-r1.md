# Independent critic brief — Steam Circuit Padel Pro, the Godot 3D port (round 1)

You are an independent critic. You did not write this port and nobody here can score their
own work. Judge the artifact itself, not this brief: a claim earns nothing until it is
visible in the artifact or in the evidence listed below.

You are one of two critics on a council; you cannot see the other critic's verdict, and
you must not try to. Ignore any file that looks like another critic's report.

## The artifact

`/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` — a steampunk
padel arcade game being rebuilt in **Godot 4.7.2** from a browser game that ships in the
same repository. The browser game (`js/`, `index.html`, `styles.css`, `assets/`) is the
**frozen reference**: the port must reproduce it, and nothing may edit it. The Godot
project is `godot/`.

Judged revision: commit `9cca592` plus the working-tree changes in progress (the tree is
shared with another session; treat it as read-only).

## The evidence you must work from

1. **Renders of the port** (real frames, 1280x720, rendered on this Mac through Metal):
   `/tmp/padel-captures/` — `menu-full.png`, `menu-demo.png`, `arena-*.png` (nine arenas),
   `hud.png`, `rally.png`, `result.png`, `quickmatch-serve.png`, `mode-drill.png`,
   `mode-tournament.png`, `mode-career.png`, `mode-career-screen.png`.
2. **Renders of the frozen reference** (headless Chrome on the same machine, same size):
   `/tmp/padel-ref/ref-menu-1280x720.png`, `ref-menu-1280x2400.png`, `ref-menu-demo.png`.
3. **A parity inventory** built by reading the reference source outward:
   `/tmp/padel-parity-inventory.md`. Treat its counts as claims to check, not facts.
4. **The oracle run** (the repository's own suites, this Mac, serialised):
   `/tmp/padel-oracle-r1.md` with each command's exit code and tally line.
5. **The repository itself** — read anything you like: the reference (`js/**`,
   `index.html`, `styles.css`, `assets/**`) and the port (`godot/**`), including
   `godot/tests/**` and `docs/wayfinder/evidence/**`.

## The checklist — 9 items, boolean, one claim each

Answer each with PASS or FAIL, then one line of evidence, then the concrete fixes that
would flip a FAIL. Item 9 is the only soft item; one soft fail is allowed.

1. **GATING — UI surface parity.** Every screen the browser reference renders (title,
   athlete select, mode select, arena select, help/how-to-play, history, challenges,
   career profile, feedback, drill, settings, in-match HUD, result, pause overlay,
   loading, on-screen keyboard, colourblind filter) has a reachable counterpart in the
   port. Reachable means a scene or script in `godot/` loads it — a file on disk that
   nothing references does not count.
2. **GATING — Asset parity.** Every asset the reference actually loads (arena backdrops,
   athlete portraits and sprite sheets, outfit previews and poses, UI art, key art,
   controller glyphs, mode-card art, webfonts, sound effects, music) is carried into the
   Godot project AND reachable at runtime. Where the port deliberately substitutes 3D for
   2D art, say so and say whether the substitute covers the same content.
3. **GATING — Visual language parity.** Compare the port's renders side by side against
   the reference's own renders and name concrete deltas: typography and type identity,
   palette and accent colours, layout and hierarchy, legibility, any clipped or truncated
   label, any accented Italian rendered as ASCII, any mixed-language label.
4. **GATING — The score is wired into the live match.** The ported music module plays
   during a real match, is driven by the reference's own intensity formula, and stops at
   the match's end.
5. **GATING — Oracle green on a fresh clone on this Mac, demo build included.** Every
   suite reports PASS with zero `SCRIPT ERROR` next to it. Verify against
   `/tmp/padel-oracle-r1.md` and by reading the suite that owns any claim you doubt.
6. **GATING — Cross-engine parity unregressed.** The same seed and scripted input still
   produce identical tick-by-tick results between the browser reference and the Godot core.
7. **GATING — The known defect list is closed.** Every finding the second independent
   review raised (`docs/wayfinder/evidence/independent-review-2.md`, items F-1 to F-11) is
   either repaired with a test that can fail, or shown false with evidence. None may be
   carried silently.
8. **GATING — Pause and rematch are stable.** Pausing and then rematching does not freeze
   the simulation, does not leave a stale HUD, and clears the queued one-shot inputs the
   way the reference's own pause does.
9. **SOFT — Pack integrity.** An exported build carries the athlete rigs and the UI assets
   (no excluded tree inside the pack). Soft only because exporting may not be possible on
   this host; if it cannot be built, report it as not-established, never as a pass.

## Output format — exactly this, nothing else

For each of the nine items:

```
ITEM <n> — <short name> — PASS|FAIL
evidence: <one line, with the file path, line, or render you saw it in>
fixes: <the concrete changes that would flip a FAIL; write "-" for a PASS>
```

Then:

```
PASSED: <n>/9
SCORE: <passes/9*10, one decimal>
BIGGEST GAP: <one line>
RETIRE-OR-REFINE: <retire if fewer than 5 items pass, else refine>
```

## Rules

- **Read-only.** Do not create, edit, rename or delete anything. Do not run git commands
  that change state. You may run read-only commands (`git log`, `git status`, `grep`,
  `ls`, `python3` for image inspection) if you need them.
- **Strict beats kind.** No credit for work that is in progress, claimed in a document, or
  visible only in a comment. If you cannot establish a fact, write `not established` and
  say what would establish it.
- **Judge against the reference, not in a vacuum.** Where the reference has a screen, art
  file or sound that the port lacks, that is a FAIL with the reference path cited.
- **Do not pad.** Short, specific, citable lines only.
