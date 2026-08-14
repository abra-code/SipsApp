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

# ---------------------------------------------------------------------------
# Helper: populate width/height fields with the selected image's original
# pixel dimensions (or a derived value for single-axis modes).
# Arguments: mode  (exact|width|height|longest)
# ---------------------------------------------------------------------------
# Returns 0 when it filled the fields in, 1 when there was no image to measure.
restore_pixel_values() {
    local mode="$1"
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    [ -z "$selected_path" ] || [ ! -e "$selected_path" ] && return 1

    get_image_dimensions "$selected_path"
    [ -z "$_orig_width" ] || [ -z "$_orig_height" ] && return 1

    case "$mode" in
        exact)
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID}  "$_orig_width"
            "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$_orig_height"
            export OMC_ACTIONUI_VIEW_31_VALUE="$_orig_width"
            export OMC_ACTIONUI_VIEW_32_VALUE="$_orig_height"
            ;;
        width)
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$_orig_width"
            export OMC_ACTIONUI_VIEW_31_VALUE="$_orig_width"
            ;;
        height)
            "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$_orig_height"
            export OMC_ACTIONUI_VIEW_32_VALUE="$_orig_height"
            ;;
        longest)
            local longest=$(( _orig_width > _orig_height ? _orig_width : _orig_height ))
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$longest"
            export OMC_ACTIONUI_VIEW_31_VALUE="$longest"
            ;;
    esac
    return 0
}

clear_width_field() {
    "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} ""
    export OMC_ACTIONUI_VIEW_31_VALUE=""
}

clear_height_field() {
    "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} ""
    export OMC_ACTIONUI_VIEW_32_VALUE=""
}

# ---------------------------------------------------------------------------
# Helper: seed the pixel fields a mode reads, and blank them when there is no
# image to measure.
#
# Blanking is the whole point. A mode switch that wants a reseed and cannot get
# one used to leave the fields untouched, which is how a percentage escapes into
# a mode where the number means pixels: set 250 %, deselect everything, switch to
# Exact Pixels, then add another image and press Convert - every file gets forced
# to 250 px wide. A blank field fails positive_int, so build_sips_args drops the
# flag and the conversion keeps the original size, which is the safe direction.
# Arguments: mode  (exact|width|height|longest)
# ---------------------------------------------------------------------------
seed_pixel_fields() {
    local mode="$1"

    restore_pixel_values "$mode" && return

    case "$mode" in
        exact)
            clear_width_field
            clear_height_field
            ;;
        width|longest)
            clear_width_field
            ;;
        height)
            clear_height_field
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: calculate height from width preserving aspect ratio (for "width" mode)
# ---------------------------------------------------------------------------
calculate_height_from_width() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    local current_width="$OMC_ACTIONUI_VIEW_31_VALUE"
    [ -z "$selected_path" ] || [ ! -e "$selected_path" ] || [ -z "$current_width" ] && return

    get_image_dimensions "$selected_path"
    if [ -n "$_orig_width" ] && [ -n "$_orig_height" ] && [ "$_orig_width" -gt 0 ]; then
        local new_height=$(( _orig_height * current_width / _orig_width ))
        "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} "$new_height"
    fi
}

# ---------------------------------------------------------------------------
# Helper: calculate width from height preserving aspect ratio (for "height" mode)
# ---------------------------------------------------------------------------
calculate_width_from_height() {
    local selected_path="$OMC_ACTIONUI_TABLE_10_COLUMN_2_VALUE"
    local current_height="$OMC_ACTIONUI_VIEW_32_VALUE"
    [ -z "$selected_path" ] || [ ! -e "$selected_path" ] || [ -z "$current_height" ] && return

    get_image_dimensions "$selected_path"
    if [ -n "$_orig_width" ] && [ -n "$_orig_height" ] && [ "$_orig_height" -gt 0 ]; then
        local new_width=$(( _orig_width * current_height / _orig_height ))
        "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$new_width"
    fi
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
# Handle resize-mode changes: show/hide fields, convert values between
# percentage and pixel representations so the text fields always hold the
# correct unit for the active mode.
# ---------------------------------------------------------------------------
handle_resize_mode_change() {
    local new_mode="$OMC_ACTIONUI_VIEW_30_VALUE"

    # Read the previous mode from our state file (empty on first run)
    local prev_mode=""
    [ -f "$RESIZE_MODE_STATE_FILE" ] && prev_mode=$(cat "$RESIZE_MODE_STATE_FILE")

    # Persist the new mode for the next invocation
    echo "$new_mode" > "$RESIZE_MODE_STATE_FILE"

    # If the mode didn't actually change, just do incremental calculations
    # (user is typing in a text field, not switching the picker).
    if [ "$new_mode" = "$prev_mode" ]; then
        case "$new_mode" in
            width)   calculate_height_from_width ;;
            height)  calculate_width_from_height ;;
        esac
        return
    fi

    # --- Mode is changing - configure field visibility and convert values ---

    local was_percent="false"
    [ "$prev_mode" = "percent" ] && was_percent="true"

    case "$new_mode" in
        exact)
            set_field_visibility "false" "false" "false" "true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "width"
            # Exact pixels is the one mode that needs both fields to hold real
            # pixel counts, and it can be reached in two states that do not.
            # Coming from percent, the width field holds a 1-500 scale factor,
            # which is meaningless as a width. Coming from a mode the user never
            # gave an image to, the fields were never filled in at all. Either
            # way, seed both from the selected image.
            #
            # A width the user actually typed in Width mode (with its height
            # already derived alongside it) is a deliberate choice, so leave that
            # pair alone rather than overwriting it with the original size.
            if [ "$was_percent" = "true" ] \
                || [ -z "$(positive_int "$OMC_ACTIONUI_VIEW_31_VALUE")" ] \
                || [ -z "$(positive_int "$OMC_ACTIONUI_VIEW_32_VALUE")" ]; then
                seed_pixel_fields "exact"
            fi
            ;;
        width)
            set_field_visibility "false" "true" "true" "true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "width"
            if [ "$was_percent" = "true" ]; then
                seed_pixel_fields "width"
            fi
            calculate_height_from_width
            ;;
        height)
            set_field_visibility "true" "false" "true" "true"
            "$dialog_tool" "$window_uuid" ${HEIGHT_FIELD_ID} omc_set_property "prompt" "height"
            if [ "$was_percent" = "true" ]; then
                seed_pixel_fields "height"
            fi
            calculate_width_from_height
            ;;
        longest)
            set_field_visibility "false" "true" "true" "true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "longest edge"
            if [ "$was_percent" = "true" ]; then
                seed_pixel_fields "longest"
            fi
            ;;
        percent)
            set_field_visibility "false" "true" "true" "false"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "percent"
            # Always reset to 100 % when entering percent mode
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} "$DEFAULT_RESIZE_PERCENT"
            export OMC_ACTIONUI_VIEW_31_VALUE="$DEFAULT_RESIZE_PERCENT"
            ;;
        *)
            set_field_visibility "false" "false" "false" "true"
            "$dialog_tool" "$window_uuid" ${WIDTH_FIELD_ID} omc_set_property "prompt" "width"
            ;;
    esac
}

# ===== Main =====

validate_quality

# Handle resize mode - show/hide fields, convert pixel<->percent values.
# This runs before the "is anything selected" check on purpose: the window now
# opens empty, so the user reaches the resize picker before any image is in the
# list, and the fields still have to follow the mode they pick.
handle_resize_mode_change

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
