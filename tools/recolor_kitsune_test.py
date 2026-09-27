#!/usr/bin/env python3
"""Create a small, frame-perfect Katana Kitsune palette-variant test."""

from pathlib import Path
import colorsys

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/characters/KatanaKitsune"
OUTPUT = ROOT / "assets/sprites/characters/_tests/AzureKitsune"
TEST_ANIMATIONS = (
    "IdleStanding",
    "Walking",
    "KatanaIdle",
    "KatanaSlashMid",
    "Death",
)


def recolor_pixel(
    pixel: tuple[int, int, int, int], *, protect_face: bool
) -> tuple[int, int, int, int]:
    r, g, b, a = pixel
    if a == 0:
        return pixel

    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)

    # Katana Kitsune's saturated crimson cloth becomes a blue-teal uniform.
    # Warm skin shades are protected by the high-saturation requirement.
    is_crimson_cloth = (h < 0.035 or h > 0.97) and s > 0.72 and r > 35
    if is_crimson_cloth and not protect_face:
        nr, ng, nb = colorsys.hsv_to_rgb(0.535, min(0.92, s), min(1.0, v * 1.06))
        return round(nr * 255), round(ng * 255), round(nb * 255), a

    # Shift small warm-gold equipment highlights toward cool moon-silver.
    is_gold_accent = 0.075 < h < 0.17 and s > 0.48 and v > 0.28
    if is_gold_accent:
        nr, ng, nb = colorsys.hsv_to_rgb(0.52, s * 0.42, min(1.0, v * 1.08))
        return round(nr * 255), round(ng * 255), round(nb * 255), a

    return pixel


def recolor(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    output = image.copy()
    frame_width = 480 if image.width % 480 == 0 and image.height == 480 else image.width

    for frame_left in range(0, image.width, frame_width):
        frame = image.crop((frame_left, 0, frame_left + frame_width, image.height))
        bbox = frame.getbbox()
        if bbox is None:
            continue

        upper_limit = bbox[1] + round((bbox[3] - bbox[1]) * 0.55)
        skin_points: set[tuple[int, int]] = set()
        for fy in range(bbox[1], upper_limit):
            for fx in range(bbox[0], bbox[2]):
                fr, fg, fb, fa = frame.getpixel((fx, fy))
                is_skin = (
                    fa > 32
                    and fr > 75
                    and fr > fg * 1.18
                    and fg > fb * 1.08
                    and 20 < fg < 190
                )
                if is_skin:
                    skin_points.add((fx, fy))

        components: list[list[tuple[int, int]]] = []
        remaining = set(skin_points)
        while remaining:
            start = remaining.pop()
            component = [start]
            stack = [start]
            while stack:
                px, py = stack.pop()
                for neighbor in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.append(neighbor)
                        stack.append(neighbor)
            if len(component) >= 3:
                components.append(component)

        face_points = min(
            components,
            key=lambda points: sum(point[1] for point in points) / len(points),
            default=[],
        )
        if face_points:
            face_box = (
                min(point[0] for point in face_points) - 3,
                min(point[1] for point in face_points) - 3,
                max(point[0] for point in face_points) + 4,
                max(point[1] for point in face_points) + 4,
            )
        else:
            face_box = (0, 0, 0, 0)

        for local_y in range(image.height):
            for local_x in range(frame_width):
                x = frame_left + local_x
                pixel = image.getpixel((x, local_y))
                protect_face = (
                    face_box[0] <= local_x < face_box[2]
                    and face_box[1] <= local_y < face_box[3]
                )
                output.putpixel(
                    (x, local_y),
                    recolor_pixel(pixel, protect_face=protect_face),
                )

    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination, optimize=True)


def main() -> None:
    for animation in TEST_ANIMATIONS:
        animation_source = SOURCE / "sprites" / animation
        animation_output = OUTPUT / "sprites" / animation
        for source in sorted(animation_source.glob("*.png")):
            destination_name = source.name.replace("KatanaKitsume", "AzureKitsune")
            recolor(source, animation_output / destination_name)

    recolor(SOURCE / "HUDicon.png", OUTPUT / "HUDicon.png")


if __name__ == "__main__":
    main()
