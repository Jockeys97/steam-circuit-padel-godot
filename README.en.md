*[Italiano](README.md) · **English***

# Steam Circuit Padel Pro

[![audit](https://github.com/Jockeys97/steam-circuit-padel-pro/actions/workflows/audit.yml/badge.svg)](https://github.com/Jockeys97/steam-circuit-padel-pro/actions/workflows/audit.yml)

A steampunk arcade padel game in HTML5 Canvas. Playable in the browser, no install.

**Zero dependencies**: no `package.json`, no npm, no bundler. 8,500 lines of plain
JavaScript on Canvas 2D, with a hand-written perspective projection. Audio is synthesised
at runtime through `AudioContext` — there isn't a single audio file in the project.

---

## Why this README talks about decisions

A feature list says very little about a game. What follows is the reasoning behind a
handful of balance decisions instead: what was broken, **how I measured it**, and what I
changed. Every number below comes from a runnable script, not from a hunch.

### 1. The slice dominated the flat drive

I suspected an imbalance and measured it from the baseline:

| charge | shot | speed | depth | 2nd bounce | energy |
|---|---|---|---|---|---|
| 0.5 | drive | 380 | 136 | **41** | 0.085 |
| 0.5 | slice | **393** | **144** | **22** | **0.075** |

The slice was faster, deeper, cheaper in energy **and** handed the opponent a bounce half
as high. There was no situation in which pressing drive was the right call: a dead button.

While fixing it I discovered an engine constraint I hadn't known about.
`setComputerTrajectory` solves for the velocity that lands on the target in the given
time, so **the apex is a pure function of flight time**. Slowing the slice down to make it
"pay in time" turned it into a half-lob (apex from 94 to 140).

I had to change what it trades: the slice doesn't buy time, it buys a flattened bounce by
giving up depth and pace. The flat drive stays the pressure shot.

### 2. The player could not miss

I flew the ball forward using the game's own physics to count real outcomes. Stacking
everything bad at once — terrible timing, running, sprinting, ball out to the side, energy
at the floor, ball already past the body:

| situation | quality | outcomes out of 80 |
|---|---|---|
| still, terrible timing | 0.72 | 80 in court |
| + running | 0.67 | 80 in court |
| + drained | 0.56 | 80 in court |
| + ball already past | 0.51 | 80 in court |

**480 shots, zero errors.** The cause was structural, not a tuning issue: the target is
clamped inside the court and the solver always lands on it. On top of that, the penalty
meant to shorten a bad ball triggered below quality 0.68, while the floor reachable by
timing alone was 0.72 — that branch never ran.

### 3. Threshold effects cannot be tuned

The first error model used continuous perturbations: lateral spread, a flatter arc.
Measured, it turned out to be a switch rather than a curve — either nothing happened, or
everything failed.

The same shape showed up later on the "x2" smash, whose outcome depended on an
interception race:

| return velocity | Rival | Engineer | Champion |
|---|---|---|---|
| 430 | 18.3% | 16.3% | 11.3% |
| 520 | **100%** | 28.7% | 18.8% |

Ninety points of velocity flipped the easy opponent from 18% to 100%.

The lesson, applied twice: where the outcome hinges on crossing a geometric threshold, **a
discrete decision taken once** is tunable and a continuous perturbation is not. Both the
player's errors and the x2 read now use that shape — which is also what the design
document prescribes.

### 4. The AI had no concept of an attackable ball

On a soft, high sitter at the net, 2,000 trials per difficulty, the Champion:

- smashed **20%** of the time
- **lobbed 22% of the time**, standing at the net, off a ball sitting up in front of it
- and was practically identical to the easy opponent: six points apart

Shot selection only looked at its own position, the contact height and a dice roll. Worse:
`hitBall` clamped `ball.z` to 74 **before** the decision, so a ball at 88 and one at 105
were the same object as far as the AI was concerned.

I added an attackability score (real contact height, how slow the ball is, how far forward
it can be taken) and wired it into the choice:

| | before | after |
|---|---|---|
| Rival | 14.3% | **58.7%** |
| Champion | 20.2% | **76.1%** |

Lobbing from the net off a high ball is now forbidden. The spread between difficulties
went from 6 to 17 points.

### 5. A stat that did nothing

`stats.stamina` appeared in **exactly one place** in the whole engine: special-ability
recharge. It never touched rally energy, which drives shot quality, the timing window and
the error rate.

So the character described as *"unbreakable, retrieves every point"* had one advantage: a
slightly faster special. Once stamina fed rally energy, the difference over a long rally
became real: 2.89 errors against 3.30 for the most brittle athlete.

### 6. The serve could not fail

400 trials at every charge level: **100% valid**, always. Second serve, double fault and
`serveAttempts` were unreachable code paths, even though the design document devotes a
chapter to them.

I added execution spread that grows with charge and shrinks with the athlete's control. A
half-power serve is now safe for everyone, while at full charge the Maestro (control 1.28)
faults 16.5% and never double-faults, and the Steamer (0.90) faults 36% and double-faults
8.6%.

### 7. The career rewarded losing on purpose

The season objectives were named as such, and the hand-written targets took it for
granted — `winPoints` asked for 26 points — but the check read the stats of **a single
11-point match**. Three seasons out of the six-season cycle therefore had a
mathematically unreachable star:

| season | dead objective | real ceiling |
|---|---|---|
| 3, 4, 5 | winPoints 26 / 28 / 30 | 11 |
| 6, 7, 8 | winners 12 / 13 / 14 | 11 |

The ceiling isn't an estimate: every point goes through `scorePoint` with a category, and
the two are exclusive, so `winners[p] + errors[opponent] = pointsWon[p] ≤ 11`.

Worse than the impossible star was its mirror image. Losing two matches out of three
replays the season, and the replay regenerated the objectives with `done: false`: the
same three stars could be collected every cycle. Measured over ten cycles in season 1 —
the easiest opponent — **60 stars, zero trophies**, enough for everything stars unlock.
The optimal strategy was to lose.

Targets are now derived from the reachable ceiling, season objectives are measured on the
season total, and a star is paid once. Replaying only pays the match bonuses: 33 stars
against the 60 earned by moving up.

### 8. Two tables disagreeing on what an error was

Settling the cumulative objectives produced two sources for the same rule:
`SEASON_METRIC_AGG` said errors are kept at the **worst match**, an `agg` field on the
objectives said they are **summed**. The game read the first; the second sat there
looking authoritative. And because the audit computed ceilings assuming the sum,
`fewErrors: max 18` looked tuned (18 < 33) while being impossible to fail: you cannot
make more than 11 errors in a single match.

The duplicated field is gone, and the audit now asks the real rule for the ceiling — with
an assertion that prevents reintroducing the second table. The lesson is the same as the
pseudo-random generator: when a value doesn't move the outcome, the instrument is the
first suspect.

### 9. Training taught physics that did not exist

`drill.js` was a second engine: its own gravity, its own meter, a "perfect"
pinned at `0.62`. No timing window, no shot quality, no rally energy, no athlete
stats, no glass. It didn't train badly — it trained **a different game**. And
that is the worst kind of defect, because it doesn't surface as an error: it
surfaces as a player who practises and doesn't improve.

Training is now a match: `createMatchState` builds the real state and
`updateMatch` advances it. The file only does the two things a match doesn't —
feed the ball and score the objectives — and every mechanic comes for free,
including the ones that get retuned tomorrow. The ball isn't even hand-built:
`hitBall` with `forceContact` sends it, so what arrives is a real shot, with its
own spread and the physics of the chosen arena.

The engine was left untouched. Where the drill needs the rivals frozen, they stop
by raising their `hitCooldown`: `hitBall` refuses the shot while it is positive.
No special mode to maintain inside `game.js`.

Three exercises, one per mechanic that wasn't trainable before: targets that ask
for slice or drive, lobs to close out with x2/x3, and a full rally where energy
drives timing and quality.

### 10. The court was a menu

With training running, the space bar pressed the focused button and the arrow
keys moved the menu focus. The cause was one line:

```js
const menuActive = !matchState?.running || matchState?.paused;
```

Training doesn't use `matchState`, so the condition held for the whole exercise
and the menu branch swallowed the keys with a `return` before `keys.add(key)`.
Not a single command reached the court: the old drill only responded because it
read space from `keyup`, which wasn't intercepted.

You can't see it by reading the drill code, and no audit catches it: I found it by
screenshotting the screen and asking why it kept returning to the menu.

### 11. Target practice rewarded the button, not the shot

Shot coherence was judged from `backspin > 0.5` — an input flag that only said
*"you pressed X"*. But slice, per the design document, buys **a squashed bounce**,
and that is an outcome, not a command. A badly executed slice passed exactly like
a good one.

Measuring the outcome took two attempts. The first, the apex of the second bounce,
returned **129 in all six cases** across 40 seeds each: a suspicious constant, and
indeed the instrument was broken. Tracing the height showed why:

```
bounce 1 at y=120 vz=-249
  z=-2 y=120     ← the ball no longer moves
  z=-2 y=120
```

After the first bounce the point is already awarded, and during `pointPause` the
physics doesn't advance: **the second bounce is not observable** from training.

The right number was one step earlier — the vertical velocity at impact, from
which the engine derives the bounce height. Measured over 30 trials per charge
level:

| shot | |vz| at impact |
|---|---|
| flat | 227 – 259 |
| slice | 181 – 221 |

They don't overlap, but the gap is **6 units**: a hard threshold in the middle
would be the switch section 3 says not to use. Scoring is therefore continuous
between the two references, and a half-executed slice earns a half mark.

It has to be read *before* the simulation step: after impact the engine has
already reflected and damped `vz`, so reading it afterwards would no longer say
how hard the ball arrived.

### 12. Scoring without diagnosing teaches half the lesson

Training gave a grade and points and stayed silent on the reason. Every attempt
now closes with a diagnosis — too short, too deep, wide, in but bouncing too high,
smash defended, arrived on empty — and the audit checks two things: that **no
attempt closes without one**, and that every key exists in both languages. `t()`
returns the raw key when a translation is missing, so a hole would reach the
screen as `drillWhyWide`.

In the same pass: the record now survives the session, in `localStorage` and **per
exercise** (target-practice and rally scores aren't comparable); difficulty is
chosen on the screen instead of being silently inherited from the quick match; and
there is a **serve** exercise, which uses the engine's `prepareServe` and shows
double faults — the path that was unreachable before execution spread existed.

Persistence lives in `ui.js`, not `drill.js`: that file must stay runnable without
a DOM, because the audit imports it in Node where `localStorage` doesn't exist.

### 13. A feedback form that loses messages is worse than none

The menu now has a player-feedback button, ahead of release. The hard part wasn't
the form: it was deciding **what** gets attached and **what happens** when sending
fails.

Free text alone is unusable. "The x2 smash is too strong" doesn't say with which
athlete, in which arena, at what difficulty and — above all — under which tuning.
That's why `VERSION.balance` travels with every message: without it, a complaint
that arrives today becomes indistinguishable from one that arrives after the next
retune, and you no longer know which game it referred to. The rest of the context
the game already has in `localStorage`: settings, career state, training records,
the last three matches.

The context is **shown and refusable**: the form prints it in full before sending.
Attaching data without showing it isn't acceptable, and on Steam it would require
a separate privacy notice.

The local queue is written **before** any network attempt, because on Steam people
play offline and a failed POST would lose the message with nobody noticing.
`endpoint` is deliberately `null`: while it stays that way, feedback is collected
and copied to the clipboard, with no server to maintain. The day an endpoint
exists, you fill that field in and nothing else changes.

Writing it produced two defects, both found by a test rather than by re-reading:

**The send branch was unreachable.** `flushFeedback` checked the endpoint first, so
with `endpoint: null` the "rejected" and "offline" cases couldn't run: you'd learn
whether they work on the day you ship. It's the same defect as the serve that
couldn't fail. Endpoint and `fetch` are now parameters, and the audit exercises
them for real — including the case where a second send must not even touch the
network.

**The new screen rendered blank.** `showScreen` turns every screen off and the
requested one on: a name missing from the `screens` registry turned them all off
and none on. No console error, nothing pointing at the cause. An unregistered name
now leaves the screen where it is and logs something readable.

### 14. On a controller, half the game was a dead end

Checking pad navigation ahead of Steam surfaced four defects: three trivial, and one
the code hid well.

**Back wasn't where anyone looks for it.** It was on `b(2)` — X on Xbox, Square on
PlayStation. `b(1)`, that is B/Circle, wasn't mapped to anything in menus. And the
in-game help, in both languages, promised `"A confirm · B back"`: a binding that did
not exist. Three different things — what you try, what the guide promises, what the
code does.

**From the main menu, "back" went forward.** `menuBack` clicked the first
`[data-action^="to-"]` in the active screen; on the menu the top bar comes before the
hero, so it opened the Profile. The back control is now declared with `data-back`, and
the menu — being the root — doesn't have one.

**The message field never received focus**, because the target selector listed
`button, input, .mode-card…` and not `textarea` — nor `summary`, so the "what gets
attached" disclosure wouldn't open on a pad.

The fourth is the one that matters. With `textarea` added to the selector, **the
textarea was still unreachable**. The cause was in `moveMenuFocus`, which compared
centres only and penalised cross-axis offset threefold. A wide element has its centre
in the middle of the row: starting from the left column of the six topics, the small,
better-aligned checkbox won despite sitting much further down, and the textarea was
skipped. The focus path, traced in the browser, said it plainly:

```
path: BUTTON -> BUTTON -> BUTTON -> BUTTON#feedbackCopyBtn
textarea reached: false
```

Now whatever overlaps on the cross axis beats centre distance, because that is what
actually lies in that direction. It holds for every wide element, not just this one.

### 15. Without an on-screen keyboard the feedback form was decorative

On a controller alone you couldn't type: no virtual keyboard existed in the project.
You can't rely on Steam's — in Big Picture and on Deck it appears depending on the
wrapper and Steam Input configuration, and on the web it doesn't appear at all.

The keys are real `<button>`s inside an overlay that becomes the focus context: the
menus' geometric navigation reaches them **without a single new line of code**, and
they work with a mouse too. Confirming on a text field opens it, back closes it, and
what you type shows in a preview because the panel covers the real field.

Tested by driving a fake pad — replacing `navigator.getGamepads`, so the real path
runs, detection included:

```
path: BUTTON -> BUTTON -> BUTTON -> TEXTAREA#feedbackMessage
keyboard open: true      typed into field: 'ciao qui'      counter: 8 / 1200
```

The counter moving is the proof the `input` event fires: without it the field would
fill up and the rest of the form wouldn't notice.

---

## When the test harness lies

Two measurement mistakes worth telling, because they nearly led me to the wrong
conclusions.

**The pseudo-random generator.** Measuring the AI's shot selection I was getting zero
smashes out of 600 trials, with a value that *never* fell below the threshold. The flaw was
mine: I was reseeding a linear congruential generator with consecutive seeds 1, 2, 3… and
an LCG seeded that way produces correlated values that sweep a lattice instead of covering
the interval. Rewritten with a generator seeded once and a sanity check on the real code
path (mean 0.496 against an expected 0.5), the numbers changed completely.

**Module identity.** A parameter sweep kept returning the same result. The reason: the
game's modules import each other with a cache-busting query (`data.js?v=…`) and my script
imported `data.js` without one. To Node those are **two distinct modules**, so I was
mutating an object the game never read.

**Language inside the measurement.** `recordPointStats` decided whether a point was a
winning shot or an error with a regex over the **already translated** message. Playing in
English almost nothing matched: `errors` stayed at zero for the whole match and the
end-of-match screen showed 0-0. The objective "at most N errors" became a free star and
"N winning shots" became unreachable — the entire career mode measured wrong, in one
language only. The category is now declared by whoever awards the point, and translation
happens only when it is drawn.

All three taught me to verify the instrument before the results: if a parameter doesn't
move the output, the measurement is the first suspect.

---

## The audit suite

Runnable scripts in `scripts/`, no test framework:

```bash
node scripts/shot-quality-audit.mjs       # timing, quality, energy, speed
node scripts/shot-balance-audit.mjs       # lobs, x3, AI repertoire
node scripts/smash-input-audit.mjs        # double tap, downgrades, serve return
node scripts/difficulty-audit.mjs         # the three-difficulty ladder
node scripts/controller-tactics-audit.mjs # technical shots, movement, tactics
node scripts/career-audit.mjs             # reachable stars, ramp, farming, finale
node scripts/drill-audit.mjs              # training runs on the game engine
node scripts/feedback-audit.mjs           # no feedback is lost, nothing is attached silently
node scripts/api-feedback-audit.mjs       # the endpoint's guards, with no deploy and no keys
node scripts/gamepad-nav-audit.mjs        # everything reachable on a pad, text fields included
node scripts/module-contract-audit.mjs    # every import finds its export
node scripts/modules-audit.mjs            # every module evaluates without throwing
```

They don't check that the code runs: they check that the **balance** holds. Some assertions
are explicit design constraints — for instance that the x2 smash stays *"strong but
defendable"*, under 40% of points won. While tuning I had pushed it to 54% and that test
stopped me: it was right and I was wrong.

`module-contract-audit` is the exception that does check the code runs, and it exists for
a failure that doesn't degrade: an import that fails to resolve breaks the module chain,
and the page opens with the court drawn and **no button responding**, because no listener
was ever attached. It happened twice, the second time by restoring from HEAD blocks that
had been added deliberately. It now checks 105 imports against the real exports, and the
version query must be a single one.

All tuning lives in a single `BALANCE` object in [`js/data.js`](js/data.js), so a value can
be moved without touching the logic.

---

## Architecture

| file | responsibility |
|---|---|
| `game.js` | simulation: physics, rules, AI, scoring |
| `render.js` | drawing: projection, court, characters, HUD |
| `data.js` | balance constants, athletes, arenas |
| `main.js` | game loop, input, gamepad |
| `audio.js` | procedural audio synthesis |
| `ui.js`, `i18n.js`, `fx.js`, `drill.js` | interface, languages, particles, practice |

The simulation knows nothing about the renderer: `game.js` imports nothing from
`render.js` except one maths helper. The graphics layer could be replaced without touching
a line of gameplay.

---

## Player feedback

The menu has a button that collects player messages. Delivery goes through
`api/feedback.js`, a serverless function on Vercel: you cannot send mail from the
browser, and a key in client code would be public by definition.

The game stays at **zero dependencies**: the function uses `fetch`, which Vercel's
Node runtime provides.

### Configuration

Environment variables to set on Vercel (Settings → Environment Variables). You need
**one** of the two routes:

```bash
# by email (Resend)
FEEDBACK_TO=your@inbox.com
RESEND_API_KEY=re_...
FEEDBACK_FROM=onboarding@resend.dev     # or a sender on your verified domain

# or by webhook (Discord/Slack) — no mail provider to configure
FEEDBACK_WEBHOOK_URL=https://discord.com/api/webhooks/...

# optional: restrict accepted origins
FEEDBACK_ALLOWED_ORIGINS=https://your-domain.vercel.app
```

While nothing is configured the function answers **503**, not 200. That is a
choice: an endpoint answering 200 without delivering would make the game drain its
queue, and the message would vanish believing it had arrived.

### The three safety nets

The message is saved to `localStorage` **before** any network attempt, so nothing is
lost in any of the ways this can go wrong:

| what goes wrong | what the game does |
|---|---|
| no network | stays queued and retries on next launch |
| function not configured (503) | opens the player's mail app |
| no endpoint (Steam package without an absolute URL) | opens the player's mail app |
| clipboard denied | the message stays queued, and it says so |

### Watch out for the Steam package

`endpoint` is a relative path (`/api/feedback`): fine on the site, where page and
function share a domain. In a Steam package the page isn't served from a domain, so
`js/data.js` needs the **absolute URL** of the deployment. Without it the POST goes
to an origin that doesn't exist — the mail fallback covers the player, but automatic
delivery doesn't happen.

### What travels with the message

Free text alone is unusable: "the x2 smash is too strong" doesn't say with which
athlete, in which arena, at what difficulty. That's why every message carries
`VERSION.balance`, the reference of the **tuning in force** — bump it when you move
a `BALANCE` value, otherwise today's complaint becomes indistinguishable from one
that arrives after the next retune. The context is shown in full in the form and
the player can refuse it.

---

## Running it

Any static server will do, since the game uses ES modules:

```bash
python3 -m http.server 8000
# then open http://localhost:8000
```

Modules carry a version query (`?v=…`) for cache busting. **If you change one, all 25
occurrences** in `index.html` and `js/*.js` must be updated: leave them out of sync and the
browser can serve an old module alongside a new one — and an import that can't find its
export doesn't degrade, the game simply won't start.

```bash
grep -c "20260910-sprite-gate-v41" index.html js/*.js styles.css   # must total 26
```

---

## Controls

Keyboard and gamepad. On a controller: **A** drive, **X** slice/víbora, **Y** lob, **B**
special, **LB** switch player, **RB** technical modifier, **LT** split-step, **RT** sprint
— and, while charging a shot, **RT** becomes the tight angle: it pulls the target towards
the glass and sharpens execution, but adds an irreducible spread that turns the shot into a
deliberate gamble.

## Status

Playable alpha with 6 complete athletes and 26 total kits. Every athlete has unique
signature and mythic outfits; the 20 unlockable variants use 120 dedicated lossless WebP sprite
sheets, loaded on first request. The initial image payload remains below 15 MB.
