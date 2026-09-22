# ORACOLO — palette dell'outfit `signature` 3D, misurata dagli sprite in campo

Specifica delle sei slot (regione × famiglia) per l'outfit `signature` dell'Oracolo,
**derivata misurando gli sprite**, più la misura di **quanta parte di quell'outfit è
ottenibile con la sola ricolorazione e quanta no**. Nessuna modifica al gioco, nessun commit.
Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, ramo
`codex/integrate-arena-11m`. L'albero era già sporco di lavoro altrui (altre corsie su
`maestro`, `colosso` e la maschera dell'Oracolo) e non è stato toccato: nessun file `.gd`,
`.tscn` o `.gdshader` è stato modificato da questa corsia.

Strumento: `tools/character/measure_oracolo_palette.py` (numpy + PIL, nessuna rete).
Report macchina: `docs/agent-work/outfits-3d/evidence/oracolo-palette/oracolo-palette-report.json`.
Sonde di questa corsia (script + output): `docs/agent-work/outfits-3d/evidence/oracolo-palette/probes/`.
Formato di riferimento: la voce `fiamma` di `OUTFIT_PROFILES` in
`godot/src/character/outfit_catalogue.gd` (letto, non modificato).

**Fuori scope, per istruzione:** l'outfit `mythic` dell'Oracolo. Non è stato misurato e non
compare in nessuna tabella di questo documento. L'outfit `base` è misurato solo come termine
di confronto: nel profilo `base` è assente per design, perché ripristinare il materiale del
rig è l'unico modo per essere equivalenti all'originale e non solo vicini.

---

## 1. Metodo, in breve

| passo | come |
|---|---|
| griglia dei frame | divisione pari della striscia (`width / frameCount`), come fa il runtime; i conteggi sono verificati contro i vuoti di alpha fra le figure |
| bbox del corpo | `alpha > 200`, per frame |
| fasce | frazioni fisse dell'**altezza** della bbox: `torso 0.16–0.47`, `hip 0.47–0.56`, `foot 0.86–1.00`. Scelte dalla mappa riga-per-riga dello sprite base (stampata dallo script con `--row-map`), non a occhio. La mappa dell'Oracolo è **diversa** da quella del Maestro: la gonna finisce a 0.56 e gli stivali iniziano a 0.86 |
| esclusi | pelle, capelli, racchetta (euristiche, §2) |
| famiglie | k-means k=2 deterministico **per (outfit, regione)**; `a` = cluster più grande, `b` = l'altro |
| valore di una famiglia | la **moda** (bin più popoloso del cluster), non la media: la media include ombre e schiarisce il colore |
| distanza cromatica | CIE76 (ΔE76) su sRGB → Lab D65 |

**Nomi degli sprite, caso speciale.** `outfitSpritePaths` in `js/data.js` ha un ramo proprio
per l'Oracolo: usa `idle-v2.webp` e `back-idle-v2.webp` invece di `idle.webp` e
`back-idle.webp`, perché la prima idle apparteneva a un concept luminoso diverso e a schermo
sembrava semitrasparente. Lo strumento segue quel ramo. Il confronto vecchia/nuova idle è nel
report (`old_idle_vs_v2`): stessa dimensione (716×286), alpha pieno in entrambe (0 px sotto
alpha 200), ma il **98.0%** dei pixel del corpo cambia su `idle` e l'**87.7%** su `back-idle`.
Sono due disegni diversi, non una correzione di trasparenza.

**Il numero di pixel misurati non è confrontabile fra base e outfit.** Nelle foglie
`idle`/`action`/`back-*` lo sprite base è disegnato a 298 px per frame e quello dell'outfit a
179 px (fattore 1.665); su `run` 220 contro 132 e su `back-run` 178 contro 107. I confronti di
colore sono fra **modi**, non fra conteggi.

### Riproduzione

```sh
python3 -m venv "$SCRATCH/oracolo-venv" && "$SCRATCH/oracolo-venv/bin/pip" install pillow numpy
"$SCRATCH/oracolo-venv/bin/python" tools/character/measure_oracolo_palette.py
# opzioni: --out-dir <dir>  --no-evidence  --row-map  --change-eps <n>
```

Lo strumento è **deterministico**: due esecuzioni consecutive producono un report byte-identico
(sha256 `2046524aac2bacdc…`, verificato in questa corsia).

Esito (troncato, riprodotto due volte con lo stesso risultato):

```
base       torso_a=#471868(mode)/#5f257c(mean) 75.9%  torso_b=#fffeff(mode)/#ecacd3(mean) 24.1%  hip_a=#461868(mode)/#3d1951(mean) 74.8%  hip_b=#7936a5(mode)/#9f70ab(mean) 25.2%  foot_a=#060406(mode)/#3f2143(mean) 69.5%  foot_b=#fdfafb(mode)/#d9c2c2(mean) 30.5%
signature  torso_a=#281548(mode)/#4c2c79(mean) 75.6%  torso_b=#fffeff(mode)/#e6afd2(mean) 24.4%  hip_a=#281648(mode)/#251537(mean) 57.4%  hip_b=#593697(mode)/#7c5a9e(mean) 42.6%  foot_a=#2a1947(mode)/#36203c(mean) 69.0%  foot_b=#fcfafa(mode)/#d6bfc1(mean) 31.0%
ATLAS godot/assets/athletes/oracolo_texture_0.png [2048,2048] saturated=62.3%  violet240_300=74.7%  skin0_40=20.4%  cyan170_215=0.00%  gold=1.59%
MODEL godot/assets/athletes/oracolo.glb verts=60869 tris=32106 area=3.446 m2  classes: other=20.3%  skin=16.5%  violet=45.6%  magenta=0.1%  grey_white=0.9%  near_black=16.7%
MASKLANE godot/assets/athletes/outfits/oracolo present=False
```

## 2. Le euristiche di esclusione (dichiarate, non esatte)

| esclusione | regola | perché / quanto è grossolana |
|---|---|---|
| pelle | hue 9–38° **e** saturazione > 0.30 **e** valore > 0.20 | finestra già usata dal port; la pelle dichiarata dell'Oracolo (`#8a5a3b`) sta a hue 22.6° / sat 0.57, dentro la finestra. Sui bordi antialiasati può sfuggire qualche pixel |
| capelli | distanza max-canale ≤ 48/255 dal colore dichiarato `#0e0c16` | **difetto dichiarato**: il secondary dell'Oracolo (`#1a0f38`) dista solo **34/255** da quel colore, quindi la regola del Maestro cancella anche pixel di tessuto viola scuro. Sono misurate due varianti (stretta e con gate di saturazione ≤ 0.35) e il report le porta entrambe |
| racchetta | blob 8-connesso più grande della famiglia oro, chiuso 9 px poi dilatato 11 px | **fallisce su questo atleta**: l'Oracolo tiene la racchetta davanti al petto e la sua racchetta ha il piatto scuro, così la regola trova solo il bordo/emblema (blob 61–224 px su idle/action, contro i 1254 px massimi altrove). Conseguenza: la fascia `torso` frontale è per il 16–30% quasi-nera e solo per il 13–22% viola, mentre sul retro è per il 42–57% viola e per lo 0% quasi-nera. **Il torso è quindi misurato sulle foglie di schiena** (`back-idle`, `back-action`); i numeri frontali restano nel report come evidenza |

Le foglie `run`/`back-run` sono **artwork diverso**: hue del tessuto 293–306° contro 275°
(base) / 262° (signature) su tutte le altre foglie, più un crema `#ebd4b9` e un verde acceso
`#18ff09` che nessun'altra foglia porta. Sono escluse dal pool dei colori per ogni regione
(evidenza: `sheet_band_composition`, `measured_palette_per_sheet`). Inoltre 1992 colonne ai
bordi delle foglie a quattro frame appartengono all'inchiostro di una figura vicina e sono
state scartate (`sheet_bleed`).

Controllo visivo: `mask-check-{idle,action,run,back-idle,back-action,back-run}.png` in
`evidence/oracolo-palette/`.

## 3. Tabella delle sei slot

`S` = dal dato sorgente (`js/data.js` ATHLETE_OUTFITS, voce `oracolo` variante `signature`,
due colori soltanto) · `M` = misurato dallo sprite · `P` = scelta di port.

L'outfit `signature` dichiara **due** colori: `#38216f` e `#29dfff`. Il rig ha sei slot, quindi
il dato non basta: quattro slot sono dichiarati e due no, e delle due famiglie per regione il
dato non dice quale sia quale.

| slot | hex | origine | modo misurato | quota della regione | nota |
|---|---|---|---|---|---|
| `torso_a` | `#38216f` | **S** | `#281548` | 75.6% | stesso hue del dichiarato (Δhue 4.7°, dentro la finestra di 12°); cambia solo il valore, 0.28 misurato contro 0.44 dichiarato. Lo slot porta l'identità dell'outfit, quindi vince il valore autoriale |
| `torso_b` | `#29dfff` | **S** | `#fffeff` (sat 0.002) | 24.4% | lo sprite dipinge questo trim con il **bianco condiviso** con la base: identico in base e signature, quindi non porta informazione di outfit. Il secondo colore dichiarato è a sua volta un colore (sat 0.839) e prende lo slot |
| `hip_a` | `#281648` | **M** | `#281648` | 57.4% | modo della regione. Il dato non dichiara nessun colore per questa regione/famiglia |
| `hip_b` | `#593697` | **M** | `#593697` | 42.6% | modo della regione. Idem |
| `foot_a` | `#2a1947` | **M** | `#2a1947` | 69.0% | modo della regione. Idem |
| `foot_b` | `#29dfff` | **S** | `#fcfafa` (sat 0.009) | 31.0% | come `torso_b`: trim bianco condiviso, non informativo |

**`port_only`: nessuno.** `PORT_OVERRIDES` è vuoto e nessuno slot è una scelta di port: tutti e
sei vengono dal dato o da un modo misurato. Non c'è qui il caso del Maestro, dove uno slot
doveva deviare da entrambi per separare `circuit` da `signature` — la separazione richiesta la
danno già i valori dichiarati (sotto).

### Separazione base → signature

ΔE76 fra il modo misurato della base e il valore proposto per la signature, per slot:

| slot | base (misurato) | signature (misurato) | ΔE76 misurato | signature (proposto) | ΔE76 proposto | peso |
|---|---|---|---|---|---|---|
| `torso_a` | `#471868` | `#281548` | 18.6 | `#38216f` | **7.3** | 31.2% |
| `torso_b` | `#fffeff` | `#fffeff` | 0.0 | `#29dfff` | **46.1** | 9.9% |
| `hip_a` | `#461868` | `#281648` | 19.1 | `#281648` | 19.1 | 22.3% |
| `hip_b` | `#7936a5` | `#593697` | 11.8 | `#593697` | 11.8 | 9.5% |
| `foot_a` | `#060406` | `#2a1947` | 34.3 | `#2a1947` | 34.3 | 18.8% |
| `foot_b` | `#fdfafb` | `#fcfafa` | 0.6 | `#29dfff` | **46.3** | 8.3% |

Media pesata sulle quote misurate: **17.7 → 22.5**. I pesi sono quote di pixel misurate,
proxy di leggibilità a distanza, non un modello percettivo.

Da notare, perché è una conseguenza dei dati e non una scelta: i due slot che la proposta
**avvicina** (`torso_a`, 18.6 → 7.3) sono quelli dove il dato autoriale e lo sprite divergono
di valore; i due che la proposta **allontana** di più (`torso_b`, `foot_b`, da ~0 a ~46) sono
quelli dove lo sprite non ha nessuna informazione di outfit. Cioè: la proposta è più separata
della misura grezza proprio perché sostituisce due trim bianchi condivisi con il ciano
dichiarato. Su `torso_a` la proposta riduce la separazione rispetto alla base, ed è una
conseguenza diretta di tenere il valore autoriale invece del modo ombreggiato dello sprite.

## 4. Valori misurati grezzi

Modi (bin più popoloso) e medie del cluster, per regione e famiglia. La moda è il colore che
un artista nominerebbe; la media include le ombre e serve solo come pista di audit.

| outfit | regione | famiglia | modo | media | quota | pixel |
|---|---|---|---|---|---|---|
| base | torso | a | `#471868` | `#5f257c` | 75.9% | 51578 |
| base | torso | b | `#fffeff` | `#ecacd3` | 24.1% | |
| base | hip | a | `#461868` | `#3d1951` | 74.8% | 39810 |
| base | hip | b | `#7936a5` | `#9f70ab` | 25.2% | |
| base | foot | a | `#060406` | `#3f2143` | 69.5% | 34000 |
| base | foot | b | `#fdfafb` | `#d9c2c2` | 30.5% | |
| base | boot_top | a | `#060607` | `#3d2a3f` | 68.4% | 20649 |
| base | boot_top | b | `#fcfafb` | `#dacccd` | 31.6% | |
| signature | torso | a | `#281548` | `#4c2c79` | 75.6% | 18475 |
| signature | torso | b | `#fffeff` | `#e6afd2` | 24.4% | |
| signature | hip | a | `#281648` | `#251537` | 57.4% | 14371 |
| signature | hip | b | `#593697` | `#7c5a9e` | 42.6% | |
| signature | foot | a | `#2a1947` | `#36203c` | 69.0% | 12128 |
| signature | foot | b | `#fcfafa` | `#d6bfc1` | 31.0% | |
| signature | boot_top | a | `#241838` | `#35293c` | 68.1% | 7644 |
| signature | boot_top | b | `#fcfafb` | `#d9ccce` | 31.9% | |

`boot_top` è una fascia di sola evidenza (0.78–0.86), **non** una regione del rig: il rig ha
tre regioni. È riportata perché il pale boot-top è dove il Maestro aveva una terza famiglia.

**Stabilità per foglio.** Il modo viola del capo, per foglio (foglie `run` escluse, vedi §2):

| foglio | base | signature |
|---|---|---|
| idle | hip `#280937` h281, foot `#381847` h281 | torso `#160c28` h262, hip `#281647` h262, foot `#241839` h262 |
| action | hip `#290938` h281, foot `#381847` h281 | hip `#281647` h262, foot `#241839` h262 |
| back-idle | torso `#471868` h276, hip `#451869` h274, foot `#391757` h272 | torso/hip `#281549` h262, foot `#291847` h262 |
| back-action | torso `#471868` h276, hip `#451869` h273, foot `#391757` h272 | torso/hip `#281548` h262, foot `#291848` h262 |
| back-run | torso `#481767` h277, hip `#481768` h277 | torso/hip `#281648` h262 |
| run (esclusa) | torso `#361839` h296, hip `#381836` h303 | torso `#371838` h298, hip `#381836` h305 |

Su `idle`/`action` frontali il torso non ha un modo viola utilizzabile proprio per il fallimento
della regola racchetta (§2): da lì la scelta di misurare il torso sul retro.

**Sensibilità della regola capelli** (le due varianti, §2). Su `torso` e `hip` le due regole
danno lo stesso modo (ΔE76 0.0), cambia solo il numero di pixel sopravvissuti (hip: 39810 →
29819, cioè la regola del Maestro mangia 9991 pixel di tessuto). Su `foot` le due regole
**divergono**: modo `#060406` (gate di saturazione) contro `#3a1856` (regola stretta), ΔE76
**44.6**. Cioè sugli stivali la scelta dell'euristica decide il colore dello slot. Il valore
portato è quello della regola con gate, che conserva il tessuto; la sensibilità è dichiarata
qui perché un revisore non debba riscoprirla.

## 5. Le due famiglie e il test di tinta dello shader

Il rischio da misurare era: se le due famiglie della stessa regione sono entrambe viola,
distano pochi gradi e il test di tinta dello shader (tolleranza **45°**) non le separa — lo
stesso problema del Maestro, dove distavano 20.0°.

**Esiste, ed è peggiore del Maestro.** Distanza in tinta fra le due famiglie dominanti che lo
sprite dipinge, per regione:

| regione | famiglia a | famiglia b | distanza in tinta | lettura |
|---|---|---|---|---|
| torso | `#281548` h262.0 sat0.704 | `#fffeff` h329.5 **sat0.002** | **indefinita** | la b non è un colore: è il bianco condiviso con la base. Sotto sat 0.15 la tinta non significa niente, e `sat_min` 0.18 la rifiuta comunque |
| hip | `#281648` h262.0 sat0.700 | `#593697` h262.0 sat0.645 | **0.0°** | entrambe a hue 262.0. Sotto una tolleranza di 45° il test di tinta accetta entrambe le famiglie per entrambe le target |
| foot | `#2a1947` h262.0 sat0.650 | `#fcfafa` h351.8 **sat0.009** | **indefinita** | come il torso: bianco condiviso |

Il Maestro stava a 20.0° e il suo problema era reale; qui l'anca sta a **0.0°**. Però la natura
del problema è diversa: le due famiglie dell'anca differiscono di **valore** (0.282 contro
0.593, un salto di 0.311), non di tinta. La correzione del Maestro è stata un **gate di
valore**, cioè una banda per famiglia misurata su una discontinuità di densità dell'atlante.

**Sull'atlante quel gate qui non c'è.** Le due famiglie saturate più grandi dell'atlante sono
`#341c54` (h265.7, **80.2%**) e `#9c745c` (h22.5, 19.8%), a 116.8° l'una dall'altra — ma la
seconda è la **pelle**, non un trim. La famiglia viola dell'atlante, misurata da sola
(`probes/probe_atlas_families.py`, regola sat > 0.25 e val > 0.10, hue 240–300):

| proprietà della famiglia viola | valore misurato |
|---|---|
| texel | **1 958 657** = 46.7% dell'atlante |
| continuità in **valore** | **nessun bin vuoto** fra 0.10 e 1.00, nessuna discontinuità di densità: non c'è un punto su cui mettere un gate |
| forma in valore | picco a 0.325–0.350 (244 080 texel), poi decadimento monotono con coda lunga fino a 1.0; p05/p50/p95 = 0.153 / 0.302 / 0.435 |
| continuità in **tinta** | **nessun buco** in 240–300°; 74.1% in 260–270°, 89.3% in 255–275° |
| seconda famiglia viola | **non esiste**: la famiglia è unica e continua |

Due conseguenze, dette come stanno:

1. La separazione che lo sprite ha nell'anca (viola scuro / viola medio) **non esiste come due
   famiglie nell'atlante**. Il capo dell'atlante è una sola famiglia viola continua: gli slot
   `hip_a` e `hip_b` non hanno due famiglie distinte su cui atterrare, e il gate di valore del
   Maestro non è disponibile perché non c'è nessuna discontinuità di densità da misurare.
2. La seconda famiglia dell'atlante è la **pelle** (h22.5), che lo shader protegge. Quindi la
   struttura a sei slot non ha, sull'atlante, una seconda famiglia di capo da riempire.

**Questo è un limite misurato, non una conclusione definitiva.** Le ancore del profilo vanno
misurate *dentro* la maschera, e la maschera dell'Oracolo non esiste ancora nell'albero
(`mask_lane_cross_check.present = false`). Quello che questa corsia può dire è la struttura
globale dell'atlante — una sola famiglia viola, continua — e che la corsia della maschera dovrà
o trovare due famiglie separabili dentro il capo, o dichiarare che gli slot `_b` sono inerti.

**Il ciano dichiarato non ha superficie.** Il secondo colore dichiarato è `#29dfff` (hue 189.0,
sat 0.839), ed è quello che va in `torso_b` e `foot_b`. Sull'atlante, hue 170–215 con
sat > 0.25 e val > 0.10: **11 texel**, cioè 0.0004% dei texel saturi. (A sat ≥ 0.35 senza il
gate di valore se ne contano 8547, ma 8536 sono quasi-neri con val ≤ 0.10, dove la tinta è
rumore: il conteggio utile è 11.) Cioè: gli slot `torso_b` e `foot_b` portano il ciano
dichiarato ma non hanno praticamente nessun texel su cui dipingerlo. È lo stesso caso di
`foot_b` del Maestro — che non muoveva niente perché `sat_min` rifiutava il grigio — ma qui
peggiore, perché non c'è proprio una famiglia ciano. Chi integra il profilo deve aspettarsi
che quei due slot muovano ~niente finché la maschera non dimostri il contrario.

## 6. La discrepanza del catalogo, risolta con le misure

Il catalogo di riferimento dichiara per l'Oracolo `visual.kit #6b3df0` e `visual.accent
#e3c6ff`, mentre l'outfit `base` dichiara `colors ["#6d42b8", "#a96cff"]`. È l'unico atleta
dove i due dati non coincidono, ed è documentato in `outfit_catalogue.gd` dove **vince il dato
dell'outfit**. Verificato sugli sprite: **il dato dell'outfit ha ragione, e la scelta del
catalogo è corretta.**

Metodo (`probes/probe_discrepancy.py`, che riusa le costanti e le funzioni dello strumento,
quindi la segmentazione è identica): un pixel di tessuto ombreggiato è una copia del colore
di pittura **scalata in valore** — stessa tinta, stessa saturazione, valore più basso. Per ogni
candidato si costruisce la retta delle sue ombre `{C·k, k ∈ [0.05, 1]}` e si misura la distanza
media ΔE76 dei pixel del capo da quella retta. Vince il candidato su cui i pixel giacciono
davvero. Otto celle: {base, signature} × {torso, hip, foot, boot_top}, pixel viola del capo
(hue 240–300, sat > 0.35).

| candidato | tinta | ΔE76 medio alla retta delle ombre (8 celle) | Δhue medio dal misurato | celle vinte |
|---|---|---|---|---|
| `base.colors[0] #6d42b8` | 261.9° | **8.24** | 10.4° | **5/8** |
| `base.colors[1] #a96cff` | 264.9° | **8.71** | 7.6° | **3/8** |
| `visual.kit #6b3df0` | 255.4° | 10.73 | 16.8° | **0/8** |
| `visual.shoes #3c1f8a` | 256.3° | 12.36 | 16.0° | 0/8 |
| `sig colors[0] #38216f` | 257.7° | 13.00 | 14.6° | 0/8 |
| `visual.secondary #1a0f38` | 256.1° | 24.46 | 16.2° | 0/8 |
| `visual.accent #e3c6ff` | 270.5° | 31.99 | 6.5° | 0/8 |
| `sig colors[1] #29dfff` | 189.0° | 46.71 | 83.3° | 0/8 |

I due valori dell'outfit `base` vincono **tutte e otto** le celle; `visual.kit` non ne vince
nessuna. Il dettaglio per cella, che è la parte che convince:

| cella | pixel | tinta misurata | Δhue da `#6d42b8` | Δhue da `#6b3df0` | ΔE76 `#6d42b8` | ΔE76 `#6b3df0` |
|---|---|---|---|---|---|---|
| base / torso | 40169 | 279.3° | 17.4° | 23.9° | 14.02 | 15.22 |
| base / hip | 29643 | 277.0° | 15.1° | 21.6° | 9.62 | 11.00 |
| base / foot | 14549 | 278.3° | 16.4° | 22.9° | 8.67 | 11.20 |
| base / boot_top | 7943 | 280.5° | 18.6° | 25.0° | 8.74 | 11.79 |
| signature / torso | 14464 | 264.8° | **2.9°** | 9.3° | 8.45 | 10.88 |
| signature / hip | 10684 | 264.0° | **2.1°** | 8.6° | 5.05 | 7.74 |
| signature / foot | 5294 | 266.3° | **4.4°** | 10.8° | 5.55 | 8.77 |
| signature / boot_top | 3108 | 268.0° | **6.1°** | 12.6° | 5.83 | 9.25 |

Sull'outfit `signature` la tinta misurata sta a 264.0–268.0°, cioè a 2.1–6.1° da `#6d42b8` e a
8.6–12.6° da `#6b3df0`: il divario è sistematico, sempre nello stesso verso, su tutte e quattro
le regioni. Nessuna delle due coppie descrive il personaggio *esattamente* — la base sta a
277–280.5°, che è 15–19° da `#6d42b8` e 22–25° da `#6b3df0` — ma il dato dell'outfit è più
vicino in **ogni** cella, e sull'outfit `signature` è vicino quasi esattamente.

**Terza conferma, indipendente dagli sprite: l'atlante 3D.** La famiglia di capo dominante
dell'atlante è `#341c54` (h265.7, sat0.667, 80.2% dei texel saturi). Confrontata con i candidati:

| candidato | tinta | Δhue dall'atlante | saturazione | Δsat dall'atlante |
|---|---|---|---|---|
| `base.colors[1] #a96cff` | 264.9° | **0.8°** | 0.576 | 0.090 |
| `base.colors[0] #6d42b8` | 261.9° | **3.8°** | 0.641 | **0.025** |
| `visual.kit #6b3df0` | 255.4° | 10.3° | 0.746 | 0.079 |
| `visual.accent #e3c6ff` | 270.5° | 4.8° | 0.224 | **0.443** |

L'atlante sta a 0.8–3.8° dai due valori dell'outfit e a 10.3° da `visual.kit`. E la sua
saturazione (0.667) combacia con `#6d42b8` (0.641, Δ 0.025) molto meglio che con `visual.accent`
(0.224, Δ 0.443). Il modello 3D è quindi stato cotto dalla stessa famiglia cromatica del dato
dell'outfit, non da `visual.kit`/`visual.accent`.

**Conclusione operativa:** il dato che descrive il personaggio reale è
`["#6d42b8", "#a96cff"]`. `visual.kit #6b3df0` / `visual.accent #e3c6ff` non va usato per
derivare colori 3D. La scelta già presente in `outfit_catalogue.gd` (vince il dato dell'outfit)
è confermata dalle misure su tre fonti indipendenti — sprite base, sprite outfit, atlante cotto.

## 7. Quanto è reskin e quanto è geometria nuova

L'audit classifica Oracolo Signature come **"T+G locale"** (texture più geometria): la carta 2D
mostra top corto e spalle scoperte che il vestito/armatura attuale non ha. Misurato, quel
"T+G" **non è confermato dagli sprite**: è vero solo della carta, e la carta è un'illustrazione.

### 7.1 Gli sprite: l'outfit è una ricolorazione pura

Confronto **indipendente dalla risoluzione** (`probes/probe_silhouette.py`), perché base e
outfit sono disegnati a scale diverse e un confronto pixel-per-pixel richiederebbe di
ricampionare l'una sull'altra (§1, e la stessa avvertenza è nello strumento). Le due grandezze
usate sono normalizzate e sopravvivono al cambio di scala: la **quota di pelle** dentro una
fascia e la **larghezza della fascia divisa per l'altezza del corpo**. 6 foglie × 20 fasce =
**120 confronti**:

| foglio | Δ quota di pelle (media / peggiore) | fasce oltre ±10 pp | Δ larghezza normalizzata (media / peggiore) | fasce oltre ±10% |
|---|---|---|---|---|
| idle | +0.1 pp / +1.8 pp | 0/20 | −0.6% / −3.2% | 0/20 |
| action | −0.3 pp / −1.1 pp | 0/20 | −1.2% / −16.8% | 1/20 |
| run | −0.2 pp / −1.8 pp | 0/20 | −1.0% / −3.3% | 0/20 |
| back-idle | −0.1 pp / +1.1 pp | 0/20 | −0.4% / −1.1% | 0/20 |
| back-action | −0.1 pp / +1.5 pp | 0/20 | −0.2% / +4.5% | 0/20 |
| back-run | −0.0 pp / +1.6 pp | 0/20 | −1.6% / −23.4% | 1/20 |

Le due sole fasce oltre il 10% di larghezza sono `action` a 0.20 (−16.8%) e `back-run` a 0.95
(−23.4%), e in **entrambe** la quota di pelle è invariata (23.5→23.4 e 9.8→10.4): sono bordi di
posa/render, non un cambio di capo.

Cioè: **lo sprite dell'outfit è lo sprite base ricolorato.** Stessa silhouette, stessa
esposizione di pelle, entro 1.8 punti percentuali di pelle su tutte e 120 le fasce. Non c'è
nessun top corto e nessuna spalla scoperta nello sprite in campo.

Verificato anche a occhio, non solo coi numeri: la tavola
`probes/montage.png` mette affiancati la carta, lo sprite base, lo sprite signature e il
modello 3D cotto. Carta: top corto, spalle e vita scoperte, ciano e trim dorato. Sprite base e
sprite signature: capo **chiuso** che copre spalle e busto, pelle solo su gambe, viso e collo.
Modello 3D: spalle coperte, vita coperta, manica corta, solo un accenno di scollo.

### 7.2 La carta è un'altra illustrazione

`card_check`: la carta `signature-preview.webp` (560×747) differisce dalla carta base
`assets/athletes/oracolo.webp` (1024×1536) sul **60.3%** della sua area a Δ > 16/255 per canale
(media 38.5/255). Non è una ricolorazione della carta base: è un disegno diverso. Come da
istruzione, il riferimento è lo sprite, e la carta non è stata seguita.

### 7.3 Quello che il modello 3D non può dare con la sola ricolorazione

Misure sulla superficie reale del GLB, pesate per area dei triangoli e classificate campionando
l'atlante cotto alle UV di ciascun triangolo:

| zona | area | viola | pelle | quasi-nero | quota di pelle fuori dai capelli |
|---|---|---|---|---|---|
| spalle (top, 1.38–1.47 m) | 0.0416 m² | 11.8% | 1.2% | 83.9% (capelli) | 7.7% |
| spalle (senza capelli) | 0.0067 m² | **73.7%** | 7.7% | — | 7.7% |
| petto (1.20–1.45 m, fronte) | 0.2295 m² | 56.4% | 14.4% | 0.2% | 14.4% |
| **vita** (1.00–1.20 m, fronte) | 0.1907 m² | **57.9%** | 23.0% | 0.0% | 23.0% |
| gonna (0.80–1.00 m) | 0.6005 m² | 70.5% | 5.7% | 2.4% | 5.8% |
| coscia (0.55–0.80 m) | 0.2124 m² | 7.0% | 86.9% | 0.1% | 87.0% |
| stivale (0.15–0.55 m) | 0.1722 m² | 32.3% | 28.1% | 0.1% | 28.2% |
| piede (0.00–0.15 m) | 0.1141 m² | 40.6% | 5.3% | 0.5% | 5.3% |

Corpo intero 3.4457 m²: viola **1.5704 m²** (45.6%), pelle 0.5674 m² (16.5%), quasi-nero
0.5737 m² (16.7%), altro 0.6993 m² (20.3%), grigio/bianco 0.0315 m² (0.9%), magenta 0.0033 m².

Il modello ha **le spalle coperte** (la zona spalle, fuori dai capelli, è viola per il 73.7% e
pelle per il 7.7%) e **la vita coperta** (viola 57.9%, pelle 23.0%). Per ottenere il look della
carta — top corto e spalle scoperte — quella superficie di capo dovrebbe leggersi come pelle
nuda:

| da convertire in pelle nuda | area | quota del capo (1.5704 m²) | quota del corpo (3.4457 m²) |
|---|---|---|---|
| viola sulle spalle | 0.0049 m² | 0.3% | 0.1% |
| viola sulla vita | 0.1104 m² | 7.0% | 3.2% |
| **totale** | **0.1153 m²** | **7.3%** | **3.3%** |

Sono numeri piccoli, e questo è il punto: **il problema non è quanto, è dove.** Il motivo per
cui la sola ricolorazione non ci arriva non è l'area, è la struttura della maschera:

* le regioni della maschera sono **gruppi ossei** (torso, hip, foot). La vita (1.00–1.20 m) e il
  petto (1.20–1.45 m) cadono **entrambi** nella regione `torso`. Dipingere la vita di pelle
  significa dipingere di pelle anche il petto, a meno che la divisione in famiglie della
  maschera non li separi per colore;
* e i due non si separano per colore: il profilo frontale del tronco (`front_trunk_profile` nel
  report) dà viola 61.0% e pelle 23.1% a 1.00–1.05 m, viola 43.0% e pelle 8.6% a 1.15–1.20 m,
  viola 48.7% e pelle 5.6% a 1.20–1.25 m — la stessa famiglia viola attraversa il confine,
  senza gradini;
* e sull'atlante la famiglia viola è **unica e continua** (§5): non c'è una seconda famiglia in
  cui mettere la vita separandola dal petto.

Quindi, detto senza promettere equivalenza: **la ricolorazione dà il colore del capo e non la
sua forma.** Il look della carta richiede o geometria nuova (un top che finisce sopra la vita e
spalle scoperte) oppure una maschera che separi la vita dal petto — e la seconda strada non è
dimostrata possibile su questo atlante, mentre la prima è esattamente il "G" di "T+G".

### 7.4 Quanto pesa, visivamente, rispetto alla carta

Onestamente: **poco sul modello, tanto sulla carta.** Sulla sagoma del modello la differenza è
0.1153 m² su 3.4457 m², cioè il 3.3% della superficie del corpo, e cade tutta in due strisce
(0.0049 m² sulle spalle, 0.1104 m² sulla vita) che sul render frontale sono il bordo superiore
del busto e una fascia sopra la gonna. È una differenza che si vede in un confronto affiancato
con la carta, non una differenza che cambia la lettura del personaggio a schermo — e va pesata
contro il fatto che **lo sprite in campo, che è il riferimento, non la mostra affatto**. Chi
decide se spendere geometria nuova per il "G" sta decidendo se inseguire la carta o lo sprite:
questa corsia ha misurato entrambi e riporta i numeri, non la decisione.

## 8. Blocco GDScript

Da incollare in `OUTFIT_PROFILES` **dopo** la voce `maestro`, stessa struttura e stessi nomi di
campo (`mask`, `shader`, `anchor_a`, `anchor_b`, `mask_sha256_prefix`, `outfits`). I sei colori
sono quelli di §3. **Maschera, anchor e `mask_sha256_prefix` NON sono disponibili**: la
directory `godot/assets/athletes/outfits/oracolo` non esiste nell'albero
(`mask_lane_cross_check.present = false`), quindi quei tre campi restano `TODO` e non sono
inventati. Il sotto-dizionario `outfits` invece è definitivo e incollabile così com'è.

```gdscript
	# ORACOLO — measured from the in-field 2D sprites, not from the cards.
	# Tool: tools/character/measure_oracolo_palette.py. Report, per-sheet numbers and probes:
	# docs/agent-work/outfits-3d/evidence/oracolo-palette/.
	# The reference declares only TWO colours for this athlete
	# (js/data.js ATHLETE_OUTFITS.oracolo signature: ["#38216f", "#29dfff"]), so four slots
	# are "source" (the declared colour placed on the region the sprite paints it in) and two
	# are "sprite" (the measured modal colour of that region/family, which the reference
	# declares nowhere). No slot is a port deviation: `port_only` is empty.
	#
	# DATA DISCREPANCY, MEASURED: the reference catalogue's `visual.kit`/`visual.accent`
	# (#6b3df0 / #e3c6ff) do NOT describe this character; the `base` outfit's
	# colors (#6d42b8 / #a96cff) do. Measured three ways: on the in-field sprites the
	# outfit values win 8/8 region x outfit cells on a shade-line test (#6d42b8 mean dE76
	# 8.24 vs #6b3df0 10.73), the signature sprite's garment sits at hue 264.0-268.0 deg
	# (2.1-6.1 deg from #6d42b8, 8.6-12.6 deg from #6b3df0), and the BAKED atlas's own
	# dominant garment family #341c54 (hue 265.7, 80.2% of saturated texels) is 0.8-3.8 deg
	# from the outfit values and 10.3 deg from visual.kit. So the catalogue's rule that the
	# outfit record wins is correct. Probes: evidence/oracolo-palette/probes/.
	#
	# CAVEAT(mask): no Oracolo mask exists in the tree yet, so the three fields below cannot
	#       be filled from here and are left TODO on purpose. Two measured consequences the
	#       mask lane has to resolve, both from the atlas itself:
	#       1. the atlas's garment is ONE hue-continuous, value-continuous violet family
	#          (1,958,657 texels = 46.7% of the atlas; 74.1% of it in 260-270 deg; no empty
	#          value bin anywhere, so the Maestro's value-gate fix has no density
	#          discontinuity to sit on). The sprite's hip does carry two violet families
	#          (#281648 and #593697) but they are 0.0 deg apart in hue and differ only in
	#          value (0.282 vs 0.593), under a 45 deg hue tolerance. The `_b` slots may
	#          therefore be inert, or collapse onto the `_a` colour.
	#       2. the declared second colour #29dfff has essentially no surface on the atlas:
	#          hue 170-215 at sat > 0.25 and val > 0.10 is 11 texels (0.0004% of saturated).
	#          Expect `torso_b` and `foot_b` to move ~nothing until the mask proves otherwise.
	&"oracolo": {
		"mask": "TODO",                   # no mask in the tree; build_*_outfit_mask.py pattern
		"shader": REGION_SHADER_PATH,
		"anchor_a": "TODO",               # must be measured INSIDE the mask, not from here
		"anchor_b": "TODO",               # must be measured INSIDE the mask, not from here
		"mask_sha256_prefix": "TODO",
		"outfits": {
			# Reference colors: ["#38216f", "#29dfff"]. Sprite: a dark violet kit with a
			# mid-violet skirt panel and a shared near-white trim that the base wears too;
			# the declared cyan is nowhere in the atlas, so torso_b/foot_b carry it on faith.
			&"signature": {
				"torso_a": "#38216f", "torso_b": "#29dfff",
				"hip_a": "#281648", "hip_b": "#593697",
				"foot_a": "#2a1947", "foot_b": "#29dfff",
			},
		},
	},
```

Se il profilo viene invece costruito senza maschera, solo il sotto-dizionario `outfits` è già
definitivo e si può incollare così com'è.

## 9. Limiti onesti

1. **La maschera dell'Oracolo non esiste.** `godot/assets/athletes/outfits/oracolo` non è
   nell'albero (verificato: `No such file or directory`), quindi il percorso della maschera, le
   due ancore e il prefisso sha256 restano `TODO` e **non sono inventati**. Le sei slot non
   possono essere verificate contro una maschera da questa corsia: la verifica che qui è
   possibile è *sprite contro atlante*, non *slot contro texel mascherati*.
   **Nota sullo stato dell'albero:** mentre questa corsia lavorava è comparso
   `tools/character/build_oracolo_outfit_mask.py` (17:34), cioè la corsia della maschera ha
   iniziato a costruirla. La lettura `present = false` è quindi una fotografia al momento della
   misura, non una previsione: quando la maschera atterra, i tre campi `TODO` del blocco §8 si
   riempiono con i valori misurati **dentro** la maschera e gli slot `_b` si possono finalmente
   verificare contro la copertura reale.
2. **L'atlante ha una sola famiglia di capo.** La famiglia viola è unica, continua in tinta e
   in valore (46.7% dell'atlante). Il modello a due famiglie per regione non ha, sull'atlante,
   una seconda famiglia di capo su cui atterrare; il gate di valore del Maestro non è
   disponibile perché non c'è nessuna discontinuità di densità da misurare. Questa è una
   affermazione sulla **struttura globale dell'atlante**, non una misura di copertura: la
   maschera potrebbe ancora esporre due famiglie separabili dentro il capo, e solo la corsia
   della maschera può dirlo.
3. **Il ciano dichiarato non ha superficie.** `#29dfff` in `torso_b` e `foot_b`: sull'atlante
   11 texel utili (0.0004% dei saturi). Da aspettarsi inerti.
4. **Il gate di saturazione sui capelli è una scelta dichiarata, e su `foot` decide il colore.**
   Il secondary dichiarato `#1a0f38` dista 34/255 dal colore capelli dichiarato `#0e0c16`,
   quindi la regola del Maestro cancella tessuto viola scuro. Su `torso` e `hip` le due regole
   danno lo stesso modo; su `foot` danno `#060406` contro `#3a1856`, ΔE76 **44.6**. Il valore
   portato è quello della regola con gate (che conserva il tessuto), ma la sensibilità è reale.
5. **La regola racchetta fallisce su questo atleta.** L'Oracolo tiene la racchetta davanti al
   petto e la sua racchetta ha il piatto scuro: il blob oro trovato è di 61–224 px su
   idle/action, contro 1254 px altrove. La fascia `torso` frontale è quindi 16–30% quasi-nera e
   solo 13–22% viola, e il torso è stato misurato **sul retro**. Il numero di texel del torso
   viene dalle foglie di schiena, non dal fronte.
6. **Le foglie `run` sono un altro disegno** (tessuto a 293–306° contro 275°/262°, più crema
   `#ebd4b9` e verde `#18ff09`), quindi escluse dal pool dei colori per **tutte** le regioni.
   Chi legge `measured_palette_per_sheet` troverà lì valori che non entrano in nessuna slot.
7. **Il confronto pixel-per-pixel base/outfit è ricampionato e le sue percentuali sono un
   intervallo, non un valore.** Le cornici base sono larghe 298 px e quelle dell'outfit 179
   (fattore 1.665; `run` 220 contro 132, `back-run` 178 contro 107), quindi lo strumento
   ridimensiona la base con LANCZOS e lo dichiara (`resampled: true`, con l'avvertenza
   ereditata dalla corsia Maestro). I `changed_pct_*` in `pixel_changes_vs_base` vanno letti
   come ordini di grandezza. **La tesi di §7.1 non usa quei numeri**: usa quote di pelle e
   larghezze normalizzate, che sono indipendenti dalla risoluzione.
8. **Le anteprime 2D non sono state seguite.** Sono illustrazioni e la misura lo dice: la carta
   `signature` differisce dalla carta base sul 60.3% dell'area (media 38.5/255). La carta mostra
   top corto e spalle scoperte; gli sprite no; il riferimento è lo sprite.
9. **La griglia dei frame non cade su un vuoto di alpha su tutte le foglie.** Su `run` e sulle
   foglie `back-*` la divisione pari cade esattamente su un vuoto (deviazione 0 px); su `idle` e
   `action` no (deviazioni fino a 559 px), perché le figure non sono equispaziate. I conteggi
   dei frame sono quelli del contratto degli asset, verificati contro i vuoti dove i vuoti ci
   sono; il report porta la deviazione per foglia invece di nasconderla.
10. **1992 colonne di bordo** appartengono all'inchiostro di una figura vicina sulle foglie a
    quattro frame e sono state scartate dalla misura dei colori (`sheet_bleed`).
11. **`boot_top` non è una regione del rig.** È riportata come sola evidenza (0.78–0.86): il rig
    ha tre regioni e non ha nessuno slot per quella fascia.
12. **Nessuna equivalenza è promessa.** §7 dice esplicitamente cosa la ricolorazione dà (il
    colore del capo, e sugli sprite è una ricolorazione pura) e cosa non dà (la forma: top corto
    e spalle scoperte, 0.1153 m², 7.3% del capo). Il "G" di "T+G" resta geometria nuova.

## 10. File prodotti

| file | cosa |
|---|---|
| `tools/character/measure_oracolo_palette.py` | lo strumento (misura sprite + atlante + modello, nessuna scrittura di asset) |
| `docs/agent-work/outfits-3d/ORACOLO-PALETTE.md` | questo documento |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/oracolo-palette-report.json` | report macchina completo |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/mask-check-*.png` | controllo visivo delle fasce, per foglia |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/measured-slots.png`, `proposed-slots.png` | le sei slot misurate e proposte |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/model-front.png`, `model-back.png` | il modello cotto, fronte e retro |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/model-front-classes.png`, `model-back-classes.png` | classi di superficie del modello |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/probes/probe_discrepancy.py` + `.json` | §6: la discrepanza risolta |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/probes/probe_silhouette.py` + `.json` | §7.1: confronto silhouette/pelle indipendente dalla risoluzione |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/probes/probe_atlas_families.py` + `.json` | §5: struttura della famiglia viola dell'atlante |
| `docs/agent-work/outfits-3d/evidence/oracolo-palette/probes/make_montage.py` + `montage.png` | carta / sprite base / sprite signature / modello, affiancati |

Nessun file `.gd`, `.tscn` o `.gdshader` è stato modificato. Nessun commit.
