# Integration review

Accepted in canonical 11m working tree, codex/integrate-arena-11m. Source f732998
selectively ported; unrelated dirty work preserved. Root reviewed loader changes,
render probe and Torii capture. Uniform scaling of seven deep assets accepted to
keep them visible within rear-glass/backdrop bounds; repeated asymmetric meshes
now center correctly. All 50 GLB remain intact, 145 decorative instances mounted.

Root staged only the 205 GLB/JPG/PNG binary paths from the source arena tree using
existing LFS attributes. All pointer hashes/sizes match working files and local
LFS objects. ASSET LFS PASS checked=253 lfs=218 legacy=35. No commit or push;
code, sidecars and evidence remain unstaged. No history rewrite.

Kit spatial gate passes; selection 18/18, rendered captures 39/39. Kit suite
250/252 and world field-law 68/88 retain pre-existing bleacher/prop violations;
do not call the full suites green. Test baseline fixture is local ignored data,
so those fixture-dependent checks are not yet reproducible in a fresh clone.
See REPORT.md and baseline logs for exact evidence.

Rendered scene probe: kit visible vs hidden adds 0.31–0.59 ms/frame on this M4,
1280x720 OpenGL, one camera/preset. Not full-match FPS, not GPU timing, and not
a before/after measurement including procedural replacement. Process-lifetime
scene cache remains; exit logs flag unreleased cached nodes/resources. This
limitation is now exercised by new content, not evidence of clean teardown.

Worker /root/luca_arena_integration completed and stopped. Static route validated;
provider inference metadata not independently verified. No paid asset generation.
