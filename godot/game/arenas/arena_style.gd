## arena_style.gd — the nine arenas' presentation data, and nothing else.
##
## WHERE THIS COMES FROM. Two frozen sources, no invention:
##
##  1. `js/data.js:560-648` (`ARENAS`) is the authority on *identity*: id, name,
##     desc, `image`, `wallBounce`, `floorGrip`, `unlock` and `palette`
##     (`floor` / `accent` / `gear`). The port reads that table through
##     `src/sim/frozen.gd.arenas()` (its mechanical serialisation), never a copy
##     — see `arena_library.gd::info()`. Nothing in this file re-states a
##     `wallBounce` or a `floorGrip`.
##
##  2. `js/render.js` is the authority on *treatment*: the browser paints each
##     arena's backdrop from its own code, and those colours are copied here
##     verbatim (hex for hex):
##
##       - `drawFantasyArenaBackdrop` (js/render.js:500-558) — the four
##         `themes` entries (`tempesta`, `abissale`, `caldera`, `orrery`): a
##         top/bottom gradient plus a `glow` colour, with the arena artwork
##         composited under a veil.
##       - `drawLocomotiveDepotBackdrop` (js/render.js:260-340) and
##         `drawClockworkFactoryBackdrop` — the two family backdrops, their sky
##         stops and their prop colours.
##       - the default open arena's sky gradient and body colours.
##       - `exteriorFloor` (js/render.js:760-767) — the ground beyond the cage,
##         per scene. Used here as the apron strip at the foot of the backdrop.
##       - `drawFantasyArenaProps` (js/render.js:560-...) — each fantasy arena's
##         own scenery objects, with their own colours.
##
## WHAT IS A PORT CHOICE, NOT A COPY (recorded so nobody reads it as fidelity):
##
##  - `cattedrale` and `forgia` have no backdrop code of their own in the
##    reference: `drawArena` maps them onto the `locomotive` / `clockwork`
##    family (`js/render.js:697-701`) and paints that family's backdrop with
##    fixed colours — the family backdrops are palette-blind. Their `image`
##    field points at another arena's file too. Here the family's props are
##    tinted from the arena's own palette, so the nine arenas stay
##    distinguishable in a frame. That tinting is the port's, and it is the only
##    place this file departs from a copied value.
##  - `props` positions are in METRES in the scene `arena_scenery.gd` builds and
##    are derived from the reference's own object positions (its canvas x/y),
##    rescaled to the proscenium band the reference's `clipArenaScenery` defines
##    (`js/render.js:481-499`, `ctx.rect(0, 0, 960, 96)`): the upper band above
##    the rear glass plus the two wedges outside the cage. See
##    `arena_scenery.gd` for why every object ends up in the band.
extends RefCounted

## Where the reference's own painted arena artwork is copied to, when it exists
## on disk. `js/data.js` points at `assets/arenas/*.webp` (1672x941, the
## reference's own files); four of the nine arenas have artwork of their own —
## the other five either have none or share another arena's file. An empty
## `artwork` means "no artwork for this arena", and the backdrop is the
## gradient only.
const ARTWORK_DIR := "res://game/arenas/art/"

## One entry per row of `js/data.js`'s `ARENAS`, keyed by the frozen id.
##
##   family  — which of the reference's own backdrop functions draws the arena
##             (`drawArena`, js/render.js:694-734): "open" is the default
##             outdoor scene, "locomotive" and "clockwork" are the two depot
##             families, "fantasy" is the group with `themes` entries.
##   sky     — the gradient stops, top (0.0) to bottom (1.0), exactly the
##             reference's `addColorStop` values.
##   apron   — `exteriorFloor` for this scene: the ground beyond the cage.
##   glow    — the reference's accent light for this arena (its `theme.glow`,
##             or the family's own lamp/steam colour).
##   artwork — the reference's own painted file for this arena, or "".
##   props   — scenery objects, in metres, standing on the ground behind the
##             rear glass. `x` is across the court, `y` is a centre height for
##             objects that hang, `h`/`r` are size, `tint` is a palette key
##             ("accent", "gear", "floor") or a literal hex.
const STYLES := {
	"officina": {
		# js/render.js:709-733 (the default open scene) + palette.
		"family": "open",
		"sky": [["0.00", "#51c6f4"], ["0.48", "#c8f1ff"], ["0.49", "#f5a277"], ["1.00", "#e57958"]],
		"apron": "#e78c68",
		"glow": "#7fd4ff",
		"artwork": "",
		"props": [
			{"kind": "floodlight", "x": -7.6, "h": 2.10},
			{"kind": "floodlight", "x": 7.4, "h": 2.10},
			{"kind": "cloud", "x": -2.8, "y": 1.70, "r": 0.42},
			{"kind": "cloud", "x": 3.1, "y": 1.80, "r": 0.34},
			{"kind": "tree", "x": -10.6, "h": 1.9},
			{"kind": "tree", "x": 10.7, "h": 1.7},
			{"kind": "gearring", "x": -4.6, "y": 1.35, "r": 0.55, "tint": "gear"},
			{"kind": "gearring", "x": 4.8, "y": 1.45, "r": 0.5, "tint": "gear"},
			{"kind": "signal", "x": -12.0, "h": 1.6, "tint": "accent"},
		],
	},
	"locomotive": {
		# drawLocomotiveDepotBackdrop (js/render.js:260-310).
		"family": "locomotive",
		"sky": [["0.00", "#071526"], ["0.46", "#1b4d5d"], ["0.47", "#5c5b50"], ["1.00", "#37444d"]],
		"apron": "#4f5552",
		"glow": "#78c9da",
		"artwork": "",
		"props": [
			{"kind": "loco", "x": 0.0, "tint": "gear"},
			{"kind": "girder", "x": -6.4, "h": 2.10, "lean": -1.0},
			{"kind": "girder", "x": 6.2, "h": 2.10, "lean": 1.0},
			{"kind": "girder", "x": -2.6, "h": 1.95, "lean": 1.0},
			{"kind": "girder", "x": 2.8, "h": 1.95, "lean": -1.0},
			{"kind": "signal", "x": -10.6, "h": 1.85, "tint": "#f4bd48"},
			{"kind": "signal", "x": 10.7, "h": 1.85, "tint": "#f4bd48"},
			{"kind": "rail", "x": -8.6, "y": 0.28, "lean": -1.0},
			{"kind": "rail", "x": 8.8, "y": 0.28, "lean": 1.0},
		],
	},
	"clockwork": {
		# drawClockworkFactoryBackdrop.
		"family": "clockwork",
		"sky": [["0.00", "#160f31"], ["0.45", "#3b2048"], ["0.46", "#7b465b"], ["1.00", "#33214b"]],
		"apron": "#4c344d",
		"glow": "#ecaa43",
		"artwork": "",
		"props": [
			{"kind": "clock", "x": 0.0, "y": 1.25, "r": 0.86, "tint": "#d4a64c"},
			{"kind": "gear", "x": -4.3, "y": 1.0, "r": 0.6, "tint": "#c68737"},
			{"kind": "gear", "x": 4.4, "y": 1.1, "r": 0.62, "tint": "#c68737"},
			{"kind": "gear", "x": -8.1, "y": 0.62, "r": 0.44, "tint": "#b52b65"},
			{"kind": "gear", "x": 8.2, "y": 0.6, "r": 0.44, "tint": "#b52b65"},
			{"kind": "lamp", "x": -10.6, "y": 1.7, "r": 0.22, "tint": "#ff4b9a"},
			{"kind": "lamp", "x": 10.7, "y": 1.75, "r": 0.22, "tint": "#ff4b9a"},
			{"kind": "piston", "x": 1.9, "y": 0.55},
		],
	},
	"cattedrale": {
		# Family `locomotive` (js/render.js:697-699); tints are the port's, taken
		# from this arena's own palette in `js/data.js`. No artwork of its own.
		"family": "locomotive",
		"sky": [["0.00", "#071526"], ["0.46", "#1b4d5d"], ["0.47", "#5c5b50"], ["1.00", "#37444d"]],
		"apron": "#312b4f",
		"glow": "#c98bff",
		"artwork": "",
		"props": [
			{"kind": "loco", "x": 0.0, "tint": "gear"},
			{"kind": "girder", "x": -6.4, "h": 2.10, "lean": -1.0, "tint": "accent"},
			{"kind": "girder", "x": 6.2, "h": 2.10, "lean": 1.0, "tint": "accent"},
			{"kind": "signal", "x": -10.6, "h": 1.85, "tint": "accent"},
			{"kind": "signal", "x": 10.7, "h": 1.85, "tint": "accent"},
			{"kind": "clock", "x": 0.0, "y": 1.70, "r": 0.4, "tint": "gear"},
			{"kind": "rail", "x": -8.6, "y": 0.28, "lean": -1.0, "tint": "accent"},
			{"kind": "rail", "x": 8.8, "y": 0.28, "lean": 1.0, "tint": "accent"},
		],
	},
	"forgia": {
		# Family `clockwork` (js/render.js:700-701); tints are the port's, from
		# this arena's palette. No artwork of its own.
		"family": "clockwork",
		"sky": [["0.00", "#160f31"], ["0.45", "#3b2048"], ["0.46", "#7b465b"], ["1.00", "#33214b"]],
		"apron": "#42272b",
		"glow": "#ffd54a",
		"artwork": "",
		"props": [
			{"kind": "clock", "x": 0.0, "y": 1.3, "r": 0.8, "tint": "gear"},
			{"kind": "gear", "x": -4.3, "y": 1.0, "r": 0.58, "tint": "gear"},
			{"kind": "gear", "x": 4.4, "y": 1.1, "r": 0.6, "tint": "gear"},
			{"kind": "gear", "x": -8.1, "y": 0.62, "r": 0.42, "tint": "accent"},
			{"kind": "gear", "x": 8.2, "y": 0.6, "r": 0.42, "tint": "accent"},
			{"kind": "lava", "x": -10.7, "y": 0.5, "r": 0.9, "tint": "accent"},
			{"kind": "lava", "x": 10.8, "y": 0.5, "r": 0.9, "tint": "accent"},
			{"kind": "piston", "x": -2.1, "y": 0.55},
			{"kind": "spark", "x": 5.6, "y": 1.5},
			{"kind": "spark", "x": -6.0, "y": 1.7},
		],
	},
	"tempesta": {
		# themes.tempesta (js/render.js:502) + drawFantasyArenaProps tempesta.
		"family": "fantasy",
		"sky": [["0.00", "#07142f"], ["1.00", "#287eb0"]],
		"apron": "#17253c",
		"glow": "#79eeff",
		"artwork": "bastione-tempesta.webp",
		"props": [
			{"kind": "airship", "x": -8.4, "y": 1.05, "r": 0.62, "tint": "#b47b35"},
			{"kind": "airship", "x": 8.4, "y": 1.15, "r": 0.62, "tint": "#b47b35"},
			{"kind": "gear", "x": -4.7, "y": 0.62, "r": 0.42, "tint": "#a96f2d"},
			{"kind": "gear", "x": 4.8, "y": 0.62, "r": 0.42, "tint": "#a96f2d"},
			{"kind": "bolt", "x": -2.4, "y": 1.6, "h": 1.5, "tint": "glow"},
			{"kind": "bolt", "x": 2.6, "y": 1.5, "h": 1.35, "tint": "glow"},
			{"kind": "chain", "x": -11.2, "y": 1.1, "h": 1.9, "tint": "#cd9748"},
			{"kind": "chain", "x": 11.3, "y": 1.1, "h": 1.9, "tint": "#cd9748"},
			{"kind": "cloud", "x": 0.4, "y": 1.55, "r": 0.4, "tint": "glow"},
		],
	},
	"abissale": {
		# themes.abissale (js/render.js:503) + drawFantasyArenaProps abissale.
		"family": "fantasy",
		"sky": [["0.00", "#020b1d"], ["1.00", "#086474"]],
		"apron": "#0b3038",
		"glow": "#42fff2",
		"artwork": "santuario-abissale.webp",
		"props": [
			{"kind": "dome", "x": 0.0, "y": 1.45, "r": 5.9, "tint": "#c18440"},
			{"kind": "porthole", "x": -10.9, "y": 0.95, "r": 0.5, "tint": "#cf9950"},
			{"kind": "porthole", "x": 11.0, "y": 0.95, "r": 0.5, "tint": "#cf9950"},
			{"kind": "rock", "x": -6.3, "h": 0.95, "tint": "#123a3f"},
			{"kind": "rock", "x": 6.4, "h": 0.8, "tint": "#123a3f"},
			{"kind": "bubble", "x": -3.2, "y": 1.35, "r": 0.16, "tint": "glow"},
			{"kind": "bubble", "x": -1.4, "y": 1.8, "r": 0.11, "tint": "glow"},
			{"kind": "bubble", "x": 2.0, "y": 1.5, "r": 0.14, "tint": "glow"},
			{"kind": "bubble", "x": 3.8, "y": 1.95, "r": 0.09, "tint": "glow"},
		],
	},
	"caldera": {
		# themes.caldera (js/render.js:504) + drawFantasyArenaProps caldera.
		"family": "fantasy",
		"sky": [["0.00", "#160b10"], ["1.00", "#7b2817"]],
		"apron": "#3c211d",
		"glow": "#ff7138",
		"artwork": "caldera-titano.webp",
		"props": [
			{"kind": "titan", "x": -8.6, "y": 1.15, "r": 0.72, "tint": "#a2492c"},
			{"kind": "titan", "x": 8.7, "y": 1.25, "r": 0.72, "tint": "#a2492c"},
			{"kind": "lava", "x": -3.4, "y": 0.45, "r": 1.1, "tint": "glow"},
			{"kind": "lava", "x": 3.5, "y": 0.45, "r": 1.1, "tint": "glow"},
			{"kind": "gear", "x": -5.7, "y": 0.55, "r": 0.5, "tint": "#73321f"},
			{"kind": "gear", "x": 5.9, "y": 0.55, "r": 0.5, "tint": "#73321f"},
			{"kind": "rock", "x": -1.6, "h": 0.8, "tint": "#120e0f"},
			{"kind": "rock", "x": 1.5, "h": 0.62, "tint": "#120e0f"},
			{"kind": "rock", "x": 11.1, "h": 1.0, "tint": "#120e0f"},
			{"kind": "rock", "x": -11.2, "h": 1.0, "tint": "#120e0f"},
			{"kind": "chain", "x": -7.4, "y": 1.3, "h": 1.5, "tint": "#80462d"},
			{"kind": "chain", "x": 7.6, "y": 1.3, "h": 1.5, "tint": "#80462d"},
			{"kind": "spark", "x": 0.0, "y": 1.7, "tint": "glow"},
		],
	},
	"orrery": {
		# themes.orrery (js/render.js:505) + drawFantasyArenaProps orrery.
		"family": "fantasy",
		"sky": [["0.00", "#080722"], ["1.00", "#30246a"]],
		"apron": "#241d4b",
		"glow": "#b595ff",
		"artwork": "orrery-celeste.webp",
		"props": [
			{"kind": "orbit", "x": 0.0, "y": 0.95, "r": 5.8, "tint": "#e1b553"},
			{"kind": "orbit", "x": 0.0, "y": 0.95, "r": 4.0, "tint": "#e1b553"},
			{"kind": "orbit", "x": 0.0, "y": 0.95, "r": 2.4, "tint": "#e1b553"},
			{"kind": "planet", "x": -6.6, "y": 0.85, "r": 0.42, "tint": "#50d8ff"},
			{"kind": "planet", "x": 6.5, "y": 1.05, "r": 0.5, "tint": "#d17cff"},
			{"kind": "planet", "x": -10.5, "y": 0.5, "r": 0.32, "tint": "#e2b653"},
			{"kind": "planet", "x": 10.5, "y": 0.55, "r": 0.36, "tint": "#6e8dff"},
			{"kind": "column", "x": -9.1, "y": 0.95, "h": 1.9, "tint": "#c69a49"},
			{"kind": "column", "x": 9.2, "y": 0.95, "h": 1.9, "tint": "#c69a49"},
			{"kind": "spark", "x": 2.9, "y": 1.6, "tint": "glow"},
			{"kind": "spark", "x": -3.4, "y": 1.8, "tint": "glow"},
		],
	},
}


## The style for one arena id. Unknown ids fall back to the roster's first arena
## — the same "first is the default" rule `match_config.gd` uses.
static func style(id: String) -> Dictionary:
	if STYLES.has(id):
		return STYLES[id]
	var ids: Array = STYLES.keys()
	return STYLES[ids[0] if ids.size() > 0 else "officina"]


static func ids() -> Array:
	return STYLES.keys()


static func family(id: String) -> String:
	return String(style(id).get("family", "open"))


## A compact digest of what makes this arena's frame different from the others'.
## Used by `tests/game_slice_test.gd` to assert the nine are actually distinct
## rather than nine copies of one court: family, sky top and bottom, apron, glow,
## artwork and the number of scenery objects.
static func signature(id: String) -> String:
	var s := style(id)
	var sky: Array = s.get("sky", [])
	var stops := ""
	for stop in sky:
		stops += String(stop[1])
	return "%s|%s|%s|%s|%s|%d" % [
		String(s.get("family", "open")),
		stops,
		String(s.get("apron", "")),
		String(s.get("glow", "")),
		String(s.get("artwork", "")),
		(s.get("props", []) as Array).size(),
	]


## The absolute path of the arena's own painted artwork, or "" when it has none.
## The file is the reference's (`js/data.js`'s `image`), copied verbatim; nothing
## is generated and no external asset is fetched.
static func artwork_path(id: String) -> String:
	var name := String(style(id).get("artwork", ""))
	return "" if name == "" else ARTWORK_DIR + name
