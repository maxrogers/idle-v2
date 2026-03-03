import UIKit
import Foundation

// MARK: - Plex Headers

/// Standard headers required for all Plex API requests.
/// Including `X-Plex-Provides: player` registers idle as a Plex player device.
enum PlexHeaders {
    static let clientIdentifier: String = {
        let key = "idle_plex_client_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }()

    static let product = "idle"
    static let version = "1.0.0"
    static let platform = "iOS"
    static let device = "iPhone"

    static func apply(to request: inout URLRequest, token: String? = nil) {
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(product, forHTTPHeaderField: "X-Plex-Product")
        request.setValue(version, forHTTPHeaderField: "X-Plex-Version")
        request.setValue(platform, forHTTPHeaderField: "X-Plex-Platform")
        request.setValue(device, forHTTPHeaderField: "X-Plex-Device")
        request.setValue(product, forHTTPHeaderField: "X-Plex-Device-Name")
        request.setValue("player", forHTTPHeaderField: "X-Plex-Provides")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        }
    }
}

// MARK: - Stored Config

/// Plex configuration stored in UserDefaults.
struct PlexConfig: Codable {
    /// The user's plex.tv auth token (from PIN flow).
    var authToken: String

    /// Selected server's access token (may differ from authToken for shared servers).
    var serverAccessToken: String

    /// Selected server connection URL, e.g. "https://192-168-1-100.abc123.plex.direct:32400"
    var serverURL: String

    /// Friendly server name.
    var serverName: String

    /// Server machine identifier.
    var machineIdentifier: String
}

// MARK: - PIN Auth Models

struct PlexPIN: Codable {
    let id: Int
    let code: String
    let authToken: String?
    let expiresAt: String?
}

// MARK: - Resource Models

struct PlexResource: Codable {
    let name: String
    let provides: String
    let clientIdentifier: String
    let accessToken: String?
    let owned: Bool?
    let connections: [PlexConnection]?
}

struct PlexConnection: Codable {
    let uri: String
    let local: Bool?
}

// MARK: - PIN Authentication Manager

/// Handles the Plex Link Code (PIN) authentication flow.
/// 1. POST /api/v2/pins → get a 4-char code
/// 2. User visits plex.tv/link and enters the code
/// 3. Poll GET /api/v2/pins/{id} until authToken is returned
@MainActor
final class PlexPINAuth: ObservableObject {

    enum AuthState: Equatable {
        case idle
        case waitingForUser(code: String)
        case polling
        case authenticated(token: String)
        case failed(String)
    }

    @Published var state: AuthState = .idle

    private var pinID: Int?
    private var pollTask: Task<Void, Never>?

    /// Start the PIN auth flow: request a new PIN and begin polling.
    func startAuth() {
        state = .polling
        pollTask?.cancel()

        pollTask = Task {
            do {
                // Step 1: Request a PIN
                let pin = try await requestPIN()
                pinID = pin.id
                state = .waitingForUser(code: pin.code)

                // Step 2: Poll for auth token
                let token = try await pollForToken(pinID: pin.id, code: pin.code)
                state = .authenticated(token: token)
            } catch is CancellationError {
                // Cancelled — no state change needed
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        state = .idle
    }

    // MARK: - API Calls

    private func requestPIN() async throws -> PlexPIN {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        PlexHeaders.apply(to: &request)
        request.httpBody = "strong=true".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 else {
            throw PlexError.authenticationFailed
        }
        return try JSONDecoder().decode(PlexPIN.self, from: data)
    }

    private func pollForToken(pinID: Int, code: String) async throws -> String {
        let maxAttempts = 180  // ~3 minutes at 1s intervals
        for _ in 0..<maxAttempts {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(1))

            var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins/\(pinID)")!)
            request.httpMethod = "GET"
            PlexHeaders.apply(to: &request)

            let (data, _) = try await URLSession.shared.data(for: request)
            let pin = try JSONDecoder().decode(PlexPIN.self, from: data)

            if let token = pin.authToken, !token.isEmpty {
                return token
            }
        }

        throw PlexError.authenticationTimedOut
    }
}

// MARK: - Server Discovery

/// After authentication, fetches the user's Plex servers.
enum PlexServerDiscovery {

    static func fetchServers(token: String) async throws -> [PlexResource] {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1")!)
        PlexHeaders.apply(to: &request, token: token)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlexError.authenticationFailed
        }

        let resources = try JSONDecoder().decode([PlexResource].self, from: data)

        // Filter to owned servers that provide "server"
        return resources.filter { resource in
            resource.provides.contains("server")
        }
    }

    /// Pick the best connection URL for a server, preferring non-local HTTPS.
    static func bestConnectionURL(for server: PlexResource) -> String? {
        // Prefer remote HTTPS connections
        if let remote = server.connections?.first(where: { !($0.local ?? false) && $0.uri.hasPrefix("https") }) {
            return remote.uri
        }
        // Then any HTTPS
        if let https = server.connections?.first(where: { $0.uri.hasPrefix("https") }) {
            return https.uri
        }
        // Fallback to first available
        return server.connections?.first?.uri
    }
}

// MARK: - Plex Service

/// Plex video service integration using Link Code (PIN) authentication.
/// Registers idle as a Plex player device via X-Plex-Provides headers.
final class PlexService: VideoService {
    let id = "plex"
    let name = "Plex"
    let icon = UIImage(systemName: "play.rectangle.on.rectangle")!

    private var config: PlexConfig?

    var isAuthenticated: Bool {
        config != nil
    }

    init() {
        config = Self.loadStoredConfig()
    }

    // MARK: - Authentication

    func authenticate() async throws {
        guard let config = Self.loadStoredConfig() else {
            throw PlexError.notConfigured
        }

        // Validate by hitting the server identity endpoint
        guard let url = URL(string: "\(config.serverURL)/identity") else {
            throw PlexError.authenticationFailed
        }
        var request = URLRequest(url: url)
        PlexHeaders.apply(to: &request, token: config.serverAccessToken)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PlexError.authenticationFailed
        }

        self.config = config
    }

    func signOut() {
        config = nil
        UserDefaults.standard.removeObject(forKey: "idle_plex_config")
    }

    // MARK: - Content Browsing

    func fetchCategories() async throws -> [ContentCategory] {
        guard let config = config else { throw PlexError.notConfigured }

        guard let url = URL(string: "\(config.serverURL)/library/sections") else {
            throw PlexError.notConfigured
        }
        var request = URLRequest(url: url)
        PlexHeaders.apply(to: &request, token: config.serverAccessToken)

        let (data, _) = try await URLSession.shared.data(for: request)

        let parser = PlexXMLParser()
        let sections = parser.parseSections(data: data)

        return sections.map { section in
            ContentCategory(
                id: section.key,
                name: section.title,
                thumbnailURL: nil
            )
        }
    }

    func fetchItems(for category: ContentCategory) async throws -> [VideoItem] {
        guard let config = config else { throw PlexError.notConfigured }

        guard let url = URL(string: "\(config.serverURL)/library/sections/\(category.id)/all") else {
            throw PlexError.notConfigured
        }
        var request = URLRequest(url: url)
        PlexHeaders.apply(to: &request, token: config.serverAccessToken)

        let (data, _) = try await URLSession.shared.data(for: request)

        let parser = PlexXMLParser()
        let items = parser.parseItems(data: data, serverURL: config.serverURL, token: config.serverAccessToken)

        return items.map { plexItem in
            VideoItem(
                title: plexItem.title,
                originalURL: plexItem.streamURL,
                source: .plex,
                thumbnailURL: plexItem.thumbnailURL,
                streamURL: plexItem.streamURL
            )
        }
    }

    func search(query: String) async throws -> [VideoItem] {
        guard let config = config else { throw PlexError.notConfigured }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(config.serverURL)/search?query=\(encodedQuery)") else {
            throw PlexError.notConfigured
        }
        var request = URLRequest(url: url)
        PlexHeaders.apply(to: &request, token: config.serverAccessToken)

        let (data, _) = try await URLSession.shared.data(for: request)

        let parser = PlexXMLParser()
        let items = parser.parseItems(data: data, serverURL: config.serverURL, token: config.serverAccessToken)

        return items.map { plexItem in
            VideoItem(
                title: plexItem.title,
                originalURL: plexItem.streamURL,
                source: .plex,
                thumbnailURL: plexItem.thumbnailURL,
                streamURL: plexItem.streamURL
            )
        }
    }

    func extractStream(for item: VideoItem) async throws -> StreamInfo {
        guard let streamURL = item.streamURL, let url = URL(string: streamURL) else {
            throw PlexError.noStreamURL
        }
        return StreamInfo(url: url)
    }

    // MARK: - Config Storage

    nonisolated static func loadStoredConfig() -> PlexConfig? {
        guard let data = UserDefaults.standard.data(forKey: "idle_plex_config") else { return nil }
        return try? JSONDecoder().decode(PlexConfig.self, from: data)
    }

    nonisolated static func saveConfig(_ config: PlexConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "idle_plex_config")
        }
    }
}

// MARK: - Errors

enum PlexError: LocalizedError {
    case notConfigured
    case authenticationFailed
    case authenticationTimedOut
    case noStreamURL
    case noServersFound

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Plex not configured"
        case .authenticationFailed: return "Could not connect to Plex"
        case .authenticationTimedOut: return "Authentication timed out"
        case .noStreamURL: return "No stream URL available"
        case .noServersFound: return "No Plex servers found on your account"
        }
    }
}

// MARK: - XML Parsing

struct PlexSection {
    let key: String
    let title: String
}

struct PlexMediaItem {
    let title: String
    let streamURL: String
    let thumbnailURL: String?
}

/// Lightweight XML parser for Plex API responses.
final class PlexXMLParser: NSObject, XMLParserDelegate {
    private var sections: [PlexSection] = []
    private var items: [PlexMediaItem] = []
    private var serverURL: String = ""
    private var token: String = ""

    func parseSections(data: Data) -> [PlexSection] {
        sections = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return sections
    }

    func parseItems(data: Data, serverURL: String, token: String) -> [PlexMediaItem] {
        items = []
        self.serverURL = serverURL
        self.token = token
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "Directory" {
            if let key = attributeDict["key"], let title = attributeDict["title"] {
                // Filter to video sections only
                let type = attributeDict["type"] ?? ""
                if type == "movie" || type == "show" {
                    sections.append(PlexSection(key: key, title: title))
                }
            }
        }

        if elementName == "Video" {
            if let title = attributeDict["title"], let key = attributeDict["key"] {
                let streamURL = "\(serverURL)\(key)?X-Plex-Token=\(token)"
                var thumbnailURL: String?
                if let thumb = attributeDict["thumb"] {
                    thumbnailURL = "\(serverURL)\(thumb)?X-Plex-Token=\(token)"
                }
                items.append(PlexMediaItem(
                    title: title,
                    streamURL: streamURL,
                    thumbnailURL: thumbnailURL
                ))
            }
        }
    }
}
