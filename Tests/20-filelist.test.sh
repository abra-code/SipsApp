#!/bin/sh
# Tests/20-filelist.test.sh - building the image list, and what a selection does.
#
# The list is the applet's only model. Everything else - the preview, the three
# row buttons, the whole batch - reads from it, so the handlers that add to it
# and take away from it are worth pinning precisely.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.sips.sh"

section "preconditions"
check_preconditions

# --------------------------------------------------------------------------
section "the add panel puts chosen images in the list"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init

omc_dialog_answer choose_object "$(fixture landscape.png)
$(fixture portrait.png)"
run_with_list sips.add.files
check_status "the add handler succeeded" 0

check "both images were added" "2" "$(file_count)"
check "sorted by display name" "landscape.png
portrait.png" "$(file_list_names)"

# Nothing was selected before the add, so the handler takes the first row itself
# rather than chaining to the selection handler and leaving the window pointing
# at nothing. The window used to fill its list and keep an empty preview beside
# a size picker with no image to describe.
check "the first row was selected" "1" "$(ui_calls "omc_select_row")"
check "the preview shows it" "$(fixture landscape.png)" \
    "$(ui_value "$IMAGE_PREVIEW_ID")"
check "and the row buttons woke up" "1" "$(ui_enabled "$REMOVE_BUTTON_ID")"

# --------------------------------------------------------------------------
section "adding more keeps what was already there"
# --------------------------------------------------------------------------
# add_files_to_table rebuilds the whole table from the engine's ALL_ROWS export
# plus the new paths, so "preserves the existing rows" is a real behavior with a
# real way to break: run_with_list is what supplies that export.
omc_dialog_answer choose_object "$(fixture photo.jpg)"
run_with_list sips.add.files
check "the list grew rather than being replaced" "3" "$(file_count)"
check "the earlier images are still there" "yes" \
    "$(contains "$(file_list_names)" "landscape.png")"

# --------------------------------------------------------------------------
section "the same image added twice appears once"
# --------------------------------------------------------------------------
omc_dialog_answer choose_object "$(fixture photo.jpg)"
run_with_list sips.add.files
check "the duplicate collapsed" "3" "$(file_count)"

# --------------------------------------------------------------------------
section "adding to a window that already has a selection leaves it alone"
# --------------------------------------------------------------------------
# The other half of the rule above. Taking the first row is for a window that is
# pointing at nothing; once the user has picked a row, the applet has no business
# moving them off it, and the usual hand-off to the selection handler stands.
reset_window
omc_run sips.init
select_file "$(fixture landscape.png)"

omc_dialog_answer choose_object "$(fixture portrait.png)"
run_with_list sips.add.files
check_status "the add handler succeeded" 0
check "the user's selection was not taken over" "0" "$(ui_calls "omc_select_row")"
check "and the controls were refreshed the usual way" "1" \
    "$(chain_asked sips.files.selection.changed)"

# --------------------------------------------------------------------------
section "a file sips cannot read is skipped, and the user is told once"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init
alerts_reset

omc_dialog_answer choose_object "$(fixture landscape.png)
$(fixture notes.txt)"
run_with_list sips.add.files

check "the image went in"       "1" "$(file_count)"
check "the text file did not"   "no" "$(contains "$(file_list_names)" "notes.txt")"
check "and exactly one alert was raised" "1" "$(alerts_count)"
check "which named the skipped file" "1" "$(alerts_mention "notes.txt")"

# --------------------------------------------------------------------------
section "a whole folder is scanned for images"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init

folder="$OMCTEST_WORK/album"
/bin/mkdir -p "$folder/nested"
/bin/cp "$(fixture landscape.png)" "$folder/one.png"
/bin/cp "$(fixture photo.jpg)" "$folder/nested/two.jpg"
/bin/cp "$(fixture notes.txt)" "$folder/readme.txt"
/bin/chmod -R u+w "$folder"

omc_dialog_answer choose_object "$folder"
run_with_list sips.add.files
check "images were found, including in subfolders" "2" "$(file_count)"
check "the text file in the folder was left out" "no" \
    "$(contains "$(file_list_names)" "readme.txt")"
# A folder's non-images are filtered silently - one alert per stray file in a
# scanned folder would be unusable. Only individually chosen files are reported.
check "and scanning a folder raises no alert" "0" "$(alerts_count)"

# --------------------------------------------------------------------------
section "dropping images on the table adds them"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init

omc_drop "$(fixture landscape.png)" "$(fixture portrait.png)"
run_with_list sips.files.drop
check_status "the drop handler succeeded" 0
check "both dropped images landed" "2" "$(file_count)"
check "the first row was selected" "1" "$(ui_calls "omc_select_row")"
check "and the preview shows it" "$(fixture landscape.png)" \
    "$(ui_value "$IMAGE_PREVIEW_ID")"

# --------------------------------------------------------------------------
section "a drop with no payload changes nothing"
# --------------------------------------------------------------------------
chains_reset
omc_trigger "$TABLE_ID"
run_with_list sips.files.drop
check_status "the handler exited cleanly" 0
check "the list is untouched" "2" "$(file_count)"
check "and nothing was refreshed" "0" "$(chain_asked sips.files.selection.changed)"

# --------------------------------------------------------------------------
section "selecting a row lights up its buttons and previews it"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init
select_file "$(fixture landscape.png)"
omc_run sips.files.selection.changed
check_status "the selection handler succeeded" 0

check "remove is live" "1" "$(ui_enabled "$REMOVE_BUTTON_ID")"
check "reveal is live" "1" "$(ui_enabled "$REVEAL_BUTTON_ID")"
check "info is live"   "1" "$(ui_enabled "$INFO_BUTTON_ID")"
check "the preview shows the selected image" "$(fixture landscape.png)" \
    "$(ui_value "$IMAGE_PREVIEW_ID")"

# --------------------------------------------------------------------------
section "losing the selection puts them back to sleep"
# --------------------------------------------------------------------------
clear_selection
omc_run sips.files.selection.changed
check "remove is dead" "0" "$(ui_enabled "$REMOVE_BUTTON_ID")"
check "reveal is dead" "0" "$(ui_enabled "$REVEAL_BUTTON_ID")"
check "info is dead"   "0" "$(ui_enabled "$INFO_BUTTON_ID")"
check "and the preview was cleared" "" "$(ui_value "$IMAGE_PREVIEW_ID")"

# --------------------------------------------------------------------------
section "remove takes out the selected row and leaves the rest"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init
omc_dialog_answer choose_object "$(fixture landscape.png)
$(fixture portrait.png)
$(fixture photo.jpg)"
run_with_list sips.add.files
check "three images to start with" "3" "$(file_count)"

select_file "$(fixture portrait.png)"
run_with_list sips.remove.selected
check_status "the remove handler succeeded" 0
check "one row went"                 "2" "$(file_count)"
check "and it was the selected one"  "no" \
    "$(contains "$(file_list_names)" "portrait.png")"
check "the others stayed"            "yes" \
    "$(contains "$(file_list_names)" "landscape.png")"

# --------------------------------------------------------------------------
section "remove with nothing selected removes nothing"
# --------------------------------------------------------------------------
clear_selection
run_with_list sips.remove.selected
check "the list is unchanged" "2" "$(file_count)"

# --------------------------------------------------------------------------
section "clear all empties the list"
# --------------------------------------------------------------------------
run_with_list sips.clear.all
check_status "the clear handler succeeded" 0
check "the list is empty" "0" "$(file_count)"
check "the table was actively emptied" "yes" \
    "$([ "$(ui_calls "omc_table_remove_all_rows")" -ge 1 ] && echo yes || echo no)"

# --------------------------------------------------------------------------
section "cumulative: no handler wrote to a view id the window does not declare"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no bare value write clobbered the table's rows" "" "$(ui_suspect_writes)"
check "the harness detected no misuse" "" "$(ui_errors)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
