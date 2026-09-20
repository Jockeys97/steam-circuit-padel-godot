# Asset pesanti: Git LFS e sorgenti

Stato: **attivo dal 2026-09-20**. Questa regola evita che il repository del gioco
accumuli nuovi blob binari in Git normale. Non introduce un backend nel gioco: gli
asset restano locali durante lo sviluppo e vengono incorporati nell'export Godot.

## Regola operativa

| Contenuto | Posto | Versionamento |
|---|---|---|
| Codice, scene, configurazioni e documentazione | repository principale | Git normale |
| Asset necessari per eseguire/esportare il gioco | `godot/assets/` | Git LFS |
| Sorgenti e output di authoring Meshy | `art/generated/`, `meshy/`, `tools/meshy/output/` | Git LFS |
| Cache Godot, screenshot, render di prova e build | directory già ignorate | mai in Git/LFS |

Le estensioni e le directory vincolate sono dichiarate in [`.gitattributes`](../../.gitattributes).
Non usare `git add -f` per aggirarle.

## Primo clone o cambio macchina

```sh
git lfs install --local
git lfs pull
npm run assets:verify
```

Il primo comando abilita il filtro solo per questa copia. Il secondo scarica gli oggetti
LFS referenziati dal commit corrente. Il terzo controlla che gli asset pesanti già in
indice rispettino il contratto.

Prima di creare un commit che aggiunge arte:

```sh
git add godot/assets/athletes/nuovo-atleta.glb
git lfs ls-files
npm run assets:verify
```

`git lfs ls-files` deve mostrare il nuovo file. Il controllo rifiuta ogni binario di almeno
5 MiB dentro le directory di asset che non sia un puntatore LFS. In CI il checkout scarica
gli oggetti LFS e il controllo viene rieseguito.

## Compatibilita' e migrazione della storia

Gli asset già presenti prima di questa policy sono elencati in
[`lfs-legacy-large-assets.txt`](lfs-legacy-large-assets.txt): restano blob Git per non
riscrivere il lavoro condiviso. La lista non accetta nuovi ingressi.

La conversione di quegli oggetti con `git lfs migrate import` richiede una finestra
concordata: backup/cloni nuovi per tutti, freeze dei push, esecuzione su mirror pulito,
force-push coordinato e verifica di clone + export. Non eseguire la migrazione da un
checkout con modifiche locali o mentre altri stanno lavorando.

Quando il volume degli originali superera' il budget LFS, li spostiamo in un repository
privato `steam-circuit-padel-assets` con LFS, pubblicando nel repository del gioco un
manifest con versione e SHA-256. Il runtime continua a usare esclusivamente la copia
versionata sotto `godot/assets/`: nessun download avviene nel gioco del giocatore.
