# Richiesta immagini 2D — corpi e capelli per "Crea atleta" (2026-09-27)

Per: Alessio, da generare in ChatGPT. Dopo, Claude le porta in 3D con Meshy
(account 2), aggiunge lo scheletro, adatta tutte le animazioni del gioco a ogni corpo e
le collega all'editor "Crea atleta" che esiste già (nome, pelle, capelli, completo).

## Come funziona la personalizzazione

Il gioco **ricolora** i modelli, con la stessa tecnica del pubblico 3D. Per questo i
colori delle immagini sono **neutri e fissi**:

| Parte | Colore nell'immagine | Nel gioco diventa |
|---|---|---|
| Maglia | grigio chiaro neutro `#dcdfe5` | il colore del completo scelto |
| Pantaloncini / gonna | grigio medio neutro `#8e939c` | una tonalità più scura dello stesso colore |
| Pelle | carnagione media, uniforme | la tonalità di pelle scelta |
| Capelli (pezzi separati) | grigio chiaro neutro `#c8c8c8` | il colore di capelli scelto |
| Scarpe | antracite scuro, suola bianca | restano così |

I corpi sono **calvi**: i capelli sono pezzi separati che il gioco appoggia sulla testa.

## Come consegnarle

Stessa cartella `asset-arene` (o una nuova `asset-atleta`), nomi **esatti** come nelle
tabelle. Quadrate 1:1, sfondo bianco puro. Rigenera se compaiono racchetta, pallina,
scritte, loghi, ombre a terra, una seconda persona, o colori diversi da quelli indicati.

---

## A. Corpi (4 immagini)

Prompt uguale per tutti, cambia solo la riga CORPO:

```
A single full-body padel athlete, {CORPO}, completely bald head with no hair at all,
neutral friendly face, standing in a relaxed A-pose with arms slightly away from the
body and empty open hands, no racket, no ball. Stylized 3D game character, clean
geometric shapes with smooth shading, flat matte materials, subtle ambient occlusion
only, no texture noise, no outlines, no cel shading, no photorealism.

Clothing, exact flat colours, no logos, no stripes, no print, no trim of other colours:
a plain short-sleeved athletic t-shirt in light neutral grey (#dcdfe5); plain athletic
shorts in medium neutral grey (#8e939c); short white sports socks; dark charcoal court
shoes with white soles. Skin: an even medium skin tone, uniform, no make-up, no tattoos,
no jewellery, no wristbands, no headband.

Front view, straight on, orthographic-looking with minimal perspective distortion, the
whole body visible with a clear margin on every side, centred, filling about 80 percent
of the square frame's height.

Lighting: even, diffused, shadowless studio lighting from the front. Background: pure
white seamless background #FFFFFF, no gradient, no floor plane, no shadow under the feet.

Square 1:1 image, sharp focus. No text, no letters, no logo, no watermark, no border,
no second person, no props.
```

| File | CORPO |
|---|---|
| `corpo_uomo_medio.png` | `adult man, average athletic build, 1.80 m tall` |
| `corpo_uomo_robusto.png` | `adult man, broad powerful build with strong shoulders and legs, 1.85 m tall` |
| `corpo_donna_media.png` | `adult woman, slim athletic build, 1.68 m tall` |
| `corpo_donna_atletica.png` | `adult woman, tall muscular athletic build, 1.75 m tall` |

Per le due donne i pantaloncini possono diventare una gonna-pantalone (skort) sempre
nello stesso grigio medio `#8e939c`: aggiungi `athletic skort instead of shorts` alla riga
CORPO se preferisci.

---

## B. Capelli (4 immagini)

Ogni immagine è **solo la capigliatura**, senza testa né viso, come una parrucca vista
da davanti leggermente di tre quarti. Prompt uguale per tutti, cambia la riga CAPELLI:

```
A single isolated hairstyle for a stylized 3D game character, {CAPELLI}, shown on its
own as a hair piece with NO head, NO face, NO neck and NO body inside it, as if it were
a wig floating in space, seen from the front rotated about 20 degrees. The hair is one
flat light neutral grey colour (#c8c8c8), matte, with simple chunky clumps and smooth
shading, no strands detail, no highlights of other colours, no outlines, no cel shading,
no photorealism.

Lighting: even, diffused, shadowless studio lighting. Background: pure white seamless
background #FFFFFF, no shadow. Centred, filling about 70 percent of the square frame.
Square 1:1 image. No text, no logo, no watermark, no head, no mannequin, no accessories.
```

| File | CAPELLI |
|---|---|
| `capelli_corti.png` | `short cropped hair with a small tidy fringe` |
| `capelli_coda.png` | `long hair pulled back into a high ponytail` |
| `capelli_ricci.png` | `short thick curly hair, rounded volume on top` |
| `capelli_chignon.png` | `hair pulled back into a neat bun at the back of the head` |

(La testa rasata non serve: è il corpo così com'è.)

---

## Cosa fa Claude dopo

1. **Controllo delle immagini** prima di spendere crediti: colori neutri, niente
   racchetta, corpo intero, testa calva.
2. **Meshy (account 2)**: per ogni corpo modello 3D + scheletro standard del gioco
   (circa 20 crediti l'uno), per ogni capigliatura modello 3D (circa 15). Totale circa
   **140 crediti**; l'account 2 ne ha 252 prima del limite di 500.
3. **Verifica della sorgente prima di usarla**, come per le animazioni: scheletro
   corretto, proporzioni, colori leggibili dallo shader.
4. **Animazioni**: tutti i colpi e i movimenti del roster adattati a ogni corpo, senza
   costi (stesso script degli atleti).
5. **Editor**: si sceglie il corpo, poi pelle, capelli, colore capelli, completo e
   colore del completo, come oggi. Il manichino attuale resta solo come riserva se un
   modello mancasse.
6. Confronto a vista con gli atleti del roster e prova in partita.
