import Foundation

/// Generates and parses stable links to saved ShareGather items.
public enum SharedItemDeepLink {
    public static let scheme = "sharegather"
    public static let host = "bookmark"

    /// Returns the canonical URL for a saved item.
    public static func url(for itemID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(itemID.uuidString)"

        guard let url = components.url else {
            preconditionFailure("The static ShareGather deep-link components must form a valid URL.")
        }
        return url
    }

    /// Extracts a saved-item identifier from a canonical ShareGather bookmark URL.
    public static func itemID(from url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == host,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        let path = components.percentEncodedPath
        guard path.first == "/",
              path.last != "/",
              !path.dropFirst().contains("/") else {
            return nil
        }

        let identifier = String(path.dropFirst())
        guard !identifier.contains("%"),
              let itemID = UUID(uuidString: identifier),
              itemID.uuidString.caseInsensitiveCompare(identifier) == .orderedSame else {
            return nil
        }
        return itemID
    }
}

/// Resolves a deep link against the current library snapshot without touching SwiftUI state.
public enum DeepLinkOutcome: Equatable, Sendable {
    case open(UUID)
    case unavailable
}

extension SharedItemDeepLink {
    /// Pure decision: given a URL and the currently known items, returns the routing outcome.
    /// `unavailable` covers malformed URLs and references to items that no longer exist.
    public static func resolve(_ url: URL, against items: [SharedItem]) -> DeepLinkOutcome {
        guard let itemID = itemID(from: url) else { return .unavailable }
        guard items.contains(where: { $0.id == itemID }) else { return .unavailable }
        return .open(itemID)
    }
}
