#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$(dirname "$0")/.push-config.sh"

# ── 读取或询问远程仓库地址 ──────────────────────────────
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "=== Hermes Agent fnOS — GitHub 推送脚本 ==="
  echo ""
  read -rp "请输入 GitHub 仓库 URL (HTTPS): " REMOTE_URL
  echo "REMOTE_URL=\"$REMOTE_URL\"" > "$CONFIG_FILE"
  echo "URL 已保存到 $CONFIG_FILE，以后可直接运行 $0"
  echo ""
fi

# ── 检查 git 远程仓库 ──────────────────────────────────
cd "$(dirname "$0")"

if ! git remote get-url origin &>/dev/null; then
  echo "添加远程仓库 origin → $REMOTE_URL"
  git remote add origin "$REMOTE_URL"
fi

# ── 推送到 GitHub ──────────────────────────────────────
echo "推送 main 分支到 GitHub..."
git push -u origin main

echo ""
echo "✅ 推送完成！"
echo "   仓库地址: $REMOTE_URL"
