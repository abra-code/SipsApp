#!/bin/bash
# sips.files.selection.changed.sh - Handle file selection changes

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Get selected row - column 1 is filename, column 2 is path (hidden)
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

file_info_view_id=12
remove_file_button_id=102
reveal_button_id=104
quicklook_button_id=105
    
# Update the file info display (Text id 12 in ScrollView)
if [ -n "$selected_path" ]; then
    "$dialog_tool" "$window_uuid" "${remove_file_button_id}" omc_enable
    "$dialog_tool" "$window_uuid" "${reveal_button_id}" omc_enable
    "$dialog_tool" "$window_uuid" "${quicklook_button_id}" omc_enable
    
    # Get file info using 'file', filter out Contents line
    file_info="$(/usr/bin/sips --getProperty all "$selected_path" 2>&1)"
    
    # Get creation and modification dates using stat
    if [ -e "$selected_path" ]; then
        # Get dates in readable format
        created="$(/usr/bin/stat -f "%SB" "$selected_path" 2>/dev/null)"
        modified="$(/usr/bin/stat -f "%Sm" "$selected_path" 2>/dev/null)"
        
        if [ -n "$created" ] || [ -n "$modified" ]; then
            file_info="${file_info}

  Created: ${created}
  Modified: ${modified}"
        fi
    fi
    
    "$dialog_tool" "$window_uuid" "${file_info_view_id}" "$file_info"
else
    "$dialog_tool" "$window_uuid" "${remove_file_button_id}" omc_disable
    "$dialog_tool" "$window_uuid" "${reveal_button_id}" omc_disable
    "$dialog_tool" "$window_uuid" "${quicklook_button_id}" omc_disable
    "$dialog_tool" "$window_uuid" "${file_info_view_id}" ""
fi
