# Port — continuazione su Sonnet 5: recupero, regressione a contatto, correzione minima

Owner: Port integrator (continuazione). Nativo: Sonnet 5 (subagent). 2026-09-17.
Recupero da due lanci precedenti morti per esaurimento quota provider (opencode-go 429),
non per problemi tecnici. Lavoro isolato in `/tmp/padel-shot-payload-fix/godot` recuperato,
non ricreato. **Nessuna promozione a produzione in questo lancio.**

## Verdetto

**Regressione reale confermata fino al CONTATTO, non solo a livello di coda.**
Correzione minima implementata e verificata GREEN, in isolamento. 0 SCRIPT ERROR
introdotti dalla patch. File di produzione NON toccati.

## Recupero del lavoro parziale

- `/tmp/padel-shot-payload-fix/godot`: copia isolata già presente (creata dal lancio
  `deleg_78418204`), hash dei sorgenti chiave verificati identici al checkout corrente
  prima di procedere:
  - `game/match_controller.gd` = `e1c75caf1625eb00f82ad4e728d039861446bf2669440513f7c81be45185c6d6`
  - `src/sim/sim.gd` = `f2d1e7f2023000fdd66bbe0b5c956d0b623217b448792c994ef730993bd7e0c3`
  - `game/input_map.gd` = `a1780ce43d2b64da2de8788d45f43b9eb186f6da14e05515669084affbf292af`
- Diagnosi ereditata (`review/FINAL.md`, `MAP.md`, `LOG.md`): il latch dei one-shot
  (`queued_one_shots`, `match_controller.gd`) sopravvive a un frame a zero sub-step,
  ma `shotVariant`/`slice`/`aim` no — non essendo in `ONE_SHOTS`. `sim.gd:2854-2857`
  (`queue_paddle_hit` per il secondo giocatore, `update_shot_control` per l'aim) allora
  ripiega su `"auto"` invece della variante realmente richiesta.
- Nessun test/harness precedente arrivava al contatto reale con la palla: era gap
  dichiarato esplicitamente da `review/FINAL.md` (punto 4). Colmato qui.
- Mancava `godot/tests/build/*` nella copia isolata (mai copiato dai lanci precedenti):
  rsync-ato dalla produzione (sola lettura, nessuna modifica) per permettere l'import
  headless completo — non è una modifica di produzione, è satisfare una dipendenza
  di caricamento della copia isolata.

## Prova della regressione (RED, pre-fix)

Nuovo test `tests/input/deferred_shot_payload_test.gd`, path reale
(`Match.tscn` → `apply_frame()`, la stessa funzione chiamata da `_process`), stato
allineato al bench già usato da `tests/audits/smash_input_audit.gd::buffered_smash`
(stesso atleta/arena/avversario, stessa posizione vicino rete, stessa altezza/velocità
palla — un bench dove "auto" vs "drive" è già noto essere decisivo per l'ammissibilità
allo smash, non cosmetico).

Sequenza:
1. Frame 1 (1/240s, zero sub-step): rilascio reale con `hit=true, shotVariant="drive"`.
2. Frame 2 (1/240s, neutro, nessun input): consuma il sub-step latched.
3. ~200 frame idle a 1/120s fino al contatto reale con la palla.

Comando:
```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /tmp/padel-shot-payload-fix/godot
$GODOT --headless --path . --script res://tests/input/deferred_shot_payload_test.gd
```

**Risultato PRE-fix (RED):**
```
ok release frame runs no sub-step (zero-substep setup)
ok hit is latched, unconsumed, after the release frame
ok neutral frame spends exactly one sub-step
ok the spent tick saw hit=true
# trace post-consume queuedShotVariant=auto playerSwingBuffer=0.272 smashPrimed=false
# trace shotType_after_fix_or_before=serve queuedShotVariant_last=auto
```

`queuedShotVariant` diventa `"auto"` (perso "drive") al consumo. La conseguenza REALE
osservata non è "smash invece di drive": è che il buffer diventa lo `shotBufferWindow`
generico (0.28s) invece dello `smashBufferWindow` (0.9s) che `can_prime_smash` avrebbe
impostato con "drive" preservato — sul bench usato la palla arriva *dopo* la scadenza
del buffer più corto, quindi **il colpo non parte affatto** (`shotType` resta "serve").
Con "drive" preservato, invece, `smashPrimed=true` e il buffer resta aperto abbastanza
per il contatto reale (vedi run GREEN sotto): risultato finale `shotType="drive"`.

**Confronto onesto auto vs drive (punto 2 dell'obiettivo tecnico):** un riferimento
esplicito che forza `queuedShotVariant="auto"` sullo stesso bench (bypassando il
controller, chiamata diretta a `Sim`) produce `smash-flat`. Quindi su QUESTO bench
"auto" e "drive" **non producono lo stesso colpo finale** — la differenza non è
cosmetica, è comportamentale (contatto mancato/rinviato vs contatto riuscito). Questo
non generalizza a "ogni A produce un colpo diverso": è il verdetto per lo scenario
provato, come richiesto dal charter.

## Correzione minima (GREEN)

File isolato modificato: `game/match_controller.gd` (diff completo in
`port/match_controller.diff`, 41 righe).

1. Nuova costante `HIT_PAYLOAD_FIELDS := ["shotVariant", "slice", "aim", "aimY", "analogAim"]`
   — tracciata leggendo gli usi reali in `sim.gd`: `queue_paddle_hit` (righe 2540-2543)
   legge `shotVariant`/`slice` al consumo, `update_shot_control` (righe 2644-2647) legge
   `shotVariant`/`slice` per `state.shotIntent`, e l'aim (`aim`/`aimY`/`analogAim`) è
   letto in testa alla stessa funzione (righe 2631-2633). Nessun altro campo del payload
   di hit è consumato al di fuori di questi.
2. Nuovo campo `queued_hit_payload: Dictionary`, popolato in `latch_one_shots()` SOLO
   quando il sample corrente porta `hit=true` — cioè esattamente il frame che oggi arma
   il latch — copiando i campi non-null di `HIT_PAYLOAD_FIELDS`.
3. `_with_queued()` applica `queued_hit_payload` sopra il sample corrente SOLO quando
   `queued_one_shots["hit"]` è vero (cioè un hit è effettivamente in latch da riprodurre)
   — non sovrascrive mai lo shotVariant di un hit fresco non differito.
4. Consumo/azzeramento: `queued_hit_payload.clear()` ovunque `queued_one_shots.clear()`
   già avviene — al consumo (`steps > 0` in `advance_frame`), a `start_match`,
   all'adozione di sessione, e in `_reset_transient_input()` (pausa). Un solo punto di
   scrittura (armo), un solo punto di lettura (consumo), stessi punti di pulizia del
   meccanismo esistente — nessun nuovo stato che possa sopravvivere a un reset già
   coperto.

**Risultato POST-fix (GREEN):**
```
# trace post-consume queuedShotVariant=drive playerSwingBuffer=0.892 smashPrimed=true
# trace shotType_after_fix_or_before=drive queuedShotVariant_last=auto
ok requested drive is preserved through the zero-substep frame (result=drive, auto-reference=smash-flat)
PASS 5/5
```
`queuedShotVariant` resta "drive" al consumo, `smashPrimed=true` (buffer lungo), la
palla raggiunge il contatto reale e il colpo finale è "drive" — coerente con la
richiesta originale del giocatore, non degradato. `EXIT=0`, nessun `FAIL`.

## Nessun replay/doppio fuoco, nessuna sovrascrittura, pulizia corretta

- La suite esistente `tests/game_slice_test.gd` (sezione `_frame_clock_contract`,
  righe 682-717) continua a passare invariata sulla copia con la patch:
  `ok the press is latched while no sub-step has spent it`,
  `ok the one-shot is consumed once and not left armed` — il meccanismo esistente non
  è stato alterato, solo esteso.
- Run completa: `$GODOT --headless --path . --script res://tests/game_slice_test.gd`
  → `EXIT=1` per 3 FAIL preesistenti e noti (skill `padel-godot-port-ops`, sezione
  "fresh-clone gotchas": pack non esportato, `js/render.js` non copiato nella copia
  isolata, `_arena_reference_spec` dipendente dal primo) — **0 SCRIPT ERROR**, nessun
  fail su input/one-shot/latch. Log: `/tmp/padel-shot-payload-fix/slice_check.log`.

## Script error: conteggio

- Run RED iniziale (prima di allineare `tests/build/*`): SCRIPT ERROR di import
  mancante (`BuildFlag.gd`), risolto copiando `godot/tests/build/**` dalla produzione
  (sola lettura) nella copia isolata — non è codice di produzione modificato, è un
  file mancante nella copia dal lancio precedente.
- Run RED/GREEN del nuovo test: 0 `SCRIPT ERROR` propri (i 72→123→... "SCRIPT ERROR
  Invalid assignment ... Nil" osservati nei log intermedi erano `_sync_views()` che
  chiama `Court.world_pos` su `_ball_view` non istanziato perché `load_models=false`
  nell'harness — preesistente al di fuori della patch, innocuo per l'headless, non
  legato al payload; il conteggio finale riportato sopra per RED/GREEN del test
  dedicato è quello depurato da questa causa nota una volta allineato `harness_mode()`
  — vedi log completi sotto).
- **Nessuno SCRIPT ERROR originato dal codice della patch stessa** (`queued_hit_payload`,
  `HIT_PAYLOAD_FIELDS`, `latch_one_shots`, `_with_queued`): verificato per grep mirato,
  nessuna occorrenza che referenzi quelle righe/simboli.

## File

- Copia isolata: `/tmp/padel-shot-payload-fix/godot` (cache `.godot` propria, unica
  istanza Godot alla volta, mai avviata insieme al gioco live PID 43135).
- Patch (diff vs baseline produzione): `port/match_controller.diff`.
- Test nuovo (copia isolata, promuovibile più tardi): `port/deferred_shot_payload_test.gd`
  = `tests/input/deferred_shot_payload_test.gd` nella copia isolata.
- Log: `/tmp/padel-shot-payload-fix/red_run3.log` (RED), `/tmp/padel-shot-payload-fix/green_run.log`
  (GREEN), `/tmp/padel-shot-payload-fix/slice_check.log` (suite esistente invariata).
- Journal: `/tmp/padel-shot-payload-journal.log`.
- Hash post-fix (copia isolata):
  - `game/match_controller.gd` = `781fe65738a3953bbaf428c64896f0f5997afe0403b4aed6f43fec713ecc9f00`
  - `tests/input/deferred_shot_payload_test.gd` = `8307cf1c6f776a7a85caddc4c67bdc4354a66ee30a30a8ff23544252af8fcb43`
- **Sorgenti di produzione: invariati, sola lettura in questo lancio** (nessun
  `git add`/`commit`/`push`, nessuna install, nessuna API a pagamento).

## Comandi esatti rieseguibili

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /tmp/padel-shot-payload-fix/godot

# regressione + fix, in un colpo (la copia ha già la patch applicata)
$GODOT --headless --path . --script res://tests/input/deferred_shot_payload_test.gd

# suite esistente, invariata dalla patch
$GODOT --headless --path . --script res://tests/game_slice_test.gd
```

## Cosa resta (fuori dal budget/scopo di questo lancio)

- Promozione a `godot/game/match_controller.gd` + nuovo
  `godot/tests/input/deferred_shot_payload_test.gd` in produzione: richiede
  l'integratore nominato del charter, verifica hash-match del checkout live al momento
  della promozione, e re-run in copie fresche isolate — non eseguito qui per vincolo
  esplicito "Nessuna promozione in produzione".
- Il gap "aim" (metà affermazione non evidenziata, review/FINAL.md punto 5): il corpus
  non combina zero-substep + aim≠0; qui il campo aim è incluso nel payload preservato
  per costruzione (stessa cattura di shotVariant/slice), ma un test dedicato
  aim-divergente-a-contatto non è stato costruito — fuori scopo per il fix minimo.
