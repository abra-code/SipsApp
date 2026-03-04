#!/bin/bash
# sips.files.double.click.sh - Handle double-click on file

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Get the double-clicked row path
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

if [ -n "$selected_path" ] && [ -e "$selected_path" ]; then
    # Open the file with the default application
    /usr/bin/open "$selected_path"
fi
