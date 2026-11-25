import AppKit

enum RunningAccounts {
    static let bundleIdentifier = "com.openai.codex"

    static func current() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
    }

    @MainActor
    static func quit(_ instances: [NSRunningApplication]) async -> Int {
        for app in instances where !app.isTerminated {
            app.terminate()
        }
        // Quitting is asynchronous and an app can ask the user to confirm.
        for _ in 0..<32 {
            if instances.allSatisfy(\.isTerminated) { return 0 }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return instances.filter { !$0.isTerminated }.count
    }
}
