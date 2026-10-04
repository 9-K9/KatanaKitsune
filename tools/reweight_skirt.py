"""Move a robe's skirt off the thigh bones so it swings instead of splitting.

Run under Blender:
    blender --background --python tools/reweight_skirt.py -- <in.glb> <out.glb> [blend_height]

Meshy's auto-rig assigns a long kimono to the upper-leg bones, because that is
where the geometry sits. It is the right answer for trousers and the wrong one
for a skirt: each half follows its own thigh, so the robe scissors open when the
character walks rather than swinging as one piece.

The fix moves skirt weight from the thighs onto the hips, fading in with height
so the hem — which should still follow the legs a little — is left alone and the
waist, which should not move independently at all, is moved entirely. Legs then
pass through the robe instead of tearing it apart. At 224px that is the right
trade: a skirt that holds together reads correctly, and interpenetration of a
few pixels does not.

Only the upper-leg bones are touched. Knees, feet, arms and spine are left as
the rigger set them.
"""
import sys

import bpy

THIGHS = ("mixamorig:LeftUpLeg", "mixamorig:RightUpLeg")
## The knee, which is the head of the lower leg bone. The thigh bone's own head
## is at the hip, and reading that instead collapses the fade into a band a few
## centimetres tall at the waistband — moving the robe's waist, which was never
## the problem, and leaving the skirt that actually splits still on the thighs.
SHINS = ("mixamorig:LeftLeg", "mixamorig:RightLeg")
HIPS = "mixamorig:Hips"


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, dst = argv[0], argv[1]
    ## Above this fraction of the thigh's span the robe is treated as waist
    ## rather than leg. 0.55 keeps the lower half following the knee.
    blend = float(argv[2]) if len(argv) > 2 else 0.55

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)

    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh = max((o for o in bpy.data.objects if o.type == "MESH"),
               key=lambda o: len(o.data.vertices))

    bones = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}
    hip_z = bones[HIPS].z
    knee_z = min(bones[b].z for b in SHINS if b in bones)
    ## Where the fade starts: part way down from the hips toward the knees. Below
    ## this the hem still follows the legs, which is what stops the robe reading
    ## as a rigid bell.
    floor_z = knee_z + (hip_z - knee_z) * blend

    groups = {g.name: g for g in mesh.vertex_groups}
    if HIPS not in groups:
        groups[HIPS] = mesh.vertex_groups.new(name=HIPS)
    index_of = {g.index: g.name for g in mesh.vertex_groups}

    moved = 0
    total_shift = 0.0
    for v in mesh.data.vertices:
        z = (mesh.matrix_world @ v.co).z
        if z < floor_z:
            continue
        ## Fully hips at the waist, tapering back to the thigh at floor_z, so
        ## there is no seam where the two regions meet.
        t = min(1.0, (z - floor_z) / max(hip_z - floor_z, 1e-6))
        take = 0.0
        for g in list(v.groups):
            if index_of.get(g.group) in THIGHS and g.weight > 0.0:
                shift = g.weight * t
                groups[index_of[g.group]].add([v.index], g.weight - shift, "REPLACE")
                take += shift
        if take > 0.0:
            existing = next((g.weight for g in v.groups
                             if index_of.get(g.group) == HIPS), 0.0)
            groups[HIPS].add([v.index], existing + take, "REPLACE")
            moved += 1
            total_shift += take

    print("REWEIGHT hips_z=%.3f knee_z=%.3f fade_from=%.3f" % (hip_z, knee_z, floor_z))
    print("REWEIGHT moved %d vertices, %.1f total weight onto %s" % (moved, total_shift, HIPS))

    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                              export_animations=True, export_nla_strips=True)
    print("REWEIGHT wrote %s" % dst)


main()
