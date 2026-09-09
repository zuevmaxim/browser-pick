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
