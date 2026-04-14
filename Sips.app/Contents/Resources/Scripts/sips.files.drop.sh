#!/bin/sh
# sips.files.drop.sh - Handle files dropped onto the image table

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

plister="$OMC_OMC_SUPPORT_PATH/plister"

# OMC_ACTIONUI_TRIGGER_CONTEXT is JSON: {"items": ["/path/a", "/path/b"], "location": {...}}
if [ -z "$OMC_ACTIONUI_TRIGGER_CONTEXT" ]; then
    exit 0
fi

tmp_json="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/sips.drop.XXXXXX.json")"
printf '%s' "$OMC_ACTIONUI_TRIGGER_CONTEXT" > "$tmp_json"

dropped_paths="$("$plister" iterate "$tmp_json" /items get value /)"
/bin/rm -f "$tmp_json"

if [ -z "$dropped_paths" ]; then
    exit 0
fi

add_files_to_table "$dropped_paths"

"$OMC_OMC_SUPPORT_PATH/omc_next_command" "${OMC_CURRENT_COMMAND_GUID}" "sips.files.selection.changed"
