/* @source cursor @line_count 188 @branch main */
import Foundation
import AppKit

// MARK: - 数据模型
struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String         // 文本内容；图片为 "图片 W×H"（供搜索）
    var previewText: String     // 显示用的截断文本
    var imageFileName: String?  // 非 nil 表示图片条目，值为磁盘文件名
    var contentHash: String?    // 图片去重用的 SHA256 前缀；文本条目为 nil
    var lastUsed: Date
    var copyCount: Int
    var isFavorite: Bool = false
    var ocrText: String? = nil  // Vision OCR 识别的图片文字（用于搜索）

    var isImage: Bool { imageFileName != nil }

    // 搜索用全文：文本内容 + OCR 文字
    var searchableText: String { content + (ocrText.map { " " + $0 } ?? "") }

    /// 文本条目
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.previewText = String(content.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.imageFileName = nil
        self.contentHash = nil
        self.lastUsed = Date()
        self.copyCount = 1
    }

    /// 图片条目
    init(imageFilename: String, size: CGSize, hash: String) {
        self.id = UUID()
        let desc = "图片 \(Int(size.width))×\(Int(size.height))"
        self.content = desc
        self.previewText = desc
        self.imageFileName = imageFilename
        self.contentHash = hash
        self.lastUsed = Date()
        self.copyCount = 1
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - LRU 历史记录
/// 淘汰策略：最近最少使用（LRU）
/// - 新复制内容插入头部；粘贴/访问已有条目时移至头部
/// - 超出容量后删除尾部（最久未使用），图片条目同时删除磁盘文件
/// - 文本重复内容：合并并移至头部，copyCount++
/// - 图片：每次截图均作为新条目，不去重
final class ClipboardHistory: ObservableObject {

    @Published private(set) var items: [ClipboardItem] = []
    private let maxSize: Int
    private let persistenceKey = "CopyListsHistory"
    private let queue = DispatchQueue(label: "com.copylists.history", attributes: .concurrent)

    init(maxSize: Int = 0) {
        let saved = UserDefaults.standard.integer(forKey: "maxHistorySize")
        self.maxSize = (saved > 0) ? saved : (maxSize > 0 ? maxSize : 50)
        loadFromDisk()
    }

    // MARK: - 写入文本
    func addItem(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items

            if let idx = updated.firstIndex(where: { !$0.isImage && $0.content == trimmed }) {
                var item = updated.remove(at: idx)
                item.lastUsed = Date()
                item.copyCount += 1
                updated.insert(item, at: 0)
            } else {
                updated.insert(ClipboardItem(content: trimmed), at: 0)
                self.evict(&updated)
            }
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - 写入图片（含去重）
    /// hash 为原始图片数据的 SHA256，用于判断是否已存在相同图片
    func addImage(filename: String, size: CGSize, hash: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items

            if let existingIdx = updated.firstIndex(where: {
                $0.isImage && $0.contentHash == hash
            }) {
                // 已存在相同图片：移至头部，删除刚保存的重复文件
                ImageStorage.shared.delete(filename: filename)
                var item = updated.remove(at: existingIdx)
                item.lastUsed = Date()
                item.copyCount += 1
                updated.insert(item, at: 0)
            } else {
                // 全新图片
                let newItem = ClipboardItem(imageFilename: filename, size: size, hash: hash)
                updated.insert(newItem, at: 0)
                self.evict(&updated)
            }
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - LRU 淘汰（超容量删尾部，跳过收藏项，图片同时清理文件）
    private func evict(_ list: inout [ClipboardItem]) {
        var removed = 0
        var i = list.count - 1
        while list.count > maxSize && i >= 0 {
            if !list[i].isFavorite {
                let tail = list.remove(at: i)
                if let fn = tail.imageFileName { ImageStorage.shared.delete(filename: fn) }
                removed += 1
            }
            i -= 1
        }
    }

    // MARK: - 标记使用（提升到头部）
    func markUsed(item: ClipboardItem) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items
            guard let idx = updated.firstIndex(where: { $0.id == item.id }) else { return }
            var target = updated.remove(at: idx)
            target.lastUsed = Date()
            updated.insert(target, at: 0)
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - 删除单条
    func removeItem(_ item: ClipboardItem) {
        if let fn = item.imageFileName { ImageStorage.shared.delete(filename: fn) }
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let updated = self.items.filter { $0.id != item.id }
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - 动态调整历史上限
    func applyNewMaxSize(_ newMax: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items
            self.evict(&updated)
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - OCR 回填（图片识别完成后异步更新）
    func updateOCR(filename: String, text: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items
            guard let idx = updated.firstIndex(where: { $0.imageFileName == filename }) else { return }
            updated[idx].ocrText = text
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - 收藏切换（收藏项永久保存，不随 LRU 淘汰；不改变排列顺序）
    func toggleFavorite(item: ClipboardItem) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items
            guard let idx = updated.firstIndex(where: { $0.id == item.id }) else { return }
            updated[idx].isFavorite.toggle()
            DispatchQueue.main.async { self.items = updated; self.saveToDisk(updated) }
        }
    }

    // MARK: - 清空（保留收藏项）
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let toDelete = self.items.filter { !$0.isFavorite }
            toDelete.forEach { if let fn = $0.imageFileName { ImageStorage.shared.delete(filename: fn) } }
            let kept = self.items.filter { $0.isFavorite }
            DispatchQueue.main.async {
                self.items = kept
                if kept.isEmpty {
                    UserDefaults.standard.removeObject(forKey: self.persistenceKey)
                } else {
                    self.saveToDisk(kept)
                }
            }
        }
    }

    // MARK: - 持久化
    private func saveToDisk(_ items: [ClipboardItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = Array(saved.prefix(maxSize))
    }
}
