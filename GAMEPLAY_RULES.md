# Padel Flow Arena - Gameplay Rules

## Obiettivo

Il gioco deve sembrare padel prima che arcade: rally leggibili, recuperi possibili,
scelte di posizione riconoscibili e punti vinti per costruzione dello scambio, non
per traiettorie casuali o colpi inevitabili.

## Scala del Campo

- Il campo logico rappresenta un rettangolo 20 x 10 metri.
- La rete separa due meta campo. Ogni lato ha una zona di fondo e una zona di rete.
- La palla usa coordinate orizzontali `x/y` e altezza `z`.
- Il vetro e' attivo soltanto dopo un primo rimbalzo valido sul lato che lo riceve.
- Il secondo rimbalzo sullo stesso lato termina il punto.

## Servizio

- Il battitore resta dietro la propria linea di servizio.
- Il battitore resta nel proprio riquadro (destra o sinistra), alternato a ogni punto.
- Il servizio e' dal basso, attraversa la rete e rimbalza soltanto nel riquadro diagonale opposto.
- La risposta non puo' essere una volée prima del rimbalzo.
- Un errore produce seconda palla; due errori consecutivi producono doppio fallo.
- Il servizio ha una velocita' massima distinta da drive e smash: deve iniziare il
  rally, non chiuderlo.

## Palla e Colpi

### Qualita' del colpo

- La potenza scelta non coincide con la qualita' di esecuzione. Ogni impatto combina
  timing, distanza dalla palla, equilibrio, altezza, controllo dell'atleta ed energia.
- Una pressione breve produce un colpo di controllo: meno veloce, preciso e poco
  dispendioso. La carica intermedia produce un colpo bilanciato; la carica alta produce
  potenza, ma riduce gli angoli disponibili e amplifica gli errori contestuali.
- Il rilascio vicino al contatto e' perfetto. Un rilascio anticipato usa una breve
  memoria del colpo ma perde qualita'; colpire quando la palla ha gia' superato il
  corpo viene valutato in ritardo.
- Una qualita' bassa produce prima una palla corta o centrale. Rete e fuori campo
  diventano probabili solo sommando timing scorretto, posizione difficile, mira
  estrema, poca energia o potenza eccessiva.
- L'energia e' locale allo scambio: correre e ripetere colpi potenti la consumano,
  slice e controllo costano meno, una breve pausa la recupera. Si azzera a ogni punto.
- Lo stesso modello viene applicato all'AI. La difficolta' modifica la sua precisione
  temporale e tattica, non le concede contatti impossibili.

- Un colpo standard usa una velocita' orizzontale moderata e una parabola leggibile.
- L'altezza del colpo determina la parabola: piu' alto significa piu' margine sulla
  rete e piu' tempo di risposta, non piu' potenza gratuita.
- La volée e' rapida ma meno potente di uno smash pulito.
- Il lob usa potenza e profondita' reali: un tocco resta corto, la carica intermedia
  supera la coppia a rete e una carica massima verso il fondo puo' colpire il vetro
  prima del rimbalzo. Il controllo dell'atleta riduce, ma non annulla, questo rischio.
- Lo smash ha una finestra precisa: palla alta, giocatore vicino alla rete, direzione
  sicura. In ogni altra situazione viene convertito in bandeja controllata.
- Su una palla alta vicino alla rete, un colpo quasi completamente caricato attiva
  uno smash tecnico: mira centrale per lo smash di ritorno x2, mira laterale decisa
  per l'uscita x3. Il primo rimbalzo deve sempre avvenire nel campo avversario.
- Lo smash x2 rimbalza sul fondo e torna oltre la rete; lo smash x3 usa topspin,
  vetro di fondo e uscita sopra la parete laterale. Una preparazione bassa o lontana
  dalla rete produce invece un normale drive potente.
- Una mira estrema su un colpo standard cerca il rimbalzo vicino al vetro laterale:
  dopo il contatto con la parete la traiettoria si riapre verso il centro del campo.
- I colpi laterali sono limitati: la palla non deve poter uscire dal campo con una
  piccola imprecisione dell'AI.

## Logica dell'AI

### Priorita' di decisione

1. Rientrare in una posizione sicura rispetto alla palla e al compagno.
2. Colpire soltanto una palla raggiungibile e sotto l'altezza massima di controllo.
3. Scegliere un bersaglio nel campo avversario con margini dal vetro e dalle linee.
4. Usare vetri e accelerazioni solo quando il contesto li rende sicuri.

### Zone bersaglio

- **Sicura:** centro o tre quarti del campo avversario, lontano almeno 12% della
  larghezza dai vetri laterali e dal vetro di fondo.
- **Pressione:** angolo solo con palla bassa e avversari fuori posizione.
- **Recupero:** lob alto e centrale quando l'AI e' in ritardo o la palla e' sotto
  la linea della rete.
- **Vietata:** traiettoria che raggiunge il vetro avversario prima del rimbalzo.
- L'AI usa drive, lob, volée, víbora e smash. X2 e X3 richiedono palla alta e
  posizione avanzata; la frequenza e la precisione crescono con la difficolta'.

### Errore controllato

- L'AI non sbaglia aggiungendo potenza casuale.
- La difficolta' modifica tempo di reazione, velocita', precisione del bersaglio e
  probabilita' di scegliere il colpo migliore. La risposta non usa probabilita'
  rieseguite a ogni fotogramma.
- Anche alla difficolta' alta, il bersaglio resta normalmente dentro una zona sicura.
  Un errore fuori campo e' ammesso soltanto dopo una scelta aggressiva e deve essere
  raro, deciso una volta al colpo e proporzionato alla difficolta'.
- Un colpo carico e angolato aumenta la pressione sulla ricezione: l'AI puo' restare
  contropiede una sola volta per traiettoria. La probabilita' e il ritardo diminuiscono
  con la difficolta', premiando potenza e mira senza controlli casuali per fotogramma.
- Un tocco leggero resta corto e facile da recuperare; non puo' produrre lo stesso
  vantaggio di un colpo caricato verso lo spazio libero.

### Pareti e assegnazione del punto

- Una palla che colpisce direttamente la parete avversaria senza rimbalzare assegna
  il punto alla squadra che si trovava su quel lato.
- Un colpo sul proprio vetro di fondo puo' proseguire verso il campo avversario.
- Dopo un rimbalzo e il contatto con il proprio vetro, la palla resta colpibile anche
  se la sua velocita' e' ora diretta verso la rete. Ricevitore e previsione vengono
  ricalcolati al momento del contatto con la parete.
- Il secondo rimbalzo viene contato soltanto sul lato in cui avviene e assegna il
  punto alla squadra opposta.

### Compagni di squadra

- La coppia difende insieme vicino al fondo e attacca insieme vicino alla rete,
  mantenendo due corsie laterali distinte e un leggero sfalsamento in profondita'.
- Il ricevitore designato intercetta la palla; il compagno copre centro e diagonale
  senza inseguire lo stesso bersaglio.
- Se un compagno puo' colpire, l'altro rientra in una posizione di copertura.
- Il cambio automatico valuta tempo di arrivo, distanza laterale e altezza prevista.
  La scelta avviene al colpo avversario e resta stabile fino alla risposta del giocatore.
- Se la scelta e' quasi alla pari, il movimento gia' iniziato mantiene il controllo.
  Se il compagno e' nettamente favorito, il cambio automatico ha priorita'. Un cambio
  manuale resta bloccato fino alla risposta.
- In risposta al servizio i compagni hanno diagonali fisse: il giocatore di sinistra
  riceve il servizio diretto a sinistra, quello di destra riceve il servizio diretto
  a destra. La selezione avviene prima della battuta e resta stabile fino alla risposta.
- Durante il servizio avversario entrambi i giocatori della squadra in risposta restano
  dietro la linea di servizio. Possono avanzare verso la rete solo dopo la risposta.
- La stessa formazione vale per la squadra AI quando serve il giocatore: entrambi gli
  avversari partono dietro la linea e solo il ricevitore del diagonale puo' rispondere.

## Parametri di Bilanciamento

- Velocita' standard: deve attraversare il campo in circa 1.0-1.4 secondi.
- Velocita' massima AI: non oltre il 15% sopra un drive standard.
- Deviazione laterale AI: ridotta vicino ai vetri, maggiore solo sui colpi sicuri.
- Altezza massima di risposta: impedisce smash automatici su palle troppo alte.
- Dopo un rimbalzo, la velocita' diminuisce abbastanza da rendere possibile leggere
  vetro e recupero.

## Feedback al Giocatore

- Il log deve spiegare gli eventi rilevanti: servizio valido, vetro valido, secondo
  rimbalzo, doppio fallo e colpo difensivo.
- Il punteggio resta tennis: 0, 15, 30, 40, vantaggio, game, set e tie-break.
- L'animazione della palla deve rendere evidente altezza e punto di rimbalzo.
- Dopo il contatto appare un feedback breve: PERFETTO, BUONO, IN ANTICIPO o IN
  RITARDO, accompagnato dall'intenzione CONTROLLO, BILANCIATO o POTENZA.
- Una barra sottile sotto il giocatore attivo mostra l'energia residua nello scambio.

## Controller

- Il movimento usa il vettore analogico completo dello stick sinistro, con deadzone
  radiale regolabile e curva progressiva per conservare micro-movimenti e diagonali.
- A carica il drive, X carica slice o vibora, Y carica il lob, B usa l'abilita'
  speciale e LB cambia rapidamente giocatore.
- Durante la carica lo stick sinistro controlla la mira assoluta su due assi e
  conserva un movimento ridotto: il giocatore puo' aggiustare i piedi, ma perde
  stabilita' se corre. Gli estremi laterali corrispondono agli angoli estremi del
  campo, mentre avanti allunga il colpo e indietro lo accorcia.
- Il timing meter mostra prima del contatto una finestra perfetta contestuale:
  corsa, energia, altezza e uscita dal vetro la restringono; lo split-step la amplia.
  Il consiglio tattico suggerisce il colpo piu' sicuro, ma non limita la scelta.
- I profili di esecuzione sono controllo (margine e profondita'), attacco (angolo e
  ritmo) e rischio (massima liberta' di mira, ma dispersione piu' alta).
- Lo smash usa un input temporale: si carica e rilascia A su una palla alta a rete,
  poi si preme nuovamente A all'impatto. Lo stick sinistro avanti seleziona X2,
  diagonale seleziona X3, neutro produce lo smash piatto e indietro la bandeja.
- LT attiva lo split-step: riduce la velocita' ma migliora stabilita', timing e
  lettura del rimbalzo. RT e' una corsa analogica progressiva che consuma energia
  e riduce la precisione mentre aumenta la velocita'.
- RB e' un modificatore tecnico: RB + A produce la chiquita, RB + X richiede la
  vibora e RB + Y produce un lob difensivo piu' alto e controllato.
- Il D-pad imposta la tattica della coppia: su conquista la rete, giu difende il
  vetro, sinistra crea una disposizione sfalsata e destra ripristina l'equilibrio.
- A stick destro libero, un flick verso il compagno effettua il cambio direzionale.
- Il cambio giocatore offre tre modalita': assistito, semi-assistito e manuale. In
  manuale non avvengono cambi automatici durante il rally; il ricevitore corretto
  del servizio resta comunque vincolato dalle regole.

## Criteri di Accettazione

- L'AI completa rally multipli senza colpire direttamente pareti o uscire dal campo
  nella maggior parte degli scambi.
- I colpi dell'AI restano dentro i margini del campo salvo un rischio deliberato.
- Ogni punto perso dall'AI corrisponde a una regola visibile, non a casualita'.
- Il giocatore puo' prevedere dove arrivera' la palla e ha tempo per muoversi.
