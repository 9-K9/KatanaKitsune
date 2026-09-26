# Template rooms

The level generator builds a floor by placing these prefabs on a grid and
joining orthogonal neighbours with corridors. Drop new rooms in this folder and
the generator picks them up; nothing needs registering.

## Why prefabs instead of generated walls

The Crocotile wall tiles are single tiles spanning a 5x16 atlas region — a
4-cell-wide, ~350px-tall plane, in 8 rotations, with collision authored in.
They were positioned by eye against a specific room shape, and reading the 16
authored placements out of `ysortmap.tscn` shows two different strides
(~255px and ~152px per step), neither aligned to a tile axis, and varying
within each run. There is no fixed tile stride that tiles them, which is why
two attempts at painting walls procedurally both looked wrong. Authoring rooms
keeps the walls looking the way they do in the hand-built map.

## Room scene layout

```
RoomSmall (Node2D, y_sort_enabled = true)
├── Ground      (TileMapLayer)   REQUIRED, this exact name
├── BackWalls   (TileMapLayer)   far walls
├── FrontWalls  (TileMapLayer)   near walls, faded when the player is behind them
├── Roofs       (TileMapLayer)   optional
└── Door_N / Door_S / Door_E / Door_W   (Marker2D, 2-4 of them)
```

The footprint is read from `Ground.get_used_rect()`, so there is no size to
declare anywhere.

Tilesets to paint with, both already extracted from `ysortmap.tscn`:

- `res://assets/sprites/tiles/crocotileGround.tres` — 56 ground tiles
- `res://assets/sprites/tiles/crocotileWalls.tres` — 8 wall directions

`ysortmap.tscn` is already exactly this shape. Copying it, trimming it and
adding door markers is the quickest way to a first large room.

## Door markers

Put the marker on the **floor tile just inside the wall opening**, and leave a
gap in the wall there.

Names are **what the door looks like on screen**, so there is nothing to work
out and nothing to get backwards. Stand in the room, look at the opening, and
name it after the direction you would walk to leave through it:

| Marker           | On screen  | (tile axis, for reference) |
| ---------------- | ---------- | -------------------------- |
| `Door_UpRight`   | up-right   | -Y                         |
| `Door_DownLeft`  | down-left  | +Y                         |
| `Door_DownRight` | down-right | +X                         |
| `Door_UpLeft`    | up-left    | -X                         |

Compass names were tried first and dropped: in isometric, "north" reads as
either -Y in tile space or straight up on screen, and those are 45 degrees
apart. Screen-relative names cannot be misread.

## Corridors

Rooms only connect to orthogonal neighbours, so corridors are always straight —
isometric tiles cannot be rotated, so corners would need their own prefabs.

- `CorridorDownRight.tscn` — runs down-right on screen (tile +X), carries
  `Door_UpLeft` and `Door_DownRight`
- `CorridorDownLeft.tscn` — runs down-left on screen (tile +Y), carries
  `Door_UpRight` and `Door_DownLeft`

Same layer structure as a room. Pick whatever fixed length tiles evenly for the
walls; the generator repeats the prefab to span a gap.

## Start with one room and one corridor

Enough to wire the generator against and render. If the door convention above is
wrong, that is one room to redo instead of five.
