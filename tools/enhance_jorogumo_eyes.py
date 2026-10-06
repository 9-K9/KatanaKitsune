#!/usr/bin/env python3
"""Direction-aware, deterministic F-eye pass for Jorogumo sprite sheets."""

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


TILE = 480
DARK = (38, 18, 38, 255)
LIGHT = (255, 236, 224, 255)


def components(points):
    points = set(points)
    found = []
    while points:
        seed = points.pop()
        queue = [seed]
        component = [seed]
        while queue:
            x, y = queue.pop()
            for neighbor in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if neighbor in points:
                    points.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        found.append(component)
    return sorted(found, key=len, reverse=True)


def face_boxes(frame):
    bbox = frame.getchannel("A").getbbox()
    if not bbox:
        return None
    x0, y0, x1, _ = bbox
    candidates = []
    for y in range(y0, min(TILE, y0 + 62)):
        for x in range(max(0, x0 - 10), min(TILE, x1 + 10)):
            red, green, blue, alpha = frame.getpixel((x, y))
            if alpha > 128 and red > 105 and green > 95 and blue > 95 and max(red, green, blue) - min(red, green, blue) < 80:
                candidates.append((x, y))
    boxes = []
    for component in components(candidates):
        bx = (
            min(x for x, _ in component),
            min(y for _, y in component),
            max(x for x, _ in component) + 1,
            max(y for _, y in component) + 1,
        )
        width, height = bx[2] - bx[0], bx[3] - bx[1]
        if len(component) >= 45 and 7 <= width <= 30 and 8 <= height <= 32:
            boxes.append((bx, len(component)))
    return boxes


def choose_face_box(frame, expected_center=None):
    boxes = face_boxes(frame)
    if not boxes:
        return None
    if expected_center is None:
        sprite_box = frame.getchannel("A").getbbox()
        expected_center = ((sprite_box[0] + sprite_box[2]) / 2, sprite_box[1] + 34)
    ex, ey = expected_center
    return min(
        boxes,
        key=lambda item: ((item[0][0] + item[0][2]) / 2 - ex) ** 2
        + ((item[0][1] + item[0][3]) / 2 - ey) ** 2,
    )[0]


def paint_front(frame, box):
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    eye_y = y0 + max(5, round(height * (0.68 if height > 20 else 0.46)))
    left_x = x0 + max(3, round(width * 0.28))
    right_x = x0 + max(8, round(width * 0.68))
    # Mirrored 2x2 F-shaped eyes: dark upper lash/inner stem, pale eye pixel.
    for point in ((left_x, eye_y), (left_x + 1, eye_y), (left_x, eye_y + 1)):
        frame.putpixel(point, DARK)
    frame.putpixel((left_x + 1, eye_y + 1), LIGHT)
    for point in ((right_x, eye_y), (right_x + 1, eye_y), (right_x + 1, eye_y + 1)):
        frame.putpixel(point, DARK)
    frame.putpixel((right_x, eye_y + 1), LIGHT)


def paint_three_quarter(frame, box):
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    eye_y = y0 + max(4, round(height * (0.68 if height > 20 else 0.46)))
    near_x = x0 + max(5, round(width * 0.62))
    far_x = x0 + max(2, round(width * 0.34))
    for point in ((near_x, eye_y), (near_x + 1, eye_y), (near_x, eye_y + 1)):
        frame.putpixel(point, DARK)
    frame.putpixel((near_x + 1, eye_y + 1), LIGHT)
    frame.putpixel((far_x, eye_y), DARK)
    frame.putpixel((far_x, eye_y + 1), LIGHT)


def process_sheet(source, destination, direction):
    sheet = Image.open(source).convert("RGBA")
    frame_count = sheet.width // TILE
    edited_frames = []
    diagnostics = []
    expected_center = None
    for index in range(frame_count):
        frame = sheet.crop((index * TILE, 0, (index + 1) * TILE, TILE))
        box = choose_face_box(frame, expected_center)
        diagnostics.append(box)
        if box:
            expected_center = ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)
            if direction == 8:
                paint_front(frame, box)
            elif direction == 7:
                paint_three_quarter(frame, box)
        edited_frames.append(frame)
        sheet.alpha_composite(frame, (index * TILE, 0))
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, optimize=True)
    return edited_frames, diagnostics


def make_review(original_path, edited_frames, diagnostics, output_path, direction):
    original = Image.open(original_path).convert("RGBA")
    scale = 10
    crop_size = 32
    count = len(edited_frames)
    sheet = Image.new("RGBA", (count * crop_size * scale, crop_size * scale * 2 + 36), (55, 55, 62, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (edited, box) in enumerate(zip(edited_frames, diagnostics)):
        if not box:
            continue
        x0, y0, x1, y1 = box
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        crop_box = (cx - crop_size // 2, cy - crop_size // 2, cx + crop_size // 2, cy + crop_size // 2)
        before = original.crop((i * TILE, 0, (i + 1) * TILE, TILE)).crop(crop_box)
        after = edited.crop(crop_box)
        for row, image in enumerate((before, after)):
            enlarged = image.resize((crop_size * scale, crop_size * scale), Image.Resampling.NEAREST)
            background = Image.new("RGBA", enlarged.size, (75, 75, 84, 255))
            background.alpha_composite(enlarged)
            sheet.alpha_composite(background, (i * crop_size * scale, row * crop_size * scale))
        draw.text((i * crop_size * scale + 4, crop_size * scale * 2 + 8), f"d{direction} f{i}", fill="white")
    sheet.save(output_path, optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    input_root = Path(args.input)
    output_root = Path(args.output)
    for direction in (7, 8):
        source = input_root / f"Jorogumo_Idle_7_dir{direction}.png"
        destination = output_root / f"Jorogumo_Idle_7_dir{direction}_eyes_test.png"
        frames, boxes = process_sheet(source, destination, direction)
        make_review(source, frames, boxes, output_root / f"review_dir{direction}.png", direction)
        frames[0].save(
            output_root / f"preview_dir{direction}.gif",
            save_all=True,
            append_images=frames[1:],
            duration=125,
            loop=0,
            disposal=2,
            transparency=0,
        )
        print(direction, boxes)


if __name__ == "__main__":
    main()
