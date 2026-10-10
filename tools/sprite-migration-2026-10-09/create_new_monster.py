#!/usr/bin/env python3
"""Build a brand-new monster scene from a raw PixelOver export.

Unlike migrate_monsters.py (which edits an existing .tscn in place), this
generates one from scratch: copies+renames the per-direction PNGs into the
project's asset convention, then writes ext_resource/AtlasTexture/SpriteFrames
blocks and the node tree (FiniteStateMachine state nodes, CollisionShape2D,
HitBox, HealthBar, TauntComponent) matching the hand-built scenes
(karasuShinobi.tscn, kappa.tscn).

One call per monster; see MONSTERS below for the three driving this run
(Kasha, Yokai Lord, NinaNinja).
"""
import os
import random
import shutil
import string
import subprocess

ROOT = "/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-"
EXPORT_ROOT = "/home/emanzi/Apps/PixelOver/exports/katanakitsune"
ART = os.path.join(ROOT, "assets/sprites/monsters")
SCENES = os.path.join(ROOT, "scenes/monsters")

## Matches one top-level `[node ...]` block: its own header line plus every
## property line under it, up to (but not including) the next `[` heading or
## end of file.
import re
_NODE_BLOCK = r'\[node name="%s"[^\]]*\](?:\n(?!\[).*)*'


def _preserve_hand_edits(existing_text, generated_text, node_name):
    """Keeps whatever a person last saved for every node with this name,
    splicing them back into a freshly regenerated scene in order.

    This generator used to overwrite the whole .tscn unconditionally,
    including both CollisionShape2D nodes (the body circle and the HitBox
    capsule) it hardcodes from the same template every time — so any
    hand-tuned collision/hit box got silently reset back to the generator's
    guess the next time this ran again for that monster (e.g. to add a
    clip it was missing). A scene has two nodes sharing this name (the body
    and the HitBox's own), so matches are paired up by position rather than
    assuming there is only one. Splicing the previous file's own blocks back
    in means a human edit in the Godot editor always wins over this script;
    everything else (art, frame counts, stats) still updates freely.
    """
    pattern = _NODE_BLOCK % re.escape(node_name)
    saved = iter(re.finditer(pattern, existing_text))
    def _keep_saved(found):
        prior = next(saved, None)
        return prior.group(0) if prior is not None else found.group(0)
    return re.sub(pattern, _keep_saved, generated_text)


CELL = 768
FRAMES = 16
DIRECTIONS = ("southWest", "west", "northWest", "north",
              "northEast", "east", "southEast", "south")

## loop=1 clips, everything else is a one-shot.
LOOPING = {"idle", "walk"}
## speed buckets, from the existing hand-built scenes.
SPEEDS = {
    "idle": 10.0, "alert": 10.0, "taunt": 10.0,
    "walk": 16.0, "block": 16.0, "hurt": 16.0, "arise": 16.0,
    "attack": 20.0, "crit": 20.0, "dodge": 20.0,
    "death": 10.0,
}

## Shared script resources — same uid as every hand-built scene; these are
## existing project resources, not new ones.
SCRIPT_UIDS = {
    "enemy_script": ("uid://c0k3po474ljt8", "res://scripts/stateMachine/unit/EnemyUnit.gd"),
    "fsm": ("uid://ciq77fttx01rl", "res://addons/finite_state_machine/scripts/finite_state_machine.gd"),
    "soften_shader_SHADER": ("uid://b7wlcman4m8dk", "res://shaders/powerState.gdshader"),
    "taunt_component": ("uid://ws3hybtfrc2h", "res://scripts/components/TauntComponent.gd"),
    "st_idle": ("uid://cncsf706jkruh", "res://scripts/stateMachine/enemyState/enemyIdle.gd"),
    "st_alert": ("uid://cdnm3u4k8yokd", "res://scripts/stateMachine/enemyState/enemyAlert.gd"),
    "st_walk": ("uid://bf816vqk133sa", "res://scripts/stateMachine/enemyState/enemyWalk.gd"),
    "st_attack": ("uid://bi8sqlh885usf", "res://scripts/stateMachine/enemyState/enemyAttack.gd"),
    "st_cast": ("uid://b6sbb6i756esa", "res://scripts/stateMachine/enemyState/enemyCast.gd"),
    "st_block": ("uid://kerj3vxii6x4", "res://scripts/stateMachine/enemyState/enemyBlock.gd"),
    "st_hurt": ("uid://craqxbew6ba3y", "res://scripts/stateMachine/enemyState/enemyHurt.gd"),
    "st_death": ("uid://qhi5wu5tw664", "res://scripts/stateMachine/enemyState/enemyDeath.gd"),
    "st_crit": ("uid://bu06g37f1lcip", "res://scripts/stateMachine/enemyState/enemyCrit.gd"),
    "st_arise": ("uid://dfwdrixc8i4a7", "res://scripts/stateMachine/enemyState/enemyArise.gd"),
    "st_dodge": ("uid://n5vpaya0ud2", "res://scripts/stateMachine/enemyState/enemyDodge.gd"),
    "st_taunt": ("uid://bpo4asbpcd3j8", "res://scripts/stateMachine/enemyState/enemyTaunt.gd"),
}

TAUNT_TIMELINE = "res://dialogue/enemies/undeadRonin_taunt.dtl"
KAPPA_PROJECTILE_TEX = ("uid://chu2lshruen2j", "res://assets/sprites/fx/projectiles/egg_kappa.png")

## Monster definitions. Each state maps to (export_clip_folder, asset_state_folder).
MONSTERS = {
    "kasha": {
        "title": "Kasha",
        "export_folder": "kasha",
        "export_prefix": "Kasha",
        "states": {
            "idle": "Idle_7",
            "alert": "Alert",
            "walk": "Walking",
            "attack": "Lunge_Spin_Kick",
            "block": "Block1",
            "hurt": "Hit_Reaction",
            "death": "Dead",
            "dodge": "Backflip_Jump",
            "taunt": "Breakdance_1990",
        },
        "attack_kind": "melee",
        "stats": {"tier": 3, "max_health": 150.0, "move_speed": 50.0,
                   "attack_damage": 24.0, "attack_cooldown": 1.4},
    },
    "ninaNinja": {
        "title": "NinaNinja",
        "export_folder": "ninaninja",
        "export_prefix": "NinaNinja",
        "states": {
            "idle": "Idle_6",
            "alert": "Alert",
            "walk": "Walking",
            "attack": "Flying_Fist_Kick",
            "block": "Block1",
            "hurt": "Hit_Reaction",
            "death": "Dead",
            "crit": "Backflip_and_Hooks",
            "arise": "Backflip_and_Rise",
            "dodge": "Backflip",
        },
        "attack_kind": "melee",
        "stats": {"tier": 2, "max_health": 95.0, "move_speed": 64.0,
                   "attack_damage": 22.0, "attack_cooldown": 1.3},
    },
    "yokailord": {
        "title": "Yokailord",
        "export_folder": "yokailord",
        "export_prefix": "Yokai_Lord",
        "states": {
            "idle": "Idle_02",
            "alert": "Alert",
            "walk": "Walking",
            "attack": "Charged_Spell_Cast",
            "block": "Block2",
            "hurt": "Hit_Reaction",
            "death": "Dead",
        },
        "attack_kind": "cast",
        "stats": {"tier": 6, "max_health": 260.0, "move_speed": 46.0,
                   "attack_damage": 28.0, "attack_cooldown": 1.6},
    },
}

## asset state-folder name per FSM state key, matching the hand-built scenes'
## capitalised single-word convention (Idle, Walk, Attack, Block, ...).
STATE_ASSET_FOLDER = {
    "idle": "Idle", "alert": "Alert", "walk": "Walk", "attack": "Attack",
    "block": "Block", "hurt": "Hurt", "death": "Death", "crit": "Crit",
    "arise": "Arise", "dodge": "Dodge", "taunt": "Taunt",
}

## position/offset for the AnimatedSprite2D — measured from each export's own
## idle dir1 frame so the feet land where the existing monsters' do (world
## bottom ~= +17..+32, see session notes). All three exports share almost
## identical proportions, so the computed offset is the same for all three.
SPRITE_POSITION = (0, -88)
SPRITE_OFFSET = (0, 2)


def _existing_uids():
    out = subprocess.run(
        ["grep", "-roh", "uid://[a-z0-9]*", ROOT],
        capture_output=True, text=True)
    return set(out.stdout.split())


def _new_uid(taken):
    alphabet = string.ascii_lowercase + string.digits
    while True:
        candidate = "uid://" + "".join(random.choices(alphabet, k=13))
        if candidate not in taken:
            taken.add(candidate)
            return candidate


def copy_assets(monster, cfg):
    folder = monster
    src_root = os.path.join(EXPORT_ROOT, cfg["export_folder"])
    dst_root = os.path.join(ART, folder, "sprites")
    for state, clip in cfg["states"].items():
        asset_folder = STATE_ASSET_FOLDER[state]
        src_dir = os.path.join(src_root, clip)
        dst_dir = os.path.join(dst_root, asset_folder)
        os.makedirs(dst_dir, exist_ok=True)
        for d in range(1, 9):
            src = os.path.join(src_dir, "%s_%s_dir%d.png" % (cfg["export_prefix"], clip, d))
            dst = os.path.join(dst_dir, "%s_%s_dir%d.png" % (folder, asset_folder, d))
            if not os.path.exists(src):
                raise FileNotFoundError(src)
            shutil.copyfile(src, dst)


def build_art_blocks(monster, cfg):
    """Return (ext_resource_lines, sub_resource_atlas_lines, sprite_frames_block)."""
    ext_lines = []
    atlas_lines = []
    animations = []
    for state in cfg["states"]:
        asset_folder = STATE_ASSET_FOLDER[state]
        for d in range(1, 9):
            tx_id = "tx_%s_%d" % (state, d)
            path = "res://assets/sprites/monsters/%s/sprites/%s/%s_%s_dir%d.png" % (
                monster, asset_folder, monster, asset_folder, d)
            ext_lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (path, tx_id))
            frame_refs = []
            for f in range(FRAMES):
                atlas_id = "Atlas_%s_%d_%d" % (state, d, f)
                atlas_lines.append(
                    '[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, 0, %d, %d)'
                    % (atlas_id, tx_id, f * CELL, CELL, CELL))
                frame_refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % atlas_id)
            animations.append(
                '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": %.1f\n}'
                % (", ".join(frame_refs),
                   "true" if state in LOOPING else "false",
                   state, DIRECTIONS[d - 1],
                   SPEEDS[state]))
    sprite_frames = '[sub_resource type="SpriteFrames" id="SpriteFrames_mummy"]\nanimations = [%s]' % ", ".join(animations)
    return ext_lines, atlas_lines, sprite_frames


def build_scene(monster, cfg, taken_uids):
    title = cfg["title"]
    states = list(cfg["states"].keys())

    ext_resource_lines = []
    ext_resource_lines.append('[ext_resource type="Script" uid="%s" path="%s" id="enemy_script"]' % SCRIPT_UIDS["enemy_script"])
    ext_resource_lines.append('[ext_resource type="Script" uid="%s" path="%s" id="fsm"]' % SCRIPT_UIDS["fsm"])
    ext_resource_lines.append('[ext_resource type="Shader" uid="%s" path="%s" id="soften_shader"]' % SCRIPT_UIDS["soften_shader_SHADER"])

    ## Only the scripts this monster's state list actually uses.
    state_script_id = {}
    for state in states:
        if state == "attack":
            key = "st_cast" if cfg["attack_kind"] == "cast" else "st_attack"
        else:
            key = "st_%s" % state
        state_script_id[state] = key
    for key in sorted(set(state_script_id.values())):
        uid, path = SCRIPT_UIDS[key]
        ext_resource_lines.append('[ext_resource type="Script" uid="%s" path="%s" id="%s"]' % (uid, path, key))
    ext_resource_lines.append('[ext_resource type="Script" uid="%s" path="%s" id="taunt_component"]' % SCRIPT_UIDS["taunt_component"])

    if cfg["attack_kind"] == "cast":
        uid, path = KAPPA_PROJECTILE_TEX
        ext_resource_lines.append('[ext_resource type="Texture2D" uid="%s" path="%s" id="tex_shot"]' % (uid, path))

    tex_ext_lines, atlas_lines, sprite_frames_block = build_art_blocks(monster, cfg)
    ext_resource_lines.extend(tex_ext_lines)

    ## -- sub_resources --------------------------------------------------
    sub_resource_lines = []
    sub_resource_lines.append('[sub_resource type="CircleShape2D" id="CircleShape2D_body"]\nradius = 32.0')
    sub_resource_lines.append(
        '[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_hitbox"]\n'
        'resource_local_to_scene = true\nradius = 31.0\nheight = 176.0')
    sub_resource_lines.append(
        '[sub_resource type="ShaderMaterial" id="ShaderMaterial_soften"]\n'
        'shader = ExtResource("soften_shader")\n'
        'shader_parameter/enabled = false\n'
        'shader_parameter/shadow_color = Vector3(0.282353, 0.015686, 0.003922)\n'
        'shader_parameter/highlight_color = Vector3(0.94902, 0.227451, 0.078431)\n'
        'shader_parameter/soften_highlights = true\n'
        'shader_parameter/soften_amount = 0.85\n'
        'shader_parameter/spike_threshold = 0.1\n'
        'shader_parameter/spike_range = 0.35')
    sub_resource_lines.extend(atlas_lines)
    sub_resource_lines.append(sprite_frames_block)
    sub_resource_lines.append(
        '[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_hpbg"]\n'
        'bg_color = Color(0.113725, 0.0862745, 0.0862745, 1)')
    sub_resource_lines.append(
        '[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_hpfill"]\n'
        'bg_color = Color(0.66, 0.15, 0.15, 1)')

    ## -- nodes ------------------------------------------------------------
    stats = cfg["stats"]
    node_lines = []
    node_lines.append(
        '[node name="%s" type="CharacterBody2D" groups=["enemy"]]\n'
        'collision_layer = 3\n'
        'script = ExtResource("enemy_script")\n'
        'tier = %d\n'
        'max_health = %.1f\n'
        'move_speed = %.1f\n'
        'attack_damage = %.1f\n'
        'attack_cooldown = %.1f'
        % (title, stats["tier"], stats["max_health"], stats["move_speed"],
           stats["attack_damage"], stats["attack_cooldown"]))
    node_lines.append('[node name="NavigationAgent2D" type="NavigationAgent2D" parent="."]')
    node_lines.append(
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
        'shape = SubResource("CircleShape2D_body")')
    node_lines.append(
        '[node name="HitBox" type="Area2D" parent="." groups=["enemy_hitbox"]]\n'
        'collision_layer = 2\ncollision_mask = 0')
    node_lines.append(
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="HitBox"]\n'
        'position = Vector2(0, -56)\n'
        'shape = SubResource("CapsuleShape2D_hitbox")')
    default_anim = "alert_%s" % DIRECTIONS[5] if "alert" in states else "idle_%s" % DIRECTIONS[5]
    node_lines.append(
        '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\n'
        'material = SubResource("ShaderMaterial_soften")\n'
        'position = Vector2(%d, %d)\n'
        'sprite_frames = SubResource("SpriteFrames_mummy")\n'
        'animation = &"%s"\n'
        'offset = Vector2(%d, %d)'
        % (SPRITE_POSITION[0], SPRITE_POSITION[1], default_anim, SPRITE_OFFSET[0], SPRITE_OFFSET[1]))
    node_lines.append(
        '[node name="HealthBar" type="ProgressBar" parent="."]\n'
        'offset_left = -26.0\noffset_top = -251.0\noffset_right = 26.0\noffset_bottom = -245.0\n'
        'theme_override_styles/background = SubResource("StyleBoxFlat_hpbg")\n'
        'theme_override_styles/fill = SubResource("StyleBoxFlat_hpfill")\n'
        'value = 100.0\nshow_percentage = false')
    node_lines.append(
        '[node name="TauntComponent" type="Node" parent="."]\n'
        'script = ExtResource("taunt_component")\n'
        'timeline = "%s"' % TAUNT_TIMELINE)
    node_lines.append(
        '[node name="FiniteStateMachine" type="Node" parent="." node_paths=PackedStringArray("current_state")]\n'
        'script = ExtResource("fsm")\n'
        'current_state = NodePath("idle")')
    for state in states:
        key = state_script_id[state]
        extra = ""
        if state == "dodge":
            extra = "\ndistance = 120.0\nduration = 0.4"
        elif state == "attack" and cfg["attack_kind"] == "cast":
            extra = (
                '\nprojectile_texture = ExtResource("tex_shot")'
                '\nprojectile_speed = 230.0'
                '\ndamage_multiplier = 1.0'
            )
        node_lines.append(
            '[node name="%s" type="Node" parent="FiniteStateMachine"]\nscript = ExtResource("%s")%s'
            % (state, key, extra))

    ## -- assemble ----------------------------------------------------------
    ## No load_steps here, matching every hand-built monster scene — it is
    ## only a progress-bar hint, and a stale one on a 1000+ sub_resource file
    ## is what caused the threaded ResourceLoader race (null texture) this
    ## generator used to produce before the hint was dropped.
    scene_uid = _new_uid(taken_uids)
    parts = [
        '[gd_scene format=3 uid="%s"]' % scene_uid,
        "\n".join(ext_resource_lines),
        "\n\n".join(sub_resource_lines),
        "\n\n".join(node_lines),
    ]
    return "\n\n".join(parts) + "\n"


def main():
    taken = _existing_uids()
    for monster, cfg in MONSTERS.items():
        copy_assets(monster, cfg)
        text = build_scene(monster, cfg, taken)
        out_path = os.path.join(SCENES, "%s.tscn" % monster)
        if os.path.exists(out_path):
            existing = open(out_path).read()
            text = _preserve_hand_edits(existing, text, "CollisionShape2D")
        with open(out_path, "w") as fh:
            fh.write(text)
        print("wrote", out_path)


if __name__ == "__main__":
    main()
