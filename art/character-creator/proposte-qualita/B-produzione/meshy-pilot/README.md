# Campione B maschile — 2026-09-28

Generato esclusivamente con la chiave etichettata account 2 nel file locale indicato dall'utente. Nessuna credenziale è copiata qui.

## Spesa verificata

- Saldo iniziale 1077, finale 1022.
- Corpo con texture 30; capelli senza texture 20; rigging 5.
- Totale 55 crediti. Nessuna rigenerazione, animazione a pagamento o generazione femminile.
- Identificativi delle richieste e consumi: `ledger.json`.

## File e verifica

- `body.glb`: sorgente non riggata, 16585 triangoli.
- `body-rigged.glb`: corpo riggato, 16583 triangoli, 24 ossa, radice `Hips`.
- `walk.glb`: camminata base inclusa nel risultato del rigging; una posa a 0.4 s è stata renderizzata in Godot.
- `hair.glb`: capelli modulari, 3653 triangoli, senza texture. Il marrone nello screenshot è solo un materiale della scena di verifica.
- `*-review.png`: immagini effettivamente renderizzate con Godot 4.7.2, non immagini promozionali Meshy.
- `../review-pilot.gd`: revisione isolata tramite GLTFDocument, senza sostituire asset o impostazioni del gioco.
- Il bounding box della mesh non deformata restituisce una scala diversa da quella della skin; l'inquadratura di verifica del corpo usa esplicitamente l'altezza richiesta di 1.8 m. La misura non è una validazione automatica della scala.

## Non ancora approvato per il gioco

Aggiornamento: adattamento locale completato nel prototipo `godot/prototypes/creator_b/`, con retarget delle animazioni e capelli agganciati alla testa. Vedere il suo README per verifiche e limiti. Il paragrafo seguente descrive lo stato dei GLB grezzi al momento del download, non l'adattatore nuovo.

Il rig restituito ha 24 ossa e nomi senza prefisso mixamorig; lo standard documentato del roster ne richiede 28. Occorrono adattamento/retarget e verifica dei colpi prima di promuovere il campione. Non è stata provata una partita. Capelli e corpo sono stati verificati separatamente: aggancio, scala e clipping dei capelli restano da verificare. Aspetto e materiali necessitano della revisione ravvicinata sotto le luci effettive del gioco. Nessun personaggio corrente è stato modificato.

Non rieseguire le generazioni: lo script blocca le richieste già registrate. `status` recupera solo quelle esistenti. Una richiesta dal risultato ambiguo deve essere controllata su Meshy prima di ogni nuovo invio.
