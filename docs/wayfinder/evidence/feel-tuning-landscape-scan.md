# Feel-tuning scan: tennis and padel adjacent games

Date: 2026-09-18. Repo: `steam-circuit-padel-godot`, worktree `luca-game-mechanics`.

Purpose: check our movement and ball-speed tuning against comparable games and against the real
sport, and find out whether comparable games let players change these values.

Method: 4 parallel budget scouts (deepseek-flash via opencode-go), one lane each. The parent then
re-read our own files and cross-checked the decisive external claims against primary sources.
Everything below is labelled either **verified by parent** (I read the file or the paper myself) or
**scout-sourced** (URL given, not re-fetched). Correction of two scout errors is in the last section.

Lanes: commercial tennis sims; padel titles; open-source constants; real-sport ground truth and
design practice.

---

## 1. Our numbers, measured

From `tools/audit-port/logs/court_speed_audit.log` (seed 11, mean ball speed from strike to first
bounce, not launch speed). **Verified by parent.**

```
ball(driveSoft=211.6 driveFull=520.4 smash=580.2)
athletes(slow=291.6 median=304.3 fast=412.1)
ai(easy=280.9 hard=378.1)
ratios(driveFull/median=1.71 smash/median=1.91)
PASS 25/25
```

That audit encodes three promises the reference makes, and all three pass: a full drive beats the
median athlete, a smash beats a full drive, no athlete outruns a full drive, and the AI speed
bracket straddles the athletes' band. So the tuning is internally consistent. The question this scan
answers is whether the whole speed *scale* sits where it should.

Frozen values the scan compares against, from `godot/src/sim/frozen/data.json`: `basePaddleSpeed` 317,
`ballGravity` 720, `groundRestitution` 0.56 plus 0.07 at high impact, `airDrag` 0.9985,
`minimumBounceVz` 118. Arena `wallBounce` runs 0.83 to 0.95 across the nine courts.

## 2. The unit problem, and why it decides everything

`godot/game/court.gd` converts simulation pixels to the 3D world. **Verified by parent** (read the
file). It says outright: "X maps linearly to 10 m", and depth uses "a monotone C1 curve through net,
service line (6.95 m) and back glass (10 m)". Its own header calls this "an arcade projection, not
new physical metres".

The consequences, all computed from that mapping:

| Axis | Scale | Kind |
|---|---|---|
| X, across the court | 800 px = 10 m, so 80 px/m | linear |
| Y, along the court | 254 px = 10 m, so 18.1 px/m at the net rising to 42.0 px/m at the back glass | nonlinear curve |
| Z, height | 40 px/m (`PX_TO_M` 0.025) | linear |

So there is no single "pixels per metre" in this game. Cross-axis reasoning is invalid, and the two
scouts who converted our numbers to metres disagreed by a factor of two for exactly this reason.

It has a second effect worth knowing: a ball at a constant 580 px/s has a *real-metre* speed of
32.1 m/s near the net and 13.8 m/s at the back glass. The projection makes the ball appear to lose
more than half its speed on the way to the back wall, on top of what drag already does. That is a
presentation decision, not a bug, but it means "the ball feels slow at the back" is partly geometry.

The usable metric is therefore time, not speed. Our court is 10 m across and 20 m long by
construction, so flight times are real regardless of the pixel scale.

## 3. Real padel, verified

**Verified by parent.**

- FIP Rules of Padel, in force 1.01.2026: court 10 m x 20 m interior, service line 6.95 m, net
  0.88 m at the centre and 0.92 m at the ends. Our port renders the net at 38 px x 0.025 = 0.95 m,
  close to the real 0.88 m.
- Rivilla-Garcia et al. 2019, *Kinesiology* 51(2) 206-212, 44 players, StalkerPro radar, **peak**
  velocity of an overhead smash. Semi-pro 133.12 km/h (37.0 m/s) with no opposition, 120.81 km/h
  (33.6 m/s) with opposition. Amateur 124.55 km/h (34.6 m/s) with no opposition, 104.55 km/h
  (29.0 m/s) with opposition. Method note that matters: these are peak readings, and the shot was
  hit from 2 m from the net into the opponent's court.

**Scout-sourced, not re-fetched:** padel player median maximum speed 15.21 km/h (4.23 m/s), elite up
to 25 km/h, 3430 m covered per match, 52 percent of it lateral (Biol Sport 2025, doi 10.5114/biolsport.2025.139856).
Treat this as the weaker link: one study, and "median max speed" is a loose definition.

### The comparison that survives the unit problem

| | Our game | Real semi-pro, peak | Real semi-pro, opposed | Real amateur, opposed |
|---|---|---|---|---|
| Top shot speed | 580.2 px/s | 37.0 m/s | 33.6 m/s | 29.0 m/s |
| Time to cross 20 m | 876 ms | 541 ms | 596 ms | 689 ms |
| Distance the defending player covers in that time | 3.47 m | 2.29 m | 2.52 m | 2.91 m |

(The real-player column uses the scout-sourced 4.23 m/s.)

Our smash crosses the court in 876 ms. Even against the slowest real benchmark, an amateur smash hit
with opponents in front of them, the real ball takes 689 ms. So our ball is about 1.3x to 1.6x slower
across the court than real padel, and our defending player has correspondingly more time to reach it.

To match a real crossing time, the smash wants:

- 738 px/s to match an amateur smash under opposition
- 852 px/s to match a semi-pro smash under opposition
- 939 px/s to match a semi-pro peak smash

Call it 740 to 940 px/s against today's 580, a rise of roughly 1.3x to 1.6x. The middle of that band
is a defensible target, and the choice between them is a feel decision, not a research one.

Meanwhile the player's own speed is fine. Base 317 px/s is 3.96 m/s against a real 4.23 m/s median,
and our fastest athlete (Pantera, 412.1 px/s) is 5.15 m/s against real elite figures up to 6.9 m/s.
The player crossing the full court width takes 2.52 s here against 2.36 s for a real player. So the
runner is already at the sport's scale and the ball is the low end. Scout 4 concluded the opposite
and was wrong; see section 8.

## 4. What comparable games let you change

The short answer: almost nothing exposes raw physics, and two games expose gameplay sliders.

**Scout-sourced unless marked.** Slider names for AO Tennis 2 and Tiebreak could not be re-fetched
(Steam news pages render client-side and return an empty extract), so treat those two rows as
unconfirmed.

| Game | Exposes | Notes |
|---|---|---|
| AO Tennis 2 | per-surface Game Speed, Ball Speed, Assisted Movement, Aiming Sensitivity sliders, plus difficulty | the closest thing to what you are asking for. Unconfirmed |
| Tiebreak (Big Ant) | Custom Difficulty sliders since Dec 2024; patch notes describe tuning movement speed, per-shot ball physics, surface speed and bounce, net cord | unconfirmed |
| Tennis Elbow 4 | editable `Tennis.ini` plus an "Edit Hidden Settings" menu, dev mode, official mod support, 6 difficulty levels x 10 sublevels | the most tunable commercial title found |
| Full Ace Tennis Simulator | official modding support, animation mods; sliders community-claimed only | |
| TopSpin 2K25 | AI difficulty presets and toggles only | 2K markets it as both a simulation and "a realistic arcade experience" |
| Tennis World Tour 2 | career difficulty only | |
| Mario Tennis Aces, Virtua Tennis | nothing beyond gameplay options | arcade |

Nothing in that list publishes absolute speed, gravity or restitution values. No competitor gives the
player a gravity or bounce slider. The exposure pattern is difficulty presets, assists, and (twice)
surface-speed sliders.

## 5. Padel titles

**Scout-sourced.** The padel field is thin and mostly unreleased.

- **PadelVR Game** (Quest): the only one found with a physics tab, exposing bounce and air friction
  and a racket bounce rate. No published values.
- **KorrPadel, SliceShot Padel, Padel Impact Pro, Padel Rivals, Padel Simulator**: announced on Steam,
  no builds, no published values. Several claim glass rebounds.
- **Padel Pro World Tour** (released July 2026): arcade, no documented settings.
- **Red Bull Padel: Court Legends** (mobile, Aug 2026): the only title found modelling out-of-court
  returns, plus a slow-motion mechanic.
- **Steam Circuit Padel Pro**: the browser original of this project, on itch.io. Four difficulties.

Two corrections to common assumptions, worth recording: there is no *World Padel Tour: The Game*
(the circuit was absorbed into Premier Padel), and *Padel Manager* is club booking software, not a
game. *Padelo* is a crash-betting game with padel art. *Racket Club* sells an invented sport that
merely resembles padel.

So on the mechanics we already have (glass rebound varying per arena, serve rules, lob and cut
volley, a three-tier shot quality system), we are ahead of everything shipping. Our exposed surface
(four difficulties) matches the field's ceiling.

## 6. Open-source constants, the only directly comparable numbers

**Scout-sourced**, with literal constant names read from source. Units are not convertible between
projects, so compare shapes rather than magnitudes.

| Project | Engine | Key values |
|---|---|---|
| `phausser/Padel` (MIT) | JS canvas | `COURT_WIDTH_METERS` 10, `COURT_LENGTH_METERS` 20, `BALL_FLOOR_RESTITUTION` 0.72, `BALL_WALL_RESTITUTION` 0.84, `BALL_NET_RESTITUTION` 0.36, `BALL_SPIN_DECAY` 0.92, `AI_MAX_SPEED` 6.25 |
| `alandaitch/premier-padel` (MIT) | TS / Three.js | court halfWidth 5, halfLength 10, netHeight 0.88, restitution by material: hard 0.768, glass 0.768, turf 0.75, mesh 0.48, **net 0.12**; `dragCoefficient` 0.55, `runSpeed` 5.6 m/s, AI 4.7 to 5.9 |
| `mbkma/pelota` (GPL-3.0) | Godot 4 | `PLAYER_MOVE_SPEED` 5.0, `GRAVITY` 9.81, `BALL_DAMP` 0.8, `AIR_DRAG` 0.02, `MIN_BOUNCE_SPEED` 0.2 |
| `pyroboy/pickleball-godot` | Godot 4 | `PLAYER_SPEED` 5.8, `AI_SPEED` 6.5, `MIN_SERVE_SPEED` 5.5, `MAX_SERVE_SPEED` 12.0, `BOUNCE_COR` 0.640, `DRAG_COEFFICIENT` 0.47. Two files disagree on `GRAVITY_SCALE` (1.5 vs 1.0) |
| `nicolassantibanez/padel-arcade` | Godot 4 | the only Godot padel code found. `MAX_SPEED` 300, ball `speed` 14, player `default_speed` 7, units unstated |
| `Tennis Elbow 4` modding SDK | Mana engine | per-surface `CoF` / `CoR0` / `CoR1` / `SurfaceSpeed`, for example clay CoF 0.76, CoR0 0.85; `GameSys.ini` `SlidingSpeed` 4.75 to 5.75, `FrameBySecond` 60 |

The closest structural analogue to our game is `phausser/Padel`: top-down, 10 x 20 m, same family of
constants. The most physically serious is `premier-padel`: it separates restitution per material and
gives the net its own very low value.

Two patterns worth taking. First, `premier-padel` models the net as its own material with its own
restitution (0.12) rather than folding it into one wall number. Second, Tennis Elbow exposes surface
coefficients as a small editable table, which is the shape a personal tuning file could take here.

## 7. What the design literature says

**Scout-sourced**, with one important caveat: no source prescribes a projectile-to-player speed ratio
for sports games specifically. The published rules come from other genres.

- Make the player's own projectile fast: 5x player speed (Vlambeer, "The art of screenshake", 2013);
  3x in a University of Michigan brief.
- Make what the player must react to slow: Lockhart, "Bright, Slow and Deadly" (2012), and Stark's
  GDC 2017 "Predictable Projectiles".
- Reaction budget: 200 to 300 ms for a simple visual cue, which is 12 to 18 frames at 60 fps.
  Wagar sets enemy attacks at 20+ frames (333 ms) of startup, or 16 frames (267 ms) if telegraphed.

The scout's own inference was a 4x to 9x band for a ball that must beat a runner yet stay reactable.
That is a derivation, not a published rule, and this scan's independent calculation lands in the same
place: 738 to 939 px/s against a 317 px/s runner is 2.3x to 3.0x in screen terms but 4.5x to 5.8x once
both are converted through their own axis scales. Either way our current 1.83x screen ratio is below
the band.

The reaction-budget rule is the one to be careful with. Raising the ball toward 900 px/s leaves our
876 ms crossing at 689 to 541 ms, still comfortably above the 333 ms telegraph threshold, so it stays
reactable. That is the argument for the change, and also its limit.

## 8. Corrections to scout output

Recorded because the first draft of this scan would have shipped a wrong number.

Scout 4 assumed 800 px = 20 m. `court.gd` says X is 800 px = 10 m and depth is 508 px = 20 m. Two
consequences:

1. Scout 4 stated our player runs 7.9 m/s, "1.9x a real padel player", and concluded the player was
   too fast and the ball needed 5x player speed, about 1600 px/s. The player is actually 3.96 m/s
   against a real 4.23 m/s, so 0.94x. The player is right and the ball is low. The recommendation is
   therefore on the correct side of the problem for the wrong reason, and its number is roughly twice
   what the crossing-time calculation gives.
2. Scout 3 read the same axis as I did (80 px/m) and reached the right conclusion by a different
   route.

Scout 4's real-sport figures all checked out against primary sources, including the study's method and
its full results table.

Scout 1: AO Tennis 2 and Tiebreak slider lists could not be confirmed. Steam news pages render
client-side. Treat those two rows as unconfirmed.

No published ball-speed, gravity or restitution values exist for any commercial tennis or padel title
found. That absence is itself the finding: there is no benchmark to compare our table against, so the
real sport is the only external reference available.

## 9. Recommendations, ranked

1. **Raise the top shot into 740 to 940 px/s, from 580.** This is the one change with evidence behind
   it. It moves the ball from 0.62x to 0.79x of a real smash up to roughly 1.0x, and shortens the
   crossing time from 876 ms to 689 to 541 ms. Re-run `court_speed_audit` afterwards: every promise
   there is ratio-based, so a higher smash should keep them green, and Pantera at 412.1 px/s stays
   well under a stronger drive. Pick the low end (around 740) if you want the AI to keep coping, the
   high end if you want smashes to feel decisive.
2. **Do not expose gravity, restitution or drag as player settings.** No comparable title does, and
   they interact in ways a slider hides. The competitor pattern is difficulty presets and assists,
   which we already have.
3. **Add a small editable tuning table for yourself, shaped like Tennis Elbow's surface file.** You
   asked to iterate by hand; a file with named values beats editing `data.json` and remembering to
   sync `js/data.js`. Keep it dev-facing, not in the shipped menu.
4. **Convert remaining feel arguments into times, not speeds.** "The ball feels slow" becomes "the
   ball crosses in 876 ms and a real one takes 541 to 689 ms". Times survive the projection; px/s
   between axes does not.
5. **Consider giving the net its own restitution**, as `premier-padel` does (0.12), instead of leaving
   it inside `netClearance` behaviour alone. Low priority, but it is the one physics idea in the
   field we do not already have.

## 10. Not verified

- Padel player movement speed (4.23 m/s median max) rests on one scout-sourced study, doi
  10.5114/biolsport.2025.139856. Not re-fetched. Every real-player column above depends on it.
- No coefficient of restitution is published for padel glass or mesh. Our 0.56 and 0.9985 have no
  FIP or ITF counterpart, and the comparative study found only that glass rebounds faster and longer
  than concrete, with no number.
- AO Tennis 2 and Tiebreak slider names.
- All open-source constants are source literals read at the access date. Nothing was built or run.
- Tennis Elbow 4 per-shot ball speeds are engine-internal; only surface coefficients are readable.

## 11. Sources

Real sport: FIP Rules of Padel, in force 1.01.2026
(https://www.padelfip.com/wp-content/uploads/2024/11/FIP-Rules-of-Padel.pdf); Rivilla-Garcia et al.
2019, doi 10.26582/k.51.2.6; ITF Rules of Tennis 2026 and Technical Booklet 2026
(itftennis.com); Gea-Garcia et al. 2021, doi 10.1080/24748668.2021.1875778; Biol Sport 2025, doi
10.5114/biolsport.2025.139856; Human Benchmark reaction-time statistics.

The same numbers were read from three mirrors of the paper (doi.org, hrcak.srce.hr/clanak/331494,
ojs.srce.hr/kinesiology/article/view/5656) to rule out a transcription error, and all three give the
same 133.12 / 120.81 / 124.55 / 104.55 table. One mirror's abstract text reads "Forty-four
semi-professional (n=14) and amateur (n=30)", which contradicts itself; the data table and the body
both give 14 semi-professional and 30 amateur, totalling 44, so the table is the correct reading.

Competitors: Steam news for AO Tennis 2 (app 1072500) and Tiebreak (app 2264340); managames.com
Tennis Elbow documentation and forum; 2k.com TopSpin 2K25 pages; store pages for Mario Tennis Aces,
Virtua Tennis 4, Full Ace, Tennis World Tour 2, KorrPadel, SliceShot Padel, Padel Impact Pro, Padel
Rivals, Padel Simulator, Padel Pro World Tour; padelvrgame.com FAQ; Google Play listing for Red Bull
Padel; jockeys97.itch.io.

Open source: github.com/phausser/Padel, github.com/alandaitch/premier-padel, github.com/mbkma/pelota,
github.com/pyroboy/pickleball-godot, github.com/nicolassantibanez/padel-arcade,
codeberg.org/osgames/cannonsmash, codeberg.org/osgames/freetennis, Tennis Elbow 4 modding SDK
(managames.com/download.php?TE4-ModdingSDK_v1.zip).

Design practice: Vlambeer "The art of screenshake" (INDIGO 2013); Lockhart "Bright, Slow and Deadly"
(2012); Stark, GDC 2017, "Predictable Projectiles"; Wagar on attack startup frames.
