import AppKit
import SwiftUI

/// Borderless panel that still accepts key events.
private final class ChooserPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ChooserWindowController: NSWindowController {
    private let store: BrowserStore
    private let onPick: (Browser, WebURLRequest) -> Void
    private var currentRequest: WebURLRequest?

    init(store: BrowserStore, onPick: @escaping (Browser, WebURLRequest) -> Void) {
        self.store = store
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

    func show(for request: WebURLRequest) {
        currentRequest = request
        let view = ChooserView(
            store: store,
            request: request,
            onPick: { [weak self] browser in
                guard let request = self?.currentRequest else { return }
                self?.onPick(browser, request)
            },
            onCancel: { [weak self] in self?.hide() }
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

    func hide() {
        window?.orderOut(nil)
        currentRequest = nil
    }
}
