# Outfit 2D → 3D: inventario e fattibilità

Audit locale, 20 settembre 2026. Nessuna generazione, chiamata Meshy o modifica al
gioco. Checkout verificato: steam-circuit-padel-11m, codex/integrate-arena-11m.

## Risultato verificato

`js/data.js::ATHLETE_OUTFITS` contiene 26 outfit: 6 base e 20 varianti.
Maestro, Pantera, Steamer e Fiamma ne hanno 5 ciascuno; Oracolo e Colosso 3.
Tutte le 20 anteprime e le 120 risorse sprite indicate dalle varianti esistono.
Fornaio è un'aggiunta Godot separata, non parte di queste 26 voci.

Le 20 anteprime sono state ispezionate visivamente. Sono illustrazioni, NON UV
texture utilizzabili direttamente sul modello. Lo script generate-outfit-assets.mjs
mostra che molti sprite sono ricolorazioni del personaggio base, anche quando
l'anteprima ha abiti completamente differenti. Verificati anche gli sprite Mythic
di Maestro e Fiamma: non riproducono rispettivamente il cappotto e le code della
giacca mostrati nelle anteprime. Occorre distinguere fedeltà allo sprite in campo
da fedeltà alla carta outfit, non promettere equivalenza automatica.

## Stato 3D attuale

| Personaggio | Runtime verificato nel codice | Conseguenza |
|---|---|---|
| Maestro | maestro.glb, 24 ossa, 1 mesh/materiale, 7,6 MiB | Base sportiva utilizzabile; UV e maschere specifiche necessarie |
| Fiamma | fiamma.glb, 28 ossa, 1 mesh/materiale, 24,4 MiB | Buona candidata per tre varianti tessili |
| Oracolo | oracolo.glb, 28 ossa, 1 mesh/materiale, 27,3 MiB | Armatura/vestito già incorporati; cambiare silhouette richiede editing |
| Colosso | colosso.glb, 28 ossa, 1 mesh/materiale, 22,6 MiB | Base gladiatore adatta a Signature; Mythic aggiunge indumenti |
| Pantera | fallback Volpe, non un corpo umano dedicato | Prima serve integrare il modello corretto |
| Steamer | fallback Volpe; registro dichiara modello assente | Prima serve creare/importare il modello corretto |

Misure lette dai GLB correnti. Confronto visivo dei quattro modelli tramite le
tavole locali già prodotte in docs/agent-work/meshy-roster-retarget; non è stato
effettuato un nuovo render in questo audit. Le tavole non provano l'assenza di
compenetrazioni in ogni animazione.

Pantera ha `art/generated/athletes/pantera/pantera-source.glb`: 35,7 MiB,
nessuno scheletro e nessuna animazione. Il vecchio percorso riggato indicato nel
registro (`tools/meshy/output/pantera/pantera-riggato.glb`) qui non esiste.
Non occorre quindi necessariamente rigenerare Pantera da zero, ma il sorgente
va verificato, ottimizzato e riggato prima di lavorare sulle varianti.

`athlete_rig.gd::uses_catalogue_recolour` abilita lo shader solo per GLB_BASE
(Volpe). `outfit_catalogue.gd::apply` sugli altri modelli registra la selezione e
ritorna true SENZA cambiare il materiale. Quindi selezionabile non significa
visivamente realizzato. Non riutilizzare la maschera della Volpe sui corpi umani.

## Classificazione delle 20 varianti

T = texture/mask/materiali; A = accessori/geometria locale; G = vestito con nuova
silhouette e pesi sullo scheletro. Sono stime progettuali, non conversioni provate.
La classificazione punta alle ANTEPRIME; replicare i soli sprite è spesso più semplice.

| Atleta | Variante | Lavoro previsto e limite |
|---|---|---|
| Maestro | Circuit | T: pannelli blu/viola e linee ciano sulla divisa corrente |
| Maestro | Legend | T+A: nero/avorio/oro, cintura/catena e colletto; disegnare tutto in texture sarebbe una semplificazione |
| Maestro | Signature | T: diagonali ciano/blu e disegni; confrontare anche polsini/fascia |
| Maestro | Mythic | G+A: cappotto, pantaloni, stivali, spallaccio; non una ricolorazione |
| Pantera | Circuit | T sul futuro modello umano, divisa blu/ciano |
| Pantera | Legend | T sul futuro modello, nero/avorio/oro |
| Pantera | Signature | T sul futuro modello, nero e graffi rossi |
| Pantera | Mythic | G+A: crop top, pantaloncini, drappo laterale e bracciali; prima completare la base |
| Steamer | Circuit | T+A sulla futura base, petrolio/menta e piccoli elementi metallici |
| Steamer | Legend | T+A sulla futura base, avorio/nero/oro, cintura e catene |
| Steamer | Signature | T sulla futura base, grafica manometri sulla maglia/pantaloncini |
| Steamer | Mythic | G+A: gilet, pantaloni sotto il ginocchio, guanti e accessori |
| Fiamma | Circuit | T: blu/ciano, stessa struttura sportiva |
| Fiamma | Legend | T: nero/avorio/oro, bordi e decorazioni |
| Fiamma | Signature | T: petrolio/lime e motivo fiamma |
| Fiamma | Mythic | G+A: maniche, giacca con code, cintura e stivali |
| Oracolo | Signature | T+G locale: costellazioni ciano, ma top corto e spalle scoperte richiedono modificare il vestito/armatura correnti |
| Oracolo | Mythic | T+A/G locale: nero/viola/ciano; verificare coprispalla e pannelli del vestito rispetto alla base |
| Colosso | Signature | T+A se necessario: cuoio scuro, metallo e dettagli arancio/emissivi; geometria già vicina |
| Colosso | Mythic | G+A: maglia chiara con maniche, verde, cintura e drappo frontale |

Nessuna delle sei basi è dichiarata copia perfetta dell'illustrazione. Pantera e
Steamer sono bloccanti per un guardaroba completo fedele; ricolorare la Volpe non
soddisferebbe la richiesta.

## Pipeline proposta

1. Prova Fiamma Circuit, Legend, Signature sul GLB attuale: maschere UV per
   tessuto/bordi/scarpe, protezione di pelle/capelli/metalli, texture dedicate ai
   motivi. Una semplice tinta piatta non riproduce i disegni delle anteprime.
2. Conservare scheletro, animazioni, scala, attacco racchetta, hitbox e id outfit.
   Nessun cambiamento alle sfide/sblocchi; niente nuovo rig per una texture.
3. Verificare fronte/retro, idle, corsa, rovescio e smash con due compagni che
   indossano outfit diversi: materiali non condivisi accidentalmente, niente
   pelle tinta o texture tremolanti. Confrontare immagine menu e risultato reale.
4. Estendere a Maestro; poi Colosso e Oracolo, con editing geometrico dove serve.
5. Completare i corpi di Pantera e Steamer prima delle rispettive varianti.
6. Mythic con abiti nuovi: preservare testa/corpo ove possibile, creare vestiti,
   trasferire pesi e verificare compenetrazioni. Evitare simulazione stoffa nella
   prima versione: deformazione con ossa/pesi già disponibili.

## Meshy e costi

Per la prova tessile non è necessaria una generazione 3D a pagamento: il lavoro
principale è UV/mask/texture e integrazione materiali. Per gli abiti complessi
Meshy è un possibile strumento di produzione di sorgenti, NON una garanzia di
vestiti già aderenti, stessa topologia o stesso rig. Prima di sceglierne un
endpoint bisogna verificarne i vincoli attuali e approvare un budget separato.
Questo audit non verifica API, prezzi o crediti e non ha letto la chiave.

Decisione consigliata: partire da Fiamma con le tre varianti tessili, conservando
la Mythic per una seconda fase. La qualità finale delle maschere resta da provare
sul modello; non è già una consegna di skin pronte.
