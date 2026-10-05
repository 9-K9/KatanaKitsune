"""Render one frame of one clip from a GLB, to look at a rigging fault.

Run under Blender:
    blender --background --python tools/render_pose.py -- <in.glb> <out.png> <clip> <frame> [view]

view: front (default) or quarter.

This exists because weight analysis lies. A tally of each vertex's dominant bone
said a sleeve sat correctly on the forearm — it was 60% forearm and 40% hips,
and the 40% stretched it into a membrane the moment the arm raised. Two rounds
of numbers passed it; one render caught it. So the loop is: render the pose that
stresses the fault, look at the picture, then change something.

Kept in tools/ rather than a scratch directory because the first version lived
in /tmp and was wiped by a power cut, taking the only way to verify the fixes
with it.
"""
import math
import sys

import bpy
from mathutils import Vector


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out, clip, frame = a[0], a[1], a[2], int(a[3])
    view = a[4] if len(a) > 4 else "front"

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    ## Clips arrive as NLA strips from the glTF importer; the pose only
    ## evaluates once one is the active action.
    action = None
    for track in (arm.animation_data.nla_tracks if arm.animation_data else []):
        for strip in track.strips:
            if strip.action and clip.lower() in (strip.action.name or "").lower():
                action = strip.action
    if action is None:
        have = [t.name for t in arm.animation_data.nla_tracks]
        print("NO_CLIP %s — have: %s" % (clip, have))
        return
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    arm.animation_data.action = action
    bpy.context.scene.frame_set(frame)

    ## Frame on the POSED geometry, not on bound_box. bound_box is the object's
    ## rest bounding box and ignores armature deformation entirely, so a clip
    ## carrying root motion walks the character clean out of shot and renders an
    ## empty frame that still reports success. Evaluating the depsgraph gives
    ## the vertices where they actually are on this frame.
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(deps)
        mesh = ev.to_mesh()
        pts += [ev.matrix_world @ v.co for v in mesh.vertices]
        ev.to_mesh_clear()
    if not pts:
        print("NO_GEOMETRY")
        return
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    span = max((hi - lo).x, (hi - lo).z)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span * 1.35
    if view == "quarter":
        ## Three-quarter, which shows a skirt scissoring that a flat front hides.
        ang = math.radians(40.0)
        cam.location = centre + Vector((-4 * math.sin(ang), -4 * math.cos(ang), 0.0))
        cam.rotation_euler = (math.radians(90), 0, -ang)
    else:
        cam.location = centre + Vector((0, -4, 0))
        cam.rotation_euler = (math.radians(90), 0, 0)

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", type="SUN"))
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(55), 0, math.radians(30))
    sun.data.energy = 4.0

    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.08, 0.10, 1)
    bpy.context.scene.world = world

    scene = bpy.context.scene
    scene.render.resolution_x = 420
    scene.render.resolution_y = 560
    scene.render.filepath = out
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("RENDERED %s" % out)


main()
