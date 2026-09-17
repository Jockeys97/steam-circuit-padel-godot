# Tasto A: mappa dell'indagine

Parent map: ../../wayfinder/map.md

## Destination
Confrontare il percorso completo del tasto A, senza cambiare il gioco per far passare la prova.

## Execution override
This focused diagnostic mission includes harness implementation, not gameplay changes. Existing project map remains authoritative for broader product decisions.

## Frontier
- [Reference oracle](tickets/reference-oracle.md): claimed by Reference.
- [Port replay](tickets/port-replay.md): claimed by Port; integration blocked by Reference oracle.
- [Independent review](tickets/independent-review.md): audit unblocked; certification blocked by integrated proof.

## Fog
Hardware polling and visual latency are not proven by a scripted replay. Exact player symptom remains unspecified. A code-path divergence, if found, is not automatically its cause.

## Out of scope
Gameplay fixes, feel approval, arena/camera changes, export, git publication.

## Latest evidence
Input/queue divergence reproduced by CEO in integration/summary.json. Final shot and feel unproven. Certification blocked on comparator false-green paths; independent review active.

## Final disposition
Reference and Port replay artifacts delivered; queue divergence independently reproduced and reviewed. Full harness certification and final-contact/feel gates remain open. Comparator nested-field completeness residual is recorded in board-20260917.md. Launch budget exhausted; stop here without gameplay changes.
