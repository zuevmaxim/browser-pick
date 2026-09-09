import Foundation

struct WebURLRequest: Equatable {
    let originalString: String
    let url: URL
    let normalizedHost: String

    init?(validating originalString: String) {
        guard !originalString.isEmpty,
              !originalString.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let components = URLComponents(string: originalString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let rawHost = components.host,
              !rawHost.isEmpty,
              components.url?.absoluteString == originalString,
              let url = URL(string: originalString) else {
            return nil
        }

        var normalizedHost = rawHost.lowercased()
        while normalizedHost.hasSuffix(".") {
            normalizedHost.removeLast()
        }
        guard !normalizedHost.isEmpty else { return nil }

        self.originalString = originalString
        self.url = url
        self.normalizedHost = normalizedHost
    }
}
