# Team menu visual repair

Completed directly by Astra with user authorization after the Flash provider repeatedly returned HTTP 400.

Workspace: steam-circuit-padel-11m, branch codex/integrate-arena-11m.

Scope: CharactersScreen.gd, screen_characters_audit.gd, optional scroll capture in capture_ui.gd. Pre-existing changes to other UI, gameplay and assets were preserved. No commit or push.

Changes: localized header/back, compact right-aligned primary confirmation, separate role tags, 3:4 top-aligned portraits, stacked card content/actions, wrapped visible stats, colored names and action pills. The existing scroll container exposes content below the viewport. Selection, wardrobe, unlock and confirmation behavior is unchanged.

Validation: character audit 153/153; cross-screen legibility 664/664. The latter exits successfully but still reports resource leak warnings at shutdown. Real OpenGL captures cover all five character screen states plus the scrolled team view. The application keeps its configured 1280x720 logical canvas at larger window resolutions; no global stretch settings changed.

Evidence: shots/ and adjacent audit/capture logs. Captured baseline is under baseline/. No further provider retry is needed.
