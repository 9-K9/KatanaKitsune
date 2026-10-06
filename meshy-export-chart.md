# PixelOver export chart

Set `Speed -> Frequency` per clip to the FPS below. That samples the clip to
exactly eight frames without altering it — the Rescale dialog also works but
rewrites the animation itself.

    FPS = 8 / length_in_seconds

Canvas **224 x 224**, Pixel/Meter **91**, feet at **y = 192**, eight directions
(dir1=SE through dir8=S). Export as a sprite sheet so each clip is one strip.

Folder names are what `tools/build_enemy_scene.py` matches on, not the Meshy
clip name — `Idle_7` goes into a folder called `Idle`.

Durations are read from the GLB accessors, so they are exact rather than the
rounded values the UI shows.

## Jorogumo

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_7 | Idle | 8.83 | **0.91** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Running | Run | 0.71 | **11.29** |
| mage_soell_cast | Attack | 2.33 | **3.43** |
| mage_soell_cast_3 | Attack2 | 3.38 | **2.37** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Block10 | Block | 0.62 | **12.80** |
| Alert | Alert | 4.04 | **1.98** |

Block10 is only 0.62s — the shortest clip in the set. If eight frames read as a twitch, `Quick_Step_and_Spin_Dodge` (1.25s, 6.40 FPS) is the alternative, and a spider dodging suits her anyway.

## Kappa

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_03 | Idle | 5.38 | **1.49** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| air_squat | Attack | 1.96 | **4.09** |
| Backflip | Attack2 | 2.21 | **3.62** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Block1 | Block | 3.50 | **2.29** |
| Alert | Alert | 4.04 | **1.98** |

`air_squat` is the nearest thing to a lunge. Kappa wrestle in the folklore, so a grapple would suit better if Meshy has one.

## KarasuShinobi

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_11 | Idle | 1.96 | **4.09** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Sweeping_Kick | Attack | 2.38 | **3.37** |
| Backflip_and_Hooks | Attack2 | 5.88 | **1.36** |
| Hit_Reaction_1 | Hurt | 1.29 | **6.19** |
| Dead | Death | 3.00 | **2.67** |
| Block1 | Block | 3.50 | **2.29** |
| Alert | Alert | 4.04 | **1.98** |

## Kasha

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_7 | Idle | 8.83 | **0.91** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Running | Run | 0.71 | **11.29** |
| Lunge_Spin_Kick | Attack | 1.71 | **4.68** |
| Step_in_High_Kick | Attack2 | 1.33 | **6.00** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Block1 | Block | 3.50 | **2.29** |
| Alert | Alert | 4.04 | **1.98** |

## Ninja

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_6 | Idle | 7.46 | **1.07** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Running | Run | 0.71 | **11.29** |
| Lunge_Roundhouse_Kick | Attack | 3.04 | **2.63** |
| Flying_Fist_Kick | Attack2 | 4.71 | **1.70** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Block1 | Block | 3.50 | **2.29** |
| Alert | Alert | 4.04 | **1.98** |

Eighteen clips, the richest set. `Flying_Fist_Kick` and `Lunge_Roundhouse_Kick` are both strong attacks; swap if the other reads better.

## Oni

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_10 | Idle | 3.71 | **2.16** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Punch_Combo | Attack | 2.50 | **3.20** |
| Axe_Spin_Attack | Attack2 | 2.54 | **3.15** |
| Hit_Reaction_1 | Hurt | 1.29 | **6.19** |
| Dead | Death | 3.00 | **2.67** |
| Block2 | Block | 1.67 | **4.80** |
| Alert | Alert | 4.04 | **1.98** |

## Tengu

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_3 | Idle | 10.00 | **0.80** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Roundhouse_Kick | Attack | 2.75 | **2.91** |
| Rising_Flying_Kick | Attack2 | 1.54 | **5.19** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Backflip | Block | 2.21 | **3.62** |
| Alert | Alert | 4.04 | **1.98** |

No Block clip of its own, so `Backflip` stands in — which fits: a winged mountain spirit evades rather than guards, and `enemyBlock` gives ground while the clip plays.

## Yokai_Lord

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_10 | Idle | 3.71 | **2.16** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Charged_Spell_Cast | Attack | 2.71 | **2.95** |
| mage_soell_cast_2 | Attack2 | 3.04 | **2.63** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Block2 | Block | 1.67 | **4.80** |
| Alert | Alert | 4.04 | **1.98** |

## Yuki_Onna

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_7 | Idle | 8.75 | **0.91** |
| Quick_Walk | Walk | 3.00 | **2.67** |
| Running | Run | 0.67 | **12.00** |
| Step_in_High_Kick | Attack | 1.33 | **6.00** |
| Backflip_Jump | Attack2 | 4.12 | **1.94** |
| Hit_Reaction | Hurt | 1.67 | **4.80** |
| Dead | Death | 3.00 | **2.67** |
| Block2 | Block | 1.62 | **4.92** |
| Alert | Alert | 4.00 | **2.00** |

## Notes

Every model ships `Armature|clip0|baselayer` at 0.04s. That is the bind pose,
not an animation — do not export it.

`Walking` (1.08s) and `Quick_Walk` (3.04s) are different clips with very
different rates. Jorogumo, Kasha, Ninja and Yuki_Onna use Quick_Walk; the rest
use Walking.

`Running` is 0.71s on every model and needs **11.29 FPS** — far higher than
anything else, because it is the shortest clip.

