#!/usr/bin/env bash
set -eu

export DISPLAY="${DISPLAY:-:99}"

PACKAGE="app.capgo.capacitor.navigation"
ACTIVITY="${PACKAGE}/.MainActivity"
APK_PATH="${1:?apk path required}"
OUTPUT="${2:?output png path required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFY_SCRIPT="${REPO_ROOT}/.github/scripts/verify-tabbar-screenshot.py"
WORK_PNG="${OUTPUT%.png}.work.png"

python3 -m pip install --user pillow >/dev/null

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
  adb shell input tap "$((width / 2))" "$((height * 2 / 3))" >/dev/null 2>&1 || true
  adb shell input keyevent 3 >/dev/null 2>&1 || true
}

swipe_content_into_view() {
  local size width height
  size="$(screen_size)"
  if [ -z "${size}" ]; then
    adb shell input swipe 240 360 40 360 350
    return
  fi
  width="${size%x*}"
  height="${size#*x}"
  adb shell input swipe "$((width * 3 / 4))" "$((height * 2 / 3))" "$((width / 8))" "$((height * 2 / 3))" 400
}

capture_frame() {
  wake_display
  adb exec-out screencap -p > "${WORK_PNG}"
  test -s "${WORK_PNG}"
}

try_capture_pass() {
  local wait_seconds="$1"
  adb shell am force-stop "${PACKAGE}" >/dev/null 2>&1 || true
  adb logcat -c >/dev/null 2>&1 || true
  adb shell am start -n "${ACTIVITY}" >/dev/null 2>&1 || true
  sleep "${wait_seconds}"
  dismiss_blocking_dialogs
  swipe_content_into_view
  sleep 2
  capture_frame
  cp "${WORK_PNG}" "${OUTPUT}"
  python3 "${VERIFY_SCRIPT}" "${OUTPUT}"
}

adb wait-for-device
adb shell true
sleep 15
dismiss_blocking_dialogs
adb shell settings put global package_verifier_enable 0
adb shell settings put global verifier_verify_adb_installs 0

adb uninstall "${PACKAGE}" >/dev/null 2>&1 || true
install_attempt=0
while [ "${install_attempt}" -lt 6 ]; do
  if adb install -r "${APK_PATH}"; then
    break
  fi
  install_attempt=$((install_attempt + 1))
  sleep 15
done
if [ "${install_attempt}" -ge 6 ]; then
  echo "Failed to install screenshot APK after retries" >&2
  exit 1
fi

if try_capture_pass 75; then
  rm -f "${WORK_PNG}"
  exit 0
fi

echo "First capture pass failed; retrying after relaunch" >&2
if try_capture_pass 45; then
  rm -f "${WORK_PNG}"
  exit 0
fi

if [ -s "${WORK_PNG}" ]; then
  cp "${WORK_PNG}" "${REPO_ROOT}/android-floating-tabbar-capture-debug.png" || true
fi
adb logcat -d | tail -120 >&2 || true
adb shell dumpsys window windows 2>/dev/null | tail -60 >&2 || true
exit 1
