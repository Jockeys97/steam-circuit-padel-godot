# Deposito Locomotive and Fabbrica degli Orologi

Canonical 11m / codex/integrate-arena-11m. Same direct workflow as Officina;
no delegation, paid APIs, new generated asset purchases, commits or real-save edits.

## Contract and implementation

Only the two named arena IDs change. Reuse Officina batching, procedural surface
materials, canopy recolouring and bounded steam; preserve existing Officina and
all concurrent work. Extract flush_batches/dress_fabric without changing its
geometry. HeritageHall adds two distinct cutaway rear halls, entirely outside
the cage; no roof over gameplay or new shadows/lights/collision.

- Locomotive: green boiler/cab, brass bands/rivets, static wheels/spokes/bielle,
  smokestack with six-particle steam, rail/sleepers, signals, crates and track sign.
  Train remains parked: wheels do not spin while it is stationary.
- Clockwork: ivory dial, fine brass rim, quarter numerals and hour ticks,
  differently paced hands; four opposed slow-turning gears, columns and violet
  window accents. No claim of mechanically simulated gear contacts or real time.

Changes stay in presentation code. Arena IDs, unlocks, physics, camera settings,
gameplay and imported source materials are unchanged. Existing furniture is
recoloured using instance overrides; sponsor boards are excluded.

## Validation

Native heritage_halls_test.gd: HERITAGE_HALLS 371/371, exit 0. Bounds/cost/lighting/
collider/physics metadata assertions; both real Match.tscn selections verified
with isolated save path. Captures for default/wide/playable/broadcast and actual
match generated; actual match and playable views inspected. No script/shader
errors, only existing ReplayOverlay anchor warnings.

New decorative geometry only: Locomotive 5,292 triangles / 9 MultiMesh families;
Clockwork 5,340 triangles / 18 MultiMesh families plus clock meshes/labels.
No full FPS benchmark; imported shared bleachers/shelters remain the dominant
existing polygon cost. Geometric bounds are not an automated all-camera occlusion
proof. Full historic frozen-scene-count suite not run, as these replacements
deliberately change those counts.

Officina native regression still passes: 13,440 triangles; STEAM_WORKSHOP and
WORKSHOP_MATCH zero failures. Its isolation comparison now uses unchanged
Cattedrale because Locomotive is deliberately redesigned by this task.

Stylistic result is a lightweight 3D reinterpretation, not photoreal 2D parity.
