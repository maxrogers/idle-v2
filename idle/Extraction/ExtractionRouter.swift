import Foundation

/// Routes URLs to the appropriate video extractor based on URL patterns.
@MainActor
final class ExtractionRouter {

    static let shared = ExtractionRouter()

    private let youtubeExtractor = YouTubeExtractor()
    private let plexExtractor = PlexExtractor()
    private let genericExtractor = GenericExtractor()

    private init() {}

    /// Extract playable stream URLs from any URL.
    /// Returns streams ordered by quality (best first).
    func extract(from urlString: String) async throws -> [StreamInfo] {
        guard let url = URL(string: urlString) else {
            throw ExtractionError.invalidURL
        }

        let host = url.host?.lowercased() ?? ""

        // YouTube
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return try await youtubeExtractor.extract(from: url)
        }

        // Plex
        if host.contains("plex") || urlString.contains("X-Plex-Token") {
            return try await plexExtractor.extract(from: url)
        }

        // Direct video URLs
        let pathExtension = url.pathExtension.lowercased()
        if ["mp4", "m4v", "mov", "m3u8", "mpd", "webm"].contains(pathExtension) {
            return [StreamInfo(url: url, mimeType: mimeType(for: pathExtension))]
        }

        // Generic: try to extract from page
        return try await genericExtractor.extract(from: url)
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m3u8": return "application/x-mpegURL"
        case "webm": return "video/webm"
        default: return "video/mp4"
        }
    }
}

enum ExtractionError: LocalizedError {
    case invalidURL
    case noStreamsFound
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noStreamsFound: return "No playable video found"
        case .extractionFailed(let reason): return "Extraction failed: \(reason)"
        }
    }
}
