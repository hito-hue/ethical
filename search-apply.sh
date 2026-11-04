#!/usr/bin/env bash
# Google検索広告用LP（search/）に「Google広告のID（AW-…）」と「コンバージョンの変換ラベル」を差し込む。
#   広告のリンク先（予定）: https://hito-hue.github.io/ethical/search/ （GitHub Pages）
#
# 使い方:
#   bash search-apply.sh <AW-ID> <変換ラベル> [<DiscordのWebhook URL>]
#     例) bash search-apply.sh AW-123456789 AbCdEfGhIjKlMnOp
#   bash search-apply.sh --show        ← 今入っている値を表示するだけ（何も書き換えない）
#
#   ・AW-ID と 変換ラベルは、Google広告の「目標 → コンバージョン → 作ったアクション → タグを設定 → 自分でタグをインストール」に出る
#     イベントスニペットの send_to: 'AW-123456789/AbCdEfGhIjKlMnOp' の「/の前」と「/の後ろ」。
#   ・3つ目（任意）は Google検索広告用の新しい Discord チャンネルの Webhook URL。
#     ※Meta用チャンネルのURLは入れないこと（ダッシュボードがMeta広告のリードとして数えてしまう）。
#   ・何度実行してもよい（前に入れた値を新しい値で上書きする）。
#
# ★このスクリプトは手元のファイルを書き換えるだけ。公開（VPSへのコピー・GitHubへのpush）は下でコメントアウトしてある。
#   公開は伊藤さんのOKをもらってから、コメントを外すか同じコマンドを手で実行する。
set -euo pipefail
cd "$(dirname "$0")"

IDX=search/index.html
THX=search/thanks.html

show() {
  echo "--- 今の値 ---"
  echo "Googleタグ(index) : $(grep -o "gtag('config', '[^']*')" "$IDX" | head -1)"
  echo "Googleタグ(thanks): $(grep -o "gtag('config', '[^']*')" "$THX" | head -1)"
  echo "コンバージョン    : $(grep -o "'send_to': '[^']*'" "$THX" | head -1)"
  echo "Discord           : $(grep -E '^\s*const DISCORD_WEBHOOK' "$IDX" | grep -o '"[^"]*"' | head -1 | cut -c1-60)"
  echo "送信元の印        : $(grep -o "source:'[^']*'" "$IDX" | sort -u | tr '\n' ' ')"
}

if [ "${1:-}" = "--show" ]; then show; exit 0; fi

AW="${1:-}"; LABEL="${2:-}"; HOOK="${3:-}"
# 2026-11-04〜 DiscordのウェブフックURLはLPに書かない（誰でも偽の通知を送れるため）。サーバー /opt/ethical-dash/.env の DISCORD_GOOGLE_WEBHOOK に入れる。
if [ -n "$HOOK" ]; then echo "DiscordのURLはLPに入れません。サーバーの .env（DISCORD_GOOGLE_WEBHOOK）に入れてください。" >&2; exit 1; fi
if [ -z "$AW" ] || [ -z "$LABEL" ]; then
  echo "使い方: bash search-apply.sh <AW-ID> <変換ラベル> [<DiscordのWebhook URL>]" >&2; exit 1
fi
# 形のチェック（打ち間違いでLPを壊さないため）
[[ "$AW" =~ ^AW-[0-9]{6,15}$ ]] || { echo "AW-ID の形が違います（例 AW-123456789）: $AW" >&2; exit 1; }
[[ "$LABEL" =~ ^[A-Za-z0-9_-]{6,40}$ ]] || { echo "変換ラベルの形が違います（英数字と - _ だけ）: $LABEL" >&2; exit 1; }
if [ -n "$HOOK" ]; then
  [[ "$HOOK" =~ ^https://(discord\.com|discordapp\.com)/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$ ]] || { echo "Webhook URL の形が違います: $HOOK" >&2; exit 1; }
  META_HOOK="$(grep -E '^\s*const DISCORD_WEBHOOK' lp/index.html | grep -o 'https://[^"]*' | head -1 || true)"
  if [ -n "$META_HOOK" ] && [ "$HOOK" = "$META_HOOK" ]; then
    echo "そのWebhookは Meta用LP と同じチャンネルです。Google検索広告用の新しいチャンネルのURLを使ってください。" >&2; exit 1
  fi
fi

# 1) AW-ID：ダミー（AW-XXXXXXXXXX）または前に入れたID を新しいIDに（index・thanks の両方）
for f in "$IDX" "$THX"; do
  perl -0pi -e "s/AW-(?:X{10}|[0-9]{6,15})/$AW/g" "$f"
done
# 2) 変換ラベル：サンクスページの send_to の「/の後ろ」
perl -0pi -e "s{('send_to': 'AW-[0-9]+/)[^']*'}{\${1}$LABEL'}g" "$THX"
# 3) Discord（任意・index側だけに定数がある）
if [ -n "$HOOK" ]; then
  perl -0pi -e "s|^(\\s*)const DISCORD_WEBHOOK = \"[^\"]*\";|\${1}const DISCORD_WEBHOOK = \"$HOOK\";|m" "$IDX"
fi

# 置き換え漏れの確認
if grep -q "AW-XXXXXXXXXX\|YYYYYYYY" "$IDX" "$THX"; then
  echo "⚠️ ダミーの値が残っています。中身を確認してください。" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# 公開（★伊藤さんのOKが出るまで実行しない。OK後にコメントを外す／または手で実行）
# ---------------------------------------------------------------------------
# VPS（予備の置き場。Meta用・TikTok用と同じ /opt/ethical の下）
# KEY="$HOME/.ssh/filedrop_vps"; H="root@85.131.252.8"
# ssh -i "$KEY" "$H" "mkdir -p /opt/ethical/search"
# scp -q -i "$KEY" search/index.html   "$H:/opt/ethical/search/index.html"
# scp -q -i "$KEY" search/thanks.html  "$H:/opt/ethical/search/thanks.html"
# scp -q -i "$KEY" search/privacy.html "$H:/opt/ethical/search/privacy.html"
#
# GitHub Pages（search/ だけをコミット。Meta版・TikTok版のファイルは触らない）
# git add search/index.html search/thanks.html search/privacy.html
# if ! git diff --cached --quiet -- search/; then
#   git commit -q -m "Google検索広告用LP: タグID/変換ラベルを更新" -- search/index.html search/thanks.html search/privacy.html
#   git push -q origin main
# fi

echo "=== 手元のファイルに反映しました（まだ公開していません）==="
show
echo "広告のリンク先（公開後）: https://hito-hue.github.io/ethical/search/ （GitHubの反映は1〜2分）"
