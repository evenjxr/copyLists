/* @source cursor @line_count 238 @branch main */
import AppKit
import SwiftUI

// MARK: - 自定义面板
// sendEvent 在事件分发给任何 View（包括 TextField）之前被调用，
// 这是拦截键盘的最可靠位置，不受 First Responder 影响。
final class ClipboardPanel: NSPanel {

    var keyInterceptor: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           let interceptor = keyInterceptor,
           interceptor(event) {
            return   // 事件已消费，不再分发给任何子视图
        }
        super.sendEvent(event)
    }
}

// MARK: - 面板控制器
final class ClipboardPanelController {

    private var panel: ClipboardPanel?
    private let history: ClipboardHistory
    private let keyboard = KeyboardBridge()
    private let pinManager = FloatingPinManager()
    private var previousApp: NSRunningApplication?

    init(history: ClipboardHistory) {
        self.history = history
    }

    // MARK: - 显示 / 隐藏
    func showPanel() {
        if let panel, panel.isVisible { return }

        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = buildPanel()
        self.panel = panel

        centerOnScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panel?.orderOut(nil)
        // 关闭面板后将焦点归还给之前的应用
        previousApp?.activate(options: [])
    }

    func togglePanel() {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - 键盘拦截（在 sendEvent 层消费，不到达 TextField）
    /// 返回 true = 已消费；返回 false = 继续正常分发
    private func interceptKey(_ event: NSEvent) -> Bool {
        let cmd   = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case 126:               keyboard.send(.up);          return true   // ↑
        case 125:               keyboard.send(.down);        return true   // ↓
        case 123:               keyboard.send(.filterLeft);  return true   // ← 切换标签
        case 124:               keyboard.send(.filterRight); return true   // → 切换标签
        case 36, 76:
            keyboard.send(shift ? .plainText : .confirm)     // ↵ 粘贴 / ⇧↵ 纯文本粘贴
            return true
        case 35 where cmd:      keyboard.send(.pin);          return true   // ⌘P 置顶悬浮
        case 1  where cmd:      keyboard.send(.favorite);    return true   // ⌘S 收藏
        case 53:                keyboard.send(.escape);      return true   // ⎋
        case 51 where cmd:      keyboard.send(.delete);      return true   // ⌘⌫ 删除条目
        default:
            // ⌘1~9 快速粘贴第 n 条
            if cmd, let digit = numberKey(event.keyCode), digit >= 1 && digit <= 9 {
                keyboard.send(.quickPaste(digit - 1))
                return true
            }
            return false
        }
    }

    // MARK: - 构建面板
    private func buildPanel() -> ClipboardPanel {
        let p = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.isReleasedWhenClosed = false

        let contentView = ContentView(
            history: history,
            keyboard: keyboard,
            onSelect:    { [weak self] item in self?.pasteItem(item) },
            onPin:       { [weak self] item in self?.pinItem(item) },
            onClose:     { [weak self] in self?.hidePanel() },
            onDelete:    { [weak self] item in self?.history.removeItem(item) },
            onFavorite:  { [weak self] item in self?.history.toggleFavorite(item: item) },
            onPlainText: { [weak self] item in self?.pastePlainText(item) }
        )

        // 关键：NSHostingView 默认有白色底层。
        // 正确做法：以 NSVisualEffectView 作为 contentView，
        // NSHostingView 嵌在其内，背景透明，由 NSVisualEffectView 提供毛玻璃效果。
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let vibrancy = NSVisualEffectView()
        vibrancy.material = .windowBackground  // 最亮浅色背景
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 14
        vibrancy.layer?.masksToBounds = true
        vibrancy.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: vibrancy.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
        ])

        p.contentView = vibrancy

        p.keyInterceptor = { [weak self] event in
            self?.interceptKey(event) ?? false
        }

        return p
    }

    // MARK: - 粘贴逻辑
    private func pasteItem(_ item: ClipboardItem) {
        history.markUsed(item: item)

        if item.isImage, let filename = item.imageFileName {
            // 图片：从磁盘读回写入粘贴板
            guard ImageStorage.shared.putOnPasteboard(filename: filename) else { return }
        } else {
            // 文本
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.content, forType: .string)
        }

        hidePanel()

        guard let target = previousApp else { return }
        target.activate(options: [])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.simulatePaste()
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - 纯文本粘贴
    private func pastePlainText(_ item: ClipboardItem) {
        history.markUsed(item: item)
        let plain: String
        if item.isImage {
            // 图片没有纯文本，降级为普通粘贴
            pasteItem(item); return
        } else {
            plain = item.content
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plain, forType: .string)
        hidePanel()
        guard let target = previousApp else { return }
        target.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self.simulatePaste() }
    }

    // MARK: - 置顶悬浮
    private func pinItem(_ item: ClipboardItem) {
        history.markUsed(item: item)
        let dedupeKey: String = {
            if item.isImage {
                if let hash = item.contentHash { return "img:\(hash)" }
                if let filename = item.imageFileName { return "img:\(filename)" }
                return "img:\(item.id.uuidString)"
            }
            return "txt:\(item.content)"
        }()
        if item.isImage, let filename = item.imageFileName {
            guard let image = ImageStorage.shared.load(filename: filename) else { return }
            pinManager.pinImage(image, dedupeKey: dedupeKey)
        } else {
            pinManager.pinText(item.content, dedupeKey: dedupeKey)
        }
    }

    private func numberKey(_ keyCode: UInt16) -> Int? {
        // kVK_ANSI_1..9 = 18,19,20,21,23,22,26,28,25
        let map: [UInt16: Int] = [18:1,19:2,20:3,21:4,23:5,22:6,26:7,28:8,25:9]
        return map[keyCode]
    }

    // MARK: - 居中显示
    private func centerOnScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.midX - panel.frame.width  / 2
        let y = sf.midY - panel.frame.height / 2 + sf.height * 0.08
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
