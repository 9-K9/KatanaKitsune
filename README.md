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

| Action | What it does |
|--------|--------------|
| `Left` `Right` `Up` `Down` | Move on the isometric lattice |
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
| `ScrollUse` | Pad `R3`: tap to read the highlighted scroll, hold to cycle, release to read |

## Scrolls

Breakables sometimes drop a power-up scroll (`scroll_chance`, 12%). Each player
has a 6-slot bar along the bottom of the screen. Scrolls of the same kind stack
in one slot.

| Kanji | Scroll | Effect |
|-------|--------|--------|
| 無 | Invincibility | Health cannot drop, 8s |
| 気 | Exertion | Stamina does not drain, 15s |
| 隠 | Invisibility | Faded; monsters lose track of you; stealth does not drain, 10s |
| 速 | Speed | Run ×1.4, 12s |
| 剛 | Attack | Damage ×1.6, 12s |
| 石 | Stone | The next strike turns one monster to stone for 6s instead of damaging it. Striking it while stone shatters it for 3× damage |

## How it works

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
