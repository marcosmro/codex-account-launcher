import Foundation

enum Account: Hashable {
    case main, second, named(String)

    var labelKey: String {
        switch self {
        case .main: return "main"
        case .second: return "second"
        case .named(let name): return "named:" + name
        }
    }

    var title: String {
        switch self {
        case .main: return "Main account"
        case .second: return "Second account"
        case .named(let name): return name
        }
    }
}

enum AccountError: LocalizedError {
    case invalidName, duplicate, wrongApp
    var errorDescription: String? {
        switch self {
        case .invalidName: return "Use 1–40 letters, numbers, spaces, hyphens or underscores, with no spaces at either end."
        case .duplicate: return "An account with that name already exists. Choose another name."
        case .wrongApp: return "Choose the installed ChatGPT desktop app with Codex."
        }
    }
}

struct Accounts {
    let home: URL
    private let files = FileManager.default
    private var support: URL { home.appendingPathComponent("Library/Application Support") }
    private var root: URL { support.appendingPathComponent("ChatGPT Account Launcher/Profiles") }

    func list() throws -> [Account] {
        let entries: [URL]
        do {
            entries = try files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: .skipsHiddenFiles)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            entries = []
        }
        let names = try entries.filter {
            let info = try $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return info.isDirectory == true && info.isSymbolicLink != true
        }.map(\.lastPathComponent).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return [.main, .second] + names.map(Account.named)
    }

    func create(_ name: String) throws -> Account {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_")
        guard (1...40).contains(name.count), name.unicodeScalars.allSatisfy(allowed.contains),
              name.first != " ", name.last != " " else { throw AccountError.invalidName }
        try files.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard try !list().contains(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) else { throw AccountError.duplicate }
        try files.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return .named(name)
    }

    func profile(for account: Account) -> Profile {
        switch account {
        case .main:
            return Profile(codex: home.appendingPathComponent(".codex"), data: support.appendingPathComponent("Codex"))
        case .second:
            return Profile(codex: home.appendingPathComponent(".codex-second"), data: support.appendingPathComponent("ChatGPT-Second"))
        case .named(let name):
            let folder = root.appendingPathComponent(name)
            return Profile(codex: folder.appendingPathComponent("Codex"), data: folder.appendingPathComponent("AppData"))
        }
    }
}

struct Profile {
    let codex: URL
    let data: URL

    func prepare() throws {
        for folder in [codex, data] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }

    var ownerPID: Int32? {
        guard let lock = try? FileManager.default.destinationOfSymbolicLink(atPath: data.appendingPathComponent("SingletonLock").path),
              let separator = lock.lastIndex(of: "-"),
              lock[..<separator].lowercased().split(separator: ".").first == ProcessInfo.processInfo.hostName.lowercased().split(separator: ".").first,
              let pid = Int32(lock[lock.index(after: separator)...]), pid > 0 else { return nil }
        return pid
    }
}
