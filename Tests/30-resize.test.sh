#!/bin/sh
# Tests/30-resize.test.sh - the resize argument builder and the mode switcher.
#
# This is the regression suite for the defect the applet shipped with: the window
# opened on Exact Pixels with both pixel fields reading 0, build_sips_args emitted
# "-z 0 0", and sips refused every conversion while the applet said nothing.
#
# Two distinct claims are made about every case, and both are needed. That the
# builder produced the intended argument list is a string comparison and could be
# satisfied by a list sips rejects. That sips accepts the list is an exit status
# and could be satisfied by a list that resizes nothing. Only together do they
# say the applet asked for the right thing and the right thing worked.
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.sips.sh"

section "preconditions"
check_preconditions

landscape="$(fixture landscape.png)"   # 400 x 300
portrait="$(fixture portrait.png)"     # 60 x 180
tiny="$(fixture tiny.png)"             # 8 x 4
out="$OMCTEST_WORK/out.png"

# --------------------------------------------------------------------------
section "the original defect: a zero dimension never reaches sips"
# --------------------------------------------------------------------------
# What the window used to hand the builder on open. Exact mode with both fields
# at 0 is the exact state that failed.
check "exact mode with 0 x 0 builds no resize at all" "" \
    "$(sips_args_for exact 0 0 "$landscape")"
# The claim that actually matters, in the currency the bug was paid in: sips
# accepts what the builder produced. The old code emitted "-z 0 0" here, which
# sips rejects, and this check is what would have caught it.
check "and what it does build, sips accepts" "0" \
    "$(sips_accepts_args "$(sips_args_for exact 0 0 "$landscape")" "$landscape" "$out")"
check "the image was still converted, at its own size" "400x300" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# The positive control for the two checks above. If sips_accepts_args returned 0
# for everything - a broken helper, a swallowed error - the assertions would be
# vacuous. It has to be able to say no.
check "the harness can tell a bad argument list from a good one" "no" \
    "$(sips_accepts_args "-z 0 0" "$landscape" "$out" | /usr/bin/grep -q '^0$' && echo yes || echo no)"
/bin/rm -f "$out"

# --------------------------------------------------------------------------
section "every field a user can empty or mistype drops its flag"
# --------------------------------------------------------------------------
# The general form of the same defect. sips refuses a zero or negative
# dimension, so a field that cannot be used must not produce a flag - the worst
# outcome allowed is a conversion at the original size.
for _case in "exact::" "exact:0:0" "exact:abc:def" "exact:-5:-5" "exact:100:" \
             "width:0:" "width::" "width:abc:" \
             "height::0" "height::" "height::x1" \
             "longest:0:" "longest::" "longest: :"; do
    _mode=${_case%%:*}
    _rest=${_case#*:}
    _w=${_rest%%:*}
    _h=${_rest#*:}
    check "$_mode with width [$_w] height [$_h] builds nothing" "" \
        "$(sips_args_for "$_mode" "$_w" "$_h" "$landscape")"
done

# The positive control for that whole loop: usable values must still build
# something, or "builds nothing" is being satisfied by a builder that never
# builds anything.
check "a usable exact size does build a flag" "-z 200 100" \
    "$(sips_args_for exact 100 200 "$landscape")"

# --------------------------------------------------------------------------
section "exact pixels asks sips for exactly those pixels"
# --------------------------------------------------------------------------
# sips -z takes HEIGHT then WIDTH. A builder that swaps them produces a valid
# command that resizes to the wrong shape, which no exit status would catch -
# hence fixtures with unequal sides and an assertion on the output's dimensions.
args=$(sips_args_for exact 100 200 "$landscape")
check "the height comes first, as sips wants" "-z 200 100" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$landscape" "$out")"
check "and the result is 100 wide by 200 high" "100x200" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# --------------------------------------------------------------------------
section "single-axis modes resample on their own axis"
# --------------------------------------------------------------------------
args=$(sips_args_for width 200 "" "$landscape")
check "width mode resamples the width" "--resampleWidth 200" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$landscape" "$out")"
check "and the aspect ratio is kept" "200x150" "$(dimensions_of "$out")"
/bin/rm -f "$out"

args=$(sips_args_for height "" 90 "$portrait")
check "height mode resamples the height" "--resampleHeight 90" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$portrait" "$out")"
check "and the aspect ratio is kept" "30x90" "$(dimensions_of "$out")"
/bin/rm -f "$out"

args=$(sips_args_for longest 100 "" "$portrait")
check "longest-edge mode uses -Z" "-Z 100" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$portrait" "$out")"
# 60 x 180 bounded to 100 on its longest edge: the height is what gets capped.
check "and the longest edge is the one capped" "33x100" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# --------------------------------------------------------------------------
section "percentage: 100 is free, and everything else is computed per image"
# --------------------------------------------------------------------------
# 100 % means "leave it alone", and re-encoding an image at its own dimensions is
# a resample pass bought for nothing. The builder emits no flag at all.
check "100 percent builds no resize flag" "" \
    "$(sips_args_for percent 100 "" "$landscape")"

args=$(sips_args_for percent 50 "" "$landscape")
check "50 percent of 400x300 is 150 200 in sips order" "-z 150 200" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$landscape" "$out")"
check "and the image really halved" "200x150" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# The percentage is resolved against each image, not once for the batch. Same
# percentage, different image, different pixels - that is the whole reason
# build_sips_args takes a path.
check "the same percentage against a different image gives different pixels" \
    "-z 90 30" "$(sips_args_for percent 50 "" "$portrait")"

# --------------------------------------------------------------------------
section "percentage is clamped at both ends"
# --------------------------------------------------------------------------
check "an absurd percentage is capped at 500" "-z 1500 2000" \
    "$(sips_args_for percent 9999 "" "$landscape")"

# 8 x 4 at 10 % rounds the height to zero, which sips refuses. The clamp to 1 is
# what keeps the original defect from coming back through arithmetic.
args=$(sips_args_for percent 10 "" "$tiny")
check "a scale that rounds an axis to zero clamps it to one" "-z 1 1" "$args"
check "and sips accepts that too" "0" "$(sips_accepts_args "$args" "$tiny" "$out")"
/bin/rm -f "$out"

# Percent needs an image to measure. With none, it must build nothing rather
# than guess - the preview runs in exactly this state before anything is picked.
check "percent with no image builds nothing" "" "$(sips_args_for percent 50 "" "")"

# --------------------------------------------------------------------------
section "switching modes moves the fields to the right unit"
# --------------------------------------------------------------------------
reset_window
omc_run sips.init
select_file "$landscape"

# Into exact from percent: the width field holds 100 meaning percent, and 100
# pixels is not what the user asked for. Both fields are reseeded from the image.
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
check_status "the mode change succeeded" 0
check "the width field became the image's width"  "400" "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height field its height"           "300" "$(ui_value "$HEIGHT_FIELD_ID")"
check "the height field is shown for exact mode"  "false" "$(field_hidden "$HEIGHT_FIELD_ID")"
check "the x separator with it"                   "false" "$(field_hidden "$X_TEXT_ID")"
check "and the percent sign is put away"          "true"  "$(field_hidden "$PERCENT_SIGN_ID")"

# Back to percent: always resets to 100, whatever pixel value was there.
omc_control "$WIDTH_FIELD_ID" 400
omc_control "$HEIGHT_FIELD_ID" 300
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_run sips.update.preview
check "percent mode resets to 100"            "$DEFAULT_RESIZE_PERCENT" "$(ui_value "$WIDTH_FIELD_ID")"
check "the percent sign comes back"           "false" "$(field_hidden "$PERCENT_SIGN_ID")"
check "and the height field goes away"        "true"  "$(field_hidden "$HEIGHT_FIELD_ID")"

# --------------------------------------------------------------------------
section "a width the user typed survives the switch to exact"
# --------------------------------------------------------------------------
# Reseeding unconditionally would throw away a deliberate choice. Width mode with
# a real image derives the matching height, so the pair is already consistent and
# must be left alone.
#
# The sequence is the user's, step by step, because the applet distinguishes
# them. Arriving in width mode FROM percent reseeds the field - the number
# standing in it meant percent and would be a lie as a pixel width - so the width
# has to be typed after that switch, not before it, exactly as a user would.
reset_window
omc_run sips.init
select_file "$landscape"

omc_control "$RESIZE_MODE_PICKER_ID" width
omc_run sips.update.preview
check "arriving in width mode seeds the field from the image" "400" \
    "$(ui_value "$WIDTH_FIELD_ID")"

# Now the user types. Same mode as last time, so the handler only recalculates.
omc_control "$WIDTH_FIELD_ID" 200
omc_run sips.update.preview
check "width mode derived the matching height" "150" "$(ui_value "$HEIGHT_FIELD_ID")"

# The derived height was written by the handler, so it has to be bridged back in
# as input - the harness does not do that, and without it the next dispatch would
# see whatever this test last set by hand.
bridge_field "$HEIGHT_FIELD_ID"
omc_control "$RESIZE_MODE_PICKER_ID" exact

# "The pair survived" is the absence of a write, and the recording still holds
# the 400 an earlier dispatch put there - which would read exactly like a fresh
# reseed. Clear it first, so what remains is only what THIS dispatch did.
ui_reset
omc_run sips.update.preview
check "the switch to exact left the typed width alone" "" "$(ui_value "$WIDTH_FIELD_ID")"
check "and the derived height alone"                   "" "$(ui_value "$HEIGHT_FIELD_ID")"

# Re-dispatching on the same mode does nothing at all: the switcher compares
# against the mode it recorded last time and returns early. Worth pinning,
# because it is also why the positive control below cannot simply re-run.
ui_reset
omc_run sips.update.preview
check "re-entering the same mode writes nothing" "" "$(ui_value "$WIDTH_FIELD_ID")"

# The positive control, without which the pair above is satisfied by a handler
# that writes nothing ever. A real mode change, with one field left unusable:
# the switcher must reseed both from the image.
omc_control "$RESIZE_MODE_PICKER_ID" width
omc_run sips.update.preview
omc_control "$WIDTH_FIELD_ID" 200
omc_control "$HEIGHT_FIELD_ID" 0
omc_control "$RESIZE_MODE_PICKER_ID" exact
ui_reset
omc_run sips.update.preview
check "but an unusable height does bring the reseed back" "400" "$(ui_value "$WIDTH_FIELD_ID")"
check "for both fields"                                   "300" "$(ui_value "$HEIGHT_FIELD_ID")"

# --------------------------------------------------------------------------
section "a percentage cannot escape into a mode that means pixels"
# --------------------------------------------------------------------------
# The subtle version of the original defect, and the reason the reseed reports
# whether it happened. Set a percentage, take the selection away, then switch to
# a pixel mode: the reseed is asked for but there is no image to measure, and
# leaving 250 in the field would turn "250 percent" into "250 pixels" on the next
# Convert - silently, for every file in the batch.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_run sips.update.preview

omc_control "$WIDTH_FIELD_ID" 250
clear_selection
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
check "the stale percentage was cleared from the width field" "" \
    "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height field with it" "" "$(ui_value "$HEIGHT_FIELD_ID")"
# What the cleared field is worth: the builder now drops the flag, so the batch
# converts at original size instead of forcing every image to 250 pixels.
check "so the builder asks for no resize" "" "$(sips_args_for exact "" "" "$landscape")"

# The same leak on the way into the single-axis modes, where a stray percentage
# is merely less obviously wrong.
for _mode in width longest; do
    reset_window
    omc_run sips.init
    select_file "$landscape"
    omc_control "$RESIZE_MODE_PICKER_ID" percent
    omc_run sips.update.preview
    omc_control "$WIDTH_FIELD_ID" 250
    clear_selection
    omc_control "$RESIZE_MODE_PICKER_ID" "$_mode"
    omc_run sips.update.preview
    check "$_mode mode cleared the stale percentage too" "" "$(ui_value "$WIDTH_FIELD_ID")"
done

# --------------------------------------------------------------------------
section "the resize picker responds before any image is in the list"
# --------------------------------------------------------------------------
# The window now opens empty, so the mode switcher runs before there is a
# selection. It used to sit behind an "is anything selected" guard, which made
# the picker inert on a fresh window - the state every user starts in.
reset_window
omc_run sips.init
clear_selection
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
check_status "the handler succeeded with an empty list" 0
check "the height field appeared anyway" "false" "$(field_hidden "$HEIGHT_FIELD_ID")"
check "and the percent sign went away"   "true"  "$(field_hidden "$PERCENT_SIGN_ID")"

# --------------------------------------------------------------------------
section "cumulative: no handler wrote to a view id the window does not declare"
# --------------------------------------------------------------------------
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no bare value write clobbered the table's rows" "" "$(ui_suspect_writes)"
check "the harness detected no misuse" "" "$(ui_errors)"
check "the id set was extracted" "yes" \
    "$([ -s "$OMCTEST_UI/known_ids.txt" ] && echo yes || echo no)"

omctest_end
