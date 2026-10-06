#!/usr/bin/env python3
"""Pixelate Blender renders, validate them, and create contact sheets."""

import argparse
import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--working-size", type=int, default=112)
    parser.add_argument("--final-size", type=int, default=224)
    args = parser.parse_args()
    root = Path(args.root)
    manifest_path = root / "render_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = []
    for record in manifest["renders"]:
        source = Path(record["raw_render"])
        image = Image.open(source).convert("RGBA")
        pixelated = image.resize((args.working_size, args.working_size), Image.Resampling.LANCZOS)
        pixelated = pixelated.resize((args.final_size, args.final_size), Image.Resampling.NEAREST)
        initial_bbox = pixelated.getchannel("A").getbbox()
        if initial_bbox and (
            initial_bbox[0] == 0
            or initial_bbox[1] == 0
            or initial_bbox[2] == args.final_size
            or initial_bbox[3] == args.final_size
        ):
            padded_size = int(args.final_size * 0.90)
            inset = (args.final_size - padded_size) // 2
            padded = Image.new("RGBA", (args.final_size, args.final_size), (0, 0, 0, 0))
            padded.alpha_composite(pixelated.resize((padded_size, padded_size), Image.Resampling.NEAREST), (inset, inset))
            pixelated = padded
        pixelated.save(source, optimize=True)
        alpha = pixelated.getchannel("A")
        bbox = alpha.getbbox()
        occupied = sum(1 for value in alpha.getdata() if value > 8)
        fraction = occupied / (args.final_size * args.final_size)
        status = "PASS"
        if bbox is None or fraction < 0.005:
            status = "EMPTY"
        elif fraction < 0.025:
            status = "TOO_SMALL"
        elif bbox[0] == 0 or bbox[1] == 0 or bbox[2] == args.final_size or bbox[3] == args.final_size:
            status = "EDGE_TOUCH"
        record.update({"output": str(source), "width": image.width, "height": image.height, "alpha_bbox": bbox, "occupancy": round(fraction, 5), "validation": status})
        rows.append(record)

    with (root / "frames.csv").open("w", encoding="utf-8", newline="") as handle:
        fields = ["character", "animation", "frame", "frame_range", "output", "width", "height", "alpha_bbox", "occupancy", "validation", "source_glb"]
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    manifest["pixel_art"] = {"working_size": args.working_size, "final_size": args.final_size}
    manifest["renders"] = rows
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    for directory in sorted(path for path in root.iterdir() if path.is_dir()):
        frames = sorted(directory.glob("*.png"))
        if not frames:
            continue
        thumb = 224
        label_h = 32
        columns = 5
        rows_count = (len(frames) + columns - 1) // columns
        sheet = Image.new("RGBA", (columns * thumb, rows_count * (thumb + label_h)), (32, 32, 38, 255))
        draw = ImageDraw.Draw(sheet)
        for i, frame in enumerate(frames):
            image = Image.open(frame).convert("RGBA")
            x = (i % columns) * thumb
            y = (i // columns) * (thumb + label_h)
            checker = Image.new("RGBA", (thumb, thumb), (72, 72, 80, 255))
            checker.alpha_composite(image)
            sheet.alpha_composite(checker, (x, y))
            draw.text((x + 4, y + thumb + 6), frame.stem[:32], fill=(235, 235, 240, 255), font=ImageFont.load_default())
        sheet.save(root / f"{directory.name}_contact_sheet.png", optimize=True)

    counts = {}
    for row in rows:
        counts[row["validation"]] = counts.get(row["validation"], 0) + 1
    print(json.dumps({"frames": len(rows), "validation": counts, "failures": manifest.get("failures", [])}, indent=2))


if __name__ == "__main__":
    main()
