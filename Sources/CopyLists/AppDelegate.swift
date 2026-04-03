/* @source cursor @line_count 185 @branch main */
import AppKit
import Carbon.HIToolbox
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panelController: ClipboardPanelController!
    private var clipboardMonitor: ClipboardMonitor!
    private(set) var history: ClipboardHistory!
    private var settingsController = SettingsWindowController()

    // Carbon 热键引用
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // 状态栏暂停菜单项（动态更新标题）
    private weak var pauseMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        history = ClipboardHistory(maxSize: 50)
        clipboardMonitor = ClipboardMonitor(history: history)
        clipboardMonitor.start()

        panelController = ClipboardPanelController(history: history)
        setupStatusItem()
        setupCarbonHotkey()

        // 首次启动自动弹出主面板
        let launchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: launchedKey) {
            UserDefaults.standard.set(true, forKey: launchedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.panelController.showPanel()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }

    // MARK: - 状态栏图标
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        updateStatusIcon()

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "显示历史记录  ⌘⇧V", action: #selector(showPanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let pauseTitle = clipboardMonitor.isPaused ? "恢复记录" : "暂停记录"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(title: "清空历史记录", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 CopyLists", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        _ = button
    }

    private func updateStatusIcon() {
        let name = clipboardMonitor.isPaused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "CopyLists")
        statusItem.button?.image?.isTemplate = true
    }

    // MARK: - Carbon 全局热键注册（不需要辅助功能权限）
    private func setupCarbonHotkey() {
        // 安装事件处理器
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async { delegate.togglePanel() }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // 注册 ⌘⇧V 热键 (kVK_ANSI_V = 9)
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4953) // "CLIS"
        hotKeyID.id = 1

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            // 注册失败时回退到 NSEvent 全局监听（需要辅助功能权限）
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags.contains([.command, .shift]) && event.keyCode == 9 {
                    DispatchQueue.main.async { self?.togglePanel() }
                }
            }
        }
    }

    // MARK: - 辅助功能权限（仅粘贴模拟需要）
    func checkAndPromptAccessibility() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限（用于自动粘贴）"
            alert.informativeText = "快捷键唤起无需权限，但「自动粘贴」功能需要辅助功能权限。\n\n前往：系统设置 → 隐私与安全性 → 辅助功能，添加本应用后重启。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    // MARK: - 面板控制
    @objc private func showPanel() { panelController.showPanel() }
    @objc private func clearHistory() { history.clearAll() }
    func togglePanel() { panelController.togglePanel() }

    // MARK: - 暂停/恢复
    @objc private func togglePause() {
        clipboardMonitor.isPaused.toggle()
        let paused = clipboardMonitor.isPaused
        pauseMenuItem?.title = paused ? "恢复记录" : "暂停记录"
        updateStatusIcon()
    }

    // MARK: - 设置
    @objc private func openSettings() {
        settingsController.show(monitor: clipboardMonitor, history: history)
    }
}
