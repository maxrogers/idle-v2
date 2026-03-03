import UIKit
import Foundation

/// Plex configuration stored in Keychain/UserDefaults.
struct PlexConfig: Codable {
    var serverURL: String   // e.g., "http://192.168.1.100:32400"
    var token: String       // X-Plex-Token
    var serverName: String? // Friendly name
}

/// Plex video service integration.
/// Provides library browsing and direct stream URL construction.
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
        // Authentication is handled via the iPhone settings UI.
        // This method validates the stored config by hitting the server.
        guard let config = Self.loadStoredConfig() else {
            throw PlexError.notConfigured
        }

        let url = URL(string: "\(config.serverURL)/identity?X-Plex-Token=\(config.token)")!
        let (_, response) = try await URLSession.shared.data(from: url)
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

        let url = URL(string: "\(config.serverURL)/library/sections?X-Plex-Token=\(config.token)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse XML response for library sections
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

        let url = URL(string: "\(config.serverURL)/library/sections/\(category.id)/all?X-Plex-Token=\(config.token)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let parser = PlexXMLParser()
        let items = parser.parseItems(data: data, serverURL: config.serverURL, token: config.token)

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
        let url = URL(string: "\(config.serverURL)/search?query=\(encodedQuery)&X-Plex-Token=\(config.token)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let parser = PlexXMLParser()
        let items = parser.parseItems(data: data, serverURL: config.serverURL, token: config.token)

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
    case noStreamURL

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Plex server not configured"
        case .authenticationFailed: return "Could not connect to Plex server"
        case .noStreamURL: return "No stream URL available"
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
