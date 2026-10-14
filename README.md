# KatanaKitsune (Isometric)

An isometric action roguelike in Godot 4.7. You play a katana-carrying kitsune
descending floor by floor through a dungeon of yokai, where the aggressive line
and the safe line are the same line.

> **Working on this project?** Read [CLAUDE.md](CLAUDE.md) first. It records the
> 2026-10-08 split: the workshop is no longer a git repository, and audio is
> deliberately absent until the end of development.

## State of play

In development, and playable end to end: title → character select → maze.

Seventeen monsters have finished 8-direction sprite sets, but only three —
jorogumo, kappa and karasuShinobi — are wired into the spawn roster while the
newer ten-clip animation set is being playtested. Audio is deferred to the end
of development, so the game is silent by design. See [CLAUDE.md](CLAUDE.md) for
why, and where the archived audio lives.

## Running it

Open the project in **Godot 4.7** (GL Compatibility renderer) and press play.
The main scene is `scenes/title_screen.tscn`; everything else is reachable from
there. Viewport is 1536×864, stretched on `canvas_items`.

## Controls

Keyboard or gamepad, up to four players locally.

After choosing the human-player count, choose **0-3 AI teammates** in the
remaining party slots. The default is zero; four human players skip this
step. Humans claim devices and pick costumes as before. Bots get distinct
costumes and `AI2`/`AI3`/`AI4` markers and HUD tags, and never claim a controller.
There is no online networking in this version.

Each AI teammate then gets a **behaviour** (up/down picks the bot, left/right
changes it). The pause menu's **AI TEAMMATES** entry changes it mid-run, and
the HUD shows it on the bot's portrait:

| Mode | Tag | Fights |
|------|-----|--------|
| Aggressive | AGG | any visible monster near the party |
| Defensive (default) | DEF | monsters that just hurt a human or the bot, or that a human just struck |
| Stealth | STL | while its human sneaks it sneaks too, blade sheathed, and stealth-strikes only monsters that have not noticed anyone; otherwise Defensive |
| Passive | PAS | only monsters that just hurt the bot or a human; follows closer and keeps its blade sheathed until needed |

"Just" means the last four seconds; once a fight is joined the bot sees it
through for a few seconds more. A sneaking bot that is hit drops cover and
fights back.

AI teammates follow the nearest living human and fight visible nearby
enemies their behaviour allows, without wandering far from the party. They guard
ordinary melee telegraphs and back away from heavy attacks when the retreat
is safe. They use the
same movement, stamina, slash hit frames, damage and death rules as humans.
Bounded collision-aware pathfinding routes around walls, scenery, ponds and
spike traps, including retracted spikes; if no safe route is found they stop
or take a safe partial route rather than crossing the hazard or teleporting.
Pause and floor loading freeze their controls, and descent resets their path.
In every mode, a fallen human takes priority over fighting and following.
Bots search across the floor, route around walls and pillars, then sheath and
sneak within clear reach to revive using the normal sneak-meter cost. Fallen
humans take priority over fallen bots; humans can also revive bots normally.
A living bot keeps the run active while rescuing the party.
Crowded bots yield in one consistent direction; when scenery blocks that
direction they stay facing still and block human movement instead of flickering.
Humans still pass through other humans, and bots through other bots.
Bots do not seek pickups, use scrolls or coordinate tactics.
Bot upgrade points are spent automatically across
the least-upgraded stats; bot slots start ready between floors. High-score
name entry uses the best human score, not a bot's score.

| Action | What it does |
|--------|--------------|
| `Left` `Right` `Up` `Down` | Move on the isometric lattice: WASD, left stick or D-pad |
| `Run` | Sprint |
| `Katana` | Draw or sheath the blade |
| `Attack` | Slash — standing, crouched, or a charged strike held |
| `Defend` | Raise a block; a well-timed one opens a counter-slash |
| `Dodge` | Forward roll |
| `Jump` | Jump, or a running jump at speed |
| `Stealth` | Crouch into stealth, halving the range monsters notice you at |
| `Action` | Interact — rest at a chair, take a pickup, descend a stairway |
| `Pause` | Pause menu |
| `Scroll1`–`Scroll6` | Keys `1`–`6`: read the scroll in that inventory slot |
| `ScrollPrevious` / `ScrollNext` | Right stick left/right or left/right arrow keys: select the previous/next occupied slot |
| `ScrollUse` | Press `L3` or up/down arrow: use the highlighted scroll |

Power-up selection wraps, skips empty slots and never activates a scroll.
Each stick deflection or arrow press selects once; recenter/release before
selecting again. Activation happens once per fresh press, never on release.
Arrow keys no longer move the character during gameplay, but still navigate
menus. Keys `1`–`6` remain direct-use shortcuts. Input belongs to each player's
own device; selecting while pressing use does not consume a scroll.

## Scrolls

Breakables sometimes drop a power-up scroll (`scroll_chance`, 12%). Each player
has a 6-slot bar along the bottom of the screen. Scrolls of the same kind stack
in one slot.

The hotbar uses the shared selection-screen/kill-counter font. Slot numbers,
stack counts and effect timers have translucent dark backings;
active-effect icons are enlarged and backed for readability over scenery.
Player tags, scores, floor and kill counts also have translucent backings.

| Kanji | Scroll | Effect |
|-------|--------|--------|
| 無 | Invincibility | Health cannot drop, 8s |
| 気 | Exertion | Stamina does not drain, 15s |
| 隠 | Invisibility | Faded; monsters lose track of you; stealth does not drain, 10s |
| 速 | Speed | Run ×1.4, 12s |
| 剛 | Attack | Damage ×1.6, 12s |
| 石 | Stone | The next strike turns one monster to stone for 6s instead of damaging it. Striking it while stone shatters it for 3× damage |

## How it works

**Day and night.** Each run begins in day and alternates five minutes of day
with five minutes of night. The party shares one gameplay clock across floors;
pause, loading and floor rebuilding freeze it. A sun travels from left to right
over the dragon-framed radar's upper semicircle; at sunset it becomes a moon
travelling along the lower semicircle back to sunrise. Lighting fades for 20 seconds after each
boundary; gameplay bonuses switch immediately, indoors and outdoors alike.

Each portrait has its player's kill count for the current floor underneath.
These counters reset on descent, while `Score.run_kills` retains each player's
credited kills in memory through game over. Existing point scoring is unchanged.
Below the radar, a centred translucent black panel shows shared floor progress
as `killed/total`, then the number of enemies remaining on the next line.

**Levels and upgrades.** The player who lands a kill earns experience for that
species: kappa 10, karasu shinobi 12, nina ninja 15, jorogumo 25, oni 30,
tengu 35, kasha 40, yuki-onna 60 and yokai lord 200. Each tier the spawner rolls
above the species' own scene tier adds 15%. Level 2 needs 80 XP, and each later
level needs 40 XP more than the last. Every level grants one point.

After a floor is cleared, the upgrade screen appears if any active player levelled
up. Players spend independently in their own column with Up/Down, Confirm and Back
(undo), then choose Ready; the next floor starts once everyone is ready. Each stat
has five ranks: Health +10% maximum health; Stamina +10% maximum and +8% regen;
Speed +4% walk and run speed; Stealth +10% sneak capacity, -8% sneak drain and +8%
sneak regen. Progress is per player slot for the current run and resets on a new
game or game over. Point scoring is unchanged.

| Phase | Player advantage | Enemies |
|-------|------------------|---------|
| Day | Katana strikes +25% damage, katana run +20% speed, stamina costs -25% while the blade is drawn | Sight range +25%; normal attack damage |
| Night | Stealth strikes +25% damage, ninja run +20% speed, all sneak costs -25% (including strikes and revival) | Sight range -25%; attack damage x2 |

Kicks and ordinary unarmed attacks receive neither damage bonus. Existing
charged/counter/assassination and scroll multipliers compose with the phase
bonus without changing base stats; regeneration is unchanged. Ranged enemy
shots retain the damage of their launch phase. Vision still respects cones,
stealth and wall/door occlusion. The cycle does not change weather's visual-only
behavior.

**The floor.** `MazeDemo.gd` tiles one room scene across a diamond lattice, each
neighbour half a room across and half a room down so the diamonds interlock,
then knocks walls out from both sides. The result reads as one continuous space
rather than a corridor. Pillars are stood in every opening so a removed wall
looks like a deliberate colonnade. Walking onto the stairway `Exit` sends the
run down a floor.

**Scoring is a streak.** A kill opens a short window of invulnerability, and
killing again inside it extends the window and climbs the grade. The window you
are safe in is exactly the window you must kill in, so pressure and protection
are one number (`streak_window`, 2.2s). Standing back to pick enemies off one at
a time scores least. Tier weight, wave bonus, stealth and speed all multiply
through the grade, capped at 8×. Scored per player, so a party competes on one
screen.

**Stealth is readable.** The radar draws each monster's actual vision cone —
same arc, same range, same walls — so a gap between two cones on the radar is a
gap you can walk through. Blips carry monster state, so a cone turning from
amber to red is the moment you were seen.

**Monsters scale by tier, not by subclass.** `EnemyTier.gd` is one table of six
rungs — SHAMBLER, RUNNER, WARDEN, BRUTE, SPIRIT, YOKAI LORD — that switches
behaviours on and sets the numbers. Every tier reuses the same state machine, so
chase logic exists once. Higher rungs guard or bring the full katana kit. What a
monster *is* rides on top as `species_traits`: Yuki Onna alone phases through
walls. Each species also sets its own `run_speed` for the chase, so the nimble
ones close fast and the heavy ones lumber.

**Twelve elemental aspects.** `PowerState.gd` holds the colour schemes — Jade
Dragon, Vermilion Phoenix, White Tiger, Black Tortoise and the rest — chosen at
character select and read by the title screen, the maze and the player alike.

**Revised title artwork.** The title, character-select and pause screens show
the new heroine in the chosen aspect's colours:
`assets/sprites/ui/title_covers_kitsune/<state id>.png`, with
`title_cover_kitsune.png` as the neutral fallback. Each is a 768x432 Lanczos
reduction of a GPT-generated master (`/mnt/K-DRIVE/Pictures/Misc/Meshy/TitleCover.png`
and the `title_variants/` set); the full-resolution sources stay outside the
game repository (see `tools/build_kitsune_title_covers.py`). The previous
`title_cover.png` and `title_power_states/` artwork remain in place for the
old-character cheat below.

**KARMAGEISHA.** The high-score name entry takes up to twelve characters
(confirm saves whatever is on the wheel, so shorter names are fine). Enter
`KARMAGEISHA` as your name and the score is saved under it, then the previous
heroine — Katana Kitsune, `scenes/characters/KatanaKitsune.tscn` — takes over
every player slot, humans and bots alike, as a god: triple damage, 1.6x speed,
twice the sneak meter at half the drain, immortality on by default (toggleable
from the pause menu's Cheats submenu, which she makes visible in release
builds), and all six scrolls stocked and never spent. HUD icons and the
title/pause/select covers revert to her art. The trade is the scoreboard: while
she is active a run scores nothing and the name entry still opens on game over
showing 0, and entering any other name there turns her off again. The state
persists across launches in `user://cheats.cfg`; the logic lives in
`scripts/system/CheatManager.gd`.

**Outdoor biomes are asset-gated.** `scripts/system/ExteriorBiome.gd` owns the
Sakura / desert / snow selection, terrain slots and weather compatibility. The
runtime checks `res://resources/biomes/*.tres`, `res://assets/pixellab/japanese_environment/biome_tiles/*.png`
and `res://assets/pixellab/japanese_environment/weather/*.png` before enabling a
biome or weather effect. Missing or unapproved art keeps the floor in its calm
state rather than crashing or inventing placeholder props.

## Layout

```
scenes/       title, menuscreens, world, characters, monsters, props, fx
scripts/
  stateMachine/
    playerState/   katana draw/block/charge/counter, kicks, rolls, stealth
    enemyState/    idle, alert, walk, charge, attack, block, hurt, death
    class/         shared bases — AnimatedCharacterClass, NavAIClass, IsoFacing
  system/          maze generation, score, roster, radar, HUD, pickups, traps
assets/sprites/    characters, monsters (8 directions per clip), props
dialogue/          Dialogic timelines
tools/             Python for sprite import, rig retargeting, sheet export
_GDD/              design document (PDF and Markdown)
archive/           superseded scenes and scripts, kept for reference
```

Autoloads: `Dialogic`, `CheatManager`, `PowerState`, `Roster`, `Score`.

## Where the art comes from

Sprites are rendered out of 3D rather than drawn by hand. Rigs are generated and
animated in Meshy, retargeted in Blender, then turned into 8-direction
spritesheets through PixelOver. The recipes live in
[meshy-prompts.md](meshy-prompts.md), [meshy-animations.md](meshy-animations.md)
and [meshy-export-chart.md](meshy-export-chart.md).

That pipeline is **not** in this repository — it is plain files in Dropbox, as
[CLAUDE.md](CLAUDE.md) explains. This repo holds the finished sprites and the
game that uses them.
