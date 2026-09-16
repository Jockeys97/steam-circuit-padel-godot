#!/usr/bin/env python3
from collections import deque
from pathlib import Path
import sys

from PIL import Image


FRAME_COUNT = 4
SAMPLE_SCALE = 4
TARGET_WIDTH = 430
TARGET_HEIGHT = 660
BASELINE_Y = 744


def connected_bounds(alpha):
    sample = alpha.resize(
        (max(1, alpha.width // SAMPLE_SCALE), max(1, alpha.height // SAMPLE_SCALE)),
        Image.Resampling.NEAREST,
    )
    pixels = sample.load()
    visited = bytearray(sample.width * sample.height)
    components = []

    for y in range(sample.height):
        for x in range(sample.width):
            index = y * sample.width + x
            if visited[index] or pixels[x, y] < 24:
                continue
            queue = deque([(x, y)])
            visited[index] = 1
            count = 0
            min_x = max_x = x
            min_y = max_y = y
            while queue:
                px, py = queue.popleft()
                count += 1
                min_x = min(min_x, px)
                max_x = max(max_x, px)
                min_y = min(min_y, py)
                max_y = max(max_y, py)
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or nx >= sample.width or ny < 0 or ny >= sample.height:
                        continue
                    neighbor = ny * sample.width + nx
                    if visited[neighbor] or pixels[nx, ny] < 24:
                        continue
                    visited[neighbor] = 1
                    queue.append((nx, ny))
            if count > 250:
                components.append((count, min_x, min_y, max_x + 1, max_y + 1))

    components.sort(reverse=True)
    figures = sorted(components[:FRAME_COUNT], key=lambda item: (item[1] + item[3]) / 2)
    if len(figures) != FRAME_COUNT:
        raise RuntimeError(f"Expected {FRAME_COUNT} figures, found {len(figures)}")

    bounds = []
    for _, min_x, min_y, max_x, max_y in figures:
        bounds.append((
            max(0, min_x * SAMPLE_SCALE - 8),
            max(0, min_y * SAMPLE_SCALE - 8),
            min(alpha.width, max_x * SAMPLE_SCALE + 8),
            min(alpha.height, max_y * SAMPLE_SCALE + 8),
        ))
    return bounds


def normalize(source_path, output_path):
    image = Image.open(source_path).convert("RGBA")
    bounds = connected_bounds(image.getchannel("A"))
    crops = [image.crop(box) for box in bounds]
    max_width = max(crop.width for crop in crops)
    max_height = max(crop.height for crop in crops)
    scale = min(TARGET_WIDTH / max_width, TARGET_HEIGHT / max_height)
    frame_width = round(image.width / FRAME_COUNT)
    canvas = Image.new("RGBA", (frame_width * FRAME_COUNT, image.height), (0, 0, 0, 0))

    for index, crop in enumerate(crops):
        width = max(1, round(crop.width * scale))
        height = max(1, round(crop.height * scale))
        resized = crop.resize((width, height), Image.Resampling.LANCZOS)
        x = index * frame_width + (frame_width - width) // 2
        y = BASELINE_Y - height
        canvas.alpha_composite(resized, (x, y))

    canvas.save(output_path)
    print(f"Wrote {output_path}")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: normalize_run_sprites.py INPUT OUTPUT")
    normalize(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
