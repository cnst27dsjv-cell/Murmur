#!/usr/bin/env python3

from pathlib import Path

import numpy as np
from PIL import Image


POSES = (
    "cat_box",
    "cat_cookie",
    "cat_default",
    "cat_sit",
    "cat_sleep",
    "cat_yarn",
)
FRAME_COUNT = 8
ALPHA_THRESHOLD = 12
CONTENT_PADDING = 3


def separator_columns(alpha: Image.Image) -> list[int]:
    width, height = alpha.size
    column_coverage = [
        sum(1 for y in range(height) if alpha.getpixel((x, y)) > ALPHA_THRESHOLD)
        for x in range(width)
    ]
    nominal_width = width / FRAME_COUNT
    search_radius = max(24, round(nominal_width * 0.30))
    separators: list[int] = []

    for index in range(1, FRAME_COUNT):
        target = round(index * nominal_width)
        lower = max((separators[-1] + 1) if separators else 1, target - search_radius)
        upper = min(width - 1, target + search_radius)
        separator = min(
            range(lower, upper + 1),
            key=lambda x: (column_coverage[x], abs(x - target)),
        )
        separators.append(separator)

    return separators


def frame_anchor(frame: Image.Image) -> tuple[int, int]:
    alpha = np.asarray(frame.getchannel("A"))
    visible_y, visible_x = np.nonzero(alpha > ALPHA_THRESHOLD)
    if visible_x.size == 0:
        raise RuntimeError("Frame contains no visible pixels")

    # Median visible pixels follow the cat's body and ignore sparse hearts or motion marks.
    return round(float(np.median(visible_x))), int(visible_y.max())


def extract_frames(sheet: Image.Image) -> list[Image.Image]:
    sheet = sheet.convert("RGBA")
    alpha = sheet.getchannel("A")
    boundaries = [0, *separator_columns(alpha), sheet.width]
    frames: list[Image.Image] = []

    for index in range(FRAME_COUNT):
        left, right = boundaries[index], boundaries[index + 1]
        cell = sheet.crop((left, 0, right, sheet.height))
        content_bounds = cell.getchannel("A").point(
            lambda value: 255 if value > ALPHA_THRESHOLD else 0
        ).getbbox()
        if content_bounds is None:
            raise RuntimeError(f"Frame {index + 1} contains no visible pixels")

        content_left, content_top, content_right, content_bottom = content_bounds
        crop_bounds = (
            max(0, content_left - CONTENT_PADDING),
            max(0, content_top - CONTENT_PADDING),
            min(cell.width, content_right + CONTENT_PADDING),
            min(cell.height, content_bottom + CONTENT_PADDING),
        )
        frames.append(cell.crop(crop_bounds))

    anchors = [frame_anchor(frame) for frame in frames]
    left_extent = max(anchor_x for anchor_x, _ in anchors)
    right_extent = max(frame.width - anchor_x for frame, (anchor_x, _) in zip(frames, anchors))
    top_extent = max(anchor_y for _, anchor_y in anchors)
    bottom_extent = max(frame.height - anchor_y for frame, (_, anchor_y) in zip(frames, anchors))
    canvas_width = left_extent + right_extent
    canvas_height = top_extent + bottom_extent
    normalized: list[Image.Image] = []

    for frame, (anchor_x, anchor_y) in zip(frames, anchors):
        canvas = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))
        x = left_extent - anchor_x
        y = top_extent - anchor_y
        canvas.alpha_composite(frame, (x, y))
        normalized.append(canvas)

    return normalized


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    pet_directory = project_root / "Resources" / "Pets" / "cat"
    output_directory = pet_directory / "frames"
    output_directory.mkdir(parents=True, exist_ok=True)

    for pose in POSES:
        sheet_path = pet_directory / f"{pose}2.png"
        frames = extract_frames(Image.open(sheet_path))
        for index, frame in enumerate(frames, start=1):
            frame.save(output_directory / f"{pose}_{index:02}.png")


if __name__ == "__main__":
    main()
