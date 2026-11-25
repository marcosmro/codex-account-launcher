import Foundation

@main
struct AccountsTests {
    static func main() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let store = Accounts(home: home)
        let initial = try store.list()
        precondition(initial == [.main, .second])
        let main = store.profile(for: .main)
        precondition(main.codex.path == home.path + "/.codex")
        precondition(main.data.path == home.path + "/Library/Application Support/Codex")
        let second = store.profile(for: .second)
        precondition(second.codex.path == home.path + "/.codex-second")
        precondition(second.data.path == home.path + "/Library/Application Support/ChatGPT-Second")
        try second.prepare()
        let lock = second.data.appendingPathComponent("SingletonLock")
        try FileManager.default.createSymbolicLink(atPath: lock.path, withDestinationPath: ProcessInfo.processInfo.hostName.uppercased() + "-12345")
        precondition(second.ownerPID == 12345 && main.ownerPID == nil)
        precondition(Account.main.labelKey != Account.named("main").labelKey)
        let account = try store.create("Work Profile")
        let named = store.profile(for: account)
        try named.prepare()
        let folder = home.appendingPathComponent("Library/Application Support/ChatGPT Account Launcher/Profiles/Work Profile")
        for path in ["Codex", "AppData"] {
            precondition(FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path))
        }
        for invalid in ["", "../escape", " work", "work ", "Second account", "MAIN ACCOUNT", "work profile", String(repeating: "a", count: 41)] {
            do { _ = try store.create(invalid); fatalError("Accepted invalid or duplicate name") }
            catch is AccountError { }
        }
        let saved = try Accounts(home: home).list()
        precondition(saved == [.main, .second, .named("Work Profile")])
        print("Passed account discovery, validation, storage and launch argument checks.")
    }
}
