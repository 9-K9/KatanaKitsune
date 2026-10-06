#!/usr/bin/env python3
"""Build an enemy scene from a finished sprite folder.

Every monster shares one structure — the same SpriteFrames layout, state
machine, collision polygon and health bar — because behaviour is the tier
table's job now. So a new enemy is the undeadRonin scene with its art swapped
and its own base numbers, and that is entirely mechanical.

Usage:  build_enemy_scene.py <folder> [tier]
        build_enemy_scene.py --all      # every complete set without a scene
"""
import os
import re
import sys

ROOT = "/home/emanzi/GODOT/Projects/KatanaKitsune"
ART = os.path.join(ROOT, "assets/sprites/monsters")
SCENES = os.path.join(ROOT, "scenes/monsters")
TEMPLATE = os.path.join(SCENES, "undeadRonin.tscn")

## The template's clips remain first so legacy five-clip scenes retain their
## byte-for-byte layout. Additional folders are appended in this order.
BASE_CLIPS = ("Idle", "Walk", "Attack", "Hurt", "Death")
EXTRA_CLIPS = ("Block", "Draw", "Charge")
LEGACY_COUNTS = {"Idle": 6, "Walk": 8, "Attack": 8, "Hurt": 4, "Death": 8}
## Playback rate per clip. These were one number for everything when clips ran
## four to six frames; at eight a walk at 10fps cycles in under a second and
## reads as a blur rather than a stride. A walk wants to match the legs, an idle
## wants to breathe, and a hit wants to snap.
SPEEDS = {
    "Idle": 6.0,
    "Walk": 8.0,
    "Run": 12.0,
    "Alert": 8.0,
    "Taunt": 8.0,
}

## The sprite cell. 768, well beyond Katana Kitsune's 480, because the monsters
## are taller than she is and their attacks and dodges leave the frame — a
## backflip or a spin clips at anything smaller. Raising it costs texture memory
## and nothing else: the character still draws at about 195px, it just has room
## to move.
FRAME = 768
## dirN in a PixelOver export, mapped to the game's SCREEN-SPACE facings — see
## IsoFacing.VECTORS, where south is straight down the screen and east straight
## right. Two of these are certain from looking at the sprites: dir4 is the back
## view and dir8 the front, so dir4 is north and dir8 south. The rest follow
## from which way the circle turns, and that is the part worth checking by
## walking a monster around rather than reasoning about, because it produces no
## error either way — the monster simply travels one way while facing another.
DIRECTIONS = ("southWest", "west", "northWest", "north",
              "northEast", "east", "southEast", "south")

## How tall each one stands against a human, which the art cannot carry on its
## own: a generator normalises every model it makes, so a giant skeleton and a
## weasel come back the same size and the bestiary reads flat.
##
## Visual only. The collision polygon is left alone deliberately — a gashadokuro
## with a body three times the size would wedge itself in the corridors it is
## supposed to come down.
HEIGHT = {
    "gashadokuro": 2.6,   # towers over everything; the point of it
    "oni":         1.40,
    "nurarihyon":  1.15,  # bosses read as bigger than the duellists
    "hannya":      1.15,
    "kamaitachi":  0.70,  # small and fast, and should look breakable
}

## Where the feet sit inside a frame, measured from the sprite's centre.
## 452 in a 768 cell — where the feet land, 68 below the 384 centre, measured as
## the median across every frame of a finished export rather than off one clip.
## A death or a dodge can put the lowest pixel anywhere, so a single sample
## would just be whichever clip sorted first. That number is the art's, not ours: it was chosen so a jump or a
## death still has headroom and nothing gets its head cut off, and it has been
## tested. The code bends to it. Scaling the sprite scales this gap too, so the
## offset has to move with it or a scaled monster floats.
FEET_IN_FRAME = 452.0
FEET_BELOW_CENTRE = FEET_IN_FRAME - FRAME / 2.0
## The template's own sprite offset, which the formula has to reproduce at 1.0.
BASE_SPRITE_Y = -72.0
## The head, measured the same way. These were taken in a 224 frame, where
## content ran y=37 to y=192, putting the head 75px above the sprite's centre.
## They are offsets from the centre, so they do not change with the cell size.
HEAD_ABOVE_CENTRE = 75.0
## Clear air between the head and the bar, held constant at every size — it is
## a readability margin, not part of the monster, so it should not grow.
BAR_GAP = 47.0
BAR_HEIGHT = 6.0

## The nine, with their rung and the numbers that suit them. Tier drives
## behaviour; these are only what the monster is before the wave scaling.
##
## Keys are the asset folder name, lowercase-first, which is also what the
## PixelOver export is named after.
ROSTER = {
    "kasha":         (1, 120.0, 40.0, 12.0),  # corpse-stealing cat demon, a scavenger
    "kappa":         (2, 140.0, 50.0, 15.0),  # river imp; wrestles, drags you under
    "karasuShinobi": (2,  90.0, 66.0, 14.0),  # crow ninja, fast and frail
    "jorogumo":      (3, 160.0, 48.0, 20.0),  # spider woman, ambusher
    "oni":           (3, 240.0, 44.0, 24.0),  # horned ogre, the wall of the set
    "tengu":         (4, 170.0, 54.0, 19.0),  # mountain spirit, master of arms
    "yuki_Onna":     (5, 210.0, 52.0, 25.0),  # snow woman, cold and inevitable
    "ninja":         (5, 190.0, 60.0, 26.0),  # the human among them, and the quickest
    "yokai_Lord":    (6, 420.0, 58.0, 32.0),  # the boss
}

## Where the feet sit inside a frame, measured from the sprite's centre.
## 452 in a 768 cell — where the feet land, 68 below the 384 centre, measured as
## the median across every frame of a finished export rather than off one clip.
## A death or a dodge can put the lowest pixel anywhere, so a single sample
## would just be whichever clip sorted first. That number is the art's, not ours: it was chosen so a jump or a
## death still has headroom and nothing gets its head cut off, and it has been
## tested. The code bends to it. Scaling the sprite scales this gap too, so the
## offset has to move with it or a scaled monster floats.
FEET_IN_FRAME = 452.0
FEET_BELOW_CENTRE = FEET_IN_FRAME - FRAME / 2.0
## The template's own sprite offset, which the formula has to reproduce at 1.0.
BASE_SPRITE_Y = -72.0
## The head, measured the same way. These were taken in a 224 frame, where
## content ran y=37 to y=192, putting the head 75px above the sprite's centre.
## They are offsets from the centre, so they do not change with the cell size.
HEAD_ABOVE_CENTRE = 75.0
## Clear air between the head and the bar, held constant at every size — it is
## a readability margin, not part of the monster, so it should not grow.
BAR_GAP = 47.0
BAR_HEIGHT = 6.0



def sheets_for(folder):
    """Return detected clip frame counts plus incomplete/corrupt sheet lists."""
    missing, wrong = [], []
    sprite_root = os.path.join(ART, folder, "sprites")
    if not os.path.isdir(sprite_root):
        return {}, ["sprites folder"], wrong
    found = set(name for name in os.listdir(sprite_root)
                if os.path.isdir(os.path.join(sprite_root, name)))
    clips = [clip for clip in BASE_CLIPS + EXTRA_CLIPS if clip in found]
    clips += sorted(found.difference(clips))
    for clip in BASE_CLIPS:
        if clip not in found:
            missing.append("%s folder" % clip)

    counts = {}
    for clip in clips:
        direction_counts = []
        for d in range(1, 9):
            name = "%s_%s_dir%d.png" % (folder[0].upper() + folder[1:], clip, d)
            path = os.path.join(ART, folder, "sprites", clip, name)
            if not os.path.exists(path):
                missing.append(os.path.join(clip, name))
                continue
            ## Size is checked, not just presence: a half-written PNG from a
            ## generator still in flight would otherwise pass and produce a
            ## scene full of broken frames.
            try:
                from PIL import Image
                w, h = Image.open(path).size
                if h != FRAME or w % FRAME:
                    wrong.append("%s is %dx%d, want Nx%d by %d"
                                 % (name, w, h, FRAME, FRAME))
                else:
                    direction_counts.append(w // FRAME)
            except Exception as exc:
                wrong.append("%s unreadable (%s)" % (name, exc))
        if direction_counts:
            if len(set(direction_counts)) != 1:
                wrong.append("%s directions have differing frame counts: %s"
                             % (clip, direction_counts))
            elif len(direction_counts) == 8:
                counts[clip] = direction_counts[0]
    return counts, missing, wrong


def _art_resources(folder, title, clips):
    """Build texture, atlas and SpriteFrames resources for measured sheets."""
    ext, atlas, animations = [], [], []
    for clip, frames in clips.items():
        key = clip.lower()
        for direction in range(1, 9):
            ext.append('[ext_resource type="Texture2D" path="res://assets/sprites/monsters/%s/sprites/%s/%s_%s_dir%d.png" id="t_%s_%d"]'
                       % (folder, clip, title, clip, direction, key, direction))
            for frame in range(frames):
                atlas.append('[sub_resource type="AtlasTexture" id="Atlas_%s_%d_%d"]\natlas = ExtResource("t_%s_%d")\nregion = Rect2(%d, 0, %d, %d)'
                             % (key, direction, frame, key, direction, frame * FRAME, FRAME, FRAME))
            frame_rows = []
            for frame in range(frames):
                frame_rows.append('{\n"duration": 1.0,\n"texture": SubResource("Atlas_%s_%d_%d")\n}'
                                  % (key, direction, frame))
            animations.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": %.1f\n}'
                              % (", ".join(frame_rows),
                                 "true" if clip in ("Idle", "Walk") else "false",
                                 key, DIRECTIONS[direction - 1],
                                 SPEEDS.get(clip, 10.0)))
    sprite_frames = '[sub_resource type="SpriteFrames" id="SpriteFrames_mummy"]\nanimations = [%s]' % ", ".join(animations)
    return "\n".join(ext), "\n\n".join(atlas), sprite_frames


## The state each extra clip unlocks. A monster gets the node when it has the
## art to show it, which is what EnemyStateClass._drop_skills_without_states
## looks for when it decides whether a rolled rung can be performed.
EXTRA_STATES = {
    "Block":  ("block", "enemyBlock.gd", "st_block"),
    "Draw":   ("draw", "enemyDraw.gd", "st_draw"),
    "Charge": ("charge", "enemyCharge.gd", "st_charge"),
}


def _expand_template(out, folder, title, clips):
    """Replace the fixed art resource block and add whatever states the art supports.

    Driven by which clips exist rather than by tier, because tier is not a
    property of the art: the generator picks a scene uniformly and rolls a rung
    for it afterwards, so any monster may be asked to guard. A warden with a
    Block folder can raise its guard whatever rung it was handed, and one
    without is demoted at spawn rather than erroring.
    """
    ext, atlas, sprite_frames = _art_resources(folder, title, clips)
    start = out.index('[ext_resource type="Texture2D"')
    end = out.index('[sub_resource type="StyleBoxFlat"')
    out = out[:start] + ext + "\n\n" + atlas + "\n\n" + sprite_frames + "\n\n" + out[end:]

    added = [EXTRA_STATES[c] for c in EXTRA_CLIPS if c in clips]
    if added:
        resources = "".join(
            '[ext_resource type="Script" path="res://scripts/stateMachine/enemyState/%s" id="%s"]\n'
            % (script, rid) for _, script, rid in added)
        marker = '[ext_resource type="Script" path="res://scripts/stateMachine/enemyState/enemyHurt.gd"'
        out = out.replace(marker, resources + marker, 1)
        nodes = "".join(
            '[node name="%s" type="Node" parent="FiniteStateMachine"]\nscript = ExtResource("%s")\n\n'
            % (node, rid) for node, _, rid in added)
        out = out.replace('[node name="hurt" type="Node" parent="FiniteStateMachine"]',
                          nodes + '[node name="hurt" type="Node" parent="FiniteStateMachine"]', 1)
    old_atlas = sum(LEGACY_COUNTS.values()) * 8
    delta = (len(clips) * 8 - len(BASE_CLIPS) * 8
             + sum(clips.values()) * 8 - old_atlas
             + len(added))
    out = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=%d' % (int(m.group(1)) + delta), out, count=1)
    return out


def _apply_height(out, folder):
    """Scale the sprite, keeping the feet on the floor.

    The sprite draws centred, so its feet sit FEET_BELOW_CENTRE under its own
    position. Scaling by k scales that gap as well, and a monster scaled about
    its middle ends up hovering by the difference. Moving the offset to
    8 - 80k cancels it: at k=1 that is the template's own -72, and at any other
    k the feet land in the same place.
    """
    k = HEIGHT.get(folder)
    if k is None:
        return out
    y = (BASE_SPRITE_Y + FEET_BELOW_CENTRE) - FEET_BELOW_CENTRE * k
    anchor = '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\nposition = Vector2(0, -72)'
    assert anchor in out, "sprite node not where %s expected it" % folder
    out = out.replace(
        anchor,
        '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\n'
        'position = Vector2(0, %.1f)\nscale = Vector2(%.2f, %.2f)' % (y, k, k),
        1)

    ## The bar is a sibling of the sprite, so it does not inherit the scale and
    ## would otherwise stay at a man's head height — across a giant's waist, and
    ## floating well above a weasel. It rides the head instead: the head sits
    ## HEAD_ABOVE_CENTRE above the sprite's centre and that distance scales,
    ## so the bar follows it and keeps a constant gap above.
    top = y - HEAD_ABOVE_CENTRE * k - BAR_GAP
    bar = '[node name="HealthBar" type="ProgressBar" parent="."]\noffset_left = -26.0\noffset_top = -194.0'
    assert bar in out, "health bar not where %s expected it" % folder
    return out.replace(
        bar,
        '[node name="HealthBar" type="ProgressBar" parent="."]\n'
        'offset_left = -26.0\noffset_top = %.1f' % top,
        1).replace("offset_bottom = -188.0", "offset_bottom = %.1f" % (top + BAR_HEIGHT), 1)


def build(folder, tier=None):
    clips, missing, wrong = sheets_for(folder)
    if missing or wrong:
        return False, "incomplete: %d missing, %d wrong" % (len(missing), len(wrong))

    stats = ROSTER.get(folder)
    if stats is None:
        return False, "not in the roster table"
    tier = tier if tier is not None else stats[0]
    _, health, speed, damage = stats
    ## Tiers 5 and 6 are duellists by definition, so a scene built for one has
    ## to carry the whole kit. Lower rungs take whatever extras they have — a
    ## Block folder alone is enough to make a warden actually guard.
    if tier >= 5:
        absent = [clip for clip in EXTRA_CLIPS if clip not in clips]
        if absent:
            return False, "incomplete: missing duellist clips %s" % ", ".join(absent)

    title = folder[0].upper() + folder[1:]
    out = open(TEMPLATE).read()
    out = out.replace("res://assets/sprites/monsters/undeadRonin/",
                      "res://assets/sprites/monsters/%s/" % folder)
    out = out.replace("UndeadRonin_", "%s_" % title)
    out = out.replace('[node name="UndeadRonin"', '[node name="%s"' % title)
    ## A fresh identity, or two scenes claim the same uid.
    out = re.sub(r'\suid="uid://[a-z0-9]+"', "", out, count=1)
    out = out.replace("max_health = 180.0\nmove_speed = 38.0",
                      "tier = %d\nmax_health = %.1f\nmove_speed = %.1f\nattack_damage = %.1f"
                      % (tier, health, speed, damage))

    ## Preserve the historical path for template-shaped sets. This is what
    ## keeps a gashadokuro rebuild byte-identical to earlier builds.
    if clips != LEGACY_COUNTS:
        out = _expand_template(out, folder, title, clips)

    out = _apply_height(out, folder)

    path = os.path.join(SCENES, "%s.tscn" % folder)
    open(path, "w").write(out)
    return True, "tier %d, %d hp, speed %d" % (tier, health, speed)


def wire_pool():
    """Puts every built monster scene into the generator's spawn pool.

    Idempotent, so it can run on every pass without duplicating entries. A
    monster with a scene but no pool entry never spawns, which is a silent
    failure — the art and the scene both look finished.
    """
    maze = os.path.join(ROOT, "scenes/world/mazeDemo.tscn")
    text = open(maze).read()
    added = []
    for folder in ROSTER:
        scene = "res://scenes/monsters/%s.tscn" % folder
        if not os.path.exists(os.path.join(ROOT, scene[6:])):
            continue
        if scene in text:
            continue
        rid = "90_%s" % folder
        anchor = '[ext_resource type="PackedScene" path="res://scenes/props/spikeTrap.tscn"'
        if anchor not in text:
            anchor = text[text.index("[ext_resource"):].split("\n")[0]
        line = '[ext_resource type="PackedScene" path="%s" id="%s"]\n' % (scene, rid)
        text = text.replace(anchor, line + anchor, 1)
        text = re.sub(r'(enemy_scenes = Array\[PackedScene\]\(\[)([^\]]*)(\]\))',
                      lambda m: m.group(1) + m.group(2) + ', ExtResource("%s")' % rid + m.group(3),
                      text, count=1)
        added.append(folder)
    if added:
        open(maze, "w").write(text)
    return added


def main():
    args = sys.argv[1:]
    if args and args[0] == "--all":
        built = []
        for folder in ROSTER:
            if os.path.exists(os.path.join(SCENES, "%s.tscn" % folder)):
                continue
            if not os.path.isdir(os.path.join(ART, folder)):
                continue
            ok, why = build(folder)
            print("%-14s %s" % (folder, why if ok else "skipped — " + why))
            if ok:
                built.append(folder)
        wired = wire_pool()
        print("built %d, wired %d: %s" % (len(built), len(wired), ", ".join(wired) or "-"))
        return
    if not args:
        print(__doc__)
        return
    ok, why = build(args[0], int(args[1]) if len(args) > 1 else None)
    print("%s: %s" % (args[0], why))


if __name__ == "__main__":
    main()
