#!/bin/bash
# sips.info.sh - Show file info in a new window

# Get selected file path from table (column 2)
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

if [ -z "$selected_path" ]; then
    echo "No file selected"
    exit 0
fi

if [ ! -e "$selected_path" ]; then
    echo "File does not exist: $selected_path"
    exit 0
fi

# Get all properties using sips
file_info="$(/usr/bin/sips --getProperty all "$selected_path" 2>&1)"

# Also get file stats
file_size="$(/usr/bin/stat -f %z "$selected_path" 2>/dev/null)"
created="$(/usr/bin/stat -f "%SB" "$selected_path" 2>/dev/null)"
modified="$(/usr/bin/stat -f "%Sm" "$selected_path" 2>/dev/null)"

# Build info text
info_text="File: $selected_path

Size: $file_size bytes
Created: $created
Modified: $modified

---
$file_info"

echo "$info_text"
