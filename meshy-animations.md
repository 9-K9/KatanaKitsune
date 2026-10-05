# Which animations each enemy needs

Nine clips, the same nine for every enemy. Tier no longer changes the animation
set — it changes damage, health and speed, which are numbers in
`scripts/system/EnemyTier.gd` and need no art at all.

## The nine

| folder | loops | required | what it is |
|---|---|---|---|
| `Idle` | yes | **yes** | standing; the most-seen clip in the game |
| `Walk` | yes | **yes** | from Meshy |
| `Run` | yes | no | tier 2+ chase at ~2x speed, and a sped-up walk reads badly. From Meshy |
| `Attack` | no | **yes** | |
| `Attack2` | no | no | the cheapest variety available — one attack on repeat is the clearest tell that an enemy is shallow |
| `Hurt` | no | **yes** | without it a hit does not register and combat feels dead |
| `Death` | no | **yes** | |
| `Block` | no | no | `enemyBlock` already backs the monster away while this plays. Without it every enemy only trades blows |
| `Alert` | no | no | the state machine has an `alert` node. A brief "spotted you" beat is what makes the sneak system feel like it matters |

The five marked required are what `tools/build_enemy_scene.py` refuses to build
without. The other four are what stop the bestiary feeling thin.

If one has to go, drop `Alert` — the state falls back to Idle. Keep `Attack2`:
repetition is more visible than a missing telegraph.

## Asking Meshy for them

**Weaponless.** Kicks, claws, palm strikes, a magic gesture. Only the player
carries a katana, and weaponless attacks also avoid the prop-alignment problems
that cost a day earlier.

**Idle, Walk and Run loop. The other six play once.** A walk whose last frame
does not meet its first snaps every stride, and that is the fault most worth
catching in Meshy's preview rather than after export.

**In place.** Nothing should travel. The game moves the body in code through
`move_towards`; a clip that translates the character walks it out of
PixelOver's fixed camera partway through the cell.

## Export

Eight directions per clip, 224x224 cells, feet at y=192:

    assets/sprites/monsters/<name>/sprites/<Clip>/<Name>_<Clip>_dir<N>.png

dir1=SE dir2=E dir3=NE dir4=N dir5=NW dir6=W dir7=SW dir8=S

Then `python3 tools/build_enemy_scene.py <name>`. It measures each clip's frame
count rather than assuming, so clip lengths do not have to match anything.

Heights come from the builder's own table — gashadokuro 2.6x, oni 1.4x, the two
lords 1.15x, kamaitachi 0.7x — so do not bake relative scale into the models.

## Why Mixamo is not in this pipeline

**Upload never worked.** FBX uploads fail on this setup regardless of scale,
orientation or stripped skeletons. OBJ zip uploads succeed and reach the rigger,
but the rig itself then fails on thin-limbed characters.

**Retargeting Mixamo clips onto Meshy rigs does not work either**, even though
both use `mixamorig:` bone names. Copying an action between skeletons is only
valid when they share a rest pose, and these do not — measured on a tengu:
LeftUpLeg 172 degrees apart, LeftFoot 136, Spine 90. Arms happen to sit within
14, which is why the upper body looked plausible while the legs were garbage and
the fault survived several reviews.

So: rig in Meshy, animate in Meshy. See
`KatanaKitsuneWorkshop/meshy/Archived/bad_retargets/WHY.md`.
