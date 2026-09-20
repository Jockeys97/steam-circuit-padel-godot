# Report — Oracolo del percorso di input del tasto A (Reference)

Team: Reference. Owner: solo `reference/**` + `/tmp/padel-a-button-20260917-reference`.
Stato: oracolo eseguibile, corpus machine-readable, verifica rosso-capace completati.

## Esito (summary)

Costruito e **eseguito** un oracolo che fa girare le **vere funzioni di input del
browser** estratte da `js/main.js` (`radialStick`, `shotAimAxis`, `isSliceAction`,
`pollGamepadGameplay`, `getInput`) e alimenta, per ogni tick, l'`input` tradotto
nella **vera** `updateMatch` di `js/game.js`. Nessuna semantica browser è stata
reimplementata come risultato atteso: entrambi gli stadi eseguono codice di
produzione.

L'oracolo produce una traccia byte-comparabile (`tol=0`) di 290 frame su 11
scenari, riproducibile a seed fissato e rosso-capace (una copia corrotta è
rilevata con exit code nonzero).

## Provenienza sorgente (identificata, non assunta)

| file | sha256 |
|---|---|
| `js/main.js` (repo) | `d1e2d3d20b37395eb1e9fbd3ad8e1dc83c3fc392e75711380fc93b48306a4e0a` |
| `/Users/alessiofantini/Documents/Padel/js/main.js` | `d1e2d3d2…4e0a` (identico) |
| `js/game.js` | `22b8a4f4154d8ed2b35d107cd94b41e114a53b6fbe3da07c156103e989040fe7` |
| `js/data.js` | `dca8fe0abe4e1b890541b2c9bae278af040ec0c06a2d3a2e4e2e355eff434a53` |

Le due copie di `main.js` sono **byte-identiche** (stesso sha256, stessa size
100390 B, stesso mtime). La revisione testata è quindi unica; il confronto è stato
fatto, non assunto. Sorgenti di produzione letti in sola lettura, mai modificati.

## Design dell'oracolo

`reference/oracle/a-button-oracle.mjs`:

- **Stadio 1 (input path)**: estrae le 5 funzioni reali con lo stesso approccio di
  `tools/controller-parity.mjs` e le esegue in una VM Node con lo stato `gamepad`/
  `matchState`/code persistenti tra i frame. Output: l'oggetto `getInput()` completo
  (23 campi) = *translated input*.
- **Stadio 2 (sim)**: lo stesso `input` tradotto è passato alla reale `updateMatch`
  (`js/game.js`). Output: stato code (charge/power/variant) e stato primed
  (`smashPrimed`/`cutVolleyPrimed`/`globoPrimed`), più `ball.shotType` al contatto.
- **Sincronizzazione**: i flag primed calcolati dalla sim sono ricopiati in
  `matchState` della VM prima di ogni poll, così il double-tap su A vede il primed
  reale (non un flag impostato a mano).

Percorso coperto: **pad fisico → `pollGamepadGameplay` → `getInput` →
`updateMatch` → colpo in coda/colpo** (nel bench `contact`).

## Corpus e copertura (11 scenari, 290 frame)

`reference/corpus/scenarios.json` + schema in `reference/corpus/schema.md`:

| scenario | ossservazione verificata nell'esecuzione reale |
|---|---|
| `no-input` | nessuna coda, stato invariato |
| `a-tap` | press 1 tick → release: `hit=true, shotVariant="drive", queuedPower≈0.415` |
| `a-release-hold-1-frame` / `-2-frames` | rilascio al confine dei tick fissi (power≈0.430) |
| `a-short-charge` (12 tick) | power≈0.581 |
| `a-full-charge` (66 tick) | charge cap 1.0 → `queuedPower=1.35`, **`smashPrimed=true`** |
| `a-repress-smashPrimed` | rilascio full → primed; ri-press → `smashUpgrade=true`, `queuedShotVariant="smash"` |
| `rb-a` | `technicalModifier` → `shotVariant="chiquita"` |
| `modifier-change-mid-hold` | RB premuto a metà: `chargeAction` **latchato** → `shotVariant="drive"` (non chiquita) |
| `left-stick-aim` | `aim=-0.833418/-0.594151` (curva `radialStick`→`shotAimAxis` reale) |
| `a-tap-contact` | tap con palla in arrivo: `ball.shotType` passa a `"drive"` (colpo) |

I comportamenti non banali confermati dal codice reale: il latch di `chargeAction`
al primo press (RB mid-hold non cambia la variante) e la promozione
`smash` al secondo tap dentro la finestra.

## Comandi

```sh
# rigenerare la traccia (11 scenari, 290 frame)
node docs/mission/a-button-parity-20260917/reference/oracle/a-button-oracle.mjs \
  --out=/tmp/padel-a-button-20260917-reference/trace.txt
# verificare riproducibilità + red-control (exit 0)
node docs/mission/a-button-parity-20260917/reference/verify.mjs
```

Output eseguito (journal): `reference/out/trace.txt` (exit 0, 303 righe).
`verify.mjs`: `PASS reproducibility` (due run byte-identiche, 223298 B) +
`PASS red-control` (diff exit 1 su copia corrotta).

## Seam non coperti (registrati, non nascosti)

1. **1:1 poll:update** — l'oracolo assume un poll del gamepad per tick di sim.
   Nel browser reale `gamepadLoop` corre su `requestAnimationFrame` mentre la sim
   avanza a passo fisso: le due frequenze possono divergere. Questa differenza di
   cadenza non è dimostrata da un replay a tick fisso.
2. **Hardware/latenza** — polling fisico e latenza visiva non sono dimostrabili da
   uno script (fog dichiarato nel MAP).
3. **Contatto** — solo `a-tap-contact` arriva al colpo; il bench `stationary`
   isola la coda e **non** esercita il contatto (palla posta alta a z=160, cade
   sotto gravità arcade ~150 px/s² ma non rimbalza né chiude il punto entro la
   finestra di ~85 tick). Il colpo completo con smash/x2/x3 è già coperto da
   `tools/sim-port/shot-intent-probe.mjs` (non duplicato qui).
4. **`coop`/`pvp`** — il percorso testato è il ramo **solo** di `updateMatch`
   (usa `updateShotControl`/`queueChargedShot` top-level). I rami `coop` e `pvp`
   usano `queuePaddleHit`/`controlPaddleCharge` per-paddle e non sono esercitati.
5. **Primo frame** — `smashUpgrade`/`cutVolley`/`globo` sono `null` al tick 0
   (stato reale pre-poll), poi `false` (vedi `schema.md`).

## Verifica

- Exit code oracolo: **0** (11 scenari, 290 frame, nessun `SCRIPT ERROR`).
- Riproducibilità: due run a seed 12345 byte-identiche.
- Red-control: copia corrotta rilevata (exit 1) senza toccare sorgenti di produzione.

## Budget

- Tool call usate: ~25 (sotto il target 30).
- Lanci di worker nativi: 0 (nessun worker aggiuntivo; nessun avvio Godot).
- API a pagamento: 0. Token: costo sconosciuto (mai riportato come zero misurato).
- Godot: mai avviato. Sorgenti di produzione e albero JS: sola lettura.
