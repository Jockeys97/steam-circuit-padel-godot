# The timing presentation on the court (the ring, the words, the bars)

Slice S14c. The reference draws the timing around the athlete it is about; the port
drew the words in a corner panel and nothing on the field at all. This is what
landed on the court, and how each mark was measured on a rendered frame.

## The gap this closes

| reference | where | port before this slice |
|---|---|---|
| timing ring while charging | `js/render.js:1655-1690` | absent |
| green circle when the perfect window is met | `js/render.js:1679-1688` | absent |
| RT precision bar | `js/render.js:1695-1726` | absent |
| advice word + profile colour | `js/render.js:1730-1750` | **absent anywhere** (a `shotAdvice_*` word had no renderer in `godot/**`) |
| energy bar under the active athlete | `js/render.js:1031-1037` | corner panel only (`hud.gd::_update_energy`) |
| shot verdict over the athlete who hit | `js/render.js:1041-1069` | corner panel only (`hud.gd::_update_feedback`) |

## The reference's geometry and constants

| element | reference | value |
|---|---|---|
| ring centre | `js/render.js:1657` | `p.y - 96*scale` above the feet |
| ring radius / stroke | `:1658`, `:1675` | `20*scale` / `3.4*scale` |
| ring gate | `:1656` | `state.shotCharge > 0.05 && read.active` |
| track / fill arcs | `:1667`, `:1677` | `1.85*PI` and `1.6*PI * clamp(1 - eta/0.55, 0, 1)` |
| ring gradient | `:1669-1673` | `#28d7e8` → `#9ef05b` (0.72) → `#fff36a` (0.86) → `#ff7048`, sampled along the local x |
| window circle | `:1660`, `:1679-1688` | radius `r + 5*scale`, stroke `2*scale`, alpha `0.55 + 0.4*blink`, `blink = 0.5 + 0.5*sin(time*18)` |
| precision bar | `:1697-1700`, `:1709-1717` | `46*scale x 5*scale` at `p.y - 64*scale`, `precision > 0.04`, cyan below `tight > 0.02`, amber/pulsing above (`sin(time*16)`) |
| advice word | `:1730-1745` | `t("shotAdvice_" + advice).toUpperCase()` at `p.y - 132*scale`, box `tw + 22` by 20 px, `#ffd46a` aggressive / `#8fffd0` otherwise, drawn while `!serving && !pointPause` |
| energy bar | `:1031-1037` | `52*scale` at `p.y + 54*scale`, a `2*scale` fill over a `4*scale` track, `#56e8d8` > 0.55 / `#ffd45c` > 0.3 / `#ff6b64` |
| verdict | `:1041-1069` | the grade word `700 14px` with a 5 px `rgba(4,14,32,0.9)` stroke, the mode line `600 9px` 15 px below, at `p.y - 105*scale - (0.78 - life)*18`, alpha `clamp(life/0.28, 0, 1)`, `perfect #74ffba / good #77e7ff / early #ffd45c / late #ff8b70` |
| canvas | `js/render.js:740-750` | 960x620, `scale = 0.58 + depth*0.62`, sprite ~139 px tall |

## The conversion, and what the frame forced

The reference's offsets are canvas pixels of a hand-drawn projection. The port's
court is 10 x 20 m and the captures are 1280x720, so every value was re-expressed
through ONE conversion, `TIMING_M_PER_PX` (metres per screen pixel), whose value is
**measured, not assumed**: in the default framing the 2.45 m pin floats 89 px above
the athlete's feet → **36 px per metre vertically** (`PROBE_FRAME` in the probe
below). Horizontally the same metre is ~55-62 px, which is why a billboarded mark
prints as an ellipse: the ring's circle is 78 px wide and 60 px tall.

Sizes were then set, rendered and measured, twice:

| mark | first pass (faithful) | measured | after | measured |
|---|---|---|---|---|
| ring | r 0.44 m, stroke 0.08 m | **48 x 36 px** ellipse, `diff=996` | r 0.62 m, stroke 0.11 m | **~80 x 70 px**, `diff=1868` |
| advice word | font 30 x pixel 0.0062 = 0.186 m | the glyphs were **~7 px** tall — unreadable, and the word's own colour `#8fffd0` matched **0 px** in the frame | font 15 x pixel 0.0278 = 0.417 m | glyphs **16 px**, `#8fffd0` = **350 px** |
| chip | fixed `92 x 5 px` | a hairline | `(tw + 22)` by `20` px ratios → **198 x 30 px** | `diff=7723` (the panel covers what is under it) |
| energy bar | 0.80 x 0.09 m | 46 x 7 px | 0.80 x 0.13 m | **~41 x 13 px**, `diff=662` |
| precision bar | 0.66 x 0.11 m | — | 0.80 x 0.14 m | track **42 x 6 px**, fill **30 x 5 px** |
| verdict | font 34 x pixel 0.0062 = 0.21 m | — | font 19 x pixel 0.0278 = 0.53 m | word **~125 x 22 px**, `diff=3996` |

The first pass is the same lesson `active-player-marker.md` wrote down: a value
faithful to the 2D numbers printed a 48 px mark and a 7 px word, and neither read.
The enlarged values are the ones shipped.

`billboard_keep_scale` matters here: the marks are billboarded, and without it the
billboard throws the node's scale away (every bar would be one metre wide). The
depth test is OFF on every mark, because the reference paints them after the court
(`js/main.js:1919`) — they lie over the athlete's own body, over the net and over
the glass.

## Frame evidence

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916
```

`shots=5`: the capture plan gained a fifth shot (`timing.png`) whose condition is the
reference's own gate — `shotCharge > 0.5 && read.active` — plus an A/B frame written
from the SAME tick with every timing mark switched off (`timing-off.png`), and
`hud.png` gained the same A/B (`hud-off.png`) so the verdict can be attributed too.
The marker lines the harness prints say where to look:

```
CAPTURE_TIMING ring=(421,551) advice=(414,499) verdict=(855,526) energy=(404,616) \
  ring_visible=true advice_visible=true verdict_visible=false fill=0.509 segments=20 radius_m=0.620 energy=0.974
CAPTURE_VERDICT word= mode= grade= paddle= alpha=0.000 charge=0.508 eta=0.270 in_window=false precision=0.000
CAPTURE_SHOT name=timing.png tick=512 points=0 crossings=4 rally=3
CAPTURE_AB file=timing-off.png timing_hidden=true tick=512

CAPTURE_TIMING ring=(421,551) advice=(413,501) verdict=(421,558) energy=(403,618) \
  ring_visible=false advice_visible=true verdict_visible=true fill=0.853 segments=0 radius_m=0.620 energy=0.900
CAPTURE_VERDICT word=PERFETTO mode=BILANCIATO grade=perfect paddle=player alpha=1.000 charge=0.000 eta=0.081 in_window=false
CAPTURE_SHOT name=hud.png tick=536 points=0 crossings=4 rally=4
CAPTURE_AB file=hud-off.png timing_hidden=true tick=536
```

Note the isolation the two frames give for free: on `timing.png` the ring is drawn
and the verdict is NOT (`ring_visible=true verdict_visible=false`), on `hud.png` the
verdict is drawn and the ring is not. Each mark therefore has a window of its own.

### Per-element counts (ON frame vs the same tick with the marks off)

Colour counts use the reference's own colour for the mark; the `diff` column counts
pixels that differ between the two frames (any channel by more than 8). The snippet
is stdlib-only and reuses `inspect_png.read_png`, like `yellow_map.py` does:

```bash
python3 - <<'PY'
import sys; sys.path.insert(0, "godot/game/tools")
import inspect_png as ip
def px(path, win):
    x0, y0, w, h = (int(v) for v in win.split(","))
    _d, width, _h, ch, data = ip.read_png(path)
    return [tuple(data[(y*width + x)*ch:(y*width + x)*ch + 3]) for y in range(y0, y0+h) for x in range(x0, x0+w)]
def near(path, win, rgb, tol=48):
    return sum(1 for c in px(path, win) if all(abs(c[i]-rgb[i]) < tol for i in range(3)))
def diff(a, b, win):
    return sum(1 for ca, cb in zip(px(a, win), px(b, win)) if max(abs(ca[i]-cb[i]) for i in range(3)) > 8)
RING, ADVICE, ENERGY, VERDICT, PREC = "380,515,90,75", "305,478,200,42", "385,605,70,20", "350,530,150,60", "828,570,55,16"
print("ring",   diff("godot/game/out/timing.png","godot/game/out/timing-off.png",RING),
      near("godot/game/out/timing.png",RING,(158,240,91)), near("godot/game/out/timing-off.png",RING,(158,240,91)))
print("advice", diff("godot/game/out/timing.png","godot/game/out/timing-off.png",ADVICE),
      near("godot/game/out/timing.png",ADVICE,(143,255,208)), near("godot/game/out/timing-off.png",ADVICE,(143,255,208)))
print("energy", diff("godot/game/out/timing.png","godot/game/out/timing-off.png",ENERGY),
      near("godot/game/out/timing.png",ENERGY,(86,232,216)), near("godot/game/out/timing-off.png",ENERGY,(86,232,216)))
print("verdict", diff("godot/game/out/hud.png","godot/game/out/hud-off.png",VERDICT),
      near("godot/game/out/hud.png",VERDICT,(116,255,186)), near("godot/game/out/hud-off.png",VERDICT,(116,255,186)))
print("precision", diff("godot/game/out/probe-precision.png","godot/game/out/probe-precision-off.png",PREC),
      near("godot/game/out/probe-precision.png",PREC,(126,243,255)), near("godot/game/out/probe-precision-off.png",PREC,(126,243,255)))
PY
```

Measured (`diff`, then the mark's own colour ON → OFF):

| element | window | diff | colour | ON | OFF |
|---|---|---|---|---|---|
| ring | `380,515,90,75` | **1868** | `#9ef05b` | **132** | **0** |
| advice word | `305,478,200,42` | **7723** | `#8fffd0` | **350** | **0** |
| energy bar | `385,605,70,20` | **662** | `#56e8d8` | **234** | **9** |
| verdict | `350,530,150,60` | **3996** | `#74ffba` | **725** | **0** |
| precision bar | `828,570,55,16` | **604** | `#7ef3ff` | **138** | **0** |

The 9 surviving `#56e8d8` pixels on the energy window are the arena, not the bar: the
A/B is what says so. The two frames are otherwise identical — four control windows
away from the athlete (`100,200,80,60`, `900,380,80,60`, `600,150,80,60`,
`20,20,120,80`) report **0** differing pixels, so every pixel the counts above
attribute is inside the mark's own window.

### The ring's shape, in the repository's own tool

```bash
python3 godot/game/tools/yellow_map.py godot/game/out/timing.png yellow "380,515,90,75" 4
python3 godot/game/tools/yellow_map.py godot/game/out/timing-off.png yellow "380,515,90,75" 4
```

```
# timing.png      window=380,515,90,75 cell=4 mode=yellow pixels=275
 519 ........##+............
 523 ........++.....++......
 527 ...............##+.....
 531 ...............+##.....
 535 ................+#+....
 539 .................##....
 543 .................++....
 555 .................++....
 559 .................##....
 563 ................+#+....
 567 ...............+##.....
 571 ...............##+.....
 575 ...............++......
# timing-off.png  window=380,515,90,75 cell=4 mode=yellow pixels=76
 515 .......+###............
 519 ........##+............
 523 ........++.............
```

275 against 76, and the 76 that survive are the pin (the blob at rows 515-523, in
both frames): the ring's arc is the shape that changed. The rest of the same ring —
the cyan and green half — is in the same window and is what makes `diff=1868`.

The verdict's word, mapped by its own colour (`#ff8b70`, a LATE verdict, on the
throwaway probe's frame): the glyphs read `R I T A R D A T O` over rows 548-570.

## The precision bar, and why it needs a probe

`precision` is the SPRINT input: `state.shotPrecision = clamp(input.sprint, 0, 1)`
(`sim.gd:2643`), and `scripted_player.gd` — the input the capture harness drives —
never presses it. No `--capture=match` frame can therefore contain the precision bar,
and the ticket's evidence recipe cannot produce one. It was measured with a
throwaway `SceneTree` probe in `res://game/out/` (deleted afterwards, as the ticket
asks), which instantiates the real `Match.tscn`, ticks it with the scripted player
until a shot is charging, and then feeds the same tick path the 22-field input struct
with `sprint = 0.72` for the last six ticks:

```
PROBE_STATE precision tick=499 charge=0.254 eta=0.588 feedback=null
PROBE_RECT precision prec_track visible=true px=x833..876 y575..581 (42x6)
PROBE_RECT precision prec_fill  visible=true px=x834..864 y575..580 (30x5)
CAPTURE_TIMING ring=(859,547) advice=(865,495) energy=(835,612) ... precision=0.720
```

`precision=0.720` of a 0.80 m bar is 0.576 m → 30 px of fill in a 42 px track.

The same probe produced the framing table the metres-per-pixel conversion rests on
(`PROBE_FRAME`, screen y of a point at height `h` over each athlete): near side
0 m → 601 px, 1.90 → 532, 2.45 → 511, 3.40 → 474; far side 0 → 197, 1.90 → 141,
3.40 → 94. Nothing the marks draw leaves the frame at either end of the court.

## The owner's verdict: the texts were twice the reference — they are now the reference's own proportion

The delivered sizes were read at `1280/960` **on top of** the frame's 36 px/m (the
`TIMING_FRAME_SCALE` the previous pass used), which printed the reference's 11 px as
0.417 m. That is twice the reference's own proportion — and on the owner's window the
word's glyphs measured ~40 px, twice what the same constant prints in a 1280×720
capture. The verdict that came back with his screenshot was *"le scritte qui sono troppo
grandi"*: the enlargement the previous lane made for legibility in a capture is the thing
he rejected.

The conversion the TEXTS are in is the reference's own, and the file now says so in one
place: its ring floats `96*scale` px above the feet (`js/render.js:1657`) and this port
anchors that offset at `TIMING_RING_HEIGHT = 1.60 m`, so the reference's canvas reads
**60 px/m** and one reference pixel is **1/60 m** (`TIMING_REF_M_PER_PX`). Every text
size below is its reference pixel value × 1/60 m, and nothing else moved: the ring, the
two bars, the drift and every anchor are the ones the previous lane measured.

| text | reference | delivered | **now** | @1280×720 delivered → now | @1568×882 now |
|---|---|---|---|---|---|
| advice word | `800 ${11 * scale}px`, upper case | 15 px × 1/36 = **0.4167 m** | 11 px × 1/60 = **0.1833 m** | word ink **14 → 7** rows; chip **194×41 → 85×17 px** | word ink **9** rows; chip **105×21 px** |
| advice chip | `tw + 22` by **20 px** | 0.7576 m tall, pad 0.6111 m | **0.3333 m** tall, pad 0.3667 m | (the chip rows above) | (the chip rows above) |
| verdict | `700 14px`, 5 px stroke | 19 px × 1/36 = 0.5278 m, outline 7 | 14 px × 1/60 = **0.2333 m**, outline 5 | word ink **20 → 12** rows | word ink **11** rows (679..690) |
| mode line | `600 9px`, `y + 15` | 12 px × 1/36 = 0.3333 m, drop 0.5556 m | 9 px × 1/60 = **0.1500 m**, drop **0.2500 m** | A/B band **14 → 8** rows | A/B band **7** rows |

The advice's own proportion is the reference's: **11 of the ring's 96 px** (11/96 =
0.1146), which is what the new slice check measures on the live camera.

### Measured on the frames, at both window sizes

The two captures are the ticket's own commands, run on this host (the window manager
renders `--resolution 1568x881` as **1568×882**: `CAPTURE_SAVE … size=1568x882`, so the
"owner's window" column is 1 px taller than the ticket's number):

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # ~3 min, five shots
$GODOT --rendering-driver opengl3 --resolution 1568x881 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # the owner's window
```

The tick and the athlete's screen position are IDENTICAL to the previous capture's
(`CAPTURE_TIMING ring=(421,551) advice=(414,499) …` and `… verdict=(421,558) …` at
1280×720; `advice=(507,611) … verdict=(516,684)` at 1568×882), so the two frames are the
same state and the numbers below compare like with like. The frames of the delivered
build are kept beside the new ones: `godot/game/out/probe-before-*` (1280×720, copied
from the delivered `timing.png`/`hud.png` and their A/Bs before this pass rewrote them),
`probe-1280-*` and `probe-881-*`.

The marker lines the harness prints carry the frame's own numbers (`labels_px`, measured
by unprojecting each word's world height through the live camera):

```
# 1280x720 timing.png  tick=512  … advice=(414,499) … advice_w_m=1.617 advice_h_m=0.183 labels_px=advice:7.3,verdict:0.0,mode:0.0
# 1280x720 hud.png     tick=536  … verdict=(421,558) … advice_w_m=1.967 advice_h_m=0.183 labels_px=advice:7.3,verdict:8.7,mode:5.5
# 1568x882 timing.png  tick=512  … advice=(507,611) … advice_w_m=1.617 advice_h_m=0.183 labels_px=advice:8.9,verdict:0.0,mode:0.0
# 1568x882 hud.png     tick=536  … verdict=(516,684) … advice_w_m=1.967 advice_h_m=0.183 labels_px=advice:8.9,verdict:10.6,mode:6.7
```

and the pixels themselves, before and after, from the A/B pairs. The snippet is the one
that produced the log under it (stdlib, the repository's own decoder; `probe-before-*`
are the delivered frames, `probe-1280-*` and `probe-881-*` the new ones):

```bash
python3 - <<'PY'
import sys; sys.path.insert(0, "godot/game/tools")
import inspect_png as ip

def load(p):
    _d, w, h, ch, px = ip.read_png(p); return w, h, ch, px

def pts(w, h, ch, px, rect):
    x0, y0, rw, rh = rect
    return [(x, y) for y in range(y0, min(y0 + rh, h)) for x in range(x0, min(x0 + rw, w))]

def box(ps):
    if not ps: return "(none)"
    xs = [p[0] for p in ps]; ys = [p[1] for p in ps]
    return "(%d,%d %dx%d)" % (min(xs), min(ys), max(xs)-min(xs)+1, max(ys)-min(ys)+1)

def mark(tag, on, off, rect, rgb, tol=64):
    w, h, ch, a = load(on); _w2, _h2, _c2, b = load(off)
    d = [(x, y) for (x, y) in pts(w, h, ch, a, rect)
         if max(abs(a[(y*w+x)*ch+k] - b[(y*w+x)*ch+k]) for k in range(3)) > 8]
    x0, y0, x1, y1 = (min(p[0] for p in d), min(p[1] for p in d),
                      max(p[0] for p in d), max(p[1] for p in d))
    ink = [(x, y) for (x, y) in pts(w, h, ch, a, (x0+3, y0+3, x1-x0-5, y1-y0-5))
           if all(abs(a[(y*w+x)*ch+k]-rgb[k]) <= tol for k in range(3))]
    rows = sorted(set(p[1] for p in ink))
    print("%-20s chip=%s diff=%d ink=%s rows=%d (%d..%d)" % (
        tag, box(d), len(d), box(ink), len(rows), rows[0], rows[-1]))

O = "godot/game/out"
A = (0x8f, 0xff, 0xd0)   # advice, #8fffd0
V = (0x74, 0xff, 0xba)   # verdict, #74ffba
mark("advice before 1280", O+"/probe-before-timing.png", O+"/probe-before-timing-off.png", (310,474,210,48), A)
mark("advice after  1280", O+"/probe-1280-timing.png", O+"/probe-1280-timing-off.png", (310,474,210,48), A)
mark("advice after  1568", O+"/probe-881-timing.png", O+"/probe-881-timing-off.png", (380,581,257,59), A)
mark("verdict before 1280", O+"/probe-before-hud.png", O+"/probe-before-hud-off.png", (345,535,160,40), V)
mark("verdict after  1280", O+"/probe-1280-hud.png", O+"/probe-1280-hud-off.png", (345,535,160,40), V)
mark("verdict after  1568", O+"/probe-881-hud.png", O+"/probe-881-hud-off.png", (423,655,196,49), V)
PY
```

```
advice before 1280   chip=(317,478 194x44) diff=8010 ink=(342,493 145x14) rows=14 (493..506)
advice after  1280   chip=(372,490 85x32) diff=1530 ink=(382,495 60x24) rows=10 (495..518)
advice after  1568   chip=(455,600 105x40) diff=2343 ink=(468,607 79x30) rows=13 (607..636)
verdict before 1280  chip=(355,546 133x29) diff=3293 ink=(359,549 125x20) rows=20 (549..568)
verdict after  1280  chip=(392,542 65x33) diff=935 ink=(395,551 56x12) rows=12 (551..562)
verdict after  1568  chip=(480,676 72x23) diff=1122 ink=(483,679 66x12) rows=11 (679..690)
```

The `rows=` figures are the mark's colour found inside the difference's own box, and the
window — chosen so that it contains the mark at both the old and the new size — also
contains the ring's arc below the chip (the ring's top is at y≈514 on the 1280×720 frame,
y≈630 at 1568×882), which is why the ink boxes run past the word. With the window tight
around the chip alone, above the ring — `368,482,92,27` at 1280×720 and `450,595,115,32`
at 1568×882 — the chip measures **85×17 px** and **105×21 px** and the word's ink rows are
**7** (495..501) and **9** (607..615); the delivered chip, in the same kind of window
(`310,474,210,48`, the ring's arc below it), measures **194×41 px** — rows 478..518, each
194 px wide — with **14** ink rows (493..506). Ratios 1.24/1.24 against the frame's own
1.225: the chip is a world object at the reference's proportion, so it grows with the
frame exactly as the frame's own px/m does.

### The window law, and what "not growing with the window" can mean

Measured on the same state at the two sizes, the three texts scale with the frame by
exactly the frame's height ratio (8.9/7.2 = 1.236, 10.6/8.7 = 1.218, 6.7/5.5 = 1.218
against the frames' 1.225), and so does everything else on the court: the ring's ellipse
measures **81×74 px** at 1280×720 and **102×91 px** at 1568×882, the energy bar's A/B
diff 603 → 973 px. That is the reference's own behaviour: its 960×620 canvas is scaled to
the window (`ctx.scale(canvas.width / 960, canvas.height / 620)`, `js/render.js:1627`,
and in immersive mode `.canvas-wrap canvas { object-fit: contain }`, `styles.css:2836-2843`),
so its word is 11/960 of the canvas at every window — the PROPORTION is what is held, not
a fixed number of screen pixels. A word fixed in screen pixels against a ring that grows
with the frame would be 6.6 px against a 70 px ring at 1568×882 instead of 8.9 against
70: a ratio of 0.094 where the reference's own is 0.1146 (−18% below the ratio this
ticket requires in the same breath). It was measured, priced and not shipped; the budget
of the choice is the 60 px/m conversion above, and the check pins the delivered side of
it.

### Legibility, against the frames themselves

The word at 1280×720 reads: on `timing.png` the chip carries `DRIVE SICURO` in the
profile's `#8fffd0` and the letters are legible at ~50-60% of the chip's height (a
vision pass reads the word without being told it, and the glyph ink is 65×8 px inside a
85×17 px chip, 7 rows of it). At 1568×882 it is 23% larger in pixels (9 rows of ink), so
it does not become harder to read where the owner plays;
what changes there is the ring and the court, which grow with it. The ticket's own
failure clause (unreadable at the owner's window ⇒ present the two candidates) therefore
does not trigger: the reference's proportion reads at both sizes.

If the owner still wants more, the candidates are, in the same metres (each one is a
single constant in `match_controller.gd`): **11/60 m (delivered, the reference's own
proportion, 11 of the ring's 96)**, or 1.5× that (0.275 m, ~15 px of ink at 1568×882);
the 2.27× (0.417 m) he rejected is what the before frames show. The call is his, not this
lane's — and it is now a one-line change with a measurement attached.

### What this does NOT prove

- **It does not prove the texts are the same size as the 2D game on the owner's physical
  screen.** The reference's canvas is a 960×620 drawing space shown at whatever size its
  window gives it; the port's court is a 10×20 m world on a fixed camera. What is equal
  is the ratio between the word and the mark it is drawn against (11 of the ring's 96 px)
  and the fact that both scale with the frame.
- **It does not measure the mode line as a box.** The mode line is drawn over the
  athlete's white body; its A/B band is read by rows (14 → 8 at 1280×720, 7 at 1568×882)
  and its anchor height comes from the frame's camera, not from a colour match.
- **It does not touch the ring, the two bars or the verdict's drift** — their numbers in
  the section above still stand (`diff=1635` for the ring and `603` for the energy bar on
  the new 1280×720 frame, against `1868` and `662` on the delivered one: same mark, the
  count differs only in the pixels the background contributes).
- **It does not prove the A/B pairs differ ONLY at the marks.** One control window is not
  zero on this run: 20 px at `(645,206)` on the 1280×720 timing pair (21 px at the same
  relative position at 1568×882, 2 px on the delivered capture's run, 0 in the hud pair)
  — a character in the arena whose pose follows the wall clock, drawn between two frames
  a moment apart. It is not a timing mark: nothing is drawn there, and the mark windows
  above carry the shapes.
- **It does not re-measure the precision bar**: no `--capture=match` frame can contain it
  (see the probe section above), and this pass did not repeat the probe.

## Tests

`godot/tests/game_slice_test.gd::_timing_presentation` (registered in `SECTIONS`,
appended last so no existing section's index moves; 36 checks). It drives the real
## The owner's verdict: the texts were twice the reference — they are now the reference's own proportion

The delivered sizes were read at `1280/960` **on top of** the frame's 36 px/m (the
`TIMING_FRAME_SCALE` the previous pass used), which printed the reference's 11 px as
0.417 m. That is twice the reference's own proportion — and on the owner's window the
word's glyphs measured ~40 px, twice what the same constant prints in a 1280×720
capture. The verdict that came back with his screenshot was *"le scritte qui sono troppo
grandi"*: the enlargement the previous lane made for legibility in a capture is the thing
he rejected.

The conversion the TEXTS are in is the reference's own, and the file now says so in one
place: its ring floats `96*scale` px above the feet (`js/render.js:1657`) and this port
anchors that offset at `TIMING_RING_HEIGHT = 1.60 m`, so the reference's canvas reads
**60 px/m** and one reference pixel is **1/60 m** (`TIMING_REF_M_PER_PX`). Every text
size below is its reference pixel value × 1/60 m, and nothing else moved: the ring, the
two bars, the drift and every anchor are the ones the previous lane measured.

| text | reference | delivered | **now** | @1280×720 delivered → now | @1568×882 now |
|---|---|---|---|---|---|
| advice word | `800 ${11 * scale}px`, upper case | 15 px × 1/36 = **0.4167 m** | 11 px × 1/60 = **0.1833 m** | word ink **14 → 7** rows; chip **194×41 → 85×17 px** | word ink **9** rows; chip **105×21 px** |
| advice chip | `tw + 22` by **20 px** | 0.7576 m tall, pad 0.6111 m | **0.3333 m** tall, pad 0.3667 m | (the chip rows above) | (the chip rows above) |
| verdict | `700 14px`, 5 px stroke | 19 px × 1/36 = 0.5278 m, outline 7 | 14 px × 1/60 = **0.2333 m**, outline 5 | word ink **20 → 12** rows | word ink **11** rows (679..690) |
| mode line | `600 9px`, `y + 15` | 12 px × 1/36 = 0.3333 m, drop 0.5556 m | 9 px × 1/60 = **0.1500 m**, drop **0.2500 m** | A/B band **14 → 8** rows | A/B band **7** rows |

The advice's own proportion is the reference's: **11 of the ring's 96 px** (11/96 =
0.1146), which is what the new slice check measures on the live camera.

### Measured on the frames, at both window sizes

The two captures are the ticket's own commands, run on this host (the window manager
renders `--resolution 1568x881` as **1568×882**: `CAPTURE_SAVE … size=1568x882`, so the
"owner's window" column is 1 px taller than the ticket's number):

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # ~3 min, five shots
$GODOT --rendering-driver opengl3 --resolution 1568x881 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # the owner's window
```

The tick and the athlete's screen position are IDENTICAL to the previous capture's
(`CAPTURE_TIMING ring=(421,551) advice=(414,499) …` and `… verdict=(421,558) …` at
1280×720; `advice=(507,611) … verdict=(516,684)` at 1568×882), so the two frames are the
same state and the numbers below compare like with like. The frames of the delivered
build are kept beside the new ones: `godot/game/out/probe-before-*` (1280×720, copied
from the delivered `timing.png`/`hud.png` and their A/Bs before this pass rewrote them),
`probe-1280-*` and `probe-881-*`.

The marker lines the harness prints carry the frame's own numbers (`labels_px`, measured
by unprojecting each word's world height through the live camera):

```
# 1280x720 timing.png  tick=512  … advice=(414,499) … advice_w_m=1.617 advice_h_m=0.183 labels_px=advice:7.3,verdict:0.0,mode:0.0
# 1280x720 hud.png     tick=536  … verdict=(421,558) … advice_w_m=1.967 advice_h_m=0.183 labels_px=advice:7.3,verdict:8.7,mode:5.5
# 1568x882 timing.png  tick=512  … advice=(507,611) … advice_w_m=1.617 advice_h_m=0.183 labels_px=advice:8.9,verdict:0.0,mode:0.0
# 1568x882 hud.png     tick=536  … verdict=(516,684) … advice_w_m=1.967 advice_h_m=0.183 labels_px=advice:8.9,verdict:10.6,mode:6.7
```

and the pixels themselves, before and after, from the A/B pairs. The snippet is the one
that produced the log under it (stdlib, the repository's own decoder; `probe-before-*`
are the delivered frames, `probe-1280-*` and `probe-881-*` the new ones):

```bash
python3 - <<'PY'
import sys; sys.path.insert(0, "godot/game/tools")
import inspect_png as ip

def load(p):
    _d, w, h, ch, px = ip.read_png(p); return w, h, ch, px

def pts(w, h, ch, px, rect):
    x0, y0, rw, rh = rect
    return [(x, y) for y in range(y0, min(y0 + rh, h)) for x in range(x0, min(x0 + rw, w))]

def box(ps):
    if not ps: return "(none)"
    xs = [p[0] for p in ps]; ys = [p[1] for p in ps]
    return "(%d,%d %dx%d)" % (min(xs), min(ys), max(xs)-min(xs)+1, max(ys)-min(ys)+1)

def mark(tag, on, off, rect, rgb, tol=64):
    w, h, ch, a = load(on); _w2, _h2, _c2, b = load(off)
    d = [(x, y) for (x, y) in pts(w, h, ch, a, rect)
         if max(abs(a[(y*w+x)*ch+k] - b[(y*w+x)*ch+k]) for k in range(3)) > 8]
    x0, y0, x1, y1 = (min(p[0] for p in d), min(p[1] for p in d),
                      max(p[0] for p in d), max(p[1] for p in d))
    ink = [(x, y) for (x, y) in pts(w, h, ch, a, (x0+3, y0+3, x1-x0-5, y1-y0-5))
           if all(abs(a[(y*w+x)*ch+k]-rgb[k]) <= tol for k in range(3))]
    rows = sorted(set(p[1] for p in ink))
    print("%-20s chip=%s diff=%d ink=%s rows=%d (%d..%d)" % (
        tag, box(d), len(d), box(ink), len(rows), rows[0], rows[-1]))

O = "godot/game/out"
A = (0x8f, 0xff, 0xd0)   # advice, #8fffd0
V = (0x74, 0xff, 0xba)   # verdict, #74ffba
mark("advice before 1280", O+"/probe-before-timing.png", O+"/probe-before-timing-off.png", (310,474,210,48), A)
mark("advice after  1280", O+"/probe-1280-timing.png", O+"/probe-1280-timing-off.png", (310,474,210,48), A)
mark("advice after  1568", O+"/probe-881-timing.png", O+"/probe-881-timing-off.png", (380,581,257,59), A)
mark("verdict before 1280", O+"/probe-before-hud.png", O+"/probe-before-hud-off.png", (345,535,160,40), V)
mark("verdict after  1280", O+"/probe-1280-hud.png", O+"/probe-1280-hud-off.png", (345,535,160,40), V)
mark("verdict after  1568", O+"/probe-881-hud.png", O+"/probe-881-hud-off.png", (423,655,196,49), V)
PY
```

```
advice before 1280   chip=(317,478 194x44) diff=8010 ink=(342,493 145x14) rows=14 (493..506)
advice after  1280   chip=(372,490 85x32) diff=1530 ink=(382,495 60x24) rows=10 (495..518)
advice after  1568   chip=(455,600 105x40) diff=2343 ink=(468,607 79x30) rows=13 (607..636)
verdict before 1280  chip=(355,546 133x29) diff=3293 ink=(359,549 125x20) rows=20 (549..568)
verdict after  1280  chip=(392,542 65x33) diff=935 ink=(395,551 56x12) rows=12 (551..562)
verdict after  1568  chip=(480,676 72x23) diff=1122 ink=(483,679 66x12) rows=11 (679..690)
```

The `rows=` figures are the mark's colour found inside the difference's own box, and the
window — chosen so that it contains the mark at both the old and the new size — also
contains the ring's arc below the chip (the ring's top is at y≈514 on the 1280×720 frame,
y≈630 at 1568×882), which is why the ink boxes run past the word. With the window tight
around the chip alone, above the ring — `368,482,92,27` at 1280×720 and `450,595,115,32`
at 1568×882 — the chip measures **85×17 px** and **105×21 px** and the word's ink rows are
**7** (495..501) and **9** (607..615); the delivered chip, in the same kind of window
(`310,474,210,48`, the ring's arc below it), measures **194×41 px** — rows 478..518, each
194 px wide — with **14** ink rows (493..506). Ratios 1.24/1.24 against the frame's own
1.225: the chip is a world object at the reference's proportion, so it grows with the
frame exactly as the frame's own px/m does.

### The window law, and what "not growing with the window" can mean

Measured on the same state at the two sizes, the three texts scale with the frame by
exactly the frame's height ratio (8.9/7.2 = 1.236, 10.6/8.7 = 1.218, 6.7/5.5 = 1.218
against the frames' 1.225), and so does everything else on the court: the ring's ellipse
measures **81×74 px** at 1280×720 and **102×91 px** at 1568×882, the energy bar's A/B
diff 603 → 973 px. That is the reference's own behaviour: its 960×620 canvas is scaled to
the window (`ctx.scale(canvas.width / 960, canvas.height / 620)`, `js/render.js:1627`,
and in immersive mode `.canvas-wrap canvas { object-fit: contain }`, `styles.css:2836-2843`),
so its word is 11/960 of the canvas at every window — the PROPORTION is what is held, not
a fixed number of screen pixels. A word fixed in screen pixels against a ring that grows
with the frame would be 6.6 px against a 70 px ring at 1568×882 instead of 8.9 against
70: a ratio of 0.094 where the reference's own is 0.1146 (−18% below the ratio this
ticket requires in the same breath). It was measured, priced and not shipped; the budget
of the choice is the 60 px/m conversion above, and the check pins the delivered side of
it.

### Legibility, against the frames themselves

The word at 1280×720 reads: on `timing.png` the chip carries `DRIVE SICURO` in the
profile's `#8fffd0` and the letters are legible at ~50-60% of the chip's height (a
vision pass reads the word without being told it, and the glyph ink is 65×8 px inside a
85×17 px chip, 7 rows of it). At 1568×882 it is 23% larger in pixels (9 rows of ink), so
it does not become harder to read where the owner plays;
what changes there is the ring and the court, which grow with it. The ticket's own
failure clause (unreadable at the owner's window ⇒ present the two candidates) therefore
does not trigger: the reference's proportion reads at both sizes.

If the owner still wants more, the candidates are, in the same metres (each one is a
single constant in `match_controller.gd`): **11/60 m (delivered, the reference's own
proportion, 11 of the ring's 96)**, or 1.5× that (0.275 m, ~15 px of ink at 1568×882);
the 2.27× (0.417 m) he rejected is what the before frames show. The call is his, not this
lane's — and it is now a one-line change with a measurement attached.

### What this does NOT prove

- **It does not prove the texts are the same size as the 2D game on the owner's physical
  screen.** The reference's canvas is a 960×620 drawing space shown at whatever size its
  window gives it; the port's court is a 10×20 m world on a fixed camera. What is equal
  is the ratio between the word and the mark it is drawn against (11 of the ring's 96 px)
  and the fact that both scale with the frame.
- **It does not measure the mode line as a box.** The mode line is drawn over the
  athlete's white body; its A/B band is read by rows (14 → 8 at 1280×720, 7 at 1568×882)
  and its anchor height comes from the frame's camera, not from a colour match.
- **It does not touch the ring, the two bars or the verdict's drift** — their numbers in
  the section above still stand (`diff=1635` for the ring and `603` for the energy bar on
  the new 1280×720 frame, against `1868` and `662` on the delivered one: same mark, the
  count differs only in the pixels the background contributes).
- **It does not prove the A/B pairs differ ONLY at the marks.** One control window is not
  zero on this run: 20 px at `(645,206)` on the 1280×720 timing pair (21 px at the same
  relative position at 1568×882, 2 px on the delivered capture's run, 0 in the hud pair)
  — a character in the arena whose pose follows the wall clock, drawn between two frames
  a moment apart. It is not a timing mark: nothing is drawn there, and the mark windows
  above carry the shapes.
- **It does not re-measure the precision bar**: no `--capture=match` frame can contain it
  (see the probe section above), and this pass did not repeat the probe.

## Tests

`godot/tests/game_slice_test.gd::_timing_presentation` (registered in `SECTIONS`,
appended last so no existing section's index moves; **37** checks now — the 36 the
presentation pass wrote plus the proportion check below). It drives the real
scene to a charging state and asserts: every mark exists; the ring is invisible when
nothing charges and visible while charging; its fill is `1 - eta/0.55` and the drawn
arc's mesh is rebuilt and larger as `eta` falls; an `eta` past 0.55 leaves it empty;
the precision bar follows `precision > 0.04` and the armed/unarmed colours; the
advice word is `Locale.t("shotAdvice_<advice>")` uppercased and never an id; the
profile colours are the reference's two; the energy bar's fill is
`rallyEnergy.player` of the bar with the reference's three bands, sits under the
active athlete and follows a switch to the partner, as the zone and the pin do; and
the verdict is drawn over the athlete in `shotFeedback.paddleKey` (not the controlled
one), takes the word from the grade through the locale layer, fades with
`life / 0.28` and drifts upwards as it fades.

The label-scale pass added ONE check, at the end of the same section: with the frame set
to the owner's window (`1568x881`) it unprojects the advice's world height and the ring's
own span from the feet through the live camera and requires the word to be the
reference's 11 of the ring's 96 px — in metres within 2%, and on the frame's own pixels
within 15% (the two anchors sit at different heights, where this camera's px/m differs by
10.5%: measured, not assumed). It fails on the delivered 0.417 m, and it fails on a
window-compensated or `fixed_size` word at this window, which is the point. The section
prints its measurement on every run:

```
# TIMING_LABELS frame=(1568.0, 881.0) word_h=0.1833 m reference_h=0.1833 m word=8.87 px ring_span=70.04 px ratio=0.1266 want=0.1146
```

```
before: 288/289 checks (1 red: `padel.pck`, the clone artifact)
after:  324/325 checks (same 1 red) — the new section is 36 of them, all green
        # sections ran 23/23
now:    325/326 checks (same 1 red: `padel.pck` — the clone artifact, not fixed)
        — the section is 37; the label-scale pass added exactly one
```

The other suites this lane could disturb re-ran unmoved: `godot/tests/audits/run_all.gd`
`PASS 10/10` (`checks=221`), `godot/tests/input/run_all.gd` `PASS 5/5` (`checks=393`),
the smoke harness `PASS 8/8`.
now:    325/326 checks (same 1 red: `padel.pck` — the clone artifact, not fixed)
        — the section is 37; the label-scale pass added exactly one
```

The other suites this lane could disturb re-ran unmoved: `godot/tests/audits/run_all.gd`
`PASS 10/10` (`checks=221`), `godot/tests/input/run_all.gd` `PASS 5/5` (`checks=393`), the
smoke harness `PASS 8/8`. The label-scale pass re-ran all three: `10/10` (`checks=221`),
`5/5` (`checks=393` — the input suite reads none of the files this pass touched), `8/8`.

## Files

- `godot/game/match_controller.gd` — the marks: `_build_timing_marks`, `_sync_timing`,
  `_sync_verdict`, `timing_report()`, the geometry constants, the `CAPTURE_TIMING` /
  `CAPTURE_VERDICT` marker lines, the `timing.png` shot and the A/B frames.
  The label-scale pass changed only the SIZES of the three texts and of the chip:
  `TIMING_REF_M_PER_PX` (1/60 m, the reference's own conversion), `TIMING_ADVICE_PX` 15 →
  11, `TIMING_VERDICT_PX` 19 → 14, `TIMING_VERDICT_MODE_PX` 12 → 9, the verdict's outline
  7 → 5, `TIMING_VERDICT_MODE_DROP` 0.5556 → 0.25 m, and the chip's floor; plus
  `_timing_labels_px()` and the `labels_px=` / `advice_h_m=` fields on the marker line.
- `godot/game/hud.gd` — the text and colour rules, in one place: `advice_word`,
  `advice_color`, `advice_of`, `precision_color`, `field_energy_color`,
  `field_grade_color` (`FIELD_GRADE_COLORS`, the reference's second palette).
- `godot/tests/game_slice_test.gd` — the `_timing_presentation` section (37 checks).
- `godot/game/out/{timing,timing-off,hud,hud-off}.png` — the captures and their A/Bs
  (gitignored), plus the deleted probe's `probe-*.png`.
  The label-scale pass changed only the SIZES of the three texts and of the chip:
  `TIMING_REF_M_PER_PX` (1/60 m, the reference's own conversion), `TIMING_ADVICE_PX` 15 →
  11, `TIMING_VERDICT_PX` 19 → 14, `TIMING_VERDICT_MODE_PX` 12 → 9, the verdict's outline
  7 → 5, `TIMING_VERDICT_MODE_DROP` 0.5556 → 0.25 m, and the chip's floor; plus
  `_timing_labels_px()` and the `labels_px=` / `advice_h_m=` fields on the marker line.
- `godot/game/hud.gd` — the text and colour rules, in one place: `advice_word`,
  `advice_color`, `advice_of`, `precision_color`, `field_energy_color`,
  `field_grade_color` (`FIELD_GRADE_COLORS`, the reference's second palette).
- `godot/tests/game_slice_test.gd` — the `_timing_presentation` section (37 checks).
- `godot/game/out/{timing,timing-off,hud,hud-off}.png` — the captures and their A/Bs
  (gitignored), plus the deleted probe's `probe-*.png`. The label-scale pass keeps four
  generations side by side: `probe-before-*` (the delivered sizes at 1280×720, copied
  before the new capture overwrote them), `probe-1280-*` (the new sizes at 1280×720) and
  `probe-881-*` (the new sizes at 1568×882).

## What is still not on the field

- The charge power bar (`70*scale x 7*scale` under the feet, `js/render.js:981-1029`)
  and the smash status line (`js/render.js:1014-1023`) — different elements from the
  RT precision bar, unported.
- The tight-angle word above an armed precision bar (`t("hudTightAngle")` = `ANGOLO`,
  `js/render.js:1718-1724`) — unported.
- The in-window circle's translucent FILL (`js/render.js:1681-1682`, a ~1.3 m green
  disc at alpha 0.12-0.22 over the athlete) — only the circle's stroke is ported.
- `roundRect` corners and the cyan rim of the chip and of the two bars: the port's
  `no_depth_test` quads have no rounded corners and the rim is the track's own
  slightly larger rectangle.
- The team-geometry link (`js/render.js:926-947`) — a known gap from the previous
  lane, still open.
- The HUD's corner panel still shows the energy bar and `state.shotFeedback`: the
  field marks are additions, nothing was removed from the panel.

## What this ticket gets wrong

1. **The advice word was never drawn.** The "port today" cell points at
   `hud.gd:513-544` ("text only, corner panel"), but no `shotAdvice_*` string was
   rendered anywhere in `godot/**` — the key exists only in
   `src/locale/locale_data.gd`. The corner panel draws `shotFeedback` (the grade),
   which is a different element.
2. **The port's energy bar is not a port of the reference's.** The reference has no
   energy bar in its HUD at all: `js/main.js:1916` hands `state.rallyEnergy.player` to
   `drawActiveIndicator`, which draws it on the court. The panel bar is the port's own
   addition, and its (0.6 / 0.3) bands and cyan/amber/red are its own; the reference's
   field bar uses (0.55 / 0.3) and `#56e8d8`/`#ffd45c`/`#ff6b64`. The two rules
   coexist, each in `hud.gd`, and nothing was silently unified.
3. **The call site is `js/main.js:1919` for `drawTimingHud` and `:1916` for the energy
   bar; `:1850` is `drawHitZone`.**
4. **The ticket's evidence recipe cannot show the precision bar** (see above), and it
   asks for a frame measurement of the ring while the capture plan had no shot that
   could contain one: a fifth shot had to be added. `godot/game/run.sh`'s echo line
   still lists the four original names (that file is outside this lane's allowlist).
5. The ticket's claim that a marker under ~20 px "is not delivered" is what the sizes
   above were chosen against, but two of the reference's own values (the 5 px bar and
   the 7 px word) pass a literal pixel count and still do not read — the rule that
   actually held was the measured one: a 48 px ring and a 7 px word were both
   rewritten.

### The label-scale ticket (`timing-label-scale.md`), which this section answers

6. **"Make their screen size independent of the window" cannot be done without breaking
   the proportion the same ticket asks for in the same sentence.** The labels are world
   objects on a fixed camera: holding their SCREEN pixels while the ring, the athlete and
   the court still scale with the frame (measured: the ring's ellipse 81×74 px at
   1280×720 → 102×91 px at 1568×882) prints a word that is 0.094 of the ring instead of
   the reference's 0.1146. The reference's own canvas is scaled to its window
   (`js/render.js:1627`, `styles.css:2836-2843`), so its proportion, not a pixel count, is
   what a window can hold. Delivered: the proportion, at any window — and it is the
   window-scaled alternative that was *measured* and priced here, not silently dropped.
7. **The ticket's `≈6.6 px at 1280×720` is the word at the 36 px/m rate measured over the
   pin's 0→2.45 m span; the word itself sits at 2.95 m**, where this camera's conversion
   is larger. Measured on the frames: the chip prints 85×17 px and the glyph ink 7 rows
   at 1280×720 (the frame's own camera reports 7.3 px for the word's world height), and
   105×21 px / 9 rows at 1568×882.
8. **Its own anchors disagree with each other.** The metres row says 11/60 m = 11/96 of
   the ring's 1.60 m (which is what was delivered, and what the port's existing
   `TIMING_RING_HEIGHT` already anchored); the Inputs/outputs line says "advice ≈ 11/96 of
   the athlete's on-screen height", and the reference's athlete sprite is ~139 px against
   the ring's 96 px — ~1.3× more. The two readings differ by the athlete/ring height
   ratio; the delivered one is the ring's, the only one pinned by a port constant.
9. **`--resolution 1568x881` is not what this host renders.** Both captures at the
   owner's size came out **1568×882** (`CAPTURE_SAVE … size=1568x882`): the window
   manager takes one more row than asked. Every 1568 number in this file is from those
   frames.
10. **The factor the delivered sizes were built on does not exist.** `TIMING_FRAME_SCALE`
   (1280/960) is the reference's canvas scale *in a 1280-wide capture*, not a world
   conversion; applying it and then 36 px/m counted the frame's canvas twice. The
   reference's own conversion is the ring's: 96 px = `TIMING_RING_HEIGHT` = 1.60 m, i.e.
   60 px/m — 0.6 frame pixels per reference pixel at 1280×720, not 1.33. The constant is
   gone; the comment where it lived states the two conversions apart.
