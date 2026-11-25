# Multi AI Launcher

A native macOS account picker for the ChatGPT desktop app with Codex. Open your default account, switch to a separate secondary profile, or create named profiles for work and personal use.

## Install

1. Open `dist/Multi-AI-Launcher-1.0.4.pkg` and follow the macOS Installer prompts. If you have the source checkout, run `./build.sh` first.
2. Open **ChatGPT Account Launcher** from Applications.
3. To keep the picker handy, Control-click its Dock icon and select **Options → Keep in Dock**. Click that icon whenever you want to choose an instance.
4. Select a profile and choose **Open account**, or choose **Add account** to create one. Sign in once in each new profile.

Use the arrow keys to select an account and press Return to open it, or double-click its row. Running profiles show a **Running** indicator and a **Show account** action. The next time you start the launcher, it selects the last account you opened successfully. Press Command-N to add a profile.

Use the pencil beside any account to change its display name. The label is saved locally and the profile keeps its original storage location.

To close all running instances, click **Quit all accounts…** in the picker and confirm. Each instance receives a normal macOS quit request. You can reopen any profile from the Dock.

The launcher requires macOS 13 or later and includes Apple silicon and Intel executables. The target desktop app must also support your Mac. The launcher finds the installed app with bundle identifier `com.openai.codex`, or asks you to locate it.

## Account storage

| Account | Codex home | App data |
| --- | --- | --- |
| Main account | Desktop app default | Desktop app default |
| Second account | `~/.codex-second` | `~/Library/Application Support/ChatGPT-Second` |
| Named account | `<profile>/Codex` | `<profile>/AppData` |

Named profiles live in `~/Library/Application Support/ChatGPT Account Launcher/Profiles/<name>`. The launcher discovers profiles created with the original AppleScript version. New names accept 1–40 ASCII letters, digits, spaces, underscores and hyphens. Names must be unique and cannot start or end with a space.

The launcher focuses the ChatGPT process holding the selected profile’s local Electron instance lock. When that profile is closed, the launcher starts it with explicit Codex and app-data folders. The picker hides after sending the request and returns when you click its Dock icon. Secondary profiles use the desktop app’s internal environment settings and user-data argument. Desktop app updates may change this behavior. Each profile runs with your macOS user’s file access.

To uninstall, move **ChatGPT Account Launcher** from Applications to the Trash. Profile data remains in the locations above.

## Build and verify

Install Apple’s Xcode Command Line Tools on macOS, then run:

```sh
./build.sh
xcrun swiftc -module-cache-path .build/module-cache src/Accounts.swift tests/AccountsTests.swift -o .build/accounts-tests
.build/accounts-tests
```

The build creates a universal app and an Installer package in `dist/`. The package installs only the app in `/Applications`. The default local build uses an ad hoc app signature and an unsigned installer.

## Public release

Use Developer ID Application and Developer ID Installer certificates and a saved notarytool keychain profile:

```sh
APP_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
INSTALLER_SIGN_IDENTITY='Developer ID Installer: YOUR NAME (TEAMID)' \
NOTARY_PROFILE='your-notary-profile' ./build.sh
```

The release build signs the app and package, submits the package to Apple, staples the notarization ticket and checks Gatekeeper acceptance. Distribute the resulting `.pkg`. Before publishing a new version, update the version and build number in `build.sh` and test installing, creating a profile and reopening it on a clean Mac with a supported desktop app.
