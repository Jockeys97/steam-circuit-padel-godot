# Steamworks prerequisites

- Status: open
- Type: task
- Mode: HITL
- Owner: unassigned
- Blocked by: none

## Question

The Steam-side setup only Luca can do: the App ID for this game, the achievement
list mapped to what the game already tracks, and the cloud storage quota.

**Correction on sequencing:** the live App ID does not block bridge research or
the save-format decision. Integration work can proceed against a Steam
development/test app; only the **live release proof** requires the real App ID.
The ticket therefore resolves in two parts: the decidable part (achievement list,
quota) and Luca's action (App ID recorded).

What the game already tracks, as achievement sources: career stars and the
career progression model (`data.js` CAREER_*), trophies/history, and the **20
unlockable outfit challenges** (`outfitsWon` in `data.js`). Specials are shot
abilities (`specialCooldown`/`specialReady`), not separate characters.

## Why it matters

Achievements and cloud ship in v1 by decision, and neither can be built against
a missing App ID.

## Resolved when

The achievement list is defined with API names, the cloud quota is known, and the
App ID is recorded (a development/test ID is acceptable until the release ticket,
which requires the live one).
