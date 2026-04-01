/* @source cursor @line_count 74 @branch main */
import AppKit
import CryptoKit

/// 通过轮询 NSPasteboard.changeCount 检测剪贴板变化，每 0.5 秒检查一次
/// 优先级：图片（截图）> 文本 > 文件路径
final class ClipboardMonitor {

    private let history: ClipboardHistory
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general

    init(history: ClipboardHistory) {
        self.history = history
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
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // 1. 图片优先（当没有文字时才记录为图片，避免把带图文本记两次）
        //    截图/复制图片 → 粘贴板只有 TIFF/PNG，无对应文本
        let hasText = pasteboard.string(forType: .string).map { !$0.isEmpty } ?? false

        if !hasText {
            if let imageData = pasteboard.data(forType: .tiff),
               let image = NSImage(data: imageData),
               image.size.width > 10, image.size.height > 10 {
                let hash = imageHash(imageData)
                if let filename = ImageStorage.shared.save(image: image) {
                    history.addImage(filename: filename, size: image.size, hash: hash)
                }
                return
            }

            // PNG 类型（部分 App 用 PNG 而非 TIFF）
            if let imageData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")),
               let image = NSImage(data: imageData),
               image.size.width > 10, image.size.height > 10 {
                let hash = imageHash(imageData)
                if let filename = ImageStorage.shared.save(image: image) {
                    history.addImage(filename: filename, size: image.size, hash: hash)
                }
                return
            }
        }

        // 2. 文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            history.addItem(string)
            return
        }

        // 3. 文件 URL 路径
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let paths = urls.map(\.path).joined(separator: "\n")
            if !paths.isEmpty { history.addItem(paths) }
        }
    }

    // MARK: - SHA256 哈希（取前 16 字节 hex，足够唯一且开销极小）
    private func imageHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
