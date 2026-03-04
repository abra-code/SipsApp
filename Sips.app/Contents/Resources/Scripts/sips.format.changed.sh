#!/bin/bash
# sips.format.changed.sh - Handle format picker change

# This script runs when the output format picker changes
# We could update UI or store the selection
# Currently just logs the selection

output_format="$OMC_ACTIONUI_VIEW_13_VALUE"

if [ -n "$output_format" ]; then
    echo "Output format changed to: $output_format"
fi
