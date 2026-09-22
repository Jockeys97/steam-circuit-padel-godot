# Low contact posture — direct implementation

Canonical 11m / codex/integrate-arena-11m. Existing concurrent edits preserved;
no simulation, balance, JS, asset generation or paid API changes.

- View latches observed ball height at swing edge (visual approximation, not a
  new authoritative contact event). Height below 38 progressively requests flexion,
  capped at height 8. Overhead smash, bandeja, vibora and serve are excluded.
- Rig locally caches three strengths of adapted source clips. Thigh/knee/ankle
  rotations flex by at most -18/+36/-18 degrees. Pelvis correction retains the
  original mean foot anchor, not full per-foot IK. Wrist/upper body tracks remain
  those of the source shot. No root motion, timing or trajectory change.
- Flexion recovers over the existing follow-through; new high strokes, movement
  recovery, and point reset do not retain an old crouch.
- Native screenshot /tmp/padel-low-contact.png inspected: Fiamma and Colosso,
  normal/low contact pairs. Static pose review, not a full interactive match.
- Headless low_contact_pose_test: 495/495 (six athletes, base/Mythic, five
  stroke clips, mirrored view integration, latch/reset, completion and foot anchor).
- fluidity_animation_test: 163/163. racket_hand_follow_test: 90 poses, failures=0.

Limit: mean-foot compensation is not individual foot planting; existing source
animation foot motion is retained. Adaptation starts at the observed hit, not an
anticipatory prediction. First use bakes a bounded 25-sample per-instance clip.
