# Verdetto CEO — payload del colpo differito

Verificato personalmente da Opus 5 (orchestratore), non su auto-dichiarazione dei worker.

## Il difetto
Quando il rilascio di A cade su un frame senza sub-step, il latch conserva il flag `hit`
ma non la variante richiesta. La simulazione riceve `auto` invece di `drive`, la finestra
utile si accorcia da 0.9 s a 0.28 s e sul bench di contatto la palla arriva a finestra chiusa.

## Prova eseguita dal CEO (due run sullo stesso bench)
| match_controller.gd | esito |
|---|---|
| con patch (`781fe657…`) | PASS 6/6, exit 0, colpo finale `drive`, contatto riuscito |
| produzione, patch rimossa (`e1c75caf…`) | FAIL 2/6, exit 1, colpo finale `serve` — non parte |

## Test cieco intercettato e corretto
Il test consegnato nel lancio precedente stampava PASS 5/5 anche a patch rimossa:
il ramo di fallimento era irraggiungibile sul bench e il campo controllato aveva il nome
sbagliato (`queued_shot_payload` invece di `queued_hit_payload`). Rispedito indietro,
ora ha un controllo rosso eseguito e riproducibile.

## Stato
Patch e test vivono solo in /tmp/padel-shot-payload-fix/godot. Produzione invariata,
hash di baseline riverificati. Promozione NON eseguita: attende decisione dell utente.

## Comandi
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /tmp/padel-shot-payload-fix/godot
$GODOT --headless --path . --script res://tests/input/deferred_shot_payload_test.gd
