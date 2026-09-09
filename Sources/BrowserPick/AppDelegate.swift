import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = BrowserStore()
    private var settingsWindowController: SettingsWindowController?
    private var chooserWindowController: ChooserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerForURLEvents()
        claimDefaultBrowserIfNeeded()
    }

    /// On every launch, if we are not the default http(s) handler, trigger the
    /// system prompt to make us default. macOS shows its own confirmation
    /// dialog — there's no API to bypass it. If already default, this is a no-op.
    private func claimDefaultBrowserIfNeeded() {
        guard !DefaultBrowserManager.isDefault else { return }
        // Slight delay so the menubar icon paints first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
            DefaultBrowserManager.setAsDefault { _ in }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.triangle.branch",
                accessibilityDescription: "BrowserPick"
            )
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            openSettings()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.showsStateColumn = false
        addPlainItem(to: menu, title: "Settings…", action: #selector(openSettings))
        addPlainItem(to: menu, title: "About BrowserPick", action: #selector(showAbout))
        addPlainItem(to: menu, title: "Quit", action: #selector(quit))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach the menu so left-click goes back to the action
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// macOS 26 auto-adds SF Symbols to menu items whose title matches common
    /// system phrases (e.g. "Settings…" gets a gear). Setting a 1×1 blank image
    /// overrides the auto-decoration; `.image = nil` is ignored.
    private func addPlainItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(size: NSSize(width: 1, height: 1))
        menu.addItem(item)
    }

    @objc private func showAbout() {
        let center = NSMutableParagraphStyle()
        center.alignment = .center

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: center,
        ]

        let credits = NSMutableAttributedString(
            string: "Pick which browser opens a link.\n\nBy Vladan Čolović\n",
            attributes: baseAttrs
        )

        let urlString = "github.com/cvladan/browser-pick"
        var linkAttrs = baseAttrs
        linkAttrs[.link] = URL(string: "https://\(urlString)")!
        credits.append(NSAttributedString(string: urlString, attributes: linkAttrs))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: - URL events

    private func registerForURLEvents() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let request = WebURLRequest(validating: urlString) else {
            return
        }
        presentChooser(for: request)
    }

    private func presentChooser(for request: WebURLRequest) {
        if chooserWindowController == nil {
            chooserWindowController = ChooserWindowController(store: store) { [weak self] browser, request in
                self?.open(request: request, in: browser)
            }
        }
        chooserWindowController?.show(for: request)
    }

    func open(request: WebURLRequest, in browser: Browser) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [request.url],
            withApplicationAt: browser.bundleURL,
            configuration: config,
            completionHandler: nil
        )
        chooserWindowController?.hide()
    }
}
