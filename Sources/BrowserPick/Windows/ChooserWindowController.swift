import AppKit
import SwiftUI

/// Borderless panel that still accepts key events.
private final class ChooserPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ChooserWindowController: NSWindowController {
    private let store: BrowserStore
    private let siteRoutingStore: SiteRoutingStore
    private let onPick: (Browser, WebURLRequest) -> Void
    private var requests = FIFOQueue<WebURLRequest>()

    init(
        store: BrowserStore,
        siteRoutingStore: SiteRoutingStore,
        onPick: @escaping (Browser, WebURLRequest) -> Void
    ) {
        self.store = store
        self.siteRoutingStore = siteRoutingStore
        self.onPick = onPick

        let panel = ChooserPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func enqueue(_ request: WebURLRequest) {
        let shouldPresent = requests.current == nil
        requests.enqueue(request)
        if shouldPresent {
            showCurrent()
        }
    }

    private func showCurrent() {
        guard let request = requests.current else {
            window?.orderOut(nil)
            return
        }

        let suggestion = siteRoutingStore.suggestion(for: request.normalizedHost).flatMap { suggestion in
            store.browser(bundleIdentifier: suggestion.browserBundleIdentifier).map { (suggestion, $0) }
        }

        let view = ChooserView(
            store: store,
            request: request,
            suggestion: suggestion.map { (suggestion: $0.0, browser: $0.1) },
            onPick: { [weak self] browser, remember in
                guard let self, let request = self.requests.completeCurrent() else { return }
                if remember {
                    self.siteRoutingStore.remember(
                        host: request.normalizedHost,
                        browserBundleIdentifier: browser.bundleIdentifier
                    )
                } else {
                    if suggestion != nil {
                        self.siteRoutingStore.dismissSuggestion(for: request.normalizedHost)
                    }
                    self.siteRoutingStore.recordChoice(
                        host: request.normalizedHost,
                        browserBundleIdentifier: browser.bundleIdentifier
                    )
                }
                self.onPick(browser, request)
                self.showCurrent()
            },
            onAcceptSuggestion: { [weak self] in
                guard let self,
                      let suggestedBrowser = suggestion?.1,
                      let request = self.requests.completeCurrent() else { return }
                self.siteRoutingStore.remember(
                    host: request.normalizedHost,
                    browserBundleIdentifier: suggestedBrowser.bundleIdentifier
                )
                self.onPick(suggestedBrowser, request)
                self.showCurrent()
            },
            onDismissSuggestion: { [weak self] in
                self?.siteRoutingStore.dismissSuggestion(for: request.normalizedHost)
            },
            onCancel: { [weak self] in
                self?.requests.cancelCurrent()
                self?.showCurrent()
            }
        )
        window?.contentViewController = NSHostingController(rootView: view)

        // Size to fit content
        if let window {
            window.layoutIfNeeded()
            let fitted = window.contentViewController?.view.fittingSize ?? NSSize(width: 380, height: 200)
            window.setContentSize(fitted)
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

}
