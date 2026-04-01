#!/bin/bash
# @source cursor @line_count 57 @branch main
# 构建 CopyLists.app 包（macOS 13+）

set -e

APP_NAME="CopyLists"
BUNDLE_ID="com.copylists.app"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
ICON_SRC="AppIcon.icns"

echo "▶ 编译 Release..."
swift build -c release 2>&1

echo "▶ 打包 ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 复制图标
if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "   图标已嵌入"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>CopyLists</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>CopyLists 需要辅助功能权限以监听全局快捷键 ⌘⇧V 并自动粘贴内容。</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ 构建完成：${APP_BUNDLE}"
echo "   运行方式：open ${APP_BUNDLE}"
echo "   或直接双击 Finder 中的 ${APP_BUNDLE}"
