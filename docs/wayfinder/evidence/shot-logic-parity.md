# Shot logic parity — every intent, anchor to anchor

Slice **S14a**. Owner question: *"se i colpi corrispondono come logica a quelle della
versione 2d"* — do the shots correspond, as logic, to the 2D version?

**Verdict: yes, for the whole intent space, at the reference's own printed precision.**
35 scripted scenarios, one per intent / modifier / selection rule, run on both engines
with the same seed and the same input; all 13 intents are produced by both engines with
the same intent, the same direction, the same spin sign and the same x3 flag, and 657
cross-engine field comparisons agree exactly (`tol=0`). Two fields differ in
*representation* and are named in §6, not hidden.

| artifact | side | what it is |
|---|---|---|
| `tools/sim-port/shot-intent-probe.mjs` | JavaScript (reference) | the 35 scenarios against the frozen `js/game.js`; prints `# trace <json>` |
| `godot/tests/shot_logic_parity_test.gd` | Godot (port) | the same 35 scenarios against `res://src/sim/**`; asserts every field against the reference's recorded values and prints the same trace |
| `tools/sim-port/shot-intent-compare.mjs` | — | the verdict: parses both traces, compares scenario by scenario, field by field |
| `tools/sim-port/out/shot-intent-js.txt` | reference | the reference trace (35 rows) |
| `tools/sim-port/out/shot-intent-gd.txt` | port | the port trace (35 rows) |
| `tools/sim-port/out/shot-intent-compare.txt` | — | the comparison output |

The reference tree (`/Users/alessiofantini/Documents/Padel`) was read-only throughout; the
trace runs against the vendored copy of the same frozen `js/` tree, byte-identical
(`sha256 js/game.js = 22b8a4f4154d8ed2b35d107cd94b41e114a53b6fbe3da07c156103e989040fe7`,
`js/data.js = dca8fe0abe4e1b890541b2c9bae278af040ec0c06a2d3a2e4e2e355eff434a53` on both).
No file under `godot/src/sim/**` was touched: a proven divergence would be reported here
with its anchors, not fixed in passing. None was found.

---

## 1. The commands, and what they actually printed

```bash
cd /Users/alessiofantini/Documents/steam-circuit-padel-godot
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# 1. the reference side
node tools/sim-port/shot-intent-probe.mjs > tools/sim-port/out/shot-intent-js.txt
#    exit=0, 36 lines (1 header + 35 `# trace` rows)

# 2. the port side
$GODOT --headless --path godot/ --script res://tests/shot_logic_parity_test.gd \
  > tools/sim-port/out/shot-intent-gd-raw.txt
#    exit=0 ; 675 `ok`, 0 `FAIL` ; `# report scenarios=35 intents=13 expected_rows=35` ;
#    `PASS 675/675`

# 3. the verdict
grep '^# trace' tools/sim-port/out/shot-intent-gd-raw.txt > tools/sim-port/out/shot-intent-gd.txt
node tools/sim-port/shot-intent-compare.mjs \
  --js=tools/sim-port/out/shot-intent-js.txt \
  --gd=tools/sim-port/out/shot-intent-gd.txt | tee tools/sim-port/out/shot-intent-compare.txt
```

Real output of step 3 (`tools/sim-port/out/shot-intent-compare.txt`):

```
# known-difference intent/serve wallKill: js=null gd="0.000000" (representation, declared in the test and in the evidence)
# known-difference intent/serve/slice wallKill: js=null gd="0.000000" (representation, declared in the test and in the evidence)
# scenarios js=35 gd=35 fields_compared=657
IDENTICAL 35/35 scenarios, 657 field comparisons, tol=0
```

Exit code `0` = IDENTICAL. The comparator has no tolerance: both sides print floats with
`%.6f` and the comparison is `!==` — the same rule as `tools/parity/**` (`--tol=0`).

Non-regression, in the same tree, at the same time (`--headless --path godot/ --script
res://tests/game_slice_test.gd`): **287/289**, two reds, neither of them this slice's —
see §7.

### The gate can fail

A green run is not a lookup — the comparator was mutated on a real artifact and caught it:

```bash
sed 's/"shotType":"smash-x3"/"shotType":"smash-x2"/' \
  tools/sim-port/out/shot-intent-gd.txt > tools/sim-port/out/selftest-mut-gd.txt
node tools/sim-port/shot-intent-compare.mjs \
  --js=tools/sim-port/out/shot-intent-js.txt --gd=tools/sim-port/out/selftest-mut-gd.txt
```

Real output:

```
DIVERGED intent/smash/x3 shotType: js="smash-x3" gd="smash-x2"
DIVERGED rule/x3-vs-x2-auto shotType: js="smash-x3" gd="smash-x2"
# scenarios js=35 gd=35 fields_compared=657
DIVERGED 2 field comparison(s)
```

exit `1`. The two rows are exactly the two whose `smash-x3` was rewritten by the `sed`, and
nothing else moved.

The port's test is sensitive on its own account for the same reason: every field check
compares the port's *live* value against the reference's recorded number in `EXPECTED`,
which is a constant in the test file. It reported this during the slice: the first run on
this tree printed `671/675` with four failing checks — the two `path` strings (which were
made byte-identical to the reference's) and the two `wallKill` fields (the representation
difference named in §6, now an explicit assertion of `"0.000000"`). Both were resolved by
fixing the discrepancy or naming it; no assertion was weakened and no tolerance was widened
anywhere.


---

## 2. The 13 intents — the decision, the anchors, the verdict

`js/game.js:1468-1921` is `hitBall` in the reference; `godot/src/sim/sim.gd:1527-1868` is
`hit_ball` in the port. Every row below is `identical`: the same branch, in the same order,
with the same constants read from the same frozen table (`js/data.js` ->
`godot/src/sim/frozen/data.json`, generated by `tools/sim-port/extract-constants.mjs`; the
values cited were read back from both files and are equal).

| intent | the decision that produces it | reference anchor | port anchor | constants involved | verdict |
|---|---|---|---|---|---|
| `drive` | the base trajectory: no branch taken (no smashType, `\|aimedOffset\| < 0.72`, not slice, not lob/chiquita/globo/cut-volley) | `js/game.js:1508` (default), `:1645-1668` | `sim.gd:1555`, `:1647-1660` | `aimReach 0.42`, `shotErrorThreshold 0.8`, `shotErrorSpan 0.32` | identical |
| `slice` | `else if (slice)` and `viboraRange` false (outside `viboraNetWindow`) | `js/game.js:1799-1816` | `sim.gd:1764-1780` | `viboraNetWindow 96` | identical |
| `vibora` | `slice` + `viboraRange` + contact height >= 42 (42 when the variant is `vibora`, else 48) | `js/game.js:1540-1542`, `:1800-1812` | `sim.gd:1572`, `:1765-1777` | `smashNetWindow 190`, `viboraNetWindow 96`, threshold 42/48 | identical |
| `bandeja` | `explicitSmash` with `smashReady` false (low ball, baseline, service return) or `aimedDepth >= 0.32` | `js/game.js:1556-1567`, `:1751-1757` | `sim.gd:1582-1592`, `:1726-1732` | `smashMinHeight 46`, `smashMinPower 0.98`, depth `0.32` | identical |
| `chiquita` | `shotVariant === "chiquita"` (branch before the smash ones) | `js/game.js:1672-1690` | `sim.gd:1663-1674` | depth `62 + power*34 - aimedDepth*18`, `backspin 0.55` | identical |
| `volley` | `chooseComputerShot`: `atNet && ball.z > 42 && choice < 0.78 + attack*volleyGain`, then the kind roll misses the vibora band | `js/game.js:1219-1220` | `sim.gd:1335` | `attackReadVolleyGain 0.2`, vibora band `0.28 + skill*0.12` | identical |
| `cut-volley` | `shotVariant === "cut-volley"` and `quality >= cutVolleyMinQuality` | `js/game.js:1782-1798` | `sim.gd:1751-1763` | `cutVolleyMinQuality 0.52`, depth 214, flight 0.86, backspin 1.15 | identical |
| `lob` | `shotVariant === "lob"` (branch before the smash ones) | `js/game.js:1691-1715` | `sim.gd:1675-1690` | depth `96 + powerRatio*118`, flight `1.5 - powerRatio*0.18` | identical |
| `defensive-lob` | the same branch with `defensiveLob` true (pad **Y + RB**) | `js/game.js:1692`, `:1705-1710` | `sim.gd:1676`, `:1685-1689` | depth `112 + powerRatio*98`, flight `1.68 - powerRatio*0.12` | identical |
| `globo` | `shotVariant === "globo"` and `quality >= globoMinQuality` (else the success flag is false and the intent is `lob`) | `js/game.js:1765-1781` | `sim.gd:1738-1750` | `globoMinQuality 0.72`, depth 218 / fail 118, flight 1.98 / fail 1.52 | identical |
| `smash` (x2) | `smashReady` + `explicitSmash` + `aimedDepth <= -0.28` + `\|aimedOffset\| < 0.42`; or `smashReady` + auto + `\|aimedOffset\| < 0.52`; then `quality >= smashX2MinQuality` | `js/game.js:1556-1565`, `:1733-1739` | `sim.gd:1582-1590`, `:1708-1715` | `smashX2MinQuality 0.78`, offsets 0.42 / 0.52, `smashNetWindow 190`, `smashMinHeight 46`, `smashMinPower 0.98` | identical |
| `smash` (x3) | the same, with `\|aimedOffset\| >= 0.42` (explicit) / `>= 0.52` (auto) and `quality >= smashX3MinQuality` | `js/game.js:1556-1565`, `:1716-1724` | `sim.gd:1582-1590`, `:1691-1699` | `smashX3MinQuality 0.9`; **x3 flag true** | identical |
| `smash-flat` | a sound `smashReady` contact below the x2 quality gate but above `smashFlatMinQuality` | `js/game.js:1741-1750` | `sim.gd:1716-1725` | `smashFlatMinQuality 0.48`, target `netY - 174`, topspin 0.72 | identical |
| `wall-angle` | `seeksSideGlass`: no smashType, not slice, not lob, `\|aimedOffset\| >= 0.72` | `js/game.js:1569-1572`, `:1761-1764` | `sim.gd:1593`, `:1734-1737` | offset `0.72`, spin `aimedOffset*68*control` | identical |
| `serve` | `performServe`: charge `clamp(requestedCharge ?? 0.62, 0, 1)`, spread, service box depth, flight, spin sign by court; the intent lives in `server.shotIntent = "serve"` because `hitBall` never runs | `js/game.js:715-778`, `:771` | `sim.gd:689-758`, `:747` | `serveSpread`, `serveSpreadBase`, `serveFlightBase/Gain`, `serveSecondSafety` | identical |

---

## 3. The four modifiers (plus the globo tap)

| modifier | the rule that selects it | reference anchor | port anchor | what the trace proves | verdict |
|---|---|---|---|---|---|
| `special` | `input.special` -> `trySpecial` -> `hitBall(.., isSpecial=true)` -> `applySpecial`; gated by `specialMinCharge` and the cooldown | `js/game.js:3199-3202`, `:1978-1990`, `:1923-1976` | `sim.gd:2937-2939`, `:1918-1930`, `:1874` | it fired: `specialCooldown` 2.983333 (`3 - dt`), `specialReady` 0, `hitCooldown` 0.18, and the maestro signature on the ball (vy -469.295 = -470 x drag, vz 313; the read penalty consumed into `aiReactionDelay`) — the same values on both engines | identical |
| `smashUpgrade` | the **A double tap**: the first release primes (`smashPrimed`, `smashTapWindow 0.7`), the second tap sets `queuedShotVariant = "smash"` and the stroke keeps until contact | `js/game.js:3117-3122`, `:3174-3183`, `:2842-2852` | `sim.gd:2860-2865`, `:2913-2921`, `:2527-2536` | `primedAfterFirstRelease=true`, tap window 0.700000, buffer 0.883333, variant after the tap `smash`, contact at tick 18 -> `smash-x2` | identical |
| `cutVolley` | the **X double tap**: a released slice primes while `bounces.player == 0`, inside `viboraNetWindow`, with `ball.z >= cutVolleyMinHeight`; the tap sets `cut-volley` | `js/game.js:3126-3131`, `:3141-3142`, `:3165-3173` | `sim.gd:2866-2871`, `:2879-2882`, `:2905-2912` | primed true, tap window 0.700000, buffer 0.833333, `queuedShotSlice=true` after the first release, `shotIntent` `cut-volley` after the tap, contact at tick 6 -> `cut-volley` | identical |
| `globo` (the third tap) | a **lob** off a real charge (`>= globoMinCharge`) on a ball that is not too high (`<= globoMaxHeight`) primes; the tap promotes the queued variant | `js/game.js:3136-3140`, `:3156-3164` | `sim.gd:2874-2878`, `:2897-2904` | primed true, tap window 0.700000, `shotIntent` `globo` after the tap, contact at tick 2 -> `globo` | identical |
| `teamTactic` | `setPlayerTeamTactic(input.teamTactic)` — the D-pad/keys steer the pair | `js/game.js:2786-2791`, called at `:2983` | `sim.gd:2622-2627`, called at `:2742` | `balanced` -> `attack`, `tacticFlash` 1.100000, re-setting the same tactic is a no-op | identical |
| — | **`teamTactic` does not upgrade an intent, in either engine.** The ticket lists it among "the four modifiers that upgrade an intent"; it does not: it writes `state.playerTeamTactic`, and nothing on the shot path reads it. The trace records the tactic state instead. A ticket description issue, not a port divergence — §8. | | | | not comparable (no intent to compare: the modifier does not select one) |

---

## 4. The charge / double-tap rules that select them

| rule | the decision under test | reference anchor | port anchor | verdict |
|---|---|---|---|---|
| charge accrual | `shotCharge = min(1, shotCharge + dt/1.05)`; the release freezes `queuedShotPower = 0.4 + charge*0.95` and `queuedShotCharge` | `js/game.js:2686-2690`, `:2698-2704` | `sim.gd:2639-2642`, `:2651-2657` | identical (30 ticks -> 0.476190; power 0.852381; same 6 decimals on both engines) |
| variant translation | `variant = input.shotVariant ?? (input.slice ? "slice" : "auto")`, latched at the release | `js/game.js:3115`, `:2860` | `sim.gd:2852-2858`, `:2539-2543` | identical (`slice` queued, `queuedShotSlice=true`, power 0.685000) |
| smash prime accepted | `queuedShotVariant === "drive"` && !slice && `rallyHits > 0` && near net && `ball.z >= smashMinHeight - 8` && power >= `smashMinPower` -> primed, window 0.7, buffer 0.9 | `js/game.js:3117-3122`, `:3132-3133`, `:3145-3151` | `sim.gd:2860-2865`, `:2872-2873`, `:2883-2890` | identical |
| prime refused: slice queued | a slice never primes the smash (the variant is not `drive`) | `js/game.js:3117` | `sim.gd:2860` | identical (`smashPrimed=false`) |
| prime refused: service return | `rallyHits > 0` | `js/game.js:3119` | `sim.gd:2862` | identical |
| prime refused: baseline | `withinNetRange(player, smashNetWindow)` | `js/game.js:3120` | `sim.gd:2863` | identical |
| prime refused: low ball | `ball.z >= smashMinHeight - 8` | `js/game.js:3121` | `sim.gd:2864` | identical |
| prime refused: soft contact | `queuedShotPower * athlete.power >= smashMinPower` | `js/game.js:3122` | `sim.gd:2865` | identical (power 0.495000 < 0.98) |
| tap window expiry | `smashTapWindow` decays per tick; at 0 `smashPrimed = false` and the contact fallback arms, after `smashDoubleTapWindow` = 0.7 s | `js/game.js:3099-3104`, `:2890-2895` | `sim.gd:2839-2843`, `:2581-2585` | identical (expires after exactly 42 ticks at `dt = 1/60`, both engines) |
| no second tap | the prepared shot degrades to its queued variant, it does not vanish, and the striker is still the player | `js/game.js:3266-3297`, `:2899-2909` | `sim.gd:3000-3027`, `:2589-2598` | identical (contact at tick 43, `drive`, `lastHitterSide` `player`) |
| x3 flag (auto) | `smashReady` + auto + `\|aimedOffset\| >= 0.52` -> `smash-x3` | `js/game.js:1564-1565` | `sim.gd:1589-1590` | identical (x3 true) |
| x3 downgrade | the x3 branch needs `quality >= smashX3MinQuality`; in the x2 band the x3 asked becomes an x2 | `js/game.js:1716-1732` | `sim.gd:1691-1707` | identical (topspin 0.96, `smash-x2`, x3 false) |
| service return forbids the smash | `serviceReturn = rallyHits === 0` removes `smashReady`, so an explicit smash becomes a bandeja | `js/game.js:1548-1551`, `:1566` | `sim.gd:1574-1577`, `:1591` | identical |
| smash defence | replying to a smash with a grade that is neither perfect nor good raises and shortens the base trajectory | `js/game.js:1521-1534`, `:1658-1660` | `sim.gd:1563-1568`, `:1654-1655` | identical (vz 431.77 against the clean drive's 225.14, in both engines) |

---

## 5. The measured trace, per scenario

Every row below is the reference's printed output for that scenario; the port prints the
same values, field for field (`shot_logic_parity_test.gd` asserts each one against them,
and `shot-intent-compare.mjs` re-checks the two files independently).

### 5.1 The 13 intents

| scenario | kind | produced intent | `paddle.shotIntent` | dir | spin sign | x3 | trajectory signature (px/s, spin units) | flags measured |
|---|---|---|---|---|---|---|---|---|
| `intent/drive` | shot | `drive` | `drive` | -1 | 0 | false | vy `-509.147984` · vz `225.141483` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/slice` | shot | `slice` | `slice` | -1 | 0 | false | vy `-432.831581` · vz `265.628767` · spin `0.000000` · backspin `1.019138` · topspin `0.000000` | — |
| `intent/vibora` | shot | `vibora` | `vibora` | -1 | 1 | false | vy `-397.913300` · vz `228.126829` · spin `76.000000` · backspin `0.820000` · topspin `0.000000` | — |
| `intent/bandeja` | shot | `bandeja` | `bandeja` | -1 | 1 | false | vy `-312.965190` · vz `329.945098` · spin `48.000000` · backspin `0.580000` · topspin `0.000000` | — |
| `intent/chiquita` | shot | `chiquita` | `chiquita` | -1 | 0 | false | vy `-275.880478` · vz `313.278431` · spin `0.000000` · backspin `0.550000` · topspin `0.000000` | — |
| `intent/volley` | shot | `volley` | `volley` | 1 | 1 | false | vy `275.324767` · vz `230.830388` · spin `24.527656` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/cut-volley` | shot | `cut-volley` | `cut-volley` | -1 | 1 | false | vy `-443.484927` · vz `245.646512` · spin `66.560000` · backspin `1.150000` · topspin `0.000000` | — |
| `intent/lob` | shot | `lob` | `lob` | -1 | 0 | false | vy `-264.758808` · vz `460.482554` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/defensive-lob` | shot | `defensive-lob` | `defensive-lob` | -1 | 0 | false | vy `-233.649401` · vz `543.939197` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/globo` | shot | `globo` | `globo` | -1 | 0 | false | vy `-204.577594` · vz `685.022222` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/smash/x2` | shot | `smash-x2` | `smash-x2` | -1 | 0 | false | vy `-642.351654` · vz `113.972414` · spin `0.000000` · backspin `0.000000` · topspin `1.000000` | — |
| `intent/smash/x3` | shot | `smash-x3` | `smash-x3` | -1 | 1 | **true** | vy `-592.033134` · vz `134.490323` · spin `104.960000` · backspin `0.000000` · topspin `1.150000` | — |
| `intent/smash/flat` | shot | `smash-flat` | `smash-flat` | -1 | 1 | false | vy `-550.926459` · vz `129.436066` · spin `57.600000` · backspin `0.000000` · topspin `0.720000` | — |
| `intent/wall-angle` | shot | `wall-angle` | `wall-angle` | -1 | 1 | false | vy `-505.341317` · vz `225.141483` · spin `87.040000` · backspin `0.000000` · topspin `0.000000` | — |
| `intent/serve` | shot | `serve` | `serve` | -1 | -1 | false | vy `-237.234076` · vz `369.833630` · spin `-14.000000` · backspin `0.000000` · topspin `0.000000` | `serveTargetX`=298.930640, `serveTargetY`=224.665490, `served`=true, `serveInFlight`=true |
| `intent/serve/slice` | shot | `serve` | `serve` | -1 | -1 | false | vy `-237.234076` · vz `369.833630` · spin `-25.200000` · backspin `0.750000` · topspin `0.000000` | `backspinIsSlice`=true, `serveTargetX`=298.930640, `serveTargetY`=224.665490 |

### 5.2 The modifiers

| scenario | kind | produced intent | `paddle.shotIntent` | dir | spin sign | x3 | trajectory signature (px/s, spin units) | flags measured |
|---|---|---|---|---|---|---|---|---|
| `modifier/special` | shot | `smash-x2` | `smash-x2` | -1 | 0 | false | vy `-469.295000` · vz `313.000000` · spin `0.000000` · backspin `0.000000` · topspin `0.995000` | `aiReactionDelay`=0.862622, `specialCooldown`=2.983333, `specialReady`=0.000000, `swingBuffer`=0.240000, `hitCooldown`=0.180000 |
| `modifier/smashUpgrade` | shot | `smash-x2` | `smash-x2` | -1 | 0 | false | vy `-642.351654` · vz `81.213793` · spin `0.000000` · backspin `0.000000` · topspin `1.000000` | `primedAfterFirstRelease`=true, `tapWindowAfterPrime`=0.700000, `swingBufferAfterPrime`=0.883333, `variantAfterFirstRelease`=drive, `primedAfterSecondTap`=false, `intentAfterTap`=smash, `queuedVariantAfterTap`=smash, `contactTick`=18 |
| `modifier/cutVolley` | shot | `cut-volley` | `cut-volley` | -1 | 1 | false | vy `-352.854492` · vz `223.553488` · spin `66.560000` · backspin `1.150000` · topspin `0.000000` | `primedAfterFirstRelease`=true, `tapWindowAfterPrime`=0.700000, `swingBufferAfterPrime`=0.833333, `sliceAfterFirstRelease`=true, `primedAfterSecondTap`=false, `intentAfterTap`=cut-volley, `contactTick`=6 |
| `modifier/globo` | shot | `globo` | `globo` | -1 | 0 | false | vy `-204.577594` · vz `676.385859` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | `primedAfterFirstRelease`=true, `tapWindowAfterPrime`=0.700000, `intentAfterTap`=globo, `contactTick`=2 |
| `modifier/teamTactic` | state | `queued` | `drive` | 0 | 0 | false | — | `before`=balanced, `after`=attack, `tacticFlashAfterSet`=1.100000, `reSetIsNoOp`=true |

### 5.3 The charge / double-tap rules

| scenario | kind | produced intent | `paddle.shotIntent` | dir | spin sign | x3 | trajectory signature (px/s, spin units) | flags measured |
|---|---|---|---|---|---|---|---|---|
| `rule/charge-accrual` | state | `queued` | `drive` | 0 | 0 | false | — | `ticks`=30, `chargeAfterTicks`=0.476190, `intentWhileCharging`=drive, `queuedShotPower`=0.852381, `queuedShotCharge`=0.476190, `queuedShotVariant`=auto, `queuedShotSlice`=false |
| `rule/charge-variant-slice` | state | `queued` | `drive` | 0 | 0 | false | — | `queuedShotVariant`=slice, `queuedShotSlice`=true, `queuedShotPower`=0.685000 |
| `rule/smash-prime-accepted` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=true, `smashTapWindow`=0.700000, `swingBuffer`=0.883333, `smashContactFallback`=false |
| `rule/smash-prime-slice-refused` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=false, `cutVolleyPrimed`=false |
| `rule/smash-prime-service-return-refused` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=false |
| `rule/smash-prime-baseline-refused` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=false |
| `rule/smash-prime-low-ball-refused` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=false |
| `rule/smash-prime-low-power-refused` | state | `queued` | `drive` | 0 | 0 | false | — | `smashPrimed`=false, `queuedShotPower`=0.495000 |
| `rule/smash-tap-window-expiry` | state | `queued` | `drive` | 0 | 0 | false | — | `primedAfterFirstRelease`=true, `expiredAfterTicks`=42, `queuedShotVariant`=drive, `swingBuffer`=0.183333 |
| `rule/no-double-tap-degrades` | shot | `drive` | `drive` | -1 | 0 | false | vy `-242.849088` · vz `308.296953` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | `contactTick`=43, `lastHitterSide`=player |
| `rule/x3-vs-x2-auto` | shot | `smash-x3` | `smash-x3` | -1 | 1 | **true** | vy `-592.033134` · vz `134.490323` · spin `104.960000` · backspin `0.000000` · topspin `1.150000` | — |
| `rule/x3-downgrade` | shot | `smash-x2` | `smash-x2` | -1 | 1 | false | vy `-611.578913` · vz `129.436066` · spin `25.000000` · backspin `0.000000` · topspin `0.960000` | — |
| `rule/service-return-no-smash` | shot | `bandeja` | `bandeja` | -1 | 1 | false | vy `-312.965190` · vz `313.278431` · spin `48.000000` · backspin `0.580000` · topspin `0.000000` | — |
| `rule/smash-defence-vs-incoming` | shot | `drive` | `drive` | -1 | 0 | false | vy `-213.614996` · vz `431.767941` · spin `0.000000` · backspin `0.000000` · topspin `0.000000` | — |

`dir` is `sign(ball.vy)`: `-1` is a shot toward the AI's side, `+1` toward the player's
(so the AI's volley and the player's strokes read opposite, correctly). `spin sign` is
`sign(ball.spin)`; `x3` is `ball.shotType == "smash-x3"`. `kind = state` marks a row whose
evidence is a rule/state observation rather than a struck ball (the ball columns are `—`).

---

## 6. Divergences

**One, and it is `divergent (named)`: a representation difference, not a behaviour
difference.**

- `wallKill` on the two serve rows. `createBall` (`js/game.js:74-107`) has **no** `wallKill`
  key — it is first written inside `hitBall` (`js/game.js:1506`) — so the reference's trace
  prints `null`; `godot/src/sim/entities.gd` declares `wallKill: float = 0.0`, so the port
  prints `0.000000`. Both engines only ever assign it or compare it numerically, and both
  read 0 at this point (nothing has hit a wall yet). The port value is asserted explicitly
  (`"0.000000"`) in `UNINITIALISED_IN_REFERENCE` in the test and in
  `KNOWN_REPRESENTATION_DIFFERENCES` in the comparator: a named exception carrying its
  expected values, not a tolerance.

No other field diverges: 655 of the 657 comparisons are exact matches of the printed
numbers, and the two exceptions are the ones above.

---

## 7. Counts, before and after

| gate | before this slice | after this slice |
|---|---|---|
| `godot/tests/shot_logic_parity_test.gd` | (did not exist) | **675/675 PASS**, `# report scenarios=35 intents=13 expected_rows=35` |
| `node tools/sim-port/shot-intent-probe.mjs` | (did not exist) | exit 0, 35 trace rows |
| `node tools/sim-port/shot-intent-compare.mjs` | (did not exist) | exit 0, **IDENTICAL 35/35**, 657 field comparisons, `tol=0` |
| `godot/tests/game_slice_test.gd` | 288/289 (only red: the gitignored `padel.pck`) | **287/289** — two reds, neither from this slice: (a) the same `padel.pck`, (b) *"no `res://` path in `game/**` or `src/**` lives in a tree the exporters exclude"*, which flags `res://game/out/timing_probe.gd` and `res://game/out/probe-%s.png`, written by the **timing** lane working in this tree at the same time. That check scans `game/**` and `src/**` (`godot/tests/game_slice_test.gd:1011`); this slice's files are `godot/tests/shot_logic_parity_test.gd`, `tools/sim-port/shot-intent-*.mjs` and this document — none of them under `game/` or `src/`. |

Files this slice created (all inside the ticket's allowlist; no commit, no push):

```
godot/tests/shot_logic_parity_test.gd        sha256 211f8e7a6a0724ee778ed9f22d61d81412ca3b6e8a4b75f334f5be6b77409497
godot/tests/shot_logic_parity_test.gd.uid    uid://cshotparity01  (Godot loads the script with no UID warning)
tools/sim-port/shot-intent-probe.mjs         sha256 318f89cac2b541b495424da76971bc78de9611e142d5c0f3e9266fcd301c7953
tools/sim-port/shot-intent-compare.mjs       sha256 426c154e5089543c1722708862b8a25427d4527db6778090e8f40d30d40196b0
tools/sim-port/out/shot-intent-js.txt        sha256 cd49c9b50446d207a50685f27e2f8cdce20ea77b9d88eb825e7f805c5e70eb89
tools/sim-port/out/shot-intent-gd.txt        sha256 7fc04c60271a667f74a3a7fa972bb3661393430e5af2c07f587896406ef8fb54
tools/sim-port/out/shot-intent-compare.txt   the comparator's output (exit 0)
tools/sim-port/out/nonregression-game-slice.txt   the non-regression log
docs/wayfinder/evidence/shot-logic-parity.md      this document
```

---

## 8. What this does NOT prove

- **Not the input layer.** Every scenario feeds the simulation directly with the 22-field
  struct. That the *buttons* produce those fields — `godot/game/input_map.gd` against
  `js/main.js:1047-1094` (`getInput`: X/RB -> `vibora`, Y/RB -> `defensive-lob`, A/RB ->
  `chiquita`, B -> `special`, the X / Y / A double taps, the D-pad tactics) — is anchored in
  the code and covered by the input audits (`godot/tests/input/run_all.gd`), not by this
  trace. A button mapped to the wrong `shotVariant` would not be caught here.
- **Not the human-movement or the co-op/PvP branches.** The scenarios run
  `humanMode == "solo"` (the inlined path inside `updateMatch` / `update_match`) plus one AI
  scenario. The separate functions `queuePaddleHit` / `attemptHumanSwing` / `moveHumanPaddle`
  (`sim.gd:2525` / `:2601` / `:2665`) — the co-op and PvP path — are reached by the existing
  `smash_input_audit`, not by these 35 scenarios.
- **Not the contact geometry.** The bench puts the ball exactly on the paddle and passes
  `forceContact = true`, so `canHit` / `crossedPaddle` / `contactWidth` are bypassed in 18
  of the 35 scenarios (the 17 `bench()` ones plus the AI volley); the other 17 reach the
  stroke through the real contact detection and the queue. Whether a real rally *reaches*
  those contacts at all is the digest lanes' question (`tools/parity/**`,
  `tools/parity-godot/**`), not this one.
- **Not one seed, one athlete, one opponent.** `state.rngState = 12345` (1 for the AI
  volley), athlete `maestro`, opponent `ingegnere` (skill 0.6). The athlete-dependent paths —
  the other athletes' `applySpecial` branches (`pantera` dash, `fiamma` shield) and the
  per-athlete control/power scaling — are outside this trace. The maestro special is proven;
  the others are not.
- **Not bit-exact.** "Identical" is agreement of the `%.6f`-printed values, the same rule as
  the frozen digest harness — not float64 vs float32 bit equality. The two fields compared as
  a named representation difference are in §6.
- **Not the rest of the shot.** Only the first stroke of each scenario is compared: what the
  ball does afterwards (net, glass, bounce, scoring, the receiver locks, the
  `smashStage >= 2` return) belongs to the wall/net/scoring lanes.
- **Not the AI intent set in full.** `chooseComputerShot` is exercised for `volley` only; its
  `lob`, `vibora`, `drive`, `smash-x2/x3` branches and its error rolls are the AI audit
  lane's subject.
- **Not `teamTactic` as an intent modifier** — it does not modify an intent in either engine
  (§3), and the mate-positioning policy it drives is not compared across engines (the
  reference's `tacticalMateTarget` is not exported, so only the port's half is reachable).

---

## 9. Reproduce

```bash
cd /Users/alessiofantini/Documents/steam-circuit-padel-godot
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

node tools/sim-port/shot-intent-probe.mjs > tools/sim-port/out/shot-intent-js.txt
$GODOT --headless --path godot/ --script res://tests/shot_logic_parity_test.gd \
  > tools/sim-port/out/shot-intent-gd-raw.txt
grep '^# trace' tools/sim-port/out/shot-intent-gd-raw.txt > tools/sim-port/out/shot-intent-gd.txt
node tools/sim-port/shot-intent-compare.mjs \
  --js=tools/sim-port/out/shot-intent-js.txt --gd=tools/sim-port/out/shot-intent-gd.txt
# expected: IDENTICAL 35/35 scenarios, 657 field comparisons, tol=0   (exit 0)
```

`flock` and `timeout` do not exist on this Mac: run the binary directly, one heavy engine
process at a time. The probe carries two recon modes that were used to choose the scenarios
and the seeds: `--scan-volley` (which AI seed volleys) and `--scan-smash` (where the x3
downgrade band starts).
