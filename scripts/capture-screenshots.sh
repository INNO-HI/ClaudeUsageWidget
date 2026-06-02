#!/bin/bash
# capture-screenshots.sh — best-effort automated capture for marketing assets.
#
# What it does:
#   1. (re)launches the app
#   2. Captures the menu bar strip
#   3. Sleeps so YOU can click the menu-bar icon, then captures the popover
#   4. Sleeps again so YOU can switch to Settings tab, then captures that
#
# Why not fully automatic? macOS Accessibility prevents non-permitted apps from
# clicking another app's menu-bar icon. Granting Accessibility to the shell is
# noisier than just clicking once during a release.
#
# Usage:
#   bash scripts/capture-screenshots.sh
#
# Output:
#   screenshots/v1.4.0/menubar.png
#   screenshots/v1.4.0/popover-main.png
#   screenshots/v1.4.0/popover-settings.png
#   screenshots/v1.4.0/popover-onboarding.png

set -e

VERSION="${1:-v1.4.0}"
OUT="screenshots/${VERSION}"
mkdir -p "$OUT"

APP_PATH="macos/build/Claude Usage Widget.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Build the app first:  cd macos && SKIP_SIGN=1 ./build.sh"
    exit 1
fi

# Restart for a clean state
pkill -x ClaudeUsageBar 2>/dev/null || true
sleep 1
open "$APP_PATH"
sleep 2

# 1. Menu bar strip (the % indicator at top-right)
echo "📸 Capturing menu bar strip → $OUT/menubar.png"
screencapture -x -R 1300,0,640,32 "$OUT/menubar.png"

# 2. Popover main view
echo ""
echo "👉 Click the Claude Usage Widget icon in the menu bar to open the popover."
echo "   You have 6 seconds…"
sleep 6
echo "📸 Capturing popover (whole screen — crop later if needed) → $OUT/popover-main.png"
screencapture -x "$OUT/popover-main.png"

# 3. Settings tab
echo ""
echo "👉 Click the gear icon (top-right of the popover) to open Settings."
echo "   You have 5 seconds…"
sleep 5
echo "📸 Capturing settings panel → $OUT/popover-settings.png"
screencapture -x "$OUT/popover-settings.png"

# 4. Onboarding (requires deleting config first)
echo ""
echo "👉 (Optional) For an onboarding screenshot, delete the config and relaunch:"
echo "      rm ~/.claude-usage-widget-config.json"
echo "      pkill -x ClaudeUsageBar; open \"$APP_PATH\""
echo "   then click the menu bar icon, and run:"
echo "      screencapture -x \"$OUT/popover-onboarding.png\""
echo ""
echo "✅ Done. Files saved under $OUT/"
echo "   Crop in Preview (⌘K) or use \`sips -c\` to tighten the popover region."
