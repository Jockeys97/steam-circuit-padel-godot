# Independent review — tasto A: percorso controller→frame→simulazione

Owner: Review. Stato: audit (non certifica i lavori altrui). Nessun Godot avviato, nessuna mutazione; solo lettura sorgenti e diff sporco.

## Verdetto breve
Il percorso committed `input_map.gd → match_controller.gd (apply_frame/advance_frame) → Sim.update_match` è coerente col riferimento e coperto da due harness reali (`tools/controller-parity.mjs` per il campionatore, `tools/sim-port/*` + `shot_logic_parity_test.gd` per l'handoff alla simulazione). Il diff sporco su `match_controller.gd` è **solo presentazione** (trail + anello spin, `_sync_ball_cues`), non tocca l'input. Restano 4 punti ciechi reali, il primo dei quali è il più probabile a produrre una differenza percepibile su A, e nessuno è ancora coperto da un test eseguibile.

## Il diff sporco (non ignorato)
`git diff godot/game/match_controller.gd` = 109 righe inserite, tutte: costanti colore/soglia (righe 286-295), nodi trail/spin-ring (`_build_scene`, 680-714), `_sync_ball_cues` + chiamata in `_sync_views` (1197-1245). Legge solo stato simulato, non calcola nulla, non tocca `sample`/`apply_frame`/`advance_frame`/`tick_fixed`. **Non spiega** la sensazione "A diverso dal 2D": il percorso input è codice committed, non sporco.

## Punti ciechi, ordinati per rischio

### B1 — Nessun test esercita la lettura hardware reale di Godot (ALTO)
Tutti i test del campionatore sottoclassano `input_map.gd` e sovrascrivono `_button/_axis/_key_pressed` (`tests/input/controller_trace.gd:5-11`, `tests/input/shot_sequences_test.gd:5-15`). L'unica asserzione sul percorso nativo (`shot_sequences_test.gd:86-93`) gira con `device == NO_DEVICE`, quindi `_button` ritorna false comunque: non legge mai un pad connesso.
Non coperti: `select_device`/`assign_devices` (`input_map.gd:324-347`), `device_has_activity` (`:305-314`), e la mappatura asse-trigger.
**Differenza concreta**: il riferimento legge i trigger come `pad.buttons[6]?.value ?? (b(6)?1:0)` (`js/main.js:834-835`); Godot legge `clampf(_axis(JOY_AXIS_TRIGGER_LEFT), 0, 1)` (`input_map.gd:168-169`). Se un driver espone il trigger a range pieno −1..1, una mezza pressione (−0.5) viene clampata a 0 invece di 0.25: `splitStep`/`sprint` — e quindi la precisione del colpo via `input.sprint` (`sim.gd:2551`) — leggono male. È la cucitura non verificata a più alto impatto sul colpo A.

### B2 — Il secondo giocatore non è confrontato col riferimento (MEDIO)
`controller-parity.mjs` esegue solo `pollGamepadGameplay(gamepad,…)` + `getInput()` (`:37`): mai `getInput2()` né `pollGamepadGameplay(…, isSecond=true)`. `shot_sequences_test.gd` testa `primary=false` ma contro attese scritte a mano, non contro il JS congelato.
**Differenza concreta trovata**: `analogAim` del P2. JS `getInput2:1114` usa `Boolean(controllerAim2?.x || controllerAim2?.y)` (false quando aim è esattamente 0,0); Godot `input_map.gd:225-228` mette `analogAim=true` ogni volta che sta caricando. Divergenza a livello di campo, **effetto simulativo nullo** (con aim 0,0 il valore letto è 0 in entrambi i rami, `sim.gd:2631-2642` / `control_paddle_charge:2508-2515`). Da dichiarare, non nascondere in una tolleranza.

### B3 — Il latch one-shot è una divergenza deliberata e documentata dal riferimento (MEDIO, viva a >120 Hz)
JS: `getInput()` azzera i flag one-shot subito dopo aver costruito l'input (`js/main.js:1082-1092`), PRIMA dell'accumulatore; un press+release su un frame con zero sub-step è **perso** nel browser.
Godot: il latch sopravvive ai frame senza sub-step (`match_controller.gd:965-967` azzera solo `if steps > 0`; header `:20-23` e `:1001-1002` lo dichiarano "DELIBERATE DIVERGENCE"). Vivo a 144 Hz, dove il browser lascia cadere ~1 one-shot su ~1.2 frame che sarebbero a zero step, e Godot lo conserva. Godot è più reattivo, in un modo che l'harness **non** modella (alimenta a granularità di frame con mappatura 1:1). Il test frame-clock (`game_slice_test.gd:639-716`) asserisce il comportamento Godot come fix H-3 ma non lo confronta col drop del browser.

### B4 — Due loop rAF nel browser, uno solo in Godot (MODEL TIMING, non bug)
JS: `gamepadLoop` (`js/main.js:1042-1045`) e `gameLoop` (`:1236`) sono due `requestAnimationFrame` indipendenti; l'ordine entro il frame è quello di registrazione, non sincronizzato. Godot: `_process` (`match_controller.gd:1016-1030`) campiona e avanza in una sola funzione, con i latch di bordo aggiornati esattamente alla cadenza del frame di simulazione. Un bordo rilevato in `pollGamepadGameplay` può cadere su un frame sim diverso nel browser, specialmente dopo un frame perso in un loop. "Stessa timeline di input → stesso stato sim" vale solo assumendo i due loop in lockstep — assunzione che nessun test asserisce. (Il percorso tastiera è anch'esso strutturalmente diverso — eventi in JS `keys` vs polling `Input.is_physical_key_pressed` in `input_map.gd:266-273` — ma fuori scope: A è polled in entrambi.)

## Sequenze discriminanti minime (per gli artefatti differenziali in arrivo)
1. **Frame senza sub-step + press/release**: due frame a 1/240 ciascuno (mezzo FIXED_STEP), primo `hit=true`, secondo `hit=false`. Browser perde, Godot conserva e spara al sub-step del secondo frame. Discrimina B3.
2. **Trigger a mezza corsa** (se pad reale disponibile): LT/RT a metà, assert `splitStep`/`sprint ≈ 0.5` su Godot vs browser. Discrimina B1.
3. **Takeover multi-pad**: due pad connessi, A su pad 2 a metà partita, assert che il colpo parta da pad 2 e che l'A tenuto su pad 1 non spari. Esercita `select_device`/`assign_devices`/`awaitingGameplayRelease` (B1), oggi mai esercitati.
4. **P2 in carica con stick centrato** (coop): P2 carica A con stick al centro, assert `analogAim` (campo) e aim risultante. Discrimina B2 (atteso: effetto sim nullo).
5. **Latch del modificatore**: A tenuto, RB premuto durante la carica (rilascio → chiquita vs drive); assert variante latched all'inizio della carica (`input_map.gd:198-202`; logica coperta in `shot_sequences_test.gd:37-38`, da rifare su pad reale).

## Checklist di certificazione (per l'artefatto differenziale, verificata da Review)
- [ ] Hash di entrambi gli alberi registrati; JS congelato read-only confermato.
- [ ] Replay usa le funzioni di input di produzione (`sample()`/`getInput()`), non riscritture; i run adapter-only e sim-only sono etichettati come tali.
- [ ] Harness di parità exit 0 sui campi campionatore (`controller-parity.mjs`) E sull'handoff sim (`shot-intent-compare.mjs`), tol=0.
- [ ] Red-control: una COPIA corrotta di una traccia produce exit ≠ 0 (infrastruttura già presente: `controller-parity.mjs:84`, `shot-intent-compare.mjs:130`, ma nessun run lo fa ancora).
- [ ] Schedule frame pinnato (seed + pattern fps): 120 tick/secondo-muro a 30/60/240 (`game_slice_test.gd _frame_clock_contract`).
- [ ] Le divergenze deliberate note (latch one-shot a >120 Hz; campo `analogAim` P2) sono elencate nella lista known-differences dell'artefatto, non nascoste in tolleranza.
- [ ] Percorso lettura device reale (select_device, asse trigger) esercitato, OPPURE dichiarato esplicitamente fuori scope con nota di blocco.
- [ ] Percorso `getInput2`/secondario incluso OPPURE dichiarato fuori scope.

## Limiti di questa review
Nessun Godot eseguito (divieto per Review mentre Port gira). Tutte le affermazioni sono da lettura sorgente e da diff; nessuna divergenza è stata riprodotta in esecuzione, quindi nessuna è presentata come causa del sintomo del giocatore (gate umano: Luca giudica la sensazione). B1 è il candidato più probabile a produrre una differenza su A, ma è una previsione riproducibile, non una radice dimostrata.
