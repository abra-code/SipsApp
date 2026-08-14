#!/bin/bash
# sips.files.selection.changed.sh - Handle file selection changes

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Get selected row - column 1 is filename, column 2 is path (hidden).
# Show the original image until the user changes a setting; sips.update.preview
# is what renders the converted version.
apply_file_selection "$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
