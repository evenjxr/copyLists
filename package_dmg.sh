#!/bin/bash
# @source cursor @line_count 38 @branch main
# 将 CopyLists.app 打包成带版本号的 DMG 供分发
# 用法：bash package_dmg.sh [版本号]  默认 1.0.0

set -e

VERSION="${1:-1.0.0}"
BUILD_DATE=$(date "+%Y%m%d")
APP="CopyLists.app"
DMG="CopyLists.dmg"
STAGING="dmg_staging"

# 先构建（传入版本号）
bash build_app.sh "$VERSION"

echo "▶ 创建 DMG：${DMG}..."
rm -rf "$STAGING" CopyLists*.dmg
mkdir "$STAGING"
cp -R "$APP" "$STAGING/"

# 创建软链接到 /Applications，方便拖拽安装
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "CopyLists" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"

rm -rf "$STAGING"

echo "✅ 打包完成：$DMG"
echo "   版本：${VERSION}  日期：${BUILD_DATE}  架构：universal"
echo "   文件大小：$(du -sh "$DMG" | cut -f1)"
