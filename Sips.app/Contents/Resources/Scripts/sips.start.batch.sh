#!/bin/bash
# sips.start.batch.sh - Run batch conversion using sips

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Get destination folder from CHOOSE_FOLDER_DIALOG
destination="$OMC_DLG_CHOOSE_FOLDER_PATH"

if [ -z "$destination" ]; then
    exit 0
fi

# Get output format from Picker id 13
output_format="$OMC_ACTIONUI_VIEW_13_VALUE"

if [ -z "$output_format" ]; then
    output_format="jpeg"
fi

# Get all file paths from the table (column 2)
file_paths="$OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS"

# The window opens with an empty list, so Convert is reachable with nothing to
# convert. Say so instead of returning from the folder panel to a still screen.
if [ -z "$file_paths" ]; then
    set_status "Nothing to convert - drop images into the list first."
    exit 0
fi

# Convert newline-separated paths to array
IFS=$'\n' read -r -d '' -a files <<< "$file_paths" || true

# Get overwrite option
overwrite="$OMC_ACTIONUI_VIEW_14_VALUE"

set_status "Converting ${#files[@]} file(s)..."

# Get resize mode for percentage handling
resize_mode="$OMC_ACTIONUI_VIEW_30_VALUE"

# A percentage typed and committed by the Convert click itself has not been past
# the preview handler, so it is corrected here as well - the builder caps it
# either way, and a batch scaled by 500 % beside a field still reading 9999 is
# the applet misreporting what it did.
if [ "$resize_mode" = "percent" ]; then
    correct_percent_field
fi

# Collect errors and results
errors=""
results=""
skipped=""

# Process each file
success_count=0
error_count=0
skipped_count=0

for file_path in "${files[@]}"; do
    if [ -e "$file_path" ]; then
        filename="$("/usr/bin/basename" "$file_path")"
        name_without_ext="${filename%.*}"
        
        output_file="$destination/${name_without_ext}.${output_format}"
        
        # Check if output exists - skip if overwrite is not enabled
        if [ -e "$output_file" ] && [ "$overwrite" != "true" ]; then
            ((skipped_count++))
            skipped="${skipped}
- ${name_without_ext}.${output_format}: skipped"
        else
            # Build sips args against this file. Percent resolves its scale
            # against the file's own dimensions; the single-axis modes need it
            # too, to see whether the axis sips works out for itself would come
            # to less than a pixel and take the conversion down with it.
            sips_args=$(build_sips_args "$file_path")
            
            output=$(/usr/bin/sips $sips_args --out "$output_file" "$file_path" 2>&1)
            exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                ((success_count++))
                results="${results}
✓ ${name_without_ext}.${output_format}"
            else
                ((error_count++))
                errors="${errors}
✗ ${name_without_ext}.${output_format}: ${output}"
            fi
        fi
    else
        ((error_count++))
        errors="${errors}
✗ ${file_path}: file does not exist"
    fi
done

# Build completion message
result_message="Destination Folder:
${destination}

Converted: ${success_count} succeeded, ${skipped_count} skipped, ${error_count} failed${results}${skipped}${errors}"

set_status "$result_message"
