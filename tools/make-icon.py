"""Render the project's original geometric calendar icon; no external packages."""

from pathlib import Path
import struct
import zlib


SIZE = 1024
BACKGROUND = (20, 110, 102)
PAPER = (248, 246, 235)
ACCENT = (230, 183, 83)


def rounded(x, y, left, top, right, bottom, radius):
    if not left <= x < right or not top <= y < bottom:
        return False
    cx = max(left + radius, min(x, right - radius))
    cy = max(top + radius, min(y, bottom - radius))
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def color_at(x, y):
    color = BACKGROUND
    if rounded(x, y, 206, 244, 818, 826, 72):
        color = PAPER
    if 242 <= x < 782 and 384 <= y < 408:
        color = BACKGROUND
    for left in (322, 650):
        if rounded(x, y, left, 170, left + 52, 316, 26):
            color = PAPER
    for left in (304, 468, 632):
        for top in (486, 640):
            if rounded(x, y, left, top, left + 90, top + 90, 18):
                color = ACCENT if (left, top) == (468, 486) else BACKGROUND
    return color


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def main():
    pixels = bytearray()
    for y in range(SIZE):
        pixels.append(0)
        for x in range(SIZE):
            pixels.extend(color_at(x + 0.5, y + 0.5))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(pixels, 9))
    png += chunk(b"IEND", b"")
    target = Path(__file__).resolve().parents[1] / "Takupoke/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    target.write_bytes(png)
    print("Generated opaque RGB app icon.")


if __name__ == "__main__":
    main()
