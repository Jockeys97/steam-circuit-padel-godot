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
##
## THE FIVE WORLD ARENAS (`family: "world"`). `torii`, `medina`, `carioca`,
## `aurora` and `egeo` are PORT ADDITIONS: the reference has no row for them and
## this port must not invent one, so `src/sim/frozen/data.json` is untouched and
## they are NOT part of `Arena.ids()` (the frozen roster stays nine). Their only
## authority is the concept deck `art/concepts/world-arenas-r1/` (`BRIEF.md` +
## `README.md`), which is READ-ONLY: nothing here or anywhere else loads, imports,
## copies or regenerates one of its stills — the deck's own five sky/apron/glow
## values and its own scenery language are transcribed, the PNGs are not.
##
## Because no frozen row exists, a world entry carries three things a frozen row
## would otherwise supply, all of them presentation and all copied from the deck:
## `name`/`desc` (the deck's own arena names, in the roster's Italian voice),
## `palette` (the deck's apron/glow/horizon tones, used for the ground paint and
## the accent props) and nothing else. It deliberately carries NO `wallBounce`,
## `floorGrip` or `unlock`: those are simulation values, and inventing them here
## would be re-tuning frozen data. The library instead supplies the documented
## NEUTRAL defaults as an explicit PROVISIONAL recommendation
## (`arena_library.gd`'s `WORLD_WALL_BOUNCE` / `WORLD_FLOOR_GRIP`, marked
## `provisional` in `world_info()`), so a world arena is buildable, capturable AND
## playable. When the owner's tuning decision lands, it replaces those two values
## and nothing else.
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
##
## A `family: "world"` entry adds `name`, `desc` and `palette` (see the file
## header) and has no frozen row behind it.
const STYLES := {
	"officina": {
		# js/render.js:709-733 (the default open scene) + palette.
		"family": "open",
		"sky": [["0.00", "#51c6f4"], ["0.48", "#c8f1ff"], ["0.49", "#f5a277"], ["1.00", "#e57958"]],
		"apron": "#e78c68",
		"glow": "#7fd4ff",
		# The reference paints this one too (`js/data.js` ARENAS[0].image), so the port
		# copies its file like the other four: a gradient-only backdrop was a port gap,
		# not a decision the reference made.
		"artwork": "officina-vapore-standard.webp",
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
		"artwork": "deposito-locomotive.webp",
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
		"artwork": "clockwork-factory.webp",
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
		# from this arena's own palette in `js/data.js`. The reference reuses the depot
		# backdrop for it (`ARENAS[3].image`), so the port does the same rather than
		# leaving the arena unpainted.
		"family": "locomotive",
		"sky": [["0.00", "#071526"], ["0.46", "#1b4d5d"], ["0.47", "#5c5b50"], ["1.00", "#37444d"]],
		"apron": "#312b4f",
		"glow": "#c98bff",
		"artwork": "deposito-locomotive.webp",
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
		# this arena's palette. The reference reuses the factory backdrop here
		# (`ARENAS[4].image`), so the port does the same.
		"family": "clockwork",
		"sky": [["0.00", "#160f31"], ["0.45", "#3b2048"], ["0.46", "#7b465b"], ["1.00", "#33214b"]],
		"apron": "#42272b",
		"glow": "#ffd54a",
		"artwork": "clockwork-factory.webp",
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
	# --- the five world arenas (port additions, family "world") -----------------
	"torii": {
		# Portale Torii, Kyoto at dusk. Deck: `01-torii.png`, sky stops
		# `#0b1026 -> #3a2350 -> #e8734f`, apron `#2b2a33` stone, glow `#ffb24d`
		# lantern gold. Scenery: vermilion torii colonnade, five-storey pagoda,
		# paper lanterns, drifting petals, crescent moon.
		"family": "world",
		"name": "Portale Torii",
		"desc": "Crepuscolo di Kyoto: portali vermigli, lanterne di carta e petali.",
		"sky": [["0.00", "#0b1026"], ["0.55", "#3a2350"], ["1.00", "#e8734f"]],
		"apron": "#2b2a33",
		"glow": "#ffb24d",
		"palette": {"floor": "#2b2a33", "accent": "#ffb24d", "gear": "#e8734f"},
		"artwork": "",
		"props": [
			{"kind": "moon", "x": -8.0, "y": 3.5, "r": 0.34, "tint": "#f6e7c8"},
			{"kind": "petal", "x": -10.2, "y": 2.50, "tint": "#ffb7d5"},
			{"kind": "petal", "x": -5.0, "y": 2.10, "tint": "#ffc6dd"},
			{"kind": "petal", "x": 2.0, "y": 2.70, "tint": "#ffb7d5"},
			{"kind": "petal", "x": 6.6, "y": 1.90, "tint": "#ffc6dd"},
			{"kind": "petal", "x": 10.4, "y": 2.40, "tint": "#ffb7d5"},
			{"kind": "torii", "x": 0.4, "w": 4.0, "h": 2.30, "tint": "#c8402c"},
			{"kind": "torii", "x": -7.0, "w": 2.8, "h": 1.80, "tint": "#b23a28"},
			{"kind": "torii", "x": 7.4, "w": 2.8, "h": 1.80, "tint": "#b23a28"},
			{"kind": "torii", "x": -10.8, "w": 2.0, "h": 1.45, "tint": "#9c3223"},
			{"kind": "torii", "x": 11.0, "w": 2.0, "h": 1.45, "tint": "#9c3223"},
			{"kind": "lantern", "x": -3.4, "y": 1.70, "r": 0.190, "hang": 0.50, "tint": "glow"},
			{"kind": "lantern", "x": 3.8, "y": 1.60, "r": 0.170, "hang": 0.55, "tint": "glow"},
			{"kind": "lantern", "x": -7.0, "y": 1.30, "r": 0.150, "hang": 0.40, "tint": "glow"},
			{"kind": "lantern", "x": 7.4, "y": 1.35, "r": 0.150, "hang": 0.45, "tint": "glow"},
			{"kind": "pagoda", "x": 9.6, "h": 3.10, "r": 0.98, "tint": "#33203a"},
		],
	},
	"medina": {
		# Cortile Medina, Marrakech at golden hour. Deck: `02-medina.png`, sky
		# stops `#f7c884 -> #e08a52 -> #8f3f30`, apron `#c78a5a` clay, glow
		# `#3fd0c9` zellige turquoise. Scenery: clay walls, horseshoe gate, date
		# palms, brass lanterns, tiled band, slim minaret.
		"family": "world",
		"name": "Cortile Medina",
		"desc": "Ora d'oro su Marrakech: mura d'ocra, palme e zellige.",
		"sky": [["0.00", "#f7c884"], ["0.55", "#e08a52"], ["1.00", "#8f3f30"]],
		"apron": "#c78a5a",
		"glow": "#3fd0c9",
		"palette": {"floor": "#c78a5a", "accent": "#3fd0c9", "gear": "#8f3f30"},
		"artwork": "",
		"props": [
			{"kind": "sun", "x": -8.6, "y": 3.20, "r": 0.50, "tint": "#ffd9a0"},
			{"kind": "wall", "x": 0.0, "w": 21.0, "h": 0.80, "tint": "#b06a3f", "z": -7.45},
			{"kind": "zellige", "x": 0.0, "w": 9.0, "h": 0.26, "y": 0.94, "tint": "accent", "z": -7.42},
			{"kind": "arch", "x": 0.2, "w": 2.2, "h": 1.30, "tint": "#c98a52"},
			{"kind": "minaret", "x": 8.8, "h": 3.20, "r": 0.40, "tint": "#d9a06a"},
			{"kind": "palm", "x": -6.6, "h": 2.20, "tint": "#3f5b34"},
			{"kind": "palm", "x": -4.4, "h": 1.75, "tint": "#48633a"},
			{"kind": "palm", "x": 5.9, "h": 2.05, "tint": "#3f5b34"},
			{"kind": "palm", "x": 7.4, "h": 1.60, "tint": "#48633a"},
			{"kind": "palm", "x": -11.0, "h": 1.50, "tint": "#48633a"},
			{"kind": "lantern", "x": -2.6, "y": 1.62, "r": 0.170, "hang": 0.35, "tint": "#e8b652"},
			{"kind": "lantern", "x": 2.9, "y": 1.50, "r": 0.150, "hang": 0.40, "tint": "#e8b652"},
			{"kind": "lantern", "x": -8.4, "y": 1.72, "r": 0.140, "hang": 0.50, "tint": "#e8b652"},
		],
	},
	"carioca": {
		# Terrazza Carioca, Rio de Janeiro at noon. Deck: `03-carioca.png`, sky
		# stops `#2fb6d9 -> #9fdcf0 -> #eaf7ff`, apron `#e8d5a8` beach sand, glow
		# `#ffd84d` afternoon sun. Scenery: Sugarloaf and twin peaks in haze, palm
		# rows, wave foam, the cable-car line.
		"family": "world",
		"name": "Terrazza Carioca",
		"desc": "Mezzogiorno a Rio: creste di granito, palme e schiuma.",
		"sky": [["0.00", "#2fb6d9"], ["0.52", "#9fdcf0"], ["1.00", "#eaf7ff"]],
		"apron": "#e8d5a8",
		"glow": "#ffd84d",
		"palette": {"floor": "#e8d5a8", "accent": "#ffd84d", "gear": "#2fb6d9"},
		"artwork": "",
		"props": [
			{"kind": "sun", "x": -2.4, "y": 3.90, "r": 0.42, "tint": "#ffe08a"},
			{"kind": "cloud", "x": -9.4, "y": 2.60, "r": 0.32, "tint": "#ffffff"},
			{"kind": "cloud", "x": 9.0, "y": 2.90, "r": 0.28, "tint": "#ffffff"},
			{"kind": "ridge", "x": -5.2, "r": 1.50, "count": 5, "spread": 1.45, "alpha": 0.80, "tint": "#8fb4c4"},
			{"kind": "peak", "x": 3.6, "r": 0.95, "twin": 0.55, "twin_x": 2.2, "tint": "#5f7f8e"},
			{"kind": "peak", "x": 9.6, "r": 0.60, "tint": "#6d8c99"},
			{"kind": "cable", "x": 6.2, "y": 2.25, "w": 4.0, "lean": 3.0, "tint": "#2b3f4a"},
			{"kind": "palm", "x": -8.8, "h": 1.90, "tint": "#2f6b46"},
			{"kind": "palm", "x": -3.0, "h": 1.55, "tint": "#37784d"},
			{"kind": "palm", "x": 4.6, "h": 1.70, "tint": "#2f6b46"},
			{"kind": "palm", "x": 10.2, "h": 1.45, "tint": "#37784d"},
			{"kind": "foam", "x": -5.6, "r": 0.90, "count": 3, "tint": "#ffffff"},
			{"kind": "foam", "x": 0.9, "r": 0.70, "count": 3, "tint": "#f2fbff"},
			{"kind": "foam", "x": 6.8, "r": 0.80, "count": 3, "tint": "#ffffff"},
		],
	},
	"aurora": {
		# Banco Aurora, Iceland at night. Deck: `04-aurora.png`, sky stops
		# `#04060f -> #0a1b33 -> #123a3c`; the moonlit basalt apron tint
		# must not multiply its detailed ground texture down to near-black. Glow
		# `#4dffc3` aurora green. Scenery: basalt colonnade, snow-capped ridge,
		# geyser steam plumes, aurora ribbons, stars.
		"family": "world",
		"name": "Banco Aurora",
		"desc": "Notte islandese: colonne di basalto, neve e nastri d'aurora.",
		"sky": [["0.00", "#04060f"], ["0.60", "#0a1b33"], ["1.00", "#123a3c"]],
		"apron": "#748895",
		"glow": "#4dffc3",
		"palette": {"floor": "#0d0f12", "accent": "#4dffc3", "gear": "#7a5cff"},
		"artwork": "",
		"props": [
			{"kind": "star", "x": -10.4, "y": 4.10, "r": 0.050, "tint": "#dff6ff"},
			{"kind": "star", "x": -6.2, "y": 3.60, "r": 0.045, "tint": "#cfe9ff"},
			{"kind": "star", "x": 0.8, "y": 4.30, "r": 0.050, "tint": "#dff6ff"},
			{"kind": "star", "x": 5.4, "y": 3.80, "r": 0.045, "tint": "#cfe9ff"},
			{"kind": "star", "x": 9.8, "y": 4.20, "r": 0.050, "tint": "#dff6ff"},
			{"kind": "moon", "x": 11.2, "y": 3.40, "r": 0.30, "tint": "#e8f2f8"},
			{"kind": "aurora", "x": -3.2, "y": 3.00, "w": 8.5, "h": 1.40, "tint": "#7a5cff", "alpha": 0.90},
			{"kind": "aurora", "x": 5.4, "y": 3.35, "w": 6.5, "h": 1.05, "tint": "#9d7bff", "alpha": 0.75},
			{"kind": "basalt", "x": -6.0, "r": 0.50, "h": 2.50, "count": 7, "tint": "#15171c"},
			{"kind": "basalt", "x": 6.6, "r": 0.40, "h": 2.00, "count": 5, "tint": "#15171c"},
			{"kind": "snowridge", "x": 0.6, "r": 1.60, "count": 4, "tint": "#1b2530"},
			{"kind": "steam", "x": -2.0, "y": 0.90, "r": 0.30, "tint": "#9fb4c0"},
			{"kind": "steam", "x": 2.8, "y": 0.80, "r": 0.26, "tint": "#9fb4c0"},
		],
	},
	"egeo": {
		# Isola Egeo, Santorini at noon. Deck: `05-egeo.png`, sky stops
		# `#1f5fd0 -> #7fb3f0 -> #eef4ff`, apron `#d9d2c4` pale stone, glow
		# `#2b5fd9` cobalt. Scenery: whitewashed cubes cascading down the cliff,
		# cobalt domes, a windmill, bougainvillea, the caldera sea below.
		"family": "world",
		"name": "Isola Egeo",
		"desc": "Mezzogiorno a Santorini: case bianche, cupole cobalt e caldera.",
		"sky": [["0.00", "#1f5fd0"], ["0.55", "#7fb3f0"], ["1.00", "#eef4ff"]],
		"apron": "#d9d2c4",
		"glow": "#2b5fd9",
		"palette": {"floor": "#d9d2c4", "accent": "#2b5fd9", "gear": "#eef4ff"},
		"artwork": "",
		"props": [
			{"kind": "sun", "x": 6.8, "y": 3.80, "r": 0.40, "tint": "#fff3c8"},
			{"kind": "sea", "x": -1.2, "y": 0.20, "w": 24.0, "h": 0.40, "tint": "#1d4a92", "z": -7.90},
			{"kind": "island", "x": -4.6, "r": 1.50, "h": 2.20, "tint": "#eef4ff"},
			{"kind": "island", "x": 3.2, "r": 1.10, "h": 1.70, "tint": "#e6edf7"},
			{"kind": "windmill", "x": 8.4, "h": 1.90, "r": 0.30, "tint": "#f4f7fc"},
			{"kind": "bougainvillea", "x": -8.8, "r": 0.36, "tint": "#d2267f"},
			{"kind": "bougainvillea", "x": 6.0, "r": 0.28, "tint": "#c81f74"},
		],
	},
}


## The style for one arena id. Unknown ids fall back to the frozen roster's first
## arena — the same "first is the default" rule `match_config.gd` uses. The
## fallback names that arena explicitly instead of reading `STYLES.keys()[0]`:
## since the world family was appended, key order is no longer a promise, and a
## world arena must never become the fallback for a typo.
static func style(id: String) -> Dictionary:
	if STYLES.has(id):
		return STYLES[id]
	return STYLES["officina"]


## Every entry of this table, world arenas included. NOT the selectable roster:
## the roster is `arena_library.gd::ids()` (the frozen nine) and the world set is
## `world_ids()` below.
static func ids() -> Array:
	return STYLES.keys()


## The world arenas, in table order. This is the table's own answer to "which
## entries are port additions"; `arena_library.gd` re-exports it.
static func world_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in STYLES.keys():
		if String((STYLES[id] as Dictionary).get("family", "open")) == "world":
			out.append(String(id))
	return out


## Is this id a world arena (a `family: "world"` entry, with no frozen row)?
static func is_world(id: String) -> bool:
	return STYLES.has(id) and String((STYLES[id] as Dictionary).get("family", "open")) == "world"


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
