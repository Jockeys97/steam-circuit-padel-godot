# Port — replay isolato del percorso reale del tasto A (Godot)

Owner: Port (integratore unico). Nativo: opencode-go / deepseek-v4-pro. 2026-09-17.

## Verdetto

**PASS 32/32** · exit 0 · **SCRIPT ERROR 0** · 1 `ERROR:` residuo benigno
("1 resources still in use at exit", teardown motore, non è né un errore di script
né di import). Il replay copre il percorso **live reale**, non un mapper riscritto.

## Cosa è stato costruito

- Copia isolata del sorgente: `/tmp/padel-a-button-20260917-port/godot`
  (game/ + src/ + assets/ + tests/ + project.godot, cache `.godot` propria).
- Harness: `docs/mission/a-button-parity-20260917/port/port_replay.gd`
  (copiato in `res://port/port_replay.gd` della copia isolata).
- Runner: `docs/mission/a-button-parity-20260917/port/run.sh`.
- Provenance: `docs/mission/a-button-parity-20260917/port/hashes.json`.

## Comando rieseguibile

```
/Users/alessiofantini/Documents/steam-circuit-padel-godot/docs/mission/a-button-parity-20260917/port/run.sh
```

Fa: guard (rifiuta se c'è un secondo motore Godot diagnostico), warm-up `--import`
(idempotente, genera la cache audio `.sample`), poi il replay headless seriale con
`--quit-after` (questo host macOS non ha `timeout`). Log: `/tmp/padel-a-button-20260917-port/run.log`.
Il gioco live dell'utente (PID 43135, `res://game/Main.tscn`) non è mai stato toccato
né rilanciato: verificato vivo prima e dopo ogni run.

## Cosa esercita il replay (32 check)

Due layer, distinti come richiesto dal contratto:

- **Layer A — sampler reale** (`input_map.gd.sample`): A hold→carica drive e ferma il
  movimento, release→`hit` drive con aim preservato (una sola volta), RB+A→chiquita,
  priorità X>Y>A, doppia pressione primed→`smashUpgrade` one-shot. Unico override: il
  *device seam* `_button`/`_axis`/`_key_pressed` (lo stesso confine dei test
  pre-esistenti `shot_sequences_test.gd`/`controller_trace.gd`). Il corpo di `sample()`
  è quello di produzione, intatto.
- **Layer B — percorso live reale** (`Match.tscn` → `apply_frame` → `advance_frame` →
  `tick_fixed` → `Sim.update_match`): seed pinnato 20260917, uscita dalla fase di
  servizio col `ScriptedPlayer` reale, poi:
  - tap: 6 frame di carica (shotCharge 0.0079→0.0476), release → `queuedShotVariant=drive`,
    `queuedShotCharge=0.0476`, `queuedShotPower=0.4452`, `queuedShotAim=0.5876`, nessun doppio fuoco;
  - RB+A → `queuedShotVariant=chiquita`, power 0.4302;
  - aim → `shotAim` traccia −0.8932 e arriva a `queuedShotAim` al release;
  - primed → `queuedShotVariant=smash`, `evSmashTapConfirmed`, `smashPrimed` consumato;
  - tick: delta sub-step → 0 tick, full-step → 1, double-step → 2, stall → clamp a 8 (MAX_SIM_STEPS).

## Gap / seam dichiarati (non è una prova end-to-end)

1. **Device seam**: `_button`/`_axis`/`_key_pressed` alimentati da dizionari (niente pad
   fisico; headless non ha device). È il confine documentato, non un mapper.
2. **Doppia pressione primed (smash)**: la precondizione è seminata manualmente
   (`smashPrimed=true`, `smashTapWindow=0.7`, `playerSwingBuffer=0.9` — i valori reali di
   `frozen/data.json`), non prodotta da uno scambio organico; serve a rendere raggiungibile
   il ramo `smashUpgrade` del handoff reale senza una rally completa.
3. **Uscita dal servizio** tramite `ScriptedPlayer` (input di produzione, solo setup).
4. **Nessun confronto con l'oracolo browser** — attende il corpus Reference (dispatch separato).
5. **1 risorsa "in use at exit"** — teardown motore benigno, non un errore.
6. **Audio**: il modulo carica i `.sample` solo dopo `--import` (incluso nel runner);
   non tocca il percorso di input.

## Interfaccia per l'integratore (diff contro il corpus oracolo)

- Righe `SAMPLER <timeline> <json>`: l'intent emesso dal sampler reale (struct a 22 campi:
  `hit, slice, shotVariant, aim, aimY, analogAim, charging, smashUpgrade, cutVolley, globo,
  special, switchPlayer, switchDirection, teamTactic, moveX, moveY, left, right, up, down,
  splitStep, sprint, technicalModifier`).
- Righe `REPLAY <timeline> <idx> <json>`: `{intent, steps, accumulator, ticks, shotCharge,
  shotAim, shotIntent, queuedShotVariant, queuedShotCharge, queuedShotPower, queuedShotAim,
  smashPrimed, cutVolleyPrimed, globoPrimed, rallyHits, events_total, events_tail}`.
- Verdetto: una riga `PASS n/n` o `FAIL n/n`; exit code del processo; conteggio `SCRIPT ERROR`.

Il runner non contiene logica oracolo duplicata: emette solo il trace del percorso Godot.
Il confronto col corpus esatto Reference avverrà nel dispatch di integrazione, alimentando
queste stesse righe.

## Budget

- Tool call: ~31 (target ≤30; il run iniziale rotto per l'esclusione di `tests/build` ha
  richiesto un giro in più per correggere il copy minimale).
- Spesa API a pagamento: 0 EUR. Token subscription: ignoti, non riportati come zero.
- Lanci nativi rimanenti (condivisi): 3 di 6.
