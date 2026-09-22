# Maestro — verifica visiva dei tre outfit 3D

Esito: **catture eseguite e valide.** 64 fotogrammi (4 stati × 4 pose × 2 lati × 2
scale) più la tavola comparativa etichettata, prodotti dalla cattura reale nella scena
studio; confronto oggettivo eseguito sui pixel con i tre gate accesi, tutti passati.

Il risultato che conta per il rischio noto: **`circuit` e `signature` si separano
sullo schermo.** Il 42.69% dei pixel del corpo cambia fra i due (46.45% a figura
intera, 41.96% in primo piano), con differenza media 21.36/255 e 50.03/255 sui soli
pixel mossi: sono la coppia **più vicina** delle tre, come la corsia della palette
aveva previsto misurando gli sprite, ma non sono la stessa cosa. Vedi §6.

Nessun commit, nessun push, nessun file di gioco modificato. Checkout:
`/Users/alessiofantini/Documents/steam-circuit-padel-11m`, ramo
`codex/integrate-arena-11m`, albero già sporco di lavoro altrui e non toccato.

| artefatto | percorso | stato |
| --- | --- | --- |
| cattura | `godot/tests/outfit_maestro_capture.gd` | eseguita, exit 0, `written=64 failures=0` |
| tavola | `docs/agent-work/outfits-3d/evidence/renders-maestro/maestro-lineup.png` | prodotta (1280×512, quattro colonne etichettate) |
| fotogrammi | `docs/agent-work/outfits-3d/evidence/renders-maestro/*.png` | 64, 640×640 ciascuno |
| confronto | `tools/character/compare_maestro_renders.py` | eseguito, exit 0, `COMPARE_MAESTRO_RENDERS_PASS` |
| report macchina | `docs/agent-work/outfits-3d/evidence/maestro-render-compare.json` | scritto |
| questo documento | `docs/agent-work/outfits-3d/MAESTRO-RENDER.md` | — |

---

## 1. Dipendenza: il profilo `&"maestro"`, e il gate che ha funzionato due volte

`OutfitCatalogue.apply()` ha tre esiti (intestazione di `outfit_catalogue.gd`): con un
profilo si prende il percorso mascherato; senza profilo un atleta dedicato **conserva
il proprio materiale baked** e la selezione viene solo registrata. Per il Maestro
questo profilo è di un'altra corsia e non era presente quando questa lane è partita.

Perciò `outfit_maestro_capture.gd` **rifiuta di partire** se
`OutfitCatalogue.has_profile(&"maestro")` è falso: stampa
`OUTFIT_MAESTRO_PROFILE present=false`, l'errore, `OUTFIT_MAESTRO_CAPTURE_FAIL
profile_absent written=0 failures=1` ed esce con codice 1 **prima** di scrivere
qualunque file. Un render senza profilo è indistinguibile pixel per pixel dal render
della base, e la cartella di evidenza non deve poter restare piena di 64 fotogrammi
identici con quattro etichette diverse sopra. L'opzione `--allow-missing-profile`
esiste solo per provare l'impalcatura e lo dichiara nel log.

Il gate è servito una seconda volta, sui **pixel** invece che sul profilo: la prima
esecuzione con il profilo presente è uscita **1** con

```
SHADER ERROR: No matching function found for: 'value_band_weight'.
ERROR: Shader compilation failed.
ERROR: outfit_maestro_capture: circuit and signature carry identical shader targets on this rig
OUTFIT_MAESTRO_CAPTURE_FAIL written=64 failures=1
```

Il gate per valore che l'altra corsia stava aggiungendo a
`outfit_region_recolour.gdshader` chiamava `value_band_weight()` **prima** della sua
definizione (riga 153 contro riga 160): in Godot Shading Language le funzioni vanno
definite prima dell'uso, lo shader non compilava, e i tre outfit rendevano tutti lo
stesso materiale rotto — nel log `targets=` vuoto per tutti e quattro gli stati, e
nella tavola tre figure grigie non texture e identiche. Dopo la correzione dell'altra
corsia (16:43) la cattura è passata con `written=64 failures=0` e i sei target più il
gate per valore leggibili sul materiale vivo:

```
OUTFIT_STATE circuit  ... target_torso_a=(0.192,0.361,1.0)  target_torso_b=(0.110,0.200,0.353)
                          target_hip_a=(0.192,0.361,1.0)    target_hip_b=(0.620,0.973,1.0)
                          target_foot_a=(0.094,0.208,0.404) target_foot_b=(0.620,0.973,1.0)
                          value_gate_enabled=true value_band_a=(0.0,0.74) value_band_b=(0.76,1.0)
                          value_band_feather=0.01
```

Questo è il motivo per cui il controllo a livello di materiale esiste: cattura il caso
"le due voci sono identiche" **prima** che si guardino 64 fotogrammi. Che i due outfit
restino distinti anche **sullo schermo** lo dice invece solo il confronto sui pixel
(§6), ed è un controllo diverso.

`base` non porta nessuno shader: `targets=` vuoto è l'esito corretto, perché `base`
restituisce alla mesh il materiale proprio del rig.

## 2. Comandi ed exit code

Godot: `/Applications/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official`.
Python del confronto: venv con numpy 2.0.2 e Pillow 11.3.0 (nessun numpy/Pillow di
sistema: `/usr/bin/python3 -m venv <scratch>/maestro-venv`). Tutti i comandi dalla
radice del repo.

| # | comando | exit | esito |
| --- | --- | --- | --- |
| 1 | `Godot --path godot --script res://tests/outfit_maestro_capture.gd -- --out=/tmp/maestro-smoke --allow-missing-profile` (prima che il profilo esistesse) | **0** | smoke test dell'impalcatura: 64 frame + tavola, `OUTFIT_MAESTRO_CAPTURE_PASS` |
| 2 | `<venv>/bin/python tools/character/compare_maestro_renders.py --dir /tmp/maestro-smoke --require-distinct` | **1** | sulle catture senza profilo: `circuit/legend/signature identical to base`, come deve essere |
| 3 | `<venv>/bin/python <scratch>/synth_maestro_renders.py /tmp/maestro-synth` | **0** | fixture sintetico a differenze note (§5) |
| 4 | `<venv>/bin/python tools/character/compare_maestro_renders.py --dir /tmp/maestro-synth/variants --require-distinct --require-separable --skin-max-mean 1.0` | **0** | `COMPARE_MAESTRO_RENDERS_PASS` |
| 5 | idem, `--dir /tmp/maestro-synth/identical --require-distinct --require-separable` | **1** | quattro stati identici: gate falliti correttamente |
| 6 | `Godot --path godot --script res://tests/outfit_maestro_capture.gd -- --out=docs/agent-work/outfits-3d/evidence/renders-maestro` (prima esecuzione col profilo, shader non compilante) | **1** | `written=64 failures=1`, `SHADER ERROR`, gate circuit/signature fallito |
| 7 | idem, dopo la correzione dello shader | **0** | `written=64 failures=0`, 65 PNG in `renders-maestro/` |
| 8 | `<venv>/bin/python tools/character/compare_maestro_renders.py --dir docs/agent-work/outfits-3d/evidence/renders-maestro --json-out docs/agent-work/outfits-3d/evidence/maestro-render-compare.json --require-distinct --require-separable --skin-max-mean 2.5` | **0** | `COMPARE_MAESTRO_RENDERS_PASS`, nessun gate fallito |

Le catture girano **senza** `--headless`: senza framebuffer `root.get_texture()`
restituisce un'immagine vuota.

`--skin-max-mean 2.5` è una soglia, non una misura: sta sopra il residuo misurato
(1.88/255 sul canale peggiore, §7) e sotto qualunque ricolorazione reale della pelle.
Sulla Fiamma lo stesso numero era 0.94/255.

## 3. Cosa fa la cattura, e le quattro correzioni già pagate dalla corsia Fiamma

`outfit_maestro_capture.gd` è modellato su `godot/tests/outfit_fiamma_capture.gd`, e le
quattro correzioni che quella corsia ha imparato sono nel file, non nella sua storia:

1. **tutti gli altri rig nascosti prima di ogni render.** Quattro rig vivi alla stessa
   origine, tutti visibili, rendono quattro mesh coincidenti: una mesh sola e nessuna
   prova. Il ciclo fa `visible = (other == state)` per ogni stato.
2. **framebuffer quadrato.** La cattura legge il framebuffer della finestra, quindi la
   finestra *è* la dimensione di uscita: `window_set_size` + `root.size` +
   `root.content_scale_size` a 640², poi 1280×512 per la tavola.
3. **clip in pausa e fasi normalizzate.** Ogni posa è `play_clip()` +
   `sample_at(phase * get_clip_length())` + `_anim.pause()`: la posa è un valore, non
   una corsa con il frame loop. Le fasi sono le stesse di Fiamma (idle 0.45, run 0.35,
   backhand 0.50, smash 0.50), così i due atleti restano confrontabili.
4. **spazio colore.** Non è compito di questo programma: la conversione sta nel
   fragment shader (`OUTPUT_IS_SRGB` in `outfit_region_recolour.gdshader`) e la
   cattura non post-processa nulla.

Copertura: 4 stati × 4 pose (`idle`, `run`, `backhand`, `smash`) × 2 lati (`front`,
`back`) × 2 scale (`close` = primo piano del busto, `match` = figura intera) = **64
fotogrammi** più la tavola. Nomi: `maestro_<stato>_<posa>_<lato>_<scala>.png`. La
tavola nasce dalla cattura stessa, non da un montaggio a parte: quattro colonne a
1.15 m l'una dall'altra, camera ortogonale derivata dall'estensione misurata del rig,
etichette `BASE / CIRCUIT / LEGEND / SIGNATURE` centrate sopra ogni figura.

Il Maestro porta le clip `meshy_backhand` e `meshy_smash` da
`assets/athletes/animations/maestro_meshy_*.tres`, come Fiamma; `idle` e `run` arrivano
dai GLB companion (`maestro-idle.glb`, `maestro-running.glb`, `COMPANION_CLIPS` in
`athlete_rig.gd`). Nessuna clip è mancata: `failures=0`.

## 4. Lo strumento di confronto, e perché i suoi numeri sono attribuibili

`tools/character/compare_maestro_renders.py` legge **solo** i PNG della cattura. Non
esegue Godot, non scrive nella cartella di evidenza, non tocca la rete.

**(a) maschera del corpo.** Questa cattura non produce un fotogramma di solo sfondo,
quindi lo sfondo è stimato dal bordo del fotogramma (anello di 4 px, colore modale →
`rgb8 (20,23,28)`, identico per tutti e quattro gli stati) e "corpo" è ogni pixel che
se ne allontana di più di 6/255 su almeno un canale. La maschera è calcolata **una
volta per (posa, lato, scala) e unificata sui quattro stati**, così ogni coppia è
misurata esattamente sugli stessi pixel; il report porta anche
`max_mask_disagreement_frac`, cioè quanto le maschere dei quattro stati disaccordano
fra loro: **9.2e-05** al massimo (0.009% dei pixel del corpo), cioè la geometria è la
stessa e le maschere coincidono. A figura intera, `idle_front_match`: 54 018 px di
corpo, 13.19% del fotogramma.

**(b) metriche per coppia.** Sui pixel del corpo, per ogni coppia e per ogni scala
separatamente: differenza assoluta media per canale, p95 per canale, massimo per
canale, media euclidea, media **con segno** per canale, frazione di pixel mossi oltre
4/255 e oltre 16/255, e differenza media **sui soli pixel mossi**. Media, p95 e massimo
sono accumulati come istogrammi a 256 bin per canale: i percentili sono esatti e la
memoria non cresce col numero di fotogrammi.

Perché un delta è il capo e nient'altro: studio, luci, camera e posa sono identici per
costruzione fra i quattro stati (stessa scena, stesso `sample_at`, stesse luci senza
ombre), le mesh sono le stesse, e le maschere coincidono al 99.99%: cambia solo il
materiale di superficie.

**(c) la pelle — e qui la dichiarazione conta.** È un'**euristica sul colore, non una
prova semantica**. I pixel di pelle si scelgono sul fotogramma **base** con tinta HSV
in [9.0, 37.8]°, saturazione > 0.30 e valore > 0.30 (la finestra che usa già il port e
in cui cade la pelle dichiarata del Maestro, `#c98258`, tinta 25°, sat 0.56), e poi si
differenziano **le stesse coordinate** fra variante e base. Limiti, detti: la finestra
non distingue la pelle da un capo caldo, da una scarpa o da un bordo antialiasato, e
può mancare un texel la cui ombreggiatura l'ha spinto fuori; e siccome la selezione è
fatta sulla base, una variante che ridipinge un texel che la finestra non ha mai
selezionato non compare qui. Il numero **limita** il problema, non lo chiude: l'ultima
parola resta a un'ispezione visiva.

Il report è JSON su stdout (`--json-out` per scriverlo anche su file) e un riassunto
leggibile su stderr, così stdout resta JSON puro.

## 5. Verifica dello strumento su un fixture a differenze note

Il fixture (`synth_maestro_renders.py`, in scratch, non nel repo) dipinge: sfondo
`(20,23,28)`, un corpo rettangolare di 134 400 px, un cerotto di pelle `#c98258` di
2 250 px per fotogramma, e per ogni variante un rettangolo di capo di area nota.
Attesi e ottenuti:

| grandezza | atteso | misurato |
| --- | --- | --- |
| pixel del corpo (`idle_front_match`) | 560 × 240 = 134 400 | 134 400 |
| campioni di pelle sulle 8 viste `match` | 2 250 × 8 = 18 000 | 18 000 |
| `circuit` vs base, pixel mossi >4/255 | 40 000/134 400 = 0.2976 | 0.2976 |
| `legend` vs base, pixel mossi >4/255 | 56 000/134 400 = 0.4167 | 0.4167 |
| `circuit` vs base, massimo per canale | (9, 32, 135) | [9, 32, 135] |
| `circuit` vs `signature`, massimo per canale | (46, 107, 18) | [46, 107, 18] |
| pelle, media per canale, tutte le varianti | 0 | [0, 0, 0] |
| set con i quattro stati identici | tutti identici, gate falliti | tutti identici, `COMPARE_MAESTRO_RENDERS_FAIL`, exit 1 |

Lo strumento riporta esattamente le aree, i canali e gli zeri che il fixture ha
costruito, e distingue "le varianti differiscono" da "sono lo stesso fotogramma".

## 6. Risultati sui render del Maestro

Tutti i numeri di questa sezione vengono da
`docs/agent-work/outfits-3d/evidence/maestro-render-compare.json`, prodotto dal
comando 8. 64/64 fotogrammi presenti, 32 per scala, 4 pose × 2 lati ciascuno.

### (a) ogni variante contro la base

| coppia | media /255 | p95 per canale | max per canale | media euclidea | media con segno (R,G,B) | mossi >4/255 | >16/255 | media sui mossi |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| circuit vs base | 35.51 | [35, 75, 178] | [224, 201, 210] | 74.04 | +11.2, +23.3, **+65.1** | 47.67% | 43.12% | 74.48 |
| legend vs base | **67.09** | [225, 208, 134] | [251, 236, 202] | 120.80 | **+81.4, +73.0**, +37.7 | 47.70% | 43.15% | 140.64 |
| signature vs base | 44.35 | [12, 197, 175] | [224, 229, 210] | 92.05 | −3.5, **+64.2, +59.0** | 47.66% | 43.09% | 93.05 |

Lettura: **legend** è la variante che si allontana di più dalla base e nel modo più
riconoscibile — media con segno fortemente positiva su R e G, cioè molto più chiara,
che è quello che ci si aspetta da un completo avorio/oro su una base navy. **circuit**
spinge sul blu (+65 sul canale B). **signature** spinge su G e B lasciando R quasi
fermo: ciano. Le tre varianti toccano la stessa **quantità** di figura (47.7% dei pixel
del corpo), che è la firma attesa di un cambio di sola palette: la geometria e l'area
del capo non cambiano.

### (b) le varianti fra loro

| coppia | media /255 | media euclidea | mossi >4/255 | media sui mossi |
| --- | --- | --- | --- | --- |
| circuit vs legend | 49.94 | 94.95 | 42.77% | 116.77 |
| **circuit vs signature** | **21.36** | **49.42** | **42.69%** | **50.03** |
| legend vs signature | 38.98 | 89.67 | 42.76% | 91.17 |

**La coppia circuit/signature è la più vicina delle tre**, con la media più bassa
(21.36 contro 49.94 e 38.98) e la media euclidea più bassa (49.42). Questo conferma la
previsione della corsia della palette, che misurando gli sprite aveva trovato i due
pantaloncini a ΔE76 22.2 con lo stesso valore e le due famiglie `b` di `hip` come lo
stesso bianco (`MAESTRO-PALETTE.md` §6).

Ma **non collassano**: il 42.69% dei pixel del corpo cambia fra i due, e sui pixel mossi
la differenza media è 50.03/255 — cioè un quinto dell'intera scala. Per scala:

| scala | pixel mossi >4/255 | media /255 |
| --- | --- | --- |
| `close` (busto) | 41.96% | 20.61 |
| `match` (figura intera) | **46.45%** | 25.23 |

La separazione è **più forte a figura intera che in primo piano**, che è la direzione
giusta: gli elementi che li distinguono (pantaloncini e scarpe) stanno in basso e a
figura intera pesano di più. Il segno per canale di circuit−signature è (+14.7, −40.9,
+6.0): signature è più verde, circuit più rosso, a parità di blu — coerente con
royal-blue contro ciano.

Il gate per valore che l'altra corsia ha aggiunto allo shader è quindi **necessario e
sufficiente** su questo atlante: con la sola tolleranza di tinta i due anchor del
Maestro (196.5° e 217.1°) distano 20° sotto una tolleranza di 42°, e le sei slot
sarebbero collassate su un colore per regione. Con le bande di valore `[0, 0.74]` e
`[0.76, 1.0]` le due famiglie si indirizzano separatamente, e `circuit` lo mostra: la
maglia prende `target_torso_a = #315cff` mentre il pannello scuro prende
`target_torso_b = #1c335a`, due valori diversi sulla stessa regione.

### (c) lettura visiva della tavola

`renders-maestro/maestro-lineup.png` (1280×512) è la tavola richiesta: quattro figure
affiancate, tutte intere in inquadratura, etichette leggibili sopra ciascuna. Letta a
vista:

* **BASE** — completo navy con la fascia bianca diagonale, scarpe blu con suola bianca;
* **CIRCUIT** — completo blu royal, pantaloncini blu, scarpe blu;
* **LEGEND** — maglia avorio, pantaloncini oro scuro/oliva, scarpe avorio;
* **SIGNATURE** — maglia ciano, pantaloncini teal scuro, scarpe ciano.

La striscia bianca diagonale sul petto **resta la stessa in tutte e quattro** — e non
poteva essere altrimenti: è il bianco condiviso della base, e con due sole famiglie per
regione non è esprimibile (`MAESTRO-PALETTE.md` §4 lo aveva previsto). Anche la fascia
bianca e i polsini restano quelli baked. Questo è un **adattamento di palette**, non
una ricostruzione delle grafiche illustrate: è la stessa dichiarazione che la corsia
Fiamma ha messo nel suo REPORT.

## 7. Controllo della pelle

Euristica dichiarata in §4c. Campioni selezionati sul fotogramma base: **124 855**
sulle 8 viste a figura intera (`match`, il set confrontabile con la misura Fiamma),
463 064 sui primi piani (`close`), 587 919 su tutti e 32 i fotogrammi. Le tre varianti
danno **gli stessi numeri a quattro decimali**:

| grandezza | circuit | legend | signature |
| --- | --- | --- | --- |
| media per canale (R,G,B) /255 | 1.8813, 1.3303, 1.0081 | 1.8813, 1.3303, 1.0081 | 1.8813, 1.3303, 1.0081 |
| p95 per canale | [7, 5, 4] | [7, 5, 4] | [7, 5, 4] |
| massimo per canale | [147, 98, 64] | [147, 98, 64] | [147, 98, 64] |
| mossi >8/255 | 3.36% | 3.36% | 3.36% |
| mossi >16/255 | 1.12% | 1.12% | 1.12% |

Il numero da guardare per primo è però un altro, e sta nella sezione
`skin_check.pairwise_between_variants` dello stesso report: **variante contro variante,
sugli stessi pixel di pelle, la differenza è esattamente zero** — media [0, 0, 0] e
massimo [0, 0, 0] su tutti e tre gli accoppiamenti, 587 919 campioni. Cioè: **nessun
pixel di pelle cambia a seconda dell'outfit indossato.** Il residuo di ~1.88/255 contro
la base non è una ricolorazione della pelle: è la differenza fra i due **percorsi di
ombreggiatura**, perché `base` è l'unico stato che usa lo `StandardMaterial3D` del rig
mentre le tre varianti usano il `ShaderMaterial` mascherato. Se gli outfit toccassero
la pelle, i due outfit si differenzierebbero fra loro esattamente lì.

Dove stanno i pixel che si muovono di più: sui 32 fotogrammi, 19 986 campioni (3.4%)
si muovono oltre 8/255 e **518 (0.088%)** oltre 32/255. Di questi 518, **293 (57%)
stanno entro 2 px dal contorno della figura**, cioè sui bordi antialiasati dove i due
percorsi di ombreggiatura disegnano il bordo in modo leggermente diverso; gli altri
stanno dentro la figura, nella zona orlo-pantaloncini/coscia nuda che la corsia della
maschera ha misurato (51 759 texel di pelle nella regione `hip`). Nessuno dei due
gruppi è una macchia di pelle ridipinta.

**Questo resta un'euristica.** Non ho isolato il meccanismo del residuo base↔shader, e
la finestra di tinta non distingue la pelle da un capo caldo o da un bordo: il
controllo **limita** il problema e non lo chiude. L'ultima parola è a un'ispezione
visiva dei fotogrammi.

## 8. Limiti onesti

1. **La tavola e i 64 fotogrammi sono di uno stato del codice, non del gioco.** Sono la
   scena studio di questo harness con il profilo `&"maestro"` come era alle 16:43 di
   oggi. Se il profilo o lo shader cambiano, i numeri di §6 e §7 invecchiano: il report
   JSON è la fotografia di quel momento.
2. **La scala `match` è la camera di questo harness**, non la camera di partita: la
   scena `Match` reale non è stata renderizzata. La corsia Fiamma aveva un secondo
   script per quello; qui non c'è, e "si legge in partita" resta non misurato.
3. **Il controllo pelle è un'euristica** (§4c, §7): finestra di tinta sulla base,
   applicata alle stesse coordinate nelle varianti. Non è una prova semantica e non
   copre un texel che la finestra non ha selezionato. Il residuo base↔shader
   (1.88/255) è misurato ma non spiegato meccanismo per meccanismo.
4. **Lo sfondo è inferito dal bordo del fotogramma**, non misurato con un fotogramma di
   solo sfondo che questa cattura non produce. La stima è `(20,23,28)`, identica per
   tutti e quattro gli stati, e il disaccordo fra le maschere è 9.2e-05: entrambi sono
   nel report proprio perché siano controllabili.
5. **La verifica dello strumento è sintetica** (§5): prova che il comparatore misura
   aree, canali e percentili come dichiarato, non che i render reali siano ben esposti o
   privi di artefatti. Quello lo dice solo l'ispezione visiva delle catture vere, che ho
   fatto sulla tavola (§6c) e su un primo piano.
6. **Le soglie sono scelte, non misurate.** `--change-eps 4`, `--change-eps-big 16`,
   `--bg-eps 6`, `--skin-eps 8`, `--skin-max-mean 2.5`: stanno nel report sotto
   `thresholds` perché chi legge possa rifare i conti con altre. Un "mossi >4/255" al
   42.69% non è la stessa affermazione di un "mossi >16/255".
7. **Le fasce della figura non sono state separate.** Il confronto è sul corpo intero e
   per scala, non per regione (torso/bacino/piede): mappare i pixel di schermo sulle
   regioni della maschera richiederebbe di renderizzare la maschera stessa. La domanda
   "circuit e signature si distinguono sul bacino?" resta quindi senza una risposta
   per regione — l'aggregato dice che si distinguono, non dove.
8. **La prima esecuzione è fallita per un file di un'altra corsia** (§1). Non l'ho
   toccato: `outfit_region_recolour.gdshader` e `outfit_catalogue.gd` sono stati letti
   e mai scritti. La correzione è arrivata dalla corsia che li possiede.
9. **Fuori scope per istruzione:** l'outfit `mythic` del Maestro.

## 9. File

| file | cosa è |
| --- | --- |
| `godot/tests/outfit_maestro_capture.gd` | la cattura: 4 stati × 4 pose × 2 lati × 2 scale + tavola etichettata, con i due gate (profilo, target circuit≠signature) |
| `tools/character/compare_maestro_renders.py` | confronto oggettivo: varianti vs base, varianti fra loro, euristica pelle con dichiarazione, gate opzionali |
| `docs/agent-work/outfits-3d/evidence/renders-maestro/maestro-lineup.png` | la tavola: quattro varianti affiancate, etichette leggibili |
| `docs/agent-work/outfits-3d/evidence/renders-maestro/maestro_<stato>_<posa>_<lato>_<scala>.png` | i 64 fotogrammi 640×640 |
| `docs/agent-work/outfits-3d/evidence/maestro-render-compare.json` | il report macchina: maschere, sfondo, tutte le coppie, la pelle, i verdetti |
| `docs/agent-work/outfits-3d/MAESTRO-RENDER.md` | questo documento |

Non modificati: `godot/src/character/outfit_catalogue.gd`,
`godot/src/character/outfit_region_recolour.gdshader`, e qualunque altro file di gioco.
Nessun commit, nessun push.
