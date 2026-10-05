"""Produce a bare mesh FBX that Mixamo's auto-rigger will accept.

Run under Blender:
    blender --background --python tools/strip_rig.py -- <in.glb|fbx> <out.fbx>

Mixamo reports "unable to map your existing skeleton" for several different
problems, not only the one it names. A Meshy export trips at least three of
them: it already carries a skeleton, so the rigger tries to map rather than
create; it arrives as more than one object; and its scale and orientation are
whatever the generator chose.

So this removes the armature entirely, joins everything into a single mesh,
clears parenting and vertex groups, applies all transforms, and writes the
result facing -Y at roughly human height — which is the shape the auto-rigger
expects to be handed.

It prints what it found and what it changed, because when the upload fails again
the useful question is which of those was actually wrong.
"""
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, dst = argv[0], argv[1]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    if src.lower().endswith(".glb") or src.lower().endswith(".gltf"):
        bpy.ops.import_scene.gltf(filepath=src)
    else:
        bpy.ops.wm.fbx_import(filepath=src)

    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    print("FOUND %d armature(s), %d mesh object(s)" % (len(arms), len(meshes)))
    if not meshes:
        print("STRIP FAIL: no mesh")
        return

    ## Unparent first, keeping the posed-at-rest shape, or removing the armature
    ## would drag the mesh back to the origin.
    for m in meshes:
        m.select_set(True)
        matrix = m.matrix_world.copy()
        m.parent = None
        m.matrix_world = matrix
        for mod in list(m.modifiers):
            if mod.type == "ARMATURE":
                m.modifiers.remove(mod)
        ## Vertex groups are what Mixamo reads as "an existing skeleton" even
        ## after the armature itself is gone.
        m.vertex_groups.clear()

    for a in arms:
        bpy.data.objects.remove(a, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
        print("JOINED %d meshes into one" % len(meshes))
    obj = bpy.context.view_layer.objects.active

    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    ## Stand it up. A Meshy FBX arrives Y-up, so the character's height runs
    ## along Y and in Blender it is lying on its back. Mixamo wants it upright,
    ## and says "unable to map your existing skeleton" when it is not — which
    ## names the wrong problem entirely.
    d = obj.dimensions
    tallest = max(range(3), key=lambda i: d[i])
    if tallest != 2:
        import math
        obj.rotation_euler = (math.radians(90), 0, 0) if tallest == 1 \
            else (0, math.radians(90), 0)
        bpy.ops.object.transform_apply(rotation=True)
        print("STOOD UP from %s-up, now %.3f tall" % ("XYZ"[tallest], obj.dimensions.z))

    h = obj.dimensions.z
    ## Mixamo wants roughly human scale. These arrive around 12cm, and a model
    ## that small is rejected silently.
    if h > 0 and not (0.5 < h < 5.0):
        s = 1.75 / h
        obj.scale = (s, s, s)
        bpy.ops.object.transform_apply(scale=True)
        print("RESCALED from %.3f to %.2f units" % (h, obj.dimensions.z))

    ## Blender 5.0's FBX exporter takes filepath and axes and nothing else — no
    ## selection filter, no object types, no texture embedding. That is survivable
    ## only because the armature has already been deleted, so the whole scene is
    ## the one mesh we want. Textures travel as the PNGs beside the source; upload
    ## the FBX alone, which is all Mixamo needs to rig.
    bpy.ops.export_scene.fbx(filepath=dst)
    print("STRIP OK: %s  (%d verts, %.2f units tall)"
          % (os.path.basename(dst), len(obj.data.vertices), obj.dimensions.z))


main()
