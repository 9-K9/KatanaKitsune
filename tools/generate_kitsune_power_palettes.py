#!/usr/bin/env python3
"""Generate clothing-only elemental power-state palettes for Katana Kitsune."""

from collections import deque
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/characters/KatanaKitsune"
OUTPUT = SOURCE / "power_states"

# Shadow and highlight ramps. The five classical Chinese elements come first,
# followed by seven mythology-inspired power states.
PALETTES = {
    "01_Wood_JadeDragon": ((4, 38, 23), (48, 196, 105)),
    "02_Fire_VermilionPhoenix": ((72, 4, 1), (242, 58, 20)),
    "03_Earth_GoldenQilin": ((65, 34, 4), (218, 154, 31)),
    "04_Metal_WhiteTiger": ((42, 48, 60), (224, 234, 240)),
    "05_Water_BlackTortoise": ((3, 18, 58), (29, 116, 226)),
    "06_Lightning_ThunderDragon": ((34, 13, 78), (177, 91, 255)),
    "07_Ice_MoonFrost": ((16, 61, 88), (158, 237, 255)),
    "08_Darkness_Eclipse": ((12, 5, 21), (91, 34, 118)),
    "09_Light_SolarYang": ((93, 61, 18), (255, 239, 159)),
    "10_Wind_AzureGale": ((0, 56, 61), (70, 224, 203)),
    "11_Poison_JadeSerpent": ((31, 52, 5), (159, 219, 34)),
    "12_Spirit_CelestialQi": ((70, 17, 63), (245, 99, 207)),
}


def face_box(frame: Image.Image) -> tuple[int, int, int, int] | None:
    bbox = frame.getbbox()
    if bbox is None:
        return None
    upper_limit = bbox[1] + round((bbox[3] - bbox[1]) * 0.55)
    candidates: set[tuple[int, int]] = set()
    for y in range(bbox[1], upper_limit):
        for x in range(bbox[0], bbox[2]):
            r, g, b, a = frame.getpixel((x, y))
            if a > 32 and r > 75 and r > g * 1.18 and g > b * 1.08 and 20 < g < 190:
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

    face = min(
        components,
        key=lambda points: sum(point[1] for point in points) / len(points),
        default=[],
    )
    if not face:
        return None
    return (
        min(point[0] for point in face) - 3,
        min(point[1] for point in face) - 3,
        max(point[0] for point in face) + 4,
        max(point[1] for point in face) + 4,
    )


def clothing_mask(image: Image.Image) -> np.ndarray:
    pixels = np.asarray(image)
    rgb = pixels[:, :, :3].astype(np.int16)
    alpha = pixels[:, :, 3]
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = (maximum - minimum) / np.maximum(maximum, 1)
    mask = (
        (alpha > 0)
        & (rgb[:, :, 0] == maximum)
        & (rgb[:, :, 0] > 35)
        & (saturation > 0.72)
        & (rgb[:, :, 1] < rgb[:, :, 0] * 0.42)
        & (rgb[:, :, 2] < rgb[:, :, 0] * 0.35)
    )

    frame_width = 480 if image.width % 480 == 0 and image.height == 480 else image.width
    for left in range(0, image.width, frame_width):
        frame = image.crop((left, 0, left + frame_width, image.height))
        protected = face_box(frame)
        if protected is not None:
            x1, y1, x2, y2 = protected
            mask[max(0, y1):min(image.height, y2), left + max(0, x1):left + min(frame_width, x2)] = False
    return mask


def apply_palette(image: Image.Image, mask: np.ndarray, ramp: tuple[tuple[int, int, int], tuple[int, int, int]]) -> Image.Image:
    pixels = np.asarray(image).copy()
    source_red = pixels[:, :, 0].astype(np.float32)
    amount = np.clip((source_red - 45.0) / 85.0, 0.0, 1.0)
    shadow = np.array(ramp[0], dtype=np.float32)
    highlight = np.array(ramp[1], dtype=np.float32)
    recolored = shadow + amount[:, :, None] * (highlight - shadow)
    pixels[:, :, :3][mask] = np.clip(recolored[mask], 0, 255).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def generate_asset(source: Path, relative_destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    mask = clothing_mask(image)
    for state, ramp in PALETTES.items():
        destination = OUTPUT / state / relative_destination
        destination.parent.mkdir(parents=True, exist_ok=True)
        apply_palette(image, mask, ramp).save(destination, optimize=True)


def make_preview() -> None:
    cells: list[Image.Image] = []
    for state in PALETTES:
        sheet = OUTPUT / state / "sprites/IdleStanding" / "KatanaKitsume_IdleStanding_dir1.png"
        frame = Image.open(sheet).convert("RGBA").crop((0, 0, 480, 480))
        bbox = frame.getbbox()
        if bbox is None:
            continue
        bbox = (max(0, bbox[0] - 6), max(0, bbox[1] - 6), min(480, bbox[2] + 6), min(480, bbox[3] + 6))
        frame = frame.crop(bbox).resize(((bbox[2] - bbox[0]) * 4, (bbox[3] - bbox[1]) * 4), Image.Resampling.NEAREST)
        cell = Image.new("RGBA", (280, 430), (36, 38, 44, 255))
        cell.alpha_composite(frame, ((280 - frame.width) // 2, max(24, (410 - frame.height) // 2)))
        label = state.split("_", 1)[1].replace("_", " ")
        ImageDraw.Draw(cell).text((8, 8), label, fill=(240, 240, 244, 255))
        cells.append(cell)

    preview = Image.new("RGBA", (1120, 1290), (36, 38, 44, 255))
    for index, cell in enumerate(cells):
        preview.alpha_composite(cell, ((index % 4) * 280, (index // 4) * 430))
    preview.save(OUTPUT / "preview_12_power_states.png", optimize=True)


def main() -> None:
    animation_dirs = sorted(path for path in (SOURCE / "sprites").iterdir() if path.is_dir())
    for animation_index, animation_dir in enumerate(animation_dirs, start=1):
        sources = sorted(animation_dir.glob("*.png"))
        print(f"[{animation_index:02d}/{len(animation_dirs):02d}] {animation_dir.name}: {len(sources)} directions", flush=True)
        for source in sources:
            image = Image.open(source).convert("RGBA")
            mask = clothing_mask(image)
            for state, ramp in PALETTES.items():
                destination = OUTPUT / state / "sprites" / animation_dir.name / source.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                apply_palette(image, mask, ramp).save(destination, compress_level=6)

    hud = Image.open(SOURCE / "HUDicon.png").convert("RGBA")
    hud_mask = clothing_mask(hud)
    for state, ramp in PALETTES.items():
        destination = OUTPUT / state / "HUDicon.png"
        apply_palette(hud, hud_mask, ramp).save(destination, compress_level=6)

    manifest = {
        "base_character": "KatanaKitsune",
        "frame_size": [480, 480],
        "frames_per_sheet": 8,
        "directions": 8,
        "animations": [path.name for path in animation_dirs],
        "states": [
            {
                "id": state,
                "name": state.split("_", 1)[1].replace("_", " "),
                "path": state,
            }
            for state in PALETTES
        ],
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "power_states_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    make_preview()


if __name__ == "__main__":
    main()
