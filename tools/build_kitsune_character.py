#!/usr/bin/env python3
"""Build the Kitsune player character from the new-model PixelOver export.

The player used to be scenes/characters/KatanaKitsune.tscn drawing from
assets/sprites/characters/KatanaKitsune/sprites. A re-exported model that fits
the game's theme better replaces her as the main character; the old one is
kept untouched so it can come back later as a settings cheat.

Rather than hand-build a second 40k-line scene, this clones the existing one
and swaps only the sheets behind each frame: every state node, animation name,
AnimationPlayer track, collision shape, light and timing is byte-identical.

Sheets
------
The new export is 16 frames of 480x480 per sheet. The game's sheets are 16
frames of 432x342 (the old 768 canvas cropped to the character's extent, see
sprite-migration-2026-10-09/recrop.py). To keep the AtlasTexture regions and
the AnimatedSprite2D offset untouched, each new frame is cropped to the same
432x342 cell, positioned so her feet land where the old model's did:

    old idle feet  y=244, centre x=216 (in the 432x342 cell)
    new idle feet  y=293, centre x=240 (in the 480x480 cell)
    => window origin (240-216, 293-244) = (24, 49)

She is the same height in both exports (162px vs 164px standing), so there is
no resampling: every output pixel is copied from the source.

Clip mapping
------------
The export renamed four clips. Death has no bare equivalent in the new set, so
death_* reuses the KatanaDeath sheets rather than shipping a duplicate copy.

Power-state material
--------------------
The cloned ShaderMaterial carries Katana Kitsune's pure-red clothing key. The
new model's hair and skirt are the same dark red, and the user wants both to
take the elemental theme, so SHADER_PARAMS widens the key (see
shaders/powerState.gdshader) and switches off the legacy hair/skin passes
whose grey key would dim her white top. `--material-only` rewrites just that
block in the existing Kitsune.tscn without minting new UIDs or touching sheets.
"""
import hashlib
import random
import re
import sys
from pathlib import Path

from PIL import Image

Image.MAX_IMAGE_PIXELS = None

GAME = Path(__file__).resolve().parent.parent
EXPORT = Path("/home/emanzi/3D/Blender 4.5/Meshy-Blender-Toolkit/pixelover/sprites/KatanaKitsune_NewModel")

OLD_SCENE = GAME / "scenes/characters/KatanaKitsune.tscn"
NEW_SCENE = GAME / "scenes/characters/Kitsune.tscn"
OLD_SPRITES = "res://assets/sprites/characters/KatanaKitsune/sprites/"
NEW_SPRITES = "res://assets/sprites/characters/Kitsune/sprites/"
OLD_NODE = "KatanaKitsune"
NEW_NODE = "Kitsune"

FRAMES = 16
SRC_CELL = 480
CELL_W, CELL_H = 432, 342
CROP_X, CROP_Y = 24, 49

## ShaderMaterial_powerState overrides, in the shader's raw 0..1 units.
## Measured on Idle dir1 frame 0: hair r 40-106 sat .55-.90 g/r,b/r .11-.47;
## skirt r 44-105 sat .63-.98 g/r,b/r .02-.38; skin g/r .85 b/r .80; top ~1.0.
SHADER_PARAMS = {
    "clothing_min_red": "0.117647",      # red > 30
    "clothing_min_sat": "0.5",
    "clothing_max_green_ratio": "0.5",
    "clothing_max_blue_ratio": "0.5",
    "clothing_amount_offset": "40.0",
    "clothing_amount_range": "70.0",
    "hair_skin_passes": "false",
}

## old clip folder -> (export subfolder, export clip folder)
CLIPS = {
    "Death":               ("Katana",   "KatanaDeath"),
    "FastRun":             ("NoKatana", "FastRun"),
    "Flair":               ("NoKatana", "Flair"),
    "ForwardRoll":         ("NoKatana", "ForwardRoll"),
    "HighKick":            ("NoKatana", "HighKick"),
    "IdleStanding":        ("NoKatana", "Idle"),
    "KatanaBlock":         ("Katana",   "KatanaBlock"),
    "KatanaBlockCrouched": ("Katana",   "KatanaBlockCrouched"),
    "KatanaChargeAttack":  ("Katana",   "KatanaChargeAttack"),
    "KatanaCounterSlash":  ("Katana",   "KatanaCounterSlash"),
    "KatanaDeath":         ("Katana",   "KatanaDeath"),
    "KatanaDraw":          ("Katana",   "KatanaDraw"),
    "KatanaIdle":          ("Katana",   "KatanaIdle"),
    "KatanaJump":          ("Katana",   "KatanaJump"),
    "KatanaKick":          ("Katana",   "KatanaKick"),
    "KatanaRun":           ("Katana",   "KatanaRun"),
    "KatanaSeath":         ("Katana",   "KatanaSeath"),
    "KatanaSlashCrouched": ("Katana",   "KatanaSlashCrouched"),
    "KatanaSlashMid":      ("Katana",   "KatanaSlashMid"),
    "KatanaWalk":          ("Katana",   "KatanaWalk"),
    "MidKick":             ("NoKatana", "MidKick"),
    "NinjaRun":            ("NoKatana", "NinjaRun"),
    "RoundKick":           ("NoKatana", "RoundKick"),
    "RuningJump":          ("NoKatana", "RuningJump"),
    "SeductiveDance":      ("NoKatana", "SeductiveDance"),
    "Sitting":             ("NoKatana", "Sitting"),
    "SittingFloor":        ("NoKatana", "SittingFloor"),
    "SlowRun":             ("NoKatana", "SlowRun"),
    "SneakWalk":           ("NoKatana", "SneakWalk"),
    "StealthIdle":         ("NoKatana", "StealthIdle"),
    "StealthToCrouch":     ("NoKatana", "StealthToCrouch"),
    "SwitchDirectionIdle": ("NoKatana", "CatwalkTwistLToTwistR"),
    "Walking":             ("NoKatana", "CatwalkWalking"),
}

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

UID_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"


def existing_uids() -> set:
    found = set()
    for pattern in ("**/*.tscn", "**/*.tres", "**/*.import", "**/*.uid"):
        for f in GAME.glob(pattern):
            if ".godot" in f.parts or "addons" in f.parts:
                continue
            found.update(re.findall(r"uid://[a-z0-9]+", f.read_text(errors="ignore")))
    return found


class Uids:
    def __init__(self):
        self.taken = existing_uids()

    def new(self) -> str:
        while True:
            n = random.getrandbits(63)
            s = ""
            while n:
                n, r = divmod(n, 36)
                s = UID_CHARS[r] + s
            uid = "uid://" + s
            if uid not in self.taken:
                self.taken.add(uid)
                return uid


def crop_sheet(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    if img.size != (FRAMES * SRC_CELL, SRC_CELL):
        raise SystemExit(f"{src}: unexpected sheet size {img.size}")
    out = Image.new("RGBA", (FRAMES * CELL_W, CELL_H), (0, 0, 0, 0))
    for f in range(FRAMES):
        box = (f * SRC_CELL + CROP_X, CROP_Y, f * SRC_CELL + CROP_X + CELL_W, CROP_Y + CELL_H)
        out.paste(img.crop(box), (f * CELL_W, 0))
    return out


def patch_material(scene: str) -> str:
    """Replace/insert SHADER_PARAMS inside the ShaderMaterial_powerState block."""
    m = re.search(r'\[sub_resource type="ShaderMaterial" id="ShaderMaterial_powerState"\]\n(?:.+\n)+?(?=\n)', scene)
    if m is None:
        raise SystemExit("ShaderMaterial_powerState block not found")
    block = m.group(0)
    for key, value in SHADER_PARAMS.items():
        line = f"shader_parameter/{key} = {value}\n"
        block, n = re.subn(rf"^shader_parameter/{key} = .*\n", line, block, flags=re.M)
        if n == 0:
            block += line
    return scene[:m.start()] + block + scene[m.end():]


def main() -> None:
    apply = "--apply" in sys.argv
    if "--material-only" in sys.argv:
        patched = patch_material(NEW_SCENE.read_text())
        if apply:
            NEW_SCENE.write_text(patched)
        print("material patched" if apply else "DRY RUN - re-run with --apply")
        return
    uids = Uids()
    scene = OLD_SCENE.read_text()

    ext_re = re.compile(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="([^"]+)" id="([^"]+)"\]\n')
    refs = [(m.group(0), m.group(2), m.group(3)) for m in ext_re.finditer(scene) if m.group(2).startswith(OLD_SPRITES)]
    if len(refs) != len(CLIPS) * 8:
        raise SystemExit(f"expected {len(CLIPS) * 8} sprite ext_resources, found {len(refs)}")

    ## Export sheet for each old reference, plus the game path it becomes.
    new_path_uid: dict = {}
    id_by_new_path: dict = {}
    alias: dict = {}
    written = 0
    for line, old_path, ext_id in refs:
        m = re.search(r"/sprites/([^/]+)/[^/]+_dir(\d)\.png$", old_path)
        clip, d = m.group(1), m.group(2)
        sub, new_clip = CLIPS[clip]
        src = EXPORT / sub / new_clip / f"Kitsune_{new_clip}_dir{d}.png"
        if not src.exists():
            raise SystemExit(f"missing export {src}")
        new_res = f"{NEW_SPRITES}{new_clip}/Kitsune_{new_clip}_dir{d}.png"
        if new_res in id_by_new_path:
            ## Two old clips share one new sheet (Death -> KatanaDeath): keep one
            ## ext_resource and redirect the other's atlases to it.
            alias[ext_id] = id_by_new_path[new_res]
            scene = scene.replace(line, "")
            continue
        id_by_new_path[new_res] = ext_id
        uid = uids.new()
        new_path_uid[new_res] = uid
        scene = scene.replace(line, f'[ext_resource type="Texture2D" uid="{uid}" path="{new_res}" id="{ext_id}"]\n')

        dst = GAME / new_res.replace("res://", "")
        if apply:
            dst.parent.mkdir(parents=True, exist_ok=True)
            crop_sheet(src).save(dst, "PNG")
            md5 = hashlib.md5(new_res.encode()).hexdigest()
            (dst.parent / (dst.name + ".import")).write_text(
                IMPORT_TEMPLATE.format(uid=uid, name=dst.name, md5=md5, res=new_res))
        written += 1

    for old_id, new_id in alias.items():
        scene = scene.replace(f'atlas = ExtResource("{old_id}")', f'atlas = ExtResource("{new_id}")')

    scene_uid = uids.new()
    scene = re.sub(r'^\[gd_scene ([^\]]*?)uid="uid://[a-z0-9]+"', rf'[gd_scene \1uid="{scene_uid}"', scene, count=1)
    scene = scene.replace(f'[node name="{OLD_NODE}" type="CharacterBody2D"', f'[node name="{NEW_NODE}" type="CharacterBody2D"', 1)
    ns, ne = scene.count("[sub_resource "), scene.count("[ext_resource ")
    scene = re.sub(r"load_steps=\d+", f"load_steps={ns + ne + 1}", scene, count=1)
    scene = patch_material(scene)

    if apply:
        NEW_SCENE.write_text(scene)
    print(f"sheets={written} aliased={len(alias)} scene_uid={scene_uid}")
    print("APPLIED" if apply else "DRY RUN - re-run with --apply")


if __name__ == "__main__":
    main()
