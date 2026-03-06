#!/bin/bash
# sips.init.sh - Initialize the table

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Set up table columns - one visible column (path is hidden in data)
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_columns "Images"
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_column_widths 270

# Clear any existing rows
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

while IFS= read -r line; do
    # Check if line contains "Writable"
    if echo "$line" | /usr/bin/grep -q "Writable"; then
        # Extract the short format code (second column)
        format=$(echo "$line" | /usr/bin/awk '{print $2}')
        
        # Skip empty or "--" format codes
        if [ -n "$format" ] && [ "$format" != "--" ]; then
            # Get display name
            display_name=$(get_format_name "$format")
            
            if [ "$first" = true ]; then
                first=false
            else
                options_json="${options_json},"
            fi
            options_json="${options_json}{\"title\": \"${display_name}\", \"tag\": \"${format}\"}"
        fi
    fi
done <<< "$sips_formats"

options_json="${options_json}]"

echo "[DEBUG] Format options: $options_json"

# Set the format picker options dynamically
"$dialog_tool" "$window_uuid" ${FORMAT_PICKER_ID} omc_set_property "options" "$options_json"

# If files were dropped on the app, add them
# OMC_OBJ_PATH contains newline-separated list of file paths
if [ -n "$OMC_OBJ_PATH" ]; then
    add_files_to_table "$OMC_OBJ_PATH"
fi
