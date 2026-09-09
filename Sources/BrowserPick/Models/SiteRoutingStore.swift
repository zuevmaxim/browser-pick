import Foundation
import Observation

struct SiteRule: Identifiable, Codable, Hashable {
    var id: String { host }
    let host: String
    var browserBundleIdentifier: String
}

struct SiteSuggestion: Equatable {
    let host: String
    let browserBundleIdentifier: String
}

private struct SiteChoiceHistory: Codable, Equatable {
    var browserBundleIdentifier: String
    var consecutiveChoices: Int
    var suggestionCooldown: Int
}

@MainActor
@Observable
final class SiteRoutingStore {
    private(set) var rules: [SiteRule] = []
    var hasLearnedChoices: Bool { !histories.isEmpty }

    private var histories: [String: SiteChoiceHistory] = [:]
    private let defaults: UserDefaults
    private let rulesKey: String
    private let historiesKey: String

    private static let suggestionThreshold = 3
    private static let dismissalCooldown = 10

    init(
        defaults: UserDefaults = .standard,
        rulesKey: String = "siteRules",
        historiesKey: String = "siteChoiceHistories"
    ) {
        self.defaults = defaults
        self.rulesKey = rulesKey
        self.historiesKey = historiesKey
        load()
    }

    func browserBundleIdentifier(for host: String) -> String? {
        rules.first { $0.host == host }?.browserBundleIdentifier
    }

    func suggestion(for host: String) -> SiteSuggestion? {
        guard browserBundleIdentifier(for: host) == nil,
              let history = histories[host],
              history.consecutiveChoices >= Self.suggestionThreshold,
              history.suggestionCooldown == 0 else {
            return nil
        }
        return SiteSuggestion(host: host, browserBundleIdentifier: history.browserBundleIdentifier)
    }

    func recordChoice(host: String, browserBundleIdentifier: String) {
        guard self.browserBundleIdentifier(for: host) == nil else { return }

        if var history = histories[host],
           history.browserBundleIdentifier == browserBundleIdentifier {
            history.consecutiveChoices += 1
            history.suggestionCooldown = max(0, history.suggestionCooldown - 1)
            histories[host] = history
        } else {
            histories[host] = SiteChoiceHistory(
                browserBundleIdentifier: browserBundleIdentifier,
                consecutiveChoices: 1,
                suggestionCooldown: histories[host]?.suggestionCooldown ?? 0
            )
        }
        saveHistories()
    }

    func dismissSuggestion(for host: String) {
        guard var history = histories[host] else { return }
        history.suggestionCooldown = Self.dismissalCooldown
        histories[host] = history
        saveHistories()
    }

    func remember(host: String, browserBundleIdentifier: String) {
        let rule = SiteRule(host: host, browserBundleIdentifier: browserBundleIdentifier)
        if let index = rules.firstIndex(where: { $0.host == host }) {
            rules[index] = rule
        } else {
            rules.append(rule)
            rules.sort { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
        }
        histories.removeValue(forKey: host)
        saveRules()
        saveHistories()
    }

    func update(_ rule: SiteRule) {
        guard let index = rules.firstIndex(where: { $0.host == rule.host }) else { return }
        rules[index] = rule
        saveRules()
    }

    func remove(_ rule: SiteRule) {
        rules.removeAll { $0.host == rule.host }
        saveRules()
    }

    func clearLearnedChoices() {
        histories.removeAll()
        saveHistories()
    }

    private func load() {
        if let data = defaults.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([SiteRule].self, from: data) {
            rules = decoded
        }
        if let data = defaults.data(forKey: historiesKey),
           let decoded = try? JSONDecoder().decode([String: SiteChoiceHistory].self, from: data) {
            histories = decoded
        }
    }

    private func saveRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: rulesKey)
    }

    private func saveHistories() {
        guard let data = try? JSONEncoder().encode(histories) else { return }
        defaults.set(data, forKey: historiesKey)
    }
}
