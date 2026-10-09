#!/usr/bin/env python3
"""Wire the new enemy states into the six monster scenes.

Adds ext_resources for the new state scripts, FSM child nodes with their
per-monster tuning, swaps the casters' attack state from melee to enemyCast,
and sets species traits on the root body.
"""
import re, sys, shutil
from pathlib import Path

GAME = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-")
DRY  = "--apply" not in sys.argv
SCRIPTS = "res://scripts/stateMachine/enemyState"
FX = "res://assets/sprites/fx/projectiles"

## state node name -> (script file, {property: literal})
PLAN = {
 "oni": {
   "nodes": {
     "stomp": ("enemyStomp.gd", {"impact_frame":"9","reach":"2.4","damage_multiplier":"1.6","recovery_seconds":"1.1"}),
     "heavy": ("enemyHeavy.gd", {"hit_frame":"6","reach":"1.8","damage_multiplier":"1.45"}),
     "dodge": ("enemyDodge.gd", {"distance":"90.0","duration":"0.45"}),
     "block": ("enemyBlock.gd", {}),
   }, "cast": None, "traits": None},
 "kappa": {
   "nodes": {
     "stumble": ("enemyStumble.gd", {"exposed_multiplier":"2.0","down_seconds":"0.9"}),
     "arise":   ("enemyArise.gd", {}),
     "dodge":   ("enemyDodge.gd", {"distance":"80.0","duration":"0.45"}),
   },
   ## He throws eggs. Heavy, slow, tumbling.
   "cast": {"release_frame":"7", "tex":"egg_kappa.png", "projectile_speed":"215.0",
            "damage_multiplier":"0.8", "projectile_spin":"300.0"},
   "traits": '{"shell": 0.12}'},
 "jorogumo": {
   "nodes": {
     "weave": ("enemyWeave.gd", {"heal_fraction":"0.35","ticks":"6"}),
     "dodge": ("enemyDodge.gd", {"distance":"145.0","duration":"0.4"}),
   },
   ## Bubbles drift rather than fly.
   "cast": {"release_frame":"9", "tex":"bubble_jorogumo.png", "projectile_speed":"195.0",
            "damage_multiplier":"0.7", "projectile_bob_rate":"6.0", "projectile_bob_height":"3.0"},
   "traits": None},
 "karasuShinobi": {
   "nodes": {
     "crit":  ("enemyCrit.gd", {"hit_frame":"8","reach":"1.5","damage_multiplier":"2.2","whiff_chance":"0.3"}),
     "arise": ("enemyArise.gd", {}),
     "dodge": ("enemyDodge.gd", {"distance":"155.0","duration":"0.38"}),
   }, "cast": None, "traits": None},
 "tengu": {
   "nodes": {
     "crit":  ("enemyCrit.gd", {"hit_frame":"8","reach":"1.6","damage_multiplier":"2.0","whiff_chance":"0.35"}),
     "arise": ("enemyArise.gd", {}),
     "dodge": ("enemyDodge.gd", {"distance":"165.0","duration":"0.38"}),
   }, "cast": None, "traits": None},
 "yukiOnna": {
   "nodes": {
     "weave": ("enemyWeave.gd", {"heal_fraction":"0.3","ticks":"6"}),
     "dodge": ("enemyDodge.gd", {"distance":"130.0","duration":"0.42"}),
   },
   ## Snow, packed hard and thrown flat.
   "cast": {"release_frame":"8", "tex":"snowball_yukionna.png", "projectile_speed":"290.0",
            "damage_multiplier":"0.8"},
   "traits": None},
}


def wire(scene, spec):
    f = GAME/"scenes/monsters"/f"{scene}.tscn"
    t = f.read_text()
    added, skipped = [], []

    existing = set(re.findall(r'\[node name="([a-z0-9]+)" type="Node" parent="FiniteStateMachine"\]', t))
    exts = []

    # --- new FSM nodes ---
    blocks = ""
    for name, (script, props) in spec["nodes"].items():
        if name in existing:
            skipped.append(name); continue
        rid = f"st_{name}"
        if f'id="{rid}"' not in t:
            exts.append(f'[ext_resource type="Script" path="{SCRIPTS}/{script}" id="{rid}"]')
        blocks += f'\n[node name="{name}" type="Node" parent="FiniteStateMachine"]\nscript = ExtResource("{rid}")\n'
        for k, v in props.items():
            blocks += f"{k} = {v}\n"
        added.append(name)

    # --- caster: swap the attack node's script and configure the shot ---
    cast_note = ""
    if spec["cast"]:
        c = spec["cast"]
        if 'path="%s/enemyCast.gd"' % SCRIPTS not in t:
            exts.append(f'[ext_resource type="Script" path="{SCRIPTS}/enemyCast.gd" id="st_cast"]')
        tex_id = "tex_shot"
        if f'id="{tex_id}"' not in t:
            exts.append(f'[ext_resource type="Texture2D" path="{FX}/{c["tex"]}" id="{tex_id}"]')
        m = re.search(r'(\[node name="attack" type="Node" parent="FiniteStateMachine"\]\n)script = ExtResource\("[^"]+"\)\n((?:[a-z_]+ = .*\n)*)', t)
        if m:
            body = f'script = ExtResource("st_cast")\nprojectile_texture = ExtResource("{tex_id}")\n'
            for k, v in c.items():
                if k != "tex":
                    body += f"{k} = {v}\n"
            t = t[:m.start()] + m.group(1) + body + t[m.end():]
            cast_note = f'attack -> enemyCast ({c["tex"]})'

    # --- species traits on the root body ---
    trait_note = ""
    if spec["traits"]:
        root = re.search(r'(\[node name="\w+" type="CharacterBody2D" groups=\["enemy"\]\]\n)', t)
        if root and "species_traits" not in t:
            t = t[:root.end()] + f'species_traits = {spec["traits"]}\n' + t[root.end():]
            trait_note = spec["traits"]

    # --- splice ext_resources and node blocks ---
    if exts:
        last = list(re.finditer(r'^\[ext_resource [^\]]*\]$', t, re.M))[-1]
        t = t[:last.end()] + "\n" + "\n".join(exts) + t[last.end():]
    if blocks:
        fsm = list(re.finditer(r'\[node name="[a-z0-9]+" type="Node" parent="FiniteStateMachine"\]\nscript = ExtResource\("[^"]+"\)\n(?:[a-z_]+ = .*\n)*', t))
        t = t[:fsm[-1].end()] + blocks + t[fsm[-1].end():]

    ns, ne = t.count("[sub_resource "), t.count("[ext_resource ")
    t = re.sub(r'load_steps=\d+', f'load_steps={ns+ne+1}', t, count=1)

    print(f"  {scene:15s} +states={added or '-'} skipped={skipped or '-'}")
    print(f"  {'':15s} {cast_note or 'melee'}   traits={trait_note or '-'}   load_steps={ns+ne+1}")
    if not DRY:
        shutil.copy2(f, str(f)+".bak3")
        f.write_text(t)


for scene, spec in PLAN.items():
    wire(scene, spec)
print("\nDRY RUN — re-run with --apply" if DRY else "\nAPPLIED")
