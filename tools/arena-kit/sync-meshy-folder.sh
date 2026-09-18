#!/bin/bash
# Keep meshy/arenas/ in step with the canonical arena-kit image batch (art/arena-kits/).
#
# meshy/arenas/<arena>/          the 10 Meshy-ready props per map (upload 1 by 1)
# meshy/arenas/_ground-textures/ the 5 ground textures — NEVER upload these to Meshy,
#                                they are material swatches for Godot
# Canonical source, ledger and prompts stay in art/arena-kits/ + tools/arena-kit/.
# Files are hard-linked where possible, so this costs no extra disk.
set -euo pipefail
cd "$(dirname "$0")/../.."

ARENAS="torii medina carioca aurora egeo"
SLOTS="hero_landmark gate_portal light_source vegetation_cluster ground_dressing ornament_accent column_pillar railing_segment furniture signage_banner"
SRC=art/arena-kits
DST=meshy/arenas

mkdir -p "$DST/_ground-textures"
for a in $ARENAS; do
  mkdir -p "$DST/$a"
  cp -f "$SRC/$a/MANIFEST.md" "$DST/$a/MANIFEST.md"
  for s in $SLOTS; do
    cp -lf "$SRC/$a/$s.png" "$DST/$a/$s.png" 2>/dev/null || cp -f "$SRC/$a/$s.png" "$DST/$a/$s.png"
  done
  cp -f "$SRC/$a/ground_texture.png" "$DST/_ground-textures/$a-ground_texture.png"
done

# The owner-facing upload list, with paths rewritten to this folder.
if [ -f "$SRC/UPLOAD-LIST.md" ]; then
  sed -e 's#art/arena-kits/\([a-z]*\)/ground_texture\.png#meshy/arenas/_ground-textures/\1-ground_texture.png#g' \
      -e 's#art/arena-kits/\([a-z]*\)/#meshy/arenas/\1/#g' \
      "$SRC/UPLOAD-LIST.md" > "$DST/UPLOAD-LIST.md"
fi

echo "synced: $(find "$DST" -name '*.png' | wc -l | tr -d ' ') images under $DST"
