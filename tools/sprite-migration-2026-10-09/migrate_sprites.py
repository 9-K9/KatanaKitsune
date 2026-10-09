#!/usr/bin/env python3
"""Migrate KatanaKitsune sprites 480x480/8-frame -> 768x768/16-frame.

- copies new PixelOver exports onto the existing in-game filenames so every
  ext_resource path and uid stays valid
- adds a new katanaDeath_* animation set (death with weapon drawn)
- regenerates all AtlasTexture regions at 768 and 16 frames per animation
- doubles every animation speed so timing is unchanged
- fixes the pre-existing death_southWest -> dir1 bug (should be dir7)
"""
import re, shutil, sys, os, collections
from pathlib import Path

GAME = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-")
SPR  = GAME/"assets/sprites/characters/KatanaKitsune/sprites"
NEW  = Path("/home/emanzi/Apps/PixelOver/exports/katanakitsune/katanakitsune")
TSCN = GAME/"scenes/characters/KatanaKitsune.tscn"
DRY  = "--apply" not in sys.argv

KATANA_GROUP = {"KatanaBlock","KatanaBlockCrouched","KatanaChargeAttack",
    "KatanaCounterSlash","KatanaDraw","KatanaIdle","KatanaJump","KatanaKick",
    "KatanaRun","KatanaSeath","KatanaSlashCrouched","KatanaSlashMid","KatanaWalk"}

def new_path(folder, n):
    """in-game folder + dirN -> new export file"""
    if folder in KATANA_GROUP:
        return NEW/"katana"/folder/f"KatanaKitsume_{folder}_dir{n}.png"
    if folder == "Death":                       # sheathed death keeps the old slot
        return NEW/"nokatana/Death"/f"KatanaKitsumeRPG_export_Death_dir{n}.png"
    return NEW/"nokatana"/folder/f"KatanaKitsumeRPG_export_{folder}_dir{n}.png"

def katana_death_src(n):
    return NEW/"katana/Death"/f"KatanaKitsume_Death_dir{n}.png"

t = TSCN.read_text()

ext   = {m.group(2): m.group(1) for m in re.finditer(
    r'\[ext_resource type="Texture2D" uid="[^"]+" path="([^"]+)" id="([^"]+)"\]', t)}
atlas = {m.group(1): m.group(2) for m in re.finditer(
    r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\natlas = ExtResource\("([^"]+)"\)', t)}
blob  = re.search(r'animations = \[(.*?)\]\n', t, re.S)

anims = []
for blk in re.finditer(
        r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)\s*\}',
        blob.group(1), re.S):
    ids   = re.findall(r'SubResource\("([^"]+)"\)', blk.group(1))
    files = {ext[atlas[i]] for i in ids if i in atlas}
    anims.append(dict(name=blk.group(3), loop=blk.group(2),
                      speed=float(blk.group(4)), src=sorted(files)[0]))
assert len(anims) == 256, len(anims)

DIRMAP = {}                       # compass -> dirN, learned from a clean animation
for a in anims:
    base, comp = a['name'].rsplit('_', 1)
    if base == 'walk':
        DIRMAP[comp] = re.search(r'dir(\d)\.png', a['src']).group(1)
assert len(set(DIRMAP.values())) == 8, DIRMAP

# ---- 1. copy PNGs onto existing in-game names -------------------------------
copied = missing = 0
for a in anims:
    folder = a['src'].split('/')[-2]
    n      = re.search(r'dir(\d)\.png', a['src']).group(1)
    if a['name'] == 'death_southWest':          # bug fix: was dir1
        n = DIRMAP['southWest']
        a['src'] = re.sub(r'dir\d\.png', f'dir{n}.png', a['src'])
    src = new_path(folder, n)
    dst = GAME/a['src'].replace('res://', '')
    if not src.exists():
        print(f"  MISSING {src}"); missing += 1; continue
    if not DRY:
        shutil.copy2(src, dst)
    copied += 1

# ---- 2. new katanaDeath set -------------------------------------------------
kd_dir = SPR/"KatanaDeath"
kd_files = {}
for comp, n in DIRMAP.items():
    src = katana_death_src(n)
    dst = kd_dir/f"KatanaKitsune_KatanaDeath_dir{n}.png"
    if not src.exists():
        print(f"  MISSING {src}"); missing += 1; continue
    kd_files[comp] = (f"res://assets/sprites/characters/KatanaKitsune/sprites/KatanaDeath/KatanaKitsune_KatanaDeath_dir{n}.png", src, dst)
    if not DRY:
        kd_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

print(f"PNG copy: {copied} replaced, {len(kd_files)} new katanaDeath, {missing} missing")
if missing:
    sys.exit("aborting: missing source files")

# ---- 3. new ext_resources for katanaDeath -----------------------------------
ext_ids = {}
last_ext = list(re.finditer(r'^\[ext_resource [^\]]*\]$', t, re.M))[-1]
ins = ""
for i, (comp, (respath, _, _)) in enumerate(sorted(kd_files.items())):
    rid = f"kd_tex_{i}"
    ext_ids[comp] = rid
    ins += f'\n[ext_resource type="Texture2D" path="{respath}" id="{rid}"]'
t = t[:last_ext.end()] + ins + t[last_ext.end():]

# ---- 4. regenerate AtlasTextures + animations --------------------------------
FRAMES, CELL = 16, 768
atlas_blocks, new_anims = [], []

def emit(tag, extid, loop, name, speed):
    ids = []
    for f in range(FRAMES):
        aid = f"At_{tag}_{f:02d}"
        ids.append(aid)
        atlas_blocks.append(
            f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
            f'atlas = ExtResource("{extid}")\n'
            f'region = Rect2({f*CELL}, 0, {CELL}, {CELL})\n')
    frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
    new_anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                     % (frames, loop, name, speed))

path2ext = {v: k for k, v in ext.items()}
for idx, a in enumerate(anims):
    emit(f"{idx:03d}", path2ext[a['src']], a['loop'], a['name'], a['speed']*2)
for j, (comp, (respath, _, _)) in enumerate(sorted(kd_files.items())):
    emit(f"kd{j}", ext_ids[comp], "false", f"katanaDeath_{comp}", 10.0)

t = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("[^"]+"\)\nregion = Rect2\([^)]*\)\n\n?', '', t)
sf = re.search(r'\[sub_resource type="SpriteFrames" id="[^"]+"\]', t)
t = t[:sf.start()] + "\n".join(atlas_blocks) + "\n" + t[sf.start():]
t = re.sub(r'animations = \[.*?\]\n', "animations = [" + ", ".join(new_anims) + "]\n", t, count=1, flags=re.S)

n_sub = t.count("[sub_resource ")
n_ext = t.count("[ext_resource ")
t = re.sub(r'load_steps=\d+', f'load_steps={n_sub+n_ext+1}', t, count=1)

print(f"AtlasTextures: 2048 -> {len(atlas_blocks)}")
print(f"animations:    256 -> {len(new_anims)}  (speeds doubled)")
print(f"load_steps -> {n_sub+n_ext+1}  (sub={n_sub} ext={n_ext})")

if DRY:
    print("\nDRY RUN - nothing written. re-run with --apply")
else:
    shutil.copy2(TSCN, str(TSCN)+".bak")
    TSCN.write_text(t)
    print(f"\nwrote {TSCN}  (backup at {TSCN}.bak)")
