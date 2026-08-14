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

# The builder acts on what the user typed and ignores what the applet worked out
# from the selected image, so every check on it stands on a claim about which is
# which. The sections below are about the argument list itself, so they say once
# that every value in them is the user's.
typed_resize_fields

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
for _case in "exact::" "exact:0:0" "exact:abc:def" "exact:-5:-5" \
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

# One side of an exact size, with the other side unusable, is not the same as
# nothing asked for: the user did type a width. Resampling that one axis honors
# it and keeps the file's proportions, which beats silently ignoring it.
args=$(sips_args_for exact 100 "" "$landscape")
check "an exact width with no usable height resamples the width" \
    "--resampleWidth 100" "$args"
check "sips accepts it" "0" "$(sips_accepts_args "$args" "$landscape" "$out")"
check "and the aspect ratio is kept" "100x75" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# The positive control for that whole loop: usable values must still build
# something, or "builds nothing" is being satisfied by a builder that never
# builds anything.
check "a usable exact size does build a flag" "-z 200 100" \
    "$(sips_args_for exact 100 200 "$landscape")"

# --------------------------------------------------------------------------
section "a size that would flatten the other axis is spelled out instead"
# --------------------------------------------------------------------------
# The single-axis flags hand sips one number and let it work out the other, and
# sips applies no floor to what it works out: 8 x 4 asked for a width of 1 comes
# to a height of zero, and sips refuses the whole conversion rather than
# clamping.
check "sips really does refuse it" "no" \
    "$(sips_accepts_args "--resampleWidth 1" "$tiny" "$out" | /usr/bin/grep -q '^0$' && echo yes || echo no)"
/bin/rm -f "$out"

# So the applet asks for both sides itself, floored at 1 - the pair the field is
# already showing, and the same answer the percent branch reaches when a scale
# rounds an axis away. The size the user typed is honored either way.
args=$(sips_args_for width 1 "" "$tiny")
check "width mode spells the pair out rather than handing over a flag sips refuses" \
    "-z 1 1" "$args"
check "and sips accepts what it built" "0" "$(sips_accepts_args "$args" "$tiny" "$out")"
check "at the size the fields were showing" "1x1" "$(dimensions_of "$out")"
/bin/rm -f "$out"

check "longest edge does the same" "-z 1 1" "$(sips_args_for longest 1 "" "$tiny")"
# Height mode collapses on a TALL image, not on the wide one above: it is the
# axis sips is left to work out that runs out of pixels. 60 x 180 asked for a
# height of 1 comes to a width of zero, while the same request against 8 x 4
# leaves a perfectly good 2 - so the wide fixture would have passed this check
# with the substitution removed.
check "height mode too, on an image tall enough for it" "-z 1 1" \
    "$(sips_args_for height "" 1 "$portrait")"
check "and the same height against a wide image resamples as usual" \
    "--resampleHeight 1" "$(sips_args_for height "" 1 "$tiny")"
# Exact pixels reaches the same flags whenever only one axis was asked for.
set_resize_state exact typed auto 0 0
check "and exact pixels, where only one axis was asked for" "-z 1 1" \
    "$(sips_args_for exact 1 "" "$tiny")"
typed_resize_fields

# The negative control for the substitution: one more pixel and the other axis
# survives, so the ordinary resample flag must come back. Otherwise "-z 1 1" is
# being produced by a builder that has stopped measuring.
args=$(sips_args_for width 2 "" "$tiny")
check "a size that leaves a pixel on the other axis resamples normally" \
    "--resampleWidth 2" "$args"
check "and sips accepts that" "0" "$(sips_accepts_args "$args" "$tiny" "$out")"
check "at the size it promised" "2x1" "$(dimensions_of "$out")"
/bin/rm -f "$out"

# With no file to measure there is nothing to substitute against, and the same
# size against a bigger image is perfectly ordinary, so the resample flag stands.
check "an unmeasurable image gets the ordinary flag" \
    "--resampleWidth 1" "$(sips_args_for width 1 "" "")"

# --------------------------------------------------------------------------
section "a number the applet worked out is not an instruction"
# --------------------------------------------------------------------------
# The difference the whole mechanism exists to make. The fields fill themselves
# in from the SELECTED image; carrying those numbers into the conversion would
# force one file's dimensions onto every other file, and would re-aim the batch
# every time the user clicked a different row. Only what the user typed counts.
#
# The state file is written directly here: what these checks are about is the
# builder's reading of it, not the route the window took to get there.
set_resize_state exact auto auto 400 300
check "fields the applet filled in build no resize at all" "" \
    "$(sips_args_for exact 400 300 "$landscape")"

# The positive control: the same numbers, recorded as the user's, must build the
# resize. Otherwise "builds nothing" is being satisfied by a builder that has
# stopped working.
set_resize_state exact typed typed 400 300
check "the same numbers typed by the user do build one" "-z 300 400" \
    "$(sips_args_for exact 400 300 "$landscape")"

# A width typed against a height the applet derived: the width is the
# instruction, and the derived height must not turn into one.
set_resize_state exact typed auto 800 600
check "a typed width with a derived height resamples the width" \
    "--resampleWidth 800" "$(sips_args_for exact 800 600 "$landscape")"
set_resize_state exact auto typed 800 600
check "and the same the other way round" \
    "--resampleHeight 600" "$(sips_args_for exact 800 600 "$landscape")"

# The single-axis modes have the same rule, one field at a time.
set_resize_state width auto auto 400 300
check "a width the applet filled in builds nothing" "" \
    "$(sips_args_for width 400 300 "$landscape")"
set_resize_state longest auto auto 400 300
check "a longest edge the applet filled in builds nothing" "" \
    "$(sips_args_for longest 400 "" "$landscape")"
set_resize_state height auto auto 400 300
check "a height the applet filled in builds nothing" "" \
    "$(sips_args_for height "" 300 "$landscape")"

# A value that reached the builder before any handler recorded it - pressing
# Convert straight after typing - is still the user's. The state file says the
# applet last wrote 400; the field says something else; only the user could have
# put it there.
set_resize_state width auto auto 400 300
check "a size typed but not yet recorded still counts as the user's" \
    "--resampleWidth 250" "$(sips_args_for width 250 "" "$landscape")"

# That inference needs something to compare against. With the state file gone -
# TMPDIR is purged, and the file is only rewritten when a resize control is
# touched, so a window left open long enough gets there - the applet's own
# writes are gone from the record too, and every field looks like it holds
# something it never wrote. Reading that as "the user asked for this" would take
# the dimensions of whichever image happened to be selected and force them on
# the whole batch, which is the defect this section exists to prevent, arrived
# at from the other side.
forget_resize_state
check "with no record at all, nothing counts as asked for" "" \
    "$(sips_args_for exact 400 300 "$landscape")"
check "not in the single-axis modes either" "" \
    "$(sips_args_for width 400 "" "$landscape")"

typed_resize_fields

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

# Re-dispatching on the same mode writes nothing. Not because the handler stops
# early - it recomputes the fields on every dispatch - but because the values it
# arrives at are the ones already standing there, and the field writers suppress
# a write that would change nothing. Worth pinning: it is why the positive
# control below cannot simply re-run.
ui_reset
omc_run sips.update.preview
check "re-entering the same mode writes nothing" "" "$(ui_value "$WIDTH_FIELD_ID")"

# The positive control, without which the pair above is satisfied by a handler
# that writes nothing ever. Emptying the field is how the user hands it back, so
# it is also the one thing that must bring the reseed on.
omc_control "$WIDTH_FIELD_ID" ""
ui_reset
omc_run sips.update.preview
check "emptying the width field fills it from the image again" "400" \
    "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height follows it"                             "300" \
    "$(ui_value "$HEIGHT_FIELD_ID")"
check "the applet has the field back" "auto" "$(resize_state width_source)"
# Said out loud, because nothing on screen distinguishes a field that follows the
# selection from one that does not.
check "and the user was told what changed" "yes" \
    "$(contains "$(status_text)" "Following the selected image again")"

# --------------------------------------------------------------------------
section "a typed size is a rule for the batch and does not move"
# --------------------------------------------------------------------------
# The question this whole mechanism answers: with several images in the list and
# one size in the fields, does the size belong to the selected image or to the
# batch? Both, depending on where it came from - and this is the "typed" half.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview

omc_control "$WIDTH_FIELD_ID" 800
omc_run sips.update.preview
check "the typed width is recorded as the user's" "typed" "$(resize_state width_source)"
check "and the user was told it now applies to every image" "yes" \
    "$(contains "$(status_text)" "Fixed for every image")"
# The conversion has to draw the same distinction the fields do, or the whole
# mechanism stops at the picker: the width was asked for, the height was worked
# out, so only the width is an instruction.
check "the batch resamples the typed width and leaves the derived height out" \
    "--resampleWidth 800" "$(sips_args_for exact 800 600 "$landscape")"
# The other field is still the applet's, so it keeps the image's proportions
# rather than snapping to its original height, which would stretch the result.
check "the height came along in proportion" "600" "$(ui_value "$HEIGHT_FIELD_ID")"

# Now the selection moves. The typed width is the whole point: it must not.
#
# Only the height is bridged. bridge_field replays the last value the APPLET
# wrote, and the applet did not write the width - the user did, and the harness
# is already carrying that. Bridging it too would replace the typed 800 with the
# 400 an earlier dispatch put there and quietly take the section's subject away.
bridge_field "$HEIGHT_FIELD_ID"
select_file "$portrait"
ui_reset
omc_run sips.files.selection.changed
check_status "the selection handler succeeded" 0
check "the typed width stayed where the user put it" "" "$(ui_value "$WIDTH_FIELD_ID")"
check "and it is still recorded as theirs" "typed" "$(resize_state width_source)"
# 60 x 180 at a fixed 800 wide: the height the applet owns tracks the new image.
check "the height it owns moved to the new image" "2400" "$(ui_value "$HEIGHT_FIELD_ID")"

# --------------------------------------------------------------------------
section "the side the applet works out agrees with what sips will produce"
# --------------------------------------------------------------------------
# The derived field is a promise about the output, so it has to be computed the
# way sips computes it. sips truncates: 8 x 4 resampled to 5 wide comes out 2
# high, and a field saying 3 would be the applet describing a result it is not
# going to get. The claim is checked against the converted file rather than
# against a second copy of the arithmetic.
reset_window
omc_run sips.init
select_file "$tiny"
omc_control "$RESIZE_MODE_PICKER_ID" width
omc_run sips.update.preview
omc_control "$WIDTH_FIELD_ID" 5
omc_run sips.update.preview

shown="$(ui_value "$HEIGHT_FIELD_ID")"
check "the applet says the other side will be 2" "2" "$shown"
args=$(sips_args_for width 5 "" "$tiny")
check "sips accepts what that builds" "0" "$(sips_accepts_args "$args" "$tiny" "$out")"
check "and the file it wrote is the size the field promised" "5x${shown}" \
    "$(dimensions_of "$out")"
/bin/rm -f "$out"

# --------------------------------------------------------------------------
section "a size committed by clicking another image is still the user's"
# --------------------------------------------------------------------------
# The dispatch the whole pin mechanism was built for. A text field commits on
# focus loss, so typing a size and clicking straight onto another row delivers
# the size on the SELECTION's dispatch, not on the field's own action. A refresh
# that did not look first would overwrite it with the newly selected image's
# dimensions, and the user would watch their size disappear as they clicked.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
bridge_field "$WIDTH_FIELD_ID"
bridge_field "$HEIGHT_FIELD_ID"

omc_control "$WIDTH_FIELD_ID" 900
select_file "$portrait"
ui_reset
omc_run sips.files.selection.changed
check_status "the selection handler succeeded" 0
check "the width typed on the way out was noticed" "typed" \
    "$(resize_state width_source)"
check "and not overwritten by the newly selected image" "" \
    "$(ui_value "$WIDTH_FIELD_ID")"
# 60 x 180 at a fixed 900 wide.
check "the height it owns moved to that image" "2700" "$(ui_value "$HEIGHT_FIELD_ID")"
check "and the selection handler is the one that said so" "yes" \
    "$(contains "$(status_text)" "Fixed for every image")"

# --------------------------------------------------------------------------
section "a field the applet owns follows the selection"
# --------------------------------------------------------------------------
# The defect as reported: the pixel fields showed the size of nothing at all and
# went on showing it however the selection changed.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
check "the fields opened on the selected image" "400" "$(ui_value "$WIDTH_FIELD_ID")"

bridge_field "$WIDTH_FIELD_ID"
bridge_field "$HEIGHT_FIELD_ID"
select_file "$portrait"
ui_reset
omc_run sips.files.selection.changed
check "the width field moved to the newly selected image" "60" \
    "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height field with it"                      "180" \
    "$(ui_value "$HEIGHT_FIELD_ID")"
# Nothing changed hands here, so the status area has no business saying anything.
check "and nothing was announced" "no" \
    "$(contains "$(status_text)" "Fixed for every image")"

# The single-axis modes describe the selected image too, each on its own axis.
for _case in "width:60" "longest:180" "height:180"; do
    _mode=${_case%%:*}
    _expected=${_case#*:}
    reset_window
    omc_run sips.init
    select_file "$landscape"
    omc_control "$RESIZE_MODE_PICKER_ID" "$_mode"
    omc_run sips.update.preview
    bridge_field "$WIDTH_FIELD_ID"
    bridge_field "$HEIGHT_FIELD_ID"
    select_file "$portrait"
    ui_reset
    omc_run sips.files.selection.changed
    if [ "$_mode" = "height" ]; then
        check "$_mode mode followed the selection" "$_expected" "$(ui_value "$HEIGHT_FIELD_ID")"
    else
        check "$_mode mode followed the selection" "$_expected" "$(ui_value "$WIDTH_FIELD_ID")"
    fi
done

# --------------------------------------------------------------------------
section "with nothing selected the fields are empty, not zero"
# --------------------------------------------------------------------------
# An empty field builds no flag, so the batch converts at each file's own size.
# A field reading 0 was the original defect: it looks like a size, it is the one
# size sips refuses, and it made every conversion fail silently.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
# Both fields have a real size to lose. Without this the checks below read "" for
# a field that was simply never written and would pass on an applet that does
# nothing at all.
check "the width field held the image's width"  "400" "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height field its height"         "300" "$(ui_value "$HEIGHT_FIELD_ID")"
bridge_field "$WIDTH_FIELD_ID"
bridge_field "$HEIGHT_FIELD_ID"

clear_selection
ui_reset
omc_run sips.files.selection.changed
check "the width field emptied with the selection"  "" "$(ui_value "$WIDTH_FIELD_ID")"
check "and the height field with it"                "" "$(ui_value "$HEIGHT_FIELD_ID")"
check "so the builder asks for no resize at all" "" \
    "$(sips_args_for exact "$(ui_value "$WIDTH_FIELD_ID")" "$(ui_value "$HEIGHT_FIELD_ID")" "$landscape")"

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

# The same leak by a different route. The state file lives in TMPDIR, which the
# system purges, and it is only rewritten when a resize control is touched - so
# a window left open for days reaches its next mode switch with no record of
# where it came from. An unrecognized previous mode is the percent case with
# less information, not more: the number standing in the field is then of
# unknown unit, and guessing "pixels" is how 250 % becomes 250 px.
reset_window
omc_run sips.init
select_file "$landscape"
omc_control "$RESIZE_MODE_PICKER_ID" percent
omc_run sips.update.preview
omc_control "$WIDTH_FIELD_ID" 250

forget_resize_state
clear_selection
omc_control "$RESIZE_MODE_PICKER_ID" exact
omc_run sips.update.preview
check "a lost state file does not turn a percentage into pixels" "" \
    "$(ui_value "$WIDTH_FIELD_ID")"
check "and the field went back to the applet rather than being read as typed" \
    "auto" "$(resize_state width_source)"

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
