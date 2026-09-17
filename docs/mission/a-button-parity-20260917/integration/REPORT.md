# Integrazione — prova differenziale cross-engine del tasto A

Owner: Port (integratore unico). Nativo: opencode-go / deepseek-v4-pro. 2026-09-17.
Lane 6/6 (ultimo). Artefatti diagnostici, nessuna modifica a produzione/alberi JS.

## Verdetto (ristretto — supersede il verdetto ampio della lane 4)

**PASS — parità input/coda sugli schedule sintetici elencati + divergenza di coda riprodotta.**
Nient'altro è certificato.

- **Parità input/coda** (campi input 23 + coda 10 + `steps`, tol=0) sugli schedule
  sintetici `no-input, a-tap, a-short-charge, rb-a, left-stick-aim, hz60-release`
  (delta 0.0084 / 0.0168, margine pulito). 2278 coppie campo, **0 divergenze inattese**.
- **Divergenza di coda riprodotta** su `zero-substep-latch` (250 Hz): 14 divergenze,
  tutte attese e solo sui campi allowlistati `sim.queuedShotPower` /
  `sim.playerSwingBuffer` (frame 2-8).

**NON provato / NON misurato** (restano gap dichiarati, non affermazioni):

- **"fallback auto = colpo finale degradato": NON misurato.** `queuedShotVariant="auto"`
  è un *fallback* osservato a livello di coda, non un esito di colpo/contatto finale.
  Nessuno scenario di contatto eseguito cross-engine.
- **"Godot perde aim": NON evidenziato.** Il corpus non combina zero sub-step + aim≠0,
  quindi `queuedShotAim` non diverge mai (0.0 su entrambi). Solo inferenza da sorgente.
- **Hardware fisico e contatto finale: non testati.** Device seam alimentato da
  dizionari headless; nessun pad reale; nessun colpo smash/x2/x3 cross-engine.

## Correzione esplicita (supersede la lane 4)

La lane 4 certificava "PASS cross-engine, 0 divergenze inattese" in senso ampio.
Quella frase è **superata**: il comparatore di allora inghiottiva divergenze reali
su campi non-latch dello scenario latch (allowlist per scenario, non per campo),
il red-control era vacuo (baseline già divergente), `count_mismatch` era ignorato
dal verdetto, e l'import + i secondi exit code non erano gate. Il REPORT 4 resta
come evidenza storica; il verdetto vigente è quello sopra, ristretto. La diagnosi
stretta (latch a zero sub-step reale e riprodotto) è confermata; la dicitura
"variante degradata" del REPORT 4 è rimossa in favore di "fallback non misurato".

## Fix applicati al comparatore (lane 6/6)

1. `classify()` → allowlist **a coppie (scenario, campo)**: solo
   `{("zero-substep-latch","sim.queuedShotPower"), ("zero-substep-latch","sim.playerSwingBuffer")}`.
   Ogni altra divergenza sullo scenario latch è `real`.
2. Red-control **baseline-relative** (`red_detected`): deve *aggiungere* divergenze
   al baseline già divergente, o produrre count-mismatch, o essere classificata
   `real`. Aggiunto **negative-control**: una mutazione no-op (rinomina di campo
   non confrontato) NON deve essere rilevata.
3. Verdetto condiviso (`comparator.verdict`): `count_mismatch` → exit 2; mismatch di
   **copertura corpus** (frame count / sequenza scenario attesa) → exit 2; il latch
   deve essere **riprodotto esattamente** (no-repro = fail, non pass).
4. Gate import + **entrambi** gli exit code e i marker harness di ogni run
   (`runs_ok`); una run fallita non può essere mascherata da output stantio riusato
   (si usa lo stdout della run stessa, mai un file riletto).
5. `compare([],[])` e record senza campi obbligatori → `ComparatorError`.

## Comandi rieseguibili (bounded, nessun engine per i self-test)

```sh
# Self-test dei percorsi false-green del comparatore (nessun Godot/node):
python3 docs/mission/a-button-parity-20260917/integration/test_comparator.py
# Run integrale (unico, bounded):
python3 docs/mission/a-button-parity-20260917/integration/run_integration.py
```

## Risultati del rerun (lanci 6/6, schedule sintetici esistenti)

- Import warm-up: exit 0.
- JS harness: exit 0/0, marker OK. Godot harness: exit 0/0, SCRIPT ERROR=0, marker OK.
- Determinismo: stream evidenza JS e Godot byte-identici su due run.
- Confronto: **2278 coppie campo, 14 divergenze (14 attese, 0 inattese)**;
  frame 67/67 (attesi 67), sequenza scenario OK.
- Red-control: baseline 14 → copia corrotta 15 (rilevato). Negative-control no-op:
  non rilevato (corretto). Troncato: `count_mismatch=True` (rilevato).
- Verdetto: **exit 0**.
- Self-test: **8/8 pass**, exit 0.

## La divergenza riprodotta (zero-substep latch)

Scenario `zero-substep-latch` (250 Hz, A premuto frame 0, rilasciato frame 1 —
entrambi i frame giustificano **zero** sub-step):

| | browser (JS) | Godot |
|---|---|---|
| release su frame a 0 sub-step | `getInput()` azzera `hitQueued` PRIMA dell'accumulatore → **colpo perso** | latch `hit` sopravvive → consegnato al sub-step del frame 2 |
| `queuedShotPower` frame 2+ | `1.000000` (default, nessun colpo) | `0.400000` (colpo accodato) |
| `playerSwingBuffer` | `0.000000` | `0.271667` (colpo armato) |

Il latch Godot conserva solo i one-shot (`hit, special, switchPlayer,
switchDirection, smashUpgrade, cutVolley, globo, teamTactic`), NON
`shotVariant`/`slice`/`aim`: il colpo consegnato in ritardo arriva con
`shotVariant=null`, accodato con variante di **fallback "auto"**. Questa è
l'osservazione a livello di coda; **l'effetto downstream sul colpo finale resta
non misurato** (nessun contatto eseguito).

## Cosa è stato costruito

- `integration/comparator.py` — comparatore + verdetto condivisi (unica fonte di
  verità; nessun diff proxy separato).
- `integration/test_comparator.py` — self-test dei percorsi false-green, senza engine.
- `integration/run_integration.py` — runner con i fix del comparatore.
- `integration/corpus/production_rate.json`, `js_frame_glue.mjs`, `port_frame_glue.gd`
  — invariati (schedule sintetici esistenti).

## Gap dichiarati (feel gate resta aperto)

1. **Nessun contatto**: evidenza a livello input/coda, non colpo finale.
2. **Schedule sintetici**: delta a margine pulito (0.0084/0.0168/0.004), non i delta
   di render reali ≈0.008333/≈0.016667; il confine delta≈FIXED_STEP non è saggiato.
3. **144/240 Hz non eseguiti come scenario separato**: principio sub-step >120 Hz
   dimostrato a 250 Hz.
4. **Device seam** a dizionari (nessun pad fisico); **aim-loss non evidenziato**
   (corpus senza zero sub-step + aim≠0).

## Budget

- Lanci nativi rimanenti (condivisi): **0 di 6**.
- API a pagamento: **0 EUR**. Token subscription: **ignoti** (mai riportati come zero).
