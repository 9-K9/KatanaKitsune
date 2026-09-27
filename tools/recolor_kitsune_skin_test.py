#!/usr/bin/env python3
"""Create a skin-only Katana Kitsune palette test."""

from pathlib import Path
from collections import deque

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/characters/_tests/AzureKitsune"
OUTPUT = ROOT / "assets/sprites/characters/_tests/GoldenKitsune"

SKIN_PALETTE = {
    (108, 64, 48): (94, 65, 76),
    (137, 82, 61): (153, 108, 116),
    (167, 110, 88): (204, 157, 158),
    (196, 137, 116): (238, 198, 190),
    (238, 170, 142): (255, 232, 216),
}


def recolor_frame(frame: Image.Image) -> Image.Image:
    output = frame.copy()
    candidates: set[tuple[int, int]] = set()
    seeds: set[tuple[int, int]] = set()
    bright_skin = {(196, 137, 116), (238, 170, 142)}

    for y in range(frame.height):
        for x in range(frame.width):
            rgb = frame.getpixel((x, y))[:3]
            if rgb in SKIN_PALETTE:
                candidates.add((x, y))
                if rgb in bright_skin:
                    seeds.add((x, y))

    selected: set[tuple[int, int]] = set()
    queue = deque(seeds)
    while queue:
        point = queue.popleft()
        if point in selected or point not in candidates:
            continue
        selected.add(point)
        x, y = point
        for neighbor in (
            (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
            (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
        ):
            if neighbor in candidates and neighbor not in selected:
                queue.append(neighbor)

    for x, y in selected:
        r, g, b, a = frame.getpixel((x, y))
        output.putpixel((x, y), (*SKIN_PALETTE[(r, g, b)], a))

    return output


def recolor(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    frame_width = 480 if image.width % 480 == 0 and image.height == 480 else image.width
    output = Image.new("RGBA", image.size)
    for left in range(0, image.width, frame_width):
        frame = image.crop((left, 0, left + frame_width, image.height))
        output.alpha_composite(recolor_frame(frame), (left, 0))
    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination, optimize=True)


def main() -> None:
    source_dir = SOURCE / "sprites/IdleStanding"
    output_dir = OUTPUT / "sprites/IdleStanding"
    for source in sorted(source_dir.glob("*.png")):
        name = source.name.replace("AzureKitsune", "GoldenKitsune")
        recolor(source, output_dir / name)
    recolor(SOURCE / "HUDicon.png", OUTPUT / "HUDicon.png")


if __name__ == "__main__":
    main()
