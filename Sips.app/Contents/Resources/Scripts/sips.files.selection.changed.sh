#!/bin/bash
# sips.files.selection.changed.sh - Handle file selection changes

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

echo "[DEBUG sips.files.selection.changed]"

# Get selected row - column 1 is filename, column 2 is path (hidden)
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

echo "[DEBUG] selected_path = '$selected_path'"

# Update buttons and preview based on selection
if [ -n "$selected_path" ]; then
    echo "[DEBUG] Enabling buttons, showing preview for: $selected_path"
    
    "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_enable
    "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_enable
    "$dialog_tool" "$window_uuid" ${INFO_BUTTON_ID} omc_enable
    
    # Update image preview (show original until Preview button is clicked)
    update_image_preview "$selected_path"
    
    echo "[DEBUG] Preview updated"
else
    echo "[DEBUG] No selection, disabling buttons, clearing preview"
    
    "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_disable
    "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_disable
    "$dialog_tool" "$window_uuid" ${INFO_BUTTON_ID} omc_disable
    
    # Clear image preview
    update_image_preview ""
fi

echo "[DEBUG] Done"
