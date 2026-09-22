# COLOSSO — palette dell'outfit `signature`, misurata dagli sprite in campo

Specifica delle sei slot (regione × famiglia) per l'outfit `signature` del Colosso,
**derivata misurando gli sprite**. Nessuna modifica al gioco, nessun commit.
Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, ramo
`codex/integrate-arena-11m`. L'albero era già sporco di lavoro altrui e non è stato toccato.

Strumento: `tools/character/measure_colosso_palette.py` (numpy + PIL, nessuna rete).
Report macchina e stdout completo dello strumento:
`docs/agent-work/outfits-3d/evidence/colosso-palette/`.
Formato di riferimento: la voce `fiamma` di `OUTFIT_PROFILES` in
`godot/src/character/outfit_catalogue.gd` (letto, non modificato).

**Fuori scope, per istruzione:** l'outfit `mythic` del Colosso (richiede geometria nuova via
Meshy: maglia chiara a maniche, cintura, drappeggio frontale). Non è stato letto, non è stato
misurato e non compare in nessuna tabella di questo documento.

**Risposta breve, perché chi legge deve saperla subito.** La palette è derivabile, ma su
questo atleta **non è derivabile dagli sprite**: cinque delle sei modi misurate sono
l'ombreggiatura neutra del disegno, non il colore del capo, e vengono scartate (§4). Cinque
slot su sei sono quindi i **due colori dichiarati** dal riferimento, e uno è misurato.

Le due cose che possono far fallire l'outfit sono misurate entrambe, e la seconda è peggiore
della prima:

1. **Le slot `torso_a` e `hip_a` sono inerti**: il cuoio dichiarato `#25211e` sta a **ΔE76
   4.3** dal cuoio già cotto nel modello, quindi dipingerlo non cambia niente che si veda
   (§7.3). E senza un value gate le sei slot **collassano** su un colore per regione (§7.1).
2. **L'arancio e la pelle non sono separabili, né per colore né per maschera.** Per tinta
   distano **3.5°** (§8.1), e la maschera UV non tiene la pelle fuori dalla propria copertura:
   **45 059 texel di pelle nuda stanno dentro la maschera**, con peso pieno da entrambe le
   famiglie, e il **97.8%** di essi cade dal lato `light` — il lato che le slot `*_b`
   ricolorano (§8.2). La corsia che possiede la maschera lo dichiara con un **NO**.

Quindi: **le tre slot `*_a` sono una ricolorazione invisibile per costruzione, e le tre `*_b`
dipingono la pelle.** Le opzioni oneste sono in §8.2; questo documento propone i valori ma non
le sceglie, perché la scelta è di chi possiede maschera e rig.

---

## 1. Metodo, in breve

| passo | come |
|---|---|
| griglia dei frame | divisione pari della striscia (`naturalWidth / frameCount`), come fa il runtime; i conteggi sono verificati contro i vuoti di alpha |
| bbox del corpo | `alpha > 200`, per frame |
| fasce | frazioni fisse dell'**altezza** della bbox: `torso 0.12–0.48`, `hip 0.48–0.62`, `foot 0.90–1.00`. Scelte dalla mappa riga-per-riga dello sprite base (§1.1), non a occhio |
| esclusi | pelle, capelli, racchetta (euristiche, §2) |
| famiglie | k-means k=2 deterministico **per (outfit, regione)**, seminato dai due bin a 16 livelli più popolosi distanti ≥ 96/255; `a` = cluster più grande, `b` = l'altro |
| valore di una famiglia | la **moda** (bin più popoloso a 16 livelli del cluster), non la media: la media include ombre e schiarisce il colore |
| distanza cromatica | CIE76 (ΔE76) su sRGB → Lab D65 |

### 1.1 La mappa riga-per-riga che fissa le fasce

Sprite base `idle`, frame 0, bbox `y 47–424` (h = 378). Corsa più larga di pixel opachi per
riga, in frazioni dell'altezza della bbox:

| frazione | corsa max (px) | cosa è |
|---|---|---|
| 0.000–0.100 | 12 → 35 | testa (capelli, faccia): la figura è stretta |
| 0.125 | 60 | spalle che si aprono |
| 0.150 | 91 | spalle |
| 0.225–0.275 | 134–141 | torace più largo (braccia comprese) |
| 0.575 → 0.600 | **108 → 55** | **orlo dei pantaloncini**: sotto, la figura si divide in due gambe |
| 0.625–0.775 | 39–56, warm 81–95% | gambe nude |
| 0.800–0.975 | neutro in salita, warm in calo | scarpe |

Quindi: testa ≈ 0.00–0.11, spalle da ≈ 0.125. La fascia `torso` che parte a **0.12** cade
sulla linea delle spalle ed **esclude la testa**; la sua parte alta non taglia la faccia.
L'orlo misurato è a **0.59–0.60** su `idle`/`run`, e la fascia `hip` (0.48–0.62) lo
attraversa (§10.7).

### 1.2 Orlo misurato per foglio (mediana del primo salto, per frame)

| foglio | base | outfit |
|---|---|---|
| idle | 0.59 | 0.59 |
| run | 0.60 | 0.60 |
| back-idle | 0.58 | 0.58 |
| action | 0.66 | 0.66 |
| back-run | 0.66 | 0.70 |
| back-action | 0.48 | 0.48 |

Il rilevatore è un **primo-salto**: su `back-action` (0.48) scatta sul braccio che attraversa
il corpo, non sull'orlo. Solo `back-action` è escluso dal numero `hip` aggregato
(`bands_sheet_policy` nel report); `idle` e `back-idle` restano dentro, perché il loro
trabocco (0.03–0.04 di altezza) è coscia nuda, cioè pelle, che la regola sulla pelle rimuove.

> **Correzione rispetto alla revisione precedente dello strumento.** La revisione
> interrotta escludeva da `hip` i fogli `("action", "back-run")`, cioè i due con l'orlo
> **più basso** (0.66), quelli in cui la fascia sta più sicuramente dentro i pantaloncini, e
> teneva `back-action`, il peggiore. La lista era invertita. È stata corretta e il motivo è
> scritto nel file; i numeri `hip` di questo documento sono quelli corretti.

### 1.3 Le due risoluzioni, e perché non si confrontano

Nelle foglie a 4 frame lo sprite base è disegnato a **298 px per frame** e quello degli outfit
a **179**; su `run` 238 contro 143. Il numero di pixel misurati **non è confrontabile fra base
e varianti**: i confronti di questo documento sono fra **modi** e fra **quote percentuali
sulla regione**, mai fra conteggi. L'unico confronto di pixel esatto è fra le due carte
(`assets/athletes/colosso.webp` e il master di `signature`, entrambe 1024×1536, §6).

La griglia pari è verificata contro i vuoti di alpha: i confini cadono sui vuoti su `idle`,
`run`, `back-idle`, `back-action` (scarto 0.0 px); **non** ci cadono su `action` (base
6.0 / 304.0 / 251.0 px, outfit 4.0 / 183.0 / 151.0) e su `back-run` non esiste alcun vuoto
(le figure si toccano). Lo slittamento è gestito misurando solo le colonne della figura
propria; in totale sono stati scartati **2259 px** (`sheet_bleed` nel report).

### Riproduzione

```sh
python3 -m venv /tmp/palette-venv && /tmp/palette-venv/bin/pip install pillow numpy
/tmp/palette-venv/bin/python tools/character/measure_colosso_palette.py
# opzioni: --out-dir <dir>  --no-evidence  --change-eps <n>
```

## 2. Le tre euristiche di esclusione (dichiarate, non esatte)

| esclusione | regola | perché / quanto è grossolana |
|---|---|---|
| pelle | hue 9–38° **e** saturazione > 0.30 **e valore > 0.50** | finestra già usata dal port, **più un pavimento sul valore** che il port non ha. La pelle dichiarata del Colosso (`#b06a3f`, hue 22.8°, sat 0.642, val 0.690) ci cade dentro. Il pavimento è **misurato**, non scelto: senza di esso la sola regola hue+sat toglierebbe il **63.5–68.2%** del corpo su `idle` (§8), perché il cuoio condivide la fascia di tinta della pelle |
| capelli | distanza max-canale ≤ 48/255 dal colore dichiarato `#1c130d` | i capelli sono quasi neri; **la stessa regola toglie anche il telaio e il manico neri della racchetta** e buona parte dei contorni scuri del disegno |
| racchetta | geometrica: dentro la fascia, il blocco di colonne del corpo è la corsa di colonne con occupazione ≥ 0.85 dell'altezza di fascia; l'inchiostro a sinistra, separato da un vuoto trasparente ≥ 3 px, è la racchetta | **NON HA MAI FUNZIONATO su questo atleta**: `racket_rule_log.applied_count` è **0** su tutti i 6 fogli × 12 frame. La racchetta **non è stata rimossa** e il pool può contenerne i pixel. È dichiarato, non nascosto |

Perché la regola della racchetta del Maestro (il blob oro più grande) non è trasferibile, e
questo è misurato: la famiglia **oro brillante** (hue 40–62°, sat > 0.6, val > 200/255) è
**0.357–1.195% del corpo** sugli sprite base e **0.000%** su quelli `signature`, e il suo blob
8-connesso più grande è **9–241 px** (241 px su `action` base): è una suola, non la faccia di
una racchetta. La racchetta del Colosso ha la faccia nera e il telaio in ottone **scuro**
(val 0.3–0.45).

> Nota a margine che vale come controprova: lo sprite `signature` ha **zero** oro brillante,
> la base ne ha 0.357–1.195%. Il `signature` toglie l'oro, non lo aggiunge (§6).

## 3. Tabella delle sei slot

`S` = dal dato sorgente (`js/data.js` ATHLETE_OUTFITS, voce colosso, variante `signature`) ·
`M` = misurato dallo sprite · `P` = scelta di port (deviazione deliberata sia dal dato sia
dallo sprite).

Dato sorgente: `colors: ["#25211e", "#ff7a12"]` — **due colori soltanto**, cuoio scuro e
arancio.

| slot | hex | origine | da dove viene |
|---|---|---|---|
| torso_a | `#25211e` | **S** | famiglia `a` = massa dominante del capo. La moda misurata è `#474545` (sat **0.030**), cioè l'ombreggiatura neutra del disegno: **scartata** dalla regola 5 (§4). Il primario dichiarato prende la slot |
| torso_b | `#ff7a12` | **S** | famiglia `b` = finitura/accento. La moda misurata è `#fffffe` (sat **0.002**), **scartata**. L'unica famiglia di accento satura e non-pelle misurata nella regione è l'arancio emissivo, **4.3%** del torso (§6) |
| hip_a | `#25211e` | **S** | come `torso_a`: moda misurata `#484645` (sat **0.042**), scartata; il cluster dominante copre l'**81.5%** della regione (90.1% sul `signature`), cioè la massa scura |
| hip_b | `#ff7a12` | **S** | moda misurata `#fffffe` (sat **0.003**), scartata; l'arancio è **3.0%** della regione `hip` |
| foot_a | `#562908` | **M** | moda misurata della regione `foot` (**7.5%** del pool, media `#5f4127`), sat 0.902: è **l'unica moda misurata su tutto l'atleta che superi il test di famiglia dello shader** (sat_min 0.18). La scarpa è la parte più gialla/oro della base (13.8% giallo+oro) e nel `signature` è un marrone scuro saturo |
| foot_b | `#ff7a12` | **S** | moda misurata `#fffffe` (sat **0.004**), scartata; l'arancio è **7.7%** della regione `foot`, la quota più alta delle tre |

Provenienza sulle sei slot: **5 dal dato sorgente**, **1 dallo sprite misurato**, **0 scelte
di port**. `port_only` è quindi **assente** dal blocco GDScript, e questo è deliberato: il
riferimento dichiara due colori, lo sprite ne mostra gli stessi due, non esiste un terzo
colore da sistemare e non c'è un secondo outfit da tenere distinto. Inventare una deviazione
qui non avrebbe una ragione misurata.

Nessun hex di questa tabella è inventato: la moda misurata di ogni slot, comprese quelle
scartate, sta nel report JSON accanto al valore proposto, con la sua quota.

## 4. Valori misurati grezzi

Pixel del capo nella fascia, dopo le esclusioni, con la moda di ciascuna famiglia (fra
parentesi la sua quota sul pool della regione) e la media del cluster, che è più chiara
perché contiene le ombre.

| regione | pool base (px) | pool `signature` (px) | base `a` | base `b` | `signature` `a` | `signature` `b` |
|---|---|---|---|---|---|---|
| torso | 88229 | 27488 | `#474545`/`#63432a` 74.9% sat 0.029 | `#fffffe`/`#e1ce98` 25.1% sat 0.002 | `#474545`/`#603f2a` 83.0% sat 0.030 | `#fffffe`/`#dfd8c6` 17.0% sat 0.002 |
| hip | 17875 | 5515 | `#484645`/`#634226` 81.5% sat 0.042 | `#fffffe`/`#d5bc79` 18.5% sat 0.003 | `#484645`/`#5f3e26` 90.1% sat 0.042 | `#fffffe`/`#cec7aa` 9.9% sat 0.003 |
| foot | 13755 | 3955 | `#572908`/`#654727` 72.1% sat 0.907 | `#fffffe`/`#e2cb85` 27.9% sat 0.002 | `#562908`/`#5f4127` 84.0% sat 0.902 | `#fffffe`/`#dbd5bf` 16.0% sat 0.004 |

Le tre modi più popolose a 16 livelli, `signature`:

| regione | #1 | #2 | #3 |
|---|---|---|---|
| torso | `#474545` 7.38% | `#57260a` 5.47% | `#fffffe` 5.16% |
| hip | `#484645` 10.52% | `#ffffff` 8.19% | `#583717` 4.09% |
| foot | `#562908` 7.48% | `#583616` 5.51% | `#494645` 4.17% |

**Qui c'è la ragione per cui cinque slot su sei non vengono dallo sprite.** Su questo atleta
non esiste un riempimento piatto di capo: la moda più popolosa di una regione è il **7.4%**
del torso, il **10.5%** dell'anca, il **7.5%** del piede. Il cluster dominante è grande —
**74.9% / 81.5% / 72.1%** della regione, quanto o più che sul Maestro (55–87%) — ma è una
**sfumatura**, non una tinta: sul Maestro la moda più popolosa del torso vale **15.4%**
(base) e **34.1–38.6%** su `signature`/`legend`, qui vale 7.4%. La massa c'è, il colore piatto
no. Quello che vince la moda è l'**ombreggiatura neutra** del disegno — `#474545`
(sat 0.029) sul torso e sull'anca, `#fffffe`/`#ffffff` (sat 0.000–0.004) come seconda
famiglia — che non è il colore di nessun capo. **Cinque delle sei modi misurate falliscono
il test di famiglia dello shader** (`sat_min` 0.18): sarebbero, come target, dei no-op.

Confronto con il Maestro, dai rispettivi report (moda più popolosa / quota del cluster
dominante, regione `torso`):

| | moda più popolosa | cluster dominante |
|---|---|---|
| Colosso `base` | 7.4% | 74.9% |
| Colosso `signature` | 7.4% | 83.0% |
| Maestro `base` | 15.4% | 56.6% |
| Maestro `legend` | 38.6% | 61.3% |
| Maestro `signature` | 34.1% | 55.0% |

Cioè: la differenza non è *quanto* è grande la massa dominante — sul Colosso è più grande —
ma **quanto è piatta**. Sul Maestro la massa dominante è un riempimento riconoscibile e la
sua moda è un colore di capo; sul Colosso è un gradiente di ombreggiatura e la sua moda è un
gradino qualunque della sfumatura.

**Regola 5**, dichiarata e applicata meccanicamente in `measure()`: una moda misurata che
fallisce il test di famiglia viene **scartata** (e conservata nel record, mai buttata) e la
slot ricade sul **colore dichiarato della sua famiglia** — famiglia `a` = massa dominante →
`colors[0]` (primario), famiglia `b` = finitura → `colors[1]` (trim). È la convenzione che il
catalogo stesso dichiara per `colors[0] -> primary, colors[1] -> trim`.

## 5. Il blocco GDScript

Da incollare in `OUTFIT_PROFILES` **dopo** la voce `fiamma`, stessa struttura e stessi nomi
di campo (`mask`, `shader`, `anchor_a`, `anchor_b`, `mask_sha256_prefix`, `outfits`).
I sei colori per outfit sono quelli di §3.

Maschera, anchor, `value_split` e `mask_sha256_prefix` **non sono miei**: sono i valori
misurati dalla corsia della maschera, citati dal suo report e **riletti a ogni esecuzione**.
Quella corsia stava lavorando mentre scrivevo (il report e la maschera sono stati riscritti
alle 17:46, il mio ultimo giro è delle 17:46): i valori qui sotto sono quelli letti a
quell'ora e **si muoveranno**. Lo sha256 non esiste nel report della maschera: lo calcola il
mio strumento dal file su disco, quindi va riletto prima di incollare.

```gdscript
	# COLOSSO — measured from the in-field 2D sprites, not from the cards.
	# Tool: tools/character/measure_colosso_palette.py. Report, per-sheet numbers and the
	# tool's own stdout: docs/agent-work/outfits-3d/evidence/colosso-palette/.
	# Reference colors: ["#25211e", "#ff7a12"] -- TWO colours, dark leather and orange.
	# 5 of the 6 slots are those two values placed on the family each belongs to
	# (colors[0] -> family a, the dominant mass; colors[1] -> family b, the trim). The
	# sixth, foot_a, is the one measured modal colour on this athlete that passes the
	# shader's own family test. There is no port_only: the reference declares two colours
	# and the sprite shows the same two.
	#
	# CAVEAT(palette): the sprite measurement could NOT resolve these slots. The most
	# populated 16-level bin of a region is 7.4-10.5 % of it (Maestro: 56 %), and what
	# wins is the drawing's NEUTRAL shading (#474545 sat 0.029, #fffffe sat 0.002), so
	# 5 of the 6 measured modes were rejected as non-garment colours. Read section 4 of
	# COLOSSO-PALETTE.md before treating any measured number here as the outfit's colour.
	#
	# CAVEAT(inert): torso_a and hip_a are INVISIBLE against the atlas's own leather
	# family. #25211e sits dE76 4.3 from the baked anchor #282018, so painting it changes
	# nothing the eye can see; the signature's dark body is what the model already looks
	# like. The outfit's only visible change on the rig is the accent family.
	#
	# CAVEAT(gate): the atlas's two families are 6.0 deg apart in hue under a 45 deg
	# tolerance, so with the value gate OFF both anchors accept exactly the same texels
	# (68.3 % of the torso's masked texels) and the six slots collapse onto one colour
	# per region. The gate below is what stops that. Measured in
	# COLOSSO-PALETTE.md section 7.1.
	#
	# CAVEAT(skin): the three *_b slots paint BARE SKIN. The mask does not keep the skin
	# out of its own coverage: 45059 texels inside it (12.67 %) carry the athlete's skin
	# tone on bare skin the garment bones own (RightUpLeg 19189, LeftShoulder 12983,
	# RightShoulder 11544, Spine 632), and all of them take FULL weight from BOTH families
	# (>= 0.99). 97.8 % of them sit on the LIGHT side of the split -- the side *_b
	# recolours -- so this accent lands on thighs and shoulders. The mask lane's own
	# verdict is "NO", and its best single value cut (0.54) still misplaces 21860 garment
	# and 5909 skin-toned texels (balanced accuracy 0.848). See COLOSSO-PALETTE.md
	# section 8.2 before shipping this outfit.
	&"colosso": {
		"mask": "res://assets/athletes/outfits/colosso/colosso_region_mask.png",
		# anchors and value windows: MEASURED by tools/character/build_colosso_outfit_mask.py
		# and quoted from docs/agent-work/outfits-3d/evidence/colosso-mask-report.json.
		# Its own verdict: "MASK USABLE AS A PERMISSION MAP, NOT USABLE AS A TWO-FAMILY
		# RECOLOUR MAP". The anchors are still that lane's decision, not settled data.
		"shader": REGION_SHADER_PATH,
		"anchor_a": "#282018",             # leather, hue 33.3 deg, 17234 samples
		"anchor_b": "#906040",             # light,   hue 28.2 deg, 17146 samples
		"mask_sha256_prefix": "5182250b9aee31ea",
		# The mask lane's measured windows; `feather` is MY default (the report declares
		# none) and Maestro used 0.01, so this is the one number here that is a choice.
		"value_gate": {
			"band_a": [0.02, 0.50],
			"band_b": [0.50, 0.98],
			"feather": 0.05,
		},
		"outfits": {
			&"signature": {
				"torso_a": "#25211e", "torso_b": "#ff7a12",
				"hip_a": "#25211e", "hip_b": "#ff7a12",
				"foot_a": "#562908", "foot_b": "#ff7a12",
			},
		},
	},
```

Se il profilo viene invece costruito senza maschera, solo il sotto-dizionario `outfits` è già
definitivo e si può incollare così com'è.

## 6. Quali regioni cambiano davvero (base → `signature`)

Questa è la misura che risponde alla domanda, e lo fa **senza ricampionare niente**: ogni
numero è una quota sui pixel opachi della **propria** regione, quindi le due risoluzioni non
si incontrano mai.

| classe | torso base → sig (Δ) | hip base → sig (Δ) | foot base → sig (Δ) |
|---|---|---|---|
| giallo brillante (h35–65, s>.4, v>.45) | 5.3 → 0.1 (**−5.2**) | 3.8 → 0.1 (**−3.7**) | 9.7 → 0.2 (**−9.5**) |
| oro (h35–60, s>.4, v .3–.7) | 2.2 → 0.3 (**−1.9**) | 1.8 → 0.3 (**−1.5**) | 4.1 → 0.6 (**−3.5**) |
| arancio emissivo (h5–40, s>.6, v>.8) | 4.6 → 4.3 (−0.3) | 3.5 → 3.0 (−0.5) | 8.2 → 7.7 (−0.5) |
| scuro (v < .25) | 48.5 → 48.4 (−0.1) | 61.6 → 61.9 (+0.3) | 48.4 → 48.4 (±0.0) |
| neutro (s ≤ .15) | 27.6 → 27.6 (±0.0) | 36.0 → 36.1 (+0.1) | 16.8 → 16.8 (±0.0) |
| marrone caldo (h9–38, s>.3, v≤.5) | 25.3 → 26.1 (+0.8) | 20.0 → 20.8 (+0.8) | 29.7 → 31.7 (+2.0) |
| pelle (ΔE76 ≤ 20 dal dichiarato) | 18.9 → 21.4 (+2.5) | 15.4 → 17.4 (+2.0) | 10.8 → 14.1 (+3.3) |
| bianco (v>.85, s<.15) | 1.4 → 1.4 (±0.0) | 1.0 → 1.1 (+0.1) | 1.3 → 1.3 (±0.0) |

Cosa dicono i numeri, e sono tre cose che vanno contro l'intuizione:

1. **Tutte e tre le regioni cambiano, e cambiano allo stesso modo: il `signature` toglie il
   giallo e l'oro.** Giallo −5.2 / −3.7 / −9.5 punti, oro −1.9 / −1.5 / −3.5. È l'unica
   differenza sostanziale fra base e `signature` su questo atleta.
2. **La massa scura non cambia**: 48.5 → 48.4 sul torso, 48.4 → 48.4 sul piede, 61.6 → 61.9
   sull'anca. Il `signature` **non scurisce** il corpo: era già scuro. Anche i neutri sono
   identici (±0.1).
3. **L'arancio non è un'aggiunta del `signature`.** Gli accenti emissivi ci sono già nella
   base (4.6 / 3.5 / 8.2) e nel `signature` calano appena (4.3 / 3.0 / 7.7). Il riferimento
   dichiara l'arancio come secondo colore del `signature` e il giallo pallido `#ffe98a` come
   secondo colore della base, ma lo sprite mostra l'arancio in entrambi. È il motivo per cui
   `torso_b`/`hip_b`/`foot_b` prendono l'arancio dichiarato: è l'unica famiglia di accento
   satura e non-pelle che lo sprite dipinge **in tutte e tre** le regioni.

Il marrone caldo sale di +0.8 / +0.8 / +2.0 e la pelle di +2.5 / +2.0 / +3.3: sono la stessa
cosa vista da due lati — l'area che era gialla/oro diventa marrone scuro e, sul totale della
regione, la quota di pelle sale.

**Controprova sulle carte** (`card_check`): il master di `signature`
(`assets/_archivio/originali/outfits/colosso/signature-master.png`, 1024×1536) contro la
carta base (1024×1536, **stessa risoluzione, confronto esatto**) differisce sul **12.6%** dei
pixel a Δ>16 per canale (3.1% a Δ>48, media 10.0/255). L'anteprima
(`signature-preview.webp`, 560×747) darebbe **54.7%**, ma è un confronto **ricampionato** e
come tale non è un risultato: è etichettato `APPROXIMATE` nel report e non viene citato.

Il **12.6%** delle carte va confrontato con la **perdita di giallo+oro per regione**, non con
un numero unico, perché le tre regioni non perdono la stessa cosa: `foot` perde **13.0** punti
(9.5 giallo + 3.5 oro), `torso` **7.1** (5.2 + 1.9), `hip` **5.2** (3.7 + 1.5). Quindi il
12.6% delle carte è **in linea con il piede** e sta **sopra** torso e anca: le carte e gli
sprite concordano sull'ordine di grandezza del cambiamento, non su quale regione cambi di più.
Le carte sono un'illustrazione e non sono la fonte (§10.13): la coincidenza si riporta, non si
usa come prova.

## 7. RISCHIO 1 — quali slot rischiano di essere inerti, e perché

Ci sono **due domande diverse** dietro la parola "inerte", e vanno tenute separate, perché
hanno risposte opposte su questo atleta.

### 7.1 Prima domanda: lo shader accetta la famiglia della slot?

Il test di famiglia dello shader **non guarda il colore target**: guarda il **texel
dell'atlante cotto** contro l'**anchor**, dentro la maschera, e solo dopo mescola il target.
Quindi la domanda si risponde contando, per regione e per anchor, quanti texel mascherati il
test accetta.

Costanti: quelle che girano davvero sono quelle del catalogo, non i default dello shader.
`outfit_catalogue.gd::MASK_DEFAULTS` scrive `sat_min 0.18`, `val_min 0.02`, `val_max 0.98`,
`hue_tol_deg 45.0` in ogni materiale di profilo; i default dichiarati nello shader
(`outfit_region_recolour.gdshader`: `sat_min 0.25`, `val_min 0.06`, `hue_tol_deg 42.0`)
vengono sovrascritti. Il mio strumento calcola entrambe le serie.

Anchor misurati dalla corsia della maschera: `leather #282018` (hue 33.3°) e
`light #906040` (hue 28.2°). **Distano 6.0° di tinta**, sotto una tolleranza di 42–45°.

| costanti | regione | texel mascherati | accettati da `leather` | da `light` | **da ENTRAMBI** |
|---|---|---|---|---|---|
| **effettive** (45/0.18/0.02), gate **OFF** | torso | 515645 | 68.3% | 68.3% | **352025 (68.3%)** |
| | hip | 531136 | 34.2% | 34.2% | **181736 (34.2%)** |
| | foot | 373671 | 31.2% | 31.2% | **116476 (31.2%)** |
| effettive, gate **ON** | torso | 515645 | 41.3% | 33.2% | 32126 (6.2%) |
| | hip | 531136 | 16.4% | 20.7% | 15376 (2.9%) |
| | foot | 373671 | 20.5% | 13.8% | 11929 (3.2%) |
| default shader (42/0.25/0.06), gate **OFF** | torso | 515645 | 63.7% | 63.7% | 328232 (63.7%) |
| | hip | 531136 | 32.3% | 32.3% | 171362 (32.3%) |
| | foot | 373671 | 25.7% | 25.7% | 96050 (25.7%) |

**Con il gate spento i due anchor accettano esattamente lo stesso insieme** — non
"quasi": le due percentuali sono identiche a un decimale su tutte e tre le regioni, perché
6.0° sotto 42–45° significa che ogni texel del capo risponde a entrambi. È la stessa
modalità di guasto del Maestro, e significa che le sei slot **collassano su un colore per
regione**: l'ultimo `apply_anchor` vince. Senza `value_gate` questa palette non funziona.

**Con il gate acceso** (bande della corsia della maschera, `[0.02, 0.50]` e `[0.50, 0.98]`)
l'intersezione scende da 352025 a 32126 texel sul torso, da 181736 a 15376 sull'anca, da
116476 a 11929 sul piede. Restano però **orfani** (fuori da entrambe le bande) 163527 /
349381 / 257132 texel, che restano cotti: la maschera è una mappa di permesso, non una mappa
di ricolorazione a due famiglie. La corsia della maschera arriva alla stessa conclusione nel
proprio `verdict`.

> **Cross-check riuscito, e vale come validazione.** Il report della corsia della maschera
> dichiara «1048218 di 1421791 texel mascherati rispondono a entrambi gli anchor». È un
> conteggio a **sola finestra di tinta** (senza le rampe sat/val). Riproducendo lo stesso
> criterio con la mia re-implementazione di `family_weight()`: **1047268 su 1420186, 73.7%**
> — contro **1048218 su 1421791, 73.7%** della corsia. Differenza 0.09%, attribuibile alla
> revisione della maschera (il mio strumento legge quella su disco quando gira). Aggiungendo
> le rampe `sat/val` dello shader quel set scende a **711419 (50.1%)**: è il numero che il
> render vede davvero, e nessuno dei due è il numero della finestra.

**Esito della prima domanda: nessuna slot è inerte per colpa dell'anchor.** Con il gate
acceso entrambe le famiglie superano il test con peso pieno (`leather` sat 0.40 val 0.157,
`light` sat 0.556 val 0.565: entrambe sopra `sat_min` 0.18 e `val_min` 0.02). Il rischio non
è che la slot non dipinga: è che non si veda, ed è la seconda domanda.

### 7.2 La domanda del committente, verificata: "troppo poco saturo o troppo scuro per superare sat_min 0.18"

Il target di ogni slot, alla sua saturazione e al suo valore, contro `sat_min` effettivo 0.18:

| slot | hex | sat | val | passa a **0.18** | passa a **0.25** (default shader) |
|---|---|---|---|---|---|
| torso_a | `#25211e` | 0.189 | 0.145 | **sì, per un pelo** | **no** |
| torso_b | `#ff7a12` | 0.929 | 1.000 | sì | sì |
| hip_a | `#25211e` | 0.189 | 0.145 | **sì, per un pelo** | **no** |
| hip_b | `#ff7a12` | 0.929 | 1.000 | sì | sì |
| foot_a | `#562908` | 0.907 | 0.337 | sì | sì |
| foot_b | `#ff7a12` | 0.929 | 1.000 | sì | sì |

**Il cuoio dichiarato `#25211e` sta a sat 0.189 contro un `sat_min` di 0.18: passa con 0.009
di margine, e con i default dello shader (0.25) non passerebbe affatto.** Se il catalogo non
sovrascrivesse `sat_min` a 0.18, le due slot `*_a` del cuoio sarebbero respinte dal test. E
anche a 0.18 il peso della rampa è `ss((0.189−0.18)/0.12) = ss(0.075) ≈ 0.016`: se fosse
l'anchor a dover passare quel test, il cuoio sarebbe praticamente invisibile. Non è l'anchor
(§7.1), quindi non è un blocco — ma è il margine più sottile di tutta la palette, e va
saputo.

### 7.3 Seconda domanda: la ricolorazione si vede?

Qui c'è il risultato che conta. Confronto ogni target con l'**anchor cotto della famiglia che
ricolora** (ΔE76; soglia dichiarata: ≤ 5.0 = INVISIBILE, ≤ 12.0 = appena percettibile):

| slot | target | vs `leather #282018` | vs `light #906040` | verdetto |
|---|---|---|---|---|
| torso_a | `#25211e` | **4.3** | 42.3 | **INVISIBILE** sul cuoio |
| hip_a | `#25211e` | **4.3** | 42.3 | **INVISIBILE** sul cuoio |
| foot_a | `#562908` | 28.6 | 23.2 | visibile |
| torso_b | `#ff7a12` | 93.6 | 57.5 | visibile |
| hip_b | `#ff7a12` | 93.6 | 57.5 | visibile |
| foot_b | `#ff7a12` | 93.6 | 57.5 | visibile |

**Il cuoio scuro che il riferimento dichiara per il `signature` è, a ΔE76 4.3, lo stesso
colore del cuoio che il modello ha già cotto addosso.** Dipingere `torso_a` e `hip_a` con
`#25211e` è corretto e conforme al dato, e **non cambia niente che si veda**. Lo sprite
conferma per conto suo: la massa scura non cambia fra base e `signature` (48.5 → 48.4 sul
torso, §6), e la carta master differisce solo sul 12.6% dei pixel.

**Conseguenza da mettere in chiaro prima che qualcuno la scopra guardando un render: su
questo atleta il `signature` differisce dalla base, sul rig, essenzialmente per la famiglia
di accento.** Le tre slot `*_a` sono una ricolorazione invisibile per costruzione; le tre
`*_b` sono l'unica cosa che si vede.

### 7.4 Il rischio simmetrico: l'accento è troppo grande

Il riferimento dichiara l'arancio come accento. Sull'atlante la famiglia `light` — che è
quella che `*_b` ricolora — copre molto più della quota di arancio dello sprite:

| regione | `light` accettata (gate ON, costanti effettive) | arancio misurato nello sprite | rapporto |
|---|---|---|---|
| torso | **33.2%** dei texel mascherati | **4.3%** della fascia | ~7.7× |
| hip | **20.7%** | **3.0%** | ~6.9× |
| foot | **13.8%** | **7.7%** | ~1.8× |

Cioè: `torso_b` e `hip_b` non disegnano un dettaglio luminoso, disegnano un **pannello**
grande un terzo del torso. Se il risultato voluto è un accento piccolo, questa palette non lo
dà, e le opzioni oneste sono tre: accettarlo; rendere `*_b` dello stesso cuoio scuro (e
allora `*_b` non cambia nulla, come `*_a`); oppure lasciare gli accenti fuori scope. Non c'è
una quarta opzione che il dato sostenga.

E c'è un secondo strato, che rende questo rischio peggiore di quanto sembri leggendo solo le
dimensioni: **la famiglia `light` è quella che contiene la pelle.** Dei 45 059 texel di pelle
nuda che stanno dentro la maschera, il **97.8%** cade dal lato `light` della soglia di valore.
Quindi `*_b` non dipinge "un pannello troppo grande": dipinge **pelle nuda** su cosce e spalle.
È il §8.2, e va letto insieme a questo paragrafo.

## 8. RISCHIO 2 — quanto l'arancio è distinguibile dalla pelle

### 8.1 Cromaticamente: per niente. Solo saturazione e valore lo separano

| colore | hue | sat | val | nella finestra pelle 9–38°? |
|---|---|---|---|---|
| arancio dichiarato `#ff7a12` | **26.3°** | **0.929** | 1.000 | **sì**, e con la regola completa (sat>0.30 e val>0.50) |
| cuoio dichiarato `#25211e` | 25.7° | 0.189 | 0.145 | sì per tinta, no per la regola completa |
| pelle dichiarata `#b06a3f` | **22.8°** | 0.642 | 0.690 | sì (è la pelle) |

L'arancio e la pelle dichiarata distano **3.5° di tinta** — praticamente la stessa tinta. La
separazione esiste solo su saturazione (Δ 0.287) e valore (Δ 0.310), per un **ΔE76 43.6**.
Misurato sugli sprite, i pixel che superano val > 0.90 (il glow) hanno modi a hue 19–29°:
`#ea9c52`, `#eb8c32`, `#ec8525`, `#ee994a` su `idle`; `#eb7b13`, `#eb7c13`, `#eb7d15`,
`#eb8c33` su `action`. Tutti dentro la finestra della pelle.

Quanto è grande il glow, e quanto mangia la regola pelle: sugli sprite `signature` il glow
(val > 0.90) è lo **0.3–5.0%** del corpo secondo il foglio, e la regola pelle in versione
hue+sat toglierebbe il **68.2%** del corpo su `idle` (63.5% sulla base) — scendendo al
**21.4%** con il pavimento sul valore. Il pavimento è ciò che tiene il cuoio nel pool e ciò
che butta fuori il glow: **è la stessa leva**, e questo è il punto.

| foglio | base: hue+sat → con pavimento | `signature`: hue+sat → con pavimento | glow (val>.90) base → sig |
|---|---|---|---|
| idle | 63.5% → 19.0% | 68.2% → 21.4% | 0.5% → 0.3% |
| action | 57.8% → 18.3% | 60.7% → 20.7% | 1.1% → 1.0% |
| run | 48.8% → 38.8% | 50.5% → 40.2% | 3.3% → 2.4% |
| back-idle | 39.9% → 28.2% | 42.4% → 30.0% | 6.4% → 5.0% |
| back-action | 55.1% → 50.6% | 58.9% → 54.3% | 7.4% → 4.6% |
| back-run | 43.3% → 27.2% | 45.8% → 28.8% | 2.3% → 1.1% |

### 8.2 Nel render: la separazione non c'è, e la corsia della maschera lo dichiara

La conclusione ovvia — "tanto la maschera UV tiene la pelle fuori, il colore non conta" — è
**falsa**, e va scritta perché è la conclusione a cui chiunque arriverebbe. La maschera fa il
suo lavoro principale: copre 1421477 texel (0.3389 dell'atlante) e la perdita sui gruppi
protetti è **≤ 0.0001** dell'area UV di ciascuno (`Head` 0.0, `Hands` 0.0, `ForeArm` 0.0,
`Arm` 0.0001, `Shin` 0.0). Ma la copertura della maschera **non è priva di pelle**: il verdetto
della corsia della maschera, `skin_recolourable_verdict`, comincia con **NO**:

> «NO. … Inside the mask, 45059 sampled texels (12.67% of it) carry that exact skin tone, **on
> bare skin the garment bones own**: mixamorig:RightUpLeg 19189, mixamorig:LeftShoulder 12983,
> mixamorig:RightShoulder 11544, mixamorig:Spine 632. A value gate separates the dark leather
> from the light family, but **the light family IS the skin**: 44077 of those 45059 texels
> (97.8%) sit above the split.»

Cioè: **45 059 texel di pelle nuda stanno dentro la maschera**, sui triangoli che le ossa del
capo possiedono (19 189 sulla coscia destra — la regione `hip` — e 24 527 fra le due spalle —
la regione `torso`). E quei texel ricevono **peso pieno da entrambe le famiglie**: il
`shader_family_weight_mirror` della stessa corsia li conta tutti e 45 059 a peso ≥ 0.99 sia
per `leather` sia per `light`, con il value gate spento. Il commento della corsia è la sintesi
migliore: «the skin of this athlete sits at the centre of both anchors' ramps, so the shader
recolours it at full weight for both families; **outside the mask the mask is what keeps it
out, and inside the mask nothing does**.»

E **il 97.8% di quei texel sta dal lato `light`** — cioè esattamente il lato che `torso_b`,
`hip_b` e `foot_b` ricolorano. Quindi l'arancio della `signature`, sulle slot `*_b`, **finisce
sulla pelle nuda delle cosce e delle spalle**. Non è un rischio teorico: è il conteggio della
corsia che possiede la maschera.

E non si sistema con una soglia: la stessa corsia ha provato il miglior taglio singolo di
valore dentro la maschera (**0.54**) e riporta che lascia comunque **21860 texel di capo
cromatico dal lato della pelle** e **5909 texel di pelle dal lato del capo**, accuratezza
bilanciata **0.848** — sotto lo 0.95 che servirebbe per chiamarla separazione. La pelle
dell'atleta sta a hue **24.0°**, dentro la banda del capo (21–45°): il 64.5% dei texel di pelle
risponde all'anchor `leather` e il 64.5% a `light`.

Quindi, in due righe, e sono l'opposto di quelle che avevo scritto prima di leggere il
verdetto della corsia:

* **la misura** non separa arancio e pelle (Δhue 3.5°): metà del "capo" che il pool contiene è
  pelle in ombra che il pavimento sul valore non ha potuto togliere senza portarsi via anche il
  glow;
* **il render** non li separa nemmeno, e per una ragione diversa: la maschera tiene la pelle
  fuori da sé stessa, non fuori dalla propria copertura. Fuori dalla maschera la pelle è al
  sicuro (122 584 dei 200 924 texel di pelle prenderebbero peso pieno, e la maschera li
  esclude); **dentro**, niente la esclude.

**Conseguenza operativa, e chiude il cerchio con §7.4.** Le tre slot `*_b` non sono solo
troppo grandi: cadono sulla pelle. Le opzioni oneste, in ordine di quanto sono difendibili:

1. **non ricolorare la famiglia `light` su questo atleta** (lasciare `*_b` = `*_a`, o togliere
   il gate e accettare il collasso), perché la famiglia `light` è dove sta la pelle;
2. ricolorarla e **accettare** che l'arancio vada su cosce e spalle — che, va detto, è quello
   che fanno gli sprite 2D: l'arancio emissivo sul Colosso sta su cosce e spalle anche lì;
3. stringere la maschera con una soglia, che però la corsia che possiede la maschera ha già
   misurato come insufficiente (0.848 < 0.95).

Questo documento propone i valori di §3 e **non** sceglie fra le tre: la scelta è di chi
possiede la maschera e il rig, non di chi misura la palette. Ma va fatta prima di un render, non
dopo.

## 9. Verifica dei dati pre-misurati (non riprodotti)

Non ho riprodotto né riverificato questi numeri; li ho **letti** e li cito come tali:

* gli anchor `#282018` / `#906040`, il `value_split` 0.50, le finestre `[15,45]` di tinta e
  `[0.02,0.5]`/`[0.5,0.98]` di valore, la copertura 1421477 texel (0.3389), i triangoli
  (2766 torso / 1583 hip / 947 foot), le perdite di pelle e il `verdict` vengono dal report
  della **corsia della maschera**, `docs/agent-work/outfits-3d/evidence/colosso-mask-report.json`,
  riletto a ogni esecuzione.
* **tutto il blocco pelle di §8.2** è della corsia della maschera, non mio: `skin_anchor`
  `#906040` a hue 24.0° su 85454 campioni, `skin_match_fraction` 0.6447/0.6448, i 45059 texel
  in-mask con tono pelle e la loro attribuzione per osso (`RightUpLeg` 19189, `LeftShoulder`
  12983, `RightShoulder` 11544, `Spine` 632), il `shader_family_weight_mirror` (45059 a peso
  ≥ 0.99 per entrambe le famiglie), il taglio 0.54 con accuratezza bilanciata 0.848, il 97.8%
  sopra lo split, e il testo di `skin_recolourable_verdict`. Sono numeri **letti**, e la
  coincidenza con la mia misura di §8.1 (Δhue 3.5° fra arancio e pelle) è una conferma
  incrociata da due metodi indipendenti — colore contro geometria — non una riproduzione.
* il valore `1048218 di 1421791` viene dallo stesso report; l'ho **riprodotto** entro lo 0.09%
  (§7.1) ma con un criterio che ho dovuto dedurre (sola finestra di tinta), quindi la
  coincidenza è una conferma, non una citazione.
* `outfit_region_recolour.gdshader` e `outfit_catalogue.gd` sono stati **letti**, non
  modificati; `sat_min` 0.18 e `val_min` 0.02 sono letti da `MASK_DEFAULTS`.

## 10. Limiti onesti

1. **La palette non è derivata dagli sprite, ed è il risultato principale.** Cinque slot su
   sei vengono dai due colori dichiarati perché le modi misurate non sono colori di capo
   (§4). Un documento che presentasse `#474545` come "il colore del torso" sarebbe peggio che
   inutile: sarebbe falso. Il Colosso non ha riempimenti piatti nei suoi sprite: il cluster
   dominante copre il 72–83% della regione, ma la sua moda più popolosa è il 7.4–10.5%,
   contro il 15.4–38.6% del torso del Maestro (§4).
2. **Non esiste una terza scelta, quindi non esiste `port_only`.** Il riferimento dichiara
   due colori, lo sprite ne mostra gli stessi due, e il Colosso ha un solo outfit in scope.
   Non ho inventato una deviazione per riempire il campo.
3. **`torso_a` e `hip_a` sono inerti nel senso che conta: non si vedono.** `#25211e` sta a
   ΔE76 4.3 dal cuoio già cotto `#282018` (§7.3). Il `signature` sul rig differisce dalla base
   quasi solo per la famiglia di accento. Se si vuole che il corpo scuro cambi, serve una
   deviazione dichiarata dal dato — e allora va scritta come `port_only` e motivata, non
   lasciata implicita.
4. **`#25211e` passa `sat_min` con 0.009 di margine, e solo perché il catalogo abbassa
   `sat_min` a 0.18.** Con i default dello shader (0.25) non passerebbe (§7.2). È il margine
   più sottile di tutta la palette.
5. **Le tre slot `*_b` dipingono pelle nuda, e questo è il limite più grave del set.** La
   famiglia `light` è quella che contiene la pelle: 45 059 texel di pelle nuda stanno dentro la
   maschera e ricevono peso pieno da entrambe le famiglie, il 97.8% dal lato `light` (§8.2). La
   corsia della maschera lo dichiara con un **NO** e misura che nessun taglio singolo di valore
   separa pelle da capo (0.848 < 0.95). Questo documento propone i valori di §3 e **non**
   risolve la questione: la decisione è di chi possiede la maschera e il rig, e le tre opzioni
   sono elencate in §8.2. Se l'outfit va in scena così com'è, va deciso *consapevolmente* che
   l'arancio finisce su cosce e spalle.
6. **Senza `value_gate` le sei slot collassano su un colore per regione.** I due anchor
   distano 6.0° di tinta sotto una tolleranza di 42–45°, quindi con il gate spento accettano
   *esattamente* lo stesso insieme: 68.3% del torso, 34.2% dell'anca, 31.2% del piede (§7.1).
   Il gate nel blocco §5 è **necessario**, non un abbellimento. Le bande sono della corsia
   della maschera; il `feather` 0.05 è **mio** (il report non ne dichiara uno) ed è l'unico
   numero del blocco che è una scelta.
7. **Le tre slot `*_b` dipingono un pannello, non un accento** (§7.4): la famiglia `light`
   copre il 33.2% del torso mascherato contro il 4.3% di arancio nello sprite.
8. **La fascia `hip` attraversa l'orlo misurato.** Su `idle` e `back-idle` l'orlo sta a
   0.58–0.59 e la fascia arriva a 0.62: i primi 0.03–0.04 sono coscia nuda, che la regola
   pelle rimuove. Su `back-action` il rilevatore di orlo (0.48) scatta sul braccio e non
   sull'orlo, e quel foglio è escluso dal numero `hip` aggregato; le sue misure restano nel
   report. La lista di esclusione della revisione precedente era **invertita** ed è stata
   corretta (§1.2).
9. **La regola della racchetta non ha mai funzionato** (`applied_count` 0): la racchetta non
   è stata esclusa e il pool può contenerne i pixel (§2). Il cross-check che misura lo stesso
   pool con la regola volutamente spenta (`measured_palette_no_racket_exclusion`) è nel
   report, ed è identico al principale — perché la regola non è mai scattata.
10. **La griglia pari non cade sui vuoti di alpha su `action`** (scarto 6.0 / 304.0 / 251.0 px
   sulla base) e su `back-run` i vuoti non esistono. Lo slittamento è gestito misurando solo
   le colonne della figura propria, ma il runtime disegna anche quel filo di pixel: è un
   dettaglio preesistente del gioco, segnalato perché chi guarda uno sprite ingrandito lo
   vede. In totale 2259 px scartati.
11. **Nessuna verifica sul modello.** Non ho renderizzato il rig: questa è una specifica, non
    una prova. Non esiste ancora un render 3D del Colosso con la maschera, e le due cose che
    potrebbero smentire questa tabella — che `*_a` non si veda (§7.3) e che `*_b` copra un
    terzo del torso (§7.4) — si vedono solo a schermo.
12. **Maschera e anchor sono di un'altra corsia e si stanno muovendo.** Il report e la
    maschera della corsia sono stati riscritti **mentre scrivevo** (17:46, il mio ultimo giro
    è delle 17:46) e gli anchor sono già cambiati una volta sotto i miei piedi (i campioni
    `leather` sono passati da 16059 a 17234, la tinta di `light` da 28.6° a 28.2°, il
    `value_split` da 0.48 a 0.50). Lo `sha256` **non esiste** nel report della maschera: lo
    calcola il mio strumento dal file su disco (`5182250b9aee31ea` alle 17:46). Se la maschera
    viene rigenerata cambiano hash, anchor e finestre, e va rivista la mappa delle slot. Il
    mio strumento rilegge tutto a ogni esecuzione proprio per non citare un valore stantio.
13. **Le anteprime 2D non sono state seguite.** Sono illustrazioni: l'anteprima di
    `signature` (560×747) contro la carta base (1024×1536) dà 54.7% di pixel diversi, ma è un
    confronto ricampionato e non è un risultato (§6). Il riferimento è lo **sprite**.

## 11. File prodotti

| file | cosa è |
|---|---|
| `tools/character/measure_colosso_palette.py` | lo strumento; unica fonte di tutti i numeri di questo documento |
| `docs/agent-work/outfits-3d/COLOSSO-PALETTE.md` | questo documento |
| `evidence/colosso-palette/colosso-palette-report.json` | report macchina: palette misurate, modi, cluster, distanze target↔anchor, split di famiglia su atlante e maschera, delta di classe per regione, controllo griglia, inventario atlante |
| `evidence/colosso-palette/colosso-palette-tool-stdout.txt` | stdout integrale dello strumento, la stessa esecuzione del report |
| `evidence/colosso-palette/measured-slots.png` | strip delle modi misurate per regione × famiglia |
| `evidence/colosso-palette/proposed-slots.png` | strip dei valori proposti, con lettera di provenienza S/M/P |
| `evidence/colosso-palette/mask-check-{idle,action,run,back-idle,back-action,back-run}.png` | fasce ed esclusioni sopra lo sprite base e quello `signature`: è il controllo a vista delle euristiche |
| `evidence/colosso-mask-report.json` | **non mio**: report della corsia della maschera, citato in §5, §7.1, §8.2 e §9 per anchor, finestre, copertura, perdite di pelle, `shader_family_weight_mirror` e i due verdetti (`verdict`, `skin_recolourable_verdict`) |
| `godot/assets/athletes/outfits/colosso/colosso_region_mask.png` | **non mio**: la maschera della corsia della maschera, letta e mai scritta |

Nessun file di gioco è stato modificato: solo i tre percorsi dello scope (script, documento,
immagini di analisi). Nessun `.gd`, `.tscn` o `.gdshader` toccato, nessun commit, nessun push,
nessun asset rigenerato.

### Cosa è cambiato in questa ripresa

La lane interrotta aveva scritto lo strumento ma non l'aveva mai portato a termine: tre
esecuzioni, tre eccezioni (`ValueError` di broadcasting nella regola racchetta, `KeyError`
sull'inertness, `IndexError` nelle immagini di evidenza) e nessun report. In questa ripresa:

* **tre bug corretti** perché lo strumento girasse: la maschera racchetta non veniva
  ritagliata, l'inertness leggeva una chiave inesistente, le immagini di evidenza
  confrontavano maschere a larghezza piena con pixel ritagliati;
* **la lista di esclusione di `hip` era invertita** ed è stata corretta (§1.2);
* **le costanti dello shader erano citate solo come default**: ora sono distinte dalle
  effettive del catalogo, e ogni numero è calcolato a entrambe (§7.1, §7.2);
* **l'inertness era mal posta**: testava il colore target, mentre lo shader testa il texel
  dell'atlante. Ora ci sono due misure separate, la seconda delle quali — il test di famiglia
  dello shader rieseguito sull'atlante dentro la maschera — è nuova, e riproduce il numero
  della corsia della maschera entro lo 0.09% (§7.1);
* **la regola 5** (moda scartata se fallisce il test di famiglia) è nuova, e senza di essa la
  tabella §3 avrebbe proposto `#fffffe` come colore di tre slot;
* **la misura "quali regioni cambiano"** è nuova e non ricampiona nulla (§6);
* **due affermazioni non verificate sono state rimosse** dai docstring: i valori d'orlo
  dichiarati non corrispondevano alla misura, e i numeri della famiglia oro erano sbagliati
  (§2, §1.2);
* **il rischio pelle è stato corretto, e nella direzione scomoda.** La prima stesura di questo
  documento concludeva che l'arancio è salvo nel render perché "la maschera UV separa pelle e
  capo geometricamente". È falso, e la smentita sta nel verdetto della corsia che *possiede* la
  maschera: 45 059 texel di pelle nuda stanno **dentro** la maschera e prendono peso pieno da
  entrambe le famiglie. Il §8.2 ora riporta quel verdetto e le tre opzioni, e il blocco §5 ha
  un `CAVEAT(skin)`;
* **due numeri citati a memoria sono stati riportati alla fonte**: il confronto con la moda del
  Maestro (avevo scritto 56%, che è la quota del *cluster*, non della moda: il valore giusto è
  15.4–38.6%, §4) e il confronto fra le carte e la perdita di giallo+oro (avevo scritto un
  unico "12–13%": per regione è 7.1 / 5.2 / 13.0 punti, §6).
