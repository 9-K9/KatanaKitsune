"""Bake a small Mixamo zombie set onto Meshy's reduced humanoid rig.

Run with Blender:
  blender --background --python tools/retarget_gashadokuro.py -- TARGET_FBX MIXAMO_DIR OUTPUT_GLB
"""

import os
import sys

import bpy


args = sys.argv[sys.argv.index("--") + 1:]
target_path, mixamo_dir, output_path = args

CLIPS = {
    "idle": "Zombie Idle.fbx",
    "walk": "Zombie Walk.fbx",
    "attack": "Zombie Attack.fbx",
    "hit": "Zombie Reaction Hit.fbx",
    "death": "Zombie Death.fbx",
}

TARGET_TO_SOURCE = {
    "Hips": "mixamorig:Hips",
    "Spine02": "mixamorig:Spine",
    "Spine01": "mixamorig:Spine1",
    "Spine": "mixamorig:Spine2",
    "neck": "mixamorig:Neck",
    "Head": "mixamorig:Head",
    "LeftShoulder": "mixamorig:LeftShoulder",
    "LeftArm": "mixamorig:LeftArm",
    "LeftForeArm": "mixamorig:LeftForeArm",
    "LeftHand": "mixamorig:LeftHand",
    "RightShoulder": "mixamorig:RightShoulder",
    "RightArm": "mixamorig:RightArm",
    "RightForeArm": "mixamorig:RightForeArm",
    "RightHand": "mixamorig:RightHand",
    "LeftUpLeg": "mixamorig:LeftUpLeg",
    "LeftLeg": "mixamorig:LeftLeg",
    "LeftFoot": "mixamorig:LeftFoot",
    "LeftToeBase": "mixamorig:LeftToeBase",
    "RightUpLeg": "mixamorig:RightUpLeg",
    "RightLeg": "mixamorig:RightLeg",
    "RightFoot": "mixamorig:RightFoot",
    "RightToeBase": "mixamorig:RightToeBase",
}


class Reporter:
    def report(self, kinds, message):
        print("FBX", kinds, message)


def import_fbx(path):
    # Blender 5.0.1's packaged FBX operator omits its multi-file RNA fields.
    # Calling the add-on loader directly avoids that UI-only regression.
    from io_scene_fbx import import_fbx
    before = set(bpy.context.scene.objects)
    before_actions = set(bpy.data.actions)
    import_fbx.load(Reporter(), bpy.context, filepath=path, use_anim=True)
    return list(set(bpy.context.scene.objects) - before), list(set(bpy.data.actions) - before_actions)


def armature_from(objects):
    arms = [obj for obj in objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise RuntimeError(f"Expected one armature, found {len(arms)}")
    return arms[0]


def action_range(action):
    start, end = action.frame_range
    return int(round(start)), int(round(end))


def remove_objects(objects):
    for obj in objects:
        if obj and obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
target_objects, target_actions = import_fbx(target_path)
target_arm = armature_from(target_objects)
target_arm.name = "Gashadokuro_Armature"
target_object_ids = {obj.as_pointer() for obj in target_objects}

# Preserve the Meshy-generated clip bundled with the only downloadable rig.
for action in target_actions:
    if action.frame_range[1] - action.frame_range[0] > 2:
        action.name = "meshy_generated_walk"
        action.use_fake_user = True
    else:
        action.use_fake_user = False

if target_arm.animation_data is None:
    target_arm.animation_data_create()
target_arm.animation_data.action = None

for clip_name, filename in CLIPS.items():
    source_path = os.path.join(mixamo_dir, filename)
    if not os.path.exists(source_path):
        raise FileNotFoundError(source_path)

    source_objects, source_actions = import_fbx(source_path)
    source_arm = armature_from(source_objects)
    source_arm.name = f"SOURCE_{clip_name}"
    animated = [a for a in source_actions if a.frame_range[1] > a.frame_range[0]]
    if not animated:
        raise RuntimeError(f"No animation in {source_path}")
    source_action = max(animated, key=lambda a: a.frame_range[1] - a.frame_range[0])
    source_arm.animation_data_create()
    source_arm.animation_data.action = source_action
    frame_start, frame_end = action_range(source_action)

    # Local rotations transfer well because both exports use the same standard
    # biped bone axes. Visual baking converts constraints into ordinary keys.
    for target_name, source_name in TARGET_TO_SOURCE.items():
        target_bone = target_arm.pose.bones.get(target_name)
        source_bone = source_arm.pose.bones.get(source_name)
        if target_bone is None or source_bone is None:
            raise RuntimeError(f"Missing map bone: {target_name} <- {source_name}")
        constraint = target_bone.constraints.new("COPY_ROTATION")
        constraint.name = "MixamoRetarget"
        constraint.target = source_arm
        constraint.subtarget = source_name
        constraint.owner_space = "LOCAL"
        constraint.target_space = "LOCAL"
        constraint.mix_mode = "REPLACE"

    action = bpy.data.actions.new(clip_name)
    action.use_fake_user = True
    target_arm.animation_data.action = action
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    bpy.context.scene.render.fps = 30
    bpy.ops.object.select_all(action="DESELECT")
    target_arm.select_set(True)
    bpy.context.view_layer.objects.active = target_arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(
        frame_start=frame_start,
        frame_end=frame_end,
        step=1,
        only_selected=True,
        visual_keying=True,
        clear_constraints=True,
        clear_parents=False,
        use_current_action=True,
        clean_curves=False,
        bake_types={"POSE"},
        channel_types={"LOCATION", "ROTATION", "SCALE", "BBONE", "PROPS"},
    )
    bpy.ops.object.mode_set(mode="OBJECT")

    # These are gameplay clips, so suppress horizontal root travel. Preserve
    # vertical pelvis motion for impacts and the collapse in the death clip.
    hips = target_arm.pose.bones["Hips"]
    bpy.context.scene.frame_set(frame_start)
    base_x, base_y = hips.location.x, hips.location.y
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        hips.location.x = base_x
        hips.location.y = base_y
        hips.keyframe_insert("location", frame=frame, group="Hips")

    action.name = clip_name
    target_arm.animation_data.action = None
    source_arm.animation_data.action = None
    for source_action_item in source_actions:
        if source_action_item.users == 0:
            bpy.data.actions.remove(source_action_item)
    remove_objects(source_objects)
    print(f"BAKED {clip_name}: {frame_start}-{frame_end}")

# Stash every action in NLA so exporters and downstream tools retain them.
target_arm.animation_data_create()
for action in [a for a in bpy.data.actions if a.name in set(CLIPS) | {"meshy_generated_walk"}]:
    track = target_arm.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    strip.name = action.name
    track.mute = True

target_arm.animation_data.action = None
os.makedirs(os.path.dirname(output_path), exist_ok=True)

# The FBX importer leaves helper geometry and source actions in Blender's data
# even after their armature objects are removed. Strip them explicitly so the
# GLB exposes only the character and its final named clips.
allowed_actions = set(CLIPS) | {"meshy_generated_walk"}
for obj in list(bpy.data.objects):
    if obj.as_pointer() not in target_object_ids:
        bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    if action.name not in allowed_actions:
        bpy.data.actions.remove(action)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format="GLB",
    use_selection=False,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_force_sampling=True,
    export_def_bones=True,
    export_optimize_animation_size=False,
    export_image_format="AUTO",
)
print("EXPORTED", output_path)
