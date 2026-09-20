# REPORT — comparator continuation (Sonnet 5), chiusura falsi verdi residui

Owner: Comparator team (Sonnet 5). Scope scritto: solo
`integration/comparator.py`, `integration/test_comparator.py`,
`followup-shot-payload/comparator/**`. Nessun Godot avviato, nessuna
scrittura fuori scope, nessuna modifica a `reference/**` o a
`run_integration.py`.

## Stato di partenza

I due tentativi precedenti (deleg_78418204, deleg_804d0092) sono terminati
per esaurimento quota (opencode-go 429) prima di applicare fix; i transcript
non contenevano modifiche già presenti nei file (verificato: nessun hit su
`LATCH_ALLOWLIST`/`missing.*field` nei log). `comparator.py`/`test_comparator.py`
erano già nello stato del gate 1 precedente (allowlist per campo, red-control
baseline-relative, `count_mismatch`/`frame_count_ok`/`scenario_ok` propagati),
ma con i due difetti residui indicati dal CEO:

1. **Campi assenti su entrambi i lati**: `_validate()` controllava solo le 5
   chiavi top-level (`scenario, frame, steps, input, sim`), non i singoli
   campi nominati del contratto (`INPUT_FIELDS`/`SIM_FIELDS`). Un campo
   assente (non `null`, proprio mancante come chiave) su **entrambi** js e gd
   veniva confrontato come `dict.get(field) == dict.get(field)` → `None ==
   None` → nessuna divergenza, verdetto verde silenzioso.
2. **Contratto del latch per nome di campo, non per frame/valore esatti**:
   `LATCH_ALLOWLIST` era `{(scenario, field)}`. Qualunque divergenza su quel
   campo, a QUALSIASI frame e con QUALSIASI valore, veniva classificata
   "intended". Una regressione che spostasse la divergenza al frame sbagliato,
   o cambiasse il valore osservato, sarebbe stata assorbita silenziosamente.

## Fix applicati (red poi green)

### 1. Validazione campi assenti (comparator.py `_validate`)
Aggiunto un loop su `INPUT_FIELDS`/`SIM_FIELDS` che solleva `ComparatorError`
se il campo è **assente come chiave** da `input`/`sim` di un record — anche
quando manca da entrambi js e gd. Un `None` esplicito resta legittimo e non
solleva. Test rosso-poi-verde: `t_missing_field_both_sides` — verifica che la
rimozione della chiave (non del valore) su entrambi i lati sollevi
`ComparatorError` (per un campo input e uno sim), e che l'assegnazione
esplicita di `None` su entrambi i lati NON sollevi.

### 2. Contratto esatto del latch (comparator.py `LATCH_CONTRACT`)
Sostituito l'allowlist per nome-campo con `LATCH_CONTRACT`: mappa
`(scenario, frame, field) -> (valore_js_atteso, valore_gd_atteso)`, con i due
valori esatti riportati da `review/FINAL.md` (frame 2:
`queuedShotPower` 1.000000→0.400000, `playerSwingBuffer` 0.000000→0.271667).
`classify()` marca "intended" solo se scenario, frame, campo E valori
osservati coincidono esattamente col contratto; qualunque scarto (frame
sbagliato, valore sbagliato, campo diverso, occorrenza mancante o in
eccesso) diventa "real" e fa fallire il verdetto (`latch_reproduced` confronta
insiemi di chiavi `(scenario, frame, field)` esatti, non solo nomi).
`LATCH_ALLOWLIST` derivato mantenuto per compatibilità di forma con
`run_integration.py` (non toccato, fuori scope).

Nuovi test rosso-poi-verde:
- `t_wrong_frame`: divergenza sullo stesso campo ma al frame sbagliato →
  classificata real, `latch_reproduced` falso, verdetto exit 2.
- `t_wrong_value`: divergenza al frame/campo giusti ma valore diverso dal
  contratto → real, exit 2.
- `t_extra_occurrence`: contratto soddisfatto al frame 2 + una divergenza
  extra non contrattuale al frame 3 → contratto riconosciuto ma verdetto
  comunque exit 2 per la divergenza reale in eccesso.

### 3. Controlli rossi (invariati, riverificati)
`red_detected` resta baseline-relative (corruzione reale deve aggiungere
divergenze / causare count-mismatch / produrre una divergenza "real";
mutazione no-op non accettata). Riverificato con `t_red_control` dopo il
refactor del contratto — nessuna regressione: corruzione reale rilevata,
no-op non rilevata.

## Comandi esatti ed exit code

```
$ cd /Users/alessiofantini/Documents/steam-circuit-padel-godot
$ python3 docs/mission/a-button-parity-20260917/integration/test_comparator.py
PASS  exact contract: latch frame/field/value match is intended, other field is real
PASS  wrong frame: contract field diverging on the WRONG frame is real, not intended
PASS  wrong value: right frame/field but value != contract is real
PASS  extra occurrence: contract satisfied but an ADDITIONAL divergence exists -> real, verdict fails
PASS  known latch difference must be present exactly (no-repro is a failure)
PASS  empty and missing-required-field inputs raise ComparatorError
PASS  contract field silently ABSENT on both sides raises, not a silent None==None pass
PASS  equally truncated traces fail against expected corpus frame count
PASS  unequal traces fail via count mismatch and propagate to verdict
PASS  scenario sequence mismatch fails verdict
PASS  red-control is baseline-relative; no-op mutation is NOT detected
PASS  runs_ok rejects nonzero exit codes and missing markers (no stale reuse)

12 passed, 0 failed
EXIT:0
```

Nessun motore (node/Godot) coinvolto — self-test puro, coerente col vincolo
del charter.

## Hash finali (SHA-256)

```
5053ec36c520d9d2a294d670b60af5838cc52a333f503f64727907f6756f9a0  integration/comparator.py
55b792b5944cd2faef8ff6d3db00bf0eda11f808d8fe74396331d7fedcde151  integration/test_comparator.py
```

## Nota per l'integratore

`run_integration.py` (fuori scope per questo worker, non modificato) chiama
`comparator.classify(rep["divergences"])` e `comparator.latch_reproduced`,
che ora richiedono il match esatto su frame/valore invece che solo sul nome
campo — comportamento retrocompatibile per il corpus reale (la divergenza
storica reale è comunque a frame 2 con quei valori esatti), nessuna modifica
di firma. `LATCH_ALLOWLIST` resta esportato (derivato da `LATCH_CONTRACT`)
per qualunque consumer che ne legga solo la forma `(scenario, field)`.

## Fuori scope / non toccato

- `run_integration.py`, `reference/**`, sorgenti di produzione, Godot: non
  eseguiti né modificati.
- Gap "auto vs drive = colpo finale diverso" e scenario zero-substep+aim≠0
  (review/FINAL.md punti 4-5, "Fix spec minimo" punto 5): esplicitamente
  fuori dall'ambito di questo worker (comparatore, non contatto/harness).
