# Fiamma: one paid forehand trial

## Runtime integration (subsequent user approval)

Activated only for Fiamma's drive/safe-drive intents. The original 28-joint
mesh and skin are unchanged. `tests/bake_meshy_fiamma.gd` maps 23 source joints
using global rest-space rotation deltas (including reversed spine naming),
retains target translations/scales, bakes 0.62 seconds and blends back to idle.
Runtime uses the compact `assets/athletes/animations/fiamma_meshy_drive.tres`;
the generated 24-joint mesh is not loaded by gameplay. Existing drive contact
phase 0.34 and speed 1.12 are preserved; source forward-swing sample 1.5 seconds
is aligned to that phase. This is visual calibration, not racket/ball IK.
Missing resource retains the existing procedural drive. Other athletes and
smash/wall-angle/volley/serve are unchanged. No further API credits consumed.
Three equipped poses were rendered on the original rig and inspected.
The historical trial-only gate below describes the state before integration.

User authorized a maximum of 18 credits for one trial. Actual charges: rig 5,
Prime motion 10, animation retarget 3; total 18. No retries or additional jobs.
Task IDs and confirmed SUCCEEDED states are in tasks.json (no credentials).

The current fiamma.glb was submitted as a copy with the roster height 1.74 m.
Downloaded outputs: fiamma-trial-rig.glb, forehand-prime.fbx,
fiamma-forehand.glb. Runtime models and gameplay were not replaced.

Godot 4.7.2 imported the result successfully. The motion is rigify_clip, duration
3.0333 seconds. The other 0.0667-second clip is the base pose, not the forehand.
Five rendered samples (pose-*.png) were captured; start, midpoint and recovery
were inspected. These are pose checks, not proof of ball/racket contact accuracy.

Important integration gate: generated rig has 24 joints, while the current
Fiamma uses the 28-joint Mixamo family. Do not directly replace the runtime mesh
or copy animation tracks blindly. Retarget the motion to the existing skeleton,
remove unwanted root motion, calibrate racket/contact timing and test recovery
before promoting. No runtime integration is claimed by this trial.

Live review:
`Godot --path godot --script res://tests/meshy_fiamma_preview.gd`

The preview intentionally displays the generated copy without the game racket;
it is for reviewing body motion, not the final equipped gameplay character.
