# Anticipation and look layers — athletes wind up before contact and follow the ball

**Answer:** 92 % of the rally strokes in a measured match now start from a wound-up upper body (median weight 0.85, the cap), against 0 % before; chest and head follow the ball within ±55°. The simulation is untouched: the M1 digest is byte-identical.

Owner request 2026-09-23: *«a livello di gameplay ci sono animazioni da aggiungere per la fluidità?»* → points 1 (anticipation) and 2 (look at the ball) approved with *«procedi»*.

## Findings (before)

- The sim reports a stroke only on its contact tick (`src/sim/sim.gd:1852-1854`, `paddle.swing = 1.0` inside the hit). The rig therefore starts every stroke at its contact frame with no blend (`src/character/athlete_rig.gd`, `play_stroke_at`: *"Contact is authoritative: never blend away its first pose"*). An athlete who was not charging (the AI, the partner) went from the `ready` stance to the contact pose in one frame.
- Facing was the side's base yaw plus the run-phase sway only; `face_towards(ball)` was deliberately unused (`game/athletes_view.gd` header, point 2) because turning the whole body changes the court composition.

## What changed

| File | Change |
|------|--------|
| `godot/src/character/athlete_pose_layer.gd` (new) | `SkeletonModifier3D` applied after the AnimationPlayer: (1) slerps the upper body (spine, shoulders, arms, right hand — never legs or hips) towards a stroke's backswing pose by a weight; (2) turns spine chain + neck + head about the rig's up axis by a yaw split over five bones. A modifier's result is not persisted into the bone poses, so every clip readout and existing test still sees the clip's own values. |
| `godot/src/character/athlete_rig.gd` | Installs the layer at build time. New API: `set_anticipation(stroke, weight, contact_phase)`, `get_anticipation()`, `set_look_yaw(deg)`, `get_look_yaw()`. The backswing pose is measured from each stroke's own clip (the frame before contact furthest from the clip's first pose), so authored and Meshy clips calibrate alike. Weight capped at 0.85; forced to 0 while a stroke plays and on the `play_stroke_at` call itself. Yaw clamped ±55°, NaN ignored. |
| `godot/game/athletes_view.gd` | `_contact_guess`: ballistic read of the ball (position + velocity + `ballGravity`) against the athlete's **depth reach** (`reach × player/aiDepthReach`, the same box as `Sim.can_hit`), with the partner-closer and lateral-reach filters; nothing during serve, point pause or result. `_sync_anticipation` ramps the weight from 0.42 s to 0.10 s before the predicted contact, clip chosen by `anticipation_stroke` (overhead above 70 px, else forehand/backhand by contact side — the rule of `meshy_stroke_for`). `_sync_look` eases the chest/head yaw towards the ball (rate 9/s), fading out for a ball behind the athlete and zeroed during a stroke. |
| `godot/tests/anticipation_look_test.gd` (new) | 97 checks — see below. |
| `godot/game/tools/anticipation_probe.gd` (new) | Out-of-band instrument: one headless match with rigs, reports how wound-up each hitter was on the tick before contact and the upper-body pose jump at contact with/without the layer. |
| `godot/game/tools/anticipation_frames.gd` (new) | Renders the same frame with the layers on and off (A/B) to a directory of your choice (never `game/out/`). |

## Verification

| Check | Before | After |
|-------|--------|-------|
| `tests/anticipation_look_test.gd` | — | **97/97** |
| `fluidity_animation_test` | 163/163 | 163/163 |
| `meshy_strokes_test` | 611/611 | 611/611 |
| `athlete_stroke_bridge_test` | 75/75 | 75/75 |
| `locomotion_weight_test` | 519/519 | 519/519 |
| `gameplay_polish_test` | 40/40 | 40/40 |
| `racket_hand_follow_test` | 90 poses, 0 failures | 90 poses, 0 failures |
| `low_contact_pose_test` | 495/495 | 495/495 |
| `roster_ready_pose_test` | 156/156 | 156/156 |
| `three_athlete_assets_test` | PASS | PASS |
| `athlete_rig_test` | — | 42/42 |
| `game_slice_test` | 319/327 | 319/327, **same 8 reds** (pack, locale size, timing marks, energy colour, `_arena_library` section, object count, outfit lineup — all pre-existing, diffed) |
| M1 digest (seed 12345, frozen, 30000 ticks) | `135cc16a…5e66f41` | `135cc16a…5e66f41` |

`anticipation_probe.gd -- --ticks=12000` (tier 2, scripted human vs sim AI, 4 rigs):

```
strokes=65 wound_before_contact=60 (92%) median_weight=0.85 predicted_clip_matches=27/60 look_max_deg=55.0
CONTACT_JUMP_DEG n=76  with_layer: median=312 p90=558   without_layer: median=414 p90=646
```

The contact jump (sum of the upper-body bone rotations between the tick before contact and the contact frame) drops by about a quarter at the median. The jump does not reach zero because contact remains the stroke's authored frame and the predicted clip is right only 27/60 times: the view cannot know the sim's `actionIntent` before the hit (slice, lob, volley, wall-angle are chosen at contact). A wrong prediction still winds the same arm back, so the contact reads as a swing either way.

`anticipation_frames.gd` (1280×720, opengl3, seed 20260916): three A/B pairs; the layers change 4,254–5,680 pixels per frame, all inside the athletes' bounding boxes (x 186–1084, y 173–609). A vision read of `ant-1-player-on.png` reports natural poses and no contortion — a weak check, stated as such.

## Correction accepted from the owner (2026-09-23): «è troppo esagerato quanto si piegano nell'animazione»

Measured, then bounded — two separate excesses, both now capped by data:

| What | Before | After |
|------|--------|-------|
| Low-contact adaptation (ball under 38 px): total knee flexion on a groundstroke | **100–110°** (the clip's own 15–72° **plus a flat +36°**) — a deep squat | **49–78°**; the added part backs off per sample until the knee is under `LOW_CONTACT_MAX_KNEE_DEG = 58°`, so a clip that already crouches gets almost nothing |
| Anticipation wind-up: racket-hand travel from the ready stance | 0.60–1.11 m (maestro `meshy_drive` 1.11 m) — a tennis-style take-back | 0.23–0.58 m at the cap (drive 0.43, backhand 0.30, slice 0.48, smash 0.58 — an overhead raise *is* half a metre); every joint is now bounded by `PREP_LIMIT_DEG` (spine ≤ 6°, shoulder ≤ 8°, arm ≤ 16°, forearm ≤ 13°, hand ≤ 8°) and the wind-up tops out at `ANTICIPATION_MAX = 0.60` |

### Second pass: the owner's actual complaint was the *shape* of the preparation

«quello in preparazione, quando si prepara il colpo, sembra quasi si protegga con la racchetta» — not a size problem, a direction problem. Measured by forward kinematics over each clip's own rotation tracks (validated against the animated skeleton: **0.0000 m** difference on every sampled frame), in the rig's local frame where **+Z is towards the net**, so a take-back is `z < 0` and a racket held across the chest is `z > 0`:

| Clip | Frame the OLD rule picked (furthest from the clip's first pose) | Frame the NEW rule picks |
|------|---------------------------------------------------------------|--------------------------|
| `meshy_backhand` | `z = +0.31` — **in front of the chest: the shield** | `z = -0.40` |
| `meshy_drive` | `z = -0.34` | `z = -0.32` |
| `meshy_slice` | `z = -0.29` | `z = -0.51` |
| `meshy_bandeja` | `z = -0.25` | `z = -0.41` |
| `meshy_smash` | no wind-up at all (score under threshold) | `z = +0.03`, **0.55 body-lengths above the shoulder** — the overhead raise |
| authored `drive`/`slice`/`lob`/`serve` (placeholders) | `z = +0.09…+0.42` — **shields on every frame** | rejected (`z` in front, hand not above the shoulder) → no wind-up, except on `maestro` where the clip does hold a real take-back at `z = -0.23` |

A frame now counts as a preparation only if it takes the racket **behind the torso plane** (`z ≤ -0.10`) **or** **above the shoulder without pushing it forward** (`z ≤ +0.10` and hand ≥ 0.10 body-lengths above the shoulder line, both read from the skeleton at that same frame). "Raised" is measured against the athlete's own **ready** hand — not against the clip's first frame, which for the smash is *already* overhead at 1.50 m and was silently disqualifying the stroke.

The wind-up does **not** bend the torso: measured torso pitch (Hips→Neck against up) changes by **+0.0°** in every athlete and stroke, at any weight — it is a twist plus an arm raise, and it touches no leg or hip bone. So "si piegano" cannot be the anticipation's torso; the numbers above say which parts actually fold.

Instruments: `game/tools/low_contact_probe.gd` (knee flexion, clip vs adapted), `game/tools/torso_probe.gd` (torso pitch + hand travel per stroke), `game/tools/windup_scale_probe.gd` (hand/head travel against weight), `game/tools/prep_frame_probe.gd` (which frame each clip's wind-up chooses, and where the racket ends up), `game/tools/bend_frames.gd` (the side-by-side frames, `docs/agent-work/fluidity-2026-09-23/`; `--stroke=<clip>` picks the stroke). Bake cost unchanged: ~1 ms per clip, then cached.

Suites after both passes: `low_contact_pose_test` 495/495, `anticipation_look_test` 97/97, `fluidity_animation_test` 163/163, `meshy_strokes_test` 611/611, `roster_ready_pose_test` 156/156, `athlete_rig_test` 42/42, `athlete_stroke_bridge_test` 75/75; `game_slice_test` 319/327 with the **same eight reds** (outfit lineup, shipping pack, locale sizes, timing marks, energy fill, energy colour, `_arena_library` section, object count); M1 digest `135cc16a…5e66f41` unchanged at 30000 ticks (run with the args from `tools/parity-godot/README.md` — the wrapper needs `flock`, which macOS does not have). `anticipation_probe.gd --ticks=12000`: 92 % of strokes still wound before contact, median weight 0.85 → 0.60 after the cap.

## What this does NOT prove

- **The feel.** Whether the wind-up reads as smoother on screen at 60 fps is the owner's verdict at the pad; no suite measures that.
- **Clip choice.** The wind-up predicts forehand/backhand/overhead only; 55 % of predictions differ from the clip the sim then plays.
- **Human charging.** When the human charges, `prepare` already plays; the layer adds on top of it. Not measured separately.
- **Performance.** One modifier per rig (4), ~10 slerps + 5 quaternion products per rig per frame; not profiled.
- The racket hand follows the modified pose (BoneAttachment3D, measured by the test); no new racket/ball contact alignment was checked.

## Environment

macOS, Godot 4.7.2 at `/opt/homebrew/bin/godot`, suites run directly (no `run.sh`, which needs `flock`/`timeout`). Worktree `~/Documents/steam-circuit-padel-11m`, branch `codex/integrate-arena-11m`, HEAD `067584e`; not committed.
