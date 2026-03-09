# Sips.app

![Sips Icon](Icon/Sips-macOS-128x128@2x.png)

A native macOS applet for batch image conversion and resizing. Wraps the built-in macOS `sips` command-line tool in a SwiftUI interface with real-time preview.

Built with **OMC 5.0** engine — [github.com/abra-code/OMC](https://github.com/abra-code/OMC/)  
UI rendered by **ActionUI** — [github.com/abra-code/ActionUI](https://github.com/abra-code/ActionUI/)

## Features

- **Batch conversion** of multiple images in one go
- **Drag & drop** files or folders onto the app to populate the file list
- **Recursive folder scanning** for supported image types
- **Real-time preview** of resize, rotation, and flip settings
- **20+ output formats** dynamically queried from macOS `sips`
- **5 resize modes**: Exact Pixels, Percentage, Width, Height, Longest Edge
- **Rotation**: 0°, ±90°, ±180°, ±270°
- **Flip**: Horizontal, Vertical, or None
- **Quality control** for lossy formats (1–100)
- **Compression options** for applicable formats (e.g. TIFF LZW/PackBits)
- **File info** panel with image dimensions, file size, and dates
- **Overwrite protection** — optionally skip existing output files

## Supported Formats

Output formats are discovered at launch from the system `sips` command. Typical formats include:

JPEG, PNG, TIFF, GIF, BMP, HEIC, HEICS, WebP, PSD, PDF, JPEG 2000, ICNS, AVIF, DNG, ICO, DDS, EXR, ASTC, KTX, PBM, PVR, TGA

## Requirements

- **macOS 14.6+**

## Usage

1. Launch `Sips.app` (or drop image files/folders onto it)
2. Add images using the **+** button
3. Select an image to see its preview and info
4. Adjust resize mode, rotation, flip, output format, and quality
5. Click **Convert** and pick a destination folder
