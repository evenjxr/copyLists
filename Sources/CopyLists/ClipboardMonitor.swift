/* @source cursor @line_count 118 @branch main */
import AppKit
import CryptoKit

/// 通过轮询 NSPasteboard.changeCount 检测剪贴板变化，每 0.5 秒检查一次
/// 支持暂停、敏感 App 排除
final class ClipboardMonitor {

    private let history: ClipboardHistory
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general

    // 暂停状态（持久化）
    var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: "monitorPaused") }
        set { UserDefaults.standard.set(newValue, forKey: "monitorPaused") }
    }

    // 排除的 App Bundle ID 列表（持久化）
    var excludedBundleIDs: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: "excludedBundleIDs") ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "excludedBundleIDs")
        }
    }

    // 默认排除的敏感 App（密码管理器等）
    static let defaultExcluded: [String] = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.1password.1password",
        "com.dashlane.dashlane",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop",
        "com.roboform.RoboFormDesktop"
    ]

    init(history: ClipboardHistory) {
        self.history = history
        // 首次初始化写入默认排除列表
        if UserDefaults.standard.object(forKey: "excludedBundleIDs") == nil {
            self.excludedBundleIDs = Set(ClipboardMonitor.defaultExcluded)
        }
    }

    func start() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        guard !isPaused else { return }

        // 排除敏感 App
        if let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIDs.contains(frontBundleID) {
            lastChangeCount = pasteboard.changeCount  // 更新计数，避免切回后重复记录
            return
        }

        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let hasText = pasteboard.string(forType: .string).map { !$0.isEmpty } ?? false

        if !hasText {
            if let imageData = pasteboard.data(forType: .tiff),
               let image = NSImage(data: imageData),
               image.size.width > 10, image.size.height > 10 {
                let hash = imageHash(imageData)
                if let filename = ImageStorage.shared.save(image: image) {
                    history.addImage(filename: filename, size: image.size, hash: hash)
                    OCRManager.recognize(image: image, filename: filename)
                }
                return
            }

            if let imageData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")),
               let image = NSImage(data: imageData),
               image.size.width > 10, image.size.height > 10 {
                let hash = imageHash(imageData)
                if let filename = ImageStorage.shared.save(image: image) {
                    history.addImage(filename: filename, size: image.size, hash: hash)
                    OCRManager.recognize(image: image, filename: filename)
                }
                return
            }
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            history.addItem(string)
            return
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let paths = urls.map(\.path).joined(separator: "\n")
            if !paths.isEmpty { history.addItem(paths) }
        }
    }

    private func imageHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
