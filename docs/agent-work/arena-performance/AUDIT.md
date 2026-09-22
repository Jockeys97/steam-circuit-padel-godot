# Audit prestazioni arene — 22 settembre 2026

## Esito e confidenza

Nessuna ottimizzazione applicata. Aggiunti soltanto due script diagnostici e questo
rapporto. Target: 11m, codex/integrate-arena-11m; preservate le modifiche concorrenti.

Il costo della geometria condivisa è il candidato meglio supportato. Non è ancora
dimostrata la causa di ogni scatto intermittente segnalato dall'utente. Non assegnare
una classifica FPS alle arene usando questi dati.

## Metodo

Apple M4, Godot 4.7.2, renderer Compatibility/OpenGL su Metal. Match.tscn reale,
modelli caricati, camera default, salvataggio diagnostico separato. Sei arene:
Officina, Torii, Medina, Carioca, Aurora, Egeo. 720p e 1080p, scena statica e breve
sequenza con giocatore scriptato. 54 finestre da circa due secondi, 20 frame di
assestamento tra interventi. Per Torii/Medina/Egeo: un fattore spento alla volta,
seguito dal ripristino della configurazione originale. Tutte le modifiche sono
transitorie, nel processo diagnostico, mai nelle preferenze del giocatore.

Due tentativi preliminari scartati: su macOS i contatori di rendering rimanevano
congelati quando la finestra smetteva di renderizzare, mentre il ciclo degli eventi
proseguiva. La prova conservata usa RenderingServer.force_draw(false): i contatori
ora reagiscono alle esclusioni. Può effettuare lavoro aggiuntivo rispetto al loop
normale. Tempi e throughput NON sono gli FPS reali in partita né benchmark GPU puri.

Un altro test Godot era attivo all'inizio (~59% di un core in un campione), ma era
terminato prima del run conservato. Il gioco dell'utente è rimasto aperto. Finestre
brevi, ordine fisso, cache riscaldate progressivamente e carico variabile limitano
la precisione. TIME_PROCESS nei dati grezzi è campionato lentamente e può contenere
un picco precedente: non viene usato per attribuire il collo di bottiglia alla CPU.

## Evidenze robuste

Primitive renderizzate nella baseline 1080p (contatore Godot, non triangoli unici
degli asset, include passaggi di rendering): Officina 2,43 M; Torii 2,54 M; Medina
2,58 M; Carioca 2,58 M; Aurora 2,55 M; Egeo 2,56 M.

Nascondere soltanto Bleachers e ArenaProps elimina **2.072.760 primitive** in tutte
le tre prove A/B. Le draw call scendono soltanto di nove: qui è soprattutto densità
geometrica, non migliaia di oggetti separati.

| Arena | Mediana ripristinata ms | Senza tribune/props ms | Differenza osservata |
|---|---:|---:|---:|
| Torii | 45,09 | 28,14 | -38% |
| Medina | 24,37 | 16,79 | -31% |
| Egeo | 23,72 | 14,73 | -38% |

Sono confronti diagnostici ravvicinati, NON guadagni promessi con modelli ottimizzati:
nascondere tutto dà un limite indicativo, non una soluzione finale. Il miglioramento
coerente nelle tre arene rende questo il primo intervento da provare.

Ombre globali spente: draw call 407→270 (Torii), 465→300 (Medina), 424→280 (Egeo).
Mediane circa -20%, -16%, -24% rispetto al successivo ripristino. Non eliminare le
ombre globalmente: valutare solo i caster decorativi. Tribune e ArenaProps hanno
già cast_shadow=false, quindi non va proposta come nuova correzione.

Glow/SSAO/nebbia: risultati non sufficientemente stabili per attribuire un costo
affidabile o proporre tagli. Una proprietà abilitata non dimostra da sola il costo
effettivo del relativo passaggio in questo renderer.

## Scatti e caricamento

Costruzione sincrona del match: 7,05 s Officina; 11,02 Torii; 10,95 Medina; 8,14
Carioca; 9,30 Aurora; 9,27 Egeo. Cache e ordine di avvio differenti: valori indicativi,
non confronto cold-start equo. Il loader GLB di arena_kit è sincrono ma memorizza
le risorse: può pesare sul caricamento, non è prova che rilegga file a ogni colpo.

Picchi di centinaia di ms osservati anche nell'Officina, ma non attribuiti mediante
tracing a shader, texture, driver o simulazione. L'audit non certifica assenza di
problemi CPU o memoria. Il processo riporta leak RID/risorse alla chiusura: vanno
separati da una crescita verificata durante una singola partita, qui non misurata.

Test separato low_contact_cost_audit, headless, sei modelli base, drive/backhand/slice:
prima preparazione clip **2,105–7,287 ms**, riuso **0,013–0,117 ms**. Questo isola il
costo CPU della creazione, non compilazione shader o upload GPU; non include Mythic.
Non giustifica attribuire alle flessioni picchi da 200–800 ms. Precalcolarle resta
un affinamento secondario, non la soluzione principale dimostrata.

## Decisione proposta, non eseguita

1. Versioni meno dense delle tribune/coperture/cartelloni, conservando materiali,
   silhouette e originali. Stessa camera, screenshot prima/dopo e nuova prova A/B.
2. Ridurre selettivamente le ombre della scenografia lontana, preservando giocatori,
   palla e contatto col terreno. Verificare differenza visiva prima di accettare.
3. Precaricamento/preriscaldamento durante la schermata di avvio; misurare di nuovo
   i primi scambi con tracing per identificare i picchi, non nasconderli nella media.

Prima di dichiarare un obiettivo FPS: prova nativa non forzata, finestra realmente
renderizzata, altri test chiusi, sessioni più lunghe ripetute in ordine alternato,
risoluzione/camera e roster dell'utente. Nessun intervento sul gameplay suggerito.

## Riproduzione

`godot --path godot --script res://tests/arena_performance_audit.gd`

`godot --headless --path godot --script res://tests/low_contact_cost_audit.gd`

Entrambi exit 0; primo AUDIT_DONE rows=54, secondo 18 combinazioni × 3 chiamate.
Log e JSON conservati accanto a questo documento. Nessun commit.
