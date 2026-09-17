#!/usr/bin/env python3
"""Compose the GATE-A before/after contact sheets from real captures (no fabrication).

Inputs are copied into gate-a-review/pairs/ byte-identical first (hash-verified),
then the contact sheets are composed here (panels pasted unmodified, captions burned in).
Composition only — no pixel edits inside any panel.
"""
import hashlib
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path("/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot")
UIR = REPO / "docs/implementation/ui-recreation"
OUT = UIR / "gate-a-review"
PAIRS = OUT / "pairs"
SHEETS = OUT / "sheets"
PULL = Path("/tmp/padel-uir-pull-20260917/repo/godot/game/out")
# Post-merge 1280x720 HUD recapture stage (closeout pass, 2026-09-17): the merged-tip
# capture ran in the real checkout and its raw outputs were staged here before
# godot/game/out/ was restored byte-identical (PROVENANCE.md, cross-check 6).
POST_1280 = Path("/tmp/padel-gatea-1280-20260917/out-after")

FONT_R = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

BG = (14, 18, 26)
BAND = (24, 30, 42)
INK = (226, 232, 240)
DIM = (150, 160, 175)
CYAN = (126, 243, 255)

# name -> (source path, label line 1, label line 2)
SOURCES = {
    "menu-reference-web-1280x720.png": (
        UIR / "evidence/reference-captures/menu.png",
        "REFERENCE (frozen web build \u2014 index.html/styles.css)",
        "evidence/reference-captures/menu.png",
    ),
    "menu-before-ported-1280x720.png": (
        UIR / "integration-prep/before-set/menu.png",
        "BEFORE (ported Godot UI \u2014 UIR-00 register baseline)",
        "integration-prep/before-set/menu.png",
    ),
    "menu-after-prototype-1280x720.png": (
        PULL / "ui-prototype-menu.png",
        "AFTER (recreated MenuScreen \u2014 real capture, merged tip c9470e2)",
        "/tmp/padel-uir-pull-20260917/repo/godot/game/out/ui-prototype-menu.png",
    ),
    "hud-reference-web-1280x720.png": (
        UIR / "evidence/reference-captures/game.png",
        "REFERENCE (frozen web build \u2014 in-match HUD)",
        "evidence/reference-captures/game.png",
    ),
    "hud-before-ported-1280x720.png": (
        UIR / "integration-prep/before-set/quickmatch-serve.png",
        "BEFORE (ported legacy HUD \u2014 UIR-00 register baseline)",
        "integration-prep/before-set/quickmatch-serve.png",
    ),
    "hud-after-prototype-1152x648.png": (
        PULL / "quickmatch-serve.png",
        "AFTER (recreated HUD, --ui=new \u2014 real capture, merged tip c9470e2)",
        "/tmp/padel-uir-pull-20260917/repo/godot/game/out/quickmatch-serve.png",
    ),
    "hud-after-prototype-hud-1152x648.png": (
        PULL / "hud.png",
        "AFTER (recreated HUD, later state \u2014 real capture, merged tip)",
        "/tmp/padel-uir-pull-20260917/repo/godot/game/out/hud.png",
    ),
    "hud-after-prototype-rally-1152x648.png": (
        PULL / "rally.png",
        "AFTER (recreated HUD, rally \u2014 real capture, merged tip)",
        "/tmp/padel-uir-pull-20260917/repo/godot/game/out/rally.png",
    ),
    "hud-prototype-premerge-1280x720.png": (
        PULL / "ui-prototype-hud-rally.png",
        "AUX (recreated HUD, 1280\u00d7720 \u2014 captured BEFORE the court merge)",
        "/tmp/padel-uir-pull-20260917/repo/godot/game/out/ui-prototype-hud-rally.png",
    ),
    "hud-after-prototype-serve-1280x720.png": (
        POST_1280 / "quickmatch-serve.png",
        "AFTER (recreated HUD, serve \u2014 real capture, merged tip 3238a50, POST-merge 1280\u00d7720)",
        "/tmp/padel-gatea-1280-20260917/out-after/quickmatch-serve.png",
    ),
    "hud-after-prototype-hud-1280x720.png": (
        POST_1280 / "hud.png",
        "AFTER (recreated HUD, later state \u2014 real capture, merged tip 3238a50, POST-merge 1280\u00d7720)",
        "/tmp/padel-gatea-1280-20260917/out-after/hud.png",
    ),
    "hud-after-prototype-rally-1280x720.png": (
        POST_1280 / "rally.png",
        "AFTER (recreated HUD, rally \u2014 real capture, merged tip 3238a50, POST-merge 1280\u00d7720)",
        "/tmp/padel-gatea-1280-20260917/out-after/rally.png",
    ),
}


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def md5(p: Path) -> str:
    return hashlib.md5(p.read_bytes()).hexdigest()


def copy_verified(src: Path, dst: Path) -> dict:
    shutil.copyfile(src, dst)
    s_src, s_dst = sha256(src), sha256(dst)
    assert s_src == s_dst, f"copy mismatch {src} -> {dst}"
    return {"src": src, "dst": dst, "sha256": s_src, "md5": md5(src)}


def compose(sheet_path: Path, title: str, panels, note_lines):
    """panels: list of (image_path, label1, label2)."""
    imgs = [Image.open(p).convert("RGB") for p, _, _ in panels]
    margin, gap, title_h, cap_h, line_h = 24, 24, 64, 106, 34
    f_title = ImageFont.truetype(FONT_B, 34)
    f_cap = ImageFont.truetype(FONT_B, 25)
    f_cap2 = ImageFont.truetype(FONT_R, 22)
    f_note = ImageFont.truetype(FONT_R, 21)
    f_note_b = ImageFont.truetype(FONT_B, 21)

    width = margin * 2 + sum(i.width for i in imgs) + gap * (len(imgs) - 1)
    note_h = 16 + len(note_lines) * 30 + 12
    height = margin * 2 + title_h + 12 + max(i.height for i in imgs) + cap_h + note_h

    canvas = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(canvas)
    d.text((margin, margin + 10), title, font=f_title, fill=CYAN)

    x = margin
    y = margin + title_h + 12
    for img, l1, l2, (p, _, _) in [(i, pl[1], pl[2], pl) for i, pl in zip(imgs, panels)]:
        canvas.paste(img, (x, y))
        h = sha256(p)
        d.text((x, y + img.height + 8), l1, font=f_cap, fill=INK)
        d.text((x, y + img.height + 8 + line_h), l2, font=f_cap2, fill=DIM)
        d.text(
            (x, y + img.height + 8 + line_h * 2),
            f"{img.width}\u00d7{img.height}  sha256 {h[:12]}\u2026",
            font=f_cap2,
            fill=DIM,
        )
        x += img.width + gap

    ny = y + max(i.height for i in imgs) + cap_h + 10
    d.rectangle([0, ny, width, height], fill=BAND)
    for i, line in enumerate(note_lines):
        f = f_note_b if i == 0 else f_note
        d.text((margin, ny + 12 + i * 30), line, font=f, fill=INK if i == 0 else DIM)

    canvas.save(sheet_path)
    print(f"sheet {sheet_path.name} {canvas.width}x{canvas.height}")


def main():
    PAIRS.mkdir(parents=True, exist_ok=True)
    SHEETS.mkdir(parents=True, exist_ok=True)

    records = []
    for name, (src, l1, l2) in SOURCES.items():
        dst = PAIRS / name
        rec = copy_verified(src, dst)
        rec["name"] = name
        records.append(rec)
        print(f"copy {name}  sha256 {rec['sha256'][:16]}\u2026")

    # SHA256SUMS for the pairs dir
    sums = PAIRS / "SHA256SUMS.txt"
    with open(sums, "w") as f:
        for r in records:
            f.write(f"{r['sha256']}  {r['name']}\n")
    print(f"wrote {sums}")

    menu_note = [
        "Contact sheet composed 2026-09-17 by a docs-only verification pass (no engine, no git writes, $0). Panels are "
        "unmodified real frames; each was copied byte-identical first and hash-verified (pairs/SHA256SUMS.txt).",
        "REFERENCE = capture of the frozen web build (read-only target). BEFORE = UIR-00 register baseline (ported Godot menu, commit 252ff60). "
        "AFTER = in-engine capture of the recreated MenuScreen at the merged tip c9470e2 (2026-09-17 02:26, isolated pull copy).",
        "The AFTER frame is byte-identical to the pre-merge capture ui-menu.png (md5 b99f1cc7\u2026): the court merge did not change the menu frame. "
        "No taste verdict is made or implied here \u2014 GATE-A (look/feel) belongs to Luca.",
    ]
    compose(
        SHEETS / "menu-before-after-1280x720.png",
        "MENU \u2014 before / after at the merged tip \u00b7 real captures, labels in captions",
        [
            (PAIRS / "menu-reference-web-1280x720.png", *SOURCES["menu-reference-web-1280x720.png"][1:]),
            (PAIRS / "menu-before-ported-1280x720.png", *SOURCES["menu-before-ported-1280x720.png"][1:]),
            (PAIRS / "menu-after-prototype-1280x720.png", *SOURCES["menu-after-prototype-1280x720.png"][1:]),
        ],
        menu_note,
    )

    hud_note = [
        "Contact sheet composed 2026-09-17 by a docs-only verification pass (no engine, no git writes, $0). Panels are "
        "unmodified real frames; each was copied byte-identical first and hash-verified (pairs/SHA256SUMS.txt).",
        "REFERENCE = frozen web build in-match HUD (EN locale in that capture; the port runs IT strings). BEFORE = UIR-00 register baseline (ported legacy HUD).",
        "AFTER = in-engine capture of the recreated HUD (--ui=new; legacy _hud hidden) over the merged 10\u00d720 m court, 1152\u00d7648 viewport \u2014 no post-merge 1280\u00d7720 "
        "prototype-HUD capture exists yet (see gate-a-review/REPORT.md \u00a75). S14 timing cues (ring/advice/verdict) are the merged branch's own and visible here.",
        "The pre-merge 1280\u00d7720 prototype frame is kept as pairs/hud-prototype-premerge-1280x720.png. No taste verdict is made or implied \u2014 GATE-A belongs to Luca.",
    ]
    compose(
        SHEETS / "hud-before-after.png",
        "IN-MATCH HUD \u2014 before / after at the merged tip \u00b7 real captures, labels in captions",
        [
            (PAIRS / "hud-reference-web-1280x720.png", *SOURCES["hud-reference-web-1280x720.png"][1:]),
            (PAIRS / "hud-before-ported-1280x720.png", *SOURCES["hud-before-ported-1280x720.png"][1:]),
            (PAIRS / "hud-after-prototype-1152x648.png", *SOURCES["hud-after-prototype-1152x648.png"][1:]),
        ],
        hud_note,
    )

    hud1280_note = [
        "Contact sheet composed 2026-09-17 by the post-pull closeout pass (merged-tip 1280\u00d7720 HUD recapture + this composition). Panels are unmodified real captures, each copied byte-identical and hash-verified (pairs/SHA256SUMS.txt).",
        "REFERENCE = frozen web build in-match HUD (EN locale in that capture; the port runs IT strings). BEFORE = UIR-00 register baseline (ported legacy HUD), integration-prep/before-set/quickmatch-serve.png.",
        "AFTER = in-engine capture of the recreated HUD (--ui=new; legacy _hud hidden) over the merged 10\u00d720 m court at 1280\u00d7720 \u2014 the post-merge 1280\u00d7720 frame the earlier pack recorded as missing. Merged tip 3238a50, 2026-09-17, Metal/Apple M4. S14 timing cues (ring/advice/verdict) are the merged branch's own and visible here.",
        "The earlier 1152\u00d7648 HUD sheet (sheets/hud-before-after.png, composed 2026-09-17) is retained unchanged with its own hash record. Pre-merge 1280\u00d7720 prototype frame kept as pairs/hud-prototype-premerge-1280x720.png. No taste verdict is made or implied \u2014 GATE-A belongs to Luca.",
    ]
    compose(
        SHEETS / "hud-before-after-1280x720.png",
        "IN-MATCH HUD \u2014 before / after at the merged tip, 1280\u00d7720 \u00b7 real captures, labels in captions",
        [
            (PAIRS / "hud-reference-web-1280x720.png", *SOURCES["hud-reference-web-1280x720.png"][1:]),
            (PAIRS / "hud-before-ported-1280x720.png", *SOURCES["hud-before-ported-1280x720.png"][1:]),
            (PAIRS / "hud-after-prototype-serve-1280x720.png", *SOURCES["hud-after-prototype-serve-1280x720.png"][1:]),
        ],
        hud1280_note,
    )

    # append sheet hashes next to the sums
    with open(sums, "a") as f:
        for s in sorted(SHEETS.glob("*.png")):
            f.write(f"{sha256(s)}  ../sheets/{s.name}\n")
    print("done")


if __name__ == "__main__":
    main()
