#!/usr/bin/env bash
set -eu

PACKAGE="app.capgo.capacitor.navigation"
ACTIVITY="${PACKAGE}/.MainActivity"
APK_PATH="${1:?apk path required}"
OUTPUT="${2:?output png path required}"

adb install -r "${APK_PATH}"
adb shell am force-stop "${PACKAGE}"
adb shell am start -W -n "${ACTIVITY}"

wait_for_screenshot_ready() {
  local attempt=0
  local max_attempts=90
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    adb shell uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1 || true
    if adb shell cat /sdcard/uidump.xml 2>/dev/null | grep -q "screenshot-ready"; then
      return 0
    fi
    if adb shell cat /sdcard/uidump.xml 2>/dev/null | grep -qE "RESTAURANT|Pizza room"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "Timed out waiting for screenshot-ready WebView content" >&2
  adb shell dumpsys window windows | tail -40 >&2 || true
  return 1
}

wait_for_screenshot_ready

# Bring the orange venue card into view behind the floating tabbar.
adb shell input swipe 900 1100 150 1100 450
sleep 2

adb exec-out screencap -p > "${OUTPUT}"
test -s "${OUTPUT}"
