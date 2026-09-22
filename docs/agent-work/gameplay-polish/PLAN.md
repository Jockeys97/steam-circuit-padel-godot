# Gameplay polish: readable, skill-led doubles

Canonical 11m only; direct implementation, preserving existing dirty stamina,
outfits, UI and animation work. No commits, paid services or save changes.

## Contract

1. Human teammate positions only: no new autonomous contacts in solo/manual,
   semi, auto-selection, co-op or PvP. Keep explicit tactics. Stabilize covering
   lane near centre and avoid crossing directly through the active player's lane.
2. Preserve lob/chiquita physics and first-bounce policy. Validate deep lobs create
   recovery time, short lobs remain attackable, and tactics allow advancing behind
   placement rather than granting an artificial buff.
3. Evaluate support reaction without crippling normal recovery. Keep the existing
   recovery when adding a delay breaks the smash-defence audit. Never increase
   speed/reach, teleport, or force misses to end points. Fatigue
   must also affect responder travel estimates, not only actual movement.
4. Modest roster-based attack/patient/balanced style biases in shot selection and
   offensive depth; same difficulty skill, contact legality and physical limits.
5. Visual follow-through can blend back to moving locomotion after its contact
   and most of the follow-through; never delay input or change simulated position.

## Validation and scope guard

Preserve JS/Godot gameplay parity. Add deterministic boundary tests for teammate
coverage/no auto-hit, receiver reaction, style differences, fatigue forecasts and
animation recovery. Run existing contact, attack, tactics, stamina and animation
audits, plus seeded before/after match samples. Sampled rally length is evidence,
not a promise about human enjoyment. Render a real Match smoke capture if viable.
Do not add more precision penalties, controls, timers or guaranteed finishers.
