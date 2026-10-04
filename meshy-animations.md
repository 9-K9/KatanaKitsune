# Which animations each enemy needs

Tier drives behaviour; the art only has to be able to perform it. Class names
are from `scripts/system/EnemyTier.gd`.

## The twelve

| enemy | tier | class | hp / speed | clips |
|---|---|---|---|---|
| gashadokuro | 1 | SHAMBLER | 150 / 34 | 5 |
| jikininki | 1 | SHAMBLER | 110 / 42 | 5 |
| kamaitachi | 2 | RUNNER | 80 / 64 | 5 |
| nureOnna | 2 | RUNNER | 100 / 58 | 5 |
| oni | 3 | WARDEN | 220 / 44 | 5 (+Block) |
| tengu | 3 | WARDEN | 160 / 52 | 5 (+Block) |
| onryo | 4 | REVENANT | 180 / 30 | 5 |
| yurei | 4 | REVENANT | 160 / 28 | 5 |
| kitsuneBi | 5 | SPIRIT | 200 / 56 | **8** |
| yukiOnna | 5 | SPIRIT | 210 / 54 | **8** |
| nurarihyon | 6 | YOKAI LORD | 420 / 60 | **8** |
| hannya | 6 | YOKAI LORD | 400 / 64 | **8** |

What each class does:

- **SHAMBLER** — walks, attacks. Nothing else.
- **RUNNER** — chases at ~2x speed. First thing that punishes standing still.
- **WARDEN** — runs and raises a guard, so it has to be opened up.
- **REVENANT** — creeps, but walks through walls and never loses the scent.
- **SPIRIT** — fights the way the player does: draws, blocks, charges.
- **YOKAI LORD** — boss. Faster and stronger, and takes triple from a strike it
  never saw coming.

## The five everything needs

| clip | what it is | Meshy library search |
|---|---|---|
| **Idle** | standing, looping | "idle", "breathing idle", "fight stance" |
| **Walk** | looping, must return to its start pose | "walk", "zombie walk", "scary walk" |
| **Attack** | one swing, plays once | "punch", "slash", "sword attack", "claw" |
| **Hurt** | recoil from a hit, plays once | "hit reaction", "taking punch", "stagger" |
| **Death** | collapse, plays once, holds the last frame | "death", "dying", "falling back death" |

## The three more for tiers 5 and 6

| clip | what it is | Meshy library search |
|---|---|---|
| **Draw** | unsheathes once on first engagement | "draw sword", "unsheathe", "equip weapon" |
| **Block** | guard held up, holds its last frame | "block", "guard", "sword block idle" |
| **Charge** | winds up a heavy strike | "charge attack", "heavy attack windup" |

## Two things worth deciding before you start

**Walk and Idle loop. The other six play once.** A walk whose last frame does
not meet its first will visibly snap every stride — that is the single most
noticeable fault at this size, and it is worth checking in Meshy's preview
before exporting rather than after.

**Tier is rolled separately from the art.** The generator picks a scene from the
pool uniformly and then rolls a rung for it, so a gashadokuro can come up tier 6
and a hannya tier 1. Any monster missing the state for a skill is quietly
demoted a rung instead of erroring (`_drop_skills_without_states`).

That means there is a choice:

- **Five clips for the eight lower tiers** — matches what is built now. A
  shambler rolled into tier 5 simply fights as a lower rung.
- **Eight clips for all twelve** — three extra picks per character, and any art
  can then perform any rung the generator hands it. Oni and tengu are WARDENs
  and are *supposed* to guard, so they are already getting less than their class
  describes without Block.

Eight for all twelve is the better game if the extra picks are cheap, which they
are when you are choosing from a library rather than generating. If you would
rather not, do Block for oni and tengu at least — their class is built around a
guard they currently cannot raise.

## Export

Eight directions per clip, 224x224 cells, feet at y=192:

    assets/sprites/monsters/<name>/sprites/<Clip>/<Name>_<Clip>_dir<N>.png

dir1=SE dir2=E dir3=NE dir4=N dir5=NW dir6=W dir7=SW dir8=S

Then `python3 tools/build_enemy_scene.py <name>` rebuilds the scene against
whatever is in the folder. It measures the frame count of each clip rather than
assuming, so Meshy clip lengths do not need to match what is there now.

Heights are applied automatically from the builder's own table — gashadokuro
2.6x, oni 1.4x, the two lords 1.15x, kamaitachi 0.7x — so do not try to bake
relative scale into the models. Meshy normalises them anyway.
