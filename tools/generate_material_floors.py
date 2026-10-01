#!/usr/bin/env python3
"""Generate eight geometry-locked isometric floor frames for each wall material."""

from pathlib import Path
from PIL import Image
import colorsys
import bisect
import math
import random


ROOT = Path(__file__).resolve().parents[1]
GROUNDS = ROOT / "assets/crocotile/isometrictiles/grounds"
WALLS = ROOT / "assets/crocotile/isometrictiles/walls"
MATERIALS = """rusticBrick cement cementBurnt whiteMarble japanese chinaTown chinese casino arcadeGame computerScreen blackAsylumn whiteAsylumn chainPrison slum schoolBrick bathroom toilet supermarket apartment glass wooden rusticWooden metalic rustedMetalic stainedMetalic aluminiumMetalic greenMetalic whiteMetalic chainMetal metalicFence metalicGate scifiBlack scifiBlue scifiBlackBlue scifiMetal devils snakeEdge porcelinWhite rubixGame green white wood&Blue wood&Brick""".split()


def lum(c):
    return .2126*c[0] + .7152*c[1] + .0722*c[2]


def source_for(material):
    stems = [material, material + "Wall"] if material == "wooden" else [material + "Wall", material]
    for stem in stems:
        p = WALLS / f"{stem}_dir1.png"
        if p.exists():
            return p
    raise FileNotFoundError(f"No wall reference for {material}")


def wall_palette(material, n=10):
    im = Image.open(source_for(material)).convert("RGBA")
    colors = [p[:3] for p in im.getdata() if p[3] == 255 and lum(p[:3]) > 10]
    colors.sort(key=lum)
    ramp = []
    for i in range(n):
        at = round(i*(len(colors)-1)/(n-1))
        sample = colors[max(0, at-64):min(len(colors), at+65)]
        ramp.append(tuple(sum(c[k] for c in sample)//len(sample) for k in range(3)))
    return ramp


def hsv_shift(c, sat=1.0, val=1.0):
    h,s,v = colorsys.rgb_to_hsv(*(x/255 for x in c))
    r,g,b = colorsys.hsv_to_rgb(h, min(1,s*sat), min(1,v*val))
    return tuple(round(x*255) for x in (r,g,b))


def mix(a,b,t):
    return tuple(round(a[i]*(1-t)+b[i]*t) for i in range(3))


def pattern(material, u, v, ramp, seed):
    """Return a top-face color in canonical floor coordinates."""
    dark, low, mid, high, bright = ramp[1], ramp[3], ramp[5], ramp[7], ramp[9]
    brick = {"rusticBrick", "schoolBrick"}
    concrete = {"cement", "cementBurnt", "slum"}
    tile = {"bathroom", "toilet", "porcelinWhite", "supermarket"}
    wood = {"wooden", "rusticWooden", "apartment"}
    metal = {"metalic", "aluminiumMetalic", "greenMetalic", "whiteMetalic"}
    sci = {"scifiBlack", "scifiBlue", "scifiBlackBlue", "scifiMetal"}
    mesh = {"chainPrison", "chainMetal", "metalicFence", "metalicGate"}

    if material in brick:
        row = (v+24)//7
        x = u + (4 if row%2 else 0)
        return dark if v%7 in (0,1) or x%12 in (0,1) else (high if (u+v)%9==0 else mid)
    if material in concrete:
        crack = ((u*5 + v*3 + seed) % 31 == 0) or ((u-v+seed)%37 == 0 and v%3==0)
        grit = (u*13+v*7+seed)%17==0
        return dark if crack else (high if grit else mid)
    if material == "whiteMarble":
        vein = abs(((u*2 + v*5 + seed)%29)-14) <= 1
        return low if vein else (bright if (u+v)%5 else high)
    if material == "japanese":
        border = u%16 in (0,1) or v%12 in (0,1)
        weave = (u+v)%4==0
        return dark if border else (bright if weave else high)
    if material in {"chinaTown", "chinese"}:
        lattice = u%10 in (0,1) or v%10 in (0,1) or (u-v)%18==0
        return bright if lattice else mid
    if material == "casino":
        diamond = (abs(u%14-7)+abs(v%14-7)) in (5,6)
        dot = u%14==7 and v%14==7
        return bright if dot else (dark if diamond else mid)
    if material in {"arcadeGame", "computerScreen"}:
        grid = u%8==0 or v%8==0
        pulse = (u*3+v*5+seed)%23==0
        return dark if grid else (bright if pulse else mid)
    if material in {"blackAsylumn", "whiteAsylumn"}:
        checker = ((u//8)+(v//8))%2
        stain = (u*11+v*7+seed)%41==0
        return dark if stain else (low if checker else high)
    if material in mesh:
        bars = (u+v)%8 in (0,1) or (u-v)%8 in (0,1)
        return bright if bars else dark
    if material == "stainedMetalic":
        stain = (u*u + v*7 + seed)%29 < 6
        seam = u%16==0 or v%16==0
        return dark if stain else (low if seam else mid)
    if material == "rustedMetalic":
        rust = (u*7+v*11+seed)%19 < 5
        seam = u%16 in (0,1) or v%16 in (0,1)
        return dark if seam else (low if rust else high)
    if material in metal:
        seam = u%16 in (0,1) or v%16 in (0,1)
        rivet = u%16==3 and v%16==3
        return bright if rivet else (dark if seam else mid)
    if material in sci:
        grate = u%7 in (0,1) or v%14 in (0,1)
        light = v%14==7 and u%14 in (6,7,8)
        return bright if light else (dark if grate else mid)
    if material in tile:
        size = 10 if material != "supermarket" else 14
        grout = u%size in (0,1) or v%size in (0,1)
        fleck = (u*9+v*5+seed)%43==0
        return dark if grout else (bright if fleck else high)
    if material in wood:
        plank = v%8 in (0,1)
        joint = u%18==0 and (v//8)%2==0
        grain = (u*7+v+seed)%23==0
        return dark if plank or joint else (high if grain else mid)
    if material == "glass":
        seam = u%16==0 or v%16==0
        shine = (u-v)%19 in (0,1)
        return dark if seam else (bright if shine else high)
    if material == "devils":
        fissure = abs(((u*3+v*5+seed)%23)-11) <= 1
        return bright if fissure else dark
    if material == "snakeEdge":
        scale = ((u+(v//5)*4)%10 in (0,1)) or v%5==0
        return dark if scale else high
    if material == "rubixGame":
        # Deliberately multicolored while staying within a compact game-tile palette.
        colors = ((220,45,38),(245,190,30),(35,170,75),(35,105,220),(235,235,225),(230,95,25))
        return dark if u%8==0 or v%8==0 else colors[((u//8)+(v//8)*3)%len(colors)]
    if material == "green":
        return high if (u*5+v*3+seed)%13 else bright
    if material == "white":
        return bright if (u+v)%7 else high
    return high


def top_coords(direction, x, y):
    diagonal = direction % 2 == 1
    hw, hh = (24.0, 12.0) if diagonal else (17.0, 8.0)
    cx, cy = 47.5, 45.0
    dx, dy = x-cx, y-cy
    inside = abs(dx)/hw + abs(dy)/hh <= .88
    # Inverse isometric mapping, then rotate the material with PixelOver's direction.
    u, v = dx + 2*dy, -dx + 2*dy
    a = -math.radians((direction-1)*45)
    return inside, round(u*math.cos(a)-v*math.sin(a)), round(u*math.sin(a)+v*math.cos(a))


def generate(material, direction):
    template = Image.open(GROUNDS / f"checkeredFloorIsometric_dir{direction}.png").convert("RGBA")
    ramp = wall_palette(material)
    out = Image.new("RGBA", template.size)
    tp, op = template.load(), out.load()
    seed = sum((i+1)*ord(c) for i,c in enumerate(material))
    opaque_lums = sorted(lum(p[:3]) for p in template.getdata() if p[3])
    for y in range(96):
        for x in range(96):
            r,g,b,a = tp[x,y]
            if not a:
                continue
            is_top,u,v = top_coords(direction,x,y)
            if is_top:
                c = pattern(material,u,v,ramp,seed)
            elif lum((r,g,b)) < 8:
                c = (8,10,11)  # Locked hard outline.
            else:
                # Recolor the visible slab thickness with a dark material ramp.
                rank = bisect.bisect_right(opaque_lums, lum((r,g,b))) / len(opaque_lums)
                c = ramp[min(4, max(0, int(rank*5)))]
                if x < 48: c = hsv_shift(c, 1.0, 1.08)  # upper-left light
                else: c = hsv_shift(c, 1.0, .78)
            op[x,y] = (*c,255)
    out.save(GROUNDS / f"{material}Floor_dir{direction}.png", optimize=True)


if __name__ == "__main__":
    for material in MATERIALS:
        for direction in range(1,9):
            generate(material,direction)
    print(f"Generated {len(MATERIALS)*8} floor sprites in {GROUNDS}")
