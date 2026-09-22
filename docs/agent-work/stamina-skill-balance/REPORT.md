# Rally stamina: skill-first tuning

Implemented in canonical 11m, with equivalent JS and Godot rules.

## Contract

- Smooth slowdown starts below 70% energy, capped at 25% (previously 60% / 12%).
- No input delay, new random roll, forced miss, ball-speed reduction or rally time limit.
- Fatigue no longer shrinks the timing window. Existing movement, charge and glass timing rules remain.
- Shot execution demand combines squared charge (0.40), movement reduced by split-step (0.30), imperfect timing (0.80), and overhead effort (0.15). Demand is clamped to 0..1.
- Assessment energy is `1 - 0.85 * fatigue * demand`. It feeds existing quality/risk; the direct quality loss is capped at 0.068. A planted, perfectly timed tap has identical quality/risk at full or minimum stamina. Full-power overheads retain an effort penalty even with good timing, but good timing is still beneficial.
- Movement slowdown opens court space: winning placement is the intended way to shorten exchanges, rather than mandatory errors or weaker/slower balls that prolong them.
- Continuous recovery coefficient halved to 0.004; resting still recovers slowly. Contact costs and resistance differences preserved. Each athlete retains their energy when control switches; all reset between points.

## Verification

- JS stamina test passed, three deterministic match seeds (12345, 999, 2024), 12/15/15 completed rallies, longest 9/10/11 hits. These scripted inputs are regression coverage, not human playtesting or proof of optimal rally duration.
- Godot stamina test: 1653/1653, including 324 cross-language fixtures, execution-demand parity, a 45-shot assessment matrix, protected control, forced-shot risk, split-step advantage, movement, pause, switching and reset behavior.
- Godot shot logic: 675/675 across 35 scenarios.
- Godot timing feedback: 100/100.
- 30-second controlled effort scenario ends at 63% energy; repeated smash scenario reaches the 15% floor. 10-second controlled scenario stays at 88.5%, unaffected by slowdown. Results agree at 30/60/120Hz.

## Remaining validation

Live player feel still needs playtesting, particularly long defensive rallies and high-stamina athletes. No claim that every rally is shorter or that existing shot errors have been removed. No gameplay saves changed; no commit or paid API call.
