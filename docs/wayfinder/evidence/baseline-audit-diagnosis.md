# Baseline audit diagnosis — two reds out of 27

- Repo: `/root/projects/steam-circuit-padel-pro`
- Commit: `2979588` (no git state changed by this diagnosis: no commit, no checkout, no branch move)
- Toolchain: Node v22.22.1 / npm 9.2.0
- Date: 2026-09-16 (CEST)
- Raw log after install: `docs/wayfinder/evidence/baseline-audit-after-install.log`

## Commands run and exit codes

| # | Command | Exit code | Effect |
|---|---------|-----------|--------|
| 1 | `npm run audit` (pre-install, `node_modules/` absent) | **1** | 25/27 pass; reproduces both reds |
| 2 | `npm install` | **0** | added 11 packages; installed declared devDependencies only |
| 3 | `npm run audit` (post-install) | **0** | **27/27 pass** |
| 4 | `node scripts/outfit-assets-audit.mjs` | 0 | prints `{"athletes":6,"outfits":26,"dedicatedSheets":120}` |
| 5 | `node scripts/unlockable-animation-audit.mjs` | 0 | prints `{"unlockables":2,"standardizedStates":12}` |

Install was authorised toolchain acquisition only. `package.json` was not touched, and
`git diff --stat package-lock.json` is **empty** — the lockfile already declared `sharp@0.34.5`
and `@tauri-apps/cli@2.11.4`, so no dependency was added, removed or changed.
`node_modules/` (70 MB) is git-ignored. `git status --short` shows only pre-existing untracked
`docs/`, `godot/`, `meshy/` — no generated-asset or source churn.

## Pass count

- Before install: **25/27** (`25/27 audit passano`, exit 1)
- After install: **27/27** (`27/27 audit passano`, exit 0)

The recorded baseline in `docs/wayfinder/evidence/baseline-audit.log` matches the pre-install
run line-for-line: same 25 green, same two reds, same two error lines.

## Red audit 1 — `scripts/outfit-assets-audit.mjs`

**Root cause: missing devDependency `sharp` (`node_modules/` absent) — not a failing assertion.**

The audit loads `sharp` through CommonJS (`scripts/outfit-assets-audit.mjs:7`):

```js
const require = createRequire(import.meta.url);
const sharp = require("sharp");
```

With `node_modules/` absent, that `require` throws at line 7 before any audit logic runs.
Reproduced faithfully in a throwaway copy (`/tmp/scp-probe`, repo copied without
`node_modules/`), raw stderr:

```
node:internal/modules/cjs/loader:1383
  const err = new Error(message);
              ^

Error: Cannot find module 'sharp'
Require stack:
- /tmp/scp-probe/scripts/outfit-assets-audit.mjs
    at Module._resolveFilename (node:internal/modules/cjs/loader:1383:15)
    ...
    at file:///tmp/scp-probe/scripts/outfit-assets-audit.mjs:7:15
  code: 'MODULE_NOT_FOUND',
  requireStack: [ '/tmp/scp-probe/scripts/outfit-assets-audit.mjs' ]
}
```

**Why it was misreported as an "assertion error":** the runner
`scripts/run-audits.mjs:64` prints the *first stderr line containing the substring `Error`*:

```js
const riga = esito.errore.split("\n").find((l) => l.includes("Error")) ?? esito.errore.split("\n")[0];
```

For a CJS resolution failure the first such line is the Node internal code-frame source line
`const err = new Error(message);` — an artefact of `node:internal/modules/cjs/loader`. That is
exactly the line in both the recorded baseline and the pre-install run. The real message
(`Cannot find module 'sharp'`) sits two lines further down. So the baseline's "assertion error,
cause undiagnosed" was a **reporting artefact**, not a distinct defect.

**Verdict: environment/toolchain issue** (missing installed devDependency), not a product defect.

**Not vacuous — verified.** In the throwaway copy the audit is genuinely load-bearing: replacing
one generated sprite (`assets/outfits/maestro/signature/idle.webp`) with a 64×64 opaque image
makes it fail for real:

```
AssertionError [ERR_ASSERTION]: maestro/signature/sprite: lo sprite deve essere a 0,6x
64 !== 716
    at file:///tmp/scp-probe/scripts/outfit-assets-audit.mjs:59:14
```

With `sharp` installed it validates 26 outfits / 120 dedicated sprite sheets against the
committed generated assets, which are all present and git-tracked (160 outfit files under
`assets/outfits/**`). **No regeneration was required** — `assets:outfits` was therefore not
needed to turn this audit green, and the mission repo carries no generated-file churn.

(Side finding, not one of the reds: `npm run assets:outfits` cannot run in this environment —
`scripts/generate-outfit-assets.mjs:18` reads source masters from the repo-relative, git-ignored
path `tmp/imagegen/**`, which does not exist. Output: `Error: Input file is missing:
/tmp/scp-probe/tmp/imagegen/outfits/maestro.png`. Environment/toolchain gap; irrelevant to the
pass count because the committed generated assets are already in sync.)

## Red audit 2 — `scripts/unlockable-animation-audit.mjs`

**Root cause: missing devDependency `sharp`.** Static ESM import at line 2:

```js
import sharp from "sharp";
```

Raw error (pre-install run, quoted from the recorded baseline and reproduced identically):

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'sharp' imported from /root/projects/steam-circuit-padel-pro/scripts/unlockable-animation-audit.mjs
  code: 'ERR_MODULE_NOT_FOUND'
```

**Installing `sharp` fixes it: yes.** Post-install the audit exits 0 and prints
`{"unlockables":2,"standardizedStates":12}`. No new error of any kind.

**Verdict: environment/toolchain issue**, not a product defect.

## Shared surface

Five scripts depend on `sharp` (`build-icons.mjs`, `generate-outfit-assets.mjs`,
`outfit-assets-audit.mjs`, `standardize-unlockable-sprites.mjs`,
`unlockable-animation-audit.mjs`) — two of them are audits and both were red for the same single
reason. `@tauri-apps/cli` is used only by the desktop build path, not by any audit.

**Net conclusion: two reds, one root cause, zero product defects.** No audit, test or assertion
was edited, skipped or weakened.

## What a fix would touch (not applied)

1. **The only fix required was already the declared dependency install** —
   `npm install` in the repo root. No source change is needed for 27/27.
2. **Optional, correctness of future diagnosability** (not needed for green):
   `scripts/run-audits.mjs:64` extracts a failure line by substring `"Error"`, which mislabels
   module-resolution failures as assertion failures. Extracting the line starting with
   `Error:`/`Error [` instead of the first line *containing* `Error`, or preferring the first line
   matching `/(^|\s)(Assertion|Type)?Error\b/`, would prevent this misdiagnosis. This is a
   reporting-only change to the runner — the audits themselves stay untouched.
3. **Optional, environmental**: a first-run bootstrap check that `node_modules/` exists
   (or that `sharp` resolves) before running audits, so a cold checkout reports
   "dependencies not installed" instead of two reds.
4. **Latent, environmental, not part of the reds**: `npm run assets:outfits` cannot run without
   the git-ignored source masters at `tmp/imagegen/**`. Restoring those masters (or pointing
   `scripts/generate-outfit-assets.mjs:18` at a committed source directory) would be needed before
   any intentional asset regeneration.

No fix from items 2–4 has been applied, and none is required to reach 27/27.
