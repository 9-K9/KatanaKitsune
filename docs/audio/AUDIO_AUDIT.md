# Katana Kitsune Audio Audit

Audit date: 2026-10-21  
Repository revision inspected: `689ff612`  
Method: static inspection only. Godot was not launched, so no imports or user settings were rewritten.

## Executive finding

The playable game is effectively silent. The repository contains five WAV files, all example typing sounds bundled with Dialogic. There are no game-owned audio files, no central audio manager, no `default_bus_layout.tres`, no gameplay `AudioStreamPlayer` nodes, and no calls from game scripts that play audio. Dialogic contains generic audio/voice subsystems, but the game does not supply music, voices, ambience, or combat effects to them.

This is a large clarity gap because the game already implements animation-rich melee combat, damage mitigation and parries, projectiles, traps, breakables, pickups, multi-stage progression, weather, animal-populated environments, and private online co-op.

## Scope inspected

- 660 `.tscn` scenes, 393 `.gd` scripts, 48 `.tres` resources.
- `project.godot`, `export_presets.cfg`, autoloads, input actions, and all audio-extension references.
- Player and enemy state machines; level generation, environments, props, HUD, menus, progression, game over, Dialogic, and networking.
- All WAV/OGG/MP3/FLAC/Opus files and all `AudioStreamPlayer*` declarations.
- Source references in the CSV were verified against the filesystem.

## Existing audio inventory

| File | Purpose/reference | Resolves | Usage assessment | Licence/attribution |
|---|---|---:|---|---|
| `addons/dialogic/Example Assets/sound-effects/typing1.wav` | Default Dialogic VN choice pressed sound | Yes | Referenced by `vn_choice_layer.gd/.tscn`; no verified game timeline uses that layout | Bundled Dialogic example; no per-file licence found |
| `.../typing2.wav` | Default choice hover sound | Yes | Referenced as a default path in `vn_choice_layer.gd` | Same |
| `.../typing3.wav` | Example typing variation | Yes | No direct game reference found | Same |
| `.../typing4.wav` | Default choice focus sound | Yes | Referenced by `vn_choice_layer.gd/.tscn` | Same |
| `.../typing5.wav` | Example typing variation | Yes | No direct game reference found | Same |

No duplicate binary assessment was performed; filenames and roles are distinct. All five are plugin example content, not evidence of an authored game sound library. Before shipping any of them, confirm the installed Dialogic version's licence and whether example assets are covered.

## Existing audio systems

- **PARTIAL — Dialogic:** `addons/dialogic/Modules/Audio/subsystem_audio.gd` dynamically creates non-positional `AudioStreamPlayer` nodes and supports channels/fades. `Modules/Voice/subsystem_voice.gd` supports voice playback. These are plugin capabilities, not wired game audio.
- **PARTIAL — dialogue typing/choice nodes:** default Dialogic layouts contain audio players. Only the example typing files are configured.
- **MISSING — buses:** no `default_bus_layout.tres` is present. The effective project layout is the single default Master bus.
- **MISSING — runtime manager/registry:** no game autoload or event registry handles SFX, music, ambience, pooling, variation, concurrency, or volume settings.
- **MISSING — spatial playback:** no game-owned `AudioStreamPlayer2D` or attenuation policy was found.
- **MISSING — settings:** the controls system is substantial, but no music/SFX/voice volume settings were found.

## Implemented systems and audio opportunities

### Player and combat

**IMPLEMENTED.** `scenes/characters/KatanaKitsune.tscn` and `scripts/stateMachine/playerState/` implement walking, several run speeds, stealth movement, forward roll, jumps, kicks, katana draw/sheathe, standing/crouched slash, charged slash, block, timed parry/counter, damage, death, chair resting, and flair. `AnimatedCharacterClass.gd` implements stamina, sneak, guard direction, damage soak, six scroll buffs, petrification, and revival. Audio should make animation timing, hit confirmation, defensive success, stamina state, and co-op revival readable.

**PARTIAL.** Animation names verify many motions, but static inspection cannot prove exact foot-contact frames. Footstep and weapon cues should be placed with animation call-method tracks or state-timed event hooks after runtime review.

### Enemies

**IMPLEMENTED.** Nine active scenes exist: Jorogumo, Kappa, Karasu Shinobi, Kasha, Nina Ninja, Oni, Tengu, Yokai Lord, and Yuki Onna. Their shared state system includes alert, arise, attack, block, critical attack, dodge, hurt, death, walk, taunt, and, depending on scene, cast/charge/heavy/stomp/stumble/weave. Jorogumo, Kappa, Yokai Lord, and Yuki Onna have projectile configuration.

**PARTIAL.** Every inspected active monster scene points its TauntComponent to `dialogue/enemies/undeadRonin_taunt.dtl`, including species for which that line is not authored. Two short dialogue timelines exist, plus a test timeline. Species-specific spoken taunts need a narrative pass before voice production.

### World and hazards

**IMPLEMENTED.** Procedural floors include indoor rooms and exteriors. Five named themes are backed by resources: Sakura Gardens, Bamboo Woodland, Abandoned Shrines, Desert Ruins, and Frozen Pass. Weather includes calm, petals, rain, snowfall, and sandstorm. Ponds, torches, braziers, numerous animals, day/night lighting, doors, windows, spike runs, furniture, and decorative/interactive objects are present.

**IMPLEMENTED.** `Breakable.gd`, `SlidingDoor.gd`, `SpikeTrap.gd`, `Pickup.gd`, `Exit.gd`, and `SlashProjectile.gd` expose exact event points for breaks, impacts, warnings, collection, descent, and projectiles.

### UI, progression, and game state

**IMPLEMENTED.** Title, character select, level select, online lobby, pause, HUD, six-slot scroll inventory, level-up spending, score/name entry, death countdown, and game-over flows exist. None has game-owned audio. These are high-value non-positional cues, especially confirm/error, progression spend, countdown, and online state.

### Multiplayer

**IMPLEMENTED.** `NetworkManager.gd` hosts/joins WebSocket rooms, assigns seats, synchronizes lobby choices, relays inputs, broadcasts actor snapshots, replicates world events, floor descent, and session ending. Audio must not play once for the input request and again for the authoritative result. Local UI cues can play immediately; world cues should be derived from authoritative state/event transitions and emitted once per entity/event ID.

### Music and narrative

**PROPOSED.** No music-state machine exists. Existing screens and combat states justify menu, selection, lobby, exploration, combat, boss, victory, and defeat music. Dynamic intense-combat layering is proposed, not present.

**PARTIAL.** Dialogic and TauntComponent are implemented, but authored narrative content is minimal. Do not record broad dialogue until lines, speakers, and scene assignments are approved.

## Web/export observations

The Web preset uses GL Compatibility, exports all resources except listed exclusions, has no thread support, and targets `build/web/index.html`. Use OGG Vorbis for streamed music/ambience, WAV for short source masters, and import short SFX compressed only after listening tests. Browsers require a user gesture before audio starts; initialize/unmute on the first title-screen input. Keep simultaneous voices bounded and avoid preloading all long tracks.

## Runtime validation (2026-10-21)

- The normal title scene ran headlessly for 15 seconds with no script errors or warnings and peaked at 152,740 KiB RSS (about 149 MiB).
- `validate_player_animation_rates.tscn` completed 163 checks with zero failures. It confirms the examined idle/dance/walk/attack animation-rate contracts for the player and Jorogumo, Yuki Onna, and Kappa. Loading those full directional sprite sets peaked at 2,523,280 KiB RSS (about 2.41 GiB), so future asset-heavy validators should run sequentially rather than in parallel.
- `validate_breakable_environment.tscn` was inconclusive under the dummy headless renderer. During its generated floor it repeatedly hit null rendering-texture operations in `EnemyStateClass._measure_sprite_content`; the run was stopped to avoid log and memory growth. This is a headless texture-inspection incompatibility, not evidence that the graphical game fails, but that validator is unsuitable for audio-timing conclusions until it skips visual measurement in headless mode.
- No audio playback could be validated because the game still has no game-owned runtime audio events or assets.

## Remaining runtime questions

1. Confirm exact foot-contact and attack-impact animation frames.
2. Confirm material/surface detection available at the player position.
3. Measure whether exterior ambience zones overlap indoor rooms.
4. Determine whether Yokai Lord is treated as a formal boss or simply tier 6.
5. Verify whether current Dialogic taunts are reachable in normal play and which layout they use.
6. Profile web decode/memory cost after the first generated batch.
7. Confirm intended mix behavior during pause, game-over, and browser focus loss.
