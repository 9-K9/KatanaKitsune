#!/usr/bin/env python3
"""Crop every sprite sheet down to the space its character actually uses.

The PixelOver canvas is 768x768 for everyone, but what each character draws in
it varies enormously: Kappa occupies 270x227, Tengu 664x435. Shipping all of
them at 768 means ~70% of every texture is transparent padding that still has
to be decoded on import, held in RAM at runtime, and paid for per frame.

Each character gets a cell sized to its own content plus a margin. Sheets are
normalised to a single row of 16 frames, which also flattens Tengu's 8x2 grid.
No resampling anywhere - every output pixel is copied from the source.

Atlas regions in each scene are renumbered to match, and the AnimatedSprite2D
gets a compensating offset so nothing moves on screen: Godot draws these
centred, so shrinking the cell would otherwise shift every character.
"""
import re, sys, shutil, glob, os
from pathlib import Path
from PIL import Image
Image.MAX_IMAGE_PIXELS = None

GAME = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-")
EXP  = Path("/home/emanzi/Apps/PixelOver/exports/katanakitsune")
DRY  = "--apply" not in sys.argv
SRC_CELL = 768
FRAMES   = 16
MARGIN   = 8          # breathing room so nothing sits flush against an edge

## measured content bounds, x[L,R] y[T,B], within the 768 source cell
BOUNDS = {
 "KatanaKitsune": (176, 592, 232, 557),
 "oni":           (198, 570, 234, 579),
 "kappa":         (249, 519, 309, 536),
 "jorogumo":      (144, 624, 235, 587),
 "karasuShinobi": ( 56, 712, 195, 637),
 "tengu":         ( 52, 716, 196, 631),
 "yukiOnna":      (250, 518, 295, 527),
}
SCENE = {"KatanaKitsune": "scenes/characters/KatanaKitsune.tscn"}
for m in ["oni","kappa","jorogumo","karasuShinobi","tengu","yukiOnna"]:
    SCENE[m] = f"scenes/monsters/{m}.tscn"

## the six monsters were deleted by a mistimed cleanup; regenerate from the
## exports. The player's sheets survived and are cropped in place.
EXPORT_DIR = {"oni":"oni","kappa":"kappa","jorogumo":"jorogumo",
              "karasuShinobi":"karasushinobi","tengu":"tengu","yukiOnna":"yukionna"}
CLIPS = {
 "oni": {"idle":"Idle_02","walk":"Walking","run":"Running","alert":"Alert","block":"Block2",
   "hurt":"Hit_Reaction_1","death":"Dead","attack":"Punch_Combo","attack2":"Punch_Combo_1",
   "heavy":"Axe_Spin_Attack","stomp":"Angry_Ground_Stomp","dodge":"Backflip"},
 "kappa": {"idle":"Idle_02","walk":"Walking","run":"Running","alert":"Alert","block":"Block1",
   "hurt":"Hit_Reaction","death":"Dead","attack":"Agree_Gesture","attack2":"air_squat",
   "taunt":"Angry_To_Tantrum_Sit","arise":"Arise","dodge":"Backflip"},
 "jorogumo": {"idle":"Idle_7","walk":"Walking","run":"Running","alert":"Alert","block":"Block10",
   "hurt":"Hit_Reaction","death":"Dead","attack":"mage_soell_cast","attack2":"mage_soell_cast_3",
   "taunt":"Bubble_Dance","dodge":"Quick_Step_and_Spin_Dodge","quickwalk":"Quick_Walk"},
 "karasuShinobi": {"idle":"Idle_11","walk":"Walking","run":"Running","alert":"Alert","block":"Block1",
   "hurt":"Hit_Reaction_1","death":"Dead","attack":"Sweeping_Kick","attack2":"360_Power_Spin_Jump",
   "crit":"Backflip_and_Hooks","arise":"Backflip_and_Rise","dodge":"Backflip"},
 "tengu": {"idle":"Idle_3","walk":"Walking","run":"Running","alert":"Alert","hurt":"Hit_Reaction",
   "death":"Dead","attack":"Roundhouse_Kick","attack2":"Rising_Flying_Kick",
   "aerial":"360_Power_Spin_Jump","shove":"Spartan_Kick","crit":"Backflip_and_Hooks",
   "arise":"Backflip_and_Rise","dodge":"Backflip"},
 "yukiOnna": {"idle":"Idle_7","walk":"Walking","run":"Running","alert":"Alert","block":"Block2",
   "hurt":"Hit_Reaction","death":"Dead","attack":"Angry_Stomp","attack2":"Step_in_High_Kick",
   "taunt":"Bubble_Dance","dodge":"Backflip_Jump","quickwalk":"Quick_Walk"},
}


def even(n): return n + (n % 2)


def cell_for(name):
    L, R, T, B = BOUNDS[name]
    ox = max(0, L - MARGIN); oy = max(0, T - MARGIN)
    cw = even(min(SRC_CELL - ox, (R - L) + 2 * MARGIN))
    ch = even(min(SRC_CELL - oy, (B - T) + 2 * MARGIN))
    return ox, oy, cw, ch


def crop_sheet(src_img, ox, oy, cw, ch):
    """Source may be a single row or a grid; output is always one row."""
    W, H = src_img.size
    cols, rows = W // SRC_CELL, H // SRC_CELL
    out = Image.new("RGBA", (FRAMES * cw, ch), (0, 0, 0, 0))
    for f in range(FRAMES):
        c, r = f % cols, f // cols
        box = (c * SRC_CELL + ox, r * SRC_CELL + oy,
               c * SRC_CELL + ox + cw, r * SRC_CELL + oy + ch)
        out.paste(src_img.crop(box), (f * cw, 0))
    return out


def run(name):
    ox, oy, cw, ch = cell_for(name)
    scene = GAME / SCENE[name]
    t = scene.read_text()
    ## Only this character's own sheets. "/sprites/" alone also catches
    ## assets/sprites/fx/projectiles/*, which are not frame strips.
    root = ("assets/sprites/characters/KatanaKitsune/sprites/" if name == "KatanaKitsune"
            else f"assets/sprites/monsters/{name}/sprites/")
    refs = sorted({q.replace("res://", "") for q in
                   re.findall(r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)"', t)
                   if q.replace("res://", "").startswith(root)})

    written = missing = 0
    for rel in refs:
        dst = GAME / rel
        if name == "KatanaKitsune":
            src = dst if dst.exists() else None
        else:
            ## regenerate from the export: .../sprites/<Cap>/<scene>_<Cap>_dirN.png
            ## Anchored to the end — the path also contains "assets/sprites/",
            ## and an unanchored match picks that one up and returns "monsters".
            m = re.search(r"/sprites/([^/]+)/[^/]+_dir(\d)\.png$", rel)
            if m is None:
                print(f"    UNPARSED path {rel}"); missing += 1; continue
            clip = CLIPS[name].get(m.group(1)[0].lower() + m.group(1)[1:])
            hits = glob.glob(str(EXP / EXPORT_DIR[name] / clip / f"*_dir{m.group(2)}.png")) if clip else []
            src = Path(hits[0]) if hits else None
        if src is None:
            print(f"    MISSING source for {rel}"); missing += 1; continue
        img = crop_sheet(Image.open(src).convert("RGBA"), ox, oy, cw, ch)
        if not DRY:
            dst.parent.mkdir(parents=True, exist_ok=True)
            img.save(dst, "PNG")
        written += 1

    ## regions
    t = re.sub(r'(\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("[^"]+"\)\n)region = Rect2\(\d+, \d+, \d+, \d+\)',
               lambda m: m.group(1) + "region = Rect2(%d, 0, %d, %d)" % (0, cw, ch), t)
    idx = {}
    def renumber(m):
        aid = m.group(1)
        n = idx.setdefault(m.group(2), 0)
        idx[m.group(2)] = n + 1
        return (f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = ExtResource("{m.group(2)}")\n'
                f'region = Rect2({(n % FRAMES) * cw}, 0, {cw}, {ch})')
    t = re.sub(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\natlas = ExtResource\("([^"]+)"\)\nregion = Rect2\(\d+, 0, \d+, \d+\)',
               renumber, t)

    ## compensating offset so the art does not move on screen
    dx = ox + cw / 2.0 - SRC_CELL / 2.0
    dy = oy + ch / 2.0 - SRC_CELL / 2.0
    def add_offset(m):
        head = m.group(1)
        if "offset = Vector2" in m.group(0):
            return re.sub(r'offset = Vector2\(([-\d.]+), ([-\d.]+)\)',
                          lambda o: "offset = Vector2(%g, %g)" % (float(o.group(1)) + dx, float(o.group(2)) + dy),
                          m.group(0))
        return head + "offset = Vector2(%g, %g)\n" % (dx, dy)
    t = re.sub(r'(\[node name="AnimatedSprite2D" type="AnimatedSprite2D"[^\]]*\]\n)((?:[a-z_]+ = .*\n)*)',
               add_offset, t, count=1)

    ns, ne = t.count("[sub_resource "), t.count("[ext_resource ")
    t = re.sub(r'load_steps=\d+', f'load_steps={ns+ne+1}', t, count=1)

    before = SRC_CELL * SRC_CELL
    print(f"  {name:15s} cell {cw}x{ch}  crop@({ox},{oy})  sheets={written} missing={missing}")
    print(f"  {'':15s} offset {dx:+g},{dy:+g}   {before/(cw*ch):.2f}x smaller   "
          f"{written*cw*ch*FRAMES*4/1073741824:.2f} GB (was {written*before*FRAMES*4/1073741824:.2f})")
    if missing == 0 and not DRY:
        scene.write_text(t)


for n in BOUNDS:
    run(n)
print("\nDRY RUN — re-run with --apply" if DRY else "\nAPPLIED")
