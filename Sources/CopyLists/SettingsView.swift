/* @source cursor @line_count 198 @branch main */
import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 设置窗口控制器
final class SettingsWindowController {
    private var window: NSWindow?

    func show(monitor: ClipboardMonitor, history: ClipboardHistory) {
        if let w = window, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let view = SettingsView(monitor: monitor, history: history)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 440)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "CopyLists 设置"
        w.contentView = hosting
        w.center()
        w.isReleasedWhenClosed = false
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 设置主视图
struct SettingsView: View {
    let monitor: ClipboardMonitor
    let history: ClipboardHistory

    // 历史条数
    @State private var maxSize: Int = UserDefaults.standard.integer(forKey: "maxHistorySize").nonZero(default: 50)
    // 开机启动
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    // 暂停监听
    @State private var isPaused: Bool = UserDefaults.standard.bool(forKey: "monitorPaused")
    // 排除 App 列表（bundle id）
    @State private var excludedList: [String] = (UserDefaults.standard.stringArray(forKey: "excludedBundleIDs") ?? [])
                                                    .sorted()
    @State private var newExcludeInput: String = ""
    @State private var showRestoreAlert = false

    private let sizeOptions = [20, 50, 100, 200, 500]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("通用")
                generalSection

                sectionHeader("隐私与安全")
                privacySection

                sectionHeader("排除应用")
                excludeSection

                sectionHeader("数据管理")
                dataSection
            }
            .padding(20)
        }
        .frame(width: 480, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 通用
    private var generalSection: some View {
        settingsCard {
            // 开机启动
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("开机自动启动").font(.system(size: 13, weight: .medium))
                    Text("登录后自动在后台运行").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { val in
                        do {
                            if val { try SMAppService.mainApp.register() }
                            else   { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = !val
                        }
                    }
            }

            Divider()

            // 历史记录条数
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("历史记录条数上限").font(.system(size: 13, weight: .medium))
                    Text("超出后自动删除最旧记录（收藏不受影响）").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $maxSize) {
                    ForEach(sizeOptions, id: \.self) { n in Text("\(n) 条").tag(n) }
                }
                .pickerStyle(.menu)
                .frame(width: 90)
                .onChange(of: maxSize) { val in
                    UserDefaults.standard.set(val, forKey: "maxHistorySize")
                    history.applyNewMaxSize(val)
                }
            }
        }
    }

    // MARK: - 隐私
    private var privacySection: some View {
        settingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isPaused ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(isPaused ? "监听已暂停" : "监听运行中")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Text(isPaused ? "剪贴板内容不会被记录" : "正在记录剪贴板变化")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isPaused },
                    set: { val in
                        isPaused = val
                        monitor.isPaused = val
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - 排除应用
    private var excludeSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("以下 Bundle ID 的应用处于前台时，不记录剪贴板内容。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)

                ForEach(excludedList, id: \.self) { bid in
                    HStack {
                        Text(bid).font(.system(size: 12, design: .monospaced)).foregroundStyle(.primary)
                        Spacer()
                        Button {
                            excludedList.removeAll { $0 == bid }
                            monitor.excludedBundleIDs = Set(excludedList)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("添加 Bundle ID，如 com.company.appname", text: $newExcludeInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("添加") {
                        let bid = newExcludeInput.trimmingCharacters(in: .whitespaces)
                        guard !bid.isEmpty, !excludedList.contains(bid) else { return }
                        excludedList.append(bid); excludedList.sort()
                        monitor.excludedBundleIDs = Set(excludedList)
                        newExcludeInput = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(newExcludeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - 数据管理
    private var dataSection: some View {
        settingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("恢复默认排除列表").font(.system(size: 13, weight: .medium))
                    Text("重置为内置的密码管理器排除列表").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("恢复默认") {
                    excludedList = ClipboardMonitor.defaultExcluded.sorted()
                    monitor.excludedBundleIDs = Set(ClipboardMonitor.defaultExcluded)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 辅助
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

private extension Int {
    func nonZero(default val: Int) -> Int { self == 0 ? val : self }
}
