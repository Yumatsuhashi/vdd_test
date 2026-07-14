#!/bin/bash
# build.sh - original/ + assets/ から公開用 public/ を生成する
#
# 変換内容:
#   1. 元 Cloudflare Worker のオリジン URL をルート絶対パスに置換
#      (https://delicate-pine-6fa3.yxnatakeuchi.workers.dev/... -> /...)
#   2. 各コンテンツ HTML を元サイトのパス構造 (design/ sdn/ RS/ Programmability/) へ再配置
#   3. ハブ (index.html) の休眠 iframe の src を about:blank にし、
#      ブラウザ拡張が注入した不要ブロックを除去
#   4. 新規アセット (manifest.json / icon-192.png / sw.js / Policy プレースホルダー) を配置
#
# 使い方: リポジトリルートで  bash scripts/build.sh

set -euo pipefail
cd "$(dirname "$0")/.."   # リポジトリルートへ

ORIGIN='https://delicate-pine-6fa3.yxnatakeuchi.workers.dev'
SRC="original"
ASSETS="assets"
OUT="public"

echo "[build] クリーン: $OUT/"
rm -rf "$OUT"
mkdir -p "$OUT/design" "$OUT/sdn" "$OUT/RS" "$OUT/Programmability"

# オリジン URL をルート絶対パスへ置換し、保存時にブラウザ拡張が注入した
# 不要要素 (SciSpace/Toastify) を除去して出力するヘルパ。全ファイル共通。
relativize() {  # $1=src file  $2=dst file
  sed "s|${ORIGIN}||g" "$1" > "$2"
  # (a) <head> へ注入された style ブロック (toastify / scispace / chrome-extension を
  #     含むもの) を除去。アプリ本来の style はこれらのトークンを含まないため残る。
  perl -0pi -e 's{<style\b[^>]*>(?:(?!</style>)[\s\S])*?(?:--toastify|scispace|chrome-extension)(?:(?!</style>)[\s\S])*?</style>}{}g' "$2"
  # (b) 注入されたトースト通知用の隠し div (3重ネスト) を除去
  perl -0pi -e 's{<div><div style="display: none; position: fixed; top: 30px;.*?</div></div></div>}{}gs' "$2"
  # (c) 注入された scispace 拡張のシャドウルート (chrome-extension 参照含む) を除去
  perl -0pi -e 's{<scispace-div\b.*?</scispace-div>}{}gs' "$2"
}

# --- ハブ (index.html) ---
echo "[build] index.html (ハブ) を生成"
relativize "$SRC/CCIE Study Hub.html" "$OUT/index.html"
# 休眠 iframe の初期 src を about:blank に (存在しない保存リソースへの 404 を防ぐ)
perl -0pi -e 's{src="\./CCIE Study Hub_files/saved_resource\.html"}{src="about:blank"}g' "$OUT/index.html"

# --- コンテンツページ (src|dst の対応表) ---
echo "[build] コンテンツページを再配置"
while IFS='|' read -r src dst; do
  [ -z "$src" ] && continue
  relativize "$SRC/$src" "$OUT/$dst"
  echo "  - $dst"
done <<'MAP'
CCIE EI Lab S2+ Design v1.1 - 全問一覧.html|design/Design_S2+.html
SPOTO CCIE EI Lab S2++ Design v1.5 - 全問一覧.html|design/Design_S2++.html
CCIE EI Lab S2+++ Design v1.0 - 全問一覧.html|design/Design_S2+++.html
SDN v1.1 Visual Architecture Map.html|sdn/sdn_v1_1_visual_map.html
SDN v1.3 Visual Architecture Map.html|sdn/sdn_v1_3_visual_map.html
CCIE EI Lab SDN S2 1.1 - 全問一覧.html|sdn/SDN S2 1.1 - 穴埋め.html
CCIE EI Lab SDN S2 1.3 - 全問一覧.html|sdn/SDN S2 1.3 - 穴埋め.html
RS コンフィグ パターン比較 (Task 1.2〜1.14).html|RS/config_comparison.html
Pattern 4 — 予想コマンド＆知識チートシート.html|RS/pattern4_cheatsheet.html
CCIE Automation Section 3 — 完全回答集.html|Programmability/spoto_programming_guide.html
Section 3 — コマンド一覧チートシート.html|Programmability/command_cheatsheet.html
MAP

# --- 新規アセット ---
echo "[build] アセットを配置"
cp "$ASSETS/manifest.json" "$OUT/manifest.json"
cp "$ASSETS/icon-192.png"  "$OUT/icon-192.png"
cp "$ASSETS/sw.js"         "$OUT/sw.js"
cp "$ASSETS/sdn_policy_guide.html" "$OUT/sdn/sdn_policy_guide.html"

echo "[build] 完了。生成物一覧:"
find "$OUT" -type f | sort | sed 's/^/  /'
