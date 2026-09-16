*[**Italiano**](README.md) · [English](README.en.md)*

# Steam Circuit Padel Pro

[![audit](https://github.com/Jockeys97/steam-circuit-padel-pro/actions/workflows/audit.yml/badge.svg)](https://github.com/Jockeys97/steam-circuit-padel-pro/actions/workflows/audit.yml)

Padel arcade steampunk in HTML5 Canvas. Giocabile nel browser, senza installazione.

**Zero dipendenze**: niente `package.json`, niente npm, niente bundler. 8.500 righe di
JavaScript puro su Canvas 2D, con una proiezione prospettica scritta a mano. L'audio è
sintetizzato a runtime con `AudioContext` — nel progetto non esiste un solo file audio.

---

## Perché questo README parla di decisioni

L'elenco delle funzionalità dice poco su un gioco. Quello che segue è invece il
ragionamento dietro alcune scelte di bilanciamento: cosa non funzionava, **come l'ho
misurato**, e cosa ho cambiato. Ogni numero qui sotto viene da uno script eseguibile,
non da una sensazione.

### 1. Il colpo tagliato dominava quello piatto

Sospettavo uno sbilanciamento e l'ho misurato dal fondo campo:

| carica | colpo | velocità | profondità | 2° arco | energia |
|---|---|---|---|---|---|
| 0.5 | drive | 380 | 136 | **41** | 0.085 |
| 0.5 | slice | **393** | **144** | **22** | **0.075** |

Il taglio era più veloce, più profondo, costava meno energia **e** consegnava un
rimbalzo alto la metà. Non c'era una sola situazione in cui premere il drive fosse
giusto: un pulsante morto.

Provando a correggerlo ho scoperto un vincolo del motore che non conoscevo:
`setComputerTrajectory` risolve la velocità per atterrare sul bersaglio nel tempo dato,
quindi **l'apice dipende solo dal tempo di volo**. Rallentare il taglio per fargli
"pagare del tempo" lo trasformava in un mezzo pallonetto (apice da 94 a 140).

Ho dovuto cambiare la moneta di scambio: il taglio non compra tempo, compra un rimbalzo
schiacciato rinunciando a profondità e spinta. Il piatto resta il colpo di pressione.

### 2. Il giocatore non poteva sbagliare

Ho fatto volare la palla con la stessa fisica del gioco per contare gli esiti reali.
Accumulando tutto il peggio possibile — timing pessimo, corsa, sprint, palla lontana,
energia al minimo, palla già superata:

| situazione | qualità | esiti su 80 |
|---|---|---|
| fermo, timing pessimo | 0.72 | 80 in campo |
| + in corsa | 0.67 | 80 in campo |
| + energia scarica | 0.56 | 80 in campo |
| + palla superata | 0.51 | 80 in campo |

**480 colpi, zero errori.** La causa era strutturale, non di taratura: il bersaglio è
clampato dentro il campo e il solutore ci atterra sempre. Inoltre la penalità che
avrebbe dovuto accorciare la palla si attivava sotto qualità 0.68, mentre il pavimento
raggiungibile dal solo timing era 0.72 — quel ramo di codice non veniva mai eseguito.

### 3. Gli effetti a soglia non si tarano

Il primo modello d'errore usava perturbazioni continue: dispersione laterale, arco più
piatto. Misurandolo si è rivelato un interruttore, non una curva — o non succedeva
niente, o falliva tutto.

Stessa cosa più avanti sullo smash "x2", il cui esito dipendeva da una corsa di
intercettazione:

| velocità di ritorno | Rivale | Ingegnere | Campione |
|---|---|---|---|
| 430 | 18.3% | 16.3% | 11.3% |
| 520 | **100%** | 28.7% | 18.8% |

Novanta punti di velocità ribaltavano il livello facile dal 18% al 100%.

La lezione, applicata due volte: dove l'esito dipende dal superamento di una soglia
geometrica, **una decisione discreta presa una volta sola** è tarabile, una
perturbazione continua no. Sia gli errori del giocatore sia la lettura dello x2 usano
ora quella forma — che è anche quella prescritta dal documento di design.

### 4. L'IA non sapeva cosa fosse una palla attaccabile

Su un pallonetto molle e alto a rete, 2000 prove per livello, il Campione:

- smashava nel **20%** dei casi
- **pallonettava a sua volta nel 22%**, stando a rete su una palla che gli sedeva davanti
- ed era praticamente identico al livello facile: sei punti di scarto

La scelta del colpo guardava solo la propria posizione, l'altezza di contatto e un dado.
Peggio: `hitBall` schiacciava `ball.z` a 74 **prima** della decisione, quindi una palla
a 88 e una a 105 erano per l'IA lo stesso oggetto.

Ho aggiunto un punteggio di attaccabilità (altezza reale del contatto, lentezza della
palla, quanto avanti la si prende) e l'ho agganciato alla scelta:

| | prima | dopo |
|---|---|---|
| Rivale | 14.3% | **58.7%** |
| Campione | 20.2% | **76.1%** |

Il lob dalla rete su palla alta è vietato. La forbice fra i livelli è passata da 6 a 17
punti.

### 5. Una statistica che non faceva niente

`stats.stamina` compariva in **un solo punto** dell'intero motore: la ricarica
dell'abilità speciale. Non toccava l'energia dello scambio, che invece governa qualità
del colpo, finestra di timing e tasso d'errore.

Il personaggio descritto come *"inossidabile, recupera ogni punto"* aveva quindi come
unico vantaggio una speciale più rapida. Collegata l'energia alla stamina, la differenza
in uno scambio lungo è diventata reale: 2.89 errori contro 3.30 della più fragile.

### 6. Il servizio non poteva fallire

400 prove per ogni livello di carica: **100% validi**, sempre. Seconda palla, doppio
fallo e `serveAttempts` erano percorsi di codice irraggiungibili, malgrado il documento
di design dedichi loro un capitolo.

Aggiunta una dispersione d'esecuzione che cresce con la carica e cala con il controllo
dell'atleta. Ora un servizio a mezza forza resta sicuro per tutti, mentre a carica piena
il Maestro (controllo 1.28) fallisce il 16.5% e non arriva mai al doppio fallo, lo
Steamer (0.90) fallisce il 36% e doppia l'8.6%.

### 7. La carriera premiava chi perdeva di proposito

Gli obiettivi di stagione si chiamavano così, e i target scritti a mano lo davano per
scontato — `winPoints` chiedeva 26 punti — ma la verifica leggeva i dati di **una sola
partita da 11**. Tre stagioni su sei del ciclo avevano quindi una stella
matematicamente irraggiungibile:

| stagione | obiettivo morto | tetto reale |
|---|---|---|
| 3, 4, 5 | winPoints 26 / 28 / 30 | 11 |
| 6, 7, 8 | winners 12 / 13 / 14 | 11 |

Il tetto non è una stima: ogni punto passa da `scorePoint` con una categoria, e le due
sono esclusive, quindi `winners[p] + errors[avversario] = pointsWon[p] ≤ 11`.

Peggio della stella impossibile c'era la sua faccia opposta. Perdendo due partite su
tre si ripete la stagione, e la ripetizione rigenerava gli obiettivi con `done: false`:
le stesse tre stelle si riprendevano a ogni ciclo. Misurato su dieci cicli in stagione
1 — l'avversario più facile — **60 stelle, zero trofei**, abbastanza per tutto ciò che
le stelle sbloccano. La strategia ottimale era perdere.

Ora i target si derivano dal tetto raggiungibile, gli obiettivi di stagione si misurano
sul totale della stagione, e una stella si riscuote una volta sola. Ripetere paga solo i
bonus di partita: 33 stelle contro le 60 di chi avanza.

### 8. Due tabelle in disaccordo su cosa fosse un errore

Assestando gli obiettivi cumulativi sono nate due fonti per la stessa regola:
`SEASON_METRIC_AGG` diceva che gli errori si tengono al **match peggiore**, un campo
`agg` sugli obiettivi diceva che si **sommano**. Il gioco leggeva la prima, la seconda
restava lì a sembrare autorevole. E siccome l'audit calcolava i tetti assumendo la
somma, `fewErrors: max 18` sembrava tarato (18 < 33) mentre era impossibile da fallire:
in una partita non si possono fare più di 11 errori.

Il campo duplicato è stato eliminato, e l'audit ora chiede il tetto alla regola vera —
con un'asserzione che impedisce di reintrodurre la seconda tabella. La lezione è la
stessa del generatore pseudocasuale: quando un valore non cambia l'esito, il primo
sospettato è lo strumento.

### 9. L'allenamento insegnava una fisica che non esisteva

`drill.js` era un secondo motore: gravita' propria, misuratore proprio, un
"perfetto" fissato a `0.62`. Nessuna finestra di timing, nessuna qualita' del
colpo, nessuna energia dello scambio, nessuna statistica dell'atleta, nessun
vetro. Non allenava male: allenava **un altro gioco**. Ed e' il difetto peggiore
di tutti, perche' non si manifesta come un errore — si manifesta come un
giocatore che si allena e non migliora.

Ora l'allenamento *e'* una partita: `createMatchState` costruisce lo stato vero e
`updateMatch` lo fa avanzare. Il file si limita a due cose che il match non fa,
mandare la palla e dare un punteggio, e ogni meccanica arriva gratis — comprese
quelle che verranno ritarate domani. La palla non viene nemmeno costruita a mano:
la manda `hitBall` con `forceContact`, quindi quello che arriva e' un colpo vero,
con la sua dispersione e la fisica dell'arena scelta.

Il motore non e' stato toccato. Gli avversari, dove servono immobili, si fermano
alzando il loro `hitCooldown`: `hitBall` rifiuta il colpo quando e' positivo.
Nessuna modalita' speciale da mantenere dentro `game.js`.

Tre esercizi, uno per meccanica che prima non era allenabile: bersagli che
chiedono il taglio o il piatto, pallonetti da chiudere con lo x2/x3, e uno
scambio pieno dove l'energia governa timing e qualita'.

### 10. Il campo era un menu

Con l'allenamento in corso, la barra spaziatrice premeva il bottone col fuoco e
le frecce spostavano il fuoco del menu. La causa stava in una riga:

```js
const menuActive = !matchState?.running || matchState?.paused;
```

L'allenamento non usa `matchState`, quindi la condizione era vera per tutto
l'esercizio, e il ramo dei menu intercettava i tasti con un `return` prima di
`keys.add(key)`. Al campo non arrivava un solo comando: il vecchio allenamento
rispondeva solo perche' leggeva lo spazio dal `keyup`, che non era intercettato.

Non si vede leggendo il codice del drill, e nessun audit lo prende: l'ho trovato
fotografando la schermata e chiedendomi perche' tornasse al menu.

### 11. Il tiro al bersaglio premiava il tasto, non il colpo

La coerenza del colpo si giudicava da `backspin > 0.5`, cioe' da un flag
dell'input: diceva soltanto *"hai premuto X"*. Ma il taglio, secondo il documento
di design, compra **un rimbalzo schiacciato** — e quello e' un esito, non un
comando. Un taglio mal eseguito passava identico a uno riuscito.

Misurare l'esito ha richiesto due tentativi. Il primo, l'apice del secondo
rimbalzo, ha dato **129 in tutti e sei i casi** su 40 semi ciascuno: costante
sospetta, e infatti lo strumento era rotto. Tracciando la quota si e' visto
perche':

```
rimbalzo 1 a y=120 vz=-249
  z=-2 y=120     ← la palla non si muove piu'
  z=-2 y=120
```

Dopo il primo rimbalzo il punto e' gia' assegnato, e durante `pointPause` la
fisica non avanza: **il secondo rimbalzo non e' osservabile** dall'allenamento.

Il numero giusto era un passo prima — la velocita' verticale all'impatto, da cui
il motore ricava l'altezza del rimbalzo. Misurata su 30 prove per livello di
carica:

| colpo | |vz| all'impatto |
|---|---|
| piatto | 227 – 259 |
| taglio | 181 – 221 |

Non si sovrappongono, ma il divario e' di **6 unita'**: una soglia secca li' in
mezzo sarebbe l'interruttore che la sezione 3 dice di non usare. Il punteggio e'
quindi continuo fra i due riferimenti, e un taglio a meta' prende un voto a meta'.

Va letta *prima* del passo di simulazione: dopo l'impatto il motore ha gia'
riflesso e attenuato `vz`, quindi letta dopo non direbbe piu' con quanta forza la
palla e' arrivata a terra.

### 12. Valutare senza diagnosticare insegna a meta'

L'allenamento dava voto e punti e taceva sul motivo. Ora ogni tentativo chiude con
una diagnosi — troppo corta, troppo profonda, larga, dentro ma con un rimbalzo
troppo alto, smash difeso, arrivato a energia scarica — e l'audit verifica due
cose: che **nessun tentativo si chiuda senza diagnosi**, e che ogni chiave esista
in entrambe le lingue. `t()` restituisce la chiave grezza quando manca la
traduzione, quindi un buco finirebbe a schermo come `drillWhyWide`.

Con la stessa passata: il record ora sopravvive alla sessione, in
`localStorage` e **per esercizio** (i punteggi di un tiro al bersaglio e di uno
scambio non sono confrontabili); la difficolta' si scoglie sulla schermata invece
di essere ereditata in silenzio da quella della partita rapida; e c'e' l'esercizio
del **servizio**, che usa `prepareServe` del motore e mostra i doppi falli —
il percorso che prima della dispersione d'esecuzione era irraggiungibile.

La persistenza vive in `ui.js` e non in `drill.js`: quel file deve restare
eseguibile senza DOM, perche' l'audit lo importa in Node dove `localStorage` non
esiste.

### 13. Un modulo di feedback che perde e' peggio di nessun modulo

Il menu ha ora un pulsante per il feedback dei giocatori, in vista della
pubblicazione. La parte difficile non era il modulo: era decidere **cosa** gli si
allega e **cosa** succede quando l'invio non riesce.

Il testo libero da solo non si usa. "Lo smash x2 e' troppo forte" non dice con
quale atleta, in quale arena, a quale difficolta' e — soprattutto — con quale
taratura in vigore. Per questo `VERSION.balance` accompagna ogni messaggio: senza,
un reclamo arrivato oggi diventa indistinguibile da uno arrivato dopo la prossima
ritaratura, e non si sa piu' a quale gioco si riferisse. Il resto del contesto il
gioco lo ha gia' in `localStorage`: impostazioni, stato di carriera, record
d'allenamento, le ultime tre partite.

Il contesto e' **mostrato e rifiutabile**: il modulo lo stampa per intero prima
dell'invio. Allegare dati senza farli vedere non e' accettabile, e su Steam
richiederebbe un'informativa a parte.

La coda locale si scrive **prima** di qualunque tentativo di rete, perche' su Steam
si gioca offline e una POST fallita perderebbe il messaggio senza che nessuno se
ne accorga. `endpoint` e' volutamente `null`: finche' resta cosi' il feedback si
raccoglie e si copia negli appunti, senza alcun server da mantenere. Il giorno che
un endpoint esistera', si riempie quel campo e il resto non cambia.

Scriverlo ha prodotto due difetti, entrambi trovati da una prova e non da una
rilettura:

**Il ramo di invio era irraggiungibile.** `flushFeedback` controllava l'endpoint
per primo, quindi con `endpoint: null` i casi "rifiutato" e "offline" non si
potevano eseguire: si sarebbe scoperto se funzionano il giorno della messa in
produzione. E' lo stesso difetto del servizio che non poteva fallire. Ora endpoint
e `fetch` sono parametri, e l'audit li esercita davvero — compreso il caso in cui
un secondo invio non deve nemmeno toccare la rete.

**La schermata nuova dava una pagina bianca.** `showScreen` spegne tutte le
schermate e accende quella richiesta: un nome non presente nel registro `screens`
le spegneva tutte e non ne accendeva nessuna. Nessun errore in console, niente che
dicesse dove guardare. Ora un nome non registrato lascia la schermata dov'e' e
lascia una traccia leggibile.

### 14. Col controller mezzo gioco era un vicolo cieco

Verificando la navigazione col pad in vista di Steam sono usciti quattro difetti,
tre banali e uno che il codice nascondeva bene.

**Indietro non era dove lo cerca chiunque.** Era su `b(2)` — X su Xbox, Quadrato su
PlayStation. `b(1)`, cioe' B/Cerchio, nei menu non era mappato a niente. E l'aiuto
del gioco, in entrambe le lingue, prometteva `"A conferma · B indietro"`: un
comando che non esisteva. Tre cose diverse — cosa si prova, cosa promette la
guida, cosa fa il codice.

**Dal menu principale "indietro" andava avanti.** `menuBack` cliccava il primo
`[data-action^="to-"]` della schermata attiva; nel menu la barra in alto viene
prima dell'hero, quindi apriva il Profilo. Ora il ritorno si dichiara con
`data-back` e il menu, che e' la radice, non ne ha.

**Il campo del messaggio non riceveva il fuoco**, perche' il selettore dei
bersagli elencava `button, input, .mode-card…` e non `textarea` — ne' `summary`,
quindi il riquadro "cosa viene allegato" non si apriva col pad.

Il quarto e' quello che conta. Aggiunto `textarea` al selettore, **la textarea
restava comunque irraggiungibile**. La causa era nel punteggio di
`moveMenuFocus`, che confrontava i soli centri penalizzando lo scostamento
trasversale per tre. Un elemento largo ha il centro in mezzo alla riga: partendo
dalla colonna di sinistra dei sei argomenti, la casella di spunta — piccola e piu'
allineata — vinceva pur stando molto piu' in basso, e la textarea veniva saltata.
Il percorso del fuoco, tracciato nel browser, lo diceva senza appello:

```
percorso: BUTTON -> BUTTON -> BUTTON -> BUTTON#feedbackCopyBtn
textarea raggiunta: false
```

Ora chi si sovrappone sull'asse trasversale vince sulla distanza fra i centri,
perche' e' quello che sta *davvero* in quella direzione. Vale per ogni elemento
largo, non solo per questo.

### 15. Senza tastiera su schermo il modulo di feedback era decorativo

Col solo controller non si poteva scrivere: nessuna tastiera digitale esisteva nel
progetto. Non si puo' contare su quella di Steam — in Big Picture e su Deck compare
in base al wrapper e alla configurazione di Steam Input, e sul sito non compare
affatto.

I tasti sono veri `<button>` dentro un overlay che diventa il contesto di fuoco:
la navigazione geometrica dei menu li raggiunge **senza una riga di codice nuova**,
e funzionano anche col mouse. Confermare su un campo di testo la apre, indietro la
chiude, e il testo scritto si vede in un'anteprima perche' il pannello copre il
campo vero.

Provata pilotando un pad finto — sostituendo `navigator.getGamepads`, cosi' gira
il percorso reale, rilevamento incluso:

```
percorso: BUTTON -> BUTTON -> BUTTON -> TEXTAREA#feedbackMessage
tastiera aperta: true      scritto nel campo: 'ciao qui'      contatore: 8 / 1200
```

Il contatore che si muove e' la prova che l'evento `input` arriva: senza, il campo
si riempirebbe e il resto del modulo non se ne accorgerebbe.

---

## Quando il banco di prova mente

Due errori di misurazione che vale la pena raccontare, perché mi hanno quasi portato a
conclusioni sbagliate.

**Il generatore pseudocasuale.** Misurando le scelte dell'IA ottenevo zero smash su 600
prove, con un valore che non scendeva *mai* sotto la soglia. Il difetto era mio:
riseminavo un generatore lineare con semi consecutivi 1, 2, 3… e un LCG così produce
valori correlati che spazzano un reticolo invece di coprire l'intervallo. Riscritto con
un generatore seminato una volta sola e un controllo di sanità sul percorso reale (media
0.496 contro 0.5 atteso), i numeri sono cambiati completamente.

**L'identità dei moduli.** Una ricerca sui parametri restituiva sempre lo stesso
risultato. Il motivo: i moduli del gioco si importano con una query di cache busting
(`data.js?v=…`) e il mio script importava `data.js` senza. Per Node sono **due moduli
distinti**, quindi stavo mutando un oggetto che il gioco non leggeva mai.

**La lingua dentro la misura.** `recordPointStats` decideva se un punto era un colpo
vincente o un errore con una regex sul messaggio **già tradotto**. Giocando in inglese
non corrispondeva quasi niente: `errors` restava a zero per l'intera partita e la
schermata di fine match mostrava 0-0. L'obiettivo "al massimo N errori" diventava una
stella regalata e "N colpi vincenti" irraggiungibile — l'intera modalità carriera
misurata sbagliato, in una lingua sola. Ora la categoria la dichiara chi assegna il
punto e la traduzione arriva solo al momento di disegnarla.

Da tutti e tre ho preso l'abitudine di verificare lo strumento prima dei risultati: se un
parametro non cambia l'output, il primo sospettato è la misura.

---

## La suite di audit

Script eseguibili in `scripts/`, senza framework di test:

```bash
node scripts/shot-quality-audit.mjs      # timing, qualità, energia, velocità
node scripts/shot-balance-audit.mjs      # lob, x3, repertorio dell'IA
node scripts/smash-input-audit.mjs       # doppio tap, degrado, risposta al servizio
node scripts/difficulty-audit.mjs        # scala dei tre livelli
node scripts/controller-tactics-audit.mjs # colpi tecnici, movimento, tattiche
node scripts/career-audit.mjs            # stelle raggiungibili, rampa, farm, finale
node scripts/drill-audit.mjs             # l'allenamento gira sul motore del gioco
node scripts/feedback-audit.mjs          # nessun feedback si perde, nulla si allega di nascosto
node scripts/api-feedback-audit.mjs      # le guardie dell'endpoint, senza deploy e senza chiavi
node scripts/gamepad-nav-audit.mjs       # tutto raggiungibile col pad, campi di testo compresi
node scripts/module-contract-audit.mjs   # ogni import trova il suo export
node scripts/modules-audit.mjs           # ogni modulo si valuta senza esplodere
```

Non verificano che il codice giri: verificano che il **bilanciamento** regga. Alcune
asserzioni sono vincoli di design espliciti — per esempio che lo smash x2 resti *"forte
ma difendibile"*, sotto il 40% di punti vinti. Durante il bilanciamento ero arrivato al
54% e quel test mi ha fermato: aveva ragione lui.

`module-contract-audit` è l'eccezione che verifica proprio che il codice giri, e c'è per
un guasto che non degrada: un import che non risolve interrompe la catena dei moduli, e
la pagina si apre con il campo disegnato e **nessun bottone che risponde**, perché
nessun listener è mai stato agganciato. È successo due volte, la seconda ripristinando
da HEAD dei blocchi che erano stati aggiunti di proposito. Ora 105 import vengono
verificati contro gli export reali, e la query di versione deve essere una sola.

Tutta la taratura è in un unico oggetto `BALANCE` in [`js/data.js`](js/data.js), così
un valore si sposta senza entrare nella logica.

---

## Architettura

| file | responsabilità |
|---|---|
| `game.js` | simulazione: fisica, regole, IA, punteggio |
| `render.js` | disegno: proiezione, campo, personaggi, HUD |
| `data.js` | costanti di bilanciamento, atleti, arene |
| `main.js` | ciclo di gioco, input, gamepad |
| `audio.js` | sintesi audio procedurale |
| `ui.js`, `i18n.js`, `fx.js`, `drill.js` | interfaccia, lingue, particelle, allenamento |

La simulazione non conosce il renderer: `game.js` non importa niente da `render.js` a
parte una funzione di utilità matematica. Il motore grafico è sostituibile senza toccare
una riga di gioco.

---

## Il feedback dei giocatori

Il menu ha un pulsante che raccoglie i messaggi dei giocatori. La consegna passa
da `api/feedback.js`, una funzione serverless su Vercel: dal browser non si
spedisce posta, e una chiave nel codice del client sarebbe pubblica per
definizione.

Il gioco resta a **zero dipendenze**: la funzione usa `fetch`, che il runtime Node
di Vercel ha di suo.

### Configurazione

Variabili d'ambiente da impostare su Vercel (Settings → Environment Variables).
Serve **una** delle due vie:

```bash
# via email (Resend)
FEEDBACK_TO=tua@casella.it
RESEND_API_KEY=re_...
FEEDBACK_FROM=onboarding@resend.dev     # o un mittente del tuo dominio verificato

# oppure via webhook (Discord/Slack) — nessun servizio di posta da configurare
FEEDBACK_WEBHOOK_URL=https://discord.com/api/webhooks/...

# facoltativo: restringe le origini ammesse
FEEDBACK_ALLOWED_ORIGINS=https://tuo-dominio.vercel.app
```

Finche' non e' configurato niente la funzione risponde **503**, non 200. E' una
scelta: un endpoint che risponde 200 senza consegnare farebbe svuotare la coda del
gioco, e il messaggio sparirebbe convinto di essere arrivato.

### Le tre reti di sicurezza

Il messaggio si salva in `localStorage` **prima** di ogni tentativo di rete, quindi
non si perde in nessuno dei casi che vanno storti:

| cosa va storto | cosa fa il gioco |
|---|---|
| nessuna rete | resta in coda e riparte al prossimo avvio |
| funzione non configurata (503) | apre il client di posta del giocatore |
| endpoint assente (pacchetto Steam senza URL assoluto) | apre il client di posta |
| appunti negati | il messaggio resta in coda, e lo dice |

### Attenzione per il pacchetto Steam

`endpoint` e' un percorso relativo (`/api/feedback`): funziona sul sito, dove
pagina e funzione stanno sullo stesso dominio. In un pacchetto per Steam la pagina
non e' servita da un dominio, quindi in `js/data.js` va messo l'**URL assoluto** del
deploy. Senza, la POST parte verso un'origine che non esiste — e il ripiego sulla
posta la copre, ma la consegna automatica no.

### Cosa viaggia col messaggio

Il testo libero da solo non si usa: "lo smash x2 e' troppo forte" non dice con
quale atleta, in quale arena, a quale difficolta'. Per questo ogni messaggio porta
`VERSION.balance`, il riferimento della **taratura in vigore** — va incrementato
quando si sposta un valore di `BALANCE`, altrimenti un reclamo di oggi diventa
indistinguibile da uno di dopo la prossima ritaratura. Il contesto e' mostrato per
intero nel modulo e il giocatore puo' rifiutarlo.

---

## Come si esegue

Serve un server statico qualsiasi, perché il gioco usa moduli ES:

```bash
python3 -m http.server 8000
# poi apri http://localhost:8000
```

I moduli usano una query di versione (`?v=…`) come cache busting. **Cambiandone uno,
vanno aggiornate tutte e 25 le occorrenze** in `index.html` e `js/*.js`: se restano
disallineate il browser può servire un modulo vecchio insieme a uno nuovo, e un import
che non trova il proprio export non degrada — il gioco non parte.

```bash
grep -c "20260910-sprite-gate-v41" index.html js/*.js styles.css   # deve dare 26 in totale
```

---

## Controlli

Tastiera e gamepad. Su controller: **A** drive, **X** slice/víbora, **Y** lob, **B**
speciale, **LB** cambio giocatore, **RB** modificatore tecnico, **LT** split-step, **RT**
sprint — e, tenendo la carica, **RT** diventa l'angolo stretto: avvicina il bersaglio al
vetro guadagnando precisione, ma con una dispersione incomprimibile che rende il colpo un
azzardo consapevole.

## Stato

Alpha giocabile con 6 atleti completi e 26 completi complessivi. Ogni atleta ha un
outfit firma e uno mitico esclusivo; le 20 varianti sbloccabili usano 120 fogli sprite WebP lossless
dedicati, caricati alla prima richiesta. Il payload immagini iniziale resta sotto 15 MB.
