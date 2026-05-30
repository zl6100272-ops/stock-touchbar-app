#!/usr/bin/env bash
set -euo pipefail

APP_NAME="StockTouchBar"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp Info.plist "${CONTENTS_DIR}/Info.plist"

swiftc \
  -o "${MACOS_DIR}/${APP_NAME}" \
  Sources/*.swift \
  -framework AppKit \
  -framework Foundation

chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "Built ${APP_DIR}"
echo "Run with: open ${APP_DIR}"
