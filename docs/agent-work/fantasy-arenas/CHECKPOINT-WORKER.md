# CHECKPOINT - fantasy_arenas worker

Updated: 2026-09-25 (rolling; overwritten each checkpoint)
Branch/worktree: `codex/integrate-arena-11m` @ `/Users/alessiofantini/Documents/steam-circuit-padel-11m`

## State

Discovery and baselining are DONE. Implementation has started (shaders landed).

Implemented paths so far:

- `godot/game/arenas/fantasy/fantasy_gradient.gdshader` - unshaded world-height gradient shell
  (continuous background for all six; one draw call, no script).
- `godot/game/arenas/fantasy/fantasy_drift.gdshader` - slow bounded cloud/sea/lava/dust layers
  (capped amplitude + rate => no strobe; one draw per layer, GPU-only motion).
- `godot/game/arenas/fantasy/fantasy_stars.gdshader` - hashed starfield + nebula shell
  (Orrery / Abyssal deep field).
- `godot/tests/fantasy_render_probe.gd` + `.tscn` - temporary rendering feasibility probe
  (result below).

Baseline copies: `docs/agent-work/fantasy-arenas/evidence/baseline/`
(`arena_library.gd.baseline` plus four suite logs).

## Baseline results (captured, unchanged by me)

| check | exit | result |
| --- | --- | --- |
| `tests/arena_catalog_test.gd` | 0 | PASS 15/15 |
| `tests/arena_look_test.gd` | 1 | 354/368 - PRE-EXISTING 14 FAILs, all world-arena look drift (torii/medina/carioca/aurora/egeo) plus one ground-fixture check. The frozen-nine env pin (`frozen/the_nine_keep_the_environment_their_captures_were_made_with`) PASSES and must stay passing. |
| `tests/game_slice_test.gd` | 1 | 337/338 - PRE-EXISTING `locomotive: unexpected floor shader or tint` (concurrent work). |
| `tests/fantasy_render_probe.gd` | 0 | `PROBE_OK px=640x360 distinct_colours=4 png_bytes=1825` on `display=macOS adapter=Apple M4 api=4.1 Metal - 90.5 - Compatibility`. Rendering-enabled capture works on this host. |

Measured band requirement at z=-12 (via `tests/world_arenas_band_probe.gd`), which sizes the hall:

- `default`: top 4.80 m, half-x 20.70 m
- `wide`: top 11.06 m, half-x 36.88 m
- `playable`: top 12.30 m, half-x 30.58 m

## Contract conflict (reported to Astra, no out-of-scope file edited)

`DESIGN.md` wants the builder to adjust the six arenas' `Environment`/lights, but
`tests/arena_look_test.gd::_frozen_nine_untouched` (lines 370-430, `const FROZEN` line 55)
pins those exact six ids to `BG_COLOR` / `sky==null` / ambient defaults / fog off /
glow off / ssao off / adjustments off / LINEAR tonemap / fixed sun+fill rotation and
energy / no `Surround` texture. `tests/game_slice_test.gd:1969-1980` additionally pins
`Surround`'s material to the arena `apron` colour and requires `Scenery/Backdrop` plus one
`Dressing_*` per prop to still EXIST (hidden is fine - `egeo` proves it).

Resolution taken: geometry + shaders carry the visual (dome shell, layered depth, emissive
accents), and I adjust only env/light fields that gate does not pin (`sun.light_color`,
`fill.light_color`, background energy). No test weakened, no unowned file touched. Full
sky/fog/glow upgrade is a one-place change if Astra authorises it.

## Next step (active)

Write `godot/game/arenas/fantasy/fantasy_kit.gd` (shared material/mesh/MultiMesh helpers plus
a triangle/draw `budget()` the test reuses), `godot/game/arenas/fantasy/fantasy_motion.gd`
(bounded pivot rotation + ember/bubble MultiMesh drift), then
`godot/game/arenas/fantasy_environment.gd` with the six builders, then the shared hook in
`godot/game/arenas/arena_library.gd`, then `tests/fantasy_arenas_test.gd` and
`tests/fantasy_arenas_capture.gd`.

No git staging/commit/push. No paid asset calls. Dirty concurrent files untouched.
