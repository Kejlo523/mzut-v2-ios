#!/usr/bin/env bash
set -euo pipefail

SIMULATOR_UDID="${SIMULATOR_UDID:?SIMULATOR_UDID is required}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-pl.kejlo.mzut.ios}"
OUTPUT_DIR="${OUTPUT_DIR:-artifacts}"

SCREENSHOT_DIR="$OUTPUT_DIR/screenshots"
mkdir -p "$SCREENSHOT_DIR"

capture_screen() {
  local screen="$1"
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --args --ui-demo "--screen=$screen" >/dev/null
  sleep 3
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_DIR/$screen.png"
}

capture_screen "login"
capture_screen "home"
capture_screen "plan"
capture_screen "grades"
capture_screen "info"
capture_screen "news"
capture_screen "attendance"
capture_screen "links"
capture_screen "settings"

# Real network screenshot: week view + search by album number.
xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --args --screen=plan --plan-search-category=number --plan-search-query=57796 >/dev/null
sleep 6
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_DIR/plan_album_57796.png"

VIDEO_PATH="$OUTPUT_DIR/walkthrough.mp4"
xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl io "$SIMULATOR_UDID" recordVideo "$VIDEO_PATH" >/dev/null 2>&1 &
REC_PID=$!
sleep 1

for screen in home plan grades info news attendance links settings; do
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --args --ui-demo "--screen=$screen" >/dev/null
  sleep 2
done

kill -INT "$REC_PID" >/dev/null 2>&1 || true
wait "$REC_PID" 2>/dev/null || true

xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
