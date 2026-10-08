#!/usr/bin/env bash
set -eu

PACKAGE="app.capgo.capacitor.navigation"
ACTIVITY="${PACKAGE}/.MainActivity"
APK_PATH="${1:?apk path required}"
OUTPUT="${2:?output png path required}"

wait_for_boot() {
  local attempt=0
  local max_attempts=120
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    if adb shell getprop sys.boot_completed 2>/dev/null | grep -q '^1$'; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "Timed out waiting for emulator boot" >&2
  return 1
}

wait_for_screenshot_ready() {
  if timeout 240 adb logcat -v brief | grep -m1 -q "NATIVE_NAV_SCREENSHOT_READY"; then
    return 0
  fi

  adb shell uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1 || true
  if adb shell cat /sdcard/uidump.xml 2>/dev/null | grep -qE "screenshot-ready|RESTAURANT|Pizza room"; then
    return 0
  fi

  echo "Timed out waiting for screenshot-ready WebView content" >&2
  adb logcat -d | tail -120 >&2 || true
  adb shell dumpsys window windows 2>/dev/null | tail -60 >&2 || true
  return 1
}

wait_for_boot

adb install -r "${APK_PATH}"
adb shell am force-stop "${PACKAGE}"
adb logcat -c
adb shell am start -W -n "${ACTIVITY}"

wait_for_screenshot_ready

# Bring the orange venue card into view behind the floating tabbar.
adb shell input swipe 900 1100 150 1100 450
sleep 2

adb exec-out screencap -p > "${OUTPUT}"
test -s "${OUTPUT}"
