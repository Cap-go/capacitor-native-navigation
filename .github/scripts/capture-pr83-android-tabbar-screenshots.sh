#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAIN_WT="${REPO_ROOT}/.worktrees/main-pr83-screenshot"
OUT_DIR="${REPO_ROOT}/docs/screenshots/pr-83"
BEFORE_APK="${REPO_ROOT}/.tmp/pr83-before.apk"
AFTER_APK="${REPO_ROOT}/.tmp/pr83-after.apk"
BEFORE_TEST_APK="${REPO_ROOT}/.tmp/pr83-before-test.apk"
AFTER_TEST_APK="${REPO_ROOT}/.tmp/pr83-after-test.apk"
OPTIMIZE_SCRIPT="${REPO_ROOT}/.github/scripts/optimize-pr83-tabbar-screenshot.py"

mkdir -p "${OUT_DIR}" "${REPO_ROOT}/.tmp"

build_screenshot_apk() {
  local root="$1"
  local layout_rtl="${2:-}"
  local out_apk="$3"
  echo "Building screenshot APK in ${root} (layoutDirection=${layout_rtl:-omitted})"
  (
    cd "${root}"
    bun install
    bun run build
    cd example-app
    bun install
    export VITE_SCREENSHOT_MODE=floating-tabbar
    if [ -n "${layout_rtl}" ]; then
      export VITE_SCREENSHOT_LAYOUT_DIRECTION=rtl
    else
      unset VITE_SCREENSHOT_LAYOUT_DIRECTION || true
    fi
    bun run build
    VITE_SCREENSHOT_MODE=floating-tabbar bun x cap sync android
    cd android
    chmod +x gradlew
    VITE_SCREENSHOT_MODE=floating-tabbar ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest --no-daemon -q
    cp app/build/outputs/apk/debug/app-debug.apk "${out_apk}"
  )
}

run_instrumented_screenshot() {
  local apk="$1"
  local android_test_apk="$2"
  local output_png="$3"
  configure_rtl_emulator
  adb uninstall app.capgo.capacitor.navigation >/dev/null 2>&1 || true
  adb install -r -g "${apk}"
  adb install -r "${android_test_apk}"
  adb shell am instrument -w -r \
    -e class 'app.capgo.capacitor.navigation.FloatingTabbarScreenshotTest' \
    app.capgo.capacitor.navigation.test/androidx.test.runner.AndroidJUnitRunner
  adb exec-out run-as app.capgo.capacitor.navigation cat files/Pictures/floating-tabbar-screenshot.png > "${output_png}.full"
  python3 "${OPTIMIZE_SCRIPT}" "${output_png}.full" "${output_png}"
  rm -f "${output_png}.full"
}

prepare_main_worktree() {
  if [ -f "${MAIN_WT}/.git" ] || [ -d "${MAIN_WT}/.git" ]; then
    return 0
  fi
  git -C "${REPO_ROOT}" fetch origin main
  git -C "${REPO_ROOT}" worktree add "${MAIN_WT}" origin/main
}

configure_rtl_emulator() {
  adb shell settings put global debug.force_rtl 1
  adb shell settings put global debug.force_rtl_all_locales 1
}

prepare_main_worktree
ANDROID_TEST_SRC="${REPO_ROOT}/example-app/android/app/src/androidTest/java/app/capgo/capacitor/navigation/FloatingTabbarScreenshotTest.java"
ANDROID_TEST_DST="${MAIN_WT}/example-app/android/app/src/androidTest/java/app/capgo/capacitor/navigation/FloatingTabbarScreenshotTest.java"
mkdir -p "$(dirname "${ANDROID_TEST_DST}")"
cp "${ANDROID_TEST_SRC}" "${ANDROID_TEST_DST}"
build_screenshot_apk "${MAIN_WT}" "" "${BEFORE_APK}"
cp "${MAIN_WT}/example-app/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk" "${BEFORE_TEST_APK}"
build_screenshot_apk "${REPO_ROOT}" "rtl" "${AFTER_APK}"
cp "${REPO_ROOT}/example-app/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk" "${AFTER_TEST_APK}"

run_instrumented_screenshot "${BEFORE_APK}" "${BEFORE_TEST_APK}" "${OUT_DIR}/android-before.png"
run_instrumented_screenshot "${AFTER_APK}" "${AFTER_TEST_APK}" "${OUT_DIR}/android-after.png"

ls -lh "${OUT_DIR}/android-before.png" "${OUT_DIR}/android-after.png"
