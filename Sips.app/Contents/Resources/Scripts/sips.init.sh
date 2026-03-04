#!/bin/bash
# sips.init.sh - Initialize the table

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Set up table columns - one visible column (path is hidden in data)
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_columns "Images"
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_column_widths 270

# Clear any existing rows
"$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_remove_all_rows

# If files were dropped on the app, add them
# OMC_OBJ_PATH contains newline-separated list of file paths
if [ -n "$OMC_OBJ_PATH" ]; then
    add_files_to_table "$OMC_OBJ_PATH"
fi
