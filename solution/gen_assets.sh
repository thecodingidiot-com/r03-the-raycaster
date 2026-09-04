#!/bin/bash
# Generate the four cardinal wall textures for r03.
#
# Each is a 64x64 brick pattern in its own colour, striped so a real
# error in wall_x (the horizontal texture coordinate raycaster.c
# computes from the exact hit point) shows up immediately as smeared
# or repeating brick columns instead of a clean vertical grid.

set -e

mkdir -p assets

python3 - <<'EOF'
from PIL import Image, ImageDraw

SIZE = 64
BRICK_W = 16
BRICK_H = 8

COLOURS = {
    "wall_west.png": (0xb0, 0x3a, 0x3a),
    "wall_east.png": (0x2e, 0x4f, 0x8b),
    "wall_north.png": (0x3a, 0x8b, 0x4a),
    "wall_south.png": (0xb0, 0x9a, 0x2e),
}

for name, base in COLOURS.items():
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    mortar = tuple(max(0, c - 60) for c in base)
    row = 0
    y = 0
    while y < SIZE:
        offset = (BRICK_W // 2) if (row % 2) else 0
        x = -offset
        while x < SIZE:
            d.rectangle([x, y, x + BRICK_W - 2, y + BRICK_H - 2], outline=mortar)
            x += BRICK_W
        y += BRICK_H
        row += 1
    img.save(f"assets/{name}")
    print(f"  wrote assets/{name}")
EOF
