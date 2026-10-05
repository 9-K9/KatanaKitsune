"""Export a .blend to every format Mixamo or the game pipeline might want.

Run under Blender:
    blender --background --python tools/export_formats.py -- <in.blend> <out_dir> <name>

Writes, under <out_dir>:
    <name>.glb              textures packed into the binary
    gltf/<name>.gltf        textures as base64 inside the json
    obj/<name>.obj + .mtl   textures as files beside it, which is what OBJ allows

FBX is not written. Blender 5.0's exporter is broken for scripted use — it dies
inside its own execute on a missing `use_space_transform` attribute whatever
arguments it is given, the same way its importer dies on a missing `files`.
There is no workaround from the command line; the GUI exporter still works.

OBJ cannot embed textures — the format has no mechanism for it. It references
them from a .mtl beside the file, so the three files have to travel together,
which is why Mixamo wants a zip.
"""
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_dir, name = argv[0], argv[1], argv[2]
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.open_mainfile(filepath=src)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        print("SKIP %s: no mesh" % name)
        return
    verts = sum(len(m.data.vertices) for m in meshes)
    dims = meshes[0].dimensions
    print("OPEN %-22s %d mesh, %d verts, %.2f x %.2f x %.2f"
          % (name, len(meshes), verts, dims.x, dims.y, dims.z))

    ## Textures have to be unpacked to disk for OBJ, and packed for glb. Doing
    ## the pack first means every later exporter sees them regardless of how the
    ## .blend referenced them.
    try:
        bpy.ops.file.pack_all()
    except Exception as exc:
        print("  pack warning: %s" % exc)

    wrote = []

    glb = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB",
                              export_animations=True)
    wrote.append("%s.glb %.1fMB" % (name, os.path.getsize(glb) / 1e6))

    ## GLTF_EMBEDDED was removed in Blender 5.0 — the only formats left are GLB
    ## and GLTF_SEPARATE. So .glb IS the embedded-texture option, and .gltf can
    ## only be written with its textures as files beside it. Each character gets
    ## its own folder, or they all write texture_0.png over each other.
    gdir = os.path.join(out_dir, "gltf", name)
    os.makedirs(gdir, exist_ok=True)
    gltf = os.path.join(gdir, name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=gltf, export_format="GLTF_SEPARATE",
                              export_animations=True)
    wrote.append("gltf/%s/ (%d files)" % (name, len(os.listdir(gdir))))

    odir = os.path.join(out_dir, "obj", name)
    os.makedirs(odir, exist_ok=True)
    obj = os.path.join(odir, name + ".obj")
    ## wm.obj_export is the current operator; export_scene.obj was removed.
    if hasattr(bpy.ops.wm, "obj_export"):
        bpy.ops.wm.obj_export(filepath=obj, export_materials=True,
                              path_mode="COPY")
    else:
        bpy.ops.export_scene.obj(filepath=obj, use_materials=True,
                                 path_mode="COPY")
    ## The OBJ exporter's COPY mode does not unpack images that are packed into
    ## the .blend, so the .mtl ends up naming a texture that is not beside it and
    ## the model uploads untextured. Write them out by hand, under the exact name
    ## the .mtl refers to, which is the image datablock's own name.
    for img in bpy.data.images:
        if not img.has_data or img.name in ("Render Result", "Viewer Node"):
            continue
        target = os.path.join(odir, img.name)
        if not target.lower().endswith((".png", ".jpg", ".jpeg")):
            target += ".png"
        try:
            img.save(filepath=target)
        except Exception as exc:
            print("  image warning %s: %s" % (img.name, exc))

    made = sorted(os.listdir(odir))
    wrote.append("obj/%s/{%s}" % (name, ",".join(made)))

    print("DONE %-22s %s" % (name, " | ".join(wrote)))


main()
