#!/usr/bin/env bash
set -eu

PACKAGE="app.capgo.capacitor.navigation"
APK_PATH="${1:?apk path required}"
OUTPUT="${2:?output png path required}"
AVD_NAME="${AVD_NAME:-navbar_left_items_api34}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_HOME
export PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"

SCREENSHOT_REMOTE="/data/user/0/${PACKAGE}/files/Pictures/navbar-left-items-screenshot.png"
DONE_REMOTE="/data/user/0/${PACKAGE}/files/Pictures/navbar-left-items-screenshot.done"
TEST_CLASS="app.capgo.capacitor.navigation.NavbarLeftItemsScreenshotTest"

start_emulator() {
  if adb devices | grep -q 'emulator-'; then
    return 0
  fi
  if ! avdmanager list avd | grep -q "Name: ${AVD_NAME}"; then
    echo no | avdmanager create avd -n "${AVD_NAME}" -k "system-images;android-34;google_apis;x86_64" --device pixel_6
  fi
  nohup emulator -avd "${AVD_NAME}" -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect >/tmp/navbar-left-items-emulator.log 2>&1 &
  adb wait-for-device
  booted=""
  for _ in $(seq 1 120); do
    booted="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [ "${booted}" = "1" ]; then
      break
    fi
    sleep 2
  done
  if [ "${booted}" != "1" ]; then
    echo "Emulator failed to boot" >&2
    exit 1
  fi
}

start_emulator
adb uninstall "${PACKAGE}" >/dev/null 2>&1 || true
adb install -r "${APK_PATH}"
adb shell am instrument -w -r -e class "${TEST_CLASS}" "${PACKAGE}.test/androidx.test.runner.AndroidJUnitRunner"
for _ in $(seq 1 30); do
  if adb shell test -f "${DONE_REMOTE}" 2>/dev/null; then
    break
  fi
  sleep 2
done
adb pull "${SCREENSHOT_REMOTE}" "${OUTPUT}"
