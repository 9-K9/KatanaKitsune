# PixelOver export chart — every clip, 8 frames each

Every animation exports at **8 frames**, whatever its length, so the strips match
Katana Kitsune's. PixelOver has no frame-count field; it samples at a rate:

    Speed -> Frequency = 8 / length_in_seconds

Canvas **224 x 224**, Pixel/Meter **91**, feet **y = 192**, 8 directions
(dir1=SE .. dir8=S), sprite sheet on.

A correct export computes **64 frames** per clip — 8 frames x 8 directions. If the
progress dialog shows hundreds or thousands, Frequency is still at 30 and the clip
is rendering every source frame.

Clips with a **folder** go into the game. The rest are listed so the rate is to
hand if you want them later. `Armature|clip0|baselayer` is the bind pose — skip it.

## Jorogumo

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | — | 1.08 | **7.38** |
| Alert | Alert | 4.04 | **1.98** |
| Block10 | Block | 0.62 | **12.80** |
| Bubble_Dance | Taunt | 8.12 | **0.98** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Idle_7 | Idle | 8.83 | **0.91** |
| Quick_Step_and_Spin_Dodge | — | 1.25 | **6.40** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| mage_soell_cast | Attack | 2.33 | **3.43** |
| mage_soell_cast_3 | Attack2 | 3.38 | **2.37** |

## Kappa

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | Walk | 1.08 | **7.38** |
| Agree_Gesture | — | 13.04 | **0.61** |
| Alert | Alert | 4.04 | **1.98** |
| Angry_To_Tantrum_Sit | Taunt | 8.54 | **0.94** |
| Arise | — | 1.88 | **4.27** |
| Backflip | Attack2 | 2.21 | **3.62** |
| Block1 | Block | 3.50 | **2.29** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Idle_02 | — | 2.38 | **3.37** |
| Idle_03 | Idle | 5.38 | **1.49** |
| air_squat | Attack | 1.96 | **4.09** |

## KarasuShinobi

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | Walk | 1.08 | **7.38** |
| 360_Power_Spin_Jump | Taunt | 3.12 | **2.56** |
| Alert | Alert | 4.04 | **1.98** |
| Backflip | — | 2.21 | **3.62** |
| Backflip_and_Hooks | Attack2 | 5.88 | **1.36** |
| Backflip_and_Rise | — | 2.75 | **2.91** |
| Block1 | Block | 3.50 | **2.29** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction_1 | Hurt | 1.29 | **6.19** |
| Idle_11 | Idle | 1.96 | **4.09** |
| Sweeping_Kick | Attack | 2.38 | **3.37** |

## Kasha

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | — | 1.08 | **7.38** |
| Alert | Alert | 4.04 | **1.98** |
| Backflip_Jump | — | 4.17 | **1.92** |
| Block1 | Block | 3.50 | **2.29** |
| Breakdance_1990 | Taunt | 0.54 | **14.77** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Idle_7 | Idle | 8.83 | **0.91** |
| Lunge_Spin_Kick | Attack | 1.71 | **4.68** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Step_in_High_Kick | Attack2 | 1.33 | **6.00** |

## Ninja

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | — | 1.08 | **7.38** |
| Alert | Alert | 4.04 | **1.98** |
| Angry_Stomp | Taunt | 8.04 | **0.99** |
| Backflip | — | 2.21 | **3.62** |
| Backflip_and_Hooks | — | 5.88 | **1.36** |
| Backflip_and_Rise | — | 2.75 | **2.91** |
| Block1 | Block | 3.50 | **2.29** |
| Dead | Death | 3.00 | **2.67** |
| Flying_Fist_Kick | Attack2 | 4.71 | **1.70** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Idle_6 | Idle | 7.46 | **1.07** |
| Lunge_Roundhouse_Kick | Attack | 3.04 | **2.63** |
| Quick_Walk | Walk | 3.04 | **2.63** |
| Rising_Flying_Kick | — | 1.54 | **5.19** |
| Step_in_High_Kick | — | 1.33 | **6.00** |
| mage_soell_cast_3 | — | 3.38 | **2.37** |

## Oni

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | Walk | 1.08 | **7.38** |
| Alert | Alert | 4.04 | **1.98** |
| Angry_Ground_Stomp | Taunt | 1.46 | **5.49** |
| Axe_Spin_Attack | Attack2 | 2.54 | **3.15** |
| Backflip | — | 2.21 | **3.62** |
| Block2 | Block | 1.67 | **4.80** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction_1 | Hurt | 1.29 | **6.19** |
| Idle_02 | — | 2.38 | **3.37** |
| Idle_10 | Idle | 3.71 | **2.16** |
| Punch_Combo | Attack | 2.50 | **3.20** |
| Punch_Combo_1 | — | 2.29 | **3.49** |

## Tengu

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | Walk | 1.08 | **7.38** |
| 360_Power_Spin_Jump | Taunt | 3.12 | **2.56** |
| Alert | Alert | 4.04 | **1.98** |
| Backflip | Block | 2.21 | **3.62** |
| Backflip_and_Hooks | — | 5.88 | **1.36** |
| Backflip_and_Rise | — | 2.75 | **2.91** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Idle_3 | Idle | 10.00 | **0.80** |
| Rising_Flying_Kick | Attack2 | 1.54 | **5.19** |
| Roundhouse_Kick | Attack | 2.75 | **2.91** |
| Spartan_Kick | — | 1.50 | **5.33** |

## Yokai_Lord

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.71 | **11.29** |
| Walking | Walk | 1.08 | **7.38** |
| Alert | Alert | 4.04 | **1.98** |
| Block2 | Block | 1.67 | **4.80** |
| Charged_Spell_Cast | Attack | 2.71 | **2.95** |
| Charged_Spell_Cast_1 | Taunt | 4.33 | **1.85** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.71 | **4.68** |
| Hit_Reaction_1 | — | 1.29 | **6.19** |
| Idle_02 | — | 2.38 | **3.37** |
| Idle_10 | Idle | 3.71 | **2.16** |
| mage_soell_cast_2 | Attack2 | 3.04 | **2.63** |

## Yuki_Onna

| clip | folder | sec | FPS |
|---|---|---|---|
| Running | Run | 0.67 | **12.00** |
| Walking | — | 1.04 | **7.68** |
| Alert | Alert | 4.00 | **2.00** |
| Block2 | Block | 1.62 | **4.92** |
| Bubble_Dance | Taunt | 8.04 | **0.99** |
| Dead | Death | 3.00 | **2.67** |
| Hit_Reaction | Hurt | 1.67 | **4.80** |
| Idle_7 | Idle | 8.75 | **0.91** |
| Quick_Walk | Walk | 3.00 | **2.67** |
| Step_in_High_Kick | Attack | 1.33 | **6.00** |
| Angry_Stomp | — | 8.00 | **1.00** |
| Backflip_Jump | Attack2 | 4.12 | **1.94** |

