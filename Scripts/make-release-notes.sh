#!/bin/bash
# リリース本文を、Sparkle が更新ダイアログに表示するページとして描画する。
# 使い方: Scripts/make-release-notes.sh <tag> <output.html>
#
# 本文は実行時点の GitHub リリースが持っているもので、リリースページと同じ Markdown API で描画するので
# 見た目が食い違わない。先頭に版と公開日の見出しを付ける。リリースワークフローが公開時に呼び、release-notes.yml が本文の編集のたびに呼び直す。
#
# gh は GH_TOKEN のトークンで動く。
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <tag> <output.html>" >&2
  exit 2
fi

TAG="$1"
OUTPUT="$2"
VERSION="${TAG#v}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

gh release view "${TAG}" --json body,publishedAt > "${WORK}/release.json"
jq -r .body "${WORK}/release.json" > "${WORK}/body.md"
body="$(gh api /markdown -f mode=gfm -F text=@"${WORK}/body.md")"
# 公開日は日本時間の日付で出す。gmtime の月は 0 始まり
published="$(jq -r '.publishedAt | fromdateiso8601 | strftime("%B %d, %Y (UTC)")' "${WORK}/release.json")"

mkdir -p "$(dirname "${OUTPUT}")"
{
  printf '<!doctype html>\n<meta charset="utf-8">\n'
  printf '<title>SwiftKeyRemap %s</title>\n' "${VERSION}"
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<style>body{font:14px/1.6 -apple-system,system-ui,sans-serif;margin:1em;color:#1d1d1f}'
  printf 'code,pre{font-family:ui-monospace,monospace;background:#f5f5f7;border-radius:4px}'
  printf 'pre{padding:.75em;overflow-x:auto}code{padding:.1em .3em}'
  printf 'h1,h2,h3{line-height:1.3}img{max-width:100%%}'
  printf '@media(prefers-color-scheme:dark){body{background:#1d1d1f;color:#f5f5f7}'
  printf 'code,pre{background:#2c2c2e}}</style>\n'
  # ページ単体で開いても、どの版のいつのノートか分かるように本文の先頭に置く
  printf '<h1>SwiftKeyRemap %s</h1>\n<p>Published %s</p>\n' "${VERSION}" "${published}"
  printf '%s\n' "${body}"
} > "${OUTPUT}"

echo "wrote ${OUTPUT}"
