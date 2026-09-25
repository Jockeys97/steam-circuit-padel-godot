# Errori dei colpi del giocatore — ritaratura del 2026-09-23

Richiesta del proprietario: i colpi presi male (in ritardo, in anticipo, sbilanciati) restano
quasi sempre in campo, e il pallonetto non va mai fuori. Dati dalle sue partite registrate
(`tools/match-log/out/`, `game/match_log.gd`).

## Cosa è cambiato (solo per il giocatore umano; l'IA non cambia)

1. **L'IA lascia andare le palle che escono** (`sim.gd` `ai_lets_it_go_out`, previsione esatta
   `ai_glass.gd` `first_contact`). Prima rimetteva in gioco i colpi lunghi del giocatore: 2 su
   3 in una partita. Verificato nella partita successiva: 2 colpi lunghi su 2 sono diventati
   punto per l'IA.
2. **Più errori per i colpi presi male** (`roll_shot_error`, costanti `HUMAN_ERROR_*`). La
   funzione la usano solo i colpi dell'umano. L'IA (`ai_shot_error`) continua a leggere i
   valori `shotError*` del bilanciamento, che non sono stati toccati.

   | qualità del colpo | prima | ora (misurato, 200.000 estrazioni) |
   |---|---|---|
   | 0,87 (perfetto) | 0% | 0,3% |
   | 0,75 | 3% | 7,8% |
   | 0,60 (tipico in ritardo o anticipo) | 23% | 33,0% |
   | 0,50 e meno | 50% | 60,0% |

3. **In ritardo va lungo, sul vetro al volo**, cioè fuori. Soglia `timingBias` da 0,05 a 0. Nelle
   partite registrate, gli errori dei colpi in ritardo erano: 5 lunghi, 3 in rete, 1 largo.
4. **Anche il pallonetto può sbagliare**, con la stessa estrazione del drive: lungo oltre la
   linea di fondo, in rete o largo. Prima ignorava del tutto l'errore.

5. **Anche i colpi sopra la testa possono sbagliare** (bandeja, smash piatto, X2, X3,
   víbora). Prima l'errore estratto veniva scartato, perché quei colpi ricalcolano la
   traiettoria: 2 errori su 9 persi così in una partita del proprietario. Ora lungo va fuori
   sul vetro al volo, largo va fuori di lato, in rete va in rete. Per la palla sbagliata gli
   effetti speciali dello smash (uscita dal vetro, X3 oltre la parete) sono disattivati.
   Verifica in simulazione, 30 partite: 28 errori estratti su 28 arrivano in campo (prima
   si perdevano quelli sopra la testa), e 24 costano subito il punto.

**Registrazione dell'estrazione.** `State.lastShotErrorRoll` (solo diagnostica, fuori dal
digest) e `match_log.gd` salvano, per ogni colpo, qualità, probabilità, numero estratto ed
esito. Nella partita delle 18:57 (13 punti) la qualità della regola coincide con quella
mostrata a schermo: 14,3 errori attesi, 9 estratti, 7 arrivati in campo (i 2 persi erano
bandeja e smash, ora corretti). La partita precedente (5 errori su circa 14 attesi) non si è
ripresentata e, senza quel dato registrato, non si può ricostruire.

Le partite registrate `tools/parity-godot/golden/` sono state riregistrate: m1 e m3 cambiano
dove il giocatore automatico tira colpi di bassa qualità, m2 è identica.
Test generale invariato: i 17 rossi sono delle lavorazioni parallele su audio e interfaccia.

## Da verificare giocando
Quanti errori escono in una partita e come si sentono. Se è troppo o troppo poco, i
parametri da regolare sono `HUMAN_ERROR_THRESHOLD`, `HUMAN_ERROR_MAX_CHANCE` e
`HUMAN_ERROR_CURVE`.

## Il pallonetto del giocatore (2026-09-23)

Dai 34 pallonetti registrati nelle partite del proprietario:

| dove cade (px dalla rete, metà campo 254) | pallonetti | schiacciati dall'IA |
|---|---|---|
| < 140 | 17 | 6 |
| 140-170 | 9 | 5 |
| 170-190 | 5 | 0 |
| ≥ 190 | 3 | 0 |

Oltre i 170 px l'IA non ha mai schiacciato. La curva vecchia arrivava a 170 solo con una
carica di circa 0,8, e il proprietario carica di solito tra 0 e 0,3. Il pallonetto dell'IA mira
a 202 px (`apply_computer_shot`): quello umano era il più debole dei due.

**Nuova curva** (`sim.gd`, ramo `lob` dei colpi umani), misurata con `hit_ball` reale:

| carica | prima | ora |
|---|---|---|
| 0 | 101 | 123 |
| 0,5 | 147 | 172 |
| 1,0 | 198 | 226 |

**Errore di profondità secondo il timing.** Prima era simmetrico, quindi un pallonetto preso
male poteva cadere più profondo di uno buono: i più profondi del proprietario (184-206 px)
erano tutti in anticipo e senza carica. Ora in anticipo accorcia, in ritardo allunga, in tempo
resta simmetrico. Stessa singola estrazione casuale di prima, quindi il resto della partita non
si sposta. Misurato: in anticipo mediana 124 px (massimo 184), in ritardo mediana 217 px.

Il pallonetto dell'IA non cambia. Partite registrate identiche, test generale invariato.

## Pallonetto da calibrare, e avversario che attacca quelli corti (seconda passata)

Richiesta del proprietario: un pallonetto a carica media non deve essere un modo sicuro per
prendere fiato. Va calibrato bene, altrimenti l'avversario, soprattutto ai livelli alti, lo
attacca e lo schiaccia.

**Curve più ripide** (solo colpi umani, misurate con `hit_ball` reale, Maestro):
- normale: carica 0,4 → 165 px, 0,45 → 173, 0,6 → 197, 0,85 → 237, **0,9 e oltre fuori**;
- difensivo: finestra più larga e più corta (0,4 → 171, 0,9 → 231), carica piena fuori;
- globo: riesce con qualità ≥ 0,82 (prima 0,72), oltre 0,85 di carica va fuori, finestra per
  ripremere 0,5 s (prima 0,7). Nuovo messaggio `evGloboLong`.

**L'avversario ora attacca i pallonetti corti.** Tre cause, tutte trovate seguendo un
pallonetto tick per tick:
1. la palla veniva assegnata al giocatore di fondo, e quello a rete (l'unico che schiaccia)
   non poteva toccarla. Ora `ai_overhead_receiver` la assegna a chi può prenderla sopra la
   testa;
2. finché la palla era nella metà del giocatore, la coppia andava in posizione di "reset" in
   fondo. Ora il giocatore scelto va verso il punto dello smash;
3. il pianificatore considerava "da schiacciare" solo i pallonetti entro 126 px dalla rete.
   Ora usa la zona del livello.

Zona e altezza dello smash crescono con il livello (`AI_OVERHEAD_*`): Leggenda schiaccia da
circa 144 px dalla rete e fino a circa 119 px di altezza, Rivale come prima. Misurato con la
coppia in tre formazioni diverse, 20 pallonetti per carica:

| livello | pallonetti corti schiacciati | il pallonetto passa da |
|---|---|---|
| Rivale | circa metà, a volte | 165 px |
| Ingegnere | 55-65% | 173 px |
| Campione | 65-75% | 182 px |
| Leggenda | 70-85% | 197 px |

Controllo col giocatore automatico: livello 1 → 9,4% di punti vinti (prima 8-10%), livello 3
→ 1,6% (prima 1,1%). Partite registrate m1 e m3 riregistrate (il comportamento dell'IA è
cambiato di proposito), m2 identica.

Nota sul metodo: le prove sintetiche precedenti sul pallonetto non erano valide. La partita di
prova non giocava il servizio, e restava impostato `aiServiceReceiverKey`, che manda
l'avversario in posizione di ricezione. Corretto azzerandolo.

## Il pallonetto buono scavalca (terza passata)

Richiesta del proprietario: un pallonetto fatto bene, a seconda di dove si trova l'avversario,
deve scavalcarlo e costringerlo a far rimbalzare la palla o a rincorrerla.

**Regola:** nel momento del colpo umano, l'avversario decide **una volta sola** (come un
giocatore) se il pallonetto è da smash (`State.aiOverheadPlan`: chi lo prende e dove) oppure
se lo scavalca (`State.aiLobOver`). Se lo scavalca **non può voleare**: arretra e lo gioca dopo
il rimbalzo o dopo il vetro di fondo (`ai_glass.gd`), oppure corre verso il punto di rimbalzo.
Ripetere la decisione a ogni tick la faceva cambiare a metà volo, e gli smash andavano persi.

Correzioni trovate strada facendo:
- la decisione veniva presa prima che la simulazione registrasse chi aveva colpito
  (`lastHitterSide` si scrive dopo il blocco del ricevitore), quindi non scattava mai;
- la zona smash per livello è stata ridotta (`AI_OVERHEAD_ZONE_PER_SKILL` 25): Leggenda
  schiaccia da circa 137 px dalla rete.

Misura (20 pallonetti per carica, con la coppia in formazioni diverse, anche tutta a rete):

| | pallonetto corto | pallonetto buono |
|---|---|---|
| **Leggenda** | fino a 190 px: schiacciato 70-80% | da 205 px (carica 0,65): **dopo il rimbalzo**; a 237 px **dopo il vetro** |
| **Rivale** | fino a 173 px: schiacciato circa 50% | da 190 px (carica 0,55): dopo il rimbalzo o dopo il vetro |

Finestra del pallonetto normale a Leggenda: carica circa 0,65-0,85. Sotto viene schiacciato,
sopra va fuori. Nei livelli bassi la finestra è più larga.
Controllo col giocatore automatico: livello 1 → 11,3% dei punti, livello 3 → 0,7%.
Partite registrate m1 e m3 riregistrate.

## 2026-09-24 — "late" on screen means long, always

In the owner's match of 14:31 (Leggenda, 0-11), 5 shots graded "late" went into the net.
The grade reads only how far the ball passed the athlete (`passed_distance > late_grace`);
the error direction read `timingBias = late_miss - early_miss`, and against a smash the
player often pressed early AND let the ball pass, so the early part won. `shot_is_late()`
now counts a shot as late when the grade says so or the bias leans late; it drives both
`roll_shot_error` (long vs net) and the lob's timing-biased depth error. Human-only.
Goldens m1/m3 re-recorded: in each, one post-smash `evShotNet` became `evShotLong` →
`msgWallNoBounce`; m2 identical.

**Refined the same day (owner: "alcune volte è anche giusto che vada a rete", "non dipende
anche dalla carica?").** A late error goes long only when `late_error_goes_long(contact_z,
charge)`: charge >= 0.5 (`LATE_LONG_CHARGE`) OR contact at/above the net height (38 px).
A soft swing at a ball scooped from below the net goes into the net. The long error now
lands `30 + charge*40` px beyond the back line (was a fixed 30), at all three long-error
sites (drive, lob, overhead). Goldens re-recorded again: m1's tick-1924 late shot, taken at
z~3 px after the bounce with a soft charge, went back to `evShotNet`; m3's post-smash long
lands a little deeper. m2 identical.

## 2026-09-24 — lob curve with a knee at charge ~0.35

Three matches, 50 human lobs, all charged 0-0.35: none reached 205 px, Leggenda attacked
them all. `lob_curve` now climbs fast up to `LOB_KNEE_RATIO` (power_ratio 0.31, charge
~0.35) and slowly after. Probe (20 seeds per charge, Leggenda, one at 75 px, one at 200):

| charge | normal lob | AI | defensive lob | AI |
|---|---|---|---|---|
| 0.0 | 130 px | attacked | 143 px | attacked |
| 0.2 | 173 px | attacked | 174 px | mostly attacked |
| 0.3 | 193 px | 14/20 attacked | 190 px | after bounce |
| 0.4 | 210 px | after bounce | 204 px | after glass |
| 0.6 | 233 px | after glass | 223 px | after bounce |
| 0.7 | 243 px | after glass | 232 px | after bounce |
| 0.8 | out | — | 242 px | after glass |
| 0.9+ | out | — | out | — |

(Before: normal 205 px only at ~0.65, out from 0.9; defensive 183 px at 0.5, out at 1.0.)
Goldens unchanged (no human lob in m1-m3).

## 2026-09-24 — the AI reads the lob by where it stands

`ai_overhead_receiver` used a fixed overhead depth from the net (126 + skill), so with
~1.4 s of flight any AI backed into it and a lob worked the same wherever the pair stood.
Now each athlete can plan an overhead only up to `own distance from net + 30 + stretch*40`
px (`AI_OVERHEAD_BACKPEDAL_*`), capped at 200 (`AI_OVERHEAD_MAX_DEPTH_PX`). The execution
gates (smash only within 126 + stretch*25) are unchanged, so a deep player takes a good lob
as a high volley, not a smash. In the owner's matches Leggenda stood at 70-90 px when he
lobbed, 100-170 px about one time in four. Probe, 20 seeds, human lob by charge:

Leggenda: at the net (72/80) a 0.3 lob (193 px) now passes (after the glass, 20/20; before:
attacked 14/20); 0.2 (173 px) is still smashed. With one player at 160, or both at 120+,
lobs at 0.4-0.6 (210-233 px), which pass a net pair, are volleyed in the air 20/20.
Rivale: at the net a 0.2 lob already passes; deeper pairs volley 0.3-0.5.
Goldens identical (no human lob in m1-m3); slice 338/338.

## 2026-09-24 (later) — narrower lob window, Leggenda finishes overhead lobs

Owner's 15:06 match: 20 lobs in court, Leggenda smashed 2, swung a soft high drive at 7
(contact 110-150 px from the net, where the generic smash chance is low), let 11 bounce.
- Knee moved: `LOB_KNEE_RATIO` 0.386 (charge ~0.45), `LOB_KNEE_RATIO_DEFENSIVE` 0.347
  (~0.4). Normal: 0 -> 105, 0.2 -> 149, 0.35 -> 182, 0.45 -> 203, 0.6 -> 228, 0.7 -> 243,
  0.75+ out. Defensive: 0 -> 133, 0.3 -> 182, 0.45 -> 205, 0.85 -> 240, ~0.9+ out.
- `choose_computer_shot`: on an unbounced human lob with `overhead_ready`, the smash chance
  has a floor `stretch/0.44 * AI_LOB_SMASH_TOP (0.85)`: Leggenda ~85%, Rivale unchanged.
Probe, Leggenda at the net (72/80): charge <= 0.35 smashed 14-17/20; 0.4 (192 px) passes;
at 90/100 or with one player deep, lobs up to 0.4 are smashed and 0.45+ taken on the volley.
Rivale at the net: 0.3 already passes. Goldens identical; slice 338/338.

## 2026-09-24 — chasing the lob: turn-and-run, and the partner drops back once

- `game/athletes_view.gd::_sync_chase_turn` (presentation only): an athlete retreating at
  run speed while the ball's ballistic landing (`landing_y`) is > 45 px deeper than them
  turns its back to the net (~0.2 s) and plays `run`; it faces the net again 0.4 s before
  the landing, once the ball has bounced on its side, or after a 0.12 s stop.
- `sim.gd::move_opponent_team`: on a `lob-*` wait plan the partner's depth follows the
  receiver's plan instead of the ball's current depth (traced: support 170 -> 114 -> 184 px
  as the lob crossed the net; now 170 -> 184). Goldens identical, lob probe identical.
