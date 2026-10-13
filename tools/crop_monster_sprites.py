#!/usr/bin/env python3
"""Losslessly trims transparent padding out of monster sprite strips.

The rendered monster sheets ship every frame on a huge fixed canvas (kasha,
ninaNinja and yokailord use 768x768 for a ~160px-tall monster), and Godot
decodes every strip to raw RGBA, so the padding alone cost ~13 GB of memory.

Each frame is cropped to its opaque pixels, grown symmetrically about the
frame's own centre. AnimatedSprite2D draws every frame centred on `offset`,
so a centre-preserving crop puts every pixel exactly where it was: no offset,
scene or script changes needed, and flip_h/flip_v stay correct.

The strips are repacked left to right and each AtlasTexture region in the
scene is rewritten to point at its new spot. Idempotent: re-running it on
already-trimmed sheets changes nothing. Run it again after rebuilding a
monster with build_enemy_scene.py.

    python3 tools/crop_monster_sprites.py            # dry run, prints savings
    python3 tools/crop_monster_sprites.py --apply    # rewrite PNGs + scenes
    python3 tools/crop_monster_sprites.py --apply kasha tengu
"""
import glob
import os
import re
import sys

from PIL import Image

MARGIN = 2  # transparent border kept round each frame for filtering/shaders
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT_RE = re.compile(
    r'\[ext_resource type="Texture2D"[^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"\]')
ATLAS_RE = re.compile(
    r'atlas = ExtResource\("([^"]+)"\)\n'
    r'region = Rect2\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)')


def centred_crop(image, rect):
    """Smallest rect inside `rect`, centred on its centre, holding every
    opaque pixel plus MARGIN. Keeps the original size's parity so the centre
    lands on the same half-pixel."""
    x, y, w, h = rect
    box = image.crop((x, y, x + w, y + h)).getbbox()
    if box is None:
        cw, ch = w % 2 or 2, h % 2 or 2
    else:
        half_w = max(w / 2 - box[0], box[2] - w / 2) + MARGIN
        half_h = max(h / 2 - box[1], box[3] - h / 2) + MARGIN
        cw = min(w, 2 * int(half_w + 0.5) + w % 2)
        ch = min(h, 2 * int(half_h + 0.5) + h % 2)
    return (x + (w - cw) // 2, y + (h - ch) // 2, cw, ch)


def process(scene, apply):
    text = open(scene).read()
    ext = {m.group(2): m.group(1) for m in EXT_RE.finditer(text)}
    regions = {}
    for m in ATLAS_RE.finditer(text):
        rect = tuple(int(float(v)) for v in m.group(2, 3, 4, 5))
        regions.setdefault(ext[m.group(1)], set()).add(rect)
    if not regions:
        return 0, 0
    before = after = 0
    moved = {}
    for path, rects in regions.items():
        image = Image.open(path).convert("RGBA")
        before += image.width * image.height * 4
        crops = [(r, centred_crop(image, r)) for r in sorted(rects)]
        width = sum(c[2] for _, c in crops)
        height = max(c[3] for _, c in crops)
        after += width * height * 4
        if not apply:
            continue
        sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        cursor = 0
        for old, (cx, cy, cw, ch) in crops:
            sheet.paste(image.crop((cx, cy, cx + cw, cy + ch)), (cursor, 0))
            moved[(path, old)] = (cursor, 0, cw, ch)
            cursor += cw
        if sheet.size != image.size or sheet.tobytes() != image.tobytes():
            sheet.save(path, optimize=True)
    if apply:
        def rewrite(m):
            rect = tuple(int(float(v)) for v in m.group(2, 3, 4, 5))
            x, y, w, h = moved[(ext[m.group(1)], rect)]
            return 'atlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)' % (
                m.group(1), x, y, w, h)
        new_text = ATLAS_RE.sub(rewrite, text)
        if new_text != text:
            open(scene, "w").write(new_text)
    return before, after


def main():
    os.chdir(ROOT)
    apply = "--apply" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    total_before = total_after = 0
    for scene in sorted(glob.glob("scenes/monsters/*.tscn")):
        name = os.path.splitext(os.path.basename(scene))[0]
        if only and name not in only:
            continue
        before, after = process(scene, apply)
        if before:
            total_before += before
            total_after += after
            print("%-16s %6.2f GB -> %5.2f GB" % (name, before / 1e9, after / 1e9))
    print("%-16s %6.2f GB -> %5.2f GB%s" % ("TOTAL", total_before / 1e9,
          total_after / 1e9, "" if apply else "   (dry run, pass --apply)"))


if __name__ == "__main__":
    main()
