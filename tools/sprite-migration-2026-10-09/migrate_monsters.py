#!/usr/bin/env python3
"""Migrate monster sprites to the new 768px / 16-frame PixelOver exports.

Per monster: copy the mapped export clip onto the in-game filenames, regenerate
every AtlasTexture at 768 with 16 frames, and drop any state the new export has
no clip for (animations, textures and the FSM node together, so
EnemyStateClass._drop_skills_without_states() can trim the matching trait).
"""
import re, shutil, sys, glob, os
from pathlib import Path

GAME = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-")
EXP  = Path("/home/emanzi/Apps/PixelOver/exports/katanakitsune")
DRY  = "--apply" not in sys.argv
CELL, FRAMES = 768, 16

## in-game scene name -> (export folder, {game state: export clip})
## A state absent here but present in the scene is dropped.
PLAN = {
	"kappa": ("kappa", {
		"idle": "Idle_02", "walk": "Walking", "run": "Running", "alert": "Alert",
		"block": "Block1", "death": "Dead", "hurt": "Hit_Reaction",
		"attack": "Agree_Gesture",        # caster: arm thrust -> water bolt
		"attack2": "air_squat",           # heavier charged cast
		"taunt": "Angry_To_Tantrum_Sit",  # drops onto his shell
	}),
	"jorogumo": ("jorogumo", {
		"idle": "Idle_7", "walk": "Walking", "run": "Running", "alert": "Alert",
		"block": "Block10", "death": "Dead", "hurt": "Hit_Reaction",
		"attack": "mage_soell_cast", "attack2": "mage_soell_cast_3",
		"taunt": "Bubble_Dance",
	}),
	"karasuShinobi": ("karasushinobi", {
		"idle": "Idle_11", "walk": "Walking", "run": "Running", "alert": "Alert",
		"block": "Block1", "death": "Dead", "hurt": "Hit_Reaction_1",
		"attack": "Sweeping_Kick", "attack2": "360_Power_Spin_Jump",
		# taunt dropped: no taunt-like clip in the export
	}),
	"oni": ("oni", {
		"idle": "Idle_02", "walk": "Walking", "attack": "Punch_Combo",
		"death": "Dead", "hurt": "Hit_Reaction_1",
	}),
	"yukiOnna": ("yukionna", {
		"idle": "Idle_7", "walk": "Walking", "attack": "Angry_Stomp",
		"block": "Block2", "death": "Dead", "hurt": "Hit_Reaction",
		# charge and draw dropped: no clips. _drop_skills_without_states()
		# clears the duellist trait once the draw node is gone.
	}),
}

COMPASS = ["east","north","northEast","northWest","south","southEast","southWest","west"]


def export_file(folder, clip, n):
	hits = glob.glob(str(EXP/folder/clip/f"*_dir{n}.png"))
	return Path(hits[0]) if hits else None


def migrate(scene_name, folder, mapping):
	tscn = GAME/"scenes/monsters"/f"{scene_name}.tscn"
	if not tscn.exists():
		print(f"  !! no scene for {scene_name}"); return
	t = tscn.read_text()

	ext = {m.group(2): m.group(1) for m in re.finditer(
		r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', t)}
	atlas = {m.group(1): m.group(2) for m in re.finditer(
		r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\natlas = ExtResource\("([^"]+)"\)', t)}
	blob = re.search(r'animations = \[(.*?)\]\n', t, re.S)

	anims = []
	for blk in re.finditer(
			r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)\s*\}',
			blob.group(1), re.S):
		ids = re.findall(r'SubResource\("([^"]+)"\)', blk.group(1))
		src = {ext[atlas[i]] for i in ids if i in atlas}
		anims.append(dict(name=blk.group(3), loop=blk.group(2),
						  speed=float(blk.group(4)), src=sorted(src)[0]))

	states = sorted({a['name'].rsplit('_',1)[0] for a in anims})
	keep   = [s for s in states if s in mapping]
	drop   = [s for s in states if s not in mapping]

	# ---- copy PNGs ----
	copied = missing = 0
	for a in anims:
		state = a['name'].rsplit('_',1)[0]
		if state not in mapping:
			continue
		n = re.search(r'dir(\d)\.png', a['src']).group(1)
		src = export_file(folder, mapping[state], n)
		dst = GAME/a['src'].replace('res://','')
		if src is None:
			print(f"    MISSING export {folder}/{mapping[state]} dir{n}"); missing += 1; continue
		if not DRY:
			dst.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(src, dst)
		copied += 1

	# ---- regenerate atlases + animations ----
	blocks, new_anims = [], []
	path2ext = {v: k for k, v in ext.items()}
	kept_ext = set()
	for idx, a in enumerate(anims):
		if a['name'].rsplit('_',1)[0] not in mapping:
			continue
		eid = path2ext[a['src']]; kept_ext.add(eid)
		ids = []
		for f in range(FRAMES):
			aid = f"At_{idx:03d}_{f:02d}"; ids.append(aid)
			blocks.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
						  f'atlas = ExtResource("{eid}")\n'
						  f'region = Rect2({f*CELL}, 0, {CELL}, {CELL})\n')
		frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
		new_anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
						 % (frames, a['loop'], a['name'], a['speed']*2))

	t = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("[^"]+"\)\nregion = Rect2\([^)]*\)\n\n?', '', t)
	sf = re.search(r'\[sub_resource type="SpriteFrames" id="[^"]+"\]', t)
	t = t[:sf.start()] + "\n".join(blocks) + "\n" + t[sf.start():]
	t = re.sub(r'animations = \[.*?\]\n', "animations = [" + ", ".join(new_anims) + "]\n",
			   t, count=1, flags=re.S)

	# ---- drop unused texture ext_resources ----
	for eid, p in list(ext.items()):
		if eid not in kept_ext:
			t = re.sub(r'\[ext_resource type="Texture2D" path="%s" id="%s"\]\n' % (re.escape(p), re.escape(eid)), '', t)

	# ---- drop FSM nodes for dropped states ----
	for s in drop:
		t = re.sub(r'\[node name="%s" type="Node" parent="FiniteStateMachine"\]\nscript = ExtResource\("[^"]+"\)\n\n?' % re.escape(s), '', t)

	n_sub = t.count("[sub_resource "); n_ext = t.count("[ext_resource ")
	t = re.sub(r'load_steps=\d+', f'load_steps={n_sub+n_ext+1}', t, count=1)

	print(f"  {scene_name:15s} keep={keep}")
	print(f"  {'':15s} DROP={drop or 'none'}  pngs={copied} missing={missing} atlases={len(blocks)} anims={len(new_anims)} load_steps={n_sub+n_ext+1}")
	if missing:
		print("    !! aborted (missing sources)"); return
	if not DRY:
		shutil.copy2(tscn, str(tscn)+".bak")
		tscn.write_text(t)


for scene, (folder, mapping) in PLAN.items():
	migrate(scene, folder, mapping)
print("\nDRY RUN - nothing written. re-run with --apply" if DRY else "\nAPPLIED")
