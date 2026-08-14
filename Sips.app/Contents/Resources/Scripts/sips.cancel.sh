#!/bin/bash
# sips.cancel.sh - Cleanup on window close

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.sips.sh"

# Both are keyed by window UUID, so closing one window leaves any other window's
# state alone.
/bin/rm -f "$RESIZE_STATE_FILE"
/bin/rm -rf "${TMPDIR:-/tmp}/sips_preview_${window_uuid}"
