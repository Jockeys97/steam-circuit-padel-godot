## BuildFlag.gd — the single build flag: full game or demo.
##
## The reference has exactly one place that answers this question
## (`js/build.js:19-35`, `IS_DEMO = resolveBuild()`) and everything else reads
## that answer. The port keeps the shape: `is_demo()` is the only function that
## inspects the feature tag, and no other file reads `OS.has_feature("demo")`
## directly.
##
## Detection order (mirrors `js/build.js`, container first):
##
##   1. the `demo` feature tag — set by the export preset's `custom_features`
##      (`godot/export_presets.cfg`, the `linux-x86_64-demo` preset). This is the
##      desktop equivalent of `window.__PADEL_BUILD`, which is how the browser
##      build's container announces the build, and it is read FIRST for the
##      reference's reason (`js/build.js:19-24`): the container's word is the
##      build's identity, so nothing the player can pass on the command line can
##      talk a demo out of being a demo.
##   2. `--demo` / `--full` in the user args (`godot ... -- --demo`), the
##      equivalent of the reference's `?build=demo` URL flag: it exists so the
##      full repository can PROVE the demo without publishing anything. It is only
##      consulted when the feature tag is absent — i.e. in the editor project and
##      in the full build, never inside a shipped demo.
##   3. nothing: full game. The default is the product, not the demo — if
##      detection fails the worst case is that someone sees the whole game, not
##      that a paying customer gets a mutilated build (`js/build.js:14-16`).
##
## A build that is not a demo is a full build: `is_full()` is not a second flag,
## it is the same answer negated, exactly as the reference has no second flag.
##
## review-2 F-1 is why the order above is the order it is. The first port of this
## file read the user args BEFORE the tag, so the shipped demo binary launched as
## `padel-demo.x86_64 -- --full` reported `build=full`, listed 6 athletes / 9
## arenas / 3 modes, and still printed its own PASS line. `resolve()` is separated
## from `is_demo()` so that priority is a value a test can assert without an
## export (`tests/game_slice_test.gd`, `_build_flag_priority`).
extends RefCounted

const FEATURE_TAG := "demo"


## The whole rule as a pure function of the two inputs it actually reads, so the
## priority can be tested without an export preset and without a real command line.
##
## `has_feature_tag` is the container's announcement and it WINS: a build whose
## container says "demo" is a demo whatever `user_args` holds (`js/build.js:19-24`).
## Only when the tag is absent do the args decide, which is what makes
## `-- --demo` useful in the editor project — the `linux-x86_64` preset sets no
## tag, so that build can be asked to behave as the demo for a test run.
static func resolve(has_feature_tag: bool, user_args: PackedStringArray) -> bool:
	if has_feature_tag:
		return true
	for arg in user_args:
		if arg == "--demo":
			return true
		if arg == "--full":
			return false
	return false


static func is_demo() -> bool:
	return resolve(OS.has_feature(FEATURE_TAG), OS.get_cmdline_user_args())


static func is_full() -> bool:
	return not is_demo()


## The flag as a string, for evidence logs: which build a run believes it is.
static func label() -> String:
	return "demo" if is_demo() else "full"
