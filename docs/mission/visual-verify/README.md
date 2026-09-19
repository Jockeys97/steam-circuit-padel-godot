# Visual verification — why the loop kept passing frames that are wrong, and the Jev probe

Owner question, 2026-09-19: *can Jev run the visual verification loop, given the loop keeps failing?*

**Short answer: no — Jev has no eyes. It can only be the last mile (rubric application over a
pixel-derived inventory). Measured today: 4/4 right from an inventory, 1/4 and "clean" from a
summary.**

## 1. What actually failed

The loop has three legs. Two work; the third does not exist.

| leg | state | evidence |
|---|---|---|
| capture | works | `evidence/vvl-uir/` — 21 screens, the characters screen in 5 states, two resolutions, done by a script (`logs/sweep-journal.txt` ends `SWEEP DONE`) |
| deterministic checks | green, and blind to this class | `arena_look_test` 373/373, `arena_kit_test` 83/83, world-arena proof 883 checks, 0 `SCRIPT ERROR`. They read the **scene tree**: node exists, string is right, colour came from the right theme token. A glyph that renders in the wrong ink under the right token passes every one of them. |
| review (the eye) | **absent** | `evidence/vvl-uir/critic/` and `evidence/vvl-uir/fixes/` are **empty directories**. The captures were produced and never reviewed; no fix leg was ever opened. |

Where an eye *did* run, it was scoring text about the frames, not the frames: `review-round2.md`
re-hashed the 16 frozen captures and the 9 step logs, then scored **80/80 PASS** — while the CEO's
read of the same arenas found **aurora too dark to play** (mean luma 79 → 37, court lines and glass
lost). Re-hashing proves the file did not change. It says nothing about what is in it.

## 2. The captured frame, measured

`evidence/vvl-uir/port-1710x1073/ui-characters.png` — the athlete picker. The frame the owner
attached is the same screen at devicePixelRatio 2 (3420×2146 = 1710×1073 × 2).

**Deterministic — raw pixel means, no vision involved:**

- **The bottom 112 px of the frame are pure black** (`meanRGB = [0,0,0]`) across the full width, all
  six column bands. Screen content stops at y = 2033 of 2146.
- **The second row of cards is truncated.** Its panel is 606 px tall against the top row's 777 px,
  and its content stops after the ability line: The Oracle and The Colossus carry **no stat row and
  no status word**. The two rows are not the same card.
- Evidence crop: `evidence/row2-truncation-and-black-band.png`.

**Code side — what the stat row is supposed to be** (`CharactersScreen.gd:787-790`,
`padel_theme.tres:434`, `theme/README.md:133`):

- one text label of **five glyphs**: `U+25AE` filled + `U+25AF` empty to five ticks;
- ink from the theme token `stat_bar` = `Color(0.4941, 0.8784, 1)` = **#7ee0ff** (cyan);
- font size 12, wrapper `modulate` alpha 0.85, text clipping on.

**Vision read of the mark row** (two passes agreed, one dissented — see §5): **four** marks, not
five, in a **neutral / desaturated ink**, not the theme's cyan. Every core pixel sampled in that row
is neutral (`≈131,133,153` — a desaturated blue-grey), which a `#7ee0ff` glyph cannot average to.
Evidence crop: `evidence/card1-stat-mark-row.png`.

Three defect classes in a frame the capture loop had already produced: a wrongly-rendered stat row,
a truncated second card row, and an unpainted black band. None of them is visible to any green suite.

## 3. The Jev probe — measured, not argued

Two states, same five questions, one call each, model pinned `typesafe/jev-1.13-20260917`.

| question | ground truth | state A: 243-char summary | state B: 2,391-char pixel inventory |
|---|---|---|---|
| six cards present | yes | 0.96 ✔ | 0.98 ✔ |
| bars read as intended | **no** | **0.26** ✘ (leaning clean) | **0.05** ✔ |
| something is cut / clipped | **yes** | **0.25** ✘ | **0.99** ✔ |
| defect class | ink not from the theme | **`none` 0.59** ✘ (conf 0.49) | **`colour_mismatch` 0.82** ✔ |
| severity, 0–4 | clearly wrong | **0.52** ✘ (level 0 at 0.81) | **3.49** ✔ (levels 3/4 at 0.43/0.55) |

**A thin state does not just lose precision — it returns a false clean bill.** The summary state
called the frame clean on every question that had an answer. That is the current loop's failure mode
in one line.

Cost: $0.000029 + $0.000053; 681 ms / 649 ms. Ledger: `jev-ledger.jsonl` (2 rows). Files: `probe-01/`.

## 4. The loop that would work

Three layers, each doing only what it can prove:

1. **Deterministic extractor (never Jev).** Read the element's rect from the scene tree, then probe
   the capture inside it: ink-colour histogram against the theme token, mark count by connected
   components, element-vs-viewport-edge test. This turns "four desaturated marks where five cyan
   ticks belong" and "the bottom 112 px are unpainted black" into numbers. **My own ad-hoc scan could
   not isolate the mark row from the small text around it** — band thresholds alone were not enough.
   The extractor must therefore be driven by the audit's own printed Rects, not by a blind scan.
2. **Perception (vision → inventory).** A vision pass writes a *neutral inventory*: what is present,
   absent, where, what colour, what is cut. No verdicts — a verdict in the state is what Jev echoes
   back.
3. **Judgment residue (Jev, one batched call).** Rubric questions over the inventory. Measured
   today: 4/4 on the rich state. ~$0.00005 and 0.7 s per screen — about a tenth of a cent for the
   whole 21-screen sweep.

Then the sharp move from the integration contract: **rule-vs-Jev disagreement queue.** Layer 1
labels items from numbers, Jev labels the same items from the inventory, and a human reads only the
disagreements. It is the only mechanism here that finds a defect neither layer would flag alone.

## 5. Honest limits — do not read this as a shipped pairing

- **One frame, four scored questions, ground truth partly my own vision read.** No labelled slice,
  no baseline to beat. Per the integration contract a candidate graduates only with a labelled slice
  of real data *and* a baseline; this has neither. Candidate, not pairing.
- **The inventory in state B was written by a vision model** — the "prose description of an image"
  step the Jev skill calls *different and still unmeasured*. What was measured is inventory →
  judgment, not pixels → judgment. Jev still cannot see.
- **The inventory was wrong about the mechanism, and Jev answered confidently anyway.** State B said
  the second-row cards are "cut off by the bottom edge of the frame"; the measurement says the
  second row is *truncated* (a shorter panel, content dropped) with a black band below it. Jev
  returned 0.99 on "something is clipped" — right that something is wrong there, wrong about what.
  This is exactly the recorded failure in the integration contract: Jev is not wrong about its
  input; its input is wrong about the world.
- **The vision passes disagreed on the mark count** — 4, 4, then 3 on a magnified strip. Fine
  detail at this scale is not reliably countable by a vision model. The count must come from layer 1.
- **The defect-class question was close to a check.** The state carried both hex values, so
  `colour_mismatch` was nearly arithmetic — that question should not have been asked. The genuinely
  judgmental answers were `bars_read` (0.05) and `severity` (3.49).
- **Severity confidence 0.58**, levels 3 and 4 split 0.43/0.55: the level is soft, the verdict class
  is not.
- **Jev is advisory, never a gate.** Luca's eye stays the final word on look and feel.
