# L'avversario lascia rimbalzare la palla? — misura di partenza

2026-09-23. Ramo `codex/integrate-arena-11m`. Nessun cambio di comportamento: questa è la
fotografia del gioco com'è, più una manopola spenta per le prove successive.

## Come si misura

```bash
godot --headless --path godot/ --script res://game/tools/ai_rally_metrics.gd
# variabili: SEEDS=16  LEVELS=0,1,2,3  AI_BOUNCE_BIAS=0.0
```

[`godot/game/tools/ai_rally_metrics.gd`](../../../godot/game/tools/ai_rally_metrics.gd) gioca
partite vere nella simulazione (nessuna scena, nessun render) contro ognuno dei 4 livelli,
con il giocatore automatico (`game/scripted_player.gd`) che tira **sempre drive** (A) oppure
**sempre taglio** (X). Legge lo stato, non lo modifica.

"Al volo" = il contatore dei rimbalzi della simulazione nel tick prima del colpo
dell'avversario. Un secondo rilevatore indipendente (la palla che tocca terra nella metà
dell'avversario e inverte la velocità verticale) concorda nel 94-96% dei contatti.

Il giocatore automatico è debole: i **punti vinti** in assoluto non dicono niente di un
giocatore umano. Valgono i **confronti** tra livelli, tra drive e taglio, e tra prima e dopo.

## Risultati (16 partite per riga, manopola a 0)

> **Correzione, stesso giorno.** La prima versione di questa tabella contava come "al volo"
> anche le palle che rimbalzano e vengono colpite **nello stesso tick**: il contatore dei
> rimbalzi, letto al tick prima del colpo, segnava ancora 0. Scoperto accendendo
> `aiGlassPlay`, quando i colpi dopo il rimbalzo sono diventati la norma. Lo strumento ora
> riconosce il rimbalzo del tick stesso (`landRing == 0.5`). I numeri qui sotto sono quelli
> corretti. Quelli di prima (76-100% al volo da fondo) erano gonfiati.

Dati grezzi: [`baseline-2026-09-23.jsonl`](baseline-2026-09-23.jsonl).

| livello | colpo | punti | vinti % | scambio medio | non restituiti % | al volo % | a rete % | a fondo % |
|---|---|---|---|---|---|---|---|---|
| 0 Rivale | drive | 488 | 22.3 | 4.86 | 5.4 | 75.0 | 94.4 | **58.3** |
| 0 Rivale | taglio | 410 | 10.7 | 5.91 | 1.2 | 80.6 | 91.6 | **62.0** |
| 1 Ingegnere | drive | 399 | 7.8 | 7.14 | 0.7 | 82.1 | 95.5 | **61.6** |
| 1 Ingegnere | taglio | 394 | 6.6 | 7.12 | 0.1 | 89.8 | 95.1 | **66.3** |
| 2 Campione | drive | 373 | 1.3 | 6.48 | 0.0 | 96.1 | 98.8 | **85.9** |
| 2 Campione | taglio | 376 | 2.1 | 6.11 | 0.1 | 87.8 | 95.8 | **46.1** |
| 3 Leggenda | drive | 372 | 1.1 | 5.38 | 0.1 | 98.5 | 98.7 | **97.4** |
| 3 Leggenda | taglio | 371 | 0.8 | 5.98 | 0.0 | 97.8 | 98.2 | **92.4** |

Cosa dice:

- **Il giocatore di fondo prende al volo il 46-97% delle palle, e di più ai livelli alti**:
  86-97% col drive ai livelli 2 e 3. Nel padel reale dovrebbe lasciarne rimbalzare la maggior
  parte.
- **Il taglio è peggio del drive** dove i numeri sono leggibili: al livello 0 i punti vinti
  si dimezzano (22,3% → 10,7%) e le palle non restituite passano dal 5,4% all'1,2%.

Perché il giocatore di fondo rinuncia ad aspettare (`ai_contact.gd`, motivi più frequenti):
il rimbalzo cadrebbe **vicino alla rete**, **vicino al vetro laterale** o **vicino al vetro di
fondo**, oppure non c'è tempo. Una parte dei casi è `volley`: il giocatore sta a 130-150 px
dalla rete, cioè a metà campo, dove il pianificatore lo considera ancora a rete.

## Le cause nel codice

1. **Il difensore va incontro alla palla.** In `move_opponent_team` il giocatore che risponde
   punta alla profondità *attuale* della palla (`ball.y - 18`), quindi la incontra in aria.
   Il pianificatore del rimbalzo interviene dopo, quando ormai è troppo vicino.
2. **Il pianificatore non sa giocare i vetri.** Rifiuta ogni rimbalzo da cui la palla
   potrebbe toccare un vetro prima del colpo: il suo commento dice *"reject any possible wall
   contact before our target"*. Nel padel quasi ogni palla profonda o angolata passa dal vetro.
3. **Dopo ogni proprio colpo la coppia corre a rete** (`attacking`, 62-94 px dalla rete), e il
   compagno segue sempre chi risponde (`support_target_y = primary_target_y - 10`).

## La manopola: `State.aiBounceBias` (0 = com'è oggi)

A 0 le tre partite registrate (`tools/parity-godot/run-golden.sh`) restano **identiche**:
verificato. Sopra 0 fa due cose, entrambe solo per il giocatore già fuori dalla zona di volée
(oltre 130 px dalla rete):

- il difensore si piazza **dietro il rimbalzo previsto** invece di andare incontro alla palla;
- il pianificatore allenta tre soglie: attesa massima 0,65 → 1,10 s, margine dal vetro
  laterale 76 → 40 px, margine dalla rete 42 → 22 px.

**Prova fatta, livello 1, drive, 6 partite** (misurata con lo strumento ancora da correggere, quindi le percentuali al volo sono gonfiate; resta valido il confronto tra le righe):

| manopola | al volo da fondo | contatti a rete | scambio medio |
|---|---|---|---|
| 0 | 82% | 405 | 7,0 |
| 0,5 | 93% | 36 | 8,2 |
| 1,0 | 88% | 31 | 6,8 |

**Da sola non risolve e peggiora il gioco a rete.** La coppia arretra (il compagno segue chi
risponde) e smette quasi di stare a rete. Il giocatore di fondo resta comunque al volo
nell'88-93% dei casi, perché i rimbalzi che dovrebbe aspettare finiscono quasi sempre vicino
a un vetro, e lì il pianificatore rinuncia. **Non va accesa in una partita vera** così com'è:
nessuna parte del gioco la imposta sopra 0.

## Il gioco dopo il rimbalzo, vetri compresi: `State.aiGlassPlay` (spento)

[`godot/src/sim/ai_glass.gd`](../../../godot/src/sim/ai_glass.gd) prevede la traiettoria
facendo avanzare una **copia** della palla con le stesse formule della simulazione:
gravità, attrito, effetto, rimbalzo e riflessione sul vetro. Non tocca né lo stato né il
generatore casuale. I casi del vetro decisi a caso (smash X2/X3, cut-volley) non vengono
previsti: lì l'avversario gioca come prima.

**Accuratezza misurata** contro la traiettoria vera, su circa 14.000 punti di 6 partite, fuori
dal `hitStop`: in aria errore 0,00 px, dopo il rimbalzo 0,00 px nel 95% dei casi, sui vetri
mediana 0,00 px e 95° percentile 5,35 px, su un campo largo 800 px.

Quando è acceso, e solo per chi è fuori dalla zona di volée, dove il vecchio pianificatore
diceva "prendila in aria" l'avversario cerca il primo punto dopo il rimbalzo che riesce a
raggiungere, con la palla a un'altezza comoda, e la aspetta lì. Spento, le partite
registrate sono identiche (verificato).

Dati grezzi: [`glass-play-on-2026-09-23.jsonl`](glass-play-on-2026-09-23.jsonl).

| livello | colpo | al volo da fondo (spento → acceso) | scambio medio | vinti % | contatti a rete | punti persi dall'avversario per doppio rimbalzo |
|---|---|---|---|---|---|---|
| 0 Rivale | drive | 58.3% → **38.7%** | 4.86 → 4.61 | 22.3% → 16.8% | 659 → 378 | 76 → 55 |
| 0 Rivale | taglio | 62.0% → **35.7%** | 5.91 → 5.05 | 10.7% → 10.0% | 932 → 519 | 11 → 8 |
| 1 Ingegnere | drive | 61.6% → **35.2%** | 7.14 → 6.41 | 7.8% → 5.4% | 1036 → 586 | 9 → 7 |
| 1 Ingegnere | taglio | 66.3% → **19.0%** | 7.12 → 8.33 | 6.6% → 7.0% | 1340 → 845 | 0 → 1 |
| 2 Campione | drive | 85.9% → **31.0%** | 6.48 → 5.80 | 1.3% → 2.1% | 1202 → 716 | 0 → 0 |
| 2 Campione | taglio | 46.1% → **9.1%** | 6.11 → 10.02 | 2.1% → 2.0% | 1153 → 925 | 0 → 0 |
| 3 Leggenda | drive | 97.4% → **31.1%** | 5.38 → 5.25 | 1.1% → 0.8% | 1102 → 729 | 0 → 1 |
| 3 Leggenda | taglio | 92.4% → **10.0%** | 5.98 → 9.42 | 0.8% → 0.8% | 1257 → 1045 | 0 → 0 |

- **Da fondo l'avversario ora lascia rimbalzare**: al volo scende al 9-39%, a ogni livello.
- **Non sbaglia di più**: i punti persi per doppio rimbalzo (non ci arriva) non aumentano.
- **Col taglio ai livelli alti gli scambi si allungano** (6 → 10 colpi): il taglio viene
  finalmente lasciato rimbalzare e restituito.
- **Effetto collaterale: meno contatti a rete** (−20/−45%). Più palle le prende chi sta
  dietro, e la coppia sta meno a rete. È il punto 2 qui sotto.

## Prova in partita e causa vera (stesso giorno)

Acceso nel gioco per la prova del proprietario: **"l'IA sembra troppo scarsa, e non viene più
a rete"**. Confermato dalla misura (livello 2, drive): l'altezza media di contatto dell'IA
scende da 42 a 24 px, i suoi colpi da 487 a 460 px/s, i contatti a rete da 774 a 454.

Alzare l'altezza di contatto minima a 36 px (e preferire il colpo dopo il vetro di fondo)
riporta l'IA com'era, ma rende la funzione quasi inerte: 83% al volo da fondo, colpi dopo il
vetro di fondo 0-2%. Perché:

> **Correzione (stesso giorno): la frase che stava qui era sbagliata.** Diceva che dopo il
> rimbalzo la palla sale in mediana di 10 px. La sonda che l'aveva misurato faceva partire la
> previsione nel momento sbagliato (risultava anche un 60% di colpi "che non arrivano mai nella
> metà avversaria", impossibile). Misura rifatta con la previsione presa quando la palla passa
> la rete, fuori dal `hitStop` (livello 2, 8 partite per tipo):
>
> | colpo del giocatore | risale dopo il rimbalzo (mediana) | sopra la rete (38 px) |
> |---|---|---|
> | drive | **40 px** (p10 38, p90 51) | 71% |
> | taglio | 28 px (p10 20, p90 32) | 4% |
> | uscita dal vetro | 30 px | 0% |
> | smash piatto | 34 px | 0% |
>
> Quasi tutte le palle atterrano in campo (1-3 su circa 650 finiscono sul vetro di fondo al volo).

~~Il limite quindi sta nel rimbalzo a terra.~~ **Sbagliato, vedi sopra.** Il drive rimbalza
all'altezza della rete: la fisica non è il problema principale. Il problema è stato il
pianificatore, che sceglieva il primo punto dopo il rimbalzo (la palla ancora bassa, a 18 px,
mentre risale) invece di aspettarla vicino al punto più alto. E alzando la soglia a 36 px la
finestra utile si è ridotta quasi a niente: il drive arriva al massimo a circa 40 px, il
taglio a 28. Interruttore spento nel gioco (`match_controller.gd`, `AI_GLASS_PLAY := false`).

## Terza versione (stesso giorno): riaccesa nel gioco per la prova

Cosa è cambiato rispetto alla prima versione:

1. **Colpisce vicino alla cima dell'arco dopo il rimbalzo**, cioè almeno l'80% dell'altezza
   massima di quella palla (`TOP_SHARE`), mai sotto 20 px. Non più una soglia fissa.
2. **Una palla a portata ora, a un'altezza giocabile, si colpisce.** Il vetro si usa solo
   quando prima non si può prendere. Scommettere sul vetro gli costava il punto: dopo il vetro
   la simulazione gli ridà un tempo di reazione in parte casuale (57 doppi rimbalzi su 62
   persi al livello 1, 24 su 27 al livello 2, erano palle lasciate passare mentre erano a
   portata).
3. **Se la palla rimbalzata sta ancora salendo, la aspetta in cima**, ma solo se, calcolando
   dove sarà, resterà ancora a portata.
4. **Il compagno vicino alla rete resta a rete** mentre chi risponde arretra per il rimbalzo.

Misura, drive, 8 partite per livello, spento → acceso:

| livello | al volo da fondo | punti al giocatore automatico | doppi rimbalzi dell'IA | velocità colpi IA | altezza contatto IA | tempo a rete |
|---|---|---|---|---|---|---|
| 1 | 63% → 47% | 9,8% → 9,4% | 6 → 9 | 496 → 474 | 34 → 30 | — |
| 2 | 84% → 36% | 0,5% → 3,2% | 0 → 4 | 481 → 480 | 42 → 34 | 38% → 40% |
| 3 | 97% → 44% | 1,1% → 1,6% | 0 → 2 | 480 → 470 | 41 → 34 | 39% → 41% |

I contatti a rete calano (livello 2: 615 → 424) perché più palle le gioca chi sta dietro
(contatti da fondo 142 → 347), non perché la coppia lasci la rete: il tempo a rete sale.
**Il colpo dopo il vetro di fondo resta raro (1-4%)**: il prezzo della regola 2. Farlo
crescere senza perdere punti richiede di prevedere anche il tempo di reazione dopo il vetro,
che nella simulazione è in parte casuale.

## Seconda prova in partita: bocciata, spento di nuovo

Il proprietario, giocando: lascia rimbalzare di più, sì; ma **"sono molto più scarsi di
prima, a Leggenda prima erano molto più forti"** e **"pochissimo viene a rete"**. Le misure
col giocatore automatico dicevano il contrario (forza e tempo a rete uguali). **Il giocatore
automatico non rappresenta un avversario umano**: gioca sempre drive o sempre taglio dal
fondo, non varia, non attacca. Per questa modifica non può essere il giudice.
`AI_GLASS_PLAY := false` nel gioco.

## Cosa serve davvero (non fatto)

1. ~~Insegnare all'avversario a giocare dopo il rimbalzo anche sui vetri~~: fatto,
   `aiGlassPlay`, spento finché non si decide per quali livelli accenderlo.
2. **Staccare il compagno da chi risponde**: chi è a rete resta a rete quando il compagno
   arretra (la classica posizione a rete più fondo).
3. **Tornare a rete dopo un buon colpo, non dopo ogni colpo.**
4. Solo dopo, **ritarare il taglio** e rimisurare con lo stesso strumento.

Ognuno di questi cambia le regole: va riregistrato `golden/` insieme al cambio.
