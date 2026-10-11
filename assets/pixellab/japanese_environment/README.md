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

The forty game-ready scenes are under `res://scenes/props/japanese/`, one per
prop and facing (`<prop>_<facing>.tscn`). Each is a Y-sorted `StaticBody2D`
with a collision polygon fitted to that facing's art, intact texture,
single-frame broken texture, and persistent debris after destruction.

The original chair scene now exposes a `SitAnchor` and sitting direction.
Katana Kitsune snaps to that anchor before playing the existing directional
`sittingChair` animation, so nearby idle resting is visually aligned.
