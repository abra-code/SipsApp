#!/bin/sh
# Tests/25-format.test.sh - the compression controls following the output format.
#
# sips.format.changed is the one handler the rest of this suite never dispatches,
# and it is not trivial: quality means nothing for a format with no lossy
# setting, and TIFF wants a compression scheme rather than a quality number.
# Leaving the wrong control live invites the user to type a value that is then
# silently ignored.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.sips.sh"

section "preconditions"
check_preconditions

# --------------------------------------------------------------------------
section "lossy formats get a quality field and no compression picker"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init

for _format in jpeg heic jp2 avif; do
    omc_fire sips.format.changed "$FORMAT_PICKER_ID" "$_format"
    check_status "$_format was handled" 0
    check "$_format leaves the quality field live" "false" \
        "$(ui_prop "$QUALITY_FIELD_ID" disabled)"
    check "and hides the compression picker" "true" \
        "$(ui_prop "$COMPRESSION_PICKER_ID" hidden)"
done

# --------------------------------------------------------------------------
section "tiff swaps the quality field for a compression picker"
# --------------------------------------------------------------------------
omc_fire sips.format.changed "$FORMAT_PICKER_ID" tiff
check "the quality field goes dead" "true" "$(ui_prop "$QUALITY_FIELD_ID" disabled)"
check "and the compression picker appears" "false" \
    "$(ui_prop "$COMPRESSION_PICKER_ID" hidden)"

schemes="$(ui_prop "$COMPRESSION_PICKER_ID" options)"
check "LZW is offered"      "yes" "$(contains "$schemes" '"tag": "lzw"')"
check "and a default"       "yes" "$(contains "$schemes" '"tag": "default"')"

# --------------------------------------------------------------------------
section "a format with neither setting has both put away"
# --------------------------------------------------------------------------
for _format in png gif bmp; do
    omc_fire sips.format.changed "$FORMAT_PICKER_ID" "$_format"
    check "$_format has no quality setting" "true" "$(ui_prop "$QUALITY_FIELD_ID" disabled)"
    check "and no compression picker"       "true" "$(ui_prop "$COMPRESSION_PICKER_ID" hidden)"
done

# --------------------------------------------------------------------------
section "an out-of-range quality is corrected in the field, not just on the way out"
# --------------------------------------------------------------------------
# build_sips_args clamps too, but only for the run it is building. If the field
# still shows 500 the user is looking at a number the applet is not using.
reset_window
omc_run sips.init

omc_control "$QUALITY_FIELD_ID" 500
ui_reset
omc_fire sips.format.changed "$FORMAT_PICKER_ID" jpeg
check "too high is pulled down to 100" "100" "$(ui_value "$QUALITY_FIELD_ID")"

omc_control "$QUALITY_FIELD_ID" 0
ui_reset
omc_fire sips.format.changed "$FORMAT_PICKER_ID" jpeg
check "too low is pushed up to 1" "1" "$(ui_value "$QUALITY_FIELD_ID")"

omc_control "$QUALITY_FIELD_ID" abc
ui_reset
omc_fire sips.format.changed "$FORMAT_PICKER_ID" jpeg
check "and nonsense falls back to 80" "80" "$(ui_value "$QUALITY_FIELD_ID")"

# The control for the three above: a value already in range must be left alone,
# or "the field was corrected" is being satisfied by a handler that rewrites it
# every time.
omc_control "$QUALITY_FIELD_ID" 60
ui_reset
omc_fire sips.format.changed "$FORMAT_PICKER_ID" jpeg
check "a usable quality is not touched" "" "$(ui_value "$QUALITY_FIELD_ID")"

# --------------------------------------------------------------------------
section "the quality the field shows is the quality sips is asked for"
# --------------------------------------------------------------------------
# The field and the argument builder clamp independently, so they can disagree.
# This is the check that says they do not.
check "a usable quality is passed through" "-s format jpeg -s formatOptions 60" \
    "$(sips_args_with_format jpeg 60)"
check "an absurd one is clamped for the run too" "-s format jpeg -s formatOptions 100" \
    "$(sips_args_with_format jpeg 500)"
check "and nonsense falls back to the same 80" "-s format jpeg -s formatOptions 80" \
    "$(sips_args_with_format jpeg abc)"

# --------------------------------------------------------------------------
section "cumulative: the last section's window writes were all declared"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
