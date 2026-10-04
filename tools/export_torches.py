#!/usr/bin/env python3
"""Pull the torch art out of PixelLab and lay it out the way Breakable wants.

Breakable drives one Sprite2D with hframes, so both the flame loop and the
shatter have to be horizontal strips of equal cells rather than separate files
per frame. This downloads each object, finds its animations by display name and
writes the strips.

The Backblaze frame URLs that get_object prints are not readable without a
token, but /mcp/objects/<id>/download is, and it returns the whole object as a
zip. That is the export route.

Usage:  export_torches.py            # everything in TORCHES
        export_torches.py <name> ..  # just these
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

from PIL import Image

ROOT = "/home/emanzi/GODOT/Projects/KatanaKitsune"
OUT = os.path.join(ROOT, "assets/sprites/props/torches")
API = "https://api.pixellab.ai/mcp/objects/%s/download"

## What each clip was generated with. These are how the two are told apart, so
## changing one means regenerating that clip for every torch.
LIT_FRAMES = 6
BREAK_FRAMES = 4

## Trailing break frames to drop, per torch.
##
## persist_broken keeps the last frame on screen for the rest of the floor, so
## it is the one frame that has to read as destroyed. The paper lantern's
## generator kept relighting it on the final frame — dark through the middle,
## bright again at the end — which would leave a shattered lantern glowing while
## throwing no light. Its first three frames are right, so the fix is to stop
## before the bad one rather than spend more generations arguing with it.
TRIM_BREAK = {"paperLantern": 1}

## name -> (object id, light colour, light energy)
## The colour is the flame's own, so the pool of light a torch throws matches
## what the sprite shows rather than every torch washing the room the same
## orange.
TORCHES = {
    "ironBrazier":   ("48432117-292c-47d0-8765-2bb29004dcc9", (1.00, 0.60, 0.26), 1.35),
    "stoneLantern":  ("8c5f0135-921d-4411-a456-6a224b6d7180", (1.00, 0.78, 0.42), 1.10),
    "stakeTorch":    ("7679d906-ec70-4ec5-8ef2-fd52305b4f41", (1.00, 0.64, 0.30), 1.45),
    "paperLantern":  ("04e12bcd-1e9e-4a5e-896b-d7e01ecb3eca", (1.00, 0.72, 0.46), 1.00),
    "spiritCenser":  ("da1d9ec9-59c9-4f38-b82f-193e409678e2", (0.52, 0.76, 1.00), 1.15),
    "bambooTorch":   ("6c6b45f7-a59f-4aa2-9c29-31665b5ed9df", (0.62, 1.00, 0.66), 1.05),
}


def fetch(object_id):
    with urllib.request.urlopen(API % object_id, timeout=120) as r:
        return zipfile.ZipFile(io.BytesIO(r.read()))


def strip(frames):
    """Lay frames out left to right in one image of equal cells."""
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def animation_dirs(zf):
    """Animation folder name -> sorted frame paths, in frame order."""
    found = {}
    for path in zf.namelist():
        if not path.startswith("animations/") or not path.endswith(".png"):
            continue
        folder = path.split("/")[1]
        found.setdefault(folder, []).append(path)
    for paths in found.values():
        paths.sort()
    return found


def export(name, object_id):
    zf = fetch(object_id)
    os.makedirs(OUT, exist_ok=True)
    wrote = []

    base = Image.open(io.BytesIO(zf.read("rotations/unknown.png"))).convert("RGBA")
    base.save(os.path.join(OUT, "%s.png" % name))
    wrote.append("%s.png (%dx%d)" % (name, base.width, base.height))

    ## Told apart by length, not by name. The zip folders are the animation
    ## description slugged, and matching words against those silently mislabels
    ## any clip phrased differently — "scattering", "toppling" and "tearing" all
    ## missed a list built around "shatter", and the 4-frame break was written
    ## over the 6-frame flame. Length is what the generation actually fixed.
    for paths in animation_dirs(zf).values():
        frames = [Image.open(io.BytesIO(zf.read(p))).convert("RGBA") for p in paths]
        if len(frames) == LIT_FRAMES:
            suffix = "_lit"
        elif len(frames) == BREAK_FRAMES:
            suffix = "_broken"
            drop = TRIM_BREAK.get(name, 0)
            if drop:
                frames = frames[:-drop]
        else:
            wrote.append("skipped a %d-frame clip: expected %d or %d"
                         % (len(frames), LIT_FRAMES, BREAK_FRAMES))
            continue
        sheet = strip(frames)
        sheet.save(os.path.join(OUT, "%s%s.png" % (name, suffix)))
        wrote.append("%s%s.png (%d frames, %dx%d)"
                     % (name, suffix, len(frames), sheet.width, sheet.height))
    return wrote


SCENES = os.path.join(ROOT, "scenes/props/torches")

SCENE = '''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/system/Breakable.gd" id="1_s"]
[ext_resource type="Texture2D" path="res://assets/sprites/props/torches/%(name)s_lit.png" id="2_lit"]
[ext_resource type="Texture2D" path="res://assets/sprites/props/torches/%(name)s_broken.png" id="3_broken"]
[ext_resource type="Texture2D" path="res://assets/sprites/ui/glow.tres" id="4_glow"]

[sub_resource type="ConvexPolygonShape2D" id="ConvexPolygonShape2D_t"]
points = PackedVector2Array(-11, 0, 0, -6, 11, 0, 0, 6)

[node name="%(title)s" type="StaticBody2D" groups=["breakable"]]
y_sort_enabled = true
collision_layer = 3
script = ExtResource("1_s")
max_health = 20.0
lit_frames = %(lit)d
lit_fps = 9.0
break_texture = ExtResource("3_broken")
break_frames = %(broken)d
break_frame_time = 0.08
persist_broken = true

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -34)
texture = ExtResource("2_lit")
hframes = %(lit)d

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("ConvexPolygonShape2D_t")

[node name="PointLight2D" type="PointLight2D" parent="."]
position = Vector2(0, -44)
texture = ExtResource("4_glow")
color = Color(%(r).2f, %(g).2f, %(b).2f, 1)
energy = %(energy).2f
texture_scale = %(reach).2f
'''


def write_scene(name):
    """A torch scene, sized from the strips that were just exported."""
    lit_path = os.path.join(OUT, "%s_lit.png" % name)
    broken_path = os.path.join(OUT, "%s_broken.png" % name)
    if not (os.path.exists(lit_path) and os.path.exists(broken_path)):
        return "%s: needs both strips, scene not written" % name
    lit = Image.open(lit_path)
    broken = Image.open(broken_path)
    ## Square cells, so the frame count is just how many fit across.
    lit_n = lit.width // lit.height
    broken_n = broken.width // broken.height
    _, colour, energy = TORCHES[name]
    os.makedirs(SCENES, exist_ok=True)
    body = SCENE % {
        "name": name,
        "title": name[0].upper() + name[1:],
        "lit": lit_n,
        "broken": broken_n,
        "r": colour[0], "g": colour[1], "b": colour[2],
        "energy": energy,
        ## Brighter torches reach further, so the pool of light matches the
        ## source rather than every flame lighting the same circle.
        "reach": 2.0 + energy,
    }
    open(os.path.join(SCENES, "%s.tscn" % name), "w").write(body)
    return "%s.tscn (lit %df, broken %df)" % (name, lit_n, broken_n)


def main():
    want = sys.argv[1:] or sorted(TORCHES)
    for name in want:
        if name not in TORCHES:
            print("%-14s not in the table" % name)
            continue
        try:
            for line in export(name, TORCHES[name][0]):
                print("  %s" % line)
            print("  %s" % write_scene(name))
        except Exception as exc:
            print("%-14s FAILED %s" % (name, exc))


if __name__ == "__main__":
    main()
