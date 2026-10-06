# PixelOver export chart

Set `Speed -> Frequency` per clip to the FPS below. That samples the clip down to
exactly 8 frames without altering it — the Rescale dialog also works but rewrites
the animation itself.

    FPS = 8 / length_in_seconds

Canvas **224 x 224**, Pixel/Meter **91**, feet at **y = 192**, 8 directions
(dir1=SE through dir8=S). Export as a sprite sheet so each clip is one strip.

Folder names are what `tools/build_enemy_scene.py` matches on — not the Meshy
clip name. A clip called `Idle_7` goes into a folder called `Idle`.

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
| Quick_Step_and_Spin_Dodge | Block | 1.25 | **6.40** |
| Alert | Alert | 4.04 | **1.98** |

A spider dodging suits her better than a guard, and `enemyBlock` backs the
monster away while the clip plays, so the dodge reads correctly in that slot.

## Kappa

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_03 | Idle | 5.38 | **1.49** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| air_squat | Attack | 1.96 | **4.09** |
| Backflip | Attack2 | 2.21 | **3.62** |
| Arise | Hurt | 1.88 | **4.27** |
| Dead | Death | 3.00 | **2.67** |
| Block1 | Block | 3.50 | **2.29** |
| Alert | Alert | 4.04 | **1.98** |

**Hurt is a stand-in.** `Arise` is a getting-up animation, not a hit reaction.
Kappa wrestle in the folklore, so a grapple or shove would suit better.

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

## NikitaNinja

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_6 | Idle | 7.46 | **1.07** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Running | Run | 0.71 | **11.29** |
| Lunge_Roundhouse_Kick | Attack | 3.04 | **2.63** |
| Rising_Flying_Kick | Attack2 | 1.54 | **5.19** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Dead | Death | 3.00 | **2.67** |
| Backflip | Block | 2.21 | **3.62** |
| Angry_Stomp | Alert | 8.04 | **0.99** |

No dedicated Block or Alert in this set, so a backflip covers the evade and the
stomp the telegraph. Both are stand-ins.

## Oni

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_10 | Idle | 3.71 | **2.16** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Punch_Combo | Attack | 2.50 | **3.20** |
| Axe_Spin_Attack | Attack2 | 2.54 | **3.15** |
| Hit_Reaction_1 | Hurt | 1.29 | **6.19** |
| Angry_Ground_Stomp | Death | 1.46 | **5.49** |
| Block2 | Block | 1.67 | **4.80** |
| Alert | Alert | 4.04 | **1.98** |

**Oni has no Dead clip.** The ground stomp is standing in and will read wrong —
he will stamp instead of falling. Worth getting a death from Meshy before
exporting him.

## Tengu

| clip | folder | sec | FPS |
|---|---|---|---|
| Idle_3 | Idle | 10.00 | **0.80** |
| Walking | Walk | 1.08 | **7.38** |
| Running | Run | 0.71 | **11.29** |
| Roundhouse_Kick | Attack | 2.75 | **2.91** |
| Rising_Flying_Kick | Attack2 | 1.54 | **5.19** |
| Backflip_and_Rise | Hurt | 2.75 | **2.91** |
| Dead | Death | 3.00 | **2.67** |
| Backflip | Block | 2.21 | **3.62** |
| Alert | Alert | 4.04 | **1.98** |

**Hurt is a stand-in** — `Backflip_and_Rise` is a recovery, not a flinch. The
kicks suit him: tengu are martial arts masters and need no weapon.

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

Two spell casts, which suits a lord who fights at range rather than with fists.

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

## Gaps worth filling before export

- **Oni has no death** — the ground stomp stands in and will read as a stamp.
- **Kappa's hurt is a getting-up clip**, not a flinch.
- **Tengu's hurt is a recovery**, not a flinch.
- **NikitaNinja has neither a block nor an alert** of its own.

Every model also carries `Armature|clip0|baselayer` at 0.04s. That is the bind
pose, not an animation. Do not export it.
