# Japanese Environment — PixelLab Source Assets

PixelLab source and runtime art for Katana Kitsune. The resources and scenes
described below wire reviewed assets into the game; pending biome art stays gated.

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

## Biome and weather asset slots

The gameplay side uses explicit resource slots rather than implicit asset names:

- `scripts/system/ExteriorBiome.gd`: Sakura, desert and snow definitions, each
  with `ground_paths`, `trees`, `edge_trees`, `compatible_weather`, `ponds` and
  the approved / unapproved gate.
- `scripts/system/OutdoorWeather.gd`: ambient weather controllers that only load
  `res://assets/pixellab/japanese_environment/weather/*.png` when the selected
  biome declares that weather as approved and the texture path exists.
- `res://resources/biomes/*.tres`: biome resources that remain in the original
  Sakura state until art has passed the 2:1 isometric review for that biome.

This keeps the project stable when art is still pending: the floor stays calm,
indoors remain unchanged, and the game never invents missing textures or claim
final assets before they have been checked.

### Supplying reviewed art

Desert and snow environment art is still pending (`art_approved = false`).
The four particle textures below have been generated with PixelLab, inspected,
and approved. Sakura now cycles petals and rain; snow/sand particles are wired
but their floors remain gated until environment art is supplied. File existence
alone does not enable a biome or approve its perspective.

| Slot | Required files |
|---|---|
| Desert ground | `biome_tiles/sand_a.png`, `biome_tiles/sand_b.png` |
| Snow ground | `biome_tiles/snow_a.png`, `biome_tiles/snow_b.png` |
| Desert trees | `scenes/props/japanese/exterior/cactus_a.tscn`, `cactus_b.tscn`, `palm_a.tscn` |
| Snow trees | `scenes/props/japanese/exterior/dead_tree_a.tscn`, `dead_tree_b.tscn` |
| Weather particles | `weather/sakura_petal.png`, `rain_drop.png`, `snowflake.png`, `sand_grain.png` |

Ground textures must be flat, seamless 48x24 **2:1 isometric** diamonds on
transparent 48x48 canvases, aligned exactly like `exterior_tiles/`. No raised
sides, baked shadows, front-view or top-down substitutes. Review repeated tiles
for seams before setting `art_approved = true` in the corresponding
`resources/biomes/*.tres`. Tree scenes must follow `ExteriorProp.gd`, use a
ground-contact root pivot and a `Sprite2D` child, and carry fitted trunk
collision/occlusion without overwriting existing tree scenes. Placement reads
new trees' sprite bounds to keep their crowns clear of walls.

Particle textures are small transparent isolated sprites, not environment
tiles; keep rain streaks vertical (wind moves the ground anchor), petals and
snowflakes centered, with no background slab. Once reviewed, add weather IDs to
the biome resource's `approved_weather`: petals `1`, rain `2`, snowfall `3`,
sandstorm `4`. Compatibility still applies: sakura allows `0/1/2`, desert
`0/4`, snow `0/3`; `0` is calm. Changing paths or palettes is done in these
resources, not the generator. Missing/invalid slots log warnings and retain
the existing sakura floor or calm weather.

### Particle provenance

All particles use transparent 16x16 canvases with small centered visible bounds,
nearest filtering and no baked shadow. PixelLab Pixen outputs were reduced with
nearest-neighbor sampling to gameplay-sized motes. Snow's dark background
remnants were removed; the second rain generation's vertical stem was extracted
without its horizontal foot or opaque grey background. The first rain result
was rejected because it depicted a cloud rather than a streak.

| Texture | PixelLab job ID | Gallery asset ID | Visible size |
|---|---|---|---|
| `sakura_petal.png` | `12e80a72-58e1-4a20-b52a-cdfc963c32f9` | `e48ec51a-5b5e-51d9-872b-9a98e768c5d5` | 4x6 |
| `rain_drop.png` | `37034cbf-5ba9-44e3-96d3-b62e588a4148` | `8fc310cf-7998-568f-9eb0-1bb69762d10f` | 1x7 |
| `snowflake.png` | `922a267a-37b8-4cf4-bfe4-c27d1e169b97` | `6a807218-645f-5981-a8e2-0622c3b55fb0` | 4x3 |
| `sand_grain.png` | `18cb3215-b093-4564-8639-ffeab9d05088` | `beb44854-1701-5e49-ad42-c0f66f3a1309` | 3x3 |

### Runtime controls and exclusion

`MazeDemo` exposes `outdoor_biome`, `outdoor_weather` (automatic or forced) and
`weather_intensity` in the Exteriors inspector group. Choose once per floor;
automatic weather alternates calm with an available compatible effect every
35-65 gameplay seconds. Opacity changes gradually, fading to zero before
switching effect. Biome selection and weather use separate seed streams and
never consume the combat/layout RNG on weather ticks.

`scenes/weather/outdoor_particles.tscn` is shared by all four effects.
`outdoorWeather.gdshader` stores each particle's **ground anchor and height**
separately, rejects indoor spawns, and traverses crossed lattice cells when
wind moves an anchor. `outdoorWeatherDraw.gdshader` clips both the projected
sprite and its ground footprint. Occupancy comes from measured building cells,
not roof visibility: fading/hidden roofs and open doors do not expose indoors
to weather. This deliberately clips outdoor sprites that project over an
indoor footprint too, rather than drawing precipitation inside.

One bounded world-space field per effect covers the current shared party
camera, including zoom. The controller can accept up to four view rectangles
without duplicate overlapping emitters, caps allocation at 1024 particles
(256 per effect), and retains only recent view bounds for culling. Moving the
camera changes future spawn coverage, not existing particle positions.
Gameplay pause freezes weather timing and simulation; floor teardown hides
and frees emitters. Interior-only floors never create weather. Desert omits
ponds and lush plants; snow keeps existing impassable pond collision without
adding ice mechanics. All weather is visual-only: no audio, damage, debuffs,
accumulation or gameplay lighting changes.

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
| Snow hare (rabbit) | `scenes/animals/rabbit.tscn` | `061522e2-cb6c-4355-abf4-3e32397688a4` | 35-49 |
| Freshwater turtle | `scenes/animals/turtle.tscn` | Creator gallery (see below) | 27-30 |

The rabbit has eight idle frames and six hopping frames per right-facing
diagonal, mirrored for the left-facing diagonals like the other animals.
Original PNG pixels are preserved on padded 104x104 canvases. Each clip's
initial ground-contact pivot is aligned at (52, 90), with a constant offset
throughout that clip to preserve the hopping motion. The scene uses 0.75 scale
and a 10 px collision radius; hopping is also used while fleeing.

The freshwater turtle comes from PixelLab's **Creator** gallery, not the
character library. Its clips were exported unchanged by running a zero-pixel
`pixelart_workbench edit` on each gallery ID and downloading the resulting
`frames.png` sheet. Frames are the original 64x64 transparent canvases with no
realignment. The scene uses 0.75 scale, an 11 px collision radius, and slow
walk/flee speeds (16/45).

| Turtle clip | Creator gallery ID | Frames |
| --- | --- | --- |
| Idle south-east | `3c3c2728-6b00-56b8-bbc4-073ffc0f2a54` | 5 |
| Idle north-east | `abe64f2c-bc22-5eff-b322-6292e100d8ed` | 5 |
| Walk south-east | `a89f8ea7-eedc-5b4f-ab23-94dccb5e5631` | 7 |
| Walk north-east | `e92c00be-d8ff-51f2-8e4e-877f91865a1b` | 7 |

Heights are relative to the roughly 180 px player. Animals idle, wander near
where they spawned, and flee from anything in the `player` or `enemy` groups.
The crow (`can_fly`) instead takes off with its `fly` animation, rises, fades
and is removed. Animals are on collision layer 0 and are not in the `enemy`
or `breakable` groups, so combat, wave counting and the radar ignore them.
`MazeDemo.animal_scenes` and `animals_per_room` control spawning; the start
room never gets animals.

## Exterior props and shrine compounds

`exterior_props/` holds the outdoor dressing, every piece generated with
PixelLab pixflux at a strict 2:1 isometric angle (no front or top-down art):
sakura trees (`sakura_tree_a`, `sakura_tree_c`, `sakura_weeping`), `black_pine`,
`bamboo_clump`, `azalea_bush`, `grass_tuft`, `pond_reeds`, `garden_rocks`,
`komainu_statue`, `dragon_statue` and `torii_gate`. Each has a scene in
`scenes/props/japanese/exterior/`; tall canopies use `scripts/system/ExteriorProp.gd`
to fade when the player walks behind them.

The five trees were regenerated at 400px tall (roughly twice the old height;
backgrounds removed locally) and drawn at 1.2–1.3x scale. Enclosed background
patches between branches are transparent too; pale pink blossom highlights
are preserved. The baked-in ground slabs and ellipse/diamond shadows are
removed so trunks and bamboo sit directly over the map's grass tiles.
Canvas dimensions and trunk anchors remain unchanged:

| Tree | Gallery id |
|---|---|
| `sakura_tree_a` | `ad87f943-9bd8-454f-acee-de76c595b941` |
| `sakura_tree_c` | `0d4b20e8-35e6-4046-b7d1-d08da2871e82` |
| `sakura_weeping` | `4a805fa2-e825-4481-80b9-38453c033ac3` |
| `black_pine` | `23139814-2551-4963-9e4e-e64f4319e381` |
| `bamboo_clump` | `3279f81e-6840-4df6-a365-53ad3a75db72` |

Building walls are single long tiles y-sorted at one point, so a canopy that
crosses one gets cut or drawn out of order. `MazeExterior._clips_building`
rejects any tree spot whose canopy (`TREE_CANOPY` x `TREE_HEIGHT`) overlaps a
wall tile's art.

`scripts/system/MazeExterior.gd` turns the maze into a shrine compound: separate
buildings (roofed, entered through shoji doors guarded by komainu) set among
courtyards, gardens, ponds (`shaders/water.gdshader`) and an abandoned road,
fenced by tree lines with a torii at each road end. Roofs lift when the player
is inside and are painted in the floor's wall material by
`shaders/roofWall.gdshader`. The `MazeDemo` "Exteriors" export group controls it.

### World depth sorting

The maze root, room containers and wall TileMapLayers enable Y-sorting so
independent objects and wall tiles share one world-depth order. Individual
animals, trees, furniture and torches keep `y_sort_enabled = false` on their
roots: their raised sprite children must draw together at the root's ground
contact point, not enter the world sort using the canopy or torso's local Y.
Player and enemy scenes use the same atomic-root convention.

Leave ordinary entities at Z index 0. Ground and ponds stay at -1; roofs and
explicit overlay effects retain their separate layers. Sprite lift, animation,
canopy fade and bird takeoff must not change an entity's sort anchor. Displayed
loot stays grouped with its furniture until released onto the world layer.
Do not enable Y-sorting on a new tree/animal root to "fix" overlap: that splits
its raised art out of its ground-root sort group and causes tall trees to
render behind characters even when their trunks are in front.
