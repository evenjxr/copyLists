#!/bin/bash
: '/* @source cursor @line_count 29 @branch main */'

set -euo pipefail

APP_NAME="CopyLists"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_PATH=".build/arm64-apple-macosx/debug/${APP_NAME}"
LOG_FILE="/tmp/${APP_NAME}_dev.log"

cd "$ROOT_DIR"

echo "▶ 关闭已运行的 ${APP_NAME}..."
pkill -x "${APP_NAME}" 2>/dev/null || true

echo "▶ 编译 debug arm64..."
swift build -c debug --arch arm64

echo "▶ 直接启动二进制（不生成 .app 中间产物）..."
nohup "$BIN_PATH" >"$LOG_FILE" 2>&1 &
sleep 0.2

if pgrep -x "${APP_NAME}" >/dev/null; then
  echo "✅ 已启动：$BIN_PATH"
  echo "   日志：$LOG_FILE"
else
  echo "❌ 启动失败，请看日志：$LOG_FILE"
  exit 1
fi
