# Tests/lib.test.sips.sh - Sips's own test vocabulary, for omctest.
#
# Sourced after omctest.sh by every Tests/*.test.sh file. Holds the things the
# harness has no business knowing: how this applet's table is shaped, where it
# keeps its per-window state, and how to call into lib.sips.sh directly.

# omc_control_defaults arrived in API 2. Without it a test would start from a
# blank window - every picker empty, every field unset - which for this applet is
# not a window any user can reach, and the resize defaults are exactly what the
# suite is here to pin down.
if [ "${OMCTEST_API_VERSION:-0}" -lt 2 ]; then
    printf 'lib.test.sips: needs omctest API 2 or newer, found %s\n' \
        "${OMCTEST_API_VERSION:-none}" >&2
    exit 1
fi

APP_SCRIPTS="$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts"
APP_LIB="$APP_SCRIPTS/lib.sips.sh"

# ---------------------------------------------------------------------------
# View ids, imported from the applet rather than restated
# ---------------------------------------------------------------------------

# lib.sips.sh writes them as NAME_ID=10. A second list here could disagree with
# that one, and a test suite asserting against ids the app stopped using is
# worse than no suite at all.
eval "$(/usr/bin/sed -n 's/^\([A-Z][A-Z0-9_]*_ID\)=\([0-9][0-9]*\)$/\1=\2/p' "$APP_LIB")"

# The resize defaults are the subject of half this suite, so they are imported
# too rather than retyped - a test that hardcodes 100 would keep passing if the
# applet changed its mind.
eval "$(/usr/bin/sed -n \
    -e 's/^\(DEFAULT_RESIZE_PERCENT\)=\([0-9][0-9]*\)$/\1=\2/p' \
    -e 's/^\(DEFAULT_RESIZE_MODE\)="\([a-z][a-z]*\)"$/\1=\2/p' \
    "$APP_LIB")"

# Without this guard a renamed constant expands to the empty string, omc_control
# writes OMC_ACTIONUI_VIEW__VALUE, and the file fails check by check with no hint
# why. With it, it fails once and names what went missing.
for _required in TABLE_ID FILE_INFO_VIEW_ID REMOVE_BUTTON_ID REVEAL_BUTTON_ID \
                 INFO_BUTTON_ID IMAGE_PREVIEW_ID RESIZE_MODE_PICKER_ID \
                 WIDTH_FIELD_ID HEIGHT_FIELD_ID X_TEXT_ID PERCENT_SIGN_ID \
                 ROTATE_PICKER_ID FLIP_PICKER_ID \
                 FORMAT_PICKER_ID QUALITY_FIELD_ID COMPRESSION_PICKER_ID \
                 DEFAULT_RESIZE_MODE DEFAULT_RESIZE_PERCENT; do
    eval "_value=\${$_required}"
    if [ -z "$_value" ]; then
        printf 'lib.test.sips: %s did not import from lib.sips.sh\n' "$_required" >&2
        exit 1
    fi
done
unset _required _value

# The hidden path column. The applet names it only inside variable names it
# builds by hand (OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS), so there is no
# constant to import - which makes it exactly the kind of number that drifts.
# Pin it, and check the applet still agrees.
TABLE_PATH_COLUMN=2

app_uses_path_column() { # -> yes | no
    if /usr/bin/grep -q "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS" \
        "$APP_LIB"; then
        echo yes
    else
        echo no
    fi
}

# ---------------------------------------------------------------------------
# Calling into the applet's library
# ---------------------------------------------------------------------------

# Run a library function in a subshell with lib.sips.sh loaded.
#
# The subshell keeps the library's globals out of the test file and stops a
# function that exits from taking the whole file with it. Arguments are expanded
# by the CALLING shell, so a call naming one of the library's own constants needs
# sips_eval instead.
sips_call() { # <function> [argument ...]
    ( . "$APP_LIB" >/dev/null 2>&1
      "$@" )
}

# As above, but the first argument is shell text evaluated INSIDE the subshell,
# so it can name the library's constants.
sips_eval() { # <shell-text> [argument ...]
    local _text="$1"
    shift
    ( . "$APP_LIB" >/dev/null 2>&1
      eval "$_text" )
}

# The sips arguments the applet would build for the given resize settings.
#
# The values travel through the environment the way the engine delivers them,
# because that is what build_sips_args reads - passing them as function arguments
# would test a calling convention the app does not have.
#
# `export "NAME=value"` rather than the `NAME=value command` prefix form: the
# name here is built by expanding a view id, and a prefix assignment whose name
# side contains an expansion is not an assignment at all - the shell reads the
# whole word as a command. That failure is silent, and it leaves every field
# unset, which looks exactly like a builder that refuses everything.
#
# The rotation, flip and format controls are pinned empty so each case is about
# resizing alone; the format is added back by sips_accepts_args, which needs an
# operation for sips to produce a file.
sips_args_for() { # <mode> <width> <height> [image-path]
    (
        export "OMC_ACTIONUI_VIEW_${RESIZE_MODE_PICKER_ID}_VALUE=$1"
        export "OMC_ACTIONUI_VIEW_${WIDTH_FIELD_ID}_VALUE=$2"
        export "OMC_ACTIONUI_VIEW_${HEIGHT_FIELD_ID}_VALUE=$3"
        export "OMC_ACTIONUI_VIEW_${FORMAT_PICKER_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${QUALITY_FIELD_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${COMPRESSION_PICKER_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${ROTATE_PICKER_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${FLIP_PICKER_ID}_VALUE="
        . "$APP_LIB" >/dev/null 2>&1
        # The builder accumulates with "$sips_args -flag" from an empty string,
        # so its result carries a leading space. Normalize the spacing rather
        # than writing it into every expected value: what these assertions are
        # about is the argument list, and the callers word-split it anyway, so
        # the whitespace between the words is not a property worth pinning.
        _built=$(build_sips_args "$4")
        echo $_built
    )
}

# The sips arguments the applet would build for a format and quality, with the
# resize controls pinned out of the way.
#
# The counterpart of sips_args_for: that one isolates resizing, this one isolates
# the format side, so a check about quality clamping cannot be answered by a
# resize flag appearing or disappearing.
sips_args_with_format() { # <format> <quality>
    (
        export "OMC_ACTIONUI_VIEW_${RESIZE_MODE_PICKER_ID}_VALUE=percent"
        export "OMC_ACTIONUI_VIEW_${WIDTH_FIELD_ID}_VALUE=$DEFAULT_RESIZE_PERCENT"
        export "OMC_ACTIONUI_VIEW_${HEIGHT_FIELD_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${FORMAT_PICKER_ID}_VALUE=$1"
        export "OMC_ACTIONUI_VIEW_${QUALITY_FIELD_ID}_VALUE=$2"
        export "OMC_ACTIONUI_VIEW_${COMPRESSION_PICKER_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${ROTATE_PICKER_ID}_VALUE="
        export "OMC_ACTIONUI_VIEW_${FLIP_PICKER_ID}_VALUE="
        . "$APP_LIB" >/dev/null 2>&1
        _built=$(build_sips_args "")
        echo $_built
    )
}

# Run an argument list the applet built against the real sips, and echo the exit
# status. The join the argument assertions alone cannot make: a list can be
# exactly what was intended and still be one the binary refuses. This is how the
# original "-z 0 0" defect is pinned - as a status, not as a string.
#
# A format flag is always appended, for two reasons. It is what the applet
# itself always passes, so this is the real invocation rather than a reduced
# one. And sips with no operation at all exits 0 while writing no output file,
# so without it the "no resize" cases would assert against a file that was never
# created and read as though the conversion had been skipped.
sips_accepts_args() { # <args> <input> <output> -> exit status
    # $1 is deliberately unquoted: it is a built command line, and word
    # splitting is what turns it back into arguments, exactly as the applet's
    # own callers do it.
    /usr/bin/sips $1 -s format png --out "$3" "$2" >/dev/null 2>&1
    printf '%s' "$?"
}

# ---------------------------------------------------------------------------
# The image list: table 10, and the env var the engine derives from it
# ---------------------------------------------------------------------------

# Rows are two tab-separated fields - display name, path - and the path is the
# hidden second column.
file_list() { ui_rows "$TABLE_ID" | /usr/bin/cut -f "$TABLE_PATH_COLUMN"; }
file_list_names() { ui_rows "$TABLE_ID" | /usr/bin/cut -f 1; }
file_count() { ui_row_count "$TABLE_ID"; }

status_text() { ui_value "$FILE_INFO_VIEW_ID"; }

# Export the image list the way the engine would, from whatever the table now
# holds.
#
# The harness records what a handler wrote to the table but does not feed it back
# as OMC_ACTIONUI_TABLE_<t>_COLUMN_<c>_ALL_ROWS on the next dispatch. Every
# handler here that acts on more than the selected row reads the list through
# that variable, so without this bridge they would all see an empty list and pass
# for the wrong reason.
sync_file_list() {
    local rows
    rows=$(file_list)
    omctest_setvar "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS" "$rows"
}

# Dispatch a handler that reads the whole list, with the list exported the way
# the engine would export it at dispatch time.
run_with_list() { # <script-stem>
    sync_file_list
    omc_run "$1"
}

select_file() { omc_table_cell "$TABLE_ID" "$TABLE_PATH_COLUMN" "$1"; }
clear_selection() { omc_table_cell "$TABLE_ID" "$TABLE_PATH_COLUMN" ""; }

# ---------------------------------------------------------------------------
# Reading the window back
# ---------------------------------------------------------------------------

# This applet shows and hides through omc_set_property "hidden", not omc_show /
# omc_hide, so ui_visible never learns anything about it - it would read empty
# for every field forever, and every visibility assertion would be vacuous.
# Read the property the applet actually sets.
field_hidden() { ui_prop "$1" hidden; }

# Feed a value a handler just wrote back in as the next dispatch's input.
#
# The engine exports current control values on every dispatch, but the harness
# only records what a handler wrote - it does not feed it back. Any sequence
# where one handler's output is the next one's input has to say so explicitly,
# or the second handler sees whatever the test last set by hand and the check
# passes for the wrong reason.
bridge_field() { omc_control "$1" "$(ui_value "$1")"; }

# A property as the ActionUI DOCUMENT declares it, before any handler runs.
#
# omc_control_defaults cannot answer this for the resize fields: they are
# format: "integer" TextFields, whose declared value lives in "value" rather
# than "text" (the ActionUI TextField schema: "Used instead of text when format
# is set"), and the harness's default extraction reads "text". So the one
# property this suite most needs to pin - the width field's opening 100 - is
# invisible to omc_control_defaults and has to be read from the document.
#
# That is not a workaround, it is the more direct assertion: what the field
# declares IS what the window shows before init writes anything, and a field
# declaring nothing is what produced the original 0 x 0.
declared_prop() { # <document-name> <view-id> <property> -> declared value, or ""
    /usr/bin/python3 - \
        "$OMC_APP_BUNDLE_PATH/Contents/Resources/Base.lproj/$1.json" "$2" "$3" <<'PY'
import json, sys
document, wanted, key = sys.argv[1], int(sys.argv[2]), sys.argv[3]
found = []
def walk(node):
    if found:
        return
    if isinstance(node, dict):
        if node.get("id") == wanted:
            properties = node.get("properties", {})
            if key in properties:
                found.append(properties[key])
            return
        for child in node.values():
            walk(child)
    elif isinstance(node, list):
        for child in node:
            walk(child)
walk(json.load(open(document)))
if found:
    value = found[0]
    sys.stdout.write(("true" if value else "false") if isinstance(value, bool) else str(value))
PY
}

# ---------------------------------------------------------------------------
# Per-window state
# ---------------------------------------------------------------------------

# Recomputed the way the applet computes it, interpolating the window uuid rather
# than hardcoding a path - so a change to the applet's naming shows up as a
# missing file rather than as a test quietly asserting about a file nobody
# writes.
resize_mode_file() { printf '%s' "${TMPDIR:-/tmp}/sips_resize_mode_${OMC_ACTIONUI_WINDOW_UUID}.txt"; }
preview_dir() { printf '%s' "${TMPDIR:-/tmp}/sips_preview_${OMC_ACTIONUI_WINDOW_UUID}"; }

# The Open... handoff key is global rather than per-window - it has to be, since
# the window it feeds does not exist yet - so a value left behind by one section
# silently seeds the next one's window.
pb_open_paths() { "$OMC_OMC_SUPPORT_PATH/pasteboard" SIPS_OPEN_PATHS "$@"; }

# ---------------------------------------------------------------------------
# Resetting between sections
# ---------------------------------------------------------------------------

# Put the window back to how it opens: declared control defaults, no rows, no
# selection, no leftover handoff, no per-window state, no recorded writes.
reset_window() {
    omc_control_defaults Sips
    pb_open_paths set "" >/dev/null 2>&1
    omc_object ""
    /bin/rm -f "$(resize_mode_file)"
    /bin/rm -rf "$(preview_dir)"
    # ui_reset deletes unknown_ids.log, suspect_writes.log and errors.log, so a
    # single check at the end of the file would only ever see the last section
    # and would read as a standing guarantee while being inert. Check here, on
    # the way past, so every section is covered by the reset that follows it.
    check "no writes to undeclared view ids in the section just ended" "" "$(ui_unknown_writes)"
    check "no bare value write clobbered the table's rows" "" "$(ui_suspect_writes)"
    check "the harness detected no misuse" "" "$(ui_errors)"
    ui_reset
    alerts_reset
    alert_answers_reset
    # Chain history is cumulative across the file, so a section asserting a
    # chain did NOT happen would inherit an earlier section's legitimate one.
    chains_reset
    unset "OMC_ACTIONUI_TABLE_${TABLE_ID}_COLUMN_${TABLE_PATH_COLUMN}_ALL_ROWS"
}

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

contains() { # <haystack> <needle> -> yes | no
    # A function rather than an inline `case`: a case pattern's ")" terminates a
    # $( ) command substitution in bash 3.2, so the obvious one-liner is a parse
    # error inside the substitution rather than a wrong answer.
    case "$1" in
        *"$2"*) echo yes ;;
        *) echo no ;;
    esac
}

# Tests/fixtures is gitignored and generated by Tests/make-fixtures.sh. Generated
# rather than committed: the assertions care about dimensions and format, not
# bytes, so the generator is a readable statement of what they depend on.
ensure_fixtures() {
    local marker="$OMCTEST_FIXTURES/landscape.png"
    [ -f "$marker" ] && return 0
    if [ ! -f "$OMCTEST_TESTS/make-fixtures.sh" ]; then
        printf 'lib.test.sips: no fixtures and no Tests/make-fixtures.sh to build them\n' >&2
        return 1
    fi
    if ! /bin/sh "$OMCTEST_TESTS/make-fixtures.sh" "$OMCTEST_FIXTURES" >/dev/null 2>&1; then
        # A half-written fixture set is worse than none: it fails later, in
        # assertions that look like applet defects.
        /bin/chmod -R u+w "$OMCTEST_FIXTURES" 2>/dev/null
        /bin/rm -rf "$OMCTEST_FIXTURES"
        printf 'lib.test.sips: fixture generation failed\n' >&2
        return 1
    fi
    return 0
}

# Pixel dimensions of an image, as "WxH". The tests assert on what sips actually
# produced, not on what the applet believed it asked for.
dimensions_of() { # <path> -> WxH, or "missing"
    [ -e "$1" ] || { printf 'missing'; return; }
    /usr/bin/sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | /usr/bin/awk '
        /pixelWidth/ { w = $2 }
        /pixelHeight/ { h = $2 }
        END { if (w == "" || h == "") print "unreadable"; else printf "%sx%s", w, h }'
}

format_of() { # <path> -> the sips format name, or "missing"
    [ -e "$1" ] || { printf 'missing'; return; }
    /usr/bin/sips -g format "$1" 2>/dev/null | /usr/bin/awk '/format:/ { print $2 }'
}

# sips is a precondition, not a thing under test. Assert it where it is needed so
# the day it goes missing the failure names it rather than surfacing as twenty
# unrelated assertion failures.
check_preconditions() {
    check_exists "precondition: sips is present" /usr/bin/sips
    check "precondition: the fixtures are present" "yes" \
        "$(ensure_fixtures && echo yes || echo no)"
    check "precondition: the applet still reads the path from column $TABLE_PATH_COLUMN" \
        "yes" "$(app_uses_path_column)"
}
