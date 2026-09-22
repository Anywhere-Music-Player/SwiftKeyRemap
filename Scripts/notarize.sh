#!/bin/bash
# アプリまたはディスクイメージを Apple の公証サービスへ提出し、チケットをステープルする。
# 使い方: Scripts/notarize.sh [対象]   （既定: build/SwiftKeyRemap.app）
#
# 対象は .app バンドルか .dmg。公証サービスはバンドルではなく書庫を受け取るため、.app のときは提出用に zip を作る。
# チケットはアプリ本体にステープルされるので、この zip は提出専用。配布用の書庫は別途作る。.dmg はそのまま提出する。
# .app は先に build.sh を、.dmg は先に make-dmg.sh を実行しておくこと。
#
# 認証情報は環境変数で渡す:
#   NOTARY_KEYCHAIN_PROFILE  `xcrun notarytool store-credentials` で保存したプロファイル名
#   NOTARY_KEY_P8            App Store Connect API キーのパス（NOTARY_KEY_ID と NOTARY_ISSUER_ID も必要）
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${DIR}/build/SwiftKeyRemap.app}"

if [ ! -e "${TARGET}" ]; then
  echo "${TARGET} was not found. Run build.sh for an app or make-dmg.sh for a disk image first." >&2
  exit 1
fi

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  CREDENTIALS=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
elif [ -n "${NOTARY_KEY_P8:-}" ]; then
  CREDENTIALS=(--key "${NOTARY_KEY_P8}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER_ID}")
else
  echo "Notarization credentials are missing. Set NOTARY_KEYCHAIN_PROFILE, or NOTARY_KEY_P8, NOTARY_KEY_ID and NOTARY_ISSUER_ID." >&2
  exit 1
fi

case "${TARGET}" in
  *.app)
    SUBMISSION="${DIR}/build/notarize/$(basename "${TARGET%.app}").zip"
    echo "==> archive for submission"
    mkdir -p "$(dirname "${SUBMISSION}")"
    rm -f "${SUBMISSION}"
    ditto -c -k --keepParent "${TARGET}" "${SUBMISSION}"
    # Gatekeeper がアプリを実行対象として評価する
    ASSESS=(-t exec)
    ;;
  *.dmg)
    SUBMISSION="${TARGET}"
    # Gatekeeper がイメージを開く対象として、イメージ自身の署名で評価する
    ASSESS=(-t open --context context:primary-signature)
    ;;
  *)
    echo "Only .app bundles and .dmg images are supported: ${TARGET}" >&2
    exit 1
    ;;
esac

echo "==> notarytool submit"
xcrun notarytool submit "${SUBMISSION}" "${CREDENTIALS[@]}" --wait

echo "==> stapler staple"
xcrun stapler staple "${TARGET}"
xcrun stapler validate "${TARGET}"
spctl -a -vvv "${ASSESS[@]}" "${TARGET}"

echo "==> done: ${TARGET}"
