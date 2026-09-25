# Feedback 3D → endpoint esistente

## Contratto

- Riutilizzare `https://steam-circuit-padel-pro.vercel.app/api/feedback`, che accetta `POST` JSON `{ "entries": [...] }` e risponde `{ "ok": true, "received": n }` solo dopo la consegna. Il webhook Discord resta una variabile d'ambiente del server; mai nel client Godot.
- Conservare il formato della coda `feedback` e i metodi/test del `FeedbackScreen` esistente. Salvare prima di qualunque richiesta HTTP; segnare `sent` solo dopo una conferma coerente. Errori, timeout e risposte inattese lasciano il messaggio in coda e mostrano un esito onesto.
- Evitare richieste concorrenti e inviare al massimo una voce per POST: l'API esistente limita il webhook Discord a 1900 caratteri per chiamata e accetta massimo 20 voci. Al riavvio ritentare le voci pendenti una volta, senza loop aggressivi.
- Non inviare feedback reali durante i test; usare un trasporto simulato. Non cambiare endpoint, webhook, salvataggi, prezzi, menu non correlati, né creare commit/push/deploy.

## Fasi

1. Implementare il trasporto HTTP asincrono e i test con risposta simulata (successo, rifiuto, rete assente, più messaggi, nessuna richiesta duplicata).
2. Collegarlo al menu 3D e allo stato UI del feedback, inclusa la ripresa della coda all'avvio; preservare il percorso di copia manuale e il seam sincrono usato dagli audit.
3. Verificare i test mirati della schermata, del trasporto e della navigazione; rivedere il diff senza traffico reale o modifiche ai dati del profilo.

## Rischi e limiti

La funzione server 2D tronca il testo Discord a 1900 caratteri: questo lavoro non cambia il comportamento del server. L'effettiva configurazione del webhook su Vercel non e verificabile dai test locali.
