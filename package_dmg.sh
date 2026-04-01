#!/bin/bash
# @source cursor @line_count 30 @branch main
# 将 CopyLists.app 打包成 DMG 供分发

set -e

APP="CopyLists.app"
DMG="CopyLists.dmg"
STAGING="dmg_staging"

# 先构建
bash build_app.sh

echo "▶ 创建 DMG..."
rm -rf "$STAGING" "$DMG"
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
echo "   文件大小：$(du -sh $DMG | cut -f1)"
