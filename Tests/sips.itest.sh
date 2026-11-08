# Tests/sips.itest.sh - Sips through the real engine (appletbuilder itest, OMC 5.5).
#
# The omctest suites (*.test.sh) run Sips's handlers one at a time with stand-in tools; this file
# launches the applet itself, for the line of OMC 5.5's hands-on checklist "launch; the main
# command chains to *.new, which opens the window. The window must open with its initial values
# filled in", and for the Open... handoff: files left on the SIPS_OPEN_PATHS pasteboard (private to the
# test run) seed the next window's list. Every file is the test's own, in $ITEST_WORK.

eval "$(/usr/bin/sed -n \
    -e 's/^\([A-Z][A-Z0-9_]*_ID\)=\([0-9][0-9]*\)$/\1=\2/p' \
    -e 's/^\([A-Z][A-Z0-9_]*\)="\([A-Za-z0-9_. ,-]*\)"$/\1="\2"/p' \
    "$ITEST_APP/Contents/Resources/Scripts/lib.sips.sh")"
check "the ids imported from lib.sips.sh" "yes" "$([ -n "$TABLE_ID" ] && [ -n "$OPEN_PATHS_PB_KEY" ] && printf yes || printf no)"

rows() { # <window> -> the list's rows, as the bridge gives them (JSON)
    itest_call actionui.getRows "{\"window\": \"$1\", \"viewID\": $TABLE_ID}"
}

section "The launch chain opens a filled-in window"
# The harness waited for the launch already; this one reports a slow launch as a timeout.
itest_wait_idle 60
launched="$(itest_windows)"
check "one window after the launch" "1" "$(printf '%s\n' "$launched" | /usr/bin/grep -c .)"
check "quality starts at 80" "80" "$(itest_value "$launched" "$QUALITY_FIELD_ID")"
check "resizing by the default mode" "$DEFAULT_RESIZE_MODE" "$(itest_value "$launched" "$RESIZE_MODE_PICKER_ID")"
# The two above are also what the window JSON gives on its own (its quality field says 80, and a
# picker starts on its first option, percent); the info line is set by sips.init.sh alone.
check "the info line explains what to do" "Drop images into the list, pick a format and size, then press Convert." "$(itest_value "$launched" "$FILE_INFO_VIEW_ID")"
check "with an empty list" "[]" "$(rows "$launched")"

section "Files handed over on the Open... pasteboard seed a new window"
SAMPLE_A="$ITEST_WORK/itest sample one.png"
SAMPLE_B="$ITEST_WORK/itest-sample-two.png"
: > "$SAMPLE_A"
: > "$SAMPLE_B"
# Empty files: adding to the list goes by the extension; nothing here converts them.
itest_set_pasteboard "$(printf '%s\n%s' "$SAMPLE_A" "$SAMPLE_B")" "$OPEN_PATHS_PB_KEY"
before="$(itest_windows)"
itest_run sips.new > /dev/null
itest_wait_idle 60
window="$(itest_new_window "$before")"
check "sips.new opened a window" "yes" "$([ -n "$window" ] && printf yes || printf no)"
listed="$(rows "$window")"
check_contains "the first file is listed" "itest sample one.png" "$listed"
check_contains "and the second" "itest-sample-two.png" "$listed"
check "the handoff was used up" "" "$(itest_pasteboard "$OPEN_PATHS_PB_KEY")"
check "the launch's window kept its empty list" "[]" "$(rows "$launched")"
