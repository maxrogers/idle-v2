import UIKit
import Foundation

/// YouTube video service integration.
/// Uses YouTube Data API for browsing/search, YouTubeKit for stream extraction.
final class YouTubeService: VideoService {
    let id = "youtube"
    let name = "YouTube"
    let icon = UIImage(systemName: "play.rectangle.fill")!

    private var apiKey: String?

    var isAuthenticated: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    init() {
        apiKey = Self.loadStoredAPIKey()
    }

    // MARK: - Authentication

    func authenticate() async throws {
        guard let key = Self.loadStoredAPIKey(), !key.isEmpty else {
            throw YouTubeError.noAPIKey
        }

        // Validate key with a lightweight API call
        let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=id&id=dQw4w9WgXcQ&key=\(key)")!
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw YouTubeError.invalidAPIKey
        }

        self.apiKey = key
    }

    func signOut() {
        apiKey = nil
        UserDefaults.standard.removeObject(forKey: "idle_youtube_api_key")
    }

    // MARK: - Content Browsing

    func fetchCategories() async throws -> [ContentCategory] {
        // Static categories for YouTube
        return [
            ContentCategory(id: "trending", name: "Trending", thumbnailURL: nil),
            ContentCategory(id: "search", name: "Search", thumbnailURL: nil),
        ]
    }

    func fetchItems(for category: ContentCategory) async throws -> [VideoItem] {
        guard let key = apiKey else { throw YouTubeError.noAPIKey }

        switch category.id {
        case "trending":
            return try await fetchTrending(apiKey: key)
        default:
            return []
        }
    }

    func search(query: String) async throws -> [VideoItem] {
        guard let key = apiKey else { throw YouTubeError.noAPIKey }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=12&q=\(encodedQuery)&key=\(key)"
        guard let url = URL(string: urlString) else { throw YouTubeError.invalidResponse }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseSearchResults(data: data)
    }

    func extractStream(for item: VideoItem) async throws -> StreamInfo {
        // Use YouTubeExtractor for actual stream extraction
        let extractor = YouTubeExtractor()
        guard let url = URL(string: item.originalURL) else {
            throw ExtractionError.invalidURL
        }
        let streams = try await extractor.extract(from: url)
        guard let best = streams.first else {
            throw ExtractionError.noStreamsFound
        }
        return best
    }

    // MARK: - API Calls

    private func fetchTrending(apiKey: String) async throws -> [VideoItem] {
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&chart=mostPopular&maxResults=12&regionCode=US&key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw YouTubeError.invalidResponse }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseTrendingResults(data: data)
    }

    // MARK: - Parsing

    private func parseTrendingResults(data: Data) throws -> [VideoItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw YouTubeError.invalidResponse
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { return nil }

            let thumbnailURL = (snippet["thumbnails"] as? [String: Any])?["high"] as? [String: Any]
            let thumbURL = thumbnailURL?["url"] as? String

            return VideoItem(
                title: title,
                originalURL: "https://www.youtube.com/watch?v=\(id)",
                source: .youtube,
                thumbnailURL: thumbURL
            )
        }
    }

    private func parseSearchResults(data: Data) throws -> [VideoItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw YouTubeError.invalidResponse
        }

        return items.compactMap { item in
            guard let idObj = item["id"] as? [String: Any],
                  let videoId = idObj["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { return nil }

            let thumbnailURL = (snippet["thumbnails"] as? [String: Any])?["high"] as? [String: Any]
            let thumbURL = thumbnailURL?["url"] as? String

            return VideoItem(
                title: title,
                originalURL: "https://www.youtube.com/watch?v=\(videoId)",
                source: .youtube,
                thumbnailURL: thumbURL
            )
        }
    }

    // MARK: - Config Storage

    static func loadStoredAPIKey() -> String? {
        UserDefaults.standard.string(forKey: "idle_youtube_api_key")
    }

    static func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "idle_youtube_api_key")
    }
}

// MARK: - Errors

enum YouTubeError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "YouTube API key not configured"
        case .invalidAPIKey: return "Invalid YouTube API key"
        case .invalidResponse: return "Invalid response from YouTube"
        }
    }
}
