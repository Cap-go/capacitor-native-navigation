#!/usr/bin/env bash
set -eu

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

screenshot_is_valid() {
  local path="$1"
  [ -s "${path}" ] && python3 "${VERIFY_SCRIPT}" --relaxed "${path}" >/dev/null 2>&1
}

wait_for_valid_screenshot() {
  local attempt=0
  local max_attempts=60
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    adb exec-out screencap -p > "${WORK_PNG}" || true
    if screenshot_is_valid "${WORK_PNG}"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
  echo "Timed out waiting for floating tabbar screenshot content" >&2
  if [ -s "${WORK_PNG}" ]; then
    cp "${WORK_PNG}" "${REPO_ROOT}/android-floating-tabbar-capture-debug.png" || true
  fi
  adb logcat -d | tail -120 >&2 || true
  adb shell dumpsys window windows 2>/dev/null | tail -60 >&2 || true
  return 1
}

adb wait-for-device
adb shell true
adb shell settings put global package_verifier_enable 0
adb shell settings put global verifier_verify_adb_installs 0

install_apk() {
  local attempt=0
  while [ "${attempt}" -lt 6 ]; do
    if adb install -r "${APK_PATH}"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 20
  done
  echo "Failed to install screenshot APK after retries" >&2
  return 1
}

install_apk
adb shell am force-stop "${PACKAGE}"
adb logcat -c
adb shell am start -W -n "${ACTIVITY}"

wait_for_valid_screenshot

swipe_content_into_view
sleep 2

adb exec-out screencap -p > "${OUTPUT}"
test -s "${OUTPUT}"
python3 "${VERIFY_SCRIPT}" "${OUTPUT}"
rm -f "${WORK_PNG}"
