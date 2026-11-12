import AppKit
import Darwin
import FinderSync
import OSLog

final class FinderMenu: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private var menuTemplateIDs: [UUID] = []
    private var language = InterfaceLanguage.systemDefault
    private let files = FileManager.default
    private let logger = Logger(subsystem: "dev.ekko.rightmouse.finder", category: "NewFile")
    private let transferQueue = DispatchQueue(label: "dev.ekko.rightmouse.transfer")

    override init() {
        super.init()
        refreshMenuLocations()
        let notifications = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            notifications.addObserver(self, selector: #selector(volumeChanged(_:)), name: name, object: nil)
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func volumeChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.refreshMenuLocations() }
    }

    private func refreshMenuLocations() {
        let volumes = files.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        controller.directoryURLs = Set(volumes + [
            URL(fileURLWithPath: "/", isDirectory: true),
            Preferences.homeDirectory
        ])
    }

    override func menu(for kind: FIMenuKind) -> NSMenu? {
        guard kind == .contextualMenuForContainer || kind == .contextualMenuForItems else {
            return nil
        }

        let menu = NSMenu()
        let preferences: Preferences
        do {
            preferences = try Preferences.load()
            language = preferences.resolvedLanguage
        } catch {
            menu.addItem(item(tr("读取 RightMouse 设置失败")) {
                self.show(self.tr("读取设置失败"), error.localizedDescription)
            })
            return menu
        }

        let selection = kind == .contextualMenuForItems ? controller.selectedItemURLs() ?? [] : []
        for command in preferences.commands where !preferences.hidden.contains(command) {
            switch command {
            case .create:
                guard kind == .contextualMenuForContainer, controller.targetedURL() != nil else { continue }
                let templates = preferences.templates
                menuTemplateIDs = templates.map(\.id)
                let entries = templates.enumerated().map { index, template in
                    let title = "\(template.fileExtension.lowercased())(\(template.displayName(in: language)))"
                    let entry = NSMenuItem(title: title, action: #selector(createFromMenu(_:)), keyEquivalent: "")
                    entry.target = self
                    entry.tag = index
                    return entry
                }
                addSubmenu(command, to: menu, items: entries)
            case .favorites:
                guard selection.isEmpty else { continue }
                addSubmenu(command, to: menu, items: preferences.folders.map { folder in
                    item(folder.name) { self.open(folder) }
                })
            case .move, .copy:
                guard !selection.isEmpty else { continue }
                let direction = command == .move ? -1 : 1
                var destinations = preferences.folders.enumerated().map { index, folder in
                    transferMenuItem(folder.name, tag: direction * (index + 2))
                }
                if !destinations.isEmpty {
                    destinations.append(.separator())
                }
                destinations.append(transferMenuItem(tr("选择目录…"), tag: direction))
                addSubmenu(command, to: menu, items: destinations)
            case .hiddenItems:
                guard kind == .contextualMenuForContainer, controller.targetedURL() != nil else { continue }
                let entry = NSMenuItem(
                    title: tr(command.rawValue) + "…", action: #selector(showHiddenItems(_:)), keyEquivalent: ""
                )
                entry.target = self
                menu.addItem(entry)
            case .terminal:
                let opensSelection = kind == .contextualMenuForItems
                guard opensSelection ? selection.count == 1 : controller.targetedURL() != nil else { continue }
                let entry = NSMenuItem(
                    title: tr(command.rawValue), action: #selector(openInTerminal(_:)), keyEquivalent: ""
                )
                entry.target = self
                entry.tag = opensSelection ? 1 : 0
                menu.addItem(entry)
            case .path:
                let copiesSelection = kind == .contextualMenuForItems
                guard copiesSelection ? !selection.isEmpty : controller.targetedURL() != nil else { continue }
                let entry = NSMenuItem(
                    title: tr(command.rawValue), action: #selector(copyPaths(_:)), keyEquivalent: ""
                )
                entry.target = self
                entry.tag = copiesSelection ? 1 : 0
                menu.addItem(entry)
            }
        }
        return menu.items.isEmpty ? nil : menu
    }

    private func item(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action
        return item
    }

    private func addSubmenu(_ command: Command, to menu: NSMenu, items: [NSMenuItem]) {
        guard !items.isEmpty else { return }
        let parent = NSMenuItem(title: tr(command.rawValue), action: nil, keyEquivalent: "")
        let children = NSMenu()
        items.forEach(children.addItem)
        parent.submenu = children
        menu.addItem(parent)
    }

    @objc private func run(_ sender: NSMenuItem) {
        (sender.representedObject as? () -> Void)?()
    }

    private func open(_ folder: Folder) {
        guard isDirectory(folder.url), NSWorkspace.shared.open(folder.url) else {
            show(tr("无法打开「%@」", folder.name), tr("请在 RightMouse 设置中重新选择目录。"))
            return
        }
    }

    @objc private func createFromMenu(_ sender: NSMenuItem) {
        logger.notice("New file action received")
        guard let directory = controller.targetedURL() else {
            show(tr("无法新建文件"), tr("访达未提供目标文件夹。请打开本地文件夹后在空白处重试。"))
            return
        }

        do {
            let templates = try Preferences.load().templates
            guard menuTemplateIDs.indices.contains(sender.tag),
                  let template = templates.first(where: { $0.id == menuTemplateIDs[sender.tag] }) else {
                show(tr("无法新建文件"), tr("文件模板已更改，请重新打开右键菜单。"))
                return
            }

            do {
                _ = try template.createFile(in: directory, language: language)
            } catch CocoaError.fileWriteNoPermission {
                guard let authorized = authorizeDirectory(directory) else { return }
                defer { authorized.stopAccessingSecurityScopedResource() }
                _ = try template.createFile(in: authorized, language: language)
            }
            logger.notice("New file created")
        } catch {
            logger.error("New file failed: \(error as NSError, privacy: .private)")
            show(tr("无法新建文件"), error.localizedDescription)
        }
    }

    @objc private func showHiddenItems(_ sender: NSMenuItem) {
        logger.notice("Hidden files action received")
        guard let directory = controller.targetedURL() else {
            show(tr("无法查看隐藏文件"), tr("访达未提供目标目录，请重新选择。"))
            return
        }

        var request = URLComponents()
        request.scheme = "rightmouse"
        request.host = "hidden-files"
        request.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        guard let url = request.url else { return }

        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // PlugIns
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // RightMouse.app
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: .init()) { _, error in
            guard let error else { return }
            self.logger.error("Could not open hidden files window: \(error as NSError, privacy: .private)")
            DispatchQueue.main.async {
                self.show(self.tr("无法查看隐藏文件"), error.localizedDescription)
            }
        }
    }

    @objc private func copyPaths(_ sender: NSMenuItem) {
        let urls: [URL]
        if sender.tag == 1 {
            urls = controller.selectedItemURLs() ?? []
        } else if let directory = controller.targetedURL() {
            urls = [directory]
        } else {
            return
        }

        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }

    @objc private func openInTerminal(_ sender: NSMenuItem) {
        let directory: URL?
        if sender.tag == 1 {
            let items = controller.selectedItemURLs() ?? []
            directory = items.count == 1 ? items.first.map { item in
                item.hasDirectoryPath ? item : item.deletingLastPathComponent()
            } : nil
        } else {
            directory = controller.targetedURL()
        }

        guard let directory else {
            show(tr("无法打开终端"), tr("访达未提供目标目录，请重新选择。"))
            return
        }

        // Opening a directory descriptor lets macOS request access without reading its entries.
        DispatchQueue.global(qos: .userInitiated).async {
            let descriptor = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
            let accessError = descriptor < 0 ? errno : 0
            if descriptor >= 0 { Darwin.close(descriptor) }

            DispatchQueue.main.async {
                switch accessError {
                case 0:
                    self.launchTerminal(in: directory)
                case EACCES, EPERM:
                    self.chooseTerminalDirectory(startingAt: directory)
                default:
                    self.show(self.tr("无法打开终端"),
                              NSError(domain: NSPOSIXErrorDomain, code: Int(accessError)).localizedDescription)
                }
            }
        }
    }

    private func chooseTerminalDirectory(startingAt directory: URL) {
        let panel = NSOpenPanel()
        panel.title = tr("选择终端目录")
        panel.message = tr("请选择要在终端中打开的文件夹，以授予本次操作的访问权限。")
        panel.prompt = tr("授权并打开")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        launchTerminal(in: chosen)
    }

    private func launchTerminal(in directory: URL) {
        let workspace = NSWorkspace.shared
        guard let terminal = workspace.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            show(tr("无法打开终端"), tr("系统找不到「终端」应用。"))
            return
        }

        let accessing = directory.startAccessingSecurityScopedResource()
        workspace.open([directory], withApplicationAt: terminal, configuration: .init()) { _, error in
            if accessing { directory.stopAccessingSecurityScopedResource() }
            guard let error else { return }
            DispatchQueue.main.async {
                self.show(self.tr("无法打开终端"), error.localizedDescription)
            }
        }
    }

    private func transferMenuItem(_ title: String, tag: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(transferFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.tag = tag
        return item
    }

    @objc private func transferFromMenu(_ sender: NSMenuItem) {
        guard let selection = controller.selectedItemURLs(), !selection.isEmpty else {
            show(tr("找不到所选文件"), tr("请在访达重新选中文件后重试。"))
            return
        }

        let move = sender.tag < 0
        let destinationIndex = abs(sender.tag) - 2
        if destinationIndex == -1 {
            DispatchQueue.main.async {
                self.chooseDestination(for: selection, move: move)
            }
            return
        }

        do {
            let folders = try Preferences.load().folders
            guard folders.indices.contains(destinationIndex),
                  folders[destinationIndex].name == sender.title else {
                show(tr("常用目录已更改"), tr("请重新打开右键菜单后重试。"))
                return
            }
            transfer(selection, to: folders[destinationIndex], move: move)
        } catch {
            show(tr("无法读取常用目录"), error.localizedDescription)
        }
    }

    private func chooseDestination(for selection: [URL], move: Bool) {
        let panel = NSOpenPanel()
        panel.title = move ? tr("选择移动目标") : tr("选择复制目标")
        panel.prompt = move ? tr("移动到这里") : tr("复制到这里")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = selection.first?.deletingLastPathComponent()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        transfer(selection, to: Folder(name: url.lastPathComponent, url: url), move: move)
    }

    private func authorizeDirectory(_ directory: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = tr("授权访问文件夹")
        panel.message = tr("请选择当前操作的文件夹以继续。")
        panel.prompt = tr("授权")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let authorized = panel.url else { return nil }
        guard authorized.standardizedFileURL.path == directory.standardizedFileURL.path else {
            authorized.stopAccessingSecurityScopedResource()
            show(tr("无法访问「%@」", directory.lastPathComponent), tr("请选择当前操作的文件夹以继续。"))
            return nil
        }
        return authorized
    }

    private func transfer(_ selection: [URL], to folder: Folder, move: Bool) {
        var grants: [URL] = []
        let destinationScope = folder.url.startAccessingSecurityScopedResource()
        if destinationScope { grants.append(folder.url) }
        var destinationURL = folder.url
        let directories = Set(selection.map { $0.deletingLastPathComponent().standardizedFileURL })
        for directory in directories.sorted(by: { $0.path < $1.path }) {
            let mode = move ? R_OK | W_OK | X_OK : R_OK | X_OK
            if Darwin.access(directory.path, mode) != 0 {
                guard let authorized = authorizeDirectory(directory) else {
                    grants.forEach { $0.stopAccessingSecurityScopedResource() }
                    return
                }
                grants.append(authorized)
            }
        }
        if Darwin.access(destinationURL.path, W_OK | X_OK) != 0 {
            guard let authorized = authorizeDirectory(destinationURL) else {
                grants.forEach { $0.stopAccessingSecurityScopedResource() }
                return
            }
            grants.append(authorized)
            destinationURL = authorized
        }
        let scopedDirectories = grants
        let targetDirectory = destinationURL
        let destination = targetDirectory.resolvingSymlinksInPath().standardizedFileURL
        let language = self.language
        transferQueue.async {
            defer {
                scopedDirectories.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            var completed = 0
            var skipped = 0
            var failures: [String] = []
            for source in selection {
                let original = source.standardizedFileURL
                let target = targetDirectory.appendingPathComponent(source.lastPathComponent)
                let sourcePath = source.resolvingSymlinksInPath().standardizedFileURL.path
                if self.isDirectory(source), destination.path == sourcePath ||
                    destination.path.hasPrefix(sourcePath + "/") {
                    failures.append(language.text("%@：目标位于源文件夹内", source.lastPathComponent))
                    continue
                }
                if move, original.deletingLastPathComponent().resolvingSymlinksInPath().path == destination.path {
                    skipped += 1
                    continue
                }

                do {
                    try self.transferItem(original, to: target, move: move)
                    completed += 1
                } catch CocoaError.fileWriteFileExists {
                    let keep = DispatchQueue.main.sync { self.keepBoth(source.lastPathComponent, language: language) }
                    guard keep else {
                        skipped += 1
                        continue
                    }
                    do {
                        try self.transferKeepingBoth(original, to: target, move: move)
                        completed += 1
                    } catch {
                        failures.append("\(source.lastPathComponent)：\(error.localizedDescription)")
                    }
                } catch {
                    failures.append("\(source.lastPathComponent)：\(error.localizedDescription)")
                }
            }

            let summary = language.text("成功 %ld 项，跳过 %ld 项，失败 %ld 项。", completed, skipped, failures.count)
            let details = ([summary] + failures).joined(separator: "\n")
            DispatchQueue.main.async { self.show(language.text(move ? "移动结果" : "复制结果"), details) }
        }
    }

    private func transferItem(_ source: URL, to target: URL, move: Bool) throws {
        if move {
            try files.moveItem(at: source, to: target)
        } else {
            try files.copyItem(at: source, to: target)
        }
    }

    private func transferKeepingBoth(_ source: URL, to target: URL, move: Bool) throws {
        let directory = target.deletingLastPathComponent()
        let base = target.deletingPathExtension().lastPathComponent
        let suffix = target.pathExtension.isEmpty ? "" : "." + target.pathExtension
        for index in 2...1000 {
            let candidate = directory.appendingPathComponent("\(base) \(index)\(suffix)")
            do {
                try transferItem(source, to: candidate, move: move)
                return
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }

    private func keepBoth(_ filename: String, language: InterfaceLanguage) -> Bool {
        let alert = NSAlert()
        alert.messageText = language.text("已存在「%@」", filename)
        alert.informativeText = language.text("保留两份会给新文件自动编号。")
        alert.addButton(withTitle: language.text("保留两份"))
        alert.addButton(withTitle: language.text("跳过"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return files.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }

    private func tr(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    private func show(_ title: String, _ details: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        alert.addButton(withTitle: tr("好"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
