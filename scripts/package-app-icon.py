#!/usr/bin/env python3
"""Package opaque source PNGs verbatim into an ICNS family (no image filters)."""

import struct
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: package-app-icon.py AppIcon.appiconset output.icns")
    catalog, output = map(Path, sys.argv[1:])
    entries = [
        (b"icp4", "icon_16x16.png", 16),
        (b"ic11", "icon_16x16@2x.png", 32),
        (b"icp5", "icon_32x32.png", 32),
        (b"ic12", "icon_32x32@2x.png", 64),
        (b"icp6", "icon_32x32@2x.png", 64),
        (b"ic07", "icon_128x128.png", 128),
        (b"ic13", "icon_128x128@2x.png", 256),
        (b"ic08", "icon_256x256.png", 256),
        (b"ic14", "icon_256x256@2x.png", 512),
        (b"ic09", "icon_512x512.png", 512),
        (b"ic10", "icon_512x512@2x.png", 1024),
    ]
    chunks = []
    for tag, filename, size in entries:
        png = (catalog / filename).read_bytes()
        if png[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not a PNG: {filename}")
        width, height, depth, color = struct.unpack(">IIBB", png[16:26])
        if (width, height, depth, color) != (size, size, 8, 2):
            raise ValueError(f"Expected opaque RGB8 {size}px image: {filename}")
        chunks.append(tag + struct.pack(">I", len(png) + 8) + png)
    payload = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


if __name__ == "__main__":
    main()
