#!/usr/bin/env python3
"""Fold a PixelOver export into the game's sprite tree.

Usage:  import_sprites.py <Character>        # one
        import_sprites.py --all              # every character with a mapping

PixelOver writes <Character>/sprites/<Clip>/<Name>_<Clip>_dir<N>.png -- a folder
per clip named after the Meshy animation, holding one strip per direction. The
game wants the same files under its own clip names — `Idle_7` is an `Idle`, `mage_soell_cast`
is an `Attack` — so this is a copy with the clip renamed in both the folder and
the filename.

It also reflows a wrapped sheet. With the sprite-sheet constraint set to eight
columns, a nine-frame clip puts its ninth frame on a second row and the sheet
comes out two cells tall. Those frames are all present and in order; they just
need laying back out in a single row. A correct export needs none of this, but it
costs nothing to handle and saves a re-export when a clip slips.

The cell size is read from the first direction of each clip rather than fixed.
It has been 224, 480, 560, 768 and now 1024 as the art was re-exported to stop
clipping, and a stale constant does not fail -- it divides the strip by the wrong
number and reports a frame count that is quietly wrong.
"""
import os
import shutil
import sys

from PIL import Image

ROOT = "/home/emanzi/GODOT/Projects/KatanaKitsune"
EXPORTS = "/home/emanzi/GODOT/Projects/KatanaKitsuneWorkshop/meshy/pixelOverProjects"
ART = os.path.join(ROOT, "assets/sprites/monsters")
## PixelOver's sprite-sheet constraint, which every export shares. See
## meshy-export-chart.md -- it is what makes the cell size recoverable.
COLUMNS = 8

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
    "Kappa": ("kappa", {
        "Idle_03": "Idle",
        "Walking": "Walk",
        "Running": "Run",
        "air_squat": "Attack",
        "Backflip": "Attack2",
        "Hit_Reaction": "Hurt",
        "Dead": "Death",
        "Block1": "Block",
        "Alert": "Alert",
        "Angry_To_Tantrum_Sit": "Taunt",
    }),
    "KarasuShinobi": ("karasuShinobi", {
        "Idle_11": "Idle",
        "Walking": "Walk",
        "Running": "Run",
        "Sweeping_Kick": "Attack",
        "Backflip_and_Hooks": "Attack2",
        "Hit_Reaction_1": "Hurt",
        "Dead": "Death",
        "Block1": "Block",
        "Alert": "Alert",
        "360_Power_Spin_Jump": "Taunt",
    }),
}


def reflow(image, cell):
    """One row of frames, from a sheet that may have wrapped onto several.

    Returns None when the sheet is already a single row, so the caller can copy
    the file untouched rather than re-encoding it.
    """
    w, h = image.size
    if h == cell:
        return None
    cols, rows = w // cell, h // cell
    frames = []
    for r in range(rows):
        for c in range(cols):
            box = image.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell))
            ## Trailing cells of the last row are empty padding, not frames.
            if box.split()[3].getbbox():
                frames.append(box)
    out = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * cell, 0))
    return out


def do(character):
    if character not in MAPPING:
        print("%s: no clip mapping" % character)
        return 0
    folder, clips = MAPPING[character]
    src_root = os.path.join(EXPORTS, character, "sprites")
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
            ## The export is constrained to COLUMNS columns, so the cell is the
            ## sheet width divided by that -- not its height. A wrapped sheet is
            ## square-ish, and reading the height would take a two-row sheet of
            ## nine frames for four frames of double size.
            cell = image.size[0] // COLUMNS
            flat = reflow(image, cell)
            if flat is None:
                shutil.copy2(src, dst)
            else:
                flat.save(dst)
                reflowed += 1
            counts.add(Image.open(dst).size[0] // cell)
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
