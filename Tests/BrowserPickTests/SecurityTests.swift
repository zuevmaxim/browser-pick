import Foundation
import XCTest
@testable import BrowserPick

final class WebURLRequestTests: XCTestCase {
    func testAcceptsHTTPAndHTTPSAndPreservesExactInput() {
        let inputs = [
            "https://example.com/a%2Fb?q=a%20b#fragment",
            "HTTP://example.com:8080/path?x=1&x=2",
        ]

        for input in inputs {
            let request = WebURLRequest(validating: input)
            XCTAssertNotNil(request)
            XCTAssertEqual(request?.originalString, input)
            XCTAssertEqual(request?.url.absoluteString, input)
        }
    }

    func testNormalizesHostForExactSiteMatching() throws {
        let request = try XCTUnwrap(WebURLRequest(validating: "https://GitHub.COM./apple/swift"))

        XCTAssertEqual(request.normalizedHost, "github.com")
    }

    func testRejectsDisallowedAndMalformedURLs() {
        let inputs = [
            "file:///tmp/example",
            "javascript:alert(1)",
            "data:text/plain,hello",
            "browserpick://example.com",
            "/relative/path",
            "https:///missing-host",
            "https://",
            "https://example.com/%",
            "https://example.com/line\nfeed",
        ]

        for input in inputs {
            XCTAssertNil(WebURLRequest(validating: input), input)
        }
    }
}

@MainActor
final class SiteRoutingStoreTests: XCTestCase {
    func testSuggestsOnlyAfterThreeConsecutiveChoices() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SiteRoutingStore(defaults: defaults)

        store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        XCTAssertNil(store.suggestion(for: "github.com"))

        store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        XCTAssertEqual(
            store.suggestion(for: "github.com"),
            SiteSuggestion(host: "github.com", browserBundleIdentifier: "browser-a")
        )

        store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-b")
        XCTAssertNil(store.suggestion(for: "github.com"))
    }

    func testDismissedSuggestionReturnsAfterCooldown() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SiteRoutingStore(defaults: defaults)
        for _ in 0..<3 {
            store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        }

        store.dismissSuggestion(for: "github.com")
        for _ in 0..<9 {
            store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        }
        XCTAssertNil(store.suggestion(for: "github.com"))

        store.recordChoice(host: "github.com", browserBundleIdentifier: "browser-a")
        XCTAssertNotNil(store.suggestion(for: "github.com"))
    }

    func testRememberedRulePersistsAndCanBeChangedAndRemoved() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SiteRoutingStore(defaults: defaults)
        store.remember(host: "github.com", browserBundleIdentifier: "browser-a")

        let restored = SiteRoutingStore(defaults: defaults)
        XCTAssertEqual(restored.browserBundleIdentifier(for: "github.com"), "browser-a")
        XCTAssertNil(restored.browserBundleIdentifier(for: "evilgithub.com"))
        XCTAssertNil(restored.suggestion(for: "github.com"))

        var rule = try XCTUnwrap(restored.rules.first)
        rule.browserBundleIdentifier = "browser-b"
        restored.update(rule)
        XCTAssertEqual(restored.browserBundleIdentifier(for: "github.com"), "browser-b")

        restored.remove(rule)
        XCTAssertNil(restored.browserBundleIdentifier(for: "github.com"))
    }

    func testLearnedChoicesCanBeClearedWithoutRemovingRules() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SiteRoutingStore(defaults: defaults)
        store.recordChoice(host: "example.com", browserBundleIdentifier: "browser-a")
        store.remember(host: "github.com", browserBundleIdentifier: "browser-b")

        XCTAssertTrue(store.hasLearnedChoices)
        store.clearLearnedChoices()

        XCTAssertFalse(store.hasLearnedChoices)
        XCTAssertEqual(store.browserBundleIdentifier(for: "github.com"), "browser-b")
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "BrowserPickTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suiteName)), suiteName)
    }
}

final class FIFOQueueTests: XCTestCase {
    func testMultipleEventsAreCompletedInFIFOOrder() {
        var queue = FIFOQueue<String>()
        queue.enqueue("first")
        queue.enqueue("second")
        queue.enqueue("third")

        XCTAssertEqual(queue.current, "first")
        XCTAssertEqual(queue.completeCurrent(), "first")
        XCTAssertEqual(queue.current, "second")
        XCTAssertEqual(queue.completeCurrent(), "second")
        XCTAssertEqual(queue.completeCurrent(), "third")
        XCTAssertNil(queue.current)
    }

    func testCancelDoesNotCompleteOrForwardCurrentEvent() {
        var queue = FIFOQueue<String>()
        queue.enqueue("cancelled")
        queue.enqueue("next")

        queue.cancelCurrent()

        XCTAssertEqual(queue.current, "next")
        XCTAssertEqual(queue.completeCurrent(), "next")
    }
}

final class BrowserLaunchValidatorTests: XCTestCase {
    private let browser = Browser(
        bundleIdentifier: "com.example.Browser",
        name: "Example",
        bundleURL: URL(fileURLWithPath: "/Applications/Example.app"),
        shortcut: nil
    )

    func testAcceptsMatchingRegisteredBrowser() {
        XCTAssertTrue(validate(browser))
    }

    func testRejectsMissingOrStaleOrTamperedBrowserRecords() {
        XCTAssertFalse(validate(browser, fileExists: false))
        XCTAssertFalse(validate(browser, actualBundleIdentifier: "com.example.Other"))
        XCTAssertFalse(validate(browser, handlers: ["http": [], "https": [browser.bundleIdentifier]]))
        XCTAssertFalse(validate(browser, handlers: ["http": [browser.bundleIdentifier], "https": []]))

        let selfRecord = Browser(
            bundleIdentifier: "com.zuevmaxim.BrowserPick",
            name: "BrowserPick",
            bundleURL: URL(fileURLWithPath: "/Applications/BrowserPick.app"),
            shortcut: nil
        )
        XCTAssertFalse(validate(selfRecord, actualBundleIdentifier: selfRecord.bundleIdentifier))
    }

    private func validate(
        _ candidate: Browser,
        fileExists: Bool = true,
        actualBundleIdentifier: String? = "com.example.Browser",
        handlers: [String: [String]] = [
            "http": ["com.example.Browser"],
            "https": ["com.example.Browser"],
        ]
    ) -> Bool {
        BrowserLaunchValidator.isValidLaunchTarget(
            candidate,
            ownBundleIdentifier: "com.zuevmaxim.BrowserPick",
            fileExists: { _ in fileExists },
            bundleIdentifierAt: { _ in actualBundleIdentifier },
            handlersForScheme: { handlers[$0] ?? [] }
        )
    }
}

@MainActor
final class BrowserStoreTests: XCTestCase {
    func testSettingsPersistAcrossStoreInstances() throws {
        let suiteName = "BrowserPickTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let browser = Browser(
            bundleIdentifier: "com.example.Browser",
            name: "Original",
            bundleURL: URL(fileURLWithPath: "/Applications/Example.app"),
            shortcut: nil
        )
        let first = BrowserStore(defaults: defaults, discovery: { [browser] })
        var updated = browser
        updated.name = "Renamed"
        updated.shortcut = "e"
        first.update(updated)

        let restored = BrowserStore(defaults: defaults, discovery: { [] })
        XCTAssertEqual(restored.browsers, [updated])
    }
}
