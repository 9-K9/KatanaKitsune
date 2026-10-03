# Meshy prompts — the twelve yokai

Replacing the PixelLab placeholders. These describe the silhouettes already in
the game, so a swap reads as the same bestiary rather than a different one.

## Append to every prompt

> stylised anime game character, A-pose, arms slightly down and away from the
> body, symmetrical, clean topology, full body including feet, neutral
> expression, single character on a plain background, no base, no pedestal

A-pose rather than T-pose: Mixamo rigs both but deforms shoulders better from
A-pose, and it is closer to Meshy's native output.

## What matters for this pipeline

Silhouette over detail. Everything ends up at 224px rendered to eight
directions, so a readable outline at thumbnail size beats surface texture that
will vanish. Keep props large and held away from the body — a katana held
against the leg disappears into it at this size.

Each needs five clips: Idle, Walk, Attack, Hurt, Death. Tiers 5 and 6 need
three more: Block, Draw, Charge.

Feet at y=192 in a 224px cell is what makes them stand on the floor rather than
hover. That is a render-time concern, not a modelling one, but it is the single
thing most likely to go wrong on export.

---

## Tier 1 — shamblers

**gashadokuro** — 150 hp, speed 34
> giant starved skeleton yokai, enormous bare skull with empty eye sockets,
> exposed ribcage, long thin bone limbs, hunched forward, tattered grey burial
> cloth hanging from the hips, pale bone

**jikininki** — 110 hp, speed 42
> emaciated corpse-eating ghoul, gaunt grey-green skin stretched over bone,
> sunken eyes, open mouth with long teeth, ragged brown monk's robe, bare feet,
> hunched and reaching forward

## Tier 2 — runners

**kamaitachi** — 80 hp, speed 64
> bipedal weasel yokai, orange and white fur, sharp narrow snout, wild white
> mane, large curved sickle blades instead of hands, dark blue hakama trousers,
> lean and crouched ready to spring

Keep it bipedal. A true quadruped breaks Mixamo and it already runs faster than
anything else in the game, so the stance should read as a sprinter.

**nureOnna** — 100 hp, speed 58
> serpent woman yokai, pale human upper body in a white and red shrine maiden
> kimono, long black hair, thick green serpent coils below the waist, coiled
> body raised, forward-leaning posture

Mixamo cannot rig the coil. Either model legs under the kimono and hide them,
or hand-animate.

## Tier 3 — guards

**oni** — 220 hp, speed 44
> hulking red-skinned ogre, two curved ivory horns, wild black hair, broad
> muscular build, dark iron shoulder armour and plated skirt, heavy iron club,
> bare feet, broad stance

**tengu** — 160 hp, speed 52
> crow-headed yokai swordsman, black feathered head with a long beak, large
> black feathered wings folded at the back, dark red and black robes, straight
> katana at the hip, slim upright build

Wings folded, not spread. Spread wings double the silhouette width and the
character ends up tiny once the frame is fitted to it.

## Tier 4 — revenants

**onryo** — 180 hp, speed 30
> vengeful female ghost, long black hair covering much of the face, pale white
> skin, loose white burial kimono, arms hanging forward with limp wrists, hem
> fading into a soft wisp near the floor

**yurei** — 160 hp, speed 28
> drifting female ghost, translucent pale figure, long straight black hair,
> plain white funeral robe, head tilted, arms crossed loosely, lower robe
> trailing away into mist

Both fade out at the bottom. Model the feet anyway and hide them under the hem
— Mixamo needs them, and the fade can be a texture or a shader later.

## Tier 5 — duellists

These fight the way the player does: they draw, block and charge. The katana
must read clearly in every pose.

**kitsuneBi** — 200 hp, speed 56
> fox spirit swordsman, white fox mask with red markings, dark navy kimono and
> hakama, blue flame wisps floating around the shoulders, katana held at the
> hip in a scabbard, slim agile build

**yukiOnna** — 210 hp, speed 54
> snow woman yokai, pale blue-white skin, long black hair, flowing white winter
> kimono with a pale blue sash, frost patterns on the fabric, katana in a white
> scabbard at the waist, tall and still

## Tier 6 — bosses

Both are faster and stronger than the player. They should look it at a glance —
bigger silhouette, more vertical presence than the tier 5 pair.

**nurarihyon** — 420 hp, speed 60
> yokai lord, tall elongated bald head, aged pale face, rich dark purple and
> gold formal kimono with wide shoulders, long ornate katana, imperious upright
> posture, commanding presence

**hannya** — 400 hp, speed 64
> horned demon woman, white hannya mask with gold horns and a wide grinning
> mouth, long black hair, deep red kimono with gold patterns over dark grey
> hakama, katana drawn, aggressive forward stance

---

## Export

Per clip, eight directions, 224x224 cells, feet at y=192, to:

    assets/sprites/monsters/<name>/sprites/<Clip>/<Name>_<Clip>_dir<N>.png

dir1=SE dir2=E dir3=NE dir4=N dir5=NW dir6=W dir7=SW dir8=S.

Then `python3 tools/build_enemy_scene.py <name>` rebuilds the scene against
whatever is in the folder. It measures frame counts per clip rather than
assuming them, so Mixamo clip lengths do not have to match what PixelLab
produced.
