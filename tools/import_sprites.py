#!/usr/bin/env python3
"""Fold a PixelOver export into the game's sprite tree.

Usage:  import_sprites.py <Character>        # one
        import_sprites.py --all              # every character with a mapping

PixelOver writes a folder per clip named after the Meshy animation, holding one
strip per direction already named <Name>_<Clip>_dir<N>.png. The game wants the
same files under its own clip names — `Idle_7` is an `Idle`, `mage_soell_cast`
is an `Attack` — so this is a copy with the clip renamed in both the folder and
the filename.

It also reflows a wrapped sheet. With the sprite-sheet constraint set to eight
columns, a nine-frame clip puts its ninth frame on a second row and the sheet
comes out 960 tall instead of 480. Those frames are all present and in order;
they just need laying back out in a single row. A correct export needs none of
this, but it costs nothing to handle and saves a re-export when a clip slips.
"""
import os
import shutil
import sys

from PIL import Image

ROOT = "/home/emanzi/GODOT/Projects/KatanaKitsune"
EXPORTS = "/home/emanzi/GODOT/Projects/KatanaKitsuneWorkshop/meshy/pixelOverProjects"
ART = os.path.join(ROOT, "assets/sprites/monsters")
CELL = 768

## PixelOver clip name -> the folder the game reads it from. Clips absent here
## are not imported: every character exports more than the game uses.
##
## The folder is what decides the animation's identity — build_enemy_scene.py
## matches on it, never on the Meshy name.
MAPPING = {
    "Jorogumo": ("jorogumo", {
        "Idle_7": "Idle",
        "Walking": "Walk",
        "Running": "Run",
        "mage_soell_cast": "Attack",
        "mage_soell_cast_3": "Attack2",
        "Hit_Reaction": "Hurt",
        "Dead": "Death",
        "Block10": "Block",
        "Alert": "Alert",
        "Bubble_Dance": "Taunt",
    }),
}


def reflow(image):
    """One row of frames, from a sheet that may have wrapped onto several.

    Returns None when the sheet is already a single row, so the caller can copy
    the file untouched rather than re-encoding it.
    """
    w, h = image.size
    if h == CELL:
        return None
    cols, rows = w // CELL, h // CELL
    frames = []
    for r in range(rows):
        for c in range(cols):
            cell = image.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
            ## Trailing cells of the last row are empty padding, not frames.
            if cell.split()[3].getbbox():
                frames.append(cell)
    out = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * CELL, 0))
    return out


def do(character):
    if character not in MAPPING:
        print("%s: no clip mapping" % character)
        return 0
    folder, clips = MAPPING[character]
    src_root = os.path.join(EXPORTS, character)
    if not os.path.isdir(src_root):
        print("%s: nothing exported at %s" % (character, src_root))
        return 0
    title = folder[0].upper() + folder[1:]

    copied = reflowed = 0
    for src_clip, dst_clip in sorted(clips.items()):
        src_dir = os.path.join(src_root, src_clip)
        if not os.path.isdir(src_dir):
            print("  %-28s MISSING" % src_clip)
            continue
        dst_dir = os.path.join(ART, folder, "sprites", dst_clip)
        os.makedirs(dst_dir, exist_ok=True)
        counts = set()
        for d in range(1, 9):
            src = os.path.join(src_dir, "%s_%s_dir%d.png" % (character, src_clip, d))
            if not os.path.exists(src):
                print("  %-28s missing dir%d" % (src_clip, d))
                continue
            dst = os.path.join(dst_dir, "%s_%s_dir%d.png" % (title, dst_clip, d))
            image = Image.open(src).convert("RGBA")
            flat = reflow(image)
            if flat is None:
                shutil.copy2(src, dst)
            else:
                flat.save(dst)
                reflowed += 1
            counts.add(Image.open(dst).size[0] // CELL)
            copied += 1
        note = "" if len(counts) == 1 else "   <-- directions disagree: %s" % sorted(counts)
        print("  %-28s -> %-8s %d frames%s"
              % (src_clip, dst_clip, sorted(counts)[0] if counts else 0, note))
    print("%s: %d files, %d reflowed" % (character, copied, reflowed))
    return copied


def main():
    args = sys.argv[1:]
    names = sorted(MAPPING) if (args and args[0] == "--all") else args
    if not names:
        print(__doc__)
        return
    for n in names:
        do(n)


if __name__ == "__main__":
    main()
