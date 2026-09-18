#!/usr/bin/env python3
"""Build the per-arena prompt packs for the arena kit (KIT-STANDARD v1).

Why a builder instead of hand-written JSON: the Meshy recipe
(`docs/mission/arena-kit/scan/image-prototyping.md` §3a/§6) requires the shared
blocks to be byte-identical across every prompt in an arena — wording drift IS
style drift. Composing from one source table removes copy-paste drift.

Output: tools/arena-kit/prompts/<arena>.json
  { arena, kit, style_block, negative_block, slots: { <slot>: {prompt, view,
    reference|null, kind: prop|material, meshy: bool, note? } } }

Run:  python3 tools/arena-kit/build_packs.py
"""

from __future__ import annotations

import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "tools", "arena-kit", "prompts")

KIT_SLOTS = [
    "hero_landmark", "gate_portal", "light_source", "vegetation_cluster",
    "ground_dressing", "ornament_accent", "column_pillar", "railing_segment",
    "furniture", "signage_banner", "ground_texture",
]

# ---------------------------------------------------------------- shared blocks

DNA = (
    "Stylized low-poly 3D game asset, clean geometric shapes with smooth shading, "
    "gently rounded edges, flat matte materials, subtle ambient occlusion only, "
    "no texture noise, no surface grunge, no outlines, no cel shading, no photorealism."
)

VIEW_TAIL = (
    ", orthographic-looking with minimal perspective distortion, long lens, camera far "
    "from the subject, the whole object visible with a clear margin on every side and "
    "nothing crossing the frame edge, the object centred and filling 70 to 90 percent "
    "of the square frame."
)

LIGHT = (
    "Lighting: even, diffused, shadowless studio lighting from the front, uniform "
    "ambient fill, no directional key light, no rim light, no bounce light, no cast "
    "shadow on the ground, no highlight blowout."
)

BACKGROUND = (
    "Background: pure white seamless background, #FFFFFF, no gradient, no vignette, "
    "no horizon line, no floor plane, no reflection, no shadow under the object."
)

NEGATIVE = (
    "No text, no letters, no numbers, no glyphs, no signage, no label, no watermark, "
    "no signature, no logo, no caption, no UI, no border, no frame, no additional "
    "objects, no second subject, no duplicate parts, no people, no hands, no animals, "
    "no scenery, no plants in the background, no ground, no props around it, no depth "
    "of field, no motion blur, no lens flare, no noise, no paper texture, no HDR look."
)

VIEWS = {
    # Architecture / hero masses: front or 3/4 at 15-30 deg, camera mid-height.
    "arch": (
        "Front view, camera at mid-height with the verticals parallel, three-quarter "
        "angle rotated about 20 degrees off-axis"
    ),
    "arch_front": (
        "Front view, camera at mid-height with the verticals parallel, facing the "
        "subject straight on"
    ),
    # Medium props: 3/4 at 15-30 deg, slight downward tilt.
    "prop": (
        "Three-quarter view rotated about 20 degrees off-axis, eye level with a slight "
        "downward tilt"
    ),
    "prop_front": (
        "Front view, eye level with a slight downward tilt, facing the subject straight on"
    ),
    # Foliage: flat frontal silhouette, cluster treated as one blob.
    "foliage": (
        "Front view, flat frontal silhouette, facing the subject straight on"
    ),
}


def prop_prompt(subject: str, details: str, view_key: str, style_block: str,
                palette_line: str, materials_line: str) -> str:
    head = (
        f"A single isolated {subject}, {details}, read as one connected solid form. "
        + DNA
    )
    style = f"{style_block}\nPalette: {palette_line}.\nMaterials: {materials_line}. " \
            "All surfaces matte — no gloss, no chrome, no glass, no wet reflection, " \
            "no metallic highlight."
    return "\n\n".join([
        head, style, VIEWS[view_key] + VIEW_TAIL, LIGHT, BACKGROUND,
        "Square 1:1 image, sharp focus edge to edge, clean readable silhouette, "
        f"{subject} occupies 70-90 percent of the frame.",
        NEGATIVE,
    ]) + "\n"


def material_prompt(material: str, palette_line: str) -> str:
    """ground_texture: flat top-down tileable swatch. NOT a prop, never goes to Meshy."""
    head = (
        f"A flat top-down seamless tileable material texture of {material}. "
        "Hand-painted stylized low-poly game material, flat matte finish, even "
        "shadowless lighting, no highlights, no objects in frame, no props, no "
        "horizon, no vignette; the material fills the entire square frame edge to "
        "edge as one even repeating pattern that tiles seamlessly on all four sides."
    )
    style = (
        f"Palette: {palette_line}. All surfaces matte — no gloss, no wet reflection, "
        "no specular highlight, no chrome, no glass."
    )
    return "\n\n".join([
        head, style,
        "Square 1:1 image, flat orthographic-looking top-down view, sharp focus edge "
        "to edge, even tone across the frame.",
        NEGATIVE,
    ]) + "\n"


# ---------------------------------------------------------------- arena content
# style_block = the shared style block pasted verbatim into every prompt of the
# arena (BRIEF.md palette + one line of mood; lighting mood stays out).

ARENAS = {
    "torii": {
        "still": "art/concepts/world-arenas-r1/01-torii.png",
        "style_block": (
            "A quiet Kyoto shrine garden at dusk: warm vermilion and deep indigo "
            "lacquerwork with lantern-gold accents, hand-built and uncluttered, drawn "
            "from a dusk sky of deep indigo #0b1026, muted violet #3a2350 and sunset "
            "coral #e8734f, over grey stone paving #2b2a33."
        ),
        "palette": (
            "vermilion #e8493a, warm lantern gold #ffb24d, deep indigo #24243a, "
            "muted violet #3a2350, stone grey #2b2a33"
        ),
        "materials": "matte painted wood, opaque paper, matte carved stone, matte patinated bronze",
        "slots": {
            "hero_landmark": dict(
                subject="five-story pagoda",
                details=("stacked tapering tiered roofs in deep indigo, timber posts in "
                         "weathered vermilion, warm gold window lattice, a small grey stone "
                         "base with three entry steps"),
                view="arch",
                note="already delivered by the parent probe (reuse; do not regenerate)",
            ),
            "gate_portal": dict(
                subject="vermilion torii gate",
                details=("two thick round pillars, one wide gently curved upper crossbeam, "
                         "one straight lower tie beam, black stone footing collars"),
                view="arch_front",
                note="reference-image probe slot: pass the torii concept still as "
                     "reference on the first attempt",
                reference="art/concepts/world-arenas-r1/01-torii.png",
            ),
            "light_source": dict(
                subject="carved stone lantern",
                details=("squat hexagonal base, wide square roof cap, warm lantern-gold "
                         "paper panel on one face, small stone finial on top"),
                view="prop",
            ),
            "vegetation_cluster": dict(
                subject="cherry tree cluster",
                details=("one thick gnarled dark trunk, three chunky blossom canopies "
                         "modelled as solid softly rounded masses, a few thick branches"),
                view="foliage",
            ),
            "ground_dressing": dict(
                subject="stone boulder cluster on raked gravel",
                details=("three smooth rounded grey stones of different sizes nested in "
                         "one low mound of fine pale gravel, read as one connected solid "
                         "form, kept compact with a generous white margin on every side"),
                view="prop",
            ),
            "ornament_accent": dict(
                subject="small wooden shrine",
                details=("steep indigo gabled roof, vermilion timber posts, plain closed "
                         "vermilion doors, one stone step"),
                view="arch",
            ),
            "column_pillar": dict(
                subject="vermilion timber fence post",
                details=("one thick square post, flat dark cap, black stone base collar"),
                view="prop_front",
            ),
            "railing_segment": dict(
                subject="wooden railing segment",
                details=("two thick square vermilion posts, two deep chunky horizontal "
                         "timber rails, solid proportions, no open lattice"),
                view="prop",
            ),
            "furniture": dict(
                subject="plain wooden bench",
                details=("one thick solid plank seat, sturdy square legs, dark stained "
                         "timber with a thin vermilion edge trim"),
                view="prop",
            ),
            "signage_banner": dict(
                subject="hanging fabric banner panel",
                details=("one thick indigo cloth panel with a simple gold horizontal "
                         "band, hanging from a solid wooden top rod, the cloth modelled "
                         "as a thick flat slab with gentle folds, plain and undecorated"),
                view="foliage",
            ),
            "ground_texture": dict(
                material="fine pale grey raked gravel with soft parallel raked ripple lines",
            ),
        },
    },

    "medina": {
        "still": "art/concepts/world-arenas-r1/02-medina.png",
        "style_block": (
            "A Marrakech courtyard at golden hour: warm ochre clay walls, terracotta "
            "and deep umber earth tones, matte turquoise zellige tile as the single "
            "cool accent, drawn from sunlit clay #f7c884, terracotta #e08a52 and deep "
            "umber #8f3f30 over clay ground #c78a5a."
        ),
        "palette": (
            "sunlit clay #f7c884, terracotta #e08a52, deep umber #8f3f30, turquoise "
            "zellige #3fd0c9, clay ground #c78a5a"
        ),
        "materials": "matte clay plaster, matte glazed tile, matte brass, matte painted cedar",
        "slots": {
            "hero_landmark": dict(
                subject="slim minaret tower",
                details=("square tapering shaft in warm ochre clay, small arched windows, "
                         "one band of turquoise zellige tile, a narrow balcony with a "
                         "chunky parapet, crowned by a small green-tiled cupola"),
                view="arch",
            ),
            "gate_portal": dict(
                subject="horseshoe-arch gateway",
                details=("two thick clay-plastered piers, one rounded horseshoe arch "
                         "opening, a turquoise zellige border band around the arch, "
                         "a flat stone threshold"),
                view="arch_front",
            ),
            "light_source": dict(
                subject="hanging brass lantern",
                details=("faceted thick brass body, amber panels modelled as solid "
                         "opaque amber slabs, a short chunky brass link column above, "
                         "pointed brass cap"),
                view="prop",
            ),
            "vegetation_cluster": dict(
                subject="date palm tree",
                details=("one thick textured trunk, a crown of broad chunky fronds "
                         "modelled as solid tapered blades, a small rounded cluster of "
                         "dates beneath the crown"),
                view="foliage",
            ),
            "ground_dressing": dict(
                subject="clay pottery cluster",
                details=("three terracotta vessels of different sizes — one large jar, "
                         "one wide bowl, one amphora — all matte glazed and nested "
                         "together as one cluster, kept compact with a generous white "
                         "margin on every side"),
                view="prop",
            ),
            "ornament_accent": dict(
                subject="small zellige fountain",
                details=("an octagonal basin banded in turquoise and white tile, a low "
                         "chunky pedestal in the middle, the water surface modelled as a "
                         "flat matte pale-blue slab, no spray"),
                view="prop",
            ),
            "column_pillar": dict(
                subject="tiled courtyard column",
                details=("square plaster column with one turquoise-and-white zellige "
                         "tile band, a simple flat capital, a clay base plinth"),
                view="prop_front",
            ),
            "railing_segment": dict(
                subject="wrought iron railing segment",
                details=("two thick square iron posts, one wide horizontal rail carrying "
                         "a chunky palmette silhouette cut as a solid flat plate, matte "
                         "dark iron, sturdy proportions, no open lattice"),
                view="prop",
            ),
            "furniture": dict(
                subject="low divan bench",
                details=("thick clay-plaster base, a flat striped mattress modelled as a "
                         "solid slab, two square cushions, matte woven fabric"),
                view="prop",
            ),
            "signage_banner": dict(
                subject="fabric awning sign",
                details=("one thick ochre canvas awning on a chunky wooden bar, folds "
                         "modelled as solid thickness, a single turquoise stripe along "
                         "the hem, plain and undecorated"),
                view="prop",
            ),
            "ground_texture": dict(
                material="warm terracotta clay floor tiles in a simple square grid",
            ),
        },
    },

    "carioca": {
        "still": "art/concepts/world-arenas-r1/03-carioca.png",
        "style_block": (
            "A Rio de Janeiro terrace at noon: bright tropical light, blue-green "
            "granite ridges, sun-bleached sand and painted white concrete, drawn from "
            "sky blue #2fb6d9 and pale sky #9fdcf0 over beach sand #e8d5a8, with "
            "afternoon sun yellow #ffd84d as the single warm accent."
        ),
        "palette": (
            "sky blue #2fb6d9, pale sky #9fdcf0, beach sand #e8d5a8, granite grey-green "
            "#6b7a72, sun yellow #ffd84d, painted white concrete #f4f1e8"
        ),
        "materials": "matte granite, matte painted concrete, matte weathered timber, matte rope",
        "slots": {
            "hero_landmark": dict(
                subject="granite sugarloaf peak",
                details=("one tall smooth rounded granite dome, a steep lower earth "
                         "slope, a few chunky rock ribs, matte grey-green stone"),
                view="arch",
            ),
            "gate_portal": dict(
                subject="white quay arch",
                details=("two chunky whitewashed stone piers, one wide rounded arch "
                         "opening, a dressed stone keystone and coping"),
                view="arch_front",
            ),
            "light_source": dict(
                subject="festoon light strand",
                details=("one thick braided rope swag, oversized round bulbs modelled as "
                         "solid matte balls alternating warm cream and sun yellow, "
                         "chunky brass fittings, read as one connected solid form"),
                view="prop_front",
            ),
            "vegetation_cluster": dict(
                subject="banana plant cluster",
                details=("three thick upright stems, broad chunky leaves modelled as "
                         "solid tapered blades, one small dense clump of lower leaves"),
                view="foliage",
            ),
            "ground_dressing": dict(
                subject="beach boulder cluster",
                details=("three smooth rounded granite boulders of different sizes, one "
                         "with a ridge of pale sand along its base, all matte, kept "
                         "compact with a generous white margin on every side"),
                view="prop",
            ),
            "ornament_accent": dict(
                subject="low painted concrete capoeira ring",
                details=("one shallow circular kerb ring of painted white concrete, a "
                         "single low stone post with a small sun-yellow band, read as "
                         "one connected form"),
                view="prop",
            ),
            "column_pillar": dict(
                subject="painted timber mast",
                details=("tall square timber column painted white with one sun-yellow "
                         "band at the top, a chunky base plinth"),
                view="prop_front",
            ),
            "railing_segment": dict(
                subject="quay rope railing segment",
                details=("two thick whitewashed timber posts with rounded caps, two "
                         "thick ropes swagging between them, chunky proportions, no "
                         "open lattice"),
                view="prop",
            ),
            "furniture": dict(
                subject="wood and canvas deck chair",
                details=("solid painted timber frame, a taut striped canvas seat "
                         "modelled as a thick slab, chunky joints"),
                view="prop",
            ),
            "signage_banner": dict(
                subject="triangular flag pennant on a short pole",
                details=("one green cloth pennant with a single yellow diamond shape, "
                         "the cloth modelled as thick chunky fabric, a solid painted "
                         "pole with a brass cap, plain and undecorated"),
                view="prop_front",
            ),
            "ground_texture": dict(
                material="fine golden beach sand with soft wind ripples",
            ),
        },
    },

    "aurora": {
        "still": "art/concepts/world-arenas-r1/04-aurora.png",
        "style_block": (
            "An Icelandic volcanic shore at night: near-black basalt, deep midnight "
            "navy and cold deep teal, snow covers and matte ice, drawn from midnight "
            "navy #04060f and deep teal #0a1b33/#123a3c over volcanic black #0d0f12, "
            "with aurora green #4dffc3 as the single glow accent."
        ),
        "palette": (
            "volcanic black #0d0f12, midnight navy #04060f, deep teal #0a1b33, teal "
            "#123a3c, snow #eaf4f6, aurora green #4dffc3"
        ),
        "materials": "matte volcanic basalt, matte snow, matte weathered iron, matte driftwood",
        "slots": {
            "hero_landmark": dict(
                subject="cluster of hexagonal basalt columns",
                details=("tall hexagonal prisms of different heights, flat snow caps on "
                         "the shorter ones, dark matte basalt with subtle grey facets"),
                view="arch",
            ),
            "gate_portal": dict(
                subject="stone cairn marker",
                details=("stacked flat stones, a broad base tapering to a small "
                         "capstone, one aurora-green painted band on a single middle "
                         "stone"),
                view="arch_front",
            ),
            "light_source": dict(
                subject="iron brazier",
                details=("sturdy tripod legs, a deep wide bowl, glowing aurora-green "
                         "coals modelled as solid rounded lumps, matte black iron"),
                view="prop",
            ),
            "vegetation_cluster": dict(
                subject="moss-covered rock cluster",
                details=("three rounded boulders capped with thick moss in deep teal "
                         "green, a dusting of snow on top, read as one connected mass"),
                view="foliage",
            ),
            "ground_dressing": dict(
                subject="basalt shard cluster",
                details=("five angular dark basalt shards of different sizes with "
                         "chunky facets, one dusted with snow, kept compact with a "
                         "generous white margin on every side"),
                view="prop",
            ),
            "ornament_accent": dict(
                subject="carved standing runestone",
                details=("one tall flat-topped basalt slab with carved geometric bands "
                         "and a shallow interlocking knot relief, plain raised stone, "
                         "no lettering"),
                view="arch_front",
            ),
            "column_pillar": dict(
                subject="single basalt prism",
                details=("one tall hexagonal column, a flat chipped top, subtle "
                         "vertical facets"),
                view="prop_front",
            ),
            "railing_segment": dict(
                subject="driftwood fence segment",
                details=("two thick weathered driftwood posts, two chunky horizontal "
                         "planks, matte grey timber, solid proportions"),
                view="prop",
            ),
            "furniture": dict(
                subject="wooden sled bench",
                details=("a flat timber sled deck with one upturned front curl, low "
                         "chunky legs, matte weathered wood"),
                view="prop",
            ),
            "signage_banner": dict(
                subject="triangular pennant on a short pole",
                details=("one deep teal cloth pennant with a single aurora-green stripe, "
                         "thick chunky fabric, a dark timber pole, plain and undecorated"),
                view="prop_front",
            ),
            "ground_texture": dict(
                material="black volcanic gravel with fine grey ash speckle",
            ),
        },
    },

    "egeo": {
        "still": "art/concepts/world-arenas-r1/05-egeo.png",
        "style_block": (
            "A Santorini cliffside at noon: whitewashed Cycladic plaster volumes, "
            "matte cobalt blue domes and trim, pale grey-stone bases and paving, drawn "
            "from cobalt #2b5fd9 and sky blue #1f5fd0 with pale sky #eef4ff over pale "
            "stone #d9d2c4."
        ),
        "palette": (
            "whitewash plaster #f7f4ec, cobalt #2b5fd9, sky blue #1f5fd0, pale stone "
            "#d9d2c4, olive green #6d7a4f"
        ),
        "materials": "matte whitewash plaster, matte cobalt painted plaster, matte pale stone",
        "slots": {
            "hero_landmark": dict(
                subject="cluster of whitewashed cubic houses",
                details=("stepped cubic volumes with flat roofs, one cobalt-blue dome "
                         "cap, deep cobalt-blue doors and window recesses, a pale "
                         "grey-stone base course along the bottom"),
                view="arch",
                note="white-on-white probe slot: the pale stone base course and cobalt "
                     "dome carry the silhouette against the white background",
            ),
            "gate_portal": dict(
                subject="whitewashed chapel doorway",
                details=("a chalk-white plaster wall panel with a rounded top, a deep "
                         "cobalt-blue timber door, one pale stone step, a small cobalt "
                         "niche above the door"),
                view="arch_front",
            ),
            "light_source": dict(
                subject="whitewashed lantern post",
                details=("a square white plaster post, cobalt-blue cap and base collar, "
                         "a warm amber lamp behind a thick frosted panel"),
                view="prop",
            ),
            "vegetation_cluster": dict(
                subject="olive tree cluster",
                details=("one thick gnarled pale trunk, three rounded dusty-green "
                         "canopies modelled as solid masses, a low pale stone base"),
                view="foliage",
            ),
            "ground_dressing": dict(
                subject="dry-stone block cluster",
                details=("a cluster of four rough pale stone blocks of different sizes "
                         "with chunky edges and one short low fragment of stacked pale "
                         "stone wall, plain rocks not a building, no roof, no door, no "
                         "dome, kept compact with a generous white margin on every side"),
                view="prop",
            ),
            "ornament_accent": dict(
                subject="wooden donkey cart",
                details=("a deep cobalt-blue painted cart box, two thick wooden wheels, "
                         "two chunky shafts, plain and undecorated"),
                view="prop",
            ),
            "column_pillar": dict(
                subject="whitewashed square pier",
                details=("a chalk-white plaster pier, a flat cobalt cap, a pale stone base"),
                view="prop_front",
            ),
            "railing_segment": dict(
                subject="cobalt-blue railing segment",
                details=("two thick square timber posts, two chunky horizontal rails, "
                         "painted cobalt blue, matte, solid proportions"),
                view="prop",
            ),
            "furniture": dict(
                subject="taverna chair",
                details=("a solid whitewashed timber frame, a woven seat modelled as a "
                         "thick matte slab, cobalt-blue accents on the frame"),
                view="prop",
            ),
            "signage_banner": dict(
                subject="whitewashed signboard",
                details=("one thick plaster board with a deep cobalt-painted border, a "
                         "blank face with a single small cobalt diamond motif, no "
                         "lettering"),
                view="arch_front",
            ),
            "ground_texture": dict(
                material="pale Cycladic stone paving slabs with soft grey joints",
            ),
        },
    },
}


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for arena, a in ARENAS.items():
        slots = {}
        for slot in KIT_SLOTS:
            cfg = a["slots"][slot]
            if slot == "ground_texture":
                prompt = material_prompt(cfg["material"], a["palette"])
                entries = dict(
                    prompt=prompt, view="top-down flat (material swatch)",
                    kind="material", meshy=False,
                    reference=None,
                    note="flat top-down tileable material swatch — image-only, "
                         "never uploaded to Meshy (KIT-STANDARD §1)",
                )
            else:
                prompt = prop_prompt(
                    cfg["subject"], cfg["details"], cfg["view"],
                    a["style_block"], a["palette"], a["materials"])
                entries = dict(
                    prompt=prompt, view=VIEWS[cfg["view"]],
                    kind="prop", meshy=True,
                    reference=cfg.get("reference"),
                    subject=cfg["subject"],
                )
            if cfg.get("note"):
                entries["note"] = cfg["note"]
            slots[slot] = entries
            total += 1
        pack = {
            "arena": arena,
            "kit": "arena-kit-v1 (KIT-STANDARD 2026-09-18 §1)",
            "concept_still": a["still"],
            "style_block": a["style_block"],
            "palette": a["palette"],
            "materials": a["materials"],
            "negative_block": NEGATIVE,
            "template_source": "docs/mission/arena-kit/scan/image-prototyping.md §6",
            "slots": slots,
        }
        path = os.path.join(OUT, f"{arena}.json")
        with open(path, "w") as fh:
            json.dump(pack, fh, indent=1, ensure_ascii=False)
            fh.write("\n")
        print(f"wrote {os.path.relpath(path, REPO)} ({len(slots)} slots)")
    print(f"total slots: {total} (5 arenas x 11)")


if __name__ == "__main__":
    build()
