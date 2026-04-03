/* @source cursor @line_count 670 @branch main */
import AppKit
import SwiftUI

final class PinPanel: NSPanel {
    var commandReturnHandler: (() -> Void)?
    var closeHandler: (() -> Void)?
    var undoHandler: (() -> Void)?
    var redoHandler: (() -> Void)?
    var toggleAlwaysOnTopHandler: ((Bool) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let hasCmd   = event.modifierFlags.contains(.command)
            let hasShift = event.modifierFlags.contains(.shift)
            if hasCmd && (event.keyCode == 36 || event.keyCode == 76) {
                commandReturnHandler?(); return
            }
            if hasCmd && !hasShift && event.keyCode == 6 { // ⌘Z
                undoHandler?(); return
            }
            if hasCmd && hasShift && event.keyCode == 6 {  // ⌘⇧Z
                redoHandler?(); return
            }
            if event.keyCode == 53 {
                closeHandler?(); return
            }
        }
        super.sendEvent(event)
    }
}

final class FloatingPinManager {
    private var windows: [PinPanel] = []
    private var panelsByKey: [String: PinPanel] = [:]
    private let margin: CGFloat = 18
    private let panelWidth: CGFloat = 480

    // MARK: - 弹框 frame 持久化
    private func savedFrame(for key: String) -> NSRect? {
        guard let arr = UserDefaults.standard.array(forKey: "pinFrame:\(key)") as? [CGFloat],
              arr.count == 4 else { return nil }
        return NSRect(x: arr[0], y: arr[1], width: arr[2], height: arr[3])
    }
    private func saveFrame(_ frame: NSRect, for key: String) {
        UserDefaults.standard.set([frame.origin.x, frame.origin.y,
                                   frame.size.width, frame.size.height],
                                  forKey: "pinFrame:\(key)")
    }

    func pinText(_ text: String, dedupeKey: String) {
        if let existing = panelsByKey[dedupeKey], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: false)
            return
        }
        var latestText = text
        weak var panelRef: PinPanel?

        let size = suggestedTextPanelSize(for: text)
        let panel = buildPanel(
            size: size,
            title: "文本",
            dedupeKey: dedupeKey,
            commandReturnHandler: { [weak self] in
                self?.copyTextToPasteboard(latestText)
                panelRef?.close()
            },
            closeHandler: { panelRef?.close() }
        ) { p in
            PinnedTextView(
                initialText: text,
                onTextChanged: { latestText = $0 },
                onCommit: {
                    self.copyTextToPasteboard(latestText)
                    panelRef?.close()
                },
                onToggleAlwaysOnTop: { pinned in p.toggleAlwaysOnTopHandler?(pinned) }
            )
        }
        panelRef = panel
        placeTopRight(panel, key: dedupeKey)
        observeFrameChanges(panel, key: dedupeKey)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    func pinImage(_ image: NSImage, dedupeKey: String) {
        if let existing = panelsByKey[dedupeKey], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: false)
            return
        }
        let size = suggestedImagePanelSize(for: image)
        weak var panelRef: PinPanel?
        let store = ImageAnnotationStore()
        let panel = buildPanel(
            size: size,
            title: "图片",
            dedupeKey: dedupeKey,
            commandReturnHandler: {
                FloatingPinManager.renderAnnotatedImage(image: image, store: store)
                panelRef?.close()
            },
            closeHandler: { panelRef?.close() }
        ) { p in
            PinnedImageView(
                image: image,
                store: store,
                onToggleAlwaysOnTop: { pinned in p.toggleAlwaysOnTopHandler?(pinned) }
            )
        }
        panel.undoHandler = { store.undo() }
        panel.redoHandler = { store.redo() }
        panelRef = panel
        placeTopRight(panel, key: dedupeKey)
        observeFrameChanges(panel, key: dedupeKey)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    static func renderAnnotatedImage(image: NSImage, store: ImageAnnotationStore) {
        let imgW = image.size.width
        let imgH = image.size.height
        let geoSize = store.geoSize
        guard imgW > 0, imgH > 0, geoSize.width > 0, geoSize.height > 0 else {
            // geoSize 未就绪时直接把原图写剪贴板
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
            return
        }

        let scale = min(geoSize.width / imgW, geoSize.height / imgH)
        let drawX = (geoSize.width  - imgW * scale) / 2
        let drawY = (geoSize.height - imgH * scale) / 2

        let outSize = NSSize(width: imgW, height: imgH)
        let outImage = NSImage(size: outSize)
        outImage.lockFocus()

        // 画底图（NSImage 坐标系：原点左下角，y 向上）
        image.draw(in: NSRect(origin: .zero, size: outSize))

        if let ctx = NSGraphicsContext.current?.cgContext {
            // 翻转坐标系使 y=0 在顶部，与 SwiftUI Canvas 一致
            ctx.saveGState()
            ctx.translateBy(x: 0, y: imgH)
            ctx.scaleBy(x: 1, y: -1)

            for item in store.annotations {
                // 将显示坐标映射到原图坐标
                let pts = item.points.map {
                    CGPoint(x: ($0.x - drawX) / scale,
                            y: ($0.y - drawY) / scale)
                }
                ctx.setStrokeColor(item.color.cgColor)
                ctx.setLineWidth(item.width / scale)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                switch item.tool {
                case .pen:
                    guard pts.count > 1 else { continue }
                    ctx.beginPath()
                    ctx.move(to: pts[0])
                    pts.dropFirst().forEach { ctx.addLine(to: $0) }
                    ctx.strokePath()
                case .rect:
                    guard pts.count == 2 else { continue }
                    ctx.stroke(CGRect(
                        x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                        width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y)
                    ))
                case .arrow:
                    guard pts.count == 2 else { continue }
                    let s = pts[0], e = pts[1]
                    let dx = e.x - s.x, dy = e.y - s.y
                    let len = max(sqrt(dx*dx + dy*dy), 0.001)
                    let ux = dx/len, uy = dy/len
                    let head = max(10, item.width / scale * 3), wing = head * 0.55
                    let p1 = CGPoint(x: e.x - ux*head + (-uy)*wing, y: e.y - uy*head + ux*wing)
                    let p2 = CGPoint(x: e.x - ux*head - (-uy)*wing, y: e.y - uy*head - ux*wing)
                    ctx.beginPath(); ctx.move(to: s); ctx.addLine(to: e); ctx.strokePath()
                    ctx.beginPath(); ctx.move(to: e); ctx.addLine(to: p1); ctx.strokePath()
                    ctx.beginPath(); ctx.move(to: e); ctx.addLine(to: p2); ctx.strokePath()
                }
            }
            ctx.restoreGState()
        }
        outImage.unlockFocus()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([outImage])
    }

    private func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func suggestedTextPanelSize(for text: String) -> NSSize {
        let textWidth: CGFloat = panelWidth - 44
        let measured = text.nsHeight(
            constrainedTo: textWidth,
            font: NSFont.systemFont(ofSize: 15)
        )
        let minH: CGFloat = 220
        let maxH: CGFloat = 620
        let contentH = measured + 120
        return NSSize(width: panelWidth, height: min(max(contentH, minH), maxH))
    }

    private func suggestedImagePanelSize(for image: NSImage) -> NSSize {
        let imageWidth = panelWidth - 22
        let ratio = max(image.size.height / max(image.size.width, 1), 0.1)
        let imageH = imageWidth * ratio
        let minH: CGFloat = 280
        let maxH: CGFloat = 760
        return NSSize(width: panelWidth, height: min(max(imageH + 84, minH), maxH))
    }

    private func buildPanel<Content: View>(
        size: NSSize,
        title: String,
        dedupeKey: String,
        commandReturnHandler: (() -> Void)?,
        closeHandler: (() -> Void)?,
        @ViewBuilder content: (PinPanel) -> Content
    ) -> PinPanel {
        let panel = PinPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        // 仅允许通过标题栏拖动，避免图片涂鸦时误拖窗口
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true
        // 默认不强制置顶，等用户主动 pin
        panel.hidesOnDeactivate = true
        panel.commandReturnHandler = commandReturnHandler
        panel.closeHandler = closeHandler
        panel.minSize = NSSize(width: 360, height: 220)

        // pin 激活：level=floating + 不随失焦隐藏；取消：恢复普通行为
        panel.toggleAlwaysOnTopHandler = { [weak panel] pinned in
            panel?.level = pinned ? .floating : .floating
            panel?.hidesOnDeactivate = !pinned
        }

        let root = PinContainerView(content: content(panel))
        let host = NSHostingView(rootView: root)
        host.translatesAutoresizingMaskIntoConstraints = false

        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        bg.addSubview(host)

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: bg.topAnchor),
            host.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])
        panel.contentView = bg

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.panelsByKey.removeValue(forKey: dedupeKey)
            self?.windows.removeAll { $0 === panel }
        }
        windows.append(panel)
        panelsByKey[dedupeKey] = panel
        return panel
    }

    private func placeTopRight(_ panel: PinPanel, key: String) {
        if let saved = savedFrame(for: key),
           let screen = NSScreen.main,
           screen.frame.intersects(saved) {
            panel.setFrame(saved, display: false)
            return
        }
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.maxX - panel.frame.width - margin
        let usedHeight = windows
            .filter { $0 !== panel && $0.isVisible }
            .reduce(0) { $0 + $1.frame.height + margin }
        let y = sf.maxY - panel.frame.height - margin - usedHeight
        panel.setFrameOrigin(NSPoint(x: x, y: max(sf.minY + margin, y)))
    }

    private func observeFrameChanges(_ panel: PinPanel, key: String) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self, weak panel] _ in
            guard let self, let panel else { return }
            self.saveFrame(panel.frame, for: key)
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self, weak panel] _ in
            guard let self, let panel else { return }
            self.saveFrame(panel.frame, for: key)
        }
    }
}

private struct PinContainerView<Content: View>: View {
    let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

// 置顶切换按钮（📌 风格）
private struct PinToggleButton: View {
    @Binding var alwaysOnTop: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                alwaysOnTop.toggle()
            }
            onChange(alwaysOnTop)
        } label: {
            // 实心 = 已置顶；空心 = 未置顶；颜色统一用次要色
            Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
        .help(alwaysOnTop ? "取消窗口置顶" : "窗口置顶")
    }
}

private struct PinnedTextView: View {
    @State private var text: String
    @State private var alwaysOnTop: Bool = false
    let onTextChanged: (String) -> Void
    let onCommit: () -> Void
    let onToggleAlwaysOnTop: (Bool) -> Void

    init(initialText: String,
         onTextChanged: @escaping (String) -> Void,
         onCommit: @escaping () -> Void,
         onToggleAlwaysOnTop: @escaping (Bool) -> Void) {
        _text = State(initialValue: initialText)
        self.onTextChanged = onTextChanged
        self.onCommit = onCommit
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
                .onChange(of: text) { onTextChanged($0) }
                .onAppear { onTextChanged(text) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Spacer()
                    PinToggleButton(alwaysOnTop: $alwaysOnTop) { onToggleAlwaysOnTop($0) }
                    Button("完成", action: onCommit)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                HStack(spacing: 14) {
                    textShortcutHint("⌘↩", "保存")
                    textShortcutHint("Esc", "关闭")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func textShortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .foregroundStyle(.tertiary)
    }
}

enum ImageTool: String, CaseIterable, Identifiable {
    case pen, arrow, rect
    var id: String { rawValue }

    var label: String {
        switch self {
        case .pen: return "画笔"
        case .arrow: return "箭头"
        case .rect: return "矩形"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .rect: return "square"
        }
    }
}

// 注解数据共享对象：ObservableObject 让视图响应变化，同时外部可同步读取
final class ImageAnnotationStore: ObservableObject {
    @Published var annotations: [PinAnnotation] = []
    var geoSize: CGSize = .zero

    private var undoStack: [[PinAnnotation]] = []
    private var redoStack: [[PinAnnotation]] = []

    func pushAnnotation(_ ann: PinAnnotation) {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.append(ann)
    }

    func clearAnnotations() {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.removeAll()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = prev
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }
}

struct PinAnnotation {
    let tool: ImageTool
    let points: [CGPoint]
    let color: NSColor
    let width: CGFloat
}

private struct PinnedImageView: View {
    let image: NSImage
    @ObservedObject var store: ImageAnnotationStore
    let onToggleAlwaysOnTop: (Bool) -> Void
    @State private var alwaysOnTop: Bool = false
    @State private var draftingPoints: [CGPoint] = []
    @State private var penNSColor: NSColor = NSColor(calibratedRed: 1, green: 0.23, blue: 0.19, alpha: 1)
    @State private var lineWidth: CGFloat = 3
    @State private var tool: ImageTool = .pen
    @State private var colorIndex: Int = 0
    @State private var baseZoom: CGFloat = 1
    @GestureState private var pinchZoom: CGFloat = 1
    // 调色板直接用 NSColor，写入 store 无需 SwiftUI.Color 转换
    private let palette: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.23, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.00, alpha: 1),
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.48, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.69, green: 0.32, blue: 0.87, alpha: 1),
        NSColor.black
    ]
    private var penColor: Color { Color(nsColor: penNSColor) }

    private var currentZoom: CGFloat {
        min(max(baseZoom * pinchZoom, 0.5), 4.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                    Canvas { context, _ in
                        for item in store.annotations {
                            draw(item.points, tool: item.tool,
                                 color: Color(nsColor: item.color),
                                 width: item.width, in: &context)
                        }
                        draw(draftingPoints, tool: tool, color: penColor, width: lineWidth, in: &context)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in updateDraft(with: value.location) }
                            .onEnded { _ in commitDraft() }
                    )
                }
                .scaleEffect(currentZoom, anchor: .center)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinchZoom) { value, state, _ in state = value }
                        .onEnded { value in
                            baseZoom = min(max(baseZoom * value, 0.5), 4.0)
                        }
                )
                .onAppear { store.geoSize = geo.size }
                .onChange(of: geo.size) { store.geoSize = $0 }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                // 第一行：工具栏
                HStack(spacing: 8) {
                    toolButtons
                    colorButtons
                    Spacer(minLength: 4)
                    Button(action: { store.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("撤销 ⌘Z")
                    Button(action: { store.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("重做 ⌘⇧Z")
                    Text("\(Int(lineWidth))px")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, alignment: .trailing)
                    Slider(value: $lineWidth, in: 1...10)
                        .frame(width: 72)
                        .controlSize(.mini)
                    Divider().frame(height: 14)
                    PinToggleButton(alwaysOnTop: $alwaysOnTop) { onToggleAlwaysOnTop($0) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

                Divider()

                // 第二行：快捷键说明
                HStack(spacing: 14) {
                    shortcutHint("⌘Z",    "撤销")
                    shortcutHint("⌘⇧Z",   "重做")
                    shortcutHint("⌘↩",    "保存")
                    shortcutHint("Esc",   "关闭")
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var toolButtons: some View {
        HStack(spacing: 4) {
            ForEach(ImageTool.allCases) { item in
                Button {
                    tool = item
                    draftingPoints.removeAll(keepingCapacity: true)
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(tool == item ? Color.white : Color.secondary)
                        .background(tool == item ? Color(red: 0.00, green: 0.48, blue: 1.00) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .help(item.label)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorButtons: some View {
        HStack(spacing: 6) {
            ForEach(Array(palette.enumerated()), id: \.offset) { idx, color in
                Button {
                    colorIndex = idx
                    penNSColor = color
                } label: {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                        .overlay(
                            Circle().strokeBorder(
                                Color.black.opacity(colorIndex == idx ? 0.8 : 0.14),
                                lineWidth: colorIndex == idx ? 2 : 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updateDraft(with point: CGPoint) {
        switch tool {
        case .pen:
            draftingPoints.append(point)
        case .arrow, .rect:
            if draftingPoints.isEmpty {
                draftingPoints = [point, point]
            } else if draftingPoints.count == 1 {
                draftingPoints.append(point)
            } else {
                draftingPoints[1] = point
            }
        }
    }

    private func commitDraft() {
        switch tool {
        case .pen:
            guard draftingPoints.count > 1 else {
                draftingPoints.removeAll(keepingCapacity: true)
                return
            }
        case .arrow, .rect:
            guard draftingPoints.count == 2 else {
                draftingPoints.removeAll(keepingCapacity: true)
                return
            }
        }
        store.pushAnnotation(PinAnnotation(
            tool: tool, points: draftingPoints,
            color: penNSColor, width: lineWidth
        ))
        draftingPoints.removeAll(keepingCapacity: true)
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .foregroundStyle(.tertiary)
    }

    private func draw(_ points: [CGPoint], tool: ImageTool, color: Color, width: CGFloat, in context: inout GraphicsContext) {
        switch tool {
        case .pen:
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: points[0])
            for p in points.dropFirst() { path.addLine(to: p) }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        case .rect:
            guard points.count == 2 else { return }
            let rect = CGRect(
                x: min(points[0].x, points[1].x),
                y: min(points[0].y, points[1].y),
                width: abs(points[1].x - points[0].x),
                height: abs(points[1].y - points[0].y)
            )
            context.stroke(Path(rect), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        case .arrow:
            guard points.count == 2 else { return }
            let start = points[0]
            let end = points[1]
            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))

            let dx = end.x - start.x
            let dy = end.y - start.y
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            let ux = dx / len
            let uy = dy / len
            let head: CGFloat = max(10, width * 3)
            let wing: CGFloat = head * 0.55

            let p1 = CGPoint(x: end.x - ux * head + (-uy) * wing, y: end.y - uy * head + ux * wing)
            let p2 = CGPoint(x: end.x - ux * head - (-uy) * wing, y: end.y - uy * head - ux * wing)

            var arrow = Path()
            arrow.move(to: end)
            arrow.addLine(to: p1)
            arrow.move(to: end)
            arrow.addLine(to: p2)
            context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

private extension String {
    func nsHeight(constrainedTo width: CGFloat, font: NSFont) -> CGFloat {
        let attr = [NSAttributedString.Key.font: font]
        let rect = (self as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attr
        )
        return ceil(rect.height)
    }
}
