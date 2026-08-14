#!/bin/sh
# Tests/make-fixtures.sh - build the image fixtures the suite runs against.
#
# Generated rather than committed. The assertions care about pixel dimensions
# and format, nothing about the bytes, so a generator is a readable statement of
# exactly what the tests depend on - and keeps binaries out of the repository.
#
# The base PNG is written by hand (zlib + struct, no third-party module) and the
# other formats are converted from it with sips, which is the applet's own
# engine and is present on every macOS. Usage: make-fixtures.sh <dest-dir>

set -e

dest="${1:?usage: make-fixtures.sh <dest-dir>}"
/bin/mkdir -p "$dest"

# A solid-color PNG of a given size. Two sizes, both with an odd aspect ratio,
# so a resize that silently swaps width and height cannot pass.
/usr/bin/python3 - "$dest" <<'PY'
import os, struct, sys, zlib

def png(path, width, height, rgb):
    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", header)
                     + chunk(b"IDAT", zlib.compress(raw))
                     + chunk(b"IEND", b""))

dest = sys.argv[1]
png(os.path.join(dest, "landscape.png"), 400, 300, (200, 40, 40))
png(os.path.join(dest, "portrait.png"), 60, 180, (40, 80, 200))
# Small enough that scaling to 1 % rounds an axis below one pixel, which is the
# case build_sips_args has to clamp.
png(os.path.join(dest, "tiny.png"), 8, 4, (10, 200, 90))
PY

# A second format, so the format picker and the extension rewrite are exercised
# against something that is genuinely not a PNG.
/usr/bin/sips -s format jpeg "$dest/landscape.png" --out "$dest/photo.jpg" >/dev/null 2>&1

# Not an image. The applet has to skip it and say so.
printf 'This is not an image.\n' > "$dest/notes.txt"

# An image whose extension lies about its content: sips reads it, so the applet
# must not reject it on the extension alone... and equally must not claim to
# convert something it cannot read. Named .tiff, actually a PNG.
/bin/cp "$dest/landscape.png" "$dest/mislabeled.tiff"

/bin/chmod a-w "$dest"/* 2>/dev/null || true
