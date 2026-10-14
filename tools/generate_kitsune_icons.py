#!/usr/bin/env python3
"""Render the Kitsune HUD icons: one neutral, one per elemental power state.

Mirrors the Katana Kitsune icon set in assets/sprites/characters/KatanaKitsune:
96x96, opaque, 1px black + 1px white frame, dark plum gradient, the heroine's
head-to-hem bust at 1:1 pixel scale with a 1px white outline.

The bust is frame 0 of Idle dir1 (standing, facing south-west). Each state is
recoloured with a NumPy port of shaders/powerState.gdshader driven by the exact
uniforms Kitsune.tscn sets (build_kitsune_character.SHADER_PARAMS) and the
ramps in scripts/system/PowerState.gd, so the icon matches what the shader does
to her in play. Does not launch Godot; writes the .import sidecars itself.

    python3 tools/generate_kitsune_icons.py            # dry run: /tmp preview only
    python3 tools/generate_kitsune_icons.py --apply    # write assets + sidecars
    python3 tools/generate_kitsune_icons.py --check    # shader-port regression
"""
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_kitsune_character import IMPORT_TEMPLATE, SHADER_PARAMS, Uids  # noqa: E402

GAME = Path(__file__).resolve().parent.parent
SOURCE = GAME / "assets/sprites/characters/Kitsune/sprites/Idle/Kitsune_Idle_dir1.png"
OUT_DIR = GAME / "assets/sprites/characters/Kitsune"
OUT_RES = "res://assets/sprites/characters/Kitsune"
POWER_STATE_GD = GAME / "scripts/system/PowerState.gd"
OLD_ICON = GAME / "assets/sprites/characters/KatanaKitsune/HUDicon.png"
OLD_SOURCE = GAME / "assets/sprites/characters/KatanaKitsune/sprites/IdleStanding/KatanaKitsune_IdleStanding_dir1.png"

CELL_W, CELL_H = 432, 342
ICON = 96
## Bust window in the 432x342 idle cell (frame 0): hair tips to skirt hem.
BUST = (190, 92, 254, 180)
## Vertical gradient sampled from the old icon's interior (top -> bottom).
GRAD_TOP, GRAD_BOTTOM = (69, 40, 60), (4, 2, 4)


## ---------------------------------------------------------------- shader port
def luma(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def shader_defaults() -> dict:
    """Uniform defaults as declared in powerState.gdshader (player path)."""
    return dict(
        enabled=True,
        shadow=np.array((72, 4, 1)) / 255, highlight=np.array((242, 58, 20)) / 255,
        clothing_min_red=0.137255, clothing_min_sat=0.72,
        clothing_max_green_ratio=0.42, clothing_max_blue_ratio=0.35,
        clothing_amount_offset=45.0, clothing_amount_range=85.0,
        fill_strays=False, stray_min_red=0.1, stray_min_sat=0.25, stray_neighbour_ratio=0.5,
        hair_skin_passes=True, recolor_hair=True, recolor_skin=True,
        hair_shadow=np.zeros(3), hair_highlight=np.array((168, 168, 168)) / 255,
        skin_shadow=np.array((108, 64, 48)) / 255, skin_highlight=np.array((238, 170, 142)) / 255,
        soften_highlights=True, soften_amount=0.85, spike_threshold=0.10, spike_range=0.35,
    )


def kitsune_params(ramp) -> dict:
    P = shader_defaults()
    for key, value in SHADER_PARAMS.items():
        P[key] = {"true": True, "false": False}.get(value, None)
        if P[key] is None:
            P[key] = float(value)
    P["shadow"], P["highlight"] = np.array(ramp[0]) / 255, np.array(ramp[1]) / 255
    return P


def clothing_key(c, P):
    rgb = c[..., :3]
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1 / 255)
    return ((c[..., 3] > 0) & (r >= mx) & (r > P["clothing_min_red"]) & (sat > P["clothing_min_sat"])
            & (g < r * P["clothing_max_green_ratio"]) & (b < r * P["clothing_max_blue_ratio"]))


def recolour(c, hair_ctx, P, stray_ctx=None):
    rgb = c[..., :3]
    a = c[..., 3]
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1 / 255)
    out = rgb.copy()
    done = a <= 0
    if P["enabled"]:
        cloth = clothing_key(c, P)
        if P["fill_strays"] and stray_ctx is not None:
            cloth |= ((~done) & ~cloth & stray_ctx & (r >= mx)
                      & (r > P["stray_min_red"]) & (sat > P["stray_min_sat"]))
        amt = np.clip((r * 255 - P["clothing_amount_offset"]) / P["clothing_amount_range"], 0, 1)[..., None]
        out[cloth] = (P["shadow"] + (P["highlight"] - P["shadow"]) * amt)[cloth]
        done |= cloth
    if not P["hair_skin_passes"]:
        return out
    if P["recolor_skin"]:
        gr, br = g / np.maximum(r, 1e-9), b / np.maximum(r, 1e-9)
        skin = ((~done) & (r > 0.078431) & (r > g) & (g > b)
                & (gr > 0.55) & (gr < 0.85) & (br > 0.40) & (br < 0.75))
        amt = np.clip((r * 255 - 20) / 220, 0, 1)[..., None]
        out[skin] = (P["skin_shadow"] + (P["skin_highlight"] - P["skin_shadow"]) * amt)[skin]
        done |= skin
    if P["recolor_hair"]:
        hair = (~done) & ((mx - mn) <= 0.035) & hair_ctx
        amt = np.clip(luma(rgb), 0, 1)[..., None]
        out[hair] = (P["hair_shadow"] + (P["hair_highlight"] - P["hair_shadow"]) * amt)[hair]
    return out


def shade(img: Image.Image, P: dict) -> Image.Image:
    im = np.array(img.convert("RGBA")).astype(float) / 255
    H, W, _ = im.shape
    pad = np.zeros((H + 2, W + 2, 4))
    pad[1:-1, 1:-1] = im
    nb = np.stack([pad[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx, dy) != (0, 0)])
    nop = nb[..., 3] > 0
    ngrey = nop & ((nb[..., :3].max(-1) - nb[..., :3].min(-1)) <= 0.035)
    opaque_n, grey_n = nop.sum(0), ngrey.sum(0)
    hair_ctx = (opaque_n < 3) | ((grey_n / np.maximum(opaque_n, 1)) >= 0.5)
    keyed_n = np.stack([clothing_key(nb[i], P) for i in range(8)]).sum(0)
    stray_ctx = (opaque_n >= 3) & ((keyed_n / np.maximum(opaque_n, 1)) >= P["stray_neighbour_ratio"])
    color = recolour(im, hair_ctx, P, stray_ctx)
    if P["soften_highlights"]:
        ncol = np.stack([recolour(nb[i], np.ones((H, W), bool), P) for i in range(8)])
        w = nop[..., None].astype(float)
        avg = (ncol * w).sum(0) / np.maximum(opaque_n, 1)[..., None]
        avg_l = (luma(ncol) * nop).sum(0) / np.maximum(opaque_n, 1)
        spike = np.maximum(0, luma(color) - avg_l)
        blend = np.clip((spike - P["spike_threshold"]) / max(P["spike_range"] - P["spike_threshold"], 0.001), 0, 1)
        blend = np.where(opaque_n >= 3, blend * P["soften_amount"], 0)[..., None]
        color = color * (1 - blend) + avg * blend
    out = np.concatenate([np.clip(color, 0, 1), im[..., 3:4]], -1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8))


## ------------------------------------------------------------------- icons
def ramps() -> dict:
    text = POWER_STATE_GD.read_text()
    body = re.search(r"const RAMPS := \{(.*?)\n\}", text, re.S).group(1)
    found = {}
    for m in re.finditer(r'"([^"]+)":\s*\[Color8\((\d+), (\d+), (\d+)\),\s*Color8\((\d+), (\d+), (\d+)\)\]', body):
        v = [int(x) for x in m.groups()[1:]]
        found[m.group(1)] = ((v[0], v[1], v[2]), (v[3], v[4], v[5]))
    if len(found) != 12:
        raise SystemExit(f"expected 12 ramps in PowerState.gd, parsed {len(found)}")
    return found


def backdrop() -> Image.Image:
    a = np.zeros((ICON, ICON, 3), np.uint8)
    t = (np.arange(ICON) - 2) / (ICON - 5)
    t = np.clip(t, 0, 1)[:, None]
    a[:] = (np.array(GRAD_TOP) * (1 - t) + np.array(GRAD_BOTTOM) * t + 0.5).astype(np.uint8)[:, None, :]
    a[1, :] = a[-2, :] = a[:, 1] = a[:, -2] = 255
    a[0, :] = a[-1, :] = a[:, 0] = a[:, -1] = 0
    return Image.fromarray(a, "RGB").convert("RGBA")


def outline(sprite: Image.Image) -> Image.Image:
    """1px white halo under the figure, as on the old icon."""
    a = np.array(sprite)
    alpha = a[..., 3] > 0
    halo = np.zeros_like(alpha)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            halo |= np.roll(np.roll(alpha, dy, 0), dx, 1)
    halo &= ~alpha
    out = a.copy()
    out[halo] = (255, 255, 255, 255)
    return Image.fromarray(out, "RGBA")


def compose(bust: Image.Image) -> Image.Image:
    icon = backdrop()
    figure = outline(bust)
    x = (ICON - figure.width) // 2
    y = ICON - 3 - figure.height
    icon.alpha_composite(figure, (x, y))
    return icon


def bust_source() -> Image.Image:
    sheet = Image.open(SOURCE).convert("RGBA")
    frame = sheet.crop((0, 0, CELL_W, CELL_H))
    x0, y0, x1, y1 = BUST
    bust = frame.crop((x0 - 1, y0 - 1, x1 + 1, y1 + 1))
    ## Fade the cut edge at the hem over 6 rows so the crop reads as a vignette
    ## rather than a hard slice through her legs.
    a = np.array(bust)
    h = a.shape[0]
    for i, row in enumerate(range(h - 6, h)):
        a[row, :, 3] = (a[row, :, 3] * (1 - (i + 1) / 7)).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def import_sidecar(png: Path, res: str, uids: Uids) -> None:
    """Write the Godot import sidecar, keeping an existing UID so re-rendering
    the icons never invalidates scenes that reference them."""
    sidecar = png.parent / (png.name + ".import")
    uid = None
    if sidecar.exists():
        m = re.search(r'^uid="(uid://[a-z0-9]+)"', sidecar.read_text(), re.M)
        uid = m.group(1) if m else None
    md5 = hashlib.md5(res.encode()).hexdigest()
    sidecar.write_text(IMPORT_TEMPLATE.format(uid=uid or uids.new(), name=png.name, md5=md5, res=res))


def check() -> None:
    """Measure what the wide key would do to the old heroine, as a sanity
    bound: only her red clothing fringe may move, never skin or white."""
    old = Image.open(OLD_SOURCE).convert("RGBA").crop((0, 0, CELL_W, CELL_H))
    a = np.array(shade(old, shader_defaults()))
    wide = np.array(shade(old, kitsune_params(((72, 4, 1), (242, 58, 20)))))
    changed = (np.abs(wide.astype(int) - a.astype(int)).sum(-1) > 0).sum()
    print(f"wide key on old heroine moves {changed} px of {(a[..., 3] > 0).sum()} opaque")


def main() -> None:
    apply = "--apply" in sys.argv
    if "--check" in sys.argv:
        check()
        return
    bust = bust_source()
    states = ramps()
    uids = Uids()
    preview = Image.new("RGBA", (13 * (ICON + 4), ICON), (40, 40, 40, 255))

    neutral = compose(bust)
    preview.paste(neutral, (0, 0))
    outputs = [(OUT_DIR / "HUDicon.png", f"{OUT_RES}/HUDicon.png", neutral)]
    for i, (state, ramp) in enumerate(sorted(states.items()), start=1):
        icon = compose(shade(bust, kitsune_params(ramp)))
        preview.paste(icon, (i * (ICON + 4), 0))
        outputs.append((OUT_DIR / "power_states" / state / "HUDicon.png",
                        f"{OUT_RES}/power_states/{state}/HUDicon.png", icon))

    preview.save("/tmp/kitsune_icons_preview.png")
    if not apply:
        print(f"DRY RUN - preview at /tmp/kitsune_icons_preview.png; re-run with --apply")
        return
    for png, res, icon in outputs:
        png.parent.mkdir(parents=True, exist_ok=True)
        icon.convert("RGB").convert("RGBA").save(png, "PNG")
        import_sidecar(png, res, uids)
    preview_png = OUT_DIR / "power_states" / "_preview_powerStates.png"
    preview.save(preview_png)
    import_sidecar(preview_png, f"{OUT_RES}/power_states/_preview_powerStates.png", uids)
    print(f"wrote {len(outputs)} icons under {OUT_DIR.relative_to(GAME)}")


if __name__ == "__main__":
    main()
