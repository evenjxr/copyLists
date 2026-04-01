/* @source cursor @line_count 82 @branch main */
import AppKit
import Foundation

/// 负责截图/图片的磁盘存储、读取、缩略图生成和粘贴板写入
final class ImageStorage {

    static let shared = ImageStorage()

    private let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("CopyLists/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - 保存
    /// 将 NSImage 保存为 PNG，返回文件名（不含路径）
    func save(image: NSImage) -> String? {
        guard let png = image.pngData() else { return nil }
        let filename = UUID().uuidString + ".png"
        let url = directory.appendingPathComponent(filename)
        try? png.write(to: url)
        return filename
    }

    // MARK: - 加载
    func load(filename: String) -> NSImage? {
        NSImage(contentsOf: directory.appendingPathComponent(filename))
    }

    /// 生成固定高度的缩略图（保持宽高比）
    func thumbnail(filename: String, maxHeight: CGFloat = 72) -> NSImage? {
        guard let image = load(filename: filename) else { return nil }
        let size = image.size
        guard size.height > 0 else { return nil }
        let scale = maxHeight / size.height
        let newSize = CGSize(width: size.width * scale, height: maxHeight)
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    // MARK: - 删除
    func delete(filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    // MARK: - 写入粘贴板
    @discardableResult
    func putOnPasteboard(filename: String) -> Bool {
        guard let image = load(filename: filename) else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        return true
    }
}

// MARK: - NSImage PNG 转换
private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
