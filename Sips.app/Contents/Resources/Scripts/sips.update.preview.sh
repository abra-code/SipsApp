#!/bin/bash
# sips.update.preview.sh - Update preview with current settings applied

# Source shared library
source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# ---------------------------------------------------------------------------
# Helper: set visibility of the width / height / "x" / "%" fields.
# The trailing "%" is what tells the user the number in the width field is a
# scale factor and not a pixel count, so it tracks percent mode exactly.
# ---------------------------------------------------------------------------
set_field_visibility() {
    local width_hidden="$1" height_hidden="$2" x_hidden="$3" percent_hidden="$4"
    "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID}   omc_set_property "hidden" "$width_hidden"
    "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID}  omc_set_property "hidden" "$height_hidden"
    "$dialog_tool" "$window_uuid" ${X_TEXT_ID}        omc_set_property "hidden" "$x_hidden"
    "$dialog_tool" "$window_uuid" ${PERCENT_SIGN_ID}  omc_set_property "hidden" "$percent_hidden"
}

# The placeholder is the only thing naming what an empty field would mean, and
# an empty field is now a state the user sees often - it is how the applet says
# "this one follows whatever you select".
set_width_prompt() {
    "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "$1"
}

set_height_prompt() {
    "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_set_property "prompt" "$1"
}

# ---------------------------------------------------------------------------
# Validate and correct quality value in UI
# ---------------------------------------------------------------------------
validate_quality() {
    local quality="$OMC_ACTIONUI_VIEW_51_VALUE"
    local corrected="$quality"

    if [ -z "$quality" ] || [ "$quality" = "default" ]; then
        corrected="80"
    elif [[ "$quality" =~ ^[0-9]+$ ]]; then
        [ "$quality" -gt 100 ] && corrected="100"
        [ "$quality" -lt 1 ]   && corrected="1"
    else
        corrected="80"
    fi

    if [ "$corrected" != "$quality" ]; then
        "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} "$corrected"
    fi
}

# ---------------------------------------------------------------------------
# Keep the percent field inside the range the builder will act on.
#
# The builder already falls back to 100 and clamps at MAX_RESIZE_PERCENT, so
# nothing here changes what a conversion does. What it changes is the field
# agreeing with it: 9999 left standing next to a conversion that scaled by 500 %
# is the applet reporting something it did not do.
# ---------------------------------------------------------------------------
validate_percent() {
    set_width_field "$(clamped_percent "$OMC_ACTIONUI_VIEW_31_VALUE")"
}

# ---------------------------------------------------------------------------
# Say what a pixel mode the user has typed nothing into will actually do.
#
# The fields fill themselves in from the selected image, which makes them look
# like an instruction that has already been given - and the conversion, which
# acts only on what the user typed, would then read as doing nothing. Said at
# the moment the mode is chosen, because that is when the expectation forms.
# ---------------------------------------------------------------------------
announce_descriptive_fields() {
    [ "$WIDTH_SOURCE"  = "$SOURCE_TYPED" ] && return 1
    [ "$HEIGHT_SOURCE" = "$SOURCE_TYPED" ] && return 1
    set_status "These fields show the selected image's size. Type a size into one to apply it to all of them; leave them alone and each image keeps its own size."
    return 0
}

# ---------------------------------------------------------------------------
# The resize mode changed: lay the fields out for the new mode and decide what
# survives the switch.
# ---------------------------------------------------------------------------
apply_resize_mode() {
    local new_mode="$1"
    local prev_mode="$2"

    # A field the new mode does not own stops being the user's. In Width mode the
    # height is a consequence of the width rather than a choice; in Height mode
    # it is the other way round; percent owns neither. A lock left on a field the
    # user cannot see is one they have no way to release.
    case "$new_mode" in
        exact)         ;;
        width|longest) HEIGHT_SOURCE="$SOURCE_AUTO" ;;
        height)        WIDTH_SOURCE="$SOURCE_AUTO" ;;
        *)             WIDTH_SOURCE="$SOURCE_AUTO"
                       HEIGHT_SOURCE="$SOURCE_AUTO" ;;
    esac

    # Coming out of percent, the width field holds a 1-500 scale factor, and read
    # as a pixel count it is a lie that survives into the next conversion: set
    # 250 %, switch to Exact Pixels, press Convert, and every file comes out
    # 250 px wide. The number goes, whoever put it there.
    #
    # An unrecognized previous mode is treated the same way, because the only way
    # to get one is to have lost the state file - and the number standing in the
    # field is then of unknown unit, which is the same problem with less
    # information. TMPDIR is purged periodically, so a long-lived window reaches
    # this on its own.
    case "$prev_mode" in
        exact|width|height|longest) ;;
        *)
            WIDTH_SOURCE="$SOURCE_AUTO"
            HEIGHT_SOURCE="$SOURCE_AUTO"
            set_width_field ""
            set_height_field ""
            ;;
    esac

    case "$new_mode" in
        exact)
            set_field_visibility "false" "false" "false" "true"
            set_width_prompt "width"
            ;;
        width)
            set_field_visibility "false" "true" "true" "true"
            set_width_prompt "width"
            ;;
        height)
            set_field_visibility "true" "false" "true" "true"
            set_height_prompt "height"
            ;;
        longest)
            set_field_visibility "false" "true" "true" "true"
            set_width_prompt "longest edge"
            ;;
        percent)
            set_field_visibility "false" "true" "true" "false"
            set_width_prompt "percent"
            # Always back to 100 %. Whatever stood there a moment ago was a pixel
            # count, and 1200 px reading as 1200 % is the same lie in the other
            # direction.
            put_width_field "$DEFAULT_RESIZE_PERCENT"
            ;;
        *)
            set_field_visibility "false" "false" "false" "true"
            set_width_prompt "width"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# The whole resize section, on every dispatch that touches it.
#
# One handler serves the mode picker and both text fields, and the thing it has
# to work out first is whether the picker moved - which only the state file
# knows, since the engine hands over the current mode and not the previous one.
# Everything else follows from the values in the fields.
# ---------------------------------------------------------------------------
handle_resize_controls() {
    local mode="$OMC_ACTIONUI_VIEW_30_VALUE"

    load_resize_state
    local prev_mode="$RESIZE_MODE"
    RESIZE_MODE="$mode"

    local mode_changed="no"
    if [ "$mode" != "$prev_mode" ]; then
        mode_changed="yes"
        apply_resize_mode "$mode" "$prev_mode"
    fi

    if [ "$mode" = "percent" ]; then
        validate_percent
    else
        refresh_resize_fields "$mode" "$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
        # A field changing hands is the news; failing that, a mode the user has
        # just arrived in is worth explaining once. Neither overwrites the other,
        # and nothing is said on the dispatches in between.
        if ! announce_pin_changes && [ "$mode_changed" = "yes" ]; then
            announce_descriptive_fields
        fi
    fi

    save_resize_state
}

# ===== Main =====

validate_quality

# Lay out and fill the resize fields. This runs before the "is anything
# selected" check on purpose: the window opens empty, so the user reaches the
# resize picker before any image is in the list, and the fields still have to
# follow the mode they pick.
handle_resize_controls

# Get selected file path from table (column 2)
selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"

if [ -z "$selected_path" ] || [ ! -e "$selected_path" ]; then
    exit 0
fi

# Output format (default to png for preview)
output_format="$OMC_ACTIONUI_VIEW_13_VALUE"
: "${output_format:=png}"

# Create temp preview. Keyed by window so two windows previewing files of the
# same name do not overwrite each other's image mid-render.
temp_preview_dir="${TMPDIR:-/tmp}/sips_preview_${window_uuid}"
/bin/mkdir -p "$temp_preview_dir"

filename="$("/usr/bin/basename" "$selected_path")"
name_without_ext="${filename%.*}"
output_file="$temp_preview_dir/${name_without_ext}_preview.${output_format}"
/bin/rm -f "$output_file"

# Build and execute sips command (pass image path for percentage calculation)
sips_args=$(build_sips_args "$selected_path")

output=$(/usr/bin/sips $sips_args --out "$output_file" "$selected_path" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    exit 0
fi

if [ -e "$output_file" ]; then
    update_image_preview "$output_file"
fi
