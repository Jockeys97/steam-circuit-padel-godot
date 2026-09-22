# Egeo environment pilot

Approved scope: correct visible sky-panel edges and shallow scenery in Egeo,
including low camera angles. Other arenas remain unchanged pending acceptance.

Architecture: true environment sky; separate distant sea/islands and near 3D
architecture. No growing billboard to disguise the defect. Reuse source assets
without modifying shared originals. Presentation only; no court/gameplay/camera
changes, extra shadow lights, paid generation or commit.

One end-to-end Flash implementation bundle owns arena module edits, focused
tests and native visual captures. Astra owns contract and acceptance. Preserve
dirty source baselines and report differences against them, not HEAD.

Acceptance: all existing camera presets, particularly lowest angle, show no
sky-panel boundary or void seam; court readable/unobstructed; Egeo selected through
actual Match path; other-arena isolation; bounded extra geometry and no runtime
mesh rebuilding. Automated tests plus native before/after visual evidence.

Review performance structurally, not invented FPS gains. Existing diagnostic audit
uses forced drawing and cannot certify real gameplay framerate. Shared environment
must not leak Egeo resources into other arena builds.

Worker: /root/egeo_environment. Checkpoints five minutes; soft handoff fifteen
minutes. Static route configuration passed; inference remains unverified.
