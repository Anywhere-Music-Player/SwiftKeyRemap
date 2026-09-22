#!/bin/bash
# build/SwiftKeyRemap.app から配布用のディスクイメージ build/SwiftKeyRemap-v<版>-arm64.dmg を作る（create-dmg を使う。brew install create-dmg）。
#
# 先に build.sh と notarize.sh を実行しておくこと。アプリはそのままイメージに入るので、
# ステープル済みのチケットを持っている必要がある。イメージ自体の公証は、出来上がった dmg に対して
# notarize.sh をもう一度実行する。
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"

APP_NAME="SwiftKeyRemap"
APP_DIR="${DIR}/build/${APP_NAME}.app"
WORK="${DIR}/build/dmg"
STAGING="${WORK}/staging"
BACKGROUND="${WORK}/background.png"

if [ ! -d "${APP_DIR}" ]; then
  echo "${APP_DIR} was not found. Run build.sh first." >&2
  exit 1
fi

if ! command -v create-dmg > /dev/null; then
  echo "create-dmg was not found. Install it with brew install create-dmg." >&2
  exit 1
fi

# 版はビルド済みアプリの Info.plist から取る。配布物の名前は zip と同じ規則にする
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist")"
DMG="${DIR}/build/SwiftKeyRemap-v${VERSION}-arm64.dmg"

# 署名 ID の選び方は build.sh と同じ: CODESIGN_IDENTITY があればそれ、なければ Keychain の Developer ID Application、
# どちらもなければ署名しない。イメージの署名は公証に必須ではないが、証明書があるなら付けておく。
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY="Developer ID Application"
fi

echo "==> background"
mkdir -p "${WORK}"
swift "${DIR}/Scripts/make-dmg-background.swift" "${BACKGROUND}"

# create-dmg は元フォルダの中身をすべて入れるので、staging にはアプリだけを置く。
# Applications フォルダは --app-drop-link で入る。
echo "==> staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"

# ウィンドウの寸法は make-dmg-background.swift と合わせる。背景の矢印は 2 つのアイコン中心の間に描かれる。
echo "==> create-dmg"
rm -f "${DMG}"
CREATE_DMG_ARGS=(
  --volname "${APP_NAME}"
  --volicon "${APP_DIR}/Contents/Resources/AppIcon.icns"
  --background "${BACKGROUND}"
  --window-pos 200 120
  --window-size 660 400
  --icon-size 128
  --icon "${APP_NAME}.app" 165 190
  --hide-extension "${APP_NAME}.app"
  --app-drop-link 495 190
)
create-dmg "${CREATE_DMG_ARGS[@]}" "${DMG}" "${STAGING}"

# create-dmg の --codesign は識別子をファイル名から作るので、ここで識別子を指定して署名する
if [ -n "${IDENTITY}" ]; then
  echo "==> codesign (${IDENTITY})"
  codesign --force --timestamp --sign "${IDENTITY}" --identifier "io.github.dominion525.cmd-eikana.dmg" "${DMG}"
else
  echo "==> codesign skipped: no Developer ID Application certificate or CODESIGN_IDENTITY was found"
fi

echo "==> done: ${DMG}"
