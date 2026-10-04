"""Graft Mixamo clips onto a Meshy-rigged GLB that already shares its skeleton.

Run under Blender:
    blender --background --python tools/retarget.py -- <target.glb> <out.glb> <Name=clip.fbx> ...

This is not retargeting in the hard sense. Meshy's Mixamo-compatible rigs and
the Mixamo clips use the same 28 bones under the same `mixamorig:` names, so an
action authored against one addresses the other correctly with no bone mapping.
What does need handling is scale: Mixamo FBX is authored in centimetres and the
GLB is in metres, so the hip translation curves arrive a hundred times too big
and the character rockets off the floor. Importing at 0.01 fixes it at source.

Each clip keeps the name it is given on the command line, because that name is
what the exporter and then the game's folder layout rely on — not whatever
Mixamo called the file.
"""
import os
import sys

import bpy


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def fcurves_of(action):
    """Every F-curve in an action, on either API.

    Blender 4.4 moved actions to layers and slots, so `action.fcurves` is gone
    in 5.0 and the curves live under layer -> strip -> channelbag. The older
    attribute is tried first so this keeps working on 4.x.
    """
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                out.extend(bag.fcurves)
    return out


def armature_of(objs):
    for o in objs:
        if o.type == "ARMATURE":
            return o
    return None


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def import_fbx(path):
    before = set(bpy.data.objects)
    ## wm.fbx_import, not import_scene.fbx. The latter still exists in Blender
    ## 5.0 but only exposes filepath and axes and then dies inside its own
    ## execute on a missing `files` attribute — it cannot be driven from a
    ## script. The newer operator takes the scale and animation flags that
    ## actually matter here.
    ##
    ## Centimetres to metres: Mixamo authors in cm and the GLB is in metres, so
    ## without this the hip translation arrives a hundred times too large and
    ## the character launches off the floor.
    bpy.ops.wm.fbx_import(filepath=path, global_scale=0.01,
                          use_anim=True, ignore_leaf_bones=True)
    return [o for o in bpy.data.objects if o not in before]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    target_path, out_path = argv[0], argv[1]
    clips = []
    for spec in argv[2:]:
        name, _, path = spec.partition("=")
        clips.append((name, path))

    clear()
    target_objs = import_glb(target_path)
    target = armature_of(target_objs)
    if target is None:
        print("RETARGET FAIL: no armature in %s" % target_path)
        return

    ## Everything the target already had, so existing clips survive.
    kept = []
    if target.animation_data and target.animation_data.action:
        kept.append(target.animation_data.action)
    for track in (target.animation_data.nla_tracks if target.animation_data else []):
        for strip in track.strips:
            if strip.action:
                kept.append(strip.action)

    target_bones = {b.name for b in target.pose.bones}
    added = []
    for name, path in clips:
        if not os.path.exists(path):
            print("  %-10s MISSING %s" % (name, path))
            continue
        objs = import_fbx(path)
        src = armature_of(objs)
        if src is None or not src.animation_data or not src.animation_data.action:
            print("  %-10s no action in %s" % (name, os.path.basename(path)))
            for o in objs:
                bpy.data.objects.remove(o, do_unlink=True)
            continue

        action = src.animation_data.action
        ## How much of THIS skeleton the clip drives — not how much of the clip
        ## gets used. Mixamo authors every finger, and these rigs have 28 bones
        ## with no fingers, so a third of the source curves legitimately land
        ## nowhere. Measuring the source makes a perfect graft look like a 42%
        ## failure; measuring the target asks the question that matters, which
        ## is whether any bone was left unanimated.
        driven = set()
        for fc in fcurves_of(action):
            if '["' in fc.data_path:
                bone = fc.data_path.split('["')[1].split('"]')[0]
                if bone in target_bones:
                    driven.add(bone)
        hit, total = len(driven), len(target_bones)
        action.name = name
        action.use_fake_user = True
        added.append((name, hit, total))

        ## The imported rig has served its purpose; the action outlives it.
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)

    for name, hit, total in added:
        share = (100.0 * hit / total) if total else 0.0
        flag = "ok" if share > 80.0 else "CHECK — names did not line up"
        print("  %-10s drives %d/%d target bones (%.0f%%) %s" % (name, hit, total, share, flag))

    ## Stack every action as its own NLA strip, which is how the glTF exporter
    ## decides what to write out as separate animations.
    if target.animation_data is None:
        target.animation_data_create()
    target.animation_data.action = None
    for track in list(target.animation_data.nla_tracks):
        target.animation_data.nla_tracks.remove(track)
    for action in kept + [bpy.data.actions[n] for n, _, _ in added]:
        track = target.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, int(action.frame_range[0]), action)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB",
                              export_animations=True, export_nla_strips=True)
    print("RETARGET OK: %s (%d existing + %d grafted)"
          % (os.path.basename(out_path), len(kept), len(added)))


main()
