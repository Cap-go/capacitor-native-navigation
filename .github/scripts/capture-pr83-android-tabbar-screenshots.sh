#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAIN_WT="${REPO_ROOT}/.worktrees/main-pr83-screenshot"
OUT_DIR="${REPO_ROOT}/docs/screenshots/pr-83"
BEFORE_APK="${REPO_ROOT}/.tmp/pr83-before.apk"
AFTER_APK="${REPO_ROOT}/.tmp/pr83-after.apk"
BEFORE_FULL="${REPO_ROOT}/.tmp/pr83-before-full.png"
AFTER_FULL="${REPO_ROOT}/.tmp/pr83-after-full.png"
CAPTURE_SCRIPT="${REPO_ROOT}/.github/scripts/capture-floating-tabbar-screenshot.sh"
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
    VITE_SCREENSHOT_MODE=floating-tabbar ./gradlew :app:assembleDebug --no-daemon -q
    cp app/build/outputs/apk/debug/app-debug.apk "${out_apk}"
  )
}

capture_apk_to_pr83_png() {
  local apk="$1"
  local full_png="$2"
  local output_png="$3"
  configure_rtl_emulator
  bash "${CAPTURE_SCRIPT}" "${apk}" "${full_png}"
  python3 "${OPTIMIZE_SCRIPT}" "${full_png}" "${output_png}"
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
build_screenshot_apk "${MAIN_WT}" "" "${BEFORE_APK}"
build_screenshot_apk "${REPO_ROOT}" "rtl" "${AFTER_APK}"

capture_apk_to_pr83_png "${BEFORE_APK}" "${BEFORE_FULL}" "${OUT_DIR}/android-before.png"
capture_apk_to_pr83_png "${AFTER_APK}" "${AFTER_FULL}" "${OUT_DIR}/android-after.png"

ls -lh "${OUT_DIR}/android-before.png" "${OUT_DIR}/android-after.png"
