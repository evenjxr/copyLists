/* @source cursor @line_count 398 @branch main */
/* @source cursor @line_count 18 @branch main */
import SwiftUI
import AppKit
import Combine

// MARK: - 内容类型
enum ContentKind: CaseIterable, Equatable, Hashable {
    case image, url, email, filePath, code, text

    var icon: String {
        switch self {
        case .image:    return "photo.fill"
        case .url:      return "link.circle.fill"
        case .email:    return "envelope.circle.fill"
        case .filePath: return "folder.circle.fill"
        case .code:     return "curlybraces.square.fill"
        case .text:     return "doc.circle.fill"
        }
    }

    var filterIcon: String {
        switch self {
        case .image:    return "photo"
        case .url:      return "link"
        case .email:    return "envelope"
        case .filePath: return "folder"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .text:     return "doc.text"
        }
    }

    var label: String {
        switch self {
        case .image:    return "截图"
        case .url:      return "URL"
        case .email:    return "邮箱"
        case .filePath: return "路径"
        case .code:     return "代码"
        case .text:     return "文本"
        }
    }

    var color: Color {
        switch self {
        case .image:    return Color(red: 0.99, green: 0.45, blue: 0.40)
        case .url:      return Color(red: 0.00, green: 0.48, blue: 1.00)
        case .email:    return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .filePath: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .code:     return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .text:     return Color(red: 0.42, green: 0.47, blue: 0.55)
        }
    }

    /// 根据完整 ClipboardItem 检测（含图片判断）
    static func detect(item: ClipboardItem) -> ContentKind {
        if item.isImage { return .image }
        return detectText(item.content)
    }

    private static func detectText(_ text: String) -> ContentKind {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .text }
        let urlRx  = #"^(https?|ftp)://[^\s]+"#
        let wwwRx  = #"^www\.[^\s]+\.[^\s]+"#
        if t.range(of: urlRx,  options: .regularExpression) != nil { return .url }
        if t.range(of: wwwRx,  options: .regularExpression) != nil { return .url }
        let emailRx = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#
        if t.range(of: emailRx, options: .regularExpression) != nil { return .email }
        if t.hasPrefix("/") || t.hasPrefix("~/") || t.hasPrefix("./") { return .filePath }
        let codeHints = ["{", "}", "func ", "def ", "class ", "import ", "const ",
                         "let ", "var ", "=>", "->", "!=", "&&", "||", "#!/"]
        if t.count > 8 && codeHints.contains(where: { t.contains($0) }) { return .code }
        return .text
    }
}

// MARK: - 键盘桥接
final class KeyboardBridge: ObservableObject {
    enum Action { case up, down, confirm, escape, delete, filterLeft, filterRight }
    let keyPress = PassthroughSubject<Action, Never>()
    func send(_ action: Action) { keyPress.send(action) }
}

// MARK: - 主视图
struct ContentView: View {

    @ObservedObject var history: ClipboardHistory
    @ObservedObject var keyboard: KeyboardBridge

    var onSelect: (ClipboardItem) -> Void
    var onClose:  () -> Void
    var onDelete: (ClipboardItem) -> Void

    @State private var searchText    = ""
    @State private var filterKind: ContentKind? = nil
    @State private var selectedIndex = 0
    @State private var appeared = false
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardItem] {
        var result = history.items
        if let kind = filterKind {
            result = result.filter { ContentKind.detect(item: $0) == kind }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let words = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            result = result.filter { item in
                words.allSatisfy { item.content.localizedCaseInsensitiveContains($0) }
            }
        }
        return result
    }

    // 青白色调色盘
    private let warmStart  = Color(red: 0.000, green: 0.737, blue: 0.831) // 青色  #00BCE4
    private let warmMid    = Color(red: 0.000, green: 0.647, blue: 0.753) // 深青  #00A5C0
    private let warmEnd    = Color(red: 0.102, green: 0.741, blue: 0.737) // 青绿  #1ABCBC
    private let divLine    = Color(red: 0.855, green: 0.863, blue: 0.875) // #DADCE0
    private let hoverBg    = Color(red: 0.945, green: 0.953, blue: 0.957) // #F1F3F4
    private let selectBg   = Color(red: 1.000, green: 0.930, blue: 0.930) // 暖红浅底

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部统一渐变区（头部 + 搜索 + 筛选，一个背景从上到下消隐）──
            VStack(spacing: 0) {
                header
                searchBar
                filterBar
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: warmStart.opacity(0.28), location: 0.00),
                        .init(color: warmMid.opacity(0.20),   location: 0.30),
                        .init(color: warmEnd.opacity(0.12),   location: 0.60),
                        .init(color: warmEnd.opacity(0.00),   location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            divLine.frame(height: 1).opacity(0)   // 渐变已消隐，不需要额外分割线
            itemList
            divLine.frame(height: 1)
            footer
        }
        .background(.clear)
        .frame(width: 480, height: 580)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            searchFocused = true
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { appeared = true }
        }
        .onReceive(keyboard.keyPress) { handleKeyboard($0) }
        .onChange(of: searchText)  { _ in selectedIndex = 0 }
        .onChange(of: filterKind)  { _ in selectedIndex = 0 }
    }

    // MARK: - 头部（浅暖色调，深色文字）
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(warmMid)
            Text("CopyLists")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.15))
            Spacer()
            if !history.items.isEmpty {
                Text("\(history.items.count) 条")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(warmMid.opacity(0.12))
                    .foregroundStyle(warmMid)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .regular))
            TextField("搜索历史记录...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.white.opacity(0.92))    // 高白透明，渐变中部仍可见
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(searchFocused ? warmMid : Color.primary.opacity(0.12), lineWidth: searchFocused ? 1.5 : 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 类型筛选标签栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 全部
                FilterChip(
                    label: "全部",
                    icon: "square.grid.2x2",
                    color: Color(red: 0.40, green: 0.40, blue: 0.45),
                    count: history.items.count,
                    isSelected: filterKind == nil
                ) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                        filterKind = nil
                    }
                }

                ForEach(ContentKind.allCases, id: \.self) { kind in
                    let cnt = history.items.filter { ContentKind.detect(item: $0) == kind }.count
                    if cnt > 0 {
                        FilterChip(
                            label: kind.label,
                            icon: kind.filterIcon,
                            color: kind.color,
                            count: cnt,
                            isSelected: filterKind == kind
                        ) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                filterKind = (filterKind == kind) ? nil : kind
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 列表
    @ViewBuilder
    private var itemList: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            ItemRow(
                                item: item,
                                isSelected: index == selectedIndex
                            )
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                            .contextMenu {
                                Button("粘贴此内容")   { onSelect(item) }
                                Button("仅复制不粘贴") { copyOnly(item) }
                                Divider()
                                Button("删除", role: .destructive) { onDelete(item) }
                            }
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    // filter 或搜索变化时强制整列重建，彻底避免 SwiftUI 行视图复用导致 kind 显示错误
                    .id("\(filterKind?.label ?? "all")_\(searchText)")
                }
                .background(Color.white.opacity(0.92))   // 列表区域增亮
                .onChange(of: selectedIndex) { newIdx in
                    let list = filtered
                    guard newIdx < list.count else { return }
                    proxy.scrollTo(list[newIdx].id, anchor: .center)
                }
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: (searchText.isEmpty && filterKind == nil) ? "clipboard" : "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.quaternary)
            Text((searchText.isEmpty && filterKind == nil) ? "暂无复制记录" : "未找到匹配内容")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部
    private var footer: some View {
        HStack(spacing: 0) {
            footerKey("↑↓",  label: "选择")
            footerKey("←→",  label: "标签")
            footerKey("↵",   label: "粘贴")
            footerKey("⌘⌫",  label: "删除")
            footerKey("⎋",   label: "关闭")
            Spacer()
            Text("⌘⇧V 唤起")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func footerKey(_ key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
        .foregroundStyle(.tertiary)
        .padding(.trailing, 10)
    }

    // MARK: - 键盘处理
    private func handleKeyboard(_ action: KeyboardBridge.Action) {
        let list  = filtered
        let count = list.count
        switch action {
        case .up:           if selectedIndex > 0         { selectedIndex -= 1 }
        case .down:         if selectedIndex < count - 1 { selectedIndex += 1 }
        case .confirm:      guard !list.isEmpty else { return }; onSelect(list[selectedIndex])
        case .escape:       onClose()
        case .filterLeft:   cycleFilter(forward: false)
        case .filterRight:  cycleFilter(forward: true)
        case .delete:
            guard !list.isEmpty else { return }
            onDelete(list[selectedIndex])
            DispatchQueue.main.async {
                let n = self.filtered.count
                if self.selectedIndex >= n { self.selectedIndex = max(0, n - 1) }
            }
        }
    }

    // MARK: - 左右切换 Filter 标签
    private func cycleFilter(forward: Bool) {
        // 只展示有内容的 kind，顺序与标签栏一致
        let available: [ContentKind?] = [nil] + ContentKind.allCases.filter { kind in
            history.items.contains { ContentKind.detect(item: $0) == kind }
        }
        guard available.count > 1 else { return }
        let cur = available.firstIndex(where: { $0 == filterKind }) ?? 0
        let next = forward
            ? (cur + 1) % available.count
            : (cur - 1 + available.count) % available.count
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            filterKind = available[next]
        }
    }

    private func copyOnly(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }
}

// MARK: - 筛选标签 Chip
struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.22) : color.opacity(0.18))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isSelected ? color : Color.primary.opacity(0.07))
            .foregroundStyle(isSelected ? Color.white : color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - 单行视图
struct ItemRow: View {

    let item: ClipboardItem
    let isSelected: Bool

    @State private var isHovered  = false
    @State private var thumbnail: NSImage? = nil

    private var kind: ContentKind { ContentKind.detect(item: item) }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧类型色条（图片行高度更高）
            RoundedRectangle(cornerRadius: 2)
                .fill(kind.color)
                .frame(width: 3, height: item.isImage ? 64 : 36)
                .padding(.leading, 4)
                .padding(.trailing, 10)

            if item.isImage {
                imageContent
            } else {
                textContent
            }
        }
        .padding(.vertical, 7)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.08), value: isHovered)
    }

    // MARK: - 图片内容
    private var imageContent: some View {
        HStack(spacing: 10) {
            // 缩略图
            Group {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 90, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.previewText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                badgeRow
            }
            Spacer()
            copyCountBadge
        }
    }

    // MARK: - 文本内容
    private var textContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewText)
                    .lineLimit(2)
                    .font(.system(size: 13))
                badgeRow
            }
            Spacer()
            copyCountBadge
        }
    }

    // MARK: - 通用子视图
    private var badgeRow: some View {
        HStack(spacing: 6) {
            Label(kind.label, systemImage: kind.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(kind.color)
            Text("·").foregroundStyle(.quaternary).font(.system(size: 10))
            Text(relativeTime(item.lastUsed))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var copyCountBadge: some View {
        if item.copyCount > 1 {
            Text("×\(item.copyCount)")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(kind.color.opacity(0.15))
                .foregroundStyle(kind.color)
                .clipShape(Capsule())
                .padding(.trailing, 6)
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(kind.color.opacity(0.12))          // 与类型色条、标签颜色一致
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(kind.color.opacity(0.50), lineWidth: 1.5)
                )
        } else if isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(kind.color.opacity(0.06))
        } else {
            Color.clear
        }
    }

    // MARK: - 缩略图异步加载
    private func loadThumbnail() {
        guard item.isImage, let filename = item.imageFileName, thumbnail == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = ImageStorage.shared.thumbnail(filename: filename, maxHeight: 60)
            DispatchQueue.main.async { thumbnail = img }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60    { return "刚刚" }
        if diff < 3600  { return "\(Int(diff / 60)) 分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }
        let fmt = DateFormatter(); fmt.dateFormat = "MM/dd HH:mm"
        return fmt.string(from: date)
    }
}

