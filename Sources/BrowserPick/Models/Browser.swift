import AppKit
import Foundation

struct Browser: Identifiable, Codable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    var name: String
    var bundleURL: URL
    var shortcut: String? // single-character keyboard shortcut, lowercase

    static func discoverInstalled() -> [Browser] {
        guard let probeURL = URL(string: "https://example.com") else { return [] }
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: probeURL)

        let ourBundleID = Bundle.main.bundleIdentifier ?? ""

        return appURLs.compactMap { url -> Browser? in
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != ourBundleID else { return nil }

            let name = FileManager.default
                .displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")

            return Browser(
                bundleIdentifier: bundleID,
                name: name,
                bundleURL: url,
                shortcut: nil
            )
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func icon() -> NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}

enum BrowserLaunchValidator {
    static func isValidLaunchTarget(_ browser: Browser) -> Bool {
        isValidLaunchTarget(
            browser,
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            bundleIdentifierAt: { Bundle(url: $0)?.bundleIdentifier },
            handlersForScheme: { scheme in
                guard let probeURL = URL(string: "\(scheme)://example.com") else { return [] }
                return NSWorkspace.shared.urlsForApplications(toOpen: probeURL).compactMap {
                    Bundle(url: $0)?.bundleIdentifier
                }
            }
        )
    }

    static func isValidLaunchTarget(
        _ browser: Browser,
        ownBundleIdentifier: String?,
        fileExists: (URL) -> Bool,
        bundleIdentifierAt: (URL) -> String?,
        handlersForScheme: (String) -> [String]
    ) -> Bool {
        guard browser.bundleURL.isFileURL,
              browser.bundleURL.pathExtension.lowercased() == "app",
              fileExists(browser.bundleURL),
              browser.bundleIdentifier != ownBundleIdentifier,
              bundleIdentifierAt(browser.bundleURL) == browser.bundleIdentifier else {
            return false
        }

        return ["http", "https"].allSatisfy {
            handlersForScheme($0).contains(browser.bundleIdentifier)
        }
    }
}
