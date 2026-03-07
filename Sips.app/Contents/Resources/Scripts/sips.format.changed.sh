#!/bin/bash
# sips.format.changed.sh - Handle format picker change

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

output_format="$OMC_ACTIONUI_VIEW_13_VALUE"

# Validate and correct quality value
validate_and_correct_quality() {
    local quality="$OMC_ACTIONUI_VIEW_51_VALUE"
    local corrected="$quality"
    
    if [ -z "$quality" ] || [ "$quality" = "default" ]; then
        corrected="80"
    elif [[ "$quality" =~ ^[0-9]+$ ]]; then
        if [ "$quality" -gt 100 ]; then
            corrected="100"
        elif [ "$quality" -lt 1 ]; then
            corrected="1"
        fi
    else
        corrected="80"
    fi
    
    if [ "$corrected" != "$quality" ]; then
        echo "[DEBUG] Correcting quality from $quality to $corrected"
        "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} "$corrected"
    fi
}

if [ -n "$output_format" ]; then
    echo "Output format changed to: $output_format"
    
    # Validate quality first
    validate_and_correct_quality
    
    # Set appropriate compression controls based on format
    case "$output_format" in
        jpeg|heic|heics|jp2|avif)
            # These formats support quality percentage - enable quality field, hide compression picker
            "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} omc_set_property "disabled" "false"
            "$dialog_tool" "$window_uuid" ${COMPRESSION_PICKER_ID} omc_set_property "hidden" "true"
            ;;
        tiff)
            # TIFF uses lzw compression - disable quality field, show compression picker
            "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} omc_set_property "disabled" "true"
            options_json='[{"title": "Default", "tag": "default"}, {"title": "LZW", "tag": "lzw"}, {"title": "PackBits", "tag": "pacbits"}]'
            "$dialog_tool" "$window_uuid" ${COMPRESSION_PICKER_ID} omc_set_property "options" "$options_json"
            "$dialog_tool" "$window_uuid" ${COMPRESSION_PICKER_ID} omc_set_property "hidden" "false"
            ;;
        *)
            # Disable quality field, hide compression picker for formats that don't support compression
            "$dialog_tool" "$window_uuid" ${QUALITY_FIELD_ID} omc_set_property "disabled" "true"
            "$dialog_tool" "$window_uuid" ${COMPRESSION_PICKER_ID} omc_set_property "hidden" "true"
            ;;
    esac
fi
