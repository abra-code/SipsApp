#!/bin/sh
# Tests/40-batch.test.sh - the Convert run, end to end against the real sips.
#
# The other files assert what the applet asked for. This one runs it: real
# images in, real images out, dimensions and formats read back off the results.
# That is the only way to be sure the arguments and the binary agree - the
# original defect was a list that looked right in isolation and that sips
# refused.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.sips.sh"

section "preconditions"
check_preconditions

# Put the fixtures somewhere writable, so a run that misbehaves and writes over
# its input damages a copy rather than the fixture set.
landscape="$(fixture_copy landscape.png)"    # 400 x 300
portrait="$(fixture_copy portrait.png)"      # 60 x 180

# Convert into a fresh empty folder each time, so "the file is there" cannot be
# satisfied by something an earlier section left behind.
new_destination() { # -> path
    local dir
    dir="$(/usr/bin/mktemp -d "$OMCTEST_WORK/dest.XXXXXX")"
    printf '%s' "$dir"
}

# Set up a window holding the given images, ready to Convert.
load_images() { # <path ...>
    reset_window
    omc_run sips.init
    omc_dialog_answer choose_object "$(printf '%s\n' "$@")"
    run_with_list sips.add.files
}

# --------------------------------------------------------------------------
section "pressing Convert with an empty list says so"
# --------------------------------------------------------------------------
# The window now opens empty, so Convert is reachable with nothing to convert.
# It used to exit silently, which returned the user from the destination panel
# to a screen where nothing had changed.
reset_window
omc_run sips.init
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the handler succeeded" 0
check "the status area explains the empty list" "yes" \
    "$(contains "$(status_text)" "Nothing to convert")"
check "and nothing was written to the destination" "0" \
    "$(/usr/bin/find "$destination" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

# --------------------------------------------------------------------------
section "the default window converts every image at its own size"
# --------------------------------------------------------------------------
# The whole point of the percentage default: a user who opens the applet, drops
# images and presses Convert gets their images in a new format, unscaled - not
# the silent total failure the Exact Pixels default produced.
load_images "$landscape" "$portrait"
omc_control "$FORMAT_PICKER_ID" png
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0

check "both images were written"  "2" \
    "$(/usr/bin/find "$destination" -type f -name '*.png' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
check "the landscape kept its size" "400x300" "$(dimensions_of "$destination/landscape.png")"
check "the portrait kept its own"   "60x180"  "$(dimensions_of "$destination/portrait.png")"
check "the status area reports two successes" "yes" \
    "$(contains "$(status_text)" "2 succeeded")"
check "and no failures" "yes" "$(contains "$(status_text)" "0 failed")"

# --------------------------------------------------------------------------
section "the format picker decides the output format and extension"
# --------------------------------------------------------------------------
load_images "$landscape"
omc_control "$FORMAT_PICKER_ID" jpeg
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch

check "the file is named for the chosen format" "yes" \
    "$([ -f "$destination/landscape.jpeg" ] && echo yes || echo no)"
check "and really is that format" "jpeg" "$(format_of "$destination/landscape.jpeg")"

# --------------------------------------------------------------------------
section "a percentage scales every image against its own dimensions"
# --------------------------------------------------------------------------
# Two images with different shapes, one percentage: the proof that the scale is
# resolved per file rather than once for the batch.
load_images "$landscape" "$portrait"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_control "$WIDTH_FIELD_ID" 50
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0

check "the landscape halved" "200x150" "$(dimensions_of "$destination/landscape.png")"
check "the portrait halved too, on its own numbers" "30x90" \
    "$(dimensions_of "$destination/portrait.png")"

# --------------------------------------------------------------------------
section "exact pixels forces one size on the whole batch"
# --------------------------------------------------------------------------
# The mode the user was warned is for single images. It does what it says, and
# the test says so plainly: both images come out the same shape regardless of
# what shape they went in.
load_images "$landscape" "$portrait"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_control "$WIDTH_FIELD_ID" 120
omc_control "$HEIGHT_FIELD_ID" 60
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0
check "the landscape was forced to the exact size" "120x60" \
    "$(dimensions_of "$destination/landscape.png")"
check "and so was the portrait" "120x60" "$(dimensions_of "$destination/portrait.png")"

# --------------------------------------------------------------------------
section "a percentage the user never committed is corrected before converting"
# --------------------------------------------------------------------------
# Convert can be pressed on a number no handler has seen, because the field
# commits as the click lands. The builder caps the scale either way, so what is
# at stake is the field agreeing with what was done: 9999 left standing beside a
# batch that scaled by 500 % is the applet misreporting itself.
load_images "$landscape"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_control "$WIDTH_FIELD_ID" 9999
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0
check "the field was brought back to the cap" "500" "$(ui_value "$WIDTH_FIELD_ID")"
check "and the file is the size that number now claims" "2000x1500" \
    "$(dimensions_of "$destination/landscape.png")"

# --------------------------------------------------------------------------
section "converting does not leave the window unsure what mode it is in"
# --------------------------------------------------------------------------
# Convert writes the corrected percentage back to the field, which means it
# writes the state file - and a record that does not name the mode is worse than
# no record at all. The next dispatch compares against it, reads the missing
# mode as a mode change, and a change into percent resets the field to 100 %.
# Every unrelated control fires that dispatch: rotation, flip, quality.
#
# The purged state file is the way in, and the round the guards were added for.
load_images "$landscape"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_control "$WIDTH_FIELD_ID" 250
forget_resize_state

destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0
check "it converted at the percentage on screen" "1000x750" \
    "$(dimensions_of "$destination/landscape.png")"
check "and recorded the mode it converted in" "percent" "$(resize_state mode)"

# The consequence, through the control that would trip over it. Rotation shares
# the preview handler with the resize picker, so nudging it is a resize dispatch
# whether the user thinks so or not.
ui_reset
omc_control "$ROTATE_PICKER_ID" 90
omc_run sips.update.preview
check "so an unrelated control does not reset the percentage" "" \
    "$(ui_value "$WIDTH_FIELD_ID")"

# --------------------------------------------------------------------------
section "a size the applet filled in is not forced on the batch"
# --------------------------------------------------------------------------
# The other half of the rule, and the one with teeth. The pixel fields follow
# the selection, so they hold the dimensions of whichever row the user last
# clicked. Carrying those into the conversion would force one file's shape onto
# every other file - and the batch would come out differently depending on what
# happened to be selected when Convert was pressed. Only a size the user typed
# is an instruction.
load_images "$landscape" "$portrait"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" exact
# The window as it stands after the user picks Exact Pixels with the landscape
# selected and types nothing: the applet filled both fields in, and recorded
# that it did.
omc_control "$WIDTH_FIELD_ID" 400
omc_control "$HEIGHT_FIELD_ID" 300
set_resize_state exact auto auto 400 300
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0
check "the landscape came out at its own size" "400x300" \
    "$(dimensions_of "$destination/landscape.png")"
# The one that would have been squashed: 60 x 180 forced to 400 x 300.
check "and the portrait at its own, not the selected image's" "60x180" \
    "$(dimensions_of "$destination/portrait.png")"

# --------------------------------------------------------------------------
section "a zero size converts at the original size instead of failing"
# --------------------------------------------------------------------------
# The original defect, exercised through the whole handler rather than through
# the builder: the state the window used to open in must now produce files.
load_images "$landscape"
omc_control "$FORMAT_PICKER_ID" png
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_control "$WIDTH_FIELD_ID" 0
omc_control "$HEIGHT_FIELD_ID" 0
destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch succeeded" 0

check "the image was converted"        "400x300" "$(dimensions_of "$destination/landscape.png")"
check "the run reports it as a success" "yes" "$(contains "$(status_text)" "1 succeeded")"
check "and not as a failure"            "yes" "$(contains "$(status_text)" "0 failed")"

# --------------------------------------------------------------------------
section "an existing file is kept unless overwrite is on"
# --------------------------------------------------------------------------
load_images "$landscape"
omc_control "$FORMAT_PICKER_ID" png
destination="$(new_destination)"
printf 'not an image\n' > "$destination/landscape.png"

omc_control 14 false
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check "the existing file was left alone" "not an image" \
    "$(cat "$destination/landscape.png")"
check "and the run says it skipped one" "yes" "$(contains "$(status_text)" "1 skipped")"

omc_control 14 true
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check "with overwrite on it was replaced" "400x300" \
    "$(dimensions_of "$destination/landscape.png")"
check "and counted as a success" "yes" "$(contains "$(status_text)" "1 succeeded")"

# --------------------------------------------------------------------------
section "a listed file that has gone missing is reported, not fatal"
# --------------------------------------------------------------------------
vanishing="$OMCTEST_WORK/vanishing.png"
/bin/cp "$landscape" "$vanishing"
/bin/chmod u+w "$vanishing"
load_images "$vanishing" "$portrait"
omc_control "$FORMAT_PICKER_ID" png
/bin/rm -f "$vanishing"

destination="$(new_destination)"
omc_dialog_answer choose_folder "$destination"
run_with_list sips.start.batch
check_status "the batch still finished" 0
check "the surviving image was converted" "60x180" "$(dimensions_of "$destination/portrait.png")"
check "the missing one is counted as a failure" "yes" \
    "$(contains "$(status_text)" "1 failed")"
check "and named in the report" "yes" "$(contains "$(status_text)" "vanishing")"

# --------------------------------------------------------------------------
section "canceling the destination panel converts nothing"
# --------------------------------------------------------------------------
load_images "$landscape"
before="$(status_text)"
omc_dialog_answer choose_folder ""
run_with_list sips.start.batch
check_status "the handler exited cleanly" 0
check "the status area was not touched" "$before" "$(status_text)"

# --------------------------------------------------------------------------
section "cumulative: the last section's window writes were all declared"
# --------------------------------------------------------------------------
# Every earlier section was checked by reset_window on its way out; this covers
# the one after the last reset.
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
