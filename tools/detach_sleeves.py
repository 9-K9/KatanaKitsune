"""Cut the torso's hold on a sleeve so a raised arm does not drag a membrane.

Run under Blender:
    blender --background --python tools/detach_sleeves.py -- <in.glb> <out.glb> [grip]

Meshy's auto-rig gives a wide kimono sleeve weight from both the arm it hangs
from and the body it hangs beside. At rest that is invisible. Raise the arm and
the vertices still part-owned by the hips stay put while the rest travels, so
the sleeve stretches into a flat sheet between hand and waist.

The fix is not to reweight the sleeve onto the arm — it is already mostly there.
It is to remove what the torso still holds. Any vertex the arm chain owns beyond
`grip` loses its hips, spine and upper-leg influence entirely, and what is left
is renormalised so the total stays 1.0 and nothing changes shape at rest.

Worth knowing why this was missed first time round: a tally of each vertex's
*dominant* bone showed the sleeves sitting correctly on the forearms, because
60% forearm beats 40% hips. The 40% was doing the damage and never appeared.
Skinning blends, so a diagnosis that only reads the top influence will keep
saying everything is fine.
"""
import os
import sys

import bpy

ARMS = ("Shoulder", "Arm", "ForeArm", "Hand")
TORSO = ("Hips", "Spine", "UpLeg")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, dst = argv[0], argv[1]
    ## How much of a vertex the arm must own before the torso is evicted from
    ## it. Low enough to catch the sleeve's outer edge, high enough to leave
    ## the shoulder seam — where torso influence is correct — alone.
    grip = float(argv[2]) if len(argv) > 2 else 0.25

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    mesh = max((o for o in bpy.data.objects if o.type == "MESH"),
               key=lambda o: len(o.data.vertices))

    by_index = {g.index: g.name for g in mesh.vertex_groups}
    groups = {g.name: g for g in mesh.vertex_groups}

    def is_arm(n):
        return any(k in n for k in ARMS)

    def is_torso(n):
        return any(k in n for k in TORSO)

    freed = 0
    stripped = 0.0
    for v in mesh.data.vertices:
        weights = {by_index.get(g.group, ""): g.weight for g in v.groups}
        arm_share = sum(w for n, w in weights.items() if is_arm(n))
        if arm_share < grip:
            continue
        torso_share = sum(w for n, w in weights.items() if is_torso(n))
        if torso_share <= 0.0:
            continue
        for n, w in weights.items():
            if is_torso(n) and w > 0.0:
                groups[n].add([v.index], 0.0, "REPLACE")
        ## Renormalise what remains, so the vertex is still fully influenced and
        ## its rest position does not shift.
        keep = {n: w for n, w in weights.items() if not is_torso(n) and w > 0.0}
        total = sum(keep.values())
        if total > 0.0:
            for n, w in keep.items():
                groups[n].add([v.index], w / total, "REPLACE")
        freed += 1
        stripped += torso_share

    print("DETACH freed %d sleeve vertices, removed %.1f torso weight" % (freed, stripped))
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                              export_animations=True, export_nla_strips=True)
    print("DETACH wrote %s" % dst)

    ## Save the scene beside the output. Re-importing a 25MB GLB and redoing the
    ## weighting to try one different number is wasteful, and a power cut
    ## already destroyed a session's working files once.
    blend = os.path.splitext(dst)[0] + ".blend"
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    print("DETACH saved %s" % blend)


main()
