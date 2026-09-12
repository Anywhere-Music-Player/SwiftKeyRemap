#!/bin/bash
# アプリを Apple の公証サービスへ提出し、チケットをステープルする。
# 使い方: Scripts/notarize.sh [app]   （既定: build/⌘英かな.app）
#
# 公証サービスはバンドルではなく書庫を受け取るため、提出用に zip を作る。
# チケットはアプリ本体にステープルされるので、この zip は提出専用。配布用の書庫は別途作る。
# 先に build.sh を実行しておくこと。
#
# 認証情報は環境変数で渡す:
#   NOTARY_KEYCHAIN_PROFILE  `xcrun notarytool store-credentials` で保存したプロファイル名
#   NOTARY_KEY_P8            App Store Connect API キーのパス（NOTARY_KEY_ID と NOTARY_ISSUER_ID も必要）
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${DIR}/build/⌘英かな.app}"

if [ ! -d "${TARGET}" ]; then
  echo "${TARGET} がありません。先に build.sh を実行してください。" >&2
  exit 1
fi

case "${TARGET}" in
  *.app) ;;
  *)
    echo "対象は .app バンドルだけです: ${TARGET}" >&2
    exit 1
    ;;
esac

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  CREDENTIALS=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
elif [ -n "${NOTARY_KEY_P8:-}" ]; then
  CREDENTIALS=(--key "${NOTARY_KEY_P8}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER_ID}")
else
  echo "公証の認証情報がありません。NOTARY_KEYCHAIN_PROFILE か、NOTARY_KEY_P8 と NOTARY_KEY_ID と NOTARY_ISSUER_ID を設定してください。" >&2
  exit 1
fi

SUBMISSION="${DIR}/build/notarize/$(basename "${TARGET%.app}").zip"
echo "==> archive for submission"
mkdir -p "$(dirname "${SUBMISSION}")"
rm -f "${SUBMISSION}"
ditto -c -k --keepParent "${TARGET}" "${SUBMISSION}"

echo "==> notarytool submit"
xcrun notarytool submit "${SUBMISSION}" "${CREDENTIALS[@]}" --wait

echo "==> stapler staple"
xcrun stapler staple "${TARGET}"
xcrun stapler validate "${TARGET}"
# Gatekeeper がアプリを実行対象として評価する
spctl -a -vvv -t exec "${TARGET}"

echo "==> done: ${TARGET}"
