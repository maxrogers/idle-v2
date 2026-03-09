// Explicitly nonisolated to prevent SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
// from tainting Codable conformances, which would be errors in Swift 6.
import Foundation

nonisolated struct PlexPINResponse: Codable, Sendable {
    let id: Int
    let code: String
    let authToken: String?

    enum CodingKeys: String, CodingKey {
        case id, code
        case authToken = "authToken"
    }
}

nonisolated struct PlexUser: Codable, Identifiable, Sendable {
    let id: Int
    let uuid: String
    let title: String
    let thumb: String?
    let protected: Bool
    let home: Bool

    enum CodingKeys: String, CodingKey {
        case id, uuid, title, thumb
        case protected = "protected"
        case home
    }
}

nonisolated struct PlexServer: Codable, Identifiable, Sendable {
    let clientIdentifier: String
    let name: String
    let connections: [PlexConnection]

    var id: String { clientIdentifier }

    enum CodingKeys: String, CodingKey {
        case clientIdentifier, name, connections
    }
}

nonisolated struct PlexConnection: Codable, Sendable {
    let uri: String
    let local: Bool
    let relay: Bool
}

nonisolated struct PlexLibrarySection: Codable, Identifiable, Sendable {
    let key: String
    let title: String
    let type: String  // "movie", "show", "artist", "photo"

    var id: String { key }
}

nonisolated struct PlexMediaItem: Codable, Identifiable, Sendable {
    let ratingKey: String
    let key: String
    let title: String
    let type: String  // "movie", "show", "season", "episode"
    let year: Int?
    let thumb: String?
    let art: String?
    let summary: String?
    let duration: Int?
    let viewOffset: Int?

    var id: String { ratingKey }
}

nonisolated struct PlexMediaContainer<T: Codable>: Codable {
    let mediaContainer: PlexContainerBody<T>

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

nonisolated struct PlexContainerBody<T: Codable>: Codable {
    let size: Int?
    let directory: [T]?
    let metadata: [T]?
    let video: [T]?

    enum CodingKeys: String, CodingKey {
        case size
        case directory = "Directory"
        case metadata = "Metadata"
        case video = "Video"
    }
}
