#!/bin/sh
# lib.sips.sh - Shared functions and variables for Sips

# Control IDs
TABLE_ID=10
FILE_INFO_VIEW_ID=12
REMOVE_BUTTON_ID=102
REVEAL_BUTTON_ID=104
INFO_BUTTON_ID=106
IMAGE_PREVIEW_ID=20

# Resize controls
RESIZE_MODE_PICKER_ID=30
WIDTH_FIELD_ID=31
HEIGHT_FIELD_ID=32
X_TEXT_ID=33
PERCENT_SIGN_ID=34

# Rotation/Flip controls
ROTATE_PICKER_ID=40
FLIP_PICKER_ID=42

# Format controls
FORMAT_PICKER_ID=13
COMPRESSION_PICKER_ID=50
QUALITY_FIELD_ID=51
QUALITY_LABEL_ID=52

# The resize mode the window starts on. Percentage at 100 % is the only default
# that cannot fail: it needs no knowledge of any particular image, and it means
# "keep the size" until the user asks for something else. Exact Pixels used to be
# the default and came up as 0 x 0 with nothing selected, which made every
# conversion fail with no visible reason.
DEFAULT_RESIZE_MODE="percent"
DEFAULT_RESIZE_PERCENT=100

# The largest scale factor the applet will act on. Past this, a batch turns into
# gigabytes of upsampled pixels no one asked for.
MAX_RESIZE_PERCENT=500

# Get dialog tool path
dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
next_cmd="$OMC_OMC_SUPPORT_PATH/omc_next_command"
alert_tool="$OMC_OMC_SUPPORT_PATH/alert"
pasteboard_tool="$OMC_OMC_SUPPORT_PATH/pasteboard"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"

# Private pasteboard key: hand a selection from the Open... panel to a window
# that does not exist yet, so its init script can pick it up.
OPEN_PATHS_PB_KEY="SIPS_OPEN_PATHS"

# State file carrying the resize controls across script invocations: the active
# mode, where each pixel field's number came from, and what the applet last put
# in each field. Keyed by window UUID - the applet can have several windows open
# at once (File > Open... makes a new one) and a shared file would let one
# window's mode switch rewrite another window's fields.
RESIZE_STATE_FILE="${TMPDIR:-/tmp}/sips_resize_state_${window_uuid}.txt"

# Where the number in a pixel field came from.
#
# The width and height fields do two different jobs, and telling them apart is
# what makes the picker predictable. A number the applet derived from the
# selected image is a description of that image, so it follows the selection
# from one file to the next. A number the user typed is the size they want for
# the batch, so it stays put until they clear the field. Without the
# distinction, every selection change is either wrong for the user who typed a
# size or wrong for the user who wants to see what they picked.
SOURCE_AUTO="auto"
SOURCE_TYPED="typed"

# Set the status text view content
# Arguments: text
set_status() {
    "$dialog_tool" "$window_uuid" ${FILE_INFO_VIEW_ID} "$1"
}

# Echo the argument when it is a positive whole number, nothing otherwise.
# Every resize flag below is built from a text field the user can leave empty or
# fill with junk; sips rejects a zero or negative dimension and the whole
# conversion fails, so a value that cannot be used has to drop its flag instead.
# Arguments: value
positive_int() {
    case "$1" in
        '' | *[!0-9]*) return ;;
    esac
    [ "$1" -gt 0 ] && echo "$1"
}

# Get original pixel dimensions of an image file.
# Arguments: image_file_path
# Sets: _orig_width, _orig_height (caller reads these variables)
get_image_dimensions() {
    local img="$1"
    _orig_width=""
    _orig_height=""
    if [ -n "$img" ] && [ -e "$img" ]; then
        # Both numbers out of one awk. This runs once per file in a batch now -
        # the single-axis modes measure each file to see what sips will make of
        # it - and two passes over the same four lines cost a third of that
        # again for nothing.
        local dimensions=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$img" 2>/dev/null | /usr/bin/awk '
            /pixelWidth/  { w = $2 }
            /pixelHeight/ { h = $2 }
            END           { print w, h }')
        _orig_width="${dimensions% *}"
        _orig_height="${dimensions#* }"
    fi
}

# ---------------------------------------------------------------------------
# Resize state
# ---------------------------------------------------------------------------

# Read the state file into RESIZE_MODE, WIDTH_SOURCE, HEIGHT_SOURCE,
# WIDTH_LAST and HEIGHT_LAST. A missing file reads as "no mode recorded, nothing
# typed" - the same starting point init itself writes.
#
# RESIZE_STATE_LOADED says which of those two it was, and the difference
# matters: "the applet recorded that it owns this field" and "there is no record
# at all" produce identical variables but must not produce identical decisions.
# A window whose state file was purged from TMPDIR still has numbers on screen
# that the applet put there.
load_resize_state() {
    RESIZE_MODE=""
    WIDTH_SOURCE="$SOURCE_AUTO"
    HEIGHT_SOURCE="$SOURCE_AUTO"
    WIDTH_LAST=""
    HEIGHT_LAST=""
    RESIZE_STATE_LOADED="no"

    [ -f "$RESIZE_STATE_FILE" ] || return 0
    RESIZE_STATE_LOADED="yes"

    local key
    local value
    while IFS='=' read -r key value; do
        case "$key" in
            mode)          RESIZE_MODE="$value" ;;
            width_source)  WIDTH_SOURCE="$value" ;;
            height_source) HEIGHT_SOURCE="$value" ;;
            width_last)    WIDTH_LAST="$value" ;;
            height_last)   HEIGHT_LAST="$value" ;;
        esac
    done < "$RESIZE_STATE_FILE"
}

save_resize_state() {
    printf 'mode=%s\nwidth_source=%s\nheight_source=%s\nwidth_last=%s\nheight_last=%s\n' \
        "$RESIZE_MODE" "$WIDTH_SOURCE" "$HEIGHT_SOURCE" "$WIDTH_LAST" "$HEIGHT_LAST" \
        > "$RESIZE_STATE_FILE"
}

# Write a pixel field, whatever it currently holds.
#
# Three things have to move together, which is why nothing writes these fields
# directly. The window gets the value; the environment copy gets it too, because
# later functions in the same run read the fields from there and would otherwise
# work off the value this run replaced; and the state file records it, because
# the next run compares against it to decide whether the user typed something.
# Arguments: value
put_width_field() {
    "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$1"
    export OMC_ACTIONUI_VIEW_31_VALUE="$1"
    WIDTH_LAST="$1"
}

put_height_field() {
    "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$1"
    export OMC_ACTIONUI_VIEW_32_VALUE="$1"
    HEIGHT_LAST="$1"
}

# As above, but a value the field already holds is not written again. Rewriting
# it would be invisible on screen and would still count as the applet touching a
# field the user is typing in, which is exactly what the state file is trying to
# tell apart.
# Arguments: value
set_width_field() {
    if [ "$1" = "$OMC_ACTIONUI_VIEW_31_VALUE" ]; then
        WIDTH_LAST="$1"
        return 0
    fi
    put_width_field "$1"
}

set_height_field() {
    if [ "$1" = "$OMC_ACTIONUI_VIEW_32_VALUE" ]; then
        HEIGHT_LAST="$1"
        return 0
    fi
    put_height_field "$1"
}

# The percentage the applet will actually act on: a whole number, defaulted when
# the field holds nothing usable and capped at MAX_RESIZE_PERCENT.
#
# One place, because two would eventually disagree - and a conversion scaled by
# a number the field never showed is the same defect as a field showing a number
# the conversion never used.
# Arguments: field value
clamped_percent() {
    local percent="$(positive_int "$1")"
    : "${percent:=$DEFAULT_RESIZE_PERCENT}"
    [ "$percent" -gt "$MAX_RESIZE_PERCENT" ] && percent="$MAX_RESIZE_PERCENT"
    echo "$percent"
}

# Put the corrected percentage back in the field.
#
# Convert can be pressed on a percentage no handler has seen - the field commits
# as the click lands - so the correction cannot live only on the preview path,
# or the batch scales by 500 % while the field still reads 9999.
correct_percent_field() {
    load_resize_state
    # The caller reaches this only in percent mode, and it is the one place that
    # knows it. Saving without saying so would write a record claiming the applet
    # has no idea what mode it is in - which the next dispatch reads as a mode
    # change, and a mode change into percent resets the field to 100 %. A window
    # whose state file had been purged would convert at 250 % and then, the next
    # time any control was touched, silently drop to 100 %.
    RESIZE_MODE="percent"
    set_width_field "$(clamped_percent "$OMC_ACTIONUI_VIEW_31_VALUE")"
    save_resize_state
}

# One side of a resize, in proportion to the image being resized:
# value * numerator / denominator, truncated.
#
# Truncated because this number is shown to the user as what the other axis will
# come out as, and sips truncates: an 8 x 4 image resampled to 5 wide comes out
# 2 high, not the 3 that rounding would put in the field. Being right about the
# result matters more here than being closer to the real ratio.
# Arguments: value, numerator, denominator
unfloored_scale() {
    echo $(( $1 * $2 / $3 ))
}

# As above, with a floor of 1, for a field the user is going to read. Zero is
# not a size, and an image thin enough to scale to nothing on its short side
# would otherwise display one.
# Arguments: value, numerator, denominator
scale_dimension() {
    local result="$(unfloored_scale "$1" "$2" "$3")"
    [ "$result" -lt 1 ] && result=1
    echo "$result"
}

# The flag that resizes one axis of this file to this size.
#
# Normally the resample flag itself, which lets sips work out the other axis and
# so keeps each file's own proportions. But sips applies no floor to what it
# works out: given --resampleWidth 10 for a 4000 x 200 banner it arrives at a
# height of zero and refuses the conversion outright.
#
# So when the other side would come to less than a pixel, the pair is spelled
# out instead, floored at 1 - which is the pair the field is already showing,
# and the same answer the percent branch reaches when a scale rounds an axis
# away. The size the user typed is honored either way, and sips is never handed
# a request it will refuse.
# Arguments: mode (width|height|longest), size, image_path
single_axis_flag() {
    local mode="$1"
    local size="$2"

    local given_axis=""
    local other_axis=""
    local long_side_is_width="yes"

    get_image_dimensions "$3"
    # An image that can be measured tells us what sips will do with it. One that
    # cannot - including every call made without a path - tells us nothing, so
    # the resample flag stands.
    if [ -n "$(positive_int "$_orig_width")" ] && [ -n "$(positive_int "$_orig_height")" ]; then
        case "$mode" in
            width)  given_axis="$_orig_width";  other_axis="$_orig_height" ;;
            height) given_axis="$_orig_height"; other_axis="$_orig_width" ;;
            longest)
                if [ "$_orig_width" -ge "$_orig_height" ]; then
                    given_axis="$_orig_width"; other_axis="$_orig_height"
                else
                    given_axis="$_orig_height"; other_axis="$_orig_width"
                    long_side_is_width="no"
                fi
                ;;
        esac
    fi

    if [ -n "$given_axis" ] \
        && [ "$(unfloored_scale "$other_axis" "$size" "$given_axis")" -lt 1 ]; then
        # sips takes -z as HEIGHT then WIDTH.
        case "$mode" in
            width)  echo "-z 1 $size" ;;
            height) echo "-z $size 1" ;;
            longest)
                if [ "$long_side_is_width" = "yes" ]; then
                    echo "-z 1 $size"
                else
                    echo "-z $size 1"
                fi
                ;;
        esac
        return 0
    fi

    case "$mode" in
        width)   echo "--resampleWidth $size" ;;
        height)  echo "--resampleHeight $size" ;;
        longest) echo "-Z $size" ;;
    esac
}

# Notice a number the user typed over one of the applet's.
#
# The applet is the only other thing that writes these fields, and it records
# every value it puts there, so a field holding something else is a field the
# user typed in. That is the whole test - no trigger id, no guessing which
# control fired. It has to be, because the value can arrive on a dispatch that
# has nothing to do with the field: a text field commits on focus loss, so
# typing a width and clicking straight onto another image delivers the width on
# the selection's dispatch, and a refresh that did not look first would
# overwrite it.
#
# A field emptied or filled with something that is not a size goes back to the
# applet - that is how the user releases one.
#
# Sets WIDTH_PIN_CHANGED / HEIGHT_PIN_CHANGED to pinned, released or empty, so a
# caller can say what just happened.
note_typed_pixel_fields() {
    WIDTH_PIN_CHANGED=""
    HEIGHT_PIN_CHANGED=""

    local value

    value="$OMC_ACTIONUI_VIEW_31_VALUE"
    if [ "$value" != "$WIDTH_LAST" ]; then
        if [ -n "$(positive_int "$value")" ]; then
            [ "$WIDTH_SOURCE" = "$SOURCE_TYPED" ] || WIDTH_PIN_CHANGED="pinned"
            WIDTH_SOURCE="$SOURCE_TYPED"
            WIDTH_LAST="$value"
        else
            [ "$WIDTH_SOURCE" = "$SOURCE_TYPED" ] && WIDTH_PIN_CHANGED="released"
            WIDTH_SOURCE="$SOURCE_AUTO"
            set_width_field ""
        fi
    fi

    value="$OMC_ACTIONUI_VIEW_32_VALUE"
    if [ "$value" != "$HEIGHT_LAST" ]; then
        if [ -n "$(positive_int "$value")" ]; then
            [ "$HEIGHT_SOURCE" = "$SOURCE_TYPED" ] || HEIGHT_PIN_CHANGED="pinned"
            HEIGHT_SOURCE="$SOURCE_TYPED"
            HEIGHT_LAST="$value"
        else
            [ "$HEIGHT_SOURCE" = "$SOURCE_TYPED" ] && HEIGHT_PIN_CHANGED="released"
            HEIGHT_SOURCE="$SOURCE_AUTO"
            set_height_field ""
        fi
    fi
}

# Work out whether each pixel field holds a number the user typed, without
# touching the window.
#
# The read-only twin of note_typed_pixel_fields, for the conversion side: it
# asks the same question - is the field still holding what the applet put there
# - but writes nothing, so it can be asked once per file in a batch.
#
# The second half of each test matters as much as the state file. A size typed
# and committed by pressing Convert reaches the builder before any handler has
# recorded it, and a value that is not the applet's is the user's whether or not
# a dispatch has caught up yet.
#
# That second half needs a record to compare against, though. With no state file
# - TMPDIR is purged periodically, and the file is only rewritten when a resize
# control is touched, so a window left open for days gets there - every field
# would look like it holds something the applet never wrote, and a batch would
# be forced into the shape of whichever image happened to be selected. Nothing
# is known, so nothing is treated as asked for, which is where the mode switcher
# lands on the same question.
# Sets: WIDTH_IS_TYPED, HEIGHT_IS_TYPED (yes|no)
resolve_resize_sources() {
    load_resize_state

    WIDTH_IS_TYPED="no"
    HEIGHT_IS_TYPED="no"
    [ "$RESIZE_STATE_LOADED" = "yes" ] || return 0

    if [ "$WIDTH_SOURCE" = "$SOURCE_TYPED" ]; then
        WIDTH_IS_TYPED="yes"
    elif [ "$OMC_ACTIONUI_VIEW_31_VALUE" != "$WIDTH_LAST" ] \
        && [ -n "$(positive_int "$OMC_ACTIONUI_VIEW_31_VALUE")" ]; then
        WIDTH_IS_TYPED="yes"
    fi

    if [ "$HEIGHT_SOURCE" = "$SOURCE_TYPED" ]; then
        HEIGHT_IS_TYPED="yes"
    elif [ "$OMC_ACTIONUI_VIEW_32_VALUE" != "$HEIGHT_LAST" ] \
        && [ -n "$(positive_int "$OMC_ACTIONUI_VIEW_32_VALUE")" ]; then
        HEIGHT_IS_TYPED="yes"
    fi
}

# Bring the pixel fields in line with an image, leaving anything the user typed
# exactly where they put it.
#
# With no image to measure, the fields the applet owns are emptied rather than
# left holding the last image's numbers. An empty field builds no flag, so the
# conversion falls back to each file's own size - the safe direction. Numbers
# from an image that is no longer selected are the unsafe one: they look like a
# size the user chose and would be forced on every file in the batch.
# Arguments: mode, image_path (may be empty)
# Reads/updates: WIDTH_SOURCE, HEIGHT_SOURCE, WIDTH_LAST, HEIGHT_LAST
refresh_resize_fields() {
    local mode="$1"
    local image_path="$2"

    # Percent is a scale factor - there is no dimension of the selected image it
    # could mirror, and 100 % already means "whatever this image happens to be".
    case "$mode" in
        exact|width|height|longest) ;;
        *) return 0 ;;
    esac

    note_typed_pixel_fields

    get_image_dimensions "$image_path"
    local have_size="no"
    if [ -n "$(positive_int "$_orig_width")" ] && [ -n "$(positive_int "$_orig_height")" ]; then
        have_size="yes"
    fi

    # Only a usable number the user typed counts as pinned. A field they emptied
    # or filled with junk is one the applet takes back.
    local pinned_width=""
    local pinned_height=""
    [ "$WIDTH_SOURCE" = "$SOURCE_TYPED" ] && pinned_width="$(positive_int "$OMC_ACTIONUI_VIEW_31_VALUE")"
    [ "$HEIGHT_SOURCE" = "$SOURCE_TYPED" ] && pinned_height="$(positive_int "$OMC_ACTIONUI_VIEW_32_VALUE")"

    case "$mode" in
        exact)
            if [ -n "$pinned_width" ] && [ -n "$pinned_height" ]; then
                return 0
            fi
            if [ "$have_size" = "no" ]; then
                [ -n "$pinned_width" ]  || set_width_field ""
                [ -n "$pinned_height" ] || set_height_field ""
                return 0
            fi
            if [ -n "$pinned_width" ]; then
                # One side pinned, so the other keeps the image's proportions
                # rather than snapping back to its original height and stretching
                # the result.
                set_height_field "$(scale_dimension "$_orig_height" "$pinned_width" "$_orig_width")"
            elif [ -n "$pinned_height" ]; then
                set_width_field "$(scale_dimension "$_orig_width" "$pinned_height" "$_orig_height")"
            else
                set_width_field "$_orig_width"
                set_height_field "$_orig_height"
            fi
            ;;
        width)
            if [ -z "$pinned_width" ]; then
                if [ "$have_size" = "yes" ]; then
                    set_width_field "$_orig_width"
                else
                    set_width_field ""
                fi
            fi
            # The height field is hidden in this mode, but it is what a switch to
            # Exact Pixels inherits, so it is kept in step with the width instead
            # of being left at some earlier image's number.
            local width_now="$(positive_int "$OMC_ACTIONUI_VIEW_31_VALUE")"
            if [ "$have_size" = "yes" ] && [ -n "$width_now" ]; then
                set_height_field "$(scale_dimension "$_orig_height" "$width_now" "$_orig_width")"
            else
                set_height_field ""
            fi
            ;;
        height)
            if [ -z "$pinned_height" ]; then
                if [ "$have_size" = "yes" ]; then
                    set_height_field "$_orig_height"
                else
                    set_height_field ""
                fi
            fi
            local height_now="$(positive_int "$OMC_ACTIONUI_VIEW_32_VALUE")"
            if [ "$have_size" = "yes" ] && [ -n "$height_now" ]; then
                set_width_field "$(scale_dimension "$_orig_width" "$height_now" "$_orig_height")"
            else
                set_width_field ""
            fi
            ;;
        longest)
            [ -n "$pinned_width" ] && return 0
            if [ "$have_size" = "yes" ]; then
                local longest="$_orig_width"
                [ "$_orig_height" -gt "$longest" ] && longest="$_orig_height"
                set_width_field "$longest"
            else
                set_width_field ""
            fi
            ;;
    esac
}

# What the width field is called in the mode it is standing in. It is the
# longest edge in one mode and a width in the others, and a message calling it
# the wrong thing is worse than no message.
width_field_label() {
    case "$1" in
        longest) echo "longest edge" ;;
        *)       echo "width" ;;
    esac
}

# Say, once, when a field changes hands.
#
# Two identical-looking text fields where one follows the selection and the
# other does not is exactly the kind of state a user cannot see. The status area
# is the one place to explain it, and the moment it changes is the only moment
# worth explaining it in.
#
# One message, however many fields moved: the status area holds one string, so
# two calls would mean the first was never read.
# Returns 0 when it said something, 1 when there was nothing to say.
announce_pin_changes() {
    local pinned=""
    local released=""
    local label

    label="$(width_field_label "$RESIZE_MODE")"
    case "$WIDTH_PIN_CHANGED" in
        pinned)   pinned="$label ${OMC_ACTIONUI_VIEW_31_VALUE} px" ;;
        released) released="$label" ;;
    esac
    case "$HEIGHT_PIN_CHANGED" in
        pinned)
            [ -n "$pinned" ] && pinned="$pinned, "
            pinned="${pinned}height ${OMC_ACTIONUI_VIEW_32_VALUE} px"
            ;;
        released)
            [ -n "$released" ] && released="$released, "
            released="${released}height"
            ;;
    esac

    if [ -n "$pinned" ]; then
        set_status "Fixed for every image in the list: $pinned. Empty a field to follow the selected image instead."
        return 0
    fi
    if [ -n "$released" ]; then
        set_status "Following the selected image again: $released."
        return 0
    fi
    return 1
}

# Pull the pixel fields onto a newly selected image.
#
# Driven by the selection rather than by the preview: the fields describe the
# selected image, so the moment the selection moves they are describing a
# different one. Leaving them behind is what made the picker read as broken - it
# opened blank and stayed blank no matter which image was clicked.
# Arguments: image_file_path (may be empty)
refresh_resize_fields_for_selection() {
    load_resize_state
    # The picker is the authority on the current mode; the state file only
    # remembers what it was last time, which is how a mode CHANGE is detected
    # elsewhere. A picker value the engine did not export must not be mistaken
    # for one here.
    [ -n "$OMC_ACTIONUI_VIEW_30_VALUE" ] && RESIZE_MODE="$OMC_ACTIONUI_VIEW_30_VALUE"

    if [ "$RESIZE_MODE" = "percent" ]; then
        # Percent keeps no per-image value, so there is nothing to refresh - but
        # the field can still have been committed by this very click, and a
        # recorded value that disagrees with the field on screen is what the rest
        # of this machinery reads as "the user typed something".
        WIDTH_LAST="$OMC_ACTIONUI_VIEW_31_VALUE"
    else
        refresh_resize_fields "$RESIZE_MODE" "$1"
        # This is the dispatch the pin machinery exists for: a text field commits
        # on focus loss, so a size typed and then clicked away from arrives here
        # rather than on the field's own action. Saying nothing here would leave
        # the one case that needs explaining unexplained.
        announce_pin_changes
    fi

    save_resize_state
}

# Get list of readable image extensions from sips --formats
get_readable_extensions() {
    local exts=$(/usr/bin/sips --formats 2>/dev/null | /usr/bin/awk '
        NR > 2 && $2 != "--" {
            ext = $2
            if (ext == "jpeg") ext = "jpg"
            print ext
        }
    ' | /usr/bin/sort -u | /usr/bin/tr '\n' '|')
    echo "${exts%|}"
}

# Show a single consolidated alert for files skipped because their type is not
# a supported image. Aggregates so a multi-file drop produces one dialog, not one
# per file.
# Arguments: count, newline-separated list of file names
notify_unsupported_files() {
    local count="$1"
    local names="$2"
    local alert_tool="$OMC_OMC_SUPPORT_PATH/alert"

    # Cap the listed names so a large drop does not produce a giant dialog
    local max_list=10
    local shown="$(printf '%s\n' "$names" | /usr/bin/head -n "$max_list")"
    local extra=$(( count - max_list ))

    local header
    if [ "$count" -eq 1 ]; then
        header="1 file was skipped because it is not a supported image:"
    else
        header="$count files were skipped because they are not supported images:"
    fi

    local message="$header
$shown"
    if [ "$extra" -gt 0 ]; then
        message="$message
...and $extra more"
    fi

    "$alert_tool" --level caution --title "Sips" "$message"
}

# Function to add image files to the table
# Arguments: newline-separated list of file/directory paths to add
add_files_to_table() {
    local new_paths="$1"
    local buffer=""
    # Track individually added files skipped for unsupported type, so we can
    # warn once at the end instead of one alert per file.
    local unsupported_count=0
    local unsupported_names=""

    # Loop variables, declared so they stay in this function. The loops below
    # read from a file redirect rather than a pipeline, so they run in the current
    # shell and would otherwise assign at global scope.
    local file_path
    local found_file

    # Get readable extensions from sips
    local readable_exts=$(get_readable_extensions)
    # Remove trailing pipe for case statement
    readable_exts="${readable_exts%|}"
    
    # Get existing file paths from the table
    local existing_paths="$OMC_ACTIONUI_TABLE_10_COLUMN_2_ALL_ROWS"
    
    # Add existing files first
    if [ -n "$existing_paths" ]; then
        local tmp_existing="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.XXXXXX")"
        printf '%s\n' "$existing_paths" > "$tmp_existing"
        while IFS= read -r file_path; do
            if [ -n "$file_path" ]; then
                local filename="$("/usr/bin/basename" "$file_path")"
                buffer="${buffer}${filename}	${file_path}
"
            fi
        done < "$tmp_existing"
        /bin/rm -f "$tmp_existing"
    fi
    
    # Add new files/directories
    local tmp_new="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.XXXXXX")"
    printf '%s\n' "$new_paths" > "$tmp_new"
    while IFS= read -r file_path; do
        if [ -d "$file_path" ]; then
            # It's a directory - get all files and filter by extension
            local tmp_files="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.XXXXXX")"
            /usr/bin/find "$file_path" -type f ! -path "*/.*" -print > "$tmp_files" 2>/dev/null

            while IFS= read -r found_file; do
                local filename="$("/usr/bin/basename" "$found_file")"
                # Lowercase the extension so uppercase ones (e.g. .JPG) match
                local ext="$(printf '%s' "${filename##*.}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
                local ext_to_check="$ext"
                if [ "$ext" = "jpeg" ]; then
                    ext_to_check="jpg"
                elif [ "$ext" = "jpg" ]; then
                    ext_to_check="jpeg"
                fi
                case "|${readable_exts}|" in
                    *"|${ext}|"*|*"|${ext_to_check}|"*)
                        buffer="${buffer}${filename}	${found_file}
"
                    ;;
                esac
            done < "$tmp_files"
            /bin/rm -f "$tmp_files"
            
        elif [ -e "$file_path" ]; then
            # It's a file - check if it's an image using supported extensions
            local filename="$("/usr/bin/basename" "$file_path")"
            # Lowercase the extension so uppercase ones (e.g. .JPG) match
            local ext="$(printf '%s' "${filename##*.}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
            # Handle jpeg/jpg variation
            local ext_to_check="$ext"
            if [ "$ext" = "jpeg" ]; then
                ext_to_check="jpg"
            elif [ "$ext" = "jpg" ]; then
                ext_to_check="jpeg"
            fi
            case "|${readable_exts}|" in
                *"|${ext}|"*|*"|${ext_to_check}|"*)
                    buffer="${buffer}${filename}	${file_path}
"
                    ;;
                *)
                    unsupported_count=$(( unsupported_count + 1 ))
                    if [ -z "$unsupported_names" ]; then
                        unsupported_names="$filename"
                    else
                        unsupported_names="$unsupported_names
$filename"
                    fi
                    ;;
            esac
        fi
    done < "$tmp_new"
    /bin/rm -f "$tmp_new"

    # Sort, remove duplicates, and set table rows.
    # The sorted rows go through a temp file so the path that ends up in row 0
    # can be read back - callers use it to select and preview the first image
    # without waiting for a selection event that may not have landed yet.
    _first_row_path=""
    if [ -n "$buffer" ]; then
        local tmp_rows="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.XXXXXX")"
        printf "%s" "$buffer" | /usr/bin/sort -u > "$tmp_rows"
        _first_row_path="$(/usr/bin/head -1 "$tmp_rows" | /usr/bin/cut -f2)"
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_set_rows_from_stdin < "$tmp_rows"
        /bin/rm -f "$tmp_rows"
    else
        "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_table_remove_all_rows
    fi

    # Warn once about any individually added files of unsupported type
    if [ "$unsupported_count" -gt 0 ]; then
        notify_unsupported_files "$unsupported_count" "$unsupported_names"
    fi
}

# Function to build sips command arguments from current UI settings (without input/output paths)
# Arguments: optional image_path for percentage calculation
# Returns: sips arguments string (e.g., "-s format jpeg -z 100 100 -r 90")
build_sips_args() {
    local sips_args=""
    local image_path="$1"
    
    # Get resize mode (30: exact/width/height/longest)
    local resize_mode="$OMC_ACTIONUI_VIEW_30_VALUE"
    
    # Get width and height values from UI fields.
    # In pixel modes these are pixel values; in percent mode width is a percentage.
    local width="$OMC_ACTIONUI_VIEW_31_VALUE"
    local height="$OMC_ACTIONUI_VIEW_32_VALUE"

    # Only what the user typed is an instruction.
    #
    # A number the applet derived from the selected image describes that image
    # and nothing else. Carrying it into the conversion would force one file's
    # dimensions onto every other file in the list - and silently re-aim the
    # whole batch every time the user clicked a different row, since the fields
    # follow the selection. Dropping it leaves each file at its own size, which
    # is what "I typed nothing" asks for.
    #
    # The invariant this keeps: the fields always show what the SELECTED image
    # will come out as. With nothing typed it comes out unchanged, at the
    # dimensions shown; with a width typed it comes out that wide, at the height
    # shown. Every other file follows the same rule against its own dimensions.
    resolve_resize_sources

    # Each branch also drops its flag when the field it reads does not hold a
    # usable number, so an empty or half-typed field converts the image at its
    # original size instead of failing.
    local w
    local h
    case "$resize_mode" in
        exact)
            w="$(positive_int "$width")"
            h="$(positive_int "$height")"
            [ "$WIDTH_IS_TYPED"  = "yes" ] || w=""
            [ "$HEIGHT_IS_TYPED" = "yes" ] || h=""
            if [ -n "$w" ] && [ -n "$h" ]; then
                # Both axes given, so sips computes nothing and cannot collapse
                # anything: -z is exactly these pixels.
                sips_args="$sips_args -z $h $w"
            elif [ -n "$w" ]; then
                # One axis asked for, the other only describing the selection:
                # resample the axis that was asked for and keep each file's own
                # proportions, which is exactly the size the fields are showing.
                sips_args="$sips_args $(single_axis_flag width "$w" "$image_path")"
            elif [ -n "$h" ]; then
                sips_args="$sips_args $(single_axis_flag height "$h" "$image_path")"
            fi
            ;;
        width)
            w="$(positive_int "$width")"
            if [ -n "$w" ] && [ "$WIDTH_IS_TYPED" = "yes" ]; then
                sips_args="$sips_args $(single_axis_flag width "$w" "$image_path")"
            fi
            ;;
        height)
            h="$(positive_int "$height")"
            if [ -n "$h" ] && [ "$HEIGHT_IS_TYPED" = "yes" ]; then
                sips_args="$sips_args $(single_axis_flag height "$h" "$image_path")"
            fi
            ;;
        longest)
            w="$(positive_int "$width")"
            if [ -n "$w" ] && [ "$WIDTH_IS_TYPED" = "yes" ]; then
                sips_args="$sips_args $(single_axis_flag longest "$w" "$image_path")"
            fi
            ;;
        percent)
            # The width field contains a percentage value - compute absolute pixels per image
            if [ -n "$image_path" ] && [ -e "$image_path" ]; then
                local percent="$(clamped_percent "$width")"

                # 100 % is the resting default, and re-encoding an image at its
                # own dimensions only costs a resample pass - so emit nothing.
                if [ "$percent" -ne 100 ]; then
                    get_image_dimensions "$image_path"
                    if [ -n "$_orig_width" ] && [ -n "$_orig_height" ] && [ "$_orig_width" -gt 0 ]; then
                        local new_width=$(( _orig_width * percent / 100 ))
                        local new_height=$(( _orig_height * percent / 100 ))
                        # A small enough image scaled far enough down rounds to
                        # zero on one axis, which sips rejects.
                        [ "$new_width" -lt 1 ] && new_width=1
                        [ "$new_height" -lt 1 ] && new_height=1
                        sips_args="$sips_args -z $new_height $new_width"
                    fi
                fi
            fi
            ;;
    esac
    
    # Get rotation (40: -180 to 180, step 90)
    local rotation="$OMC_ACTIONUI_VIEW_40_VALUE"
    if [ -n "$rotation" ] && [ "$rotation" != "0" ]; then
        sips_args="$sips_args -r $rotation"
    fi
    
    # Get flip mode (42: none/horizontal/vertical)
    local flip_mode="$OMC_ACTIONUI_VIEW_42_VALUE"
    if [ -n "$flip_mode" ] && [ "$flip_mode" != "none" ]; then
        sips_args="$sips_args -f $flip_mode"
    fi
    
    # Get output format (13)
    local output_format="$OMC_ACTIONUI_VIEW_13_VALUE"
    if [ -n "$output_format" ]; then
        sips_args="$sips_args -s format $output_format"
        
        # Get compression/quality option - check picker (50) first, then text field (51)
        local compression="$OMC_ACTIONUI_VIEW_50_VALUE"
        local quality="$OMC_ACTIONUI_VIEW_51_VALUE"
        
        if [ -n "$quality" ] && [ "$quality" != "default" ]; then
            # Validate quality - default to 80 if not a number, clamp to 1-100
            case "$quality" in
                '' | *[!0-9]*)
                    quality=80 ;;
                *)
                    if [ "$quality" -gt 100 ]; then
                        quality=100
                    elif [ "$quality" -lt 1 ]; then
                        quality=1
                    fi ;;
            esac
            sips_args="$sips_args -s formatOptions $quality"
        elif [ -n "$compression" ] && [ "$compression" != "default" ]; then
            sips_args="$sips_args -s formatOptions $compression"
        fi
    fi
    
    echo "$sips_args"
}

# Function to update image preview
# Arguments: image_file_path
update_image_preview() {
    local image_path="$1"

    if [ -n "$image_path" ] && [ -e "$image_path" ]; then
        "$dialog_tool" "$window_uuid" ${IMAGE_PREVIEW_ID} "$image_path"
    else
        "$dialog_tool" "$window_uuid" ${IMAGE_PREVIEW_ID} ""
    fi
}

# Bring the selection-dependent controls in line with a file path, or with
# nothing selected when the path is empty.
# Arguments: image_file_path (may be empty)
apply_file_selection() {
    local image_path="$1"

    refresh_resize_fields_for_selection "$image_path"

    if [ -n "$image_path" ]; then
        "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_enable
        "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_enable
        "$dialog_tool" "$window_uuid" ${INFO_BUTTON_ID} omc_enable
    else
        "$dialog_tool" "$window_uuid" ${REMOVE_BUTTON_ID} omc_disable
        "$dialog_tool" "$window_uuid" ${REVEAL_BUTTON_ID} omc_disable
        "$dialog_tool" "$window_uuid" ${INFO_BUTTON_ID} omc_disable
    fi

    update_image_preview "$image_path"
}

# Keep the window pointing at an image once the list has one.
#
# A window with images in it and nothing selected has a blank preview and pixel
# fields describing nothing, which is the state the applet used to leave behind
# every time files were added: the list filled up and the right-hand side stayed
# empty until the user thought to click a row. An existing selection is left
# alone - only the empty case is filled in.
#
# Reads _first_row_path, which add_files_to_table sets to the path that ended up
# in row 0. Selecting a row programmatically fires no action, so the dependent
# controls are updated from that known path rather than from the engine's
# exported selection, which a chained command may read before it has caught up.
#
# Returns 0 when it took the selection over, 1 when it left things as they were.
adopt_first_row_if_unselected() {
    [ -n "$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE" ] && return 1
    [ -n "$_first_row_path" ] || return 1

    "$dialog_tool" "$window_uuid" ${TABLE_ID} omc_select_row 0
    apply_file_selection "$_first_row_path"
    return 0
}

# Function to get image info using sips
# Arguments: image_file_path
get_image_info() {
    local image_path="$1"
    
    if [ -e "$image_path" ]; then
        local info=""
        info="$info$(/usr/bin/sips -g pixelWidth -g pixelHeight -g typeIdentifier "$image_path" 2>&1)"
        
        # Get file size
        local file_size="$(/usr/bin/stat -f %z "$image_path" 2>/dev/null)"
        if [ -n "$file_size" ]; then
            info="$info

File Size: $file_size bytes"
        fi
        
        # Get creation and modification dates
        local created="$(/usr/bin/stat -f "%SB" "$image_path" 2>/dev/null)"
        local modified="$(/usr/bin/stat -f "%Sm" "$image_path" 2>/dev/null)"
        
        if [ -n "$created" ] || [ -n "$modified" ]; then
            info="$info

Created: ${created}
Modified: ${modified}"
        fi
        
        echo "$info"
    else
        echo "File does not exist"
    fi
}
