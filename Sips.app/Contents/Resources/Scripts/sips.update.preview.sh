#!/bin/bash
# sips.update.preview.sh - Update preview with current settings applied

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Control IDs (local)
WIDTH_FIELD_ID=31
HEIGHT_FIELD_ID=32

# Function to handle resize mode changes - enable/disable fields and calculate aspect ratio
handle_resize_mode_change() {
    local resize_mode="$OMC_ACTIONUI_VIEW_30_VALUE"
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    
    echo "[DEBUG handle_resize_mode_change] mode=$resize_mode"
    
    # Default: enable both fields
    local width_disabled="false"
    local height_disabled="false"
    
    case "$resize_mode" in
        exact)
            # Both fields enabled for exact dimensions
            width_disabled="false"
            height_disabled="false"
            ;;
        width)
            # Disable height, calculate from aspect ratio
            height_disabled="true"
            calculate_height_from_width
            ;;
        height)
            # Disable width, calculate from aspect ratio
            width_disabled="true"
            calculate_width_from_height
            ;;
        longest)
            # Use width field for longest edge pixel value
            width_disabled="false"
            height_disabled="true"
            ;;
        *)
            # Default state
            width_disabled="false"
            height_disabled="false"
            ;;
    esac
    
    # Apply enable/disable states
    if [ "$width_disabled" = "true" ]; then
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_disable
    else
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_enable
    fi
    
    if [ "$height_disabled" = "true" ]; then
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_disable
    else
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_enable
    fi
}

# Function to calculate height based on width and aspect ratio
calculate_height_from_width() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    local current_width="$OMC_ACTIONUI_VIEW_31_VALUE"
    
    if [ -z "$selected_path" ] || [ ! -e "$selected_path" ]; then
        return
    fi
    
    if [ -z "$current_width" ]; then
        return
    fi
    
    echo "[DEBUG calculate_height_from_width] width=$current_width"
    
    # Get original dimensions in single call
    local orig_width=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelWidth" | /usr/bin/awk '{print $2}')
    local orig_height=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelHeight" | /usr/bin/awk '{print $2}')
    
    echo "[DEBUG] orig_width=$orig_width, orig_height=$orig_height"
    
    if [ -n "$orig_width" ] && [ -n "$orig_height" ] && [ "$orig_width" -gt 0 ]; then
        local new_height=$(echo "scale=0; $orig_height * $current_width / $orig_width" | /usr/bin/bc)
        echo "[DEBUG] Setting calculated height: $new_height"
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$new_height"
    fi
}

# Function to calculate width based on height and aspect ratio
calculate_width_from_height() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    local current_height="$OMC_ACTIONUI_VIEW_32_VALUE"
    
    if [ -z "$selected_path" ] || [ ! -e "$selected_path" ]; then
        return
    fi
    
    if [ -z "$current_height" ]; then
        return
    fi
    
    echo "[DEBUG calculate_width_from_height] height=$current_height"
    
    # Get original dimensions in single call
    local orig_width=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelWidth" | /usr/bin/awk '{print $2}')
    local orig_height=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelHeight" | /usr/bin/awk '{print $2}')
    
    echo "[DEBUG] orig_width=$orig_width, orig_height=$orig_height"
    
    if [ -n "$orig_width" ] && [ -n "$orig_height" ] && [ "$orig_height" -gt 0 ]; then
        local new_width=$(echo "scale=0; $orig_width * $current_height / $orig_height" | /usr/bin/bc)
        echo "[DEBUG] Setting calculated width: $new_width"
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$new_width"
    fi
}

echo "[DEBUG sips.update.preview]"

# Get selected file path from table (column 2)
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

if [ -z "$selected_path" ]; then
    echo "[DEBUG] No file selected"
    exit 0
fi

if [ ! -e "$selected_path" ]; then
    echo "[DEBUG] File does not exist: $selected_path"
    exit 0
fi

# Handle resize mode change - enable/disable fields and calculate aspect ratio
handle_resize_mode_change

echo "[DEBUG] Updating preview for: $selected_path"

# Get output format (use png as default for preview)
output_format="$OMC_ACTIONUI_VIEW_13_VALUE"
if [ -z "$output_format" ]; then
    output_format="png"
fi

# Create temp directory if needed
temp_preview_dir="/tmp/sips_preview"
/bin/mkdir -p "$temp_preview_dir"

# Generate output filename in temp dir
filename="$("/usr/bin/basename" "$selected_path")"
name_without_ext="${filename%.*}"
output_file="$temp_preview_dir/${name_without_ext}_preview.${output_format}"

# Remove old preview file
/bin/rm -f "$output_file"

# Build and execute sips command
sips_args=$(build_sips_args)

# For preview, we still need to add output and input
sips_cmd="/usr/bin/sips $sips_args --out \"$output_file\" \"$selected_path\""
echo "[DEBUG] Running: $sips_cmd"

# Execute the sips command
output=$(/usr/bin/sips $sips_args --out "$output_file" "$selected_path" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "[DEBUG] Error: $output"
    # Don't update preview on error, just log
    exit 0
fi

echo "[DEBUG] Preview saved to: $output_file"

# Update the image preview with the temp file
if [ -e "$output_file" ]; then
    update_image_preview "$output_file"
    echo "[DEBUG] Preview updated"
else
    echo "[DEBUG] Preview file not created"
fi

echo "[DEBUG] Done"
