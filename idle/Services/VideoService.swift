import UIKit

/// Represents a category of content within a video service (e.g., "Movies", "Trending").
struct ContentCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnailURL: URL?
}

/// Information about a playable stream extracted from a video item.
struct StreamInfo {
    let url: URL
    let resolution: Int?       // e.g., 1080, 720, 480
    let mimeType: String?
    let isLiveStream: Bool

    init(url: URL, resolution: Int? = nil, mimeType: String? = nil, isLiveStream: Bool = false) {
        self.url = url
        self.resolution = resolution
        self.mimeType = mimeType
        self.isLiveStream = isLiveStream
    }
}

/// A pluggable protocol for video services (Plex, YouTube, and future services).
/// Adding a new service = conforming to this protocol.
@MainActor
protocol VideoService: AnyObject, Sendable {
    var id: String { get }
    var name: String { get }
    var icon: UIImage { get }
    var isAuthenticated: Bool { get }

    /// Authenticate the user. Implementation varies per service.
    func authenticate() async throws

    /// Sign out and clear stored credentials.
    func signOut()

    /// Fetch top-level content categories (e.g., Movies, TV Shows, Trending).
    func fetchCategories() async throws -> [ContentCategory]

    /// Fetch video items within a given category.
    func fetchItems(for category: ContentCategory) async throws -> [VideoItem]

    /// Search for video items matching a query.
    func search(query: String) async throws -> [VideoItem]

    /// Extract the playable stream URL for a given video item.
    func extractStream(for item: VideoItem) async throws -> StreamInfo
}
