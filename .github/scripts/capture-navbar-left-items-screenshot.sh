#!/usr/bin/env bash
set -eu

PACKAGE="app.capgo.capacitor.navigation"
ACTIVITY="${PACKAGE}/.MainActivity"
APK_PATH="${1:?apk path required}"
OUTPUT="${2:?output png path required}"
WORK_PNG="${OUTPUT%.png}.work.png"

screen_size() {
  adb shell wm size 2>/dev/null | tr -d '\r' | awk '/Physical size/ {print $3; exit}'
}

wake_display() {
  adb shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  adb shell svc power stayon true >/dev/null 2>&1 || true
}

dismiss_blocking_dialogs() {
  local size width height
  size="$(screen_size)"
  if [ -z "${size}" ]; then
    adb shell input keyevent 66 >/dev/null 2>&1 || true
    return
  fi
  width="${size%x*}"
  height="${size#*x}"
  if adb shell dumpsys window 2>/dev/null | tr -d '\r' | grep -qi "isn't responding"; then
    adb shell input tap "$((width / 2))" "$((height * 2 / 3))" >/dev/null 2>&1 || true
    adb shell input keyevent 66 >/dev/null 2>&1 || true
  fi
}

wait_for_boot_completed() {
  adb wait-for-device
  local attempt=0
  while [ "${attempt}" -lt 120 ]; do
    boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)"
    if [ "${boot}" = "1" ]; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "Timed out waiting for sys.boot_completed" >&2
  return 1
}

launch_app() {
  adb shell am force-stop "${PACKAGE}" >/dev/null 2>&1 || true
  adb shell am start -W -n "${ACTIVITY}" >/dev/null 2>&1 || adb shell am start -n "${ACTIVITY}"
}

clear_logcat() {
  local attempt=0
  local max_attempts=5
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    if adb logcat -c >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  echo "Failed to clear logcat after ${max_attempts} attempts" >&2
  return 1
}

screenshot_ready_in_logcat() {
  adb logcat -d 2>/dev/null | tr -d '\r' | grep -q 'NATIVE_NAV_SCREENSHOT_READY'
}

screenshot_ready_in_ui() {
  local dump='/data/local/tmp/navbar-screenshot-ui.xml'
  adb shell rm -f "${dump}" >/dev/null 2>&1 || true
  adb shell uiautomator dump "${dump}" >/dev/null 2>&1 || return 1
  adb shell test -s "${dump}" >/dev/null 2>&1 || return 1
  adb shell cat "${dump}" 2>/dev/null | tr -d '\r' | grep -q 'screenshot-ready'
}

wait_for_screenshot_ready_log() {
  local attempt=0
  local max_attempts=90
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    if screenshot_ready_in_logcat || screenshot_ready_in_ui; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "Screenshot readiness signal not observed (log or UI)" >&2
  return 1
}

if [ "${NAVBAR_SCREENSHOT_SKIP_BOOT:-0}" != "1" ]; then
  wait_for_boot_completed
fi
adb shell wm size 1080x1920 >/dev/null 2>&1 || true
adb shell wm density 420 >/dev/null 2>&1 || true
dismiss_blocking_dialogs
adb uninstall "${PACKAGE}" >/dev/null 2>&1 || true
adb install -r "${APK_PATH}"
clear_logcat
launch_app
sleep 12
wait_for_screenshot_ready_log
sleep 2
dismiss_blocking_dialogs
wake_display
adb exec-out screencap -p > "${WORK_PNG}"
test -s "${WORK_PNG}"
cp "${WORK_PNG}" "${OUTPUT}"
rm -f "${WORK_PNG}"
