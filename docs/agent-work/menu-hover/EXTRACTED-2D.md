# FASE 1 — valori :hover / :focus estratti dal 2D

Riferimento: `styles.css` (unico foglio di stile: `index.html:17` — nessun `<style>` inline,
nessun `onmouseover`, nessun `style.*` impostato da JS al passaggio del cursore).
Le regole sotto sono l'elenco **completo** di ogni blocco che contiene `:hover`, `:focus`
o `.menu-focus` nel file (estratto con uno script che stampa ogni blocco, non a campione).

## 0. Token `:root` (`styles.css:1-13`)

| token | valore | riga |
|---|---|---|
| `--ink` | `#f6f7fb` | 3 |
| `--muted` | `rgba(255,255,255,0.48)` | 4 |
| `--panel` | `#111540` | 5 |
| `--line` | `rgba(255,255,255,0.12)` | 6 |
| `--cyan` | `#00e5ff` | 7 |
| `--gold` | `#ffcc00` | 8 |
| `--coral` | `#ff4b6e` | 9 |
| `--green` | `#1aff8a` | 10 |
| `--bg` | `#07072a` | 11 |
| `--shadow` | `0 24px 80px rgba(0,0,0,0.45)` | 12 |

`--pink` non esiste (vedi `padel_theme.tres` README §2): non c'e' niente da estrarre.

## 1. Card dei menu — base

`styles.css:323-333` — `.athlete-card, .mode-card, .arena-card`

```css
text-align: left;
border: 1px solid var(--line);        /* rgba(255,255,255,0.12) */
border-radius: 12px;
background: var(--panel);             /* #111540 */
color: var(--ink);
overflow: hidden;
transition: transform 0.15s ease, border-color 0.15s ease;
```

## 2. Card dei menu — `:hover`  ← il bersaglio del ticket

`styles.css:335-340`

```css
.athlete-card:hover,
.mode-card:not(.mode-card--locked):hover,
.arena-card:hover {
  transform: translateY(-3px);
  border-color: rgba(0, 229, 255, 0.35);
}
```

Valori esatti:

| proprietà | valore | riga |
|---|---|---|
| `transform` | `translateY(-3px)` | 338 |
| `border-color` | `rgba(0, 229, 255, 0.35)` | 339 |
| transizione | `transform 0.15s ease, border-color 0.15s ease` | 332 |

**NON esiste, nel 2D, sul `:hover` di una card:** nessun `box-shadow`, nessun `scale`,
nessun `filter`, nessun cambio di `background`, nessun cambio di `border-width`
(resta 1 px). Il bordo non diventa opaco: resta al 35 % di alpha.

Guardie sul blocco: `.mode-card` esclude le card bloccate (`:not(.mode-card--locked)`);
`.athlete-card` e `.arena-card` **non** hanno guardia — una card bloccata si solleva e
cambia bordo come le altre.

## 3. Card selezionata — il bordo ciano pieno + alone

`styles.css:342-345`

```css
.athlete-card--selected {
  border-color: var(--cyan);            /* #00e5ff */
  box-shadow: 0 0 0 1px var(--cyan);    /* anello ciano di 1 px */
}
```

E l'equivalente arena in programma, `styles.css:3126-3129`:

```css
.arena-card--in-programma {
  border-color: var(--cyan);
  box-shadow: 0 0 0 1px var(--cyan), 0 12px 40px rgba(0, 229, 255, 0.18);
}
```

Questo — bordo ciano pieno + anello da 1 px che si somma al bordo (≈2 px di bordo
luminoso) — è **lo stato "selezionata"**, non lo `:hover`. In `js/ui.js:881`
(`card.classList.add("athlete-card--selected")`) la card del compagno attualmente
schierato è `--selected`. Se nello screenshot la card sotto il cursore era anche quella
selezionata, i due stati si sommavano.

Cascata fra i due (rilevante): `.athlete-card:hover` ha specificità (0,2,0),
`.athlete-card--selected` (0,1,0). Sul `border-color` **vince lo `:hover`**: passando il
cursore su una card selezionata il bordo *scende* al 35 %, mentre il `box-shadow` ciano
resta (lo `:hover` non lo tocca).

## 4. Focus da pad/tastiera — `.menu-focus`

`styles.css:733-738`

```css
.menu-focus {
  outline: 3px solid var(--cyan);       /* #00e5ff */
  outline-offset: 3px;
  border-radius: inherit;
  animation: menu-focus-pulse 1.3s ease-in-out infinite;
}
@keyframes menu-focus-pulse {           /* :740-743 */
  0%, 100% { outline-color: var(--cyan); }   /* #00e5ff */
  50%      { outline-color: #a5ffe0; }
}
```

| proprietà | valore | riga |
|---|---|---|
| `outline-width` | `3px` | 734 |
| `outline-style` | `solid` | 734 |
| `outline-color` | `var(--cyan)` = `#00e5ff` | 734 |
| `outline-offset` | `3px` | 735 |
| `border-radius` | `inherit` (→ 12 px, quello della card) | 736 |
| animazione | `1.3s ease-in-out infinite`, colore 50 % = `#a5ffe0` | 737, 742 |

Con `body.reduce-motion` l'animazione e' spenta (`styles.css:2748-2758`) e resta
`outline-width: 3px`.

**Il focus da pad compare anche col mouse.** `js/main.js:2579-2588`:

```js
document.addEventListener("pointerover", (event) => {
  if (!gamepad.connected) return;
  ...
  const target = event.target.closest("button, input, .mode-card, .athlete-card, .arena-card");
  if (target && root.contains(target) && !target.disabled
      && !target.classList.contains("mode-card--locked")) {
    setMenuFocus(target);
  }
});
```

Cioe': **con un pad collegato**, passare il cursore su una card le assegna anche
`.menu-focus` — l'anello ciano di 3 px, 3 px fuori dalla card, pulsante. E' la somma
`:hover` + `.menu-focus` che produce l'effetto "bordo luminoso ciano che la circonda e
fa da alone" descritto dall'utente: `outline-offset: 3px` disegna *fuori* dalla card,
quindi si legge come alone, e `translateY(-3px)` la solleva.

Il bersaglio del focus non esiste per le card bloccate solo per `.mode-card--locked`
(`js/main.js:612`); `athlete-card--locked` e `arena-card--locked` non sono esclusi.

## 5. Stati attenuati (non `:hover`, ma parte della stessa card)

| regola | valore | riga |
|---|---|---|
| `.mode-card--locked` | `opacity: 0.55; cursor: not-allowed` | 503-506 |
| `.athlete-card--locked, .arena-card--locked` | `opacity: 0.5; cursor: not-allowed` | 1280-1283 |
| `…--locked .athlete-card__art, .arena-card__preview` | `filter: grayscale(0.8) brightness(0.7)` | 1286-1289 |
| `.arena-card--fuori-giornata` | `opacity: 0.4; filter: saturate(0.5); cursor: default` | 3131-3135 |
| `.team-slot--dettata:hover` | `transform: none` — la casella dettata **non si solleva** | 3114-3116 |
| `.team-slot:hover` | `transform: translateY(-2px)` (−2 px, non −3) | 3040-3042 |

## 6. Gli altri `:hover` dei menu (elenco completo, per riferimento)

| selettore | valori | righe |
|---|---|---|
| `.wardrobe-kit:hover:not(.is-locked)` | `background: rgba(18,49,93,0.98)` | 452 |
| `.hud-pause:hover` | `background: #1a4a79` | 714-716 |
| `.match-feed__toggle:hover` | `background: #17456f` | 1055-1057 |
| `.controls-guide__tutorial-link:hover/:focus-visible/.menu-focus` | `background: rgba(22,190,215,0.09); outline: 2px solid #16bed7; outline-offset: -2px` | 1708-1714 |
| `.controls-guide__tutorial-link:hover > b` | `transform: translateX(3px)` | 1716-1720 |
| `.icon-back:hover/:focus-visible/.menu-focus` | `background: #16bed7; color: #061426; outline: 2px solid #7ef3ff; outline-offset: 2px` | 1779-1786 |
| `.lang-toggle:hover` | `background: #123a68` | 2102-2104 |
| `.top-nav-btn:hover` | `background: #123a68` | 2124-2126 |
| `.segmented button:hover:not(.is-active)` | `background: rgba(0,229,255,0.1); color: #cfe9f7` | 2238-2241 |
| `.segmented button:focus-visible` | `outline: 2px solid var(--cyan); outline-offset: 2px` | 2243-2246 |
| `.btn--confirm:hover` | `background: #7a1a24 !important` | 2771-2773 |
| `.athlete-grid__head [data-team-confirm]:hover` | `transform: translateY(-2px); box-shadow: 0 15px 34px rgba(0,229,255,0.44), inset 0 1px 0 rgba(255,255,255,0.55)` | 2931-2934 |
| `.slot-action:hover/:focus-visible` | `background: rgba(20,60,120,0.85); border-color: rgba(160,230,255,0.75)` | 3064-3068 |
| `.slot-action--outfit:hover/:focus-visible` | `background: rgba(80,55,10,0.7); border-color: rgba(255,225,160,0.8)` | 3075-3079 |
| `.feedback__text/:focus-visible, .feedback__input:focus-visible` | `outline: 2px solid var(--cyan); outline-offset: 2px` | 3342-3346 |
| `.osk__key:hover` | `background: rgba(0,229,255,0.16)` | 3551-3553 |

**Non esiste alcuna regola `.btn:hover`** (pulsanti del menu principale): verificato riga
per riga. Il port lo registra gia' in `padel_theme.tres` README §5 ("the stylesheet
declares **no** `.btn:hover` / `.btn:active` rule"). Quindi: i bottoni del menu principale
NON hanno effetto di hover nel 2D. Non ne va inventato uno.

Differenze per famiglia di card: **nessuna** fra card personaggio, card arena e card
modalita' — il blocco `:hover` e' unico (`styles.css:335-340`) e le tre classi
condividono la stessa base (`:323-333`). L'unica differenza e' la guardia sulle modalita'
bloccate e le due eccezioni di §5 (`.team-slot--dettata:hover`, `.team-slot:hover` −2 px).
