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

## What a finished set looks like: five clips, eight directions each.
CLIPS = {"Idle": 6, "Walk": 8, "Attack": 8, "Hurt": 4, "Death": 8}
FRAME = 224

## The twelve, with their rung and the numbers that suit them. Tier drives
## behaviour; these are only what the monster is before the wave scaling.
ROSTER = {
    "gashadokuro": (1, 150.0, 34.0, 14.0),   # starved giant skeleton
    "jikininki":   (1, 110.0, 42.0, 11.0),   # corpse-eater
    "kamaitachi":  (2,  80.0, 64.0, 13.0),   # sickle weasel, quick and frail
    "nureOnna":    (2, 100.0, 58.0, 14.0),   # serpent woman
    "oni":         (3, 220.0, 44.0, 22.0),   # horned ogre with a club
    "tengu":       (3, 160.0, 52.0, 18.0),   # crow-beaked swordsman
    "onryo":       (4, 180.0, 30.0, 20.0),   # vengeful spirit
    "yurei":       (4, 160.0, 28.0, 18.0),   # drifting ghost
    "kitsuneBi":   (5, 200.0, 56.0, 24.0),   # fox-fire spirit
    "yukiOnna":    (5, 210.0, 54.0, 25.0),   # snow woman
    "nurarihyon":  (6, 420.0, 60.0, 30.0),   # yokai lord
    "hannya":      (6, 400.0, 64.0, 32.0),   # horned demon
}


def sheets_for(folder):
    """Every sheet the set should have, and whether it is there and sane."""
    missing, wrong = [], []
    for clip, frames in CLIPS.items():
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
                if h != FRAME or w != FRAME * frames:
                    wrong.append("%s is %dx%d, want %dx%d"
                                 % (name, w, h, FRAME * frames, FRAME))
            except Exception as exc:
                wrong.append("%s unreadable (%s)" % (name, exc))
    return missing, wrong


def build(folder, tier=None):
    missing, wrong = sheets_for(folder)
    if missing or wrong:
        return False, "incomplete: %d missing, %d wrong" % (len(missing), len(wrong))

    stats = ROSTER.get(folder)
    if stats is None:
        return False, "not in the roster table"
    tier = tier if tier is not None else stats[0]
    _, health, speed, damage = stats

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
