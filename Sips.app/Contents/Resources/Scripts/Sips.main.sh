#!/bin/bash
# Sips.main.sh - Entry point for the Sips applet
#
# The window is opened by NEXT_COMMAND_ID = sips.new; the object context (images
# dropped on the app icon) propagates to the chained command, and sips.init seeds
# the image list from OMC_OBJ_PATH.
#
# A non-blocking window's main command runs at an unpredictable time relative to
# the window appearing, so this stays empty on purpose - all initialization
# belongs in sips.init.
exit 0
