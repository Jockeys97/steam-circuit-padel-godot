# Standard personaggi 3D — Steam Circuit Padel Pro

Stato: **CONGELATO 2026-09-16**. Vale per ogni atleta che entra in `godot/assets/athletes/`.
Chi genera un modello nuovo si adegua a questo documento; chi vuole cambiarlo lo cambia qui
prima, non nei file.

Si verifica da riga di comando, senza Godot installato:

```
python3 tools/character/validate_standard.py
python3 tools/character/validate_standard.py --inject-failure   # prova che il gate sa diventare rosso
```

Il registro macchina-leggibile è [`docs/art/roster-3d.json`](roster-3d.json): il validatore legge
quello, non questo testo. Questo documento spiega *perché*.

Lingua: italiano come il resto della pipeline d'arte (`tools/meshy/`, `tools/character/`). Il
codice di engine e i documenti di missione restano in inglese.

---

## 1. Nomi: l'unica autorità è l'id del roster

Gli id canonici sono i sei di `js/data.js` (`ATHLETES`), replicati in
`godot/assets/athletes/reference_catalogue.json`:

`maestro` · `pantera` · `steamer` · `fiamma` · `oracolo` · `colosso`

I nomi che escono dal generatore (`solar-titan`, `neon-court-champion`, `violet-arcane-sentinel`,
`Titan Dash`) sono nomi di lavorazione: **non entrano nei percorsi**. Si tiene traccia della loro
provenienza nel registro, campo `sorgente`, e basta.

Layout dei file, obbligatorio:

| Cosa | Dove |
|---|---|
| Asset di gioco | `godot/assets/athletes/<id>.glb` |
| Texture estratte dall'asset | le genera Godot: `<id>_<nome immagine glTF>.png` — **non si rinominano a mano** (vedi §5) |
| Sorgenti e intermedi della generazione | `art/generated/athletes/<id>/` e `tools/meshy/output/<id>/` |
| Provenienza e crediti spesi | `tools/meshy/state.json`, `tools/meshy/spese.json` |

Un GLB in `godot/assets/athletes/` il cui nome non è un id del roster è un errore, non una scelta.

## 2. Scheletro: mixamorig, 28 ossa

Lo scheletro standard è quello esportato dalla pipeline nuova: 28 giunti con prefisso
`mixamorig:`, radice `mixamorig:Hips`, personaggio in A-pose.

```
mixamorig:Hips
  mixamorig:Spine → Spine1 → Spine2
    mixamorig:Neck → Head → HeadTop_End          (+ headfront, osso tecnico senza prefisso)
    mixamorig:LeftShoulder  → LeftArm  → LeftForeArm  → LeftHand  → LeftHandMiddle4
    mixamorig:RightShoulder → RightArm → RightForeArm → RightHand → RightHandMiddle4
  mixamorig:LeftUpLeg  → LeftLeg  → LeftFoot  → LeftToeBase  → LeftToe_End
  mixamorig:RightUpLeg → RightLeg → RightFoot → RightToeBase → RightToe_End
```

**Perché questo e non altro.** I nomi `mixamorig:` sono riconosciuti dal BoneMap /
SkeletonProfileHumanoid di Godot 4: con questo scheletro si può retargettare qualunque clip
Mixamo o mocap (servizio, dritto, rovescio) senza rifare il rig. È la via più economica che
abbiamo verso animazioni di colpo vere, che oggi mancano.

Regole che ne discendono:

- **niente dita**: `*HandMiddle4` è l'unico osso oltre la mano, e serve solo come punto di
  attacco. La racchetta si aggancia a `mixamorig:RightHand` e **non** si modella dentro il mesh
  (regola già presente nella ricetta di `tools/meshy/generate_athlete.py`);
- l'altezza dichiarata alla fase di rigging è quella del personaggio, per atleta, registrata nel
  registro (`height_m`); la scala di import in Godot resta 1.0. Solo `pantera` (1,72) e `volpe`
  (1,80) sono confermate: le altre nel registro sono proposte da confermare **prima** della
  chiamata di rigging, perché `height_meters` fissa la scala e non si corregge senza rifare il rig;
- un solo skin, un solo mesh, una sola primitiva.

Chi produce 24 ossa (pipeline Meshy vecchia: `Hips/LeftUpLeg/.../headfront`, senza prefisso) è
fuori standard. Vedi §7.

## 3. Clip: tre di locomozione nel GLB, i colpi in engine

Il GLB porta esattamente tre clip, con i nomi che escono dal generatore:

| Nel GLB | Alias in engine | Note |
|---|---|---|
| `restpose` | `idle` | posa tenuta, non un vero idle respirato |
| `Walking` | `walk` | |
| `Running` | `run` | |

L'aliasing è già fatto da [`athlete_rig.gd`](../../godot/src/character/athlete_rig.gd): nessun
percorso di gioco deve usare i nomi grezzi. I colpi (`drive`, `slice`, `lob`, `serve`) restano
autorati in GDScript finché non arrivano clip retargettate: è un'impalcatura dichiarata, non una
scelta d'arte.

## 4. Geometria: un solo bersaglio per tutto il roster

| | |
|---|---|
| Bersaglio di remesh | **12.000 triangoli** |
| Banda accettata | **8.000 – 20.000** |
| Divario massimo fra due atleti approvati | **2,5×** |

**Numeri rivisti il 2026-09-16 dopo il primo render in engine** (`godot/prototypes/roster_review/`,
frame in `out/roster-review-match.png` e `-close.png`). La prima stesura di questo documento aveva
congelato 20.000 con banda 15.000–25.000 leggendo i file, senza aver mai guardato un personaggio in
campo. Guardandolo, due fatti ribaltano la scelta:

- alla camera di match (`CAMERAS.default` di `game/court.gd`: pos `(0, 14.46, 6.4)`, fov 50.9) la
  camera dista 15,8 m dal centro campo e inquadra 15,0 m di altezza: **un atleta di 1,55 m occupa
  93 px su un frame da 900**. A quella dimensione 8.928 e 45.406 triangoli sono indistinguibili;
- l'import ha `meshes/generate_lods=true`: alla distanza di match Godot disegna comunque un LOD
  basso. Il conteggio alto non si paga in pixel, si paga in **memoria e peso del repository**
  (Oracolo: 45.406 triangoli, 29,9 MB).

Il vincolo che lega davvero è l'inquadratura ravvicinata (schermata roster, selezione atleta): lì
Colosso a 8.928 triangoli regge, silhouette pulita e dettagli dell'armatura leggibili. Quindi la
banda **scende** invece di salire: Colosso è conforme com'è, Fiamma (37.327) e Oracolo (45.406)
vanno rimeshati — 5 crediti a testa, e i file dimagriscono.

## 5. Materiali e texture

Congelato adesso:

- **un solo materiale** per personaggio, baked;
- al massimo tre mappe: `baseColor`, `normal`, `metallicRoughness` (ORM);
- le PNG accanto al GLB **le produce l'import di Godot**, non una mano umana:
  `gltf/embedded_image_handling=1` (*Extract Textures*) le scrive come
  `<nome del GLB>_<nome dell'immagine glTF>.png`, cioè oggi `colosso_texture_0.png`,
  `colosso_texture_0_metallic_roughness.png`, `colosso_normal.png`.

**Corollario, imparato sbagliando il 2026-09-16**: rinominarle a mano non serve a niente — al
primo import Godot le riscrive col suo nome e restano due copie identiche dello stesso file (17 MB
buttati, verificati per md5 e rimossi). Se un nome di texture deve cambiare, si cambia il nome
dell'immagine **dentro il GLB**, a monte. La regola dell'id del roster vale sul `.glb`; i file
fratelli seguono l'engine.

Non congelato: risoluzione e peso. Oggi ogni atleta porta 22–24 MB di PNG non compressi. Il tetto
si fissa nel passaggio di budget, con i numeri misurati in engine, non a occhio.

## 6. UV: vincolo scoperto il 2026-09-16

Gli atlanti della pipeline nuova sono **frammentati in migliaia di isole minuscole** (misurato
sull'albedo di `fiamma` e `oracolo`). Conseguenza pratica: il sistema di ricolorazione delle
divise, costruito sulle due famiglie di texel dell'atlante di `volpe`
(`reference_catalogue.json`, `anchors`), **non si trasferisce** a questi modelli.

Finché non c'è una soluzione (maschere per capo, o vertex color per zona, o UV rifatte), gli
outfit valgono solo sul rig legacy. Va deciso prima di promuovere il secondo atleta, non dopo.

## 7. Eccezioni legacy, dichiarate

| Asset | Perché è fuori standard | Cosa se ne fa |
|---|---|---|
| `volpe-rigged/walking/running.glb` | 24 ossa Meshy, 31.325 tri | resta il fallback provato di `athlete_rig.gd`; si ritira quando i sei atleti sono a posto |
| `tools/meshy/output/pantera/pantera-riggato.glb` | 24 ossa, pipeline vecchia | da rigenerare su pipeline nuova (remesh + rig, 10 crediti); non promuovere così com'è |

Il validatore le riporta e non le fa fallire, perché sono registrate come `legacy`. Un asset
`approvato` che sfora, invece, fa diventare rosso il gate.

## 8. Stati del registro

### Variante outfit Maestro Mythic (2026-09-22)

Integrazione giocabile richiesta dall'utente, non promozione del modello base:
`godot/assets/athletes/outfits/maestro/mythic/`. Mantiene l'id `maestro` e usa
24 ossa Meshy legacy, 20.543 triangoli e texture 2K. È una variante **in prova**:
il lieve superamento della banda e il rig legacy restano dichiarati, non si
alza il budget globale. Le animazioni dei colpi sono retargettate appositamente;
non usa la maschera UV del Maestro base. Il registro degli atleti base resta
invariato. Provenienza: `docs/agent-work/meshy-outfit-trial/REPORT.md`.

| Stato | Significato | Il validatore |
|---|---|---|
| `approvato` | è l'asset di gioco di quell'atleta | **esige** lo standard |
| `in-prova` | importato e giocabile, standard non ancora rispettato | riporta gli scostamenti senza fallire |
| `generato` | il GLB esiste fuori da `godot/assets/`, non ancora importato | controlla scheletro e clip, riporta i triangoli, non fallisce |
| `legacy` | pipeline vecchia, tollerato a termine | riporta e basta |
| `assente` | nessun modello | nessun controllo |
