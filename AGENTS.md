# Working on this project

## There is one git repository, and this is it

KatanaKitsune used to be two repos. It is now one.

**KatanaKitsuneWorkshop no longer exists as a git repository.** Its GitHub repo
is archived — frozen and read-only. The files live on as plain files, with no
`.git` directory, at:

```
/mnt/K-DRIVE/Dropbox/Dropbox/EMANZI/KatanaKitsune/KatanaKitsuneWorkshop/
```

They sync through Dropbox and are managed by hand. Do not clone, pull, push,
commit, or offer to "restore" the workshop. There is nothing to pull from and
nothing to push to. If a task needs a workshop file, read or copy it from the
Dropbox path above.

Changed 2026-10-08.

## Why the split

The workshop held the 3D pipeline: Meshy rigs, Blender retargets, VRoid sources,
PixelOver projects. Those are large, binary, and produce the game's sprites
rather than being part of the game. Git was carrying their weight on every
clone and giving nothing back, since nothing in the workshop is diffable and
nothing in it ships.

So the heavy half moved to Dropbox and the shipping half stayed in git. This
repo is meant to stay light enough to clone quickly and reason about cheaply.

## Heavy files are deliberately absent

Working copy: `/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-/`

**There is no `sound/` directory, and that is correct.** It was roughly 1 GB of
NOX_SOUND WAV against about 280 MB for every sprite in the game, and not one
scene or script referenced it. It was stripped from history on 2026-10-08
(1.6 GB of history down to 454 MB) and is ignored going forward.

Audio is deferred to the very end of development. Until then the game has no
audio nodes and no audio code, by design. Do not treat the absence as a bug, and
do not add audio back without being asked.

The archived originals, preserved byte-for-byte:

```
/mnt/K-DRIVE/Dropbox/Dropbox/EMANZI/KatanaKitsune/_HeavyBackups/
├── Isometric_sound/   the purged sound/ library
└── Workshop_LFS/      the binaries that were briefly tracked via Git LFS
```

**Git LFS has been dropped.** If a `.gitattributes` turns up with `filter=lfs`
rules, it is a leftover and should go.

The five Dialogic example WAVs under `addons/` stay. They are 117 KB, and
`vn_choice_layer.tscn` references two of them, so deleting them breaks the
addon on load.

## Enemies

Seventeen monsters have complete 8-direction sprite sets, in three tiers that
are **not** interchangeable:

| Tier | Clips | Monsters |
|------|-------|----------|
| 10 clips | Alert, Attack, Attack2, Block, Death, Hurt, Idle, Run, Taunt, Walk | jorogumo, kappa, karasuShinobi |
| 8 clips | Attack, Block, Charge, Death, Draw, Hurt, Idle, Walk | hannya, kitsuneBi, nurarihyon, yukiOnna |
| 5 clips | Attack, Death, Hurt, Idle, Walk | gashadokuro, jikininki, kamaitachi, mummyKitsune, nureOnna, oni, onryo, tengu, undeadRonin, yurei |

Only the 10-clip three are wired into `enemy_scenes` in
`scenes/world/mazeDemo.tscn`. The rest are declared as `ext_resource` there but
unused.

That narrowing is deliberate, not an oversight. The state machine has
`enemyAlert.gd` and `enemyBlock.gd`; the 5-clip tier has neither clip, and the
8-clip tier has no `Alert`. Check what a missing clip does before widening the
roster.

Two leftovers: `mummyKitsune` has sprites but no scene, and `abomination` is
three stray PNGs that are not a monster set.
