#!/bin/bash
# lib.sips.sh - Shared functions and variables for Sips

# Control IDs
TABLE_ID=10
FILE_INFO_VIEW_ID=12
REMOVE_BUTTON_ID=102
REVEAL_BUTTON_ID=104
INFO_BUTTON_ID=106
IMAGE_PREVIEW_ID=20

# Resize controls
RESIZE_MODE_PICKER_ID=30
WIDTH_FIELD_ID=31
HEIGHT_FIELD_ID=32

# Rotation/Flip controls
ROTATE_PICKER_ID=40
FLIP_PICKER_ID=42

# Format controls
FORMAT_PICKER_ID=13

# Get dialog tool path
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Function to add image files to the table
# Arguments: newline-separated list of file/directory paths to add
add_files_to_table() {
    local new_paths="$1"
    local buffer=""
    
    # Get existing file paths from the table
    local existing_paths="$OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS"
    
    # Add existing files first
    if [ -n "$existing_paths" ]; then
        while IFS= read -r file_path; do
            if [ -n "$file_path" ]; then
                local filename="$("/usr/bin/basename" "$file_path")"
                buffer="${buffer}${filename}	${file_path}
"
            fi
        done <<< "$existing_paths"
    fi
    
    # Add new files/directories
    while IFS= read -r file_path; do
        if [ -d "$file_path" ]; then
            # It's a directory - search recursively for supported image files
            local all_images="$(/usr/bin/find "$file_path" -type f \
                \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.tiff" -o -iname "*.tif" \
                -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.heic" -o -iname "*.heif" \
                -o -iname "*.webp" -o -iname "*.psd" -o -iname "*.pdf" -o -iname "*.jp2" \) \
                ! -path "*/.*" 2>/dev/null)"
            
            for found_file in $all_images; do
                local filename="$("/usr/bin/basename" "$found_file")"
                buffer="${buffer}${filename}	${found_file}
"
            done
            
        elif [ -e "$file_path" ]; then
            # It's a file - check if it's an image
            local filename="$("/usr/bin/basename" "$file_path")"
            case "${filename##*.}" in
                jpg|jpeg|png|tiff|tif|gif|bmp|heic|heif|webp|psd|pdf|jp2)
                    buffer="${buffer}${filename}	${file_path}
"
                    ;;
            esac
        fi
    done <<< "$new_paths"
    
    # Sort, remove duplicates, and set table rows
    if [ -n "$buffer" ]; then
        printf "%s" "$buffer" | /usr/bin/sort -u | "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin
    else
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin <<< ""
    fi
}

# Function to build sips command arguments from current UI settings (without input/output paths)
# Returns: sips arguments string (e.g., "-s format jpeg -z 100 100 -r 90")
build_sips_args() {
    local sips_args=""
    
    # Get resize mode (30: exact/width/height/longest)
    local resize_mode="$OMC_ACTIONUI_VIEW_30_VALUE"
    
    # Get width and height values
    local width="$OMC_ACTIONUI_VIEW_31_VALUE"
    local height="$OMC_ACTIONUI_VIEW_32_VALUE"
    
    # Apply resize options
    case "$resize_mode" in
        exact)
            if [ -n "$width" ] && [ -n "$height" ]; then
                sips_args="$sips_args -z $height $width"
            fi
            ;;
        width)
            if [ -n "$width" ]; then
                sips_args="$sips_args --resampleWidth $width"
            fi
            ;;
        height)
            if [ -n "$height" ]; then
                sips_args="$sips_args --resampleHeight $height"
            fi
            ;;
        longest)
            if [ -n "$width" ]; then
                sips_args="$sips_args -Z $width"
            fi
            ;;
    esac
    
    # Get rotation (40: -180 to 180, step 90)
    local rotation="$OMC_ACTIONUI_VIEW_40_VALUE"
    if [ -n "$rotation" ] && [ "$rotation" != "0" ]; then
        sips_args="$sips_args -r $rotation"
    fi
    
    # Get flip mode (42: none/horizontal/vertical)
    local flip_mode="$OMC_ACTIONUI_VIEW_42_VALUE"
    if [ -n "$flip_mode" ] && [ "$flip_mode" != "none" ]; then
        sips_args="$sips_args -f $flip_mode"
    fi
    
    # Get output format (13)
    local output_format="$OMC_ACTIONUI_VIEW_13_VALUE"
    if [ -n "$output_format" ]; then
        sips_args="$sips_args -s format $output_format"
    fi
    
    echo "$sips_args"
}

# Function to build complete sips command from current UI settings
# Arguments: input_file output_file
# Returns: sips command line (not executed)
build_sips_command() {
    local input_file="$1"
    local output_file="$2"
    
    local sips_args
    sips_args=$(build_sips_args)
    
    # Add output path
    sips_args="$sips_args --out $output_file"
    
    # Add input file
    sips_args="$sips_args $input_file"
    
    echo "/usr/bin/sips $sips_args"
}

# Function to update image preview
# Arguments: image_file_path
update_image_preview() {
    local image_path="$1"
    
    echo "[DEBUG update_image_preview] image_path='$image_path'"
    echo "[DEBUG update_image_preview] IMAGE_PREVIEW_ID=${IMAGE_PREVIEW_ID}"
    echo "[DEBUG update_image_preview] window_uuid='$window_uuid'"
    
    if [ -n "$image_path" ] && [ -e "$image_path" ]; then
        echo "[DEBUG update_image_preview] Setting image to: $image_path"
        "$dialog_tool" "$window_uuid" ${IMAGE_PREVIEW_ID} "$image_path"
    else
        echo "[DEBUG update_image_preview] Clearing image"
        "$dialog_tool" "$window_uuid" ${IMAGE_PREVIEW_ID} ""
    fi
}

# Function to get image info using sips
# Arguments: image_file_path
get_image_info() {
    local image_path="$1"
    
    if [ -e "$image_path" ]; then
        local info=""
        info="$info$(/usr/bin/sips -g pixelWidth -g pixelHeight -g typeIdentifier "$image_path" 2>&1)"
        
        # Get file size
        local file_size="$(/usr/bin/stat -f %z "$image_path" 2>/dev/null)"
        if [ -n "$file_size" ]; then
            info="$info

File Size: $file_size bytes"
        fi
        
        # Get creation and modification dates
        local created="$(/usr/bin/stat -f "%SB" "$image_path" 2>/dev/null)"
        local modified="$(/usr/bin/stat -f "%Sm" "$image_path" 2>/dev/null)"
        
        if [ -n "$created" ] || [ -n "$modified" ]; then
            info="$info

Created: ${created}
Modified: ${modified}"
        fi
        
        echo "$info"
    else
        echo "File does not exist"
    fi
}
