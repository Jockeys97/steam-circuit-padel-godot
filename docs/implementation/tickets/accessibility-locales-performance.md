# Accessibility, locales, controller navigation and performance target (slice S13)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md) for the screens these settings act on, and [Demo and export presets](demo-export-presets.md) for the builds the navigation is checked in. Acceptance is blocked by [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md) (open, HITL, owner Luca), which alone can name the minimum and target frame rate and the machine the build is judged on, and which decides the input scope — gamepad, keyboard, or both — and the fate of touch and the on-screen keyboard. The locale work, the controller navigation and the reduced-motion path are unblocked and can be built now; the performance claim cannot be made on this host at all and is not made.

This ticket implements row S13 of `docs/implementation/PLAN.md` ("Accessibility, locales, controller navigation, performance target"). It does not change that plan, its slice numbering or its open-decision table, and it closes the slice list.

## Objective

Finish the port's non-gameplay surfaces: two locales that stay in sync with the reference, a controller-navigation path that reaches every screen and every action, an accessibility pass that keeps what the web build already does — reduced motion, labelled controls, keyboard reachability — and a performance measurement performed on hardware that can support the claim. The last part is the one that cannot be delivered from this host and is stated as such rather than approximated: this machine renders through software GL with no GPU, which makes it valid for correctness and invalid for any frame-rate statement.

Four threads, and this ticket keeps them apart because they fail differently:

1. **Locales** — the reference holds Italian and English in one dictionary of more than 200 keys per language with identical key sets. The port carries that contract through the locale seam and proves it the way `scripts/i18n-audit.mjs` does.
2. **Controller navigation** — the reference's audit reads markup and script to assert that every menu action is reachable from a named input, that back is a declared target rather than the first action on the screen, and that the pad confirms on the A/Cross button. The port asserts the same over Godot input actions instead of DOM markup.
3. **Accessibility** — reduced motion and labelled controls. The web build has 58 `data-i18n-aria` hooks and 81 `aria-*` attributes in its markup, and it toggles `body.reduce-motion`. The port keeps the *semantics*: a reduced-motion setting that the effects layer reads, and named controls, screen-reader text where the platform exposes it, and a keyboard path to everything a pad reaches.
4. **Performance** — measured, or explicitly not claimed. The target is Luca's to name; this ticket produces the measurement procedure and the frame-time instrumentation, and refuses to publish a number from a software renderer.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/i18n.js:1` | `DICT`, the single dictionary with the `it` and `en` blocks. The file is 1415 lines; the two blocks are the two locales |
| `js/i18n.js:1400` | `setLang(lang)` — the setter, including its fallback to `it` for an unknown language |
| `js/i18n.js:1404` | `getLang()` |
| `js/i18n.js:1408` | `t(key, params = {})` — the lookup with parameter substitution |
| `scripts/i18n-audit.mjs:21` | The audit reads `js/i18n.js` as source, so the dictionary is parsed rather than imported: the port's equivalent must read its own locale resources the same way and fail on drift |
| `scripts/i18n-audit.mjs:29` | More than 200 keys are expected — a locale that loses keys fails |
| `scripts/i18n-audit.mjs:33-34` | No key exists in Italian only, and none in English only |
| `scripts/i18n-audit.mjs:47` | Two language blocks are compared as **equal key sets**, sorted |
| `scripts/i18n-audit.mjs:58-66` | Every key used somewhere in the sources is defined, and the missing list must be empty |
| `scripts/i18n-audit.mjs:90` | Composed keys must also be present — the audit checks keys built at runtime, not only literal ones |
| `scripts/gamepad-nav-audit.mjs:17-19` | The audit reads `index.html`, `js/main.js` and `js/i18n.js` as sources |
| `scripts/gamepad-nav-audit.mjs:26` | The focus-target selector must be findable in `main.js` |
| `scripts/gamepad-nav-audit.mjs:51` | At least eight screens are expected; a two-screen build does not satisfy this yet and the gap is recorded, not asserted |
| `scripts/gamepad-nav-audit.mjs:73-80` | The menu-back rule: back must find the **declared** return target, not the first `[data-action^="to-"]` on the screen |
| `scripts/gamepad-nav-audit.mjs:87-92` | `pollGamepadMenu` must contain the A/Cross confirm binding, asserted as a regex over the source |
| `scripts/gamepad-nav-audit.mjs:95-112` | Pad help strings exist, and text fields are found — the audit expects on-screen-keyboard-relevant fields to be present in the markup today |
| `scripts/reachability-audit.mjs:17` | The three reachability rules: every action has a handler, every handler has an action, and every `<section id="screen-X">` is opened by some `showScreen` |
| `scripts/reachability-audit.mjs:68-97` | The screen inventory is read from the markup and cross-checked against the `screens` registry in `js/ui.js` |
| `js/fx.js:2-10` | The reduced-motion flag: `let reducedMotion = false`, `setReduceMotion(enabled)`, `isReduceMotion()`. It lives in the effects module |
| `js/fx.js:26, 63` | What the flag does: scales particle counts to at most 35 % (with a floor of 2) and caps shake |
| `js/main.js:2301` | The `body.reduce-motion` class toggle on the DOM |
| `styles.css:2715-2722` | The `body.reduce-motion` rules, including the `.menu-focus` rule at `:2722` — reduced motion is presentation-side, in the effects layer, and audio never reads it |
| `index.html` | 58 `data-i18n-aria` hooks and 81 `aria-*` attributes across the thirteen screens, with `aria-label` on each `<section>` (e.g. `index.html:31`) |
| `js/main.js:439-444` | The on-screen keyboard: `oskEl`, `oskGrid`, `oskTarget`, `oskShift`. Named here because it is part of the input surface this slice's decision covers, and it is **not** built by this slice |
| `GAMEPLAY_RULES.md:152-180` | The full controller map: radial deadzone with a progressive curve, per-button charge bindings, absolute aiming during charge, the timing meter, execution profiles, the smash two-tap, split-step, analog sprint, the technical modifier, D-pad tactics, the right-stick flick and three player-switch modes |
| `docs/wayfinder/tickets/product-scope-and-platforms.md` | The four questions this slice's acceptance waits on: OS set, performance target and the machine it is judged on, input scope, and save scope. It also records the rule that touch and the OSK are postponed to a stated later slice rather than dropped |
| `godot/project.godot` | The project settings any performance measurement must name: the 120 Hz physics tick and the `gl_compatibility` renderer |
| `godot/prototypes/render_probe/` and the `render.sh` scripts under `godot/prototypes/` | The proof that rendered capture works here, and the proof of the limitation: software GL, `llvmpipe`, no GPU |

The seams this slice sits next to, each with one owner: the locale contract lives in `godot/src/locale/**`, one owner, and this slice consumes it; the screens and the router belong to [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md); the input map belongs to [Quick-match vertical slice in 3D](quick-match-slice.md); the audio layer never reads the motion setting (`js/audio.js` has no match for it), and this slice keeps that.

## File ownership / allowlist

New files this ticket creates:

- `godot/tests/i18n_audit.gd` and `godot/tests/i18n_audit.tscn` — the ported locale audit: both locales present, key sets equal, more than 200 keys each, every used key defined, composed keys included, and a fallback asserted for an unknown language
- `godot/tests/controller_nav_audit.gd` and `.tscn` — the ported navigation audit: every registered screen reachable, every menu action bound to a named input action, every screen's back target declared, and the confirm action bound
- `godot/tests/a11y_audit.gd` and `.tscn` — reduced motion has an entry point and reaches the effects layer; every interactive control has a name; every pad-reachable action has a keyboard binding; the motion setting never reaches the audio module
- `godot/src/accessibility/AccessibilitySettings.gd` — the motion setting and its application, the keyboard-navigation policy, and the control-labelling helper the screens use
- `godot/src/accessibility/FrameTimeProbe.gd` — the measurement instrumentation: a frame-time sampler with p50/p95/max and a stated sample window, that writes a report and makes no claim by itself
- `godot/tools/measure_performance.sh` — the measurement procedure, runnable on agreed hardware: the binary, the scene, the fixed seed, the sample window, the output file
- `godot/tests/input_coverage_audit.gd` and `.tscn` — the ported form of the pad-help-strings check: every action a player can perform is bound to both a pad button and a keyboard key, and the bindings are enumerable
- `docs/implementation/evidence/s13-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/`, `godot/src/locale/**` (the locale seam's, consumed and never edited), `godot/src/audio/**`, `godot/src/ui/ScreenRouter.gd`, `godot/src/ui/theme/`, `godot/src/ui/UiStrings.gd`, `godot/src/input/**` (the input map belongs to [Quick-match vertical slice in 3D](quick-match-slice.md); this slice asserts over it and does not rewrite it), `godot/src/view/camera/**`, `godot/src/save/**`, `godot/prototypes/`, and `godot/project.godot` beyond nothing — the tick and the renderer stay as the harness left them, and a performance target is not a project setting to be guessed.

The location and the fate of touch and the on-screen keyboard are named, not decided: this slice records that they are postponed to a stated later slice per `PLAN.md`'s recommended default and does not build them, drop them or pretend they are gone.

## Inputs and outputs

Inputs:

- The two locales from the locale seam, loaded as Godot translations. The port never keeps a second dictionary.
- The reference's key sets, so a port missing a key fails the same way the reference's audit fails.
- The input map from the quick-match slice, as a set of named actions with pad and keyboard bindings.
- The reduced-motion setting, applied at the effects layer, never at the audio layer.
- The product-scope answers: target frame rate, the judging machine, the OS set and the input scope.

Outputs:

- A locale audit that fails if the two languages drift apart by a single key, on either side.
- A controller-navigation audit that fails if a screen is unreachable, an action is unbound, a back target is implied rather than declared, or the confirm binding is missing.
- An accessibility audit that fails if reduced motion does not reach the effects layer, if an interactive control has no name, if a pad action has no keyboard equivalent, or if the motion setting is read by audio.
- A frame-time probe and a measurement script that produce p50/p95/max on named hardware with a fixed seed and a stated window — the procedure, plus whatever number agreed hardware produces.
- An enumerated input coverage table: every action, its pad binding, its keyboard binding.

Explicitly not output: a frame-rate number measured on this host; a performance target invented in the absence of the decision; touch controls or an on-screen keyboard; new locales; new accessibility features the reference does not have; and any claim that the port is accessible in the sense a certification would mean.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/i18n-audit.mjs` — the primary locale gate, ported promise for promise: more than 200 keys (`:29`), no Italian-only and no English-only key (`:33-34`), equal key sets (`:47`), every used key defined (`:58-66`), and composed keys included (`:90`).
- `scripts/gamepad-nav-audit.mjs` — the navigation gate, ported where it applies and explicitly deferred where it does not: the declared-back rule (`:73-80`), the confirm binding (`:87-92`), the focus targets (`:26`) and the pad help strings (`:95`). The eight-screen floor at `:51` is recorded as not yet met by a smaller build rather than asserted early.
- `scripts/reachability-audit.mjs` — the three reachability rules (`:17`) and the registry cross-check (`:68-97`), asserted by the UI lane's router audit; this slice consumes its result and adds the input-binding half.
- `scripts/feedback-audit.mjs` — not this slice's, named only because the feedback screen's text fields are the ones the OSK decision concerns.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors.

Godot-side equivalents:

- `godot/tests/i18n_audit.gd` — reads the locale resources the way the reference audit reads its source, so a deleted or renamed key fails loudly; asserts the two locales' key sets are equal as sorted sets; asserts the unknown-language fallback; asserts composed keys resolve.
- `godot/tests/controller_nav_audit.gd` — walks the router, asserts one active screen, asserts every screen's back target is declared data rather than positional, asserts every menu action maps to a named input action, asserts the confirm action is bound.
- `godot/tests/input_coverage_audit.gd` — enumerates every action and asserts both a pad and a keyboard binding for each, per `GAMEPLAY_RULES.md:152-180`; a pad-only action is a failure because the keyboard is the fallback path.
- `godot/tests/a11y_audit.gd` — the motion setting reaches the effects layer and never the audio module; every interactive control has a name; the reduced-motion state is observable in a headless run.

Performance is measured, not tested. `FrameTimeProbe.gd` and `tools/measure_performance.sh` produce the numbers; no automated gate asserts a frame rate, because there is no agreed target yet and inventing one would be worse than having none.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. `timeout` is the CI bound, not `--quit-after`.

The four headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in i18n_audit controller_nav_audit input_coverage_audit a11y_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s13-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s13-${a//_/-}.log; \
done
```

The reference audits this slice ports, run as the comparison:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  node scripts/i18n-audit.mjs > docs/implementation/evidence/s13-web-i18n.log 2>&1; echo "i18n exit=$?"; \
  node scripts/gamepad-nav-audit.mjs > docs/implementation/evidence/s13-web-gamepad.log 2>&1; echo "nav exit=$?"; \
  node scripts/reachability-audit.mjs > docs/implementation/evidence/s13-web-reachability.log 2>&1; echo "reach exit=$?"
```

The performance measurement — **run this only on the machine the product-scope decision names**, never here, and never with a number published from this host:

```sh
cd /root/projects/steam-circuit-padel-pro && ./godot/tools/measure_performance.sh \
  --binary /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --scene res://scenes/QuickMatch.tscn --seed 12345 --seconds 120 \
  --out docs/implementation/evidence/s13-frametime.json
```

Why it cannot be run here, recorded rather than asserted: this host renders through software GL (`llvmpipe`) with no GPU, so a frame-time number from it says nothing about any player's machine. The render probes under `godot/prototypes/` are the proof of the route and of the limitation.

Locale and input inventories, printed for the evidence file:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  wc -l js/i18n.js; grep -c 'data-i18n-aria' index.html; grep -c 'aria-' index.html; \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://tests/input_coverage_audit.gd -- --list-actions
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s13-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s13-i18n-audit.log`, `s13-controller-nav-audit.log`, `s13-input-coverage-audit.log`, `s13-a11y-audit.log` — each with an exit code and a `PASS n/n` line.
- `docs/implementation/evidence/s13-web-i18n.log`, `s13-web-gamepad.log`, `s13-web-reachability.log` — the reference audits this slice ports, for the comparison.
- `docs/implementation/evidence/s13-input-inventory.md` — every action with its pad binding and its keyboard binding, generated from the input map rather than written by hand.
- `docs/implementation/evidence/s13-locale-inventory.md` — the key count per language, the equality verdict, and the fallback behaviour.
- `docs/implementation/evidence/s13-a11y-notes.md` — what the web build already does (reduced motion in the effects layer, 58 `data-i18n-aria` hooks and 81 `aria-*` attributes, keyboard reachability), what the port keeps, what the platform cannot express (Godot has no DOM; the equivalent is named controls and a keyboard path, not a claim of screen-reader parity), and the explicit statement that audio never reads the motion setting.
- `docs/implementation/evidence/s13-frametime.json` — **absent on this host, and its absence is recorded**: the file appears only when the measurement runs on the machine the decision names.
- `docs/implementation/evidence/s13-perf-procedure.md` — the procedure, the sample window, the seed, the scene, the metrics (p50, p95, max), and the plain statement that no number from this host is a performance claim.
- `docs/implementation/evidence/s13-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a locale claim without the key-set comparison; a navigation claim without the walk over every screen; an accessibility claim that describes intent rather than what a headless run observes; a performance number measured through software GL; and any statement that touch or the on-screen keyboard were dropped.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- A key exists in one language only, the key sets differ, or a used key is undefined in either locale.
- A screen is unreachable, a menu action is unbound, a back target is inferred from position, or the confirm binding is absent.
- A pad-reachable action has no keyboard binding, or an interactive control has no name.
- The motion setting reaches the audio module, or the effects layer ignores it.
- A frame-rate or target-hardware claim is published from this host, or a performance target is invented before the product-scope decision names one.
- Touch or the on-screen keyboard is dropped, silently or otherwise.
- A file outside the allowlist changes, `js/` or `scripts/` changes at all, or the locale seam is edited instead of consumed.
- A frame-rate claim appears anywhere in the evidence.

What stops the slice: a red audit after the retry rule below; the input scope not being decided, which blocks the inventory's completeness claim but not the locale or accessibility work; or the judging hardware not being named, which leaves the performance half deliberately unmeasured.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the locale audit reads the shipped translation resources and not a cached copy; confirm the navigation audit walks the router rather than a hardcoded screen list; confirm the input coverage audit reads the input map rather than a hand-written table; confirm the motion setting is asserted by its effect on the effects layer and not merely by the existence of a setting.

## Human gates that block this slice (open, owner Luca)

- **Product scope and platforms** — the minimum and target frame rate and the machine the build is judged on; the input scope (gamepad, keyboard, or both); the fate of touch and the on-screen keyboard, which the recommended default postpones to a stated later slice rather than dropping; and the OS set. This slice produces the measurement procedure and the inventories and refuses to answer any of the four. No performance number exists until the decision names the hardware.
- **UI port approach** — the accessibility semantics live on the screens that decision covers; if the Control tree is rejected, the labelling and focus work is re-planned with it.
