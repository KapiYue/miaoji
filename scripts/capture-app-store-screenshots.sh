#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${MIAOJI_DERIVED_DATA:-/tmp/miaoji-app-store-derived}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/MiaoJiAccout.app"
BUNDLE_ID="com.joy-coder.miaoji"
IPHONE_ID="${MIAOJI_IPHONE_SIMULATOR_ID:-EBE81B35-E9F3-46CD-9209-F8F02C924C0A}"
IPAD_ID="${MIAOJI_IPAD_SIMULATOR_ID:-D1547B6D-B368-425C-8F81-7BEE5B76809C}"
OUTPUT_ROOT="$ROOT_DIR/docs/assets/app-store-connect/zh-Hans"

xcodebuild build \
  -project "$ROOT_DIR/client/MiaoJiAccout.xcodeproj" \
  -scheme MiaoJiAccout \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_PATH" ]]; then
  echo "Simulator app not found at $APP_PATH." >&2
  exit 1
fi

capture_device() {
  local device_id="$1"
  local output_dir="$2"
  local expected_width="$3"
  local expected_height="$4"
  mkdir -p "$output_dir"

  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b
  xcrun simctl install "$device_id" "$APP_PATH"
  xcrun simctl status_bar "$device_id" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100

  local tabs=(home statistics history settings)
  local labels=(01-home 02-statistics 03-history 04-settings)
  for index in "${!tabs[@]}"; do
    local screenshot="$output_dir/${labels[$index]}.png"
    xcrun simctl terminate "$device_id" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$device_id" "$BUNDLE_ID" \
      --screenshot-demo-data \
      --screenshot-tab "${tabs[$index]}" \
      -AppleLanguages "(zh-Hans)" \
      -AppleLocale "zh_CN" >/dev/null
    sleep 2
    xcrun simctl io "$device_id" screenshot --type=png --mask=black "$screenshot"

    local dimensions
    dimensions="$(sips -g pixelWidth -g pixelHeight "$screenshot")"
    if [[ "$dimensions" != *"pixelWidth: $expected_width"* || "$dimensions" != *"pixelHeight: $expected_height"* ]]; then
      echo "Unexpected dimensions for $screenshot; expected ${expected_width}x${expected_height}." >&2
      echo "$dimensions" >&2
      exit 1
    fi
  done

  local voice_states=(ready recording analyzing drafts saved)
  local voice_labels=(01a-voice-ready 01b-voice-recording 01c-voice-analyzing 01d-voice-drafts 01e-voice-saved)
  for index in "${!voice_states[@]}"; do
    local screenshot="$output_dir/${voice_labels[$index]}.png"
    xcrun simctl terminate "$device_id" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$device_id" "$BUNDLE_ID" \
      --screenshot-demo-data \
      --screenshot-tab home \
      --screenshot-voice-state "${voice_states[$index]}" \
      -AppleLanguages "(zh-Hans)" \
      -AppleLocale "zh_CN" >/dev/null
    sleep 2
    xcrun simctl io "$device_id" screenshot --type=png --mask=black "$screenshot"

    local dimensions
    dimensions="$(sips -g pixelWidth -g pixelHeight "$screenshot")"
    if [[ "$dimensions" != *"pixelWidth: $expected_width"* || "$dimensions" != *"pixelHeight: $expected_height"* ]]; then
      echo "Unexpected dimensions for $screenshot; expected ${expected_width}x${expected_height}." >&2
      echo "$dimensions" >&2
      exit 1
    fi
  done
}

# App Store Connect 的 iPhone 6.5 英寸栏接受 1284x2778；13 英寸 iPad 为 2064x2752。
capture_device "$IPHONE_ID" "$OUTPUT_ROOT/iphone-6.5" 1284 2778
capture_device "$IPAD_ID" "$OUTPUT_ROOT/ipad-13" 2064 2752

echo "Captured and validated 18 App Store screenshots in $OUTPUT_ROOT"
