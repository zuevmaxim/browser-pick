import Foundation

struct WebURLRequest: Equatable {
    let originalString: String
    let url: URL

    init?(validating originalString: String) {
        guard !originalString.isEmpty,
              !originalString.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let components = URLComponents(string: originalString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              components.url?.absoluteString == originalString,
              let url = URL(string: originalString) else {
            return nil
        }

        self.originalString = originalString
        self.url = url
    }
}
