#!/usr/bin/env python3
"""Render one transparent PixelLab seed frame for every animation in every GLB."""

import argparse
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
    return value.strip("._") or "unnamed"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.actions,
        bpy.data.armatures,
        bpy.data.cameras,
        bpy.data.curves,
        bpy.data.images,
        bpy.data.lights,
        bpy.data.materials,
        bpy.data.meshes,
    ):
        for block in list(collection):
            collection.remove(block)


def character_meshes():
    meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        has_armature = any(mod.type == "ARMATURE" for mod in obj.modifiers)
        parent_armature = obj.parent and obj.parent.type == "ARMATURE"
        if has_armature or parent_armature:
            meshes.append(obj)
    return meshes


def evaluated_bounds(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        matrix = evaluated.matrix_world
        points.extend(matrix @ Vector(corner) for corner in evaluated.bound_box)
    if not points:
        raise RuntimeError("No skinned character mesh bounds found")
    mins = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxs = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mins, maxs


def union_bounds(armature, meshes, actions):
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    animation_data = armature.animation_data_create()
    animation_data.use_nla = False
    for action in actions:
        animation_data.action = action
        if action.slots:
            try:
                animation_data.action_slot = action.slots[0]
            except Exception:
                pass
        start, _end = action.frame_range
        # These are start-frame seeds, so fit only the starts. Sampling whole
        # clips would include root motion and make the character render tiny.
        frames = [int(round(start))]
        for frame in frames:
            bpy.context.scene.frame_set(frame)
            mins, maxs = evaluated_bounds(meshes)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], mins[axis])
                maximum[axis] = max(maximum[axis], maxs[axis])
    return minimum, maximum


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_area_light(name, location, energy, size, target):
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    look_at(obj, target)


def setup_render(bounds, resolution):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 35
    scene.render.use_file_extension = True
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = True
    scene.world.color = (0.04, 0.04, 0.04)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 1.0
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    # Transparent seed frames should not inherit viewport ground shadows.
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "WORLD"

    mins, maxs = bounds
    center = (mins + maxs) * 0.5
    height = maxs.z - mins.z
    width = max(maxs.x - mins.x, maxs.y - mins.y)
    camera_data = bpy.data.cameras.new("PixelLabCamera")
    camera_data.type = "ORTHO"
    camera_data.lens = 50
    camera_data.ortho_scale = max(height * 1.20, width * 1.20, 0.1)
    camera = bpy.data.objects.new("PixelLabCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (center.x, center.y - max(height * 3.0, 5.0), center.z + height * 0.035)
    look_at(camera, (center.x, center.y, center.z + height * 0.035))
    scene.camera = camera



def render_model(path: Path, output_root: Path, resolution: int):
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError(f"No armature in {path.name}")
    armature = armatures[0]
    meshes = character_meshes()
    if not meshes:
        raise RuntimeError(f"No skinned meshes in {path.name}")

    for obj in bpy.context.scene.objects:
        if obj not in meshes and obj != armature:
            obj.hide_render = True

    actions = sorted(list(bpy.data.actions), key=lambda action: action.name.lower())
    framing_actions = [action for action in actions if "baselayer" not in action.name.lower()] or actions
    bounds = union_bounds(armature, meshes, framing_actions)
    setup_render(bounds, resolution)
    animation_data = armature.animation_data_create()
    animation_data.use_nla = False

    character_dir = output_root / slug(path.stem)
    character_dir.mkdir(parents=True, exist_ok=True)
    records = []
    for index, action in enumerate(actions, 1):
        animation_data.action = action
        if action.slots:
            try:
                animation_data.action_slot = action.slots[0]
            except Exception:
                pass
        start, end = action.frame_range
        frame = int(round(start))
        bpy.context.scene.frame_set(frame)
        output = character_dir / f"{index:02d}_{slug(action.name)}.png"
        bpy.context.scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        records.append({
            "character": path.stem,
            "source_glb": str(path),
            "animation": action.name,
            "frame": frame,
            "frame_range": [float(start), float(end)],
            "raw_render": str(output),
        })
        print(f"RENDERED {path.stem} :: {action.name} :: frame {frame} -> {output}", flush=True)
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--resolution", type=int, default=224)
    cli_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    args = parser.parse_args(cli_args)
    input_root = Path(args.input)
    output_root = Path(args.output)
    output_root.mkdir(parents=True, exist_ok=True)
    all_records = []
    failures = []
    for path in sorted(input_root.glob("*.glb")):
        try:
            all_records.extend(render_model(path, output_root, args.resolution))
        except Exception as exc:
            failures.append({"source_glb": str(path), "error": repr(exc)})
            print(f"FAILED {path.name}: {exc!r}", flush=True)
    manifest = {"resolution": args.resolution, "renders": all_records, "failures": failures}
    (output_root / "render_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"COMPLETE renders={len(all_records)} failures={len(failures)}", flush=True)


if __name__ == "__main__":
    main()
