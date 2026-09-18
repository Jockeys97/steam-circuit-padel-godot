# Reference-image prototyping for Meshy image-to-3D — environment props
Date: 2026-09-18. Scope: how to make the INPUT IMAGES that will be dragged into Meshy
image-to-3D as environment props for the five world arenas. Not the concept stills —
that work is frozen (`art/concepts/world-arenas-r1/`, `BRIEF.md`, `astra-prompting-scan.md`
covers the Astra plan prompt, not image generation). Producer of the images:
Hermes `image_gen`, provider `openai`, model `gpt-image-2.5-flare` (the model that made
the stills). Consumer: Luca, manually, one image (or one sheet) per asset slot.

Read-only scan. All claims below carry a URL; each is tagged `[doc]` (vendor
documentation), `[vendor-blog]` (Meshy-authored marketing/tutorial page), `[third-party]`
(independent writeup, no vendor byline), `[video]`, or `[inference]` (my reasoning from the
cited facts — treat as a hypothesis to test, not a fact).

## Sources

| # | Source | Date | Type |
|---|--------|------|------|
| S1 | help.meshy.ai/en/articles/15723519-how-to-get-better-image-to-3d-results-in-meshy | no absolute date on page; retrieved 2026-09-18 | doc (help center) |
| S2 | help.meshy.ai/en/articles/9996860-how-to-use-meshy-image-to-3d | "Updated over 2 weeks ago" (as of 2026-09-18) | doc |
| S3 | help.meshy.ai/en/articles/16102789-meshy-multi-view-best-practices-angles-and-images | "Updated over a week ago" (2026-09-18) | doc |
| S4 | help.meshy.ai/en/articles/12634481-how-to-use-multi-view | no absolute date | doc |
| S5 | help.meshy.ai/en/articles/16102614-how-to-keep-characters-consistent-in-meshy | "Updated over a week ago" (2026-09-18) | doc |
| S6 | help.meshy.ai/en/articles/14234196-how-to-prevent-text-from-being-engraved-into-your-3d-model-geometry | "Updated over a week ago" (2026-09-18) | doc |
| S7 | help.meshy.ai/en/articles/15723825-how-to-fix-bad-meshy-generations-and-prompt-drift | "Updated over a week ago" (2026-09-18) | doc |
| S8 | help.meshy.ai/en/articles/16103167-meshy-prompt-templates-for-3d-assets | "Updated over a month ago" (2026-09-18) | doc |
| S9 | help.meshy.ai/en/articles/11972484-best-practices-for-creating-a-text-prompt | "Updated over 3 weeks ago" (2026-09-18) | doc |
| S10 | docs.meshy.ai/en/webapp/image-to-3d | undated | doc |
| S11 | docs.meshy.ai/en/api/image-to-3d | undated | doc (API) |
| S12 | docs.meshy.ai/en/api/multi-image-to-3d | undated | doc (API) |
| S13 | docs.meshy.ai/en/webapp/guides/choosing/generation-method | undated | doc (decision matrix incl. multi-gen consistency ratings) |
| S14 | docs.meshy.ai/en/webapp/guides/use-cases/game-assets | undated | doc |
| S15 | meshy.ai/tutorials/3d-game-environment-props | "2026 Guide", no absolute date | vendor-blog (env-prop workflow) |
| S16 | meshy.ai/tutorials/multi-view-image-to-3d | "2026 Guide", no absolute date | vendor-blog |
| S17 | meshy.ai/tutorials/image-to-3d-model-complete-guide | "2026 Guide", no absolute date | vendor-blog |
| S18 | meshy.ai/blog/meshy-5-image-to-3d | Posted May 20, 2025 | vendor-blog (terrain chunks, avoid list) |
| S19 | meshy.ai/blog/sketch-to-3d | Posted April 8, 2026 · updated August 21, 2026 | vendor-blog |
| S20 | hackernoon.com/a-practical-workflow-for-turning-photos-into-printable-stl-files-with-meshy | June 5, 2026 (Meshy team byline, disclosed in article) | vendor-authored, with reproducible numbers |
| S21 | thegamehaus.com/gamingg/how-game-designers-can-use-image-to-3d-tools-to-create-game-ready-assets/2026/07/21/ | 2026-07-21 | third-party, hands-on |
| S22 | dailytopai.com/article/how-to-create-3d-models-in-seconds-with-meshy-ai-v6-step-by-step-guide-98.html | 14 May 2026 | third-party walkthrough |
| S23 | youtube.com/watch?v=L4Z_4ERfh3Q ("How To Create Level Meshy AI (2026 Guide)") | no publish date exposed to extraction; retrieved 2026-09-18 | video (third-party, undated) |
| S24 | meshy.ai/3d-tools/ai-background-remover | undated | doc (what a clean cutout is for) |
| S25 | Hermes `image_generate` tool schema (local, `tool_describe`) | 2026-09-18 | local tool contract |
| S26 | meshy.ai/tutorials/text-to-3d-model-tutorial | "2026", no absolute date | vendor-blog (scene-composition limits) |
| S27 | github.com/meshy-dev/game-asset-pipeline | undated | vendor-affiliated repo (API usage patterns) |

## 1. Prompt recipe for a single prop image

Meshy's guidance for AI-generated reference images is explicit: "Many users generate their
reference image with tools like Midjourney or DALL-E before uploading to Meshy... add these
to your image generation prompt to get a Meshy-ready reference in one shot: White
background — skips the background removal step entirely; Neutral, even lighting — avoids
shadow bake-in on the final 3D texture; Front-facing pose — gives Meshy the clearest view of
the subject's full silhouette. Example prompt addition: *'white background, studio lighting,
front view, product photography style'*" [S1]. That is the entire documented recipe — one
sentence. Everything below beyond it is either framing rules from the same checklist or
`[inference]`.

### 1a. Subject description

- Name the subject explicitly, first, with 3–5 concrete modifiers. Meshy: "Lead with the most
  important subject and limit your modifiers to 3–5 key descriptors. Use the Subject → Style
  → Details structure" [S7]; "Terms earlier in the prompt carry more influence" [S9].
- Read as ONE closed silhouette. Meshy's failure example for image-to-3D is "Full scene photo
  with multiple objects, cluttered background → AI merges multiple objects into one distorted
  mesh" [S10]; "if the image contains more than one subject, the model may merge them. Keep
  each generation focused on a single object" [S2].
- Do not describe the prop's *use context* (a lantern hanging on a wall, a palm beside a
  court). Spatial relationships and scene props do not survive mesh extraction — Meshy's own
  text-to-3D guidance lists "Multiple unrelated objects in one prompt", "Plural nouns" and
  "Relative spatial positioning ('next to', 'behind', 'on top of'). Spatial relationships
  rarely survive mesh extraction" [S26].
- Avoid thin structures. Meshy lists "Very fine details — thin features like hair strands,
  jewelry chains, or intricate surface patterns are difficult to reconstruct accurately in 3D
  from a single image" [S2]. For our kit this bites: carioca's cable-car line (`cable`), thin
  net posts, torch flames, individual flower stems. Model them as thicker solids or plan to
  build them procedurally in Godot.
- Avoid transparency/reflection in the subject: "Highly transparent or reflective objects
  (glass, mirrors) are difficult to reconstruct — use opaque references instead" [S1]. Our
  glass cage is NOT a prop (it stays procedural) — good.

### 1b. Camera / view angle per prop class

Meshy documents only two angle rules total: "Use a front-facing or slightly angled view for
the best 3D reconstruction" and "Avoid extreme top-down or bottom-up angles — these limit the
model's ability to infer depth" [S1]; multi-view wants "views at least 45°–90° apart" [S2]
and a "true side at 90°" [S2]. There is **no documented per-prop-class angle recipe** — the
per-class table below is `[inference]`, derived from those two rules plus the fact that a
single image must imply the unseen sides.

| Class | Arena examples | View to request | Why |
|---|---|---|---|
| Architecture | torii colonnade, pagoda, horseshoe arch gate, minaret, windmill, Santorini cube cluster | Front-on or 3/4 at 15–30°, camera at mid-height, verticals parallel (orthographic-looking, minimal perspective) | Front/¾ gives depth cues without the extreme convergence Meshy warns against [S1]; architecture is mostly extruded profile, so a clean elevation reads |
| Medium props | stone lanterns, brass lanterns, planters, barrels, palm trunk, crate, bollard | 3/4 at 15–30° off-axis, slight downward tilt (5–10°), subject centred | ¾ view exposes two faces, which is the documented best case for a single image [S1][S17] |
| Small props | small lanterns, cups, padel-adjacent trophies, signboards | Same as medium, framed tighter — the 70–90% fill rule [S1] matters more when the object is small; "small subjects lose detail" [S17] | Detail budget per pixel |
| Foliage clusters | date palm crown, fan palm, bougainvillea patch, petal cluster, snow-covered rock pile | Front-on, flat frontal silhouette, treat the cluster as one blob; thicken fronds/leaves; do NOT ask for individual strands | Meshy: fine/thin structures reconstruct poorly [S2]; "pile of snow-covered rocks" is Meshy's own documented terrain-chunk example [S18] |

Two project-specific consequences `[inference]`: (a) the game camera is a fixed down-court
broadcast preset (`BRIEF.md`, "Framing mandate"), so each prop is always seen from
approximately one direction — request the view that the gameplay camera sees, not a neutral
turntable view; (b) Meshy's "Focus on Individual Terrain Chunks... A cliff wall, A mountain
peak, A pile of snow-covered rocks. You can later combine these chunks in software like Unity
or Blender to build a full environment" [S18] is the closest thing Meshy documents for
environment assets, and it endorses the chunk-per-prop plan we are already on.

Also documented, and relevant to the *set*: meshy.ai's own environment-prop tutorial says to
generate the whole scene first and extract props from it ("image models keep style and quality
more consistent when they draw a complete picture. A lone object on a white background often
comes out generic") [S15]. That contradicts the per-prop isolation rule everywhere else, and
it is a vendor-blog claim, not a help-center rule. Our resolution: keep the per-prop white
background (S1/S2/S10 all require it for the *input*), and recover the lost style context via
the style block + reference images in §3.

### 1c. Background rules

Documented, in order of strength:

- "Use a plain white or transparent background for the cleanest object isolation" and "Avoid
  reflective or gradient backgrounds — they can bleed into the model's texture" [S1].
- "Background: White or transparent (PNG)" in the recommended-settings table; "PNG
  (preferred) or high-quality JPG" [S1]. Formats accepted by Meshy: `.png .jpg .jpeg .webp`,
  20 MB (workspace) / 100 MB (API) [S2][S11].
- White is preferred over transparent for AI-generated references specifically because it
  "skips the background removal step entirely" [S1]; Meshy's own background-remover page
  agrees a "clean transparent-background cutout is the recommended input" [S24] but that is one
  extra manual step for Luca per image.
- Warned-against: busy/cluttered backgrounds [S2][S10], low contrast between subject and
  background ("busy background or low contrast between the subject and surroundings" → lumpy
  geometry) [S1], backgrounds "close to the object's color" [S16], backgrounds not removed in
  *other* multi-view slots [S2][S4].
- Practical instruction to the image model: "pure white (#FFFFFF) seamless background, no
  gradient, no floor line, no horizon, no cast shadow, no reflection, no vignette" — this is
  the plain-language expansion of "plain white background" [S1] `[inference]`.
- **egeo trap**: Santorini's whitewashed cubes and the noon sky are both near-white. A pure
  white subject on a pure white background is exactly the low-contrast case Meshy warns about
  [S1]. Fix in the prompt: give the white geometry a visible edge — the cobalt dome, the
  grey-stone base, or the arena's `#d9d2c4` stone tone — so the silhouette reads; or request a
  transparent (RGBA PNG) background for that arena's props only, and accept the one extra
  background-removal step. `[inference]` — worth one probe image before committing to a whole
  arena.

### 1d. Lighting phrases that avoid baked shadows and reflections

Documented: "Use even, diffused lighting with no harsh shadows. Avoid strong directional
light — shadows bake into the texture and make it look flat in other scenes. Studio-style or
soft-box lighting gives the best results" [S1]. "Neutral, even lighting — avoids shadow
bake-in on the final 3D texture" [S1]. Recommended-settings table: "Lighting | Even, diffused
| Prevents shadow bake-in on texture" [S1]. Independent corroboration: "Harsh shadows get
baked into the texture as fake surface detail" [S17]; "Even, diffused lighting... Harsh
shadows read as geometry" [S16]; "Shadows on or near the object read as part of the
silhouette" [S20]; "severe... Input image has shadows or dark areas → Black patches on model
surface" [S10].

Phrases to include (each maps to one of the above):
`even diffused soft lighting` · `flat, shadowless studio light` · `soft-box / product
photography lighting` · `uniform ambient light from the front` · `no cast shadow on the
ground` · `no rim light` · `no bounce light from below`.

Phrases to ban from prop prompts: `cinematic lighting` · `dramatic shadows` · `golden hour`
· `rim light` · `volumetric light` · `god rays` · `backlit` · `reflective floor` ·
`strong highlights`. All of these are Meshy-documented failure inputs [S1][S16][S18] or direct
inversions of them `[inference]`.

**Key synthesis for our five arenas** `[inference]`: the arena mood (dusk, golden hour, noon,
night) belongs in the **colour and material tokens**, never in the lighting tokens. A prop
lit for golden hour will bake an orange gradient into its base colour and then fight the
arena's own glow when Godot re-lights it. Meshy does offer a de-lighting switch — API
`remove_lighting`, default `true`, "Removes highlights and shadows from the base color
texture, producing a cleaner result that works better under custom lighting setups"
[S11] — but that is a safety net, not a licence to prompt for dramatic light.

### 1e. Negative constraints — and where they must live

Meshy contradicts itself on negative prompts, and the contradiction matters:

- "At the moment, Meshy does not support negative prompts. Instead of trying to exclude
  elements, focus on positive descriptors" [S9].
- "Use the negative prompt field to explicitly exclude unwanted elements — extra limbs,
  floating geometry, or a specific material you don't want" [S8].
- "Use negative prompts to exclude unwanted elements (e.g. 'no text, no blur, no extra
  limbs')" [S7].
- The API exposes `negative_prompt` for text-to-3D in vendor-affiliated material [S27].

Resolution `[inference]`: for **image-to-3D** this is mostly moot, because Meshy says the
image does the work — "In Image to 3D, your reference image does most of the work — a short
supplementary prompt can still help clarify style or material, but detailed template formulas
are less critical" [S8] and "Overly long prompts can dilute the influence of your reference
image" [S1]. Therefore **all negative constraints must be enforced in the image generator's
prompt (gpt-image-2.5-flare), not in Meshy's text box.** Constrain the pixels; don't argue
with the reconstructor.

Negative list to carry in every prop prompt: `no text, no letters, no numbers, no watermark,
no signature, no logo, no caption, no UI, no border, no additional objects, no second subject,
no people, no hands, no animals, no background scenery, no floor, no shadow, no reflection, no
gradient background, no depth of field, no motion blur, no vignette, no duplicate parts`.
Derived from [S1] (cropped/bleed/gradient), [S6] (text becomes engraved geometry),
[S16] (watermarks and captions overlaid on the photo), [S18] (text in the image "can confuse
the model and lead to inaccurate shapes"; multiple separate objects; "Excessive environmental
effects — smoke, fog, magical particles"), [S10] (multiple objects merge).

## 2. Resolution and framing rules

Verified against Meshy's own numbers, which do **not** agree with each other:

| Claim | Where Meshy states it | Verdict |
|---|---|---|
| 70–90% subject fill | "Subject fill \| 70–90% of frame \| Maximizes usable detail" — recommended-settings table [S1] | **Documented, exact.** Use it. |
| Nothing touching the edges | "The object is cropped or clipped — Reframe your image so the full subject is visible with a small margin around all edges. No part of the object should touch or extend beyond the image boundary" [S1]; "Make sure the subject is centered in each uploaded image with adequate padding around it — avoid subjects that touch or bleed to image edges" [S4] | **Documented.** Two independent help articles. |
| 1024 px floor | "at least 512 × 512 px; 1024 × 1024 px or higher is ideal" [S1]; "resolution ≥ 512×512" [S10]; "at least 1024px on the short side (2048px+ for Refine mode)" [S17]; "At least 1040 x 1040 px" [S16]; "Aim for images over 1040x1040px" [S18]; "below 1024×1024, the edges go soft" [S20] | **512 is the documented minimum; 1024 is the documented recommendation.** The "1040" figure appears only in Meshy's marketing/tutorial pages, not the help center or API docs. Treat 1024×1024 as the practical floor and 2048 as the target if Refine/Meshy 7+ is used. |

Other framing constraints worth encoding: "Fill the frame — your subject should take up most
of the photo; small subjects lose detail" [S17]; "One object per photo" [S16]; square beats
16:9 here — nothing in Meshy's guidance asks for a wide aspect, and a 16:9 frame at 70–90%
subject fill wastes pixels `[inference]`. The concept stills were 16:9 because they were
scenery; prop images should be **square 1:1** `[inference]`.

For our pipeline: Hermes `image_generate` accepts an `aspect_ratio` of `square` and returns
one image per call [S25]. Confirm the delivered pixel dimensions on the first probe before
committing a batch — the tool schema does not state output size, and 1024 is only a
*recommendation* from Meshy, not enforced by it [S1][S25] `[unverified]`.

## 3. Keeping a SET coherent across many props and five arenas

### 3a. What Meshy documents about consistency

Meshy is explicit that it has no memory: "Meshy doesn't retain a persistent 'character
identity' between separate generations... Each generation in Meshy is produced independently,
so 'consistency' means deliberately feeding the same visual anchors (reference images,
prompts, and textures) into every generation rather than relying on the model to remember a
character across sessions" [S5]. The four documented habits that transfer directly to props:

1. "Keeping the reference framing, lighting, and color palette consistent across generations
   is the single biggest lever for a matching look" [S5].
2. "Keep a short written reference of the character's defining details (colors, accessories,
   proportions) and reuse that exact wording in every prompt. Small wording changes between
   generations are a common cause of visual drift" [S5]. → Verbatim style block, never
   paraphrased.
3. "Reuse or reapply the same texture set across pose variants instead of letting each
   generation retexture independently" [S5]. → For props, the analogue is the API
   `texture_image_url` / `texture_image_urls` steering texture from a reference image
   [S12][S19].
4. "Export each variant with the same scale and orientation settings" [S5].

Meshy's own consistency rating for the two methods we are choosing between: Image to 3D
★ ★ ★ ★ ☆ vs Multi-view ★ ★ ★ ★ ★ on the "Consistency (multi-gen)" row of its decision matrix
[S13] — the vendor concedes single-image is the weaker of the two for set coherence. Weigh
that against the cost per arena in §5.

### 3b. Reusable style block — design

Two independent practitioner writeups converge on a three-layer structure that maps cleanly
onto a prop kit `[third-party]`: a locked identity block pasted verbatim ("lock 5 to 7
identity phrases... do not rephrase them, do not paraphrase them, copy and paste them
exactly"), plus a fixed prompt order "[Identity block] + [Action/pose] + [Setting/environment]
+ [Style block] + [Quality modifiers]", plus a saved reference image
(pixel4it.com/prompt-ai-image-tools-consistent-character/). For props, the identity block and
the style block collapse into one: the prop's own name + the shared style tokens. That is what
the template in §6 does.

Per-arena tokens come straight from our own frozen `BRIEF.md` (sky stops, apron tone, glow
accent, material language) — that file is the single source of truth and should not be
re-derived here:

| Arena | Palette tokens (verbatim from BRIEF) | Material token | Avoid in prop prompts |
|---|---|---|---|
| torii | `#0b1026`/`#3a2350`/`#e8734f`, glow `#ffb24d`, apron `#2b2a33` | painted wood, paper-and-bamboo | cherry-blossom density; petals as thin quads |
| medina | `#f7c884`/`#e08a52`/`#8f3f30`, glow `#3fd0c9`, apron `#c78a5a` | matte clay, brass (matte), painted tile | glossy metal — reads as reflective, Meshy warned [S1] |
| carioca | `#2fb6d9`/`#9fdcf0`/`#eaf7ff`, glow `#ffd84d`, apron `#e8d5a8` | granite, painted concrete, sand | water spray/foam as particles [S18] |
| aurora | `#04060f`/`#0a1b33`/`#123a3c`, glow `#4dffc3`, apron `#0d0f12` | volcanic basalt, snow, matte ice | glassy ice, steam plumes [S1][S18] |
| egeo | `#1f5fd0`/`#7fb3f0`/`#eef4ff`, glow `#2b5fd9`, apron `#d9d2c4` | whitewash plaster, matte cobalt | pure-white subject on pure-white bg (§1c) |

### 3c. Anchoring style to an existing concept still

Two options; both are available to us, and they cost nothing in Meshy credits.

1. **Text anchor (always available).** Describe the still in the style block using the same
   words as the still's own prompt (`BRIEF.md` "Shared DNA" is already a verbatim style block
   written for gpt-image-2.5-flare). Meshy's rule applies: reuse the exact wording, word for
   word, across every prop in the set [S5]. Cheap, reproducible, and it survives any tool
   change; the limitation is that text cannot carry the still's exact hue relationships.
2. **Image-to-image reference (supported by our generator — verified).** The Hermes
   `image_generate` tool accepts `image_url` (source image to edit/transform) and up to 16
   `reference_image_urls` labelled "style, character, or composition" [S25]. So a prop prompt
   can pass `art/concepts/world-arenas-r1/0X-<arena>.png` as a reference and ask for a single
   prop in that still's style. This is the strongest available anchoring and it is
   **tool-verified, not folklore** — but whether gpt-image-2.5-flare copies *palette and
   material language* well enough at prop scale is **untested in this repo**
   `[unverified]`.
   Fallback if reference images pull scene content into the prop frame: keep the reference for
   one calibration pass, note the palette it produces, then bake those values into the text
   style block and drop the image. `[inference]`

Meshy-side style anchors, for completeness: a frozen "Generate Multi-view" of an approved
render can be re-used as the primary input for sibling props [S16]; `texture_image_url` /
`texture_image_urls` steer texturing from a reference image [S11][S12]; and Meshy's 3D Agent
is documented as generating "batches of style-consistent assets for a cohesive game world"
via conversation [S14] — a Meshy-internal path we are not using because the images must come
from gpt-image-2.5-flare to match the stills.

Practitioner folklore for the same problem, undated video, no reproducible evidence attached:
"Use style references to keep everything matching. Take a screenshot of an approved asset,
upload it into image-to-3D, and use it as a style reference for new pieces" [S23]. Direction
plausible, evidence thin — treat as folklore.

## 4. Failure modes practitioners report, and the prompt fix for each

Column "evidence" is deliberately blunt: `documented` = Meshy's own docs name the failure and
the input that causes it; `folklore` = repeated by practitioners without a reproducible test.

| # | Failure mode | Evidence | Prompt-level fix (in the IMAGE prompt; §1e) |
|---|---|---|---|
| 1 | **Extra objects / scene props** merged into the mesh — Meshy's canonical image-to-3D failure example: "Full scene photo with multiple objects, cluttered background → AI merges multiple objects into one distorted mesh. Fix: Crop to a single object, remove background, use a clean reference" [S10]; also [S2][S18] | documented | `single isolated object`, `no additional objects`, `no scenery`, `no ground`, `nothing else in frame`; the subject phrase must be the *only* noun for a thing |
| 2 | **Second subject / plural subject** — "Plural nouns. 'Warriors' can produce fused or extra limbs; prompt for one 'warrior' instead" [S26] | documented (text-to-3D; mechanism is the same) | singular nouns only; forbid: `no crowd, no pair, no duplicate` |
| 3 | **Text / watermark / caption becomes geometry** — "When generating a 3D model from an image that contains text, Meshy may interpret the text as part of the object's physical structure. This results in the text being engraved or indented into the mesh... Broken or messy topology, unwanted surface deformation, distorted or unreadable text" [S6]; "Text in the image — Text can confuse the model and lead to inaccurate shapes" [S18]; "Watermarks or captions overlaid on the photo" [S16] | documented | `no text, no letters, no numbers, no glyphs, no signage, no watermark, no signature, no logo, no label`. Note Meshy's own workaround is a two-pass texture trick (clean image → mesh, original → texture) [S6] — not worth it for us; just forbid text in the source image |
| 4 | **Cropped / clipped subject → holes and missing geometry** — "This usually happens when part of the subject is cut off, heavily shadowed, or obscured. Reframe the image so the full object is visible" [S1]; "No part of the object should touch or extend beyond the image boundary" [S1]; "avoid subjects that touch or bleed to image edges" [S4] | documented | `centred, whole object visible, clear margin on all sides, nothing touching the frame edge`, plus the 70–90% fill token [S1] — the two constraints together are what actually prevent cropping |
| 5 | **Gradient / reflective / dark background bleeding into the texture** — "Avoid reflective or gradient backgrounds — they can bleed into the model's texture" [S1]; "AI-generated images often have busy or gradient backgrounds. Use the built-in Remove Background tool before generating" [S2]; "shoot against a dark matte background" for reflective subjects [S17] | documented | `pure white seamless background, no gradient, no vignette, no reflection, no floor, no horizon line, no cast shadow` |
| 6 | **Perspective mismatch → distorted proportions** — "Model proportions distorted — Severe perspective distortion in photo — Use photos with near-orthographic projection or telephoto lens" [S10] | documented | `orthographic-looking, minimal perspective distortion, no wide-angle lens, no fisheye, camera far away with a long lens` `[inference]` on the wording |
| 7 | **Black patches / flat washed-out textures** — "Black patches on model surface — Input image has shadows or dark areas" [S10]; "Textures look flat or washed out — Strong directional shadows in your reference image bake into the texture" [S1] | documented | the §1d lighting tokens; forbid `dramatic shadow`, `backlight` |
| 8 | **Lumpy / poor geometry** — "busy background or low contrast between the subject and surroundings" [S1] | documented | increase subject/background contrast (§1c), especially egeo |
| 9 | **Floating / disconnected parts in the result** — "Small detached geometry pieces are usually caused by overly complex prompts or highly detailed accessories. Simplify the object — fewer accessories and attachments" [S7]; "Add 'solid construction', 'single solid mesh', or 'unified form' to your prompt. Avoid listing too many separate accessories or attachments at once" [S9] | documented (prompt-side, but it starts in the image) | draw the prop as `one connected solid form`; stop listing sub-parts ("with ropes, tassels, chains and a hook") |
| 10 | **Multi-view tells: symmetrical hallucination, mushy sides** — "if your front and side images look nearly identical... the AI can't distinguish depth differences. Use views at least 45°–90° apart"; "Backgrounds not removed — a visible background in one or more views can confuse the model"; "Scale mismatch" [S2] | documented | if a turnaround sheet is used: identical scale, identical lighting, identical background across panels, orthogonal 90° angles, backgrounds removed in every panel [S2][S4] |
| 11 | **Off-topic / unrelated result from content guardrails** — "This can happen when content guardrails are active, particularly when the T-pose, multi-image input, or AI Stylize modes are enabled. These toggles rely on third-party processing that may interpret your prompt differently. Try disabling these toggles and regenerating" [S7] | documented | relevant to us: if a multi-view or multi-image batch comes back unrelated, the documented fix is disabling the toggle and re-running, not rewriting the image |
| 12 | **"Fix the input before the settings"** — "The biggest lever in this whole workflow is input image quality. Clean, consistent, well-lit reference views produce stable, artifact-free generations. If your generation looks off, fix the input images before touching any other setting" [S15]; "If your generation looks off, fix the input images" is Meshy's own environment-prop tutorial | documented | the whole point of this report: iteration budget belongs on the image, not on Meshy settings |

Reported by practitioners but *not* documented by Meshy, so treat as folklore: that textured
or painted materials reconstitute as melted blobs at low poly counts [S21]; that "studio-style
product shots" beat casual phone photos [S21]; that image-to-3D is fine for props/background
and unreliable for hero assets [S21][S22]. All plausible and consistent with the documented
limits, none with a reproducible attached test.

## 5. Recommendation: single image per prop vs a 2–4 view turnaround

**Recommendation: single image per prop, square 1:1, shot from the gameplay camera's
direction — as the default for all five arenas. Reserve a turnaround sheet for the small
minority of props whose back is genuinely visible or whose silhouette is ambiguous.**

The reasoning, per source:

1. Meshy rates single-image at ★ ★ ★ ★ ☆ and multi-view at ★ ★ ★ ★ ★ on the single-image vs
   multi-view comparison [S13][S16], so multi-view *is* better on fidelity and set coherence —
   but "Will more images always improve quality? No. Consistent, well-lit images of the same
   object matter more than the raw number of images" [S3], and "In these cases, a well-chosen
   single image often produces cleaner results than multiple inconsistent ones" [S3]. The
   failure mode of a bad turnaround is worse than the ceiling of a good single image.
2. Cost per arena: multi-view is a paid-plan feature, "currently only supported on Meshy 7"
   [S2], "not available in Smart Topology mode. If you switch Model Type to Smart Topology,
   the Multi-view option disappears. Need a clean low-poly topology? Generate with Standard +
   Multi-view first, then run Remesh on the result" [S16]. So a turnaround costs Luca a
   different generation path plus a manual remesh — against a 10-model-per-map budget that a
   turnaround sheet does not reduce (one sheet = one model, same as one image = one model).
3. Meshy will synthesize the missing views for free anyway: "click Generate Multi-view and
   Meshy predicts three extra angles — the sides, back, and ¾ views — from your single photo.
   The 3D generation then uses all four images together" [S17]; "Feed your scene image straight
   into Image to 3D, toggle on Multi-view, and hit Generate Multi-view. Meshy pulls the main
   object out of the scene and creates the remaining views on its own" [S15]. Free synthesized
   views require no extra work from us and no extra images from the generator.
4. Our own generator can produce either shape, but the sheet version is untested here: the
   Hermes tool takes one prompt and returns one image per call [S25]; a 2×2 turnaround sheet
   means asking for four views in one frame, which Meshy's own guidance then tells us to
   *crop into individual single-angle images before uploading* [S4]. That is 4 crops and 4
   uploads per prop to gain back/side fidelity. Only worth it where the back matters.
5. Project-specific killer argument `[inference]`: the game camera is a fixed broadcast preset
   looking down the court from behind the near baseline (`BRIEF.md`), and scenery is confined
   to "the band above the rear glass plus the two wedges outside the cage". Each prop is
   therefore seen from essentially one direction, at distance, behind glass. The back of a
   prop is not on screen. Spending turnaround budget on unseen geometry is exactly the
   over-engineering the ponytail rule targets.

When to overrule the default and build a turnaround for that prop anyway: (a) the prop
rotates or is duplicated with different facings in the scenery band (`prop_rotation`); (b) the
silhouette is genuinely ambiguous from one view — e.g. `windmill` (blades vs tower), `arch`
(does the gate read as a frame or a slab?), `basalt` (column cluster depth); (c) the first
single-image attempt came back with unusable geometry and a re-prompt is unlikely to fix it —
in which case Meshy's documented remedy order is: re-prompt → multi-view → remesh [S1][S2].

Also decided, to keep the batch reviewable: keep **one image = one prop slot**, filename-keyed
to the asset slot, so that a rejected prop can be regenerated without touching the rest of the
arena. Raw generations stay sacred (`BRIEF.md` rule) — corrections land as `-r2`, never by
overwriting.

## 6. Copy-pasteable prompt template

Fill the three placeholders, keep everything else byte-identical across every prop in an
arena (Meshy: wording drift *is* style drift [S5]). Swap only `{ARENA STYLE BLOCK}` when you
switch arena. Then pass the arena's concept still as a style reference:
`reference_image_urls: ["art/concepts/world-arenas-r1/0N-<arena>.png"]` [S25].

```
A single isolated {SUBJECT}, {THREE TO FIVE CONCRETE DETAILS}, read as one connected solid
form. Stylized low-poly 3D game asset, clean geometric shapes with smooth shading, gently
rounded edges, flat matte materials, subtle ambient occlusion only, no texture noise, no
surface grunge, no outlines, no cel shading, no photorealism.

{ARENA STYLE BLOCK — palette, materials, one line of mood, never a lighting mood}
Palette: {e.g. vermilion #e8493a, warm lantern gold #ffb24d, deep indigo #24243a}.
Materials: {e.g. matte painted wood, matte painted metal, opaque paper}. All surfaces matte —
no gloss, no chrome, no glass, no wet reflection, no metallic highlight.

{VIEW}
{front view / three-quarter view rotated about 20 degrees off-axis / eye-level view with a
slight downward tilt}, orthographic-looking with minimal perspective distortion, long lens,
camera far from the subject, the whole object visible with a clear margin on every side and
nothing crossing the frame edge, the object centred and filling 70 to 90 percent of the
square frame.

Lighting: even, diffused, shadowless studio lighting from the front, uniform ambient fill, no
directional key light, no rim light, no bounce light, no cast shadow on the ground, no
highlight blowout.

Background: pure white seamless background, #FFFFFF, no gradient, no vignette, no horizon
line, no floor plane, no reflection, no shadow under the object.

Square 1:1 image, sharp focus edge to edge, clean readable silhouette,
{SUBJECT} occupies 70-90 percent of the frame.

No text, no letters, no numbers, no glyphs, no signage, no label, no watermark, no signature,
no logo, no caption, no UI, no border, no frame, no additional objects, no second subject, no
duplicate parts, no people, no hands, no animals, no scenery, no plants in the background, no
ground, no props around it, no depth of field, no motion blur, no lens flare, no noise, no
paper texture, no HDR look.
```

Worked example (torii arena, small prop):

```
A single isolated stone lantern, squat carved base, wide square roof cap, one warm lamp
inside, read as one connected solid form. Stylized low-poly 3D game asset, clean geometric
shapes with smooth shading, gently rounded edges, flat matte materials, subtle ambient
occlusion only, no texture noise, no surface grunge, no outlines, no cel shading, no
photorealism. Palette: deep indigo #24243a body, warm lantern gold #ffb24d lamp glow at the
opening, muted stone grey #2b2a33. Materials: matte carved stone, opaque paper panel, matte
painted metal brackets. All surfaces matte — no gloss, no chrome, no glass, no wet
reflection, no metallic highlight. Front view, eye level with a slight downward tilt,
orthographic-looking with minimal perspective distortion, long lens, camera far from the
subject, the whole object visible with a clear margin on every side and nothing crossing the
frame edge, the object centred and filling 70 to 90 percent of the square frame. Lighting:
even, diffused, shadowless studio lighting from the front, uniform ambient fill, no
directional key light, no rim light, no bounce light, no cast shadow on the ground, no
highlight blowout. Background: pure white seamless background, #FFFFFF, no gradient, no
vignette, no horizon line, no floor plane, no reflection, no shadow under the object. Square
1:1 image, sharp focus edge to edge, clean readable silhouette. No text, no letters, no
numbers, no glyphs, no signage, no label, no watermark, no signature, no logo, no caption, no
UI, no border, no frame, no additional objects, no second subject, no duplicate parts, no
people, no hands, no animals, no scenery, no plants in the background, no ground, no props
around it, no depth of field, no motion blur, no lens flare, no noise, no paper texture, no
HDR look.
```

## Appendix A — contradictions, uncertainty, and what to test first

(Reference material, deliberately placed after §6: the template is the deliverable, this is
the caveat list that keeps it honest.)

**Documented contradictions between Meshy's own sources (do not paper over these):**

1. **Minimum resolution: 512 vs 1024 vs 1040.** `at least 512 × 512 px; 1024 × 1024 px or higher
   is ideal` [S1] and `resolution ≥ 512×512` [S10], against `At least 1040 x 1040 px` [S16] and
   `over 1040x1040px` [S18]. Resolution is a recommendation, not an enforced gate: Meshy accepts
   the upload either way. Treat 1024² as the floor, not 1040.
2. **Negative prompts: unsupported vs supported.** [S9] says unsupported; [S8] and [S7] tell you
   to use the negative prompt field. Both statements are current on the help center. For
   image-to-3D the question is largely academic [S8], which is why §1e pushes negatives into the
   image prompt.
3. **Multi-view model support: Meshy 6 vs Meshy 7.** `Multi-View is currently only supported on
   Meshy 7` [S2] and [S4], while [S16] (a Meshy tutorial page) says `Meshy 6 combines them` and
   `runs on Meshy 6 only`, and [S10] lists `Meshy 6 / Meshy 5` for multi-view. Assume the help
   center is right (Meshy 7) and the tutorial pages are stale.
4. **Multi-view image count: 2–8 vs 1–4.** [S10] says `Multiple (2–8)`; the API says 1–4
   (`image_urls` must contain between 1 and 4 images) [S12]; §3 of the app guide says 1–4 with
   Left/Back/Right slots [S16]. Use 4 as the real ceiling.
5. **Scene-first vs object-first prop sourcing.** Meshy's environment-prop tutorial [S15]
   argues for generating a full scene then extracting props; the help center's whole image-to-3D
   doctrine [S1][S2] argues for one isolated subject on white. Both are current. We follow the
   help center because our concept stills already exist and gpt-image-2.5-flare produces
   isolated props reliably from text.
6. **Environment assets.** Meshy does not have a dedicated environment-asset guide. The closest
   documented statements are the terrain-chunk tip (`A cliff wall, A mountain peak, A pile of
   snow-covered rocks` [S18]) and the game-assets use-case page ([S14]). Everything else about
   environment props in this report is either the general image-to-3D rules applied, or
   `[inference]`.

**Untested here — cheap to verify before spending a batch:**

- Does gpt-image-2.5-flare actually return ≥1024² for `aspect_ratio: square`? Unstated in the
  tool schema [S25]. One probe image answers it.
- Does passing a concept still as `reference_image_urls` keep the palette but drop the scene,
  or does it drag the arena's architecture into the prop frame? One probe per arena.
- Does a pure-white subject on pure-white survive for egeo (§1c)? One probe.
- Do the thin-feature props (cable line, net posts, flame) survive Meshy at all [S2], or do they
  need to be procedural in Godot? This is a Meshy-side test, not an image-side one, and it is
  the biggest open risk to the "10 models per map" budget.

**Folklore carried into the template but not documented by Meshy:** the long-lens /
orthographic wording, "one connected solid form" applied to foliage clusters, the explicit
`#FFFFFF` hex, the `70 to 90 percent` phrasing repeated twice, and the "no HDR look" clause.
They are extrapolations from the documented rules, not quotes. If a token turns out to hurt,
remove it and re-photograph rather than removing the whole block.

**Not in scope here:** Meshy-side settings (model version, Smart Topology vs Standard, remesh
targets, credits, the 10-models-per-map limit) and the Godot-side import (`ArenaStyle.STYLES`,
`arena_scenery.gd`, `BACKDROP_Z −8.0`). This report only covers producing the input images.








