# Cross-review — tasto A: verdetto sulla diagnosi differenziale e sul comparatore

Owner: Review (cross-review, worker diverso dall'integratore). Nativo: opencode-go / deepseek-v4-pro. 2026-09-17.
Lane 5/6. Solo lettura + verdetto; nessuna mutazione a sorgenti/harness esistenti, nessun Godot avviato, nessun run di integrazione ripetuto (già rieseguito dal CEO: exit 0, 2278 coppie, 14 divergenze).

## Verdetto

**REJECT** la certificazione ampia ("PASS cross-engine, 0 divergenze inattese").
**CERTIFY** la diagnosi stretta: la divergenza del latch a zero sub-step è reale e riprodotta in esecuzione, e la sfumatura "shotVariant perso → fallback auto" è corretta e verificata in sorgente.

La diagnosi è buona; il comparatore non lo è abbastanza per sostenere la frase "0 divergenze inattese".

---

## Cosa regge (verificato in questo cross-review)

1. **Parità a rate puliti.** Nei 6 scenari a passo pieno/multi-passo (0.0084 / 0.0168), i campi input (23) + coda (10) + `steps` sono identici tra JS e Godot, tol=0. Confermato leggendo i trace: valori coincidenti su ogni scenario non-latch.

2. **Divergenza del latch a zero sub-step — reale e riprodotta.**
   - Sorgente: `match_controller.gd:966-967` (`if steps > 0: queued_one_shots.clear()`) + `:78` (ONE_SHOTS non include `shotVariant/slice/aim`).
   - Trace JS `zero-substep-latch` frame 2: `queuedShotPower=1.000000`, `playerSwingBuffer=0.000000` (rilascio perso).
   - Trace GD frame 2: `queuedShotPower=0.400000`, `playerSwingBuffer=0.271667` (colpo consegnato 1 sub-step in ritardo).
   - Divergenza genuina, prima e unica osservata. Corretta e più precisa di review B3.

3. **"Godot perde shotVariant sul rilascio ritardato → variante 'auto'" — verificato.**
   - `sim.gd:2854-2857`: `hit=true` con `shotVariant=null` → `"slice" if slice else "auto"`.
   - Trace GD frame 2: `hit` latched (consegnato) ma `shotVariant=null` nel sample corrente → `queuedShotVariant="auto"` con `queuedShotPower=0.4`. JS: nessun colpo, `queuedShotVariant="auto"` default con `power=1.0`.
   - La distinzione "auto per ragioni opposte" (Godot: colpo degradato; JS: nessun colpo) è corretta ed è evidenziata da `queuedShotPower`/`playerSwingBuffer`, non solo affermata.

## Cosa NON regge / è sovrastimato

4. **"auto cambia davvero il colpo finale rispetto a drive" — NON provato.** Nessuno scenario di contatto eseguito (gap dichiarato #1). L'effetto downstream di `queuedShotVariant="auto"` vs `"drive"` sul colpo/contatto finale è ignoto. La dicitura "variante degradata" nel REPORT integrazione sovrastima: è un *fallback*, non un esito misurato.

5. **"Godot perde aim" — metà affermazione non evidenziata.** Il corpus non combina zero sub-step + aim≠0, quindi `queuedShotAim` non diverge mai (0.0 su entrambi). La parte "aim" è solo inferenza da sorgente; la parte "shotVariant" è invece tracciata.

6. **Corpus "production-rate" — etichetta sovrastimata.** I delta usati (0.0084 / 0.0168 / 0.004) sono proxy sintetici a margine pulito, non i delta di render reali (≈0.008333 / ≈0.016667). La giustificazione del troncamento del parser GDScript (`0.008333333333333333 < 1.0/120.0`) riguarda solo i *letterali JSON* del corpus, NON la produzione: il delta Godot reale è `get_process_delta_time()` (double calcolato), non un letterale. Conseguenza: la parità è provata a rate puliti ma **non al confine delta≈FIXED_STEP**, dove l'accumulatore è più sensibile e dove un monitor 120 Hz reale vive (jitter attorno a 1/120 → frame a 0/1/2 sub-step naturali). È un gap di copertura, non una falsità — ma il nome "production-rate" lo sopravvaluta. Non richiede una suite illimitata: basta 1 scenario a delta-adiacente (0.008333…/0.008334) per saggiare il confine.

## Difetti del comparatore (confermati tutti, lettura di `run_integration.py`)

Priorità bloccanti per la certificazione ampia:

1. **[BLOCKER] Allowlist wholesale per scenario, non per campo.** `classify()` (righe 146-157) classifica come "intended" *qualsiasi* divergenza con `scenario in LATCH_SCENARIOS`, ignorando il campo. Una divergenza reale nello scenario latch su un campo diverso (es. `queuedShotAim`, `queuedShotVariant`) sarebbe inghiottita silenziosamente. Fix: allowlist a coppie `(scenario, campo)` = esattamente `{("zero-substep-latch","sim.queuedShotPower"), ("zero-substep-latch","sim.playerSwingBuffer")}`.

2. **[BLOCKER] Red-control vacuo.** `red_ok = len(divergences) > 0` (riga 234) è già true al baseline (14 divergenze latch). Una corruzione che non cambiasse nulla passerebbe. Il run attuale ha *aggiunto* una 15ª divergenza (chiave `"queuedShotVariant":"drive"` → `"XueuedShotVariant"` in `a-tap`, scenario NON-latch — confermato in `gd.corrupt.txt`), ma il test non sa distinguerlo. Fix: asserire che la copia corrotta produca **più** divergenze del baseline, oppure una divergenza classificata "real"/`count_mismatch`, non solo `>0`.

3. **[HIGH] `rep.count_mismatch` ignorato dal verdetto finale.** Righe 280-289 controllano solo `red_ok`, `trunc_ok`, `real`. Se JS e Godot avessero conteggi record diversi, `compare` restituisce `count_mismatch=True, divergences=[]` → `real=[]` → PASS. Attualmente mascherato *per caso* dal red-control (un count-mismatch farebbe fallire il marker), ma è un buco latente: va reso esplicito (`if rep["count_mismatch"]: return 2`).

4. **[HIGH] Exit code delle seconde run e dell'import ignorati.** `rc2` (riga 183), `rc_gd2` (riga 194), `rc` dell'import (riga 172) sono letti ma mai verificati. Un crash sulla seconda run (con output byte-identico per puro caso, o prima della scrittura) passerebbe. Fix: `js_ok = rc==0 and rc2==0 and …`, `gd_ok = rc_gd==0 and rc_gd2==0 and …`, e abortire su import `rc != 0`.

5. **[MED] `compare([],[])` restituisce risultato pulito.** `count_mismatch=False, divergences=[], comparisons=0`. Difensivo: se entrambi gli input sono vuoti, errore esplicito (oggi parzialmente coperto dal marker-check del red-control, ma solo per il ramo GD).

## Fix spec minimo (per l'ultimo launch integratore, non implementato qui)

1. `classify()` → allowlist a coppie `(scenario, campo)` (punto 1 sopra); tutto il resto nello scenario latch → `real`.
2. Red-control → confronta con il baseline: `red_ok = (divergenze_corrotte > divergenze_baseline) or count_mismatch or any-classified-real`.
3. Verdetto finale → aggiungi `if rep["count_mismatch"]: return 2`; includi `rc2`, `rc_gd2`, `rc` import nei gate `_ok`.
4. Rilanciare il comando bounded unico; **non** ricertificare "auto vs drive = colpo finale diverso" senza uno scenario di contatto (resta gap dichiarato).
5. Opzionale, se budget residuo lo consente: (a) 1 scenario zero-substep + aim≠0 per evidenziare la metà "aim"; (b) 1 scenario delta-adiacente a 1/120 (0.008333…/0.008334) per saggiare il confine dell'accumulatore. Non richiesti per il verdetto stretto.

## Handle assoluti e budget

- Verdetto: `/Users/alessiofantini/Documents/steam-circuit-padel-godot/docs/mission/a-button-parity-20260917/review/FINAL.md`
- Comparatore: `…/integration/run_integration.py` · Corpus: `…/integration/corpus/production_rate.json` · Summary: `…/integration/summary.json`
- Trace: `/tmp/padel-a-button-20260917-port/{js,gd}.trace.txt`, `gd.corrupt.txt`
- Launch rimanenti (condivisi): **1 di 6** dopo questo cross-review. API a pagamento: **0 EUR**. Token subscription: ignoti (mai riportati come zero). Tool call: ~11/15.
