#!/bin/bash
# SwiftKeyRemap.app を組み立てて署名する。
# 手順: xcodebuild で Release ビルド（Xcode 側では署名しない）→ build/ にコピー → 内側から順に署名。
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="SwiftKeyRemap"
APP_DIR="${DIR}/build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
DERIVED_DATA="${DIR}/build/DerivedData"

echo "==> xcodebuild (release)"
xcodebuild -project "${DIR}/${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -arch arm64 \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -quiet build

echo "==> bundle"
rm -rf "${APP_DIR}"
mkdir -p "${DIR}/build"
cp -R "${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app" "${APP_DIR}"

# 署名 ID: CODESIGN_IDENTITY があればそれ、なければ Keychain の Developer ID Application、どちらもなければ ad hoc。
# ad hoc 署名はビルドのたびに変わり、アクセシビリティ等の許可がリセットされることがある。証明書ならアプリの同一性が保たれる。
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY="Developer ID Application"
fi
if [ -n "${IDENTITY}" ]; then
  SIGN=(--force --options runtime --timestamp --sign "${IDENTITY}")
  echo "==> codesign (${IDENTITY})"
else
  SIGN=(--force --sign -)
  echo "==> codesign (ad-hoc)"
fi

# Sparkle は独自の実行ファイルを同梱しており、macOS はそれぞれに個別の署名を求める。
# Sparkle が文書化している順序で内側から署名する。--deep は使わない。
# Downloader.xpc はサンドボックスで動くため entitlements を保持する。
SPARKLE="${CONTENTS}/Frameworks/Sparkle.framework"
if [ -d "${SPARKLE}" ]; then
  SPARKLE_VERSION="${SPARKLE}/Versions/B"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/XPCServices/Installer.xpc"
  codesign "${SIGN[@]}" --preserve-metadata=entitlements "${SPARKLE_VERSION}/XPCServices/Downloader.xpc"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/Autoupdate"
  codesign "${SIGN[@]}" "${SPARKLE_VERSION}/Updater.app"
  codesign "${SIGN[@]}" "${SPARKLE}"
else
  echo "    Sparkle.framework was not found in the app bundle; skipping framework signing." >&2
fi

codesign "${SIGN[@]}" "${APP_DIR}"

echo "==> codesign --verify"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "==> done: ${APP_DIR}"
