import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class ReleaseUpdates: ObservableObject {
    static let supportURL = URL(string: "https://buymeacoffee.com/1239383708p")!

    static let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "0.0.0"

    static let appIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }()

    private static func registerApplicationIcon() {
        let icon = appIcon
        NSApp.applicationIconImage = icon

        // Sparkle looks up the named AppKit image before falling back to the bundle icon.
        let name = NSImage.applicationIconName
        if let cached = NSImage(named: name), cached !== icon {
            cached.setName(nil)
        }
        icon.setName(name)
    }

    @Published private(set) var canCheck = false

    private let controller: SPUStandardUpdaterController

    init() {
        Self.registerApplicationIcon()
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        guard canCheck else { return }
        Self.registerApplicationIcon()
        controller.checkForUpdates(nil)
    }
}
