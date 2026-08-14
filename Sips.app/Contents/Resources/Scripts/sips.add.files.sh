#!/bin/bash
# sips.add.files.sh - Add files via file picker

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Files selected via CHOOSE_OBJECT_DIALOG are in OMC_DLG_CHOOSE_OBJECT_PATH (newline separated)
if [ -n "$OMC_DLG_CHOOSE_OBJECT_PATH" ]; then
    add_files_to_table "$OMC_DLG_CHOOSE_OBJECT_PATH"
fi

# Refresh controls based on current selection. Adding to a window that had
# nothing selected takes the first row instead, so the preview and the pixel
# fields have an image to describe.
if ! adopt_first_row_if_unselected; then
    "$OMC_OMC_SUPPORT_PATH/omc_next_command" "${OMC_CURRENT_COMMAND_GUID}" "sips.files.selection.changed"
fi
