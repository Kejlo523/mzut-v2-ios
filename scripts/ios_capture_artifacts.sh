#!/usr/bin/env bash
set -euo pipefail

SIMULATOR_UDID="${SIMULATOR_UDID:?SIMULATOR_UDID is required}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-mzutv2}"
OUTPUT_DIR="${OUTPUT_DIR:-artifacts}"
MZUT_LOGIN="${MZUT_LOGIN:-}"
MZUT_PASSWORD="${MZUT_PASSWORD:-}"

SCREENSHOT_DIR="$OUTPUT_DIR/screenshots"
mkdir -p "$SCREENSHOT_DIR"

AUTH_ARGS=()
if [ -n "$MZUT_LOGIN" ] && [ -n "$MZUT_PASSWORD" ]; then
  AUTH_ARGS=("--auto-login-login=$MZUT_LOGIN" "--auto-login-password=$MZUT_PASSWORD")
fi

launch_app() {
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --args "$@" >/dev/null
}

capture_screen() {
  local screen="$1"
  shift || true
  launch_app "${AUTH_ARGS[@]}" "--screen=$screen" "$@"
  sleep 5
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_DIR/$screen.png"
}

ensure_logged_in() {
  if [ ${#AUTH_ARGS[@]} -eq 0 ]; then
    echo "MZUT_LOGIN/MZUT_PASSWORD are not configured. Only login screen will be captured."
    return
  fi

  launch_app "${AUTH_ARGS[@]}"
  sleep 12
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
}

capture_login() {
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" --args --screen=login >/dev/null
  sleep 3
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_DIR/login.png"
}

capture_plan_mode() {
  local mode="$1"
  local name="$2"
  capture_screen "plan" "--plan-view=$mode"
  mv "$SCREENSHOT_DIR/plan.png" "$SCREENSHOT_DIR/$name.png"
}

capture_login
ensure_logged_in

if [ ${#AUTH_ARGS[@]} -gt 0 ]; then
  capture_screen "home"
  capture_plan_mode "week" "plan_week"
  cp "$SCREENSHOT_DIR/plan_week.png" "$SCREENSHOT_DIR/plan.png"
  capture_plan_mode "day" "plan_day"
  capture_plan_mode "month" "plan_month"
  capture_screen "grades"
  capture_screen "info"
  capture_screen "news"
  capture_screen "attendance"
  capture_screen "links"
  capture_screen "settings"

  launch_app "${AUTH_ARGS[@]}" --screen=plan --plan-view=week --plan-search-category=number --plan-search-query=57796
  sleep 8
  xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_DIR/plan_album_57796.png"
  cp "$SCREENSHOT_DIR/plan_album_57796.png" "$SCREENSHOT_DIR/plan_week_album_57796.png"

  VIDEO_PATH="$OUTPUT_DIR/walkthrough.mp4"
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl io "$SIMULATOR_UDID" recordVideo "$VIDEO_PATH" >/dev/null 2>&1 &
  REC_PID=$!
  sleep 1

  for screen in home plan grades info news attendance links settings; do
    launch_app "${AUTH_ARGS[@]}" "--screen=$screen"
    sleep 3
  done

  kill -INT "$REC_PID" >/dev/null 2>&1 || true
  wait "$REC_PID" 2>/dev/null || true
fi

xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
