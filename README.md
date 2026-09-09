# BrowserPick

A tiny macOS menubar utility that intercepts links and lets you pick which browser to open them in.

**380 KB on disk · ~53 MB of memory at idle.** Native Swift, no Electron, no web views, no telemetry.

Inspired by [Velja](https://sindresorhus.com/velja) and [Choosy](https://choosy.app), but intentionally minimal.

> **Evaluation only:** the upstream repository describes the project as MIT-licensed but does not currently include a `LICENSE` file. Do not redistribute source or binaries from this fork until the copyright holder adds a license or grants explicit permission.

> **Heads up:** the first launch is blocked by macOS Gatekeeper (the build is ad-hoc signed, not Apple-notarized). You'll see *"BrowserPick.app" was blocked to protect your Mac.* One click in **System Settings → Privacy & Security → Open Anyway** unblocks it. Full steps in [First launch: unblock Gatekeeper](#first-launch-unblock-gatekeeper).

## Features

Minimum viable scope:

- Menubar icon, no dock icon. Icon indicates the app is running. Clicking it opens **Settings**. Right-click (or menu) has two items: **Settings** and **Quit**.
- Registers as the system handler for `http` and `https`.
- Chooser popup on every intercepted URL, keyboard-driven (number keys / arrows + return).
- Settings window:
  - Manage browser list: add/remove any `.app` that can open URLs.
  - Per-browser custom name, icon, and keyboard shortcut.
  - Launch at Login toggle.

## Tech

- **Build system:** Swift Package Manager + shell script that assembles a `.app` bundle. No Xcode required, just Command Line Tools.
- **Min macOS:** 15 Sequoia.
- **Distribution:** disabled pending license clarification and independent signing/release infrastructure.

### Why these choices

- Swift 6 + SwiftUI hosted in AppKit: native, no runtime, smallest binary, best Gatekeeper story. AppKit for menubar gives us proper left-click vs right-click behavior that SwiftUI's `MenuBarExtra` can't.
- SPM over Xcode project: no `.xcodeproj` noise in the repo, builds from CLT, builds in CI without installing Xcode.
- Homebrew tap: zero-friction install for devs, plus `brew upgrade` works. Skips notarization pain initially; users can `xattr -dr com.apple.quarantine` if needed.

## Build & run

For development, use `install.sh`. It builds, copies the app to `~/Applications`, lets Launch Services discover it, and launches it:

```sh
./install.sh           # debug
./install.sh release   # release build
./install.sh --replace # explicitly replace the same BrowserPick bundle ID
```

The installer refuses to overwrite an existing app unless `--replace` is supplied, and even then verifies its bundle identifier first. Set `INSTALL_DIR=/Applications` explicitly if a system-wide installation is needed. Running from `.build/` works for basic UI testing, but default-browser registration and link interception are more reliable from an Applications directory.

On first launch, BrowserPick automatically asks macOS to make it the default browser. You'll see the system confirmation dialog ("Do you want to use 'BrowserPick' to open web pages?"). Click **Use 'BrowserPick'**.

The menubar icon (branch arrow) appears in the top right. Left-click → Settings. Right-click → Settings/Quit menu.

### Build only (without install)

If you just want to compile and inspect the bundle:

```sh
./build.sh           # debug
./build.sh release   # release
```

Output: `.build/BrowserPick.app`, ad-hoc signed.

## Project layout

```
Sources/BrowserPick/
├── main.swift                              entry point
├── AppDelegate.swift                       menubar + URL events
├── DefaultBrowserManager.swift             read/set system default http(s) handler
├── LaunchAtLogin.swift                     SMAppService wrapper
├── Models/
│   ├── Browser.swift                       browser model + discovery
│   └── BrowserStore.swift                  @Observable store, UserDefaults
├── Views/
│   ├── SettingsView.swift                  SwiftUI
│   └── ChooserView.swift                   SwiftUI
└── Windows/
    ├── SettingsWindowController.swift      NSWindowController + NSHostingController
    └── ChooserWindowController.swift       NSPanel floating chooser

Resources/Info.plist                        URL types, LSUIElement
build.sh                                    SPM build → .app assembly
install.sh                                  build → copy to /Applications → launch
release.sh                                  local release zip + SHA-256 only
Scripts/inspect-bundle.sh                   bundle security inspection
Tests/BrowserPickTests/                     URL, queue, browser, persistence tests
```

### First launch: unblock Gatekeeper

The `.app` is ad-hoc signed, not Apple-notarized. If you transfer a local evaluation build between machines, macOS may quarantine it and refuse to launch it the first time:

1. Try to open `BrowserPick.app`.
2. macOS shows: **"BrowserPick.app" was blocked to protect your Mac.** → click **Done**.
3. Open **System Settings → Privacy & Security**.
4. Scroll down to the security message: *"BrowserPick.app" was blocked to protect your Mac.* → click **Open Anyway**.
5. Confirm in the dialog (Touch ID or password).
6. The app launches and asks to be made the default browser. Click **Use 'BrowserPick'**.

After this, BrowserPick launches normally for that local install path unless the binary identity changes.

CLI shortcut for the same thing (skips the Settings dance):

```sh
xattr -dr com.apple.quarantine ~/Applications/BrowserPick.app
```

If you didn't get the default-browser prompt automatically, set it manually in **System Settings → Desktop & Dock → Default web browser**.

## Local packaging

`release.sh` only builds a local release archive and prints its SHA-256 checksum. It never commits, tags, pushes, creates a GitHub Release, or modifies a Homebrew tap:

```sh
./release.sh         # use and validate the version in Info.plist
./release.sh 0.0.5   # additionally assert the expected X.Y.Z version
```

The archive is written to `.build/BrowserPick-X.Y.Z.zip`. Publishing remains disabled until licensing, signing, notarization, and fork-owned release infrastructure are resolved.

## Verification

```sh
swift test -Xswiftc -warnings-as-errors
./build.sh release
./Scripts/inspect-bundle.sh
```

GitHub Actions also runs these tests plus ShellCheck, Gitleaks, OSV Scanner, CodeQL, and bundle inspection.

## FAQ

**Why do I see a second process called "AutoFill (BrowserPick)" in Activity Monitor?**

That's `com.apple.AutoFillPanel`, a macOS XPC service for password/credit-card autofill UI. macOS automatically attaches it to any app registered as a browser (i.e. any app with `http`/`https` in `CFBundleURLTypes`), so you'll see the same helper next to Safari, Chrome, Arc, Velja, etc. BrowserPick does not start it and never invokes it (we have no web views or form input). It's a system-managed helper and costs ~12 MB. There's no way to opt out without giving up the http handler registration that makes the whole app work.

## Status

Alpha, evaluation only, and not published. Core features work: menubar icon, URL interception, browser chooser with keyboard shortcuts, settings window, browser discovery, and launch at login.

## License

Unresolved. The upstream README says “MIT,” but there is no `LICENSE` file. Do not redistribute this fork until the copyright holder adds the license or grants explicit permission.
