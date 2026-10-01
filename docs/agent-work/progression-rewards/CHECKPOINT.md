# Progression rewards — 2026-09-27

Implemented directly with user authorization. No commits or pushes.

- Normal match CC unchanged. Tournament title +200 repeatable, first title +250.
- Career promotion +125 OR perfect season +250; first advance from each numbered season +100. First finale +600.
- After season six: Industry, Elements, Cosmos Master Cups rotate within the existing career flow. Existing 2/3 promotion and 3/3 title rules retained. First perfect clear of each cup +300, permanent per-cup receipt. Calendar intersects theme courts with available courts; fallback never grants locked courts. No separate new mode or simulation changes.
- Wallet, lifetime milestone flags and match receipt are written atomically in the existing economy record. Optional extra field preserves old saves. No retroactive grants for past matches. LUCALE behavior, challenge unlocks and prices unchanged.
- Result screen itemizes bonuses in IT/EN; mode setup describes rewards and Master Cup rules. Tournament trophies remain distinct from career unlock trophies.

Checks: milestone_rewards_test 16/16; career_audit 225/225; emporio_ost_test 105/105 (resource/allocator warnings at exit); diff whitespace clean. No manual controller/visual playthrough yet. Tune rewards from actual player completion times, not theoretical maximum income.

Files: milestone_rewards.gd, economy_service.gd, career_rules.gd, match_controller.gd, mode_screen.gd, ResultScreen.gd, locale_data.gd, milestone_rewards_test.gd. Other pre-existing dirty changes preserved, including overlapping audio changes in controller/locale.
