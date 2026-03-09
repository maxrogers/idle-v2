import SwiftUI
@preconcurrency import CarPlay

/// Plex service plugin — the flagship VideoServicePlugin implementation.
/// Handles Plex PIN authentication, home user selection, library browsing,
/// and CarPlay template generation.
@MainActor
final class PlexService: VideoServicePlugin, @unchecked Sendable {
    let id = "plex"
    let displayName = "Plex"
    let iconSystemName = "play.rectangle.fill"

    // Injected by AppDelegate / environment
    var plexAPI: PlexAPI?

    var isAuthenticated: Bool {
        KeychainHelper.load(key: "plex_user_token") != nil
    }

    var selectedServerURL: URL? {
        guard let urlString = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: urlString)
    }

    func authenticationView() -> AnyView? {
        AnyView(PlexAuthView())
    }

    func browseView() -> AnyView {
        AnyView(PlexLibraryView())
    }

    func carPlayTab(interfaceController: CPInterfaceController) -> CPTemplate {
        let template = CPListTemplate(title: "Plex", sections: [
            CPListSection(items: [loadingItem()], header: "Loading…", sectionIndexTitle: nil)
        ])
        template.tabTitle = "Plex"
        template.tabImage = UIImage(systemName: "play.rectangle.fill")

        // Kick off async load
        Task { @MainActor in
            await PlexCarPlayTemplateBuilder.populate(
                template: template,
                interfaceController: interfaceController
            )
        }

        return template
    }

    func playbackURL(for itemID: String) async throws -> URL {
        guard let serverURL = selectedServerURL,
              let tokenData = KeychainHelper.load(key: "plex_user_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            throw PlexError.notAuthenticated
        }
        // Direct play URL: serverURL + itemKey + auth token
        var components = URLComponents(url: serverURL.appendingPathComponent(itemID), resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]
        guard let url = components.url else { throw PlexError.invalidURL }
        return url
    }

    // MARK: - Private

    private func loadingItem() -> CPListItem {
        let item = CPListItem(text: "Loading Plex library…", detailText: nil)
        item.handler = { _, completion in completion() }
        return item
    }
}

enum PlexError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case networkError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated with Plex"
        case .invalidURL: return "Invalid media URL"
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiError(let msg): return "Plex API error: \(msg)"
        }
    }
}
