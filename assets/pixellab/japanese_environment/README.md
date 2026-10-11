# Japanese Environment — PixelLab Source Assets

Art-only source pack for Katana Kitsune. Nothing in this folder is wired into
Godot scenes yet.

## Scale and projection

- Native game grid: 48×24 isometric (2:1 diamond).
- PixelLab tiles use 48×48 transparent canvases. Align the visible diamond to
  the existing 48×24 grid during TileSet preparation; do not rescale it.
- Props use 96×96 transparent canvases and share the existing `chair.png`
  camera, pixel density, outline, palette, and upper-left light direction.
- Katana Kitsune is approximately 96 pixels tall in gameplay. Prop sizes were
  judged against that character height and the 48-pixel tile width.

## Tile collections

- `floors/`: 16 indoor floor variations including tatami, hinoki boards, dark
  dojo boards, stone, earth, gravel, mossy paving, and castle paving.
- `exterior_tiles/`: 16 flat outdoor variations emphasizing grass, gravel,
  stone, moss, and earth. PixelLab did not produce acceptable water, so no tile
  in this batch should be treated as the final water material.
- `terrain_grass_earth/`: 16 grass/earth corner-mask transitions rendered as
  raised terrain blocks. Use for cliffs or elevation, not flat walkable ground.
- `building_kit/`: 58 modular Japanese floor, timber-and-plaster wall, corner,
  doorway, partition, pillar, stair, and roof/floor pieces.

The raised terrain transition uses `NW<<3 | NE<<2 | SW<<1 | SE`; a set bit
selects grass and an unset bit selects earth.

## Props

Every prop is drawn in the four isometric facings as
`<prop>_<facing>.png` and `<prop>_broken_<facing>.png` (`southEast`,
`southWest`, `northWest`, `northEast`). The original front-view art broke the
isometric perspective and was removed; the IDs below are those originals.

| Prop | Base PixelLab ID | Broken PixelLab ID |
| --- | --- | --- |
| ceramic_jar | `4f26f736-7476-454a-bd5a-f1f5b937febf` | `cf777bb6-48d6-4fae-868c-0b2f3ef51478` |
| folding_screen | `ea8ab721-fed9-4679-a7ff-3af63ba510d9` | `2d7f2295-7bd6-43d5-a0d4-ab12efd940bc` |
| katana_rack | `2f00424e-f246-41df-8b91-461c01a7547f` | `b1898f43-ad97-48ef-b893-feba6a388c4d` |
| low_table | `61a206c6-9a1b-4641-aff8-34ec551b2925` | `6e8604a2-8a48-400c-9cda-3e2ea0fa8e7f` |
| offering_box | `75ace8de-fa9c-4e89-bced-ad42bb5958e8` | `0adca301-434b-4d62-b3b6-593d58ab8a9f` |
| sake_barrel | `ad6bdff0-e956-4d3b-ae2c-6c14c45f77eb` | `ef944409-a421-42e8-a8db-ccb28e4b5e26` |
| stone_lantern | `76f054ee-b621-41e8-bb2e-5323dcb98f12` | `10f1a336-ebc2-4ae6-9d5a-4993becc88d5` |
| storage_chest | `6be2dcd5-62ed-4b6c-8747-3a20d3ce1b6b` | `6ba9db27-a35c-4ce4-b011-71f4511acbaa` |
| tea_set | `8a779f51-c548-459c-a19a-e0ca7200d2bb` | `14d90eb0-e51b-4ce5-8e00-e56535cae98f` |
| zabuton_stack | `c6212a0c-48da-4111-a652-b392f8151ac5` | `d18635aa-0a50-48bb-b6b3-28567252a3df` |

The larger props below were generated directly in the four isometric facings
on 136×136 canvases and scaled in their scenes to stand against the player:

| Prop | Base PixelLab ID | Broken PixelLab ID |
| --- | --- | --- |
| tansu_chest | `f0e6e4a2-5477-48fe-b870-6aeaabea759e` | `d48f3427-dc13-4e4a-8130-f59c78eda911` |
| samurai_armour_stand | `d92e8abb-77c3-4895-a1fa-d42c76421ff5` | `9cceaefe-a7de-4afa-bc6e-0a739f572b1b` |
| taiko_drum | `809c360d-84ec-49d4-b746-b6b8680d039e` | `37d58454-414b-450a-b41a-562c3750d1f1` |
| rice_bales | `47af6b04-38b9-4352-826c-c597aab56902` | `7b38705f-e083-4deb-8e44-26a479bbce8d` |
| supply_crates | `dfa8363b-f4ef-48b9-8e6c-f6803e86cc6d` | `af2fa78e-03f8-45ac-b5b1-e9f37416fb8e` |
| butsudan_shrine | `04dd9e0e-523c-4238-a338-d9c2bc0b71f7` | `caec1cc3-c44f-4043-b42c-903fa3becc75` |

## Tile PixelLab IDs

- Floors: `dfefff55-78cd-4797-9603-9b78964c723b`
- Flat exterior materials: `01c2af8a-7366-4d74-ba87-82df21de88dd`
- Raised grass-to-earth transition: `32dbf698-d046-4612-aa87-00465c68f27d`
- Modular building kit: `92d8ef5c-aa2b-445a-9b7e-60e2530da65d`

## Godot TileSet resources

- `tilesets/japanese_ground_tileset.tres`: 32 indoor and flat exterior tiles.
- `tilesets/japanese_raised_terrain_tileset.tres`: 16 raised grass/earth pieces.
- `tilesets/japanese_building_tileset.tres`: 58 modular building pieces.

These resources use the project's 48×24 isometric grid and intentionally do
not replace the existing dungeon TileSets. Terrain painting rules, collision,
navigation, and placement metadata remain implementation work.

## Reusable prop scenes

The sixty-four game-ready scenes are under `res://scenes/props/japanese/`, one per
prop and facing (`<prop>_<facing>.tscn`). Each is a Y-sorted `StaticBody2D`
with a collision polygon fitted to that facing's art, intact texture,
single-frame broken texture, and persistent debris after destruction.

## Doors and windows

`architecture/` holds wall-tile art for the three wall directions the maze
uses (`dir3`, `dir5`, `dir7`), all 240×384 like the wall tiles:

- `shoji_door_frame_dir*.png`: the wall with an empty doorway.
- `shoji_door_panel_dir*.png` / `shoji_door_broken_dir*.png`: only the paper
  interior of the doorway, intact and torn. `SlidingDoor` slides it apart into
  the jambs with `shaders/shojiSlide.gdshader`.
- `window_dir*.png` / `window_broken_dir*.png`: only the window, transparent
  elsewhere. `MazeDemo` paints it over each floor's themed wall texture, so a
  window always matches the stone it is set into.

`MazeDemo` adds these as runtime sources of the rooms' shared wall TileSet,
places doors in some carved openings (`door_chance`) and windows in some closed
walls (`window_chance`). Smashed windows collide on physics bit 8 only, which
characters walk into but sight lines, light and slash projectiles ignore.

The original chair scene now exposes a `SitAnchor` and sitting direction.
Katana Kitsune snaps to that anchor before playing the existing directional
`sittingChair` animation, so nearby idle resting is visually aligned.

## Animals

Harmless ambient wildlife lives in `animals/<animal>/`, one PNG per frame named
`<idle|move|fly>_<southEast|northEast>_<i>.png`. Only the two isometric
facings toward the camera's right were generated. `scripts/system/Animal.gd`
mirrors them with `flip_h` for south-west and north-west, so every animal
moves strictly along the four isometric diagonals.

| Animal | Scene | PixelLab character id | Height (px) |
| --- | --- | --- | --- |
| Rat | `scenes/animals/rat.tscn` | `f94471f0-3c0d-41f6-9de4-fe3253611148` | 22 |
| Japanese rat snake | `scenes/animals/snake.tscn` | `da6f423c-3c0d-40f2-8130-2f1f96d2d5df` | 22 |
| Jungle crow | `scenes/animals/crow.tscn` | `c4207dd1-5b34-4e29-8fea-60acd345550e` | 34 |
| Fox | `scenes/animals/fox.tscn` | `c7773318-8f01-40d4-b696-4d060327729f` | 52 |
| Cat | `scenes/animals/cat.tscn` | `8d9d118e-9b90-4016-aa3f-54115787dc2b` | 40 |
| Tanuki | `scenes/animals/tanuki.tscn` | `84ee0d48-d2f5-4446-be39-b283b60a26e6` | 46 |
| Sika deer | `scenes/animals/deer.tscn` | `c4adb99f-26d7-4e61-82ad-fb46475e5649` | 130 |
| Tree frog | `scenes/animals/frog.tscn` | `27767817-d034-4419-add8-e25cbd5b4ddd` | 18 |

Heights are relative to the roughly 180 px player. Animals idle, wander near
where they spawned, and flee from anything in the `player` or `enemy` groups.
The crow (`can_fly`) instead takes off with its `fly` animation, rises, fades
and is removed. Animals are on collision layer 0 and are not in the `enemy`
or `breakable` groups, so combat, wave counting and the radar ignore them.
`MazeDemo.animal_scenes` and `animals_per_room` control spawning; the start
room never gets animals.
