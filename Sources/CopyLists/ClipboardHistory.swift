/* @source cursor @line_count 118 @branch main */
import Foundation
import AppKit

// MARK: - 数据模型
struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String
    var previewText: String      // 截断后的预览
    var lastUsed: Date
    var copyCount: Int

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.previewText = String(content.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastUsed = Date()
        self.copyCount = 1
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - LRU 历史记录
/// 淘汰策略：最近最少使用（LRU）
/// - 新复制内容插入头部
/// - 粘贴/访问已有条目时移至头部
/// - 超出容量后删除尾部（最久未使用）
/// - 重复内容：合并并移至头部，cumCopyCount++
final class ClipboardHistory: ObservableObject {

    @Published private(set) var items: [ClipboardItem] = []
    private let maxSize: Int
    private let persistenceKey = "CopyListsHistory"
    private let queue = DispatchQueue(label: "com.copylists.history", attributes: .concurrent)

    init(maxSize: Int = 50) {
        self.maxSize = maxSize
        loadFromDisk()
    }

    // MARK: - 写入
    func addItem(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items

            if let existingIndex = updated.firstIndex(where: { $0.content == trimmed }) {
                // 已存在：提升到头部，累计次数
                var item = updated.remove(at: existingIndex)
                item.lastUsed = Date()
                item.copyCount += 1
                updated.insert(item, at: 0)
            } else {
                // 全新条目
                let newItem = ClipboardItem(content: trimmed)
                updated.insert(newItem, at: 0)
                // LRU 淘汰：超容量删最后一个（最久未使用）
                if updated.count > self.maxSize {
                    updated.removeLast()
                }
            }

            DispatchQueue.main.async {
                self.items = updated
                self.saveToDisk(updated)
            }
        }
    }

    /// 用户选中某条目粘贴时调用，将其提升到头部（更新 lastUsed）
    func markUsed(item: ClipboardItem) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var updated = self.items
            guard let idx = updated.firstIndex(where: { $0.id == item.id }) else { return }
            var target = updated.remove(at: idx)
            target.lastUsed = Date()
            updated.insert(target, at: 0)
            DispatchQueue.main.async {
                self.items = updated
                self.saveToDisk(updated)
            }
        }
    }

    func removeItem(_ item: ClipboardItem) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let updated = self.items.filter { $0.id != item.id }
            DispatchQueue.main.async {
                self.items = updated
                self.saveToDisk(updated)
            }
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.items = []
                UserDefaults.standard.removeObject(forKey: self.persistenceKey)
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
