"""Re-export a GLB as .gltf with its textures and buffers written out beside it.

Run under Blender:
    blender --background --python tools/glb_to_gltf.py -- <in.glb> <out_dir>

A .glb packs geometry, animation and every texture into one binary. Some
viewers — MadView3D among them — read the separate form more reliably, showing
a checkerboard instead of the material when handed the packed one. The model is
not at fault and neither is the texture; it is how they are bundled.

Writes <out_dir>/<name>.gltf plus a .bin and the image files. The game does not
use these — Godot reads the .glb fine — so this is purely for inspection.
"""
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_dir = argv[0], argv[1]
    name = os.path.splitext(os.path.basename(src))[0]
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, name + ".gltf"),
        export_format="GLTF_SEPARATE",
        export_animations=True,
        export_nla_strips=True,
    )
    written = sorted(f for f in os.listdir(out_dir) if f.startswith(name))
    print("CONVERTED %s -> %s" % (os.path.basename(src), ", ".join(written)))


main()
