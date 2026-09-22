# Periodic train transit

The formerly static train is now grouped separately from rails, signals, crates
and hall. It waits off-screen for 60–90 seconds of active match ticks (local seeded
RNG, no simulation RNG consumption), then waits for state.pointPause > 0 before
starting. Crossing speed 2.8 m/s, x -26 to +26, entirely behind the far glass.
It can finish crossing after the next rally starts: the game never delays a serve.
After exiting it waits another 60–90 seconds. No additional train copies.
Spokes rotate with displacement; steam follows its parent. Stationary crates and
signals moved clear of the track corridor, still outside the playing cage.

Train motion uses the existing fixed match tick; pause/replay do not advance it.
Scene switching frees it; first match tick resets scheduling. Match end hides it.
Audio is a quiet locally synthesized one-second looping rumble on the existing
SFX bus, with position envelope. Existing master volume and mute are respected;
pause suspends playback. No horns, samples, downloads, new bus or paid API.

Native passing_train_test --capture: PASSING_TRAIN 19/19, exit 0. Timer expiry
during rallies, point-break triggering through real match tick, travel speed,
pause freeze/audio pause, mute, zero volume, exit, end and reset verified.
Native left/centre transit captures inspected. No listening-based sound-quality
claim or full performance benchmark. Actual visual bounds remain outside court.
Existing ReplayOverlay anchor warnings are unrelated.
