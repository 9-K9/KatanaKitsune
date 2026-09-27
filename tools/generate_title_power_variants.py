#!/usr/bin/env python3
"""Create exact title-cover variants by recoloring only Katana Kitsune's red clothing."""

from pathlib import Path
from collections import deque

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("/mnt/K-DRIVE/Pictures/PixAI/KatanaKitsune/CoverTitle.png")
OUTPUT = ROOT / "assets/sprites/ui/title_power_states"

PALETTES = {
    "01_Wood_JadeDragon": ((4, 38, 23), (48, 196, 105)),
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


def polygon_mask(size: tuple[int, int]) -> np.ndarray:
    width, height = size
    sx, sy = width / 1632.0, height / 912.0

    regions = (
        # Left sleeve and shoulder.
        ((760, 340), (905, 305), (1055, 360), (1080, 500), (945, 535), (790, 465)),
        # Collar, torso panels and diagonal sash.
        ((970, 255), (1255, 235), (1385, 345), (1395, 575), (1240, 650), (1050, 580), (940, 390)),
        # Right sleeve.
        ((1240, 280), (1405, 305), (1505, 485), (1485, 670), (1395, 760), (1300, 705), (1250, 515)),
        # Lower jacket tails visible beneath the seated body.
        ((720, 650), (965, 620), (1040, 755), (910, 805), (730, 775)),
        # Red waist/sash area around the sword mount.
        ((930, 425), (1195, 375), (1295, 630), (1190, 710), (1010, 610)),
    )

    mask_image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask_image)
    for polygon in regions:
        draw.polygon([(round(x * sx), round(y * sy)) for x, y in polygon], fill=255)

    # Preserve the face and lips even if the broad torso polygon overlaps them.
    draw.ellipse((round(1010 * sx), round(100 * sy), round(1280 * sx), round(345 * sy)), fill=0)
    return np.asarray(mask_image) > 0


def clothing_mask(image: Image.Image) -> np.ndarray:
    pixels = np.asarray(image)
    rgb = pixels[:, :, :3].astype(np.int16)
    alpha = pixels[:, :, 3]
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = (maximum - minimum) / np.maximum(maximum, 1)
    red = (
        (alpha > 0)
        & (rgb[:, :, 0] == maximum)
        & (rgb[:, :, 0] > 45)
        & (saturation > 0.66)
        & (rgb[:, :, 1] < rgb[:, :, 0] * 0.52)
        & (rgb[:, :, 2] < rgb[:, :, 0] * 0.48)
    )
    candidates = red & polygon_mask(image.size)

    sx, sy = image.width / 1632.0, image.height / 912.0
    garment_seeds = (
        (845, 395), (900, 430), (980, 410),
        (1080, 350), (1160, 330), (1240, 340), (1310, 390),
        (1360, 385), (1420, 470), (1430, 570), (1390, 650),
        (1080, 430), (1180, 470), (1230, 540),
        (810, 720), (900, 720),
    )

    selected = np.zeros_like(candidates)
    queue: deque[tuple[int, int]] = deque()
    for seed_x, seed_y in garment_seeds:
        cx, cy = round(seed_x * sx), round(seed_y * sy)
        nearest: tuple[int, int] | None = None
        nearest_distance = 10**9
        radius = max(8, round(28 * max(sx, sy)))
        for y in range(max(0, cy - radius), min(image.height, cy + radius + 1)):
            for x in range(max(0, cx - radius), min(image.width, cx + radius + 1)):
                if candidates[y, x]:
                    distance = (x - cx) ** 2 + (y - cy) ** 2
                    if distance < nearest_distance:
                        nearest = (x, y)
                        nearest_distance = distance
        if nearest is not None:
            queue.append(nearest)

    while queue:
        x, y = queue.popleft()
        if selected[y, x] or not candidates[y, x]:
            continue
        selected[y, x] = True
        for ny in range(max(0, y - 1), min(image.height, y + 2)):
            for nx in range(max(0, x - 1), min(image.width, x + 2)):
                if candidates[ny, nx] and not selected[ny, nx]:
                    queue.append((nx, ny))
    return selected


def apply_palette(image: Image.Image, mask: np.ndarray, ramp: tuple[tuple[int, int, int], tuple[int, int, int]]) -> Image.Image:
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    brightness = rgb.max(axis=2)
    amount = np.clip((brightness - 35.0) / 205.0, 0.0, 1.0)
    shadow = np.array(ramp[0], dtype=np.float32)
    highlight = np.array(ramp[1], dtype=np.float32)
    recolored = shadow + amount[:, :, None] * (highlight - shadow)
    pixels[:, :, :3][mask] = np.clip(recolored[mask], 0, 255).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def make_mask_preview(image: Image.Image, mask: np.ndarray) -> None:
    overlay = np.asarray(image).copy()
    overlay[:, :, :3][mask] = (
        overlay[:, :, :3][mask].astype(np.float32) * 0.35
        + np.array((0, 255, 255), dtype=np.float32) * 0.65
    ).astype(np.uint8)
    Image.fromarray(overlay, "RGBA").save(OUTPUT / "clothing_mask_preview.png", optimize=True)


def make_preview() -> None:
    cells: list[Image.Image] = []
    for state in PALETTES:
        image = Image.open(OUTPUT / state / "title_cover_768x432.png").convert("RGBA")
        image = image.resize((384, 216), Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (400, 244), (30, 31, 37, 255))
        cell.alpha_composite(image, (8, 24))
        label = state.split("_", 1)[1].replace("_", " ")
        ImageDraw.Draw(cell).text((8, 6), label, fill=(242, 242, 246, 255))
        cells.append(cell)

    preview = Image.new("RGBA", (1600, 732), (30, 31, 37, 255))
    for index, cell in enumerate(cells):
        preview.alpha_composite(cell, ((index % 4) * 400, (index // 4) * 244))
    preview.save(OUTPUT / "preview_11_title_variants.png", optimize=True)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    mask = clothing_mask(image)
    make_mask_preview(image, mask)

    for state, ramp in PALETTES.items():
        state_dir = OUTPUT / state
        state_dir.mkdir(parents=True, exist_ok=True)
        master = apply_palette(image, mask, ramp)
        master.save(state_dir / "title_cover_master.png", optimize=True)
        master.resize((768, 432), Image.Resampling.LANCZOS).save(
            state_dir / "title_cover_768x432.png", optimize=True
        )
    make_preview()


if __name__ == "__main__":
    main()
