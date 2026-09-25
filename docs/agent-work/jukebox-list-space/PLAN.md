# Jukebox: spazio al catalogo OST

## Contratto

- Intervenire solo sulla presentazione del catalogo Jukebox nel checkout e ramo concordati.
- Mantenere filtri, preferiti, ordinamento R3, anteprima playlist, riproduzione, salvataggio e navigazione esistenti.
- Rendere compatti i controlli sempre utili; spostare ordinamento R3 e «Riproduci solo i preferiti» in «Opzioni» apribile e richiudibile.
- Lasciare visibili titolo, scelta musiche menu/partita, filtro Tutti/Preferiti, genere e «Ascolta playlist»; l'elenco OST deve occupare lo spazio verticale rimanente e scorrere da solo.

## Accettazione

1. A 1280×720, con «Opzioni» chiuse, si vedono sensibilmente più righe complete del catalogo rispetto allo stato iniziale, senza tagli di pulsanti o testo.
2. Opzioni, filtri, stelle e playlist funzionano con mouse e controller; chiudere «Opzioni» non lascia il focus su un controllo nascosto.
3. I test Jukebox pertinenti passano; diff circoscritto, modifiche preesistenti preservate.

## Fasi

1. Baseline visiva e verifica dei vincoli di layout.
2. Implementazione compatta e test/probe mirati.
3. Revisione del diff, schermata finale e regressioni funzionali.

## Esito

- A 1280×720 nella scheda «Musiche partita»: 9 righe complete con «Opzioni» chiuse, 6 con «Opzioni» aperte.
- I controlli R3 e «solo preferiti» restano raggiungibili; richiudendo «Opzioni» il focus torna al relativo pulsante.
- Cattura: `after-1280x720.png`.
- Test: `jukebox_catalog_layout_test.gd` 12/12 (nativo), `jukebox_player_test.gd` 89/89, `music_preferences_test.gd` 37/37, `test_jukebox_screen36.gd` passato.
