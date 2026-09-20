# Fiamma: four approved Meshy strokes

## Cost and scope

User approved 52 credits for smash, bandeja, backhand and slice on Fiamma.
The existing rig 01a0c025-13e7-77d4-96ac-8508fc33ba91 was verified and reused.
All eight tasks succeeded (4 Prime motion tasks x10, 4 retarget tasks x3):
52 credits consumed, no paid retries, new rig or extra animation jobs.
Task IDs/status/charges: tasks.json. Raw FBX and GLB outputs remain here.
No secrets or signed URLs are recorded. The generator requires MESHY_API_KEY
from its environment and refuses uncertain POST retries/budget overflow.

## Runtime

Only the original Fiamma 28-joint runtime model opts in; all others unchanged.
New compact resources: fiamma_meshy_{smash,bandeja,backhand,slice}.tres.
No duplicate runtime meshes, source animations or textures loaded in matches.
The original forehand remains active.

`tests/bake_meshy_fiamma.gd -- <stroke>` maps 23 source bones using rest-space
rotation deltas. Target positions/scales remain constant (no imported root
motion). Length/contact phase/speed follow existing shot recipes. Visually
selected source contact seconds: smash 1.0, bandeja 1.15, backhand 1.25, slice
1.1. Final 0.15 seconds blend to neutral. The generated bandeja had excessive
bowing: hip/spine pitch/roll are bounded and lower-body rotation contribution
reduced to 20%, preserving the generated arm motion.

Backhand selection uses ball contact X relative to the paddle, with opposite
sign for near/far teams and a 6-simulation-unit centre tolerance. It does not
use swingSide, because that encodes aim for human players. This only changes
presentation, not shot type, physics, timing, hitboxes or AI. Slice is the
forehand slice preset; no new backhand-slice/volley/run generations are claimed.
Other intents (serve, volley, cut-volley, lob, vibora, wall-angle) keep their
prior animations. Missing clips keep procedural fallback.

## Verification

- meshy_strokes_test.gd: 594/594, live dispatch, both court sides, unchanged
  other intents/models, contact phases, constant translation, finite bones,
  hand attachment, finish/recovery and repeated hits.
- meshy_fiamma_integration_test.gd: zero failures.
- fluidity_animation_test.gd: 163/163.
- racket_hand_follow_test.gd: 30 poses, zero failures.
- athlete_stroke_bridge_test.gd: 75/75.
- runtime-poses.png: original equipped model at preparation/contact/recovery;
  inspected after timing/posture corrections. This is not ball-contact IK.

Course remains unchanged: running and backhand volley are a later phase;
no credits were spent on them. No commit/push performed.
