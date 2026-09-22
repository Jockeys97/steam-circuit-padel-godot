# MAESTRO — palette dei tre outfit 3D, misurata dagli sprite in campo

Specifica delle sei slot (regione × famiglia) per `circuit`, `legend` e `signature` del
Maestro, **derivata misurando gli sprite**. Nessuna modifica al gioco, nessun commit.
Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, ramo
`codex/integrate-arena-11m`. L'albero era già sporco di lavoro altrui e non è stato toccato.

Strumento: `tools/character/measure_maestro_palette.py` (numpy + PIL, nessuna rete).
Report macchina: `docs/agent-work/outfits-3d/evidence/maestro-palette/maestro-palette-report.json`.
Formato di riferimento: la voce `fiamma` di `OUTFIT_PROFILES` in
`godot/src/character/outfit_catalogue.gd` (letto, non modificato).

**Fuori scope, per istruzione:** l'outfit `mythic` del Maestro. Sulla carta ha cappotto,
pantaloni lunghi e stivali che lo sprite non ha: è geometria nuova e va fatto altrove.
Non è stato misurato e non compare in nessuna tabella di questo documento.

---

## 1. Metodo, in breve

| passo | come |
|---|---|
| griglia dei frame | divisione pari della striscia (`naturalWidth / frameCount`), come fa il runtime in `js/render.js`; i conteggi sono verificati contro i vuoti di alpha |
| bbox del corpo | `alpha > 200`, per frame |
| fasce | frazioni fisse dell'**altezza** della bbox: `torso 0.12–0.48`, `hip 0.48–0.66`, `foot 0.90–1.00`. Scelte dalla mappa riga-per-riga dello sprite base (stampata dallo script), non a occhio |
| esclusi | pelle, capelli, racchetta (euristiche, §2) |
| famiglie | k-means k=2 deterministico **per (outfit, regione)**, su tutti i pixel del capo delle foglie usabili; `a` = cluster più grande, `b` = l'altro |
| valore di una famiglia | la **moda** (bin più popoloso del cluster), non la media: la media include ombre e schiarisce il colore |
| distanza cromatica | CIE76 (ΔE76) su sRGB → Lab D65 |

Il numero di pixel misurati **non è confrontabile fra base e varianti**: nelle foglie
`idle`/`action`/`back-idle` lo sprite base è disegnato a 298 px per frame e quello degli
outfit a 179 px, quindi la base ha ~2.77× più pixel a parità di figura (`run`: 220 contro 132,
`back-run`: 178 contro 107). I confronti di colore sono fra modi, non fra conteggi.

### Riproduzione

```sh
python3 -m venv /tmp/palette-venv && /tmp/palette-venv/bin/pip install pillow numpy
/tmp/palette-venv/bin/python tools/character/measure_maestro_palette.py
# opzioni: --out-dir <dir>  --no-evidence  --change-eps <n>
```

Esito (troncato):

```
base       torso_a=#02c8fc(mode)/#42c9ef(mean) 56.6%  torso_b=#162a65(mode)/#192f62(mean) 43.4%  ...
circuit    torso_a=#2a78fe(mode)/#6094f1(mean) 56.4%  torso_b=#1c335a(mode)/#293c5e(mean) 43.6%  ...
legend     torso_a=#fff5d6(mode)/#f3ecd5(mean) 61.3%  torso_b=#5a471b(mode)/#68542b(mean) 38.7%  ...
signature  torso_a=#16c8ff(mode)/#51cef4(mean) 55.0%  torso_b=#195466(mode)/#285660(mean) 45.0%  ...
ATLAS godot/assets/athletes/maestro_texture_0.png: navy_hue195_265=40.7%(#132544)
      warm_hue_lt45_or_gt265=31.1%(#5c3b35) desaturated_grey=19.7%(#c3c3c3) near_black=4.6%(#000000)
```

## 2. Le tre euristiche di esclusione (dichiarate, non esatte)

| esclusione | regola | perché / quanto è grossolana |
|---|---|---|
| pelle | hue 9–38° **e** saturazione > 0.30 | finestra già usata dal port; la pelle dichiarata del Maestro (`#c98258`, hue 25°, sat 0.56) ci cade dentro. Nei bordi antialiasati può sfuggire qualche pixel |
| capelli | distanza max-canale ≤ 48/255 dal colore dichiarato `#241b19` | i capelli sono quasi neri; **la stessa regola toglie anche il telaio e il manico neri della racchetta**, che è desiderato |
| racchetta | blob 8-connesso più grande della famiglia oro (hue 40–62°, sat > 0.6, val > 200/255), chiuso 9 px poi dilatato 11 px | il blob oro è **solo** la faccia della racchetta: 616 px su ognuno dei tre sprite outfit e 1720 px sulla base, il cui frame è 1.665× più grande (616 × 1.665² = 1706). Stesso oggetto invariato. La dilatazione mangia anche qualche pixel della mano |

Il controllo visivo delle maschere è nelle immagini `mask-check-*.png`: su `idle` e `action`
le tre fasce cadono su maglia, pantaloncini e scarpe e nessuna maschera sbava sul tessuto.
Su `run` la fascia `hip` **non** è affidabile (vedi §9, limiti).

## 3. Tabella delle sei slot

`S` = dal dato sorgente (`js/data.js` ATHLETE_OUTFITS, voce maestro) · `M` = misurato
dallo sprite · `P` = scelta di port (deviazione deliberata sia dal dato sia dallo sprite).

### circuit — dato: `["#315cff", "#9ef8ff"]`

| slot | hex | origine | da dove viene |
|---|---|---|---|
| torso_a | `#315cff` | **S** | colore primario dichiarato. Lo sprite dipinge `#2a78fe` (56.4% della regione), stessa famiglia di tinta (Δhue 9.6°); lo sprite è solo più chiaro/scuro, quindi va il valore autoriale |
| torso_b | `#1c335a` | **M** | secondo colore dello sprite nel torso (43.6%): è il pannello/manica blu scuro della maglia. Il dato non ha un colore per questa regione |
| hip_a | `#315cff` | **P** | PORT: lo sprite dipinge i pantaloncini `#1c325a`, ma quello è esattamente il punto in cui circuit e signature si confondono (§6). Sostituito con il primario dichiarato: l'outfit legge blu dalla vita in giù |
| hip_b | `#9ef8ff` | **S** | secondo colore dichiarato. Lo sprite dipinge la striscia laterale di bianco (`#fcfbfb`, sat 0.004): bianco identico in base/circuit/signature, quindi non porta informazione di outfit |
| foot_a | `#183567` | **M** | corpo scarpa dallo sprite (74.1%). Il dato non dice nulla sulle scarpe |
| foot_b | `#9ef8ff` | **S** | suola/striscia bianca dallo sprite (`#fbfaf8`), quindi vale il secondo colore dichiarato (sat 0.38, è un colore) |

### legend — dato: `["#d5a62a", "#fff0a3"]`

| slot | hex | origine | da dove viene |
|---|---|---|---|
| torso_a | `#fff0a3` | **S** | secondo colore dichiarato. Lo sprite dipinge la maglia dominante avorio `#fff5d6` (61.3%), stessa tinta (Δhue 4.9°) |
| torso_b | `#5a471b` | **M** | secondo colore dello sprite nel torso (38.7%): oro scuro / oliva. Attenzione: lo sprite rende l'oro **scuro**, ΔE76 53.9 dal `#d5a62a` dichiarato (§6, alternativa) |
| hip_a | `#59471c` | **M** | pantaloncini dallo sprite (81.3%): stesso oro scuro, Δhue 1.2° dal dichiarato ma valore 0.35 contro 0.84 |
| hip_b | `#fff0a3` | **S** | la striscia è avorio `#fff5d6` (sat 0.161), cioè il bianco condiviso della base: vale il secondo colore dichiarato |
| foot_a | `#fef4d5` | **M** | scarpa avorio dallo sprite (51.1%). La `b` corrispondente è l'oro scuro (48.9%): la scarpa legend è bicolore e su quale famiglia sia "a" il dato non dice nulla |
| foot_b | `#5a4617` | **M** | oro scuro della scarpa |

### signature — dato: `["#03c7ed", "#162f61"]`

| slot | hex | origine | da dove viene |
|---|---|---|---|
| torso_a | `#03c7ed` | **S** | colore primario dichiarato. Sprite `#16c8ff` (55.0%), stessa tinta (Δhue 4.4°) |
| torso_b | `#195466` | **M** | secondo colore dello sprite nel torso (45.0%): pannello teal scuro |
| hip_a | `#154959` | **M** | pantaloncini dallo sprite (86.7%): teal scuro |
| hip_b | `#162f61` | **S** | striscia bianca nello sprite (`#fcfbfb`, sat 0.004) → vale il secondo colore dichiarato, che qui è un navy saturo (sat 0.773). Il dato dice "navy dove circuit ha il ciano pallido": è il principale separatore dei due outfit |
| foot_a | `#165568` | **M** | corpo scarpa dallo sprite (61.7%): teal scuro |
| foot_b | `#17c8fe` | **M** | accento ciano della scarpa dallo sprite (38.3%) |

Sintesi della provenienza, sui 18 valori: **7 dal dato sorgente**, **10 dallo sprite
misurato**, **1 scelta di port** (`circuit.hip_a`). Nessun hex in questa tabella è inventato:
la moda misurata di ogni slot sta nel report JSON accanto al valore proposto, con la share.

## 4. Valori misurati grezzi

Pixel del capo nella fascia, dopo le esclusioni, con la moda di ciascuna famiglia
(fra parentesi la sua quota sulla regione) e la media del cluster, che è più chiara perché
contiene le ombre. Pool di `idle`, `action`, `back-idle`, `back-action` (+ `run`/`back-run`
per `torso` e `foot`).

| outfit | regione | px | a (moda) | a % | a media | b (moda) | b % | b media |
|---|---|---|---|---|---|---|---|---|
| base | torso | 196522 | `#02c8fc` | 56.6 | `#42c9ef` | `#162a65` | 43.4 | `#192f62` |
| base | hip | 53118 | `#0d2359` | 86.7 | `#0f265e` | `#fcfbfb` | 13.3 | `#91d1e8` |
| base | foot | 35386 | `#072658` | 76.1 | `#115089` | `#fbf9f8` | 23.9 | `#d2d9df` |
| circuit | torso | 75299 | `#2a78fe` | 56.4 | `#6094f1` | `#1c335a` | 43.6 | `#293c5e` |
| circuit | hip | 19859 | `#1c325a` | 86.1 | `#20355b` | `#fcfbfb` | 13.9 | `#a1b3e7` |
| circuit | foot | 14075 | `#183567` | 74.1 | `#28498b` | `#fbfaf8` | 25.9 | `#d1d3dd` |
| legend | torso | 68572 | `#fff5d6` | 61.3 | `#f3ecd5` | `#5a471b` | 38.7 | `#68542b` |
| legend | hip | 14099 | `#59471c` | 81.3 | `#624d24` | `#fff5d6` | 18.7 | `#ebe4db` |
| legend | foot | 12813 | `#fef4d5` | 51.1 | `#dad5ca` | `#5a4617` | 48.9 | `#70562c` |
| signature | torso | 76573 | `#16c8ff` | 55.0 | `#51cef4` | `#195466` | 45.0 | `#285660` |
| signature | hip | 20438 | `#154959` | 86.7 | `#1b4e5e` | `#fcfbfb` | 13.3 | `#99d2eb` |
| signature | foot | 14020 | `#165568` | 61.7 | `#1d627d` | `#17c8fe` | 38.3 | `#98cfe4` |

Modi grezze più popolose (le prime tre di ogni regione, quota sul totale della regione):

| outfit | torso | hip | foot |
|---|---|---|---|
| base | `#02c8fc` 15.36, `#162a65` 10.32, `#01d3fe` 9.28 | `#0d2359` 17.36, `#12255a` 16.37, `#122a64` 12.02 | `#072658` 7.72, `#092a66` 5.83, `#fbf9f8` 5.48 |
| circuit | `#2a78fe` 32.17, `#1c335a` 7.7, `#243c65` 6.24 | `#1c325a` 25.86, `#162d54` 15.87, `#1c3766` 15.56 | `#183567` 8.63, `#142c57` 5.95, `#fbfaf8` 5.32 |
| legend | `#fff5d6` 38.56, `#5a471b` 9.36, `#685527` 8.9 | `#59471c` 37.24, `#6a531d` 7.85, `#634d1b` 7.32 | `#5a4617` 8.34, `#fef4d5` 6.27, `#fbfaf8` 5.82 |
| signature | `#16c8ff` 34.08, `#195466` 9.67, `#154959` 8.46 | `#154959` 30.41, `#175467` 20.07, `#0c4456` 8.22 | `#17c8fe` 7.23, `#165568` 6.12, `#0b4658` 5.63 |

Due cose che il k=2 non può mostrare e che la tabella delle modi sí:

* **il bianco `#fafafa` c'è in ogni torso** (base 6.05%, circuit 5.72%, legend 6.28%,
  signature 5.63%): è la striscia bianca sul petto, uguale in tutti e quattro. Con due sole
  famiglie per regione quella striscia **non è esprimibile**: finirà nel colore della
  famiglia a cui il suo texel appartiene nell'atlante;
* nelle regioni `hip` e `foot` la famiglia `b` di base, circuit e signature è lo stesso
 bianco (`#fcfbfb` su entrambe le `hip`, `#fbf9f8` su entrambi i `foot`): è il bianco del capo base, non una scelta
  dell'outfit. È la ragione della regola 2 della policy qui sotto.

### Stabilità per foglio

Ogni misura è ripetuta per foglio e riportata in `measured_palette_per_sheet`. Le modi
chiave sono stabili: `circuit.torso` dà `#2a78fe`/`#2a78ff` su tutti e sei i fogli
(22–44% di quota), `signature.torso` `#16c8ff`/`#15c8ff`/`#16c9ff`, `legend.torso`
`#fff5d6` su tutti; le `hip` restano nella stessa famiglia di tinta
(circuit `#1b335b`…`#243c65`, signature `#144a5a`…`#154959`, legend `#57461d`/`#59471c`).
**Instabile solo `legend.foot`**: la moda più popolosa è l'oro scuro sui fogli frontali
(`idle` `#5a4718` 16.25%, `action` `#5a4617` 8.63%, ma `run` no) e l'avorio/bianco su quelli
posteriori (`back-idle` `#fef4d5` 9.28%) — la scarpa legend è bicolore e l'ordine a/b dei due cluster cambia con
l'inquadratura. Nella tabella §3 ho tenuto l'ordine del pool, sapendolo fragile.

## 5. Le sei slot e le famiglie dell'atlante

La policy che produce la tabella §3, applicata meccanicamente dallo script:

1. **`torso_a` è la slot d'identità.** È la regione per cui il riferimento ha scritto i suoi
   due colori. Se la moda misurata sta nella stessa famiglia di tinta di un colore
   dichiarato (Δhue ≤ 12°, entrambi saturi) o entro ΔE76 20, vince **il valore dichiarato**:
   lo sprite è quel colore con la propria ombreggiatura, e lo shader 3D ombreggia di nuovo.
2. una famiglia `b` che lo sprite dipinge quasi bianca (sat < 0.20) prende **il secondo
   colore dichiarato**, se questo è a sua volta un colore (sat > 0.20). Il bianco è della
   base, non dell'outfit. Per circuit il dichiarato `#9ef8ff` ha sat 0.38 e quindi vince;
   per signature il dichiarato navy sat 0.77 vince e diventa il separatore principale.
3. **ogni altra slot prende la moda misurata della propria regione.** Scelta deliberata: il
   riferimento dichiara due colori, lo sprite ne dipinge uno diverso per regione, e le sei
   slot esistono esattamente per esprimere quella differenza. Fondere tutto sui due colori
   dichiarati farebbe di circuit un blu uniforme e di signature un ciano uniforme — proprio
   il conflitto di §6.
4. gli override di port vincono su tutto e sono marcati `P`.

**Avvertenza strutturale, misurata.** Nel `fiamma` le due famiglie dell'atlante sono due
tinte distinte (lime vs navy). Per il Maestro l'atlante baked (`maestro_texture_0.png`,
identico per sha256 alla texture dentro `maestro.glb`, misurato in sola lettura dallo
script) ha **una sola famiglia satura**: navy (hue 195–265) al 40.7%, mediana `#132544`, con
modi `#142444` (16.9%) e `#041c44` (11.0%); poi 31.1% di tinte calde (pelle/capelli), 19.7%
di grigi desaturati (`#c3c3c3`) e 4.6% di quasi-nero. Le bande di tinta sature sono 210–240°
al 52.4% e 0–30° al 39.3%, **non c'è ciano** (180–210°: 4.1%). Un grigio non può diventare
una famiglia: il test di famiglia dello shader richiede `sat > sat_min`.

### Cosa dice la corsia della maschera (in lettura)

La corsia della maschera (**non mia**, `tools/character/build_maestro_outfit_mask.py`,
report `docs/agent-work/outfits-3d/evidence/maestro-mask-report.json`) ha nel frattempo
costruito la maschera: `godot/assets/athletes/outfits/maestro/maestro_region_mask.png`,
2048², sha256[:16] `dc39e62c92bc5b8e` (ricalcolato dal mio strumento, `mask_lane_cross_check`),
copertura 0.362 = 1.518.488 texel, regioni da 1124 (torso) / 1850 (hip) / 2564 (foot)
triangoli su 12253. Questi i suoi numeri che contano per le sei slot:

| fatto | valore |
|---|---|
| anchor della famiglia dominante | `#102040`, navy, hue 217.1°, 54.088 campioni, 10.335 hit modali |
| anchor della seconda famiglia | `#68a8c8`, sky, hue 196.5°, 2.563 campioni, 557 hit modali |
| separazione di tinta fra i due anchor | **20.0°**, sotto la tolleranza effettiva dello shader (`hue_tol_deg` 45.0°, `sat_min` 0.18) |
| texel che colpiscono l'anchor navy / sky | 1.127.490 / 1.114.593 |
| texel che colpiscono **entrambi** | **1.114.473**, cioè il 99.99% dei 1.114.593 texel "sky" (e il 98.8% dei texel "navy") |
| verdetto della corsia | `hue_test_separates_the_two_families: false` |

Cioè: il test di famiglia **non separa** le due famiglie del Maestro. 20° di distanza sotto
una tolleranza di 45° significa che ogni texel che "è" sky è anche navy, e le due target
collassano su una sola. Questo non è un'opinione: è la conclusione della corsia della
maschera sulla stessa texture che ho misurato, e combacia con l'inventario dell'atlante (una
sola famiglia satura).

Conseguenze pratiche, da tenere presenti prima di cablare il profilo:

* **le sei slot possono collassare a tre.** Se le due famiglie non si separano, `torso_a` e
  `torso_b` non sono indirizzabili separatamente: la regione prende una delle due target. La
  tabella §3 resta la mappa corretta *se e quando* le famiglie si separano; senza quella
  separazione il profilo va letto come "un colore per regione", e allora **conta solo la
  slot `a`**, che è già quella d'identità. La `b` va scelta come seconda scelta innocua, non
  come secondo colore;
* per coverage, nella regione `torso` la classe navy copre 197.794 texel sui 244.240
  mascherati (81.0%), la `sky` 7.336 (3.0%): la famiglia secondaria ha **il 3% del torso**.
  Se la `b` non è indirizzabile, il colore che si perde è una minoranza, non metà maglia;
* `neutral` (texel che non colpiscono nessun anchor) è 409.697 su 938.784 nella regione
  `foot` (**43.6%**) e 32.337 su 244.240 nel torso (13.2%), ma solo 615 su 335.680 nella
  `hip` (0.2%).
  Lo sprite, nella stessa fascia `foot`, ha la suola/striscia bianca sul 24–26% dei pixel:
  **il bianco delle scarpe e delle strisce può non avere texel riccolorabili nel modello 3D**.
  Le slot `hip_b` e `foot_b`, che nella tabella §3 portano i colori dichiarati sulle strisce
  bianche, rischiano di essere inerti;
* gli anchor `a`/`b` del profilo sono quindi **quelli della corsia della maschera**, non
  scelti da me: `#102040` e `#68a8c8`. Li riporto nel blocco di §8 perché sono misurati,
  ma la decisione su come farli separare (stringere `hue_tol_deg` per questo atleta,
  o spostare un anchor, o accettare due colori per regione) **non è di questo documento**;
* come orientamento, non come anchor, le modi della base misurate sui miei sprite sono torso
  `#02c8fc`/`#162a65`, hip `#0d2359`/`#fcfbfb`, foot `#072658`/`#fbf9f8`: la maglia della
  base 2D è ciano (`#08bfe8` dichiarato) mentre l'atlante è navy, quindi la divergenza 2D/3D
  su questo atleta esiste già oggi.

## 6. Conflitto circuit / signature

### Cosa dicono le misure

Distanza ΔE76 fra i valori proposti delle due divise, slot per slot, e fra le modi misurate:

| slot | circuit | signature | ΔE76 misurato | ΔE76 proposto | Δhue | Δval |
|---|---|---|---|---|---|---|
| torso_a | `#315cff` | `#03c7ed` | 62.4 | **93.8** | 23.8° | 0.004 |
| torso_b | `#1c335a` | `#195466` | 23.3 | 23.3 | 23.7° | 0.047 |
| hip_a | `#315cff` | `#154959` | 22.2 | **90.6** | 24.6° | 0.004 |
| hip_b | `#9ef8ff` | `#162f61` | 0.0 | **82.8** | n/d (bianco) | 0.000 |
| foot_a | `#183567` | `#165568` | 28.3 | 28.3 | 24.1° | 0.004 |
| foot_b | `#9ef8ff` | `#17c8fe` | 50.3 | 31.3 | n/d (bianco contro ciano) | 0.012 |

Proxy pesato sui pixel (quota di pixel della regione × famiglia): **39.1 → 63.3**.
Il proxy conta i pixel, non l'importanza visiva, ed è dominato dal torso (38.4% del peso
sulla sola `torso_a`, 30.5% su `torso_b`).

Il quadro vero è questo: **le due divise si distinguono già sulla maglia** (ΔE 62 misurato,
94 proposto) **e sull'accento della scarpa** (ΔE 50 misurato), ma **coincidono sul bacino**: i due pantaloncini
misurati stanno a ΔE 22.2 con lo stesso valore (0.35) e 24.6° di tinta, e le due famiglie
`b` di `hip` sono il medesimo bianco, ΔE 0.0. Il bacino è la seconda massa di capo
(15.8% del peso) ed è l'unica regione che a distanza di gioco legge uguale.

### Proposta

**Un solo spostamento, e usa un colore che l'outfit già dichiara.**

* **`circuit.hip_a = #315cff`** (port, al posto del misurato `#1c325a`): i pantaloncini
  prendono il blu primario dichiarato. La separazione sul bacino passa da ΔE76 22.2 a 90.6 e
  il proxy pesato sale da 52.4 (che è dove resta senza questo spostamento) a 63.3. L'outfit
  legge blu dalla vita in giù, cioè diventa blu dove signature resta scura.
* **nessun altro port**: `signature.hip_b` e `signature.foot_b` prendono già il navy
  dichiarato `#162f61` per la regola 2, ed è quello che apre ΔE 82.8 sul bacino e sul
  piede dove circuit ha il ciano pallido. Non serve toccare signature.
* il movimento opposto **non** funziona ed è per questo che il port è su circuit: portare
  `signature.hip_a` sul navy dichiarato darebbe ΔE76 7.1 dal misurato di circuit, cioè
  peggiorerebbe.

### Slot che restano deboli, dette come stanno

* `torso_b` resta a ΔE 23.3: entrambe le divise dipingono quel pannello scuro con lo stesso
  valore e 24° di tinta, e il riferimento non offre nessun colore per separarlo. Copre il
  30.5% del peso, ma è la famiglia secondaria del torso: se nell'atlante ha poco tessuto,
  conta poco. Se invece ne ha molto, l'unica leva residua è allontanare a mano il pannello
  di una delle due divise — e questo **sarebbe** un colore inventato, quindi non lo propongo;
* `foot_a` resta a ΔE 28.3 (navy `#183567` vs teal `#165568`): le due scarpe hanno corpi
  vicini. Leva residua, se il playtest le confonde ancora: `circuit.foot_a` → il suo blu
  dichiarato `#315cff`. Non lo includo perché sarebbe un secondo allontanamento dallo sprite
  in una regione che già si distingue sull'accento.

### Alternative, con i numeri

| variante | proxy pesato | costo |
|---|---|---|
| tutte le slot = moda misurata (nessuna policy, nessun port) | 39.1 | il bacino resta ΔE 22 e le due famiglie `b` sono identiche |
| **proposta di questo documento** | **63.3** | un port (`circuit.hip_a`) |
| proposta + `circuit.foot_b` lasciato bianco come lo sprite | 64.0 | incoerenza: la regola 2 non varrebbe per la suola di circuit |
| proposta + `signature.foot_b` → navy dichiarato `#162f61` | 65.4 | la scarpa signature perde il ciano (che resta sulla maglia) |
| tutte e sei le slot = primario dichiarato per entrambe | 93.8 | massima separazione ma butta la struttura a due famiglie: due divise monocrome, e per legend non è applicabile (il primario è oro, lo sprite è avorio) |
| `legend`: `torso_b`/`hip_a`/`foot_b` sul dichiarato `#d5a62a` | — | l'oro dichiarato è ΔE76 53.9–54.4 dall'oro scuro che lo sprite dipinge davvero (valore 0.84 contro 0.35). Vale solo se la squadra preferisce il colore della carta allo sprite; **qui ho tenuto lo sprite** |

## 7. Verifica dei dati pre-misurati (non riprodotti)

I numeri dati in consegna — cambio rispetto alla base 25.0% circuit, 35.9% legend, 31.2%
signature, e 8.3% fra circuit e signature — **non li ho riprodotti**. Misure mie
(`--change-eps 16`, per foglio `idle`, come percentuale dei pixel del corpo / del rettangolo
del frame):

| confronto | % corpo | % frame |
|---|---|---|
| circuit vs base | 35.7 | 7.4 |
| legend vs base | 62.6 | 13.1 |
| signature vs base | 60.4 | 12.7 |
| circuit vs signature | 38.9 | 8.67 |

Media sui sei fogli (sempre `eps 16`, % corpo): circuit 47.9, legend 73.5, signature 71.4,
circuit-vs-signature 45.7.

Sweep su `--change-eps` (foglio `idle`, % corpo): 8 → 70.0 / 72.8 / 72.4 e 43.3;
24 → 26.5 / 57.1 / 46.1 e 22.2; 48 → 13.8 / 45.0 / 8.1 e 11.7.
Nessuna soglia dà la terna (25.0, 35.9, 31.2). L'unico valore vicino è l'8.3%: il mio
8.67% per circuit-vs-signature è la percentuale **del rettangolo del frame** a `eps 16`. Ma
con quello stesso denominatore circuit-vs-base dà 7.4%, non 25.0%.

Ho provato: base riscalata alla risoluzione dell'outfit e viceversa, con e senza blur,
soglie 8/16/24/32/48/64/96 per canale, per foglio e in pool, entrambi i denominatori. La
conclusione è che i quattro numeri non vengono da una singola metrica riproducibile su
questi file, quindi **non vanno citati a valle**. Quello che invece è confermato, e misurato
in modo esatto (stessa risoluzione, nessun riscalamento), è la conclusione di merito: circuit
e signature sono la coppia **più vicina**. ΔE76 fra le modi misurate, slot per slot
(torso_a, torso_b, hip_a, hip_b, foot_a, foot_b):

| coppia | ΔE76 per slot | lettura |
|---|---|---|
| circuit vs signature | 62.4, 23.3, 22.2, **0.0**, 28.3, 50.3 | il bianco del bacino è **identico** e bacino e pannello stanno a ~22: quattro slot su sei sotto ΔE 30 |
| circuit vs legend | 102.8, 55.9, 55.8, 16.3, 88.8, 73.6 | sotto ΔE 60 solo il bianco condiviso (16.3) |
| signature vs legend | 61.8, 47.0, 44.6, 16.3, 71.8, 85.2 | idem |

## 8. Blocco GDScript

Da incollare in `OUTFIT_PROFILES` **dopo** la voce `fiamma`, stessa struttura e stessi nomi
di campo (`mask`, `shader`, `anchor_a`, `anchor_b`, `mask_sha256_prefix`, `outfits`). I sei
colori per outfit sono quelli di §3. Maschera, anchor e `mask_sha256_prefix` **non sono
miei**: sono i valori misurati dalla corsia della maschera, citati dal suo report (§5), e li
ho solo letti e ricopiati. Attenzione a due conseguenze di §5: il test di famiglia **non
separa** i due anchor del Maestro (20° sotto una tolleranza di 45°), quindi in pratica la
regione può prendere una sola delle due target; e gli anchor stessi sono ancora materia di
decisione per quella corsia, non un dato definitivo.

```gdscript
	# MAESTRO — measured from the in-field 2D sprites, not from the cards.
	# Tool: tools/character/measure_maestro_palette.py. Report and per-sheet numbers:
	# docs/agent-work/outfits-3d/evidence/maestro-palette/.
	# Slots marked "source" are js/data.js ATHLETE_OUTFITS.maestro values placed on the
	# region the sprite paints that colour in; "measured" slots are the modal colour of
	# that region and family in the sprite; the single "port" slot is listed in
	# `port_only` and is a deliberate deviation from BOTH, taken to separate circuit from
	# signature (their measured shorts sit dE76 22.2 apart at equal value).
	# CAVEAT(mask): the Maestro atlas has ONE saturated family (my measurement: navy 40.7%
	#       of saturated texels), and the mask lane's own family test agrees that the two
	#       anchors do not separate (20.0 deg apart under a 45 deg tolerance). Until that
	#       is resolved the six slots may collapse to three: treat the `a` slots as the
	#       outfit and the `b` slots as a second choice that may never be painted.
	&"maestro": {
		"mask": "res://assets/athletes/outfits/maestro/maestro_region_mask.png",
		# anchors and prefix: MEASURED by tools/character/build_maestro_outfit_mask.py and
		# quoted from docs/agent-work/outfits-3d/evidence/maestro-mask-report.json.
		# caveat from that same report: hue separation is 20.0 deg under a 45 deg
		# tolerance, hue_test_separates_the_two_families = false.
		"shader": REGION_SHADER_PATH,
		"anchor_a": "#102040",             # navy, hue 217.1 deg, 54088 samples
		"anchor_b": "#68a8c8",             # sky,  hue 196.5 deg, 2563 samples
		"mask_sha256_prefix": "dc39e62c92bc5b8e",
		"outfits": {
			# Reference colors: ["#315cff", "#9ef8ff"]. Sprite: a royal-blue kit with a
			# navy panel and white side stripes, navy shoes, white sole.
			&"circuit": {
				"torso_a": "#315cff", "torso_b": "#1c335a",
				"hip_a": "#315cff", "hip_b": "#9ef8ff",
				"foot_a": "#183567", "foot_b": "#9ef8ff",
				"port_only": ["hip_a"],
			},
			# Reference colors: ["#d5a62a", "#fff0a3"]. Sprite: an ivory kit with a DARK
			# antique-gold trim and shorts (the sprite shades the declared gold to val 0.35;
			# this profile keeps the sprite, so the outfit reads dark), ivory shoes with a
			# dark-gold accent.
			&"legend": {
				"torso_a": "#fff0a3", "torso_b": "#5a471b",
				"hip_a": "#59471c", "hip_b": "#fff0a3",
				"foot_a": "#fef4d5", "foot_b": "#5a4617",
			},
			# Reference colors: ["#03c7ed", "#162f61"]. Sprite: a cyan kit with a dark-teal
			# panel, dark-teal shorts, dark-teal shoes with a cyan accent. The navy trim is
			# what keeps this outfit legible next to circuit.
			&"signature": {
				"torso_a": "#03c7ed", "torso_b": "#195466",
				"hip_a": "#154959", "hip_b": "#162f61",
				"foot_a": "#165568", "foot_b": "#17c8fe",
			},
		},
	},
```

Se il profilo viene invece costruito senza maschera, solo il sotto-dizionario `outfits` è
già definitivo e si può incollare così com'è.

## 9. Limiti onesti

1. **Le anteprime 2D non sono state seguite.** Sono illustrazioni, e la misura lo dice
   (`card_check` nel report, carta base `assets/athletes/maestro.webp` 1086×1448 contro le
   anteprime 560×747 alla loro risoluzione): `circuit` 97.0% di pixel diversi a Δ>16 per
   canale (media 106.3/255), `legend` 96.0% (99.9/255), `signature` 9.6% (10.4/255).
   Cioè: le carte di circuit e legend sono **disegni diversi**, non ricolorazioni, mentre la
   carta di signature è quasi la carta della base; e gli sprite in campo di signature
   cambiano il 60.4% dei pixel della base. Riferimento di questo lavoro è lo sprite, come da
   istruzione: le divergenze carta/sprite sono misurate e registrate, non seguite.
2. **I sei valori non sono verificati sul modello.** Sono la lettura corretta dello sprite,
   non la prova che il rig li renda bene: nessun render 3D del Maestro esiste ancora
   (`evidence/renders/` contiene solo i render Fiamma). La maschera invece esiste, costruita
   in parallelo mentre scrivevo, e il suo report dice che **il test di famiglia non separa i
   due anchor** (§5): quella è la verifica che manca al rig, e va fatta prima di considerare
   la tabella §3 operativa. Un render a scala di partita è il passo successivo.
3. **Le due famiglie dello sprite non sono le due famiglie dell'atlante** (§5). L'atlante del
   Maestro ha una sola famiglia satura (mia misura: navy 40.7% dei texel saturi) più grigi
   non classificabili, e la corsia della maschera conferma con il proprio test che i due
   anchor stanno a 20° sotto una tolleranza di 45°. È un rischio strutturale per il modello a
   due famiglie: le sei slot possono ridursi a tre, e in quel caso conta la `a`.
   **La maschera è di un'altra corsia e si muove**: se viene rigenerata cambia lo sha256, e
   se gli anchor cambiano va rivista la mappa delle slot. Il mio strumento ricalcola l'hash
   a ogni esecuzione (`mask_lane_cross_check`) proprio per non citare un valore stantio.
4. **Il bianco dello sprite potrebbe non essere riccolorabile.** Nella fascia `foot` lo
   sprite ha suola/striscia bianca sul 24–26% dei pixel, ma nella regione omonima della
   maschera la classe `neutral` (texel che non colpiscono nessun anchor) è il 43.6%: il
   bianco c'è, i texel indirizzabili no. Le slot `hip_b`/`foot_b`, che portano i colori
   dichiarati sulle strisce, possono risultare inerti.
5. **Le fasce sono frazioni fisse dell'altezza.** Su `idle` e `action` cadono su maglia,
   pantaloncini e scarpe (verificato a vista, `mask-check-idle.png`, `mask-check-action.png`).
   Su `run` la falcata abbassa il bacino e la fascia `hip` finisce sulle cosce nude: i fogli
   `run`/`back-run` sono quindi esclusi da `hip` (`bands_sheet_policy` nel report) e le loro
   misure restano nel report come controprova. Su `run` la fascia `foot` resta invece
   corretta.
6. **Le misure su fogli a risoluzione diversa non sono esatte.** Il confronto base↔outfit
   richiede di riscalare la base (298 px/frame contro 179), e le zone a chiodi/righe del
   disegno (la faccia della racchetta, i bordi) producono differenze da ricampionamento. Per
   questo le percentuali di §7 sono un intervallo, non un valore: l'unico confronto esatto è
   fra sprite di outfit, che hanno la stessa risoluzione.
7. **Il taglio pari dei fogli a 4 frame include una striscia della figura adiacente.** Il
   taglio è a `larghezza/4` (298 px per la base, 179 per gli outfit), ma la figura propria
   finisce prima (per esempio `idle` base, frame 0: colonne 26–250) e le colonne residue
   contengono il bordo della figura successiva. Ne hanno 24 frame su 128, da 2 a 802 px di
   corpo, **3427 px in totale** (`sheet_bleed` nel report). Lo script misura solo la colonna
   della figura propria e scarta il resto, ma il runtime disegna anche quel filo di pixel: è
   un dettaglio preesistente del gioco, non introdotto qui, segnalato perché chi guarda uno
   sprite ingrandito lo vede.
8. **Dove ho dovuto scegliere, e come si torna indietro:**
   * `circuit.hip_a` è l'unico port. Reverto a `#1c325a` per fedeltà stretta allo sprite; il
     costo è il proxy pesato che scende da 63.3 a 52.4.
   * `legend` è tutta sullo sprite, quindi l'outfit legge **scuro** (oro antico, valore 0.35).
     Chi preferisse il colore della carta metta `#d5a62a` su `torso_b`, `hip_a`, `foot_b`:
     è una deviazione dallo sprite di ΔE76 54.
   * `legend.foot`: le due famiglie della scarpa sono instabili fra fogli (§4). Ho tenuto
     l'ordine del pool; se il modellatore preferisce, si scambiano `foot_a` e `foot_b`.
   * le famiglie `b` di `hip`/`foot` in base, circuit e signature sono il bianco condiviso
     della base: la regola 2 le sostituisce con il colore dichiarato dell'outfit. Per
     circuit il dichiarato `#9ef8ff` fa scendere `foot_b` da ΔE 50.3 (bianco contro ciano) a
     31.3; lasciando il bianco misurato il proxy sale appena a 64.0, a costo di un caso
     speciale nella policy.

## 10. File prodotti

| file | cosa è |
|---|---|
| `tools/character/measure_maestro_palette.py` | lo strumento; unica fonte di tutti i numeri di questo documento |
| `docs/agent-work/outfits-3d/MAESTRO-PALETTE.md` | questo documento |
| `evidence/maestro-palette/maestro-palette-report.json` | report macchina: palette misurate, modi, cluster, distanze, cambi di pixel, controllo griglia, inventario atlante |
| `evidence/maestro-palette/measured-slots.png` | strip delle modi misurate per regione × famiglia |
| `evidence/maestro-palette/proposed-slots.png` | strip dei valori proposti, con lettera di provenienza S/M/P |
| `evidence/maestro-palette/mask-check-{idle,action,run,back-idle,back-action,back-run}.png` | fasce ed esclusioni sopra lo sprite base: è il controllo a vista delle euristiche |
| `evidence/maestro-palette/probe-{idle-frame0-outfits,racket-mask,racket-zone,feet}.png` | sonde intermedie: le quattro varianti affiancate, la maschera racchetta, la zona racchetta, le scarpe |
| `evidence/maestro-mask-report.json` | **non mio**: report della corsia della maschera, citato in §5 e §8 per anchor, sha256 e verdetto del test di famiglia |

Nessun file di gioco è stato modificato: solo i tre percorsi dello scope (script, documento,
immagini di analisi). Nessun commit, nessun push, nessun asset rigenerato.
