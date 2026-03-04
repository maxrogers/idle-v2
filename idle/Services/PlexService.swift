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
        if let token {
            request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        }
    }

    /// Apply headers for plex.tv API calls (JSON responses).
    static func applyForPlexTV(to request: inout URLRequest, token: String? = nil) {
        apply(to: &request, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }
}

// MARK: - Stored Config

/// Plex configuration stored in UserDefaults.
struct PlexConfig: Codable {
    /// The admin/account plex.tv auth token (from PIN flow).
    var authToken: String

    /// The active user's token (may differ if a home user was selected).
    /// Falls back to authToken for configs saved before user switching was added.
    var userToken: String

    /// Selected server's access token (may differ from authToken for shared servers).
    var serverAccessToken: String

    /// Selected server connection URL, e.g. "https://192-168-1-100.abc123.plex.direct:32400"
    var serverURL: String

    /// Friendly server name.
    var serverName: String

    /// Server machine identifier.
    var machineIdentifier: String

    /// All available connection URLs for fallback.
    var allConnectionURLs: [String]?

    /// Selected Plex Home user name (nil = admin account).
    var selectedUserName: String?

    /// Selected Plex Home user ID.
    var selectedUserID: Int?

    init(authToken: String, userToken: String, serverAccessToken: String, serverURL: String, serverName: String, machineIdentifier: String, allConnectionURLs: [String]? = nil, selectedUserName: String? = nil, selectedUserID: Int? = nil) {
        self.authToken = authToken
        self.userToken = userToken
        self.serverAccessToken = serverAccessToken
        self.serverURL = serverURL
        self.serverName = serverName
        self.machineIdentifier = machineIdentifier
        self.allConnectionURLs = allConnectionURLs
        self.selectedUserName = selectedUserName
        self.selectedUserID = selectedUserID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authToken = try container.decode(String.self, forKey: .authToken)
        userToken = try container.decodeIfPresent(String.self, forKey: .userToken) ?? (try container.decode(String.self, forKey: .authToken))
        serverAccessToken = try container.decode(String.self, forKey: .serverAccessToken)
        serverURL = try container.decode(String.self, forKey: .serverURL)
        serverName = try container.decode(String.self, forKey: .serverName)
        machineIdentifier = try container.decode(String.self, forKey: .machineIdentifier)
        allConnectionURLs = try container.decodeIfPresent([String].self, forKey: .allConnectionURLs)
        selectedUserName = try container.decodeIfPresent(String.self, forKey: .selectedUserName)
        selectedUserID = try container.decodeIfPresent(Int.self, forKey: .selectedUserID)
    }
}

// MARK: - Home User Models

struct PlexHomeUser: Identifiable {
    let id: Int
    let title: String
    let isAdmin: Bool
    let isProtected: Bool  // has PIN
    let thumb: String?
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
        PlexHeaders.applyForPlexTV(to: &request)
        request.httpBody = "strong=false".data(using: .utf8)

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
            PlexHeaders.applyForPlexTV(to: &request)

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
        PlexHeaders.applyForPlexTV(to: &request, token: token)

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

    /// Pick the best connection URL for a server, preferring remote HTTPS.
    static func bestConnectionURL(for server: PlexResource) -> String? {
        guard let connections = server.connections, !connections.isEmpty else { return nil }

        // Prefer remote HTTPS connections
        if let remote = connections.first(where: { !($0.local ?? false) && $0.uri.hasPrefix("https") }) {
            return remote.uri
        }
        // Then any HTTPS
        if let https = connections.first(where: { $0.uri.hasPrefix("https") }) {
            return https.uri
        }
        // Fallback to first available (including HTTP)
        return connections.first?.uri
    }

    /// All connection URLs for a server, for fallback during playback.
    static func allConnectionURLs(for server: PlexResource) -> [String] {
        server.connections?.map(\.uri) ?? []
    }
}

// MARK: - Home User Management

enum PlexHomeUserManager {

    /// Fetch all home users for this account.
    static func fetchHomeUsers(token: String) async throws -> [PlexHomeUser] {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/home/users")!)
        PlexHeaders.apply(to: &request, token: token)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlexError.authenticationFailed
        }

        // Response is XML: <MediaContainer><User id="..." title="..." admin="1" protected="1" thumb="..."/></MediaContainer>
        let parser = PlexHomeUserXMLParser()
        return parser.parse(data: data)
    }

    /// Switch to a home user, optionally providing their PIN.
    /// Returns the new auth token for that user.
    static func switchUser(userID: Int, pin: String?, adminToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/home/users/\(userID)/switch")!)
        request.httpMethod = "POST"
        PlexHeaders.apply(to: &request, token: adminToken)

        if let pin, !pin.isEmpty {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "pin=\(pin)".data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 else {
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                throw PlexError.incorrectPIN
            }
            throw PlexError.authenticationFailed
        }

        // Response is XML: <User ... authenticationToken="..."/>
        let parser = PlexSwitchUserXMLParser()
        guard let token = parser.parseToken(data: data) else {
            throw PlexError.authenticationFailed
        }
        return token
    }
}

/// Parse home users XML response.
final class PlexHomeUserXMLParser: NSObject, XMLParserDelegate {
    private var users: [PlexHomeUser] = []

    func parse(data: Data) -> [PlexHomeUser] {
        users = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return users
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attr: [String: String] = [:]
    ) {
        if elementName == "User" {
            guard let idStr = attr["id"], let id = Int(idStr), let title = attr["title"] else { return }
            let isAdmin = attr["admin"] == "1"
            let isProtected = attr["protected"] == "1"
            users.append(PlexHomeUser(id: id, title: title, isAdmin: isAdmin, isProtected: isProtected, thumb: attr["thumb"]))
        }
    }
}

/// Parse the switch user response for the auth token.
final class PlexSwitchUserXMLParser: NSObject, XMLParserDelegate {
    private var token: String?

    func parseToken(data: Data) -> String? {
        token = nil
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return token
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attr: [String: String] = [:]
    ) {
        if elementName == "User", let authToken = attr["authenticationToken"], !authToken.isEmpty {
            token = authToken
        }
    }
}

// MARK: - Watchlist

enum PlexWatchlist {

    /// Fetch the user's watchlist from plex.tv discover API.
    /// Returns items with metadata from Plex's online service.
    static func fetchWatchlist(token: String) async throws -> [PlexWatchlistItem] {
        let urlStr = "https://discover.provider.plex.tv/library/sections/watchlist/all?includeCollections=1&includeExternalMedia=1&sort=watchlistedAt:desc"
        var request = URLRequest(url: URL(string: urlStr)!)
        PlexHeaders.applyForPlexTV(to: &request, token: token)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlexError.watchlistUnavailable
        }

        let container = try JSONDecoder().decode(PlexWatchlistResponse.self, from: data)
        return container.MediaContainer.Metadata ?? []
    }
}

struct PlexWatchlistResponse: Codable {
    let MediaContainer: PlexWatchlistContainer
}

struct PlexWatchlistContainer: Codable {
    let Metadata: [PlexWatchlistItem]?
}

struct PlexWatchlistItem: Codable, Identifiable {
    let ratingKey: String?
    let key: String?
    let guid: String?
    let title: String
    let type: String?
    let year: Int?
    let thumb: String?

    var id: String { ratingKey ?? key ?? title }
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
        // Trust the stored config — server reachability is checked at connection time
        self.config = config
    }

    func signOut() {
        config = nil
        UserDefaults.standard.removeObject(forKey: "idle_plex_config")
    }

    // MARK: - Server Requests

    /// URLSession with a shorter timeout for server-to-server requests.
    private static let serverSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private func serverRequest(path: String) throws -> URLRequest {
        guard let config = config else { throw PlexError.notConfigured }
        guard let url = URL(string: "\(config.serverURL)\(path)") else {
            throw PlexError.notConfigured
        }
        var request = URLRequest(url: url)
        PlexHeaders.apply(to: &request, token: config.serverAccessToken)
        return request
    }

    // MARK: - Content Browsing

    func fetchCategories() async throws -> [ContentCategory] {
        let request = try serverRequest(path: "/library/sections")
        let (data, _) = try await Self.serverSession.data(for: request)

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
        let request = try serverRequest(path: "/library/sections/\(category.id)/all")
        let (data, _) = try await Self.serverSession.data(for: request)

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
        let request = try serverRequest(path: "/search?query=\(encodedQuery)")
        let (data, _) = try await Self.serverSession.data(for: request)

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

    /// Fetch the user's watchlist and resolve each item against the local server.
    func fetchWatchlistItems() async throws -> [VideoItem] {
        guard let config = config else { throw PlexError.notConfigured }

        let watchlist = try await PlexWatchlist.fetchWatchlist(token: config.userToken)

        // For each watchlist item, search the server for a matching title
        var videoItems: [VideoItem] = []
        for wlItem in watchlist.prefix(20) {
            // Try to find this item on the local server by searching its title
            let encodedTitle = wlItem.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? wlItem.title
            let request = try serverRequest(path: "/search?query=\(encodedTitle)")
            if let (data, _) = try? await Self.serverSession.data(for: request) {
                let parser = PlexXMLParser()
                let matches = parser.parseItems(data: data, serverURL: config.serverURL, token: config.serverAccessToken)
                // Use the first match that has the same title
                if let match = matches.first(where: { $0.title.lowercased() == wlItem.title.lowercased() }) ?? matches.first {
                    var thumbURL: String? = match.thumbnailURL
                    // Use discover thumb if server didn't provide one
                    if thumbURL == nil, let thumb = wlItem.thumb {
                        thumbURL = thumb
                    }
                    videoItems.append(VideoItem(
                        title: match.title,
                        originalURL: match.streamURL,
                        source: .plex,
                        thumbnailURL: thumbURL,
                        streamURL: match.streamURL
                    ))
                    continue
                }
            }

            // Item not on server — still show it but mark as unavailable
            videoItems.append(VideoItem(
                title: wlItem.title + (wlItem.year != nil ? " (\(wlItem.year!))" : ""),
                originalURL: "",
                source: .plex,
                thumbnailURL: wlItem.thumb
            ))
        }

        return videoItems
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
    case incorrectPIN
    case watchlistUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Plex not configured"
        case .authenticationFailed: return "Could not connect to Plex"
        case .authenticationTimedOut: return "Authentication timed out"
        case .noStreamURL: return "No stream URL available"
        case .noServersFound: return "No Plex servers found on your account"
        case .incorrectPIN: return "Incorrect PIN"
        case .watchlistUnavailable: return "Could not load watchlist"
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
