## fonts_assets_probe.gd — UIR-01 load check for the staged UI assets.
##
##   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
##   "$GODOT" --headless --path godot/ --script res://tests/ui/fonts_assets_probe.gd ; echo "exit=$?"
##
## Every path below is staged by UIR-01 under `godot/assets/ui/**` (fonts fetched from
## Google Fonts, images copied byte-for-byte from the frozen `assets/**`). This probe
## proves only that the engine imported them and that each one loads and reports a
## usable size: `.webp` through Godot's native WebP import into a Texture2D, `.ttf`
## through the FontFile importer.
##
## Contract copied from `godot/tests/smoke_test.gd:7-14`: one `ok <name>` line per
## check, a single `PASS n/n` (or `FAIL n/n`) line, exit 0 on pass and 1 on fail.
##
## Owner: UIR-01. No other ticket edits this file; delete it (and its `.uid`) before
## hand-back if the evidence table alone is preferred.
extends SceneTree

## Font roles UIR-02 assigns in the theme: display, body, semibold, bold, extrabold.
const FONTS: PackedStringArray = [
	"res://assets/ui/fonts/LilitaOne-Regular.ttf",
	"res://assets/ui/fonts/Nunito-Regular.ttf",
	"res://assets/ui/fonts/Nunito-SemiBold.ttf",
	"res://assets/ui/fonts/Nunito-Bold.ttf",
	"res://assets/ui/fonts/Nunito-ExtraBold.ttf",
]

## Mirror of `assets/ui/**` plus the card previews the reference's grids use.
const IMAGES: PackedStringArray = [
	"res://assets/ui/steam-circuit-key-art.webp",
	"res://assets/ui/xbox-controller-steam.webp",
	"res://assets/ui/playstation-controller-steam.webp",
	"res://assets/ui/generic-controller-steam.webp",
	"res://assets/ui/modes/quick-match.webp",
	"res://assets/ui/modes/tournament.webp",
	"res://assets/ui/modes/career.webp",
	"res://assets/ui/athletes/colosso.webp",
	"res://assets/ui/athletes/fiamma.webp",
	"res://assets/ui/athletes/maestro.webp",
	"res://assets/ui/athletes/oracolo.webp",
	"res://assets/ui/athletes/pantera.webp",
	"res://assets/ui/athletes/steamer.webp",
	"res://assets/ui/arenas/bastione-tempesta.webp",
	"res://assets/ui/arenas/caldera-titano.webp",
	"res://assets/ui/arenas/clockwork-factory.webp",
	"res://assets/ui/arenas/deposito-locomotive.webp",
	"res://assets/ui/arenas/officina-vapore-standard.webp",
	"res://assets/ui/arenas/orrery-celeste.webp",
	"res://assets/ui/arenas/santuario-abissale.webp",
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	print("# fonts_assets_probe · Godot %s" % Engine.get_version_info().get("string", "?"))

	for path in FONTS:
		var res: Resource = load(path)
		check_true(res != null, "%s loads" % path)
		if res == null:
			continue
		check_true(res is FontFile, "%s imports as FontFile" % path)
		var font := res as FontFile
		if font == null:
			continue
		# A font that imported but carries no usable data measures zero width.
		var width: float = font.get_string_size(
			"Steam Circuit", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x
		check_true(width > 0.0, "%s measures text (24 px 'Steam Circuit' = %.1f px)" % [path, width])

	for path in IMAGES:
		var res: Resource = load(path)
		check_true(res != null, "%s loads" % path)
		if res == null:
			continue
		check_true(res is Texture2D, "%s imports as Texture2D" % path)
		var tex := res as Texture2D
		if tex == null:
			continue
		check_true(
			tex.get_width() > 0 and tex.get_height() > 0,
			"%s has pixels (%dx%d)" % [path, tex.get_width(), tex.get_height()])

	_finish()


func check_true(got: bool, name: String) -> void:
	_checks += 1
	if got:
		print("ok %s" % name)
		return
	_failures += 1
	var line := "FAIL %s" % name
	print(line)
	printerr(line)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
