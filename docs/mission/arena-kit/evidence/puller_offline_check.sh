#!/usr/bin/env bash
# run/tmp/arena-kit/evidence/puller_offline_check.sh — verify the puller's CREDENTIAL-FREE
# path (--from-inbox) against a local fixture, end to end, and leave the tree as it found it.
#
#   1. the fixture tool rebuilds `tiny_prop.glb` byte-identically (--check);
#   2. a drop in the standard's inbox (`meshy/inbox/<arena>/<slot>.glb`) is copied to the
#      slot path, and the bytes at the slot path are the fixture's, checked with shasum
#      (not with the tool's own report);
#   3. a second run is a no-op ("already in place"), i.e. idempotent;
#   4. --report reads the log back and agrees with the file in place;
#   5. a non-GLB source is refused with exit 6 and writes nothing to the slot path;
#   6. --retire takes the file back out and the tree is clean again (0 GLBs).
#
# The live path (--task, Meshy API) is NOT exercised here: it needs a key. `--report` and
# the log work without one, and the exit-4 case (no key) is shown as its own honest line.
set -uo pipefail
ROOT="/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
cd "$ROOT" || exit 2
FIXTURE="tools/arena-kit/fixtures/tiny_prop.glb"
INBOX="meshy/inbox/torii"
SLOT="godot/assets/arenas/torii/light_source.glb"
ARENA=torii
SLOTNAME=light_source
rc() { echo "    -> exit=$1"; }

echo "=== 1. the fixture rebuilds identically ==="
python3 tools/arena-kit/fixtures/make_tiny_prop.py --check; rc $?
WANT_SHA="$(shasum -a 256 "$FIXTURE" | cut -d' ' -f1)"
echo "    fixture sha256=$WANT_SHA"

echo "=== 2. drop in the inbox, pull --from-inbox ==="
mkdir -p "$INBOX"
cp "$FIXTURE" "$INBOX/$SLOTNAME.glb"
python3 tools/arena-kit/pull_meshy.py --from-inbox --arena "$ARENA" --slot "$SLOTNAME"; rc $?
GOT_SHA="$(shasum -a 256 "$SLOT" 2>/dev/null | cut -d' ' -f1)"
if [ "$GOT_SHA" = "$WANT_SHA" ]; then
  echo "    bytes at $SLOT match the fixture ($GOT_SHA)"
else
  echo "    MISMATCH at $SLOT: want $WANT_SHA got ${GOT_SHA:-<none>}"
fi

echo "=== 3. the second run is a no-op (idempotent) ==="
python3 tools/arena-kit/pull_meshy.py --from-inbox --arena "$ARENA" --slot "$SLOTNAME"; rc $?

echo "=== 4. --report reads it back ==="
python3 tools/arena-kit/pull_meshy.py --report; rc $?

echo "=== 5. a non-GLB source is refused, and writes nothing ==="
printf 'this is not a glb' > "$INBOX/gate_portal.glb"
python3 tools/arena-kit/pull_meshy.py --from-inbox --arena "$ARENA" --slot gate_portal; rc $?
ls godot/assets/arenas/torii/gate_portal.glb 2>/dev/null && echo "    BAD: a refused file reached the slot path" || echo "    no gate_portal.glb in the slot path (correct)"
rm -f "$INBOX/gate_portal.glb"

echo "=== 6. --retire takes it back out ==="
python3 tools/arena-kit/pull_meshy.py --retire --arena "$ARENA" --slot "$SLOTNAME"; rc $?
if [ -f "$SLOT" ]; then echo "    BAD: $SLOT survived --retire"; else echo "    $SLOT is gone (correct)"; fi
LEFT="$(find godot/assets/arenas -name '*.glb' | wc -l | tr -d ' ')"
echo "    .glb files left under godot/assets/arenas: $LEFT"
# Only the inbox this check created: `meshy/` itself is TRACKED (briefs, turnarounds,
# rigged GLBs, views — another lane's lane), so never `rm -rf meshy`.
rm -rf meshy/inbox
echo "    meshy/inbox removed (meshy/ itself is tracked and untouched)"

echo "=== the live path, honestly ==="
python3 tools/arena-kit/pull_meshy.py --arena "$ARENA" --slot "$SLOTNAME" --task fake-task-id
echo "    -> exit=$? (4 = no key on this machine: the live path stays unverified until the"
echo "       owner provides one; --report and the log are the parts of it that work today)"
