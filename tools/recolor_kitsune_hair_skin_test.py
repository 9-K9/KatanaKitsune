#!/usr/bin/env python3
"""Test skin and hair recoloring while preserving Katana Kitsune frame geometry."""

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/characters/_tests/AzureKitsune"
OUTPUT = ROOT / "assets/sprites/characters/_tests/VioletKitsune"

SKIN_SOURCE = (
    (108, 64, 48),
    (137, 82, 61),
    (167, 110, 88),
    (196, 137, 116),
    (238, 170, 142),
)
SKIN_TARGET = (
    (112, 73, 60),
    (154, 105, 83),
    (190, 139, 110),
    (222, 174, 141),
    (250, 211, 177),
)


def nearest_skin(rgb: tuple[int, int, int]) -> tuple[int, int, int] | None:
    distances = [sum((rgb[i] - sample[i]) ** 2 for i in range(3)) for sample in SKIN_SOURCE]
    index = min(range(len(distances)), key=distances.__getitem__)
    return SKIN_TARGET[index] if distances[index] <= 11 * 11 else None


def skin_component(frame: Image.Image) -> list[tuple[int, int]]:
    candidates: set[tuple[int, int]] = set()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a > 32 and nearest_skin((r, g, b)) is not None:
                candidates.add((x, y))

    components: list[list[tuple[int, int]]] = []
    while candidates:
        start = candidates.pop()
        component = [start]
        queue = deque([start])
        while queue:
            px, py = queue.popleft()
            for neighbor in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                if neighbor in candidates:
                    candidates.remove(neighbor)
                    component.append(neighbor)
                    queue.append(neighbor)
        if len(component) >= 3:
            components.append(component)

    return min(
        components,
        key=lambda points: sum(point[1] for point in points) / len(points),
        default=[],
    )


def recolor_frame(frame: Image.Image) -> Image.Image:
    output = frame.copy()
    face = skin_component(frame)
    if not face:
        return output

    face_left = min(point[0] for point in face)
    face_top = min(point[1] for point in face)
    face_right = max(point[0] for point in face) + 1
    face_bottom = max(point[1] for point in face) + 1
    face_width = max(1, face_right - face_left)
    face_height = max(1, face_bottom - face_top)

    character_box = frame.getbbox()
    if character_box is None:
        return output
    hair_bottom = character_box[1] + round((character_box[3] - character_box[1]) * 0.72)

    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a == 0:
                continue

            skin = nearest_skin((r, g, b))
            if skin is not None:
                output.putpixel((x, y), (*skin, a))
                continue

            in_upper_silhouette = character_box[1] <= y < hair_bottom
            dark_hair_value = max(r, g, b) < 125 and r >= g >= b and r - b < 48
            if in_upper_silhouette and dark_hair_value:
                value = max(r, g, b) / 255.0
                nr = round((26 + value * 116))
                ng = round((20 + value * 94))
                nb = round((48 + value * 148))
                output.putpixel((x, y), (nr, ng, nb, a))

    return output


def recolor_strip(source: Path, destination: Path) -> None:
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
        name = source.name.replace("AzureKitsune", "VioletKitsune")
        recolor_strip(source, output_dir / name)
    recolor_strip(SOURCE / "HUDicon.png", OUTPUT / "HUDicon.png")


if __name__ == "__main__":
    main()
