# Richiesta immagini 2D — pubblico 3D (2026-09-25)

Per: Alessio, da generare in ChatGPT. Dopo, Claude le porta in 3D con Meshy (account 2,
circa 15 crediti l'una), le ripete sulle tribune e le ricolora per ogni arena.

## Come consegnarle

Stessa cartella `asset-arene`, nomi **esatti**: `crowd_fan_1.png` … `crowd_fan_5.png`.
Quadrate 1:1, sfondo bianco. Rigenera se compaiono sedia, panca, ombre, scritte o due
persone.

**Importante per la ricolorazione**: la **maglia** deve essere **grigio chiaro neutro**
(quasi bianca), senza loghi né righe. È la parte che il gioco tinge con i colori
dell'arena. Pantaloni blu scuro, scarpe scure.

## Il prompt (uguale per tutti, cambia solo la riga SOGGETTO)

```
A single isolated {SOGGETTO}, full body, sitting upright as if on a stadium bench, knees
bent at a right angle, thighs horizontal, feet flat, the bench itself NOT shown — nothing
under the person. Read as one connected solid form. Stylized low-poly 3D game character,
chunky proportions, clean geometric shapes with smooth shading, gently rounded edges,
simple readable face, flat matte materials, subtle ambient occlusion only, no texture
noise, no outlines, no cel shading, no photorealism.

Clothing: plain light neutral grey t-shirt (#dcdfe5) with no logo, no print, no stripes;
dark navy trousers; dark trainers. Matte cloth and skin. All surfaces matte — no gloss,
no metallic highlight.

Front three-quarter view rotated about 20 degrees off-axis, orthographic-looking with
minimal perspective distortion, the whole person visible with a clear margin on every
side, centred and filling 70 to 90 percent of the square frame.

Lighting: even, diffused, shadowless studio lighting from the front, uniform ambient
fill, no cast shadow.

Background: pure white seamless background, #FFFFFF, no gradient, no floor plane, no
shadow under the person.

Square 1:1 image, sharp focus edge to edge, clean readable silhouette.

No chair, no bench, no seat, no stool, no text, no letters, no logo, no watermark, no
border, no second person, no animals, no scenery.
```

| File | SOGGETTO |
|---|---|
| `crowd_fan_1.png` | `adult man sports fan with short hair, hands resting on his knees, relaxed and watching` |
| `crowd_fan_2.png` | `adult woman sports fan with a ponytail, clapping her hands in front of her chest, smiling` |
| `crowd_fan_3.png` | `teenage boy sports fan wearing a plain baseball cap, one fist raised above his head cheering` |
| `crowd_fan_4.png` | `sports fan with curly hair holding a plain grey scarf stretched above the head with both hands` |
| `crowd_fan_5.png` | `older sports fan with a grey beard, arms crossed, leaning slightly forward, focused` |

## Cosa faccio io dopo

- Meshy image-to-3D, smart topology **~1.500 triangoli** ciascuno (account 2).
- Pubblico ricostruito con i 5 tipi mescolati sui seggiolini delle tribune, maglie e
  sciarpe tinte con i colori di ogni arena.
- Reazioni nel codice, senza scheletro: ondeggiano, si sporgono, saltano sul punto,
  qualcuno segue la palla con il busto.
- Confronto prima/dopo con la telecamera di gioco e controllo del peso.
