#!/usr/bin/env python3
"""Import the approved WorldObjects exports and generate directional Godot scenes.

Run --archive before --generate. --cleanup removes only verified, unreferenced
legacy files. Source exports and authoring files are never modified.
"""

import argparse
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import re
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("/mnt/K-DRIVE/Dropbox/9-K9 Dropbox/9-K9 Team Folder/Meshy/KatanaKitsune/WorldObjects")
ARCHIVE = SOURCE.parent / "WorldObjectsArchive" / "placeholder-migration-2026-10-17"
ART = "assets/sprites/world_objects"
SCENES = "scenes/props/world_objects"
NATURAL = set("""azalea_bush bamboo_clump black_pine cactus_a cactus_b dead_tree_a
dead_tree_b desert_skull dry_shrub frozen_shrub garden_rocks grass_tuft palm_a
pond_reeds sakura_tree_c sakura_weeping sandstone_rocks snowy_pine snowy_rocks""".split())
EXTERIOR = NATURAL | {"dragon_statue", "jizo_statue", "komainu_statue", "komainu_statue_b", "torii_gate"}
PICKUPS = {"health_charm", "health_potion", "onigiri", "power_orb", "sake_flask", "scroll"}
TREES = {name for name in NATURAL if "tree" in name or "pine" in name} | {"palm_a", "bamboo_clump"}
FACINGS = {1: "southEast", 2: "south", 3: "southWest", 4: "west",
           5: "northWest", 6: "north", 7: "northEast", 8: "east"}
OLD_SIMPLE = {
    "breakableUrn": "breakable_urn", "breakableChest": "breakable_chest",
    "breakableStatue": "breakable_statue", "chair": "chair", "pillar": "pillar",
    "exitStairs": "exit_stairs", "spikeTrap": "spike_trap_extended", "brazier": "brazier",
    "pickupDrink": "sake_flask", "pickupFood": "onigiri",
    "pickupHealth": "health_potion", "pickupPower": "power_orb", "pickupScroll": "scroll",
    "bambooTorch": "bamboo_torch_lit", "ironBrazier": "iron_brazier_lit",
    "paperLantern": "paper_lantern_lit", "spiritCenser": "spirit_censer_lit",
    "stakeTorch": "stake_torch_lit", "stoneLantern": "stone_lantern_lit",
}
ALIASES = {"samurai_armour_stand": "armour_stand", "stone_lantern": "stone_lantern_japanese",
           "sakura_tree_a": "sakura_tree_c"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory():
    result = {}
    for folder in sorted(SOURCE.iterdir()):
        if not folder.is_dir():
            continue
        files = []
        for direction in range(1, 9):
            matches = list((folder / "sprites").glob(f"*_dir{direction}.png"))
            if len(matches) != 1:
                raise ValueError(f"Missing or ambiguous dir{direction}: {folder}")
            files.append(matches[0])
        result[folder.name] = files
    if len(result) != 92:
        raise ValueError(f"Expected 92 sets, found {len(result)}; review source changes")
    return result


def old_mapping():
    mapping = {}
    base = ARCHIVE if (ARCHIVE / "manifest.json").exists() else ROOT
    for path in sorted((base / "scenes/props").rglob("*.tscn")):
        if "world_objects" in path.parts or path.stem == "projectile":
            continue
        stem = path.stem
        direction = 1
        for number, facing in FACINGS.items():
            if stem.endswith("_" + facing):
                stem = stem[:-(len(facing) + 1)]
                direction = number
                break
        family = OLD_SIMPLE.get(stem, ALIASES.get(stem, stem))
        mapping[str(path.relative_to(base))] = (family, direction)
    return mapping


def archive():
    candidates = set()
    for old in old_mapping():
        path = ROOT / old
        candidates.add(path)
        for art in re.findall(r'path="res://([^"]+\.png)"', path.read_text()):
            if "/ui/" not in art:
                candidates.add(ROOT / art)
    for folder in ["assets/sprites/props/pillars", "assets/sprites/props/chair"]:
        candidates.update((ROOT / folder).glob("*.png"))
    for path in list(candidates):
        sidecar = Path(str(path) + ".import")
        if sidecar.exists():
            candidates.add(sidecar)
    for folder in ["scripts/system", "resources/biomes", "resources/level_themes"]:
        candidates.update((ROOT / folder).glob("*"))
    candidates.add(ROOT / "scenes/world/mazeDemo.tscn")
    manifest = {}
    for path in sorted(candidates):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        target = ARCHIVE / relative
        checksum = digest(path)
        if target.exists() and digest(target) != checksum:
            raise ValueError(f"Refusing to overwrite archive: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(path, target)
        if digest(target) != checksum:
            raise ValueError(f"Archive verification failed: {target}")
        manifest[str(relative)] = checksum
    manifest_path = ARCHIVE / "manifest.json"
    if manifest_path.exists() and json.loads(manifest_path.read_text()) != manifest:
        raise ValueError("Existing archive manifest differs; do not overwrite it")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Verified {len(manifest)} original files in {ARCHIVE}")


def archive_unused_art():
    manifest_path = ARCHIVE / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for folder in ["assets/sprites/props",
                   "assets/pixellab/japanese_environment/props",
                   "assets/pixellab/japanese_environment/exterior_props"]:
        for image in sorted((ROOT / folder).rglob("*.png")):
            for path in [image, Path(str(image) + ".import")]:
                if not path.is_file():
                    continue
                relative = str(path.relative_to(ROOT))
                checksum = digest(path)
                target = ARCHIVE / relative
                if target.exists() and digest(target) != checksum:
                    raise ValueError(f"Refusing to overwrite archive: {target}")
                target.parent.mkdir(parents=True, exist_ok=True)
                if not target.exists():
                    shutil.copy2(path, target)
                if digest(target) != checksum:
                    raise ValueError(f"Archive verification failed: {target}")
                manifest[relative] = checksum
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Verified extended archive: {len(manifest)} files")


def template_for(family, mapping):
    for path, (name, direction) in mapping.items():
        if family == name and direction == 1:
            return ARCHIVE / path if (ARCHIVE / path).exists() else ROOT / path
    if family == "komainu_statue_b":
        return ARCHIVE / "scenes/props/japanese/exterior/komainu_statue.tscn"
    if family == "health_charm":
        return ARCHIVE / "scenes/props/pickupHealth.tscn"
    if family.endswith("_unlit"):
        return template_for(family.replace("_unlit", "_lit"), mapping)
    raise ValueError(f"No gameplay classification for {family}")


def replace_paths(text, mapping):
    for old, (family, direction) in sorted(mapping.items(), key=lambda item: -len(item[0])):
        new = f"{SCENES}/{family}/{family}_dir{direction}.tscn"
        text = re.sub(r'(?:uid="[^"]+"\s+)?path="res://' + re.escape(old) + '"',
                      f'path="res://{new}"', text)
        text = text.replace(f"res://{old}", f"res://{new}")
    return text


def vector(x, y):
    return f"Vector2({x:.6f}, {y:.6f})"


def polygon(rx, ry):
    points = []
    for i in range(12):
        angle = math.tau * i / 12
        points.extend([round(rx * math.cos(angle), 3), round(ry * math.sin(angle), 3)])
    return "PackedVector2Array(" + ", ".join(map(str, points)) + ")"


def tree_base(path):
    with Image.open(path) as image:
        alpha = image.convert("RGBA").getchannel("A")
        bounds = alpha.getbbox()
        top = bounds[3] - max(1, round((bounds[3] - bounds[1]) * 0.12))
        base = alpha.crop((0, top, image.width, bounds[3])).point(
            lambda value: 255 if value >= 128 else 0).getbbox()
    if base is None:
        raise ValueError(f"Missing tree base: {path}")
    return base[0], base[2]


def sprite_position(path, scale=1.0, tree=False):
    with Image.open(path) as image:
        bounds = image.getbbox()
        width, height = image.size
    if bounds is None:
        raise ValueError(f"Empty sprite: {path}")
    left, right = tree_base(path) if tree else (bounds[0], bounds[2])
    return vector((width / 2 - (left + right) / 2) * scale,
                  -(bounds[3] - height / 2) * scale)


def player_height():
    # The normal character's default south-west idle uses exported dir1.
    sheet = ROOT / "assets/sprites/characters/Kitsune/sprites/Idle/Kitsune_Idle_dir1.png"
    with Image.open(sheet) as image:
        bounds = image.crop((0, 0, 432, 342)).getbbox()
    return bounds[3] - bounds[1]


def gate_posts(path):
    """Locate visible post feet, excluding the hanging rope and ornaments."""
    with Image.open(path) as image:
        alpha = image.convert("RGBA").getchannel("A")
    width, height = alpha.size
    pixels = alpha.load()
    top = int(height * 0.55)
    seen = set()
    posts = []
    for y in range(top, height):
        for x in range(width):
            if pixels[x, y] < 128 or (x, y) in seen:
                continue
            queue = deque([(x, y)])
            seen.add((x, y))
            component = []
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for nx, ny in [(px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)]:
                    if (0 <= nx < width and top <= ny < height
                            and (nx, ny) not in seen and pixels[nx, ny] >= 128):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) < 200:
                continue
            bottom = max(point[1] for point in component)
            base = [point[0] for point in component if point[1] >= bottom - 5]
            posts.append((sum(base) / len(base), bottom + 1))
    if len(posts) not in {1, 2}:
        raise ValueError(f"Expected one or two visible gate posts: {path}: {posts}")
    bounds = alpha.getbbox()
    centre = (bounds[0] + bounds[2]) / 2
    posts = [(x - centre, y - bounds[3]) for x, y in posts]
    if len(posts) == 1:
        # In edge-on views the front post completely hides the rear post.
        front_view = path.with_name(path.name.replace("_dir2", "_dir4").replace("_dir6", "_dir4"))
        front_posts = gate_posts(front_view)
        depth = abs(front_posts[1][0] - front_posts[0][0]) * 0.5
        posts.append((posts[0][0], posts[0][1] - depth))
    return sorted(posts)


def build_scene(family, direction, sets, mapping):
    template = template_for(family, mapping).read_text()
    resources = re.findall(r'^\[ext_resource[^\n]+', template, re.M)
    resources = [line for line in resources if 'type="Texture2D"' not in line]
    resources = [re.sub(r' uid="[^"]+"', "", line) for line in resources]
    resources = [replace_paths(line, mapping) for line in resources]
    root = re.search(r'\[node[^\n]+\]\n(.*?)(?=\n\[node|\Z)', template, re.S).group(1)
    root = re.sub(r'^(?:break_texture|break_frames|lit_frames|persist_broken|fade_rect|'
                  r'collision_layer|collision_mask|sort_bias|seat_offset|facing|y_sort_enabled)\s*=.*\n?', "", root, flags=re.M)
    root = replace_paths(root, mapping).strip()
    script_id = re.search(r'script = ExtResource\("([^"]+)"\)', root).group(1)
    pickup = family in PICKUPS
    exterior = family in EXTERIOR
    chair = family == "chair"
    trap = family == "spike_trap_extended"
    exit_stairs = family == "exit_stairs"
    texture = sets[family][direction - 1]
    scale = 0.5 if pickup else 1.0
    with Image.open(texture) as image:
        bounds = image.getbbox()
        width, height = image.size
    visible_width = bounds[2] - bounds[0]
    if family in TREES:
        scale = 2 * player_height() / (bounds[3] - bounds[1])
    elif chair:
        scale = 0.6
    rx = max(6, min(visible_width * 0.38, 54))
    ry = max(4, min(rx * 0.42, 22))
    if family in TREES:
        left, right = tree_base(texture)
        rx = max(12, min(40, (right - left) * scale * 0.4))
        ry = rx * 0.5
    if family in {"grass_tuft", "pond_reeds", "dry_shrub", "frozen_shrub"}:
        rx, ry = min(rx, 20), min(ry, 10)
    if family == "pillar":
        rx, ry = 22, 11
    if pickup:
        rx, ry = 15, 10
    if chair:
        root += f'\nfacing = "{FACINGS[direction]}"\nseat_offset = Vector2(0, -18)\nsort_bias = -24.0'
    root += f'\ny_sort_enabled = {str(chair).lower()}'
    if family == "low_table":
        root = re.sub(r'loot_display_lift = [^\n]+', 'loot_display_lift = 35.0', root)
    natural = family in NATURAL
    if exterior:
        base_left, base_right = tree_base(texture) if family in TREES else (bounds[0], bounds[2])
        canopy_left = (bounds[0] - (base_left + base_right) / 2) * scale
        visible_height = (bounds[3] - bounds[1]) * scale
        root += f"\nfade_rect = Rect2({canopy_left:.2f}, {-visible_height:.2f}, {visible_width*scale:.2f}, {max(1,visible_height-10):.2f})"
    broken = family + "_broken"
    if family.endswith(("_lit", "_unlit")):
        broken = family.rsplit("_", 1)[0] + "_broken"
    if family == "stone_lantern_japanese":
        broken = "stone_lantern_jp_broken"
    resources.append(f'[ext_resource type="Texture2D" path="res://{ART}/{family}/{family}_dir{direction}.png" id="new_art"]')
    if broken in sets:
        broken_file = sets[broken][direction-1]
        resources.append(f'[ext_resource type="Texture2D" path="res://{ART}/{broken}/{broken}_dir{direction}.png" id="new_broken"]')
        root += '\nbreak_texture = ExtResource("new_broken")\nbreak_frames = 1\npersist_broken = true'
        root += "\nbreak_sprite_position = " + sprite_position(broken_file)
    if trap:
        hidden = "spike_trap_retracted"
        resources.append(f'[ext_resource type="Texture2D" path="res://{ART}/{hidden}/{hidden}_dir{direction}.png" id="new_hidden"]')
        root += '\nretracted_texture = ExtResource("new_hidden")\nextended_texture = ExtResource("new_art")'
        root += "\nretracted_position = " + sprite_position(sets[hidden][direction-1])
    if pickup:
        root += "\nuse_world_art = true"
        if family == "health_charm":
            root = re.sub(r'^amount =.*\n?', '', root, flags=re.M)
            root += "\namount = 35.0"
        if family == "onigiri":
            root += "\nkind = 4"
    elif not chair and not exit_stairs and not trap:
        root += "\ncollision_layer = " + ("0" if 'blocks_movement = false' in root else "3")
        root += "\ncollision_mask = 0"
    root += f'\nmetadata/world_family = "{family}"\nmetadata/world_direction = {direction}\nmetadata/natural_variant = {str(natural).lower()}'
    groups = ' groups=["chair"]' if chair else ' groups=["exterior_prop"]' if exterior else ""
    node_type = "Area2D" if pickup or exit_stairs or trap else "Node2D" if chair else "StaticBody2D"
    root = re.sub(r"\n{2,}", "\n", root)
    text = "[gd_scene format=3]\n\n" + "\n".join(resources) + "\n"
    if chair or pickup:
        radius = 56 if chair else 18
        text += f'\n[sub_resource type="CircleShape2D" id="zone"]\nradius = {radius}.0\n'
    elif 'blocks_movement = false' in root:
        text += f'\n[sub_resource type="ConvexPolygonShape2D" id="hurt"]\npoints = {polygon(rx,ry)}\n'
    else:
        shadow = polygon(13, 7) if family == "torii_gate" else polygon(rx, ry)
        text += f'\n[sub_resource type="OccluderPolygon2D" id="shadow"]\npolygon = {shadow}\n'
    text += f'\n[node name="{family}" type="{node_type}"{groups}]\n{root}\n'
    text += f'\n[node name="Sprite2D" type="Sprite2D" parent="."]\ntexture_filter = 1\n'
    if chair:
        text += 'position = Vector2(0, -24)\n'
        text += f'offset = {vector(width / 2 - (bounds[0] + bounds[2]) / 2, -(bounds[3] - height / 2) + 24 / scale)}\n'
    else:
        text += f'position = {sprite_position(texture,scale,family in TREES)}\n'
    text += f'scale = {vector(scale,scale)}\ntexture = ExtResource("new_art")\n'
    if chair:
        text += '\n[node name="SitZone" type="Area2D" parent="."]\ncollision_layer = 0\ncollision_mask = 1\n'
        text += '\n[node name="CollisionShape2D" type="CollisionShape2D" parent="SitZone"]\nshape = SubResource("zone")\n'
    elif pickup:
        text += '\n[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nshape = SubResource("zone")\n'
    elif 'blocks_movement = false' in root:
        text += '\n[node name="HurtBox" type="Area2D" parent="." groups=["breakable_hitbox"]]\ncollision_layer = 2\ncollision_mask = 0\nmonitoring = false\n'
        text += '\n[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtBox"]\nshape = SubResource("hurt")\n'
    elif family == "torii_gate":
        for post, (x, y) in enumerate(gate_posts(texture)):
            text += f'\n[node name="Post{post}" type="CollisionPolygon2D" parent="."]\n'
            text += f'position = {vector(x,y)}\npolygon = {polygon(13,7)}\n'
            text += f'\n[node name="Shadow{post}" type="LightOccluder2D" parent="."]\n'
            text += f'position = {vector(x,y)}\noccluder = SubResource("shadow")\n'
    else:
        text += f'\n[node name="CollisionShape2D" type="CollisionPolygon2D" parent="."]\npolygon = {polygon(rx,ry)}\n'
        if node_type == "StaticBody2D":
            text += '\n[node name="LightOccluder2D" type="LightOccluder2D" parent="."]\noccluder = SubResource("shadow")\n'
    lights = re.search(r'\[node name="PointLight2D".*?(?=\n\[node|\Z)', template, re.S)
    if lights:
        light = re.sub(r' unique_id=\d+', '', lights.group())
        light = re.sub(r'^texture =.*\n?', '', light, flags=re.M)
        light = re.sub(r'^position =.*\n?', '', light, flags=re.M)
        resources_glow = '[ext_resource type="Texture2D" path="res://assets/sprites/ui/glow.tres" id="world_glow"]\n'
        text = text.replace('\n[sub_resource', '\n'+resources_glow+'\n[sub_resource', 1)
        light += f'\ntexture = ExtResource("world_glow")\nposition = Vector2(0, {-height*scale*0.75:.2f})\n'
        if family.endswith("_unlit"):
            light += "enabled = false\n"
        text += "\n" + light
    return text


def generate():
    if not (ARCHIVE / "manifest.json").is_file():
        raise ValueError("Run --archive first")
    sets = inventory()
    mapping = old_mapping()
    state_names = {name for name in sets if name.endswith("_broken")} | {"spike_trap_retracted"}
    families = sorted(set(sets) - state_names)
    coverage = {}
    for name, files in sets.items():
        target = ROOT / ART / name
        target.mkdir(parents=True, exist_ok=True)
        for direction, source in enumerate(files, 1):
            destination = target / f"{name}_dir{direction}.png"
            if destination.exists() and digest(destination) != digest(source):
                raise ValueError(f"Different imported sprite already exists: {destination}")
            shutil.copy2(source, destination)
        coverage[name] = {"role": "state" if name in state_names else
                          "pickup" if name in PICKUPS else
                          "biome" if name in EXTERIOR else "prop", "directions": 8}
    for family in families:
        target = ROOT / SCENES / family
        target.mkdir(parents=True, exist_ok=True)
        for direction in range(1, 9):
            (target / f"{family}_dir{direction}.tscn").write_text(build_scene(family, direction, sets, mapping))
    output = ROOT / "resources/world_objects.json"
    output.write_text(json.dumps({"source_sets": coverage, "families": families,
                                 "natural": sorted(NATURAL), "trees": sorted(TREES),
                                 "player_height": player_height(), "facings": FACINGS,
                                 "legacy": {old: f"{SCENES}/{family}/{family}_dir{direction}.tscn"
                                            for old, (family, direction) in mapping.items()}}, indent=2) + "\n")
    print(f"Imported {len(sets)*8} PNGs; generated {len(families)*8} scenes in {SCENES}")


def cleanup():
    manifest = json.loads((ARCHIVE / "manifest.json").read_text())
    catalog = json.loads((ROOT / "resources/world_objects.json").read_text())
    legacy = set(catalog["legacy"])
    candidates = set(legacy)
    for name in manifest:
        if name.startswith("assets/") and name.endswith((".png", ".png.import")):
            candidates.add(name)
    text_files = [p for folder in ["scenes", "scripts", "resources", "tools"]
                  for p in (ROOT / folder).rglob("*")
                  if p.suffix in {".tscn", ".tres", ".gd", ".py", ".json", ".md"}
                  and str(p.relative_to(ROOT)) not in legacy
                  and p.name not in {"world_objects.json", "migrate_world_objects.py"}]
    live = "\n".join(p.read_text() for p in text_files)
    removed = 0
    for name in sorted(candidates):
        path = ROOT / name
        if not path.is_file():
            continue
        reference = name.removesuffix(".import")
        if reference in live:
            if name in legacy:
                raise ValueError(f"Still referenced legacy scene: {name}")
            continue
        if name not in manifest or digest(ARCHIVE / name) != manifest[name]:
            raise ValueError(f"Missing verified backup: {name}")
        if digest(path) != manifest[name]:
            raise ValueError(f"Legacy original changed since archive: {name}")
        path.unlink()
        removed += 1
    print(f"Removed {removed} verified unreferenced legacy files; archive: {ARCHIVE}")


def wire():
    mapping = old_mapping()
    for folder in ["scenes", "scripts", "tools", "resources"]:
        for path in (ROOT / folder).rglob("*"):
            if path.suffix not in {".gd", ".tscn", ".tres", ".py"}:
                continue
            if path.name == Path(__file__).name or str(path.relative_to(ROOT)) in mapping:
                continue
            if SCENES in str(path.relative_to(ROOT)):
                continue
            old = path.read_text()
            new = replace_paths(old, mapping).replace('"sakura_tree_a"', '"sakura_tree_c"')
            if new != old:
                path.write_text(new)
    print("Repointed explicit scene references and removed obsolete Sakura palette entries")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", action="store_true")
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--cleanup", action="store_true")
    parser.add_argument("--wire", action="store_true")
    parser.add_argument("--archive-unused", action="store_true")
    options = parser.parse_args()
    if options.archive:
        archive()
    if options.generate:
        generate()
    if options.archive_unused:
        archive_unused_art()
    if options.cleanup:
        cleanup()
    if options.wire:
        wire()
