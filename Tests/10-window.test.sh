#!/bin/sh
# Tests/10-window.test.sh - the window as it opens.
#
# This file exists because of a specific defect: the window used to come up on
# Exact Pixels with its integer-formatted width and height fields reading 0, so
# every conversion failed with "-z 0 0" and said nothing. The fix is a default,
# and a default is only worth what a test says about it - so the resize controls'
# opening state is pinned here field by field.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.sips.sh"

section "preconditions"
check_preconditions

# --------------------------------------------------------------------------
section "the window opens in its declared state"
# --------------------------------------------------------------------------
reset_window

# The structural control for every assertion below that reads a control value:
# if the extraction silently matched nothing, this says so rather than letting
# later checks pass against an empty window.
check "the declared defaults loaded" "yes" \
    "$([ "${OMCTEST_DEFAULTS_APPLIED:-0}" -gt 5 ] && echo yes || echo no)"

# The heart of the bug fix. A picker's starting value is its first option, so
# this asserts the JSON option ORDER, which is the thing that actually decides
# what the user sees - not the applet's DEFAULT_RESIZE_MODE constant, which
# could agree with the code while the window disagreed with both.
eval "resize_start=\$OMC_ACTIONUI_VIEW_${RESIZE_MODE_PICKER_ID}_VALUE"
check "the resize picker opens on percentage" "$DEFAULT_RESIZE_MODE" "$resize_start"
check "it does not open on exact pixels" "no" "$(contains "$resize_start" "exact")"

# The precise defect: an integer-formatted TextField that declares no value
# renders and reports as 0, and 0 is what sips refuses. So the width field has to
# declare one. Read from the document rather than from omc_control_defaults,
# which reads "text" and cannot see a formatted field's "value" - see
# declared_prop in the test lib.
check "the width field declares an opening value" "$DEFAULT_RESIZE_PERCENT" \
    "$(declared_prop Sips "$WIDTH_FIELD_ID" value)"
# The positive control for that accessor: an assertion about a declared property
# is worthless if the reader silently finds nothing for every id.
check "the declared-property reader works" "integer" \
    "$(declared_prop Sips "$WIDTH_FIELD_ID" format)"

# The companion fields open hidden, because percent mode uses neither. Declared
# in the document rather than left to init, so the window is never briefly wrong.
check "the height field is declared hidden" "true" \
    "$(declared_prop Sips "$HEIGHT_FIELD_ID" hidden)"
check "the x separator is declared hidden"  "true" \
    "$(declared_prop Sips "$X_TEXT_ID" hidden)"

# --------------------------------------------------------------------------
section "init leaves the window ready to use with nothing dropped on it"
# --------------------------------------------------------------------------
reset_window
omc_object ""
omc_run sips.init
check_status "init succeeded" 0

check "the image list starts empty" "0" "$(file_count)"
check "the table was actively emptied, not merely never filled" "1" \
    "$(ui_calls "omc_table_remove_all_rows")"
check "the table's column was named" "Images" "$(ui_columns "$TABLE_ID")"

# The applet now opens with no document, so the status area is the only thing
# telling the user what to do with an empty window.
check "the status area tells the user what to do" "yes" \
    "$(contains "$(status_text)" "Drop images")"

# --------------------------------------------------------------------------
section "init sets up the resize controls for percent mode"
# --------------------------------------------------------------------------
# A picker fires no action for the value it starts on, so nothing would configure
# the companion fields if init did not do it here. Without this the window opens
# showing "100" next to an "x" and a height field, which reads as 100 x something
# rather than 100 percent.
check "the width field holds 100 after init" "$DEFAULT_RESIZE_PERCENT" \
    "$(ui_value "$WIDTH_FIELD_ID")"
check "the height field is hidden"   "true"  "$(field_hidden "$HEIGHT_FIELD_ID")"
check "the x separator is hidden"    "true"  "$(field_hidden "$X_TEXT_ID")"
check "the percent sign is showing"  "false" "$(field_hidden "$PERCENT_SIGN_ID")"
# The width field is the one thing percent mode does use, so nothing may hide it.
check "the width field was never hidden" "no" \
    "$(contains "$(field_hidden "$WIDTH_FIELD_ID")" "true")"

check "init recorded the starting mode for the next mode change" \
    "$DEFAULT_RESIZE_MODE" "$(cat "$(resize_mode_file)" 2>/dev/null)"
# The positive control for the resize_mode_file accessor: if it computed the
# wrong path the check above would compare two empty strings forever.
check_exists "the state file is where the applet's naming says it is" "$(resize_mode_file)"

# --------------------------------------------------------------------------
section "init fills the format picker from sips itself"
# --------------------------------------------------------------------------
options=$(ui_prop "$FORMAT_PICKER_ID" options)
check "the picker was given options"  "yes" "$([ -n "$options" ] && echo yes || echo no)"
check "including jpeg"                "yes" "$(contains "$options" '"tag": "jpeg"')"
check "including png"                 "yes" "$(contains "$options" '"tag": "png"')"
# Read-only formats must not be offered as an output: sips lists them too, and
# the filter that drops them is easy to lose.
check "the options are titled, not raw codes" "yes" \
    "$(contains "$options" '"title": "JPEG (Photo)"')"

check "the quality field opens at 80" "80" "$(ui_value "$QUALITY_FIELD_ID")"

# --------------------------------------------------------------------------
section "a window opened on dropped images seeds itself from them"
# --------------------------------------------------------------------------
# Files dropped on the app icon arrive as OMC_OBJ_PATH on the chained command.
# This is the path the migration changed - the window used to be attached to the
# main command directly - so it is worth an explicit test.
reset_window
omc_object "$(fixture landscape.png)"
omc_run sips.init
check_status "init succeeded with an object" 0

check "the dropped image is in the list" "1" "$(file_count)"
check "listed by name"      "landscape.png" "$(file_list_names)"
check "and by path"         "$(fixture landscape.png)" "$(file_list)"

# Init selects and previews the first row directly rather than chaining to the
# selection handler, to avoid racing the selection it just made.
check "the first row is selected"        "0" "$(ui_selection "$TABLE_ID")"
check "the preview shows it"             "$(fixture landscape.png)" "$(ui_value "$IMAGE_PREVIEW_ID")"
check "and the row's buttons came alive" "1" "$(ui_enabled "$REMOVE_BUTTON_ID")"
check "reveal too"                       "1" "$(ui_enabled "$REVEAL_BUTTON_ID")"
check "info too"                         "1" "$(ui_enabled "$INFO_BUTTON_ID")"

# --------------------------------------------------------------------------
section "File > Open... seeds a new window through the pasteboard"
# --------------------------------------------------------------------------
reset_window
omc_dialog_answer choose_object "$(fixture photo.jpg)"
omc_run sips.open
check_status "the open handler succeeded" 0

check "it asked for a window to be made" "1" "$(chain_asked sips.new)"
check "and left the selection where the new window will look" \
    "$(fixture photo.jpg)" "$(pb_open_paths get)"

# The window the chain would open. Note OMC_OBJ_PATH is empty here - this is the
# path that distinguishes Open... from a drop on the app icon.
omc_object ""
omc_run sips.init
check "the new window picked the selection up" "1" "$(file_count)"
check "from the pasteboard, not from the object" "$(fixture photo.jpg)" "$(file_list)"
check "and consumed it, so the next window opens empty" "" "$(pb_open_paths get)"

# The positive control for that last check: an empty read has to mean "cleared",
# not "this accessor never worked".
pb_open_paths set "sentinel" >/dev/null 2>&1
check "the pasteboard accessor does read back" "sentinel" "$(pb_open_paths get)"

# --------------------------------------------------------------------------
section "a canceled Open... makes no window and leaves nothing behind"
# --------------------------------------------------------------------------
reset_window
chains_reset
omc_dialog_answer choose_object ""
omc_run sips.open
check_status "the handler succeeded" 0
check "no window was asked for" "0" "$(chain_asked sips.new)"
check "and nothing was handed off" "" "$(pb_open_paths get)"

# --------------------------------------------------------------------------
section "closing the window cleans up its per-window scratch"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init
check_exists "init wrote the resize state file" "$(resize_mode_file)"

omc_run sips.cancel
check_status "the cancel handler succeeded" 0
check_absent "the resize state file is gone" "$(resize_mode_file)"
check_absent "and the preview directory with it" "$(preview_dir)"

# --------------------------------------------------------------------------
section "cumulative: no handler wrote to a view id the window does not declare"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no bare value write clobbered the table's rows" "" "$(ui_suspect_writes)"
check "the harness detected no misuse" "" "$(ui_errors)"
# The control for the three above: they are silently inert if the bundle
# declared no ids at all.
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
