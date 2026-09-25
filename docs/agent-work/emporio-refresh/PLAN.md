# Emporio OST refresh

## Objective
Turn the existing OST-only shop into an illustrated, controller-friendly storefront inspired by the browsing hierarchy of Sparking! ZERO while retaining Steam Circuit's navy/cyan/gold identity. Reuse the existing Jukebox cover files keyed by soundtrack track ID; do not duplicate media.

## Contract and boundaries
- The economy service remains the sole source of catalog rows, prices, affordability, ownership, and purchase. Preserve confirmation before debit and existing Italian/English behavior.
- The current Emporio is OST-only. Skin/outfit commerce and save/schema changes are out of scope.
- Keep the `EmporioScreen` public methods and host overlay integration used by `emporio_ost_test.gd`. Do not edit the concurrently changed `main_menu.gd`, Jukebox, soundtrack, or gameplay files.
- Missing/unloadable covers get a deliberate visual fallback, never a crash or invisible item.

## One implementation phase
Within `EmporioScreen.gd`/`.tscn` and focused Emporio UI tests, build a responsive shop: category browsing, visual focusable item cards, large selected-track preview with cover/title/category/price/state, visible credit balance and controller hints, and a prominent purchase/confirm flow. Selection updates the preview; activation preserves existing purchase rules. Keep focus and scrolling usable at 1280x720 by D-pad/stick and mouse; cancel closes confirm before overlay. Validate with the focused economy audit and a 1280x720 visual capture.

## Acceptance
1. Each shop OST uses its existing cover by track ID; missing art has a fallback.
2. Category/card navigation and purchase confirmation are reachable by controller without mouse.
3. Existing economy, credit, ownership, unlock, and modal-cancel tests remain green; no new purchase side effects.
4. At 1280x720, selection, pricing, currency, and Back are legible without overlap/clipping.

## Implementation checkpoint
The user explicitly requested direct implementation after the Flash route did not produce a reviewable result. The original screen was restored before direct work began. The UI now uses the existing cover path, cards, a selected-track preview, category filters, and a controller-focus graph. A later request added a 15-second listen-before-buy sample: it does not write ownership and stops on timeout, selection change, confirmation, or shop close. The continuous menu OST stays paused for the entire time the Emporio is open and resumes on every exit path. `emporio_storefront_test.gd` passes 36/36, including the Jukebox-to-shop path. The existing economy/host audit passes its purchase and focus checks but currently fails two pre-existing hard-coded catalog totals (47 expected, 63 in the concurrently expanded catalog). No automatic commit or push.
