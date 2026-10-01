#!/usr/bin/env python3
"""Generate material-matched pillar sprites from the project's locked pillar silhouette."""

from pathlib import Path
from PIL import Image
import colorsys
import math
import random


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "assets/sprites/props/pillar.png"
WALLS = ROOT / "assets/crocotile/isometrictiles/walls"
OUT = ROOT / "assets/sprites/props/pillars"
MATERIALS = """rusticBrick cement cementBurnt whiteMarble japanese chinaTown chinese casino arcadeGame computerScreen blackAsylumn whiteAsylumn chainPrison slum schoolBrick bathroom toilet supermarket apartment glass woodenWall rusticWooden metalic rustedMetalic stainedMetalic aluminiumMetalic greenMetalic whiteMetalic chainMetal metalicFence metalicGate scifiBlack scifiBlue scifiBlackBlue scifiMetal devils snakeEdge porcelinWhite rubixGame green white wood&Blue wood&Brick""".split()


def luminance(c):
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]


def source_for(material):
    names = [f"{material}Wall_dir1.png", f"{material}_dir1.png"]
    for name in names:
        p = WALLS / name
        if p.exists():
            return p
    raise FileNotFoundError(material)


def palette_from_wall(path, levels=12):
    im = Image.open(path).convert("RGBA")
    colors = [px[:3] for px in im.getdata() if px[3] > 220]
    # Ignore near-black structural outlines when estimating the material ramp.
    body = [c for c in colors if luminance(c) > 14] or colors
    body.sort(key=luminance)
    ramp = []
    for i in range(levels):
        q = i / (levels - 1)
        center = int(q * (len(body) - 1))
        lo, hi = max(0, center - 80), min(len(body), center + 81)
        sample = body[lo:hi]
        ramp.append(tuple(sum(c[k] for c in sample) // len(sample) for k in range(3)))
    # Preserve a strong dungeon-tile outline.
    darkest = min(colors, key=luminance)
    ramp[0] = tuple(min(28, v) for v in darkest)
    return ramp


def nearest_level(value, values):
    return min(range(len(values)), key=lambda i: abs(values[i] - value))


def tint(c, factor):
    return tuple(max(0, min(255, round(v * factor))) for v in c)


def generate(material):
    src = Image.open(TEMPLATE).convert("RGBA")
    ramp = palette_from_wall(source_for(material))
    opaque_lums = sorted(luminance(px[:3]) for px in src.getdata() if px[3])
    cuts = [opaque_lums[round(i * (len(opaque_lums)-1) / 11)] for i in range(12)]
    dst = Image.new("RGBA", src.size)
    sp, dp = src.load(), dst.load()
    for y in range(160):
        for x in range(160):
            r, g, b, a = sp[x, y]
            if not a:
                continue
            idx = nearest_level(luminance((r, g, b)), cuts)
            dp[x, y] = (*ramp[idx], 255)

    # Material-specific pixel clusters on the shaft only; silhouette never changes.
    rng = random.Random(material)
    accent_dark, accent_mid, accent_light = ramp[2], ramp[6], ramp[10]
    shaft = lambda x, y: 57 <= x <= 103 and 42 <= y <= 121 and sp[x, y][3] > 0

    brick = {"rusticBrick", "schoolBrick", "cementBurnt", "apartment", "slum"}
    tile = {"bathroom", "toilet", "supermarket", "porcelinWhite", "whiteMarble"}
    metal = {"metalic", "rustedMetalic", "stainedMetalic", "aluminiumMetalic", "greenMetalic", "whiteMetalic", "scifiMetal"}
    screens = {"arcadeGame", "computerScreen", "casino", "rubixGame", "scifiBlue", "scifiBlackBlue"}
    wood = {"woodenWall", "rusticWooden", "japanese", "chinaTown", "chinese"}

    if material in brick:
        for y in range(49, 120, 12):
            for x in range(58, 104):
                if shaft(x, y): dp[x, y] = (*accent_dark, 255)
            offset = 11 if (y // 12) % 2 else 0
            for x in range(64 + offset, 103, 22):
                for yy in range(y, min(y + 12, 121)):
                    if shaft(x, yy): dp[x, yy] = (*accent_dark, 255)
    elif material in tile:
        for y in range(52, 121, 17):
            for x in range(58, 103):
                if shaft(x, y): dp[x, y] = (*accent_dark, 255)
        for x in range(68, 104, 18):
            for y in range(43, 121):
                if shaft(x, y): dp[x, y] = (*accent_dark, 255)
    elif material in metal:
        for y in (56, 82, 108):
            for x in range(58, 103):
                if shaft(x, y): dp[x, y] = (*accent_dark, 255)
        for x, y in ((63, 50), (96, 50), (63, 76), (96, 76), (63, 102), (96, 102)):
            if shaft(x, y): dp[x, y] = (*accent_light, 255)
    elif material in screens:
        for y in range(49, 114, 22):
            for yy in range(y, y + 14):
                for x in range(64, 97):
                    if shaft(x, yy) and (x in (64, 96) or yy in (y, y+13)):
                        dp[x, yy] = (*accent_dark, 255)
            for x in range(69, 93, 6):
                if shaft(x, y+6): dp[x, y+6] = (*accent_light, 255)
    elif material in wood:
        for x in (69, 82, 95):
            for y in range(43, 121):
                if shaft(x, y): dp[x, y] = (*accent_dark, 255)
        for _ in range(18):
            x, y = rng.randrange(61, 100), rng.randrange(46, 118)
            if shaft(x, y): dp[x, y] = (*accent_light, 255)
    elif material in {"chainPrison", "chainMetal", "metalicFence", "metalicGate"}:
        for y in range(45, 120, 8):
            for x in range(59, 102):
                if shaft(x, y) and ((x + y) % 8 in (0, 1) or (x - y) % 8 in (0, 1)):
                    dp[x, y] = (*accent_light, 255)
    elif material in {"devils", "snakeEdge"}:
        for y in range(49, 116, 14):
            for x in range(63, 98):
                if shaft(x, y + abs(x-80)//5): dp[x, y + abs(x-80)//5] = (*accent_light, 255)
    else:
        for _ in range(28):
            x, y = rng.randrange(60, 101), rng.randrange(44, 120)
            if shaft(x, y): dp[x, y] = (*ramp[rng.randrange(3, 10)], 255)

    OUT.mkdir(parents=True, exist_ok=True)
    dst.save(OUT / f"pillar_{material}.png", optimize=True)


if __name__ == "__main__":
    for name in MATERIALS:
        generate(name)
    print(f"Generated {len(MATERIALS)} pillars in {OUT}")
