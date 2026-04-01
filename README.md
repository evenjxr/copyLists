# CopyLists

> macOS 剪贴板历史管理工具 — 原生 Swift 实现，轻量、快速、无需联网。

---

## 功能特性

| 功能 | 说明 |
|---|---|
| 📋 历史记录 | 自动监听剪贴板，记录最近 50 条内容（LRU 淘汰） |
| 🖼️ 截图支持 | 捕获微信截图等图片内容，保存为 PNG 并展示缩略图 |
| 🔍 实时搜索 | 支持多关键词（空格分隔）AND 过滤 |
| 🏷️ 类型标签 | 自动识别 URL / 邮箱 / 路径 / 代码 / 截图 / 文本，一键过滤 |
| ♻️ 自动去重 | 重复复制同一内容时自动置顶并累计次数，不产生重复条目 |
| ⌨️ 全键盘操作 | 所有操作均可通过键盘完成，无需鼠标 |
| 💾 持久化 | 退出后历史不丢失，下次启动自动恢复 |
| 🔒 纯本地 | 所有数据存储在本机，不上传任何内容 |

---

## 快捷键

| 按键 | 功能 |
|---|---|
| `⌘ ⇧ V` | 打开 / 关闭历史弹框 |
| `↑ ↓` | 在列表中上下选择 |
| `← →` | 切换类型过滤标签 |
| `↵` (Enter) | 粘贴选中内容到当前应用 |
| `⌘ ⌫` | 删除选中条目 |
| `⎋` (Esc) | 关闭弹框 |

---

## 系统要求

- macOS 13 (Ventura) 及以上
- Xcode Command Line Tools 或完整 Xcode（用于构建）

---

## 构建与运行

```bash
# 克隆仓库
git clone <repo-url>
cd copyLists

# 一键构建并打包为 .app
bash build_app.sh

# 运行
open CopyLists.app
```

首次运行时，系统会弹出授权对话框，**需授予「辅助功能」权限**（用于模拟粘贴），路径：

> 系统设置 → 隐私与安全性 → 辅助功能 → 开启 CopyLists

---

## 打包分发（DMG）

```bash
bash package_dmg.sh
```

执行后会在项目根目录生成 `CopyLists.dmg`，可直接发给他人安装。

接收方首次打开时，如提示"无法验证开发者"，在 Finder 中右键 → 打开 即可绕过 Gatekeeper。

---

## 项目结构

```
Sources/CopyLists/
├── main.swift                  # 入口，初始化 NSApplication
├── AppDelegate.swift           # 状态栏图标、Carbon 全局热键注册
├── ClipboardMonitor.swift      # 轮询 NSPasteboard，检测剪贴板变化
├── ClipboardHistory.swift      # LRU 缓存、持久化、去重逻辑
├── ImageStorage.swift          # 图片存储、缩略图生成、还原到剪贴板
├── ClipboardPanelController.swift  # NSPanel 管理、键盘事件拦截、粘贴逻辑
└── ContentView.swift           # SwiftUI UI：搜索栏、过滤标签、列表、行视图
```

---

## 数据存储位置

| 类型 | 路径 |
|---|---|
| 历史记录（JSON） | `~/Library/Application Support/CopyLists/history.json` |
| 图片文件（PNG） | `~/Library/Application Support/CopyLists/images/` |

---

## 技术栈

- **语言**：Swift 5.9
- **UI**：SwiftUI + AppKit（`NSPanel`、`NSVisualEffectView`）
- **热键**：Carbon `RegisterEventHotKey`（无需辅助功能权限）
- **粘贴模拟**：`CGEvent`（需要辅助功能权限）
- **图片哈希**：`CryptoKit.SHA256`（去重）
- **状态管理**：`ObservableObject` + `Combine.PassthroughSubject`

---

## License

MIT
