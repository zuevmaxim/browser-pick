import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(store: BrowserStore, siteRoutingStore: SiteRoutingStore) {
        let hosting = NSHostingController(
            rootView: SettingsView(store: store, siteRoutingStore: siteRoutingStore)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "BrowserPick Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 650))
        window.center()
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
