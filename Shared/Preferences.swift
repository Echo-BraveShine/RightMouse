import Foundation

enum InterfaceLanguage: String, Codable {
    case chinese = "zh-Hans"
    case english = "en"

    static var systemDefault: Self {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
    }

    private static let englishBundle = Bundle.main.url(forResource: "en", withExtension: "lproj")
        .flatMap(Bundle.init(url:))

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        text(key, arguments: arguments)
    }

    func text(_ key: String, arguments: [CVarArg]) -> String {
        let translation = self == .english
            ? Self.englishBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
            : key
        return arguments.isEmpty ? translation : String(format: translation, arguments: arguments)
    }
}

enum InterfaceAppearance: String, CaseIterable, Codable {
    case system, light, dark
}

enum Command: String, CaseIterable, Codable, Identifiable {
    case create = "新建文件"
    case move = "移动到"
    case copy = "复制到"
    case favorites = "常用目录"
    case path = "复制路径"
    case terminal = "在终端中打开"
    case hiddenItems = "查看隐藏文件"

    var id: String { rawValue }
}

struct Folder: Codable, Identifiable {
    var id = UUID()
    var name: String
    var url: URL
}

struct FileTemplate: Codable, Identifiable {
    var id = UUID()
    var name: String
    var fileExtension: String
    var data: Data

    func displayName(in language: InterfaceLanguage) -> String {
        if name == "纯文本", fileExtension == "txt", data.isEmpty {
            return language.text(name)
        }
        return name
    }

    func createFile(in directory: URL, language: InterfaceLanguage) throws -> URL {
        let baseName = language.text("未命名")
        for index in 1...1000 {
            let name = index == 1 ? baseName : "\(baseName) \(index)"
            let file = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
            do {
                try data.write(to: file, options: .withoutOverwriting)
                return file
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}

struct Preferences: Codable {
    var language: InterfaceLanguage?
    var appearance: InterfaceAppearance?

    var resolvedLanguage: InterfaceLanguage { language ?? .systemDefault }
    var resolvedAppearance: InterfaceAppearance { appearance ?? .system }


    var commands = Command.allCases
    var hidden: Set<Command> = []
    var folders: [Folder] = []
    var templates = [
        FileTemplate(name: "纯文本", fileExtension: "txt", data: Data()),
        FileTemplate(name: "Markdown", fileExtension: "md", data: Data())
    ]

    private enum CodingKeys: String, CodingKey {
        case language, appearance, commands, hidden, folders, templates
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        language = try values.decodeIfPresent(InterfaceLanguage.self, forKey: .language)
        appearance = try values.decodeIfPresent(InterfaceAppearance.self, forKey: .appearance)
        // Older settings may contain commands that have since been removed.
        commands = try values.decode([String].self, forKey: .commands).compactMap(Command.init(rawValue:))
        hidden = Set(try values.decode([String].self, forKey: .hidden).compactMap(Command.init(rawValue:)))
        folders = try values.decode([Folder].self, forKey: .folders)
        templates = try values.decode([FileTemplate].self, forKey: .templates)
    }

    static let homeDirectory = URL(
        fileURLWithPath: getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) }
            ?? NSHomeDirectory(),
        isDirectory: true
    )

    private static let location = homeDirectory
        .appendingPathComponent("Library/Application Support/RightMouse/preferences.plist")

    static func load() throws -> Self {
        do {
            var preferences = try PropertyListDecoder().decode(Self.self, from: Data(contentsOf: location))
            let savedCommands = Set(preferences.commands)
            preferences.commands.append(contentsOf: Command.allCases.filter { !savedCommands.contains($0) })
            return preferences
        } catch CocoaError.fileReadNoSuchFile {
            return Self()
        }
    }

    func save() throws {
        try FileManager.default.createDirectory(
            at: Self.location.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try PropertyListEncoder().encode(self).write(to: Self.location, options: .atomic)
    }
}
