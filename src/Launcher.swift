import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let ink = Color(red: 0.105, green: 0.12, blue: 0.11)
private let lime = Color(red: 0.80, green: 0.94, blue: 0.56)
private let paper = Color(red: 0.96, green: 0.955, blue: 0.93)

@main
struct Launcher: App {
    var body: some Scene {
        Window("Account Launcher", id: "accounts") {
            PickerView().frame(width: 520, height: 530)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

private struct PickerView: View {
    let store = Accounts(home: FileManager.default.homeDirectoryForCurrentUser)
    @State private var accounts: [Account] = [.main, .second]
    @State private var selection: Account = .main
    @State private var labels = UserDefaults.standard.dictionary(forKey: "AccountLabels") as? [String: String] ?? [:]
    @AppStorage("LastOpenedAccount") private var lastOpened = ""
    @State private var running: Set<Account> = []
    @State private var instanceCount = 0
    @FocusState private var listFocused: Bool
    @FocusState private var nameFocused: Bool
    @State private var renaming = false
    @State private var renameTarget: Account = .main
    @State private var adding = false
    @State private var name = ""
    @State private var validation = ""
    @State private var error: String?
    @State private var opening = false
    @State private var quitting = false
    @State private var quitTargets: [NSRunningApplication] = []
    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CHATGPT  /  CODEX").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(lime)
                    Text("Account Launcher").font(.system(size: 36, weight: .semibold)).tracking(-1.6)
                }
                Spacer()
                ZStack {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 6).fill(i == 2 ? lime : ink)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(lime, lineWidth: 1.5))
                            .frame(width: 35, height: 41).rotationEffect(.degrees(-12))
                            .offset(x: CGFloat(i - 1) * 8, y: CGFloat(1 - i) * 5)
                    }
                }.frame(width: 56, height: 56).accessibilityHidden(true)
            }
            .foregroundStyle(.white).padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 24)
            .background(ink)
            HStack {
                Text("Your accounts").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { name = ""; validation = ""; adding = true } label: { Label("Add account", systemImage: "plus") }
                    .controlSize(.small).keyboardShortcut("n", modifiers: .command)
            }.padding(.horizontal, 28).padding(.top, 23).padding(.bottom, 12)
            ScrollViewReader { proxy in
                List(selection: Binding<Account?>(
                    get: { selection },
                    set: { if let account = $0 { selection = account } }
                )) {
                    ForEach(accounts, id: \.self) { account in
                        HStack(spacing: 8) {
                            row(account)
                                .onTapGesture(count: 2) {
                                    selection = account
                                    open(account)
                                }
                            Button {
                                renameTarget = account
                                name = title(account)
                                validation = ""
                                renaming = true
                            } label: { Image(systemName: "pencil").frame(width: 26, height: 34) }
                            .buttonStyle(.borderless)
                            .help("Rename " + title(account))
                            .accessibilityLabel("Rename " + title(account))
                        }
                        .tag(account).id(account)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .focused($listFocused)
                .onChange(of: selection) { item in proxy.scrollTo(item) }
            }
            Spacer(minLength: 12)
            Divider()
            HStack {
                Button(quitting ? "Quitting…" : "Quit all accounts…", action: prepareQuit)
                    .buttonStyle(.link).disabled(instanceCount == 0)
                Spacer(minLength: 12)
                Button { open(selection) } label: {
                    HStack { Text(opening ? "Opening…" : running.contains(selection) ? "Show account" : "Open account"); Image(systemName: "arrow.up.right") }
                        .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 16).frame(height: 36)
                        .foregroundStyle(lime).background(ink, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 28).padding(.vertical, 16)
        }.foregroundStyle(ink).background(paper).preferredColorScheme(.light)
        .disabled(opening || quitting)
        .onAppear {
            reload()
            selection = accounts.first { $0.labelKey == lastOpened } ?? .main
            listFocused = true
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if NSApp.isActive { refreshRunning() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in reload() }
        .sheet(isPresented: $adding) { accountSheet }
        .sheet(isPresented: $renaming) { accountSheet }
        .alert("Quit all accounts?", isPresented: $confirmingQuit) {
            Button("Cancel", role: .cancel) { quitTargets = [] }
            Button("Quit all accounts", role: .destructive) {
                let targets = quitTargets
                quitTargets = []
                quitting = true
                Task { @MainActor in
                    let remaining = await RunningAccounts.quit(targets)
                    refreshRunning()
                    quitting = false
                    if remaining > 0 {
                        error = "Still running: \(remaining). Check ChatGPT for a quit prompt, then try again if needed."
                    }
                }
            }
        } message: {
            Text("This asks all running ChatGPT instances to quit, including any opened outside this launcher. Active work may be interrupted.")
        }
        .alert("Account Launcher", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func row(_ account: Account) -> some View {
        let selected = account == selection
        return HStack(spacing: 14) {
                Image(systemName: account == .main ? "person.crop.square" : account == .second ? "square.stack" : "folder")
                    .font(.system(size: 19)).frame(width: 39, height: 39)
                    .background(selected ? lime : paper, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title(account)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(account == .main ? "Default ChatGPT profile" : account == .second ? "Secondary ChatGPT profile" : "Named profile")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if running.contains(account) {
                    Text("Running").font(.caption.weight(.medium))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(lime.opacity(0.45), in: Capsule())
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? ink : Color.gray).accessibilityHidden(true)
            }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ink : ink.opacity(0.15), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
            .foregroundStyle(ink)
            .help(title(account))
    }

    private var accountSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(renaming ? "Rename account" : "Add an account").font(.title2.bold())
            Text(renaming ? "Choose the name shown in this picker." : "Use 1–40 English letters, digits, spaces, hyphens or underscores. You’ll sign in the first time you open this profile.")
            TextField("Account name", text: $name).textFieldStyle(.roundedBorder)
                .focused($nameFocused).onAppear { nameFocused = true }
                .onChange(of: name) { _ in validation = "" }
            if !validation.isEmpty { Text(validation).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("Cancel") { adding = false; renaming = false }.keyboardShortcut(.cancelAction)
                Button(renaming ? "Save name" : "Create & Open") {
                    let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty, label.count <= 40 else {
                        validation = "Choose a name with 1–40 characters."
                        return
                    }
                    guard !accounts.contains(where: { (!renaming || $0 != renameTarget) && title($0).localizedCaseInsensitiveCompare(label) == .orderedSame }) else {
                        validation = "An account already uses that name."
                        return
                    }
                    if renaming {
                        labels[renameTarget.labelKey] = label
                        UserDefaults.standard.set(labels, forKey: "AccountLabels")
                        renaming = false
                        return
                    }
                    do {
                        let account = try store.create(name)
                        accounts = try store.list()
                        selection = account
                        adding = false
                        DispatchQueue.main.async { open(account) }
                    } catch { validation = error.localizedDescription }
                }.keyboardShortcut(.defaultAction).disabled(name.isEmpty)
            }
        }.padding(24).frame(width: 380)
    }

    private func title(_ account: Account) -> String { labels[account.labelKey] ?? account.title }

    private func reload() {
        do {
            accounts = try store.list()
            refreshRunning()
            if !accounts.contains(selection) { selection = .main }
        } catch { self.error = error.localizedDescription }
    }

    private func targetApp() throws -> URL? {
        let key = "TargetApplicationPath"
        func supported(_ url: URL) -> Bool {
            Bundle(url: url)?.bundleIdentifier == RunningAccounts.bundleIdentifier
        }
        let candidates: [String?] = [UserDefaults.standard.string(forKey: key), "/Applications/ChatGPT.app",
                          NSWorkspace.shared.urlForApplication(withBundleIdentifier: RunningAccounts.bundleIdentifier)?.path]
        if let found = candidates.compactMap({ $0 }).map({ URL(fileURLWithPath: $0) }).first(where: supported) { return found }
        let panel = NSOpenPanel()
        panel.message = "Locate the ChatGPT desktop app with Codex."
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard supported(url) else { throw AccountError.wrongApp }
        UserDefaults.standard.set(url.path, forKey: key)
        return url
    }

    private func refreshRunning() {
        let instances = RunningAccounts.current()
        let pids = Set(instances.map(\.processIdentifier))
        instanceCount = instances.count
        running = Set(accounts.filter { account in
            store.profile(for: account).ownerPID.map(pids.contains) == true
        })
    }

    private func prepareQuit() {
        quitTargets = RunningAccounts.current()
        if quitTargets.isEmpty { error = "All ChatGPT accounts are already closed." }
        else { confirmingQuit = true }
    }

    private func open(_ account: Account) {
        guard !opening, !quitting, !confirmingQuit else { return }
        do {
            guard let app = try targetApp() else { return }
            let profile = store.profile(for: account)
            opening = true
            Task { @MainActor in
                defer { opening = false }
                do {
                    try await OpenProfile.open(profile, appURL: app)
                    lastOpened = account.labelKey
                    NSApp.hide(nil)
                } catch { self.error = error.localizedDescription }
            }
        } catch { self.error = error.localizedDescription }
    }
}
