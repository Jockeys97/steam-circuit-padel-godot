# Local macOS round — three red surfaces repaired, the score wired, and the real gap measured

Second local session on the owner's Mac, at commit `9cca592` plus the work below. Every
number here comes from a run on this machine, strictly serialised one engine process at a
time (macOS ships no `flock`, so the runs go through a small mkdir mutex).

## 1. The playable slice's demo build could never pass — test-side defect, repaired

`_tiers_playable` and `_arena_library` demanded all four AI tiers construct a match and
that two freely chosen arenas reach both the environment and the simulation. A demo build
correctly pins one difficulty and one arena (`js/build.js` DEMO_CONTENT: difficulty
`medium`, arena `clockwork`), so four checks failed by construction on this commit.

The tests now assert the pin in a demo build — every tier request must answer with the
pinned difficulty, every arena request must land on the granted arena in BOTH the
environment and the simulation, with the pinned index itself asserted against the
reference's declared `medium` — while a full build still demands all four tiers and free
choice. The gate itself was not touched.

## 2. The "export the pack first" red was a source-checkout artifact

The slice asserted its exported pack exists, and `godot/build/` is gitignored, so a fresh
clone failed one check and silently skipped the two pack checks behind it. The suite now
prints which mode it ran in (`# PACK_MODE ... present` / `... absent (source checkout) —
not run, not scored`) and runs and enforces both pack-content checks whenever a pack is
present. No vacuous check was added in its place.

## 3. The music red was real: the vendored dump's provenance was wrong

`godot/src/audio/music_reference.json` recorded a fingerprint of `js/main.js` of
95,899 bytes; the committed `js/main.js` is 100,390. Re-running the repository's own
extractor settled it: **the music payload is byte-identical** — `engine`, `prog`,
`layers`, `not_reproducible`, the self-checks and all 15 scenarios compare equal. Only the
recorded source hash and one anchor (`intensity_formula_lines` moved from
`js/main.js:1220-1226` to `:1273-1279`) had drifted. The dump was re-vendored with the
repo's own tooling, so the provenance now matches the committed reference. The
generated-artifact comparison in the test is likewise mode-honest when
`tools/*/out/` (gitignored) is absent.

## 4. The score is now wired into the live match — the hand-off's open item

`game/match_audio.gd` builds the music engine alongside the effect port, starts it with
the match at the reference's own 0.12 (`js/main.js:1211-1212`), drives its intensity every
tick from the reference's formula

    min(1, 0.12 + min(1, rallyHits/12) * 0.55 + min(0.35, sets*0.15 + games*0.02))

(`js/main.js:1273-1279`), and stops it when the match ends (`:1438`). The new assertions
run inside the existing full-playthrough section, on the same match node, so the probe
costs the run no extra scene — the object-accumulation ceiling is untouched (delta 383
against a 450 gate) and the score's scheduler is proven to have started real voices, not
just had its setters called.

## Oracle, on this Mac, after the repairs

| Suite | Result |
|---|---|
| engine harness | PASS 8/8, exit 0 |
| playable slice, full | **PASS 291/291**, exit 0 |
| playable slice, demo | **PASS 228/228**, exit 0 |
| saves + Steam seam | PASS 137/137, exit 0 |
| input | PASS 4/4, 308 checks, 0 failures |
| rules audits | PASS 10/10, 221 checks, mismatched=[] |
| music port | PASS (dump re-vendored; byte-identity no longer red) |

No `SCRIPT ERROR` accompanies any PASS in any of these runs.

## 5. What the round did NOT fix — the honest gap

A parity inventory built outward from the reference source (`/tmp/padel-parity-inventory.md`)
counts 28 UI surfaces and 238 assets in the browser game. **17 surfaces and 223 assets are
missing, unreachable, or reduced.** Named, worst first:

- Six screens absent: help/how-to-play, history, challenges, career profile, feedback,
  settings. Copy for them already sits unused in the locale tables.
- The pause overlay is a boolean: no resume/rematch/quit, no controller tab, no smash
  tutorial. The result screen is a stub: no stats, objectives, or actions.
- In-match HUD gaps: game timer, serve/score banner (text only reaches the log line),
  mini-map, action deck, touch controls, shot meter, HUD buttons.
- Reference art unported: 36 sprite sheets, 144 outfit poses, 25 outfit previews, 6
  athlete portraits, the UI art files, the controller glyphs, the mode-card art, and
  **the two webfonts** — the reference's type identity is gone, replaced by the engine's
  default font.
- Three arena backdrops were never copied (`officina-vapore-standard`,
  `deposito-locomotive`, `clockwork-factory`), costing five of nine arenas their painted
  backdrop; four of six athletes have no rig and fall back to the Volpe model.

**Council frame, frozen and not yet scored:** nine-item boolean checklist against the
frozen reference (target: all gating items pass; Luca's 8.5 floor allows at most one soft
fail), two rounds maximum, zero paid spend, oracle as above plus indexed renders plus
cross-engine parity digests. Artifact pinned at `9cca592`; Godot tree
`81b90334c8fec66692a20ab75370487898f36f8e`; frozen reference tree
`cf1edec26aadfcf3d4c0a3a08f3e3ec910ddc93f`.

**Honest current score: about 4 of 9.** The score's wiring and the oracle are genuinely
green; UI parity, asset parity and visual-language parity fail, and pause/rematch cannot
be judged because the pause overlay does not exist yet. **8.5 is not reachable from this
tree** — the six screens plus the reference art and fonts are a tranche of work, not a
polish pass. Biggest single gap: the port lost the reference's screens and its art, not
just its pixels.

**Note for the next session:** the sub-agent lane (ChatGPT/Codex subscription) returned
usage-limit errors on every dispatch this session, so the work above was done directly
rather than delegated. The rendering on this Mac works through Metal with real frames
(`--rendering-driver opengl3 --resolution 1280x720`); plain `--headless` still renders
blank for capture targets, exactly as the Linux evidence file says.
