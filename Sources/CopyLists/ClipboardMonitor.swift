/* @source cursor @line_count 52 @branch main */
import AppKit

/// 通过轮询 NSPasteboard.changeCount 检测剪贴板变化，每 0.5 秒检查一次
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
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
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

        // 优先取文本内容
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            history.addItem(string)
            return
        }

        // 次选：文件 URL 路径
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let paths = urls.map(\.path).joined(separator: "\n")
            if !paths.isEmpty {
                history.addItem(paths)
            }
            return
        }

        // 图片：记录占位描述（不存储二进制）
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue]) {
            history.addItem("[图片]")
        }
    }
}
