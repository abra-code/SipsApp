#!/bin/bash
# sips.update.preview.sh - Update preview with current settings applied

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Control IDs (local)
WIDTH_FIELD_ID=31
HEIGHT_FIELD_ID=32
X_TEXT_ID=33

# Temp file for corrected dimensions (used by build_sips_args)
CORRECTED_VALUES_FILE="/tmp/sips_corrected_values.txt"

# Function to handle resize mode changes - enable/disable fields and calculate aspect ratio
handle_resize_mode_change() {
    local resize_mode="$OMC_ACTIONUI_VIEW_30_VALUE"
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    
    echo "[DEBUG handle_resize_mode_change] mode=$resize_mode"
    
    # Default: show both fields
    local width_hidden="false"
    local height_hidden="false"
    local x_hidden="false"
    
    case "$resize_mode" in
        exact)
            # Both fields visible
            width_hidden="false"
            height_hidden="false"
            x_hidden="false"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Width"
            # If coming from Percent mode (corrected file exists), reset to original size
            if [ -f "$CORRECTED_VALUES_FILE" ]; then
                calculate_exact_from_original
            fi
            ;;
        width)
            # Only width field visible, calculate height
            width_hidden="false"
            height_hidden="true"
            x_hidden="true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Width"
            calculate_height_from_width
            rm -f "$CORRECTED_VALUES_FILE"
            ;;
        height)
            # Only height field visible (swap positions), calculate width
            width_hidden="true"
            height_hidden="false"
            x_hidden="true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Height"
            calculate_width_from_height
            rm -f "$CORRECTED_VALUES_FILE"
            ;;
        longest)
            # Only width field visible
            width_hidden="false"
            height_hidden="true"
            x_hidden="true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Longest"
            rm -f "$CORRECTED_VALUES_FILE"
            ;;
        percent)
            # Use width field for percentage - only reset to 100% when switching TO percent mode
            width_hidden="false"
            height_hidden="true"
            x_hidden="true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Percent"
            # Check if we already initialized percent mode (file has percent marker)
            if ! grep -q "mode=percent" "$CORRECTED_VALUES_FILE" 2>/dev/null; then
                # Switching to percent mode - reset to 100%
                echo "mode=percent width=100" > "$CORRECTED_VALUES_FILE"
                "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "100"
            else
                # User is typing in percent mode - update the corrected file with current value
                current_val="$OMC_ACTIONUI_VIEW_31_VALUE"
                if [ -n "$current_val" ] && [[ "$current_val" =~ ^[0-9]+$ ]]; then
                    echo "mode=percent width=$current_val" > "$CORRECTED_VALUES_FILE"
                fi
            fi
            ;;
        *)
            # Default state - show both
            width_hidden="false"
            height_hidden="false"
            x_hidden="false"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "placeholder" "Width"
            # Clear corrected values
            rm -f "$CORRECTED_VALUES_FILE"
            ;;
    esac
    
    # Apply hidden states
    if [ "$width_hidden" = "true" ]; then
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "hidden" "true"
    else
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "hidden" "false"
    fi
    
    if [ "$height_hidden" = "true" ]; then
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_set_property "hidden" "true"
    else
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_set_property "hidden" "false"
    fi
    
    if [ "$x_hidden" = "true" ]; then
        "$dialog_tool" "$window_uuid" ${X_TEXT_ID} omc_set_property "hidden" "true"
    else
        "$dialog_tool" "$window_uuid" ${X_TEXT_ID} omc_set_property "hidden" "false"
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

# Function to set exact dimensions to original image size
calculate_exact_from_original() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    
    if [ -z "$selected_path" ] || [ ! -e "$selected_path" ]; then
        return
    fi
    
    # Get original dimensions
    local orig_width=$(/usr/bin/sips -g pixelWidth "$selected_path" 2>/dev/null | /usr/bin/awk '/pixelWidth/{print $2}')
    local orig_height=$(/usr/bin/sips -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/awk '/pixelHeight/{print $2}')
    
    echo "[DEBUG calculate_exact_from_original] orig_width=$orig_width, orig_height=$orig_height"
    
    if [ -n "$orig_width" ] && [ -n "$orig_height" ]; then
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$orig_width"
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$orig_height"
        # Update environment variables for build_sips_args
        export OMC_ACTIONUI_VIEW_31_VALUE="$orig_width"
        export OMC_ACTIONUI_VIEW_32_VALUE="$orig_height"
    fi
    
    # Clear corrected values file
    rm -f "$CORRECTED_VALUES_FILE"
}

# Function to calculate dimensions based on percentage
calculate_percent_dimensions() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    local percent="$OMC_ACTIONUI_VIEW_31_VALUE"
    
    if [ -z "$selected_path" ] || [ ! -e "$selected_path" ]; then
        return
    fi
    
    if [ -z "$percent" ]; then
        return
    fi
    
    # Validate percentage - default to 100 if invalid
    if ! [[ "$percent" =~ ^[0-9]+$ ]] || [ "$percent" -lt 1 ]; then
        percent=100
    elif [ "$percent" -gt 500 ]; then
        percent=500
    fi
    
    echo "[DEBUG calculate_percent_dimensions] percent=$percent"
    
    # Get original dimensions
    local orig_width=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelWidth" | /usr/bin/awk '{print $2}')
    local orig_height=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$selected_path" 2>/dev/null | /usr/bin/grep "pixelHeight" | /usr/bin/awk '{print $2}')
    
    echo "[DEBUG] orig_width=$orig_width, orig_height=$orig_height"
    
    if [ -n "$orig_width" ] && [ -n "$orig_height" ] && [ "$orig_width" -gt 0 ]; then
        local new_width=$(echo "scale=0; $orig_width * $percent / 100" | /usr/bin/bc)
        local new_height=$(echo "scale=0; $orig_height * $percent / 100" | /usr/bin/bc)
        echo "[DEBUG] Setting calculated dimensions: ${new_width}x${new_height}"
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$new_width"
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$new_height"
    fi
}

# Function to validate and correct quality value in UI
validate_quality() {
    local quality="$OMC_ACTIONUI_VIEW_51_VALUE"
    local corrected="$quality"
    
    if [ -z "$quality" ] || [ "$quality" = "default" ]; then
        corrected="80"
    elif [[ "$quality" =~ ^[0-9]+$ ]]; then
        if [ "$quality" -gt 100 ]; then
            corrected="100"
        elif [ "$quality" -lt 1 ]; then
            corrected="1"
        fi
    else
        corrected="80"
    fi
    
    if [ "$corrected" != "$quality" ]; then
        echo "[DEBUG] Correcting quality from $quality to $corrected"
        "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} "$corrected"
    fi
}

echo "[DEBUG sips.update.preview]"

# Validate quality field and correct if needed
validate_quality

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

# Re-read width/height values from UI (they may have been updated by handle_resize_mode_change)
width="$OMC_ACTIONUI_VIEW_31_VALUE"
height="$OMC_ACTIONUI_VIEW_32_VALUE"

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

# Build and execute sips command (pass image path for percentage calculation)
sips_args=$(build_sips_args "$selected_path")

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
