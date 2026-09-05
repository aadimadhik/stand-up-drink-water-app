#!/usr/bin/env python3
"""Generate the 1024x1024 app icon: a water drop over a blue-to-green gradient,
the same two colours the water and stand cards use.

Written as raw PNG bytes so the repo needs no image library or binary source art.

    python3 scripts/generate_appicon.py
"""

import math
import os
import struct
import zlib

SIZE = 1024
SUPERSAMPLE = 2
OUT = os.path.join("DeskBreak", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

TOP = (0.16, 0.47, 0.96)     # blue, matches the water card tint
BOTTOM = (0.18, 0.72, 0.46)  # green, matches the stand card tint

# Teardrop: a circle for the belly, with two straight sides running tangent from
# the circle up to a sharp apex. Tangent lines are what make it read as a drop —
# an elliptical taper just produces an egg.
BELLY_Y = 0.22
RADIUS = 0.33
APEX_Y = -0.52

_D = BELLY_Y - APEX_Y
_TANGENT_LEN = math.sqrt(_D * _D - RADIUS * RADIUS)
_SLOPE = RADIUS / _TANGENT_LEN
_JOIN_Y = APEX_Y + _TANGENT_LEN * _TANGENT_LEN / _D


def inside_drop(x, y):
    if y < APEX_Y:
        return False
    if y <= _JOIN_Y:
        return abs(x) <= (y - APEX_Y) * _SLOPE
    if y <= BELLY_Y + RADIUS:
        return x * x + (y - BELLY_Y) ** 2 <= RADIUS * RADIUS
    return False


def png(width, height, rows):
    def chunk(tag, payload):
        data = tag + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))

    raw = bytearray()
    for row in rows:
        raw.append(0)  # filter type 0 (None)
        raw += row

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    rows = []
    step = 1.0 / SUPERSAMPLE

    for py in range(SIZE):
        row = bytearray()
        for px in range(SIZE):
            coverage = 0.0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    x = ((px + (sx + 0.5) * step) / SIZE - 0.5) * 2
                    y = ((py + (sy + 0.5) * step) / SIZE - 0.5) * 2
                    if inside_drop(x, y):
                        coverage += 1.0
            coverage /= SUPERSAMPLE * SUPERSAMPLE

            blend = py / (SIZE - 1)
            for channel in range(3):
                background = TOP[channel] + (BOTTOM[channel] - TOP[channel]) * blend
                value = background * (1 - coverage) + 1.0 * coverage
                row.append(int(round(max(0.0, min(1.0, value)) * 255)))
        rows.append(row)

    with open(OUT, "wb") as handle:
        handle.write(png(SIZE, SIZE, rows))
    print("%s  %d x %d  %.1f KB" % (OUT, SIZE, SIZE, os.path.getsize(OUT) / 1024))


if __name__ == "__main__":
    main()
