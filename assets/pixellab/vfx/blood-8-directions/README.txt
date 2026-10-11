PixelLab VFX Creator: one effect turned to face several ways.

Each folder is one direction (east, south-east, ... or angle-030 for an angle in degrees,
clockwise from east on screen: 90 is toward the camera). manifest.json lists them.

In a folder, every clip is a spritesheet with exact pixels: scale it by whole numbers only,
with nearest-neighbour filtering. Draw frame i at anchor + offset, the anchor being your
character's feet:
- behind: draw it, then your character facing that way, then
- front.
- whole: the effect without the character.
The folder's manifest.json has each clip's offset, frame size and timing.

Godot integration:
scripts/system/HitEffects.gd uses the whole.png clips for all eight directions.
Each 3x3 sheet plays once at 19 fps (9 frames), at integer 2x scale with nearest
filtering and its own manifest offset. The chosen direction is away from the
attacker in screen space; the pre-rendered sheets are not rotated or squashed.
The burst is anchored at the victim's impact point, 40 world pixels above its
root, and frees itself after playback. Gameplay pause also pauses playback.

Player and enemy take_damage handlers create a burst only for positive damage.
Player invincibility, wards, full guards and cheat immunity do not bleed.
Enemy armour reductions apply before spawning blood. Fatal hits still bleed;
already-dead bodies do not. Katana melee/thrown hits and enemy melee/projectiles
reuse the existing damage handlers. No blood is added to breakable scenery.
