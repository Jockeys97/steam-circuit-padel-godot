# Campione B — adattamento locale

Questo prototipo opt-in usa `pilot_rig.gd`, derivato dal rig del gioco. Non cambia il roster, i personaggi salvati o la schermata di creazione. Gli originali Meshy restano intatti nella cartella `art/character-creator/proposte-qualita/B-produzione/meshy-pilot`.

## Adattamenti

- Il rig corrente supporta già i 24 giunti Meshy: non vengono aggiunte quattro ossa inutilizzate per simulare la conformità allo standard del roster.
- Camminata originale; corsa e undici colpi esistenti riadattati tramite le rotazioni globali relative alla posa di riposo del corpo donatore. Le lunghezze degli arti del nuovo corpo restano invariate; solo il bacino trasferisce la traslazione, proporzionata.
- Capelli montati con BoneAttachment3D su Head, con scala e posizione tarate sul nuovo cranio; materiale castano indipendente.
- Nessuna richiesta API e nessun credito Meshy aggiuntivo.

## Verifica

Eseguire dalla radice del repository:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --audio-driver Dummy --script res://prototypes/creator_b/check_pilot.gd
```

Risultato grafico: **115 controlli, 0 fallimenti**, Godot 4.7.2. Verificati idle, walk, run e undici colpi: esistenza delle clip, effettiva variazione delle pose, risoluzione delle tracce, trasformazioni finite su quattro istanti e aggancio dei capelli alla posa finale modificata. L'aggancio alla mano è disponibile; non è una prova della collisione racchetta/palla.

Gli screenshot in `out/` sono render del modello e delle animazioni in Godot. Visionati anche volto e profilo, dritto, rovescio e smash. Il test dell'aggancio viene effettuato nel segnale skeleton_updated, prima del ripristino della cache da parte dei modificatori: misurarlo nel frame successivo produce falsi scostamenti.

## Limiti

Il prototipo rimane separato, ma il corpo è ora integrato nel creatore come **Uomo stilizzato B** (`uomo_b` / `cc_uomo_b`), senza sostituire le quattro opzioni precedenti. Scegliendo **Corti** si usa l'acconciatura B calibrata. Corpo e capelli sono copiati in `assets/custom_character`; `bake_runtime.gd` salva camminata, corsa e undici colpi negli asset del gioco, senza dipendenze runtime dalla cartella del prototipo o da `art`.

Il test `custom_character_flow_test.gd -- --body-b` verifica editor, salvataggio e riapertura, selezione, caricamento in partita e rivincita. L'anteprima grafica della ricolorazione è in `docs/agent-work/character-creator/evidence/editor-b.png`. La copertura automatica non garantisce l'assenza di clipping in ogni fotogramma o con tutte le acconciature; non viene dichiarata conformità del GLB allo standard roster a 28 ossa.
