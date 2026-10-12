#!/usr/bin/env python3
"""Create exact title-cover variants by recoloring only Katana Kitsune's red clothing."""

from pathlib import Path
import argparse

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


TAIL_REGIONS = (
    ((375, 366), (398, 361), (411, 351), (429, 355), (449, 365),
     (470, 375), (482, 382), (475, 384), (375, 383)),
    ((665, 357), (684, 351), (699, 370), (716, 376), (740, 373),
     (769, 374), (799, 379), (823, 387), (823, 388), (704, 388), (664, 376)),
)


def polygon_mask(size: tuple[int, int], tails_only: bool = False) -> np.ndarray:
    width, height = size
    sx, sy = width / 838.0, height / 469.0

    regions = (
        # Raised sleeve: its upper edge stays below the red gate behind it.
        ((480, 216), (499, 216), (521, 202), (538, 188), (550, 186),
         (554, 208), (545, 229), (540, 257), (539, 280), (535, 291),
         (518, 280), (505, 262), (488, 252), (481, 240)),
        # Collar, jacket panels and sash, bounded by the character silhouette.
        ((539, 198), (565, 181), (589, 161), (590, 150), (614, 153),
         (640, 165), (665, 166), (683, 181), (696, 209), (690, 248),
         (654, 257), (639, 280), (627, 292), (607, 285), (558, 263),
         (534, 269), (528, 233)),
        # Hanging sleeve ends at the black cuff, not the wrist or stone.
        ((650, 218), (686, 216), (695, 248), (707, 281), (716, 322),
         (699, 328), (679, 340), (661, 332), (650, 286)),
        # Sash and sword mount retain their original palette treatment.
        ((546, 237), (582, 255), (612, 280), (639, 302), (673, 376),
         (656, 386), (628, 349), (597, 319), (565, 284), (533, 262)),
    )

    mask_image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask_image)
    for polygon in TAIL_REGIONS if tails_only else regions + TAIL_REGIONS:
        draw.polygon([(round(x * sx), round(y * sy)) for x, y in polygon], fill=255)

    # Wrist and glove cross in front of the right jacket tail.
    draw.polygon(
        [(round(x * sx), round(y * sy)) for x, y in
         ((688, 337), (704, 332), (713, 361), (720, 372),
          (752, 374), (777, 385), (763, 389), (701, 388),
          (696, 372))],
        fill=0,
    )
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
    # Tail folds include low-saturation burgundy that the bright-red test misses.
    dark_burgundy = (
        (alpha > 0)
        & (saturation > 0.25)
        & (rgb[:, :, 0] > rgb[:, :, 1] * 1.3)
        & (rgb[:, :, 0] > rgb[:, :, 2] * 0.85)
        & (rgb[:, :, 2] > rgb[:, :, 1] * 1.2)
    )
    return (red & polygon_mask(image.size)) | (
        dark_burgundy & polygon_mask(image.size, tails_only=True)
    )


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


def make_mask_preview(image: Image.Image, mask: np.ndarray, directory: Path) -> None:
    overlay = np.asarray(image).copy()
    overlay[:, :, :3][mask] = (
        overlay[:, :, :3][mask].astype(np.float32) * 0.35
        + np.array((0, 255, 255), dtype=np.float32) * 0.65
    ).astype(np.uint8)
    directory.mkdir(parents=True, exist_ok=True)
    Image.fromarray(overlay, "RGBA").save(directory / "clothing_mask_preview.png", optimize=True)


def make_preview() -> None:
    cells: list[Image.Image] = []
    for state in PALETTES:
        image = Image.open(OUTPUT / state / "titleCover_768x432.png").convert("RGBA")
        image = image.resize((384, 216), Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (400, 244), (30, 31, 37, 255))
        cell.alpha_composite(image, (8, 24))
        label = state.split("_", 1)[1].replace("_", " ")
        ImageDraw.Draw(cell).text((8, 6), label, fill=(242, 242, 246, 255))
        cells.append(cell)

    preview = Image.new("RGBA", (1600, 732), (30, 31, 37, 255))
    for index, cell in enumerate(cells):
        preview.alpha_composite(cell, ((index % 4) * 400, (index // 4) * 244))
    preview.save(OUTPUT / "_preview_titleVariants.png", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diagnostics-dir", type=Path)
    args = parser.parse_args()
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (1677, 938):
        raise ValueError(f"Expected the original 1677x938 cover, got {image.size}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    mask = clothing_mask(image)
    if args.diagnostics_dir is not None:
        make_mask_preview(image, mask, args.diagnostics_dir)

    for state, ramp in PALETTES.items():
        state_dir = OUTPUT / state
        state_dir.mkdir(parents=True, exist_ok=True)
        master = apply_palette(image, mask, ramp)
        master.save(state_dir / "titleCover_1677x938.png", optimize=True)
        master.resize((768, 432), Image.Resampling.LANCZOS).save(
            state_dir / "titleCover_768x432.png", optimize=True
        )
    make_preview()


if __name__ == "__main__":
    main()
