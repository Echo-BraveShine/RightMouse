import FinderSync
import SwiftUI

@main
struct RightMouseApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: RightMouseAppDelegate

    var body: some Scene {
        Window("RightMouse", id: "settings") {
            SettingsView()
                .frame(minWidth: 680, minHeight: 470)
        }
        .defaultSize(width: 780, height: 530)

        Window(hiddenFilesTitle, id: "hidden-files") {
            HiddenFilesWindow(appDelegate: appDelegate)
                .frame(minWidth: 340, minHeight: 220)
                .handlesExternalEvents(preferring: [HiddenFilesWindow.route], allowing: [HiddenFilesWindow.route])
        }
        .defaultSize(width: 460, height: 320)
        .handlesExternalEvents(matching: [HiddenFilesWindow.route])
        .commandsRemoved()
    }

    private var hiddenFilesTitle: String {
        let language = (try? Preferences.load())?.resolvedLanguage ?? .systemDefault
        return language.text("隐藏文件")
    }
}

@MainActor
private final class RightMouseAppDelegate: NSObject, NSApplicationDelegate {
    var openSettingsWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard sender.activationPolicy() == .accessory, let openSettingsWindow else { return true }
        openSettingsWindow()
        return false
    }
}

private struct SettingsView: View {
    private enum Page: String, CaseIterable, Identifiable {
        case general = "通用"
        case commands = "右键菜单"
        case folders = "常用目录"
        case templates = "文件模板"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .commands: "cursorarrow.click"
            case .folders: "folder"
            case .templates: "doc.on.doc"
            }
        }
    }

    @State private var page: Page? = .general
    @State private var preferences = Preferences()
    @State private var loaded = false
    @State private var extensionEnabled = false
    @State private var checkedExtensionOnLaunch = false
    @State private var showExtensionPrompt = false
    @GestureState private var reorderDrag: ReorderDrag?

    private struct ReorderDrag {
        let source: Int
        let destination: Int
        let translation: CGFloat

        func offset(for index: Int, rowHeight: CGFloat) -> CGFloat {
            if index == source { return translation }
            if source < index && index <= destination { return -rowHeight }
            if destination <= index && index < source { return rowHeight }
            return 0
        }
    }
    @State private var selectedFolder: UUID?
    @State private var selectedTemplate: UUID?
    @State private var showTemplateRename = false
    @State private var templateNameDraft = ""
    @StateObject private var updates = ReleaseUpdates()
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .padding(8)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                let current = page ?? .general
                HStack(spacing: 12) {
                    pageIcon(current, size: 42)
                    Text(tr(current.rawValue))
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 4)

                switch current {
                case .general: general
                case .commands: commands
                case .folders: folders
                case .templates: templates
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            refreshExtensionStatus()
            if !checkedExtensionOnLaunch {
                checkedExtensionOnLaunch = true
                showExtensionPrompt = !extensionEnabled
            }
            guard !loaded else { return }
            do {
                preferences = try Preferences.load()
                NSApp.appearance = preferences.resolvedAppearance.appKitAppearance
                loaded = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: preferences.resolvedAppearance) { appearance in
            NSApp.appearance = appearance.appKitAppearance
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshExtensionStatus()
        }
        .task {
            // System Settings can save the extension state after the window becomes active.
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                refreshExtensionStatus()
            }
        }
        .alert(tr("启用访达扩展"), isPresented: $showExtensionPrompt) {
            Button(tr("打开扩展设置…")) {
                FIFinderSyncController.showExtensionManagementInterface()
            }
            .keyboardShortcut(.defaultAction)
            Button(tr("稍后"), role: .cancel) {}
        } message: {
            Text(tr("请在系统设置中启用 RightMouse 的访达扩展，启用后即可在访达中使用右键菜单。"))
        }
        .alert("RightMouse", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(tr("好"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func tr(_ text: String) -> String {
        preferences.resolvedLanguage.text(text)
    }

    private func refreshExtensionStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        if extensionEnabled { showExtensionPrompt = false }
    }

    private var general: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsSection(tr("访达扩展")) {
                    HStack(spacing: 10) {
                        Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(extensionEnabled ? Color.green : Color.secondary)
                            .accessibilityHidden(true)
                        Text(extensionEnabled ? tr("已启用") : tr("未启用"))
                        Spacer()
                        Button(tr("扩展设置…")) {
                            FIFinderSyncController.showExtensionManagementInterface()
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                }

                settingsSection(tr("语言与外观")) {
                    HStack {
                        Text(tr("语言"))
                        Spacer()
                        Picker(tr("语言"), selection: Binding(
                            get: { preferences.language },
                            set: { value in update { $0.language = value } }
                        )) {
                            Text(tr("跟随系统")).tag(Optional<InterfaceLanguage>.none)
                            Text("简体中文").tag(Optional(InterfaceLanguage.chinese))
                            Text("English").tag(Optional(InterfaceLanguage.english))
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)

                    Divider().padding(.horizontal, 14)

                    HStack {
                        Text(tr("外观"))
                        Spacer()
                        Picker(tr("外观"), selection: Binding(
                            get: { preferences.resolvedAppearance },
                            set: { value in update { $0.appearance = value } }
                        )) {
                            ForEach(InterfaceAppearance.allCases, id: \.self) { appearance in
                                Text(tr(appearance.title)).tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                }
                .disabled(!loaded)

                settingsSection(tr("版本与支持")) {
                    HStack(spacing: 10) {
                        Text(tr("版本"))
                        Text(ReleaseUpdates.installedVersion)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Button(tr("检查更新…"), action: updates.checkForUpdates)
                            .disabled(!updates.canCheck)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)

                    Divider().padding(.horizontal, 14)
                    Link(tr("官方网站"), destination: URL(string: "https://echo-braveshine.github.io/RightMouse/")!)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                    Divider().padding(.horizontal, 14)
                    Link(tr("请我喝杯咖啡"), destination: ReleaseUpdates.supportURL)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                }

                settingsSection(tr("在访达中使用")) {
                    instruction(tr("在文件夹空白处右键，选择「新建文件」。"), icon: "doc.badge.plus")
                    Divider().padding(.leading, 44).padding(.trailing, 14)
                    instruction(tr("选中文件后，使用「复制到」或「移动到」选择目标目录。"), icon: "folder")
                    Divider().padding(.leading, 44).padding(.trailing, 14)
                    HStack {
                        Button(tr("在访达打开用户目录")) {
                            NSWorkspace.shared.open(Preferences.homeDirectory)
                        }
                        .disabled(!extensionEnabled)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 2)
            VStack(alignment: .leading, spacing: 0, content: content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func instruction(_ text: String, icon: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 42, alignment: .leading)
    }

    @ViewBuilder
    private var sidebar: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let content = VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(nsImage: ReleaseUpdates.appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 31, height: 31)
                    .accessibilityHidden(true)
                Text("RightMouse").font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            VStack(spacing: 4) {
                ForEach(Page.allCases) { entry in
                    if entry == .commands {
                        Divider().padding(.vertical, 5)
                    }
                    Button {
                        page = entry
                    } label: {
                        HStack(spacing: 9) {
                            pageIcon(entry, size: 24)
                            Text(tr(entry.rawValue))
                                .font(.body.weight(page == entry ? .semibold : .medium))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .foregroundStyle(page == entry ? Color.accentColor : Color.primary)
                        .background(page == entry ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == entry ? .isSelected : [])
                    .disabled(entry != .general && !loaded)
                }
            }
            Spacer(minLength: 0)
            Label(tr("访达工具"), systemImage: "cursorarrow.click")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 3)
        }
        .padding(12)
        .frame(width: 186, alignment: .leading)

        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }

    private func pageIcon(_ entry: Page, size: CGFloat) -> some View {
        let color: Color
        switch entry {
        case .general: color = Color(nsColor: .systemGray)
        case .commands: color = Color(nsColor: .systemTeal)
        case .folders: color = Color(nsColor: .systemBlue)
        case .templates: color = Color(nsColor: .systemIndigo)
        }
        return Image(systemName: entry.symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }

    private var commands: some View {
        reorderList(\.commands) { command in
            Text(tr(command.rawValue))
                .accessibilityHidden(true)
            Spacer()
            Toggle(tr(command.rawValue), isOn: Binding(
                get: { !preferences.hidden.contains(command) },
                set: { enabled in
                    update {
                        if enabled { $0.hidden.remove(command) }
                        else { $0.hidden.insert(command) }
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(20)
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("这些目录也会出现在「移动到」和「复制到」菜单中。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            reorderList(\.folders, selection: $selectedFolder) { folder in
                Image(systemName: "folder").foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    TextField(tr("显示名称"), text: Binding(
                        get: { preferences.folders.first { $0.id == folder.id }?.name ?? folder.name },
                        set: { name in
                            update { config in
                                if let index = config.folders.firstIndex(where: { $0.id == folder.id }) {
                                    config.folders[index].name = name
                                }
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    Text(folder.url.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            HStack {
                Button(tr("添加目录…")) { chooseFolder() }
                Button(tr("重新选择…")) {
                    if let selectedFolder { chooseFolder(replacing: selectedFolder) }
                }
                .disabled(selectedFolder == nil)
                Button(tr("移除")) {
                    update { $0.folders.removeAll { $0.id == selectedFolder } }
                    selectedFolder = nil
                }
                .disabled(selectedFolder == nil)
            }
        }
        .padding(20)
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("导入一份示例文件，就能在访达里用它新建同类文件。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            reorderList(\.templates, selection: $selectedTemplate) { template in
                Image(systemName: "doc").foregroundStyle(.tint)
                Text(template.displayName(in: preferences.resolvedLanguage))
                Spacer()
                Text(".\(template.fileExtension)").foregroundStyle(.secondary)
            }
            HStack {
                Button(tr("导入模板…"), action: importTemplate)
                Button(tr("重命名…")) {
                    guard let template = preferences.templates.first(where: { $0.id == selectedTemplate }) else { return }
                    templateNameDraft = template.displayName(in: preferences.resolvedLanguage)
                    showTemplateRename = true
                }
                .disabled(selectedTemplate == nil)
                Button(tr("移除")) {
                    update { $0.templates.removeAll { $0.id == selectedTemplate } }
                    selectedTemplate = nil
                }
                .disabled(selectedTemplate == nil)
            }
        }
        .padding(20)
        .alert(tr("重命名模板"), isPresented: $showTemplateRename) {
            TextField(tr("模板名称"), text: $templateNameDraft)
            Button(tr("取消"), role: .cancel) {}
            Button(tr("保存")) {
                let name = trimmedTemplateName
                guard !name.isEmpty, let selectedTemplate else { return }
                update { preferences in
                    guard let index = preferences.templates.firstIndex(where: { $0.id == selectedTemplate }) else { return }
                    preferences.templates[index].name = name
                }
            }
            .disabled(trimmedTemplateName.isEmpty)
        }
    }

    private var trimmedTemplateName: String {
        templateNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let rowHeight: CGFloat = 44

    private func reorderList<Item: Identifiable, Row: View>(
        _ list: WritableKeyPath<Preferences, [Item]>,
        selection: Binding<Item.ID?>? = nil,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        let items = preferences[keyPath: list]
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let lifted = reorderDrag?.source == index
                    let offset = reorderDrag?.offset(for: index, rowHeight: rowHeight) ?? 0
                    HStack(spacing: 12) {
                        HStack(spacing: 10) { row(item) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .simultaneousGesture(TapGesture().onEnded {
                                selection?.wrappedValue = item.id
                            })
                        dragHandle(item, index: index, count: items.count, in: list)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    .background {
                        if lifted {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(.primary.opacity(0.10))
                                }
                                .shadow(color: .black.opacity(0.18), radius: 9, y: 4)
                        } else if selection?.wrappedValue == item.id {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.10))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if !lifted && index < items.count - 1 {
                            Divider().padding(.horizontal, 12).allowsHitTesting(false)
                        }
                    }
                    .scaleEffect(lifted ? 1.012 : 1)
                    .animation(.easeOut(duration: 0.14), value: lifted)
                    .offset(y: offset)
                    .animation(lifted ? nil : .spring(response: 0.27, dampingFraction: 0.86), value: offset)
                    .zIndex(lifted ? 1 : 0)
                }
            }
        }
    }

    private func dragHandle<Item: Identifiable>(
        _ item: Item, index: Int, count: Int, in list: WritableKeyPath<Preferences, [Item]>
    ) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 34)
            .contentShape(Rectangle())
            .help(tr("拖动以排序"))
            .accessibilityLabel(tr("拖动以排序"))
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .updating($reorderDrag) { value, drag, _ in
                        let translation = value.translation.height
                        drag = ReorderDrag(
                            source: index,
                            destination: dragDestination(index, count: count, offset: translation),
                            translation: min(max(translation, -CGFloat(index) * rowHeight),
                                             CGFloat(count - 1 - index) * rowHeight)
                        )
                    }
                    .onEnded { value in
                        let target = dragDestination(index, count: count, offset: value.translation.height)
                        if index != target { move(item, by: target - index, in: list) }
                    }
            )
            .accessibilityAction(named: Text(tr("上移"))) { move(item, by: -1, in: list) }
            .accessibilityAction(named: Text(tr("下移"))) { move(item, by: 1, in: list) }
    }

    private func dragDestination(_ index: Int, count: Int, offset: CGFloat) -> Int {
        min(max(index + Int((offset / rowHeight).rounded()), 0), count - 1)
    }

    private func move<Item: Identifiable>(
        _ item: Item, by offset: Int, in list: WritableKeyPath<Preferences, [Item]>
    ) {
        let items = preferences[keyPath: list]
        guard let source = items.firstIndex(where: { $0.id == item.id }),
              items.indices.contains(source + offset) else { return }
        let destination = source + offset + (offset > 0 ? 1 : 0)
        update { $0[keyPath: list].move(fromOffsets: IndexSet(integer: source), toOffset: destination) }
    }

    private func update(_ edit: (inout Preferences) -> Void) {
        var revised = preferences
        edit(&revised)
        do {
            try revised.save()
            preferences = revised
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chooseFolder(replacing id: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = tr("选择目录")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        update { config in
            if let id, let index = config.folders.firstIndex(where: { $0.id == id }) {
                config.folders[index].url = url
            } else {
                config.folders.append(Folder(name: url.lastPathComponent, url: url))
            }
        }
    }

    private func importTemplate() {
        let panel = NSOpenPanel()
        panel.prompt = tr("导入模板")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !url.pathExtension.isEmpty else {
            errorMessage = tr("请选择带扩展名的文件，例如 .docx 或 .md。")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            update {
                $0.templates.append(FileTemplate(
                    name: url.deletingPathExtension().lastPathComponent,
                    fileExtension: url.pathExtension,
                    data: data
                ))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


private extension InterfaceAppearance {
    var appKitAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

private struct HiddenFilesWindow: View {
    static let route = "rightmouse://hidden-files?"
    let appDelegate: RightMouseAppDelegate
    @Environment(\.openWindow) private var openWindow

    @State private var directory: URL?
    @State private var items: [URL] = []
    @State private var preferences = Preferences()
    @State private var errorMessage: String?
    @State private var itemOpenError: String?

    var body: some View {
        Group {
            if let errorMessage {
                VStack(spacing: 8) {
                    Text(preferences.resolvedLanguage.text("无法查看隐藏文件"))
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding()
            } else if let directory {
                HiddenItemsView(
                    directory: directory, items: items,
                    emptyMessage: preferences.resolvedLanguage.text("这个文件夹没有隐藏项目。"),
                    openTitle: preferences.resolvedLanguage.text("打开"), open: openItem
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(colorScheme)
        .onAppear {
            let openWindow = openWindow
            appDelegate.openSettingsWindow = { openWindow(id: "settings") }
        }
        .onOpenURL(perform: open)
        .alert(itemOpenError ?? "", isPresented: Binding(
            get: { itemOpenError != nil },
            set: { if !$0 { itemOpenError = nil } }
        )) {
            Button(preferences.resolvedLanguage.text("好"), role: .cancel) {}
        }
    }

    private var colorScheme: ColorScheme? {
        switch preferences.resolvedAppearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func open(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "rightmouse", components.host == "hidden-files",
              let path = components.queryItems?.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"), !path.utf8.contains(0) else { return }

        let directory = URL(fileURLWithPath: path, isDirectory: true)
        preferences = (try? Preferences.load()) ?? Preferences()
        self.directory = directory
        do {
            items = try hiddenItems(in: directory)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private func hiddenItems(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isHiddenKey])
            .filter { url in
                url.lastPathComponent.hasPrefix(".") ||
                    (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) == true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func openItem(_ item: URL) {
        if !NSWorkspace.shared.open(item) {
            itemOpenError = preferences.resolvedLanguage.text("无法打开「%@」", item.lastPathComponent)
        }
    }
}

private struct HiddenItemsView: View {
    let directory: URL
    let items: [URL]
    let emptyMessage: String
    let openTitle: String
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(directory.path)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(directory.path)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items, id: \.self) { item in
                    Text(item.lastPathComponent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { open(item) }
                        .contextMenu {
                            Button(openTitle) { open(item) }
                        }
                }
                .listStyle(.inset)
            }
        }
    }
}
