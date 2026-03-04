#!/bin/bash
# lib.sips.sh - Shared functions and variables for Sips

# Control IDs
TABLE_ID=10
FILE_INFO_VIEW_ID=12
REMOVE_BUTTON_ID=102
REVEAL_BUTTON_ID=104
QUICKLOOK_BUTTON_ID=105
FORMAT_PICKER_ID=13

# Get dialog tool path
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Function to add files to the table
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
            # It's a directory - search recursively for supported files
            
            # First, find all .rtfd bundles (they are directories)
            local all_rtfd="$(/usr/bin/find "$file_path" -type d -iname "*.rtfd" ! -path "*/.*" 2>/dev/null)"
            for rtfd_bundle in $all_rtfd; do
                local filename="$("/usr/bin/basename" "$rtfd_bundle")"
                buffer="${buffer}${filename}	${rtfd_bundle}
"
            done
            
            # Then find all supported text files (excluding .rtfd bundles)
            local all_files="$(/usr/bin/find "$file_path" -type f \
                \( -iname "*.txt" -o -iname "*.rtf" -o -iname "*.html" -o -iname "*.htm" \
                -o -iname "*.doc" -o -iname "*.docx" -o -iname "*.odt" -o -iname "*.wordml" -o -iname "*.webarchive" \) \
                ! -path "*/.*" 2>/dev/null)"
            
            for found_file in $all_files; do
                # Skip if inside any .rtfd/ directory
                case "$found_file" in
                    *.rtfd/*) continue ;;
                esac
                
                # Check if it's a text file using file command
                local file_type="$(/usr/bin/file -b "$found_file" 2>/dev/null)"
                if echo "$file_type" | /usr/bin/grep -qi "\btext\b"; then
                    local filename="$("/usr/bin/basename" "$found_file")"
                    buffer="${buffer}${filename}	${found_file}
"
                fi
            done
            
        elif [ -e "$file_path" ]; then
            # It's a file - add it directly
            local filename="$("/usr/bin/basename" "$file_path")"
            buffer="${buffer}${filename}	${file_path}
"
        fi
    done <<< "$new_paths"
    
    # Sort, remove duplicates, and set table rows
    if [ -n "$buffer" ]; then
        printf "%s" "$buffer" | /usr/bin/sort -u | "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin
    else
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin <<< ""
    fi
}
