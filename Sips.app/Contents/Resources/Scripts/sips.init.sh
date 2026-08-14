#!/bin/bash
# sips.init.sh - Initialize the window

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Set up table columns - one visible column (path is hidden in data)
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_columns "Images"
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_column_widths 270

# Start with an empty image list
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_remove_all_rows

# Query sips for supported writable formats and build options JSON
sips_formats=$(/usr/bin/sips --formats 2>/dev/null)

options_json="["
first=true

# Function to get display name for format
get_format_name() {
    local format="$1"
    case "$format" in
        jpeg) echo "JPEG (Photo)" ;;
        png) echo "PNG (Graphics)" ;;
        tiff) echo "TIFF (Lossless Photo)" ;;
        gif) echo "GIF (Animation Graphic)" ;;
        heic) echo "HEIC (Apple Photo)" ;;
        heics) echo "HEIC Sequence" ;;
        pdf) echo "PDF (Adobe Portable Document)" ;;
        bmp) echo "BMP (Windows Bitmap)" ;;
        webp) echo "WebP (Google Web Image)" ;;
        psd) echo "PSD (Adobe Photoshop)" ;;
        dng) echo "DNG (Digital Negative RAW)" ;;
        ico) echo "ICO (Windows Icon)" ;;
        dds) echo "DDS (Microsoft DirectX)" ;;
        exr) echo "EXR (OpenEXR HDR Image)" ;;
        astc) echo "ASTC (Mobile Texture)" ;;
        ktx) echo "KTX (Khronos Texture)" ;;
        pbm) echo "PBM (Portable Bitmap)" ;;
        pvr) echo "PVR (PowerVR Texture)" ;;
        tga) echo "TGA (Targa Image)" ;;
        jp2) echo "JPEG 2000 (Photo)" ;;
        icns) echo "ICNS (macOS Icon)" ;;
        avif) echo "AVIF (AV1 Image)" ;;
        *) echo "$format" | /usr/bin/tr '[:lower:]' '[:upper:]' ;;
    esac
}

# Per-window scratch file: several windows can initialize at the same time.
formats_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.formats.XXXXXX")"

while IFS= read -r line; do
    # Check if line contains "Writable"
    if echo "$line" | /usr/bin/grep -q "Writable"; then
        # Extract the short format code (second column)
        format=$(echo "$line" | /usr/bin/awk '{print $2}')

        # Skip empty or "--" format codes
        if [ -n "$format" ] && [ "$format" != "--" ]; then
            # Get display name
            display_name=$(get_format_name "$format")
            echo "${display_name}|${format}"
        fi
    fi
done <<< "$sips_formats" | /usr/bin/sort -d > "$formats_file"

# Build JSON from sorted formats
first=true
while IFS='|' read -r display_name format; do
    if [ "$first" = true ]; then
        first=false
    else
        options_json="${options_json},"
    fi
    options_json="${options_json}{\"title\": \"${display_name}\", \"tag\": \"${format}\"}"
done < "$formats_file"
/bin/rm -f "$formats_file"

options_json="${options_json}]"

# Set the format picker options dynamically
"$dialog_tool" "$window_uuid" ${FORMAT_PICKER_ID} omc_set_property "options" "$options_json"

# Initialize compression controls - default to JPEG with quality 80
"$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} 80
"$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} omc_set_property "disabled" "false"

# Resize starts on Percentage at 100 %, which converts every image at its own
# size. A picker fires no action for the value it starts on, so the matching
# field layout has to be set up here rather than left to sips.update.preview -
# and the mode is recorded in the state file so the first switch away from it is
# seen as a change.
"$dialog_tool" "$window_uuid" ${RESIZE_MODE_PICKER_ID} "$DEFAULT_RESIZE_MODE"
"$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$DEFAULT_RESIZE_PERCENT"
"$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_set_property "hidden" "true"
"$dialog_tool" "$window_uuid" ${X_TEXT_ID} omc_set_property "hidden" "true"
"$dialog_tool" "$window_uuid" ${PERCENT_SIGN_ID} omc_set_property "hidden" "false"
echo "$DEFAULT_RESIZE_MODE" > "$RESIZE_MODE_STATE_FILE"

set_status "Drop images into the list, pick a format and size, then press Convert."

# Seed the image list: from objects dropped on the app icon, or from the
# Open... panel selection handed off via the private pasteboard
seed_paths="$OMC_OBJ_PATH"
if [ -z "$seed_paths" ]; then
    seed_paths="$("$pasteboard_tool" "$OPEN_PATHS_PB_KEY" get)"
    if [ -n "$seed_paths" ]; then
        "$pasteboard_tool" "$OPEN_PATHS_PB_KEY" set ""
    fi
fi

if [ -n "$seed_paths" ]; then
    add_files_to_table "$seed_paths"
    if [ -n "$_first_row_path" ]; then
        # Visual selection only (fires no actionID); update the detail pane
        # directly from the known path to avoid the selection-vs-handler race.
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_select_row 0
        apply_file_selection "$_first_row_path"
    fi
fi
