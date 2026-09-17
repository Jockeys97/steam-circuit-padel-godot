# UIR-00 — "before" capture register (frozen)

The pre-existing UI captures under `godot/game/out/`, registered at commit
`252ff6074039372ebbf8ec682f9adda0e9c80d03` (2026-09-16, 23:57-23:59 local) before any
UI-recreation work lands. These files are read-only from here on: they are the "before"
half of the GATE-A capture pairs and of the final acceptance, and no ticket in the pack
writes into this directory except UIR-24/UIR-09's own `ui-*.png` / `ui-prototype-*.png`
namespaces.

Register method: `stat -f%z`, `stat -f%Sm`, `shasum -a 256`, `file -b` per file, run in
`godot/game/out/` on the commit above. All twenty are `PNG image data, 1280 x 720,
8-bit/color RGBA, non-interlaced`.

## Register (20 files)

| File | Bytes | mtime (local) | sha256 (first 16) | sha256 (full) |
|---|---|---|---|---|
| arena-abissale.png | 191066 | 2026-09-16 19:21:41 | 03d856686243cbb2 | 03d856686243cbb2c4b3f9dbf76634c7a12680de5283a78dda28ed9f0aef8068 |
| arena-caldera.png | 187352 | 2026-09-16 19:21:41 | 3d50433d76255709 | 3d50433d76255709db43d7be2d47e03cd687779e31b8a73eb07c25b20293d087 |
| arena-cattedrale.png | 187222 | 2026-09-16 19:21:39 | 1f48bc336a7260cd | 1f48bc336a7260cde50f682bffaa465413786c5ac7d31bea1fe67e254ec26920 |
| arena-clockwork.png | 187250 | 2026-09-16 19:21:38 | 5818797c9fe4b575 | 5818797c9fe4b57551e15552c85efb77b68e37ddff5572313efbcd49c5833faa |
| arena-forgia.png | 187129 | 2026-09-16 19:21:39 | 9d112275bbca6dcc | 9d112275bbca6dcc158bc8dbfe373e55713f97852acbc7d6e2d9adcd6ba7dd9b |
| arena-locomotive.png | 187206 | 2026-09-16 19:21:38 | b541e19ad99aa79e | b541e19ad99aa79e65043f1a470a186a38ae3550ba1a213377443192fbc1e643 |
| arena-officina.png | 187243 | 2026-09-16 19:21:37 | faf2738196c3c1a1 | faf2738196c3c1a15aed76054ca90a4f1e562d8d9d31b8a54a809cccf0ce3cc3 |
| arena-orrery.png | 191139 | 2026-09-16 19:21:42 | 3c46b74493c17c3b | 3c46b74493c17c3b9af0f373424ce2213205f8a5476aff6941eb16d232dd81ae |
| arena-tempesta.png | 186973 | 2026-09-16 19:21:40 | 893dba7ceecb3aa3 | 893dba7ceecb3aa3606d7ba589ee952a551039c08404e39d8e3e39978a194316 |
| hud.png | 219028 | 2026-09-16 19:14:55 | babafd27fca337a3 | babafd27fca337a35d18b1f29f4820767834ba865749f76f1accf081b3d3446b |
| menu-demo.png | 120951 | 2026-09-16 18:08:35 | d9a93c0075109e6d | d9a93c0075109e6d22e5a341adf7486dc68403fa100dda85ebe61fb369d1619f |
| menu-full.png | 137938 | 2026-09-16 18:08:35 | 5d5dd6c256e1cb6b | 5d5dd6c256e1cb6bb93478adfdbc03457512fedf5ff325163d2d817502cc8619 |
| menu.png | 120852 | 2026-09-16 19:14:50 | bb2d929c09f8d703 | bb2d929c09f8d7030ab6da25f63b47e959fc6f103e6b9b377eec390d6d777202 |
| mode-career-screen.png | 72785 | 2026-09-16 18:08:35 | 8d410f8c65d083b8 | 8d410f8c65d083b8237c5a34f653879a0ddbccf27b86c1844d4f19311a504b04 |
| mode-career.png | 207862 | 2026-09-16 18:08:35 | d901f4c50ed7a62a | d901f4c50ed7a62adebafc1d8289f700e47e37b84eb6033eec8202c06a3279da |
| mode-drill.png | 225193 | 2026-09-16 18:08:35 | d63451473923cb72 | d63451473923cb729e9efe4094735d75e13a802428a0a4d77f0c15c08e6ec9f2 |
| mode-tournament.png | 202375 | 2026-09-16 18:08:35 | 72b0e866f127cd97 | 72b0e866f127cd97420792df4086c82ffa6917aed601d1cdce24c1e435383740 |
| quickmatch-serve.png | 195475 | 2026-09-16 19:14:55 | 0a2696dd78438215 | 0a2696dd784382151dcd9f6a84bebdfd541aa77d85e33dc58f7b39b4b62e2f20 |
| rally.png | 217086 | 2026-09-16 19:14:55 | 63942951e393285d | 63942951e393285df69c844a0fb6b0ea1e5dd8ca94e8584d4cacf481dcecd970 |
| result.png | 216317 | 2026-09-16 19:14:58 | a1cce6599531f03b | a1cce6599531f03bf8f7d57132a4854d77947591dbe35a43160a323124632636 |

## The two batches, as found

- **Regenerated 2026-09-16 19:14-19:21** (11 files): `menu.png`, `hud.png`,
  `rally.png`, `quickmatch-serve.png`, `result.png` at 19:14:50-19:14:58;
  `arena-officina`, `arena-locomotive`, `arena-clockwork`, `arena-cattedrale`,
  `arena-forgia`, `arena-tempesta`, `arena-abissale`, `arena-caldera`,
  `arena-orrery` at 19:21:37-19:21:42 (nine arena files).
- **Older 18:08 batch** (6 files): `menu-full.png`, `menu-demo.png`,
  `mode-career-screen.png`, `mode-career.png`, `mode-tournament.png`, `mode-drill.png`.

Count check: 14 + 6 = 20, the full `godot/game/out/*.png` set (the directory holds
nothing else with a `.png` extension). The handoff's split ("menu, hud, rally,
quickmatch-serve, result, arena-*" vs "menu-full, menu-demo, mode-*") is confirmed by
mtime with the 18:08 side holding six names rather than the three the prose implies —
`mode-career.png` and `mode-drill.png` are in the older batch and are named by the
`mode-*` wildcard.

## Not done here, on purpose

- No capture was re-run: `./run.sh shots` cannot run on this Mac (`xvfb-run`,
  `flock`, `timeout` absent — measured, see `uir-00-baseline-gates.log`), and the
  ticket's native capture command is UIR-24's to validate on first use.
- The 20 PNGs were inspected with `file`/`stat`/`shasum` only; none was opened,
  converted or rewritten.
- `.import` sidecars next to the PNGs (`godot/game/out/*.import`) are generated
  files, not part of this register; the three untracked `godot/game/arenas/art/
  *.webp.import` files belong to another lane and were left untouched.

## Pointer (added 2026-09-17, post-pull closeout)

The register's "before" set is preserved **copy-verified at `integration-prep/before-set/`**
(`integration-prep/SHA256SUMS.txt` carries the same hashes; spot-checked again by the closeout
pass: `quickmatch-serve.png 0a2696dd…`, `menu.png bb2d929c…`, `hud.png babafd27…`,
`rally.png 63942951…`, `result.png a1cce659…` — all match). The GATE-A pack's BEFORE panels
(`gate-a-review/pairs/*-before-ported-*.png`) are copied from there, not from the working tree:
the working tree's tracked plan-lane PNGs at `HEAD` are the merge's stale renders, which is
exactly why this register and its `before-set/` copy are the before-evidence.
