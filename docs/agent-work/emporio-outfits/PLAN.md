# Outfit sbloccabili nell'Emporio — contratto approvato

## Evidenza attuale

- Checkout: `steam-circuit-padel-11m`, ramo `codex/integrate-arena-11m`, HEAD `572c5f0` al sopralluogo.
- L'Emporio oggi vende OST con Crediti Circuito; `EmporioScreen.gd` ha già una modifica locale non committata (vetrina e anteprima audio) da preservare.
- `mode_tables.gd` espone gli outfit per atleta; `career_rules.gd` sblocca quelli con sfida tramite `career.outfitsWon` e dichiara esplicitamente che i completi si vincono, non si comprano.
- Il guardaroba in `CharactersScreen.gd` e gli outfit usati in partita tramite `lineup.gd` rispettano tale regola.

## Scelta di prodotto

L'utente ha scelto l'**acquisto alternativo** con Crediti Circuito e la sfida come via principale. Mostrare i 20 outfit non-base con sfida del catalogo canonico, non gli outfit base o eventuali cosmetici Godot-only senza obiettivo. Solo quelli che il guardaroba 3D sa effettivamente applicare sono acquistabili: 14/20 allo stato attuale; gli altri 6 restano visibili ma non acquistabili. Prezzi per rarità: Circuito 600, Leggenda 900, Signature 1200, Mythic 1800 CC (OST: 150/250). Il prezzo alto rende la sfida la scorciatoia naturale; l'acquisto resta una scelta di accumulo volontaria.

## Contratti invarianti

- Non creare valuta nuova o acquisti con denaro reale.
- Conservare gli outfit già vinti/equipaggiati, le OST già possedute, il portafoglio e le modifiche locali concorrenti.
- Validare nel servizio economico ID, prezzo, proprietà e saldo; addebito e possesso devono essere nello stesso salvataggio atomico `economy`. Non registrare un acquisto come sfida vinta in `career.outfitsWon` e non assegnare Steam achievement da un acquisto.
- `economy.ownedOutfits` è il possesso d'acquisto; la vista della carriera può includerlo in un campo transitorio per `CareerRules.is_unlocked`, ma `ModesSave.save_career` non deve persistere copie derivate. La sfida resta indipendente.
- Il guardaroba, il menu e la partita devono riconoscere gli outfit acquistati senza bypassare gli stati di blocco esistenti. LUCALE/ALELU e salvataggi vecchi o rifiutati devono rimanere coerenti.
- Emporio: filtri e focus controller, conferma prima dell'addebito, Back/ESC, layout leggibile a 1280×720; nessuna regressione delle OST e dell'anteprima audio.

## Fasi dopo la scelta

1. Congelare catalogo/prezzi e contratti di accesso; acquisire baseline dei file dirty pertinenti.
2. Implementare vetrina, proprietà/acquisto atomico e accesso in guardaroba/partita.
3. Test mirati su profilo isolato: articoli e preview, sfida/acquisto, saldo, doppio acquisto, fondi insufficienti, riavvio, focus/controller e cattura 1280×720. Revisionare il diff rispetto alla baseline.

## Stato esecuzione

L'utente ha autorizzato esplicitamente l'esecuzione diretta in questa task. Nessuna configurazione/provider viene cambiata; il worker Flash non viene usato.

## Verifica

- `emporio_outfit_test.gd`: 42/42 (isolamento profilo, catalogo, acquisto/errore atomico, sfida indipendente, guardaroba, lineup, spawn nella partita reale, LUCALE/ALELU, pad e interoperabilità OST).
- `emporio_storefront_test.gd`: 44/44; `outfit_wardrobe_match_test.gd`: PASS.
- `emporio_ost_test.gd`: 100/102; gli unici due fallimenti erano già presenti prima di questa modifica: conteggi statici di 47 OST contro 63 attuali. Tutti i controlli di acquisto/host restano verdi.
- Cattura nativa a 1280×720: `emporio-outfits-1280x720.png`.
