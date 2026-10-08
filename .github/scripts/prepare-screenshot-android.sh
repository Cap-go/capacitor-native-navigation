#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="${ROOT}/example-app/android"

for file in \
  "${ANDROID_DIR}/app/capacitor.build.gradle" \
  "${ANDROID_DIR}/capacitor.settings.gradle"; do
  if [ ! -f "${file}" ]; then
    echo "Missing ${file}" >&2
    exit 1
  fi
  sed -i '/capgo-capacitor-updater/d' "${file}"
done

echo "Removed @capgo/capacitor-updater from screenshot Android build."
