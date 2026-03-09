import Foundation
import os.log

// MARK: - Plex API Actor

private let log = Logger(subsystem: "com.steverogers.idle", category: "PlexAPI")

actor PlexAPI {

    static let shared = PlexAPI()

    private let baseURL = "https://plex.tv"
    private let clientID: String
    private let session: URLSession

    private var headers: [String: String] {
        [
            "X-Plex-Client-Identifier": clientID,
            "X-Plex-Product": "idle",
            "X-Plex-Version": "1.0",
            "X-Plex-Platform": "iOS",
            "X-Plex-Device": "iPhone",
            "X-Plex-Device-Name": "idle",
            "Accept": "application/json"
        ]
    }

    init() {
        // Use a persistent client ID stored in UserDefaults
        if let existing = UserDefaults.standard.string(forKey: "plex_client_id") {
            clientID = existing
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "plex_client_id")
            clientID = newID
        }
        session = URLSession.shared
    }

    // MARK: - Authentication

    func requestPIN() async throws -> (id: Int, code: String) {
        log.info("requestPIN: using clientID=\(self.clientID, privacy: .private)")
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v2/pins")!)
        request.httpMethod = "POST"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        // NOTE: do NOT override X-Plex-Client-Identifier here — it must match the
        // clientID used when polling, otherwise Plex returns authToken=null forever.

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            log.info("requestPIN: HTTP \(http.statusCode)")
        }
        if let raw = String(data: data, encoding: .utf8) {
            log.debug("requestPIN response: \(raw, privacy: .private)")
        }
        let pin = try JSONDecoder().decode(PlexPINResponse.self, from: data)
        log.info("requestPIN: got id=\(pin.id) code=\(pin.code, privacy: .private)")
        return (pin.id, pin.code)
    }

    func pollPIN(id: Int) async throws -> String? {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v2/pins/\(id)")!)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            log.warning("pollPIN id=\(id): HTTP \(http.statusCode)")
        }
        let pin = try JSONDecoder().decode(PlexPINResponse.self, from: data)
        if let token = pin.authToken {
            log.info("pollPIN id=\(id): authToken received ✓")
            return token
        }
        log.debug("pollPIN id=\(id): no token yet (expiresAt=\(pin.expiresAt ?? "?", privacy: .public))")
        return nil
    }

    func getHomeUsers(token: String) async throws -> [PlexUser] {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v2/home/users")!)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        let (data, _) = try await session.data(for: request)
        if let raw = String(data: data, encoding: .utf8) {
            log.debug("getHomeUsers raw response: \(raw, privacy: .private)")
        }

        // v2/home/users returns: { "MediaContainer": { "users": [...] } }
        // OR a direct array, OR just { "users": [...] }
        struct HomeUsersRoot: Codable {
            let users: [PlexUser]?
        }
        struct MediaContainerRoot: Codable {
            let mediaContainer: HomeUsersRoot?
            enum CodingKeys: String, CodingKey {
                case mediaContainer = "MediaContainer"
            }
        }

        // Try direct array
        if let users = try? JSONDecoder().decode([PlexUser].self, from: data), !users.isEmpty {
            log.info("getHomeUsers: decoded as direct array, count=\(users.count)")
            return users
        }
        // Try { users: [...] }
        if let root = try? JSONDecoder().decode(HomeUsersRoot.self, from: data),
           let users = root.users, !users.isEmpty {
            log.info("getHomeUsers: decoded as HomeUsersRoot, count=\(users.count)")
            return users
        }
        // Try { MediaContainer: { users: [...] } }
        if let root = try? JSONDecoder().decode(MediaContainerRoot.self, from: data),
           let users = root.mediaContainer?.users, !users.isEmpty {
            log.info("getHomeUsers: decoded as MediaContainerRoot, count=\(users.count)")
            return users
        }

        // Fallback: try /api/v2/users (returns all friends/managed users)
        log.info("getHomeUsers: home/users empty, trying /api/v2/users")
        return try await getManagedUsers(token: token)
    }

    private func getManagedUsers(token: String) async throws -> [PlexUser] {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v2/users")!)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        let (data, _) = try await session.data(for: request)
        if let raw = String(data: data, encoding: .utf8) {
            log.debug("getManagedUsers raw response: \(raw, privacy: .private)")
        }

        if let users = try? JSONDecoder().decode([PlexUser].self, from: data) {
            log.info("getManagedUsers: decoded \(users.count) users")
            return users
        }
        return []
    }

    func switchUser(userID: Int, pin: String?, token: String) async throws -> String {
        var url = URLComponents(string: "\(baseURL)/api/v2/home/users/\(userID)/switch")!
        if let pin {
            url.queryItems = [URLQueryItem(name: "pin", value: pin)]
        }
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        let (data, _) = try await session.data(for: request)
        struct SwitchResponse: Codable {
            let authToken: String
        }
        let response = try JSONDecoder().decode(SwitchResponse.self, from: data)
        return response.authToken
    }

    func getServers(token: String) async throws -> [PlexServer] {
        var components = URLComponents(string: "\(baseURL)/api/v2/resources")!
        components.queryItems = [
            URLQueryItem(name: "includeHttps", value: "1"),
            URLQueryItem(name: "includeRelay", value: "1")
        ]
        var request = URLRequest(url: components.url!)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        let (data, _) = try await session.data(for: request)
        return (try? JSONDecoder().decode([PlexServer].self, from: data)) ?? []
    }

    // MARK: - Library

    func getLibrarySections(serverURL: URL, token: String) async throws -> [PlexLibrarySection] {
        let url = serverURL.appendingPathComponent("library/sections")
        let data = try await authenticatedGet(url: url, token: token)
        let container = try JSONDecoder().decode(PlexMediaContainer<PlexLibrarySection>.self, from: data)
        return container.mediaContainer.directory ?? []
    }

    func getOnDeck(serverURL: URL, token: String) async throws -> [PlexMediaItem] {
        let url = serverURL.appendingPathComponent("library/onDeck")
        let data = try await authenticatedGet(url: url, token: token)
        let container = try JSONDecoder().decode(PlexMediaContainer<PlexMediaItem>.self, from: data)
        return container.mediaContainer.metadata ?? []
    }

    func getRecentlyAdded(serverURL: URL, token: String) async throws -> [PlexMediaItem] {
        let url = serverURL.appendingPathComponent("library/recentlyAdded")
        let data = try await authenticatedGet(url: url, token: token)
        let container = try JSONDecoder().decode(PlexMediaContainer<PlexMediaItem>.self, from: data)
        return container.mediaContainer.metadata ?? []
    }

    func getSectionContent(serverURL: URL, sectionKey: String, token: String) async throws -> [PlexMediaItem] {
        let url = serverURL.appendingPathComponent("library/sections/\(sectionKey)/all")
        let data = try await authenticatedGet(url: url, token: token)
        let container = try JSONDecoder().decode(PlexMediaContainer<PlexMediaItem>.self, from: data)
        return container.mediaContainer.metadata ?? []
    }

    func getChildren(serverURL: URL, itemKey: String, token: String) async throws -> [PlexMediaItem] {
        let path = itemKey.hasPrefix("/") ? String(itemKey.dropFirst()) : itemKey
        let url = serverURL.appendingPathComponent(path).appendingPathComponent("children")
        let data = try await authenticatedGet(url: url, token: token)
        let container = try JSONDecoder().decode(PlexMediaContainer<PlexMediaItem>.self, from: data)
        return container.mediaContainer.metadata ?? []
    }

    func getPartKey(serverURL: URL, itemKey: String, token: String) async throws -> String {
        // Fetch item metadata to get the actual Part stream URL
        let path = itemKey.hasPrefix("/") ? String(itemKey.dropFirst()) : itemKey
        let url = serverURL.appendingPathComponent(path)
        let data = try await authenticatedGet(url: url, token: token)
        // Parse to find Media > Part > key
        struct PartContainer: Codable {
            let mediaContainer: PartBody
            enum CodingKeys: String, CodingKey { case mediaContainer = "MediaContainer" }
        }
        struct PartBody: Codable {
            let metadata: [PartMetadata]?
            enum CodingKeys: String, CodingKey { case metadata = "Metadata" }
        }
        struct PartMetadata: Codable {
            let media: [MediaItem]?
            enum CodingKeys: String, CodingKey { case media = "Media" }
        }
        struct MediaItem: Codable {
            let part: [PartItem]?
            enum CodingKeys: String, CodingKey { case part = "Part" }
        }
        struct PartItem: Codable {
            let key: String
        }
        let container = try JSONDecoder().decode(PartContainer.self, from: data)
        guard let key = container.mediaContainer.metadata?.first?.media?.first?.part?.first?.key else {
            throw PlexError.apiError("No playable part found")
        }
        return key
    }

    // MARK: - Thumbnails

    nonisolated func thumbnailURL(serverURL: URL, thumbPath: String, token: String, width: Int = 300, height: Int = 169) -> URL {
        let path = thumbPath.hasPrefix("/") ? String(thumbPath.dropFirst()) : thumbPath
        var components = URLComponents(url: serverURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "X-Plex-Token", value: token),
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "height", value: "\(height)"),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "upscale", value: "1"),
            URLQueryItem(name: "format", value: "jpeg")
        ]
        return components.url ?? serverURL
    }

    // MARK: - Private

    private func authenticatedGet(url: URL, token: String) async throws -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "X-Plex-Token", value: token)
        ]
        var request = URLRequest(url: components.url ?? url)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw PlexError.networkError("HTTP \(httpResponse.statusCode)")
        }
        return data
    }
}


