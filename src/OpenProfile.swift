import AppKit

enum OpenProfile {
    enum Failure: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "Couldn’t focus the selected profile. Check that its ChatGPT window has finished opening, then try again."
        }
    }

    @MainActor
    static func open(_ profile: Profile, appURL: URL) async throws {
        func owner() -> NSRunningApplication? {
            guard let pid = profile.ownerPID, let app = NSRunningApplication(processIdentifier: pid),
                  app.bundleIdentifier == RunningAccounts.bundleIdentifier, !app.isTerminated else { return nil }
            return app
        }
        if owner() == nil {
            try profile.prepare()
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.activates = false
            config.environment = ["CODEX_HOME": profile.codex.path, "CODEX_ELECTRON_USER_DATA_PATH": profile.data.path]
            config.arguments = ["--user-data-dir=" + profile.data.path]
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        }
        for _ in 0..<100 {
            if let app = owner(), app.isFinishedLaunching {
                app.unhide()
                if app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) { return }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw Failure.unavailable
    }
}
