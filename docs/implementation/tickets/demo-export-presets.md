# Demo and export presets (slice S12)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md): the demo must not leak achievement or cloud progress for content it does not contain, so the demo filter has to be layered onto the save seam rather than invented next to it. Acceptance is blocked by [Demo gate rule](../../wayfinder/tickets/demo-gate-preset.md) (open, HITL, owner Luca), which decides the demo's content set, what stays locked, whether the mechanism is export presets or something else, and how the filter is tested, and by [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md) for the OS set, which decides which presets exist at all. The filter's test shape can be written now; the presets cannot be finalised before the OS set lands.

This ticket implements row S12 of `docs/implementation/PLAN.md` ("Demo and export presets"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S13.

## Objective

Reproduce the demo gate in the Godot build and produce the export presets the release needs. The reference already has the shape: a build flag, a content table, and two filter functions that hide and lock content the demo does not expose — a two-athlete, one-arena, quick-match-only demo cut from the same codebase. The port reproduces that shape behind an export preset and proves it with the same promises `scripts/demo-audit.mjs` holds, including the ones that are easy to lose: the two demo athletes must be the extremes of the roster rather than any two, the demo's difficulty is fixed, and locked content stays locked while the challenge set stays reachable.

The slice also produces the export presets themselves — at minimum one per target the product-scope decision names, plus the demo preset — and proves each by running the exported build headless, not by asserting that a preset file exists.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/build.js:35` | `export const IS_DEMO = resolveBuild();` — the single build flag. The Godot equivalent is a project feature tag read by one function, not a scattered constant |
| `js/build.js:43-56` | `DEMO_CONTENT`: `athletes: ["maestro", "steamer"]`, `arenas: ["clockwork"]`, `modes: ["quick"]`, `difficulty: "medium"`, `outfitChallenges: true`, `wishlistUrl`. Its comment states the principle — cut the progression, not the game — and the reason the two athletes are the extremes: control against power, so a new player sees that athletes play differently |
| `js/build.js:58` | `demoFilter(items, allowed)` — `if (!IS_DEMO) return items;` then filters by id. A no-op in a full build |
| `js/build.js:73` | `demoLocked(item, allowed)` — `IS_DEMO && !allowed.includes(item?.id)`. Locking is a separate answer from filtering, and the port must keep both |
| `js/ui.js:737` | `applyDemoLimits()` — the presentation half: a body class, locked mode cards, a "locked in the demo" tag. The Godot equivalent is a screen-side lock state driven by the same table |
| `scripts/demo-audit.mjs:10-15` | The demo athletes and arenas resolve from the real tables: two athletes, one arena |
| `scripts/demo-audit.mjs:21` | Demo items carry no `unlock` — nothing offered in the demo is itself locked |
| `scripts/demo-audit.mjs:30` | The two demo athletes differ by at least 0.25 on both control and power — the extremes rule, expressed as a number |
| `scripts/demo-audit.mjs:40` | Every balance key the demo's difficulty needs exists |
| `scripts/demo-audit.mjs:44-46` | `modes` is exactly `["quick"]` and the difficulty is exactly `"medium"`, with the reason written down: tournament and career are the progression being sold, easy reads as trivial and hard repels |
| `scripts/demo-audit.mjs:49-50` | `demoFilter` leaves the list unchanged when the flag is off, and reduces it to the allowed set when it is on |
| `scripts/demo-audit.mjs:62-65` | At least one athlete and one arena are excluded by the filter — a filter that excludes nothing is not a demo gate |
| `scripts/demo-audit.mjs:71` | `demoLocked` returns `IS_DEMO` for everything outside the allowed set, for every athlete — the locked answer is exactly the demo flag |
| `scripts/demo-audit.mjs:74` | Every demo athlete passes the lock test, i.e. is not locked |
| `scripts/build-dist.mjs:1-18` | How the web build chooses what ships: `dist/` is not a compile step, it is a *selection*, and the comment records the rule (the 131 MB of archive masters are for regenerating assets, not for playing: 25 MB on disk, 9.6 MB at first load). The Godot export presets are the same decision made with a different mechanism |
| `scripts/build-icons.mjs` | Icon generation from the existing assets. Reused for the Godot icons rather than re-authored |
| `js/data.js:324-483` | `ATHLETES`, the roster the demo filter slices — `maestro` and `steamer` are the extremes |
| `js/data.js:560-661` | `ARENAS`, nine entries, of which the demo exposes one |
| `docs/wayfinder/tickets/demo-gate-preset.md` | The decision this slice waits on: content set, lock rules, mechanism, test approach |
| `godot/src/sim/frozen.gd` | The frozen tables the demo filter slices, so the demo uses the same numbers as the full build |

The seams this slice sits next to, each with one owner: the save seam and the achievement gate belong to [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md); the screens and the router belong to [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md) — this slice supplies a lock state they render and does not edit them; input belongs to [Quick-match vertical slice in 3D](quick-match-slice.md).

## File ownership / allowlist

New files this ticket creates:

- `godot/src/build/BuildFlag.gd` — one function, `is_demo()`, backed by a project feature tag. Nothing else in the project may read the tag directly
- `godot/src/build/DemoContent.gd` — the demo content table, generated from `js/build.js:43-56`, so the port's list cannot drift from the reference's
- `godot/src/build/ContentFilter.gd` — `filter(items, allowed)` and `is_locked(item, allowed)` as the two separate answers the reference gives, plus the demo limits applied to the roster, the arenas, the modes and the difficulty
- `godot/export_presets.cfg` — the presets, one per target plus the demo. This is a generated file; the generator is the ticket's own script so the file is reproducible
- `godot/tools/gen_export_presets.gd` — the preset generator, driven by the product-scope target list
- `godot/tools/demo_export_check.gd` — asserts that a demo export excludes the excluded content and that a full export includes it, by reading the exported artifact rather than the preset
- `godot/tests/demo_audit.gd` and `godot/tests/demo_audit.tscn` — the ported demo audit, promise for promise, including the extremes rule as a number
- `godot/tests/content_filter_audit.gd` and `.tscn` — the filter's two answers (filter and lock) against the full and demo tables
- `godot/tests/export_preset_audit.gd` and `.tscn` — every preset the target list names exists, carries a distinct name and output path, and the demo preset carries the demo feature tag
- `docs/implementation/evidence/s12-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/`, `godot/src/save/**`, `godot/src/ui/**`, `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/career/**`, `godot/src/drill/**`, `godot/src/view/**`, `godot/prototypes/`, and `godot/project.godot` beyond the feature tag the build flag needs (the 120 Hz tick and the `gl_compatibility` renderer stay as the harness left them).

No commit, tag, push or upload. Producing an export artifact on disk is in scope; publishing one is not.

## Inputs and outputs

Inputs:

- The demo content table from the reference, generated rather than re-typed.
- The product-scope target list: without it, only the demo preset can be produced, and the others are recorded as blocked.
- The save and achievement gate from [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md), so a demo build cannot unlock progression it does not contain.
- The existing icon assets, reused through the reference's own icon step.

Outputs:

- One `is_demo()` function, one content table, and two filter answers — filter and lock — with the reference's exact semantics.
- The demo limits applied to roster, arenas, modes and difficulty, and a demo build that runs quick match only, with two athletes and one arena.
- Export presets: the demo preset plus one per target the product-scope decision names.
- An exported demo artifact on disk and a headless run of it, so the preset is proven by a built thing and not by a config file.
- A ported demo audit and a filter audit, both headless.

Explicitly not output: new demo content, a demo-specific game mode, any change to the content table's contents (those are the decision's), any store-publishing step, and any claim that the demo is ready for a storefront.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/demo-audit.mjs` — the primary gate, ported promise for promise: two athletes and one arena resolve from the real tables (`:10-15`); demo items carry no unlock (`:21`); the two demo athletes differ by at least 0.25 on control **and** power (`:30`); the balance keys the fixed difficulty needs exist (`:40`); modes is exactly `["quick"]` and difficulty exactly `"medium"` (`:44-46`); the filter is a no-op when the flag is off and reduces the set when it is on (`:49-50`); at least one athlete and one arena are excluded (`:62-65`); the lock answer equals the demo flag for everything outside the allowed set (`:71`); every demo athlete is unlocked (`:74`).
- `scripts/build-dist.mjs` — the selection rule the export presets reproduce: what ships is what the game asks for at runtime, not the archive. The Godot equivalent is the preset's include/exclude list, asserted by `demo_export_check.gd`.
- `scripts/assets-audit.mjs` — the Godot equivalent is that every resource a demo build references resolves inside the demo export, which the exported-artifact check makes.
- `scripts/outfit-challenges-audit.mjs` — the demo's `outfitChallenges: true` means the challenge set is reachable in the demo (`js/build.js:51-55` explains why: challenges are bound to a feat on the court, not to progression, and the reference declares it rather than leaving it an accident). The port asserts the challenges are reachable in the demo build and that no achievement leaks for excluded content.
- `scripts/reachability-audit.mjs` — a demo build must still reach every screen it exposes. The check is the UI lane's router audit, run against the demo flag as well as the full build.

Godot-side equivalents:

- `godot/tests/demo_audit.gd` — the ported promises above, with the extremes rule computed from the frozen `ATHLETES` table rather than from a literal, and both filter answers asserted.
- `godot/tests/content_filter_audit.gd` — the filter table against the full and demo tables, asserting the two answers are independent: something can be filtered from the list and still be unlocked, and vice versa, exactly as the reference's two functions allow.
- `godot/tests/export_preset_audit.gd` — preset inventory against the target list, distinct names and output paths, and the demo tag on exactly one preset.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. An export is heavier than a test run and is done once per preset, never in a loop.

The three headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in demo_audit content_filter_audit export_preset_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s12-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s12-${a//_/-}.log; \
done
```

Generating the presets from the target list:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://tools/gen_export_presets.gd -- --targets=linux,windows \
    > docs/implementation/evidence/s12-presets.log 2>&1; echo "exit=$?"
```

One export, the demo, to an evidence directory — the artifact the gate is proven on:

```sh
cd /root/projects/steam-circuit-padel-pro && mkdir -p docs/implementation/evidence/s12-export && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 900 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --export-release "demo-linux" docs/implementation/evidence/s12-export/demo-linux.x86_64 \
    > docs/implementation/evidence/s12-export.log 2>&1; echo "exit=$?"
```

The exported artifact, run headless and checked against the content rule:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    docs/implementation/evidence/s12-export/demo-linux.x86_64 --headless \
    -- --verify-demo-content > docs/implementation/evidence/s12-export-run.log 2>&1; echo "exit=$?"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && node scripts/demo-audit.mjs; echo "demo exit=$?"; \
  npm run audit > docs/implementation/evidence/s12-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s12-demo-audit.log`, `s12-content-filter-audit.log`, `s12-export-preset-audit.log` — each with an exit code and a `PASS n/n` line.
- `docs/implementation/evidence/s12-presets.log` — the preset generation, with the target list it was given.
- `docs/implementation/evidence/s12-export.log` — the demo export, its exit code and the artifact path and size.
- `docs/implementation/evidence/s12-export-run.log` — the exported artifact running headless and reporting its own content set: the athletes present, the arenas present, the modes present, the locked list and the difficulty. **This is the proof the gate works**, because it is the built thing asserting on itself.
- `docs/implementation/evidence/s12-presets.md` — the preset inventory: name, target, output path, feature tags, and for the demo preset the content table it carries; plus the explicit note of which targets are missing because the product-scope decision has not named them.
- `docs/implementation/evidence/s12-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a preset file asserted to exist without an export produced from it; an exported artifact asserted to be a demo without running it; a content table re-typed instead of generated; and any statement that the demo is store-ready.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- The export fails, or produces an artifact that does not run headless, or whose self-reported content set disagrees with the demo table.
- The demo exposes a mode other than quick match, a difficulty other than the fixed one, more than two athletes or more than one arena.
- The two demo athletes are not the roster's control and power extremes, or their separation falls below the number the reference audit asserts.
- A filtered item is still unlockable, or a locked item is offered — the two answers are conflated.
- The demo can unlock an achievement or write progression belonging to excluded content.
- The content table is re-typed in the port rather than generated from the reference.
- The slice publishes, uploads, commits or tags anything.
- A file outside the allowlist changes, `js/` or `scripts/` changes at all, or `godot/project.godot` is edited beyond the feature tag.
- A frame-rate or storefront-readiness claim appears in the evidence.

What stops the slice: a red audit after the retry rule below; the demo-gate decision naming a mechanism that is not export presets, in which case the filter work is kept and the preset work is re-scoped; or the product-scope decision not naming the OS targets, in which case only the demo preset is produced and the rest is recorded as blocked.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the demo table is generated and diffed against the reference rather than compared by eye; confirm the exported-artifact check reads the artifact's own report and not the preset that produced it; confirm the export ran with the demo feature tag rather than a copied preset; confirm the filter audit tests both answers independently, since a single boolean would pass the reference's `:71` check while losing the distinction the reference makes.

## Human gates that block this slice (open, owner Luca)

- **Demo gate rule** — which content the demo exposes, what stays locked, whether the mechanism is export presets or something else, and how the filter is tested. This slice reproduces the reference's rule as the provisional default (`PLAN.md`'s recommendation is to reuse the demo content rule behind an export preset) and builds no preset on the assumption that the rule is settled.
- **Product scope and platforms** — the OS set, which decides which export presets exist. Until it lands, the preset inventory is partial and says so.
