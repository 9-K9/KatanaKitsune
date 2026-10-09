#!/usr/bin/env python3
"""Give each monster its full clip set as animations.

The scenes were built around a shared 5/8/10-state template. The new PixelOver
exports carry far more than that, and each monster's extra clips are what makes
it a distinct enemy rather than a reskin. This imports every clip as its own
animation, so the behaviour layer has something to drive.

Adds sprites + ext_resources + AtlasTextures + animations. FSM nodes and state
scripts are deliberately NOT touched here - a scene can hold animations nothing
plays yet, but an FSM node whose script is missing breaks the scene.
"""
import re, shutil, sys, glob
from pathlib import Path

GAME = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-")
EXP  = Path("/home/emanzi/Apps/PixelOver/exports/katanakitsune")
DRY  = "--apply" not in sys.argv
CELL, FRAMES = 768, 16

## scene -> (export folder, {animation name: export clip})
## Names already in a scene keep their art; new names are added.
PLAN = {
 "oni": ("oni", {
   "idle":"Idle_02", "walk":"Walking", "run":"Running", "alert":"Alert",
   "block":"Block2", "hurt":"Hit_Reaction_1", "death":"Dead",
   "attack":"Punch_Combo", "attack2":"Punch_Combo_1",
   "heavy":"Axe_Spin_Attack", "stomp":"Angry_Ground_Stomp", "dodge":"Backflip"}),
 "kappa": ("kappa", {
   "idle":"Idle_02", "walk":"Walking", "run":"Running", "alert":"Alert",
   "block":"Block1", "hurt":"Hit_Reaction", "death":"Dead",
   "attack":"Agree_Gesture", "attack2":"air_squat",
   "taunt":"Angry_To_Tantrum_Sit", "arise":"Arise", "dodge":"Backflip"}),
 "jorogumo": ("jorogumo", {
   "idle":"Idle_7", "walk":"Walking", "run":"Running", "alert":"Alert",
   "block":"Block10", "hurt":"Hit_Reaction", "death":"Dead",
   "attack":"mage_soell_cast", "attack2":"mage_soell_cast_3",
   "taunt":"Bubble_Dance", "dodge":"Quick_Step_and_Spin_Dodge",
   "quickwalk":"Quick_Walk"}),
 "karasuShinobi": ("karasushinobi", {
   "idle":"Idle_11", "walk":"Walking", "run":"Running", "alert":"Alert",
   "block":"Block1", "hurt":"Hit_Reaction_1", "death":"Dead",
   "attack":"Sweeping_Kick", "attack2":"360_Power_Spin_Jump",
   "crit":"Backflip_and_Hooks", "arise":"Backflip_and_Rise", "dodge":"Backflip"}),
 "tengu": ("tengu", {
   "idle":"Idle_3", "walk":"Walking", "run":"Running", "alert":"Alert",
   "hurt":"Hit_Reaction", "death":"Dead",
   "attack":"Roundhouse_Kick", "attack2":"Rising_Flying_Kick",
   "aerial":"360_Power_Spin_Jump", "shove":"Spartan_Kick",
   "crit":"Backflip_and_Hooks", "arise":"Backflip_and_Rise", "dodge":"Backflip"}),
 "yukiOnna": ("yukionna", {
   "idle":"Idle_7", "walk":"Walking", "run":"Running", "alert":"Alert",
   "block":"Block2", "hurt":"Hit_Reaction", "death":"Dead",
   "attack":"Angry_Stomp", "attack2":"Step_in_High_Kick",
   "taunt":"Bubble_Dance", "dodge":"Backflip_Jump", "quickwalk":"Quick_Walk"}),
}
COMPASS = {"east":"6","north":"4","northEast":"5","northWest":"3",
           "south":"8","southEast":"7","southWest":"1","west":"2"}
SPEED = {"idle":10.0,"walk":16.0,"run":24.0,"alert":10.0,"block":16.0,
         "hurt":16.0,"death":10.0,"taunt":10.0,"arise":16.0,"quickwalk":24.0}
LOOP  = {"idle","walk","run","quickwalk"}


def grid(path):
    """Export sheets are a single row, except tengu's 8x2 grid."""
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    w, h = Image.open(path).size
    return w // CELL, h // CELL


def run(scene, folder, mapping):
    tscn = GAME/"scenes/monsters"/f"{scene}.tscn"
    t = tscn.read_text()
    ext = {m.group(2): m.group(1) for m in re.finditer(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', t)}
    existing = {re.sub(r'_(east|north|northEast|northWest|south|southEast|southWest|west)$','',n)
                for n in re.findall(r'"name": &"([^"]+)"', t)}
    added = sorted(set(mapping) - existing)
    blocks, anims, exts, copied = [], [], [], 0
    cols = rows = None

    for ai, (anim, clip) in enumerate(sorted(mapping.items())):
        for comp, dirn in sorted(COMPASS.items()):
            hits = glob.glob(str(EXP/folder/clip/f"*_dir{dirn}.png"))
            if not hits:
                print(f"    MISSING {folder}/{clip} dir{dirn}"); return
            src = Path(hits[0])
            if cols is None:
                cols, rows = grid(src)
            cap = anim[0].upper()+anim[1:]
            rel = f"assets/sprites/monsters/{scene}/sprites/{cap}/{scene}_{cap}_dir{dirn}.png"
            dst = GAME/rel
            if not DRY:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
            copied += 1
            eid = f"tx_{anim}_{dirn}"
            exts.append(f'[ext_resource type="Texture2D" path="res://{rel}" id="{eid}"]')
            ids = []
            for f in range(FRAMES):
                aid = f"Ax_{ai:02d}_{dirn}_{f:02d}"; ids.append(aid)
                c, r = f % cols, f // cols
                blocks.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
                              f'atlas = ExtResource("{eid}")\n'
                              f'region = Rect2({c*CELL}, {r*CELL}, {CELL}, {CELL})\n')
            fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
            anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": %s\n}'
                         % (fr, "true" if anim in LOOP else "false", anim, comp,
                            SPEED.get(anim, 20.0)))

    # replace texture ext_resources, atlases and animations wholesale
    t = re.sub(r'\[ext_resource type="Texture2D" path="[^"]+" id="[^"]+"\]\n', '', t)
    last = list(re.finditer(r'^\[ext_resource [^\]]*\]$', t, re.M))[-1]
    t = t[:last.end()] + "\n" + "\n".join(exts) + t[last.end():]
    t = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("[^"]+"\)\nregion = Rect2\([^)]*\)\n\n?', '', t)
    sf = re.search(r'\[sub_resource type="SpriteFrames" id="[^"]+"\]', t)
    t = t[:sf.start()] + "\n".join(blocks) + "\n" + t[sf.start():]
    t = re.sub(r'animations = \[.*?\]\n', "animations = [" + ", ".join(anims) + "]\n",
               t, count=1, flags=re.S)
    ns, ne = t.count("[sub_resource "), t.count("[ext_resource ")
    t = re.sub(r'load_steps=\d+', f'load_steps={ns+ne+1}', t, count=1)

    print(f"  {scene:15s} clips={len(mapping):2d} grid={cols}x{rows} pngs={copied} "
          f"atlases={len(blocks)} anims={len(anims)} load_steps={ns+ne+1}")
    print(f"  {'':15s} NEW: {added}")
    if not DRY:
        shutil.copy2(tscn, str(tscn)+".bak2")
        tscn.write_text(t)


for scene, (folder, mapping) in PLAN.items():
    run(scene, folder, mapping)
print("\nDRY RUN — re-run with --apply" if DRY else "\nAPPLIED")
