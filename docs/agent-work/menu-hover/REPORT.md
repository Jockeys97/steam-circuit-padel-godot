# Hover e focus delle card dei menu — dal 2D al port Godot

Perimetro: gli effetti grafici che il 2D mostra quando il cursore passa su una card dei
menu. Nessun commit, nessun push. File di altre lane (colosso, oracolo, maestro, outfit)
non toccati.

- FASE 1 (estrazione dei valori dal 2D): `docs/agent-work/menu-hover/EXTRACTED-2D.md`.
- FASE 2 (traduzione in Godot): `godot/src/ui/components/CardFocusRing.gd` + il lift.
- Prove: `godot/tests/ui/menu_hover_audit.gd` (50 asserzioni), i log in
  `docs/agent-work/menu-hover/logs/`, e le catture qui sotto.

---

## 1. I valori estratti dal 2D, con file e riga

Fonte unica: `styles.css` (referenziato da `index.html:17`). Verificato che **non** esiste
hover impostato da JS: `mouseenter|mouseover|mouseleave|pointerenter` in `js/**` → zero
occorrenze; nessun `<style>` inline, nessun `onmouseover`, nessun `style.*` sul passaggio
del cursore. Tutto l'hover è CSS. Righe rilette una per una prima di scriverle qui.

### 1.1 Il blocco `:hover` delle card — `styles.css:335-340`

```css
.athlete-card:hover,
.mode-card:not(.mode-card--locked):hover,
.arena-card:hover {
  transform: translateY(-3px);              /* :338 */
  border-color: rgba(0, 229, 255, 0.35);    /* :339 */
}
```

Base condivisa, `styles.css:323-333`: `border: 1px solid var(--line)`, `border-radius:
12px`, `background: var(--panel)`, `overflow: hidden`, e la transizione
`transform 0.15s ease, border-color 0.15s ease` (`:332`).

| proprietà | valore esatto | riga |
|---|---|---|
| `transform` | `translateY(-3px)` | 338 |
| `border-color` | `rgba(0, 229, 255, 0.35)` | 339 |
| transizione | `0.15s ease` su entrambe | 332 |
| `border-width` | resta `1px` (non cambia) | 327 |

**Non esiste nel 2D, sullo `:hover` di una card**: nessun `box-shadow`, nessun `scale`,
nessun `filter`, nessun cambio di `background`, nessun cambio di spessore del bordo. Il
bordo **non** diventa opaco: resta al 35 % di alpha.

Token `:root` (`styles.css:1-13`): `--cyan: #00e5ff` (7), `--line:
rgba(255,255,255,0.12)` (6), `--panel: #111540` (5), `--bg: #07072a` (11).

### 1.2 L'anello di focus da pad — `styles.css:733-738`

```css
.menu-focus {
  outline: 3px solid var(--cyan);            /* :734  → #00e5ff */
  outline-offset: 3px;                       /* :735 */
  border-radius: inherit;                    /* :736  → 12px, quello della card */
  animation: menu-focus-pulse 1.3s ease-in-out infinite;   /* :737 */
}
@keyframes menu-focus-pulse {                /* :740-743 */
  0%, 100% { outline-color: var(--cyan); }   /* #00e5ff */
  50%      { outline-color: #a5ffe0; }
}
```

Con `body.reduce-motion` (`styles.css:2748-2758`) l'animazione è spenta e resta
`outline-width: 3px`.

**L'anello è la presentazione del PAD, non del puntatore**, ed è una regola separata
dall'hover. Con un pad collegato il 2D le somma: `js/main.js:2579-2588` assegna
`.menu-focus` alla card sotto il puntatore se `gamepad.connected`. È questa somma che
produce l'effetto descritto dall'utente — l'anello disegnato *fuori* dalla card si legge
come alone, e `translateY(-3px)` la solleva.

### 1.3 Le altre famiglie — differenze reali

| famiglia | `:hover` | riga |
|---|---|---|
| card personaggio / arena / modalità | **identico**: `-3px` + bordo 35 % | 335-340 |
| `.team-slot:hover` | **solo** `translateY(-2px)`, nessun bordo | 3040-3042 |
| `.team-slot--dettata:hover` | `transform: none` — non si solleva | 3114-3116 |
| `.mode-card--locked` | esclusa dall'hover (`:not(...)`) | 336 |
| `.athlete-card--locked`, `.arena-card--locked` | **non** esclusi: si sollevano come le altre | 1280-1283 |
| bottoni del menu principale | **nessuna regola `.btn:hover` esiste** | — |

Sulle card dei personaggi, delle arene e delle modalità il blocco è **uno solo**: nessuna
differenza di effetto fra le tre. Le due eccezioni sono le caselle della squadra (−2 px,
non −3) e la casella dettata (ferma).

`.btn:hover` **non esiste** (verificato riga per riga): i bottoni del menu principale non
hanno hover nel 2D, e non ne è stato inventato uno.

Altri `:hover` di menu censiti (`.segmented button:hover`, `.icon-back:hover`,
`.osk__key:hover`, `.slot-action:hover`, …) sono in `EXTRACTED-2D.md` §6 con i valori.

---

## 2. Cosa è stato portato in Godot, e perché

### 2.1 L'anello — `godot/src/ui/components/CardFocusRing.gd`

Un `Panel` figlio della card, ancorato al rect della card, con uno `StyleBoxFlat` che
disegna **solo il bordo** (`draw_center = false`) e nessun content margin.

| valore 2D | traduzione Godot | perché |
|---|---|---|
| `outline-width: 3px` (:734) | `border_width_all(3)` | la larghezza del bordo |
| `outline-offset: 3px` (:735) | `expand_margin_all(3 + 3)` | **vedi sotto** |
| `outline-color: var(--cyan)` (:734) | `Palette/colors/cyan` del tema | nessun esadecimale nel file |
| `border-radius: inherit` (:736) | `corner_radius_all(12)` | il raggio della card |
| `1.3s ease-in-out infinite` (:737) | tween `TRANS_SINE`/`EASE_IN_OUT`, `set_loops()`, 1.3 s | due metà da 0.65 s |
| keyframe 50 % `#a5ffe0` (:742) | `Palette/colors/focus_pulse` (nuovo token) | il colore viene dal tema |

**Il bug che la cattura ha trovato, e la correzione.** `expand_margin` *ingrandisce il
box* e il bordo viene poi disegnato **dentro** il box ingrandito: con il solo offset il
bordo finisce a filo della card, non 3 px fuori. La prima cattura lo mostrava — i pixel
davano l'anello a `x 643-645` con la card che iniziava a `646`, cioè **aderente**. Il box
va quindi ingrandito di `offset + width`, e il bordo cade nella banda 3..6 px fuori dalla
card, che è esattamente `outline-offset: 3px` su un `outline` di 3 px. Dopo la correzione
i pixel danno: anello `640-642` (`rgb(4,230,255)`), **gap di 3 px** `643-645`, card da
`646`. `CardFocusRing.offset_of(box)` espone il gap, e l'audit lo asserisce uguale a
`outline-offset`, così la geometria è verificata e non solo scritta.

**Perché un overlay figlio e non una variante del tema.** Una card è un `PanelContainer`
e le variazioni della famiglia `Panel` portano la cornice *della card*; `StyleBoxFlat`
porta al massimo un'ombra, quindi l'anello non può viaggiare sul box della card.

**Perché `expand_margin` e non `position`/`scale`.** `outline-offset` disegna fuori
dall'elemento senza spostarlo e senza cambiare lo spazio che occupa. `expand_margin` è
l'unico meccanismo Godot con la stessa proprietà, ed è **misurato layout-free**:
`get_minimum_size()` torna i soli content margin (18.0 con `expand_margin = 3`) e una card
che indossa il pannello tiene la sua taglia — `godot/tests/ui/menu_hover_probe.gd`.
`position` e `scale` sono rifiutati per un motivo dell'engine: un `Container` li
sovrascrive a ogni re-sort (`Container::fit_child_in_rect` scrive il rect e azzera
rotation e scale) — vincolo provato empiricamente dalla stessa probe.

### 2.2 Il sollevamento — `translateY(-3px)` / `-2px`

`CharactersScreen._lift_to` / `ArenaScreen` muovono `position.y` con un tween di
**0.15 s** (`LIFT_SECONDS`), che è il clock del 2D (`styles.css:332`), e per la distanza
giusta per famiglia: `CARD_LIFT = 3.0` per le card, `SLOT_LIFT = 2.0` per le caselle
della squadra (`styles.css:3040-3042`). Il lift passa da `position.y` e non da `scale`,
così lo spazio occupato non cambia e il layout non salta. Poiché il `Container` azzera la
`position` al re-sort, il riposo viene ri-letto (`_rest_y_of`) e il lift riapplicato.

**Verificato nei pixel**: nella cattura `characters-hover.png` la card sotto il puntatore
ha il rect a `y = 208.0` mentre le card non evidenziate stanno a `y = 211.0` — **3 px**,
esatti.

### 2.3 La cornice di hover

Il bordo `rgba(0,229,255,0.35)` era già nel tema (`PanelCardHover` della lane UI, che ha
già il precedente citato da `ControlLegend.gd`). Non è stato duplicato. Il mio contributo
sul lato hover è il **lift** e la **convivenza** con l'anello.

**Verificato nei pixel** in `characters-hover.png`:

| card | pixel del bordo sinistro a `y=640` | valore 2D atteso |
|---|---|---|
| Pantera (sotto il puntatore) | `rgb(4, 85, 116)` | `rgba(0,229,255,0.35)` su `--bg` → `(4.55, 84.7, 116.5)` ✔ |
| Steamer (non evidenziata) | `rgb(36, 36, 67)` | `rgba(255,255,255,0.12)` su `--bg` → `(38.5, 38.5, 67.6)` ✔ |

### 2.4 Hover e focus restano **distinti** (scelta motivata)

Il 2D ha due regole separate: `:hover` (`:335-340`) e `.menu-focus` (`:733-738`). Il port
le tiene separate:

- **mouse** → bordo ciano al 35 % + lift di 3 px. **Nessun anello.**
- **pad** → anello ciano pieno di 3 px, 3 px fuori dalla card, pulsante.
- **entrambi** → le due si sommano, come nel 2D con un pad collegato.

Motivo: il proprietario gioca **col gamepad**. Se hover e focus avessero lo stesso
aspetto, la selezione da pad diventerebbe indistinguibile da un cursore fermo su una
card, e con un pad in mano non si saprebbe più dove si sta per premere. Tenerli distinti
è anche ciò che fa il riferimento, e il focus ring ciano `#16bed7` da 2 px già esistente
per la navigazione col pad resta intatto: non è stato sostituito né duplicato — l'anello
nuovo è una presentazione **diversa** (`#00e5ff`, 3 px, fuori dalla card) che vive sulle
card, mentre quello esistente vive sui bottoni (`Button/styles/focus`). L'audit asserisce
che il tema non porta nessun `Panel/styles/focus`, così le due non possono collidere.

### 2.5 Colori dal tema, mai costanti sparse

Il componente legge `cyan` e `focus_pulse` da `Palette` con `Control.get_theme_color`
(la stessa catena da cui la card prende le sue cornici). Una chiave mancante è
**registrata** (`misses_of`) e risposta con `ink`, poi bianco — il contratto di
`ControlLegend.gd` e `Hud.gd`. L'audit asserisce `misses_of` **vuoto**, quindi se un
token sparisce dal tema il test cade invece di degradare in silenzio. Il file non
contiene nessun letterale di colore.

### 2.6 Rispetto delle preferenze del giocatore

`body.reduce-motion` spegne le keyframes nel 2D (`styles.css:2748-2758`) lasciando
l'anello a piena larghezza. In Godot il gate è `UiMotionPolicy`, l'unica porta del port
per "questa animazione può girare", idratata dalle stesse preferenze salvate che legge
`SettingsScreen`. Senza policy l'anello è disegnato **statico** — cioè il frame
reduce-motion del riferimento.

---

## 3. Cosa NON è riproducibile, e con quale approssimazione

| valore 2D | riga | stato in Godot |
|---|---|---|
| `transition: border-color 0.15s ease` | 332 | **Non riprodotto.** Il bordo della card è un `StyleBoxFlat` di tema, scambiato istantaneamente: Godot non interpola un cambio di stylebox. Il 2D sfuma il bordo da `rgba(255,255,255,0.12)` a `rgba(0,229,255,0.35)` in 0.15 s; qui il cambio è netto. Il **lift** invece è interpolato a 0.15 s, quindi il movimento è fedele e solo il colore del bordo scatta. Riprodurlo richiederebbe un `StyleBoxFlat` duplicato per card e un tween su `border_color`, cioè riscrivere la logica delle cornici della lane UI: fuori perimetro, e il guadagno visivo è di 9 frame. |
| espansione del raggio dell'outline per effetto dell'offset | 735-736 | **Non riprodotto.** `border-radius: inherit` è reso letteralmente con 12 px. Se Chrome espande il raggio di un outline offset di 12+3, la differenza è di 3 px sull'arco degli angoli. Non è stato verificabile (browser non disponibile) e non è stato inventato. |
| `filter: grayscale(0.8) brightness(0.7)` sulle card bloccate | 1286-1289 | **Fuori perimetro** (stato bloccato, non hover) e non introdotto qui. |
| `cursor: not-allowed` / `cursor: default` | 506, 1283, 3135 | Nessun equivalente diretto: Godot non ha un cursore "not-allowed" di default. Non toccato. |
| `box-shadow: 0 0 0 1px var(--cyan)` (spread puro, senza blur) | 344, 3127 | Sullo stato **selezionato**, non sull'hover. Già reso dalla lane UI con un bordo. Non toccato. |

---

## 4. Esiti dei test

**Comando gate (l'unico usato per giudicare):**

```
/Applications/Godot.app/Contents/MacOS/Godot --path godot --headless --script res://tests/ui/<f>.gd
```

Log per audit in `docs/agent-work/menu-hover/logs/gate-<f>.log`; tabella consolidata
generata da quei log in **`docs/agent-work/menu-hover/logs/GATE.md`**. Passata **seriale**,
un audit alla volta: due passate in parallelo sugli stessi file di log si sovrascrivono a
vicenda e producono letture sbagliate (è successo in questa sessione, vedi sotto).

### 4.1 Verdetto di ogni audit

| audit | verdetto esplicito |
|---|---|
| `theme_probe` (tema modificato) | **PASS 305/305** |
| `menu_hover_audit` (nuovo) | **PASS 50/50** |
| `menu_hover_probe` (le due misure engine) | **PASS 5/5** |
| `screen_characters_audit` | **PASS 183/183** |
| `screen_arena_audit` | **PASS 180/180** |
| `screen_modes_audit` | **PASS 119/119** |
| `screen_menu_audit` | **PASS 97/97** |
| `ui_legibility_audit` | **PASS 676/676** |
| `input_a11y_audit` | **PASS 159/159** |
| `router_audit` | **PASS 86/86** |
| `uir_route_audit` | **PASS 51/51** |
| `uir22_integration_audit` | **PASS 75/75** |
| `hud_audit` | PASS 172/172 |
| `result_coach_audit` | PASS 120/120 |
| `screen_drill_audit` | PASS 120/120 |
| `screen_feedback_audit` | PASS 119/119 |
| `screen_challenges_audit` | PASS 73/73 |
| `screen_help_audit` | PASS 91/91 |
| `screen_settings_audit` | PASS 91/91 |
| `screen_profile_audit` | PASS 74/74 |
| `screen_history_audit` | PASS 56/56 |
| `screen_result_audit` | PASS 176/176 |
| `ui_visibility_audit` | PASS 146/146 |
| `clean_mode_audit` | PASS 64/64 |
| `arena_selector_contract_test` | PASS 30/30 |
| `demo_matrix_audit` | PASS 133/133 |
| `controller_cards_test` | PASS (formato proprio) |
| `menu_pad_single_dispatch_test` | PASS (5/5, formato proprio) |
| `controller_identity_audit` | `CONTROLLER_IDENTITY PASS` |
| `data_audit` | **FAIL 130/131** — altra lane, §4.2 |

**30/30 audit hanno stampato il proprio verdetto.** Nessun verde qui si appoggia al solo
exit code. I due verdetti in "formato proprio" (`controller_cards_test`,
`menu_pad_single_dispatch_test`) sono righe `PASS <etichetta>` senza conteggio: sono
verificati leggendo le singole righe, non l'exit code.

**`data_audit` è l'unico fallimento, ed è di un'altra lane** — §4.2.

### 4.1-bis La forma `--quit-after` NON è un gate — non usarla per giudicare

Un giro precedente di questa sessione aveva lanciato le stesse audit come *scena*
(`--headless --quit-after 3000 res://tests/ui/<f>.tscn`, che per molte esiste ma serve alle
catture con finestra). Quella forma produce due tipi di falso verde, entrambi con
`exit=0`:

- **verdetto vuoto**: il timer chiude il processo prima che l'audit stampi il verdetto
  (è successo a `screen_challenges`, `screen_drill`, `screen_feedback`, `screen_result`,
  `screen_settings`, `demo_matrix`);
- **`PASS 8/8` al posto di `120/120`**: la `.tscn` non è l'audit, e Godot esegue la main
  scene del progetto — otto controlli sulla **versione dell'engine** (`SmokeTest`). È
  successo a `hud_audit`, `result_coach_audit`, `ui_visibility_audit`, e ad altri.

`exit=0` **con verdetto vuoto non è un test passato**: è un processo terminato dal timer.
Un audit conta come passato solo se stampa il proprio verdetto con il conteggio atteso; se
il verdetto manca, va dichiarato **non verificato**, mai verde. `demo_matrix_audit` sembrava
non eseguibile per questo motivo: con `--script` dà `PASS 133/133`.

### 4.2 L'unico fallimento, e perché non è mio

| audit | verdetto | attribuzione |
|---|---|---|
| `data_audit` | **FAIL 130/131** | **altra lane.** `data/one_drill_row_per_frozen_exercise`: expected 4, got 5 — un esercizio è stato aggiunto alle tabelle congelate. Non referenzia nessun mio file (`grep -c "CharactersScreen\|ArenaScreen\|padel_theme\|CardFocusRing"` → **0**). |

**Prova diretta**: rimuovendo temporaneamente l'unica mia modifica globale (il token
`focus_pulse` dal tema) `data_audit` fallisce **identicamente** (`130/131`) — quindi non è
il mio cambiamento a causarlo. Il tema è stato poi ripristinato byte-identico (`diff` →
nessuna differenza).

**`input_a11y_audit` era rosso a metà lavoro (`FAIL 155/157`) ed è ora verde
(`PASS 159/159`).** Era l'altra lane, che stava scrivendo in `game/main_menu.gd` il
possesso della tastiera da parte del campo di testo — lo stesso file che a metà sessione
aveva un errore di parse (`_text_entry_owns_the_keyboard() not found`). Non è una mia
correzione: la lane ha finito il suo lavoro. Lo registro perché una versione precedente di
questo report lo dava per fallito, e la fotografia era già vecchia.

**Lezione sulle passate concorrenti.** Due giri di audit lanciati in parallelo sugli stessi
file di log si sovrascrivono: in questa sessione il giro `--quit-after` ha riscritto i log
del giro `--script` mentre giravano, e la lettura consolidata ha mostrato `PASS 8/8` (la
SmokeTest) al posto di `146/146` su `ui_visibility_audit`, e verdetto vuoto su altri tre che
in realtà erano verdi. Da qui la regola: **una passata seriale, un audit alla volta, e si
giudica solo il verdetto stampato dall'audit.** La tabella di §4.1 è quella passata lì.

### 4.3 Il test nuovo

`godot/tests/ui/menu_hover_audit.gd` — **PASS 50/50**. Copre, su Personaggi e Arena:

- ogni card porta un `CardFocusRing`, e l'anello è **nascosto** finché non c'è focus;
- `misses_of` **vuoto** → i colori vengono davvero dalla `Palette`;
- il box dell'anello: 3 px di bordo, box ingrandito di `offset + width`, **gap == `outline-offset`**, raggio 12, `draw_center` false;
- **nessun reflow**: la taglia della card è identica con l'anello nascosto e mostrato;
- **hover ≠ focus**: dopo un hover il bordo è quello del tema al 35 % e l'anello resta **nascosto**; dopo il focus da pad (via il vero `UiFocusBridge`, e il mount che lo dipinge come in partita) l'anello è **visibile su quella card e su nessun'altra**;
- hover e focus insieme → entrambi presenti;
- il tema **non** porta un `Panel/styles/focus` → nessuna collisione con il focus ring `#16bed7` esistente dei bottoni;
- l'Arena: anello sulle card, focus da pad che lo accende, hover che **non** lo accende.

### 4.4 La prova visiva

`godot/tests/ui/menu_hover_capture.tscn` (finestra vera, **senza** `--headless`,
`--rendering-driver opengl3 --resolution 1280x720`). Questa è l'unica prova che **non** può
essere headless — serve una finestra per disegnare un frame — e ha un suo contratto: verdetto
**PASS 9/9**, con ogni stato asserito *prima* di catturare. L'hover è prodotto da un
`InputEventMouseMotion` **immesso nel viewport** (`push_input`), cioè dal percorso di
input reale, non da una chiamata diretta: il log lo registra
(`hover driven by a pushed mouse motion=true, border_alpha=0.35, ring=false`). Il focus
da pad è un `focus_entered` reale.

| file | cosa mostra |
|---|---|
| `characters-hover.png` | una card sotto il puntatore: bordo ciano al 35 % + **3 px di sollevamento**; nessun anello |
| `characters-pad-focus.png` | una card con l'**anello ciano di 3 px a 3 px di distanza** (gap verificato nei pixel), le altre col bordo sottile |
| `characters-hover-and-focus.png` | le due cose **sommate** sulla stessa card — lo stato del riferimento con un pad collegato |
| `team-hover.png` | una casella della squadra sollevata di **2 px** e **senza** bordo, come `.team-slot:hover` |

Le catture non sono a schermo vuoto: ognuna è 1280x720 con 129-140 colori distinti
campionati, e ogni stato è **asserito prima** di catturare (se lo stato non c'è, il log lo
dice invece di salvare un PNG che finge). I valori sono stati poi riletti dai pixel:

- anello: `x 640-642` = `rgb(4,230,255)`, gap `643-645`, card da `646`;
- lift: card sotto il puntatore `y=208.0` contro `y=211.0` delle altre;
- bordo hover `rgb(4,85,116)` e bordo a riposo `rgb(36,36,67)`, entrambi combacianti col
  composito atteso dei valori CSS.

---

## 5. Navigazione da gamepad

Non rotta. Il focus da pad passa dallo stesso `UiFocusBridge` di prima; l'anello è un
`Panel` figlio con `mouse_filter = MOUSE_FILTER_IGNORE`, quindi non intercetta né il
mouse né il focus e non può rubare la selezione. Il focus ring `#16bed7` da 2 px dei
bottoni è intatto. `menu_pad_single_dispatch_test`, `controller_cards_test`,
`controller_identity_audit`, `router_audit` e gli audit di tutte le schermate passano; il
test nuovo verifica esplicitamente che il pad accende l'anello su **una sola** card.
